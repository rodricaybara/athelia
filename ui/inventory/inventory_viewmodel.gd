class_name InventoryViewModel
extends Node

## InventoryViewModel (Spike 17; ampliado en el Spike 18, Fase 1)
##
## Único punto de la pantalla de inventario que habla con los sistemas de
## ítems, equipo, recursos y personajes. La View lee el estado público y
## traduce el input del jugador en llamadas request_*().
##
## Spike 18 (Fase 1) — SOLO AÑADE. Todo lo que usa la View del Spike 17
## (bag_items, equipped_items, stat_*, detail.item_def/quantity/is_equipped,
## razones de changed) sigue igual. Lo nuevo:
##   - Capacidad: capacity / used_slots / total_weight (informativo).
##   - Categorías desde res://data/ui/inventory_categories.json (tag → categoría,
##     gana la de menor prioridad). Pestañas: categories + active_category.
##   - bag_entries: mochila filtrada por la pestaña activa y ordenada
##     (categoría, nombre traducido, id). Estable y no persistente.
##   - equipment_slot_ids: slots del personaje, en el orden de su definición.
##   - stat_entries: celdas del bloque de estadísticas (lista en STAT_DEFS).
##   - DetailData ampliado: categoría, modificadores con etiqueta localizada y
##     comparación con lo equipado en el slot que le correspondería.
##   - Escucha Equipment.equip_failed (mensaje genérico localizado).
##   (El log temporal de validación de la Fase 1 se retiró en la Fase 4.)
##
## NO hace: renderizar, instanciar nodos, conocer rutas de escena.


# ============================================
# ENUMS, CONSTANTES Y DATA CLASSES
# ============================================

enum InventoryState {
	HIDDEN,         ## Cerrado
	BROWSING,       ## Abierto, sin ítem seleccionado
	ITEM_SELECTED,  ## Abierto, con un ítem seleccionado
}

## Id de la pestaña «Todo» (siempre existe, siempre la primera)
const CATEGORY_ALL: String = "all"

## Tabla tag → categoría (datos, con versión). Si falta, solo existe «Todo».
const CATEGORIES_PATH: String = "res://data/ui/inventory_categories.json"
const CATEGORIES_VERSION: int = 1

## Recursos cuyo cambio refresca la cabecera y el bloque de estadísticas
const STAT_RESOURCES: Array[String] = ["health", "stamina", "gold", "focus"]

## Celdas del bloque de estadísticas, en orden. kind: "resource" | "attribute".
## enabled = false oculta la celda (PM/Focus: sin sistema de magia todavía).
## Añadir una celda = añadir una línea + su clave INVENTORY_STAT_* en inventory.csv.
const STAT_DEFS: Array = [
	{"id": "health",       "kind": "resource",  "key": "health",       "label_key": "INVENTORY_STAT_HP",      "enabled": true},
	{"id": "stamina",      "kind": "resource",  "key": "stamina",      "label_key": "INVENTORY_STAT_STAMINA", "enabled": true},
	{"id": "focus",        "kind": "resource",  "key": "focus",        "label_key": "INVENTORY_STAT_FOCUS",   "enabled": false},
	{"id": "strength",     "kind": "attribute", "key": "strength",     "label_key": "INVENTORY_STAT_STR",     "enabled": true},
	{"id": "dexterity",    "kind": "attribute", "key": "dexterity",    "label_key": "INVENTORY_STAT_DEX",     "enabled": true},
	{"id": "constitution", "kind": "attribute", "key": "constitution", "label_key": "INVENTORY_STAT_CON",     "enabled": true},
	{"id": "intelligence", "kind": "attribute", "key": "intelligence", "label_key": "INVENTORY_STAT_INT",     "enabled": true},
	{"id": "wisdom",       "kind": "attribute", "key": "wisdom",       "label_key": "INVENTORY_STAT_WIS",     "enabled": true},
	{"id": "charisma",     "kind": "attribute", "key": "charisma",     "label_key": "INVENTORY_STAT_CHA",     "enabled": true},
]


