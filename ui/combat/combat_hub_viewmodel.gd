class_name CombatHudViewModel
extends Node

## CombatHudViewModel - Lógica y estado del HUD de combate
##
## Responsabilidades:
##   - Leer el LoadoutState del jugador al iniciar el combate
##   - Exponer los slots como ActionSlotData con estado en tiempo real
##   - Exponer recursos vitales del jugador
##
## IA-0b: el HUD ya NO lleva su propio contador de cooldowns ni lee la estamina de
## CharacterState (que nadie actualiza). Fuente única de verdad:
##   - cooldowns   → Skills.get_cooldown_remaining() (en rondas durante el combate)
##   - disponible  → Skills.can_use() (cooldown + coste, el mismo criterio que usa
##                   PlayerCombatController)
##   - vida/estamina → ResourceSystem (Resources)
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


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	EventBus.combat_started.connect(_on_combat_started)
	EventBus.resource_changed.connect(_on_resource_changed)
	Skills.cooldown_started.connect(_on_cooldown_started)
	Skills.combat_cooldowns_ticked.connect(_on_cooldowns_ticked)


func _exit_tree() -> void:
	if EventBus.combat_started.is_connected(_on_combat_started):
		EventBus.combat_started.disconnect(_on_combat_started)
	if EventBus.resource_changed.is_connected(_on_resource_changed):
		EventBus.resource_changed.disconnect(_on_resource_changed)
	if Skills.cooldown_started.is_connected(_on_cooldown_started):
		Skills.cooldown_started.disconnect(_on_cooldown_started)
	if Skills.combat_cooldowns_ticked.is_connected(_on_cooldowns_ticked):
		Skills.combat_cooldowns_ticked.disconnect(_on_cooldowns_ticked)


# ============================================
# CALLBACKS
# ============================================

## combat_started: (participants: Array)
## SkillSystem ya puso los cooldowns a 0 (se conectó antes que este nodo).
func _on_combat_started(_participants: Array) -> void:
	_refresh_slots()
	_refresh_resources()
	changed.emit("opened")


## Skills.cooldown_started: (entity_id, skill_id, duration)
## Se emite tras iniciar el cooldown, así que el slot ya refleja el valor real.
func _on_cooldown_started(entity_id: String, _skill_id: String, _duration: float) -> void:
	if entity_id != PLAYER_ID:
		return
	_refresh_slots()
	changed.emit("slots")


## Skills.combat_cooldowns_ticked: SkillSystem acaba de descontar una ronda.
## Se escucha esta señal y no round_started para no depender del orden de conexión.
func _on_cooldowns_ticked() -> void:
	_refresh_slots()
	changed.emit("slots")


## EventBus.resource_changed: (entity_id, resource_id, current, max)
## ResourceSystem reenvía aquí cada cambio. Gastar o recuperar estamina cambia la
## disponibilidad de los slots, no solo la barra.
func _on_resource_changed(entity_id: String, resource_id: String, _current: float, _max: float) -> void:
	if entity_id != PLAYER_ID:
		return
	_refresh_resources()
	changed.emit("resources")
	if resource_id == "stamina":
		_refresh_slots()
		changed.emit("slots")


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

		# Skill en el loadout pero sin instancia para el jugador (p. ej. no
		# registrada): se muestra no disponible, sin avisos en cada refresco.
		if not Skills.has_skill(PLAYER_ID, skill_id):
			data.is_available = false
			action_slots.append(data)
			continue

		# En combate el valor está en rondas (entero guardado en float).
		data.cooldown_remaining = ceili(Skills.get_cooldown_remaining(PLAYER_ID, skill_id))
		# Mismo criterio que PlayerCombatController: cooldown y coste, vía Skills.
		data.is_available = Skills.can_use(PLAYER_ID, skill_id)

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


## Vida y estamina salen de ResourceSystem: el máximo mostrado es el tope real
## (max_effective) con el que se recorta el valor actual.
func _refresh_resources() -> void:
	if not Resources.has_entity(PLAYER_ID):
		return

	var health: ResourceState = Resources.get_resource_state(PLAYER_ID, "health")
	if health:
		health_current = int(health.current)
		health_max     = int(health.max_effective)

	var stamina: ResourceState = Resources.get_resource_state(PLAYER_ID, "stamina")
	if stamina:
		stamina_current = int(stamina.current)
		stamina_max     = int(stamina.max_effective)


# ============================================
# UTILIDADES
# ============================================
# (IA-0b: _find_slot_for_skill() y el contador _cooldowns se eliminaron; ya no
#  hay nada que mapear de skill a slot porque los cooldowns viven en Skills.)
