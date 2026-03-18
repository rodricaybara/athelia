extends Node

## Test de Limpieza de Flags y Variables
## Prueba limpieza selectiva y aplicación de estado inicial

func _ready():
	print("\n=== Testing Checkpoint Cleanup ===")
	
	# Esperar un frame para inicialización
	await get_tree().process_frame
	
	test_flag_cleanup()
	test_flag_preservation()
	test_initial_flags()
	test_variable_cleanup()
	test_variable_preservation()
	test_initial_values()
	test_full_cleanup_flow()
	
	print("\n=== Checkpoint Cleanup tests complete ===\n")


func test_flag_cleanup():
	print("\n--- Test: Flag Cleanup ---")
	
	# Limpiar estado
	Narrative.clear_all()
	Checkpoints.reset()
	
	# Simular flags del Acto 1
	Narrative.set_flag("PRINCE_MET")           # Crítico - debe preservarse
	Narrative.set_flag("ACADEMY_JOINED")       # Crítico - debe preservarse
	Narrative.set_flag("TUTORIAL_ACTIVE")      # Temporal - debe eliminarse
	Narrative.set_flag("QUEST_MINOR_01")       # Temporal - debe eliminarse
	Narrative.set_flag("QUEST_MINOR_02")       # Temporal - debe eliminarse
	Narrative.set_flag("DIALOGUE_NPC_01")      # Temporal - debe eliminarse
	
	var flags_before = Narrative.get_active_flags()
	print("  Flags before cleanup: %d" % flags_before.size())
	print("    " + str(flags_before))
	
	# Obtener checkpoint
	var checkpoint_def = CheckpointDB.get_checkpoint("ACT1_END")
	
	# Realizar limpieza
	var stats = Checkpoints.cleanup_flags(checkpoint_def)
	
	var flags_after = Narrative.get_active_flags()
	print("  Flags after cleanup: %d" % flags_after.size())
	print("    " + str(flags_after))
	
	# Verificar estadísticas
	assert(stats["total_before"] == 6, "Should start with 6 flags")
	assert(stats["preserved"] == 2, "Should preserve 2 flags")
	assert(stats["removed"] == 4, "Should remove 4 flags")
	
	print("  Stats: preserved=%d, removed=%d" % [stats["preserved"], stats["removed"]])
	
	# Verificar flags críticos preservados
	assert(Narrative.has_flag("PRINCE_MET"), "PRINCE_MET should be preserved")
	assert(Narrative.has_flag("ACADEMY_JOINED"), "ACADEMY_JOINED should be preserved")
	
	# Verificar flags temporales eliminados
	assert(not Narrative.has_flag("TUTORIAL_ACTIVE"), "TUTORIAL_ACTIVE should be removed")
	assert(not Narrative.has_flag("QUEST_MINOR_01"), "QUEST_MINOR_01 should be removed")
	assert(not Narrative.has_flag("QUEST_MINOR_02"), "QUEST_MINOR_02 should be removed")
	assert(not Narrative.has_flag("DIALOGUE_NPC_01"), "DIALOGUE_NPC_01 should be removed")
	
	print("✓ Flag Cleanup OK")


func test_flag_preservation():
	print("\n--- Test: Flag Preservation ---")
	
	# Limpiar estado
	Narrative.clear_all()
	Checkpoints.reset()
	
	# Solo flags críticos
	Narrative.set_flag("PRINCE_MET")
	Narrative.set_flag("ACADEMY_JOINED")
	Narrative.set_flag("FOREST_DISCOVERED")  # No está en ACT1_END pero sí en ACT2_START
	
	print("  Initial flags: " + str(Narrative.get_active_flags()))
	
	# Checkpoint ACT1_END
	var cp1 = CheckpointDB.get_checkpoint("ACT1_END")
	var stats1 = Checkpoints.cleanup_flags(cp1)
	
	print("  After ACT1_END cleanup: " + str(Narrative.get_active_flags()))
	print("    preserved=%d, removed=%d" % [stats1["preserved"], stats1["removed"]])
	
	# Verificar que FOREST_DISCOVERED se eliminó (no está en preserved de ACT1_END)
	assert(not Narrative.has_flag("FOREST_DISCOVERED"), "FOREST_DISCOVERED should be removed by ACT1_END")
	assert(Narrative.has_flag("PRINCE_MET"), "PRINCE_MET should remain")
	assert(Narrative.has_flag("ACADEMY_JOINED"), "ACADEMY_JOINED should remain")
	
	print("✓ Flag Preservation OK")


