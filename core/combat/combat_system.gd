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

## Buffs activos por entidad
## Estructura: { entity_id: [{ buff_type, expires_on, turns_left, uses_left }, ...] }
## expires_on: "turn" (expira inicio turno jugador) | "use" (expira al activarse)
var _active_buffs: Dictionary = {}

## Módulo de defensa (absorción stamina)
var _defense_module: DefenseModule = null

## Módulo de huida (escape determinista)
var _escape_module: EscapeModule = null

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
func _on_execute_combat_action(action_data: Dictionary) -> void:
	var actor = action_data.get("actor", "")
	var skill_id = action_data.get("skill_id", "")
	var target = action_data.get("target", "")
	
	# Skills SELF (dodge) no necesitan target enemigo
	var skill_def = Skills.get_skill_definition(skill_id)
	var is_self_target = skill_def and skill_def.target_type == "SELF"
	
	if target.is_empty() and not is_self_target:
		push_error("[CombatSystem] No target specified in action_data for skill: %s" % skill_id)
		return
	
	print("[CombatSystem] Executing action: %s uses %s on %s" % [actor, skill_id, target if not is_self_target else "SELF"])
	
	_pending_skill_context = {
		"actor": actor,
		"skill_id": skill_id,
		"target": target
	}
	
	var success = Skills.request_use(actor, skill_id)
	
	if not success:
		EventBus.emit_signal("combat_action_failed", actor, "Skill use failed")
		_pending_skill_context.clear()


## Callback: Inicio del turno del jugador
func _on_player_turn_started() -> void:
	print("[CombatSystem] Player turn started - processing buffs and modules")
	
	# 1. Expirar buffs de tipo "turn" del jugador
	_expire_turn_buffs(PLAYER_ID)
	
	# 2. Expirar defensa si estaba activa
	_defense_module.on_player_turn_start()
	
	# 3. Resolver escape pendiente (se activó en el turno anterior)
	if _escape_module.is_pending():
		var threshold = _escape_module.get_current_threshold()
		var success = _escape_module.resolve_escape(PLAYER_ID)
		if success:
			# Consumir stamina como coste del escape exitoso
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
		EventBus.emit_signal("combat_action_completed", {"success": true, "action": "dodge"})
		EventBus.emit_signal("player_action_completed", {"success": true, "action": "dodge"})
		return
	
	# --- HABILIDADES DE ATAQUE: requieren target ---
	if target_id.is_empty():
		push_error("[CombatSystem] No target in pending context for skill: %s" % skill_id)
		_pending_skill_context.clear()
		return
	
	print("[CombatSystem] Resolving skill: %s → %s" % [entity_id, target_id])
	
	# Verificar guaranteed_hit antes de la tirada
	var skill_value = Characters.get_skill_value(entity_id, skill_id)
	var is_guaranteed = has_buff(entity_id, "guaranteed_hit")
	
	var roll_result = SkillRoller.roll_skill(skill_value)
	
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
		result = _process_skill_effects(entity_id, skill_def, is_critical)
		result["roll_result"] = roll_result
		
		if result.has("buffs_applied") and not result.buffs_applied.is_empty():
			for buff in result.buffs_applied:
				apply_buff(entity_id, buff)
		
		if result.get("success", false) and result.get("damage", 0) > 0:
			var damage = result.get("damage", 0.0)
			var is_crit = result.get("critical", false)
			_apply_damage_by_target_type(entity_id, target_id, skill_def, damage, is_crit)
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

	_pending_skill_context.clear()
	
	EventBus.emit_signal("combat_action_completed", result)
	EventBus.emit_signal("combat_action_executed", entity_id, skill_id, target_id, result)
	
	if entity_id == PLAYER_ID:
		EventBus.emit_signal("player_action_completed", result)
	
	if result.get("success", false):
		var crit_text = " (CRITICAL!)" if result.get("critical", false) else ""
		print("[CombatSystem] ✅ %s dealt %.1f damage%s" % [skill_id, result.get("damage", 0), crit_text])
	else:
		var fumble_text = " (FUMBLE!)" if result.get("fumble", false) else ""
		print("[CombatSystem] ❌ Skill missed%s" % fumble_text)

## Callback: SkillSystem falló al activar la habilidad
func _on_skill_failed(entity_id: String, skill_id: String, reason: String):
	print("[CombatSystem] Skill activation failed: %s (reason: %s)" % [skill_id, reason])
	
	EventBus.emit_signal("combat_action_failed", entity_id, reason)


# ============================================
# RESOLUCIÓN DE COMBATE
# ============================================

## Resuelve el resultado de una habilidad de combate
## Calcula daño usando AttributeResolver y procesa efectos
func _resolve_combat_skill(
	entity_id: String,
	skill_id: String,
	_target_id: String,
	is_critical: bool = false
) -> Dictionary:
	var skill_def = Skills.get_skill_definition(skill_id)
	if not skill_def:
		return {"success": false, "damage": 0}
	
	# FASE C.2: Calcular daño con AttributeResolver
	var effects_result = _process_skill_effects(
		entity_id,
		skill_def,
		is_critical
	)
	
	return {
		"success": true,
		"damage": effects_result.get("damage", 0.0),
		"critical": is_critical,
		"buffs_applied": effects_result.get("buffs_applied", [])
	}


