class_name DialogueNodeDefinition
extends Resource

## DialogueNodeDefinition - Nodo individual de diálogo
##
## Representa un momento del diálogo con texto y opciones

## Identificador único del nodo
@export var id: String = ""

## ID del personaje que habla
@export var speaker_id: String = ""

## Clave de localización para el texto del diálogo
@export var text_key: String = ""

## ID del portrait a mostrar
@export var portrait_id: String = ""

## Opciones disponibles en este nodo
var options: Array[DialogueOptionDefinition] = []


## Valida que el nodo sea coherente
func validate() -> bool:
	if id.is_empty():
		push_error("[DialogueNodeDefinition] id cannot be empty")
		return false
	
	if speaker_id.is_empty():
		push_error("[DialogueNodeDefinition] speaker_id cannot be empty")
		return false
	
	if text_key.is_empty():
		push_error("[DialogueNodeDefinition] text_key cannot be empty")
		return false
	
	# Validar todas las opciones
	for option in options:
		if not option.validate():
			push_error("[DialogueNodeDefinition] Invalid option in node %s" % id)
			return false
	
	return true


## Obtiene las opciones disponibles según el estado narrativo
func get_available_options() -> Array[DialogueOptionDefinition]:
	var available: Array[DialogueOptionDefinition] = []
	
	for option in options:
		if option.is_available():
			available.append(option)
	
	return available


## Obtiene una opción por ID
func get_option(option_id: String) -> DialogueOptionDefinition:
	for option in options:
		if option.id == option_id:
			return option
	
	return null


## ¿Este nodo tiene opciones?
func has_options() -> bool:
	return not options.is_empty()


## Debug
func _to_string() -> String:
	return "DialogueNode(id=%s, speaker=%s, options=%d)" % [
		id,
		speaker_id,
		options.size()
	]
