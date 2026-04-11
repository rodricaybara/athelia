class_name PlayerMenuViewModel
extends Node

## PlayerMenuViewModel - Lógica y estado del menú de personaje
##
## Responsabilidades:
##   - Exponer el estado del personaje: atributos derivados, buffs, recursos, oro
##   - Reaccionar a cambios del EventBus mientras el menú está abierto
##   - Exponer intenciones de navegación a subpantallas
##
## Panel de solo lectura — no escribe ningún estado del personaje.
##
## Razones de changed():
##   "opened"         → renderizar todo
##   "attributes"     → rerenderizar sección de atributos derivados
##   "buffs"          → rerenderizar sección de buffs activos
##   "resources"      → rerenderizar sección de recursos y oro
##   "open_loadout"   → abrir subpantalla loadout
##   "open_inventory" → abrir subpantalla inventario
##   "open_skill_tree"→ abrir subpantalla árbol de skills
##   "closed"         → ocultar panel

# ============================================
# SEÑAL
# ============================================

signal changed(reason: String)


# ============================================
# ESTADO INTERNO
# ============================================

var _character_id: String = ""


# ============================================
# DATOS PÚBLICOS (read-only para la View)
# ============================================

## Atributos derivados calculados. { attr_id: String -> value: float }
## Claves: "health_max", "stamina_max", "initiative", "melee_damage", etc.
## Solo contiene los atributos que existen en las fórmulas del JSON.
var attributes: Dictionary = {}

## Buffs activos. Array de BuffData.
var active_buffs: Array[BuffData] = []

## Recursos vitales
var health_current: int = 0
var health_max: int = 0
var stamina_current: int = 0
var stamina_max: int = 0
var gold: int = 0

## Nombre de display del personaje
var character_name: String = ""


# ============================================
# DATA CLASS
# ============================================

class BuffData:
	var buff_id: String = ""
	var time_left: float = 0.0
	var duration: float = 0.0

	static func from_state(state_dict: Dictionary) -> BuffData:
		var d := BuffData.new()
		d.buff_id    = state_dict.get("id", "")
		d.time_left  = state_dict.get("time_left", 0.0)
		d.duration   = state_dict.get("duration", 0.0)
		return d


# ============================================
# ATRIBUTOS DERIVADOS A MOSTRAR
# ============================================

## Lista de atributos derivados que el menú muestra.
## Deben coincidir con claves definidas en derived_attributes.json.
const DISPLAYED_ATTRIBUTES: Array[String] = [
	"health_max",
	"stamina_max",
	"initiative",
	"melee_damage",
	"armor_rating",
]


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	pass


# ============================================
# API PÚBLICA
# ============================================

func open(character_id: String) -> void:
	_character_id = character_id

	var state: CharacterState = Characters.get_character_state(character_id)
	if state == null:
		push_error("[PlayerMenuViewModel] Personaje no encontrado: %s" % character_id)
		return

	character_name = state.definition.id

	_disconnect_events()
	_connect_events()
	_refresh_all()
	changed.emit("opened")


func request_close() -> void:
	_disconnect_events()
	_character_id = ""
	changed.emit("closed")


# ============================================
# INTENCIONES DE NAVEGACIÓN
# — La View las llama, SceneOrchestrator las ejecuta
# — El ViewModel solo emite el evento correspondiente
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
	EventBus.buff_applied.connect(_on_buff_applied)
	EventBus.temporary_state_removed.connect(_on_buff_removed)
	EventBus.resource_changed.connect(_on_resource_changed)


func _disconnect_events() -> void:
	if EventBus.item_equipped.is_connected(_on_equipment_changed):
		EventBus.item_equipped.disconnect(_on_equipment_changed)
	if EventBus.item_unequipped.is_connected(_on_equipment_changed):
		EventBus.item_unequipped.disconnect(_on_equipment_changed)
	if EventBus.buff_applied.is_connected(_on_buff_applied):
		EventBus.buff_applied.disconnect(_on_buff_applied)
	if EventBus.temporary_state_removed.is_connected(_on_buff_removed):
		EventBus.temporary_state_removed.disconnect(_on_buff_removed)
	if EventBus.resource_changed.is_connected(_on_resource_changed):
		EventBus.resource_changed.disconnect(_on_resource_changed)


## item_equipped / item_unequipped: (entity_id, item_id, slot)
func _on_equipment_changed(entity_id: String, _item_id: String, _slot: String) -> void:
	if entity_id != _character_id:
		return
	_refresh_attributes()
	changed.emit("attributes")


## buff_applied: (character_id, buff_type, duration)
func _on_buff_applied(character_id: String, _buff_type: String, _duration: float) -> void:
	if character_id != _character_id:
		return
	_refresh_buffs()
	changed.emit("buffs")


## temporary_state_removed: (entity_id, state_id)
func _on_buff_removed(entity_id: String, _state_id: String) -> void:
	if entity_id != _character_id:
		return
	_refresh_buffs()
	changed.emit("buffs")


## resource_changed: (entity_id, resource_id, old_value, new_value)
func _on_resource_changed(entity_id: String, _resource_id: String, _old_value: float, _new_value: float) -> void:
	if entity_id != _character_id:
		return
	_refresh_resources()
	changed.emit("resources")


# ============================================
# REFRESCO INTERNO
# ============================================

func _refresh_all() -> void:
	_refresh_attributes()
	_refresh_buffs()
	_refresh_resources()


func _refresh_attributes() -> void:
	attributes.clear()
	for attr_id in DISPLAYED_ATTRIBUTES:
		attributes[attr_id] = AttributeResolver.resolve(_character_id, attr_id)


func _refresh_buffs() -> void:
	active_buffs.clear()
	var state: CharacterState = Characters.get_character_state(_character_id)
	if state == null:
		return
	for state_dict in state.active_states:
		active_buffs.append(BuffData.from_state(state_dict))


func _refresh_resources() -> void:
	var state: CharacterState = Characters.get_character_state(_character_id)
	if state == null:
		return

	health_current  = int(state.get_resource("health"))
	health_max      = int(AttributeResolver.resolve(_character_id, "health_max"))
	stamina_current = int(state.get_resource("stamina"))
	stamina_max     = int(AttributeResolver.resolve(_character_id, "stamina_max"))
	gold            = int(state.get_resource("gold"))
