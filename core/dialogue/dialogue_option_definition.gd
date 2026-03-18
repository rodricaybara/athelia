class_name DialogueOptionDefinition
extends Resource

## DialogueOptionDefinition - Opción seleccionable en un diálogo
##
## Representa una opción que el jugador puede elegir
## Puede tener condiciones narrativas y disparar eventos

## Identificador único de la opción
@export var id: String = ""

## Clave de localización para el texto de la opción
@export var text_key: String = ""

## Flags narrativos requeridos para que la opción esté disponible
@export var required_flags: Array[String] = []

## Flags narrativos que bloquean esta opción
@export var blocked_flags: Array[String] = []

## Eventos narrativos a disparar cuando se selecciona esta opción
@export var narrative_events: Array[String] = []

## ID del siguiente nodo (null = termina el diálogo)
@export var next_node_id: String = ""


## Valida que la opción sea coherente
func validate() -> bool:
	if id.is_empty():
		push_error("[DialogueOptionDefinition] id cannot be empty")
		return false
	
	if text_key.is_empty():
		push_error("[DialogueOptionDefinition] text_key cannot be empty")
		return false
	
	return true


## Verifica si esta opción está disponible según el estado narrativo
func is_available() -> bool:
	# Verificar flags requeridos
	for flag in required_flags:
		if not Narrative.has_flag(flag):
			return false
	
	# Verificar flags bloqueados
	for flag in blocked_flags:
		if Narrative.has_flag(flag):
			return false
	
	return true


## ¿Esta opción termina el diálogo?
func ends_dialogue() -> bool:
	return next_node_id.is_empty()


## Debug
func _to_string() -> String:
	return "DialogueOption(id=%s, text=%s, next=%s)" % [
		id,
		text_key,
		next_node_id if not next_node_id.is_empty() else "END"
	]
