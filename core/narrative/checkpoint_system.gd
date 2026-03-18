class_name CheckpointSystem
extends Node

## CheckpointSystem - Gestor de checkpoints narrativos
## Singleton: /root/Checkpoints
##
## Responsabilidad: Consolidar, normalizar y limpiar estado narrativo
## entre actos mediante checkpoints

## Historial de checkpoints alcanzados
var _reached_checkpoints: Array[CheckpointState] = []

## Checkpoint actual (último alcanzado)
var _current_checkpoint: CheckpointState = null


func _ready():
	print("[CheckpointSystem] Initialized - Narrative checkpoint manager ready")


# ==============================================
# CONSOLIDACIÓN DE VECTORES
# ==============================================

## Consolida vectores de valor desde el estado narrativo actual
## Retorna Dictionary con vectores consolidados
func consolidate_vectors(checkpoint_def: CheckpointDefinition) -> Dictionary:
	if not checkpoint_def:
		push_error("[CheckpointSystem] Cannot consolidate: null checkpoint definition")
		return {}
	
	var consolidated = {}
	
	print("[CheckpointSystem] Consolidating vectors for checkpoint: %s" % checkpoint_def.id)
	
	# Para cada vector declarado en el checkpoint
	for vector_name in checkpoint_def.accumulated_vectors:
		var total_value = _calculate_vector_value(vector_name)
		consolidated[vector_name] = total_value
		
		print("  [CheckpointSystem] Vector '%s' = %.2f" % [vector_name, total_value])
	
	print("[CheckpointSystem] Consolidated %d vectors" % consolidated.size())
	
	return consolidated


## Calcula el valor consolidado de un vector
## Busca todas las variables narrativas que contribuyen a este vector
func _calculate_vector_value(vector_name: String) -> float:
	var total: float = 0.0
	
	# 1. Buscar variable directa (ej: "reputation")
	if Narrative.has_variable(vector_name):
		total += Narrative.get_variable(vector_name, 0.0)
	
	# 2. Buscar variables con prefijo (ej: "reputation_act1_a", "reputation_act1_b")
	var all_vars = Narrative.get_all_variables()
	for var_name in all_vars.keys():
		if var_name.begins_with(vector_name + "_"):
			var value = all_vars[var_name]
			if value is float or value is int:
				total += float(value)
				print("    [CheckpointSystem] Adding '%s' = %.2f to '%s'" % [
					var_name, float(value), vector_name
				])
	
	return total


# ==============================================
# NORMALIZACIÓN DE VALORES
# ==============================================

## Normaliza valores consolidados según los rangos del checkpoint
## Modifica el Dictionary in-place
func normalize_values(
	consolidated: Dictionary,
	checkpoint_def: CheckpointDefinition
) -> void:
	print("[CheckpointSystem] Normalizing values for checkpoint: %s" % checkpoint_def.id)
	
	for vector_name in consolidated.keys():
		if checkpoint_def.has_normalization_for(vector_name):
			var range_data = checkpoint_def.get_normalization_range(vector_name)
			var current_value = consolidated[vector_name]
			var normalized = _normalize_to_range(
				current_value,
				range_data["min"],
				range_data["max"]
			)
			
			if normalized != current_value:
				print("  [CheckpointSystem] Normalized '%s': %.2f → %.2f (range: [%d, %d])" % [
					vector_name,
					current_value,
					normalized,
					range_data["min"],
					range_data["max"]
				])
				
				consolidated[vector_name] = normalized


## Normaliza un valor a un rango específico
func _normalize_to_range(value: float, min_val: float, max_val: float) -> float:
	return clampf(value, min_val, max_val)


# ==============================================
# APLICACIÓN DE VECTORES AL ESTADO NARRATIVO
# ==============================================

## Aplica vectores consolidados al NarrativeSystem
## Reemplaza variables dispersas por vectores únicos
func apply_consolidated_vectors(consolidated: Dictionary) -> void:
	print("[CheckpointSystem] Applying consolidated vectors to NarrativeSystem")
	
	for vector_name in consolidated.keys():
		var value = consolidated[vector_name]
		
		# Establecer el vector consolidado
		Narrative.set_variable(vector_name, value)
		
		print("  [CheckpointSystem] Set '%s' = %.2f" % [vector_name, value])
	
	print("[CheckpointSystem] Applied %d vectors" % consolidated.size())