## Una pila de la mochila tal como la pinta la View
class BagEntry:
	var instance: ItemInstance = null
	var category_id: String = ""      ## "" = sin categoría (solo se ve en «Todo»)
	var is_equipped: bool = false     ## el ítem está equipado (sigue en la mochila)
	var is_overflow: bool = false     ## por encima de la capacidad (orden de adquisición)
	var sort_rank: int = 0
	var sort_name: String = ""


## Una pestaña
class CategoryData:
	var id: String = ""
	var name: String = ""             ## ya traducido
	var count: int = 0                ## pilas en esa categoría


## Una celda del bloque de estadísticas
class StatEntry:
	var id: String = ""
	var kind: String = ""             ## "resource" | "attribute"
	var label: String = ""            ## ya traducido
	var value: int = 0


## Una línea de modificador del detalle ("Armadura", "+3")
class ModLine:
	var label: String = ""            ## ya traducido
	var text: String = ""             ## "+3", "-1", "x1.20", "= 5"
	var value: float = 0.0


## Una línea de comparación ("Armadura", "+1")
class CompareLine:
	var label: String = ""            ## ya traducido
	var text: String = ""
	var delta: float = 0.0            ## > 0 mejora, < 0 empeora (la View elige el color)


## Datos del panel de detalle
class DetailData:
	# --- Spike 17 (no cambian) ---
	var item_def: ItemDefinition = null
	var quantity: int = 0
	var is_equipped: bool = false
	# --- Spike 18 ---
	var category_id: String = ""
	var category_name: String = ""
	var modifier_lines: Array[ModLine] = []
	## Comparación: solo para EQUIPMENT no equipado con un slot válido
	var has_comparison: bool = false
	var compare_slot_id: String = ""
	var compare_slot_free: bool = false      ## el slot está libre: no hay con qué comparar
	var compare_against_name: String = ""    ## nombre traducido de lo equipado
	var compare_lines: Array[CompareLine] = []  ## vacío + has_comparison = sin diferencias


# ============================================
# SEÑAL HACIA LA VIEW
# ============================================

## Razones:
##   "opened"     → pintar todo
##   "inventory"  → mochila (bag_entries), pestañas (recuentos) y contadores
##   "equipment"  → slots de equipo, marcas de «equipado» de la mochila y bonos del equipo
##   "stats"      → cabecera de recursos y bloque de estadísticas
##   "selection"  → resaltado del slot + panel de detalle
##   "categories" → cambió la pestaña activa (Spike 18): repintar mochila y pestañas
##   "feedback"   → mensaje (feedback_message / feedback_is_error)
##   "closed"     → ocultar y emitir closed
signal changed(reason: String)


# ============================================
# ESTADO PÚBLICO (solo lectura para la View)
# ============================================

var state: InventoryState = InventoryState.HIDDEN
var entity_id: String = "player"

## Ítems de la mochila, sin relleno, en orden de adquisición (Spike 17)
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

# --- Spike 18 ---

## Huecos de la mochila (CharacterDefinition.inventory_slots)
var capacity: int = 0
## Pilas ocupadas (un ítem equipado sigue ocupando su hueco)
var used_slots: int = 0
## Suma de peso × cantidad. Informativo: ningún sistema limita por peso.
var total_weight: float = 0.0

## Pestañas: «Todo» primero, después las del JSON (en su orden)
var categories: Array[CategoryData] = []
var active_category: String = CATEGORY_ALL
## Mochila de la pestaña activa, ordenada
var bag_entries: Array[BagEntry] = []

## Slots de equipo del personaje, en el orden de su definición
var equipment_slot_ids: Array[String] = []

## Celdas del bloque de estadísticas (solo las habilitadas)
var stat_entries: Array[StatEntry] = []

## Bonos del equipo: suma por objetivo de los modificadores "add" de todo lo
## equipado, ordenados por nombre. Se actualiza con la razón "equipment".
var equipment_bonuses: Array[ModLine] = []


# ============================================
# ESTADO INTERNO
# ============================================

## Refrescos pendientes de agrupar ("inventory", "equipment", "stats").
## No es estado de pantalla: solo evita emitir varias veces lo mismo.
var _dirty: Dictionary = {}

