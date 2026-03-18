extends PanelContainer

## FeedbackPopup - Mensaje temporal de feedback

@onready var message_label: Label = $MarginContainer/MessageLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer

const SUCCESS_COLOR = Color(0.2, 0.8, 0.2, 1.0)
const ERROR_COLOR = Color(0.8, 0.2, 0.2, 1.0)


func _ready():
	visible = false


## Muestra un mensaje de éxito
func show_success(message: String):
	_show_message(message, SUCCESS_COLOR)


## Muestra un mensaje de error
func show_error(message: String):
	_show_message(message, ERROR_COLOR)


## Muestra mensaje con color
func _show_message(message: String, color: Color):
	message_label.text = message
	message_label.modulate = color
	
	visible = true
	
	# Animar fade out después de 2 segundos
	if animation_player:
		#animation_player.play("fade_out")
		animation_player.play("new_animation")
	else:
		# Fallback sin animación
		await get_tree().create_timer(2.0).timeout
		visible = false


## Oculta el mensaje
func hide_message():
	visible = false
