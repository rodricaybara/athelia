extends Node
#class_name PlayerCombatController
# eliminar la línea (no necesita class_name si es autoload)

## PlayerCombatController - Gestiona input del jugador en combate
## Debe ser hijo de un nodo Player en la escena
##
## Responsabilidades POST-REFACTOR:
## - Capturar input de habilidades (teclas 1-5)
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

# ============================================
# CONFIGURACIÓN
# ============================================

## ID de la entidad del jugador (debe coincidir con registro en sistemas)
@export var player_id: String = "player"

## Mapeo de actions (InputMap) a skill IDs
## Actions skill_1/2/3: teclas numéricas configuradas en Project Settings
## Actions defend/flee: R y F respectivamente
@export var skill_hotkeys: Dictionary = {
	"skill_1": "skill.attack.stunning_blow",
	"skill_2": "skill.attack.bleeding_strike",
	"skill_3": "skill.attack.reckless_strike",
	"defend":  "skill.combat.defend",
	"flee":    "skill.combat.flee",
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
	# Verificar que GameLoop existe
	if not game_loop:
		push_error("[PlayerCombatController] GameLoopSystem not found at /root/GameLoop!")
		return
	
	# Conectar a eventos de GameLoop
	if EventBus:
		EventBus.turn_phase_changed.connect(_on_turn_phase_changed)
		EventBus.combat_started.connect(_on_combat_started)
		EventBus.combat_ended.connect(_on_combat_ended)
		EventBus.character_died.connect(_on_character_died)
	else:
		push_error("[PlayerCombatController] EventBus autoload not found!")
	
	print("[PlayerCombatController] Initialized (Refactored)")


# ============================================
# INPUT HANDLING
# ============================================

func _input(event):
	# Solo procesar input si está habilitado
	if not input_enabled:
		return
	
	# No procesar si no estamos en combate
	if not game_loop or not game_loop.is_in_combat():
		return
	
	# Solo procesar en fase de selección de acción
	if game_loop.get_current_phase() != GameLoopSystem.TurnPhase.PLAYER_ACTION_SELECT:
		return
	
	# Cambiar target con Tab
	if event.is_action_pressed("cycle_target"):
		_cycle_target()
		get_viewport().set_input_as_handled()
		return
	
	# Usar habilidades con teclas 1-5
	for action_name in skill_hotkeys.keys():
		if event.is_action_pressed(action_name):
			var skill_id = skill_hotkeys[action_name]
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
	
	# Incrementar índice con wrap-around
	current_target_index = (current_target_index + 1) % available_targets.size()
	current_target = available_targets[current_target_index]
	
	print("[PlayerCombatController] Target cycled to [%d]: %s" % [current_target_index, current_target])
	
	# Emitir evento para UI
	EventBus.emit_signal("target_changed", current_target)


## Actualiza la lista de targets disponibles
func _update_available_targets() -> void:
	if not game_loop:
		return
	
	# Obtener enemigos vivos de GameLoop
	available_targets = game_loop.get_active_enemies()
	
	# Si el target actual ya no está disponible, seleccionar el primero
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

## Solicita el uso de una habilidad
func _request_skill_use(skill_id: String) -> void:
	# Validación: Fase correcta (doble check)
	if game_loop.get_current_phase() != GameLoopSystem.TurnPhase.PLAYER_ACTION_SELECT:
		print("[PlayerCombatController] Cannot use skill: wrong phase")
		return
	
	# Acciones especiales: flujo propio, sin target, sin pasar por GameLoop
	if skill_id in SPECIAL_ACTIONS:
		_request_special_action(skill_id)
		return
	
	# Habilidades normales: requieren target (excepto AREA que golpea a todos)
	var skill_def = Skills.get_skill_definition(skill_id)
	var needs_target = true
	if skill_def and skill_def.target_type in ["AREA", "MULTI_ENEMY"]:
		needs_target = false

	if needs_target and current_target.is_empty():
		print("[PlayerCombatController] Cannot use skill: no target selected")
		return
	
	print("[PlayerCombatController] Requesting skill: %s on %s" % [skill_id, current_target])
	
	var action_data = {
		"actor": player_id,
		"skill_id": skill_id,
		"target": current_target
	}
	
	EventBus.emit_signal("player_action_requested", action_data)
	_set_input_enabled(false)


## Emite el evento apropiado para acciones especiales (defend, flee)
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

## Callback: Cambio de fase de turno
func _on_turn_phase_changed(new_phase) -> void:
	match new_phase:
		GameLoopSystem.TurnPhase.PLAYER_ACTION_SELECT:
			# Habilitar input cuando sea el turno del jugador
			_set_input_enabled(true)
			print("[PlayerCombatController] Input enabled")
		
		GameLoopSystem.TurnPhase.PLAYER_ACTION_RESOLVE:
			# Deshabilitar input durante ejecución
			_set_input_enabled(false)
			print("[PlayerCombatController] Input disabled (resolving action)")
		
		GameLoopSystem.TurnPhase.ENEMY_TURN_START, \
		GameLoopSystem.TurnPhase.ENEMY_ACTION_RESOLVE:
			# Deshabilitar input durante turno enemigo
			_set_input_enabled(false)
			print("[PlayerCombatController] Input disabled (enemy turn)")
		
		_:
			# Deshabilitar input en otras fases
			_set_input_enabled(false)


## Callback: Combate iniciado
func _on_combat_started(_participants: Array) -> void:
	print("[PlayerCombatController] Combat started")
	
	# Actualizar targets disponibles
	_update_available_targets()
	
	# Auto-target primer enemigo
	if not available_targets.is_empty():
		current_target_index = 0
		current_target = available_targets[0]
		EventBus.emit_signal("target_changed", current_target)
		print("[PlayerCombatController] Auto-targeted: %s" % current_target)


## Callback: Combate terminado
func _on_combat_ended(result: String) -> void:
	print("[PlayerCombatController] Combat ended: %s" % result)
	
	# Limpiar estado
	_set_input_enabled(false)
	current_target = ""
	current_target_index = 0
	available_targets.clear()


## Callback: Personaje murió
func _on_character_died(character_id: String) -> void:
	# Si era un enemigo, actualizar lista de targets
	if character_id in available_targets:
		print("[PlayerCombatController] Target died: %s" % character_id)
		_update_available_targets()


# ============================================
# GESTIÓN DE INPUT
# ============================================

## Habilita o deshabilita el input
func _set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	
	# Emitir evento para UI (botones, indicadores, etc.)
	# TODO: Implementar cuando tengamos UI completa
	# EventBus.emit_signal("player_input_changed", enabled)


## Retorna si el input está habilitado
func is_input_enabled() -> bool:
	return input_enabled


# ============================================
# API PÚBLICA (para UI)
# ============================================

## Solicita usar una habilidad (llamado desde UI)
func request_skill(skill_id: String) -> void:
	if not input_enabled:
		print("[PlayerCombatController] Input disabled, cannot use skill")
		return
	
	_request_skill_use(skill_id)


## Solicita cambiar de target (llamado desde UI)
func request_cycle_target() -> void:
	if not input_enabled:
		return
	
	_cycle_target()


## Retorna lista de targets disponibles (para UI)
func get_available_targets() -> Array[String]:
	return available_targets.duplicate()
