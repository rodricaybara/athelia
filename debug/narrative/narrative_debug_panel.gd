extends CanvasLayer

## NarrativeDebugPanel - Panel de debug para narrativa
##
## Responsabilidad: Visualizar estado narrativo y checkpoints
## Controles: F12 para toggle

## Referencias a nodos UI
@onready var checkpoint_value = %CheckpointValue
@onready var flags_grid = %FlagsGrid
@onready var variables_grid = %VariablesGrid
@onready var vectors_grid = %VectorsGrid
@onready var checkpoints_list = %CheckpointsList
@onready var refresh_button = %RefreshButton
@onready var checkpoint_option_button = %CheckpointOptionButton
@onready var apply_button = %ApplyButton
@onready var reset_button = %ResetButton
@onready var confirmation_dialog = %ConfirmationDialog
@onready var feedback_label = %FeedbackLabel
@onready var feedback_timer = %FeedbackTimer

## ViewModel
var viewmodel: NarrativeDebugViewModel


func _ready():
	# Crear ViewModel
	viewmodel = NarrativeDebugViewModel.new()
	
	# Validar sistemas
	if not viewmodel.validate_systems():
		push_error("[NarrativeDebugPanel] Required systems not available")
		queue_free()
		return
	
	# Conectar señales
	_connect_signals()
	
	# Refresh inicial
	refresh_display()
	
	print("[NarrativeDebugPanel] Initialized - Press F12 to toggle")


func _connect_signals():
	refresh_button.pressed.connect(_on_refresh_pressed)
	apply_button.pressed.connect(_on_apply_checkpoint_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	confirmation_dialog.confirmed.connect(_on_reset_confirmed)
	feedback_timer.timeout.connect(_on_feedback_timeout)


func _input(event):
	# F12 para toggle (usar ui_cancel como fallback hasta configurar F12)
	if event.is_action_pressed("toggle_narrative_debug"):  # ESC temporal, cambiar a toggle_narrative_debug
		visible = not visible
		if visible:
			refresh_display()
		get_viewport().set_input_as_handled()


## Refresca toda la UI
func refresh_display():
	if not viewmodel:
		return
	
	print("[NarrativeDebugPanel] Refreshing display...")
	
	# Refrescar datos del ViewModel
	viewmodel.refresh_from_systems()
	
	# Actualizar cada sección
	_update_checkpoint_display()
	_update_flags_display()
	_update_variables_display()
	_update_vectors_display()
	_update_checkpoints_list()
	_update_checkpoint_options()
	
	print("[NarrativeDebugPanel] Display refreshed")


## Actualiza display del checkpoint actual
func _update_checkpoint_display():
	if viewmodel.current_checkpoint.is_empty():
		checkpoint_value.text = "None"
		checkpoint_value.modulate = Color.GRAY
	else:
		checkpoint_value.text = viewmodel.current_checkpoint
		checkpoint_value.modulate = Color(0.4, 0.8, 1.0)


## Actualiza display de flags
func _update_flags_display():
	# Limpiar grid
	for child in flags_grid.get_children():
		child.queue_free()
	
	# Si no hay flags
	if viewmodel.active_flags.is_empty():
		var label = Label.new()
		label.text = "  (no flags)"
		label.add_theme_color_override("font_color", Color.GRAY)
		flags_grid.add_child(label)
		return
	
	# Añadir cada flag
	for flag_id in viewmodel.active_flags:
		var hbox = HBoxContainer.new()
		
		var checkbox = CheckBox.new()
		checkbox.button_pressed = true
		checkbox.disabled = true  # Solo visualización
		checkbox.text = flag_id
		checkbox.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
		
		hbox.add_child(checkbox)
		flags_grid.add_child(hbox)


## Actualiza display de variables
func _update_variables_display():
	# Limpiar grid
	for child in variables_grid.get_children():
		child.queue_free()
	
	# Si no hay variables
	if viewmodel.variables.is_empty():
		var label = Label.new()
		label.text = "  (no variables)"
		label.add_theme_color_override("font_color", Color.GRAY)
		variables_grid.add_child(label)
		return
	
	# Añadir cada variable (ordenadas por nombre)
	var var_names = viewmodel.variables.keys()
	var_names.sort()
	
	for var_name in var_names:
		var value = viewmodel.variables[var_name]
		
		var label = Label.new()
		label.text = "  %s = %s" % [var_name, _format_value(value)]
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.6))
		
		variables_grid.add_child(label)


