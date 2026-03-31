class_name WorldObjectPanelViewModel
extends Node

## WorldObjectPanelViewModel
## Gestiona el estado del panel de interacción con objetos del mundo.
##
## Responsabilidades:
##   - Mantener el estado explícito del panel (enum PanelState)
##   - Cargar las interacciones disponibles desde WorldObjectSystem
##   - Emitir EventBus.world_object_action_chosen cuando el jugador elige
##   - Escuchar resultados del EventBus y actualizar el estado
##   - Exponer datos listos para renderizar (sin lógica en la View)
##
## NO hace:
##   - Renderizar nada
##   - Instanciar nodos
##   - Acceder a @onready de la View


# ============================================
# ENUM DE ESTADO
# ============================================

enum PanelState {
	HIDDEN,          ## Panel cerrado, no visible
	SHOWING,         ## Mostrando interacciones disponibles
	WAITING,         ## Acción emitida, esperando resolución del sistema
	SHOWING_RESULT,  ## Resultado recibido, botones actualizados
	DEPLETED,        ## Objeto agotado, sin más interacciones
}


# ============================================
# SEÑAL ÚNICA HACIA LA VIEW
# ============================================

## La View escucha solo esta señal.
## 'reason' permite refreshes parciales sin re-renderizar todo.
##
## Razones posibles:
##   "opened"        → construir botones de interacción
##   "waiting"       → deshabilitar botones
##   "result"        → mostrar feedback + refrescar botones
##   "depleted"      → mostrar mensaje de agotado + cerrar
##   "closed"        → ocultar panel
signal changed(reason: String)


# ============================================
# ESTADO PÚBLICO (read-only para la View)
# ============================================

var state: PanelState = PanelState.HIDDEN

## ID de la instancia del WorldObject activo
var current_instance_id: String = ""

## Entidad que interactúa (normalmente "player")
var current_entity_id: String = ""

## Nombre localizado del objeto para el título
var object_display_name: String = ""

## Interacciones disponibles (Array[InteractionDefinition])
var available_interactions: Array = []

## Feedback del último resultado
var result_feedback_key: String = ""
var result_outcome: String = ""  ## "critical" | "success" | "failure" | "fumble"
var result_info_key: String = ""


# ============================================
# REFERENCIAS INTERNAS
# ============================================

var _wo_system: Node = null


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	_wo_system = get_node_or_null("/root/WorldObjectSystem")
	if not _wo_system:
		push_error("[WorldObjectPanelVM] WorldObjectSystem not found")

	EventBus.world_object_interaction_requested.connect(_on_interaction_requested)
	EventBus.world_object_feedback_ready.connect(_on_feedback_ready)
	EventBus.world_object_state_changed.connect(_on_state_changed)

	print("[WorldObjectPanelVM] Ready")


# ============================================
# INTENCIONES (llamadas desde la View)
# ============================================

## El jugador ha pulsado un botón de interacción
func request_action(interaction_id: String) -> void:
	if state != PanelState.SHOWING and state != PanelState.SHOWING_RESULT:
		push_warning("[WorldObjectPanelVM] request_action ignorado en estado: %s" % _state_name())
		return

	state = PanelState.WAITING
	changed.emit("waiting")

	EventBus.world_object_action_chosen.emit(
		current_entity_id,
		current_instance_id,
		interaction_id
	)


## El jugador ha pulsado cerrar
func request_close() -> void:
	_reset()
	changed.emit("closed")


# ============================================
# CALLBACKS DEL EVENTBUS
# ============================================

func _on_interaction_requested(entity_id: String, instance_id: String) -> void:
	if not _wo_system:
		return

	current_entity_id   = entity_id
	current_instance_id = instance_id

	# Cargar interacciones disponibles
	available_interactions = _wo_system.get_available_interactions(instance_id, entity_id)

	if available_interactions.is_empty():
		return

	# Título del objeto
	var obj_state = _wo_system.get_state(instance_id)
	if obj_state and obj_state.definition:
		object_display_name = tr(obj_state.definition.display_name_key)
	else:
		object_display_name = instance_id

	# Limpiar resultado anterior
	result_feedback_key = ""
	result_outcome      = ""
	result_info_key     = ""

	state = PanelState.SHOWING
	changed.emit("opened")


func _on_feedback_ready(
		instance_id: String,
		_interaction_id: String,
		outcome: String,
		feedback_key: String,
		revealed_info_key: String) -> void:

	if instance_id != current_instance_id:
		return

	result_feedback_key = feedback_key
	result_outcome      = outcome
	result_info_key     = revealed_info_key

	# Comprobar si el objeto quedó agotado
	if _wo_system and _wo_system.is_depleted(current_instance_id):
		state = PanelState.DEPLETED
		changed.emit("depleted")
		return

	# Refrescar interacciones disponibles tras el cambio de estado del objeto
	available_interactions = _wo_system.get_available_interactions(
		current_instance_id, current_entity_id
	)

	state = PanelState.SHOWING_RESULT
	changed.emit("result")


func _on_state_changed(instance_id: String, _active_flags: Array) -> void:
	## WorldObjectSystem ya actualizó las flags.
	## El ViewModel no necesita reaccionar aquí porque _on_feedback_ready
	## llega justo después y recarga las interacciones disponibles.
	## Este callback existe por si en el futuro hay cambios de estado
	## sin feedback (ej: efecto de área que cambia el objeto sin acción directa).
	if instance_id != current_instance_id:
		return


# ============================================
# HELPERS
# ============================================

func _reset() -> void:
	state               = PanelState.HIDDEN
	current_instance_id = ""
	current_entity_id   = ""
	object_display_name = ""
	available_interactions.clear()
	result_feedback_key = ""
	result_outcome      = ""
	result_info_key     = ""


func _state_name() -> String:
	return PanelState.keys()[state]
