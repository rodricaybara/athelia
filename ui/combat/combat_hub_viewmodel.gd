class_name CombatHudViewModel
extends Node

## CombatHudViewModel - Lógica y estado del HUD de combate
##
## Responsabilidades:
##   - Leer el LoadoutState del jugador al iniciar el combate
##   - Exponer los slots como ActionSlotData con estado en tiempo real
##   - Trackear cooldowns por rondas
##   - Exponer recursos vitales del jugador
##
## Solo lectura — no modifica LoadoutState ni ningún sistema.
##
## Razones de changed():
##   "opened"    → renderizar todo
##   "slots"     → actualizar estado de slots (cooldowns, disponibilidad)
##   "resources" → actualizar barras de vida/stamina

# ============================================
# SEÑAL
# ============================================

signal changed(reason: String)


# ============================================
# CONSTANTES — keybindings por slot
# ============================================

const SLOT_KEYBIND_LABEL: Dictionary = {
	"attack_1":    "1",
	"attack_2":    "2",
	"attack_3":    "3",
	"dodge":       "Q",
	"defense":     "E",
	"escape":      "R",
	"consumable_1": "F",
	"consumable_2": "G",
}


# ============================================
# DATA CLASS
# ============================================

class ActionSlotData:
	var slot_id: String = ""
	var display_name: String = ""
	var stamina_cost: int = 0
	var cooldown_remaining: int = 0   ## rondas restantes, 0 = disponible
	var is_available: bool = true     ## false si cooldown > 0 o stamina insuficiente
	var keybind_label: String = ""
	var is_empty: bool = true
	var slot_type: String = ""        ## "skill" o "consumable"


# ============================================
# DATOS PÚBLICOS
# ============================================

var action_slots: Array[ActionSlotData] = []

var health_current: int = 0
var health_max: int = 0
var stamina_current: int = 0
var stamina_max: int = 0


# ============================================
# ESTADO INTERNO
# ============================================

const PLAYER_ID: String = "player"

## Cooldowns activos: { slot_id: rondas_restantes }
var _cooldowns: Dictionary = {}


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	EventBus.combat_started.connect(_on_combat_started)
	EventBus.round_started.connect(_on_round_started)
	EventBus.skill_used.connect(_on_skill_used)
	EventBus.resource_changed.connect(_on_resource_changed)


func _exit_tree() -> void:
	if EventBus.combat_started.is_connected(_on_combat_started):
		EventBus.combat_started.disconnect(_on_combat_started)
	if EventBus.round_started.is_connected(_on_round_started):
		EventBus.round_started.disconnect(_on_round_started)
	if EventBus.skill_used.is_connected(_on_skill_used):
		EventBus.skill_used.disconnect(_on_skill_used)
	if EventBus.resource_changed.is_connected(_on_resource_changed):
		EventBus.resource_changed.disconnect(_on_resource_changed)


# ============================================
# CALLBACKS DEL EVENTBUS
# ============================================

## combat_started: (participants: Array)
func _on_combat_started(_participants: Array) -> void:
	_cooldowns.clear()
	_refresh_slots()
	_refresh_resources()
	changed.emit("opened")


## round_started: (round_number: int)
## Cada ronda reduce todos los cooldowns activos en 1.
func _on_round_started(_round_number: int) -> void:
	var dirty: bool = false
	for slot_id in _cooldowns.keys():
		if _cooldowns[slot_id] > 0:
			_cooldowns[slot_id] -= 1
			dirty = true
		if _cooldowns[slot_id] <= 0:
			_cooldowns.erase(slot_id)

	if dirty:
		_refresh_slots()
		changed.emit("slots")