## Actualiza display de vectores consolidados
func _update_vectors_display():
	# Limpiar grid
	for child in vectors_grid.get_children():
		child.queue_free()
	
	# Si no hay vectores
	if viewmodel.consolidated_vectors.is_empty():
		var label = Label.new()
		label.text = "  (no vectors)"
		label.add_theme_color_override("font_color", Color.GRAY)
		vectors_grid.add_child(label)
		return
	
	# Añadir cada vector (ordenados por nombre)
	var vector_names = viewmodel.consolidated_vectors.keys()
	vector_names.sort()
	
	for vector_name in vector_names:
		var vector_info = viewmodel.consolidated_vectors[vector_name]
		
		# Container para vector
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		
		# Label con nombre y rango
		var label = Label.new()
		label.text = "  %s: %.1f / [%.0f, %.0f]" % [
			vector_name,
			vector_info["value"],
			vector_info["min"],
			vector_info["max"]
		]
		label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
		vbox.add_child(label)
		
		# ProgressBar visual
		var progress = ProgressBar.new()
		progress.min_value = 0.0
		progress.max_value = 1.0
		progress.value = vector_info["percentage"]
		progress.show_percentage = false
		progress.custom_minimum_size = Vector2(0, 8)
		
		# Color según valor
		if vector_info["percentage"] < 0.33:
			progress.modulate = Color(1.0, 0.4, 0.4)  # Rojo
		elif vector_info["percentage"] > 0.66:
			progress.modulate = Color(0.4, 1.0, 0.4)  # Verde
		else:
			progress.modulate = Color(1.0, 1.0, 0.4)  # Amarillo
		
		vbox.add_child(progress)
		vectors_grid.add_child(vbox)


## Actualiza lista de checkpoints alcanzados
func _update_checkpoints_list():
	# Limpiar lista
	for child in checkpoints_list.get_children():
		child.queue_free()
	
	# Si no hay checkpoints
	if viewmodel.reached_checkpoints.is_empty():
		var label = Label.new()
		label.text = "  (none)"
		label.add_theme_color_override("font_color", Color.GRAY)
		checkpoints_list.add_child(label)
		return
	
	# Añadir cada checkpoint
	for cp_id in viewmodel.reached_checkpoints:
		var label = Label.new()
		label.text = "  - %s" % cp_id
		label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
		checkpoints_list.add_child(label)


## Actualiza opciones de checkpoints disponibles
func _update_checkpoint_options():
	checkpoint_option_button.clear()
	
	if viewmodel.available_checkpoints.is_empty():
		checkpoint_option_button.add_item("(no checkpoints)", 0)
		checkpoint_option_button.disabled = true
		apply_button.disabled = true
		return
	
	# Añadir cada checkpoint disponible
	for i in range(viewmodel.available_checkpoints.size()):
		var cp_id = viewmodel.available_checkpoints[i]
		checkpoint_option_button.add_item(cp_id, i)
	
	checkpoint_option_button.disabled = false
	apply_button.disabled = false


## Formatea un valor para display
func _format_value(value) -> String:
	if value is float:
		return "%.2f" % value
	elif value is int:
		return str(value)
	elif value is bool:
		return "true" if value else "false"
	else:
		return str(value)


# ==============================================
# CALLBACKS
# ==============================================

func _on_refresh_pressed():
	print("[NarrativeDebugPanel] Manual refresh requested")
	refresh_display()

func _on_apply_checkpoint_pressed():
	var selected_index = checkpoint_option_button.selected
	if selected_index < 0:
		return
	
	var checkpoint_id = viewmodel.available_checkpoints[selected_index]
	
	print("[NarrativeDebugPanel] Applying checkpoint: %s" % checkpoint_id)
	
	var result = Checkpoints.apply_checkpoint(checkpoint_id)
	if result:
		print("[NarrativeDebugPanel] Checkpoint applied successfully")
		refresh_display()
		_show_feedback("Checkpoint aplicado: %s" % checkpoint_id, false)
	else:
		push_warning("[NarrativeDebugPanel] Failed to apply checkpoint: %s" % checkpoint_id)
		_show_feedback("Error al aplicar: %s" % checkpoint_id, true)


func _on_reset_pressed():
	# Mostrar diálogo de confirmación
	confirmation_dialog.popup_centered()


func _on_reset_confirmed():
	print("[NarrativeDebugPanel] Resetting narrative state...")
	
	Narrative.clear_all()
	Checkpoints.reset()
	
	print("[NarrativeDebugPanel] Narrative state reset complete")
	refresh_display()
	_show_feedback("Estado narrativo reiniciado", false)

# ==============================================
# FEEDBACK
# ==============================================

## Muestra un mensaje temporal de feedback al usuario
## is_error: true = rojo (error), false = verde (éxito)
func _show_feedback(message: String, is_error: bool) -> void:
	feedback_label.text = message
	if is_error:
		feedback_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	else:
		feedback_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	feedback_label.visible = true
	feedback_timer.start()


## Oculta el Label de feedback cuando el timer se completa
func _on_feedback_timeout() -> void:
	feedback_label.visible = false

# ==============================================
# DEBUG
# ==============================================

func _on_tree_exiting():
	print("[NarrativeDebugPanel] Shutting down")
