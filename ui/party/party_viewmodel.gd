class_name PartyViewModel
extends Node

## PartyViewModel (Spike 19a)
##
## Estado de la pantalla de Party: columna del jugador + columna del compañero
## activo. Entrega a la View datos ya listos para pintar (definición, cantidad,
## capacidad, marcas, textos traducidos): la View no toca ningún sistema.
##
## Responsabilidades:
##   - Construir los snapshots de las dos columnas (equipo + mochila + capacidad)
##   - Navegar entre compañeros y cambiar su estrategia (por id de enum)
##   - Equipar / desequipar / usar desde la mochila
##   - Transferir ítems entre entidades al soltarlos sobre un slot de equipo
##   - Dar feedback localizado de cada operación
##
## NO hace: renderizar, instanciar nodos, conocer rutas de escena.
##
## Razones de changed(reason):
##   "opened"            → pintar todo
##   "player_column"     → refrescar solo la columna del jugador
##   "companion_column"  → refrescar solo la columna del compañero
##   "companion_changed" → cambió el compañero activo (cabecera + columna)
##   "party_changed"     → entró o salió un compañero con la pantalla abierta
##   "feedback"          → mensaje (feedback_message / feedback_is_error)
##   "closed"            → ocultar y emitir closed


# ============================================
# ENUMS, CONSTANTES Y DATA CLASSES
# ============================================

enum PartyState {
	HIDDEN,     ## Pantalla cerrada
	SHOWING,    ## Pantalla abierta
}

const PLAYER_ID: String = "player"
## Reserva si la definición del personaje no declara slots de equipo
const DEFAULT_EQUIPMENT_SLOTS: Array[String] = ["head", "body", "hands", "feet", "weapon", "shield"]


## Una pila de la mochila
class BagEntry:
	var definition: ItemDefinition = null
	var quantity: int = 0
	var is_equipped: bool = false     ## el ítem está equipado (sigue en la mochila)
	var is_overflow: bool = false     ## por encima de la capacidad


## Un slot de equipo
class EquipEntry:
	var slot_id: String = ""
	var slot_name: String = ""        ## ya traducido
	var definition: ItemDefinition = null   ## null = slot vacío


## Una columna (jugador o compañero)
class ColumnData:
	var entity_id: String = ""
	var display_name: String = ""     ## ya traducido
	var has_entity: bool = false
	var capacity: int = 0
	var used_slots: int = 0
	var active_strategy: int = -1     ## id de Party.CompanionStrategy; -1 = no aplica
	var equip_entries: Array[EquipEntry] = []
	var bag_entries: Array[BagEntry] = []


## Una opción de estrategia
class StrategyOption:
	var id: int = 0                   ## valor de Party.CompanionStrategy
	var name: String = ""             ## ya traducido


## Una pestaña de compañero
class CompanionTab:
	var entity_id: String = ""
	var name: String = ""             ## ya traducido


signal changed(reason: String)


# ============================================
# ESTADO PÚBLICO (solo lectura para la View)
# ============================================

var state: PartyState = PartyState.HIDDEN

var player_column: ColumnData = ColumnData.new()
var companion_column: ColumnData = ColumnData.new()

## Compañeros del grupo, en orden
var companions: Array[CompanionTab] = []
var companion_index: int = 0

## Estrategias disponibles, con nombre traducido
var strategies: Array[StrategyOption] = []

## Mensaje ya traducido; la View lo lee al recibir "feedback"
var feedback_message: String = ""
var feedback_is_error: bool = false


# ============================================
# ESTADO INTERNO
# ============================================

## Entidades pendientes de refrescar: { entity_id: true }
var _dirty: Dictionary = {}

## true mientras una operación compuesta (desequipar + transferir + equipar)
## está en marcha: los eventos intermedios no dan mensaje, solo el final
var _suppress_feedback: bool = false

var _last_feedback_text: String = ""
var _last_feedback_frame: int = -1


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	Equipment.item_equipped.connect(_on_item_equipped)
	Equipment.item_unequipped.connect(_on_item_unequipped)
	Equipment.equip_failed.connect(_on_equip_failed)
	EventBus.item_added.connect(_on_inventory_changed)
	EventBus.item_removed.connect(_on_inventory_changed)
	EventBus.item_use_success.connect(_on_item_use_success)
	EventBus.item_use_failed.connect(_on_item_use_failed)
	EventBus.companion_joined.connect(_on_party_membership_changed)
	EventBus.companion_left.connect(_on_party_membership_changed)
	print("[PartyVM] Ready")


# ============================================
# INTENCIONES
# ============================================

