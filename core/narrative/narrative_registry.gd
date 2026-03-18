class_name NarrativeNarrative
extends Node

## NarrativeDB - Registro de eventos narrativos
## Singleton: /root/NarrativeDB
##
## Responsabilidad: Cargar y gestionar eventos narrativos desde JSON

## Catálogo de eventos: { event_id: String -> NarrativeEventDefinition }
var _events: Dictionary = {}


func _ready():
	print("[NarrativeDB] Initializing...")
	_load_events_from_json()
	print("[NarrativeDB] Loaded %d narrative events" % _events.size())


## Carga eventos desde archivo JSON
func _load_events_from_json():
	var json_path = "res://data/narrative/narrative_events.json"
	
	if not FileAccess.file_exists(json_path):
		push_warning("[NarrativeDB] File not found: %s" % json_path)
		return
	
	var file = FileAccess.open(json_path, FileAccess.READ)
	if not file:
		push_error("[NarrativeDB] Failed to open: %s" % json_path)
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		push_error("[NarrativeDB] JSON parse error: %s" % json.get_error_message())
		return
	
	var data = json.data
	
	if not data.has("narrative_events"):
		push_error("[NarrativeDB] Missing 'narrative_events' key in JSON")
		return
	
	var events_array = data["narrative_events"]
	
	for event_data in events_array:
		_load_event_from_dict(event_data)


## Carga un evento desde Dictionary
func _load_event_from_dict(data: Dictionary):
	var event = NarrativeEventDefinition.new()
	
	event.id = data.get("id", "")
	event.trigger_type = data.get("trigger_type", "MANUAL")
	event.trigger_ref_id = data.get("trigger_ref_id", "")
	event.description = data.get("description", "")
	
	# Arrays con conversión explícita de tipo
	var add_flags_data = data.get("add_flags", [])
	event.add_flags.clear()
	for flag in add_flags_data:
		event.add_flags.append(flag)
	
	var remove_flags_data = data.get("remove_flags", [])
	event.remove_flags.clear()
	for flag in remove_flags_data:
		event.remove_flags.append(flag)
	
	# Variables (Dictionary no tiene problema)
	event.set_variables = data.get("set_variables", {}).duplicate()
	
	# Efectos de juego (Array de Dictionaries — se duplica para evitar referencias)
	var game_effects_data = data.get("game_effects", [])
	event.game_effects.clear()
	for effect in game_effects_data:
		if typeof(effect) == TYPE_DICTIONARY:
			event.game_effects.append(effect.duplicate())
		else:
			push_warning("[NarrativeDB] Skipping invalid game_effect entry in event: %s" % data.get("id", "UNKNOWN"))
	
	# Validar
	if not event.validate():
		push_error("[NarrativeDB] Invalid event: %s" % data.get("id", "UNKNOWN"))
		return
	
	# Verificar duplicados
	if _events.has(event.id):
		push_warning("[NarrativeDB] Duplicate event ID: %s" % event.id)
		return
	
	# Registrar
	_events[event.id] = event
	print("  [NarrativeDB] Loaded event: %s" % event.id)


## Obtiene un evento por ID
func get_event(event_id: String) -> NarrativeEventDefinition:
	if not _events.has(event_id):
		push_warning("[NarrativeDB] Event not found: %s" % event_id)
		return null
	
	return _events[event_id]


## ¿Existe un evento con este ID?
func has_event(event_id: String) -> bool:
	return _events.has(event_id)


## Lista todos los IDs de eventos registrados
func list_events() -> Array:
	return _events.keys()


## Obtiene eventos por tipo de trigger
func get_events_by_trigger(trigger_type: String) -> Array[NarrativeEventDefinition]:
	var result: Array[NarrativeEventDefinition] = []
	
	for event in _events.values():
		if event.trigger_type == trigger_type:
			result.append(event)
	
	return result


## Debug: imprime todos los eventos cargados
func print_events():
	if _events.is_empty():
		print("  [NarrativeDB] No events loaded")
		return
	
	print("\n[NarrativeDB] Available events:")
	for event_id in _events.keys():
		var event = _events[event_id]
		print("  - %s (trigger: %s)" % [event_id, event.trigger_type])
	print("")
