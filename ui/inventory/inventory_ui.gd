extends CanvasLayer

## InventoryUI - Interfaz principal del inventario (producción)
##
## Layout: [EquipmentPanel | SlotsGrid + StatsPanel | DetailPanel]
##
## Responsabilidades:
## - Mostrar inventario (mochila) del jugador
## - Mostrar slots de equipamiento con sus ítems
## - Mostrar stats del personaje
## - Gestionar selección y mostrar detalle en DetailPanel
## - Emitir requests de usar/equipar/desequipar — NO ejecutar lógica
##
## Drag & drop:
## - ItemSlot provee drag data {item_id, source:"inventory"}
## - EquipSlot acepta drop y emite drop_accepted(slot_id, item_id)
## - InventoryUI escucha drop_accepted y solicita equipar

@export var entity_id: String = "player"

# ---- Inventario (mochila) ----
@onready var slots_grid: GridContainer        = %SlotsGrid

# ---- Equipamiento ----
@onready var equip_head: EquipSlot            = %EquipSlot_head
@onready var equip_body: EquipSlot            = %EquipSlot_body
@onready var equip_hands: EquipSlot           = %EquipSlot_hands
@onready var equip_feet: EquipSlot            = %EquipSlot_feet
@onready var equip_weapon: EquipSlot          = %EquipSlot_weapon
@onready var equip_shield: EquipSlot          = %EquipSlot_shield

# ---- Stats ----
@onready var stats_hp: Label                  = %StatsHP
@onready var stats_stamina: Label             = %StatsStamina
@onready var stats_str: Label                 = %StatsSTR
@onready var stats_dex: Label                 = %StatsDEX
@onready var stats_con: Label                 = %StatsCON
@onready var stats_gold: Label                = %StatsGold

# ---- Detalle + Feedback ----
@onready var detail_panel                     = %DetailPanel
@onready var feedback_popup                   = %FeedbackPopup
@onready var close_button: Button             = %CloseButton

# ---- Estado interno ----
var _selected_slot: PanelContainer = null
var _selected_item_id: String = ""
var _is_refreshing: bool = false

## Mapa slot_id → nodo EquipSlot (para refresh genérico)
var _equip_slots: Dictionary = {}


func _ready() -> void:
	# Construir mapa de slots
	_equip_slots = {
		"head":   equip_head,
		"body":   equip_body,
		"hands":  equip_hands,
		"feet":   equip_feet,
		"weapon": equip_weapon,
		"shield": equip_shield,
	}
	
	# Conectar eventos del sistema
	EventBus.item_added.connect(_on_item_changed)
	EventBus.item_removed.connect(_on_item_changed)
	EventBus.item_use_success.connect(_on_item_use_success)
	EventBus.item_use_failed.connect(_on_item_use_failed)
	
	# Conectar equipamiento — EquipmentManager tiene sus propias señales
	Equipment.item_equipped.connect(_on_equipment_changed)
	Equipment.item_unequipped.connect(_on_equipment_changed)
	
	# Conectar slots de mochila
	for slot in slots_grid.get_children():
		if slot is PanelContainer:
			slot.slot_clicked.connect(_on_inventory_slot_clicked)
	
	# Conectar slots de equipo
	for slot_id in _equip_slots:
		var equip_slot: EquipSlot = _equip_slots[slot_id]
		equip_slot.unequip_requested.connect(_on_unequip_requested)
		equip_slot.drop_accepted.connect(_on_equip_drop_accepted)
	
	# Conectar DetailPanel
	detail_panel.use_pressed.connect(_on_use_button_pressed)
	detail_panel.equip_pressed.connect(_on_equip_button_pressed)
	detail_panel.unequip_pressed.connect(_on_unequip_button_pressed)
	
	# Conectar cierre
	close_button.pressed.connect(close_inventory)
	
	# Ocultar al inicio — SceneOrchestrator llamará a open_inventory()
	visible = false
	
	print("[InventoryUI] Ready")


# ============================================
# APERTURA / CIERRE
# ============================================

func open_inventory() -> void:
	visible = true
	_refresh_all()
	print("[InventoryUI] Opened")


func close_inventory() -> void:
	visible = false
	_deselect_slot()
	print("[InventoryUI] Closed")


func toggle() -> void:
	if visible:
		close_inventory()
	else:
		open_inventory()


# ============================================
# REFRESH
# ============================================

func _refresh_all() -> void:
	if not visible or _is_refreshing:
		return
	_is_refreshing = true
	
	_refresh_inventory()
	_refresh_equipment()
	_refresh_stats()
	
	await get_tree().process_frame
	_is_refreshing = false


func _refresh_inventory() -> void:
	# Limpiar todos los slots
	for slot in slots_grid.get_children():
		if slot is PanelContainer:
			slot.clear()
	
	# Llenar con ítems del inventario
	var inventory: Dictionary = Inventory.get_inventory(entity_id)
	var idx := 0
	
	for item_id in inventory.keys():
		if idx >= slots_grid.get_child_count():
			break
		var instance: ItemInstance = inventory[item_id]
		var slot = slots_grid.get_child(idx)
		if slot is PanelContainer:
			slot.set_item(instance)
			idx += 1
	
	print("[InventoryUI] Inventory refreshed (%d items)" % inventory.size())


