extends CanvasLayer
class_name GameOverUI

## GameOverUI — Pantalla de derrota permanente (Spike 14; rediseño Spike 24).
##
## Ruta: res://ui/gameover/game_over_ui.gd
##
## Se muestra cuando todos los aliados (jugador + companions) caen en combate.
## Ofrece un único botón hacia el menú principal. La View solo renderiza y
## delega: no conoce Narrative, Checkpoints, Party ni GameLoop. El reinicio de
## sesión y la liberación de esta pantalla los hace SceneOrchestrator al
## entrar en MENU (esta pantalla nunca se libera a sí misma).
##
## Spike 24: fondo y título con TitleBackdrop (título en tono DANGER), botón
## UIButton LG con ancho por fracción de pantalla, foco inicial en el botón y
## textos en game_over.csv (GAME_OVER_*). El Backdrop bloquea los clics hacia
## lo que haya debajo (mouse_filter = STOP en la instancia de la escena).

## Ancho mínimo del botón y fracción del ancho de pantalla que ocupa.
const BUTTON_MIN_WIDTH: float = 280.0
const BUTTON_WIDTH_FRACTION: float = 0.2

@onready var backdrop: TitleBackdrop = %Backdrop
@onready var content_box: VBoxContainer = %ContentBox
@onready var message_label: Label = %MessageLabel
@onready var return_to_menu_button: UIButton = %ReturnToMenuButton

var _vm: GameOverViewModel = null


func _ready() -> void:
	visible = false
	_apply_tokens()
	_setup_static_text()
	_update_button_width()
	get_viewport().size_changed.connect(_update_button_width)

	# El ViewModel es siempre hijo de la View.
	_vm = GameOverViewModel.new()
	_vm.name = "ViewModel"
	add_child(_vm)
	_vm.changed.connect(_on_vm_changed)

	return_to_menu_button.pressed.connect(_on_return_to_menu_pressed)


func _notification(what: int) -> void:
	# Llega a todos los nodos, también ocultos: retraducir aquí cambia el idioma
	# en caliente (patrón del Spike 23).
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_setup_static_text()


## API pública — llamada desde SceneOrchestrator._show_game_over().
func show_game_over() -> void:
	_vm.open()


func _apply_tokens() -> void:
	content_box.add_theme_constant_override("separation", UITokens.SPACE_XXL)
	message_label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_XL)
	message_label.add_theme_color_override("font_color", UITokens.TEXT_PRIMARY)
	message_label.add_theme_color_override("font_outline_color", UITokens.COLOR_TEXT_OUTLINE)
	message_label.add_theme_constant_override("outline_size", UITokens.TEXT_OUTLINE_SIZE)


func _setup_static_text() -> void:
	backdrop.title_text = tr("GAME_OVER_TITLE")
	message_label.text = tr("GAME_OVER_MESSAGE")
	return_to_menu_button.text = tr("GAME_OVER_BUTTON_MENU")


## Ancho del botón por fracción de pantalla (con mínimo), no 240 px fijos.
func _update_button_width() -> void:
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	return_to_menu_button.custom_minimum_size.x = maxf(BUTTON_MIN_WIDTH, viewport_width * BUTTON_WIDTH_FRACTION)


func _on_return_to_menu_pressed() -> void:
	_vm.request_return_to_menu()


func _on_vm_changed(reason: String) -> void:
	match reason:
		"opened":
			visible = true
			return_to_menu_button.disabled = false
			return_to_menu_button.set_variant(UIButton.Variant.PRIMARY)
			return_to_menu_button.call_deferred("grab_focus")
			print("[GameOverUI] Game Over shown")
		"transitioning":
			# PRIMARY deshabilitado es ilegible: SECONDARY mientras dura.
			return_to_menu_button.disabled = true
			return_to_menu_button.set_variant(UIButton.Variant.SECONDARY)
		_:
			push_warning("[GameOverUI] Razón desconocida: %s" % reason)


func _unhandled_input(_event: InputEvent) -> void:
	if not visible:
		return
	# Bloquear todo input mientras se muestra el game over.
	get_viewport().set_input_as_handled()
