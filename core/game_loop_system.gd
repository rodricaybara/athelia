class_name GameLoopSystem
extends Node

## GameLoopSystem - Orquestador de estados y flujo de combate
## Singleton: /root/GameLoop
##
## Responsabilidades:
## - Gestionar estados globales del juego (MENU, COMBAT, VICTORY, DEFEAT)
## - Controlar fases de turno (PLAYER_TURN, ENEMY_TURN, etc.)
## - Calcular y mantener orden de turnos (iniciativa)
## - Detectar condiciones de victoria/derrota
## - Validar transiciones de estado
## - Emitir eventos de flujo (NO ejecuta mecánicas)
##
## NO hace:
## - Calcular daño (eso es CombatSystem)
## - Gestionar recursos (eso es ResourceSystem)
## - Validar costes de habilidades (eso es SkillSystem)
## - Aplicar efectos (eso es CombatSystem)
##
## Arquitectura:
## - Event-driven: emite eventos, otros sistemas escuchan
## - Sin lógica de combate: solo orquestación
## - Estado serializable para SaveSystem

# ============================================
# ESTADOS Y FASES
# ============================================

enum GameState {
	MENU,              # Estado inicial / Main Menu
	EXPLORATION,       # Jugador explorando el mundo
	DIALOGUE,          # Conversación activa con NPC
	SHOP,              # Tienda abierta
	COMBAT_ACTIVE,     # En combate activo
	VICTORY,           # Combate ganado (transitorio)
	DEFEAT,            # Combate perdido (transitorio)
	PAUSE,             # Juego pausado (overlay)
	SAVE_TRANSITION,   # Guardando (bloqueante breve)
}

## Matriz de transiciones válidas entre GameStates
## Fuente de verdad única — no duplicar en otros sistemas
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
	ROUND_START,             # Inicio de ronda (efectos de ronda)
	PLAYER_TURN_START,       # Inicio turno jugador (restaurar recursos)
	PLAYER_ACTION_SELECT,    # Esperando input del jugador
	PLAYER_ACTION_RESOLVE,   # Ejecutando acción del jugador
	ENEMY_TURN_START,        # Inicio turno enemigos
	ENEMY_ACTION_RESOLVE,    # Ejecutando acción de enemigo
	TURN_END,                # Fin de turno (efectos de fin de turno)
	ROUND_END                # Fin de ronda
}

# ============================================
# ESTADO INTERNO
# ============================================

## Estado global actual del juego
var current_game_state: GameState = GameState.MENU

## Estado anterior — usado para volver desde PAUSE
var previous_game_state: GameState = GameState.MENU

## Fase actual del turno
var current_phase: TurnPhase = TurnPhase.ROUND_START

## Número de ronda actual (empieza en 1)
var round_number: int = 0

## Lista de participantes en combate (IDs)
var participants: Array[String] = []

## Orden de turnos basado en iniciativa (calculado al inicio)
## Ordenado de mayor a menor iniciativa
var turn_order: Array[String] = []

## Índice actual en turn_order (para procesar enemigos)
var current_turn_index: int = 0

## ID del jugador (hardcoded para MVP)
const PLAYER_ID: String = "player"

## Delay entre turnos de enemigos (segundos)
@export var enemy_turn_delay: float = 0.8

## Flag para prevenir transiciones durante procesamiento
var _is_processing: bool = false

# ============================================
# REFERENCIAS A SISTEMAS
# ============================================

@onready var character_system: CharacterSystem = Characters
#@onready var attribute_resolver: AttributeResolver = preload("res://core/characters/attribute_resolver.gd").new()

# ============================================
# INICIALIZACIÓN
# ============================================

func _ready():
	# Conectar a eventos de sistemas
	if EventBus:
		EventBus.player_action_completed.connect(_on_player_action_completed)
		EventBus.combat_action_completed.connect(_on_combat_action_completed)
		EventBus.character_died.connect(_on_character_died)
		EventBus.player_action_requested.connect(_on_player_action_requested)
	else:
		push_error("[GameLoopSystem] EventBus autoload not found!")
	
	print("[GameLoopSystem] Initialized")


# ============================================
# API PÚBLICA - GESTIÓN DE ESTADOS GLOBALES
# ============================================

