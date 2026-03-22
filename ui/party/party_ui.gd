extends CanvasLayer
class_name PartyUI

## PartyUI - Pantalla de gestión de equipamiento y mochila de la party
##
## Muestra en paralelo al jugador y al companion activo seleccionado.
## Permite drag & drop entre cualquier slot/mochila de ambas columnas.
## Se abre con tecla P desde EXPLORATION — sin cambio de GameState.

# ============================================
# SEÑALES
# ============================================

signal closed

# ============================================
# NODOS — columna jugador
# ============================================

@onready var player_equip_head:   EquipSlot = %PlayerEquipHead
@onready var player_equip_body:   EquipSlot = %PlayerEquipBody
@onready var player_equip_hands:  EquipSlot = %PlayerEquipHands
@onready var player_equip_feet:   EquipSlot = %PlayerEquipFeet
@onready var player_equip_weapon: EquipSlot = %PlayerEquipWeapon
@onready var player_equip_shield: EquipSlot = %PlayerEquipShield
@onready var player_grid:         GridContainer = %PlayerGrid
@onready var strategy_option: OptionButton = %StrategyOption

# ============================================
# NODOS — columna companion
# ============================================

@onready var companion_name_label:   Label        = %CompanionNameLabel
@onready var companion_prev_button:  Button       = %CompanionPrevButton
@onready var companion_next_button:  Button       = %CompanionNextButton
@onready var companion_equip_head:   EquipSlot    = %CompanionEquipHead
@onready var companion_equip_body:   EquipSlot    = %CompanionEquipBody
@onready var companion_equip_hands:  EquipSlot    = %CompanionEquipHands
@onready var companion_equip_feet:   EquipSlot    = %CompanionEquipFeet
@onready var companion_equip_weapon: EquipSlot    = %CompanionEquipWeapon
@onready var companion_equip_shield: EquipSlot    = %CompanionEquipShield
@onready var companion_grid:         GridContainer = %CompanionGrid
@onready var no_companions_label:    Label        = %NoCompanionsLabel

# ============================================
# NODOS — comunes
# ============================================

@onready var close_button: Button = %CloseButton

# ============================================
# ESTADO INTERNO
# ============================================

const PLAYER_ID: String = "player"
const SLOTS: Array[String] = ["head", "body", "hands", "feet", "weapon", "shield"]

## Índice del companion actualmente visible
var _companion_index: int = 0

## Lista de companion_ids en el grupo
var _companion_ids: Array[String] = []

## Companion actualmente visible (vacío si no hay ninguno)
var _current_companion: String = ""

## Mapas slot_id → EquipSlot para acceso genérico
var _player_equip_slots:    Dictionary = {}
var _companion_equip_slots: Dictionary = {}


# ============================================
# INICIALIZACIÓN
# ============================================

func _ready() -> void:
	visible = false

	# Construir mapas de slots
	_player_equip_slots = {
		"head":   player_equip_head,
		"body":   player_equip_body,
		"hands":  player_equip_hands,
		"feet":   player_equip_feet,
		"weapon": player_equip_weapon,
		"shield": player_equip_shield,
	}
	_companion_equip_slots = {
		"head":   companion_equip_head,
		"body":   companion_equip_body,
		"hands":  companion_equip_hands,
		"feet":   companion_equip_feet,
		"weapon": companion_equip_weapon,
		"shield": companion_equip_shield,
	}

	# Conectar botones comunes
	close_button.pressed.connect(_on_close_pressed)
	companion_prev_button.pressed.connect(_on_prev_companion)
	companion_next_button.pressed.connect(_on_next_companion)

	# Poblar OptionButton con las estrategias disponibles
	strategy_option.clear()
	for strategy_name in Party.CompanionStrategy.keys():
		strategy_option.add_item(strategy_name)

	if strategy_option.item_selected.is_connected(_on_strategy_selected):
		strategy_option.item_selected.disconnect(_on_strategy_selected)
	strategy_option.item_selected.connect(_on_strategy_selected)

	# Conectar slots de equipo del companion
	for slot_id in _companion_equip_slots:
		var equip_slot: EquipSlot = _companion_equip_slots[slot_id]
		equip_slot.unequip_requested.connect(
			func(sid: String): _on_unequip_requested(sid, _current_companion)
		)
		equip_slot.drop_accepted.connect(
			func(sid: String, iid: String): _on_drop_accepted(sid, iid, _current_companion)
		)

	# Escuchar cambios de equipamiento para refrescar UI en tiempo real
	Equipment.item_equipped.connect(_on_equipment_changed)
	Equipment.item_unequipped.connect(_on_equipment_changed)
	EventBus.item_added.connect(_on_inventory_changed)
	EventBus.item_removed.connect(_on_inventory_changed)

	print("[PartyUI] Ready")


