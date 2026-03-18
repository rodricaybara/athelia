class_name NarrativeDebugViewModel
extends RefCounted

## ViewModel para el Narrative Debug Panel
## Responsabilidad: Proporcionar datos formateados para la UI

## Datos del estado narrativo actual
var current_checkpoint: String = ""
var active_flags: Array[String] = []
var variables: Dictionary = {}
var consolidated_vectors: Dictionary = {}  # {name: {value, min, max, percentage}}
var reached_checkpoints: Array[String] = []
var events_completed: Array[String] = []
var available_checkpoints: Array[String] = []


## Refresca todos los datos desde los sistemas
func refresh_from_systems() -> void:
	print("[NarrativeDebugVM] Refreshing from systems...")
	
	_refresh_checkpoint_data()
	_refresh_narrative_data()
	_refresh_available_checkpoints()
	
	print("[NarrativeDebugVM] Refresh complete")


## Refresca datos de checkpoints
func _refresh_checkpoint_data() -> void:
	# Checkpoint actual
	current_checkpoint = Checkpoints.get_current_checkpoint_id()
	
	# Checkpoints alcanzados
	reached_checkpoints.clear()
	for cp_state in Checkpoints.get_reached_checkpoints():
		reached_checkpoints.append(cp_state.checkpoint_id)
	
	# Vectores consolidados del checkpoint actual
	consolidated_vectors.clear()
	
	if not current_checkpoint.is_empty():
		var cp_state = Checkpoints.get_checkpoint_state(current_checkpoint)
		if cp_state:
			# Obtener definición para rangos
			var cp_def = CheckpointDB.get_checkpoint(current_checkpoint)
			
			for vector_name in cp_state.accumulated_vectors.keys():
				var value = cp_state.accumulated_vectors[vector_name]
				var vector_info = {
					"value": value,
					"min": -100.0,
					"max": 100.0,
					"percentage": 0.5
				}
				
				# Obtener rango de normalización si existe
				if cp_def and cp_def.has_normalization_for(vector_name):
					var range_data = cp_def.get_normalization_range(vector_name)
					vector_info["min"] = range_data["min"]
					vector_info["max"] = range_data["max"]
					
					# Calcular porcentaje
					var range_size = vector_info["max"] - vector_info["min"]
					if range_size > 0:
						vector_info["percentage"] = (value - vector_info["min"]) / range_size
					else:
						vector_info["percentage"] = 0.5
				
				consolidated_vectors[vector_name] = vector_info


## Refresca datos narrativos
func _refresh_narrative_data() -> void:
	# Flags activos
	active_flags = Narrative.get_active_flags().duplicate()
	
	# Variables
	variables = Narrative.get_all_variables().duplicate()
	
	# Eventos completados
	events_completed = Narrative.get_completed_events().duplicate()


## Refresca lista de checkpoints disponibles
func _refresh_available_checkpoints() -> void:
	available_checkpoints.clear()
	var checkpoints_list = CheckpointDB.list_checkpoints()
	for checkpoint_id in checkpoints_list:
		# Solo ofertar checkpoints que aún no han sido alcanzados
		if checkpoint_id not in reached_checkpoints:
			available_checkpoints.append(checkpoint_id)


## Obtiene datos formateados para display
func to_display_dict() -> Dictionary:
	return {
		"current_checkpoint": current_checkpoint if not current_checkpoint.is_empty() else "None",
		"active_flags": active_flags,
		"variables": variables,
		"consolidated_vectors": consolidated_vectors,
		"reached_checkpoints": reached_checkpoints,
		"events_completed": events_completed,
		"available_checkpoints": available_checkpoints,
		"stats": {
			"flags_count": active_flags.size(),
			"variables_count": variables.size(),
			"vectors_count": consolidated_vectors.size(),
			"checkpoints_count": reached_checkpoints.size(),
			"events_count": events_completed.size()
		}
	}


## Valida que los sistemas están disponibles
func validate_systems() -> bool:
	if not is_instance_valid(Narrative):
		push_error("[NarrativeDebugVM] Narrative system not found")
		return false
	
	if not is_instance_valid(Checkpoints):
		push_error("[NarrativeDebugVM] Checkpoints system not found")
		return false
	
	if not is_instance_valid(CheckpointDB):
		push_error("[NarrativeDebugVM] CheckpointDB not found")
		return false
	
	return true


## Debug
func print_state() -> void:
	var display = to_display_dict()
	print("\n[NarrativeDebugVM] Current State:")
	print("  Current Checkpoint: %s" % display["current_checkpoint"])
	print("  Flags: %d" % display["stats"]["flags_count"])
	print("  Variables: %d" % display["stats"]["variables_count"])
	print("  Vectors: %d" % display["stats"]["vectors_count"])
	print("  Checkpoints Reached: %d" % display["stats"]["checkpoints_count"])
	print("")
