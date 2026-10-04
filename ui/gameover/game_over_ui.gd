extends CanvasLayer
class_name GameOverUI

## GameOverUI — Pantalla de derrota permanente (Spike 14).
##
## Ruta: res://ui/gameover/game_over_ui.gd
##
## Se muestra cuando todos los aliados (jugador + companions) caen en combate.
## Ofrece un único botón hacia el menú principal. La View solo renderiza y
## delega: no conoce Narrative, Checkpoints, Party ni GameLoop. El reinicio de
## sesión y la liberación de esta pantalla los hace SceneOrchestrator al
## entrar en MENU.

@onready var title_label: Label = %TitleLabel
@onready var message_label: Label = %MessageLabel
@onready var return_to_menu_button: Button = %ReturnToMenuButton

var _vm: GameOverViewModel = null


func _ready() -> void:
	visible = false
	_setup_static_text()

	# El ViewModel es siempre hijo de la View.
	_vm = GameOverViewModel.new()
	_vm.name = "ViewModel"
	add_child(_vm)
	_vm.changed.connect(_on_vm_changed)

	return_to_menu_button.pressed.connect(_on_return_to_menu_pressed)


## API pública — llamada desde SceneOrchestrator._show_game_over().
func show_game_over() -> void:
	_vm.open()


func _setup_static_text() -> void:
	title_label.text = tr("GAMEOVER_TITLE")
	message_label.text = tr("GAMEOVER_MESSAGE")
	return_to_menu_button.text = tr("GAMEOVER_BUTTON_MENU")


func _on_return_to_menu_pressed() -> void:
	_vm.request_return_to_menu()


func _on_vm_changed(reason: String) -> void:
	match reason:
		"opened":
			visible = true
			return_to_menu_button.disabled = false
			print("[GameOverUI] Game Over shown")
		"transitioning":
			return_to_menu_button.disabled = true
		_:
			push_warning("[GameOverUI] Razón desconocida: %s" % reason)


func _unhandled_input(_event: InputEvent) -> void:
	if not visible:
		return
	# Bloquear todo input mientras se muestra el game over.
	get_viewport().set_input_as_handled()
