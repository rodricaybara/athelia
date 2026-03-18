extends Node

## Test de NarrativeEvents
## Prueba carga desde JSON y aplicación de eventos

func _ready():
	print("\n=== Testing NarrativeEvents ===")
	
	# Esperar un frame para que NarrativeDB se inicialice
	await get_tree().process_frame
	
	test_event_loading()
	test_event_application()
	test_event_effects()
	test_multiple_events()
	test_event_triggers()
	
	print("\n=== NarrativeEvents tests complete ===\n")


func test_event_loading():
	print("\n--- Test: Event Loading ---")
	
	# Verificar que se cargaron eventos
	var event_count = NarrativeDB.list_events().size()
	print("  Loaded %d events" % event_count)
	assert(event_count > 0, "Should have loaded events from JSON")
	
	# Verificar eventos específicos
	assert(NarrativeDB.has_event("EVT_MEET_PRINCE"), "Should have EVT_MEET_PRINCE")
	assert(NarrativeDB.has_event("EVT_JOIN_ACADEMY"), "Should have EVT_JOIN_ACADEMY")
	assert(NarrativeDB.has_event("EVT_FIRST_BATTLE"), "Should have EVT_FIRST_BATTLE")
	
	# Obtener evento
	var event = NarrativeDB.get_event("EVT_MEET_PRINCE")
	assert(event != null, "Should retrieve event")
	assert(event.id == "EVT_MEET_PRINCE", "Event ID should match")
	assert(event.trigger_type == "DIALOGUE_END", "Trigger type should be DIALOGUE_END")
	
	print("✓ Event Loading OK")


func test_event_application():
	print("\n--- Test: Event Application ---")
	
	# Limpiar estado
	Narrative.clear_all()
	
	# Aplicar evento manualmente
	var success = Narrative.apply_event("EVT_MEET_PRINCE")
	assert(success, "Event should apply successfully")
	
	# Verificar que el evento se registró
	assert(Narrative.has_completed_event("EVT_MEET_PRINCE"), "Event should be registered as completed")
	
	print("✓ Event Application OK")


func test_event_effects():
	print("\n--- Test: Event Effects ---")
	
	# Limpiar estado
	Narrative.clear_all()
	
	# Aplicar evento que añade flags y variables
	Narrative.apply_event("EVT_MEET_PRINCE")
	
	# Verificar flags
	assert(Narrative.has_flag("PRINCE_MET"), "Should have PRINCE_MET flag")
	
	# Verificar variables
	var reputation = Narrative.get_variable("reputation", 0)
	assert(reputation == 10, "Reputation should be 10")
	
	print("  Flag set: PRINCE_MET = %s" % Narrative.has_flag("PRINCE_MET"))
	print("  Variable set: reputation = %s" % reputation)
	
	print("✓ Event Effects OK")


func test_multiple_events():
	print("\n--- Test: Multiple Events ---")
	
	# Limpiar estado
	Narrative.clear_all()
	
	# Aplicar varios eventos en secuencia
	Narrative.apply_event("EVT_MEET_PRINCE")
	Narrative.apply_event("EVT_JOIN_ACADEMY")
	Narrative.apply_event("EVT_FIRST_BATTLE")
	
	# Verificar flags
	assert(Narrative.has_flag("PRINCE_MET"), "Should have PRINCE_MET")
	assert(Narrative.has_flag("ACADEMY_JOINED"), "Should have ACADEMY_JOINED")
	assert(Narrative.has_flag("FIRST_BATTLE_COMPLETED"), "Should have FIRST_BATTLE_COMPLETED")
	
	# Verificar que TUTORIAL_ACTIVE se removió
	assert(not Narrative.has_flag("TUTORIAL_ACTIVE"), "TUTORIAL_ACTIVE should be removed")
	
	# Verificar variables
	var academy_rep = Narrative.get_variable("academy_reputation", -1)
	var student_rank = Narrative.get_variable("student_rank", -1)
	var battles_won = Narrative.get_variable("battles_won", -1)
	
	assert(academy_rep == 0, "academy_reputation should be 0")
	assert(student_rank == 1, "student_rank should be 1")
	assert(battles_won == 1, "battles_won should be 1")
	
	# Verificar eventos completados
	var completed = Narrative.get_completed_events()
	assert(completed.size() == 3, "Should have 3 completed events")
	
	print("  Completed events: %d" % completed.size())
	print("  Active flags: %d" % Narrative.get_active_flags().size())
	
	print("✓ Multiple Events OK")


func test_event_triggers():
	print("\n--- Test: Event Triggers ---")
	
	# Obtener eventos por tipo de trigger
	var dialogue_events = NarrativeDB.get_events_by_trigger("DIALOGUE_END")
	var combat_events = NarrativeDB.get_events_by_trigger("COMBAT_END")
	var area_events = NarrativeDB.get_events_by_trigger("AREA_ENTER")
	
	print("  DIALOGUE_END events: %d" % dialogue_events.size())
	print("  COMBAT_END events: %d" % combat_events.size())
	print("  AREA_ENTER events: %d" % area_events.size())
	
	assert(dialogue_events.size() > 0, "Should have dialogue events")
	assert(combat_events.size() > 0, "Should have combat events")
	assert(area_events.size() > 0, "Should have area events")
	
	# Verificar que los eventos están en la categoría correcta
	for event in dialogue_events:
		assert(event.trigger_type == "DIALOGUE_END", "Event should be DIALOGUE_END")
	
	print("✓ Event Triggers OK")
