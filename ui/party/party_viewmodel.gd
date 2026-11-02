class_name PartyViewModel
extends Node

## PartyViewModel (Spike 19a, ampliado en el 19b-1 y 19b-2)
##
## Estado de la pantalla de Party: columna del jugador + columna del compañero
## activo. Entrega a la View datos ya listos para pintar (definición, cantidad,
## capacidad, marcas, textos traducidos): la View no toca ningún sistema.
##
## Responsabilidades:
##   - Construir los snapshots de las dos columnas (equipo + mochila + capacidad
##     + recursos + detalle del ítem seleccionado)
##   - Navegar entre compañeros y cambiar su estrategia (por id de enum)
##   - Selección de ítem por columna y sus acciones (usar, equipar, desequipar)
##   - Transferir ítems entre entidades: sobre un slot de equipo (equipa) o
##     mochila a mochila (19b-1)
##   - Regla de objetos de préstamo (tag quest_loan): no salen del jugador
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
##   "resources"         → cambió HP/estamina de alguien visible (19b-2): solo barras
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

## Atributos del tooltip del nombre (valores BASE). Las etiquetas son las del inventario.
const ATTRIBUTE_DEFS: Array = [
	{"key": "strength",     "label_key": "INVENTORY_STAT_STR"},
	{"key": "dexterity",    "label_key": "INVENTORY_STAT_DEX"},
	{"key": "constitution", "label_key": "INVENTORY_STAT_CON"},
	{"key": "intelligence", "label_key": "INVENTORY_STAT_INT"},
	{"key": "wisdom",       "label_key": "INVENTORY_STAT_WIS"},
	{"key": "charisma",     "label_key": "INVENTORY_STAT_CHA"},
]


## Una pila de la mochila
class BagEntry:
	var definition: ItemDefinition = null
	var quantity: int = 0
	var is_equipped: bool = false     ## el ítem está equipado (sigue en la mochila)
	var is_overflow: bool = false     ## por encima de la capacidad
	var is_loan: bool = false         ## objeto de préstamo de misión (quest_loan)


## Un slot de equipo
class EquipEntry:
	var slot_id: String = ""
	var slot_name: String = ""        ## ya traducido
	var definition: ItemDefinition = null   ## null = slot vacío
	var is_loan: bool = false


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
	# --- 19b-2 ---
	var health_current: float = 0.0
	var health_max: float = 0.0
	var stamina_current: float = 0.0
	var stamina_max: float = 0.0
	var attributes_text: String = ""  ## tooltip del nombre, ya traducido
	var selected_item_id: String = "" ## "" = sin selección
	var detail: ItemDetailData = null ## null = sin selección válida


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

## Hay un refresco de barras pendiente (una vez por frame)
var _resources_dirty: bool = false

## Selección por columna: { entity_id: item_id }
var _selected: Dictionary = {}

## true mientras una operación compuesta (desequipar + transferir + equipar)
## está en marcha: los eventos intermedios no dan mensaje, solo el final
var _suppress_feedback: bool = false

var _last_feedback_text: String = ""
var _last_feedback_frame: int = -1

## Cálculo del detalle (modificadores, comparación, formato), compartido con el inventario
var _detail_builder: ItemDetailBuilder = ItemDetailBuilder.new()


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
	EventBus.resource_changed.connect(_on_resource_changed)
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
	_selected.clear()
	_rebuild_strategies()
	_refresh_companion_list()
	_clamp_companion_index()
	_rebuild_columns()
	state = PartyState.SHOWING
	changed.emit("opened")


func request_close() -> void:
	state = PartyState.HIDDEN
	_dirty.clear()
	_selected.clear()
	changed.emit("closed")


## Cambia el compañero visible (pestañas). Su selección se limpia.
func select_companion(index: int) -> void:
	if state == PartyState.HIDDEN:
		return
	if index < 0 or index >= companions.size() or index == companion_index:
		return
	companion_index = index
	_clear_companion_selection()
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


## Clic en un slot de la mochila (19b-2): selecciona; volver a pulsar el mismo
## lo deselecciona. La acción (usar, equipar, desequipar) va por los botones del detalle.
func request_select(item_id: String, entity_id: String) -> void:
	if state == PartyState.HIDDEN or item_id.is_empty() or not _is_visible_entity(entity_id):
		return
	if str(_selected.get(entity_id, "")) == item_id:
		_selected.erase(entity_id)
	else:
		_selected[entity_id] = item_id
	_refresh_column_now(entity_id)


