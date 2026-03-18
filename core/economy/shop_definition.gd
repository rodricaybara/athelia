class_name ShopDefinition
extends Resource

## ShopDefinition - Definición estática de una tienda
## Responsabilidades:
## - Describir QUÉ ES una tienda
## - Definir reglas económicas base
## - NO contener estado mutable

## Identificador único de la tienda
@export var id: String = ""

## Clave de localización para el nombre
@export var name_key: String = ""

## Clave de localización para la descripción (opcional)
@export var description_key: String = ""

## Presupuesto inicial en oro
@export var initial_budget: int = 1000

## Número máximo de slots (tipos de item distintos)
@export var max_slots: int = 10

## Factor de precio al COMPRAR al jugador (Jugador → Tienda)
## Ejemplo: 0.3 = tienda paga 30% del valor base
@export_range(0.0, 1.0) var buy_price_factor: float = 0.3

## Factor de precio al VENDER al jugador (Tienda → Jugador)
## Ejemplo: 0.8 = tienda vende a 80% del valor base
@export_range(0.0, 2.0) var sell_price_factor: float = 0.8

## Items iniciales en el inventario (opcional)
## Format: { "item_id": quantity }
@export var initial_inventory: Dictionary = {}

## Tags de items que esta tienda acepta comprar (vacío = todos)
## Ejemplo: ["weapon", "armor"]
@export var accepted_tags: Array[String] = []

## ¿La tienda tiene presupuesto infinito?
@export var infinite_budget: bool = false


## Valida que la definición sea coherente
func validate() -> bool:
	if id.is_empty():
		push_error("[ShopDefinition] id cannot be empty")
		return false
	
	if name_key.is_empty():
		push_error("[ShopDefinition] name_key cannot be empty")
		return false
	
	if initial_budget < 0:
		push_error("[ShopDefinition] initial_budget cannot be negative")
		return false
	
	if max_slots < 1:
		push_error("[ShopDefinition] max_slots must be >= 1")
		return false
	
	if buy_price_factor < 0.0 or buy_price_factor > 1.0:
		push_error("[ShopDefinition] buy_price_factor must be 0.0-1.0")
		return false
	
	if sell_price_factor <= 0.0:
		push_error("[ShopDefinition] sell_price_factor must be > 0.0")
		return false
	
	return true


## Debug
func _to_string() -> String:
	return "ShopDefinition(id=%s, budget=%d, slots=%d)" % [id, initial_budget, max_slots]
