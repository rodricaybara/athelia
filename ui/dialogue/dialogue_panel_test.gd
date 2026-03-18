extends Control

@onready var dialogue_panel: Control = %DialoguePanel


func _ready() -> void:
	# Connect to EventBus signals for debugging
	if EventBus:
		EventBus.dialogue_started.connect(_on_dialogue_started)
		EventBus.dialogue_node_shown.connect(_on_dialogue_node_shown)
		EventBus.dialogue_option_selected.connect(_on_dialogue_option_selected)
		EventBus.dialogue_options_updated.connect(_on_dialogue_options_updated)
		EventBus.dialogue_ended.connect(_on_dialogue_ended)
	
	# Start the test dialogue
	if Dialogue:
		Dialogue.start_dialogue("DLG_PROLOGUE_INTRO_01")


func _on_dialogue_started(dialogue_id: String) -> void:
	print("[DialogueTest] Dialogue started: %s" % dialogue_id)


func _on_dialogue_node_shown(node_id: String, speaker_id: String, text_key: String, portrait_id: String = "") -> void:
	print("[DialogueTest] Node shown - ID: %s, Speaker: %s, Text Key: %s, Portrait: %s" % [node_id, speaker_id, text_key, portrait_id])


func _on_dialogue_option_selected(node_id: String, option_id: String) -> void:
	print("[DialogueTest] Option selected - Node: %s, Option: %s" % [node_id, option_id])


func _on_dialogue_options_updated(options: Array) -> void:
	print("[DialogueTest] Options updated with %d options" % options.size())
	for option in options:
		print("  - Option: %s (text_key: %s)" % [option.id, option.text_key])


func _on_dialogue_ended(dialogue_id: String) -> void:
	print("[DialogueTest] Dialogue ended: %s" % dialogue_id)
