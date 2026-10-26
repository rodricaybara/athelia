extends CanvasLayer
class_name PartyUI

## PartyUI — View pasiva de la pantalla de Party (Spike 19a)
##
## Layout L3: Header | [Columna jugador | Columna compañero]. En cada columna,
## el equipo va en una columna vertical de slots fijos de 64 px a la izquierda
## de la mochila (pool de UISlot según la capacidad del personaje).
## El marco ocupa FRAME_FRACTION de la pantalla hasta FRAME_MAX_SIZE, centrado,
## con un fondo opaco detrás (mismo patrón que el inventario).
##
## Solo pinta el estado de PartyViewModel y traduce el input del jugador en
## llamadas a sus intenciones. No accede a ningún sistema core.
##
## Contrato público (sin cambios):
##   - open(), close(), toggle()
##   - signal closed
## `closed` sale junto a visible = false. PartyUI NUNCA se autolibera: quien la
## instancia (SceneOrchestrator, NarrativeScenePanel) hace queue_free().
##
## Drag & drop (los slots son pasivos):
##   - Mochila: UISlot arrastrable, no acepta drops. El payload lleva owner_id.
##   - Equipo: UISlot no arrastrable; acepta solo source == "inventory". Al recibir
##     un drop, la View pasa al ViewModel destino (owner_id del slot) y origen
##     (from_owner_id del payload).
##
## Esc y open_party cierran la pantalla (se consumen aquí).

signal closed

const SLOT_SCENE: PackedScene = preload("res://ui/design_system/components/ui_slot/ui_slot.tscn")
const BUTTON_SCENE: PackedScene = preload("res://ui/design_system/components/ui_button/ui_button.tscn")

## Hueco entre slots de la mochila (debe coincidir con h/v_separation de los GridContainer)
const BAG_GAP: int = 8
## Parte de la pantalla que ocupa el marco y tamaño máximo (px de pantalla)
const FRAME_FRACTION: float = 0.9
const FRAME_MAX_SIZE: Vector2 = Vector2(1400, 820)
## Separación del aviso respecto al borde inferior del marco
const POPUP_MARGIN: float = 8.0
## Reserva para la barra de desplazamiento al calcular columnas
const SCROLLBAR_RESERVE: int = 12
## Los slots de equipo solo aceptan lo que sale de una mochila
const DROP_FILTER: String = "inventory"


## Nodos y estado de pintado de una columna (jugador o compañero)
class ColumnView:
	var name_label: Label = null
	var slots_label: Label = null
	var equip_list: VBoxContainer = null
	var bag_scroll: ScrollContainer = null
	var bag_grid: GridContainer = null
	var equip_slots: Dictionary = {}          ## slot_id → UISlot
	var equip_signature: String = ""
	var bag_pool: Array[UISlot] = []


# ---- Marco y fondo ----
@onready var backdrop: ColorRect = %Backdrop
@onready var frame: Control = %Frame
@onready var feedback_popup = %FeedbackPopup

# ---- Cabecera ----
@onready var title_label: Label = %TitleLabel
@onready var close_button: UIButton = %CloseButton

# ---- Columna del jugador ----
@onready var player_name_label: Label = %PlayerNameLabel
@onready var player_slots_label: Label = %PlayerSlotsLabel
@onready var player_equip_list: VBoxContainer = %PlayerEquipList
@onready var player_bag_scroll: ScrollContainer = %PlayerBagScroll
@onready var player_bag_grid: GridContainer = %PlayerBagGrid

# ---- Columna del compañero ----
@onready var companion_tabs: HFlowContainer = %CompanionTabs
@onready var companion_header: HBoxContainer = %CompanionHeader
@onready var companion_name_label: Label = %CompanionNameLabel
@onready var strategy_option: OptionButton = %StrategyOption
@onready var companion_slots_label: Label = %CompanionSlotsLabel
@onready var companion_body: HBoxContainer = %CompanionBody
@onready var companion_equip_list: VBoxContainer = %CompanionEquipList
@onready var companion_bag_scroll: ScrollContainer = %CompanionBagScroll
@onready var companion_bag_grid: GridContainer = %CompanionBagGrid
@onready var no_companions_label: Label = %NoCompanionsLabel

