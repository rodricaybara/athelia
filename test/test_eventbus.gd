extends Node

## Test del EventBus - Versión ampliada
## Prueba señales de Narrative y Dialogue

func _ready():
	print("\n=== Testing EventBus (Narrative & Dialogue) ===")
	
	test_narrative_signals()
	test_dialogue_signals()
	test_event_filtering()
	test_signal_stats()
	
	print("\n=== EventBus tests complete ===\n")


func test_narrative_signals():
	print("\n--- Test: Narrative Signals ---")
	
	# Conectar listeners
	EventBus.narrative_flag_set.connect(_on_flag_set)
	EventBus.narrative_flag_cleared.connect(_on_flag_cleared)
	EventBus.narrative_variable_changed.connect(_on_var_changed)
	EventBus.narrative_event_triggered.connect(_on_event_triggered)
	EventBus.narrative_state_changed.connect(_on_state_changed)
	
	# Emitir señales
	print("  Emitting narrative signals...")
	EventBus.narrative_flag_set.emit("PRINCE_MET")
	EventBus.narrative_variable_changed.emit("reputation", 50)
	EventBus.narrative_event_triggered.emit("EVT_MEET_PRINCE")
	EventBus.narrative_flag_cleared.emit("TUTORIAL_ACTIVE")
	EventBus.narrative_state_changed.emit()
	
	# Desconectar
	EventBus.narrative_flag_set.disconnect(_on_flag_set)
	EventBus.narrative_flag_cleared.disconnect(_on_flag_cleared)
	EventBus.narrative_variable_changed.disconnect(_on_var_changed)
	EventBus.narrative_event_triggered.disconnect(_on_event_triggered)
	EventBus.narrative_state_changed.disconnect(_on_state_changed)
	
	print("✓ Narrative signals OK")


func test_dialogue_signals():
	print("\n--- Test: Dialogue Signals ---")
	
	# Conectar
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_node_shown.connect(_on_node_shown)
	EventBus.dialogue_option_selected.connect(_on_option_selected)
	EventBus.dialogue_options_updated.connect(_on_options_updated)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)
	
	# Simular flujo de diálogo completo
	print("  Simulating dialogue flow...")
	EventBus.dialogue_started.emit("DLG_PRINCE_INTRO")
	
	EventBus.dialogue_node_shown.emit("N1", "prince", "DLG_PRINCE_01")
	
	var options = [
		{"id": "O1", "text_key": "DLG_OPT_01"},
		{"id": "O2", "text_key": "DLG_OPT_02"}
	]
	EventBus.dialogue_options_updated.emit(options)
	
	EventBus.dialogue_option_selected.emit("N1", "O1")
	
	EventBus.dialogue_node_shown.emit("N2", "prince", "DLG_PRINCE_02")
	
	EventBus.dialogue_ended.emit("DLG_PRINCE_INTRO")
	
	# Desconectar
	EventBus.dialogue_started.disconnect(_on_dialogue_started)
	EventBus.dialogue_node_shown.disconnect(_on_node_shown)
	EventBus.dialogue_option_selected.disconnect(_on_option_selected)
	EventBus.dialogue_options_updated.disconnect(_on_options_updated)
	EventBus.dialogue_ended.disconnect(_on_dialogue_ended)
	
	print("✓ Dialogue signals OK")


func test_event_filtering():
	print("\n--- Test: Event Filtering ---")
	
	# Configurar filtro (solo loggear narrative_flag_set)
	print("  Setting filter to only log 'narrative_flag_set'...")
	EventBus.set_event_filter(["narrative_flag_set"])
	
	# Emitir varias señales
	EventBus.narrative_flag_set.emit("FILTERED_FLAG")  # Debe loggearse
	EventBus.narrative_variable_changed.emit("test", 100)  # NO debe loggearse
	EventBus.dialogue_started.emit("DLG_TEST")  # NO debe loggearse
	
	# Limpiar filtro
	EventBus.set_event_filter([])
	
	print("✓ Event filtering OK")


func test_signal_stats():
	print("\n--- Test: Signal Stats ---")
	
	# Conectar algunas señales
	EventBus.narrative_flag_set.connect(_dummy_handler)
	EventBus.dialogue_started.connect(_dummy_handler)
	EventBus.narrative_variable_changed.connect(_dummy_handler)
	
	# Imprimir estadísticas
	EventBus.print_available_signals()
	
	# Verificar counts individuales
	var flag_count = EventBus.get_listeners_count("narrative_flag_set")
	var dialogue_count = EventBus.get_listeners_count("dialogue_started")
	
	print("  narrative_flag_set listeners: %d" % flag_count)
	print("  dialogue_started listeners: %d" % dialogue_count)
	
	# Desconectar
	EventBus.narrative_flag_set.disconnect(_dummy_handler)
	EventBus.dialogue_started.disconnect(_dummy_handler)
	EventBus.narrative_variable_changed.disconnect(_dummy_handler)
	
	print("✓ Signal stats OK")


# ==============================================
# HANDLERS DE NARRATIVE
# ==============================================

func _on_flag_set(flag_id: String):
	print("  [Handler] Flag SET: %s" % flag_id)


func _on_flag_cleared(flag_id: String):
	print("  [Handler] Flag CLEARED: %s" % flag_id)


func _on_var_changed(var_id: String, value: Variant):
	print("  [Handler] Variable CHANGED: %s = %s" % [var_id, value])


func _on_event_triggered(event_id: String):
	print("  [Handler] Event TRIGGERED: %s" % event_id)


func _on_state_changed():
	print("  [Handler] Narrative state CHANGED")


# ==============================================
# HANDLERS DE DIALOGUE
# ==============================================

func _on_dialogue_started(dialogue_id: String):
	print("  [Handler] Dialogue STARTED: %s" % dialogue_id)


func _on_node_shown(node_id: String, speaker_id: String, text_key: String):
	print("  [Handler] Node SHOWN: %s by %s (text: %s)" % [node_id, speaker_id, text_key])


func _on_option_selected(node_id: String, option_id: String):
	print("  [Handler] Option SELECTED: %s in node %s" % [option_id, node_id])


func _on_options_updated(options: Array):
	print("  [Handler] Options UPDATED: %d options available" % options.size())


func _on_dialogue_ended(dialogue_id: String):
	print("  [Handler] Dialogue ENDED: %s" % dialogue_id)


# Dummy handler para testing
func _dummy_handler():
	pass
