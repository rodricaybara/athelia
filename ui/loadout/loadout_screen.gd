class_name LoadoutScreen
extends CanvasLayer

## LoadoutScreen — View (Spike 20: Design System, selección con pista visual)
##
## Responsabilidades:
##   - Pintar los slots agrupados, la lista de candidatos y el cajetín
##   - Traducir clics en intenciones del ViewModel
##   - NADA más
##
## Nunca accede a Skills, Inventory, Characters, Items ni LoadoutState.
## Todo pasa por LoadoutViewModel, que entrega claves; la View traduce.
##
## Contratos públicos (intactos): open(character_id) y señal `closed`.
## LoadoutScreen NUNCA se autolibera: quien la instancia (PlayerMenuScreen,
## SceneOrchestrator) hace queue_free() al recibir `closed`.


signal closed


const UI_SLOT_SCENE: PackedScene = preload("res://ui/design_system/components/ui_slot/ui_slot.tscn")

const FRAME_FRACTION: float = 0.9
const FRAME_MAX_SIZE: Vector2 = Vector2(1400, 820)
const FEEDBACK_DURATION: float = 2.5
const SKILL_COLUMNS: int = 3


@onready var backdrop: ColorRect = %Backdrop
@onready var frame: Control = %Frame
@onready var title_label: Label = %TitleLabel
@onready var close_button: Button = %CloseButton
@onready var slots_box: VBoxContainer = %SlotsBox
@onready var list_header: Label = %ListHeader
@onready var list_message: Label = %ListMessage
@onready var list_box: VBoxContainer = %ListBox
@onready var detail_name: Label = %DetailName
@onready var detail_meta: Label = %DetailMeta
@onready var detail_desc: Label = %DetailDesc
@onready var clear_button: Button = %ClearButton
@onready var feedback_label: Label = %FeedbackLabel
@onready var feedback_timer: Timer = %FeedbackTimer


var _vm: LoadoutViewModel = null

## Entrada bajo el ratón (solo vista: no es estado del ViewModel).
var _hover_entry: LoadoutViewModel.EntryData = null
var _render_pending: bool = false


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	visible = false
	backdrop.color = UITokens.BG_VOID
	_style_static_labels()

	_vm = LoadoutViewModel.new()
	_vm.name = "ViewModel"
	add_child(_vm)
	_vm.changed.connect(_on_vm_changed)

	close_button.pressed.connect(func() -> void: _vm.request_close())
	clear_button.pressed.connect(_on_clear_pressed)
	feedback_timer.timeout.connect(_hide_feedback)

	get_viewport().size_changed.connect(_update_frame_rect)
	_update_frame_rect()

	print("[LoadoutScreen] Ready")


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_vm.request_close()
		get_viewport().set_input_as_handled()


# ============================================
# API PÚBLICA
# ============================================

func open(character_id: String) -> void:
	_vm.open(character_id)


# ============================================
# CALLBACK ÚNICO DEL VIEWMODEL
# ============================================

func _on_vm_changed(reason: String) -> void:
	match reason:
		"opened":
			_hover_entry = null
			title_label.text = tr("LOADOUT_TITLE")
			_hide_feedback()
			_render_all()
			_update_frame_rect()
			visible = true
		"selection", "slots":
			# Diferido: el clic que lo provocó viene de una ficha que vamos
			# a destruir al repintar.
			_schedule_render()
		"error":
			_show_feedback(tr(_vm.error_message))
		"closed":
			_hover_entry = null
			visible = false
			closed.emit()
		_:
			push_warning("[LoadoutScreen] Razón desconocida: %s" % reason)


func _schedule_render() -> void:
	if _render_pending:
		return
	_render_pending = true
	call_deferred("_flush_render")


func _flush_render() -> void:
	_render_pending = false
	if not visible:
		return
	_hover_entry = null
	_render_all()


# ============================================
# RENDERS
# ============================================

func _render_all() -> void:
	_render_slots()
	_render_list()
	_render_detail()