## Solicita una transición de estado global.
## Única vía válida para cambiar estado desde sistemas externos.
## El SceneOrchestrator y otros sistemas emiten eventos; esto valida y ejecuta.
func request_state_change(new_state: GameState, context: Dictionary = {}) -> bool:
	if not _can_transition_state(current_game_state, new_state):
		push_warning("[GameLoopSystem] Invalid state transition: %s → %s" % [
			GameState.keys()[current_game_state],
			GameState.keys()[new_state]
		])
		return false
	
	# Bloquear si estamos procesando combate (excepto transiciones de salida)
	if _is_processing and new_state != GameState.VICTORY and new_state != GameState.DEFEAT:
		push_warning("[GameLoopSystem] State change blocked: combat processing in progress")
		return false
	
	# Emitir contexto ANTES de la transición para que los listeners
	# ya tengan _pending_context cuando reciban game_state_changed
	if not context.is_empty():
		EventBus.emit_signal("game_state_context", new_state, context)
	
	_transition_game_state(new_state)
	
	return true


## Entra en modo exploración. Punto de retorno estándar tras cualquier modo.
func enter_exploration() -> void:
	request_state_change(GameState.EXPLORATION)


## Entra en modo diálogo.
func enter_dialogue(dialogue_id: String) -> void:
	if request_state_change(GameState.DIALOGUE, {"dialogue_id": dialogue_id}):
		EventBus.emit_signal("dialogue_state_entered", dialogue_id)


## Entra en modo tienda.
func enter_shop(shop_id: String) -> void:
	if request_state_change(GameState.SHOP, {"shop_id": shop_id}):
		EventBus.emit_signal("shop_open_requested", shop_id, PLAYER_ID)


## Retorna si el estado actual bloquea el input de exploración
func is_input_blocked() -> bool:
	return current_game_state in [
		GameState.DIALOGUE,
		GameState.SHOP,
		GameState.COMBAT_ACTIVE,
		GameState.SAVE_TRANSITION,
		GameState.VICTORY,
		GameState.DEFEAT,
	]


## Retorna el estado actual como String (útil para debug/UI)
func get_state_name() -> String:
	return GameState.keys()[current_game_state]


# ============================================
# API PÚBLICA - GESTIÓN DE COMBATE
# ============================================

func start_combat(enemy_ids: Array[String]) -> void:
	if current_game_state != GameState.EXPLORATION and current_game_state != GameState.DIALOGUE and current_game_state != GameState.MENU:
		push_warning("[GameLoopSystem] Cannot start combat: wrong state %s" % GameState.keys()[current_game_state])
		return
	
	if enemy_ids.is_empty():
		push_error("[GameLoopSystem] Cannot start combat with no enemies")
		return
	
	print("[GameLoopSystem] ⚔️ Starting combat with %d enemies" % enemy_ids.size())
	
	# Configurar participantes - ✅ CORRECTO
	participants.clear()
	participants.append(PLAYER_ID)
	participants.append_array(enemy_ids)
	
	# Calcular iniciativa y orden de turnos
	_calculate_initiative()
	
	# Resetear estado
	round_number = 0
	current_turn_index = 0
	
	# Transicionar a combate
	_transition_game_state(GameState.COMBAT_ACTIVE)
	
	# Emitir evento de inicio
	EventBus.emit_signal("combat_started", participants.duplicate())
	
	# Iniciar primera ronda
	_start_new_round()


## Termina el combate con el resultado dado
func end_combat(result: String) -> void:
	if current_game_state != GameState.COMBAT_ACTIVE:
		push_warning("[GameLoopSystem] Cannot end combat: not in combat")
		return
	
	print("[GameLoopSystem] Combat ended: %s" % result)
	
	# Transicionar según resultado
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
	
	# Limpiar estado
	participants.clear()
	turn_order.clear()
	current_turn_index = 0
	round_number = 0
	current_phase = TurnPhase.ROUND_START  # Reset fase para próximo combate
	
	# Emitir evento
	EventBus.emit_signal("combat_ended", result)


## Retorna si está en combate activo
func is_in_combat() -> bool:
	return current_game_state == GameState.COMBAT_ACTIVE


## Retorna lista de enemigos vivos
func get_active_enemies() -> Array[String]:
	return turn_order.filter(func(id): return id != PLAYER_ID)


