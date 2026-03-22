extends CanvasLayer
class_name GameOverUI

## GameOverUI - Pantalla de derrota permanente
##
## Se muestra cuando todos los aliados (jugador + companions) caen en combate.
## Ofrece iniciar una nueva partida desde cero.

@onready var new_game_button: Button = %NewGameButton
@onready var message_label: Label    = %MessageLabel


func _ready() -> void:
	visible = false
	new_game_button.pressed.connect(_on_new_game_pressed)


func show_game_over() -> void:
	visible = true
	message_label.text = "Todos han caído.\nNo queda nadie que pueda continuar."
	print("[GameOverUI] Game Over shown")


func _on_new_game_pressed() -> void:
	print("[GameOverUI] Starting new game...")
	# Limpiar estado narrativo completo
	Narrative.clear_all()
	Checkpoints.reset()

	# Limpiar party
	var party: Node = get_node_or_null("/root/Party")
	if party:
		for companion_id in party.get_party_members().duplicate():
			party.leave_party(companion_id)

	# Volver a la escena de exploración (nueva partida)
	get_tree().change_scene_to_file("res://scenes/exploration/exploration_test.tscn")


func _unhandled_input(_event: InputEvent) -> void:
	if not visible:
		return
	# Bloquear todo input mientras se muestra el game over
	get_viewport().set_input_as_handled()