## Botón USAR del detalle
func request_use(item_id: String, entity_id: String) -> void:
	if state == PartyState.HIDDEN or not _is_visible_entity(entity_id):
		return
	var item_def: ItemDefinition = Items.get_item(item_id)
	if item_def == null:
		return
	if item_def.item_type == "CONSUMABLE" and item_def.usable:
		EventBus.item_use_requested.emit(entity_id, item_id)


## Botón EQUIPAR del detalle
func request_equip(item_id: String, entity_id: String) -> void:
	if state == PartyState.HIDDEN or not _is_visible_entity(entity_id):
		return
	var item_def: ItemDefinition = Items.get_item(item_id)
	if item_def == null or item_def.item_type != "EQUIPMENT":
		return
	if Equipment.is_item_equipped(entity_id, item_id):
		return
	# Un préstamo de misión no se equipa en un compañero
	if _is_loan_blocked(item_def, entity_id):
		_set_feedback(tr("PARTY_ERROR_LOAN_ITEM") % tr(item_def.name_key), true)
		return
	Equipment.toggle_equipment(entity_id, item_id)


## Botón DESEQUIPAR del detalle
func request_unequip_item(item_id: String, entity_id: String) -> void:
	if state == PartyState.HIDDEN or not _is_visible_entity(entity_id):
		return
	Equipment.unequip_item(entity_id, item_id)


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
##   2. Un préstamo de misión no entra en un compañero (19b-1)
##   3. Si el destino ya tiene una copia, se equipa la suya y no se transfiere
##      (si ya la lleva equipada no pasa nada y no hay mensaje)
##   4. Si no: se desequipa en el origen, se transfiere y se equipa en el destino;
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

	# 2. Regla de préstamo
	if _is_loan_blocked(item_def, target_entity):
		_set_feedback(tr("PARTY_ERROR_LOAN_ITEM") % tr(item_def.name_key), true)
		return

	# 3. El destino ya tiene copia: se equipa la suya (el mensaje lo da el evento).
	#    Si ya la lleva equipada no hay nada que hacer.
	if Inventory.has_item(target_entity, item_id):
		if not Equipment.is_item_equipped(target_entity, item_id):
			Equipment.equip_item(target_entity, item_id)
		return

	# 4. Transferencia. Origen real: el del arrastre
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
	_set_feedback(tr("PARTY_FEEDBACK_TRANSFERRED") % [item_name, _actor_name(target_entity)], false)