## Limpia variables dispersas que fueron consolidadas
## Elimina variables con prefijos que ya no son necesarias
func cleanup_dispersed_variables(
	vector_names: Array[String]
) -> void:
	print("[CheckpointSystem] Cleaning up dispersed variables")
	
	var all_vars = Narrative.get_all_variables()
	var removed_count = 0
	
	for vector_name in vector_names:
		# Buscar y eliminar variables con prefijo
		for var_name in all_vars.keys():
			if var_name.begins_with(vector_name + "_"):
				Narrative.clear_variable(var_name)
				removed_count += 1
				print("  [CheckpointSystem] Removed dispersed variable: '%s'" % var_name)
	
	print("[CheckpointSystem] Cleaned up %d dispersed variables" % removed_count)


# ==============================================
# CONSULTAS
# ==============================================

## Obtiene el checkpoint actual
func get_current_checkpoint() -> CheckpointState:
	return _current_checkpoint


## Obtiene el ID del checkpoint actual
func get_current_checkpoint_id() -> String:
	if _current_checkpoint:
		return _current_checkpoint.checkpoint_id
	return ""


## ¿Se ha alcanzado un checkpoint específico?
func has_reached_checkpoint(checkpoint_id: String) -> bool:
	for checkpoint in _reached_checkpoints:
		if checkpoint.checkpoint_id == checkpoint_id:
			return true
	return false


## Obtiene todos los checkpoints alcanzados
func get_reached_checkpoints() -> Array[CheckpointState]:
	return _reached_checkpoints


# ==============================================
# DEBUG
# ==============================================

## Imprime el estado actual del sistema
func print_state() -> void:
	print("\n[CheckpointSystem] Current State:")
	print("  Checkpoints reached: %d" % _reached_checkpoints.size())
	
	if _current_checkpoint:
		print("  Current checkpoint: %s" % _current_checkpoint.checkpoint_id)
		print("  Vectors: %s" % _current_checkpoint.accumulated_vectors)
		print("  Flags preserved: %s" % _current_checkpoint.flags_preserved)
	else:
		print("  No current checkpoint")
	
	print("")


## Reinicia el sistema (debug)
func reset() -> void:
	_reached_checkpoints.clear()
	_current_checkpoint = null
	print("[CheckpointSystem] Reset complete")

# ==============================================
# LIMPIEZA DE FLAGS
# ==============================================

## Limpia flags obsoletos preservando solo los críticos
## Retorna estadísticas de limpieza
func cleanup_flags(checkpoint_def: CheckpointDefinition) -> Dictionary:
	if not checkpoint_def:
		push_error("[CheckpointSystem] Cannot cleanup: null checkpoint definition")
		return {}
	
	print("[CheckpointSystem] Cleaning up flags for checkpoint: %s" % checkpoint_def.id)
	
	var stats = {
		"total_before": 0,
		"preserved": 0,
		"removed": 0,
		"flags_removed": []
	}
	
	# Obtener todos los flags activos
	var active_flags = Narrative.get_active_flags()
	stats["total_before"] = active_flags.size()
	
	print("  [CheckpointSystem] Active flags before cleanup: %d" % stats["total_before"])
	
	# Identificar flags a eliminar
	for flag in active_flags:
		if checkpoint_def.preserves_flag(flag):
			# Preservar flag crítico
			stats["preserved"] += 1
			print("    [CheckpointSystem] PRESERVE: %s" % flag)
		else:
			# Eliminar flag obsoleto
			Narrative.clear_flag(flag)
			stats["removed"] += 1
			stats["flags_removed"].append(flag)
			print("    [CheckpointSystem] REMOVE: %s" % flag)
	
	print("[CheckpointSystem] Cleanup complete: %d preserved, %d removed" % [
		stats["preserved"],
		stats["removed"]
	])
	
	return stats


## Aplica flags iniciales del siguiente acto
func apply_initial_flags(checkpoint_def: CheckpointDefinition) -> void:
	if not checkpoint_def:
		push_error("[CheckpointSystem] Cannot apply initial flags: null checkpoint definition")
		return
	
	print("[CheckpointSystem] Applying initial flags for checkpoint: %s" % checkpoint_def.id)
	
	for flag in checkpoint_def.initial_flags:
		Narrative.set_flag(flag)
		print("  [CheckpointSystem] SET initial flag: %s" % flag)
	
	print("[CheckpointSystem] Applied %d initial flags" % checkpoint_def.initial_flags.size())


## Realiza limpieza completa de flags (cleanup + initial)
func process_flags(checkpoint_def: CheckpointDefinition) -> Dictionary:
	var stats = cleanup_flags(checkpoint_def)
	apply_initial_flags(checkpoint_def)
	return stats


# ==============================================
# LIMPIEZA DE VARIABLES
# ==============================================

