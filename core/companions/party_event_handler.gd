extends Node

## PartyEventHandler - Puente entre NarrativeSystem y PartyManager
## Autoload: /root/PartyEventHandler
##
## RESPONSABILIDAD ÚNICA:
##   Escuchar join_party_requested emitido por NarrativeEventDefinition
##   y traducirlo a llamadas concretas a PartyManager.
##
## CONTRATO: Mismo patrón que SkillEventHandler.
##   NarrativeEventDefinition NUNCA llama directamente a PartyManager.


func _ready() -> void:
	EventBus.join_party_requested.connect(_on_join_party_requested)
	print("[PartyEventHandler] Ready — listening for join_party_requested")


func _on_join_party_requested(companion_id: String, definition_id: String) -> void:
	print("[PartyEventHandler] join_party_requested ← companion=%s, def=%s" % [
		companion_id, definition_id
	])

	var party := get_node_or_null("/root/Party")
	if not party:
		push_error("[PartyEventHandler] PartyManager not found at /root/Party")
		return

	var success: bool = party.join_party(companion_id, definition_id)

	if success:
		print("[PartyEventHandler] ✓ '%s' joined the party" % companion_id)
	else:
		print("[PartyEventHandler] ✗ '%s' could not join (full or already in party)" % companion_id)
