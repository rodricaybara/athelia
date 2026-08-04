extends Node

## PlayerCombatController - Gestiona input del jugador en combate
## Debe ser hijo de un nodo Player en la escena
##
## Responsabilidades POST-REFACTOR:
## - Capturar input de habilidades (teclas 1-3, Q, E, R)
## - Gestionar targeting de enemigos (Tab para cambiar)
## - Validar acciones según fase actual
## - Emitir eventos de acción del jugador
## - Habilitar/deshabilitar UI según fase
##
## NO hace:
## - Ejecutar acciones (eso es CombatSystem)
## - Validar costes (eso es SkillSystem)
## - Calcular daño (eso es CombatSystem)
## - Controlar turnos (eso es GameLoopSystem)
##
## Arquitectura:
## - Event-driven: emite player_action_requested
## - Reactivo: escucha turn_phase_changed para habilitar/deshabilitar UI
##
## InputMap esperado (Project Settings → Input Map):
##   combat_attack_1 → 1   (ataque ligero)
##   combat_attack_2 → 2   (ataque pesado)
##   combat_attack_3 → 3   (ataque especial)
##   combat_dodge    → Q
##   combat_defense  → E
##   combat_scape    → R
##   cycle_target    → Tab

# ============================================
# CONFIGURACIÓN
# ============================================

## ID de la entidad del jugador (debe coincidir con registro en sistemas)
@export var player_id: String = "player"

## Mapeo de actions (InputMap) a skill IDs.
## Los nombres de action deben coincidir exactamente con Project Settings → Input Map.
@export var skill_hotkeys: Dictionary = {
	"combat_attack_1": "skill.attack.light",
	"combat_attack_2": "skill.attack.heavy",
	"combat_attack_3": "skill.attack.stunning_blow",
	"combat_dodge":    "skill.combat.dodge",
	"combat_defense":  "skill.combat.defend",
	"combat_scape":    "skill.combat.flee",
}

## Skills que son acciones especiales: no necesitan target y tienen flujo propio
const SPECIAL_ACTIONS: Array[String] = ["skill.combat.defend", "skill.combat.flee"]

# ============================================
# ESTADO INTERNO - TARGETING
# ============================================

## Target actual seleccionado
var current_target: String = ""

## Índice del target en la lista de enemigos disponibles
var current_target_index: int = 0

## Lista de enemigos disponibles para targetear
var available_targets: Array[String] = []

## Flag: ¿está el input habilitado?
var input_enabled: bool = false

# ============================================
# REFERENCIAS
# ============================================

@onready var game_loop: GameLoopSystem = get_node_or_null("/root/GameLoop")

# ============================================
# INICIALIZACIÓN
# ============================================

func _ready():
	if not game_loop:
		push_error("[PlayerCombatController] GameLoopSystem not found at /root/GameLoop!")
		return

	if EventBus:
		EventBus.turn_phase_changed.connect(_on_turn_phase_changed)
		EventBus.combat_started.connect(_on_combat_started)
		EventBus.combat_ended.connect(_on_combat_ended)
		EventBus.character_died.connect(_on_character_died)
	else:
		push_error("[PlayerCombatController] EventBus autoload not found!")

	# Verificar que las actions del InputMap existen
	for action_name in skill_hotkeys.keys():
		if not InputMap.has_action(action_name):
			push_warning("[PlayerCombatController] InputMap action not found: '%s'" % action_name)

	if not InputMap.has_action("cycle_target"):
		push_warning("[PlayerCombatController] InputMap action not found: 'cycle_target'")

	print("[PlayerCombatController] Initialized")


# ============================================
# INPUT HANDLING
# ============================================

## _unhandled_input en lugar de _input para no competir con combat_test_scene._input
## y respetar el comportamiento de Godot 4.7 con escenas aditivas.
func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return

	if not game_loop or not game_loop.is_in_combat():
		return

	if game_loop.get_current_phase() != GameLoopSystem.TurnPhase.PLAYER_ACTION_SELECT:
		return

	# Cambiar target con Tab
	if event.is_action_pressed("cycle_target"):
		_cycle_target()
		get_viewport().set_input_as_handled()
		return

	# Usar habilidades con teclas de combate
	for action_name in skill_hotkeys.keys():
		if event.is_action_pressed(action_name):
			var skill_id: String = skill_hotkeys[action_name]
			_request_skill_use(skill_id)
			get_viewport().set_input_as_handled()
			return


# ============================================
# SISTEMA DE TARGETING
# ============================================

