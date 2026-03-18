class_name CheckpointRegistry
extends Node

## CheckpointRegistry - Registro de checkpoints narrativos
## Singleton: /root/CheckpointDB
##
## Responsabilidad: Cargar y gestionar checkpoints desde JSON

## Catálogo de checkpoints: { checkpoint_id: String -> CheckpointDefinition }
var _checkpoints: Dictionary = {}


func _ready():
	print("[CheckpointDB] Initializing...")
	_load_checkpoints_from_json()
	print("[CheckpointDB] Loaded %d checkpoints" % _checkpoints.size())


## Carga todos los checkpoints desde res://data/narrative/checkpoints.json
func _load_checkpoints_from_json():
	var file_path = "res://data/narrative/checkpoints.json"
	
	if not FileAccess.file_exists(file_path):
		push_warning("[CheckpointDB] File not found: %s" % file_path)
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[CheckpointDB] Failed to open: %s" % file_path)
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		push_error("[CheckpointDB] JSON parse error: %s" % json.get_error_message())
		return
	
	var data = json.data
	
	if not data.has("checkpoints"):
		push_error("[CheckpointDB] Missing 'checkpoints' key")
		return
	
	# Cargar cada checkpoint
	var checkpoints_data = data["checkpoints"]
	for checkpoint_data in checkpoints_data:
		_load_checkpoint_from_dict(checkpoint_data)


## Carga un checkpoint desde Dictionary
func _load_checkpoint_from_dict(data: Dictionary):
	var checkpoint = CheckpointDefinition.new()
	
	checkpoint.id = data.get("checkpoint_id", "")
	checkpoint.description = data.get("description", "")
	
	# Cargar vectores acumulados
	var vectors_data = data.get("accumulated_vectors", [])
	for vector in vectors_data:
		checkpoint.accumulated_vectors.append(vector)
	
	# Cargar flags preservados
	var flags_data = data.get("flags_preserved", [])
	for flag in flags_data:
		checkpoint.flags_preserved.append(flag)
	
	# Cargar variables preservadas
	var vars_data = data.get("variables_preserved", [])
	for var_name in vars_data:
		checkpoint.variables_preserved.append(var_name)
	
	# Cargar valores iniciales
	var initial_vals = data.get("initial_values", {})
	for key in initial_vals.keys():
		checkpoint.initial_values[key] = initial_vals[key]
	
	# Cargar flags iniciales
	var initial_flags_data = data.get("initial_flags", [])
	for flag in initial_flags_data:
		checkpoint.initial_flags.append(flag)
	
	# Cargar rangos de normalización
	var norm_ranges = data.get("normalization_ranges", {})
	for key in norm_ranges.keys():
		checkpoint.normalization_ranges[key] = norm_ranges[key]
	
	# Validar
	if not checkpoint.validate():
		push_error("[CheckpointDB] Invalid checkpoint: %s" % data.get("checkpoint_id", "UNKNOWN"))
		return
	
	# Verificar duplicados
	if _checkpoints.has(checkpoint.id):
		push_warning("[CheckpointDB] Duplicate checkpoint ID: %s" % checkpoint.id)
		return
	
	# Registrar
	_checkpoints[checkpoint.id] = checkpoint
	print("  [CheckpointDB] Loaded checkpoint: %s" % checkpoint.id)


## Obtiene un checkpoint por ID
func get_checkpoint(checkpoint_id: String) -> CheckpointDefinition:
	if not _checkpoints.has(checkpoint_id):
		push_warning("[CheckpointDB] Checkpoint not found: %s" % checkpoint_id)
		return null
	
	return _checkpoints[checkpoint_id]


## ¿Existe un checkpoint con este ID?
func has_checkpoint(checkpoint_id: String) -> bool:
	return _checkpoints.has(checkpoint_id)


## Lista todos los IDs de checkpoints
func list_checkpoints() -> Array:
	return _checkpoints.keys()


## Debug: imprime todos los checkpoints cargados
func print_checkpoints():
	if _checkpoints.is_empty():
		print("  [CheckpointDB] No checkpoints loaded")
		return
	
	print("\n[CheckpointDB] Available checkpoints:")
	for checkpoint_id in _checkpoints.keys():
		var checkpoint = _checkpoints[checkpoint_id]
		print("  - %s: %s" % [checkpoint_id, checkpoint.description])
		print("    Vectors: %s" % checkpoint.accumulated_vectors)
		print("    Flags preserved: %s" % checkpoint.flags_preserved)
		print("    Variables preserved: %s" % checkpoint.variables_preserved)
	print("")
