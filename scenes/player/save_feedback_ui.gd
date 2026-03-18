extends CanvasLayer

## SaveFeedbackUI - Feedback visual mínimo para guardado/carga
## Muestra mensajes temporales en pantalla

@onready var message_label: Label = $CenterContainer/MessageLabel

var message_timer: Timer


func _ready():
	# Crear timer para ocultar mensajes
	message_timer = Timer.new()
	message_timer.one_shot = true
	message_timer.timeout.connect(_hide_message)
	add_child(message_timer)
	
	# Ocultar inicialmente
	visible = false
	
	# Conectar a eventos del SaveSystem
	var save_system = get_node("/root/SaveManager")
	if save_system:
		save_system.save_started.connect(_on_save_started)
		save_system.save_completed.connect(_on_save_completed)
		save_system.save_failed.connect(_on_save_failed)
		save_system.load_started.connect(_on_load_started)
		save_system.load_completed.connect(_on_load_completed)
		save_system.load_failed.connect(_on_load_failed)


func show_message(text: String, color: Color = Color.WHITE, duration: float = 2.0):
	message_label.text = text
	message_label.modulate = color
	visible = true
	
	message_timer.start(duration)


func _hide_message():
	visible = false


## Callbacks de SaveSystem
func _on_save_started(_slot_id: String):
	show_message("Guardando...", Color.YELLOW, 1.0)


func _on_save_completed(_slot_id: String):
	show_message("Partida guardada", Color.GREEN, 2.0)


func _on_save_failed(_slot_id: String, reason: String):
	show_message("Error al guardar: %s" % reason, Color.RED, 3.0)


func _on_load_started(_slot_id: String):
	show_message("Cargando...", Color.YELLOW, 1.0)


func _on_load_completed(_slot_id: String):
	show_message("Partida cargada", Color.GREEN, 2.0)


func _on_load_failed(_slot_id: String, reason: String):
	show_message("Error al cargar: %s" % reason, Color.RED, 3.0)