## Mochila a mochila (19b-1). `whole_stack` = true pasa la pila entera; false, 1 unidad.
##
## Se valida TODO antes de mover nada (ver el antipatrón «transferir antes de validar»):
##   1. Estado y entidades válidas; el origen tiene el ítem
##   2. Préstamo de misión: solo puede ir al jugador
##   3. Integridad (Inventory.add_item sobrescribe o recorta sin avisar):
##      destino con el ítem → debe apilar y no superar max_stack;
##      ítem con custom_state → no se puede mover (add_item lo perdería)
##   4. Hueco: un ítem que ocupa pila nueva necesita capacidad libre
## Después: desequipar en el origen si hace falta, transferir con rollback,
## comprobar la cantidad resultante y dar UN solo mensaje.
func request_transfer(item_id: String, from_entity: String, to_entity: String, whole_stack: bool) -> void:
	if state == PartyState.HIDDEN:
		return
	if from_entity.is_empty() or to_entity.is_empty() or from_entity == to_entity:
		return
	if not _is_visible_entity(from_entity) or not _is_visible_entity(to_entity):
		return

	var item_def: ItemDefinition = Items.get_item(item_id)
	var source: ItemInstance = Inventory.get_inventory(from_entity).get(item_id) as ItemInstance
	if item_def == null or source == null:
		_set_feedback(tr("PARTY_ERROR_ITEM_NOT_FOUND"), true)
		return

	var item_name: String = tr(item_def.name_key)
	var quantity: int = source.quantity if whole_stack else 1
	quantity = clampi(quantity, 1, source.quantity)

	# 2. Préstamo de misión
	if _is_loan_blocked(item_def, to_entity):
		_set_feedback(tr("PARTY_ERROR_LOAN_ITEM") % item_name, true)
		return

	# 3. Integridad
	if not source.custom_state.is_empty():
		push_warning("[PartyVM] '%s' tiene custom_state: add_item lo perdería, transferencia rechazada" % item_id)
		_set_feedback(tr("PARTY_ERROR_TRANSFER_FAILED"), true)
		return

	var dest_inventory: Dictionary = Inventory.get_inventory(to_entity)
	var existing: ItemInstance = dest_inventory.get(item_id) as ItemInstance
	if existing != null:
		var fits: bool = existing.can_stack_with(source) and existing.quantity + quantity <= item_def.max_stack
		if not fits:
			_set_feedback(tr("PARTY_ERROR_CANNOT_STACK") % item_name, true)
			return
	else:
		# 4. Pila nueva: ¿hay hueco?
		var definition: CharacterDefinition = Characters.get_character_definition(to_entity)
		var capacity: int = BagCapacity.compute(definition, dest_inventory.size(), to_entity)
		if dest_inventory.size() >= capacity:
			_set_feedback(tr("PARTY_ERROR_BAG_FULL") % _actor_name(to_entity), true)
			return

	# Ejecución
	_suppress_feedback = true
	var needs_unequip: bool = quantity >= source.quantity and Equipment.is_item_equipped(from_entity, item_id)
	if needs_unequip:
		Equipment.unequip_item(from_entity, item_id)

	var dest_before: int = Inventory.get_item_quantity(to_entity, item_id)
	if not _transfer_item(from_entity, to_entity, item_id, quantity):
		if needs_unequip:
			Equipment.equip_item(from_entity, item_id)
		_suppress_feedback = false
		_set_feedback(tr("PARTY_ERROR_TRANSFER_FAILED"), true)
		return
	_suppress_feedback = false

	var dest_after: int = Inventory.get_item_quantity(to_entity, item_id)
	if dest_after != dest_before + quantity:
		push_error("[PartyVM] Integridad: '%s' en '%s' era %d, esperado %d, es %d" % [
			item_id, to_entity, dest_before, dest_before + quantity, dest_after])

	_set_feedback(tr("PARTY_FEEDBACK_BAG_TRANSFERRED") % [item_name, quantity, _actor_name(to_entity)], false)


# ============================================
# CALLBACKS DE SISTEMAS
# ============================================

func _on_item_equipped(entity_id: String, item_id: String, _slot: String) -> void:
	if state == PartyState.HIDDEN or not _is_visible_entity(entity_id):
		return
	_mark_dirty(entity_id)
	_set_feedback(tr("PARTY_FEEDBACK_EQUIPPED") % [_actor_name(entity_id), _item_name(item_id)], false)


func _on_item_unequipped(entity_id: String, item_id: String, _slot: String) -> void:
	if state == PartyState.HIDDEN or not _is_visible_entity(entity_id):
		return
	_mark_dirty(entity_id)
	_set_feedback(tr("PARTY_FEEDBACK_UNEQUIPPED") % [_actor_name(entity_id), _item_name(item_id)], false)


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
	_set_feedback(tr("PARTY_FEEDBACK_USED") % [_actor_name(entity_id), _item_name(item_id)], false)


func _on_item_use_failed(entity_id: String, item_id: String, reason: String) -> void:
	if state == PartyState.HIDDEN or not _is_visible_entity(entity_id):
		return
	print("[PartyVM] item_use_failed '%s' (%s): %s" % [item_id, entity_id, reason])
	_set_feedback(tr("PARTY_ERROR_USE_FAILED") % _item_name(item_id), true)


## HP o estamina de alguien visible: solo se refrescan las barras (una vez por
## frame; la estamina se regenera y emite con frecuencia)
func _on_resource_changed(entity_id: String, resource_id: String, _old_value: float, _new_value: float) -> void:
	if state == PartyState.HIDDEN or not _is_visible_entity(entity_id):
		return
	if resource_id != "health" and resource_id != "stamina":
		return
	if not _resources_dirty:
		_resources_dirty = true
		call_deferred("_flush_resources")


func _flush_resources() -> void:
	_resources_dirty = false
	if state == PartyState.HIDDEN:
		return
	_fill_resources(player_column)
	_fill_resources(companion_column)
	changed.emit("resources")


