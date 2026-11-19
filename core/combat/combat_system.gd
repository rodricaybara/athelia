#class_name CombatSystem
# eliminar la línea (no necesita class_name si es autoload)
extends Node

## CombatSystem - Motor de mecánicas de combate
## Singleton: /root/Combat
##
## Responsabilidades POST-REFACTOR:
## - Ejecutar acciones de combate cuando GameLoop lo ordena
## - Resolver tiradas de habilidad con SkillRoller
## - Calcular daño con AttributeResolver
## - Aplicar daño a recursos (HP/Stamina)
## - Gestionar buffs activos de combate
## - Reproducir animaciones y VFX
## - Emitir resultados de acciones
## - Estimar daño y probabilidades sin efectos laterales (IA-0c)
## - Ofrecer a la IA candidatas, amenaza y condiciones visibles, solo lectura (IA-0c)
## - Resolver skills SELF de datos: BUFF, RESTORE y FLEE (IA-0c)
##
## NO hace (movido a GameLoopSystem):
## - Controlar turnos
## - Decidir orden de acciones
## - Iniciar/terminar combate
## - Detectar victoria/derrota
## - Gestionar targeting
##
## Arquitectura:
## - Event-driven: escucha eventos de GameLoop, emite resultados
## - Sin estado de flujo: solo ejecuta mecánicas
## - Integra con: SkillSystem, ResourceSystem, CharacterSystem, AttributeResolver

# ============================================
# CONSTANTES
# ============================================
## Contexto de la habilidad pendiente
## Se guarda aquí para usarlo en el callback de SkillSystem
var _pending_skill_context: Dictionary = {}

## Scene de números de daño (FASE B.2)
const DamageNumberScene = preload("res://ui/damage_number.tscn")

# ============================================
# ESTADO INTERNO
# ============================================

## ID del jugador (hardcoded para MVP)
const PLAYER_ID: String = "player"

## IA-0c — Grados con acierto (los que hacen daño), de menor a mayor.
const HIT_GRADES: Array = [
	SkillRoller.RollResult.SUCCESS,
	SkillRoller.RollResult.SPECIAL,
	SkillRoller.RollResult.CRITICAL,
]

## IA-0c — Traza de validación: antes de cada tirada de ataque imprime la estimación
## de esa misma acción (acierto, daño si acierta, daño esperado). Solo lectura: no
## cambia el combate. Cerrada la Tanda 2 queda a false.
const DEBUG_ESTIMATES: bool = false

## Buffs activos por entidad
## Estructura: { entity_id: [{ buff_type, expires_on, turns_left, uses_left }, ...] }
## expires_on: "turn" (expira inicio turno jugador) | "use" (expira al activarse)
var _active_buffs: Dictionary = {}

## Módulo de defensa (absorción stamina)
var _defense_module: DefenseModule = null

## Último atacante que ha hecho daño a cada combatiente: { target_id: attacker_id }.
## Lo consume la IA a través de get_last_attacker() (spec 5.3, 7 y 8).
var _last_attacker: Dictionary = {}

## Módulo de huida (escape determinista)
var _escape_module: EscapeModule = null

## IA-0c — Enemigos que han huido en este combate (efecto FLEE): { enemy_id: true }.
## Combat solo MARCA; quien retira de participants/turn_order es GameLoop al oír
## EventBus.enemy_fled. Se vacía al empezar y al acabar cada combate.
var _fled: Dictionary = {}

## IA-0c — Avisos ya impresos en este combate: { clave: true }. Evita repetir la misma
## línea en cada consulta de candidatas.
var _noted: Dictionary = {}

## Nodo padre para damage numbers (configurado externamente)
@export var damage_numbers_parent: Control

# ============================================
# REFERENCIAS A SISTEMAS
# ============================================

@onready var skill_roller: SkillRoller = preload("res://core/combat/skill_roller.gd").new()
#@onready var attribute_resolver: AttributeResolver = preload("res://core/characters/attribute_resolver.gd").new()

# ============================================
# INICIALIZACIÓN
# ============================================

func _ready():
	# Instanciar módulos
	_defense_module = DefenseModule.new()
	_escape_module = EscapeModule.new()
	
	# Bridge señales de módulos → EventBus
	_defense_module.defense_activated.connect(func(): 
		EventBus.emit_signal("defense_activated", PLAYER_ID)
		var anim = _get_animation_controller(PLAYER_ID)
		if anim:
			anim.play_defend()
			anim.start_defend_effect()
	)
	_defense_module.defense_expired.connect(func(): 
		EventBus.emit_signal("defense_expired", PLAYER_ID)
		var anim = _get_animation_controller(PLAYER_ID)
		if anim:
			anim.stop_defend_effect()
	)
	_defense_module.damage_absorbed.connect(func(st, hp, _ov): EventBus.emit_signal("damage_absorbed", PLAYER_ID, st, hp))
	_escape_module.escape_attempted.connect(func(thr): EventBus.emit_signal("escape_attempted", PLAYER_ID, thr))
	_escape_module.escape_success.connect(func(): EventBus.emit_signal("escape_succeeded", PLAYER_ID))
	_escape_module.escape_failed.connect(func(cur, req): EventBus.emit_signal("escape_failed", PLAYER_ID, cur, req))
	
	# Conectar a eventos de GameLoop
	if EventBus:
		EventBus.execute_combat_action.connect(_on_execute_combat_action)
		EventBus.player_turn_started.connect(_on_player_turn_started)
		EventBus.character_died.connect(_on_character_death)
		EventBus.defend_requested.connect(_on_defend_requested)
		EventBus.flee_requested.connect(_on_flee_requested)
		EventBus.buff_applied.connect(_on_buff_applied_vfx)
		EventBus.buff_expired.connect(_on_buff_expired_vfx)
		EventBus.enemy_turn_started.connect(_on_enemy_turn_started)
		EventBus.companion_turn_started.connect(_on_companion_turn_started)
		EventBus.combat_ended.connect(_on_combat_ended)
		EventBus.combat_started.connect(_on_combat_started)
	else:
		push_error("[CombatSystem] EventBus autoload not found!")
	
	# Conectar a eventos de SkillSystem
	if Skills:
		Skills.skill_used.connect(_on_skill_used)
		Skills.skill_failed.connect(_on_skill_failed)
	else:
		push_error("[CombatSystem] SkillSystem (Skills) autoload not found!")
	
	print("[CombatSystem] Initialized (Refactored)")


func _process(_delta):
	pass  # Buffs gestionados por turnos, no por tiempo


# ============================================
# CALLBACKS DE GAMELOOP
# ============================================

## Callback: GameLoop ordena ejecutar una acción de combate
## Contador creciente de peticiones de acción (único por sesión).
var _request_counter: int = 0

## request_id de la acción que se está ejecutando (-1 = ninguna).
var _current_request_id: int = -1


## Los productores (jugador, enemigos, Mira) piden aquí el id de cada petición.
func next_request_id() -> int:
	_request_counter += 1
	return _request_counter


## Al acabar el combate no puede quedar estado que pase al siguiente.
func _on_combat_ended(_result: String) -> void:
	_active_buffs.clear()
	_last_attacker.clear()
	_pending_skill_context.clear()
	_current_request_id = -1
	_fled.clear()
	_noted.clear()
	if _defense_module:
		_defense_module.reset()
	if _escape_module:
		_escape_module.reset()


func _on_execute_combat_action(action_data: Dictionary) -> void:
	_current_request_id = int(action_data.get("request_id", -1))
	var actor: String = action_data.get("actor", "")
	var skill_id: String = action_data.get("skill_id", "")
	var target: String = action_data.get("target", "")

	# Skills SELF (dodge) no necesitan target enemigo
	var skill_def: SkillDefinition = Skills.get_skill_definition(skill_id)
	var is_self_target: bool = skill_def and skill_def.target_type == "SELF"

	# --- STAGGERED: el actor pierde su acción ---
	if has_buff(actor, "staggered"):
		consume_buff(actor, "staggered")
		print("[CombatSystem] 😵 %s is staggered — action cancelled" % actor)
		EventBus.emit_signal("character_staggered", actor)
		EventBus.emit_signal("combat_action_completed", {
			"request_id": _current_request_id,
			"success": false,
			"staggered": true,
			"actor": actor
		})
		if actor == PLAYER_ID:
			EventBus.emit_signal("player_action_completed", {
				"success": false,
				"staggered": true,
				"actor": actor
			})
		return

	# --- DISARMED: bloquea skills con tags de arma ---
	if _blocked_by_disarm(actor, skill_def):
		print("[CombatSystem] 🚫 %s is disarmed — cannot use %s" % [actor, skill_id])
		EventBus.emit_signal("character_disarmed", actor, skill_id)
		EventBus.emit_signal("combat_action_failed", actor, "DISARMED", _current_request_id)
		EventBus.emit_signal("combat_action_completed", {
			"request_id": _current_request_id,
			"success": false,
			"disarmed": true,
			"actor": actor
		})
		if actor == PLAYER_ID:
			EventBus.emit_signal("player_action_completed", {
				"success": false,
				"disarmed": true,
				"actor": actor
			})
		return
	
	if target.is_empty() and not is_self_target:
		push_error("[CombatSystem] No target specified in action_data for skill: %s" % skill_id)
		EventBus.emit_signal("combat_action_failed", actor, "NO_TARGET", _current_request_id)
		return

	# IA-0c — INVALID_TARGET (STALE): el objetivo ya no es legal (muerto, huido o fuera del
	# combate). Se valida ANTES de cobrar coste y cooldown. Un actor que no es el jugador
	# cierra su turno sin daño con el mismo patrón que DISARMED (la IA aún no gestiona
	# fallos, IA-1); el jugador recibe solo el fallo y GameLoop le devuelve la selección.
	if not is_self_target and not _is_valid_target(target):
		print("[CombatSystem] ⛔ %s → %s: objetivo no válido (INVALID_TARGET)" % [actor, target])
		EventBus.emit_signal("combat_action_failed", actor, "INVALID_TARGET", _current_request_id)
		if actor != PLAYER_ID:
			EventBus.emit_signal("combat_action_completed", {
				"request_id": _current_request_id,
				"success": false,
				"skipped": true,
				"actor": actor
			})
		return
	
	print("[CombatSystem] Executing action: %s uses %s on %s" % [actor, skill_id, target if not is_self_target else "SELF"])
	
	_pending_skill_context = {
		"actor": actor,
		"skill_id": skill_id,
		"target": target
	}
	
	var success = Skills.request_use(actor, skill_id)
	
	if not success:
		# El fallo ya lo ha emitido Skills.skill_failed → _on_skill_failed (con su código de motivo).
		_pending_skill_context.clear()

