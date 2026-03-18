class_name GameLoopSystem
extends Node

## GameLoopSystem - Orquestador de estados y flujo de combate
## Singleton: /root/GameLoop
##
## v2: Añadida fase COMPANION_ACTION_RESOLVE para turno de companions.
## Los companions actúan después del jugador, antes de los enemigos.

# ============================================
# ESTADOS Y FASES
# ============================================

enum GameState {
	MENU,
	EXPLORATION,
	DIALOGUE,
	SHOP,
	COMBAT_ACTIVE,
	VICTORY,
	DEFEAT,
	PAUSE,
	SAVE_TRANSITION,
}

const VALID_STATE_TRANSITIONS: Dictionary = {
	GameState.MENU:            [GameState.EXPLORATION],
	GameState.EXPLORATION:     [GameState.DIALOGUE, GameState.SHOP, GameState.COMBAT_ACTIVE, GameState.PAUSE, GameState.SAVE_TRANSITION],
	GameState.DIALOGUE:        [GameState.EXPLORATION, GameState.COMBAT_ACTIVE],
	GameState.SHOP:            [GameState.EXPLORATION],
	GameState.COMBAT_ACTIVE:   [GameState.VICTORY, GameState.DEFEAT, GameState.EXPLORATION],
	GameState.VICTORY:         [GameState.EXPLORATION],
	GameState.DEFEAT:          [GameState.MENU, GameState.EXPLORATION],
	GameState.PAUSE:           [GameState.EXPLORATION, GameState.COMBAT_ACTIVE],
	GameState.SAVE_TRANSITION: [GameState.EXPLORATION],
}

enum TurnPhase {
	ROUND_START,
	PLAYER_TURN_START,
	PLAYER_ACTION_SELECT,
	PLAYER_ACTION_RESOLVE,
	COMPANION_ACTION_RESOLVE,   ## ← NUEVO: companions actúan tras el jugador
	ENEMY_TURN_START,
	ENEMY_ACTION_RESOLVE,
	TURN_END,
	ROUND_END
}

# ============================================
# ESTADO INTERNO
# ============================================

var current_game_state: GameState = GameState.MENU
var previous_game_state: GameState = GameState.MENU
var current_phase: TurnPhase = TurnPhase.ROUND_START
var round_number: int = 0
var participants: Array[String] = []
var turn_order: Array[String] = []
var current_turn_index: int = 0

const PLAYER_ID: String = "player"

@export var enemy_turn_delay: float = 0.8
@export var companion_turn_delay: float = 0.5

var _is_processing: bool = false

## Índice del companion actual procesando su turno
var _companion_turn_index: int = 0

# ============================================
# REFERENCIAS
# ============================================

@onready var character_system: CharacterSystem = Characters

# ============================================
# INICIALIZACIÓN
# ============================================

func _ready():
	if EventBus:
		EventBus.player_action_completed.connect(_on_player_action_completed)
		EventBus.combat_action_completed.connect(_on_combat_action_completed)
		EventBus.character_died.connect(_on_character_died)
		EventBus.player_action_requested.connect(_on_player_action_requested)
		EventBus.companion_action_completed.connect(_on_companion_action_completed)
	else:
		push_error("[GameLoopSystem] EventBus not found!")

	print("[GameLoopSystem] Initialized")


# ============================================
# API PÚBLICA — GESTIÓN DE ESTADOS GLOBALES
# ============================================

func request_state_change(new_state: GameState, context: Dictionary = {}) -> bool:
	if not _can_transition_state(current_game_state, new_state):
		push_warning("[GameLoopSystem] Invalid state transition: %s → %s" % [
			GameState.keys()[current_game_state],
			GameState.keys()[new_state]
		])
		return false

	if _is_processing and new_state != GameState.VICTORY and new_state != GameState.DEFEAT:
		push_warning("[GameLoopSystem] State change blocked: combat processing in progress")
		return false

	if not context.is_empty():
		EventBus.emit_signal("game_state_context", new_state, context)

	_transition_game_state(new_state)
	return true


func enter_exploration() -> void:
	request_state_change(GameState.EXPLORATION)