func open() -> void:
	feedback_message = ""
	feedback_is_error = false
	_dirty.clear()
	_rebuild_strategies()
	_refresh_companion_list()
	_clamp_companion_index()
	_rebuild_columns()
	state = PartyState.SHOWING
	changed.emit("opened")


func request_close() -> void:
	state = PartyState.HIDDEN
	_dirty.clear()
	changed.emit("closed")


## Cambia el compañero visible (pestañas)
func select_companion(index: int) -> void:
	if state == PartyState.HIDDEN:
		return
	if index < 0 or index >= companions.size() or index == companion_index:
		return
	companion_index = index
	companion_column = _build_column(_current_companion_id())
	changed.emit("companion_changed")


## Estrategia del compañero visible, por id de Party.CompanionStrategy
func request_set_strategy(strategy_id: int) -> void:
	if state == PartyState.HIDDEN:
		return
	var companion_id: String = _current_companion_id()
	if companion_id.is_empty():
		return
	Party.set_strategy(companion_id, strategy_id as Party.CompanionStrategy)
	# El OptionButton ya muestra la selección: no hace falta repintar
	companion_column.active_strategy = strategy_id


## Clic en un slot de la mochila: equipar/desequipar o usar un consumible
func request_slot_action(item_id: String, entity_id: String) -> void:
	if state == PartyState.HIDDEN:
		return
	var item_def: ItemDefinition = Items.get_item(item_id)
	if item_def == null:
		return

	if item_def.item_type == "EQUIPMENT":
		Equipment.toggle_equipment(entity_id, item_id)
	elif item_def.item_type == "CONSUMABLE" and item_def.usable:
		EventBus.item_use_requested.emit(entity_id, item_id)


## Clic en un slot de equipo ocupado
func request_unequip(slot_id: String, entity_id: String) -> void:
	if state == PartyState.HIDDEN:
		return
	Equipment.unequip_slot(entity_id, slot_id)


## Soltar un ítem sobre un slot de equipo de `target_entity`.
## `from_entity` es el dueño del slot de origen (payload del arrastre).
##
## Orden (Spike 19): se valida TODO antes de tocar nada.
##   1. El slot admite el ítem (si no, mensaje y nada se mueve)
##   2. Si el destino ya tiene una copia, se equipa la suya y no se transfiere
##   3. Si no: se desequipa en el origen, se transfiere y se equipa en el destino;
##      si algún paso falla, se revierte lo hecho y se avisa
func request_equip_drop(slot_id: String, item_id: String, target_entity: String, from_entity: String) -> void:
	if state == PartyState.HIDDEN or target_entity.is_empty():
		return

	var item_def: ItemDefinition = Items.get_item(item_id)
	if item_def == null:
		_set_feedback(tr("PARTY_ERROR_ITEM_NOT_FOUND"), true)
		return

	# 1. ¿Encaja en el slot? Antes de mover nada
	if not Equipment.can_equip_in_slot(target_entity, item_id, slot_id):
		_set_feedback(tr("PARTY_ERROR_WRONG_SLOT") % [tr(item_def.name_key), _slot_display_name(slot_id)], true)
		return

	# 2. El destino ya tiene copia: se equipa la suya (el mensaje lo da el evento)
	if Inventory.has_item(target_entity, item_id):
		Equipment.equip_item(target_entity, item_id)
		return

	# 3. Transferencia. Origen real: el del arrastre
	var source_entity: String = from_entity
	if source_entity.is_empty():
		source_entity = _find_item_owner(item_id)
	if source_entity.is_empty() or source_entity == target_entity or not Inventory.has_item(source_entity, item_id):
		_set_feedback(tr("PARTY_ERROR_ITEM_NOT_FOUND"), true)
		return

	var item_name: String = tr(item_def.name_key)
	_suppress_feedback = true

	# El origen no debe conservar el ítem equipado (ni sus modificadores)
	var was_equipped: bool = Equipment.is_item_equipped(source_entity, item_id)
	if was_equipped:
		Equipment.unequip_item(source_entity, item_id)

	if not _transfer_item(source_entity, target_entity, item_id):
		if was_equipped:
			Equipment.equip_item(source_entity, item_id)
		_suppress_feedback = false
		_set_feedback(tr("PARTY_ERROR_TRANSFER_FAILED"), true)
		return

	if not Equipment.equip_item(target_entity, item_id):
		# Revertir: devolver el ítem y reequiparlo en el origen
		_transfer_item(target_entity, source_entity, item_id)
		if was_equipped:
			Equipment.equip_item(source_entity, item_id)
		_suppress_feedback = false
		_set_feedback(tr("PARTY_ERROR_EQUIP_FAILED") % item_name, true)
		return

	_suppress_feedback = false
	_set_feedback(tr("PARTY_FEEDBACK_TRANSFERRED") % [item_name, _entity_name(target_entity)], false)