## Retorna la fase actual
func get_current_phase() -> TurnPhase:
	return current_phase


## Retorna el estado del juego como diccionario (para serialización)
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

## Calcula orden de turnos basado en iniciativa
## Iniciativa fija: se calcula una vez al inicio del combate
func _calculate_initiative() -> void:
	var initiatives: Array[Dictionary] = []
	
	for participant_id in participants:
		# AttributeResolver.resolve() obtiene el character_state internamente
		var initiative_value = AttributeResolver.resolve(
			participant_id,
			"initiative",
			{}
		)
		
		if initiative_value == 0.0:
			push_warning("[GameLoopSystem] Initiative is 0 for %s - using default 10" % participant_id)
			initiative_value = 10.0
		
		initiatives.append({
			"id": participant_id,
			"initiative": initiative_value
		})
		
		print("[GameLoopSystem] %s initiative: %.1f" % [participant_id, initiative_value])
	
	# Ordenar de mayor a menor iniciativa
	initiatives.sort_custom(func(a, b): return a.initiative > b.initiative)
	
	# ✅ Extraer IDs ordenados - Forma compatible con Array[String]
	turn_order.clear()
	for entry in initiatives:
		turn_order.append(entry.id)
	
	print("[GameLoopSystem] 📋 Turn order: %s" % str(turn_order))


# ============================================
# GESTIÓN DE RONDAS Y TURNOS
# ============================================

## Inicia una nueva ronda
func _start_new_round() -> void:
	round_number += 1
	current_turn_index = 0
	
	print("[GameLoopSystem] 🔄 Round %d started" % round_number)
	# Solo transicionar si NO estamos ya en ROUND_START
	if current_phase != TurnPhase.ROUND_START:
		_transition_to_phase(TurnPhase.ROUND_START)
	EventBus.emit_signal("round_started", round_number)
	
	# Procesar efectos de inicio de ronda (buffs, regeneración, etc.)
	# TODO: Implementar cuando tengamos sistema de efectos de duración
	
	# Iniciar turno del jugador
	_start_player_turn()


## Inicia el turno del jugador
func _start_player_turn() -> void:
	_transition_to_phase(TurnPhase.PLAYER_TURN_START)
	EventBus.emit_signal("player_turn_started")
	
	print("[GameLoopSystem] 👤 Player turn started")
	
	# CombatSystem escuchará y restaurará recursos/procesará buffs
	
	# Inmediatamente pasar a selección de acción
	await get_tree().process_frame
	_transition_to_phase(TurnPhase.PLAYER_ACTION_SELECT)


## Termina el turno del jugador e inicia turnos enemigos
func _end_player_turn() -> void:
	print("[GameLoopSystem] Player turn ended")
	
	# Verificar si hay enemigos vivos
	var enemies = get_active_enemies()
	if enemies.is_empty():
		# No hay enemigos, victoria
		_check_victory_condition()
		return
	
	# Iniciar turnos enemigos
	_start_enemy_turns()


## Inicia la secuencia de turnos enemigos
func _start_enemy_turns() -> void:
	_transition_to_phase(TurnPhase.ENEMY_TURN_START)
	
	print("[GameLoopSystem] 👹 Enemy turns started")
	
	# Resetear índice
	current_turn_index = 0
	
	# Procesar primer enemigo
	_process_next_enemy()


## Procesa el siguiente enemigo en turn_order
func _process_next_enemy() -> void:
	var enemies = get_active_enemies()
	
	# Si no hay más enemigos, terminar turno
	if current_turn_index >= enemies.size():
		_end_turn()
		return
	
	var enemy_id = enemies[current_turn_index]
	
	print("[GameLoopSystem] Processing enemy [%d/%d]: %s" % [
		current_turn_index + 1,
		enemies.size(),
		enemy_id
	])
	
	# Transicionar a resolución de acción enemiga
	_transition_to_phase(TurnPhase.ENEMY_ACTION_RESOLVE)
	
	# Emitir evento para que EnemyAI actúe
	EventBus.emit_signal("enemy_turn_started", enemy_id)
	
	# EnemyAI decidirá acción y emitirá enemy_action_requested
	# Luego CombatSystem ejecutará y emitirá combat_action_completed
	# Callback: _on_combat_action_completed() continuará


