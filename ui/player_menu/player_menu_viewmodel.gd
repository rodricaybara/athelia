class_name PlayerMenuViewModel
extends Node

## PlayerMenuViewModel - Lógica y estado del menú de personaje (Spike 22)
##
## Responsabilidades:
##   - Exponer el estado del personaje: atributos, buffs, recursos, oro, navegación
##   - Reaccionar a cambios del EventBus mientras el menú está abierto
##   - Exponer intenciones de navegación a subpantallas
##
## Panel de solo lectura — no escribe ningún estado del personaje.
## Entrega CLAVES de localización; la View traduce con tr().
##
## Razones de changed():
##   "opened"          → renderizar todo
##   "attributes"      → atributos (derivados y base)
##   "resources"       → recursos y oro (en sitio; agrupado una vez por frame)
##   "buffs"           → la lista de buffs cambió (alta o baja): reconstruir filas
##   "buff_times"      → solo cambió el tiempo restante: actualizar en sitio
##   "open_loadout"    → abrir subpantalla loadout
##   "open_inventory"  → abrir subpantalla inventario
##   "open_skill_tree" → abrir subpantalla árbol de habilidades
##   "closed"          → ocultar panel
##
## Buffs: no existen señales fiables al aplicarse o expirar un estado
## temporal (ModifierApplicator no emite ninguna), así que un Timer hijo
## relee Characters cada BUFF_REFRESH_SECONDS mientras el menú está abierto.
## No se toca el core.


# ============================================
# SEÑAL
# ============================================

signal changed(reason: String)


# ============================================
# CONSTANTES
# ============================================

const BUFF_REFRESH_SECONDS: float = 0.5

## Atributos derivados que el menú muestra (claves de derived_attributes.json).
const DISPLAYED_ATTRIBUTES: Array[String] = [
	"health_max",
	"stamina_max",
	"initiative",
	"melee_damage",
	"armor_rating",
]

## Atributos base, en orden fijo (ids de CharacterDefinition.base_attributes).
const BASE_ATTRIBUTES: Array[String] = [
	"strength",
	"dexterity",
	"constitution",
	"intelligence",
	"wisdom",
	"charisma",
]

## Botones de navegación en orden. "action" vacío = sin atajo de teclado.
const NAV_DEFINITIONS: Array = [
	{"id": "loadout", "label_key": "PLAYER_MENU_NAV_LOADOUT", "action": ""},
	{"id": "inventory", "label_key": "PLAYER_MENU_NAV_INVENTORY", "action": "open_inventory"},
	{"id": "skill_tree", "label_key": "PLAYER_MENU_NAV_SKILL_TREE", "action": "open_skill_tree"},
]


# ============================================
# DATA CLASSES
# ============================================

class AttrEntry:
	var label_key: String = ""
	## Valor que se muestra. En los atributos base es el efectivo (base + bonos).
	var value: int = 0
	## Solo atributos base: valor base y suma de modificadores "add" activos.
	var base_value: int = 0
	var bonus: int = 0


class NavEntry:
	var id: String = ""
	var label_key: String = ""
	var key_text: String = ""


class BuffData:
	var buff_id: String = ""
	var name_key: String = ""
	var time_left: float = 0.0
	var duration: float = 0.0

	static func from_state(state_dict: Dictionary) -> BuffData:
		var d := BuffData.new()
		d.buff_id = str(state_dict.get("id", ""))
		d.name_key = "PLAYER_MENU_BUFF_" + d.buff_id.to_upper()
		d.time_left = float(state_dict.get("time_left", 0.0))
		d.duration = float(state_dict.get("duration", 0.0))
		return d


# ============================================
# ESTADO INTERNO
# ============================================

var _character_id: String = ""
var _buff_timer: Timer = null
var _resources_flush_pending: bool = false


# ============================================
# DATOS PÚBLICOS (read-only para la View)
# ============================================

var derived_attributes: Array[AttrEntry] = []
var base_attributes: Array[AttrEntry] = []
var active_buffs: Array[BuffData] = []
var nav_entries: Array[NavEntry] = []

