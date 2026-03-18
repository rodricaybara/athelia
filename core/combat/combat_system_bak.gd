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
## Estructura: { entity_id: [{ buff_type, duration, time_left, stacks }, ...] }
var _active_buffs: Dictionary = {}

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
	# Conectar a eventos de GameLoop
	if EventBus:
		EventBus.execute_combat_action.connect(_on_execute_combat_action)
		EventBus.player_turn_started.connect(_on_player_turn_started)
		EventBus.character_died.connect(_on_character_death)
	else:
		push_error("[CombatSystem] EventBus autoload not found!")
	
	# Conectar a eventos de SkillSystem
	if Skills:
		Skills.skill_used.connect(_on_skill_used)
		Skills.skill_failed.connect(_on_skill_failed)
	else:
		push_error("[CombatSystem] SkillSystem (Skills) autoload not found!")
	
	print("[CombatSystem] Initialized (Refactored)")


func _process(delta):
	# Actualizar buffs
	_update_buffs(delta)


# ============================================
# CALLBACKS DE GAMELOOP
# ============================================

## Callback: GameLoop ordena ejecutar una acción de combate
func _on_execute_combat_action(action_data: Dictionary) -> void:
	var actor = action_data.get("actor", "")
	var skill_id = action_data.get("skill_id", "")
	var target = action_data.get("target", "")  # ✅ Obtener del action_data
	
	if target.is_empty():
		push_error("[CombatSystem] No target specified in action_data")
		return
	
	print("[CombatSystem] Executing action: %s uses %s on %s" % [actor, skill_id, target])
	
	# ✅ Guardar el contexto ANTES de llamar a Skills.request_use()
	_pending_skill_context = {
		"actor": actor,
		"skill_id": skill_id,
		"target": target  # ✅ Guardar el target correcto
	}
	
	# Solicitar uso de skill
	var success = Skills.request_use(actor, skill_id)
	
	if not success:
		EventBus.emit_signal("combat_action_failed", actor, "Skill use failed")
		_pending_skill_context.clear()


## Callback: Inicio del turno del jugador
func _on_player_turn_started() -> void:
	print("[CombatSystem] Player turn started - processing buffs")
	
	# Expirar buffs que duran "hasta tu turno"
	_expire_buffs_on_turn_start(PLAYER_ID)


# ============================================
# CALLBACKS DE SKILLSYSTEM
# ============================================

## Callback: SkillSystem ejecutó la habilidad exitosamente
func _on_skill_used(entity_id: String, skill_id: String):
	# ✅ Recuperar el target del contexto guardado
	var target_id = _pending_skill_context.get("target", "")
	
	if target_id.is_empty():
		push_error("[CombatSystem] No target in pending context!")
		_pending_skill_context.clear()
		return
	
	print("[CombatSystem] Resolving skill: %s → %s" % [entity_id, target_id])
	
	# Obtener skill definition
	var skill_def = Skills.get_skill_definition(skill_id)
	if not skill_def:
		push_error("[CombatSystem] Skill definition not found: %s" % skill_id)
		_pending_skill_context.clear()
		return
	
	# ✅ HACER LA TIRADA AQUÍ (como en tu código actual)
	var skill_value = Characters.get_skill_value(entity_id, skill_id)
	var is_guaranteed = has_buff(entity_id, "guaranteed_hit")
	
	var roll_result = SkillRoller.roll_skill(skill_value)
	
	if is_guaranteed:
		consume_buff(entity_id, "guaranteed_hit")
		print("[CombatSystem] Guaranteed hit used!")
	
	# Log de tirada
	print("[CombatSystem] %s rolled %d vs %d%% → %s" % [
		skill_id,
		roll_result.roll,
		roll_result.skill_value,
		roll_result.result_name
	])
	
	var result: Dictionary = {}
	
	# Si éxito o crítico → calcular daño
	if roll_result.success:
		_play_skill_animation(entity_id, skill_id)
		
		var is_critical = (roll_result.result == SkillRoller.RollResult.CRITICAL)
		
		# Procesar efectos usando el target correcto
		result = _process_skill_effects(entity_id, skill_def, is_critical)
		result["roll_result"] = roll_result
		
		# Aplicar buffs si los hay
		if result.has("buffs_applied") and not result.buffs_applied.is_empty():
			for buff in result.buffs_applied:
				apply_buff(entity_id, buff)
		
		# Aplicar daño al TARGET CORRECTO
		if result.get("success", false) and result.get("damage", 0) > 0:
			var damage = result.get("damage", 0.0)
			var is_crit = result.get("critical", false)
			_apply_damage(target_id, damage, is_crit)  # ✅ target_id del contexto
	
	else:
		# Fallo o pifia
		result = {
			"success": false,
			"damage": 0,
			"roll_result": roll_result,
			"fumble": (roll_result.result == SkillRoller.RollResult.FUMBLE)
		}
		_spawn_damage_number(target_id, 0, false, true)  # ✅ MISS en target correcto
		
		if result.fumble:
			print("[CombatSystem] ⚠️ FUMBLE!")
	
	# Limpiar contexto
	_pending_skill_context.clear()
	
	# Emitir eventos
	EventBus.emit_signal("combat_action_completed", result)
	EventBus.emit_signal("combat_action_executed", entity_id, skill_id, target_id, result)
	
	# Si es jugador, notificar específicamente
	if entity_id == PLAYER_ID:
		EventBus.emit_signal("player_action_completed", result)
	
	# Log resultado
	if result.get("success", false):
		var crit_text = " (CRITICAL!)" if result.get("critical", false) else ""
		print("[CombatSystem] ✅ Combat skill executed: %s dealt %.1f damage%s" % [
			skill_id, result.get("damage", 0), crit_text
		])
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


