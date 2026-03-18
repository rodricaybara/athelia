class_name NarrativeSystem
extends Node

## NarrativeSystem - Gestor centralizado del estado narrativo
## Singleton: /root/Narrative
##
## Responsabilidad: Mantener y exponer el estado narrativo del juego
## - Flags narrativos
## - Variables del mundo
## - Eventos completados
##
## IMPORTANTE (Spike): Este sistema es 100% PASIVO
## - NO decide progresión narrativa
## - NO ejecuta lógica compleja
## - NO limpia flags automáticamente
## - Solo set/get/check

## Estado narrativo actual
var _state: NarrativeState


func _ready():
	_state = NarrativeState.new()
	print("[NarrativeSystem] Initialized - Passive narrative state ready")


# ==============================================
# FLAGS
# ==============================================

## Activa un flag narrativo
func set_flag(flag_id: String, value: bool = true) -> void:
	var was_set = _state.has_flag(flag_id)
	_state.set_flag(flag_id, value)
	
	# Emitir evento
	if value and not was_set:
		EventBus.narrative_flag_set.emit(flag_id)
		print("[NarrativeSystem] Flag SET: %s" % flag_id)
	elif not value and was_set:
		EventBus.narrative_flag_cleared.emit(flag_id)
		print("[NarrativeSystem] Flag CLEARED: %s" % flag_id)
	
	EventBus.narrative_state_changed.emit()


## Obtiene el valor de un flag
func get_flag(flag_id: String) -> bool:
	return _state.get_flag(flag_id)


## Alias para has_flag (más semántico)
func has_flag(flag_id: String) -> bool:
	return _state.has_flag(flag_id)


## Desactiva un flag
func clear_flag(flag_id: String) -> void:
	if _state.has_flag(flag_id):
		_state.clear_flag(flag_id)
		EventBus.narrative_flag_cleared.emit(flag_id)
		EventBus.narrative_state_changed.emit()
		print("[NarrativeSystem] Flag CLEARED: %s" % flag_id)


## Obtiene todos los flags activos
func get_active_flags() -> Array[String]:
	return _state.get_active_flags()


# ==============================================
# VARIABLES
# ==============================================

## Establece una variable narrativa
func set_variable(var_id: String, value: Variant) -> void:
	_state.set_variable(var_id, value)
	EventBus.narrative_variable_changed.emit(var_id, value)
	EventBus.narrative_state_changed.emit()
	print("[NarrativeSystem] Variable SET: %s = %s" % [var_id, value])


## Obtiene una variable narrativa
func get_variable(var_id: String, default_value: Variant = null) -> Variant:
	return _state.get_variable(var_id, default_value)


## ¿Tiene esta variable?
func has_variable(var_id: String) -> bool:
	return _state.has_variable(var_id)


## Incrementa una variable numérica
func increment_variable(var_id: String, amount: float = 1.0) -> void:
	_state.increment_variable(var_id, amount)
	var new_value = _state.get_variable(var_id)
	EventBus.narrative_variable_changed.emit(var_id, new_value)
	EventBus.narrative_state_changed.emit()
	print("[NarrativeSystem] Variable INCREMENTED: %s = %s" % [var_id, new_value])


## Decrementa una variable numérica
func decrement_variable(var_id: String, amount: float = 1.0) -> void:
	_state.decrement_variable(var_id, amount)
	var new_value = _state.get_variable(var_id)
	EventBus.narrative_variable_changed.emit(var_id, new_value)
	EventBus.narrative_state_changed.emit()
	print("[NarrativeSystem] Variable DECREMENTED: %s = %s" % [var_id, new_value])


# ==============================================
# EVENTOS
# ==============================================

## Registra un evento narrativo como completado
func register_event(event_id: String) -> void:
	if not _state.has_completed_event(event_id):
		_state.register_event(event_id)
		EventBus.narrative_event_triggered.emit(event_id)
		EventBus.narrative_state_changed.emit()
		print("[NarrativeSystem] Event REGISTERED: %s" % event_id)


## ¿Se ha completado este evento?
func has_completed_event(event_id: String) -> bool:
	return _state.has_completed_event(event_id)


## Obtiene todos los eventos completados
func get_completed_events() -> Array[String]:
	return _state.get_completed_events()


# ==============================================
# DEBUG
# ==============================================

## Imprime el estado actual
func print_state() -> void:
	_state.print_state()


## Limpia todo el estado (solo para testing)
func clear_all() -> void:
	_state.clear_all()
	EventBus.narrative_state_changed.emit()
	print("[NarrativeSystem] State CLEARED")


# ==============================================
# SAVE/LOAD
# ==============================================

## Obtiene snapshot del estado para guardar
func get_save_state() -> Dictionary:
	return _state.to_dict()


## Carga estado desde snapshot
func load_save_state(data: Dictionary) -> void:
	_state.from_dict(data)
	EventBus.narrative_state_changed.emit()
	print("[NarrativeSystem] State LOADED: %s" % _state)

# ==============================================
# NARRATIVE EVENTS (FASE 3)
# ==============================================

## Aplica un evento narrativo manualmente
func apply_event(event_id: String) -> bool:
	var event = NarrativeDB.get_event(event_id)
	if not event:
		push_warning("[NarrativeSystem] Event not found: %s" % event_id)
		return false
	
	print("[NarrativeSystem] Applying event: %s" % event_id)
	event.apply_to_narrative()
	
	return true


## Aplica múltiples eventos
func apply_events(event_ids: Array[String]) -> void:
	for event_id in event_ids:
		apply_event(event_id)

# ==============================================
# MÉTODOS AUXILIARES PARA CHECKPOINTS
# ==============================================

## Obtiene todas las variables (para consolidación)
func get_all_variables() -> Dictionary:
	return _state.variables.duplicate()


## Limpia una variable específica
func clear_variable(variable_name: String) -> void:
	if _state.variables.has(variable_name):
		_state.variables.erase(variable_name)
		EventBus.narrative_variable_changed.emit(variable_name, null)
		EventBus.narrative_state_changed.emit()
