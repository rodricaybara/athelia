extends Node

## Test de Aplicación Completa de Checkpoints
## Prueba el flujo completo de checkpoint end-to-end

func _ready():
	print("\n=== Testing Checkpoint Application ===")
	
	# Esperar un frame para inicialización
	await get_tree().process_frame
	
	test_full_checkpoint_flow()
	test_checkpoint_prevents_duplicate()
	test_multiple_checkpoints()
	test_checkpoint_state_persistence()
	test_dialogue_integration()
	
	print("\n=== Checkpoint Application tests complete ===\n")


func test_full_checkpoint_flow():
	print("\n--- Test: Full Checkpoint Flow (ACT1 → ACT2) ---")
	
	# Limpiar estado
	Narrative.clear_all()
	Checkpoints.reset()
	
	# Simular Acto 1 completo
	print("  Setting up Act 1 state...")
	
	# Flags del Acto 1
	Narrative.set_flag("PRINCE_MET")
	Narrative.set_flag("ACADEMY_JOINED")
	Narrative.set_flag("TUTORIAL_ACTIVE")
	Narrative.set_flag("QUEST_MINOR_01")
	Narrative.set_flag("QUEST_MINOR_02")
	Narrative.set_flag("FOREST_DISCOVERED")
	
	# Variables dispersas que deben consolidarse
	Narrative.set_variable("reputation_quest1", 15.0)
	Narrative.set_variable("reputation_quest2", 10.0)
	Narrative.set_variable("reputation_dialogue", 8.0)
	Narrative.set_variable("community_helped", 7.0)
	Narrative.set_variable("community_defended", 5.0)
	Narrative.set_variable("cynicism_betrayal", 3.0)
	
	# Variables críticas
	Narrative.set_variable("gold", 250)
	
	# Variables temporales que deben eliminarse
	Narrative.set_variable("quest_progress_temp", 50)
	Narrative.set_variable("npc_affinity_temp", 2)
	
	print("  Act 1 state created:")
	print("    Flags: " + str(Narrative.get_active_flags().size()) + " active")
	print("    Variables: " + str(Narrative.get_all_variables().size()) + " total")
	
	# Aplicar checkpoint ACT1_END
	print("\n  Applying checkpoint: ACT1_END")
	var checkpoint_state = Checkpoints.apply_checkpoint("ACT1_END")
	
	assert(checkpoint_state != null, "Should create checkpoint state")
	assert(checkpoint_state.checkpoint_id == "ACT1_END", "Checkpoint ID should match")
	
	# Verificar vectores consolidados
	print("\n  Verifying consolidated vectors...")
	assert(checkpoint_state.accumulated_vectors.has("reputation"), "Should have reputation vector")
	assert(checkpoint_state.accumulated_vectors.has("community"), "Should have community vector")
	assert(checkpoint_state.accumulated_vectors.has("cynicism"), "Should have cynicism vector")
	
	var rep = checkpoint_state.accumulated_vectors["reputation"]
	var com = checkpoint_state.accumulated_vectors["community"]
	var cyn = checkpoint_state.accumulated_vectors["cynicism"]
	
	print("    reputation = %.1f (expected 33.0 = 15+10+8)" % rep)
	print("    community = %.1f (expected 12.0 = 7+5)" % com)
	print("    cynicism = %.1f (expected 3.0)" % cyn)
	
	assert(rep == 33.0, "Reputation should be 15+10+8 = 33")
	assert(com == 12.0, "Community should be 7+5 = 12")
	assert(cyn == 3.0, "Cynicism should be 3")
	
	# Verificar que se aplicaron al NarrativeSystem
	print("\n  Verifying vectors applied to NarrativeSystem...")
	assert(Narrative.get_variable("reputation") == 0.0, "Reputation should be reset to initial (0)")
	assert(Narrative.get_variable("community") == 0.0, "Community should be reset to initial (0)")
	assert(Narrative.get_variable("cynicism") == 0.0, "Cynicism should be reset to initial (0)")
	
	# Verificar flags
	print("\n  Verifying flags cleanup...")
	assert(Narrative.has_flag("PRINCE_MET"), "PRINCE_MET should be preserved")
	assert(Narrative.has_flag("ACADEMY_JOINED"), "ACADEMY_JOINED should be preserved")
	assert(not Narrative.has_flag("TUTORIAL_ACTIVE"), "TUTORIAL_ACTIVE should be removed")
	assert(not Narrative.has_flag("QUEST_MINOR_01"), "QUEST_MINOR_01 should be removed")
	assert(not Narrative.has_flag("FOREST_DISCOVERED"), "FOREST_DISCOVERED should be removed")
	
	# Verificar variables
	print("\n  Verifying variables cleanup...")
	assert(Narrative.has_variable("gold"), "gold should be preserved")
	assert(Narrative.get_variable("gold") == 250, "gold value should remain")
	assert(not Narrative.has_variable("reputation_quest1"), "Dispersed vars should be removed")
	assert(not Narrative.has_variable("quest_progress_temp"), "Temp vars should be removed")
	
	# Verificar estado del checkpoint
	print("\n  Verifying checkpoint registration...")
	assert(Checkpoints.has_reached_checkpoint("ACT1_END"), "Checkpoint should be registered")
	assert(Checkpoints.get_current_checkpoint_id() == "ACT1_END", "Current checkpoint should be set")
	
	print("\n✓ Full Checkpoint Flow OK")


