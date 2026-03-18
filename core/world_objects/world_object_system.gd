## class_name eliminado — el autoload se llama "WorldObjectSystem" (mismo patrón que WorldObjectRegistry)
extends Node

## WorldObjectSystem - Orquestador de interacciones con objetos del mundo
## Autoload: /root/WorldObjectSystem
##
## RESPONSABILIDADES:
##   - Registrar instancias de WorldObject en runtime
##   - Determinar qué interacciones están disponibles para una entidad
##   - Validar requisitos (flags, stamina, skill presente)
##   - Ejecutar la tirada de habilidad vía SkillRoller
##   - Aplicar cambios de flags al WorldObjectState
##   - Notificar a SkillProgressionService del outcome
##   - Emitir resultados al EventBus para que el Bridge aplique efectos
##
## NO HACE:
##   - Modificar InventorySystem directamente (lo hace WorldObjectBridge)
##   - Disparar NarrativeSystem directamente (lo hace WorldObjectBridge)
##   - Lógica de UI (lo hace WorldObjectInteractionPanel)

# ============================================
# ESTADO INTERNO
# ============================================

## Instancias activas: { instance_id: String -> WorldObjectState }
var _instances: Dictionary = {}




# ============================================
# INICIALIZACIÓN
# ============================================

func _ready() -> void:


	# Escuchar solicitudes de interacción
	EventBus.world_object_action_chosen.connect(_on_action_chosen)

	print("[WorldObjectSystem] Initialized")


# ============================================
# REGISTRO DE INSTANCIAS
# ============================================

## Registra una instancia de WorldObject en la escena.
## definition_id debe existir en WorldObjectRegistry.
## Llamado desde ExplorationTest._ready() para cada objeto de la escena.
func register_instance(instance_id: String, definition_id: String) -> bool:
	if _instances.has(instance_id):
		push_warning("[WorldObjectSystem] Instance already registered: %s" % instance_id)
		return false

	var def: WorldObjectDefinition = WorldObjects.get_object(definition_id)
	if def == null:
		push_error("[WorldObjectSystem] Definition not found: %s" % definition_id)
		return false

	var state := WorldObjectState.new(def, instance_id)
	_instances[instance_id] = state

	print("[WorldObjectSystem] Registered instance '%s' (def: '%s')" % [instance_id, definition_id])
	return true


## Desregistra una instancia (p. ej. al cambiar de escena)
func unregister_instance(instance_id: String) -> void:
	if _instances.erase(instance_id):
		print("[WorldObjectSystem] Unregistered instance: %s" % instance_id)


# ============================================
# CONSULTA DE INTERACCIONES DISPONIBLES
# ============================================

## Devuelve las interacciones disponibles para entity_id sobre instance_id.
## Filtra por:
##   1. required_flags presentes en WorldObjectState
##   2. Skill requerida conocida por la entidad (tiene skill_value > 0)
## La UI usa esta lista para construir los botones.
func get_available_interactions(instance_id: String, entity_id: String) -> Array[InteractionDefinition]:
	var result: Array[InteractionDefinition] = []

	var state := _get_state(instance_id)
	if state == null or state.is_depleted:
		return result

	for interaction in state.definition.interactions:
		if _is_interaction_available(interaction, state, entity_id):
			result.append(interaction)

	return result


## Comprueba si una interacción concreta está disponible
func _is_interaction_available(
		interaction: InteractionDefinition,
		state: WorldObjectState,
		entity_id: String) -> bool:

	# 1. Flags requeridas presentes
	if not state.has_all_flags(interaction.required_flags):
		return false

	# 2. Skill check — "skill.any" significa sin restricción (ej: recoger bolsa de loot)
	if interaction.required_skill != "skill.any":
		var skill_value := Characters.get_skill_value(entity_id, interaction.required_skill)
		if skill_value <= 0:
			return false

	return true


# ============================================
# EJECUCIÓN DE INTERACCIÓN
# ============================================

## Callback: jugador elige una interacción concreta
func _on_action_chosen(entity_id: String, instance_id: String, interaction_id: String) -> void:
	var state := _get_state(instance_id)
	if state == null:
		_fail(entity_id, instance_id, "instance_not_found")
		return

	var interaction := state.definition.get_interaction(interaction_id)
	if interaction == null:
		_fail(entity_id, instance_id, "interaction_not_found")
		return

	# Validar disponibilidad (flags + skill)
	if not _is_interaction_available(interaction, state, entity_id):
		_fail(entity_id, instance_id, "interaction_not_available")
		return

	# Validar coste de stamina
	if interaction.stamina_cost > 0:
		var stamina_state = Resources.get_resource_state(entity_id, "stamina")
		if stamina_state == null or not stamina_state.can_pay(interaction.stamina_cost):
			_fail(entity_id, instance_id, "insufficient_stamina")
			return

	# --- Todo válido: ejecutar ---
	_execute_interaction(entity_id, state, interaction)