var _vm: PartyViewModel = null
var _player_view: ColumnView = null
var _companion_view: ColumnView = null

var _tab_buttons: Array[UIButton] = []
var _tabs_signature: String = ""
var _strategy_signature: String = ""


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	_vm = PartyViewModel.new()
	_vm.name = "ViewModel"
	add_child(_vm)
	_vm.changed.connect(_on_vm_changed)

	_player_view = ColumnView.new()
	_player_view.name_label = player_name_label
	_player_view.slots_label = player_slots_label
	_player_view.equip_list = player_equip_list
	_player_view.bag_scroll = player_bag_scroll
	_player_view.bag_grid = player_bag_grid

	_companion_view = ColumnView.new()
	_companion_view.name_label = companion_name_label
	_companion_view.slots_label = companion_slots_label
	_companion_view.equip_list = companion_equip_list
	_companion_view.bag_scroll = companion_bag_scroll
	_companion_view.bag_grid = companion_bag_grid

	close_button.pressed.connect(close)
	strategy_option.item_selected.connect(_on_strategy_selected)
	player_bag_scroll.resized.connect(_update_grid_columns)
	companion_bag_scroll.resized.connect(_update_grid_columns)

	# Fondo opaco que oculta (y bloquea) lo de debajo
	backdrop.color = UITokens.COLOR_BG.darkened(0.4)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_update_frame_rect)
	_update_frame_rect()

	_setup_static_text()
	_style_strategy_option()

	# Nace oculta: quien la instancia llama a open()
	visible = false


func _setup_static_text() -> void:
	title_label.text = tr("PARTY_TITLE")
	title_label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_TITLE)
	title_label.add_theme_color_override("font_color", UITokens.COLOR_ACCENT)

	for label in [player_name_label, companion_name_label]:
		label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_LG)
		label.add_theme_color_override("font_color", UITokens.COLOR_ACCENT_SOFT)

	for label in [player_slots_label, companion_slots_label]:
		label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_MD)
		label.add_theme_color_override("font_color", UITokens.COLOR_TEXT)

	no_companions_label.text = tr("PARTY_NO_COMPANIONS")
	no_companions_label.add_theme_color_override("font_color", UITokens.COLOR_TEXT_MUTED)

	strategy_option.tooltip_text = tr("PARTY_STRATEGY_TOOLTIP")