## Callback: Inicio del turno del jugador
func _on_player_turn_started() -> void:
	print("[CombatSystem] Player turn started - processing buffs and modules")

	# 1. Ticks de recursos (bleeding, regen, drain)
	_process_resource_ticks(PLAYER_ID)

	# 2. Expirar buffs de tipo "turn" del jugador
	_expire_turn_buffs(PLAYER_ID)

	# 3. Expirar defensa si estaba activa
	_defense_module.on_player_turn_start()

	# 4. Resolver escape pendiente
	if _escape_module.is_pending():
		var threshold = _escape_module.get_current_threshold()
		var success = _escape_module.resolve_escape(PLAYER_ID)
		if success:
			Resources.add_resource(PLAYER_ID, "stamina", -threshold)
			print("[CombatSystem] 🏃 Escape succeeded — consumed %d stamina" % threshold)
			GameLoop.end_combat("escaped")

## Callback: Jugador solicita defender
func _on_defend_requested(entity_id: String) -> void:
	if entity_id != PLAYER_ID:
		return
	
	var activated = _defense_module.activate_defense()
	if activated:
		print("[CombatSystem] 🛡️ Player defending this turn")
	
	# Ceder turno a los enemigos a través de GameLoop
	GameLoop.end_player_turn_from_special_action()


## Callback: Jugador solicita huir
func _on_flee_requested(entity_id: String) -> void:
	if entity_id != PLAYER_ID:
		return
	
	var enemy_count = GameLoop.get_active_enemies().size()
	
	# Activar escape pendiente (se resolverá al inicio del siguiente turno del jugador)
	_escape_module.attempt_escape(enemy_count)
	
	# Ceder turno a los enemigos — ellos atacan antes de que se evalúe el escape
	GameLoop.end_player_turn_from_special_action()

## Callback: inicio de turno de un enemigo
func _on_enemy_turn_started(enemy_id: String) -> void:
	_process_resource_ticks(enemy_id)   # 1. aplicar efectos con turns_left actual
	_expire_turn_buffs(enemy_id)        # 2. decrementar y eliminar si llegan a 0

## Callback: inicio de turno de un companion
func _on_companion_turn_started(companion_id: String) -> void:
	_process_resource_ticks(companion_id)  # 1. efectos primero
	_expire_turn_buffs(companion_id)       # 2. decrementar después

# ============================================
# CALLBACKS DE SKILLSYSTEM
# ============================================

## Callback: SkillSystem ejecutó la habilidad exitosamente
func _on_skill_used(entity_id: String, skill_id: String):
	var target_id = _pending_skill_context.get("target", "")
	
	# Dodge es self-target: no necesita target enemigo
	var skill_def = Skills.get_skill_definition(skill_id)
	if not skill_def:
		push_error("[CombatSystem] Skill definition not found: %s" % skill_id)
		_pending_skill_context.clear()
		return
	
	# --- DODGE: solo aplica buffs, no hace tirada de ataque ---
	if skill_id == "skill.combat.dodge":
		_process_dodge(entity_id, skill_def)
		_pending_skill_context.clear()
		EventBus.emit_signal("combat_action_completed", {"success": true, "action": "dodge", "actor": entity_id, "request_id": _current_request_id})
		EventBus.emit_signal("player_action_completed", {"success": true, "action": "dodge", "actor": entity_id})
		return
	
	# --- SKILLS SELF DE DATOS (IA-0c): sin tirada; efectos BUFF, RESTORE y FLEE ---
	# Solo si la skill viene de una acción de combate en curso (contexto pendiente de esta
	# misma skill): una skill SELF fuera de combate sigue el camino de siempre.
	if skill_def.target_type == "SELF" and _pending_skill_context.get("skill_id", "") == skill_id:
		_resolve_self_skill(entity_id, skill_def)
		return

	# --- HABILIDADES DE ATAQUE: requieren target ---
	if target_id.is_empty():
		push_error("[CombatSystem] No target in pending context for skill: %s" % skill_id)
		_pending_skill_context.clear()
		return
	
	print("[CombatSystem] Resolving skill: %s → %s" % [entity_id, target_id])
	
	# IA-0c — los parámetros de la tirada salen de _get_roll_params(), la MISMA función
	# que usan las estimaciones. Aquí solo se consumen los buffs y se imprime.
	var roll_params: Dictionary = _get_roll_params(entity_id, skill_id)
	var skill_value: int = roll_params.skill_value
	var is_guaranteed: bool = roll_params.guaranteed
	var crit_bonus: int = roll_params.crit_bonus

	if DEBUG_ESTIMATES:
		_print_estimate(entity_id, target_id, skill_id)

	# precision_up: bonus temporal a la tirada (ya sumado en roll_params.skill_value)
	if roll_params.has_precision:
		consume_buff(entity_id, "precision_up")
		print("[CombatSystem] 🎯 precision_up: skill_value → %d" % skill_value)

	# critical_bonus: amplía el umbral de crítico (no se consume, dura X turnos).
	# El umbral lo calcula SkillRoller (skill_value / 20 + bonus); no se duplica aquí.
	if roll_params.has_crit_bonus:
		print("[CombatSystem] 🎯 critical_bonus activo: umbral crítico → %d" % SkillRoller.get_critical_threshold(skill_value, crit_bonus))

	var roll_result = SkillRoller.roll_skill(skill_value, false, crit_bonus)
	
	if is_guaranteed:
		consume_buff(entity_id, "guaranteed_hit")
		roll_result.success = true
		roll_result.result = SkillRoller.RollResult.SUCCESS
		roll_result.result_name = "SUCCESS (guaranteed)"
		print("[CombatSystem] ✨ Guaranteed hit activated!")
	
	print("[CombatSystem] %s rolled %d vs %d%% → %s" % [
		skill_id, roll_result.roll, roll_result.skill_value, roll_result.result_name
	])
	
	var result: Dictionary = {}
	
	if roll_result.success:
		_play_skill_animation(entity_id, skill_id)
		
		var is_critical = (roll_result.result == SkillRoller.RollResult.CRITICAL)
		# Spike 2: grado SPECIAL — cuenta como éxito (ver SkillRoller._is_success())
		# pero con su propio multiplicador de daño, menor que el de crítico.
		var is_special = (roll_result.result == SkillRoller.RollResult.SPECIAL)
		result = _process_skill_effects(entity_id, skill_def, is_critical, target_id, is_special)
		result["roll_result"] = roll_result
		
		if result.get("success", false) and result.get("damage", 0) > 0:
			var damage = result.get("damage", 0.0)
			var is_crit = result.get("critical", false)
			_apply_damage_by_target_type(entity_id, target_id, skill_def, damage, is_crit)
			
		if not target_id.is_empty():
			var target_hp: float = Resources.get_resource_amount(target_id, "health")
			if target_hp <= 0:
				result["buffs_applied"] = []
		
		if result.has("buffs_applied") and not result.buffs_applied.is_empty():
			for buff in result.buffs_applied:
				var recipient: String = buff.get("recipient", entity_id)
				apply_buff(recipient, buff)
			
	else:
		result = {
			"success": false,
			"damage": 0,
			"roll_result": roll_result,
			"fumble": (roll_result.result == SkillRoller.RollResult.FUMBLE)
		}
		_spawn_damage_number(target_id, 0, false, true)
		
		if result.fumble:
			print("[CombatSystem] ⚠️ FUMBLE!")

	# Notificar progresión a todos los aliados (jugador + companions)
	var party: Node = get_node_or_null("/root/Party")
	var is_ally: bool = entity_id == PLAYER_ID or (party != null and party.is_in_party(entity_id))
	if is_ally:
		SkillProgression.notify_skill_outcome(
			entity_id,
			skill_id,
			SkillRoller.to_progression_outcome(roll_result.result)
		)

	result["actor"] = entity_id
	_pending_skill_context.clear()
	
	result["request_id"] = _current_request_id
	EventBus.emit_signal("combat_action_completed", result)
	EventBus.emit_signal("combat_action_executed", entity_id, skill_id, target_id, result)
	
	if entity_id == PLAYER_ID:
		EventBus.emit_signal("player_action_completed", result)
	
	if result.get("success", false):
		var crit_text = " (CRITICAL!)" if result.get("critical", false) else ""
		var special_text = " (SPECIAL!)" if result.get("special", false) else ""
		print("[CombatSystem] ✅ %s dealt %.1f damage%s%s" % [skill_id, result.get("damage", 0), crit_text, special_text])
	else:
		var fumble_text = " (FUMBLE!)" if result.get("fumble", false) else ""
		print("[CombatSystem] ❌ Skill missed%s" % fumble_text)

