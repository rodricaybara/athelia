class_name InventoryViewModel
extends Node

## InventoryViewModel (Spike 17)
##
## Único punto de la pantalla de inventario que habla con los sistemas de
## ítems, equipo, recursos y personajes. La View lee el estado público y
## traduce el input del jugador en llamadas request_*().
##
## Reconstruido tomando como base el ViewModel anterior (sin uso). Cambios:
##   - Sin estado de espera: las peticiones son síncronas, no hay nada que
##     esperar, y un estado de espera podía quedarse atascado.
##   - La mochila es una lista sin relleno; cuántos huecos pinta es cosa de la View.
##   - El equipo se lee del sistema de equipo, sin lista fija de slots.
##   - Los refrescos se agrupan y se difieren un frame (equipar sobre un slot
##     ocupado emite dos eventos seguidos).
##   - Sin comparación de ítems: no existe en producción (candidata al Spike 18).
##
## NO hace: renderizar, instanciar nodos, conocer rutas de escena.


# ============================================
# ENUMS Y DATA CLASSES
# ============================================

enum InventoryState {
	HIDDEN,         ## Cerrado
	BROWSING,       ## Abierto, sin ítem seleccionado
	ITEM_SELECTED,  ## Abierto, con un ítem seleccionado
}

## Datos del panel de detalle (lo que consume ItemDetailPanel.show_item)
class DetailData:
	var item_def: ItemDefinition = null
	var quantity: int = 0
	var is_equipped: bool = false


# ============================================
# SEÑAL HACIA LA VIEW
# ============================================

## Razones:
##   "opened"    → pintar todo
##   "inventory" → mochila
##   "equipment" → slots de equipo
##   "stats"     → cabecera de recursos y atributos
##   "selection" → resaltado del slot + panel de detalle
##   "feedback"  → mensaje (feedback_message / feedback_is_error)
##   "closed"    → ocultar y emitir closed
signal changed(reason: String)


# ============================================
# ESTADO PÚBLICO (solo lectura para la View)
# ============================================

## Recursos cuyo cambio refresca la cabecera
const STAT_RESOURCES: Array[String] = ["health", "stamina", "gold"]

var state: InventoryState = InventoryState.HIDDEN
var entity_id: String = "player"

## Ítems de la mochila, sin relleno de huecos vacíos
var bag_items: Array[ItemInstance] = []
## slot_id → ItemDefinition (solo slots ocupados)
var equipped_items: Dictionary = {}
## null si no hay selección válida
var detail: DetailData = null
var selected_item_id: String = ""

var stat_health: float = 0.0
var stat_stamina: float = 0.0
var stat_gold: float = 0.0
var stat_strength: float = 0.0
var stat_dexterity: float = 0.0
var stat_constitution: float = 0.0

## Mensaje ya traducido; la View lo lee al recibir "feedback"
var feedback_message: String = ""
var feedback_is_error: bool = false

## Refrescos pendientes de agrupar ("inventory", "equipment", "stats").
## No es estado de pantalla: solo evita emitir varias veces lo mismo.
var _dirty: Dictionary = {}

## Ítem cuyo EQUIPAR pasa por el puente de ítems, que también emite
## item_use_success. Se ignora ese éxito: el mensaje lo da el evento de equipo.
var _equip_request_item_id: String = ""


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	EventBus.item_added.connect(_on_item_changed)
	EventBus.item_removed.connect(_on_item_changed)
	EventBus.item_use_success.connect(_on_item_use_success)
	EventBus.item_use_failed.connect(_on_item_use_failed)
	EventBus.resource_changed.connect(_on_resource_changed)
	# El equipo tiene sus propias señales (no pasan por el bus de eventos)
	Equipment.item_equipped.connect(_on_item_equipped)
	Equipment.item_unequipped.connect(_on_item_unequipped)


# ============================================
# INTENCIONES (llamadas desde la View)
# ============================================

func open(p_entity_id: String = "player") -> void:
	entity_id = p_entity_id
	selected_item_id = ""
	detail = null
	feedback_message = ""
	feedback_is_error = false
	_equip_request_item_id = ""
	_dirty.clear()
	_rebuild_bag()
	_rebuild_equipment()
	_rebuild_stats()
	state = InventoryState.BROWSING
	changed.emit("opened")


