class_name WorldObjectDefinition
extends Resource

## WorldObjectDefinition - Definición inmutable de un objeto interactuable del mundo
## Equivalente a ItemDefinition o SkillDefinition en su rol arquitectural.
##
## Define QUÉ ES un objeto y QUÉ interacciones admite.
## NO contiene estado mutable (eso es WorldObjectState).
## NO ejecuta lógica (eso es WorldObjectSystem).

# ============================================
# IDENTIDAD
# ============================================

## Identificador único del tipo de objeto (ej: "chest_iron", "scroll_ancient")
@export var id: String = ""

## Clave de localización para el nombre mostrado en UI
@export var display_name_key: String = ""

## Clave de localización para la descripción
@export var description_key: String = ""


# ============================================
# ESTADO INICIAL
# ============================================

## Flags activas al crear una instancia de este objeto
## Ejemplo: ["locked"] para un cofre cerrado
@export var initial_flags: Array[String] = []


# ============================================
# INTERACCIONES
# ============================================

## Lista de interacciones posibles sobre este objeto
## Cada InteractionDefinition describe una acción + requisitos + outcomes
@export var interactions: Array[InteractionDefinition] = []


# ============================================
# VALIDACIÓN
# ============================================

func validate() -> bool:
	if id.is_empty():
		push_error("[WorldObjectDefinition] id cannot be empty")
		return false

	if display_name_key.is_empty():
		push_error("[WorldObjectDefinition] display_name_key cannot be empty (id: %s)" % id)
		return false

	for interaction in interactions:
		if not interaction.validate():
			push_error("[WorldObjectDefinition] Invalid interaction in object '%s'" % id)
			return false

	return true


# ============================================
# UTILIDADES
# ============================================

## Devuelve la InteractionDefinition por su id
func get_interaction(interaction_id: String) -> InteractionDefinition:
	for interaction in interactions:
		if interaction.id == interaction_id:
			return interaction
	return null