func _refresh_equipment() -> void:
	for slot_id in _equip_slots:
		var equip_slot: EquipSlot = _equip_slots[slot_id]
		var item_id: String = Equipment.get_equipped_item(entity_id, slot_id)
		
		if item_id.is_empty():
			equip_slot.clear()
		else:
			var item_def: ItemDefinition = Items.get_item(item_id)
			if item_def:
				equip_slot.set_equipped(item_def)
			else:
				equip_slot.clear()


func _refresh_stats() -> void:
	var chars: CharacterSystem = get_node_or_null("/root/Characters")
	var resources: ResourceSystem = get_node_or_null("/root/Resources")
	
	if not chars or not resources:
		return
	
	var hp: float      = resources.get_resource_amount(entity_id, "health")
	var stamina: float = resources.get_resource_amount(entity_id, "stamina")
	var gold: float    = resources.get_resource_amount(entity_id, "gold")
	var str_val: float = chars.get_base_attribute(entity_id, "strength")
	var dex_val: float = chars.get_base_attribute(entity_id, "dexterity")
	var con_val: float = chars.get_base_attribute(entity_id, "constitution")
	
	if stats_hp:      stats_hp.text      = "HP:  %d" % hp
	if stats_stamina: stats_stamina.text = "ST:  %d" % stamina
	if stats_gold:    stats_gold.text    = "G:   %d" % gold
	if stats_str:     stats_str.text     = "STR: %d" % str_val
	if stats_dex:     stats_dex.text     = "DEX: %d" % dex_val
	if stats_con:     stats_con.text     = "CON: %d" % con_val


# ============================================
# SELECCIÓN DE SLOTS DE MOCHILA
# ============================================

func _on_inventory_slot_clicked(item_id: String) -> void:
	_deselect_slot()
	_selected_item_id = item_id
	
	# Resaltar slot
	for slot in slots_grid.get_children():
		if slot is PanelContainer and slot.item_instance:
			if slot.item_instance.definition.id == item_id:
				_selected_slot = slot
				slot.set_selected(true)
				break
	
	# Mostrar detalle
	var item_def: ItemDefinition = Items.get_item(item_id)
	var quantity: int = Inventory.get_item_quantity(entity_id, item_id)
	var is_equipped: bool = Equipment.is_item_equipped(entity_id, item_id)
	
	if item_def:
		detail_panel.show_item(item_def, quantity, is_equipped)


func _deselect_slot() -> void:
	if _selected_slot:
		_selected_slot.set_selected(false)
		_selected_slot = null
	_selected_item_id = ""
	detail_panel.clear()


# ============================================
# ACCIONES DESDE DETAIL PANEL
# ============================================

func _on_use_button_pressed(item_id: String) -> void:
	Inventory.request_use_item(entity_id, item_id)


func _on_equip_button_pressed(item_id: String) -> void:
	# Bridge gestiona validación; EquipmentManager gestiona lógica
	Inventory.request_use_item(entity_id, item_id)


func _on_unequip_button_pressed(item_id: String) -> void:
	Equipment.unequip_item(entity_id, item_id)


# ============================================
# ACCIONES DESDE EQUIP SLOTS
# ============================================

## Click en slot de equipo ocupado → desequipar directamente
func _on_unequip_requested(slot_id: String) -> void:
	Equipment.unequip_slot(entity_id, slot_id)


## Drop de ItemSlot sobre EquipSlot → equipar
func _on_equip_drop_accepted(slot_id: String, item_id: String) -> void:
	# Validar que el ítem esté en el inventario antes de equipar
	if not Inventory.has_item(entity_id, item_id):
		feedback_popup.show_error("Item not in inventory")
		return
	
	# Validar que el ítem puede ir en ese slot específico
	if not Equipment.can_equip_in_slot(entity_id, item_id, slot_id):
		var item_def: ItemDefinition = Items.get_item(item_id)
		var item_name: String = tr(item_def.name_key) if item_def else item_id
		feedback_popup.show_error("%s no encaja en %s" % [item_name, slot_id])
		return
	
	Equipment.equip_item(entity_id, item_id)


# ============================================
# CALLBACKS DE EVENTOS DEL SISTEMA
# ============================================

func _on_item_changed(ent_id: String, _item_id: String, _qty: int) -> void:
	if ent_id == entity_id and visible:
		_refresh_inventory.call_deferred()


func _on_equipment_changed(ent_id: String, _item_id: String, _slot: String) -> void:
	if ent_id == entity_id and visible:
		_refresh_equipment.call_deferred()
		_refresh_stats.call_deferred()
		# Actualizar detalle si el ítem seleccionado cambió estado de equipo
		if not _selected_item_id.is_empty():
			_on_inventory_slot_clicked(_selected_item_id)


func _on_item_use_success(ent_id: String, item_id: String) -> void:
	if ent_id != entity_id:
		return
	var item_def: ItemDefinition = Items.get_item(item_id)
	if item_def:
		feedback_popup.show_success(tr(item_def.name_key) + " usado")
	if not Inventory.has_item(entity_id, item_id):
		_deselect_slot()


func _on_item_use_failed(ent_id: String, _item_id: String, reason: String) -> void:
	if ent_id != entity_id:
		return
	feedback_popup.show_error("Error: " + reason)
