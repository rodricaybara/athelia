class_name InventoryViewModel
extends Node

## InventoryViewModel
## Gestiona el estado completo de la pantalla de inventario.
##
## Responsabilidades:
##   - Mantener estado explícito (enum InventoryState)
##   - Construir snapshots de inventario y equipamiento listos para renderizar
##   - Gestionar selección de ítems y comparación con slot equipado
##   - Emitir intenciones al EventBus (usar, equipar, desequipar)
##   - Escuchar cambios de sistema y notificar a la View
##
## NO hace:
##   - Renderizar nada
##   - Instanciar nodos
##   - Modificar inventario/equipamiento directamente


# ============================================
# ENUMS
# ============================================

enum InventoryState {
	HIDDEN,          ## Pantalla cerrada
	BROWSING,        ## Inventario visible, ningún ítem seleccionado
	ITEM_SELECTED,   ## Ítem seleccionado, detalle visible
	ACTION_PENDING,  ## Acción emitida, esperando respuesta del sistema
}


# ============================================
# DATA CLASSES (structs ligeros para la View)
# ============================================

## Datos de un slot del grid de mochila
class SlotData:
	var item_id: String = ""
	var item_def: ItemDefinition = null
	var quantity: int = 0
	var is_equipped: bool = false
	var is_empty: bool = true

	static func from_instance(instance: ItemInstance, equipped: bool) -> SlotData:
		var d := SlotData.new()
		d.item_id  = instance.definition.id
		d.item_def = instance.definition
		d.quantity = instance.quantity
		d.is_equipped = equipped
		d.is_empty = false
		return d

	static func empty() -> SlotData:
		return SlotData.new()


## Datos de un slot de equipamiento
class EquipSlotData:
	var slot_id: String = ""
	var item_id: String = ""
	var item_def: ItemDefinition = null
	var is_empty: bool = true

	static func from_equipped(slot: String, item: ItemDefinition) -> EquipSlotData:
		var d := EquipSlotData.new()
		d.slot_id  = slot
		d.item_id  = item.id
		d.item_def = item
		d.is_empty = false
		return d

	static func empty(slot: String) -> EquipSlotData:
		var d := EquipSlotData.new()
		d.slot_id = slot
		return d


## Datos del panel de detalle
class DetailData:
	var item_def: ItemDefinition = null
	var quantity: int = 0
	var is_equipped: bool = false
	## Ítem actualmente en el slot que ocuparía este ítem (para comparación)
	var competing_item_def: ItemDefinition = null
	## Acciones disponibles para este ítem
	var can_use: bool = false
	var can_equip: bool = false
	var can_unequip: bool = false


# ============================================
# SEÑAL HACIA LA VIEW
# ============================================

## Razones:
##   "opened"          → construir layout completo
##   "inventory"       → solo refrescar grid de mochila
##   "equipment"       → solo refrescar slots de equipo
##   "selection"       → solo refrescar panel de detalle
##   "stats"           → solo refrescar stats del personaje
##   "action_pending"  → bloquear botones de acción
##   "action_resolved" → desbloquear + refrescar según acción
##   "closed"          → ocultar pantalla
signal changed(reason: String)


# ============================================
# ESTADO PÚBLICO (read-only para la View)
# ============================================

var state: InventoryState = InventoryState.HIDDEN
var entity_id: String = "player"

## Slots del grid — siempre MAX_SLOTS elementos, los vacíos son SlotData.empty()
const MAX_SLOTS: int = 20
const EQUIPMENT_SLOTS: Array[String] = ["head", "body", "hands", "feet", "weapon", "shield"]

var inventory_slots: Array = []     ## Array[SlotData], tamaño MAX_SLOTS
var equipment_slots: Array = []     ## Array[EquipSlotData], tamaño EQUIPMENT_SLOTS.size()
var detail: DetailData = null       ## null si no hay selección
var selected_item_id: String = ""