## Callback: SkillSystem falló al activar la habilidad
func _on_skill_failed(entity_id: String, skill_id: String, reason: String):
	print("[CombatSystem] Skill activation failed: %s (reason: %s)" % [skill_id, reason])
	# skill_failed también salta con las skills de exploración: sin combate no hay petición que responder.
	if not GameLoop.is_in_combat():
		return
	
	EventBus.emit_signal("combat_action_failed", entity_id, reason, _current_request_id)


# ============================================
# RESOLUCIÓN DE COMBATE
# ============================================

## Resuelve el resultado de una habilidad de combate
## Calcula daño usando AttributeResolver y procesa efectos
##
## NOTA: esta función no está en el camino real de _on_skill_used() (que
## calcula el daño llamando a _process_skill_effects() directamente) — no se
## ha tocado en Spike 2 por eso; is_special no se propaga aquí y usará el
## default (false) de _process_skill_effects() si algún día se conecta.
func _resolve_combat_skill(
	entity_id: String,
	skill_id: String,
	target_id: String,
	is_critical: bool = false
) -> Dictionary:
	var skill_def = Skills.get_skill_definition(skill_id)
	if not skill_def:
		return {"success": false, "damage": 0}
	
	# FASE C.2: Calcular daño con AttributeResolver
	var effects_result = _process_skill_effects(
		entity_id,
		skill_def,
		is_critical, 
		target_id
	)
	
	return {
		"success": true,
		"damage": effects_result.get("damage", 0.0),
		"critical": is_critical,
		"buffs_applied": effects_result.get("buffs_applied", [])
	}


## Procesa efectos de una habilidad (daño + buffs)
## Procesa efectos de una habilidad (daño + buffs)
func _process_skill_effects(
	entity_id: String,
	skill_def: SkillDefinition,
	is_critical: bool,
	target_id: String = "",    # ← NUEVO: necesario para buffs con target="target"
	is_special: bool = false   # ← Spike 2: grado SPECIAL, multiplicador propio menor que crítico
) -> Dictionary:
	var character_state = Characters.get_character_state(entity_id)
	if not character_state:
		return {"damage": 0, "buffs_applied": []}

	var damage: float = 0.0
	var buffs_applied: Array = []

	for effect in skill_def.effects:
		match effect.get("type", "").to_upper():
			"DAMAGE":
				# IA-0c — fórmula única: _effect_damage() (la usan también las estimaciones)
				var parts: Dictionary = _effect_damage(entity_id, effect, _grade_from_flags(is_critical, is_special))
				damage = parts.damage

				print("[CombatSystem] Damage calculated: %.1f (base: %.1f, modifier: %.2f, crit: %s, special: %s)" % [
					damage, parts.base, parts.modifier, is_critical, is_special
				])

			"BUFF":
				# Determinar a quién se aplica el buff
				var buff_target_field: String = effect.get("target", "self")
				var buff_recipient: String = entity_id
				if buff_target_field == "target" and not target_id.is_empty():
					buff_recipient = target_id

				# IA-0c — _build_buff() es el ÚNICO sitio que construye un buff desde un efecto
				# (lo usan también las skills SELF); copia resource_id si el efecto lo declara.
				var buff_data: Dictionary = _build_buff(effect, buff_recipient)
				buffs_applied.append(buff_data)
				print("[CombatSystem] Buff queued: %s → %s (%d turns)" % [
					buff_data.buff_type, buff_recipient, buff_data.turns_left
				])

			_:
				push_warning("[CombatSystem] Unknown effect type: %s" % effect.get("type"))

	return {
		"success": true,
		"damage": damage,
		"critical": is_critical,
		"special": is_special,
		"buffs_applied": buffs_applied
	}

## Enruta el daño a uno o varios targets según target_type de la habilidad.
##
## - SINGLE_ENEMY → aplica daño al target seleccionado (comportamiento original)
## - MULTI_ENEMY  → aplica daño a max_targets enemigos (definido en el effect del .tres)
## - AREA         → aplica daño a TODOS los enemigos vivos
##
## El parámetro target_id se usa como target principal para SINGLE_ENEMY
## y como primer target para MULTI_ENEMY si la lista está ordenada.
func _apply_damage_by_target_type(
	attacker_id: String,
	target_id: String,
	skill_def: SkillDefinition,
	damage: float,
	is_critical: bool
) -> void:
	# IA-0c — el conjunto de objetivos alcanzados lo decide _get_hit_targets(), el mismo
	# que usan las estimaciones.
	var hit: Dictionary = _get_hit_targets(attacker_id, target_id, skill_def)
	var hit_targets: Array = hit.targets

	match skill_def.target_type:
		"SINGLE_ENEMY":
			pass

		"AREA":
			print("[CombatSystem] 💥 AREA attack hits %d enemies" % hit_targets.size())

		"MULTI_ENEMY":
			print("[CombatSystem] ⚔️ MULTI_ENEMY attack hits %d/%d enemies" % [hit_targets.size(), hit.pool_size])

		_:
			# Fallback seguro: comportamiento SINGLE
			push_warning("[CombatSystem] Unknown target_type '%s' for skill, falling back to SINGLE" % skill_def.target_type)

	for hit_id in hit_targets:
		_apply_damage(hit_id, damage, is_critical, attacker_id)


## Aplica daño a una entidad
## attacker_id: quién está atacando (necesario para evasión)
func _apply_damage(target_id: String, damage: float, is_critical: bool = false, attacker_id: String = "") -> void:
	# No aplicar daño a entidades ya a 0 HP (evita spam de _incapacitate_player)
	if Resources.get_resource_amount(target_id, "health") <= 0:
		print("[CombatSystem] %s already at 0 HP — damage ignored" % target_id)
		return	
	# --- PRIORIDAD 1: EVASIÓN (solo jugador, solo un uso) ---
	if target_id == PLAYER_ID and has_buff(PLAYER_ID, "evasion"):
		consume_buff(PLAYER_ID, "evasion")
		EventBus.emit_signal("evasion_triggered", PLAYER_ID)
		_spawn_damage_number(PLAYER_ID, 0, false, true)
		# Detener efecto visual de evasión
		var anim = _get_animation_controller(PLAYER_ID)
		if anim:
			anim.stop_evasion_effect()
		print("[CombatSystem] 🤸 Attack EVADED! (attacker: %s)" % attacker_id)
		return
	
	# --- ARMADURA Y BUFFS NUMÉRICOS ---
	# IA-0c — fórmula única: _mitigate_damage() (la usan también las estimaciones).
	# Aquí se imprime cada paso (log_steps = true); las estimaciones no imprimen.
	var damage_after_armor: float = _mitigate_damage(attacker_id, target_id, damage, true)["damage"]
	
	# --- PRIORIDAD 2: DEFENSA (solo jugador, todos los ataques del turno) ---
	var final_damage := int(damage_after_armor)
	if target_id == PLAYER_ID and _defense_module.is_active():
		final_damage = _defense_module.process_incoming_damage(int(damage_after_armor), PLAYER_ID)
		# ResourceSystem ya consumió stamina dentro del módulo
		# Solo aplicamos el HP residual tras absorción de stamina
		Resources.add_resource(target_id, "health", -final_damage)
	else:
		# --- PRIORIDAD 3: DAÑO NORMAL ---
		Resources.add_resource(target_id, "health", -damage_after_armor)
	
	# Animación de hit
	_play_hit_animation(target_id)
	
	var current_hp = Resources.get_resource_amount(target_id, "health")
	var applied_damage: float = float(final_damage) if (target_id == PLAYER_ID and _defense_module.is_active()) else damage_after_armor
	
	print("[CombatSystem] %s took %.1f damage (HP: %.1f)" % [target_id, applied_damage, current_hp])
	
	_spawn_damage_number(target_id, applied_damage, is_critical, false)
	
	if not attacker_id.is_empty():
		_last_attacker[target_id] = attacker_id
	EventBus.emit_signal("character_damaged", target_id, applied_damage, current_hp)
	
	if current_hp <= 0:
		EventBus.emit_signal("character_died", target_id)

# ============================================
# FÓRMULA DE DAÑO Y ESTIMACIONES (IA-0c)
# ============================================
# Una sola fórmula para el daño y para la probabilidad de acierto: el camino real
# (_on_skill_used, _process_skill_effects, _apply_damage) y las estimaciones llaman a
# las MISMAS funciones de este bloque. Las funciones puras (_get_roll_params,
# _grade_multiplier, _effect_damage, _skill_raw_damage, _mitigate_damage con
# log_steps=false, _get_hit_targets, get_grade_probabilities, get_success_chance y
# estimate_damage) no consumen buffs, no emiten señales y no tocan el RNG.

## Parámetros de la tirada de un actor. PURO: no consume buffs (los consume quien
## tira de verdad). skill_value NO está recortado a 0..100: roll_skill() lo recorta.
func _get_roll_params(entity_id: String, skill_id: String) -> Dictionary:
	var skill_value: int = Characters.get_skill_value(entity_id, skill_id)

	var has_precision: bool = has_buff(entity_id, "precision_up")
	if has_precision:
		skill_value += int(_get_buff_value(entity_id, "precision_up"))

	var has_crit_bonus: bool = has_buff(entity_id, "critical_bonus")
	var crit_bonus: int = 0
	if has_crit_bonus:
		crit_bonus = int(_get_buff_value(entity_id, "critical_bonus"))

	return {
		"skill_value": skill_value,
		"has_precision": has_precision,
		"crit_bonus": crit_bonus,
		"has_crit_bonus": has_crit_bonus,
		"guaranteed": has_buff(entity_id, "guaranteed_hit"),
	}