func test_initial_flags():
	print("\n--- Test: Initial Flags ---")
	
	# Limpiar estado
	Narrative.clear_all()
	Checkpoints.reset()
	
	# Estado después de ACT1
	Narrative.set_flag("PRINCE_MET")
	Narrative.set_flag("ACADEMY_JOINED")
	
	print("  Flags before applying initial: " + str(Narrative.get_active_flags()))
	
	# Obtener checkpoint ACT2_START
	var checkpoint_def = CheckpointDB.get_checkpoint("ACT2_START")
	
	# Aplicar flags iniciales
	Checkpoints.apply_initial_flags(checkpoint_def)
	
	var flags_after = Narrative.get_active_flags()
	print("  Flags after applying initial: " + str(flags_after))
	
	# Verificar nuevos flags
	assert(Narrative.has_flag("TUTORIAL_COMPLETE"), "Should set TUTORIAL_COMPLETE")
	assert(Narrative.has_flag("ACT2_ACTIVE"), "Should set ACT2_ACTIVE")
	
	# Verificar que los anteriores se mantienen
	assert(Narrative.has_flag("PRINCE_MET"), "Previous flags should remain")
	assert(Narrative.has_flag("ACADEMY_JOINED"), "Previous flags should remain")
	
	print("✓ Initial Flags OK")


func test_variable_cleanup():
	print("\n--- Test: Variable Cleanup ---")
	
	# Limpiar estado
	Narrative.clear_all()
	Checkpoints.reset()
	
	# Simular variables del Acto 1
	Narrative.set_variable("gold", 150)                # Crítica - debe preservarse
	Narrative.set_variable("reputation", 45)           # Vector - debe preservarse
	Narrative.set_variable("community", 12)            # Vector - debe preservarse
	Narrative.set_variable("cynicism", 5)              # Vector - debe preservarse
	Narrative.set_variable("quest_progress_01", 75)    # Temporal - debe eliminarse
	Narrative.set_variable("dialogue_choice_a", 1)     # Temporal - debe eliminarse
	Narrative.set_variable("temp_counter", 3)          # Temporal - debe eliminarse
	
	var vars_before = Narrative.get_all_variables()
	print("  Variables before cleanup: %d" % vars_before.size())
	print("    " + str(vars_before.keys()))
	
	# Obtener checkpoint
	var checkpoint_def = CheckpointDB.get_checkpoint("ACT1_END")
	
	# Realizar limpieza
	var stats = Checkpoints.cleanup_variables(checkpoint_def)
	
	var vars_after = Narrative.get_all_variables()
	print("  Variables after cleanup: %d" % vars_after.size())
	print("    " + str(vars_after.keys()))
	
	# Verificar estadísticas
	assert(stats["total_before"] == 7, "Should start with 7 variables")
	assert(stats["preserved"] == 4, "Should preserve 4 variables (gold + 3 vectors)")
	assert(stats["removed"] == 3, "Should remove 3 variables")
	
	print("  Stats: preserved=%d, removed=%d" % [stats["preserved"], stats["removed"]])
	
	# Verificar variables críticas preservadas
	assert(Narrative.has_variable("gold"), "gold should be preserved")
	assert(Narrative.has_variable("reputation"), "reputation vector should be preserved")
	assert(Narrative.has_variable("community"), "community vector should be preserved")
	assert(Narrative.has_variable("cynicism"), "cynicism vector should be preserved")
	
	# Verificar variables temporales eliminadas
	assert(not Narrative.has_variable("quest_progress_01"), "quest_progress_01 should be removed")
	assert(not Narrative.has_variable("dialogue_choice_a"), "dialogue_choice_a should be removed")
	assert(not Narrative.has_variable("temp_counter"), "temp_counter should be removed")
	
	print("✓ Variable Cleanup OK")


func test_variable_preservation():
	print("\n--- Test: Variable Preservation ---")
	
	# Limpiar estado
	Narrative.clear_all()
	Checkpoints.reset()
	
	# Solo variables críticas y vectores
	Narrative.set_variable("gold", 200)
	Narrative.set_variable("reputation", 50)
	Narrative.set_variable("community", 15)
	Narrative.set_variable("magic_power", 10)  # No preservada - debe eliminarse
	
	print("  Initial variables: " + str(Narrative.get_all_variables().keys()))
	
	# Checkpoint ACT1_END
	var checkpoint_def = CheckpointDB.get_checkpoint("ACT1_END")
	var stats = Checkpoints.cleanup_variables(checkpoint_def)
	
	print("  After cleanup: " + str(Narrative.get_all_variables().keys()))
	print("    preserved=%d, removed=%d" % [stats["preserved"], stats["removed"]])
	
	# Verificar preservación
	assert(Narrative.has_variable("gold"), "gold should be preserved")
	assert(Narrative.has_variable("reputation"), "reputation should be preserved")
	assert(Narrative.has_variable("community"), "community should be preserved")
	
	# Verificar eliminación
	assert(not Narrative.has_variable("magic_power"), "magic_power should be removed")
	
	print("✓ Variable Preservation OK")


