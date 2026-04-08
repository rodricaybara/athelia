class_name LoadoutScreen
extends CanvasLayer

## LoadoutScreen — View
##
## Responsabilidades:
##   - Renderizar los slots del loadout y las listas de skills/consumibles disponibles
##   - Traducir clicks del jugador en llamadas al ViewModel
##   - NADA más
##
## Nunca accede a Skills, Inventory, CharacterState ni sistemas core.
## Todo pasa por LoadoutViewModel.
##
## Estructura esperada del .tscn:
##
## CanvasLayer                          ← este script
## └── Panel (PanelContainer)
##     └── MarginContainer
##         └── VBox (VBoxContainer)
##             ├── Header (HBoxContainer)
##             │   ├── TitleLabel (Label)
##             │   └── CloseButton (Button)
##             ├── ContentHBox (HBoxContainer)
##             │   ├── SlotsPanel (PanelContainer)   ← columna izquierda
##             │   │   └── MarginContainer
##             │   │       └── SlotsVBox (VBoxContainer)
##             │   │           ├── AttackSection (VBoxContainer)
##             │   │           │   ├── AttackLabel (Label)
##             │   │           │   └── AttackSlotsHBox (HBoxContainer)
##             │   │           ├── DefenseSection (VBoxContainer)
##             │   │           │   ├── DefenseLabel (Label)
##             │   │           │   └── DefenseSlotsHBox (HBoxContainer)
##             │   │           └── ConsumableSection (VBoxContainer)
##             │   │               ├── ConsumableLabel (Label)
##             │   │               └── ConsumableSlotsHBox (HBoxContainer)
##             │   └── AvailablePanel (PanelContainer) ← columna derecha
##             │       └── MarginContainer
##             │           └── AvailableVBox (VBoxContainer)
##             │               ├── AvailableLabel (Label)
##             │               └── AvailableScrollContainer (ScrollContainer)
##             │                   └── AvailableList (VBoxContainer)
##             └── FeedbackLabel (Label)


# ============================================
# NODOS
# ============================================

@onready var title_label:            Label          = $Panel/MarginContainer/VBox/Header/TitleLabel
@onready var close_button:           Button         = $Panel/MarginContainer/VBox/Header/CloseButton
@onready var attack_slots_hbox:      HBoxContainer  = $Panel/MarginContainer/VBox/ContentHBox/SlotsPanel/MarginContainer/SlotsVBox/AttackSection/AttackSlotsHBox
@onready var defense_slots_hbox:     HBoxContainer  = $Panel/MarginContainer/VBox/ContentHBox/SlotsPanel/MarginContainer/SlotsVBox/DefenseSection/DefenseSlotsHBox
@onready var consumable_slots_hbox:  HBoxContainer  = $Panel/MarginContainer/VBox/ContentHBox/SlotsPanel/MarginContainer/SlotsVBox/ConsumableSection/ConsumableSlotsHBox
@onready var available_list:         VBoxContainer  = $Panel/MarginContainer/VBox/ContentHBox/AvailablePanel/MarginContainer/AvailableVBox/AvailableScrollContainer/AvailableList
@onready var available_label:        Label          = $Panel/MarginContainer/VBox/ContentHBox/AvailablePanel/MarginContainer/AvailableVBox/AvailableLabel
@onready var feedback_label:         Label          = $Panel/MarginContainer/VBox/FeedbackLabel


# ============================================
# CONSTANTES VISUALES
# ============================================

const COLOR_SLOT_FILLED  := Color(0.3, 0.9, 0.3, 1.0)
const COLOR_SLOT_EMPTY   := Color(0.6, 0.6, 0.6, 1.0)
const COLOR_ERROR        := Color(0.9, 0.2, 0.2, 1.0)
const FEEDBACK_DURATION  := 2.5

## Slot seleccionado actualmente para asignar. "" si ninguno.
var _selected_slot_id: String = ""
var _feedback_timer: SceneTreeTimer = null


# ============================================
# ESTADO INTERNO
# ============================================

var _vm: LoadoutViewModel = null


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	visible = false

	_vm = LoadoutViewModel.new()
	_vm.name = "ViewModel"
	add_child(_vm)

	_vm.changed.connect(_on_vm_changed)
	close_button.pressed.connect(func(): _vm.request_close())

	print("[LoadoutScreen] Ready")


# ============================================
# API PÚBLICA — llamada desde SceneOrchestrator
# ============================================

func open(character_id: String) -> void:
	_vm.open(character_id)


# ============================================
# CALLBACK ÚNICO DEL VIEWMODEL
# ============================================

func _on_vm_changed(reason: String) -> void:
	match reason:
		"opened":
			_render_all()
		"slots":
			_render_slots()
		"error":
			_show_feedback(tr(_vm.error_message), true)
		"closed":
			visible = false
		_:
			push_warning("[LoadoutScreen] Razón desconocida: %s" % reason)


# ============================================
# RENDERS
# ============================================

func _render_all() -> void:
	title_label.text = tr("LOADOUT_TITLE")
	_render_slots()
	_render_available_list()
	feedback_label.visible = false
	visible = true