## Probabilidad de cada grado para `actor_id` usando `skill_id`, con sus buffs actuales.
## guaranteed_hit fuerza SUCCESS después de la tirada (CombatSystem._on_skill_used), así
## que con ese buff el único grado posible es SUCCESS.
func get_grade_probabilities(actor_id: String, skill_id: String) -> Dictionary:
	var params: Dictionary = _get_roll_params(actor_id, skill_id)
	if params.guaranteed:
		return {
			SkillRoller.RollResult.FUMBLE: 0.0,
			SkillRoller.RollResult.FAILURE: 0.0,
			SkillRoller.RollResult.SUCCESS: 1.0,
			SkillRoller.RollResult.SPECIAL: 0.0,
			SkillRoller.RollResult.CRITICAL: 0.0,
		}
	return SkillRoller.get_grade_probabilities(params.skill_value, params.crit_bonus)


## Probabilidad de acierto de `actor_id` usando `skill_id` (0..1).
func get_success_chance(actor_id: String, skill_id: String) -> float:
	var probabilities: Dictionary = get_grade_probabilities(actor_id, skill_id)
	var chance: float = 0.0
	for grade in HIT_GRADES:
		chance += float(probabilities.get(grade, 0.0))
	return chance


## Grado de la tirada a partir de las banderas que usa _process_skill_effects().
func _grade_from_flags(is_critical: bool, is_special: bool) -> int:
	if is_critical:
		return SkillRoller.RollResult.CRITICAL
	if is_special:
		return SkillRoller.RollResult.SPECIAL
	return SkillRoller.RollResult.SUCCESS


## Multiplicador de daño de un grado para un efecto DAMAGE (única fuente).
func _grade_multiplier(effect: Dictionary, grade: int) -> float:
	match grade:
		SkillRoller.RollResult.CRITICAL:
			return float(effect.get("critical_multiplier", 2.0))
		SkillRoller.RollResult.SPECIAL:
			# Spike 2: bonus del grado SPECIAL, menor que el crítico.
			return float(effect.get("special_multiplier", 1.2))
	return 1.0


## Daño bruto de UN efecto DAMAGE (antes de armadura y buffs) para un grado.
## Devuelve { damage, base, modifier } (base y modifier solo para el log).
func _effect_damage(entity_id: String, effect: Dictionary, grade: int) -> Dictionary:
	var base_damage_attr: String = effect.get("base_damage_attribute", "base_damage")
	var damage_modifier: float = effect.get("value", 1.0)

	var resolved_damage: float = AttributeResolver.resolve(entity_id, base_damage_attr, {})
	var damage: float = resolved_damage * damage_modifier
	damage *= _grade_multiplier(effect, grade)

	return {"damage": damage, "base": resolved_damage, "modifier": damage_modifier}


## Daño bruto de una skill para un grado: el del último efecto DAMAGE (igual que
## _process_skill_effects, donde cada DAMAGE sobrescribe al anterior).
func _skill_raw_damage(entity_id: String, skill_def: SkillDefinition, grade: int) -> float:
	var damage: float = 0.0
	for effect in skill_def.effects:
		if effect.get("type", "").to_upper() == "DAMAGE":
			damage = _effect_damage(entity_id, effect, grade)["damage"]
	return damage


## Daño tras armadura y buffs numéricos. Sin efectos laterales salvo el log opcional.
## Orden: armadura → weakened (atacante) → damage_bonus (atacante) → vulnerable
## (defensor) → damage_reduction (defensor) → mínimo 1.
## extra_reduction_pct (IA-0c): reducción HIPOTÉTICA en % que se apila sobre la que ya tenga
## el defensor; solo la usan las estimaciones de defensa (0 = comportamiento de siempre).
## Devuelve { damage, armor }.
func _mitigate_damage(attacker_id: String, target_id: String, damage: float, log_steps: bool = false, extra_reduction_pct: float = 0.0) -> Dictionary:
	# Reducción plana: damage_after_armor = max(1, damage - armor_rating).
	# El mínimo 1 garantiza que ningún ataque haga 0 daño.
	var armor: float = AttributeResolver.resolve(target_id, "armor_rating", {})
	var result: float = maxf(1.0, damage - armor)

	if not attacker_id.is_empty():
		# weakened: el atacante hace menos daño
		if has_buff(attacker_id, "weakened"):
			var weakened_val: float = _get_buff_value(attacker_id, "weakened")
			result *= maxf(0.0, 1.0 - weakened_val / 100.0)
			if log_steps:
				print("[CombatSystem] 🔻 weakened: -%.0f%% → %.1f dmg" % [weakened_val, result])

		# damage_bonus: el atacante hace más daño
		if has_buff(attacker_id, "damage_bonus"):
			var bonus_val: float = _get_buff_value(attacker_id, "damage_bonus")
			result *= (1.0 + bonus_val / 100.0)
			if log_steps:
				print("[CombatSystem] 🔺 damage_bonus: +%.0f%% → %.1f dmg" % [bonus_val, result])

	# vulnerable: el defensor recibe más daño
	if has_buff(target_id, "vulnerable"):
		var vulnerable_val: float = _get_buff_value(target_id, "vulnerable")
		result *= (1.0 + vulnerable_val / 100.0)
		if log_steps:
			print("[CombatSystem] 🔺 vulnerable: +%.0f%% → %.1f dmg" % [vulnerable_val, result])

	# damage_reduction: el defensor recibe menos daño (se aplica al final)
	if has_buff(target_id, "damage_reduction"):
		var reduction_val: float = _get_buff_value(target_id, "damage_reduction")
		result *= maxf(0.0, 1.0 - reduction_val / 100.0)
		if log_steps:
			print("[CombatSystem] 🔻 damage_reduction: -%.0f%% → %.1f dmg" % [reduction_val, result])

	if extra_reduction_pct > 0.0:
		result *= maxf(0.0, 1.0 - extra_reduction_pct / 100.0)

	result = maxf(1.0, result)
	if log_steps and armor > 0.0:
		print("[CombatSystem] 🛡️ %s armor_rating=%.1f: %.1f → %.1f dmg" % [
			target_id, armor, damage, result
		])

	return {"damage": result, "armor": armor}


## Objetivos que alcanza una skill ofensiva cuyo objetivo principal es `target_id`.
## Misma regla que aplica el camino real. Devuelve { targets, pool_size }:
## pool_size es el total de candidatos del que sale la selección (solo para el log).
## AREA y MULTI_ENEMY golpean al bando contrario a attacker_id (IA-0d, ver _get_hit_pool).
## Hoy solo las usan el jugador y Mira; el test ia0d cubre el caso de un enemigo.
## IA-0d — Pool de objetivos de una skill de área: el bando contrario a `attacker_id`.
## Un aliado conserva la lista de GameLoop (comportamiento previo); un enemigo golpea al
## jugador y a los compañeros activos (_get_opponents ya filtra objetivos legales).
func _get_hit_pool(attacker_id: String) -> Array[String]:
	if _is_ally(attacker_id):
		return GameLoop.get_active_enemies()
	return _get_opponents(attacker_id)


func _get_hit_targets(attacker_id: String, target_id: String, skill_def: SkillDefinition) -> Dictionary:
	match skill_def.target_type:
		"AREA":
			# Golpea a todos los enemigos vivos
			var all_enemies: Array[String] = _get_hit_pool(attacker_id)
			return {"targets": all_enemies, "pool_size": all_enemies.size()}

		"MULTI_ENEMY":
			# Golpea hasta max_targets enemigos — se lee del primer effect con type DAMAGE
			var max_targets = 2  # fallback si no está definido en el .tres
			for effect in skill_def.effects:
				if effect.get("type", "").to_lower() == "damage":
					max_targets = effect.get("max_targets", max_targets)
					break

			var pool: Array[String] = _get_hit_pool(attacker_id)
			# Priorizar el target seleccionado: colocarlo primero en la lista
			var ordered: Array[String] = []
			if target_id in pool:
				ordered.append(target_id)
			for enemy_id in pool:
				if enemy_id != target_id:
					ordered.append(enemy_id)

			var targets_hit: int = int(min(max_targets, ordered.size()))
			return {"targets": ordered.slice(0, targets_hit), "pool_size": ordered.size()}

	# SINGLE_ENEMY y cualquier otro valor: solo el objetivo principal
	return {"targets": [target_id], "pool_size": 1}