## Entra o sale un compañero con la pantalla abierta
func _on_party_membership_changed(_companion_id: String) -> void:
	if state == PartyState.HIDDEN:
		return
	_dirty.clear()
	_clear_companion_selection()
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
		_refresh_column_now(str(raw_id))


## Reconstruye y avisa de la columna de esa entidad (si está visible)
func _refresh_column_now(entity_id: String) -> void:
	if entity_id == PLAYER_ID:
		player_column = _build_column(PLAYER_ID)
		changed.emit("player_column")
	elif entity_id == _current_companion_id():
		companion_column = _build_column(entity_id)
		changed.emit("companion_column")


func _rebuild_columns() -> void:
	player_column = _build_column(PLAYER_ID)
	companion_column = _build_column(_current_companion_id())


## La selección de los compañeros no sobrevive a un cambio de pestaña ni de grupo
func _clear_companion_selection() -> void:
	for raw_id in _selected.keys():
		if str(raw_id) != PLAYER_ID:
			_selected.erase(raw_id)


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

	_fill_resources(column)
	column.attributes_text = _build_attributes_text(entity_id)

	# Selección: si el ítem ya no está en la mochila, se limpia
	var selected_id: String = str(_selected.get(entity_id, ""))
	if not selected_id.is_empty() and not inventory.has(selected_id):
		_selected.erase(entity_id)
		selected_id = ""
	column.selected_item_id = selected_id
	if not selected_id.is_empty():
		var item_def: ItemDefinition = Items.get_item(selected_id)
		if item_def != null:
			column.detail = _detail_builder.build(
				entity_id,
				item_def,
				Inventory.get_item_quantity(entity_id, selected_id),
				Equipment.is_item_equipped(entity_id, selected_id))

	return column


## HP y estamina actuales y máximas (lo que pinta UIResourceBar vía set_values)
func _fill_resources(column: ColumnData) -> void:
	if not column.has_entity:
		return
	var health: ResourceState = Resources.get_resource_state(column.entity_id, "health")
	if health != null:
		column.health_current = health.current
		column.health_max = health.max_effective
	var stamina: ResourceState = Resources.get_resource_state(column.entity_id, "stamina")
	if stamina != null:
		column.stamina_current = stamina.current
		column.stamina_max = stamina.max_effective


## Tooltip con los atributos BASE (los efectivos no son un valor directo: ver AttributeResolver)
func _build_attributes_text(entity_id: String) -> String:
	var lines: PackedStringArray = []
	lines.append(tr("PARTY_TOOLTIP_ATTRIBUTES"))
	for raw_def in ATTRIBUTE_DEFS:
		var def: Dictionary = raw_def
		var value: int = int(Characters.get_base_attribute(entity_id, str(def["key"])))
		lines.append("%s: %d" % [tr(str(def["label_key"])), value])
	return "\n".join(lines)


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
			entry.is_loan = entry.definition != null and entry.definition.has_tag(Economy.LOAN_TAG)
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
		entry.is_loan = instance.definition.has_tag(Economy.LOAN_TAG)
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


## Un objeto de préstamo de misión solo puede estar en manos del jugador
func _is_loan_blocked(item_def: ItemDefinition, target_entity: String) -> bool:
	return target_entity != PLAYER_ID and item_def.has_tag(Economy.LOAN_TAG)


# ============================================
# HELPERS
# ============================================

func _current_companion_id() -> String:
	if companions.is_empty() or companion_index >= companions.size():
		return ""
	return companions[companion_index].entity_id


func _is_visible_entity(entity_id: String) -> bool:
	return entity_id == PLAYER_ID or entity_id == _current_companion_id()


## Nombre para cabeceras y pestañas ("Jugador" genérico para el jugador)
func _entity_name(entity_id: String) -> String:
	if entity_id == PLAYER_ID:
		return tr("PARTY_PLAYER_NAME")
	var definition: CharacterDefinition = Characters.get_character_definition(entity_id)
	return tr(definition.name_key) if definition != null else entity_id


## Nombre para los mensajes: el del personaje del jugador si existe
func _actor_name(entity_id: String) -> String:
	if entity_id == PLAYER_ID:
		var real_name: String = Characters.get_character_name(PLAYER_ID)
		if not real_name.is_empty():
			return real_name
	return _entity_name(entity_id)


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
