extends Node

## Test de Persistencia de Checkpoints (sin Player)
## Prueba guardado y carga del sistema de checkpoints aisladamente

func _ready():
	print("\n=== Testing Checkpoint Persistence (Isolated) ===")
	
	# Esperar un frame para inicialización
	await get_tree().process_frame
	
	test_checkpoint_serialization()
	test_multiple_checkpoints_serialization()
	test_narrative_state_snapshot()
	test_backwards_compatibility()
	
	print("\n=== Checkpoint Persistence tests complete ===\n")


func test_checkpoint_serialization():
	print("\n--- Test: Checkpoint Serialization (Manual) ---")
	
	# Limpiar estado
	Narrative.clear_all()
	Checkpoints.reset()
	
	# Crear estado narrativo
	print("  Creating narrative state...")
	Narrative.set_flag("PRINCE_MET")
	Narrative.set_flag("ACADEMY_JOINED")
	Narrative.set_variable("gold", 200)
	Narrative.set_variable("reputation", 50)
	Narrative.register_event("EVT_MEET_PRINCE")
	
	# Aplicar checkpoint
	print("  Applying checkpoint ACT1_END...")
	var checkpoint = Checkpoints.apply_checkpoint("ACT1_END")
	assert(checkpoint != null, "Checkpoint should be applied")
	
	# Obtener snapshot ANTES de limpiar
	var flags_before = Narrative.get_active_flags().duplicate()
	var vars_before = Narrative.get_all_variables().duplicate()
	var events_before = Narrative.get_completed_events().duplicate()
	var checkpoint_snapshot = Checkpoints.get_save_state()
	
	print("  State before serialization:")
	print("    Flags: %d" % flags_before.size())
	print("    Variables: %d" % vars_before.size())
	print("    Events: %d" % events_before.size())
	print("    Checkpoints: %d" % checkpoint_snapshot["reached_checkpoints"].size())
	
	# Limpiar estado completamente
	print("\n  Clearing all state...")
	Narrative.clear_all()
	Checkpoints.reset()
	
	assert(Narrative.get_active_flags().is_empty(), "Flags should be cleared")
	assert(Checkpoints.get_current_checkpoint() == null, "Checkpoints should be cleared")
	
	# Restaurar desde snapshot
	print("\n  Restoring from snapshot...")
	
	# Restaurar flags
	for flag in flags_before:
		Narrative.set_flag(flag)
	
	# Restaurar variables
	for var_name in vars_before.keys():
		Narrative.set_variable(var_name, vars_before[var_name])
	
	# Restaurar eventos
	for event_id in events_before:
		Narrative.register_event(event_id)
	
	# Restaurar checkpoints
	Checkpoints.load_save_state(checkpoint_snapshot)
	
	# Verificar estado restaurado
	var flags_after = Narrative.get_active_flags().size()
	var vars_after = Narrative.get_all_variables().size()
	var events_after = Narrative.get_completed_events().size()
	var cp_after = Checkpoints.get_current_checkpoint_id()
	
	print("\n  State after restoration:")
	print("    Flags: %d" % flags_after)
	print("    Variables: %d" % vars_after)
	print("    Events: %d" % events_after)
	print("    Current checkpoint: %s" % cp_after)
	
	# Verificar que coinciden
	assert(flags_after == flags_before.size(), "Flags count should match")
	assert(vars_after == vars_before.size(), "Variables count should match")
	assert(events_after == events_before.size(), "Events count should match")
	assert(cp_after == "ACT1_END", "Current checkpoint should match")
	
	# Verificar flags específicos
	assert(Narrative.has_flag("PRINCE_MET"), "PRINCE_MET should be restored")
	assert(Narrative.has_flag("ACADEMY_JOINED"), "ACADEMY_JOINED should be restored")
	
	# Verificar variables específicas
	assert(Narrative.has_variable("gold"), "gold should be restored")
	assert(Narrative.get_variable("gold") == 200, "gold value should be correct")
	
	# Verificar checkpoint
	assert(Checkpoints.has_reached_checkpoint("ACT1_END"), "Checkpoint should be restored")
	
	print("\n✓ Checkpoint Serialization OK")


