class_name WorldObjectInteractionPanel
extends CanvasLayer

## WorldObjectInteractionPanel - Panel de interacción con objetos del mundo
## UI PASIVA: no valida reglas, solo emite eventos y muestra resultados.
##
## ACCESO A AUTOLOADS:
##   - _wo_system  → /root/WorldObjectSystem  (nombre en Project Settings)
##   - _wo_objects → /root/WorldObjects       (nombre en Project Settings)
## Se resuelven en _ready() via get_node para evitar colisión con class_name.

# ============================================
# NODOS
# ============================================

@onready var panel:             PanelContainer = $Panel
@onready var title_label:       Label          = $Panel/MarginContainer/VBox/Header/TitleLabel
@onready var close_button:      Button         = $Panel/MarginContainer/VBox/Header/CloseButton
@onready var interactions_vbox: VBoxContainer  = $Panel/MarginContainer/VBox/InteractionsVBox
@onready var separator:         HSeparator     = $Panel/MarginContainer/VBox/ResultSeparator
@onready var feedback_label:    Label          = $Panel/MarginContainer/VBox/FeedbackLabel
@onready var info_label:        Label          = $Panel/MarginContainer/VBox/InfoLabel


# ============================================
# ESTADO INTERNO
# ============================================

## Referencias a autoloads — se asignan en _ready()
var _wo_system:  Node = null   # /root/WorldObjectSystem
var _wo_objects: Node = null   # /root/WorldObjects

var _current_instance_id: String = ""
var _entity_id: String = "player"

## True cuando _on_state_changed ya refrescó los botones en esta interacción.
## Evita que _on_feedback_ready los vuelva a reconstruir duplicándolos.
## Se resetea en _on_interaction_button_pressed antes de cada nueva acción.
var _buttons_refreshed_by_state: bool = false

const COLOR_CRITICAL := Color(1.0, 0.85, 0.0)
const COLOR_SUCCESS  := Color(0.3, 0.9, 0.3)
const COLOR_FAILURE  := Color(0.9, 0.5, 0.2)
const COLOR_FUMBLE   := Color(0.9, 0.2, 0.2)


# ============================================
# INICIALIZACIÓN
# ============================================

func _ready() -> void:
	visible = false

	_wo_system  = get_node_or_null("/root/WorldObjectSystem")
	_wo_objects = get_node_or_null("/root/WorldObjects")

	if not _wo_system:
		push_error("[WorldObjectInteractionPanel] WorldObjectSystem not found at /root/WorldObjectSystem")
	if not _wo_objects:
		push_error("[WorldObjectInteractionPanel] WorldObjects not found at /root/WorldObjects")

	close_button.pressed.connect(_on_close_pressed)

	EventBus.world_object_interaction_requested.connect(_on_interaction_requested)
	EventBus.world_object_feedback_ready.connect(_on_feedback_ready)
	EventBus.world_object_state_changed.connect(_on_state_changed)

	_hide_result_section()
	print("[WorldObjectInteractionPanel] Ready")


# ============================================
# MOSTRAR PANEL
# ============================================

func _on_interaction_requested(entity_id: String, instance_id: String) -> void:
	if not _wo_system:
		return

	_entity_id           = entity_id
	_current_instance_id = instance_id

	var interactions: Array = _wo_system.get_available_interactions(instance_id, entity_id)

	if interactions.is_empty():
		print("[WorldObjectInteractionPanel] No available interactions for '%s'" % instance_id)
		return

	var state = _wo_system.get_state(instance_id)
	if state and state.definition:
		title_label.text = tr(state.definition.display_name_key)
	else:
		title_label.text = instance_id

	_clear_interaction_buttons()

	for interaction in interactions:
		_add_interaction_button(interaction)

	_hide_result_section()
	visible = true


