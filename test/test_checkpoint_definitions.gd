extends Node

## Test de CheckpointDefinitions
## Prueba carga desde JSON, validación y acceso

func _ready():
	print("\n=== Testing CheckpointDefinitions ===")
	
	# Esperar un frame para que CheckpointDB se inicialice
	await get_tree().process_frame
	
	test_checkpoint_loading()
	test_checkpoint_data()
	test_checkpoint_validation()
	test_checkpoint_state()
	
	print("\n=== CheckpointDefinitions tests complete ===\n")


func test_checkpoint_loading():
	print("\n--- Test: Checkpoint Loading ---")
	
	# Verificar que se cargaron checkpoints
	var checkpoint_count = CheckpointDB.list_checkpoints().size()
	print("  Loaded %d checkpoints" % checkpoint_count)
	assert(checkpoint_count > 0, "Should have loaded checkpoints from JSON")
	
	# Verificar checkpoints específicos
	assert(CheckpointDB.has_checkpoint("ACT1_END"), "Should have ACT1_END")
	assert(CheckpointDB.has_checkpoint("ACT2_START"), "Should have ACT2_START")
	assert(CheckpointDB.has_checkpoint("ACT2_END"), "Should have ACT2_END")
	
	print("✓ Checkpoint Loading OK")


func test_checkpoint_data():
	print("\n--- Test: Checkpoint Data ---")
	
	var checkpoint = CheckpointDB.get_checkpoint("ACT1_END")
	assert(checkpoint != null, "Should retrieve checkpoint")
	
	# Verificar estructura básica
	assert(checkpoint.id == "ACT1_END", "ID should match")
	assert(not checkpoint.description.is_empty(), "Should have description")
	
	print("  Checkpoint: %s" % checkpoint.id)
	print("  Description: %s" % checkpoint.description)
	
	# Verificar vectores acumulados
	assert(checkpoint.accumulated_vectors.size() > 0, "Should have accumulated vectors")
	assert("reputation" in checkpoint.accumulated_vectors, "Should track reputation")
	assert("community" in checkpoint.accumulated_vectors, "Should track community")
	assert("cynicism" in checkpoint.accumulated_vectors, "Should track cynicism")
	
	print("  Accumulated vectors: %s" % checkpoint.accumulated_vectors)
	
	# Verificar flags preservados
	assert(checkpoint.flags_preserved.size() > 0, "Should have flags to preserve")
	assert("PRINCE_MET" in checkpoint.flags_preserved, "Should preserve PRINCE_MET")
	
	print("  Flags preserved: %s" % checkpoint.flags_preserved)
	
	# Verificar variables preservadas
	assert(checkpoint.variables_preserved.size() > 0, "Should have variables to preserve")
	assert("gold" in checkpoint.variables_preserved, "Should preserve gold")
	
	print("  Variables preserved: %s" % checkpoint.variables_preserved)
	
	# Verificar valores iniciales
	assert(checkpoint.initial_values.has("reputation"), "Should have initial reputation")
	assert(checkpoint.initial_values["reputation"] == 0, "Initial reputation should be 0")
	
	print("  Initial values: %s" % checkpoint.initial_values)
	
	# Verificar rangos de normalización
	assert(checkpoint.has_normalization_for("reputation"), "Should have normalization for reputation")
	var rep_range = checkpoint.get_normalization_range("reputation")
	assert(rep_range["min"] == -100, "Reputation min should be -100")
	assert(rep_range["max"] == 100, "Reputation max should be 100")
	
	print("  Normalization ranges: %d defined" % checkpoint.normalization_ranges.size())
	
	print("✓ Checkpoint Data OK")


func test_checkpoint_validation():
	print("\n--- Test: Checkpoint Validation ---")
	
	# Checkpoints válidos
	var cp1 = CheckpointDB.get_checkpoint("ACT1_END")
	assert(cp1.validate(), "ACT1_END should be valid")
	
	var cp2 = CheckpointDB.get_checkpoint("ACT2_START")
	assert(cp2.validate(), "ACT2_START should be valid")
	
	# Checkpoint con rangos válidos
	var cp_with_ranges = CheckpointDB.get_checkpoint("ACT2_END")
	assert(cp_with_ranges.validate(), "Checkpoint with ranges should be valid")
	
	print("  All loaded checkpoints are valid")
	
	print("✓ Checkpoint Validation OK")


func test_checkpoint_state():
	print("\n--- Test: CheckpointState ---")
	
	# Crear estado de checkpoint
	var state = CheckpointState.new("ACT1_END")
	
	# Poblar con datos
	state.accumulated_vectors["reputation"] = 45
	state.accumulated_vectors["community"] = 12
	state.flags_preserved.append("PRINCE_MET")
	state.flags_preserved.append("ACADEMY_JOINED")
	state.variables_preserved["gold"] = 150
	state.variables_preserved["reputation"] = 45
	
	print("  Created checkpoint state: %s" % state)
	
	# Validar
	assert(state.validate(), "CheckpointState should be valid")
	
	# Convertir a Dictionary
	var state_dict = state.to_dict()
	assert(state_dict["checkpoint_id"] == "ACT1_END", "Dictionary should preserve ID")
	assert(state_dict["accumulated_vectors"]["reputation"] == 45, "Should preserve vectors")
	assert("PRINCE_MET" in state_dict["flags_preserved"], "Should preserve flags")
	
	print("  State dict: %s" % state_dict)
	
	# Restaurar desde Dictionary
	var restored = CheckpointState.from_dict(state_dict)
	assert(restored.checkpoint_id == "ACT1_END", "Restored ID should match")
	assert(restored.accumulated_vectors["reputation"] == 45, "Restored vectors should match")
	assert("PRINCE_MET" in restored.flags_preserved, "Restored flags should match")
	assert(restored.variables_preserved["gold"] == 150, "Restored variables should match")
	
	print("  Restored state: %s" % restored)
	
	print("✓ CheckpointState OK")
