class_name CheckpointDefinition
extends Resource

## CheckpointDefinition - Definición estática de un checkpoint narrativo
##
## Un checkpoint marca el fin de un acto y define:
## - Qué vectores de valor se consolidan
## - Qué flags se preservan (resto se limpia)
## - Qué variables se preservan
## - Estado inicial para el siguiente acto

## Identificador único del checkpoint
@export var id: String = ""

## Descripción del checkpoint (debug)
@export var description: String = ""

## Vectores de valor a consolidar
## Ejemplo: ["reputation", "community", "cynicism"]
@export var accumulated_vectors: Array[String] = []

## Flags que se preservan (resto se elimina)
## Ejemplo: ["PRINCE_MET", "ACADEMY_JOINED"]
@export var flags_preserved: Array[String] = []

## Variables que se preservan
## Ejemplo: ["gold", "reputation"]
@export var variables_preserved: Array[String] = []

## Valores iniciales para el siguiente acto
## Ejemplo: {"magic_affinity": 0, "new_stat": 10}
@export var initial_values: Dictionary = {}

## Flags iniciales para el siguiente acto
## Ejemplo: ["TUTORIAL_COMPLETE", "ACT2_START"]
@export var initial_flags: Array[String] = []

## Rangos de normalización para vectores
## Ejemplo: {"reputation": {"min": -100, "max": 100}}
@export var normalization_ranges: Dictionary = {}


## Valida que el checkpoint sea coherente
func validate() -> bool:
	if id.is_empty():
		push_error("[CheckpointDefinition] id cannot be empty")
		return false
	
	# Validar rangos de normalización
	for vector in normalization_ranges.keys():
		var range_data = normalization_ranges[vector]
		if not range_data.has("min") or not range_data.has("max"):
			push_error("[CheckpointDefinition] Invalid normalization range for %s" % vector)
			return false
		
		if range_data["min"] >= range_data["max"]:
			push_error("[CheckpointDefinition] min must be < max for %s" % vector)
			return false
	
	return true


## ¿Este checkpoint normaliza un vector específico?
func has_normalization_for(vector: String) -> bool:
	return normalization_ranges.has(vector)


## Obtiene el rango de normalización para un vector
func get_normalization_range(vector: String) -> Dictionary:
	if normalization_ranges.has(vector):
		return normalization_ranges[vector]
	
	return {}


## ¿Este checkpoint preserva un flag específico?
func preserves_flag(flag: String) -> bool:
	return flag in flags_preserved


## ¿Este checkpoint preserva una variable específica?
func preserves_variable(variable: String) -> bool:
	return variable in variables_preserved


## Debug
func _to_string() -> String:
	return "CheckpointDef(id=%s, vectors=%d, flags=%d)" % [
		id,
		accumulated_vectors.size(),
		flags_preserved.size()
	]