## OptionButton con el aspecto de los botones SECONDARY del Design System
func _style_strategy_option() -> void:
	var normal := UITokens.make_stylebox(UITokens.COLOR_PANEL_ALT, UITokens.COLOR_BORDER_FOCUS,
		UITokens.BORDER_WIDTH, UITokens.BORDER_RADIUS_MD, UITokens.SPACE_SM)
	var hover := UITokens.make_stylebox(UITokens.COLOR_PANEL_ALT.lightened(0.08), UITokens.COLOR_BORDER_FOCUS,
		UITokens.BORDER_WIDTH, UITokens.BORDER_RADIUS_MD, UITokens.SPACE_SM)
	var disabled := UITokens.make_stylebox(UITokens.COLOR_PANEL_ALT.darkened(0.3), UITokens.COLOR_BORDER_FOCUS,
		UITokens.BORDER_WIDTH, UITokens.BORDER_RADIUS_MD, UITokens.SPACE_SM)
	strategy_option.add_theme_stylebox_override("normal", normal)
	strategy_option.add_theme_stylebox_override("hover", hover)
	strategy_option.add_theme_stylebox_override("pressed", hover)
	strategy_option.add_theme_stylebox_override("disabled", disabled)
	strategy_option.add_theme_stylebox_override("focus", UITokens.make_stylebox_outline(
		UITokens.COLOR_ACCENT, UITokens.BORDER_WIDTH_FOCUS, UITokens.BORDER_RADIUS_MD))
	strategy_option.add_theme_color_override("font_color", UITokens.COLOR_TEXT)
	strategy_option.add_theme_color_override("font_hover_color", UITokens.COLOR_TEXT)
	strategy_option.add_theme_color_override("font_pressed_color", UITokens.COLOR_TEXT)
	strategy_option.add_theme_color_override("font_focus_color", UITokens.COLOR_TEXT)
	strategy_option.add_theme_color_override("font_disabled_color", UITokens.COLOR_TEXT_DISABLED)
	strategy_option.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_MD)
	strategy_option.custom_minimum_size.y = UITokens.BUTTON_HEIGHT_SM

	var popup: PopupMenu = strategy_option.get_popup()
	popup.add_theme_stylebox_override("panel", UITokens.make_stylebox(UITokens.COLOR_PANEL, UITokens.COLOR_BORDER_FOCUS,
		UITokens.BORDER_WIDTH, UITokens.BORDER_RADIUS_MD, UITokens.SPACE_XS))
	popup.add_theme_stylebox_override("hover", UITokens.make_stylebox(UITokens.COLOR_PRIMARY, UITokens.COLOR_PRIMARY,
		0, UITokens.BORDER_RADIUS_SM, UITokens.SPACE_XS))
	popup.add_theme_color_override("font_color", UITokens.COLOR_TEXT)
	popup.add_theme_color_override("font_hover_color", UITokens.COLOR_TEXT_ON_PRIMARY)
	popup.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_MD)


# ============================================
# API PÚBLICA
# ============================================

func open() -> void:
	visible = true
	_vm.open()
	_update_frame_rect()
	call_deferred("_update_grid_columns")


## Cierra a través del ViewModel; la señal closed sale en el caso "closed"
func close() -> void:
	_vm.request_close()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


# ============================================
# CALLBACK ÚNICO DEL VIEWMODEL
# ============================================

func _on_vm_changed(reason: String) -> void:
	match reason:
		"opened", "party_changed":
			_render_all()
			call_deferred("_update_grid_columns")
		"player_column":
			_render_column(_player_view, _vm.player_column)
		"companion_column":
			_render_column(_companion_view, _vm.companion_column)
		"companion_changed":
			_render_companion_section()
		"feedback":
			_render_feedback()
		"closed":
			feedback_popup.hide_message()
			visible = false
			closed.emit()
		_:
			push_warning("[PartyUI] Razón desconocida: %s" % reason)


# ============================================
# RENDERS
# ============================================

func _render_all() -> void:
	_render_column(_player_view, _vm.player_column)
	_render_companion_section()


func _render_companion_section() -> void:
	var count: int = _vm.companions.size()
	var has_companions: bool = count > 0

	no_companions_label.visible = not has_companions
	companion_header.visible = has_companions
	companion_body.visible = has_companions
	# Con un solo compañero basta su nombre; las pestañas solo con 2 o más
	companion_tabs.visible = count >= 2
	companion_name_label.visible = count == 1

	_render_tabs()
	if not has_companions:
		return

	_render_strategy()
	_render_column(_companion_view, _vm.companion_column)


func _render_tabs() -> void:
	var ids: PackedStringArray = []
	for tab in _vm.companions:
		ids.append("%s:%s" % [tab.entity_id, tab.name])
	var signature: String = "|".join(ids)

	if signature != _tabs_signature:
		_tabs_signature = signature
		_tab_buttons.clear()
		for child in companion_tabs.get_children():
			companion_tabs.remove_child(child)
			child.queue_free()
		for i in range(_vm.companions.size()):
			var button: UIButton = BUTTON_SCENE.instantiate()
			button.btn_size = UIButton.Size.SM
			button.variant = UIButton.Variant.SECONDARY
			button.text = _vm.companions[i].name
			companion_tabs.add_child(button)
			button.pressed.connect(_on_tab_pressed.bind(i))
			_tab_buttons.append(button)

	for i in range(_tab_buttons.size()):
		var tab_button: UIButton = _tab_buttons[i]
		tab_button.set_variant(UIButton.Variant.PRIMARY if i == _vm.companion_index else UIButton.Variant.SECONDARY)


