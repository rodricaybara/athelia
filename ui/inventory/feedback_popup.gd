extends PanelContainer

## FeedbackPopup - Mensaje temporal de feedback
##
## Widget pasivo: lo muestra quien lo usa (View) y se oculta solo pasados
## DISPLAY_SECONDS. Un mensaje nuevo reinicia la cuenta.

const SUCCESS_COLOR: Color = Color(0.2, 0.8, 0.2, 1.0)
const ERROR_COLOR: Color = Color(0.8, 0.2, 0.2, 1.0)
const DISPLAY_SECONDS: float = 2.0

@onready var message_label: Label = $MarginContainer/MessageLabel

var _hide_timer: Timer = null


func _ready() -> void:
	visible = false
	_hide_timer = Timer.new()
	_hide_timer.one_shot = true
	_hide_timer.timeout.connect(hide_message)
	add_child(_hide_timer)


## Muestra un mensaje de éxito
func show_success(message: String) -> void:
	_show_message(message, SUCCESS_COLOR)


## Muestra un mensaje de error
func show_error(message: String) -> void:
	_show_message(message, ERROR_COLOR)


## Oculta el mensaje
func hide_message() -> void:
	if _hide_timer:
		_hide_timer.stop()
	visible = false


func _show_message(message: String, color: Color) -> void:
	message_label.text = message
	message_label.modulate = color
	visible = true
	_hide_timer.start(DISPLAY_SECONDS)
