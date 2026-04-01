class_name WorldObjectInteractionPanel
extends CanvasLayer

## WorldObjectInteractionPanel — View
##
## Responsabilidades:
##   - Renderizar el estado expuesto por WorldObjectPanelViewModel
##   - Traducir input del jugador en llamadas al ViewModel
##   - NADA más
##
## Nunca accede a WorldObjectSystem, EventBus ni sistemas core directamente.
## Todo pasa por el ViewModel.


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
# CONSTANTES VISUALES
# ============================================

const COLOR_CRITICAL := Color(1.0, 0.85, 0.0)
const COLOR_SUCCESS  := Color(0.3, 0.9, 0.3)
const COLOR_FAILURE  := Color(0.9, 0.5, 0.2)
const COLOR_FUMBLE   := Color(0.9, 0.2, 0.2)
const COLOR_DEPLETED := Color(0.6, 0.6, 0.6)

const DEPLETED_CLOSE_DELAY := 1.5


# ============================================
# ESTADO INTERNO DE LA VIEW
# ============================================

## Referencia al ViewModel — se crea como hijo en _ready()
var _vm: WorldObjectPanelViewModel = null


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	visible = false

	# Crear ViewModel como hijo para ligar su ciclo de vida al panel
	_vm = WorldObjectPanelViewModel.new()
	_vm.name = "ViewModel"
	add_child(_vm)

	# La View escucha UNA señal del ViewModel
	_vm.changed.connect(_on_vm_changed)

	# Input directo de la View
	close_button.pressed.connect(func(): _vm.request_close())

	_hide_result_section()
	print("[WorldObjectPanel] Ready")


# ============================================
# CALLBACK ÚNICO DEL VIEWMODEL
# ============================================

func _on_vm_changed(reason: String) -> void:
	match reason:
		"opened":
			_render_opened()
		"waiting":
			_render_waiting()
		"result":
			_render_result()
		"depleted":
			_render_depleted()
		"closed":
			_render_closed()
		_:
			push_warning("[WorldObjectPanel] Razón de cambio desconocida: %s" % reason)


# ============================================
# RENDERS POR ESTADO
# ============================================

func _render_opened() -> void:
	title_label.text = _vm.object_display_name
	_build_interaction_buttons()
	_hide_result_section()
	visible = true


func _render_waiting() -> void:
	## Solo deshabilita los botones — no toca nada más
	_set_buttons_enabled(false)


func _render_result() -> void:
	## Mostrar feedback
	_show_result_section(
		_vm.result_feedback_key,
		_vm.result_outcome,
		_vm.result_info_key
	)
	## Reconstruir botones con las interacciones actualizadas por el ViewModel
	_build_interaction_buttons()


func _render_depleted() -> void:
	_show_depleted_message()
	_clear_interaction_buttons()
	# Cerrar automáticamente tras un delay
	get_tree().create_timer(DEPLETED_CLOSE_DELAY).timeout.connect(
		func(): _vm.request_close()
	)


func _render_closed() -> void:
	_hide_result_section()
	_clear_interaction_buttons()
	visible = false


# ============================================
# CONSTRUCCIÓN DE BOTONES
# ============================================

func _build_interaction_buttons() -> void:
	_clear_interaction_buttons()

	for interaction in _vm.available_interactions:
		var btn := _create_interaction_button(interaction)
		interactions_vbox.add_child(btn)


func _create_interaction_button(interaction: InteractionDefinition) -> Button:
	var btn := Button.new()

	var label_text := tr(interaction.label_key)
	if interaction.stamina_cost > 0:
		label_text += "  [ST: %d]" % int(interaction.stamina_cost)
	btn.text = label_text
	btn.tooltip_text = tr(interaction.description_key)

	# Capturar el ID por valor en el closure
	var iid := interaction.id
	btn.pressed.connect(func(): _vm.request_action(iid))

	return btn


func _clear_interaction_buttons() -> void:
	for child in interactions_vbox.get_children():
		child.queue_free()


func _set_buttons_enabled(enabled: bool) -> void:
	for child in interactions_vbox.get_children():
		if child is Button:
			child.disabled = not enabled


# ============================================
# SECCIÓN DE RESULTADO
# ============================================

func _show_result_section(
		feedback_key: String,
		outcome: String,
		info_key: String) -> void:

	separator.visible      = true
	feedback_label.visible = true
	feedback_label.text    = tr(feedback_key) if not feedback_key.is_empty() else outcome
	feedback_label.modulate = _outcome_color(outcome)

	if not info_key.is_empty():
		info_label.text    = tr(info_key)
		info_label.visible = true
	else:
		info_label.visible = false


func _show_depleted_message() -> void:
	separator.visible       = true
	feedback_label.visible  = true
	feedback_label.text     = tr("WORLD_OBJECT_DEPLETED")
	feedback_label.modulate = COLOR_DEPLETED
	info_label.visible      = false


func _hide_result_section() -> void:
	separator.visible      = false
	feedback_label.visible = false
	info_label.visible     = false


# ============================================
# UTILIDADES VISUALES
# ============================================

func _outcome_color(outcome: String) -> Color:
	match outcome:
		"critical": return COLOR_CRITICAL
		"success":  return COLOR_SUCCESS
		"failure":  return COLOR_FAILURE
		"fumble":   return COLOR_FUMBLE
	return Color.WHITE