## Estimación de `attacker_id` usando `skill_id` con `target_id` como objetivo principal.
## SOLO LECTURA: no consume buffs, no emite señales, no toca el RNG.
##
## Valor esperado COMPLETO (decisión 3-A): para cada grado con acierto (SUCCESS, SPECIAL,
## CRITICAL) se calcula el daño bruto con su multiplicador, se le aplica la armadura y los
## buffs numéricos (la armadura no es lineal, por eso grado a grado) y se pondera por la
## probabilidad de ese grado. Así expected_damage coincide con la media real.
##
## Devuelve:
##   success_chance   probabilidad de acierto (0..1)
##   damage_if_hit    daño medio condicionado al acierto (suma de todos los objetivos)
##   expected_damage  success_chance × damage_if_hit (ya ponderado; suma de todos)
##   targets          objetivos alcanzados (principal primero en MULTI_ENEMY)
##   max_hit/kill_possible   del objetivo principal (mejor grado posible vs PV actuales)
##   per_target       { id: { expected_damage, max_hit, kill_possible } }
##
## NO contempla (limitaciones conocidas, IA-1): evasión y DefenseModule del jugador
## (estado de un solo uso o de absorción por estamina, solo para PLAYER_ID); un objetivo
## con la evasión activa recibirá en realidad 0.
func estimate_damage(attacker_id: String, target_id: String, skill_id: String) -> Dictionary:
	var estimate: Dictionary = {
		"success_chance": 0.0,
		"damage_if_hit": 0.0,
		"expected_damage": 0.0,
		"max_hit": 0.0,
		"kill_possible": false,
		"targets": [],
		"per_target": {},
	}

	var skill_def: SkillDefinition = Skills.get_skill_definition(skill_id)
	if skill_def == null or skill_def.target_type == "SELF":
		return estimate

	var probabilities: Dictionary = get_grade_probabilities(attacker_id, skill_id)
	var chance: float = 0.0
	for grade in HIT_GRADES:
		chance += float(probabilities.get(grade, 0.0))
	estimate.success_chance = chance

	var hit: Dictionary = _get_hit_targets(attacker_id, target_id, skill_def)
	estimate.targets = hit.targets

	var total_expected: float = 0.0
	for hit_id in hit.targets:
		var hp: float = Resources.get_resource_amount(hit_id, "health")
		if hp <= 0.0:
			continue   # _apply_damage ignora a quien ya está a 0 PV

		var on_target: Dictionary = _expected_on_target(attacker_id, hit_id, skill_def, probabilities)
		var expected: float = on_target.expected
		var max_hit: float = on_target.max_hit

		total_expected += expected
		estimate.per_target[hit_id] = {
			"expected_damage": expected,
			"max_hit": max_hit,
			"kill_possible": max_hit >= hp,
		}
		if hit_id == target_id:
			estimate.max_hit = max_hit
			estimate.kill_possible = max_hit >= hp

	estimate.expected_damage = total_expected
	if chance > 0.0:
		estimate.damage_if_hit = total_expected / chance
	return estimate


## Traza de validación (DEBUG_ESTIMATES): imprime la estimación de la acción que se va a tirar.
func _print_estimate(attacker_id: String, target_id: String, skill_id: String) -> void:
	var estimate: Dictionary = estimate_damage(attacker_id, target_id, skill_id)
	print("[CombatSystem] 📐 estimate %s → %s (%s): acierto %.3f · daño si acierta %.2f · esperado %.2f · mata: %s · objetivos %s" % [
		attacker_id, target_id, skill_id,
		estimate.success_chance, estimate.damage_if_hit, estimate.expected_damage,
		estimate.kill_possible, str(estimate.targets)
	])


## Daño esperado de `attacker_id` contra UN objetivo con la skill dada (IA-0c).
## Valor esperado COMPLETO grado a grado (SUCCESS, SPECIAL, CRITICAL): la armadura no es
## lineal, así que el daño de cada grado se mitiga por separado y se pondera por su
## probabilidad. Lo usan estimate_damage() y la estimación de defensa.
## extra_reduction_pct: reducción hipotética (ver _mitigate_damage).
## Devuelve { expected, max_hit }.
func _expected_on_target(attacker_id: String, hit_id: String, skill_def: SkillDefinition, probabilities: Dictionary, extra_reduction_pct: float = 0.0) -> Dictionary:
	var expected: float = 0.0
	var max_hit: float = 0.0
	for grade in HIT_GRADES:
		var probability: float = float(probabilities.get(grade, 0.0))
		if probability <= 0.0:
			continue
		var raw: float = _skill_raw_damage(attacker_id, skill_def, grade)
		var dealt: float = 0.0
		if raw > 0.0:   # el camino real solo aplica daño si damage > 0
			dealt = _mitigate_damage(attacker_id, hit_id, raw, false, extra_reduction_pct)["damage"]
		expected += probability * dealt
		max_hit = maxf(max_hit, dealt)
	return {"expected": expected, "max_hit": max_hit}


# ============================================
# SKILLS SELF DE DATOS (IA-0c)
# ============================================
# Una skill SELF no tira dado de ataque. Sus efectos son datos:
#   BUFF     buff sobre el propio actor (misma construcción que los buffs de ataque)
#   RESTORE  recupera `value` de `resource_id` de golpe, sin pasar del máximo
#   FLEE     el actor abandona el combate (solo enemigos; marca FLED y emite enemy_fled)
# `dodge` pasa por _build_buff() (IA-0d): sus efectos declaran `expires_on: "use"`,
# y _process_dodge() solo añade la animación.

## ÚNICO constructor de buffs a partir de un efecto BUFF.
## `duration` son TURNOS DEL DUEÑO del buff (0 = se consume al primer uso). En un efecto
## DAMAGE, en cambio, `duration` es tiempo de animación en segundos.
func _build_buff(effect: Dictionary, recipient: String) -> Dictionary:
	var duration: int = effect.get("duration", 1)
	# IA-0d — un efecto puede declarar `expires_on` ("use" / "turn"); sin él se deriva de duration
	var expires_on: String = String(effect.get("expires_on", "use" if duration == 0 else "turn"))
	var by_use: bool = (expires_on == "use")
	var buff_data: Dictionary = {
		"buff_type":  effect.get("buff_type", "unknown"),
		"value":      effect.get("value", 0.0),
		"expires_on": expires_on,
		"turns_left": duration if (duration > 0 and not by_use) else 0,
		"uses_left":  1 if by_use else 0,
		"recipient":  recipient
	}
	if effect.has("resource_id"):
		buff_data["resource_id"] = effect.get("resource_id", "")
	return buff_data


## Resuelve una skill SELF de datos y cierra la acción.
func _resolve_self_skill(entity_id: String, skill_def: SkillDefinition) -> void:
	print("[CombatSystem] 🧪 SELF skill: %s uses %s" % [entity_id, skill_def.id])

	var restored: Dictionary = {}
	var fled: bool = false
	var defended: bool = false

	for effect in skill_def.effects:
		match String(effect.get("type", "")).to_upper():
			"BUFF":
				apply_buff(entity_id, _build_buff(effect, entity_id))
				if String(effect.get("buff_type", "")) in AIScales.get_value("effect_value.defense_buffs", []):
					defended = true

			"RESTORE":
				var resource_id: String = String(effect.get("resource_id", ""))
				var added: float = _apply_restore(entity_id, resource_id, float(effect.get("value", 0.0)))
				restored[resource_id] = float(restored.get(resource_id, 0.0)) + added

			"FLEE":
				if _apply_flee(entity_id):
					fled = true

			_:
				push_warning("[CombatSystem] Efecto '%s' no soportado en una skill SELF (%s)" % [effect.get("type"), skill_def.id])

	if defended:
		var anim = _get_animation_controller(entity_id)
		if anim and anim.has_method("play_defend"):
			anim.play_defend()

	_pending_skill_context.clear()
	var result: Dictionary = {
		"success": true,
		"action": "self",
		"skill_id": skill_def.id,
		"actor": entity_id,
		"request_id": _current_request_id,
		"restored": restored,
		"fled": fled,
	}
	EventBus.emit_signal("combat_action_completed", result)
	if entity_id == PLAYER_ID:
		EventBus.emit_signal("player_action_completed", result)


## Efecto RESTORE. Devuelve lo realmente añadido (nunca pasa del máximo ni resta).
func _apply_restore(entity_id: String, resource_id: String, amount: float) -> float:
	if resource_id.is_empty() or not Resources.has_resource(entity_id, resource_id):
		push_warning("[CombatSystem] RESTORE sin recurso válido ('%s') para %s" % [resource_id, entity_id])
		return 0.0
	if amount < 0.0:
		push_warning("[CombatSystem] RESTORE con valor negativo (%.1f) ignorado" % amount)
		return 0.0

	var state: ResourceState = Resources.get_resource_state(entity_id, resource_id)
	var room: float = maxf(0.0, state.max_effective - state.current)
	var to_add: float = minf(amount, room)
	if to_add > 0.0:
		Resources.add_resource(entity_id, resource_id, to_add)
	print("[CombatSystem] 💚 RESTORE: %s +%.1f %s (pedido %.1f, hueco %.1f)" % [entity_id, to_add, resource_id, amount, room])
	return to_add


## Efecto FLEE. Solo enemigos: la huida del jugador sigue siendo EscapeModule y Mira no
## tiene huida en el MVP. Combat marca FLED y emite la señal; GameLoop retira al
## combatiente al cerrar la acción en curso y reevalúa la victoria.
func _apply_flee(entity_id: String) -> bool:
	if _is_ally(entity_id):
		push_warning("[CombatSystem] FLEE solo es para enemigos: ignorado para %s" % entity_id)
		return false
	if is_fled(entity_id):
		return false
	_fled[entity_id] = true
	print("[CombatSystem] 🏃 %s huye del combate (FLED)" % entity_id)
	EventBus.emit_signal("enemy_fled", entity_id)
	return true


## IA-1a — Bando del combatiente: &"ally" (protagonista y party) o &"enemy". Envuelve _is_ally().
func get_side(entity_id: String) -> StringName:
	return CombatTags.SIDE_ALLY if _is_ally(entity_id) else CombatTags.SIDE_ENEMY


## IA-1a — Combatientes de un bando que siguen en el combate (no huidos), con los caídos (0 PV)
## incluidos: el snapshot los necesita (p. ej. `protect` con el protagonista caído). Quien
## elija objetivos filtra con `targetable`. SOLO LECTURA. Reutiliza la misma lógica de bandos
## que _get_opponents(); unificarlas queda como pendiente de limpieza.
func get_combatant_ids(side: StringName) -> Array[String]:
	var pool: Array[String] = []
	if side == CombatTags.SIDE_ALLY:
		pool.append(PLAYER_ID)
		var party: Node = get_node_or_null("/root/Party")
		if party:
			for companion_id in party.get_active_members():
				pool.append(companion_id)
	else:
		pool = GameLoop.get_active_enemies()
	var result: Array[String] = []
	for entity_id in pool:
		if not is_fled(entity_id) and Resources.has_entity(entity_id):
			result.append(entity_id)
	return result