func enter_dialogue(dialogue_id: String) -> void:
	if request_state_change(GameState.DIALOGUE, {"dialogue_id": dialogue_id}):
		EventBus.emit_signal("dialogue_state_entered", dialogue_id)

func enter_shop(shop_id: String) -> void:
	if request_state_change(GameState.SHOP, {"shop_id": shop_id}):
		EventBus.emit_signal("shop_open_requested", shop_id, PLAYER_ID)

func is_input_blocked() -> bool:
	return current_game_state in [
		GameState.DIALOGUE,
		GameState.SHOP,
		GameState.COMBAT_ACTIVE,
		GameState.SAVE_TRANSITION,
		GameState.VICTORY,
		GameState.DEFEAT,
	]

func get_state_name() -> String:
	return GameState.keys()[current_game_state]


# ============================================
# API PÚBLICA — GESTIÓN DE COMBATE
# ============================================

func start_combat(enemy_ids: Array[String]) -> void:
	if current_game_state != GameState.EXPLORATION and current_game_state != GameState.DIALOGUE and current_game_state != GameState.MENU:
		push_warning("[GameLoopSystem] Cannot start combat: wrong state %s" % GameState.keys()[current_game_state])
		return

	if enemy_ids.is_empty():
		push_error("[GameLoopSystem] Cannot start combat with no enemies")
		return

	print("[GameLoopSystem] ⚔️ Starting combat with %d enemies" % enemy_ids.size())

	participants.clear()
	participants.append(PLAYER_ID)

	# Añadir companions activos como participantes aliados
	var party := get_node_or_null("/root/Party")
	if party:
		for companion_id in party.get_active_members():
			participants.append(companion_id)
			print("[GameLoopSystem]   + companion: %s" % companion_id)

	participants.append_array(enemy_ids)

	_calculate_initiative()

	round_number = 0
	current_turn_index = 0
	_companion_turn_index = 0

	_transition_game_state(GameState.COMBAT_ACTIVE)
	EventBus.emit_signal("combat_started", participants.duplicate())
	_start_new_round()


func end_combat(result: String) -> void:
	if current_game_state != GameState.COMBAT_ACTIVE:
		push_warning("[GameLoopSystem] Cannot end combat: not in combat")
		return

	print("[GameLoopSystem] Combat ended: %s" % result)

	match result:
		"victory":
			_transition_game_state(GameState.VICTORY)
		"defeat":
			_transition_game_state(GameState.DEFEAT)
		"escaped":
			_transition_game_state(GameState.EXPLORATION)
		_:
			push_error("[GameLoopSystem] Invalid combat result: %s" % result)
			_transition_game_state(GameState.EXPLORATION)

	participants.clear()
	turn_order.clear()
	current_turn_index = 0
	_companion_turn_index = 0
	round_number = 0
	current_phase = TurnPhase.ROUND_START

	EventBus.emit_signal("combat_ended", result)


func is_in_combat() -> bool:
	return current_game_state == GameState.COMBAT_ACTIVE


## Retorna enemigos vivos (excluye jugador y companions)
func get_active_enemies() -> Array[String]:
	var party := get_node_or_null("/root/Party")
	var party_ids: Array[String] = []
	if party:
		party_ids = party.get_party_members()

	var result: Array[String] = []
	for id in turn_order:
		if id == PLAYER_ID:
			continue
		if party_ids.has(id):
			continue
		result.append(id)
	return result


func get_current_phase() -> TurnPhase:
	return current_phase

func get_state() -> Dictionary:
	return {
		"game_state": GameState.keys()[current_game_state],
		"turn_phase": TurnPhase.keys()[current_phase],
		"round_number": round_number,
		"participants": participants.duplicate(),
		"turn_order": turn_order.duplicate(),
		"current_turn_index": current_turn_index
	}


# ============================================
# SISTEMA DE INICIATIVA
# ============================================

func _calculate_initiative() -> void:
	var initiatives: Array[Dictionary] = []

	for participant_id in participants:
		var initiative_value = AttributeResolver.resolve(participant_id, "initiative", {})
		if initiative_value == 0.0:
			push_warning("[GameLoopSystem] Initiative is 0 for %s - using default 10" % participant_id)
			initiative_value = 10.0
		initiatives.append({ "id": participant_id, "initiative": initiative_value })
		print("[GameLoopSystem] %s initiative: %.1f" % [participant_id, initiative_value])

	initiatives.sort_custom(func(a, b): return a.initiative > b.initiative)

	turn_order.clear()
	for entry in initiatives:
		turn_order.append(entry.id)

	print("[GameLoopSystem] 📋 Turn order: %s" % str(turn_order))