func _render_strategy() -> void:
	var parts: PackedStringArray = []
	for option in _vm.strategies:
		parts.append("%d:%s" % [option.id, option.name])
	var signature: String = "|".join(parts)

	if signature != _strategy_signature:
		_strategy_signature = signature
		strategy_option.clear()
		for option in _vm.strategies:
			strategy_option.add_item(option.name, option.id)

	var active_id: int = _vm.companion_column.active_strategy
	var active_index: int = strategy_option.get_item_index(active_id)
	if active_index >= 0:
		strategy_option.select(active_index)


func _render_column(view: ColumnView, data: PartyViewModel.ColumnData) -> void:
	view.name_label.text = data.display_name
	view.slots_label.text = tr("PARTY_SLOTS_COUNTER") % [data.used_slots, data.capacity]
	var over: bool = data.used_slots > data.capacity
	view.slots_label.add_theme_color_override("font_color", UITokens.COLOR_DANGER_SOFT if over else UITokens.COLOR_TEXT)
	_render_equipment(view, data)
	_render_bag(view, data)


func _render_equipment(view: ColumnView, data: PartyViewModel.ColumnData) -> void:
	var ids: PackedStringArray = []
	for entry in data.equip_entries:
		ids.append(entry.slot_id)
	var signature: String = ",".join(ids)

	if signature != view.equip_signature:
		view.equip_signature = signature
		view.equip_slots.clear()
		for child in view.equip_list.get_children():
			view.equip_list.remove_child(child)
			child.queue_free()
		for entry in data.equip_entries:
			var slot: UISlot = SLOT_SCENE.instantiate()
			slot.equipment_slot_id = entry.slot_id
			slot.draggable = false
			slot.drop_source_filter = DROP_FILTER
			slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			view.equip_list.add_child(slot)
			slot.slot_clicked.connect(_on_equip_slot_clicked)
			slot.slot_item_dropped.connect(_on_equip_item_dropped)
			view.equip_slots[entry.slot_id] = slot

	for entry in data.equip_entries:
		var equip_slot: UISlot = view.equip_slots.get(entry.slot_id) as UISlot
		if equip_slot == null:
			continue
		equip_slot.owner_id = data.entity_id
		equip_slot.slot_label_text = entry.slot_name
		if entry.definition != null:
			equip_slot.set_definition(entry.definition)
			equip_slot.tooltip_text = tr(entry.definition.name_key)
		else:
			equip_slot.clear()
			equip_slot.tooltip_text = ""


func _render_bag(view: ColumnView, data: PartyViewModel.ColumnData) -> void:
	var entries: Array[PartyViewModel.BagEntry] = data.bag_entries
	# Tantos huecos como capacidad (los vacíos se ven); si hay más pilas, solo las pilas
	var count: int = maxi(data.capacity, entries.size())

	while view.bag_pool.size() < count:
		view.bag_pool.append(_create_bag_slot(view))

	for i in range(view.bag_pool.size()):
		var slot: UISlot = view.bag_pool[i]
		if i >= count:
			slot.visible = false
			slot.clear()
			continue
		slot.visible = true
		slot.owner_id = data.entity_id
		slot.tooltip_text = ""
		if i < entries.size():
			_fill_bag_slot(slot, entries[i])
		else:
			slot.clear()