## ¿Ha huido este combatiente en el combate en curso?
func is_fled(entity_id: String) -> bool:
	return _fled.has(entity_id)


# ============================================
# CANDIDATAS, AMENAZA Y CONDICIONES VISIBLES (IA-0c) — SOLO LECTURA
# ============================================
# Nada de este bloque consume buffs, emite señales ni toca el RNG. Nadie lo llama aún en
# producción: lo usará la IA (IA-1). Las escalas y tablas salen de data/ai/ai_scales.json.

## ¿Es aliado del protagonista (él mismo o un miembro de la party)?
func _is_ally(entity_id: String) -> bool:
	if entity_id == PLAYER_ID:
		return true
	var party: Node = get_node_or_null("/root/Party")
	return party != null and party.is_in_party(entity_id)


## ¿Es un objetivo legal? Vivo, no huido y dentro del combate. Fuera de combate
## (pruebas) no se exige estar en participants.
func _is_valid_target(target_id: String) -> bool:
	if target_id.is_empty() or is_fled(target_id):
		return false
	if not Resources.has_entity(target_id) or not Resources.has_resource(target_id, "health"):
		return false
	if Resources.get_resource_amount(target_id, "health") <= 0.0:
		return false
	if GameLoop.is_in_combat() and not GameLoop.participants.has(target_id) and not _is_ally(target_id):
		return false
	return true


## Combatientes del bando contrario a `actor_id` que son objetivos legales.
func _get_opponents(actor_id: String) -> Array[String]:
	var result: Array[String] = []
	if _is_ally(actor_id):
		for enemy_id in GameLoop.get_active_enemies():
			if _is_valid_target(enemy_id):
				result.append(enemy_id)
		return result

	var allies: Array[String] = [PLAYER_ID]
	var party: Node = get_node_or_null("/root/Party")
	if party:
		for companion_id in party.get_active_members():
			allies.append(companion_id)
	for ally_id in allies:
		if _is_valid_target(ally_id):
			result.append(ally_id)
	return result


## ¿Bloquea DISARMED esta skill? (mismo criterio para ejecutar y para listar candidatas).
func _blocked_by_disarm(actor_id: String, skill_def: SkillDefinition) -> bool:
	if skill_def == null or not has_buff(actor_id, "disarmed"):
		return false
	var weapon_tags: Array[String] = ["attack", "melee", "ranged"]
	for tag in skill_def.tags:
		if tag in weapon_tags:
			return true
	return false


## ¿Puede pagar el actor el coste de la skill? Sin errores si le falta algún recurso
## (un enemigo registrado solo con salud no tiene estamina).
func _can_afford_silent(actor_id: String, skill_def: SkillDefinition) -> bool:
	if not Resources.has_entity(actor_id):
		return false
	for resource_id in skill_def.costs.keys():
		if not Resources.has_resource(actor_id, resource_id):
			return false
	var bundle: ResourceBundle = skill_def.get_cost_bundle()
	if bundle == null or bundle.is_empty():
		return true
	return Resources.can_pay(actor_id, bundle)


## Aviso o nota que se imprime una sola vez por combate.
func _note_once(key: String, message: String) -> void:
	if _noted.has(key):
		return
	_noted[key] = true
	print(message)


## Proporción de salud actual (0..1) respecto del máximo derivado. 1.0 si no se puede calcular.
func get_hp_ratio(entity_id: String) -> float:
	if not Resources.has_entity(entity_id) or not Resources.has_resource(entity_id, "health"):
		return 1.0
	var hp_max: float = AttributeResolver.resolve(entity_id, "health_max", {})
	if hp_max <= 0.0:
		return 1.0
	return clampf(Resources.get_resource_amount(entity_id, "health") / hp_max, 0.0, 1.0)


## Estado aparente de salud: healthy / hurt / badly_hurt, con umbrales de ai_scales.
func get_hp_state(entity_id: String) -> StringName:
	var ratio: float = get_hp_ratio(entity_id)
	var hurt_below: float = float(AIScales.get_value("hp_state_thresholds.hurt", 0.7))
	var badly_below: float = float(AIScales.get_value("hp_state_thresholds.badly_hurt", 0.3))
	if ratio < badly_below:
		return CombatTags.HP_BADLY_HURT
	if ratio < hurt_below:
		return CombatTags.HP_HURT
	return CombatTags.HP_HEALTHY


## Condiciones que un observador puede ver en `entity_id`: los buffs de la lista
## `visible_conditions` de ai_scales más `incapacitated` (0 PV) y `fled`. Ordenadas.
func get_visible_conditions(entity_id: String) -> Array[StringName]:
	var result: Array[StringName] = []
	var visible: Array = AIScales.get_value("visible_conditions", [])
	if _active_buffs.has(entity_id):
		for buff in _active_buffs[entity_id]:
			var buff_type: String = String(buff.get("buff_type", ""))
			if buff_type in visible and not result.has(StringName(buff_type)):
				result.append(StringName(buff_type))
	if is_fled(entity_id):
		result.append(CombatTags.CONDITION_FLED)
	elif Resources.has_entity(entity_id) and Resources.has_resource(entity_id, "health") \
			and Resources.get_resource_amount(entity_id, "health") <= 0.0:
		result.append(CombatTags.CONDITION_INCAPACITATED)
	result.sort()
	return result


## Amenaza aparente de `target_id` (low / medium / high) con información observable:
## `threat_hint` de su definición si existe (IA-0d); si no, el daño base derivado de su
## arma y atributos (AttributeResolver "base_damage") clasificado con los umbrales de
## ai_scales. Un `disarmed` visible baja un nivel. `observer_side` queda reservado: hoy
## ambos bandos ven lo mismo.
func estimate_threat(_observer_side: StringName, target_id: String) -> StringName:
	if not Characters.has_entity(target_id):
		return CombatTags.THREAT_LOW

	var level: StringName = _threat_from_hint(target_id)
	if level == &"":
		var power: float = AttributeResolver.resolve(target_id, "base_damage", {})
		if power >= float(AIScales.get_value("threat_thresholds.high", 15.0)):
			level = CombatTags.THREAT_HIGH
		elif power >= float(AIScales.get_value("threat_thresholds.medium", 8.0)):
			level = CombatTags.THREAT_MEDIUM
		else:
			level = CombatTags.THREAT_LOW

	if has_buff(target_id, "disarmed"):
		if level == CombatTags.THREAT_HIGH:
			level = CombatTags.THREAT_MEDIUM
		elif level == CombatTags.THREAT_MEDIUM:
			level = CombatTags.THREAT_LOW
	return level


## threat_hint de la definición (campo opcional de IA-0d): "" si no existe o no es válido.
func _threat_from_hint(entity_id: String) -> StringName:
	var state: CharacterState = Characters.get_character_state(entity_id)
	if state == null or state.definition == null:
		return &""
	var hint: Variant = state.definition.get("threat_hint")
	if hint is String or hint is StringName:
		var key: StringName = StringName(String(hint))
		if key == CombatTags.THREAT_LOW or key == CombatTags.THREAT_MEDIUM or key == CombatTags.THREAT_HIGH:
			return key
	return &""


## Etiquetas de una skill, DERIVADAS de sus efectos (decisión 4-A) y del coste.
func _derive_tags(actor_id: String, skill_def: SkillDefinition) -> Array[StringName]:
	var tags: Array[StringName] = []
	var defense_buffs: Array = AIScales.get_value("effect_value.defense_buffs", [])
	for effect in skill_def.effects:
		var tag: StringName = &""
		match String(effect.get("type", "")).to_upper():
			"DAMAGE":
				tag = CombatTags.TAG_ATTACK
			"BUFF":
				if String(effect.get("buff_type", "")) in defense_buffs:
					tag = CombatTags.TAG_DEFENSE
			"RESTORE":
				tag = CombatTags.TAG_RECOVER
			"FLEE":
				tag = CombatTags.TAG_FLEE
		if tag != &"" and not tags.has(tag):
			tags.append(tag)
	if _is_costly(actor_id, skill_def):
		tags.append(CombatTags.TAG_COSTLY)
	return tags


## costly: algún coste supera la fracción configurada del máximo de ese recurso del actor.
func _is_costly(actor_id: String, skill_def: SkillDefinition) -> bool:
	var fraction: float = float(AIScales.get_value("tag_rules.costly_cost_fraction", 1.0))
	for resource_id in skill_def.costs.keys():
		if not Resources.has_resource(actor_id, resource_id):
			continue
		var state: ResourceState = Resources.get_resource_state(actor_id, resource_id)
		if state.max_effective > 0.0 and float(skill_def.costs[resource_id]) > fraction * state.max_effective:
			return true
	return false