# ============================================
# GESTIÓN DE RONDAS Y TURNOS
# ============================================

func _start_new_round() -> void:
	round_number += 1
	current_turn_index = 0
	_companion_turn_index = 0

	print("[GameLoopSystem] 🔄 Round %d started" % round_number)
	if current_phase != TurnPhase.ROUND_START:
		_transition_to_phase(TurnPhase.ROUND_START)
	EventBus.emit_signal("round_started", round_number)

	_start_player_turn()


func _start_player_turn() -> void:
	_transition_to_phase(TurnPhase.PLAYER_TURN_START)
	EventBus.emit_signal("player_turn_started")
	print("[GameLoopSystem] 👤 Player turn started")

	await get_tree().process_frame
	_transition_to_phase(TurnPhase.PLAYER_ACTION_SELECT)


func _end_player_turn() -> void:
	print("[GameLoopSystem] Player turn ended")

	if _check_combat_conditions():
		return

	# Iniciar turno de companions si los hay
	var party := get_node_or_null("/root/Party")
	if party and party.has_companions():
		_start_companion_turns()
	else:
		_start_enemy_turns()


## Inicia la secuencia de turnos de companions
func _start_companion_turns() -> void:
	_companion_turn_index = 0
	_transition_to_phase(TurnPhase.COMPANION_ACTION_RESOLVE)
	print("[GameLoopSystem] 🤝 Companion turns started")
	_process_next_companion()


## Procesa el siguiente companion activo en el grupo
func _process_next_companion() -> void:
	var party := get_node_or_null("/root/Party")
	if not party:
		_start_enemy_turns()
		return

	var active_companions: Array[String] = party.get_active_members()

	if _companion_turn_index >= active_companions.size():
		# Todos los companions actuaron → turno enemigos
		_start_enemy_turns()
		return

	var companion_id: String = active_companions[_companion_turn_index]
	print("[GameLoopSystem] 🤝 Companion turn [%d/%d]: %s" % [
		_companion_turn_index + 1, active_companions.size(), companion_id
	])

	EventBus.companion_turn_started.emit(companion_id)
	# CompanionAI escucha y emitirá player_action_requested o companion_action_completed


func _start_enemy_turns() -> void:
	_transition_to_phase(TurnPhase.ENEMY_TURN_START)
	print("[GameLoopSystem] 👹 Enemy turns started")
	current_turn_index = 0
	_process_next_enemy()


func _process_next_enemy() -> void:
	var enemies := get_active_enemies()

	if current_turn_index >= enemies.size():
		_end_turn()
		return

	var enemy_id := enemies[current_turn_index]
	print("[GameLoopSystem] Processing enemy [%d/%d]: %s" % [
		current_turn_index + 1, enemies.size(), enemy_id
	])

	_transition_to_phase(TurnPhase.ENEMY_ACTION_RESOLVE)
	EventBus.emit_signal("enemy_turn_started", enemy_id)


func _end_turn() -> void:
	_transition_to_phase(TurnPhase.TURN_END)
	EventBus.emit_signal("turn_ended")
	print("[GameLoopSystem] Turn ended")
	_end_round()


func _end_round() -> void:
	_transition_to_phase(TurnPhase.ROUND_END)
	EventBus.emit_signal("round_ended", round_number)
	print("[GameLoopSystem] Round %d ended" % round_number)

	await get_tree().create_timer(0.3).timeout
	_start_new_round()


# ============================================
# CALLBACKS DE EVENTOS
# ============================================

func end_player_turn_from_special_action() -> void:
	if current_phase != TurnPhase.PLAYER_ACTION_SELECT:
		push_warning("[GameLoopSystem] end_player_turn_from_special_action: wrong phase (%s)" % TurnPhase.keys()[current_phase])
		return

	print("[GameLoopSystem] Special action consumed player turn")
	_transition_to_phase(TurnPhase.PLAYER_ACTION_RESOLVE)

	if not _check_combat_conditions():
		_end_player_turn()