# ============================================
# CALLBACKS DE SISTEMAS
# ============================================

func _on_item_equipped(entity_id: String, item_id: String, _slot: String) -> void:
	if state == PartyState.HIDDEN or not _is_visible_entity(entity_id):
		return
	_mark_dirty(entity_id)
	_set_feedback(tr("PARTY_FEEDBACK_EQUIPPED") % [_entity_name(entity_id), _item_name(item_id)], false)


func _on_item_unequipped(entity_id: String, item_id: String, _slot: String) -> void:
	if state == PartyState.HIDDEN or not _is_visible_entity(entity_id):
		return
	_mark_dirty(entity_id)
	_set_feedback(tr("PARTY_FEEDBACK_UNEQUIPPED") % [_entity_name(entity_id), _item_name(item_id)], false)


## El motivo llega como texto libre en inglés (pendiente: códigos en el core):
## solo se registra en consola, el jugador recibe un mensaje genérico localizado
func _on_equip_failed(entity_id: String, item_id: String, reason: String) -> void:
	if state == PartyState.HIDDEN or not _is_visible_entity(entity_id):
		return
	print("[PartyVM] equip_failed '%s' (%s): %s" % [item_id, entity_id, reason])
	_set_feedback(tr("PARTY_ERROR_EQUIP_FAILED") % _item_name(item_id), true)


func _on_inventory_changed(entity_id: String, _item_id: String, _qty: int) -> void:
	if state == PartyState.HIDDEN or not _is_visible_entity(entity_id):
		return
	_mark_dirty(entity_id)


func _on_item_use_success(entity_id: String, item_id: String) -> void:
	if state == PartyState.HIDDEN or not _is_visible_entity(entity_id):
		return
	var item_def: ItemDefinition = Items.get_item(item_id)
	if item_def == null or item_def.item_type == "EQUIPMENT":
		return   # equipar/desequipar ya da su mensaje
	_set_feedback(tr("PARTY_FEEDBACK_USED") % [_entity_name(entity_id), _item_name(item_id)], false)


func _on_item_use_failed(entity_id: String, item_id: String, reason: String) -> void:
	if state == PartyState.HIDDEN or not _is_visible_entity(entity_id):
		return
	print("[PartyVM] item_use_failed '%s' (%s): %s" % [item_id, entity_id, reason])
	_set_feedback(tr("PARTY_ERROR_USE_FAILED") % _item_name(item_id), true)


## Entra o sale un compañero con la pantalla abierta
func _on_party_membership_changed(_companion_id: String) -> void:
	if state == PartyState.HIDDEN:
		return
	_dirty.clear()
	_refresh_companion_list()
	_clamp_companion_index()
	_rebuild_columns()
	changed.emit("party_changed")


# ============================================
# REFRESCO AGRUPADO
# ============================================

## Transferir + equipar emite varias señales seguidas: se refresca una vez por frame
func _mark_dirty(entity_id: String) -> void:
	var was_empty: bool = _dirty.is_empty()
	_dirty[entity_id] = true
	if was_empty:
		call_deferred("_flush_dirty")


func _flush_dirty() -> void:
	if state == PartyState.HIDDEN:
		_dirty.clear()
		return

	var pending: Array = _dirty.keys()
	_dirty.clear()

	for raw_id in pending:
		var entity_id: String = str(raw_id)
		if entity_id == PLAYER_ID:
			player_column = _build_column(PLAYER_ID)
			changed.emit("player_column")
		elif entity_id == _current_companion_id():
			companion_column = _build_column(entity_id)
			changed.emit("companion_column")


func _rebuild_columns() -> void:
	player_column = _build_column(PLAYER_ID)
	companion_column = _build_column(_current_companion_id())


# ============================================
# BUILDERS DE SNAPSHOTS
# ============================================

func _build_column(entity_id: String) -> ColumnData:
	var column := ColumnData.new()
	if entity_id.is_empty():
		return column

	column.entity_id = entity_id
	column.has_entity = true
	column.display_name = _entity_name(entity_id)

	var definition: CharacterDefinition = Characters.get_character_definition(entity_id)
	var inventory: Dictionary = Inventory.get_inventory(entity_id)

	column.used_slots = inventory.size()
	column.capacity = BagCapacity.compute(definition, column.used_slots, entity_id)
	column.equip_entries = _build_equip_entries(entity_id, definition)
	column.bag_entries = _build_bag_entries(entity_id, inventory, column.capacity)

	if entity_id != PLAYER_ID:
		column.active_strategy = Party.get_strategy(entity_id) as int

	return column