func _add_interaction_button(interaction: InteractionDefinition) -> void:
	var btn := Button.new()
	btn.text = tr(interaction.label_key)
	btn.tooltip_text = tr(interaction.description_key)

	if interaction.stamina_cost > 0:
		btn.text += "  [ST: %d]" % int(interaction.stamina_cost)

	var iid := interaction.id
	btn.pressed.connect(func(): _on_interaction_button_pressed(iid))

	interactions_vbox.add_child(btn)


func _clear_interaction_buttons() -> void:
	for child in interactions_vbox.get_children():
		child.queue_free()


# ============================================
# RESULTADO DE INTERACCIÓN
# ============================================

func _on_feedback_ready(
		instance_id: String,
		_interaction_id: String,
		outcome: String,
		feedback_key: String,
		revealed_info_key: String) -> void:

	if instance_id != _current_instance_id:
		return

	separator.visible       = true
	feedback_label.visible  = true
	feedback_label.text     = tr(feedback_key) if not feedback_key.is_empty() else outcome
	feedback_label.modulate = _outcome_color(outcome)

	if not revealed_info_key.is_empty():
		info_label.text    = tr(revealed_info_key)
		info_label.visible = true
	else:
		info_label.visible = false

	# _on_state_changed ya refrescó los botones si hubo cambio de flags (failure con
	# failure_produced_flags, o éxito con consumed/produced_flags). En ese caso no
	# repetir — los botones ya son correctos y rehacerlos causaría duplicados.
	# Solo refrescar aquí en los casos donde state_changed no se emitió:
	# fumble sin flags, failure sin failure_produced_flags, etc.
	if not _buttons_refreshed_by_state:
		_refresh_interaction_buttons()

	_buttons_refreshed_by_state = false


func _refresh_interaction_buttons() -> void:
	_clear_interaction_buttons()

	if _current_instance_id.is_empty() or not _wo_system:
		return

	if _wo_system.is_depleted(_current_instance_id):
		_show_depleted_message()
		return

	var interactions: Array = _wo_system.get_available_interactions(_current_instance_id, _entity_id)
	for interaction in interactions:
		_add_interaction_button(interaction)


func _show_depleted_message() -> void:
	feedback_label.text     = tr("WORLD_OBJECT_DEPLETED")
	feedback_label.modulate = Color(0.6, 0.6, 0.6)
	feedback_label.visible  = true
	separator.visible       = true

	await get_tree().create_timer(1.5).timeout
	_close()


# ============================================
# ESTADO DEL OBJETO CAMBIÓ
# ============================================

func _on_state_changed(instance_id: String, _active_flags: Array) -> void:
	if instance_id != _current_instance_id or not visible:
		return

	_refresh_interaction_buttons()
	# Marcar que los botones ya están actualizados para esta interacción
	_buttons_refreshed_by_state = true


# ============================================
# INPUT Y CIERRE
# ============================================

func _on_interaction_button_pressed(interaction_id: String) -> void:
	print("[WorldObjectInteractionPanel] Action chosen: %s on %s" % [
		interaction_id, _current_instance_id
	])
	_set_buttons_enabled(false)

	# Resetear bandera antes de emitir — cada acción parte de cero
	_buttons_refreshed_by_state = false

	EventBus.world_object_action_chosen.emit(
		_entity_id,
		_current_instance_id,
		interaction_id
	)

	await get_tree().process_frame
	_set_buttons_enabled(true)


func _on_close_pressed() -> void:
	_close()


func _close() -> void:
	_current_instance_id = ""
	_clear_interaction_buttons()
	_hide_result_section()
	visible = false


func _set_buttons_enabled(enabled: bool) -> void:
	for child in interactions_vbox.get_children():
		if child is Button:
			child.disabled = not enabled


func _hide_result_section() -> void:
	separator.visible      = false
	feedback_label.visible = false
	info_label.visible     = false


func _outcome_color(outcome: String) -> Color:
	match outcome:
		"critical": return COLOR_CRITICAL
		"success":  return COLOR_SUCCESS
		"failure":  return COLOR_FAILURE
		"fumble":   return COLOR_FUMBLE
	return Color.WHITE
