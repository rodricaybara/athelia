extends CanvasLayer

## InventoryUI - View pasiva del inventario (Spike 17: contrato MVVM;
## Spike 18: rediseño con el Design System)
##
## Layout: Header | [Equipo | Pestañas + Mochila | Detalle + Estadísticas]
## El marco ocupa FRAME_FRACTION de la pantalla hasta FRAME_MAX_SIZE y queda
## centrado (en 1152×648 es el 90 %; en pantallas grandes no se estira más).
## Detrás hay un fondo opaco (Backdrop) que oculta la pantalla de debajo y
## bloquea sus clics. Solo tokens del Design System.
##
## Solo pinta el estado del InventoryViewModel y traduce el input del jugador
## en llamadas request_*() / select_*(). No accede a ningún sistema core.
##
## Contrato público (sin cambios desde el Spike 17):
##   - open_inventory(), close_inventory(), toggle()
##   - signal closed
##   - @export entity_id
##
## `closed` se emite junto a visible = false. InventoryUI NUNCA se autolibera:
## quien la instancia (SceneOrchestrator, PlayerMenuScreen, NarrativeScenePanel)
## hace queue_free() al recibir la señal.
##
## Drag & drop (los slots son pasivos):
##   - Mochila: UISlot arrastrable, no acepta drops. Payload {item_id, source:"inventory"}.
##   - Equipo: UISlot no arrastrable, acepta solo source == "inventory"; al recibir
##     el drop la View llama a request_equip_drop(slot_id, item_id).
##
## Esc cierra el inventario. Se consume aquí (set_input_as_handled) para que,
## en el anidado, solo se cierre la capa más profunda. No se comprueba
## is_input_blocked(): esta entrada cierra, no abre, y debe funcionar también
## en NARRATIVE_SCENE.

signal closed

@export var entity_id: String = "player"

const SLOT_SCENE: PackedScene = preload("res://ui/design_system/components/ui_slot/ui_slot.tscn")
const BUTTON_SCENE: PackedScene = preload("res://ui/design_system/components/ui_button/ui_button.tscn")

## Hueco entre slots de la mochila (debe coincidir con h/v_separation de BagGrid en el .tscn)
const BAG_GAP: int = 8
## Parte de la pantalla que ocupa el marco y tamaño máximo (px de pantalla)
const FRAME_FRACTION: float = 0.9
const FRAME_MAX_SIZE: Vector2 = Vector2(1400, 820)
## Separación del aviso respecto al borde inferior de la mochila
const POPUP_MARGIN: float = 8.0

## Reserva para la barra de desplazamiento al calcular columnas
const SCROLLBAR_RESERVE: int = 12

## Color de borde por categoría (decisión visual de la View; el ViewModel solo da el id)
const CATEGORY_COLORS: Dictionary = {
	"weapons": UITokens.COLOR_WARNING,
	"armor": UITokens.COLOR_BORDER_FOCUS,
	"consumables": UITokens.COLOR_SUCCESS,
	"quest": UITokens.COLOR_ACCENT_SOFT,
}

# ---- Marco y fondo ----
@onready var backdrop: ColorRect = %Backdrop
@onready var frame: Control = %Frame
@onready var bag_column: Control = %BagColumn

# ---- Cabecera ----
@onready var title_label: Label = %TitleLabel
@onready var gold_label: Label = %GoldLabel
@onready var weight_label: Label = %WeightLabel
@onready var slots_label: Label = %SlotsLabel
@onready var close_button: UIButton = %CloseButton

# ---- Equipo ----
@onready var equipment_header: Label = %EquipHeader
@onready var equip_list: VBoxContainer = %EquipList

# ---- Mochila ----
@onready var category_tabs: HFlowContainer = %CategoryTabs
@onready var bag_scroll: ScrollContainer = %BagScroll
@onready var bag_grid: GridContainer = %BagGrid
@onready var empty_category_label: Label = %EmptyCategoryLabel

# ---- Detalle, estadísticas, feedback ----
@onready var detail_panel: ItemDetailPanel = %DetailPanel
@onready var stats_grid: HBoxContainer = %StatsGrid
@onready var bonus_header: Label = %BonusHeader
@onready var bonus_flow: HFlowContainer = %BonusFlow
@onready var bonus_empty_label: Label = %BonusEmptyLabel
@onready var feedback_popup = %FeedbackPopup

var _vm: InventoryViewModel = null