func request_close() -> void:
	selected_item_id = ""
	detail = null
	state = InventoryState.HIDDEN
	_dirty.clear()
	changed.emit("closed")


## Seleccionar un ítem de la mochila (volver a pulsar el mismo lo mantiene)
func select_item(item_id: String) -> void:
	if state == InventoryState.HIDDEN:
		return
	selected_item_id = item_id
	_rebuild_detail()
	changed.emit("selection")


## Botón USAR. El sistema de ítems valida (existe, es usable) y emite la petición.
func request_use(item_id: String) -> void:
	if state == InventoryState.HIDDEN or item_id.is_empty():
		return
	Inventory.request_use_item(entity_id, item_id)


## Botón EQUIPAR. Mismo camino que USAR: el puente de ítems decide equipar o consumir.
func request_equip(item_id: String) -> void:
	if state == InventoryState.HIDDEN or item_id.is_empty():
		return
	_equip_request_item_id = item_id
	Inventory.request_use_item(entity_id, item_id)


## Botón DESEQUIPAR del panel de detalle
func request_unequip_item(item_id: String) -> void:
	if state == InventoryState.HIDDEN or item_id.is_empty():
		return
	Equipment.unequip_item(entity_id, item_id)


## Clic en un slot de equipo ocupado
func request_unequip_slot(slot_id: String) -> void:
	if state == InventoryState.HIDDEN or slot_id.is_empty():
		return
	Equipment.unequip_slot(entity_id, slot_id)


## Arrastrar un ítem de la mochila sobre un slot de equipo
func request_equip_drop(slot_id: String, item_id: String) -> void:
	if state == InventoryState.HIDDEN:
		return

	if not Inventory.has_item(entity_id, item_id):
		_set_feedback(tr("INVENTORY_ERROR_NOT_IN_INVENTORY"), true)
		return

	if not Equipment.can_equip_in_slot(entity_id, item_id, slot_id):
		var item_def: ItemDefinition = Items.get_item(item_id)
		var item_name: String = tr(item_def.name_key) if item_def else item_id
		_set_feedback(tr("INVENTORY_ERROR_SLOT_MISMATCH") % [item_name, _slot_display_name(slot_id)], true)
		return

	Equipment.equip_item(entity_id, item_id)


# ============================================
# CALLBACKS DE SISTEMAS
# ============================================

func _on_item_changed(ent_id: String, _item_id: String, _qty: int) -> void:
	if ent_id != entity_id or state == InventoryState.HIDDEN:
		return
	_mark_dirty("inventory")


func _on_item_equipped(ent_id: String, item_id: String, _slot: String) -> void:
	if ent_id != entity_id or state == InventoryState.HIDDEN:
		return
	_mark_equipment_dirty()
	_set_feedback(tr("INVENTORY_FEEDBACK_EQUIPPED") % _item_name(item_id), false)


func _on_item_unequipped(ent_id: String, item_id: String, _slot: String) -> void:
	if ent_id != entity_id or state == InventoryState.HIDDEN:
		return
	_mark_equipment_dirty()
	_set_feedback(tr("INVENTORY_FEEDBACK_UNEQUIPPED") % _item_name(item_id), false)


func _mark_equipment_dirty() -> void:
	_mark_dirty("equipment")
	# Los atributos cambian con los modificadores del equipo
	_mark_dirty("stats")


func _on_resource_changed(ent_id: String, resource_id: String, _old_value: float, _new_value: float) -> void:
	if ent_id != entity_id or state == InventoryState.HIDDEN:
		return
	if resource_id in STAT_RESOURCES:
		_mark_dirty("stats")


func _on_item_use_success(ent_id: String, item_id: String) -> void:
	if ent_id != entity_id or state == InventoryState.HIDDEN:
		return
	# Equipar pasa por el mismo camino que usar; su mensaje lo da item_equipped
	if item_id == _equip_request_item_id:
		_equip_request_item_id = ""
		return
	var item_def: ItemDefinition = Items.get_item(item_id)
	if item_def:
		_set_feedback(tr("INVENTORY_FEEDBACK_USED") % tr(item_def.name_key), false)