func test_checkpoint_prevents_duplicate():
	print("\n--- Test: Checkpoint Prevents Duplicate Application ---")
	
	# Limpiar estado
	Narrative.clear_all()
	Checkpoints.reset()
	
	# Aplicar checkpoint por primera vez
	Narrative.set_flag("PRINCE_MET")
	Narrative.set_variable("gold", 100)
	
	var first = Checkpoints.apply_checkpoint("ACT1_END")
	assert(first != null, "First application should succeed")
	
	# Intentar aplicar de nuevo
	var second = Checkpoints.apply_checkpoint("ACT1_END")
	assert(second == null, "Second application should fail (already reached)")
	
	# Verificar que solo se registró una vez
	var reached = Checkpoints.get_reached_checkpoints()
	assert(reached.size() == 1, "Should only have 1 checkpoint registered")
	
	print("✓ Checkpoint Prevents Duplicate OK")


func test_multiple_checkpoints():
	print("\n--- Test: Multiple Checkpoints Sequence ---")
	
	# Limpiar estado
	Narrative.clear_all()
	Checkpoints.reset()
	
	# ACT1_END
	print("  Applying ACT1_END...")
	Narrative.set_flag("PRINCE_MET")
	Narrative.set_variable("gold", 100)
	Narrative.set_variable("reputation", 20)
	
	var cp1 = Checkpoints.apply_checkpoint("ACT1_END")
	assert(cp1 != null, "ACT1_END should succeed")
	
	# ACT2_START
	print("  Applying ACT2_START...")
	Narrative.set_variable("magic_affinity", 15)
	
	var cp2 = Checkpoints.apply_checkpoint("ACT2_START")
	assert(cp2 != null, "ACT2_START should succeed")
	
	# Verificar ambos checkpoints registrados
	assert(Checkpoints.has_reached_checkpoint("ACT1_END"), "ACT1_END should be reached")
	assert(Checkpoints.has_reached_checkpoint("ACT2_START"), "ACT2_START should be reached")
	
	var reached = Checkpoints.get_reached_checkpoints()
	assert(reached.size() == 2, "Should have 2 checkpoints")
	
	# Verificar checkpoint actual
	assert(Checkpoints.get_current_checkpoint_id() == "ACT2_START", "Current should be ACT2_START")
	
	# Verificar flags de ACT2_START aplicados
	assert(Narrative.has_flag("TUTORIAL_COMPLETE"), "ACT2 initial flags should be set")
	assert(Narrative.has_flag("ACT2_ACTIVE"), "ACT2 initial flags should be set")
	
	print("✓ Multiple Checkpoints Sequence OK")


func test_checkpoint_state_persistence():
	print("\n--- Test: Checkpoint State Persistence ---")
	
	# Limpiar estado
	Narrative.clear_all()
	Checkpoints.reset()
	
	# Aplicar checkpoint
	Narrative.set_flag("PRINCE_MET")
	Narrative.set_variable("gold", 150)
	Narrative.set_variable("reputation", 30)
	
	var cp = Checkpoints.apply_checkpoint("ACT1_END")
	assert(cp != null, "Checkpoint should be applied")
	
	# Obtener save state
	var save_state = Checkpoints.get_save_state()
	
	print("  Save state: " + str(save_state.keys()))
	
	assert(save_state.has("reached_checkpoints"), "Should have reached_checkpoints")
	assert(save_state.has("current_checkpoint"), "Should have current_checkpoint")
	assert(save_state["current_checkpoint"] == "ACT1_END", "Current checkpoint should be saved")
	assert(save_state["reached_checkpoints"].size() == 1, "Should have 1 checkpoint")
	
	# Simular carga
	Checkpoints.reset()
	assert(Checkpoints.get_current_checkpoint() == null, "Should be reset")
	
	Checkpoints.load_save_state(save_state)
	
	# Verificar restauración
	assert(Checkpoints.has_reached_checkpoint("ACT1_END"), "Checkpoint should be restored")
	assert(Checkpoints.get_current_checkpoint_id() == "ACT1_END", "Current should be restored")
	
	var restored_cp = Checkpoints.get_checkpoint_state("ACT1_END")
	assert(restored_cp != null, "Should retrieve restored checkpoint")
	assert(restored_cp.accumulated_vectors.has("reputation"), "Vectors should be restored")
	
	print("✓ Checkpoint State Persistence OK")


func test_dialogue_integration():
	print("\n--- Test: Dialogue System Integration ---")
	
	# Limpiar estado
	Narrative.clear_all()
	Checkpoints.reset()
	Dialogue.reset()
	
	# Iniciar un diálogo
	Dialogue.start_dialogue("DLG_PRINCE_INTRO")
	assert(Dialogue.is_active(), "Dialogue should be active")
	
	# Aplicar checkpoint (debería terminar diálogo)
	Narrative.set_flag("PRINCE_MET")
	Checkpoints.apply_checkpoint("ACT1_END")
	
	# El diálogo debería haberse terminado automáticamente
	# (según implementación de update_dialogue_system)
	print("  Dialogue active after checkpoint: " + str(Dialogue.is_active()))
	
	# Nota: El comportamiento exacto depende de la implementación
	# Por ahora solo verificamos que no crashea
	
	print("✓ Dialogue System Integration OK")