## Limpia variables obsoletas preservando solo las críticas
## Retorna estadísticas de limpieza
func cleanup_variables(checkpoint_def: CheckpointDefinition) -> Dictionary:
	if not checkpoint_def:
		push_error("[CheckpointSystem] Cannot cleanup: null checkpoint definition")
		return {}
	
	print("[CheckpointSystem] Cleaning up variables for checkpoint: %s" % checkpoint_def.id)
	
	var stats = {
		"total_before": 0,
		"preserved": 0,
		"removed": 0,
		"variables_removed": []
	}
	
	# Obtener todas las variables
	var all_vars = Narrative.get_all_variables()
	stats["total_before"] = all_vars.size()
	
	print("  [CheckpointSystem] Variables before cleanup: %d" % stats["total_before"])
	
	# Identificar variables a eliminar
	for var_name in all_vars.keys():
		# Preservar si está en la lista de preservadas
		if checkpoint_def.preserves_variable(var_name):
			stats["preserved"] += 1
			print("    [CheckpointSystem] PRESERVE: %s = %s" % [var_name, all_vars[var_name]])
		# Preservar si es un vector consolidado
		elif var_name in checkpoint_def.accumulated_vectors:
			stats["preserved"] += 1
			print("    [CheckpointSystem] PRESERVE (vector): %s = %s" % [var_name, all_vars[var_name]])
		else:
			# Eliminar variable obsoleta
			Narrative.clear_variable(var_name)
			stats["removed"] += 1
			stats["variables_removed"].append(var_name)
			print("    [CheckpointSystem] REMOVE: %s" % var_name)
	
	print("[CheckpointSystem] Cleanup complete: %d preserved, %d removed" % [
		stats["preserved"],
		stats["removed"]
	])
	
	return stats


## Aplica valores iniciales del siguiente acto
func apply_initial_values(checkpoint_def: CheckpointDefinition) -> void:
	if not checkpoint_def:
		push_error("[CheckpointSystem] Cannot apply initial values: null checkpoint definition")
		return
	
	print("[CheckpointSystem] Applying initial values for checkpoint: %s" % checkpoint_def.id)
	
	for var_name in checkpoint_def.initial_values.keys():
		var value = checkpoint_def.initial_values[var_name]
		Narrative.set_variable(var_name, value)
		print("  [CheckpointSystem] SET initial value: %s = %s" % [var_name, value])
	
	print("[CheckpointSystem] Applied %d initial values" % checkpoint_def.initial_values.size())


## Realiza limpieza completa de variables (cleanup + initial)
func process_variables(checkpoint_def: CheckpointDefinition) -> Dictionary:
	var stats = cleanup_variables(checkpoint_def)
	apply_initial_values(checkpoint_def)
	return stats

# ==============================================
# APLICACIÓN COMPLETA DE CHECKPOINT
# ==============================================

## Aplica un checkpoint completo - Orquesta todo el proceso
## Retorna el CheckpointState creado o null si falla
func apply_checkpoint(checkpoint_id: String) -> CheckpointState:
	print("\n[CheckpointSystem] ========================================")
	print("[CheckpointSystem] APPLYING CHECKPOINT: %s" % checkpoint_id)
	print("[CheckpointSystem] ========================================")
	
	# Verificar que no se haya alcanzado ya
	if has_reached_checkpoint(checkpoint_id):
		push_warning("[CheckpointSystem] Checkpoint already reached: %s" % checkpoint_id)
		return null
	
	# Obtener definición
	var checkpoint_def = CheckpointDB.get_checkpoint(checkpoint_id)
	if not checkpoint_def:
		push_error("[CheckpointSystem] Checkpoint definition not found: %s" % checkpoint_id)
		return null
	
	# Crear estado del checkpoint
	var checkpoint_state = CheckpointState.new(checkpoint_id)
	
	print("[CheckpointSystem] Step 1/7: Consolidating vectors...")
	# 1. Consolidar vectores
	var consolidated = consolidate_vectors(checkpoint_def)
	checkpoint_state.accumulated_vectors = consolidated.duplicate()
	
	print("[CheckpointSystem] Step 2/7: Normalizing values...")
	# 2. Normalizar valores
	normalize_values(consolidated, checkpoint_def)
	checkpoint_state.accumulated_vectors = consolidated.duplicate()
	
	print("[CheckpointSystem] Step 3/7: Cleaning up flags...")
	# 3. Limpiar flags (y guardar preservados)
	var flag_stats = cleanup_flags(checkpoint_def)
	checkpoint_state.flags_preserved = Narrative.get_active_flags().duplicate()
	
	print("[CheckpointSystem] Step 4/7: Applying initial flags...")
	# 4. Aplicar flags iniciales
	apply_initial_flags(checkpoint_def)
	
	print("[CheckpointSystem] Step 5/7: Cleaning up variables...")
	# 5. Limpiar variables dispersas
	cleanup_dispersed_variables(checkpoint_def.accumulated_vectors)
	
	print("[CheckpointSystem] Step 6/7: Applying consolidated vectors...")
	# 6. Aplicar vectores consolidados
	apply_consolidated_vectors(consolidated)
	
	# Limpiar variables obsoletas y aplicar iniciales
	var var_stats = cleanup_variables(checkpoint_def)
	apply_initial_values(checkpoint_def)
	
	# Guardar variables preservadas en el estado
	for var_name in checkpoint_def.variables_preserved:
		if Narrative.has_variable(var_name):
			checkpoint_state.variables_preserved[var_name] = Narrative.get_variable(var_name)
	
	print("[CheckpointSystem] Step 7/7: Finalizing checkpoint...")
	# 7. Registrar checkpoint alcanzado
	_reached_checkpoints.append(checkpoint_state)
	_current_checkpoint = checkpoint_state
	
	# Emitir eventos
	EventBus.checkpoint_reached.emit(checkpoint_id, checkpoint_state.to_dict())
	
	print("[CheckpointSystem] ========================================")
	print("[CheckpointSystem] CHECKPOINT APPLIED SUCCESSFULLY")
	print("[CheckpointSystem] ========================================")
	print("[CheckpointSystem] Summary:")
	print("  - Vectors consolidated: %d" % consolidated.size())
	print("  - Flags preserved: %d" % checkpoint_state.flags_preserved.size())
	print("  - Flags removed: %d" % flag_stats["removed"])
	print("  - Variables preserved: %d" % checkpoint_state.variables_preserved.size())
	print("  - Variables removed: %d" % var_stats["removed"])
	print("[CheckpointSystem] ========================================\n")
	
	return checkpoint_state


