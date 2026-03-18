extends Node

## Test de DialogueSystem
## Prueba ejecución de diálogos, navegación y eventos

func _ready():
	print("\n=== Testing DialogueSystem ===")
	
	# Esperar un frame para que DialogueDB se inicialice
	await get_tree().process_frame
	
	test_dialogue_start()
	test_dialogue_navigation()
	test_option_selection()
	test_narrative_events()
	test_dialogue_end()
	test_eventbus_integration()
	
	print("\n=== DialogueSystem tests complete ===\n")


func test_dialogue_start():
	print("\n--- Test: Dialogue Start ---")
	
	# Iniciar diálogo
	var success = Dialogue.start_dialogue("DLG_PRINCE_INTRO")
	assert(success, "Should start dialogue successfully")
	assert(Dialogue.is_active(), "Dialogue should be active")
	
	# Verificar estado
	assert(Dialogue.get_current_dialogue_id() == "DLG_PRINCE_INTRO", "Dialogue ID should match")
	assert(Dialogue.get_current_node_id() == "N1", "Should start at first node")
	assert(Dialogue.get_current_speaker() == "prince", "Speaker should be prince")
	
	print("  Dialogue started: %s" % Dialogue.get_current_dialogue_id())
	print("  Current node: %s" % Dialogue.get_current_node_id())
	
	# Limpiar
	Dialogue.end_dialogue()
	
	print("✓ Dialogue Start OK")


func test_dialogue_navigation():
	print("\n--- Test: Dialogue Navigation ---")
	
	# Iniciar diálogo
	Dialogue.start_dialogue("DLG_PRINCE_INTRO")
	
	# Verificar opciones disponibles
	var options = Dialogue.get_available_options()
	print("  Available options at N1: %d" % options.size())
	assert(options.size() > 0, "Should have options")
	
	# Obtener info del nodo
	var node_info = Dialogue.get_current_node_info()
	print("  Node info: %s" % node_info)
	assert(node_info["id"] == "N1", "Node ID should be N1")
	
	# Navegar directamente a otro nodo
	var nav_success = Dialogue.go_to_node("N2")
	assert(nav_success, "Should navigate to N2")
	assert(Dialogue.get_current_node_id() == "N2", "Should be at N2")
	
	print("  Navigated to: %s" % Dialogue.get_current_node_id())
	
	# Limpiar
	Dialogue.end_dialogue()
	
	print("✓ Dialogue Navigation OK")


func test_option_selection():
	print("\n--- Test: Option Selection ---")
	
	# Limpiar estado narrativo
	Narrative.clear_all()
	
	# Iniciar diálogo
	Dialogue.start_dialogue("DLG_PRINCE_INTRO")
	
	# Seleccionar opción O1 (polite)
	var select_success = Dialogue.select_option("O1")
	assert(select_success, "Should select option successfully")
	
	# Verificar que navegó al siguiente nodo
	assert(Dialogue.get_current_node_id() == "N2", "Should be at N2 after selecting O1")
	
	print("  After selecting O1, now at: %s" % Dialogue.get_current_node_id())
	
	# Limpiar
	Dialogue.end_dialogue()
	
	print("✓ Option Selection OK")


func test_narrative_events():
	print("\n--- Test: Narrative Events Integration ---")
	
	# Limpiar estado narrativo
	Narrative.clear_all()
	
	# Iniciar diálogo
	Dialogue.start_dialogue("DLG_PRINCE_INTRO")
	
	# Verificar que el evento no está completado
	assert(not Narrative.has_completed_event("EVT_MEET_PRINCE"), "Event should not be completed yet")
	
	# Seleccionar opción que dispara evento
	Dialogue.select_option("O1")
	
	# Verificar que el evento se disparó
	assert(Narrative.has_completed_event("EVT_MEET_PRINCE"), "Event should be triggered")
	assert(Narrative.has_flag("PRINCE_MET"), "Flag should be set")
	
	var reputation = Narrative.get_variable("reputation", 0)
	assert(reputation == 10, "Reputation should be 10")
	
	print("  Event triggered: EVT_MEET_PRINCE")
	print("  Flag set: PRINCE_MET")
	print("  Variable set: reputation = %s" % reputation)
	
	# Limpiar
	Dialogue.end_dialogue()
	
	print("✓ Narrative Events Integration OK")


func test_dialogue_end():
	print("\n--- Test: Dialogue End ---")
	
	# Iniciar diálogo
	Dialogue.start_dialogue("DLG_PRINCE_INTRO")
	
	# Navegar a nodo con opción de salida
	Dialogue.go_to_node("N2")
	
	# Seleccionar opción que termina diálogo (O3 - goodbye)
	Dialogue.select_option("O3")
	
	# Verificar que el diálogo terminó
	assert(not Dialogue.is_active(), "Dialogue should have ended")
	assert(Dialogue.get_current_dialogue_id().is_empty(), "Should have no current dialogue")
	
	print("  Dialogue ended successfully")
	
	print("✓ Dialogue End OK")


func test_eventbus_integration():
	print("\n--- Test: EventBus Integration ---")
	
	# Variables para capturar eventos
	var received_events = {
		"dialogue_started": false,
		"dialogue_node_shown": false,
		"dialogue_option_selected": false,
		"dialogue_options_updated": false,
		"dialogue_ended": false
	}
	
	# Handlers
	var start_handler = func(dialogue_id: String):
		received_events["dialogue_started"] = true
		print("  [Test] Dialogue started: %s" % dialogue_id)
	
	var node_handler = func(node_id: String, speaker_id: String, text_key: String):
		received_events["dialogue_node_shown"] = true
		print("  [Test] Node shown: %s" % node_id)
	
	var option_handler = func(node_id: String, option_id: String):
		received_events["dialogue_option_selected"] = true
		print("  [Test] Option selected: %s" % option_id)
	
	var options_handler = func(options: Array):
		received_events["dialogue_options_updated"] = true
		print("  [Test] Options updated: %d available" % options.size())
	
	var end_handler = func(dialogue_id: String):
		received_events["dialogue_ended"] = true
		print("  [Test] Dialogue ended: %s" % dialogue_id)
	
	# Conectar
	EventBus.dialogue_started.connect(start_handler)
	EventBus.dialogue_node_shown.connect(node_handler)
	EventBus.dialogue_option_selected.connect(option_handler)
	EventBus.dialogue_options_updated.connect(options_handler)
	EventBus.dialogue_ended.connect(end_handler)
	
	# Limpiar estado
	Narrative.clear_all()
	Dialogue.reset()
	
	# Ejecutar flujo completo
	print("  Executing full dialogue flow...")
	Dialogue.start_dialogue("DLG_PRINCE_INTRO")
	Dialogue.select_option("O1")
	Dialogue.select_option("O3")
	
	# Verificar eventos
	assert(received_events["dialogue_started"], "dialogue_started should fire")
	assert(received_events["dialogue_node_shown"], "dialogue_node_shown should fire")
	assert(received_events["dialogue_option_selected"], "dialogue_option_selected should fire")
	assert(received_events["dialogue_options_updated"], "dialogue_options_updated should fire")
	assert(received_events["dialogue_ended"], "dialogue_ended should fire")
	
	# Desconectar
	EventBus.dialogue_started.disconnect(start_handler)
	EventBus.dialogue_node_shown.disconnect(node_handler)
	EventBus.dialogue_option_selected.disconnect(option_handler)
	EventBus.dialogue_options_updated.disconnect(options_handler)
	EventBus.dialogue_ended.disconnect(end_handler)
	
	print("✓ EventBus Integration OK")
