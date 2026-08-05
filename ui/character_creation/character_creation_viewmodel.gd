class_name CharacterCreationViewModel
extends Node

## CharacterCreationViewModel — Lógica de creación de personaje.
## Hijo de CharacterCreationScreen (ver contrato MVVM en athelia_ui_architecture.md).
##
## Mecánica de atributos:
##   - 6 atributos reales del proyecto: strength, dexterity, constitution,
##     intelligence, wisdom, charisma (NO son los 7 de RuneQuest — no hay SIZ/POW).
##   - Roll-and-assign en dos pools separados:
##       PHYSICAL_ATTRIBUTES (STR/DEX/CHA) ← 3D6
##       RESILIENT_ATTRIBUTES (CON/INT/WIS) ← 2D6+6
##     La asignación es libre DENTRO de cada pool, no entre pools — así se
##     conserva el suelo alto (mínimo 8) en supervivencia/mente.
##   - 1 reroll permitido, sobre el set completo (ambos pools a la vez).
##
## Razones de changed(reason):
##   "opened"                    → estado inicial, pantalla de tirada
##   "rolled"                    → primera tirada realizada, mostrar pools
##   "rerolled"                  → reroll usado, refrescar pools + deshabilitar botón
##   "assigned"                  → un valor fue asignado/desasignado, refrescar slots
##   "error_incomplete_assignment" → intentó continuar sin asignar los 6 atributos
##   "naming"                    → panel de nombre
##   "error_empty_name"          → intentó continuar con nombre vacío
##   "error_name_too_long"       → nombre supera MAX_NAME_LENGTH
##   "summary"                   → panel de resumen final
##   "transitioning"             → deshabilitar botones, arranca la partida o vuelve al menú

signal changed(reason: String)

enum CreationState { ROLLING, ASSIGNING, NAMING, SUMMARY, TRANSITIONING }

const PHYSICAL_ATTRIBUTES: Array[String] = ["strength", "dexterity", "charisma"]
const RESILIENT_ATTRIBUTES: Array[String] = ["constitution", "intelligence", "wisdom"]
const ALL_ATTRIBUTES: Array[String] = [
	"strength", "dexterity", "constitution", "intelligence", "wisdom", "charisma"
]

const PLAYER_DEFINITION_ID: String = "player_new"
const MAX_NAME_LENGTH: int = 20

const STARTING_SKILL_VALUES: Dictionary = {
	"skill.attack.light": 25,
	"skill.combat.dodge": 20,
	"skill.exploration.perception": 25,
}

const STARTING_GOLD: float = 50.0

const STARTING_ITEMS: Dictionary = {
	"iron_sword": 1,
	"leather_armor": 1,
}

# ============================================
# ESTADO PÚBLICO — leído por la View
# ============================================

var state: CreationState = CreationState.ROLLING

## Valores tirados sin asignar todavía, por pool.
var physical_pool: Array[int] = []
var resilient_pool: Array[int] = []

## Asignaciones confirmadas: { "strength": 14, "constitution": 12, ... }
var assigned_attributes: Dictionary = {}

var reroll_used: bool = false
var character_name: String = ""

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


# ============================================
# CICLO DE VIDA
# ============================================

func open() -> void:
	state = CreationState.ROLLING
	physical_pool = []
	resilient_pool = []
	assigned_attributes = {}
	reroll_used = false
	character_name = ""
	changed.emit("opened")


# ============================================
# INTENCIONES — TIRADA Y ASIGNACIÓN
# ============================================

func request_roll_attributes() -> void:
	if state != CreationState.ROLLING:
		push_warning("[CharacterCreationViewModel] request_roll_attributes() fuera de ROLLING")
		return
	_roll_pools()
	state = CreationState.ASSIGNING
	changed.emit("rolled")


func request_reroll() -> void:
	if state != CreationState.ASSIGNING:
		push_warning("[CharacterCreationViewModel] request_reroll() fuera de ASSIGNING")
		return
	if reroll_used:
		push_warning("[CharacterCreationViewModel] Reroll ya utilizado")
		return
	reroll_used = true
	assigned_attributes = {}
	_roll_pools()
	changed.emit("rerolled")


func request_assign_value(value: int, attribute_id: String) -> void:
	if state != CreationState.ASSIGNING:
		return
	if assigned_attributes.has(attribute_id):
		push_warning("[CharacterCreationViewModel] Atributo ya asignado: %s" % attribute_id)
		return
	if not attribute_id in ALL_ATTRIBUTES:
		push_warning("[CharacterCreationViewModel] Atributo desconocido: %s" % attribute_id)
		return

	var pool: Array = physical_pool if attribute_id in PHYSICAL_ATTRIBUTES else resilient_pool
	var idx: int = pool.find(value)
	if idx == -1:
		push_warning("[CharacterCreationViewModel] Valor %d no disponible para %s" % [value, attribute_id])
		return

	pool.remove_at(idx)
	assigned_attributes[attribute_id] = value
	changed.emit("assigned")


func request_unassign_attribute(attribute_id: String) -> void:
	if state != CreationState.ASSIGNING:
		return
	if not assigned_attributes.has(attribute_id):
		return

	var value: int = assigned_attributes[attribute_id]
	assigned_attributes.erase(attribute_id)

	var pool: Array = physical_pool if attribute_id in PHYSICAL_ATTRIBUTES else resilient_pool
	pool.append(value)
	changed.emit("assigned")