func test_multiple_checkpoints_serialization():
	print("\n--- Test: Multiple Checkpoints Serialization ---")
	
	# Limpiar estado
	Narrative.clear_all()
	Checkpoints.reset()
	
	# Aplicar varios checkpoints
	print("  Applying multiple checkpoints...")
	
	Narrative.set_flag("PRINCE_MET")
	Narrative.set_variable("gold", 100)
	Checkpoints.apply_checkpoint("ACT1_END")
	
	Narrative.set_flag("ACADEMY_JOINED")
	Narrative.set_variable("magic_affinity", 20)
	Checkpoints.apply_checkpoint("ACT2_START")
	
	# Obtener snapshot
	var checkpoints_before = Checkpoints.get_reached_checkpoints().size()
	var snapshot = Checkpoints.get_save_state()
	
	print("  Checkpoints before serialization: %d" % checkpoints_before)
	print("  Snapshot checkpoints: %d" % snapshot["reached_checkpoints"].size())
	
	# Limpiar
	Checkpoints.reset()
	assert(Checkpoints.get_reached_checkpoints().size() == 0, "Should be cleared")
	
	# Restaurar
	Checkpoints.load_save_state(snapshot)
	
	# Verificar
	var checkpoints_after = Checkpoints.get_reached_checkpoints().size()
	print("  Checkpoints after restoration: %d" % checkpoints_after)
	
	assert(checkpoints_after == checkpoints_before, "Checkpoint count should match")
	assert(Checkpoints.has_reached_checkpoint("ACT1_END"), "ACT1_END should be restored")
	assert(Checkpoints.has_reached_checkpoint("ACT2_START"), "ACT2_START should be restored")
	assert(Checkpoints.get_current_checkpoint_id() == "ACT2_START", "Current checkpoint should be ACT2_START")
	
	print("✓ Multiple Checkpoints Serialization OK")