func _build_equip_entries(entity_id: String, definition: CharacterDefinition) -> Array[EquipEntry]:
	var slot_ids: Array[String] = DEFAULT_EQUIPMENT_SLOTS
	if definition != null and not definition.equipment_slots.is_empty():
		slot_ids = definition.equipment_slots

	var result: Array[EquipEntry] = []
	for slot_id in slot_ids:
		var entry := EquipEntry.new()
		entry.slot_id = slot_id
		entry.slot_name = _slot_display_name(slot_id)
		var equipped_id: String = Equipment.get_equipped_item(entity_id, slot_id)
		if not equipped_id.is_empty():
			entry.definition = Items.get_item(equipped_id)
		result.append(entry)
	return result


func _build_bag_entries(entity_id: String, inventory: Dictionary, capacity: int) -> Array[BagEntry]:
	var result: Array[BagEntry] = []
	var index: int = 0
	for item_id in inventory.keys():
		var instance: ItemInstance = inventory[item_id] as ItemInstance
		if instance == null or instance.definition == null:
			continue
		var entry := BagEntry.new()
		entry.definition = instance.definition
		entry.quantity = instance.quantity
		entry.is_equipped = Equipment.is_item_equipped(entity_id, instance.definition.id)
		entry.is_overflow = index >= capacity
		result.append(entry)
		index += 1
	return result


func _rebuild_strategies() -> void:
	strategies.clear()
	for key in Party.CompanionStrategy.keys():
		var option := StrategyOption.new()
		option.id = int(Party.CompanionStrategy[key])
		option.name = tr("PARTY_STRATEGY_" + str(key))
		strategies.append(option)


func _refresh_companion_list() -> void:
	companions.clear()
	for companion_id in Party.get_party_members():
		var tab := CompanionTab.new()
		tab.entity_id = companion_id
		tab.name = _entity_name(companion_id)
		companions.append(tab)


func _clamp_companion_index() -> void:
	companion_index = clampi(companion_index, 0, maxi(companions.size() - 1, 0))


# ============================================
# TRANSFERENCIA DE ÍTEMS
# ============================================

## Primer dueño del ítem entre las entidades visibles (reserva si el
## arrastre no declara su origen)
func _find_item_owner(item_id: String) -> String:
	if Inventory.has_item(PLAYER_ID, item_id):
		return PLAYER_ID
	for tab in companions:
		if Inventory.has_item(tab.entity_id, item_id):
			return tab.entity_id
	return ""


func _transfer_item(from_entity: String, to_entity: String, item_id: String, quantity: int = 1) -> bool:
	if not Inventory.has_item(from_entity, item_id, quantity):
		push_warning("[PartyVM] '%s' no tiene '%s' x%d" % [from_entity, item_id, quantity])
		return false

	if not Inventory.remove_item(from_entity, item_id, quantity):
		push_warning("[PartyVM] No se pudo quitar '%s' de '%s'" % [item_id, from_entity])
		return false

	if not Inventory.add_item(to_entity, item_id, quantity):
		Inventory.add_item(from_entity, item_id, quantity)   # rollback
		push_warning("[PartyVM] No se pudo añadir '%s' a '%s' — rollback" % [item_id, to_entity])
		return false

	print("[PartyVM] Transferido: %s × %d  %s → %s" % [item_id, quantity, from_entity, to_entity])
	return true


# ============================================
# HELPERS
# ============================================

func _current_companion_id() -> String:
	if companions.is_empty() or companion_index >= companions.size():
		return ""
	return companions[companion_index].entity_id


func _is_visible_entity(entity_id: String) -> bool:
	return entity_id == PLAYER_ID or entity_id == _current_companion_id()


func _entity_name(entity_id: String) -> String:
	if entity_id == PLAYER_ID:
		return tr("PARTY_PLAYER_NAME")
	var definition: CharacterDefinition = Characters.get_character_definition(entity_id)
	return tr(definition.name_key) if definition != null else entity_id


## Nombre traducido de un ítem; si no existe la definición, su id
func _item_name(item_id: String) -> String:
	var item_def: ItemDefinition = Items.get_item(item_id)
	return tr(item_def.name_key) if item_def != null else item_id


func _slot_display_name(slot_id: String) -> String:
	var key: String = "PARTY_SLOT_" + slot_id.to_upper()
	var text: String = tr(key)
	return text if text != key else slot_id.capitalize()


func _set_feedback(message: String, is_error: bool) -> void:
	if _suppress_feedback:
		return
	# Un mismo mensaje dos veces en el mismo frame (dos oyentes del mismo evento)
	var frame: int = Engine.get_process_frames()
	if message == _last_feedback_text and frame == _last_feedback_frame:
		return
	_last_feedback_text = message
	_last_feedback_frame = frame
	feedback_message = message
	feedback_is_error = is_error
	changed.emit("feedback")