func _on_item_use_failed(ent_id: String, _item_id: String, reason: String) -> void:
	if ent_id != entity_id or state == InventoryState.HIDDEN:
		return
	_equip_request_item_id = ""
	# El motivo llega como texto libre del sistema que falla (pendiente: códigos)
	_set_feedback(tr("INVENTORY_ERROR_PREFIX") % reason, true)


# ============================================
# REFRESCO AGRUPADO
# ============================================

func _mark_dirty(kind: String) -> void:
	var was_empty: bool = _dirty.is_empty()
	_dirty[kind] = true
	if was_empty:
		call_deferred("_flush_dirty")


func _flush_dirty() -> void:
	if state == InventoryState.HIDDEN:
		_dirty.clear()
		return

	var equipment_dirty: bool = _dirty.has("equipment")
	var bag_dirty: bool = _dirty.has("inventory")
	var stats_dirty: bool = _dirty.has("stats")
	_dirty.clear()

	if equipment_dirty:
		_rebuild_equipment()
	if bag_dirty:
		_rebuild_bag()
	if stats_dirty:
		_rebuild_stats()

	# Si cambió la mochila o el equipo, el detalle (cantidad, equipado) puede
	# estar obsoleto; si el ítem ya no existe, se limpia la selección.
	var selection_dirty: bool = false
	if (bag_dirty or equipment_dirty) and not selected_item_id.is_empty():
		if not Inventory.has_item(entity_id, selected_item_id):
			selected_item_id = ""
		_rebuild_detail()
		selection_dirty = true

	# Todo el estado ya es coherente: ahora se avisa a la View
	if equipment_dirty:
		changed.emit("equipment")
	if bag_dirty:
		changed.emit("inventory")
	if stats_dirty:
		changed.emit("stats")
	if selection_dirty:
		changed.emit("selection")


# ============================================
# CONSTRUCCIÓN DE SNAPSHOTS
# ============================================

func _rebuild_bag() -> void:
	bag_items.clear()
	var inventory: Dictionary = Inventory.get_inventory(entity_id)
	for item_id in inventory.keys():
		var instance: ItemInstance = inventory[item_id]
		if instance:
			bag_items.append(instance)


func _rebuild_equipment() -> void:
	equipped_items.clear()
	var all_equipment: Dictionary = Equipment.get_all_equipment(entity_id)
	for slot_id in all_equipment.keys():
		var item_id: String = all_equipment[slot_id]
		if item_id.is_empty():
			continue
		var item_def: ItemDefinition = Items.get_item(item_id)
		if item_def:
			equipped_items[slot_id] = item_def


func _rebuild_stats() -> void:
	stat_health = Resources.get_resource_amount(entity_id, "health")
	stat_stamina = Resources.get_resource_amount(entity_id, "stamina")
	stat_gold = Resources.get_resource_amount(entity_id, "gold")
	stat_strength = Characters.get_base_attribute(entity_id, "strength")
	stat_dexterity = Characters.get_base_attribute(entity_id, "dexterity")
	stat_constitution = Characters.get_base_attribute(entity_id, "constitution")


func _rebuild_detail() -> void:
	detail = null
	var item_def: ItemDefinition = null
	if not selected_item_id.is_empty():
		item_def = Items.get_item(selected_item_id)

	if item_def:
		var data := DetailData.new()
		data.item_def = item_def
		data.quantity = Inventory.get_item_quantity(entity_id, selected_item_id)
		data.is_equipped = Equipment.is_item_equipped(entity_id, selected_item_id)
		detail = data

	if state != InventoryState.HIDDEN:
		state = InventoryState.ITEM_SELECTED if detail != null else InventoryState.BROWSING


# ============================================
# AUXILIARES
# ============================================

func _set_feedback(message: String, is_error: bool) -> void:
	feedback_message = message
	feedback_is_error = is_error
	changed.emit("feedback")


## Nombre traducido de un ítem; si no existe la definición, su id
func _item_name(item_id: String) -> String:
	var item_def: ItemDefinition = Items.get_item(item_id)
	return tr(item_def.name_key) if item_def else item_id


## Nombre visible de un slot de equipo; si no hay clave, el id capitalizado
func _slot_display_name(slot_id: String) -> String:
	var key: String = "INVENTORY_SLOT_" + slot_id.to_upper()
	var text: String = tr(key)
	return text if text != key else slot_id.capitalize()
