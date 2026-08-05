extends CanvasLayer
class_name CharacterCreationScreen

## CharacterCreationScreen — View del flujo de creación de personaje.
## Contrato MVVM (ver docs/athelia_ui_architecture.md):
##   - No accede a sistemas core directamente.
##   - Traduce input del jugador en llamadas a _vm.request_X().
##   - _on_vm_changed(reason) es el único punto de entrada de renderizado.

const ATTRIBUTE_LABEL_KEYS: Dictionary = {
	"strength": "CC_ATTR_STRENGTH",
	"dexterity": "CC_ATTR_DEXTERITY",
	"constitution": "CC_ATTR_CONSTITUTION",
	"intelligence": "CC_ATTR_INTELLIGENCE",
	"wisdom": "CC_ATTR_WISDOM",
	"charisma": "CC_ATTR_CHARISMA",
}

const SLOT_UNIQUE_NAMES: Dictionary = {
	"strength": "SlotStrength",
	"dexterity": "SlotDexterity",
	"constitution": "SlotConstitution",
	"intelligence": "SlotIntelligence",
	"wisdom": "SlotWisdom",
	"charisma": "SlotCharisma",
}

# ============================================
# @onready — nodos del .tscn
# ============================================

@onready var attribute_roll_panel: Control = %AttributeRollPanel
@onready var roll_title_label: Label = %RollTitleLabel
@onready var physical_pool_container: HBoxContainer = %PhysicalPoolContainer
@onready var resilient_pool_container: HBoxContainer = %ResilientPoolContainer
@onready var attribute_slots_container: GridContainer = %AttributeSlotsContainer
@onready var btn_roll: Button = %BtnRoll
@onready var btn_reroll: Button = %BtnReroll
@onready var btn_continue_assign: Button = %BtnContinueAssign

@onready var name_panel: Control = %NamePanel
@onready var name_title_label: Label = %NameTitleLabel
@onready var name_line_edit: LineEdit = %NameLineEdit
@onready var btn_continue_name: Button = %BtnContinueName

@onready var summary_panel: Control = %SummaryPanel
@onready var summary_title_label: Label = %SummaryTitleLabel
@onready var attributes_summary_label: RichTextLabel = %AttributesSummaryLabel
@onready var skills_summary_label: RichTextLabel = %SkillsSummaryLabel
@onready var equipment_summary_label: RichTextLabel = %EquipmentSummaryLabel
@onready var btn_back_to_naming: Button = %BtnBackToNaming
@onready var btn_confirm: Button = %BtnConfirm

@onready var error_feedback_label: Label = %ErrorFeedbackLabel
@onready var btn_back_to_menu: Button = %BtnBackToMenu

# ============================================
# Estado interno de la View (puramente de interacción, no de negocio)
# ============================================

var _vm: CharacterCreationViewModel = null

## Chip actualmente seleccionado antes de asignarlo a un slot.
## -1 = ninguno seleccionado.
var _selected_chip_value: int = -1
var _selected_chip_pool: String = ""  # "physical" o "resilient"
var _selected_chip_button: Button = null

var _feedback_timer: SceneTreeTimer = null


func _ready() -> void:
	visible = false

	_vm = CharacterCreationViewModel.new()
	_vm.name = "ViewModel"
	add_child(_vm)
	_vm.changed.connect(_on_vm_changed)

	_setup_static_text()
	_connect_buttons()


func open() -> void:
	visible = true
	_vm.open()


# ============================================
# TEXTOS ESTÁTICOS Y CONEXIONES
# ============================================

func _setup_static_text() -> void:
	roll_title_label.text = tr("CC_ROLL_TITLE")
	btn_roll.text = tr("CC_BTN_ROLL")
	btn_reroll.text = tr("CC_BTN_REROLL")
	btn_continue_assign.text = tr("CC_BTN_CONTINUE")

	name_title_label.text = tr("CC_NAME_TITLE")
	name_line_edit.placeholder_text = tr("CC_NAME_PLACEHOLDER")
	btn_continue_name.text = tr("CC_BTN_CONTINUE")

	summary_title_label.text = tr("CC_SUMMARY_TITLE")
	btn_back_to_naming.text = tr("CC_BTN_BACK")
	btn_confirm.text = tr("CC_BTN_CONFIRM")

	btn_back_to_menu.text = tr("CC_BTN_BACK_TO_MENU")

	for attr_id in SLOT_UNIQUE_NAMES.keys():
		var slot_button: Button = get_node("%" + String(SLOT_UNIQUE_NAMES[attr_id]))
		slot_button.set_meta("attribute_id", attr_id)