func is_fully_assigned() -> bool:
	return assigned_attributes.size() == ALL_ATTRIBUTES.size()


func request_continue_to_naming() -> void:
	if state != CreationState.ASSIGNING:
		return
	if not is_fully_assigned():
		changed.emit("error_incomplete_assignment")
		return
	state = CreationState.NAMING
	changed.emit("naming")


# ============================================
# INTENCIONES — NOMBRE
# ============================================

func set_character_name(new_name: String) -> void:
	character_name = new_name.strip_edges()


func request_continue_to_summary() -> void:
	if state != CreationState.NAMING:
		return
	if character_name.is_empty():
		changed.emit("error_empty_name")
		return
	if character_name.length() > MAX_NAME_LENGTH:
		changed.emit("error_name_too_long")
		return
	state = CreationState.SUMMARY
	changed.emit("summary")


func request_back_to_naming() -> void:
	if state != CreationState.SUMMARY:
		return
	state = CreationState.NAMING
	changed.emit("naming")


# ============================================
# INTENCIONES — CONFIRMACIÓN / SALIDA
# ============================================

func request_back_to_menu() -> void:
	state = CreationState.TRANSITIONING
	changed.emit("transitioning")
	await get_tree().process_frame
	GameLoop.enter_main_menu()


func request_confirm_character() -> void:
	if state != CreationState.SUMMARY:
		return
	state = CreationState.TRANSITIONING
	changed.emit("transitioning")

	_create_player_entity()

	await get_tree().process_frame
	GameLoop.enter_exploration()


# ============================================
# INTERNOS — TIRADA DE DADOS
# ============================================

func _roll_pools() -> void:
	physical_pool = []
	for i in range(PHYSICAL_ATTRIBUTES.size()):
		physical_pool.append(_roll_3d6())

	resilient_pool = []
	for i in range(RESILIENT_ATTRIBUTES.size()):
		resilient_pool.append(_roll_2d6_plus_6())


func _roll_3d6() -> int:
	return _rng.randi_range(1, 6) + _rng.randi_range(1, 6) + _rng.randi_range(1, 6)


func _roll_2d6_plus_6() -> int:
	return _rng.randi_range(1, 6) + _rng.randi_range(1, 6) + 6


# ============================================
# INTERNOS — CREACIÓN DE LA ENTIDAD
# ============================================

func _create_player_entity() -> void:
	var chars: CharacterSystem = get_node("/root/Characters")
	var skills: Node = get_node_or_null("/root/Skills")
	var resources: ResourceSystem = get_node("/root/Resources")
	var equipment: Node = get_node_or_null("/root/Equipment")
	var inventory: Node = get_node_or_null("/root/Inventory")

	if chars.has_entity("player"):
		push_warning("[CharacterCreationViewModel] 'player' ya registrado — no se recrea")
	else:
		chars.register_entity("player", PLAYER_DEFINITION_ID)

		# IMPORTANTE: ResourceSystem debe registrar la entidad ANTES de tocar
		# atributos. set_base_attribute() dispara ModifierApplicator de forma
		# síncrona (_on_base_attribute_changed → recalculate_all →
		# _recalculate_resource_maxes), que necesita encontrar "player" ya
		# registrado en ResourceSystem para poder actualizar health_max/stamina_max.
		if resources:
			resources.register_entity("player")
		else:
			push_error("[CharacterCreationViewModel] ResourceSystem no encontrado — abortando atributos derivados")

		for attr_id in assigned_attributes.keys():
			var value: int = assigned_attributes[attr_id]
			chars.set_base_attribute("player", attr_id, float(value))

		# Curar a los nuevos máximos derivados — ModifierApplicator ya actualizó
		# max_effective vía set_base_attribute(), pero no toca el valor "current".
		if resources:
			resources.restore_resource("player", "health")
			resources.restore_resource("player", "stamina")

	if skills and not skills._entity_skills.has("player"):
		# IMPORTANTE: pasar la lista explícita del kit fijo. register_entity_skills()
		# con el array vacío por defecto registra TODO el catálogo de skills del
		# juego (17 en este proyecto) — eso rompe la progresión por uso.
		skills.register_entity_skills("player", STARTING_SKILL_VALUES.keys())
	elif not skills:
		push_warning("[CharacterCreationViewModel] SkillSystem no encontrado")

	if resources:
		resources.set_resource("player", "gold", STARTING_GOLD)

	if equipment:
		equipment.register_entity("player")
	else:
		push_warning("[CharacterCreationViewModel] EquipmentManager no encontrado")

	if inventory:
		inventory.register_entity("player")
		for item_id in STARTING_ITEMS.keys():
			var quantity: int = STARTING_ITEMS[item_id]
			inventory.add_item("player", item_id, quantity)
	else:
		push_warning("[CharacterCreationViewModel] InventorySystem no encontrado")

	# TODO resuelto: el nombre ahora vive en CharacterState.character_name,
	# incluido en get_save_state()/load_save_state() — persiste con el resto
	# del personaje.
	chars.set_character_name("player", character_name)
	print("[CharacterCreationViewModel] Player creado: '%s'" % character_name)
