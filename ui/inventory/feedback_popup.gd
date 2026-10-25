extends PanelContainer

## FeedbackPopup - Mensaje temporal de feedback
##
## Widget pasivo: lo muestra quien lo usa (View) y se oculta solo pasados
## DISPLAY_SECONDS. Un mensaje nuevo reinicia la cuenta.
## Spike 18: colores del Design System (antes Color(...) literales) y fondo de
## tokens; el script va ahora dentro de feedback_popup.tscn.

const DISPLAY_SECONDS: float = 2.0

@onready var message_label: Label = $MarginContainer/MessageLabel

var _hide_timer: Timer = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_MD)

	_hide_timer = Timer.new()
	_hide_timer.one_shot = true
	_hide_timer.timeout.connect(hide_message)
	add_child(_hide_timer)


## Muestra un mensaje de éxito
func show_success(message: String) -> void:
	_show_message(message, UITokens.COLOR_SUCCESS_SOFT, UITokens.COLOR_SUCCESS)


## Muestra un mensaje de error
func show_error(message: String) -> void:
	_show_message(message, UITokens.COLOR_DANGER_SOFT, UITokens.COLOR_DANGER)


## Oculta el mensaje
func hide_message() -> void:
	if _hide_timer:
		_hide_timer.stop()
	visible = false


func _show_message(message: String, text_color: Color, border_color: Color) -> void:
	message_label.text = message
	message_label.add_theme_color_override("font_color", text_color)
	add_theme_stylebox_override("panel", UITokens.make_stylebox(
		UITokens.COLOR_PANEL_ALT, border_color,
		UITokens.BORDER_WIDTH_FOCUS, UITokens.BORDER_RADIUS_SM, UITokens.SPACE_SM))
	visible = true
	_hide_timer.start(DISPLAY_SECONDS)
