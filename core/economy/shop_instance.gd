class_name ShopInstance
extends RefCounted

## ShopInstance - Estado vivo de una tienda durante la partida
## Responsabilidades:
## - Mantener presupuesto actual
## - Mantener inventario actual
## - Validar capacidad (slots, budget)
## - NO calcular precios
## - NO ejecutar transferencias

## Referencia a la definición estática
var definition: ShopDefinition

## Presupuesto actual en oro
var budget: int = 0

## Inventario actual: { item_id: String -> ShopItemState }
var inventory: Dictionary = {}

## Número máximo de slots (copiado de definition para facilitar acceso)
var max_slots: int = 10


## Constructor
func _init(shop_def: ShopDefinition):
	if shop_def == null:
		push_error("[ShopInstance] ShopDefinition cannot be null")
		return
	
	if not shop_def.validate():
		push_error("[ShopInstance] ShopDefinition validation failed")
		return
	
	definition = shop_def
	budget = shop_def.initial_budget
	max_slots = shop_def.max_slots
	
	# Cargar inventario inicial
	_initialize_inventory()


## Inicializa el inventario desde la definición
func _initialize_inventory():
	for item_id in definition.initial_inventory.keys():
		var quantity = definition.initial_inventory[item_id]
		if quantity > 0:
			inventory[item_id] = ShopItemState.new(item_id, quantity)


## ============================================
## VALIDACIONES
## ============================================

## ¿Puede la tienda comprar este item? (Jugador → Tienda)
func can_buy_from_player(item_id: String, _quantity: int, price: int) -> Dictionary:
	# Verificar presupuesto
	if not definition.infinite_budget:
		if budget < price:
			return {
				"can": false,
				"reason": "NO_BUDGET",
				"context": "Shop has %d gold, needs %d" % [budget, price]
			}
	
	# Verificar slots disponibles si es un item nuevo
	if not inventory.has(item_id):
		if inventory.size() >= max_slots:
			return {
				"can": false,
				"reason": "NO_SLOTS",
				"context": "Shop has %d/%d slots occupied" % [inventory.size(), max_slots]
			}
	
	# Verificar tags aceptados (si aplica)
	if not definition.accepted_tags.is_empty():
		# TODO: Validar con ItemRegistry cuando esté disponible
		pass
	
	return {"can": true}


## ¿Puede la tienda vender este item? (Tienda → Jugador)
func can_sell_to_player(item_id: String, quantity: int) -> Dictionary:
	# Verificar que existe el item
	if not inventory.has(item_id):
		return {
			"can": false,
			"reason": "NO_STOCK",
			"context": "Item '%s' not in shop inventory" % item_id
		}
	
	# Verificar cantidad disponible
	var item_state = inventory[item_id] as ShopItemState
	if item_state.quantity < quantity:
		return {
			"can": false,
			"reason": "INSUFFICIENT_STOCK",
			"context": "Shop has %d, requested %d" % [item_state.quantity, quantity]
		}
	
	return {"can": true}


## ============================================
## OPERACIONES DE INVENTARIO
## ============================================

## Añade un item al inventario (Jugador → Tienda)
## Retorna true si éxito
func add_item(item_id: String, quantity: int) -> bool:
	if inventory.has(item_id):
		# Ya existe, incrementar cantidad
		inventory[item_id].add(quantity)
	else:
		# Nuevo item, crear slot
		if inventory.size() >= max_slots:
			push_error("[ShopInstance] Cannot add item: no slots available")
			return false
		
		inventory[item_id] = ShopItemState.new(item_id, quantity)
	
	return true


## Remueve un item del inventario (Tienda → Jugador)
## Retorna true si éxito
func remove_item(item_id: String, quantity: int) -> bool:
	if not inventory.has(item_id):
		push_error("[ShopInstance] Cannot remove item '%s': not in inventory" % item_id)
		return false
	
	var item_state = inventory[item_id] as ShopItemState
	
	# Reducir cantidad
	var still_has_stock = item_state.remove(quantity)
	
	# Si llegó a 0, eliminar slot
	if not still_has_stock:
		inventory.erase(item_id)
	
	return true


## Obtiene el estado de un item
func get_item_state(item_id: String) -> ShopItemState:
	return inventory.get(item_id, null)


## Obtiene la cantidad de un item
func get_item_quantity(item_id: String) -> int:
	if inventory.has(item_id):
		return inventory[item_id].quantity
	return 0


## ============================================
## OPERACIONES DE PRESUPUESTO
## ============================================

## Incrementa el presupuesto (Tienda vende)
func add_budget(amount: int) -> void:
	budget += amount


## Reduce el presupuesto (Tienda compra)
## Retorna true si había suficiente presupuesto
func subtract_budget(amount: int) -> bool:
	if definition.infinite_budget:
		return true
	
	if budget < amount:
		return false
	
	budget -= amount
	return true


## ============================================
## SAVE / LOAD
## ============================================

## Convierte a Dictionary para persistencia
func to_dict() -> Dictionary:
	var inventory_dict = {}
	for item_id in inventory.keys():
		inventory_dict[item_id] = inventory[item_id].to_dict()
	
	return {
		"shop_id": definition.id,
		"budget": budget,
		"max_slots": max_slots,
		"inventory": inventory_dict
	}


## Crea ShopInstance desde Dictionary
static func from_dict(data: Dictionary, shop_def: ShopDefinition) -> ShopInstance:
	var instance = ShopInstance.new(shop_def)
	
	instance.budget = data.get("budget", shop_def.initial_budget)
	instance.max_slots = data.get("max_slots", shop_def.max_slots)
	
	# Restaurar inventario
	instance.inventory.clear()
	var inventory_data = data.get("inventory", {})
	for item_id in inventory_data.keys():
		var item_state = ShopItemState.from_dict(inventory_data[item_id])
		if item_state.validate():
			instance.inventory[item_id] = item_state
	
	return instance


## Valida la integridad del estado
func validate() -> bool:
	if budget < 0 and not definition.infinite_budget:
		push_error("[ShopInstance] Budget cannot be negative: %d" % budget)
		return false
	
	if inventory.size() > max_slots:
		push_warning("[ShopInstance] Inventory size (%d) exceeds max_slots (%d) - legacy save?" % [inventory.size(), max_slots])
		# No es error crítico, solo warning
	
	# Validar cada item
	for item_id in inventory.keys():
		var item_state = inventory[item_id] as ShopItemState
		if not item_state.validate():
			return false
	
	return true


## ============================================
## DEBUG
## ============================================

## Imprime el estado actual
func print_state():
	print("\n[ShopInstance] %s" % definition.id)
	print("  Budget: %d gold" % budget)
	print("  Slots: %d/%d" % [inventory.size(), max_slots])
	print("  Inventory:")
	for item_id in inventory.keys():
		print("    - %s" % inventory[item_id])


func _to_string() -> String:
	return "ShopInstance(id=%s, budget=%d, items=%d/%d)" % [
		definition.id,
		budget,
		inventory.size(),
		max_slots
	]