func _connect_buttons() -> void:
	btn_roll.pressed.connect(func(): _vm.request_roll_attributes())
	btn_reroll.pressed.connect(func(): _vm.request_reroll())
	btn_continue_assign.pressed.connect(func(): _vm.request_continue_to_naming())

	for chip_button in _all_chip_buttons():
		chip_button.pressed.connect(_on_chip_pressed.bind(chip_button))

	for attr_id in SLOT_UNIQUE_NAMES.keys():
		var slot_button: Button = get_node("%" + String(SLOT_UNIQUE_NAMES[attr_id]))
		slot_button.pressed.connect(_on_slot_pressed.bind(attr_id))

	btn_continue_name.pressed.connect(func(): _vm.request_continue_to_summary())
	name_line_edit.text_changed.connect(func(new_text): _vm.set_character_name(new_text))

	btn_back_to_naming.pressed.connect(func(): _vm.request_back_to_naming())
	btn_confirm.pressed.connect(func(): _vm.request_confirm_character())

	btn_back_to_menu.pressed.connect(func(): _vm.request_back_to_menu())


func _all_chip_buttons() -> Array:
	var result: Array = []
	for child in physical_pool_container.get_children():
		result.append(child)
	for child in resilient_pool_container.get_children():
		result.append(child)
	return result


# ============================================
# CALLBACK ÚNICO DEL VIEWMODEL
# ============================================

func _on_vm_changed(reason: String) -> void:
	match reason:
		"opened":                       _render_opened()
		"rolled", "rerolled":           _render_pools()
		"assigned":                     _render_assignment()
		"error_incomplete_assignment":  _show_feedback(tr("CC_ERROR_INCOMPLETE"), true)
		"naming":                       _render_naming()
		"error_empty_name":             _show_feedback(tr("CC_ERROR_EMPTY_NAME"), true)
		"error_name_too_long":          _show_feedback(tr("CC_ERROR_NAME_TOO_LONG"), true)
		"summary":                      _render_summary()
		"transitioning":                _set_all_buttons_enabled(false)
		_: push_warning("[CharacterCreationScreen] Razón desconocida: %s" % reason)


# ============================================
# RENDERS
# ============================================

func _render_opened() -> void:
	attribute_roll_panel.visible = true
	name_panel.visible = false
	summary_panel.visible = false

	_selected_chip_value = -1
	_selected_chip_pool = ""
	_selected_chip_button = null

	btn_roll.visible = true
	btn_roll.disabled = false
	btn_reroll.visible = false
	btn_continue_assign.disabled = true

	for chip_button in _all_chip_buttons():
		chip_button.visible = false

	for attr_id in SLOT_UNIQUE_NAMES.keys():
		_render_slot(attr_id, null)

	_set_all_buttons_enabled(true)


func _render_pools() -> void:
	btn_roll.visible = false
	btn_reroll.visible = not _vm.reroll_used
	btn_reroll.disabled = _vm.reroll_used
	_refresh_chip_buttons()

	for attr_id in SLOT_UNIQUE_NAMES.keys():
		_render_slot(attr_id, null)

	btn_continue_assign.disabled = true


func _render_assignment() -> void:
	_refresh_chip_buttons()

	for attr_id in SLOT_UNIQUE_NAMES.keys():
		var value = _vm.assigned_attributes.get(attr_id, null)
		_render_slot(attr_id, value)

	btn_continue_assign.disabled = not _vm.is_fully_assigned()


## Sincroniza los botones-chip con el contenido actual de los pools del VM.
func _refresh_chip_buttons() -> void:
	_populate_chip_container(physical_pool_container, _vm.physical_pool)
	_populate_chip_container(resilient_pool_container, _vm.resilient_pool)
	_selected_chip_value = -1
	_selected_chip_pool = ""
	_selected_chip_button = null


func _populate_chip_container(container: HBoxContainer, pool: Array) -> void:
	var children: Array = container.get_children()
	for i in range(children.size()):
		var chip_button: Button = children[i]
		if i < pool.size():
			chip_button.visible = true
			chip_button.disabled = false
			chip_button.button_pressed = false
			chip_button.text = str(pool[i])
			chip_button.set_meta("value", pool[i])
		else:
			chip_button.visible = false
			chip_button.button_pressed = false


