class_name NarrativeEventDefinition
extends Resource

## NarrativeEventDefinition - Definición de un evento narrativo
##
## Representa un evento que puede modificar el estado narrativo
## cuando se dispara (trigger)
##
## Ejemplo:
##   id: "EVT_MEET_PRINCE"
##   trigger_type: "DIALOGUE_END"
##   trigger_ref_id: "DLG_PRINCE_INTRO"
##   add_flags: ["PRINCE_MET"]

## Identificador único del evento
@export var id: String = ""

## Tipo de trigger que dispara este evento
## Valores: "DIALOGUE_END", "ITEM_USED", "AREA_ENTER", "COMBAT_END", "MANUAL"
@export var trigger_type: String = "MANUAL"

## Referencia al elemento que dispara el evento
## Ejemplo: "DLG_PRINCE_INTRO" si trigger_type = "DIALOGUE_END"
@export var trigger_ref_id: String = ""

## Flags a activar cuando se dispara el evento
@export var add_flags: Array[String] = []

## Flags a desactivar cuando se dispara el evento
@export var remove_flags: Array[String] = []

## Variables a establecer cuando se dispara el evento
## Formato: { "var_id": value }
@export var set_variables: Dictionary = {}

## Descripción del evento (opcional, para debug)
@export var description: String = ""

## Efectos de juego a ejecutar cuando se dispara el evento.
## Cada efecto es un Dictionary con al menos { "type": String }.
## Tipos soportados:
##   { "type": "unlock_skill",        "entity_id": "player", "skill_id": "skill.xxx" }
##   { "type": "start_learning",      "entity_id": "player", "skill_id": "skill.xxx", "source_level": 40, "source_type": "TRAINER" }
## IMPORTANTE: este campo NO llama directamente a SkillSystem.
## Emite señales al EventBus — SkillEventHandler es el único que cruza la frontera.
@export var game_effects: Array = []


## Valida que la definición sea coherente
func validate() -> bool:
	if id.is_empty():
		push_error("[NarrativeEventDefinition] id cannot be empty")
		return false
	
	if trigger_type.is_empty():
		push_error("[NarrativeEventDefinition] trigger_type cannot be empty")
		return false
	
	# Validar trigger types conocidos
	var valid_triggers = [
		"DIALOGUE_END",
		"ITEM_USED",
		"AREA_ENTER",
		"COMBAT_END",
		"MANUAL"
	]
	
	if trigger_type not in valid_triggers:
		push_warning("[NarrativeEventDefinition] Unknown trigger_type: %s" % trigger_type)
	
	return true


## Aplica los efectos de este evento al NarrativeSystem y emite peticiones de efectos de juego.
## CONTRATO: este método SOLO emite señales para efectos de juego.
## Nunca llama directamente a SkillSystem u otros sistemas.
func apply_to_narrative() -> void:
	# Añadir flags
	for flag_id in add_flags:
		Narrative.set_flag(flag_id)
	
	# Remover flags
	for flag_id in remove_flags:
		Narrative.clear_flag(flag_id)
	
	# Establecer variables
	for var_id in set_variables.keys():
		Narrative.set_variable(var_id, set_variables[var_id])
	
	# Registrar el evento como completado
	Narrative.register_event(id)
	
	# Procesar efectos de juego — emitir peticiones, no ejecutar
	for effect in game_effects:
		_emit_game_effect(effect)


## Emite la señal correspondiente para un efecto de juego.
## SkillEventHandler (autoload) escuchará estas señales y ejecutará la lógica real.
func _emit_game_effect(effect: Dictionary) -> void:
	var effect_type = effect.get("type", "")
	
	match effect_type:
		"unlock_skill":
			var entity_id = effect.get("entity_id", "player")
			var skill_id  = effect.get("skill_id", "")
			if skill_id.is_empty():
				push_error("[NarrativeEventDefinition] unlock_skill effect missing 'skill_id' in event: %s" % id)
				return
			EventBus.skill_unlock_requested.emit(entity_id, skill_id)
		
		"start_learning":
			var entity_id    = effect.get("entity_id", "player")
			var skill_id     = effect.get("skill_id", "")
			var source_level = effect.get("source_level", 30)
			var source_type  = effect.get("source_type", "TRAINER")
			if skill_id.is_empty():
				push_error("[NarrativeEventDefinition] start_learning effect missing 'skill_id' in event: %s" % id)
				return
			EventBus.learning_session_requested.emit(entity_id, skill_id, source_level, source_type)
		
		"":
			push_error("[NarrativeEventDefinition] game_effect missing 'type' in event: %s" % id)
		
		_:
			push_warning("[NarrativeEventDefinition] Unknown game_effect type '%s' in event: %s" % [effect_type, id])


## Verifica si el evento puede dispararse (condiciones futuras)
func can_trigger() -> bool:
	# En el spike, siempre puede dispararse
	# Futuro: verificar condiciones narrativas previas
	return true


## Debug
func _to_string() -> String:
	return "NarrativeEvent(id=%s, trigger=%s, +flags=%d, -flags=%d, vars=%d)" % [
		id,
		trigger_type,
		add_flags.size(),
		remove_flags.size(),
		set_variables.size()
	]
