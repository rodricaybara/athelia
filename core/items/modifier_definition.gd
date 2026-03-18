class_name ModifierDefinition
extends Resource

## ModifierDefinition - Modificador declarativo para ítems
## NO ejecuta lógica, solo describe efectos potenciales
##
## Ejemplo:
##   target: "resource.stamina"
##   operation: "add"
##   value: 50.0
##   condition: "on_use"

## A qué afecta el modificador
## Ejemplos: "resource.stamina", "resource.health", "stat.strength"
@export var target: String = ""

## Operación a realizar
@export_enum("add", "mul", "override") var operation: String = "add"

## Magnitud del efecto
@export var value: float = 0.0

## Cuándo se aplica
## "on_use" = al usar el ítem
## "equipped" = mientras está equipado (futuro)
## "always" = efecto permanente (futuro)
@export var condition: String = "on_use"

## Duración del modificador.
## "permanent"       → se aplica y persiste (comportamiento actual)
## "next_skill_roll" → se consume automáticamente en el próximo roll de skill
##                     Solo válido cuando target_type es "skill"
@export_enum("permanent", "next_skill_roll") var duration_type: String = "permanent"

## Skill que consume este modificador cuando duration_type = "next_skill_roll"
## Vacío = cualquier roll de skill lo consume (raramente útil)
## Ejemplo: "skill.exploration.lockpick" — solo se consume al tirar lockpick
@export var duration_skill_target: String = ""

## Valida que el modificador sea coherente
func validate() -> bool:
	if target.is_empty():
		push_error("[ModifierDefinition] target cannot be empty")
		return false
	
	if not operation in ["add", "mul", "override"]:
		push_error("[ModifierDefinition] invalid operation: %s (must be add/mul/override)" % operation)
		return false
	
	if condition.is_empty():
		push_error("[ModifierDefinition] condition cannot be empty")
		return false
	
	return true


## Comprueba si el modifier afecta a recursos
func targets_resource() -> bool:
	return target.begins_with("resource.")


## Obtiene el ID del recurso (si aplica)
func get_resource_id() -> String:
	if targets_resource():
		return target.replace("resource.", "")
	return ""


## Debug
func _to_string() -> String:
	return "Modifier(%s %s %.1f when %s)" % [target, operation, value, condition]
