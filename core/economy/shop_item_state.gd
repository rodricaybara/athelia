class_name ShopItemState
extends RefCounted

## ShopItemState - Representa un slot individual en el inventario de una tienda
## Responsabilidades:
## - Mantener item_id y quantity
## - Validar integridad (quantity >= 1)
## - NO ejecutar lógica de precio ni transferencia

## ID del item (referencia a ItemDefinition)
var item_id: String = ""

## Cantidad disponible (siempre >= 1)
var quantity: int = 1


## Constructor
func _init(p_item_id: String = "", p_quantity: int = 1):
	item_id = p_item_id
	quantity = max(1, p_quantity)  # Nunca menor que 1


## Incrementa la cantidad
func add(amount: int) -> void:
	quantity += amount


## Reduce la cantidad
## Retorna true si todavía hay stock, false si llegó a 0
func remove(amount: int) -> bool:
	quantity -= amount
	return quantity > 0


## Valida que el estado sea coherente
func validate() -> bool:
	if item_id.is_empty():
		push_error("[ShopItemState] item_id cannot be empty")
		return false
	
	if quantity < 1:
		push_error("[ShopItemState] quantity must be >= 1, got %d" % quantity)
		return false
	
	return true


## Convierte a Dictionary para save/load
func to_dict() -> Dictionary:
	return {
		"item_id": item_id,
		"quantity": quantity
	}


## Crea desde Dictionary
static func from_dict(data: Dictionary) -> ShopItemState:
	var state = ShopItemState.new()
	state.item_id = data.get("item_id", "")
	state.quantity = data.get("quantity", 1)
	return state


## Debug
func _to_string() -> String:
	return "ShopItemState(item=%s, qty=%d)" % [item_id, quantity]
