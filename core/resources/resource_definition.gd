class_name ResourceDefinition
extends Resource

## ResourceDefinition - Definición inmutable de un recurso
## Parte del ResourceSystem
## Representa QUÉ ES un recurso (vida, stamina, oro, etc.)

## Identificador único del recurso
@export var id: String = ""

## Clave de localización para el nombre
@export var name_key: String = ""

## Clave de localización para la descripción
@export var description_key: String = ""

## Valor máximo base (antes de modificadores)
@export var max_base: float = 100.0

## Tasa de regeneración por segundo (0 = no regenera)
@export var regen_rate: float = 0.0

## Delay en segundos antes de iniciar regeneración
## (ej: stamina empieza a regenerar 2s después del último uso)
@export var regen_delay: float = 0.0

## ¿Puede ser negativo? (para deudas, penalizaciones, etc.)
@export var allow_negative: bool = false

## ¿Es un recurso "infinito"? (como stamina de enemigos)
@export var is_infinite: bool = false

## Color para debug UI
@export var debug_color: Color = Color.WHITE

## IA-0b — Recuperación fija por ronda DENTRO de combate (en unidades del recurso).
## GameLoop la aplica al empezar cada ronda salvo la primera. 0 = no recupera.
## Es independiente de regen_rate, que es regeneración continua en tiempo real y
## queda suspendida durante el combate. Se lee del .tres (@export): no hay from_dict.
@export var combat_regen_per_round: float = 0.0


## Valida que la definición sea coherente
func validate() -> bool:
	if id.is_empty():
		push_error("ResourceDefinition: id cannot be empty")
		return false
	
	if max_base <= 0 and not is_infinite:
		push_error("ResourceDefinition: max_base must be > 0 for finite resources")
		return false
	
	if regen_rate < 0:
		push_error("ResourceDefinition: regen_rate cannot be negative")
		return false
	
	if combat_regen_per_round < 0:
		push_error("ResourceDefinition: combat_regen_per_round cannot be negative")
		return false

	if regen_delay < 0:
		push_error("ResourceDefinition: regen_delay cannot be negative")
		return false
	
	return true


## Crea una copia de esta definición (útil para modificadores)
func duplicate_definition() -> ResourceDefinition:
	var copy = ResourceDefinition.new()
	copy.id = id
	copy.name_key = name_key
	copy.description_key = description_key
	copy.max_base = max_base
	copy.regen_rate = regen_rate
	copy.regen_delay = regen_delay
	copy.allow_negative = allow_negative
	copy.is_infinite = is_infinite
	copy.combat_regen_per_round = combat_regen_per_round
	copy.debug_color = debug_color
	return copy


## Método de debug (llamado automáticamente por Godot al convertir a String)
func _to_string() -> String:
	return "ResourceDefinition(id=%s, max=%s, regen=%s/%ss)" % [
		id, max_base, regen_rate, regen_delay
	]