## Valor de una skill SELF en PV equivalentes (spec 5.2). Devuelve { ok, value, reason }.
## ok = false si algún efecto no tiene conversión declarada en ai_scales: esa skill no
## puede ser candidata. Un total negativo se corta a 0 con aviso.
func _estimate_self_effects(actor_id: String, skill_def: SkillDefinition) -> Dictionary:
	var total: float = 0.0
	var defense_buffs: Array = AIScales.get_value("effect_value.defense_buffs", [])

	for effect in skill_def.effects:
		match String(effect.get("type", "")).to_upper():
			"BUFF":
				var buff_type: String = String(effect.get("buff_type", ""))
				if not buff_type in defense_buffs:
					return {"ok": false, "value": 0.0, "reason": "buff '%s' sin conversión en effect_value" % buff_type}
				total += _estimate_reduction_value(actor_id, effect)

			"RESTORE":
				var resource_id: String = String(effect.get("resource_id", ""))
				var unit: Variant = AIScales.get_value("effect_value.restore.%s" % resource_id, null)
				if unit == null:
					return {"ok": false, "value": 0.0, "reason": "RESTORE de '%s' sin conversión en effect_value" % resource_id}
				if not Resources.has_resource(actor_id, resource_id):
					return {"ok": false, "value": 0.0, "reason": "el actor no tiene el recurso '%s'" % resource_id}
				var state: ResourceState = Resources.get_resource_state(actor_id, resource_id)
				var room: float = maxf(0.0, state.max_effective - state.current)
				total += minf(maxf(0.0, float(effect.get("value", 0.0))), room) * float(unit)

			"FLEE":
				var flee_value: Variant = AIScales.get_value("effect_value.flee", null)
				if flee_value == null:
					return {"ok": false, "value": 0.0, "reason": "FLEE sin conversión en effect_value"}
				total += float(flee_value)

			_:
				return {"ok": false, "value": 0.0, "reason": "efecto '%s' sin conversión" % effect.get("type")}

	if total < 0.0:
		push_warning("[CombatSystem] effect_estimate negativo (%.2f) en %s: cortado a 0" % [total, skill_def.id])
		total = 0.0
	return {"ok": true, "value": total, "reason": ""}


## Daño esperado que evita un buff de reducción de daño del propio actor: para cada
## amenaza visible (bando contrario), su mejor skill pagable, con y sin la reducción,
## con las MISMAS funciones de daño. Se multiplica por las ventanas del buff (turnos del
## dueño). Con armadura alta el mínimo de 1 deja la reducción en 0: es la regla real.
func _estimate_reduction_value(actor_id: String, effect: Dictionary) -> float:
	var pct: float = float(effect.get("value", 0.0))
	if pct <= 0.0:
		return 0.0
	var windows: int = maxi(1, int(effect.get("duration", 1)))

	var avoided: float = 0.0
	for threat_id in _get_opponents(actor_id):
		if not Skills.has_entity(threat_id):
			continue
		var best_without: float = -1.0
		var best_with: float = 0.0
		for entry in Skills.get_entity_skill_snapshot(threat_id):
			if entry.mode != "COMBAT" or not entry.is_unlocked:
				continue
			var threat_skill: SkillDefinition = Skills.get_skill_definition(entry.skill_id)
			if threat_skill == null or threat_skill.target_type == "SELF" or not _can_afford_silent(threat_id, threat_skill):
				continue
			var probabilities: Dictionary = get_grade_probabilities(threat_id, entry.skill_id)
			var without: float = _expected_on_target(threat_id, actor_id, threat_skill, probabilities)["expected"]
			if without > best_without:
				best_without = without
				best_with = _expected_on_target(threat_id, actor_id, threat_skill, probabilities, pct)["expected"]
		if best_without > 0.0:
			avoided += maxf(0.0, best_without - best_with)
	return avoided * float(windows)


## Candidatas del actor: una por (skill utilizable × objetivo válido); las skills SELF
## generan una sola candidata sin objetivo. SOLO LECTURA.
##
## No lista: skills que no son de combate o están bloqueadas, las que el actor no puede
## pagar (o cuyo recurso no tiene), las que están en cooldown, las bloqueadas por
## DISARMED, las SELF con un efecto sin conversión en `effect_value`, ni objetivos a 0 PV,
## huidos o fuera del combate. Orden canónico: action_id y después target_ids[0].
##
## Cada candidata: { action_id, actor_id, target_ids, tags, resource_cost (suma de costes),
## costs (por recurso), success_chance, expected_damage (ya ponderado por success_chance),
## kill_possible, effect_estimate (PV equivalentes), action_data (listo para
## combat_action_requested; falta el request_id) }.
func get_candidates(actor_id: String) -> Array:
	var candidates: Array = []
	if not Skills.has_entity(actor_id) or not Resources.has_entity(actor_id):
		return candidates
	if is_fled(actor_id) or not Resources.has_resource(actor_id, "health") \
			or Resources.get_resource_amount(actor_id, "health") <= 0.0:
		return candidates

	var opponents: Array[String] = _get_opponents(actor_id)

	for entry in Skills.get_entity_skill_snapshot(actor_id):
		if entry.mode != "COMBAT" or not entry.is_unlocked:
			continue
		var skill_id: String = entry.skill_id
		var skill_def: SkillDefinition = Skills.get_skill_definition(skill_id)
		if skill_def == null or _blocked_by_disarm(actor_id, skill_def):
			continue
		if not _can_afford_silent(actor_id, skill_def) or not Skills.can_use(actor_id, skill_id):
			continue

		var tags: Array[StringName] = _derive_tags(actor_id, skill_def)

		if skill_def.target_type == "SELF":
			var utility: Dictionary = _estimate_self_effects(actor_id, skill_def)
			if not utility.ok:
				_note_once("nocand:" + skill_id, "[CombatSystem] ℹ️ %s no es candidata de %s: %s" % [skill_id, actor_id, utility.reason])
				continue
			candidates.append(_make_candidate(actor_id, skill_def, tags, "", {}, float(utility.value)))
		else:
			for target_id in opponents:
				var estimate: Dictionary = estimate_damage(actor_id, target_id, skill_id)
				candidates.append(_make_candidate(actor_id, skill_def, tags, target_id, estimate, 0.0))

	candidates.sort_custom(_candidate_before)
	return candidates


## Construye el diccionario de una candidata. `estimate` vacío = skill SELF (sin tirada:
## acierto 1.0 y sin daño).
func _make_candidate(actor_id: String, skill_def: SkillDefinition, tags: Array[StringName], target_id: String, estimate: Dictionary, effect_estimate: float) -> Dictionary:
	var total_cost: float = 0.0
	for resource_id in skill_def.costs.keys():
		total_cost += float(skill_def.costs[resource_id])

	var target_ids: Array[String] = []
	if not target_id.is_empty():
		target_ids.append(target_id)

	return {
		"action_id": skill_def.id,
		"actor_id": actor_id,
		"target_ids": target_ids,
		"tags": tags,
		"resource_cost": total_cost,
		"costs": skill_def.costs.duplicate(),
		"success_chance": float(estimate.get("success_chance", 1.0)),
		"expected_damage": float(estimate.get("expected_damage", 0.0)),
		"kill_possible": bool(estimate.get("kill_possible", false)),
		"effect_estimate": effect_estimate,
		"action_data": {"actor": actor_id, "skill_id": skill_def.id, "target": target_id},
	}


## Orden canónico (clave de desempate explícita: sort_custom no es estable).
func _candidate_before(a: Dictionary, b: Dictionary) -> bool:
	if a.action_id != b.action_id:
		return a.action_id < b.action_id
	var target_a: String = a.target_ids[0] if not a.target_ids.is_empty() else ""
	var target_b: String = b.target_ids[0] if not b.target_ids.is_empty() else ""
	return target_a < target_b


## Callback: Personaje murió
func _on_character_death(character_id: String) -> void:
	print("[CombatSystem] 💀 Character died callback: %s" % character_id)
	
	# Reproducir animación de muerte
	var entity_node = get_tree().get_first_node_in_group(character_id)
	if entity_node:
		var anim_controller = entity_node.get_node_or_null("AnimationController")
		if anim_controller and anim_controller.has_method("play_death"):
			anim_controller.play_death()
			print("[CombatSystem] ☠️ Death animation played for %s" % character_id)
		else:
			# Fallback visual
			entity_node.modulate = Color(0.5, 0.5, 0.5, 0.5)
	
	# Evento legacy para compatibilidad (UI, logros, etc.)
	if character_id != PLAYER_ID:
		EventBus.emit_signal("enemy_defeated", character_id)


# ============================================
# GESTIÓN DE BUFFS
# ============================================

## Procesa la habilidad dodge: aplica buffs de evasión y golpe garantizado
func _process_dodge(entity_id: String, skill_def: SkillDefinition) -> void:
	print("[CombatSystem] 🤸 Processing dodge for %s" % entity_id)
	_play_skill_animation(entity_id, "skill.combat.dodge")
	
	for effect in skill_def.effects:
		if effect.get("type") == "BUFF":
			var buff_type = effect.get("buff_type", "")
			apply_buff(entity_id, _build_buff(effect, entity_id))
			print("[CombatSystem] 🤸 Buff applied: %s" % buff_type)
			# Iniciar efecto visual persistente para evasión
			if buff_type == "evasion":
				var anim = _get_animation_controller(entity_id)
				if anim:
					anim.start_evasion_effect()


# ============================================
# GESTIÓN DE BUFFS (turn-based)
# ============================================

## Aplica un buff a una entidad
## expires_on: "turn" (expira inicio turno jugador) | "use" (expira al activarse)
func apply_buff(entity_id: String, buff_data: Dictionary) -> void:
	if not _active_buffs.has(entity_id):
		_active_buffs[entity_id] = []

	if not buff_data.has("expires_on"):
		buff_data["expires_on"] = "turn"
	if not buff_data.has("uses_left"):
		buff_data["uses_left"] = 0
	if not buff_data.has("turns_left"):
		buff_data["turns_left"] = 1

	# Buffs aplicados en este turno no hacen tick hasta el siguiente
	buff_data["skip_first_tick"] = true

	_active_buffs[entity_id].append(buff_data)

	print("[CombatSystem] 🟢 Buff applied to %s: %s (%d turns, expires_on: %s)" % [
		entity_id,
		buff_data.get("buff_type", "unknown"),
		buff_data.get("turns_left", 1),
		buff_data.get("expires_on", "turn")
	])

	EventBus.emit_signal("buff_applied", entity_id, buff_data.get("buff_type", ""), 0.0)
	
## Verifica si una entidad tiene un buff activo
func has_buff(entity_id: String, buff_type: String) -> bool:
	if not _active_buffs.has(entity_id):
		return false
	for buff in _active_buffs[entity_id]:
		if buff.get("buff_type") == buff_type:
			return true
	return false


