class_name PartyViewModel
extends Node

## PartyViewModel
## Gestiona el estado completo de la pantalla de gestión de party.
##
## Responsabilidades:
##   - Mantener estado explícito (enum PartyState)
##   - Construir snapshots de ambas columnas (jugador + companion activo)
##   - Gestionar navegación entre companions
##   - Gestionar transferencia de ítems entre entidades
##   - Validar drops antes de ejecutar equipamiento
##   - Escuchar cambios de sistema y notificar a la View
##
## NO hace:
##   - Renderizar nada
##   - Instanciar nodos
##   - Acceder a @onready


# ============================================
# ENUMS
# ============================================

enum PartyState {
	HIDDEN,     ## Pantalla cerrada
	SHOWING,    ## Pantalla abierta y activa
}


# ============================================
# DATA CLASSES
# ============================================

class ColumnData:
	var entity_id: String = ""
	var display_name: String = ""
	## Array[EquipSlotData] — siempre 6 elementos, uno por slot
	var equip_slots: Array = []
	## Array[SlotData] — siempre MAX_BAG_SLOTS elementos
	var bag_slots: Array = []
	## Solo relevante para companions
	var active_strategy: int = -1
	var has_entity: bool = false


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


class SlotData:
	var item_id: String = ""
	var item_def: ItemDefinition = null
	var quantity: int = 0
	var is_empty: bool = true

	static func from_instance(instance: ItemInstance) -> SlotData:
		var d := SlotData.new()
		d.item_id  = instance.definition.id
		d.item_def = instance.definition
		d.quantity = instance.quantity
		d.is_empty = false
		return d

	static func empty() -> SlotData:
		return SlotData.new()


# ============================================
# CONSTANTES
# ============================================

const PLAYER_ID:      String         = "player"
const EQUIPMENT_SLOTS: Array[String] = ["head", "body", "hands", "feet", "weapon", "shield"]
const MAX_BAG_SLOTS:  int            = 8


# ============================================
# SEÑAL HACIA LA VIEW
# ============================================

## Razones:
##   "opened"            → renderizar todo
##   "player_column"     → refrescar solo columna jugador
##   "companion_column"  → refrescar solo columna companion
##   "companion_changed" → companion activo cambió (nombre + columna completa)
##   "closed"            → ocultar pantalla
signal changed(reason: String)


# ============================================
# ESTADO PÚBLICO
# ============================================

var state: PartyState = PartyState.HIDDEN

var player_column:    ColumnData = ColumnData.new()
var companion_column: ColumnData = ColumnData.new()

## Lista de companion_ids en el grupo
var companion_ids: Array[String] = []

## Índice del companion visible (para los botones prev/next)
var companion_index: int = 0

## Cuántos companions hay (para mostrar/ocultar nav buttons)
var companion_count: int = 0

## Lista de nombres de estrategia disponibles (para el OptionButton)
var strategy_names: Array[String] = []


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	Equipment.item_equipped.connect(_on_equipment_changed)
	Equipment.item_unequipped.connect(_on_equipment_changed)
	EventBus.item_added.connect(_on_inventory_changed)
	EventBus.item_removed.connect(_on_inventory_changed)

	# Cachear nombres de estrategia una sola vez
	for key in Party.CompanionStrategy.keys():
		strategy_names.append(key)

	print("[PartyVM] Ready")


# ============================================
# INTENCIONES
# ============================================

func open() -> void:
	_refresh_companion_list()
	companion_index = clampi(companion_index, 0, maxi(companion_ids.size() - 1, 0))
	_refresh_all()
	state = PartyState.SHOWING
	changed.emit("opened")


func request_close() -> void:
	state = PartyState.HIDDEN
	changed.emit("closed")


func navigate_prev_companion() -> void:
	if companion_ids.is_empty():
		return
	companion_index = (companion_index - 1 + companion_ids.size()) % companion_ids.size()
	_refresh_companion_column()
	changed.emit("companion_changed")


func navigate_next_companion() -> void:
	if companion_ids.is_empty():
		return
	companion_index = (companion_index + 1) % companion_ids.size()
	_refresh_companion_column()
	changed.emit("companion_changed")


func request_set_strategy(index: int) -> void:
	var companion_id := _current_companion_id()
	if companion_id.is_empty():
		return
	var new_strategy: Party.CompanionStrategy = index as Party.CompanionStrategy
	Party.set_strategy(companion_id, new_strategy)
	# No emite changed — el OptionButton ya refleja el estado visualmente


## Click en slot de mochila: equipar/usar directamente
func request_slot_action(item_id: String, entity_id: String) -> void:
	var item_def: ItemDefinition = Items.get_item(item_id)
	if not item_def:
		return

	if item_def.item_type == "EQUIPMENT":
		Equipment.toggle_equipment(entity_id, item_id)
	elif item_def.item_type == "CONSUMABLE" and item_def.usable:
		EventBus.item_use_requested.emit(entity_id, item_id)