func _render_slots() -> void:
	_clear_container(slots_box)

	for group: LoadoutViewModel.GroupData in _vm.groups:
		var header := Label.new()
		header.text = tr(group.title_key)
		_style_label(header, UITokens.FONT_SIZE_SM, UITokens.COLOR_ACCENT)
		slots_box.add_child(header)

		if group.slot_type == "consumable":
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", UITokens.SPACE_SM)
			slots_box.add_child(row)
			for slot_id in group.slot_ids:
				var data: LoadoutViewModel.SlotData = _vm.slots.get(slot_id)
				if data != null:
					_add_consumable_slot(row, data)
		else:
			var grid := GridContainer.new()
			grid.columns = SKILL_COLUMNS
			grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_theme_constant_override("h_separation", UITokens.SPACE_SM)
			grid.add_theme_constant_override("v_separation", UITokens.SPACE_SM)
			slots_box.add_child(grid)
			for slot_id in group.slot_ids:
				var data: LoadoutViewModel.SlotData = _vm.slots.get(slot_id)
				if data != null:
					grid.add_child(_make_skill_card(data))


func _make_skill_card(data: LoadoutViewModel.SlotData) -> LoadoutCard:
	var card := LoadoutCard.new(LoadoutCard.Layout.STACKED)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.data = data

	var title: String = tr("LOADOUT_SLOT_EMPTY")
	if data.is_fixed or not data.is_empty:
		title = tr(data.name_key)

	card.setup(tr(data.label_key), title, data.keybind_label)
	card.set_empty(data.is_empty or data.is_fixed)
	card.set_selected(data.is_selected)
	card.interactive = not data.is_fixed
	card.pressed.connect(_on_slot_card_pressed)
	card.hover_changed.connect(_on_card_hover)
	return card


func _add_consumable_slot(parent: Control, data: LoadoutViewModel.SlotData) -> void:
	var slot := UI_SLOT_SCENE.instantiate() as UISlot
	slot.draggable = false
	slot.accept_drops = false
	slot.slot_label_text = data.keybind_label
	parent.add_child(slot)

	# set_definition necesita el nodo ya en el árbol (@onready de UISlot).
	if data.definition != null:
		slot.set_definition(data.definition, data.quantity)
	slot.set_selected(data.is_selected)

	slot.slot_clicked.connect(_on_consumable_slot_clicked.bind(data.slot_id))
	slot.mouse_entered.connect(_set_hover.bind(data))
	slot.mouse_exited.connect(_set_hover.bind(null))


func _render_list() -> void:
	list_header.text = tr(_vm.list_header_key)
	list_message.visible = _vm.list_message_key != ""
	if list_message.visible:
		list_message.text = tr(_vm.list_message_key)

	_clear_container(list_box)
	for cand: LoadoutViewModel.CandidateData in _vm.candidates:
		var card := LoadoutCard.new(LoadoutCard.Layout.INLINE)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.data = cand
		card.setup("", tr(cand.name_key), _candidate_trail(cand))
		card.set_marked(cand.is_assigned_here)
		card.interactive = not cand.is_assigned_here
		card.pressed.connect(_on_candidate_pressed)
		card.hover_changed.connect(_on_card_hover)
		list_box.add_child(card)


func _candidate_trail(cand: LoadoutViewModel.CandidateData) -> String:
	if cand.is_assigned_here:
		return tr("LOADOUT_ASSIGNED_HERE")
	if cand.slot_type == "consumable":
		return "x%d" % cand.quantity
	return _cost_text(cand)


## Cajetín: la entrada bajo el ratón o, si no hay, el contenido del slot
## elegido. «Vaciar» solo aparece cuando lo mostrado es ese contenido.
func _render_detail() -> void:
	var selected: LoadoutViewModel.SlotData = _vm.get_selected_slot()
	var entry: LoadoutViewModel.EntryData = _hover_entry
	if entry == null and selected != null and not selected.is_empty:
		entry = selected

	clear_button.text = tr("LOADOUT_CLEAR")
	clear_button.visible = selected != null and not selected.is_empty and entry == selected

	if entry == null:
		detail_name.text = ""
		detail_meta.text = ""
		detail_desc.text = tr("LOADOUT_DETAIL_HINT")
		return

	var slot_entry := entry as LoadoutViewModel.SlotData
	if slot_entry != null and (slot_entry.is_empty or slot_entry.is_fixed):
		detail_name.text = tr(slot_entry.label_key)
	else:
		detail_name.text = tr(entry.name_key)

	var lines: PackedStringArray = []
	if not entry.costs.is_empty():
		lines.append(tr("LOADOUT_DETAIL_COST") % _cost_text(entry))
	if not entry.tag_keys.is_empty():
		var tag_names: PackedStringArray = []
		for key in entry.tag_keys:
			tag_names.append(tr(key))
		var line_key: String = "LOADOUT_DETAIL_FITS" if entry.tag_mode == "fits" else "LOADOUT_DETAIL_REQUIRES"
		lines.append(tr(line_key) % ", ".join(tag_names))
	if entry.slot_type == "consumable" and entry.id != "":
		lines.append(tr("LOADOUT_DETAIL_QUANTITY") % entry.quantity)
	detail_meta.text = "\n".join(lines)

	if slot_entry != null and slot_entry.is_empty and not slot_entry.is_fixed:
		detail_desc.text = tr("LOADOUT_DETAIL_SLOT_EMPTY")
	else:
		detail_desc.text = _translate_or_empty(entry.description_key)