## Termina el turno actual
func _end_turn() -> void:
	_transition_to_phase(TurnPhase.TURN_END)
	EventBus.emit_signal("turn_ended")
	
	print("[GameLoopSystem] Turn ended")
	
	# Procesar efectos de fin de turno
	# TODO: Implementar cuando tengamos sistema de efectos
	
	# Finalizar ronda
	_end_round()


## Finaliza la ronda actual
func _end_round() -> void:
	_transition_to_phase(TurnPhase.ROUND_END)
	EventBus.emit_signal("round_ended", round_number)
	
	print("[GameLoopSystem] Round %d ended" % round_number)
	
	# Procesar efectos de fin de ronda
	# TODO: Implementar cuando tengamos sistema de efectos
	
	# Iniciar nueva ronda
	await get_tree().create_timer(0.3).timeout
	_start_new_round()


# ============================================
# CALLBACKS DE EVENTOS
# ============================================

## Termina el turno del jugador desde una acción especial (defend, flee fallido)
## Usado cuando la acción no pasa por el flujo player_action_requested → execute_combat_action
func end_player_turn_from_special_action() -> void:
	if current_phase != TurnPhase.PLAYER_ACTION_SELECT:
		push_warning("[GameLoopSystem] end_player_turn_from_special_action: wrong phase (%s)" % TurnPhase.keys()[current_phase])
		return
	
	print("[GameLoopSystem] Special action consumed player turn")
	_transition_to_phase(TurnPhase.PLAYER_ACTION_RESOLVE)
	
	if not _check_combat_conditions():
		_end_player_turn()


## Callback: Jugador solicita una acción
func _on_player_action_requested(action_data: Dictionary) -> void:
	var actor = action_data.get("actor", "")
	
	# Validar según quién actúa
	if actor == PLAYER_ID:
		# Acción del jugador - debe ser fase PLAYER_ACTION_SELECT
		if current_phase != TurnPhase.PLAYER_ACTION_SELECT:
			push_warning("[GameLoopSystem] Player action ignored: wrong phase (%s)" % TurnPhase.keys()[current_phase])
			return
		
		print("[GameLoopSystem] Player action received: %s" % action_data.get("skill_id", "unknown"))
		_transition_to_phase(TurnPhase.PLAYER_ACTION_RESOLVE)
	
	else:
		# Acción de enemigo - debe ser fase ENEMY_ACTION_RESOLVE
		if current_phase != TurnPhase.ENEMY_ACTION_RESOLVE:
			push_warning("[GameLoopSystem] Enemy action ignored: wrong phase (%s)" % TurnPhase.keys()[current_phase])
			return
		
		print("[GameLoopSystem] Enemy action received: %s from %s" % [action_data.get("skill_id", "unknown"), actor])
		# No transicionar - ya estamos en ENEMY_ACTION_RESOLVE
	
	# Emitir evento para que CombatSystem ejecute
	EventBus.emit_signal("execute_combat_action", action_data)

## Callback: Jugador completó su acción
func _on_player_action_completed(_result: Dictionary) -> void:
	if current_phase != TurnPhase.PLAYER_ACTION_RESOLVE:
		return  # Ignorar si no estamos en fase correcta
	
	print("[GameLoopSystem] Player action completed")
	
	# Verificar condiciones de victoria/derrota
	if not _check_combat_conditions():
		# Combate continúa, terminar turno del jugador
		_end_player_turn()


## Callback: Acción de combate completada (jugador o enemigo)
func _on_combat_action_completed(_result: Dictionary) -> void:
	if current_phase == TurnPhase.ENEMY_ACTION_RESOLVE:
		# Acción enemiga completada
		print("[GameLoopSystem] Enemy action completed")
		
		# Verificar condiciones de victoria/derrota
		if _check_combat_conditions():
			return  # Combate terminó
		
		# Incrementar índice y procesar siguiente enemigo
		current_turn_index += 1
		
		# Delay entre enemigos
		await get_tree().create_timer(enemy_turn_delay).timeout
		_process_next_enemy()