## Stats del personaje para mostrar en el panel izquierdo
var stat_hp: float = 0.0
var stat_hp_max: float = 0.0
var stat_stamina: float = 0.0
var stat_stamina_max: float = 0.0
var stat_gold: float = 0.0
var stat_strength: float = 0.0
var stat_dexterity: float = 0.0
var stat_constitution: float = 0.0

## Mensaje de feedback temporal (uso de ítem, error, etc.)
var feedback_message: String = ""
var feedback_is_error: bool = false


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	EventBus.item_added.connect(_on_inventory_changed)
	EventBus.item_removed.connect(_on_inventory_changed)
	EventBus.item_use_success.connect(_on_item_use_success)
	EventBus.item_use_failed.connect(_on_item_use_failed)
	Equipment.item_equipped.connect(_on_equipment_changed)
	Equipment.item_unequipped.connect(_on_equipment_changed)

	print("[InventoryVM] Ready")


# ============================================
# INTENCIONES (llamadas desde la View)
# ============================================

## Abrir el inventario para una entidad
func open(p_entity_id: String = "player") -> void:
	entity_id = p_entity_id
	selected_item_id = ""
	detail = null
	_refresh_all()
	state = InventoryState.BROWSING
	changed.emit("opened")


## Seleccionar un ítem del grid
func select_item(item_id: String) -> void:
	if state == InventoryState.ACTION_PENDING:
		return

	if item_id == selected_item_id:
		# Deseleccionar al pulsar el mismo
		selected_item_id = ""
		detail = null
		state = InventoryState.BROWSING
	else:
		selected_item_id = item_id
		_refresh_detail()
		state = InventoryState.ITEM_SELECTED

	changed.emit("selection")


## Usar el ítem seleccionado
func request_use() -> void:
	if selected_item_id.is_empty() or state == InventoryState.ACTION_PENDING:
		return
	state = InventoryState.ACTION_PENDING
	changed.emit("action_pending")
	EventBus.item_use_requested.emit(entity_id, selected_item_id)


## Equipar/desequipar el ítem seleccionado
func request_toggle_equip() -> void:
	if selected_item_id.is_empty() or state == InventoryState.ACTION_PENDING:
		return
	state = InventoryState.ACTION_PENDING
	changed.emit("action_pending")
	EventBus.item_use_requested.emit(entity_id, selected_item_id)


## Cerrar el inventario
func request_close() -> void:
	selected_item_id = ""
	detail = null
	state = InventoryState.HIDDEN
	changed.emit("closed")


# ============================================
# CALLBACKS DE SISTEMAS
# ============================================

func _on_inventory_changed(ent_id: String, _item_id: String, _qty: int) -> void:
	if ent_id != entity_id or state == InventoryState.HIDDEN:
		return
	_refresh_inventory_slots()
	_refresh_stats()
	# Si el ítem seleccionado ya no existe, limpiar selección
	if not selected_item_id.is_empty() and not Inventory.has_item(entity_id, selected_item_id):
		selected_item_id = ""
		detail = null
		state = InventoryState.BROWSING
		changed.emit("inventory")
	else:
		if not selected_item_id.is_empty():
			_refresh_detail()
		changed.emit("inventory")


func _on_equipment_changed(ent_id: String, _item_id: String, _slot: String) -> void:
	if ent_id != entity_id or state == InventoryState.HIDDEN:
		return
	_refresh_equipment_slots()
	_refresh_stats()
	if not selected_item_id.is_empty():
		_refresh_detail()
	changed.emit("equipment")


func _on_item_use_success(ent_id: String, item_id: String) -> void:
	if ent_id != entity_id:
		return

	var item_def: ItemDefinition = Items.get_item(item_id)
	if item_def:
		feedback_message  = tr(item_def.name_key) + " usado"
		feedback_is_error = false
	state = InventoryState.BROWSING if selected_item_id.is_empty() else InventoryState.ITEM_SELECTED
	changed.emit("action_resolved")


