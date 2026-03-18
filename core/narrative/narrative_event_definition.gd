class_name NarrativeEventDefinition
extends Resource

## NarrativeEventDefinition - Definición de un evento narrativo
##
## v2: Añadido efecto "join_party" para reclutar companions.

@export var id: String = ""
@export var trigger_type: String = "MANUAL"
@export var trigger_ref_id: String = ""
@export var description: String = ""
@export var add_flags: Array[String] = []
@export var remove_flags: Array[String] = []
@export var set_variables: Dictionary = {}

## Efectos de juego:
##   { "type": "unlock_skill",  "entity_id", "skill_id" }
##   { "type": "start_learning","entity_id", "skill_id", "source_level", "source_type" }
##   { "type": "join_party",    "companion_id", "definition_id" }
@export var game_effects: Array = []


func validate() -> bool:
	if id.is_empty():
		push_error("[NarrativeEventDefinition] id cannot be empty")
		return false

	if trigger_type.is_empty():
		push_error("[NarrativeEventDefinition] trigger_type cannot be empty")
		return false

	var valid_triggers = [
		"DIALOGUE_END", "ITEM_USED", "AREA_ENTER",
		"COMBAT_END", "MANUAL", "WORLD_OBJECT_FUMBLE"
	]
	if trigger_type not in valid_triggers:
		push_warning("[NarrativeEventDefinition] Unknown trigger_type: %s" % trigger_type)

	return true


## Aplica los efectos narrativos y emite peticiones de efectos de juego.
func apply_to_narrative() -> void:
	for flag_id: String in add_flags:
		Narrative.set_flag(flag_id)

	for flag_id: String in remove_flags:
		Narrative.clear_flag(flag_id)

	for var_id: String in set_variables.keys():
		Narrative.set_variable(var_id, set_variables[var_id])

	Narrative.register_event(id)

	for effect: Dictionary in game_effects:
		_emit_game_effect(effect)


func _emit_game_effect(effect: Dictionary) -> void:
	var effect_type: String = effect.get("type", "")

	match effect_type:
		"unlock_skill":
			var entity_id: String = effect.get("entity_id", "player")
			var skill_id: String  = effect.get("skill_id", "")
			if skill_id.is_empty():
				push_error("[NarrativeEventDefinition] unlock_skill missing 'skill_id' in event: %s" % id)
				return
			EventBus.skill_unlock_requested.emit(entity_id, skill_id)

		"start_learning":
			var entity_id: String    = effect.get("entity_id", "player")
			var skill_id: String     = effect.get("skill_id", "")
			var source_level: int    = effect.get("source_level", 30)
			var source_type: String  = effect.get("source_type", "TRAINER")
			if skill_id.is_empty():
				push_error("[NarrativeEventDefinition] start_learning missing 'skill_id' in event: %s" % id)
				return
			EventBus.learning_session_requested.emit(entity_id, skill_id, source_level, source_type)

		"join_party":
			var companion_id: String  = effect.get("companion_id", "")
			var definition_id: String = effect.get("definition_id", companion_id)
			if companion_id.is_empty():
				push_error("[NarrativeEventDefinition] join_party missing 'companion_id' in event: %s" % id)
				return
			EventBus.emit_signal("join_party_requested", companion_id, definition_id)

		"":
			push_error("[NarrativeEventDefinition] game_effect missing 'type' in event: %s" % id)

		_:
			push_warning("[NarrativeEventDefinition] Unknown game_effect type '%s' in event: %s" % [effect_type, id])


func can_trigger() -> bool:
	return true


func _to_string() -> String:
	return "NarrativeEvent(id=%s, trigger=%s, +flags=%d, -flags=%d, vars=%d)" % [
		id, trigger_type, add_flags.size(), remove_flags.size(), set_variables.size()
	]
