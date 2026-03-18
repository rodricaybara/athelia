extends Node

## Test de Consolidación de Vectores
## Prueba consolidación, normalización y limpieza

func _ready():
	print("\n=== Testing Checkpoint Consolidation ===")
	
	# Esperar un frame para inicialización
	await get_tree().process_frame
	
	test_vector_consolidation()
	test_value_normalization()
	test_dispersed_cleanup()
	test_full_consolidation_flow()
	
	print("\n=== Checkpoint Consolidation tests complete ===\n")


func test_vector_consolidation():
	print("\n--- Test: Vector Consolidation ---")
	
	# Limpiar estado
	Narrative.clear_all()
	Checkpoints.reset()
	
	# Simular variables dispersas para "reputation"
	Narrative.set_variable("reputation", 10.0)
	Narrative.set_variable("reputation_act1_a", 5.0)
	Narrative.set_variable("reputation_act1_b", 3.0)
	Narrative.set_variable("reputation_act1_c", 2.0)
	
	# Simular variables dispersas para "community"
	Narrative.set_variable("community", 0.0)
	Narrative.set_variable("community_helped", 4.0)
	Narrative.set_variable("community_defended", 3.0)
	
	# Variables no relacionadas
	Narrative.set_variable("gold", 150.0)
	Narrative.set_variable("magic_power", 5.0)
	
	print("  Initial state:")
	print("    reputation vars: reputation=10, _a=5, _b=3, _c=2")
	print("    community vars: community=0, _helped=4, _defended=3")
	
	# Obtener checkpoint definition
	var checkpoint_def = CheckpointDB.get_checkpoint("ACT1_END")
	assert(checkpoint_def != null, "Should have ACT1_END checkpoint")
	
	# Consolidar vectores
	var consolidated = Checkpoints.consolidate_vectors(checkpoint_def)
	
	# Verificar consolidación
	assert(consolidated.has("reputation"), "Should consolidate reputation")
	assert(consolidated["reputation"] == 20.0, "Reputation should be 10+5+3+2=20")
	
	assert(consolidated.has("community"), "Should consolidate community")
	assert(consolidated["community"] == 7.0, "Community should be 0+4+3=7")
	
	assert(consolidated.has("cynicism"), "Should consolidate cynicism")
	assert(consolidated["cynicism"] == 0.0, "Cynicism should be 0 (no vars)")
	
	print("  Consolidated vectors:")
	print("    reputation = %.1f (expected 20.0)" % consolidated["reputation"])
	print("    community = %.1f (expected 7.0)" % consolidated["community"])
	print("    cynicism = %.1f (expected 0.0)" % consolidated["cynicism"])
	
	print("✓ Vector Consolidation OK")


func test_value_normalization():
	print("\n--- Test: Value Normalization ---")
	
	# Limpiar estado
	Narrative.clear_all()
	Checkpoints.reset()
	
	# Simular valores que exceden rangos
	Narrative.set_variable("reputation", 150.0)  # Rango: -100 a 100
	Narrative.set_variable("community", 75.0)     # Rango: 0 a 50
	Narrative.set_variable("cynicism", -10.0)     # Rango: 0 a 50
	
	print("  Before normalization:")
	print("    reputation = 150 (range: -100 to 100)")
	print("    community = 75 (range: 0 to 50)")
	print("    cynicism = -10 (range: 0 to 50)")
	
	# Obtener checkpoint
	var checkpoint_def = CheckpointDB.get_checkpoint("ACT1_END")
	
	# Consolidar
	var consolidated = Checkpoints.consolidate_vectors(checkpoint_def)
	
	print("  After consolidation (before normalization):")
	print("    reputation = %.1f" % consolidated["reputation"])
	print("    community = %.1f" % consolidated["community"])
	print("    cynicism = %.1f" % consolidated["cynicism"])
	
	# Normalizar
	Checkpoints.normalize_values(consolidated, checkpoint_def)
	
	print("  After normalization:")
	print("    reputation = %.1f (clamped to 100)" % consolidated["reputation"])
	print("    community = %.1f (clamped to 50)" % consolidated["community"])
	print("    cynicism = %.1f (clamped to 0)" % consolidated["cynicism"])
	
	# Verificar normalización
	assert(consolidated["reputation"] == 100.0, "Reputation should be clamped to 100")
	assert(consolidated["community"] == 50.0, "Community should be clamped to 50")
	assert(consolidated["cynicism"] == 0.0, "Cynicism should be clamped to 0")
	
	print("✓ Value Normalization OK")