## Callback: Personaje murió
func _on_character_died(character_id: String) -> void:
	print("[GameLoopSystem] 💀 Character died: %s" % character_id)
	
	# Remover de participantes y turn_order
	participants.erase(character_id)
	turn_order.erase(character_id)
	
	# Verificar condiciones de combate
	_check_combat_conditions()


# ============================================
# DETECCIÓN DE CONDICIONES DE COMBATE
# ============================================

## Verifica condiciones de victoria/derrota
## Retorna true si el combate terminó
func _check_combat_conditions() -> bool:
	# Verificar victoria (todos los enemigos muertos)
	var active_enemies = get_active_enemies()
	
	if active_enemies.is_empty():
		if current_game_state == GameState.COMBAT_ACTIVE:  # ✅ Verificar primero
			print("[GameLoopSystem] All enemies defeated!")
			end_combat("victory")
		return true
	
	# Verificar derrota (jugador muerto)
	var player_hp = Resources.get_resource_amount(PLAYER_ID, "health")
	if player_hp <= 0:
		if current_game_state == GameState.COMBAT_ACTIVE:  # ✅ Verificar primero
			print("[GameLoopSystem] Player defeated!")
			end_combat("defeat")
		return true
	
	return false


## Verifica si todos los enemigos están muertos
func _all_enemies_dead() -> bool:
	var enemies = get_active_enemies()
	return enemies.is_empty()


## Verifica condición de victoria
func _check_victory_condition() -> void:
	if _all_enemies_dead():
		end_combat("victory")


# ============================================
# SISTEMA DE TRANSICIONES
# ============================================

## Transiciona a un nuevo estado del juego
func _transition_game_state(new_state: GameState) -> void:
	if current_game_state == new_state:
		return
	
	var old_state = current_game_state
	previous_game_state = old_state
	current_game_state = new_state
	
	EventBus.emit_signal("game_state_changed", new_state)
	
	print("[GameLoopSystem] State: %s → %s" % [
		GameState.keys()[old_state],
		GameState.keys()[new_state]
	])


## Valida si una transición de GameState es legal según la matriz oficial
func _can_transition_state(from: GameState, to: GameState) -> bool:
	if not from in VALID_STATE_TRANSITIONS:
		return false
	return to in VALID_STATE_TRANSITIONS[from]


## Transiciona a una nueva fase de turno
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
	
	var old_phase = current_phase
	current_phase = new_phase
	
	EventBus.emit_signal("turn_phase_changed", new_phase)
	
	print("[GameLoopSystem] Phase: %s → %s" % [
		TurnPhase.keys()[old_phase],
		TurnPhase.keys()[new_phase]
	])


## Valida si una transición de fase es legal
func _can_transition(from: TurnPhase, to: TurnPhase) -> bool:
	# Matriz de transiciones válidas
	var valid_transitions = {
		TurnPhase.ROUND_START: [TurnPhase.PLAYER_TURN_START],
		TurnPhase.PLAYER_TURN_START: [TurnPhase.PLAYER_ACTION_SELECT],
		TurnPhase.PLAYER_ACTION_SELECT: [TurnPhase.PLAYER_ACTION_RESOLVE],
		TurnPhase.PLAYER_ACTION_RESOLVE: [TurnPhase.ENEMY_TURN_START],
		TurnPhase.ENEMY_TURN_START: [TurnPhase.ENEMY_ACTION_RESOLVE],
		TurnPhase.ENEMY_ACTION_RESOLVE: [TurnPhase.ENEMY_ACTION_RESOLVE, TurnPhase.TURN_END],
		TurnPhase.TURN_END: [TurnPhase.ROUND_END],
		TurnPhase.ROUND_END: [TurnPhase.ROUND_START]
	}
	
	if not from in valid_transitions:
		return false
	
	return to in valid_transitions[from]


# ============================================
# DEBUG / UTILIDADES
# ============================================

## Imprime estado actual del sistema
func debug_print_state() -> void:
	print("=".repeat(60))
	print("[GameLoopSystem] Current State:")
	print("  Game State: %s" % GameState.keys()[current_game_state])
	print("  Turn Phase: %s" % TurnPhase.keys()[current_phase])
	print("  Round: %d" % round_number)
	print("  Participants: %s" % str(participants))
	print("  Turn Order: %s" % str(turn_order))
	print("  Current Index: %d" % current_turn_index)
	print("=".repeat(60))