## Núcleo de resolución: tirada → outcome → flags → eventos
func _execute_interaction(
		entity_id: String,
		state: WorldObjectState,
		interaction: InteractionDefinition) -> void:

	# 1. Consumir stamina
	if interaction.stamina_cost > 0:
		Resources.add_resource(entity_id, "stamina", -interaction.stamina_cost)

	# 2. Obtener skill value y lanzar tirada con modificador de dificultad
	# "skill.any" = sin restricción de skill → éxito automático, sin tirada
	var outcome_key: String
	var roll_result = null
	if interaction.required_skill == "skill.any":
		outcome_key = "success"
		print("[WorldObjectSystem] %s → %s | skill.any → auto-success" % [
			entity_id, interaction.id
		])
	else:
		var base_skill_value := Characters.get_skill_value(entity_id, interaction.required_skill)
		var effective_value  := int(float(base_skill_value) / interaction.difficulty)
		effective_value = clampi(effective_value, 1, 100)

		roll_result = SkillRoller.roll_skill(effective_value)
		outcome_key = _roll_to_outcome_key(roll_result)

		print("[WorldObjectSystem] %s → %s | skill=%d, effective=%d, roll=%d → %s" % [
			entity_id, interaction.id,
			base_skill_value, effective_value,
			roll_result.roll, outcome_key
		])

	# 3. Aplicar cambios de flags (solo en éxito — failure y fumble no modifican el estado)
	if outcome_key == "critical" or outcome_key == "success":
		state.apply_flag_changes(interaction.consumed_flags, interaction.produced_flags)

	# 4. Obtener outcome y marcar depleted ANTES de emitir state_changed
	#    para que los listeners vean is_depleted = true en la señal
	var outcome_def := interaction.get_outcome(outcome_key)
	if _check_depleted(state) or (outcome_def != null and outcome_def.depletes_object):
		state.is_depleted = true

	# 5. Emitir state_changed con estado ya final (flags + is_depleted actualizados)
	if outcome_key == "critical" or outcome_key == "success":
		EventBus.world_object_state_changed.emit(state.instance_id, state.active_flags.duplicate())

	# 6. Construir effect_data para el Bridge
	var effect_data := _build_effect_data(outcome_def)

	# 6. Notificar a SkillProgressionService (solo si hay skill real, no skill.any)
	if interaction.required_skill != "skill.any" and roll_result != null:
		var base_skill_value := Characters.get_skill_value(entity_id, interaction.required_skill)
		var effective_value  := int(float(base_skill_value) / interaction.difficulty)
		var progression_context := { "out_of_combat": true, "difficulty_rating": effective_value }
		var progression_outcome := SkillRoller.to_progression_outcome(roll_result.result)
		if SkillProgression:
			SkillProgression.notify_skill_outcome(
				entity_id,
				interaction.required_skill,
				progression_outcome,
				progression_context
			)

	# 7. Emitir resultado al EventBus → WorldObjectBridge lo aplicará
	EventBus.world_object_interaction_resolved.emit(
		state.instance_id,
		interaction.id,
		outcome_key,
		effect_data
	)


# ============================================
# HELPERS INTERNOS
# ============================================

## Traduce RollResult a string de outcome para InteractionDefinition
func _roll_to_outcome_key(roll_result) -> String:
	match roll_result.result:
		SkillRoller.RollResult.CRITICAL: return "critical"
		SkillRoller.RollResult.SUCCESS:  return "success"
		SkillRoller.RollResult.FAILURE:  return "failure"
		SkillRoller.RollResult.FUMBLE:   return "fumble"
	return "failure"  # fallback seguro


## Construye el diccionario de efectos a partir del outcome
## Campos vacíos se omiten para que el Bridge ignore lo que no aplica
func _build_effect_data(outcome: InteractionOutcome) -> Dictionary:
	if outcome == null:
		return {}

	var data := {}

	if not outcome.feedback_key.is_empty():
		data["feedback_key"] = outcome.feedback_key

	if not outcome.loot_table_id.is_empty():
		data["loot_table_id"] = outcome.loot_table_id

	if not outcome.revealed_info_key.is_empty():
		data["revealed_info_key"] = outcome.revealed_info_key

	if not outcome.narrative_event_id.is_empty():
		data["narrative_event_id"] = outcome.narrative_event_id

	if outcome.depletes_object:
		data["depletes_object"] = true

	return data


## Comprueba si el objeto ha quedado sin interacciones útiles
func _check_depleted(state: WorldObjectState) -> bool:
	for interaction in state.definition.interactions:
		# Si alguna interacción tiene sus flags requeridas activas, no está depleted
		if state.has_all_flags(interaction.required_flags):
			return false
	return true


## Emite interaction_failed y loguea la razón
func _fail(entity_id: String, instance_id: String, reason: String) -> void:
	push_warning("[WorldObjectSystem] Interaction failed — entity=%s, instance=%s, reason=%s" % [
		entity_id, instance_id, reason
	])
	EventBus.world_object_interaction_failed.emit(entity_id, instance_id, reason)


## Obtiene el WorldObjectState por instance_id con guard
func _get_state(instance_id: String) -> WorldObjectState:
	if not _instances.has(instance_id):
		push_warning("[WorldObjectSystem] Instance not found: %s" % instance_id)
		return null
	return _instances[instance_id]


# ============================================
# API PÚBLICA (para UI y Bridge)
# ============================================

## Devuelve el WorldObjectState de una instancia (para UI)
func get_state(instance_id: String) -> WorldObjectState:
	return _get_state(instance_id)

## ¿Existe esta instancia?
func has_instance(instance_id: String) -> bool:
	return _instances.has(instance_id)

## ¿Está depleted?
func is_depleted(instance_id: String) -> bool:
	var state := _get_state(instance_id)
	return state.is_depleted if state else true

## Devuelve las flags activas de una instancia (para UI / debug)
func get_active_flags(instance_id: String) -> Array:
	var state := _get_state(instance_id)
	return state.active_flags.duplicate() if state else []

## Snapshot para SaveSystem (futuro)
func get_save_state() -> Dictionary:
	var data := {}
	for instance_id in _instances:
		data[instance_id] = _instances[instance_id].get_save_state()
	return data