## Consume un buff de tipo "use" (lo elimina inmediatamente)
func consume_buff(entity_id: String, buff_type: String) -> void:
	if not _active_buffs.has(entity_id):
		return
	for i in range(_active_buffs[entity_id].size() - 1, -1, -1):
		var buff = _active_buffs[entity_id][i]
		if buff.get("buff_type") == buff_type:
			_active_buffs[entity_id].remove_at(i)
			print("[CombatSystem] 🔴 Buff consumed: %s from %s" % [buff_type, entity_id])
			EventBus.emit_signal("buff_expired", entity_id, buff_type)
			return

## Expira todos los buffs de tipo "turn" de una entidad al inicio de su turno
## Decrementa turns_left de buffs "turn" de una entidad.
## Solo elimina el buff cuando turns_left llega a 0.
func _expire_turn_buffs(entity_id: String) -> void:
	if not _active_buffs.has(entity_id):
		return
	for i in range(_active_buffs[entity_id].size() - 1, -1, -1):
		var buff: Dictionary = _active_buffs[entity_id][i]
		if buff.get("expires_on") != "turn":
			continue
		var turns_left: int = buff.get("turns_left", 1)
		turns_left -= 1
		if turns_left <= 0:
			var buff_type: String = buff.get("buff_type", "unknown")
			_active_buffs[entity_id].remove_at(i)
			print("[CombatSystem] 🔴 Buff expired: %s from %s" % [buff_type, entity_id])
			EventBus.emit_signal("buff_expired", entity_id, buff_type)
		else:
			buff["turns_left"] = turns_left
			print("[CombatSystem] ⏳ Buff tick: %s on %s (%d turns left)" % [
				buff.get("buff_type"), entity_id, turns_left
			])

## Limpia todos los buffs de una entidad (fin de combate)
## Último combatiente que ha hecho daño a `target_id` en este combate ("" si ninguno).
## La validez del atacante (¿sigue en pie?) la decide quien consulta, no Combat.
func get_last_attacker(target_id: String) -> String:
	return _last_attacker.get(target_id, "")


## Al empezar un combate no puede quedar un atacante del anterior.
func _on_combat_started(_participants: Array) -> void:
	_last_attacker.clear()
	_fled.clear()
	_noted.clear()


func clear_buffs(entity_id: String) -> void:
	if _active_buffs.has(entity_id):
		_active_buffs[entity_id].clear()

## Obtiene el valor numérico del primer buff activo del tipo indicado.
## Retorna 0.0 si no existe.
func _get_buff_value(entity_id: String, buff_type: String) -> float:
	if not _active_buffs.has(entity_id):
		return 0.0
	for buff in _active_buffs[entity_id]:
		if buff.get("buff_type") == buff_type:
			return buff.get("value", 0.0)
	return 0.0

## Procesa ticks de recursos al inicio del turno de una entidad.
## Evalúa: bleeding, resource_regen, resource_drain.
## Se llama DESPUÉS de _expire_turn_buffs para no procesar buffs
## que acaban de expirar en este mismo turno.
func _process_resource_ticks(entity_id: String) -> void:
	if not _active_buffs.has(entity_id):
		return

	for buff in _active_buffs[entity_id]:
		# Si es el primer turno desde que se aplicó, saltar y limpiar la marca
		if buff.get("skip_first_tick", false):
			buff["skip_first_tick"] = false
			continue

		var buff_type: String = buff.get("buff_type", "")

		match buff_type:
			"bleeding":
				var value: float = buff.get("value", 0.0)
				Resources.add_resource(entity_id, "health", -value)
				print("[CombatSystem] 🩸 bleeding tick: %s −%.1f HP" % [entity_id, value])
				EventBus.emit_signal("character_damaged", entity_id, value,
					Resources.get_resource_amount(entity_id, "health"))
				_spawn_damage_number(entity_id, value, false, false)
				_check_death_after_tick(entity_id)

			"resource_regen":
				var value: float = buff.get("value", 0.0)
				var resource_id: String = buff.get("resource_id", "")
				if resource_id.is_empty():
					push_warning("[CombatSystem] resource_regen sin resource_id en %s" % entity_id)
					continue
				Resources.add_resource(entity_id, resource_id, value)
				print("[CombatSystem] 💚 resource_regen tick: %s +%.1f %s" % [entity_id, value, resource_id])

			"resource_drain":
				var value: float = buff.get("value", 0.0)
				var resource_id: String = buff.get("resource_id", "")
				if resource_id.is_empty():
					push_warning("[CombatSystem] resource_drain sin resource_id en %s" % entity_id)
					continue
				Resources.add_resource(entity_id, resource_id, -value)
				print("[CombatSystem] 🔻 resource_drain tick: %s −%.1f %s" % [entity_id, value, resource_id])
				if resource_id == "health":
					EventBus.emit_signal("character_damaged", entity_id, value,
						Resources.get_resource_amount(entity_id, "health"))
					_check_death_after_tick(entity_id)

# ============================================
# ANIMACIONES (FASE B.1)
# ============================================

## Reproduce la animación de una skill
func _play_skill_animation(entity_id: String, skill_id: String) -> void:
	var entity_node = get_tree().get_first_node_in_group(entity_id)
	
	if not entity_node:
		return
	
	# Buscar AnimationController
	var anim_controller = entity_node.get_node_or_null("AnimationController")
	
	if not anim_controller:
		return
	
	# Reproducir animación según skill
	match skill_id:
		"skill.attack.light":
			anim_controller.play_attack_light()
		
		"skill.attack.heavy":
			anim_controller.play_attack_heavy()
		
		"skill.combat.dodge":
			anim_controller.play_dodge()
		
		"skill.combat.defend":
			if anim_controller.has_method("play_defend"):
				anim_controller.play_defend()
			else:
				anim_controller.play_dodge()  # Fallback visual
		
		"skill.enemy.basic_attack":
			anim_controller.play_attack_light()
		
		_:
			anim_controller.play_attack_light()


## Reproduce animación de recibir daño
func _play_hit_animation(entity_id: String) -> void:
	var entity_node = get_tree().get_first_node_in_group(entity_id)
	
	if not entity_node:
		return
	
	var anim_controller = entity_node.get_node_or_null("AnimationController")
	
	if not anim_controller:
		return
	
	anim_controller.play_hit_reaction()


# ============================================
# VFX (FASE B.2)
# ============================================

## Spawn de número de daño
func _spawn_damage_number(entity_id: String, damage: float, is_critical: bool, is_miss: bool) -> void:
	if not damage_numbers_parent:
		return
	
	var position = _get_entity_damage_number_position(entity_id)
	if position == Vector2.ZERO:
		return
	
	var damage_number = DamageNumberScene.instantiate()
	damage_numbers_parent.add_child(damage_number)
	
	# ✅ CORRECTO - Usar setup() con todos los parámetros
	damage_number.setup(damage, position, is_critical, false, is_miss)


## Obtiene la posición para mostrar damage number
func _get_entity_damage_number_position(entity_id: String) -> Vector2:
	var entity_node: Node = get_tree().get_first_node_in_group(entity_id)

	# Ficha de la arena nueva (UICombatToken, Control) — ya está en
	# espacio de pantalla, sin conversión de canvas.
	if entity_node is Control:
		var control: Control = entity_node as Control
		return control.get_global_rect().position + Vector2(control.size.x / 2.0, -10.0)

	# Nodo visual antiguo (Node2D, combat_test.tscn) — conversión de
	# posición de mundo a pantalla, como siempre.
	if entity_node is Node2D:
		var canvas: CanvasItem = entity_node as CanvasItem
		if canvas:
			return entity_node.get_global_transform_with_canvas().origin + Vector2(0, -40)

	# Fallback hardcodeado para entidades sin nodo visual
	match entity_id:
		"player":  return Vector2(300, 450)
		_:         return Vector2.ZERO


# ============================================
# UTILIDADES
# ============================================

## Obtiene el primer enemigo vivo (para MVP 1v1)
func _get_first_enemy() -> String:
	# Temporal: hardcoded para MVP
	# En producción: GameLoop proporcionaría lista de enemigos
	return "enemy_1"

## Comprueba si una entidad llegó a 0 HP tras un tick de recurso.
## Evita duplicar la lógica de muerte que ya existe en _apply_damage.
func _check_death_after_tick(entity_id: String) -> void:
	var hp: float = Resources.get_resource_amount(entity_id, "health")
	if hp <= 0:
		print("[CombatSystem] 💀 %s died from resource tick" % entity_id)
		EventBus.emit_signal("character_died", entity_id)
		
# ============================================
# VFX DE BUFFS
# ============================================

## Callback: buff aplicado → activar efecto visual persistente
func _on_buff_applied_vfx(entity_id: String, buff_type: String, _duration: float) -> void:
	var anim = _get_animation_controller(entity_id)
	if not anim:
		return
	match buff_type:
		"evasion":
			anim.start_evasion_effect()
		"defending":
			anim.start_defend_effect()


## Callback: buff expirado → detener efecto visual persistente
func _on_buff_expired_vfx(entity_id: String, buff_type: String) -> void:
	var anim = _get_animation_controller(entity_id)
	if not anim:
		return
	match buff_type:
		"evasion":
			anim.stop_evasion_effect()
		"defending":
			anim.stop_defend_effect()


## Obtiene el AnimationController de una entidad por su group
func _get_animation_controller(entity_id: String) -> EntityAnimationController:
	var entity_node = get_tree().get_first_node_in_group(entity_id)
	if not entity_node:
		return null
	return entity_node.get_node_or_null("AnimationController") as EntityAnimationController