var health_current: int = 0
var health_max: int = 0
var stamina_current: int = 0
var stamina_max: int = 0
var gold: int = 0

## Nombre del personaje tal como lo escribió el jugador (NO es una clave: sin tr()).
var character_name: String = ""


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	_buff_timer = Timer.new()
	_buff_timer.wait_time = BUFF_REFRESH_SECONDS
	_buff_timer.one_shot = false
	_buff_timer.timeout.connect(_on_buff_timer_timeout)
	add_child(_buff_timer)


# ============================================
# API PÚBLICA
# ============================================

func open(character_id: String) -> void:
	_character_id = character_id

	var state: CharacterState = Characters.get_character_state(character_id)
	if state == null:
		push_error("[PlayerMenuViewModel] Personaje no encontrado: %s" % character_id)
		return

	character_name = Characters.get_character_name(character_id)

	_disconnect_events()
	_connect_events()
	_build_nav()
	_refresh_all()
	_buff_timer.start()
	changed.emit("opened")


func request_close() -> void:
	_disconnect_events()
	_buff_timer.stop()
	_character_id = ""
	changed.emit("closed")


# ============================================
# INTENCIONES DE NAVEGACIÓN
# — La View las llama y abre la subpantalla correspondiente
# — El ViewModel solo emite el evento
# ============================================

func request_open_loadout() -> void:
	changed.emit("open_loadout")


func request_open_inventory() -> void:
	changed.emit("open_inventory")


func request_open_skill_tree() -> void:
	changed.emit("open_skill_tree")


# ============================================
# EVENTOS DEL EVENTBUS
# ============================================

func _connect_events() -> void:
	EventBus.item_equipped.connect(_on_equipment_changed)
	EventBus.item_unequipped.connect(_on_equipment_changed)
	EventBus.resource_changed.connect(_on_resource_changed)


func _disconnect_events() -> void:
	if EventBus.item_equipped.is_connected(_on_equipment_changed):
		EventBus.item_equipped.disconnect(_on_equipment_changed)
	if EventBus.item_unequipped.is_connected(_on_equipment_changed):
		EventBus.item_unequipped.disconnect(_on_equipment_changed)
	if EventBus.resource_changed.is_connected(_on_resource_changed):
		EventBus.resource_changed.disconnect(_on_resource_changed)


## item_equipped / item_unequipped: (entity_id, item_id, slot)
## Equipar puede cambiar health_max / stamina_max: se refrescan también los recursos.
func _on_equipment_changed(entity_id: String, _item_id: String, _slot: String) -> void:
	if entity_id != _character_id:
		return
	_refresh_attributes()
	changed.emit("attributes")
	_mark_resources_dirty()


## resource_changed: (entity_id, resource_id, old_value, new_value)
func _on_resource_changed(entity_id: String, _resource_id: String, _old_value: float, _new_value: float) -> void:
	if entity_id != _character_id:
		return
	_mark_resources_dirty()


## La estamina se regenera continuamente: se agrupan los cambios y la View
## se actualiza como mucho una vez por frame.
func _mark_resources_dirty() -> void:
	if _resources_flush_pending:
		return
	_resources_flush_pending = true
	_flush_resources.call_deferred()


func _flush_resources() -> void:
	_resources_flush_pending = false
	if _character_id.is_empty():
		return
	_refresh_resources()
	changed.emit("resources")


# ============================================
# BUFFS (sondeo mientras el menú está abierto)
# ============================================

func _on_buff_timer_timeout() -> void:
	if _character_id.is_empty():
		return
	var fresh: Array[BuffData] = _read_buffs()
	if _buff_ids_differ(fresh):
		active_buffs = fresh
		# Un estado temporal puede traer modificadores: atributos y máximos cambian con él
		_refresh_attributes()
		changed.emit("attributes")
		_mark_resources_dirty()
		changed.emit("buffs")
	elif not fresh.is_empty():
		active_buffs = fresh
		changed.emit("buff_times")