func _create_bag_slot(view: ColumnView) -> UISlot:
	var slot: UISlot = SLOT_SCENE.instantiate()
	slot.accept_drops = false
	slot.equipped_mark_text = tr("PARTY_EQUIPPED_BADGE")
	view.bag_grid.add_child(slot)
	slot.slot_clicked.connect(_on_bag_slot_clicked)
	return slot


func _fill_bag_slot(slot: UISlot, entry: PartyViewModel.BagEntry) -> void:
	slot.set_definition(entry.definition, entry.quantity)
	slot.set_equipped_mark(entry.is_equipped)
	slot.set_overflow(entry.is_overflow)

	var item_name: String = tr(entry.definition.name_key)
	var tooltip: String = item_name
	if entry.quantity > 1:
		tooltip = tr("PARTY_TOOLTIP_QUANTITY") % [item_name, entry.quantity]
	if entry.is_equipped:
		tooltip += "\n" + tr("PARTY_TOOLTIP_EQUIPPED")
	slot.tooltip_text = tooltip


func _render_feedback() -> void:
	if _vm.feedback_message.is_empty():
		return
	_update_popup_anchor()
	if _vm.feedback_is_error:
		feedback_popup.show_error(_vm.feedback_message)
	else:
		feedback_popup.show_success(_vm.feedback_message)


# ============================================
# LAYOUT
# ============================================

## Marco centrado: FRAME_FRACTION de la pantalla, con tope FRAME_MAX_SIZE
func _update_frame_rect() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var target := Vector2(
		minf(screen.x * FRAME_FRACTION, FRAME_MAX_SIZE.x),
		minf(screen.y * FRAME_FRACTION, FRAME_MAX_SIZE.y))
	frame.offset_left = -target.x / 2.0
	frame.offset_right = target.x / 2.0
	frame.offset_top = -target.y / 2.0
	frame.offset_bottom = target.y / 2.0


## El aviso va centrado, pegado al borde inferior del marco
func _update_popup_anchor() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var rect: Rect2 = frame.get_global_rect()
	if screen.x <= 0.0 or screen.y <= 0.0 or rect.size.x <= 0.0:
		return
	var anchor_x: float = rect.get_center().x / screen.x
	var anchor_y: float = (rect.end.y - POPUP_MARGIN) / screen.y
	feedback_popup.anchor_left = anchor_x
	feedback_popup.anchor_right = anchor_x
	feedback_popup.anchor_top = anchor_y
	feedback_popup.anchor_bottom = anchor_y
	feedback_popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	feedback_popup.grow_vertical = Control.GROW_DIRECTION_BEGIN


## Columnas de cada mochila según el ancho disponible
func _update_grid_columns() -> void:
	if _player_view == null or _companion_view == null:
		return
	var views: Array[ColumnView] = [_player_view, _companion_view]
	var slot_width: float = UITokens.SLOT_SIZE.x + BAG_GAP
	for view in views:
		var available: float = view.bag_scroll.size.x - SCROLLBAR_RESERVE
		view.bag_grid.columns = maxi(1, int((available + BAG_GAP) / slot_width))


# ============================================
# INPUT DE LA VIEW → VIEWMODEL
# ============================================

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("open_party") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _on_tab_pressed(index: int) -> void:
	_vm.select_companion(index)


func _on_strategy_selected(index: int) -> void:
	_vm.request_set_strategy(strategy_option.get_item_id(index))


func _on_bag_slot_clicked(slot: UISlot) -> void:
	if slot.is_empty():
		return
	_vm.request_slot_action(slot.get_item_id(), slot.owner_id)


func _on_equip_slot_clicked(slot: UISlot) -> void:
	if slot.is_empty():
		return
	_vm.request_unequip(slot.equipment_slot_id, slot.owner_id)


func _on_equip_item_dropped(slot: UISlot, item_id: String, from_owner_id: String) -> void:
	_vm.request_equip_drop(slot.equipment_slot_id, item_id, slot.owner_id, from_owner_id)
