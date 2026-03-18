class_name NarrativeState
extends RefCounted

## NarrativeState - Contenedor de estado narrativo del juego
## 
## Responsabilidad: Mantener el estado narrativo abstracto
## NO contiene lógica de progresión ni validación compleja
## Es 100% pasivo durante el spike

## Flags narrativos: { flag_id: String -> bool }
## Ejemplo: { "PRINCE_MET": true, "ACADEMY_JOINED": false }
var flags: Dictionary = {}

## Variables narrativas: { var_id: String -> Variant }
## Ejemplo: { "reputation": 50, "karma": -10 }
var variables: Dictionary = {}

## Eventos narrativos completados
var completed_events: Array[String] = []


## Constructor
func _init():
	pass


# ==============================================
# FLAGS
# ==============================================

## Activa un flag
func set_flag(flag_id: String, value: bool = true) -> void:
	flags[flag_id] = value


## Obtiene el valor de un flag
func get_flag(flag_id: String) -> bool:
	return flags.get(flag_id, false)


## ¿Tiene este flag activo?
func has_flag(flag_id: String) -> bool:
	return flags.get(flag_id, false)


## Desactiva un flag (lo elimina)
func clear_flag(flag_id: String) -> void:
	flags.erase(flag_id)


## Obtiene todos los flags activos
func get_active_flags() -> Array[String]:
	var active: Array[String] = []
	for flag_id in flags.keys():
		if flags[flag_id]:
			active.append(flag_id)
	return active


# ==============================================
# VARIABLES
# ==============================================

## Establece una variable narrativa
func set_variable(var_id: String, value: Variant) -> void:
	variables[var_id] = value


## Obtiene una variable narrativa
func get_variable(var_id: String, default_value: Variant = null) -> Variant:
	return variables.get(var_id, default_value)


## ¿Tiene esta variable?
func has_variable(var_id: String) -> bool:
	return variables.has(var_id)


## Incrementa una variable numérica
func increment_variable(var_id: String, amount: float = 1.0) -> void:
	var current = get_variable(var_id, 0.0)
	set_variable(var_id, current + amount)


## Decrementa una variable numérica
func decrement_variable(var_id: String, amount: float = 1.0) -> void:
	var current = get_variable(var_id, 0.0)
	set_variable(var_id, current - amount)


# ==============================================
# EVENTOS
# ==============================================

## Registra un evento como completado
func register_event(event_id: String) -> void:
	if not has_completed_event(event_id):
		completed_events.append(event_id)


## ¿Se ha completado este evento?
func has_completed_event(event_id: String) -> bool:
	return event_id in completed_events


## Obtiene todos los eventos completados
func get_completed_events() -> Array[String]:
	return completed_events.duplicate()


# ==============================================
# VALIDACIÓN Y DEBUG
# ==============================================

## Valida que el estado sea coherente (básico)
func validate() -> bool:
	# En el spike, no hay validación compleja
	return true


## Limpia todo el estado (útil para testing)
func clear_all() -> void:
	flags.clear()
	variables.clear()
	completed_events.clear()


## Imprime el estado actual
func print_state() -> void:
	print("\n[NarrativeState] Current State:")
	
	print("  Flags (%d):" % flags.size())
	for flag_id in flags.keys():
		if flags[flag_id]:
			print("    - %s" % flag_id)
	
	print("  Variables (%d):" % variables.size())
	for var_id in variables.keys():
		print("    - %s = %s" % [var_id, variables[var_id]])
	
	print("  Completed Events (%d):" % completed_events.size())
	for event_id in completed_events:
		print("    - %s" % event_id)
	
	print("")


# ==============================================
# SAVE/LOAD
# ==============================================

## Convierte a Dictionary para save
func to_dict() -> Dictionary:
	return {
		"flags": flags.duplicate(),
		"variables": variables.duplicate(),
		"completed_events": completed_events.duplicate()
	}


## Carga desde Dictionary
func from_dict(data: Dictionary) -> void:
	flags = data.get("flags", {}).duplicate()
	variables = data.get("variables", {}).duplicate()
	completed_events = data.get("completed_events", []).duplicate()


## Debug
func _to_string() -> String:
	return "NarrativeState(flags=%d, vars=%d, events=%d)" % [
		flags.size(),
		variables.size(),
		completed_events.size()
	]
