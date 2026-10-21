extends CanvasLayer

## InventoryUI - View pasiva del inventario (Spike 17, contrato MVVM)
##
## Layout: [EquipmentPanel | SlotsGrid + StatsPanel | DetailPanel]
##
## Solo pinta el estado del InventoryViewModel y traduce el input del jugador
## en llamadas request_*(). No accede a ningún sistema core.
##
## Contrato público (sin cambios respecto a antes del Spike 17):
##   - open_inventory(), close_inventory(), toggle()
##   - signal closed
##   - @export entity_id
##
## `closed` se emite junto a visible = false. InventoryUI NUNCA se autolibera:
## quien la instancia (SceneOrchestrator, PlayerMenuScreen, NarrativeScenePanel)
## hace queue_free() al recibir la señal.
##
## Drag & drop (los slots son pasivos):
##   - ItemSlot da el payload {item_id, source:"inventory"}
##   - EquipSlot acepta el drop y emite drop_accepted(slot_id, item_id)
##
## Esc cierra el inventario. Se consume aquí (set_input_as_handled) para que,
## en el anidado, solo se cierre la capa más profunda. No se comprueba
## is_input_blocked(): esta entrada cierra, no abre, y debe funcionar también
## en NARRATIVE_SCENE.

signal closed

@export var entity_id: String = "player"

# ---- Rótulos fijos (se rellenan por código con tr()) ----
@onready var title_label: Label = %TitleLabel
@onready var equipment_header: Label = %EquipmentHeader
@onready var bag_header: Label = %BagHeader
@onready var stats_header: Label = %StatsHeader

# ---- Mochila ----
@onready var slots_grid: GridContainer = %SlotsGrid

# ---- Equipamiento ----
@onready var equip_head: EquipSlot = %EquipSlot_head
@onready var equip_body: EquipSlot = %EquipSlot_body
@onready var equip_hands: EquipSlot = %EquipSlot_hands
@onready var equip_feet: EquipSlot = %EquipSlot_feet
@onready var equip_weapon: EquipSlot = %EquipSlot_weapon
@onready var equip_shield: EquipSlot = %EquipSlot_shield

# ---- Stats: rótulo + valor ----
@onready var caption_hp: Label = %StatsHPCaption
@onready var caption_stamina: Label = %StatsStaminaCaption
@onready var caption_gold: Label = %StatsGoldCaption
@onready var caption_str: Label = %StatsSTRCaption
@onready var caption_dex: Label = %StatsDEXCaption
@onready var caption_con: Label = %StatsCONCaption
@onready var stats_hp: Label = %StatsHP
@onready var stats_stamina: Label = %StatsStamina
@onready var stats_gold: Label = %StatsGold
@onready var stats_str: Label = %StatsSTR
@onready var stats_dex: Label = %StatsDEX
@onready var stats_con: Label = %StatsCON

# ---- Detalle + feedback + cierre ----
@onready var detail_panel = %DetailPanel
@onready var feedback_popup = %FeedbackPopup
@onready var close_button: Button = %CloseButton

var _vm: InventoryViewModel = null

## Nodos ItemSlot del grid, en orden (su número lo decide el .tscn)
var _bag_slots: Array = []

## slot_id → nodo EquipSlot
var _equip_slots: Dictionary = {}


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	_vm = InventoryViewModel.new()
	_vm.name = "ViewModel"
	add_child(_vm)
	_vm.changed.connect(_on_vm_changed)

	_equip_slots = {
		"head": equip_head,
		"body": equip_body,
		"hands": equip_hands,
		"feet": equip_feet,
		"weapon": equip_weapon,
		"shield": equip_shield,
	}

	for child in slots_grid.get_children():
		if child is PanelContainer:
			_bag_slots.append(child)
			child.slot_clicked.connect(_on_bag_slot_clicked)

	for slot_id in _equip_slots:
		var equip_slot: EquipSlot = _equip_slots[slot_id]
		equip_slot.unequip_requested.connect(_on_unequip_requested)
		equip_slot.drop_accepted.connect(_on_equip_drop_accepted)

	detail_panel.use_pressed.connect(_on_use_pressed)
	detail_panel.equip_pressed.connect(_on_equip_pressed)
	detail_panel.unequip_pressed.connect(_on_unequip_pressed)

	close_button.pressed.connect(close_inventory)

	_setup_static_text()

	# Nace oculta: quien la instancia llama a open_inventory()
	visible = false

	print("[InventoryUI] Ready")


