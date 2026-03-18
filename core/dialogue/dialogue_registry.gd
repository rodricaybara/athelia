class_name DialogueRegistry
extends Node

## DialogueRegistry - Registro de diálogos
## Singleton: /root/DialogueDB
##
## Responsabilidad: Cargar y gestionar diálogos desde JSON

## Catálogo de diálogos: { dialogue_id: String -> DialogueDefinition }
var _dialogues: Dictionary = {}


func _ready():
	print("[DialogueDB] Initializing...")
	_load_dialogues_from_json()
	print("[DialogueDB] Loaded %d dialogues" % _dialogues.size())


## Carga todos los diálogos desde res://data/dialogue/
func _load_dialogues_from_json():
	var dialogue_dir = "res://data/dialogue/"
	var dir = DirAccess.open(dialogue_dir)
	
	if not dir:
		push_warning("[DialogueDB] Directory not found: %s" % dialogue_dir)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".json"):
			var file_path = dialogue_dir + file_name
			_load_dialogue_from_file(file_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()


## Carga un diálogo desde un archivo JSON
func _load_dialogue_from_file(file_path: String):
	if not FileAccess.file_exists(file_path):
		push_error("[DialogueDB] File not found: %s" % file_path)
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[DialogueDB] Failed to open: %s" % file_path)
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		push_error("[DialogueDB] JSON parse error in %s: %s" % [file_path, json.get_error_message()])
		return
	
	var data = json.data
	
	if not data.has("dialogue"):
		push_error("[DialogueDB] Missing 'dialogue' key in %s" % file_path)
		return
	
	_load_dialogue_from_dict(data["dialogue"])


## Carga un diálogo desde Dictionary
func _load_dialogue_from_dict(data: Dictionary):
	var dialogue = DialogueDefinition.new()
	dialogue.id = data.get("id", "")
	
	# Cargar nodos
	var nodes_data = data.get("nodes", [])
	for node_data in nodes_data:
		var node = _load_node_from_dict(node_data)
		if node:
			dialogue.nodes.append(node)
	
	# Validar
	if not dialogue.validate():
		push_error("[DialogueDB] Invalid dialogue: %s" % data.get("id", "UNKNOWN"))
		return
	
	# Verificar duplicados
	if _dialogues.has(dialogue.id):
		push_warning("[DialogueDB] Duplicate dialogue ID: %s" % dialogue.id)
		return
	
	# Registrar
	_dialogues[dialogue.id] = dialogue
	print("  [DialogueDB] Loaded dialogue: %s (%d nodes)" % [dialogue.id, dialogue.nodes.size()])


## Carga un nodo desde Dictionary
func _load_node_from_dict(data: Dictionary) -> DialogueNodeDefinition:
	var node = DialogueNodeDefinition.new()
	
	node.id = data.get("id", "")
	node.speaker_id = data.get("speaker_id", "")
	node.text_key = data.get("text_key", "")
	node.portrait_id = data.get("portrait_id", "")
	
	# Cargar opciones
	var options_data = data.get("options", [])
	for option_data in options_data:
		var option = _load_option_from_dict(option_data)
		if option:
			node.options.append(option)
	
	return node


## Carga una opción desde Dictionary
func _load_option_from_dict(data: Dictionary) -> DialogueOptionDefinition:
	var option = DialogueOptionDefinition.new()
	
	option.id = data.get("id", "")
	option.text_key = data.get("text_key", "")
	option.next_node_id = data.get("next_node_id", "")
	
	# Arrays tipados
	var required_flags_data = data.get("required_flags", [])
	for flag in required_flags_data:
		option.required_flags.append(flag)
	
	var blocked_flags_data = data.get("blocked_flags", [])
	for flag in blocked_flags_data:
		option.blocked_flags.append(flag)
	
	var narrative_events_data = data.get("narrative_events", [])
	for event in narrative_events_data:
		option.narrative_events.append(event)
	
	return option


## Obtiene un diálogo por ID
func get_dialogue(dialogue_id: String) -> DialogueDefinition:
	if not _dialogues.has(dialogue_id):
		push_warning("[DialogueDB] Dialogue not found: %s" % dialogue_id)
		return null
	
	return _dialogues[dialogue_id]


## ¿Existe un diálogo con este ID?
func has_dialogue(dialogue_id: String) -> bool:
	return _dialogues.has(dialogue_id)


## Lista todos los IDs de diálogos
func list_dialogues() -> Array:
	return _dialogues.keys()


## Debug: imprime todos los diálogos cargados
func print_dialogues():
	if _dialogues.is_empty():
		print("  [DialogueDB] No dialogues loaded")
		return
	
	print("\n[DialogueDB] Available dialogues:")
	for dialogue_id in _dialogues.keys():
		var dialogue = _dialogues[dialogue_id]
		print("  - %s (%d nodes)" % [dialogue_id, dialogue.nodes.size()])
	print("")
