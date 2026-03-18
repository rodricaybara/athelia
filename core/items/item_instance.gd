class_name ItemInstance
extends RefCounted

## ItemInstance - Instancia dinámica de un ítem en inventario
## Representa el ESTADO mutable de un ítem (cantidad, custom state)
##
## IMPORTANTE: ItemInstance NO ejecuta lógica, solo mantiene estado

## Referencia a la definición inmutable
var definition: ItemDefinition

## Cantidad actual (1 a max_stack)
var quantity: int = 1

## Estado personalizado para ítems únicos
## Ejemplos: durabilidad actual, enchantments, propietario
var custom_state: Dictionary = {}


## Constructor
func _init(def: ItemDefinition, qty: int = 1, state: Dictionary = {}):
	if def == null:
		push_error("[ItemInstance] definition cannot be null")
		return
	
	definition = def
	quantity = _clamp_quantity(qty)
	custom_state = state.duplicate()


## Clampea la cantidad según las reglas del ítem
func _clamp_quantity(qty: int) -> int:
	if definition.stackable:
		return clampi(qty, 1, definition.max_stack)
	else:
		return 1  # Items no stackables siempre quantity = 1


## ¿Puede stackearse con otra instancia?
func can_stack_with(other: ItemInstance) -> bool:
	# Verificar que es stackable
	if not definition.stackable:
		return false
	
	# Verificar que es el mismo ítem
	if definition.id != other.definition.id:
		return false
	
	# No stackear si tienen custom_state diferente
	# (ítems con estado único no se apilan)
	if not custom_state.is_empty() or not other.custom_state.is_empty():
		return false
	
	return true


## Añade cantidad respetando max_stack
## Retorna la cantidad realmente añadida
func add_quantity(amount: int) -> int:
	if amount <= 0:
		return 0
	
	var old_qty = quantity
	quantity = _clamp_quantity(quantity + amount)
	return quantity - old_qty


## Resta cantidad
## Retorna la cantidad realmente restada
func remove_quantity(amount: int) -> int:
	if amount <= 0:
		return 0
	
	var removed = mini(quantity, amount)
	quantity -= removed
	return removed


## ¿Está vacío? (quantity <= 0)
func is_empty() -> bool:
	return quantity <= 0


## ¿Está lleno? (quantity == max_stack)
func is_full() -> bool:
	if not definition.stackable:
		return true
	
	return quantity >= definition.max_stack


## Calcula el peso total de esta instancia
func get_total_weight() -> float:
	return definition.get_total_weight(quantity)


## Calcula el valor total de esta instancia
func get_total_value() -> int:
	return definition.base_value * quantity


## Debug
func _to_string() -> String:
	if custom_state.is_empty():
		return "ItemInstance(%s x%d)" % [definition.id, quantity]
	else:
		return "ItemInstance(%s x%d, state=%s)" % [definition.id, quantity, custom_state]