func _render_slots() -> void:
	_clear_container(attack_slots_hbox)
	_clear_container(defense_slots_hbox)
	_clear_container(consumable_slots_hbox)

	for slot_id in LoadoutState.SKILL_SLOTS:
		var data: LoadoutViewModel.SlotData = _vm.slots.get(slot_id)
		if data == null:
			continue
		var btn := _create_slot_button(data)
		_get_container_for_slot(slot_id).add_child(btn)

	for slot_id in LoadoutState.CONSUMABLE_SLOTS:
		var data: LoadoutViewModel.SlotData = _vm.slots.get(slot_id)
		if data == null:
			continue
		var btn := _create_slot_button(data)
		consumable_slots_hbox.add_child(btn)


func _render_available_list() -> void:
	_clear_container(available_list)

	# Skills disponibles
	if not _vm.available_skills.is_empty():
		var section_label := Label.new()
		section_label.text = tr("LOADOUT_SKILLS_AVAILABLE")
		available_list.add_child(section_label)

		for skill_data in _vm.available_skills:
			var btn := _create_available_skill_button(skill_data)
			available_list.add_child(btn)

	# Consumibles disponibles
	if not _vm.available_consumables.is_empty():
		var section_label := Label.new()
		section_label.text = tr("LOADOUT_CONSUMABLES_AVAILABLE")
		available_list.add_child(section_label)

		for consumable_data in _vm.available_consumables:
			var btn := _create_available_consumable_button(consumable_data)
			available_list.add_child(btn)


# ============================================
# CONSTRUCCIÓN DE BOTONES
# ============================================

func _create_slot_button(data: LoadoutViewModel.SlotData) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(80, 60)

	if data.is_empty:
		btn.text = tr("LOADOUT_SLOT_EMPTY")
		btn.modulate = COLOR_SLOT_EMPTY
	else:
		btn.text = tr(data.display_name)
		btn.modulate = COLOR_SLOT_FILLED

	# Tooltip con el tag requerido
	if data.slot_type == "skill" and data.required_tag != "":
		btn.tooltip_text = tr("LOADOUT_REQUIRES_TAG") + ": " + data.required_tag

	# Seleccionar este slot para asignar
	var sid := data.slot_id
	btn.pressed.connect(func(): _on_slot_pressed(sid))

	# Resaltar si está seleccionado
	if _selected_slot_id == data.slot_id:
		btn.modulate = Color(1.0, 0.85, 0.0)

	return btn


func _create_available_skill_button(data: LoadoutViewModel.SkillSlotData) -> Button:
	var btn := Button.new()

	var label := tr(data.display_name)
	if data.stamina_cost > 0:
		label += "  [ST:%d]" % data.stamina_cost
	btn.text = label
	btn.tooltip_text = ", ".join(data.tags)

	var skill_id := data.skill_id
	btn.pressed.connect(func(): _on_available_skill_pressed(skill_id))

	return btn


func _create_available_consumable_button(data: LoadoutViewModel.ConsumableSlotData) -> Button:
	var btn := Button.new()
	btn.text = "%s (x%d)" % [tr(data.display_name), data.quantity]

	var item_id := data.item_id
	btn.pressed.connect(func(): _on_available_consumable_pressed(item_id))

	return btn


# ============================================
# INPUT — LÓGICA DE SELECCIÓN EN DOS PASOS
#
# Paso 1: jugador pulsa un slot → queda seleccionado (_selected_slot_id)
# Paso 2: jugador pulsa un ítem de la lista → se asigna al slot seleccionado
# ============================================

func _on_slot_pressed(slot_id: String) -> void:
	if _selected_slot_id == slot_id:
		# Segundo click sobre el mismo slot → deseleccionar o limpiar
		_selected_slot_id = ""
		_vm.request_clear_slot(slot_id)
	else:
		_selected_slot_id = slot_id
		# Refrescar slots para mostrar el resaltado
		_render_slots()


func _on_available_skill_pressed(skill_id: String) -> void:
	if _selected_slot_id == "":
		_show_feedback(tr("LOADOUT_SELECT_SLOT_FIRST"), false)
		return

	_vm.request_assign_skill(_selected_slot_id, skill_id)
	_selected_slot_id = ""


func _on_available_consumable_pressed(item_id: String) -> void:
	if _selected_slot_id == "":
		_show_feedback(tr("LOADOUT_SELECT_SLOT_FIRST"), false)
		return

	_vm.request_assign_consumable(_selected_slot_id, item_id)
	_selected_slot_id = ""


# ============================================
# UTILIDADES
# ============================================

func _get_container_for_slot(slot_id: String) -> HBoxContainer:
	match slot_id:
		"attack_1", "attack_2", "attack_3":
			return attack_slots_hbox
		"dodge", "defense", "escape":
			return defense_slots_hbox
	return defense_slots_hbox


func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.free()


func _show_feedback(message: String, is_error: bool) -> void:
	feedback_label.text = message
	feedback_label.modulate = COLOR_ERROR if is_error else Color.WHITE
	feedback_label.visible = true

	if _feedback_timer and is_instance_valid(_feedback_timer):
		_feedback_timer.timeout.disconnect(_hide_feedback)

	_feedback_timer = get_tree().create_timer(FEEDBACK_DURATION)
	_feedback_timer.timeout.connect(_hide_feedback)


func _hide_feedback() -> void:
	if feedback_label:
		feedback_label.visible = false