## Registra manualmente un checkpoint (para testing)
func register_checkpoint_reached(checkpoint_state: CheckpointState) -> void:
	if not checkpoint_state or not checkpoint_state.validate():
		push_error("[CheckpointSystem] Cannot register invalid checkpoint state")
		return
	
	_reached_checkpoints.append(checkpoint_state)
	_current_checkpoint = checkpoint_state
	
	print("[CheckpointSystem] Manually registered checkpoint: %s" % checkpoint_state.checkpoint_id)


## Obtiene el estado de un checkpoint alcanzado previamente
func get_checkpoint_state(checkpoint_id: String) -> CheckpointState:
	for checkpoint in _reached_checkpoints:
		if checkpoint.checkpoint_id == checkpoint_id:
			return checkpoint
	
	return null


# ==============================================
# INTEGRACIÓN CON DIALOGUE SYSTEM
# ==============================================

## Actualiza el DialogueSystem tras aplicar checkpoint
## (Futuro: puede recargar diálogos basados en nuevo estado)
func update_dialogue_system() -> void:
	print("[CheckpointSystem] Updating DialogueSystem with new narrative state...")
	
	# Por ahora, simplemente terminar cualquier diálogo activo
	if Dialogue.is_active():
		print("  [CheckpointSystem] Ending active dialogue")
		Dialogue.end_dialogue()
	
	# Aquí podrían añadirse más acciones:
	# - Recargar árboles de diálogo
	# - Actualizar opciones disponibles
	# - Invalidar caché de condiciones
	
	print("  [CheckpointSystem] DialogueSystem updated")


# ==============================================
# SAVE/LOAD SUPPORT
# ==============================================

## Obtiene snapshot para SaveSystem
func get_save_state() -> Dictionary:
	var checkpoints_data = []
	
	for checkpoint in _reached_checkpoints:
		checkpoints_data.append(checkpoint.to_dict())
	
	return {
		"reached_checkpoints": checkpoints_data,
		"current_checkpoint": _current_checkpoint.checkpoint_id if _current_checkpoint else ""
	}


## Restaura estado desde SaveSystem
func load_save_state(save_data: Dictionary) -> void:
	print("[CheckpointSystem] Loading checkpoint state from save...")
	
	# Limpiar estado actual
	_reached_checkpoints.clear()
	_current_checkpoint = null
	
	# Restaurar checkpoints alcanzados
	var checkpoints_data = save_data.get("reached_checkpoints", [])
	for cp_data in checkpoints_data:
		var checkpoint_state = CheckpointState.from_dict(cp_data)
		if checkpoint_state.validate():
			_reached_checkpoints.append(checkpoint_state)
			print("  [CheckpointSystem] Restored checkpoint: %s" % checkpoint_state.checkpoint_id)
	
	# Restaurar checkpoint actual
	var current_id = save_data.get("current_checkpoint", "")
	if not current_id.is_empty():
		_current_checkpoint = get_checkpoint_state(current_id)
		if _current_checkpoint:
			print("  [CheckpointSystem] Current checkpoint: %s" % current_id)
	
	print("[CheckpointSystem] Loaded %d checkpoints from save" % _reached_checkpoints.size())