## Procesa efectos de una habilidad (daño + buffs)
func _process_skill_effects(
	entity_id: String,
	skill_def: SkillDefinition,
	is_critical: bool
) -> Dictionary:
	var character_state = Characters.get_character_state(entity_id)  # ❌ Ya no necesitas esto
	if not character_state:
		return {"damage": 0, "buffs_applied": []}
	
	var damage: float = 0.0
	var buffs_applied: Array = []
	
	for effect in skill_def.effects:
		match effect.get("type", "").to_lower():
			"damage":
				var base_damage_attr = effect.get("base_damage_attribute", "base_damage")
				var damage_modifier = effect.get("value", 1.0)
				
				print("[CombatSystem] Skill effect - attr: %s, modifier: %.2f" % [base_damage_attr, damage_modifier])
				
				var resolved_damage = AttributeResolver.resolve(
					entity_id,
					base_damage_attr,
					{}
				)
				
				damage = resolved_damage * damage_modifier
				
				if is_critical:
					var crit_multiplier = effect.get("critical_multiplier", 2.0)
					damage *= crit_multiplier
				
				print("[CombatSystem] Damage calculated: %.1f (base: %.1f, modifier: %.2f, crit: %s)" % [
					damage,
					resolved_damage,
					damage_modifier,
					is_critical
				])
			
			"buff":
				buffs_applied.append(effect.duplicate())
			
			_:
				push_warning("[CombatSystem] Unknown effect type: %s" % effect.get("type"))
	
	return {
		"success": true,
		"damage": damage,
		"critical": is_critical,
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
	var target_type = skill_def.target_type

	match target_type:
		"SINGLE_ENEMY":
			_apply_damage(target_id, damage, is_critical, attacker_id)

		"AREA":
			# Golpea a todos los enemigos vivos
			var all_enemies = GameLoop.get_active_enemies()
			print("[CombatSystem] 💥 AREA attack hits %d enemies" % all_enemies.size())
			for enemy_id in all_enemies:
				_apply_damage(enemy_id, damage, is_critical, attacker_id)

		"MULTI_ENEMY":
			# Golpea hasta max_targets enemigos — se lee del primer effect con type DAMAGE
			var max_targets = 2  # fallback si no está definido en el .tres
			for effect in skill_def.effects:
				if effect.get("type", "").to_lower() == "damage":
					max_targets = effect.get("max_targets", max_targets)
					break

			var all_enemies = GameLoop.get_active_enemies()
			# Priorizar el target seleccionado: colocarlo primero en la lista
			var ordered: Array[String] = []
			if target_id in all_enemies:
				ordered.append(target_id)
			for enemy_id in all_enemies:
				if enemy_id != target_id:
					ordered.append(enemy_id)

			var targets_hit = min(max_targets, ordered.size())
			print("[CombatSystem] ⚔️ MULTI_ENEMY attack hits %d/%d enemies" % [targets_hit, ordered.size()])
			for i in range(targets_hit):
				_apply_damage(ordered[i], damage, is_critical, attacker_id)

		_:
			# Fallback seguro: comportamiento SINGLE
			push_warning("[CombatSystem] Unknown target_type '%s' for skill, falling back to SINGLE" % target_type)
			_apply_damage(target_id, damage, is_critical, attacker_id)


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
	
	# --- ARMOR RATING: reducción plana aplicada a todos los targets ---
	# Se resuelve ANTES de defensa/daño para que sea la base sobre la que operan.
	# Fórmula: damage_after_armor = max(1, damage - armor_rating)
	# El mínimo 1 garantiza que ningún ataque haga 0 daño.
	var armor = AttributeResolver.resolve(target_id, "armor_rating", {})
	var damage_after_armor := maxf(1.0, damage - armor)
	if armor > 0.0:
		print("[CombatSystem] 🛡️ %s armor_rating=%.1f: %.1f → %.1f dmg" % [
			target_id, armor, damage, damage_after_armor
		])
	
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
	
	EventBus.emit_signal("character_damaged", target_id, applied_damage, current_hp)
	
	if current_hp <= 0:
		EventBus.emit_signal("character_died", target_id)

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
			apply_buff(entity_id, {
				"buff_type": buff_type,
				"expires_on": "use",   # Se consume al primer uso
				"uses_left": 1
			})
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
	
	# Normalizar: si viene del .tres con 'duration', convertir a turn-based
	if not buff_data.has("expires_on"):
		buff_data["expires_on"] = "turn"
	if not buff_data.has("uses_left"):
		buff_data["uses_left"] = 1
	
	_active_buffs[entity_id].append(buff_data)
	
	print("[CombatSystem] 🟢 Buff applied to %s: %s (expires_on: %s)" % [
		entity_id,
		buff_data.get("buff_type", "unknown"),
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
func _expire_turn_buffs(entity_id: String) -> void:
	if not _active_buffs.has(entity_id):
		return
	for i in range(_active_buffs[entity_id].size() - 1, -1, -1):
		var buff = _active_buffs[entity_id][i]
		if buff.get("expires_on") == "turn":
			var buff_type = buff.get("buff_type", "unknown")
			_active_buffs[entity_id].remove_at(i)
			print("[CombatSystem] 🔴 Buff expired (turn): %s from %s" % [buff_type, entity_id])
			EventBus.emit_signal("buff_expired", entity_id, buff_type)


## Limpia todos los buffs de una entidad (fin de combate)
func clear_buffs(entity_id: String) -> void:
	if _active_buffs.has(entity_id):
		_active_buffs[entity_id].clear()


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
	# Intentar leer posición del nodo real en la escena
	var entity_node: Node = get_tree().get_first_node_in_group(entity_id)
	if entity_node and entity_node is Node2D:
		# Convertir posición del mundo a posición de pantalla
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