func _on_player_action_requested(action_data: Dictionary) -> void:
	var actor: String = action_data.get("actor", "")

	# Companions usan la misma señal — rutar a la fase correcta
	var party: Node = get_node_or_null("/root/Party")
	var is_companion: bool = party != null and party.is_in_party(actor)

	if actor == PLAYER_ID:
		if current_phase != TurnPhase.PLAYER_ACTION_SELECT:
			push_warning("[GameLoopSystem] Player action ignored: wrong phase (%s)" % TurnPhase.keys()[current_phase])
			return
		print("[GameLoopSystem] Player action received: %s" % action_data.get("skill_id", "unknown"))
		_transition_to_phase(TurnPhase.PLAYER_ACTION_RESOLVE)

	elif is_companion:
		if current_phase != TurnPhase.COMPANION_ACTION_RESOLVE:
			push_warning("[GameLoopSystem] Companion action ignored: wrong phase (%s)" % TurnPhase.keys()[current_phase])
			return
		print("[GameLoopSystem] Companion action received: %s from %s" % [action_data.get("skill_id", "unknown"), actor])

	else:
		# Enemigo
		if current_phase != TurnPhase.ENEMY_ACTION_RESOLVE:
			push_warning("[GameLoopSystem] Enemy action ignored: wrong phase (%s)" % TurnPhase.keys()[current_phase])
			return
		print("[GameLoopSystem] Enemy action received: %s from %s" % [action_data.get("skill_id", "unknown"), actor])

	EventBus.emit_signal("execute_combat_action", action_data)


func _on_player_action_completed(_result: Dictionary) -> void:
	if current_phase != TurnPhase.PLAYER_ACTION_RESOLVE:
		return

	print("[GameLoopSystem] Player action completed")

	if not _check_combat_conditions():
		_end_player_turn()


## Callback: acción de combate completada (jugador, companion o enemigo)
func _on_combat_action_completed(_result: Dictionary) -> void:
	var party := get_node_or_null("/root/Party")

	if current_phase == TurnPhase.COMPANION_ACTION_RESOLVE:
		# Acción de companion completada — continuar con el siguiente
		print("[GameLoopSystem] Companion action completed via combat_action_completed")
		if _check_combat_conditions():
			return
		_companion_turn_index += 1
		await get_tree().create_timer(companion_turn_delay).timeout
		_process_next_companion()

	elif current_phase == TurnPhase.ENEMY_ACTION_RESOLVE:
		print("[GameLoopSystem] Enemy action completed")
		if _check_combat_conditions():
			return
		current_turn_index += 1
		await get_tree().create_timer(enemy_turn_delay).timeout
		_process_next_enemy()


## Callback específico de companions (cuando skipean su turno)
func _on_companion_action_completed(companion_id: String, _result: Dictionary) -> void:
	if current_phase != TurnPhase.COMPANION_ACTION_RESOLVE:
		return

	print("[GameLoopSystem] Companion '%s' action completed (direct)" % companion_id)

	if _check_combat_conditions():
		return

	_companion_turn_index += 1
	await get_tree().create_timer(companion_turn_delay).timeout
	_process_next_companion()


func _on_character_died(character_id: String) -> void:
	print("[GameLoopSystem] 💀 Character died: %s" % character_id)

	# Companion incapacitado — no se elimina del turn_order todavía
	var party := get_node_or_null("/root/Party")
	if party and party.is_in_party(character_id):
		party.set_incapacitated(character_id)
		# No eliminar de turn_order — CompanionAI skipea si está incapacitado
		_check_combat_conditions()
		return

	# Enemigo o jugador
	participants.erase(character_id)
	turn_order.erase(character_id)
	_check_combat_conditions()


# ============================================
# DETECCIÓN DE CONDICIONES DE COMBATE
# ============================================