## Drop sobre slot de equipo: transferir si hace falta, luego equipar
## Devuelve "" si OK, o un mensaje de error localizable si falló
func request_equip_drop(slot_id: String, item_id: String, target_entity: String) -> String:
	# ¿El ítem está en el inventario de la entidad destino?
	if not Inventory.has_item(target_entity, item_id):
		var source := _find_item_owner(item_id)
		if source.is_empty():
			return "PARTY_ERROR_ITEM_NOT_FOUND"
		var ok := _transfer_item(source, target_entity, item_id)
		if not ok:
			return "PARTY_ERROR_TRANSFER_FAILED"

	if not Equipment.can_equip_in_slot(target_entity, item_id, slot_id):
		return "PARTY_ERROR_WRONG_SLOT"

	Equipment.equip_item(target_entity, item_id)
	return ""


## Desequipar slot de una entidad
func request_unequip(slot_id: String, entity_id: String) -> void:
	Equipment.unequip_slot(entity_id, slot_id)


# ============================================
# CALLBACKS DE SISTEMAS
# ============================================

func _on_equipment_changed(entity_id: String, _item_id: String, _slot: String) -> void:
	if state == PartyState.HIDDEN:
		return
	_dispatch_column_refresh(entity_id)


func _on_inventory_changed(entity_id: String, _item_id: String, _qty: int) -> void:
	if state == PartyState.HIDDEN:
		return
	_dispatch_column_refresh(entity_id)


func _dispatch_column_refresh(entity_id: String) -> void:
	if entity_id == PLAYER_ID:
		_refresh_player_column()
		changed.emit("player_column")
	elif entity_id == _current_companion_id():
		_refresh_companion_column()
		changed.emit("companion_column")


# ============================================
# REFRESH INTERNOS
# ============================================

func _refresh_all() -> void:
	_refresh_player_column()
	_refresh_companion_column()


func _refresh_companion_list() -> void:
	companion_ids = Party.get_party_members()
	companion_count = companion_ids.size()


func _refresh_player_column() -> void:
	player_column       = ColumnData.new()
	player_column.entity_id    = PLAYER_ID
	player_column.display_name = "Jugador"
	player_column.has_entity   = true
	player_column.equip_slots  = _build_equip_slots(PLAYER_ID)
	player_column.bag_slots    = _build_bag_slots(PLAYER_ID)


func _refresh_companion_column() -> void:
	companion_column = ColumnData.new()
	var companion_id := _current_companion_id()

	if companion_id.is_empty():
		companion_column.has_entity   = false
		companion_column.display_name = ""
		return

	companion_column.entity_id  = companion_id
	companion_column.has_entity = true

	var char_def: CharacterDefinition = Characters.get_character_definition(companion_id)
	companion_column.display_name = tr(char_def.name_key) if char_def else companion_id

	companion_column.equip_slots    = _build_equip_slots(companion_id)
	companion_column.bag_slots      = _build_bag_slots(companion_id)
	companion_column.active_strategy = Party.get_strategy(companion_id) as int


# ============================================
# BUILDERS DE SNAPSHOTS
# ============================================

func _build_equip_slots(entity_id: String) -> Array:
	var result: Array = []
	for slot_id in EQUIPMENT_SLOTS:
		var item_id: String = Equipment.get_equipped_item(entity_id, slot_id)
		if item_id.is_empty():
			result.append(EquipSlotData.empty(slot_id))
		else:
			var item_def: ItemDefinition = Items.get_item(item_id)
			if item_def:
				result.append(EquipSlotData.from_equipped(slot_id, item_def))
			else:
				result.append(EquipSlotData.empty(slot_id))
	return result


func _build_bag_slots(entity_id: String) -> Array:
	var result: Array = []
	var inventory: Dictionary = Inventory.get_inventory(entity_id)
	for item_id in inventory.keys():
		if result.size() >= MAX_BAG_SLOTS:
			break
		result.append(SlotData.from_instance(inventory[item_id]))
	while result.size() < MAX_BAG_SLOTS:
		result.append(SlotData.empty())
	return result


# ============================================
# TRANSFERENCIA DE ÍTEMS
# ============================================

func _find_item_owner(item_id: String) -> String:
	if Inventory.has_item(PLAYER_ID, item_id):
		return PLAYER_ID
	for companion_id in companion_ids:
		if Inventory.has_item(companion_id, item_id):
			return companion_id
	return ""


func _transfer_item(from_entity: String, to_entity: String, item_id: String, quantity: int = 1) -> bool:
	if not Inventory.has_item(from_entity, item_id, quantity):
		push_warning("[PartyVM] '%s' no tiene '%s' x%d" % [from_entity, item_id, quantity])
		return false

	if not Inventory.remove_item(from_entity, item_id, quantity):
		push_warning("[PartyVM] No se pudo quitar '%s' de '%s'" % [item_id, from_entity])
		return false

	if not Inventory.add_item(to_entity, item_id, quantity):
		Inventory.add_item(from_entity, item_id, quantity)  # rollback
		push_warning("[PartyVM] No se pudo añadir '%s' a '%s' — rollback" % [item_id, to_entity])
		return false

	print("[PartyVM] Transferido: %s × %d  %s → %s" % [item_id, quantity, from_entity, to_entity])
	return true


# ============================================
# HELPERS
# ============================================

func _current_companion_id() -> String:
	if companion_ids.is_empty() or companion_index >= companion_ids.size():
		return ""
	return companion_ids[companion_index]