func _setup_static_text() -> void:
	title_label.text = tr("INVENTORY_TITLE")
	equipment_header.text = tr("INVENTORY_EQUIPMENT_HEADER")
	bag_header.text = tr("INVENTORY_BAG_HEADER")
	stats_header.text = tr("INVENTORY_STATS_HEADER")
	caption_hp.text = tr("INVENTORY_STAT_HP")
	caption_stamina.text = tr("INVENTORY_STAT_STAMINA")
	caption_gold.text = tr("INVENTORY_STAT_GOLD")
	caption_str.text = tr("INVENTORY_STAT_STR")
	caption_dex.text = tr("INVENTORY_STAT_DEX")
	caption_con.text = tr("INVENTORY_STAT_CON")


# ============================================
# API PÚBLICA
# ============================================

func open_inventory() -> void:
	visible = true
	_vm.open(entity_id)
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
			_render_bag()
			_render_equipment()
			_render_stats()
			_render_detail()
		"inventory":
			_render_bag()
		"equipment":
			_render_equipment()
		"stats":
			_render_stats()
		"selection":
			_render_bag()
			_render_detail()
		"feedback":
			_render_feedback()
		"closed":
			for slot in _bag_slots:
				slot.set_selected(false)
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

func _render_bag() -> void:
	if _vm.bag_items.size() > _bag_slots.size():
		push_warning("[InventoryUI] %d ítems y solo %d huecos: los sobrantes no se muestran" % [_vm.bag_items.size(), _bag_slots.size()])

	for i in range(_bag_slots.size()):
		var slot = _bag_slots[i]
		var instance: ItemInstance = null
		if i < _vm.bag_items.size():
			instance = _vm.bag_items[i]

		if instance:
			slot.set_item(instance)
		else:
			slot.clear()

		var is_selected: bool = instance != null \
				and not _vm.selected_item_id.is_empty() \
				and instance.definition.id == _vm.selected_item_id
		slot.set_selected(is_selected)


func _render_equipment() -> void:
	for slot_id in _equip_slots:
		var equip_slot: EquipSlot = _equip_slots[slot_id]
		var item_def: ItemDefinition = _vm.equipped_items.get(slot_id, null) as ItemDefinition
		if item_def:
			equip_slot.set_equipped(item_def)
		else:
			equip_slot.clear()


func _render_stats() -> void:
	stats_hp.text = str(int(_vm.stat_health))
	stats_stamina.text = str(int(_vm.stat_stamina))
	stats_gold.text = str(int(_vm.stat_gold))
	stats_str.text = str(int(_vm.stat_strength))
	stats_dex.text = str(int(_vm.stat_dexterity))
	stats_con.text = str(int(_vm.stat_constitution))


func _render_detail() -> void:
	var data: InventoryViewModel.DetailData = _vm.detail
	if data == null:
		detail_panel.clear()
	else:
		detail_panel.show_item(data.item_def, data.quantity, data.is_equipped)


func _render_feedback() -> void:
	if _vm.feedback_message.is_empty():
		return
	if _vm.feedback_is_error:
		feedback_popup.show_error(_vm.feedback_message)
	else:
		feedback_popup.show_success(_vm.feedback_message)


# ============================================
# INPUT DE LA VIEW → VIEWMODEL
# ============================================

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_inventory()


func _on_bag_slot_clicked(item_id: String) -> void:
	_vm.select_item(item_id)


func _on_use_pressed(item_id: String) -> void:
	_vm.request_use(item_id)


func _on_equip_pressed(item_id: String) -> void:
	_vm.request_equip(item_id)


func _on_unequip_pressed(item_id: String) -> void:
	_vm.request_unequip_item(item_id)


func _on_unequip_requested(slot_id: String) -> void:
	_vm.request_unequip_slot(slot_id)


func _on_equip_drop_accepted(slot_id: String, item_id: String) -> void:
	_vm.request_equip_drop(slot_id, item_id)