## Pool de slots de la mochila (se reutilizan; los sobrantes se ocultan)
var _bag_pool: Array[UISlot] = []

## id de pestaña → botón
var _tab_buttons: Dictionary = {}
var _tabs_signature: String = ""

## slot_id → UISlot de equipo (orden = orden de la definición del personaje)
var _equip_slots: Dictionary = {}
var _equip_signature: String = ""

## id de estadística → {caption: Label, value: Label}
var _stat_cells: Dictionary = {}
var _stats_signature: String = ""


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	_vm = InventoryViewModel.new()
	_vm.name = "ViewModel"
	add_child(_vm)
	_vm.changed.connect(_on_vm_changed)

	detail_panel.use_pressed.connect(_on_use_pressed)
	detail_panel.equip_pressed.connect(_on_equip_pressed)
	detail_panel.unequip_pressed.connect(_on_unequip_pressed)

	close_button.pressed.connect(close_inventory)
	bag_scroll.resized.connect(_update_grid_columns)

	# Fondo opaco que oculta (y bloquea) lo de debajo
	backdrop.color = UITokens.COLOR_BG.darkened(0.4)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	get_viewport().size_changed.connect(_update_frame_rect)
	_update_frame_rect()

	_setup_static_text()

	# Nace oculta: quien la instancia llama a open_inventory()
	visible = false

	print("[InventoryUI] Ready")


func _setup_static_text() -> void:
	title_label.text = tr("INVENTORY_TITLE")
	title_label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_TITLE)
	title_label.add_theme_color_override("font_color", UITokens.COLOR_ACCENT)

	equipment_header.text = tr("INVENTORY_EQUIPMENT_HEADER")
	equipment_header.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_SM)
	equipment_header.add_theme_color_override("font_color", UITokens.COLOR_TEXT_MUTED)

	for label in [gold_label, weight_label, slots_label]:
		label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_MD)
		label.add_theme_color_override("font_color", UITokens.COLOR_TEXT)

	bonus_header.text = tr("INVENTORY_BONUS_HEADER")
	bonus_header.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_SM)
	bonus_header.add_theme_color_override("font_color", UITokens.COLOR_TEXT_MUTED)
	bonus_empty_label.text = tr("INVENTORY_BONUS_EMPTY")
	bonus_empty_label.add_theme_color_override("font_color", UITokens.COLOR_TEXT_MUTED)

	empty_category_label.text = tr("INVENTORY_CATEGORY_EMPTY")
	empty_category_label.add_theme_color_override("font_color", UITokens.COLOR_TEXT_MUTED)


# ============================================
# API PÚBLICA
# ============================================

func open_inventory() -> void:
	visible = true
	_vm.open(entity_id)
	bag_scroll.scroll_vertical = 0
	_update_frame_rect()
	call_deferred("_update_grid_columns")
	print("[InventoryUI] Opened")


## Cierra a través del ViewModel; la señal closed sale en el caso "closed"
func close_inventory() -> void:
	_vm.request_close()


func toggle() -> void:
	if visible:
		close_inventory()
	else:
		open_inventory()


# ============================================
# CALLBACK ÚNICO DEL VIEWMODEL
# ============================================

func _on_vm_changed(reason: String) -> void:
	match reason:
		"opened":
			_render_header()
			_render_tabs()
			_render_bag()
			_render_equipment()
			_render_bonuses()
			_render_stats()
			_render_detail()
		"inventory":
			_render_header()
			_render_tabs()
			_render_bag()
		"categories":
			_render_tabs()
			_render_bag()
		"equipment":
			_render_equipment()
			_render_bonuses()
			_render_bag()
		"stats":
			_render_header()
			_render_stats()
		"selection":
			_render_bag()
			_render_detail()
		"feedback":
			_render_feedback()
		"closed":
			detail_panel.clear()
			feedback_popup.hide_message()
			visible = false
			closed.emit()
			print("[InventoryUI] Closed")
		_:
			push_warning("[InventoryUI] Razón desconocida: %s" % reason)


# ============================================
# RENDERS
# ============================================

func _render_header() -> void:
	gold_label.text = "%s %d" % [tr("INVENTORY_STAT_GOLD"), int(_vm.stat_gold)]
	weight_label.text = tr("INVENTORY_WEIGHT_COUNTER") % _vm.total_weight
	slots_label.text = tr("INVENTORY_SLOTS_COUNTER") % [_vm.used_slots, _vm.capacity]
	var over: bool = _vm.is_over_capacity()
	slots_label.add_theme_color_override("font_color", UITokens.COLOR_DANGER_SOFT if over else UITokens.COLOR_TEXT)