func test_initial_values():
	print("\n--- Test: Initial Values ---")
	
	# Limpiar estado
	Narrative.clear_all()
	Checkpoints.reset()
	
	# Estado después de ACT1
	Narrative.set_variable("gold", 150)
	Narrative.set_variable("reputation", 45)
	
	print("  Variables before applying initial: " + str(Narrative.get_all_variables().keys()))
	
	# Obtener checkpoint ACT2_START
	var checkpoint_def = CheckpointDB.get_checkpoint("ACT2_START")
	
	# Aplicar valores iniciales
	Checkpoints.apply_initial_values(checkpoint_def)
	
	var vars_after = Narrative.get_all_variables()
	print("  Variables after applying initial: " + str(vars_after.keys()))
	
	# Verificar nuevos valores
	assert(Narrative.has_variable("magic_affinity"), "Should set magic_affinity")
	assert(Narrative.get_variable("magic_affinity") == 0, "magic_affinity should be 0")
	
	assert(Narrative.has_variable("discipline"), "Should set discipline")
	assert(Narrative.get_variable("discipline") == 0, "discipline should be 0")
	
	# Verificar que los anteriores se mantienen
	assert(Narrative.get_variable("gold") == 150, "Previous values should remain")
	assert(Narrative.get_variable("reputation") == 45, "Previous values should remain")
	
	print("✓ Initial Values OK")


func test_full_cleanup_flow():
	print("\n--- Test: Full Cleanup Flow ---")
	
	# Limpiar estado
	Narrative.clear_all()
	Checkpoints.reset()
	
	# Simular fin del Acto 1 con estado complejo
	print("  Simulating end of Act 1 with complex state...")
	
	# Flags
	Narrative.set_flag("PRINCE_MET")           # Crítico
	Narrative.set_flag("ACADEMY_JOINED")       # Crítico
	Narrative.set_flag("TUTORIAL_ACTIVE")      # Temporal
	Narrative.set_flag("QUEST_MINOR_01")       # Temporal
	Narrative.set_flag("DIALOGUE_TEMP")        # Temporal
	
	# Variables
	Narrative.set_variable("gold", 200)
	Narrative.set_variable("reputation", 50)
	Narrative.set_variable("community", 15)
	Narrative.set_variable("quest_temp", 5)
	Narrative.set_variable("npc_affinity_a", 3)
	
	print("    Initial state:")
	print("      Flags: " + str(Narrative.get_active_flags()))  # ✅ CORREGIDO
	print("      Variables: " + str(Narrative.get_all_variables().keys()))
	
	# Obtener checkpoint
	var checkpoint_def = CheckpointDB.get_checkpoint("ACT1_END")
	
	# Procesar flags (cleanup + initial)
	var flag_stats = Checkpoints.process_flags(checkpoint_def)
	
	# Procesar variables (cleanup + initial)
	var var_stats = Checkpoints.process_variables(checkpoint_def)
	
	print("  After full cleanup:")
	print("    Flags: " + str(Narrative.get_active_flags()))  # ✅ CORREGIDO
	print("    Variables: " + str(Narrative.get_all_variables().keys()))
	
	# Verificar flags
	assert(Narrative.has_flag("PRINCE_MET"), "Critical flag should remain")
	assert(Narrative.has_flag("ACADEMY_JOINED"), "Critical flag should remain")
	assert(not Narrative.has_flag("TUTORIAL_ACTIVE"), "Temp flag should be removed")
	assert(not Narrative.has_flag("QUEST_MINOR_01"), "Temp flag should be removed")
	
	# Verificar variables
	assert(Narrative.has_variable("gold"), "Critical var should remain")
	assert(Narrative.has_variable("reputation"), "Vector should remain")
	assert(Narrative.has_variable("community"), "Vector should remain")
	assert(not Narrative.has_variable("quest_temp"), "Temp var should be removed")
	assert(not Narrative.has_variable("npc_affinity_a"), "Temp var should be removed")
	
	# Verificar valores iniciales aplicados
	assert(Narrative.get_variable("reputation") == 0, "Initial value should be applied")
	assert(Narrative.get_variable("community") == 0, "Initial value should be applied")
	assert(Narrative.get_variable("cynicism") == 0, "Initial value should be applied")
	
	print("  ✓ Full cleanup successful")
	print("  ✓ Flags cleaned: %d removed, %d preserved" % [flag_stats["removed"], flag_stats["preserved"]])
	print("  ✓ Variables cleaned: %d removed, %d preserved" % [var_stats["removed"], var_stats["preserved"]])
	print("  ✓ Initial state applied")
	
	print("✓ Full Cleanup Flow OK")
