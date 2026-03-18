extends Node

## Tests del NarrativeDebugViewModel

func _ready():
	print("\n=== Testing NarrativeDebugViewModel ===")
	
	await get_tree().process_frame
	
	test_viewmodel_initialization()
	test_viewmodel_refresh()
	test_viewmodel_with_checkpoint()
	test_viewmodel_display_dict()
	
	print("\n=== NarrativeDebugViewModel tests complete ===\n")


func test_viewmodel_initialization():
	print("\n--- Test: ViewModel Initialization ---")
	
	var vm = NarrativeDebugViewModel.new()
	
	assert(vm != null, "ViewModel should be created")
	assert(vm.validate_systems(), "Systems should be available")
	assert(vm.current_checkpoint.is_empty(), "No checkpoint initially")
	assert(vm.active_flags.is_empty(), "No flags initially")
	
	print("✓ ViewModel Initialization OK")


func test_viewmodel_refresh():
	print("\n--- Test: ViewModel Refresh ---")
	
	# Limpiar estado
	Narrative.clear_all()
	Checkpoints.reset()
	
	# Crear estado
	Narrative.set_flag("TEST_FLAG")
	Narrative.set_variable("test_var", 42)
	Narrative.register_event("TEST_EVENT")
	
	# Crear ViewModel y refrescar
	var vm = NarrativeDebugViewModel.new()
	vm.refresh_from_systems()
	
	# Verificar datos
	assert(vm.active_flags.size() == 1, "Should have 1 flag")
	assert("TEST_FLAG" in vm.active_flags, "Should have TEST_FLAG")
	assert(vm.variables.has("test_var"), "Should have test_var")
	assert(vm.variables["test_var"] == 42, "Variable value should match")
	assert(vm.events_completed.size() == 1, "Should have 1 event")
	
	print("  Flags: " + str(vm.active_flags))
	print("  Variables: " + str(vm.variables))
	print("  Events: " + str(vm.events_completed))
	
	print("✓ ViewModel Refresh OK")


func test_viewmodel_with_checkpoint():
	print("\n--- Test: ViewModel with Checkpoint ---")
	
	# Limpiar estado
	Narrative.clear_all()
	Checkpoints.reset()
	
	# Crear estado y aplicar checkpoint
	Narrative.set_flag("PRINCE_MET")
	Narrative.set_variable("reputation_quest1", 15.0)
	Narrative.set_variable("reputation_quest2", 10.0)
	
	var cp = Checkpoints.apply_checkpoint("ACT1_END")
	assert(cp != null, "Checkpoint should be applied")
	
	# Refrescar ViewModel
	var vm = NarrativeDebugViewModel.new()
	vm.refresh_from_systems()
	
	# Verificar checkpoint
	assert(vm.current_checkpoint == "ACT1_END", "Current checkpoint should be ACT1_END")
	assert(vm.reached_checkpoints.size() == 1, "Should have 1 checkpoint reached")
	assert("ACT1_END" in vm.reached_checkpoints, "Should include ACT1_END")
	
	# Verificar vectores consolidados
	assert(vm.consolidated_vectors.has("reputation"), "Should have reputation vector")
	
	var rep_vector = vm.consolidated_vectors["reputation"]
	print("  Reputation vector: " + str(rep_vector))
	
	assert(rep_vector.has("value"), "Vector should have value")
	assert(rep_vector.has("min"), "Vector should have min")
	assert(rep_vector.has("max"), "Vector should have max")
	assert(rep_vector.has("percentage"), "Vector should have percentage")
	
	# Verificar rango (según checkpoints.json: -100 a 100)
	assert(rep_vector["min"] == -100.0, "Min should be -100")
	assert(rep_vector["max"] == 100.0, "Max should be 100")
	
	print("✓ ViewModel with Checkpoint OK")


func test_viewmodel_display_dict():
	print("\n--- Test: ViewModel Display Dict ---")
	
	# Limpiar estado
	Narrative.clear_all()
	Checkpoints.reset()
	
	# Crear estado simple
	Narrative.set_flag("FLAG1")
	Narrative.set_flag("FLAG2")
	Narrative.set_variable("var1", 100)
	
	var vm = NarrativeDebugViewModel.new()
	vm.refresh_from_systems()
	
	var display = vm.to_display_dict()
	
	# Verificar estructura
	assert(display.has("current_checkpoint"), "Should have current_checkpoint")
	assert(display.has("active_flags"), "Should have active_flags")
	assert(display.has("variables"), "Should have variables")
	assert(display.has("consolidated_vectors"), "Should have consolidated_vectors")
	assert(display.has("stats"), "Should have stats")
	
	# Verificar stats
	var stats = display["stats"]
	assert(stats["flags_count"] == 2, "Should count 2 flags")
	assert(stats["variables_count"] == 1, "Should count 1 variable")
	
	print("  Display dict keys: " + str(display.keys()))
	print("  Stats: " + str(stats))
	
	print("✓ ViewModel Display Dict OK")