## Ítem cuyo EQUIPAR pasa por el puente de ítems, que también emite
## item_use_success. Se ignora ese éxito: el mensaje lo da el evento de equipo.
var _equip_request_item_id: String = ""

## El puente de ítems convierte equip_failed en item_use_failed("Equipment
## operation failed") en el mismo frame. Se recuerda para no dar dos mensajes.
var _last_equip_failed_item_id: String = ""
var _last_equip_failed_frame: int = -1

## Todas las pilas, ordenadas. bag_entries es un filtro de esta lista (mismos objetos).
var _all_entries: Array[BagEntry] = []

## Categorías cargadas del JSON: {id, name_key, priority, tags}, en orden de pestaña
var _category_defs: Array[Dictionary] = []
var _all_name_key: String = "INVENTORY_CATEGORY_ALL"


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
	Equipment.equip_failed.connect(_on_equip_failed)
	_load_categories()


# ============================================
# INTENCIONES (llamadas desde la View)
# ============================================

func open(p_entity_id: String = "player") -> void:
	entity_id = p_entity_id
	selected_item_id = ""
	detail = null
	feedback_message = ""
	feedback_is_error = false
	active_category = CATEGORY_ALL
	_equip_request_item_id = ""
	_last_equip_failed_item_id = ""
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


## Cambiar de pestaña. Ignora ids que no existen (o la pestaña ya activa).
func select_category(category_id: String) -> void:
	if state == InventoryState.HIDDEN:
		return
	if category_id == active_category or not _has_category(category_id):
		return
	active_category = category_id
	_apply_category_filter()
	changed.emit("categories")


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
		_set_feedback(tr("INVENTORY_ERROR_SLOT_MISMATCH") % [item_name, slot_display_name(slot_id)], true)
		return

	Equipment.equip_item(entity_id, item_id)


# ============================================
# CONSULTAS PARA LA VIEW
# ============================================

## ¿Hay más pilas que huecos?
func is_over_capacity() -> bool:
	return used_slots > capacity


## Nombre visible de un slot de equipo; si no hay clave, el id capitalizado
func slot_display_name(slot_id: String) -> String:
	var key: String = "INVENTORY_SLOT_" + slot_id.to_upper()
	var text: String = tr(key)
	return text if text != key else slot_id.capitalize()


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


func _on_item_use_failed(ent_id: String, item_id: String, reason: String) -> void:
	if ent_id != entity_id or state == InventoryState.HIDDEN:
		return
	_equip_request_item_id = ""
	# Si es el eco de un equip_failed del mismo frame, ya se avisó
	if item_id == _last_equip_failed_item_id and Engine.get_process_frames() == _last_equip_failed_frame:
		return
	# El motivo llega como texto libre del sistema que falla (pendiente: códigos en el core)
	_set_feedback(tr("INVENTORY_ERROR_PREFIX") % reason, true)


## Equipment.equip_failed: el motivo es texto libre en inglés (pendiente: códigos
## en el core), así que la View recibe un mensaje genérico localizado.
func _on_equip_failed(ent_id: String, item_id: String, reason: String) -> void:
	if ent_id != entity_id or state == InventoryState.HIDDEN:
		return
	print("[InventoryViewModel] equip_failed '%s': %s" % [item_id, reason])
	_equip_request_item_id = ""
	_last_equip_failed_item_id = item_id
	_last_equip_failed_frame = Engine.get_process_frames()
	_set_feedback(tr("INVENTORY_ERROR_EQUIP_FAILED") % _item_name(item_id), true)


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

	# Si cambió la mochila o el equipo, el detalle (cantidad, equipado,
	# comparación) puede estar obsoleto; si el ítem ya no existe, se limpia la selección.
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
	_all_entries.clear()
	total_weight = 0.0

	var inventory: Dictionary = Inventory.get_inventory(entity_id)
	capacity = _compute_capacity(inventory.size())

	var index: int = 0
	for item_id in inventory.keys():
		var instance: ItemInstance = inventory[item_id]
		if instance == null:
			continue
		bag_items.append(instance)

		if instance.definition != null:
			var entry := BagEntry.new()
			entry.instance = instance
			entry.category_id = _category_of(instance.definition)
			entry.is_equipped = Equipment.is_item_equipped(entity_id, instance.definition.id)
			entry.is_overflow = index >= capacity
			entry.sort_rank = _category_rank(entry.category_id)
			entry.sort_name = tr(instance.definition.name_key)
			_all_entries.append(entry)
			total_weight += instance.definition.get_total_weight(instance.quantity)
		index += 1

	used_slots = bag_items.size()
	_all_entries.sort_custom(_entry_less)
	_rebuild_categories()
	_apply_category_filter()