func test_narrative_state_snapshot():
	print("\n--- Test: Narrative State Snapshot ---")
	
	# Limpiar estado
	Narrative.clear_all()
	Checkpoints.reset()
	
	# Crear estado complejo
	print("  Creating complex narrative state...")
	
	# Flags
	Narrative.set_flag("PRINCE_MET")
	Narrative.set_flag("ACADEMY_JOINED")
	Narrative.set_flag("FOREST_DISCOVERED")
	
	# Variables
	Narrative.set_variable("gold", 350)
	Narrative.set_variable("reputation", 75)
	Narrative.set_variable("magic_affinity", 30)
	Narrative.set_variable("discipline", 15)
	
	# Eventos
	Narrative.register_event("EVT_MEET_PRINCE")
	Narrative.register_event("EVT_JOIN_ACADEMY")
	
	# Checkpoint con vectores consolidados
	Narrative.set_variable("reputation_quest1", 10)
	Narrative.set_variable("reputation_quest2", 5)
	var cp = Checkpoints.apply_checkpoint("ACT1_END")
	
	print("  State created:")
	print("    Flags: %d" % Narrative.get_active_flags().size())
	print("    Variables: %d" % Narrative.get_all_variables().size())
	print("    Events: %d" % Narrative.get_completed_events().size())
	print("    Checkpoint vectors: %d" % cp.accumulated_vectors.size())
	
	# Crear snapshot manualmente (simulando SaveData)
	var narrative_snapshot = {
		"flags": {},
		"variables": Narrative.get_all_variables().duplicate(),
		"completed_events": Narrative.get_completed_events().duplicate(),
		"checkpoints": Checkpoints.get_save_state()
	}
	
	# Convertir flags a Dictionary (como lo hace SaveSystem)
	for flag in Narrative.get_active_flags():
		narrative_snapshot["flags"][flag] = true
	
	print("\n  Snapshot created:")
	print("    Flags in snapshot: %d" % narrative_snapshot["flags"].size())
	print("    Variables in snapshot: %d" % narrative_snapshot["variables"].size())
	print("    Events in snapshot: %d" % narrative_snapshot["completed_events"].size())
	
	# Limpiar estado
	Narrative.clear_all()
	Checkpoints.reset()
	
	# Restaurar desde snapshot (simulando _restore_narrative_state)
	print("\n  Restoring from snapshot...")
	
	# Flags
	for flag in narrative_snapshot["flags"].keys():
		if narrative_snapshot["flags"][flag]:
			Narrative.set_flag(flag)
	
	# Variables
	for var_name in narrative_snapshot["variables"].keys():
		Narrative.set_variable(var_name, narrative_snapshot["variables"][var_name])
	
	# Eventos
	for event_id in narrative_snapshot["completed_events"]:
		Narrative.register_event(event_id)
	
	# Checkpoints
	Checkpoints.load_save_state(narrative_snapshot["checkpoints"])
	
	# Verificar integración completa
	print("\n  Verifying restored state...")
	
	# Flags deben estar restaurados
	assert(Narrative.has_flag("PRINCE_MET"), "Flags should be restored")
	assert(Narrative.has_flag("ACADEMY_JOINED"), "Flags should be restored")
	
	# Variables del checkpoint deben estar (resetadas a valores iniciales)
	assert(Narrative.has_variable("reputation"), "Checkpoint vectors should be restored")
	assert(Narrative.get_variable("reputation") == 0.0, "Initial values should be applied")
	
	# Variables preservadas deben mantener su valor
	assert(Narrative.has_variable("gold"), "Preserved variables should be restored")
	
	# Eventos deben estar restaurados
	assert(Narrative.has_completed_event("EVT_MEET_PRINCE"), "Events should be restored")
	
	# Checkpoint debe estar registrado
	var restored_cp = Checkpoints.get_checkpoint_state("ACT1_END")
	assert(restored_cp != null, "Checkpoint should be restored")
	assert(restored_cp.accumulated_vectors.has("reputation"), "Vectors should be preserved")
	
	print("  ✓ All narrative components restored correctly")
	
	print("✓ Narrative State Snapshot OK")


func test_backwards_compatibility():
	print("\n--- Test: Backwards Compatibility ---")
	
	# Simular snapshot antiguo sin checkpoints
	print("  Creating narrative snapshot without checkpoints...")
	
	var old_snapshot = {
		"flags": {
			"PRINCE_MET": true,
			"ACADEMY_JOINED": true
		},
		"variables": {
			"gold": 150,
			"reputation": 30
		},
		"completed_events": ["EVT_MEET_PRINCE"]
		# NO incluir checkpoints
	}
	
	# Limpiar estado
	Narrative.clear_all()
	Checkpoints.reset()
	
	# Restaurar (con migración automática)
	print("\n  Restoring old snapshot...")
	
	# Flags
	for flag in old_snapshot["flags"].keys():
		if old_snapshot["flags"][flag]:
			Narrative.set_flag(flag)
	
	# Variables
	for var_name in old_snapshot["variables"].keys():
		Narrative.set_variable(var_name, old_snapshot["variables"][var_name])
	
	# Eventos
	for event_id in old_snapshot["completed_events"]:
		Narrative.register_event(event_id)
	
	# Checkpoints (migración: crear estructura vacía si no existe)
	var checkpoints_data = old_snapshot.get("checkpoints", {
		"reached_checkpoints": [],
		"current_checkpoint": ""
	})
	
	Checkpoints.load_save_state(checkpoints_data)
	
	# Verificar que todo funcionó
	assert(Narrative.has_flag("PRINCE_MET"), "Flags should be restored")
	assert(Narrative.get_variable("gold") == 150, "Variables should be restored")
	assert(Narrative.has_completed_event("EVT_MEET_PRINCE"), "Events should be restored")
	assert(Checkpoints.get_reached_checkpoints().is_empty(), "Checkpoints should be empty (migrated)")
	
	print("  Old snapshot restored successfully with empty checkpoints")
	
	print("✓ Backwards Compatibility OK")