# ============================================
# APERTURA / CIERRE
# ============================================

func open() -> void:
	_refresh_companion_list()

	if _companion_ids.is_empty():
		_companion_index = 0
		_current_companion = ""
	else:
		_companion_index = clampi(_companion_index, 0, _companion_ids.size() - 1)
		_current_companion = _companion_ids[_companion_index]

	visible = true
	_refresh_all()
	print("[PartyUI] Opened")


func close() -> void:
	visible = false
	closed.emit()
	print("[PartyUI] Closed")


func toggle() -> void:
	if visible:
		close()
	else:
		open()


# ============================================
# NAVEGACIÓN ENTRE COMPANIONS
# ============================================

func _on_prev_companion() -> void:
	if _companion_ids.is_empty():
		return
	_companion_index = (_companion_index - 1 + _companion_ids.size()) % _companion_ids.size()
	_current_companion = _companion_ids[_companion_index]
	_refresh_companion_column()


func _on_next_companion() -> void:
	if _companion_ids.is_empty():
		return
	_companion_index = (_companion_index + 1) % _companion_ids.size()
	_current_companion = _companion_ids[_companion_index]
	_refresh_companion_column()


# ============================================
# REFRESH
# ============================================

func _refresh_companion_list() -> void:
	var party: Node = get_node_or_null("/root/Party")
	if party:
		_companion_ids = party.get_party_members()
	else:
		_companion_ids = []


func _refresh_all() -> void:
	_refresh_player_column()
	_refresh_companion_column()


func _refresh_player_column() -> void:
	# Slots de equipo
	for slot_id in _player_equip_slots:
		var equip_slot: EquipSlot = _player_equip_slots[slot_id]
		var item_id: String = Equipment.get_equipped_item(PLAYER_ID, slot_id)
		if item_id.is_empty():
			equip_slot.clear()
		else:
			var item_def: ItemDefinition = Items.get_item(item_id)
			if item_def:
				equip_slot.set_equipped(item_def)

	# Mochila
	_populate_grid(player_grid, PLAYER_ID)

func _refresh_companion_column() -> void:
	var has_companions: bool = not _companion_ids.is_empty()
	no_companions_label.visible = not has_companions
	companion_prev_button.visible = has_companions and _companion_ids.size() > 1
	companion_next_button.visible = has_companions and _companion_ids.size() > 1

	if not has_companions or _current_companion.is_empty():
		companion_name_label.text = "Sin companions"
		for slot_id in _companion_equip_slots:
			_companion_equip_slots[slot_id].clear()
		_clear_grid(companion_grid)
		if strategy_option:
			strategy_option.disabled = true
		return

	# Nombre del companion
	var char_def: CharacterDefinition = Characters.get_character_definition(_current_companion)
	if char_def:
		companion_name_label.text = tr(char_def.name_key)
	else:
		companion_name_label.text = _current_companion

	# Slots de equipo
	for slot_id in _companion_equip_slots:
		var equip_slot: EquipSlot = _companion_equip_slots[slot_id]
		var item_id: String = Equipment.get_equipped_item(_current_companion, slot_id)
		if item_id.is_empty():
			equip_slot.clear()
		else:
			var item_def: ItemDefinition = Items.get_item(item_id)
			if item_def:
				equip_slot.set_equipped(item_def)

	# Mochila
	_populate_grid(companion_grid, _current_companion)

	# Estrategia — actualizar selector con la estrategia activa del companion
	if strategy_option:
		strategy_option.select(Party.get_strategy(_current_companion) as int)
		strategy_option.disabled = false

## Llena un GridContainer con los ítems del inventario de entity_id.
## Reutiliza los ItemSlot existentes en el grid (no los recrea).
func _populate_grid(grid: GridContainer, entity_id: String) -> void:
	_clear_grid(grid)

	var inventory: Dictionary = Inventory.get_inventory(entity_id)
	var slots: Array = grid.get_children()
	var idx: int = 0

	for item_id in inventory.keys():
		if idx >= slots.size():
			break
		var instance: ItemInstance = inventory[item_id]
		var slot = slots[idx]
		if slot is PanelContainer and slot.has_method("set_item"):
			slot.set_item(instance)
			# Conectar click si no está ya conectado
			if not slot.slot_clicked.is_connected(_on_slot_clicked.bind(entity_id)):
				slot.slot_clicked.connect(_on_slot_clicked.bind(entity_id))
		idx += 1