func _buff_ids_differ(fresh: Array[BuffData]) -> bool:
	if fresh.size() != active_buffs.size():
		return true
	for i in fresh.size():
		if fresh[i].buff_id != active_buffs[i].buff_id:
			return true
	return false


func _read_buffs() -> Array[BuffData]:
	var result: Array[BuffData] = []
	var state: CharacterState = Characters.get_character_state(_character_id)
	if state == null:
		return result
	for state_dict in state.active_states:
		result.append(BuffData.from_state(state_dict))
	return result


# ============================================
# REFRESCO INTERNO
# ============================================

func _refresh_all() -> void:
	_refresh_attributes()
	active_buffs = _read_buffs()
	_refresh_resources()


func _refresh_attributes() -> void:
	derived_attributes.clear()
	for attr_id in DISPLAYED_ATTRIBUTES:
		var entry := AttrEntry.new()
		entry.label_key = "ATTR_" + attr_id.to_upper()
		entry.value = int(AttributeResolver.resolve(_character_id, attr_id))
		derived_attributes.append(entry)

	# Los atributos base no tienen fórmula: resolve() devolvería 0.0.
	# Valor efectivo = base + modificadores "add" activos con target
	# "attribute.<id>" (equipo y estados temporales). No se aplican "mul" ni
	# "override" (mismo criterio que el bloque «Bonos del equipo» del Inventario).
	base_attributes.clear()
	var base: Dictionary = Characters.get_all_base_attributes(_character_id)
	var modifiers: Array[ModifierDefinition] = Characters.get_active_modifiers(_character_id)
	for attr_id in BASE_ATTRIBUTES:
		if not base.has(attr_id):
			continue
		var entry := AttrEntry.new()
		entry.label_key = "ATTR_ABBR_" + attr_id.to_upper()
		entry.base_value = int(base[attr_id])
		entry.bonus = _additive_bonus(modifiers, attr_id)
		entry.value = entry.base_value + entry.bonus
		base_attributes.append(entry)


## Suma de los modificadores "add" que apuntan a "attribute.<attr_id>".
func _additive_bonus(modifiers: Array[ModifierDefinition], attr_id: String) -> int:
	var target: String = "attribute." + attr_id
	var total: float = 0.0
	for modifier in modifiers:
		if modifier.target == target and modifier.operation == "add":
			total += modifier.value
	return roundi(total)


func _refresh_resources() -> void:
	var state: CharacterState = Characters.get_character_state(_character_id)
	if state == null:
		return

	health_current  = int(Resources.get_resource_amount(_character_id, "health"))
	health_max      = int(AttributeResolver.resolve(_character_id, "health_max"))
	stamina_current = int(Resources.get_resource_amount(_character_id, "stamina"))
	stamina_max     = int(AttributeResolver.resolve(_character_id, "stamina_max"))
	gold            = int(Resources.get_resource_amount(_character_id, "gold"))


# ============================================
# NAVEGACIÓN: ATAJOS
# ============================================

func _build_nav() -> void:
	nav_entries.clear()
	for definition in NAV_DEFINITIONS:
		var entry := NavEntry.new()
		entry.id = definition["id"] as String
		entry.label_key = definition["label_key"] as String
		entry.key_text = _action_key_text(StringName(definition["action"] as String))
		nav_entries.append(entry)


## Texto de la primera tecla del InputMap para una acción ("" si no tiene).
## Las acciones del proyecto usan physical_keycode: se convierte a la
## disposición real del teclado para que la letra mostrada sea la correcta.
func _action_key_text(action: StringName) -> String:
	if action.is_empty() or not InputMap.has_action(action):
		return ""
	for input_event in InputMap.action_get_events(action):
		if input_event is InputEventKey:
			var key_event := input_event as InputEventKey
			var code: Key = key_event.physical_keycode
			if code != KEY_NONE:
				code = DisplayServer.keyboard_get_keycode_from_physical(code)
			else:
				code = key_event.keycode
			return OS.get_keycode_string(code)
	return ""