func _rebuild_equipment() -> void:
	equipped_items.clear()
	equipment_slot_ids = Equipment.get_available_slots(entity_id)

	var all_equipment: Dictionary = Equipment.get_all_equipment(entity_id)
	for slot_id in all_equipment.keys():
		var item_id: String = all_equipment[slot_id]
		if item_id.is_empty():
			continue
		var item_def: ItemDefinition = Items.get_item(item_id)
		if item_def:
			equipped_items[slot_id] = item_def

	# Las marcas de «equipado» de la mochila dependen del equipo
	for entry in _all_entries:
		entry.is_equipped = Equipment.is_item_equipped(entity_id, entry.instance.definition.id)

	_rebuild_equipment_bonuses()


## Suma los modificadores "add" de cada ítem equipado (mismo criterio que la
## comparación del detalle: "mul" y "override" no se suman).
func _rebuild_equipment_bonuses() -> void:
	equipment_bonuses.clear()
	var totals: Dictionary = {}
	for slot_id in equipped_items.keys():
		var item_def: ItemDefinition = equipped_items[slot_id]
		var sums: Dictionary = _sum_add_modifiers(item_def)
		for target in sums.keys():
			totals[target] = float(totals.get(target, 0.0)) + float(sums[target])

	for target in totals.keys():
		var value: float = float(totals[target])
		if is_zero_approx(value):
			continue
		var line := ModLine.new()
		line.label = _modifier_label(str(target))
		line.value = value
		line.text = _format_signed(value)
		equipment_bonuses.append(line)
	equipment_bonuses.sort_custom(func(a: ModLine, b: ModLine) -> bool:
		return a.label.naturalnocasecmp_to(b.label) < 0)


func _rebuild_stats() -> void:
	stat_health = Resources.get_resource_amount(entity_id, "health")
	stat_stamina = Resources.get_resource_amount(entity_id, "stamina")
	stat_gold = Resources.get_resource_amount(entity_id, "gold")
	stat_strength = Characters.get_base_attribute(entity_id, "strength")
	stat_dexterity = Characters.get_base_attribute(entity_id, "dexterity")
	stat_constitution = Characters.get_base_attribute(entity_id, "constitution")

	stat_entries.clear()
	for raw_def in STAT_DEFS:
		var def: Dictionary = raw_def
		if not bool(def["enabled"]):
			continue
		var entry := StatEntry.new()
		entry.id = str(def["id"])
		entry.kind = str(def["kind"])
		entry.label = tr(str(def["label_key"]))
		var key: String = str(def["key"])
		if entry.kind == "resource":
			entry.value = int(Resources.get_resource_amount(entity_id, key))
		else:
			entry.value = int(Characters.get_base_attribute(entity_id, key))
		stat_entries.append(entry)


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
		data.category_id = _category_of(item_def)
		data.category_name = _category_name(data.category_id)
		data.modifier_lines = _build_modifier_lines(item_def)
		_fill_comparison(data)
		detail = data

	if state != InventoryState.HIDDEN:
		state = InventoryState.ITEM_SELECTED if detail != null else InventoryState.BROWSING


# ============================================
# CAPACIDAD
# ============================================