## Aplica daño a una entidad
func _apply_damage(target_id: String, damage: float, is_critical: bool = false) -> void:
	# Reducir HP del target
	Resources.add_resource(target_id, "health", -damage)
	
	# FASE B.1: Animación de hit
	_play_hit_animation(target_id)
	
	# Obtener HP actual
	var current_hp = Resources.get_resource_amount(target_id, "health")
	
	print("[CombatSystem] %s took %.1f damage (HP: %.1f)" % [target_id, damage, current_hp])
	
	# FASE B.2: Spawn damage number
	_spawn_damage_number(target_id, damage, is_critical, false)
	
	# Emitir evento de daño
	EventBus.emit_signal("character_damaged", target_id, damage, current_hp)
	
	# Verificar muerte
	if current_hp <= 0:
		EventBus.emit_signal("character_died", target_id)
		#_on_character_death(target_id)

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

## Aplica un buff a una entidad
func apply_buff(entity_id: String, buff_data: Dictionary) -> void:
	if not _active_buffs.has(entity_id):
		_active_buffs[entity_id] = []
	
	buff_data["time_left"] = buff_data.get("duration", 0.0)
	buff_data["stacks"] = 1
	
	_active_buffs[entity_id].append(buff_data)
	
	print("[CombatSystem] 🛡️ Buff applied to %s: %s (%.1fs)" % [
		entity_id,
		buff_data.get("buff_type", "unknown"),
		buff_data.duration
	])
	
	EventBus.emit_signal("buff_applied", entity_id, buff_data.get("buff_type", ""), buff_data.duration)


## Verifica si una entidad tiene un buff
func has_buff(entity_id: String, buff_type: String) -> bool:
	if not _active_buffs.has(entity_id):
		return false
	
	for buff in _active_buffs[entity_id]:
		if buff.get("buff_type") == buff_type:
			return true
	
	return false


## Consume un buff (lo elimina)
func consume_buff(entity_id: String, buff_type: String) -> void:
	if not _active_buffs.has(entity_id):
		return
	
	for i in range(_active_buffs[entity_id].size() - 1, -1, -1):
		var buff = _active_buffs[entity_id][i]
		if buff.get("buff_type") == buff_type:
			_active_buffs[entity_id].remove_at(i)
			print("[CombatSystem] Buff consumed: %s from %s" % [buff_type, entity_id])
			EventBus.emit_signal("buff_expired", entity_id, buff_type)
			return


## Actualiza buffs (cuenta tiempo)
func _update_buffs(delta: float) -> void:
	for entity_id in _active_buffs.keys():
		var buffs = _active_buffs[entity_id]
		
		for i in range(buffs.size() - 1, -1, -1):
			var buff = buffs[i]
			
			# Decrementar tiempo
			buff["time_left"] -= delta
			
			# Si expiró, eliminar
			if buff["time_left"] <= 0:
				var buff_type = buff.get("buff_type", "unknown")
				buffs.remove_at(i)
				print("[CombatSystem] Buff expired: %s from %s" % [buff_type, entity_id])
				EventBus.emit_signal("buff_expired", entity_id, buff_type)


## Expira buffs al inicio del turno
func _expire_buffs_on_turn_start(entity_id: String) -> void:
	if not _active_buffs.has(entity_id):
		return
	
	var buffs = _active_buffs[entity_id]
	
	for i in range(buffs.size() - 1, -1, -1):
		var buff = buffs[i]
		
		# Eliminar buffs que duran "hasta tu turno"
		if buff.get("expire_on_turn_start", false):
			var buff_type = buff.get("buff_type", "unknown")
			buffs.remove_at(i)
			print("[CombatSystem] Buff expired on turn start: %s from %s" % [buff_type, entity_id])
			EventBus.emit_signal("buff_expired", entity_id, buff_type)


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
		
		"skill.enemy.basic_attack":
			anim_controller.play_attack_light()  # Enemigos usan light
		
		_:
			# Skill sin animación específica, usar light por defecto
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
	var entity_node = get_tree().get_first_node_in_group(entity_id)
	
	if not entity_node:
		return Vector2.ZERO
	
	# Posiciones hardcodeadas para MVP (debería venir de config)
	match entity_id:
		"player":
			return Vector2(300, 450)
		"enemy_1":
			return Vector2(600, 450)
		_:
			return Vector2.ZERO


# ============================================
# UTILIDADES
# ============================================

## Obtiene el primer enemigo vivo (para MVP 1v1)
func _get_first_enemy() -> String:
	# Temporal: hardcoded para MVP
	# En producción: GameLoop proporcionaría lista de enemigos
	return "enemy_1"