# ============================================
# INPUT → INTENCIONES
# ============================================

func _on_slot_card_pressed(card: LoadoutCard) -> void:
	var data := card.data as LoadoutViewModel.SlotData
	if data != null:
		_vm.request_select_slot(data.slot_id)


func _on_consumable_slot_clicked(_slot: UISlot, slot_id: String) -> void:
	_vm.request_select_slot(slot_id)


func _on_candidate_pressed(card: LoadoutCard) -> void:
	var cand := card.data as LoadoutViewModel.CandidateData
	if cand == null:
		return
	if cand.slot_type == "skill":
		_vm.request_assign_skill(_vm.selected_slot_id, cand.id)
	else:
		_vm.request_assign_consumable(_vm.selected_slot_id, cand.id)


func _on_clear_pressed() -> void:
	_vm.request_clear_slot(_vm.selected_slot_id)


func _on_card_hover(card: LoadoutCard, inside: bool) -> void:
	if inside:
		_set_hover(card.data as LoadoutViewModel.EntryData)
	else:
		_set_hover(null)


func _set_hover(entry: LoadoutViewModel.EntryData) -> void:
	if _hover_entry == entry:
		return
	_hover_entry = entry
	_render_detail()


# ============================================
# TEXTO
# ============================================

func _cost_text(entry: LoadoutViewModel.EntryData) -> String:
	var parts: PackedStringArray = []
	for cost: LoadoutViewModel.CostData in entry.costs:
		parts.append("%s %d" % [_resource_name(cost.resource_id), cost.amount])
	return ", ".join(parts)


## Nombre localizado del recurso; si no hay clave RESOURCE_*_NAME, el id.
func _resource_name(resource_id: String) -> String:
	var key: String = "RESOURCE_%s_NAME" % resource_id.to_upper()
	var text: String = tr(key)
	return resource_id.capitalize() if text == key else text


func _translate_or_empty(key: String) -> String:
	if key == "":
		return ""
	var text: String = tr(key)
	return "" if text == key else text


# ============================================
# FEEDBACK
# ============================================

func _show_feedback(message: String) -> void:
	feedback_label.text = message
	feedback_label.add_theme_color_override("font_color", UITokens.COLOR_DANGER_SOFT)
	feedback_timer.start(FEEDBACK_DURATION)


func _hide_feedback() -> void:
	feedback_label.text = ""


# ============================================
# UTILIDADES
# ============================================

func _style_static_labels() -> void:
	_style_label(title_label, UITokens.FONT_SIZE_TITLE, UITokens.TEXT_PRIMARY)
	_style_label(list_header, UITokens.FONT_SIZE_SM, UITokens.COLOR_ACCENT)
	_style_label(list_message, UITokens.FONT_SIZE_MD, UITokens.TEXT_MUTED)
	_style_label(detail_name, UITokens.FONT_SIZE_LG, UITokens.TEXT_PRIMARY)
	_style_label(detail_meta, UITokens.FONT_SIZE_SM, UITokens.TEXT_SECONDARY)
	_style_label(detail_desc, UITokens.FONT_SIZE_MD, UITokens.TEXT_PRIMARY)
	_style_label(feedback_label, UITokens.FONT_SIZE_MD, UITokens.COLOR_DANGER_SOFT)


func _style_label(label: Label, font_size: int, color: Color) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)


func _clear_container(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


## Marco centrado: FRAME_FRACTION de la pantalla, con tope FRAME_MAX_SIZE
## (mismo criterio que Inventario y Party).
func _update_frame_rect() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var target := Vector2(
		minf(screen.x * FRAME_FRACTION, FRAME_MAX_SIZE.x),
		minf(screen.y * FRAME_FRACTION, FRAME_MAX_SIZE.y))
	frame.offset_left = -target.x / 2.0
	frame.offset_right = target.x / 2.0
	frame.offset_top = -target.y / 2.0
	frame.offset_bottom = target.y / 2.0