func _render_tabs() -> void:
	var ids: PackedStringArray = []
	for category in _vm.categories:
		ids.append("%s:%s" % [category.id, category.name])
	var signature: String = "|".join(ids)

	if signature != _tabs_signature:
		_tabs_signature = signature
		_tab_buttons.clear()
		for child in category_tabs.get_children():
			category_tabs.remove_child(child)
			child.queue_free()
		for category in _vm.categories:
			var button: UIButton = BUTTON_SCENE.instantiate()
			button.btn_size = UIButton.Size.SM
			button.variant = UIButton.Variant.SECONDARY
			button.text = category.name
			category_tabs.add_child(button)
			button.pressed.connect(_on_tab_pressed.bind(category.id))
			_tab_buttons[category.id] = button

	for category_id in _tab_buttons:
		var tab: UIButton = _tab_buttons[category_id]
		tab.set_variant(UIButton.Variant.PRIMARY if category_id == _vm.active_category else UIButton.Variant.SECONDARY)


func _render_bag() -> void:
	var entries: Array[InventoryViewModel.BagEntry] = _vm.bag_entries
	var show_all: bool = _vm.active_category == InventoryViewModel.CATEGORY_ALL

	# «Todo»: tantos huecos como capacidad (los vacíos se ven); si hay más pilas, solo las pilas.
	# Otras pestañas: solo lo que coincide, sin huecos vacíos.
	var count: int = entries.size()
	if show_all:
		count = maxi(_vm.capacity, entries.size())

	var no_items_here: bool = not show_all and entries.is_empty()
	empty_category_label.visible = no_items_here
	bag_scroll.visible = not no_items_here

	while _bag_pool.size() < count:
		_bag_pool.append(_create_bag_slot())

	for i in range(_bag_pool.size()):
		var slot: UISlot = _bag_pool[i]
		if i >= count:
			slot.visible = false
			slot.clear()
			continue
		slot.visible = true
		slot.border_color_override = Color.TRANSPARENT
		slot.tooltip_text = ""
		if i < entries.size():
			_fill_bag_slot(slot, entries[i])
		else:
			slot.clear()


func _create_bag_slot() -> UISlot:
	var slot: UISlot = SLOT_SCENE.instantiate()
	slot.accept_drops = false
	slot.equipped_mark_text = tr("INVENTORY_EQUIPPED_BADGE")
	bag_grid.add_child(slot)
	slot.slot_clicked.connect(_on_bag_slot_clicked)
	return slot


func _fill_bag_slot(slot: UISlot, entry: InventoryViewModel.BagEntry) -> void:
	var item_def: ItemDefinition = entry.instance.definition
	slot.set_item(entry.instance)
	slot.border_color_override = CATEGORY_COLORS.get(entry.category_id, Color.TRANSPARENT)
	slot.set_equipped_mark(entry.is_equipped)
	slot.set_overflow(entry.is_overflow)
	slot.set_selected(not _vm.selected_item_id.is_empty() and item_def.id == _vm.selected_item_id)

	var tooltip: String = tr(item_def.name_key)
	if entry.is_equipped:
		tooltip += "\n" + tr("INVENTORY_EQUIPPED_TOOLTIP")
	slot.tooltip_text = tooltip


func _render_equipment() -> void:
	var signature: String = ",".join(_vm.equipment_slot_ids)
	if signature != _equip_signature:
		_equip_signature = signature
		_equip_slots.clear()
		for child in equip_list.get_children():
			equip_list.remove_child(child)
			child.queue_free()
		for slot_id in _vm.equipment_slot_ids:
			var slot: UISlot = SLOT_SCENE.instantiate()
			slot.equipment_slot_id = slot_id
			slot.draggable = false
			slot.drop_source_filter = "inventory"
			slot.slot_label_text = _vm.slot_display_name(slot_id)
			slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			equip_list.add_child(slot)
			slot.slot_clicked.connect(_on_equip_slot_clicked)
			slot.slot_drop_received.connect(_on_equip_slot_drop)
			_equip_slots[slot_id] = slot

	for slot_id in _equip_slots:
		var equip_slot: UISlot = _equip_slots[slot_id]
		var item_def: ItemDefinition = _vm.equipped_items.get(slot_id, null) as ItemDefinition
		if item_def:
			equip_slot.set_definition(item_def)
			equip_slot.tooltip_text = tr(item_def.name_key)
		else:
			equip_slot.clear()
			equip_slot.tooltip_text = ""