func test_dispersed_cleanup():
	print("\n--- Test: Dispersed Variables Cleanup ---")
	
	# Limpiar estado
	Narrative.clear_all()
	Checkpoints.reset()
	
	# Crear variables dispersas
	Narrative.set_variable("reputation", 10.0)
	Narrative.set_variable("reputation_act1_a", 5.0)
	Narrative.set_variable("reputation_act1_b", 3.0)
	Narrative.set_variable("community_helped", 4.0)
	Narrative.set_variable("gold", 150.0)  # No debe limpiarse
	
	var vars_before = Narrative.get_all_variables()
	print("  Variables before cleanup: %d" % vars_before.size())
	print("    " + str(vars_before.keys()))  # ✅ CORREGIDO
	
	# Limpiar variables dispersas de reputation y community
	Checkpoints.cleanup_dispersed_variables(["reputation", "community"])
	
	var vars_after = Narrative.get_all_variables()
	print("  Variables after cleanup: %d" % vars_after.size())
	print("    " + str(vars_after.keys()))
	
	# Verificar limpieza
	assert(not Narrative.has_variable("reputation_act1_a"), "Should remove reputation_act1_a")
	assert(not Narrative.has_variable("reputation_act1_b"), "Should remove reputation_act1_b")
	assert(not Narrative.has_variable("community_helped"), "Should remove community_helped")
	
	# Verificar que se mantienen las importantes
	assert(Narrative.has_variable("reputation"), "Should keep reputation")
	assert(Narrative.has_variable("gold"), "Should keep gold")
	
	print("✓ Dispersed Variables Cleanup OK")


func test_full_consolidation_flow():
	print("\n--- Test: Full Consolidation Flow ---")
	
	# Limpiar estado
	Narrative.clear_all()
	Checkpoints.reset()
	
	# Simular Acto 1 completo con variables dispersas
	print("  Simulating Act 1 with dispersed variables...")
	
	Narrative.set_variable("reputation_quest1", 10.0)
	Narrative.set_variable("reputation_quest2", 5.0)
	Narrative.set_variable("reputation_dialogue", 3.0)
	Narrative.set_variable("community_helped_village", 8.0)
	Narrative.set_variable("community_defended_city", 4.0)
	Narrative.set_variable("cynicism_betrayal", 2.0)
	Narrative.set_variable("gold", 150.0)
	
	var initial_vars = Narrative.get_all_variables()
	print("    Initial variables: %d" % initial_vars.size())
	
	# Obtener checkpoint
	var checkpoint_def = CheckpointDB.get_checkpoint("ACT1_END")
	
	# 1. Consolidar vectores
	var consolidated = Checkpoints.consolidate_vectors(checkpoint_def)
	
	print("  Consolidated vectors:")
	for vector_name in consolidated.keys():
		print("    %s = %.1f" % [vector_name, consolidated[vector_name]])
	
	# 2. Normalizar
	Checkpoints.normalize_values(consolidated, checkpoint_def)
	
	print("  After normalization:")
	for vector_name in consolidated.keys():
		print("    %s = %.1f" % [vector_name, consolidated[vector_name]])
	
	# 3. Aplicar vectores consolidados al estado
	Checkpoints.apply_consolidated_vectors(consolidated)
	
	# 4. Limpiar variables dispersas
	Checkpoints.cleanup_dispersed_variables(checkpoint_def.accumulated_vectors)
	
	# Verificar estado final
	var final_vars = Narrative.get_all_variables()
	print("  Final variables: %d" % final_vars.size())
	print("    " + str(final_vars.keys()))
	
	# Verificar que tenemos los vectores consolidados
	assert(Narrative.has_variable("reputation"), "Should have reputation")
	assert(Narrative.has_variable("community"), "Should have community")
	assert(Narrative.has_variable("cynicism"), "Should have cynicism")
	
	# Verificar valores correctos
	assert(Narrative.get_variable("reputation") == 18.0, "Reputation should be 10+5+3=18")
	assert(Narrative.get_variable("community") == 12.0, "Community should be 8+4=12")
	assert(Narrative.get_variable("cynicism") == 2.0, "Cynicism should be 2")
	
	# Verificar que gold se mantiene
	assert(Narrative.get_variable("gold") == 150.0, "Gold should remain")
	
	# Verificar que las dispersas se eliminaron
	assert(not Narrative.has_variable("reputation_quest1"), "Dispersed vars should be removed")
	assert(not Narrative.has_variable("community_helped_village"), "Dispersed vars should be removed")
	
	print("  ✓ Full consolidation flow successful")
	print("  ✓ Dispersed variables consolidated and cleaned")
	print("  ✓ Important variables preserved")
	
	print("✓ Full Consolidation Flow OK")