## Hoy: la base de la definición del personaje. Cuando existan ampliaciones
## (cuenta premium, monedas, objetos mágicos) es el ÚNICO punto que cambia
## (o se sustituye por una API del core). La View solo lee `capacity`.
func _compute_capacity(used_count: int) -> int:
	var definition: CharacterDefinition = Characters.get_character_definition(entity_id)
	if definition == null:
		push_warning("[InventoryViewModel] Sin definición para '%s': no se conoce la capacidad" % entity_id)
		return used_count
	return definition.inventory_slots


# ============================================
# CATEGORÍAS Y ORDEN
# ============================================

func _load_categories() -> void:
	_category_defs.clear()
	_all_name_key = "INVENTORY_CATEGORY_ALL"

	if not FileAccess.file_exists(CATEGORIES_PATH):
		push_warning("[InventoryViewModel] Falta %s: la mochila solo tendrá la pestaña 'Todo'" % CATEGORIES_PATH)
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATEGORIES_PATH))
	if not parsed is Dictionary:
		push_warning("[InventoryViewModel] %s no es un JSON válido: solo habrá la pestaña 'Todo'" % CATEGORIES_PATH)
		return

	var root: Dictionary = parsed
	var version: int = int(root.get("version", 0))
	if version != CATEGORIES_VERSION:
		push_warning("[InventoryViewModel] %s: versión %d, se esperaba %d" % [CATEGORIES_PATH, version, CATEGORIES_VERSION])

	_all_name_key = str(root.get("all_name_key", _all_name_key))

	var raw_categories: Array = root.get("categories", []) as Array
	for raw in raw_categories:
		if not raw is Dictionary:
			continue
		var raw_dict: Dictionary = raw
		var category_id: String = str(raw_dict.get("id", ""))
		if category_id.is_empty() or category_id == CATEGORY_ALL:
			push_warning("[InventoryViewModel] Categoría con id vacío o reservado ('%s'): ignorada" % category_id)
			continue
		var tags: Array[String] = []
		for tag in (raw_dict.get("tags", []) as Array):
			tags.append(str(tag))
		_category_defs.append({
			"id": category_id,
			"name_key": str(raw_dict.get("name_key", "")),
			"priority": int(raw_dict.get("priority", 1000)),
			"tags": tags,
		})


## Categoría de un ítem: entre las que comparten algún tag con él, la de menor
## prioridad. "" si ninguna (el ítem solo se ve en «Todo»).
func _category_of(item_def: ItemDefinition) -> String:
	var best_id: String = ""
	var best_priority: int = 1 << 30
	for category in _category_defs:
		var priority: int = int(category["priority"])
		if priority >= best_priority:
			continue
		for tag in (category["tags"] as Array):
			if item_def.has_tag(str(tag)):
				best_id = str(category["id"])
				best_priority = priority
				break
	return best_id


## Posición de la categoría en el orden de pestañas (las sin categoría, al final)
func _category_rank(category_id: String) -> int:
	for i in range(_category_defs.size()):
		if str(_category_defs[i]["id"]) == category_id:
			return i
	return _category_defs.size()


func _category_name(category_id: String) -> String:
	if category_id.is_empty():
		return ""
	for category in _category_defs:
		if str(category["id"]) == category_id:
			return tr(str(category["name_key"]))
	return ""


func _has_category(category_id: String) -> bool:
	if category_id == CATEGORY_ALL:
		return true
	for category in _category_defs:
		if str(category["id"]) == category_id:
			return true
	return false


func _rebuild_categories() -> void:
	categories.clear()

	var all_tab := CategoryData.new()
	all_tab.id = CATEGORY_ALL
	all_tab.name = tr(_all_name_key)
	all_tab.count = _all_entries.size()
	categories.append(all_tab)

	for category in _category_defs:
		var tab := CategoryData.new()
		tab.id = str(category["id"])
		tab.name = tr(str(category["name_key"]))
		for entry in _all_entries:
			if entry.category_id == tab.id:
				tab.count += 1
		categories.append(tab)


func _apply_category_filter() -> void:
	bag_entries.clear()
	for entry in _all_entries:
		if active_category == CATEGORY_ALL or entry.category_id == active_category:
			bag_entries.append(entry)