func _render_bonuses() -> void:
	for child in bonus_flow.get_children():
		bonus_flow.remove_child(child)
		child.queue_free()

	bonus_empty_label.visible = _vm.equipment_bonuses.is_empty()
	bonus_flow.visible = not _vm.equipment_bonuses.is_empty()

	for bonus in _vm.equipment_bonuses:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UITokens.SPACE_XS)

		var caption := Label.new()
		caption.text = bonus.label
		caption.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_SM)
		caption.add_theme_color_override("font_color", UITokens.COLOR_TEXT_MUTED)

		var value := Label.new()
		value.text = bonus.text
		value.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_MD)
		var positive: bool = bonus.value > 0.0
		value.add_theme_color_override("font_color", UITokens.COLOR_SUCCESS if positive else UITokens.COLOR_DANGER)

		row.add_child(caption)
		row.add_child(value)
		bonus_flow.add_child(row)


func _render_stats() -> void:
	var ids: PackedStringArray = []
	for stat in _vm.stat_entries:
		ids.append("%s:%s" % [stat.id, stat.label])
	var signature: String = "|".join(ids)

	if signature != _stats_signature:
		_stats_signature = signature
		_stat_cells.clear()
		for child in stats_grid.get_children():
			stats_grid.remove_child(child)
			child.queue_free()
		for stat in _vm.stat_entries:
			var cell := VBoxContainer.new()
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.alignment = BoxContainer.ALIGNMENT_CENTER

			var caption := Label.new()
			caption.text = stat.label
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			caption.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_SM)
			caption.add_theme_color_override("font_color", UITokens.COLOR_TEXT_MUTED)

			var value := Label.new()
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			value.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_LG)
			value.add_theme_color_override("font_color", UITokens.COLOR_TEXT)

			cell.add_child(caption)
			cell.add_child(value)
			stats_grid.add_child(cell)
			_stat_cells[stat.id] = value

	for stat in _vm.stat_entries:
		var value_label: Label = _stat_cells.get(stat.id)
		if value_label:
			value_label.text = str(stat.value)


func _render_detail() -> void:
	if _vm.detail == null:
		detail_panel.clear()
	else:
		detail_panel.show_detail(_vm.detail)


func _render_feedback() -> void:
	if _vm.feedback_message.is_empty():
		return
	_update_popup_anchor()
	if _vm.feedback_is_error:
		feedback_popup.show_error(_vm.feedback_message)
	else:
		feedback_popup.show_success(_vm.feedback_message)


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


## El aviso va centrado sobre la columna de la mochila, pegado a su borde
## inferior (el hueco libre), para no tapar el bloque de estadísticas
func _update_popup_anchor() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var rect: Rect2 = bag_column.get_global_rect()
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


## Columnas de la mochila según el ancho disponible (el ancho cambia con la
## ventana, el tamaño de slot no)
func _update_grid_columns() -> void:
	var available: float = bag_scroll.size.x - SCROLLBAR_RESERVE
	var slot_width: float = UITokens.SLOT_SIZE.x + BAG_GAP
	bag_grid.columns = maxi(1, int((available + BAG_GAP) / slot_width))


# ============================================
# INPUT DE LA VIEW → VIEWMODEL
# ============================================

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_inventory()


func _on_tab_pressed(category_id: String) -> void:
	_vm.select_category(category_id)


func _on_bag_slot_clicked(slot: UISlot) -> void:
	if slot.is_empty():
		return
	_vm.select_item(slot.get_item_id())


func _on_equip_slot_clicked(slot: UISlot) -> void:
	if slot.is_empty():
		return
	_vm.request_unequip_slot(slot.equipment_slot_id)


func _on_equip_slot_drop(slot: UISlot, item_id: String) -> void:
	_vm.request_equip_drop(slot.equipment_slot_id, item_id)


func _on_use_pressed(item_id: String) -> void:
	_vm.request_use(item_id)


func _on_equip_pressed(item_id: String) -> void:
	_vm.request_equip(item_id)


func _on_unequip_pressed(item_id: String) -> void:
	_vm.request_unequip_item(item_id)