func _clear_grid(grid: GridContainer) -> void:
	for slot in grid.get_children():
		if slot.has_method("clear"):
			slot.clear()


# ============================================
# ACCIONES — DRAG & DROP Y CLICKS
# ============================================

## Drop sobre un slot de equipo: intentar equipar en esa entidad
func _on_drop_accepted(slot_id: String, item_id: String, entity_id: String) -> void:
	# Verificar que el ítem está en el inventario de la entidad destino
	if not Inventory.has_item(entity_id, item_id):
		# El ítem está en otro inventario — transferir primero
		var source_entity: String = _find_item_owner(item_id)
		if source_entity.is_empty():
			push_warning("[PartyUI] Item '%s' not found in any inventory" % item_id)
			return
		_transfer_item(source_entity, entity_id, item_id)

	# Validar slot
	if not Equipment.can_equip_in_slot(entity_id, item_id, slot_id):
		print("[PartyUI] '%s' no puede ir en slot '%s' de '%s'" % [item_id, slot_id, entity_id])
		return

	Equipment.equip_item(entity_id, item_id)


## Click en slot de equipo ocupado: desequipar
func _on_unequip_requested(slot_id: String, entity_id: String) -> void:
	Equipment.unequip_slot(entity_id, slot_id)


## Click en slot de mochila: equipar directamente si es equipable
func _on_slot_clicked(item_id: String, entity_id: String) -> void:
	var item_def: ItemDefinition = Items.get_item(item_id)
	if not item_def:
		return

	if item_def.item_type == "EQUIPMENT":
		Equipment.toggle_equipment(entity_id, item_id)
	elif item_def.item_type == "CONSUMABLE" and item_def.usable:
		EventBus.item_use_requested.emit(entity_id, item_id)


# ============================================
# TRANSFERENCIA DE ÍTEMS ENTRE ENTIDADES
# ============================================

## Busca qué entidad de la party tiene un ítem concreto
func _find_item_owner(item_id: String) -> String:
	if Inventory.has_item(PLAYER_ID, item_id):
		return PLAYER_ID
	for companion_id in _companion_ids:
		if Inventory.has_item(companion_id, item_id):
			return companion_id
	return ""


## Transfiere quantity=1 de un ítem entre inventarios
func _transfer_item(from_entity: String, to_entity: String, item_id: String, quantity: int = 1) -> bool:
	if not Inventory.has_item(from_entity, item_id, quantity):
		push_warning("[PartyUI] '%s' no tiene '%s' x%d" % [from_entity, item_id, quantity])
		return false

	var removed: bool = Inventory.remove_item(from_entity, item_id, quantity)
	if not removed:
		push_warning("[PartyUI] No se pudo quitar '%s' de '%s'" % [item_id, from_entity])
		return false

	var added: bool = Inventory.add_item(to_entity, item_id, quantity)
	if not added:
		# Rollback
		Inventory.add_item(from_entity, item_id, quantity)
		push_warning("[PartyUI] No se pudo añadir '%s' a '%s' — rollback" % [item_id, to_entity])
		return false

	print("[PartyUI] Transferido: %s × %d  %s → %s" % [item_id, quantity, from_entity, to_entity])
	return true


# ============================================
# CALLBACKS DE EVENTOS
# ============================================

func _on_equipment_changed(entity_id: String, _item_id: String, _slot: String) -> void:
	if not visible:
		return
	if entity_id == PLAYER_ID:
		_refresh_player_column()
	elif entity_id == _current_companion:
		_refresh_companion_column()


func _on_inventory_changed(entity_id: String, _item_id: String, _qty: int) -> void:
	if not visible:
		return
	if entity_id == PLAYER_ID:
		_refresh_player_column()
	elif entity_id == _current_companion:
		_refresh_companion_column()


func _on_close_pressed() -> void:
	close()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("open_party") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _on_strategy_selected(index: int) -> void:
	if _current_companion.is_empty():
		return
	var new_strategy: Party.CompanionStrategy = index as Party.CompanionStrategy
	Party.set_strategy(_current_companion, new_strategy)