## Orden estable: pestaña, nombre traducido (sin distinguir mayúsculas), id
func _entry_less(a: BagEntry, b: BagEntry) -> bool:
	if a.sort_rank != b.sort_rank:
		return a.sort_rank < b.sort_rank
	var by_name: int = a.sort_name.naturalnocasecmp_to(b.sort_name)
	if by_name != 0:
		return by_name < 0
	return a.instance.definition.id < b.instance.definition.id


# ============================================
# DETALLE: MODIFICADORES Y COMPARACIÓN
# ============================================

func _build_modifier_lines(item_def: ItemDefinition) -> Array[ModLine]:
	var lines: Array[ModLine] = []
	for mod in item_def.get_modifiers_for_condition("equipped"):
		var line := ModLine.new()
		line.label = _modifier_label(mod.target)
		line.text = _format_modifier(mod)
		line.value = mod.value
		lines.append(line)
	return lines


## Compara con lo equipado en el slot que le correspondería. Solo cuenta la
## operación "add": restar un "mul" o un "override" no tiene sentido (hoy no
## hay ítems con esas operaciones).
func _fill_comparison(data: DetailData) -> void:
	var item_def: ItemDefinition = data.item_def
	if item_def.item_type != "EQUIPMENT" or data.is_equipped:
		return

	var slot_id: String = _slot_for_item(item_def)
	if slot_id.is_empty():
		return

	data.has_comparison = true
	data.compare_slot_id = slot_id

	var candidate: Dictionary = _sum_add_modifiers(item_def)
	var current: Dictionary = {}

	var equipped_id: String = Equipment.get_equipped_item(entity_id, slot_id)
	var equipped_def: ItemDefinition = Items.get_item(equipped_id) if not equipped_id.is_empty() else null
	if equipped_def == null:
		data.compare_slot_free = true
	else:
		data.compare_against_name = tr(equipped_def.name_key)
		current = _sum_add_modifiers(equipped_def)

	var targets: Array[String] = []
	for target in candidate.keys():
		targets.append(str(target))
	for target in current.keys():
		if not targets.has(str(target)):
			targets.append(str(target))

	for target in targets:
		var delta: float = float(candidate.get(target, 0.0)) - float(current.get(target, 0.0))
		if is_zero_approx(delta):
			continue
		var line := CompareLine.new()
		line.label = _modifier_label(target)
		line.delta = delta
		line.text = _format_signed(delta)
		data.compare_lines.append(line)


## Slot donde el sistema de equipo colocaría el ítem: el primer tag del ítem que
## el propio Equipment valida (mismo criterio que EquipmentManager._determine_slot,
## sin duplicar su regla).
func _slot_for_item(item_def: ItemDefinition) -> String:
	for tag in item_def.tags:
		if Equipment.can_equip_in_slot(entity_id, item_def.id, tag):
			return tag
	return ""


## target → suma de valores de los modificadores "add" aplicados al equipar
func _sum_add_modifiers(item_def: ItemDefinition) -> Dictionary:
	var sums: Dictionary = {}
	for mod in item_def.get_modifiers_for_condition("equipped"):
		if mod.operation != "add":
			continue
		sums[mod.target] = float(sums.get(mod.target, 0.0)) + mod.value
	return sums


## "attribute.armor_rating" → INVENTORY_MOD_ARMOR_RATING; sin clave, "Armor Rating"
func _modifier_label(target: String) -> String:
	var segment: String = target.get_slice(".", target.get_slice_count(".") - 1)
	var key: String = "INVENTORY_MOD_" + segment.to_upper()
	var text: String = tr(key)
	return text if text != key else segment.capitalize()


func _format_modifier(mod: ModifierDefinition) -> String:
	match mod.operation:
		"add":
			return _format_signed(mod.value)
		"mul":
			return "x%.2f" % mod.value
		"override":
			return "= %s" % _format_number(mod.value)
	return _format_number(mod.value)


func _format_signed(value: float) -> String:
	var sign_text: String = "+" if value >= 0.0 else "-"
	return sign_text + _format_number(absf(value))


func _format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%d" % int(roundf(value))
	return "%.1f" % value


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
