class_name CheckpointState
extends RefCounted

## CheckpointState - Estado runtime de un checkpoint alcanzado
##
## Representa el snapshot del estado narrativo consolidado
## en un momento específico (checkpoint alcanzado)

## ID del checkpoint
var checkpoint_id: String = ""

## Vectores acumulados y consolidados
## Ejemplo: {"reputation": 45, "community": 12}
var accumulated_vectors: Dictionary = {}

## Flags preservados
var flags_preserved: Array[String] = []

## Variables preservadas
## Ejemplo: {"gold": 150, "reputation": 45}
var variables_preserved: Dictionary = {}

## Timestamp del checkpoint
var timestamp: String = ""


## Constructor
func _init(cp_id: String = ""):
	checkpoint_id = cp_id
	timestamp = Time.get_datetime_string_from_system()


## Convierte a Dictionary para persistencia
func to_dict() -> Dictionary:
	return {
		"checkpoint_id": checkpoint_id,
		"accumulated_vectors": accumulated_vectors.duplicate(),
		"flags_preserved": flags_preserved.duplicate(),
		"variables_preserved": variables_preserved.duplicate(),
		"timestamp": timestamp
	}


## Crea CheckpointState desde Dictionary
static func from_dict(data: Dictionary) -> CheckpointState:
	var state = CheckpointState.new()
	
	state.checkpoint_id = data.get("checkpoint_id", "")
	state.timestamp = data.get("timestamp", "")
	
	# Copiar vectores
	var vectors = data.get("accumulated_vectors", {})
	for key in vectors.keys():
		state.accumulated_vectors[key] = vectors[key]
	
	# Copiar flags
	var flags = data.get("flags_preserved", [])
	for flag in flags:
		state.flags_preserved.append(flag)
	
	# Copiar variables
	var vars = data.get("variables_preserved", {})
	for key in vars.keys():
		state.variables_preserved[key] = vars[key]
	
	return state


## Valida que el estado sea coherente
func validate() -> bool:
	if checkpoint_id.is_empty():
		push_error("[CheckpointState] checkpoint_id cannot be empty")
		return false
	
	return true


## Debug
func _to_string() -> String:
	return "CheckpointState(id=%s, vectors=%d, flags=%d)" % [
		checkpoint_id,
		accumulated_vectors.size(),
		flags_preserved.size()
	]
