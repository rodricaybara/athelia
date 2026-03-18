extends Node

## Test de DialogueDefinitions
## Prueba carga desde JSON y navegación por diálogos

func _ready():
	print("\n=== Testing DialogueDefinitions ===")
	
	# Esperar un frame para que DialogueDB se inicialice
	await get_tree().process_frame
	
	test_dialogue_loading()
	test_node_navigation()
	test_option_availability()
	test_dialogue_flow()
	
	print("\n=== DialogueDefinitions tests complete ===\n")


func test_dialogue_loading():
	print("\n--- Test: Dialogue Loading ---")
	
	# Verificar que se cargaron diálogos
	var dialogue_count = DialogueDB.list_dialogues().size()
	print("  Loaded %d dialogues" % dialogue_count)
	assert(dialogue_count > 0, "Should have loaded dialogues from JSON")
	
	# Verificar diálogo específico
	assert(DialogueDB.has_dialogue("DLG_PRINCE_INTRO"), "Should have DLG_PRINCE_INTRO")
	
	# Obtener diálogo
	var dialogue = DialogueDB.get_dialogue("DLG_PRINCE_INTRO")
	assert(dialogue != null, "Should retrieve dialogue")
	assert(dialogue.id == "DLG_PRINCE_INTRO", "Dialogue ID should match")
	assert(dialogue.nodes.size() > 0, "Dialogue should have nodes")
	
	print("  Dialogue has %d nodes" % dialogue.nodes.size())
	
	print("✓ Dialogue Loading OK")


func test_node_navigation():
	print("\n--- Test: Node Navigation ---")
	
	var dialogue = DialogueDB.get_dialogue("DLG_PRINCE_INTRO")
	
	# Obtener primer nodo
	var first_node = dialogue.get_first_node()
	assert(first_node != null, "Should have first node")
	assert(first_node.id == "N1", "First node should be N1")
	
	print("  First node: %s (speaker: %s)" % [first_node.id, first_node.speaker_id])
	
	# Obtener nodo por ID
	var node2 = dialogue.get_node("N2")
	assert(node2 != null, "Should find N2")
	assert(node2.speaker_id == "prince", "Speaker should be prince")
	
	# Verificar opciones del primer nodo
	assert(first_node.has_options(), "First node should have options")
	print("  Node N1 has %d options" % first_node.options.size())
	
	print("✓ Node Navigation OK")


func test_option_availability():
	print("\n--- Test: Option Availability ---")
	
	# Limpiar estado narrativo
	Narrative.clear_all()
	
	var dialogue = DialogueDB.get_dialogue("DLG_PRINCE_INTRO")
	var first_node = dialogue.get_first_node()
	
	# Sin flags, ambas opciones deberían estar disponibles
	var available = first_node.get_available_options()
	print("  Available options (no flags): %d" % available.size())
	assert(available.size() == 2, "Should have 2 available options")
	
	# Activar flag PRINCE_MET
	Narrative.set_flag("PRINCE_MET")
	
	# La opción O2 debería estar bloqueada (blocked_flags: ["PRINCE_MET"])
	available = first_node.get_available_options()
	print("  Available options (with PRINCE_MET flag): %d" % available.size())
	assert(available.size() == 1, "Should have 1 available option (O2 blocked)")
	assert(available[0].id == "O1", "Only O1 should be available")
	
	print("✓ Option Availability OK")


func test_dialogue_flow():
	print("\n--- Test: Dialogue Flow ---")
	
	# Limpiar estado
	Narrative.clear_all()
	
	var dialogue = DialogueDB.get_dialogue("DLG_PRINCE_INTRO")
	
	# Simular flujo de diálogo
	var current_node = dialogue.get_first_node()
	print("  Starting at node: %s" % current_node.id)
	
	# Seleccionar primera opción (O1 - polite)
	var option = current_node.get_option("O1")
	assert(option != null, "Should find option O1")
	assert(option.is_available(), "Option should be available")
	
	# Verificar eventos narrativos
	print("  Option triggers %d events" % option.narrative_events.size())
	assert("EVT_MEET_PRINCE" in option.narrative_events, "Should trigger EVT_MEET_PRINCE")
	
	# Navegar al siguiente nodo
	var next_node_id = option.next_node_id
	assert(not next_node_id.is_empty(), "Should have next node")
	
	current_node = dialogue.get_node(next_node_id)
	assert(current_node != null, "Should find next node")
	print("  Moved to node: %s" % current_node.id)
	
	# Verificar que tiene opción de salida
	var exit_option = current_node.get_option("O3")
	assert(exit_option != null, "Should have exit option")
	assert(exit_option.ends_dialogue(), "Option should end dialogue")
	
	print("✓ Dialogue Flow OK")