func _render_slot(attribute_id: String, value) -> void:
	var slot_button: Button = get_node("%" + String(SLOT_UNIQUE_NAMES[attribute_id]))
	var label_key: String = ATTRIBUTE_LABEL_KEYS[attribute_id]
	if value == null:
		slot_button.text = "%s: —" % tr(label_key)
	else:
		slot_button.text = "%s: %d" % [tr(label_key), value]


func _render_naming() -> void:
	attribute_roll_panel.visible = false
	name_panel.visible = true
	summary_panel.visible = false
	name_line_edit.text = _vm.character_name
	name_line_edit.grab_focus()


func _render_summary() -> void:
	attribute_roll_panel.visible = false
	name_panel.visible = false
	summary_panel.visible = true

	summary_title_label.text = tr("CC_SUMMARY_TITLE") + " — " + _vm.character_name

	var attr_bbcode: String = "[table=2]"
	for attr_id in SLOT_UNIQUE_NAMES.keys():
		var value: int = _vm.assigned_attributes.get(attr_id, 0)
		attr_bbcode += "[cell]%s[/cell][cell]%d[/cell]" % [tr(ATTRIBUTE_LABEL_KEYS[attr_id]), value]
	attr_bbcode += "[/table]"
	attributes_summary_label.text = attr_bbcode

	skills_summary_label.text = "[b]%s[/b]\n%s" % [tr("CC_SUMMARY_SKILLS_TITLE"), tr("CC_SUMMARY_SKILLS")]
	equipment_summary_label.text = "[b]%s[/b]\n%s" % [tr("CC_SUMMARY_EQUIPMENT_TITLE"), tr("CC_SUMMARY_EQUIPMENT")]


func _set_all_buttons_enabled(enabled: bool) -> void:
	btn_roll.disabled = not enabled
	btn_reroll.disabled = not enabled or _vm.reroll_used
	btn_continue_assign.disabled = not enabled or not _vm.is_fully_assigned()
	btn_continue_name.disabled = not enabled
	btn_back_to_naming.disabled = not enabled
	btn_confirm.disabled = not enabled
	btn_back_to_menu.disabled = not enabled


# ============================================
# INPUT — CHIPS Y SLOTS
# ============================================

func _on_chip_pressed(chip_button: Button) -> void:
	# Desmarcar el chip previamente seleccionado (si lo hay)
	if _selected_chip_button and is_instance_valid(_selected_chip_button):
		_selected_chip_button.button_pressed = false

	# Si se pulsa el mismo chip ya seleccionado, deseleccionar
	if _selected_chip_button == chip_button:
		_selected_chip_value = -1
		_selected_chip_pool = ""
		_selected_chip_button = null
		chip_button.button_pressed = false
		return

	_selected_chip_value = chip_button.get_meta("value")
	_selected_chip_pool = "physical" if chip_button.get_parent() == physical_pool_container else "resilient"
	_selected_chip_button = chip_button
	chip_button.button_pressed = true


func _on_slot_pressed(attribute_id: String) -> void:
	var is_assigned: bool = _vm.assigned_attributes.has(attribute_id)

	if is_assigned:
		_vm.request_unassign_attribute(attribute_id)
		return

	if _selected_chip_value == -1:
		_show_feedback(tr("CC_ERROR_NO_CHIP_SELECTED"), true)
		return

	var slot_pool: String = "physical" if attribute_id in CharacterCreationViewModel.PHYSICAL_ATTRIBUTES else "resilient"
	if slot_pool != _selected_chip_pool:
		_show_feedback(tr("CC_ERROR_WRONG_POOL"), true)
		return

	_vm.request_assign_value(_selected_chip_value, attribute_id)


# ============================================
# FEEDBACK TEMPORAL — sin await, patrón SceneTreeTimer
# ============================================

func _show_feedback(message: String, _is_error: bool) -> void:
	error_feedback_label.text = message
	error_feedback_label.visible = true

	if _feedback_timer and is_instance_valid(_feedback_timer):
		_feedback_timer.timeout.disconnect(_hide_feedback)

	_feedback_timer = get_tree().create_timer(3.0)
	_feedback_timer.timeout.connect(_hide_feedback)


func _hide_feedback() -> void:
	if error_feedback_label:
		error_feedback_label.visible = false