## skill_used: (entity_id, skill_id)
## Cuando el jugador usa una skill, iniciamos su cooldown en el slot correspondiente.
func _on_skill_used(entity_id: String, skill_id: String) -> void:
	if entity_id != PLAYER_ID:
		return

	# Buscar en qué slot está asignada esta skill
	var slot_id: String = _find_slot_for_skill(skill_id)
	if slot_id == "":
		return

	# Leer cooldown base de la definición (en rondas — base_cooldown se interpreta como int)
	var def: SkillDefinition = Skills.get_skill_definition(skill_id)
	if def == null:
		return

	var cooldown_rounds: int = int(def.base_cooldown)
	if cooldown_rounds > 0:
		_cooldowns[slot_id] = cooldown_rounds

	_refresh_slots()
	changed.emit("slots")


## resource_changed: (entity_id, resource_id, old_value, new_value)
func _on_resource_changed(entity_id: String, _resource_id: String, _old: float, _new: float) -> void:
	if entity_id != PLAYER_ID:
		return
	_refresh_resources()
	changed.emit("resources")


# ============================================
# REFRESCO INTERNO
# ============================================

func _refresh_slots() -> void:
	action_slots.clear()

	var state: CharacterState = Characters.get_character_state(PLAYER_ID)
	if state == null:
		return

	var loadout: LoadoutState = state.loadout

	# Slots de skill
	for slot_id in LoadoutState.SKILL_SLOTS:
		var data := ActionSlotData.new()
		data.slot_id      = slot_id
		data.slot_type    = "skill"
		data.keybind_label = SLOT_KEYBIND_LABEL.get(slot_id, "")
		data.cooldown_remaining = _cooldowns.get(slot_id, 0)

		var skill_id: String = loadout.get_skill(slot_id)
		if skill_id == "":
			data.is_empty    = true
			data.is_available = false
			action_slots.append(data)
			continue

		var def: SkillDefinition = Skills.get_skill_definition(skill_id)
		if def == null:
			data.is_empty    = true
			data.is_available = false
			action_slots.append(data)
			continue

		data.is_empty    = false
		data.display_name = tr(def.name_key)
		data.stamina_cost = int(def.get_cost("stamina"))

		# Disponible si: sin cooldown Y stamina suficiente
		var current_stamina: int = int(state.get_resource("stamina"))
		data.is_available = (data.cooldown_remaining == 0) and (current_stamina >= data.stamina_cost)

		action_slots.append(data)

	# Slots de consumible
	for slot_id in LoadoutState.CONSUMABLE_SLOTS:
		var data := ActionSlotData.new()
		data.slot_id       = slot_id
		data.slot_type     = "consumable"
		data.keybind_label  = SLOT_KEYBIND_LABEL.get(slot_id, "")
		data.cooldown_remaining = 0

		var item_id: String = loadout.get_consumable(slot_id)
		if item_id == "":
			data.is_empty    = true
			data.is_available = false
			action_slots.append(data)
			continue

		var def: ItemDefinition = Items.get_item(item_id)
		if def == null:
			data.is_empty    = true
			data.is_available = false
			action_slots.append(data)
			continue

		var qty: int = Inventory.get_item_quantity(PLAYER_ID, item_id)
		data.is_empty     = false
		data.display_name  = tr(def.name_key)
		data.is_available  = qty > 0

		action_slots.append(data)


func _refresh_resources() -> void:
	var state: CharacterState = Characters.get_character_state(PLAYER_ID)
	if state == null:
		return

	health_current  = int(state.get_resource("health"))
	health_max      = int(AttributeResolver.resolve(PLAYER_ID, "health_max"))
	stamina_current = int(state.get_resource("stamina"))
	stamina_max     = int(AttributeResolver.resolve(PLAYER_ID, "stamina_max"))


# ============================================
# UTILIDADES
# ============================================

func _find_slot_for_skill(skill_id: String) -> String:
	var state: CharacterState = Characters.get_character_state(PLAYER_ID)
	if state == null:
		return ""
	var loadout: LoadoutState = state.loadout
	for slot_id in LoadoutState.SKILL_SLOTS:
		if loadout.get_skill(slot_id) == skill_id:
			return slot_id
	return ""