## Cambia al siguiente enemigo en la lista
func _cycle_target() -> void:
	if available_targets.is_empty():
		push_warning("[PlayerCombatController] No targets available")
		return

	current_target_index = (current_target_index + 1) % available_targets.size()
	current_target = available_targets[current_target_index]

	print("[PlayerCombatController] Target cycled to [%d]: %s" % [current_target_index, current_target])
	EventBus.emit_signal("target_changed", current_target)


## Actualiza la lista de targets disponibles
func _update_available_targets() -> void:
	if not game_loop:
		return

	available_targets = game_loop.get_active_enemies()

	if not current_target in available_targets:
		if not available_targets.is_empty():
			current_target_index = 0
			current_target = available_targets[0]
			EventBus.emit_signal("target_changed", current_target)
		else:
			current_target = ""
			current_target_index = 0


## Retorna el target actual
func get_current_target() -> String:
	return current_target


# ============================================
# SOLICITUD DE ACCIONES
# ============================================

func _request_skill_use(skill_id: String) -> void:
	if game_loop.get_current_phase() != GameLoopSystem.TurnPhase.PLAYER_ACTION_SELECT:
		print("[PlayerCombatController] Cannot use skill: wrong phase")
		return

	if skill_id in SPECIAL_ACTIONS:
		_request_special_action(skill_id)
		return

	var skill_def = Skills.get_skill_definition(skill_id)
	var needs_target: bool = true
	if skill_def and skill_def.target_type in ["AREA", "MULTI_ENEMY"]:
		needs_target = false

	if needs_target and current_target.is_empty():
		print("[PlayerCombatController] Cannot use skill: no target selected")
		return

	print("[PlayerCombatController] Requesting skill: %s on %s" % [skill_id, current_target])

	var action_data: Dictionary = {
		"actor":   player_id,
		"skill_id": skill_id,
		"target":  current_target
	}

	EventBus.emit_signal("player_action_requested", action_data)
	_set_input_enabled(false)


func _request_special_action(skill_id: String) -> void:
	print("[PlayerCombatController] Requesting special action: %s" % skill_id)
	_set_input_enabled(false)

	match skill_id:
		"skill.combat.defend":
			EventBus.emit_signal("defend_requested", player_id)
		"skill.combat.flee":
			EventBus.emit_signal("flee_requested", player_id)


# ============================================
# CALLBACKS DE EVENTOS
# ============================================

func _on_turn_phase_changed(new_phase) -> void:
	match new_phase:
		GameLoopSystem.TurnPhase.PLAYER_ACTION_SELECT:
			_set_input_enabled(true)
			print("[PlayerCombatController] Input enabled — awaiting player action")

		GameLoopSystem.TurnPhase.PLAYER_ACTION_RESOLVE:
			_set_input_enabled(false)
			print("[PlayerCombatController] Input disabled (resolving action)")

		GameLoopSystem.TurnPhase.ENEMY_TURN_START, \
		GameLoopSystem.TurnPhase.ENEMY_ACTION_RESOLVE:
			_set_input_enabled(false)
			print("[PlayerCombatController] Input disabled (enemy turn)")

		_:
			_set_input_enabled(false)


func _on_combat_started(_participants: Array) -> void:
	print("[PlayerCombatController] Combat started")
	_update_available_targets()

	if not available_targets.is_empty():
		current_target_index = 0
		current_target = available_targets[0]
		EventBus.emit_signal("target_changed", current_target)
		print("[PlayerCombatController] Auto-targeted: %s" % current_target)


func _on_combat_ended(result: String) -> void:
	print("[PlayerCombatController] Combat ended: %s" % result)
	_set_input_enabled(false)
	current_target = ""
	current_target_index = 0
	available_targets.clear()


func _on_character_died(character_id: String) -> void:
	if character_id in available_targets:
		print("[PlayerCombatController] Target died: %s" % character_id)
		_update_available_targets()


# ============================================
# GESTIÓN DE INPUT
# ============================================

func _set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled

func is_input_enabled() -> bool:
	return input_enabled


# ============================================
# API PÚBLICA (para UI y combat_test_scene)
# ============================================

func request_skill(skill_id: String) -> void:
	if not input_enabled:
		print("[PlayerCombatController] Input disabled, cannot use skill")
		return
	_request_skill_use(skill_id)

func request_cycle_target() -> void:
	if not input_enabled:
		return
	_cycle_target()

func get_available_targets() -> Array[String]:
	return available_targets.duplicate()