func _check_combat_conditions() -> bool:
	# Victoria: todos los enemigos muertos
	var active_enemies := get_active_enemies()
	if active_enemies.is_empty():
		if current_game_state == GameState.COMBAT_ACTIVE:
			print("[GameLoopSystem] All enemies defeated!")
			end_combat("victory")
		return true

	# Derrota: jugador muerto
	var player_hp := Resources.get_resource_amount(PLAYER_ID, "health")
	if player_hp <= 0:
		# Comprobar si hay companions que puedan continuar
		var party := get_node_or_null("/root/Party")
		if party and not party.all_incapacitated() and party.has_companions():
			# Hay companions activos — el combate continúa (mecánica futura)
			# Por ahora tratamos la muerte del jugador como derrota igualmente
			pass

		if current_game_state == GameState.COMBAT_ACTIVE:
			print("[GameLoopSystem] Player defeated!")
			end_combat("defeat")
		return true

	return false

func _all_enemies_dead() -> bool:
	return get_active_enemies().is_empty()

func _check_victory_condition() -> void:
	if _all_enemies_dead():
		end_combat("victory")


# ============================================
# SISTEMA DE TRANSICIONES
# ============================================

func _transition_game_state(new_state: GameState) -> void:
	if current_game_state == new_state:
		return
	var old_state := current_game_state
	previous_game_state = old_state
	current_game_state = new_state
	EventBus.emit_signal("game_state_changed", new_state)
	print("[GameLoopSystem] State: %s → %s" % [
		GameState.keys()[old_state],
		GameState.keys()[new_state]
	])


func _can_transition_state(from: GameState, to: GameState) -> bool:
	if not from in VALID_STATE_TRANSITIONS:
		return false
	return to in VALID_STATE_TRANSITIONS[from]


func _transition_to_phase(new_phase: TurnPhase) -> void:
	if _is_processing:
		push_warning("[GameLoopSystem] Transition blocked: already processing")
		return

	if not _can_transition(current_phase, new_phase):
		push_error("[GameLoopSystem] Invalid transition: %s → %s" % [
			TurnPhase.keys()[current_phase],
			TurnPhase.keys()[new_phase]
		])
		return

	var old_phase := current_phase
	current_phase = new_phase
	EventBus.emit_signal("turn_phase_changed", new_phase)
	print("[GameLoopSystem] Phase: %s → %s" % [
		TurnPhase.keys()[old_phase],
		TurnPhase.keys()[new_phase]
	])


func _can_transition(from: TurnPhase, to: TurnPhase) -> bool:
	var valid_transitions := {
		TurnPhase.ROUND_START:              [TurnPhase.PLAYER_TURN_START],
		TurnPhase.PLAYER_TURN_START:        [TurnPhase.PLAYER_ACTION_SELECT],
		TurnPhase.PLAYER_ACTION_SELECT:     [TurnPhase.PLAYER_ACTION_RESOLVE],
		TurnPhase.PLAYER_ACTION_RESOLVE:    [TurnPhase.COMPANION_ACTION_RESOLVE, TurnPhase.ENEMY_TURN_START],
		TurnPhase.COMPANION_ACTION_RESOLVE: [TurnPhase.COMPANION_ACTION_RESOLVE, TurnPhase.ENEMY_TURN_START],
		TurnPhase.ENEMY_TURN_START:         [TurnPhase.ENEMY_ACTION_RESOLVE],
		TurnPhase.ENEMY_ACTION_RESOLVE:     [TurnPhase.ENEMY_ACTION_RESOLVE, TurnPhase.TURN_END],
		TurnPhase.TURN_END:                 [TurnPhase.ROUND_END],
		TurnPhase.ROUND_END:                [TurnPhase.ROUND_START]
	}

	if not from in valid_transitions:
		return false
	return to in valid_transitions[from]


# ============================================
# DEBUG
# ============================================

func debug_print_state() -> void:
	print("=".repeat(60))
	print("[GameLoopSystem] Current State:")
	print("  Game State: %s" % GameState.keys()[current_game_state])
	print("  Turn Phase: %s" % TurnPhase.keys()[current_phase])
	print("  Round: %d" % round_number)
	print("  Participants: %s" % str(participants))
	print("  Turn Order: %s" % str(turn_order))
	print("  Current Index: %d" % current_turn_index)
	var party := get_node_or_null("/root/Party")
	if party:
		print("  Party: %s" % str(party.get_party_members()))
	print("=".repeat(60))