func _on_item_use_failed(ent_id: String, _item_id: String, reason: String) -> void:
	if ent_id != entity_id:
		return
	feedback_message  = reason
	feedback_is_error = true
	state = InventoryState.BROWSING if selected_item_id.is_empty() else InventoryState.ITEM_SELECTED
	changed.emit("action_resolved")


# ============================================
# REFRESH INTERNOS
# ============================================

func _refresh_all() -> void:
	_refresh_inventory_slots()
	_refresh_equipment_slots()
	_refresh_stats()
	if not selected_item_id.is_empty():
		_refresh_detail()


func _refresh_inventory_slots() -> void:
	inventory_slots.clear()
	var inv: Dictionary = Inventory.get_inventory(entity_id)

	for item_id in inv.keys():
		var instance: ItemInstance = inv[item_id]
		var is_eq: bool = Equipment.is_item_equipped(entity_id, item_id)
		inventory_slots.append(SlotData.from_instance(instance, is_eq))

	# Rellenar hasta MAX_SLOTS con slots vacíos
	while inventory_slots.size() < MAX_SLOTS:
		inventory_slots.append(SlotData.empty())


func _refresh_equipment_slots() -> void:
	equipment_slots.clear()
	for slot_id in EQUIPMENT_SLOTS:
		var item_id: String = Equipment.get_equipped_item(entity_id, slot_id)
		if item_id.is_empty():
			equipment_slots.append(EquipSlotData.empty(slot_id))
		else:
			var item_def: ItemDefinition = Items.get_item(item_id)
			if item_def:
				equipment_slots.append(EquipSlotData.from_equipped(slot_id, item_def))
			else:
				equipment_slots.append(EquipSlotData.empty(slot_id))


func _refresh_stats() -> void:
	stat_hp           = Resources.get_resource_amount(entity_id, "health")
	stat_stamina      = Resources.get_resource_amount(entity_id, "stamina")
	stat_gold         = Resources.get_resource_amount(entity_id, "gold")
	stat_strength     = Characters.get_base_attribute(entity_id, "strength")
	stat_dexterity    = Characters.get_base_attribute(entity_id, "dexterity")
	stat_constitution = Characters.get_base_attribute(entity_id, "constitution")

	var hp_state = Resources.get_resource_state(entity_id, "health")
	var st_state = Resources.get_resource_state(entity_id, "stamina")
	stat_hp_max      = hp_state.max_effective if hp_state else 100.0
	stat_stamina_max = st_state.max_effective if st_state else 100.0


func _refresh_detail() -> void:
	if selected_item_id.is_empty():
		detail = null
		return

	var item_def: ItemDefinition = Items.get_item(selected_item_id)
	if not item_def:
		detail = null
		return

	detail = DetailData.new()
	detail.item_def   = item_def
	detail.quantity   = Inventory.get_item_quantity(entity_id, selected_item_id)
	detail.is_equipped = Equipment.is_item_equipped(entity_id, selected_item_id)

	# Ítem en competencia (para comparación de equipamiento)
	if item_def.item_type == "EQUIPMENT":
		var slot: String = _find_slot_for_item(item_def)
		if not slot.is_empty():
			var current_id: String = Equipment.get_equipped_item(entity_id, slot)
			if not current_id.is_empty() and current_id != selected_item_id:
				detail.competing_item_def = Items.get_item(current_id)

	# Acciones disponibles
	detail.can_use     = item_def.usable and item_def.item_type == "CONSUMABLE"
	detail.can_equip   = item_def.item_type == "EQUIPMENT" and not detail.is_equipped
	detail.can_unequip = item_def.item_type == "EQUIPMENT" and detail.is_equipped


func _find_slot_for_item(item_def: ItemDefinition) -> String:
	for slot_id in EQUIPMENT_SLOTS:
		if item_def.has_tag(slot_id):
			return slot_id
	return ""
