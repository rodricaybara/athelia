extends Node

## EconomySystem - Orquestador central de economía y tiendas
## Responsabilidades:
## - Registrar y mantener ShopInstances
## - Validar transacciones
## - Orquestar flujos de compra/venta
## - Calcular precios (delegar a PriceCalculator)
## - Emitir eventos vía EventBus
##
## NO hace:
## - Aplicar cambios en ResourceSystem directamente (delega)
## - Ejecutar lógica de items
## - Contener lógica de UI

## Registro de tiendas: { shop_id: String -> ShopInstance }
var _shops: Dictionary = {}

## Referencias a sistemas
var resource_system: ResourceSystem
var inventory_system: Node  # InventorySystem


## ============================================
## INICIALIZACIÓN
## ============================================

func _ready():
	print("[EconomySystem] Initializing...")
	
	# Buscar sistemas
	resource_system = get_node_or_null("/root/Resources")
	if not resource_system:
		push_error("[EconomySystem] ResourceSystem not found!")
	
	# Buscar InventorySystem
	inventory_system = get_node_or_null("/root/Inventory")
	if not inventory_system:
		push_warning("[EconomySystem] InventorySystem not found in AutoLoad! Checking for alternative...")
		inventory_system = _find_inventory_system()
	
	if not inventory_system:
		push_error("[EconomySystem] InventorySystem not available!")
	else:
		print("[EconomySystem] InventorySystem found: %s" % inventory_system.name)
		_debug_inventory_system_methods()
	
	# Cargar definiciones de tiendas
	_load_shop_definitions()
	
	# ⭐ Conectar a eventos del EventBus
	EventBus.shop_open_requested.connect(_on_shop_open_requested)
	EventBus.shop_close_requested.connect(_on_shop_close_requested)
	EventBus.shop_buy_requested.connect(_on_shop_buy_requested)
	EventBus.shop_sell_requested.connect(_on_shop_sell_requested)
	
	print("[EconomySystem] Initialized with %d shops" % _shops.size())

## Busca InventorySystem en la escena (fallback)
func _find_inventory_system() -> Node:
	# Si está como componente del jugador
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("InventoryComponent"):
		return player.get_node("InventoryComponent")
	
	return null


## Carga todas las ShopDefinitions y crea ShopInstances
func _load_shop_definitions():
	var shop_dir = "res://data/shops/"
	var dir = DirAccess.open(shop_dir)
	
	if not dir:
		push_warning("[EconomySystem] Shop directory not found: %s" % shop_dir)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".tres"):
			var file_path = shop_dir + file_name
			_load_shop_from_resource(file_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()


## Carga una tienda desde un archivo .tres
func _load_shop_from_resource(file_path: String):
	var shop_def = load(file_path) as ShopDefinition
	
	if not shop_def:
		push_error("[EconomySystem] Failed to load shop: %s" % file_path)
		return
	
	if not shop_def.validate():
		push_error("[EconomySystem] Validation failed for: %s" % file_path)
		return
	
	# Crear instancia
	var shop_instance = ShopInstance.new(shop_def)
	_shops[shop_def.id] = shop_instance
	
	print("[EconomySystem] Loaded shop: %s" % shop_def.id)


## ============================================
## GESTIÓN DE TIENDAS
## ============================================

## Obtiene una ShopInstance
func get_shop(shop_id: String) -> ShopInstance:
	if not _shops.has(shop_id):
		push_warning("[EconomySystem] Shop not found: %s" % shop_id)
		return null
	
	return _shops[shop_id]


## Registra una tienda manualmente (para testing)
func register_shop(shop_instance: ShopInstance):
	if not shop_instance or not shop_instance.definition:
		push_error("[EconomySystem] Invalid shop instance")
		return
	
	_shops[shop_instance.definition.id] = shop_instance
	print("[EconomySystem] Registered shop: %s" % shop_instance.definition.id)


## ============================================
## APERTURA/CIERRE DE TIENDA
## ============================================

## Procesa solicitud de apertura de tienda
func open_shop(shop_id: String, entity_id: String):
	print("[EconomySystem] Opening shop: %s for %s" % [shop_id, entity_id])
	
	var shop = get_shop(shop_id)
	if not shop:
		EventBus.shop_trade_failed.emit(shop_id, "SHOP_NOT_FOUND", "Shop does not exist")
		return
	
	# TODO: Validar requisitos narrativos si aplican
	
	# Generar snapshot
	var snapshot = _create_shop_snapshot(shop, entity_id)
	
	# Emitir evento
	EventBus.shop_opened.emit(shop_id, snapshot)


## Procesa solicitud de cierre de tienda
func close_shop(shop_id: String):
	print("[EconomySystem] Closing shop: %s" % shop_id)
	EventBus.shop_closed.emit(shop_id)

## ============================================
## COMPRA (Tienda → Jugador)
## ============================================

## Procesa solicitud de compra
func buy_item(shop_id: String, item_id: String, quantity: int, entity_id: String = "player"):
	print("[EconomySystem] Buy request: shop=%s, item=%s, qty=%d" % [shop_id, item_id, quantity])
	
	var shop = get_shop(shop_id)
	if not shop:
		EventBus.shop_trade_failed.emit(shop_id, "SHOP_NOT_FOUND", "Shop does not exist")
		return
	
	# 1. Validar que la tienda puede vender
	var can_sell = shop.can_sell_to_player(item_id, quantity)
	if not can_sell.can:
		EventBus.shop_trade_failed.emit(shop_id, can_sell.reason, can_sell.context)
		return
	
	# 2. Calcular precio
	var base_value = _get_item_base_value(item_id)
	if base_value <= 0:
		EventBus.shop_trade_failed.emit(shop_id, "INVALID_ITEM", "Item has no value")
		return
	
	var unit_price = PriceCalculator.calculate_buy_price(base_value, shop.definition.sell_price_factor)
	var total_price = PriceCalculator.calculate_total_price(unit_price, quantity)
	
	# 3. Validar que el jugador tiene oro
	var cost_bundle = ResourceBundle.new({"gold": total_price})
	if not resource_system.can_pay(entity_id, cost_bundle):
		EventBus.shop_trade_failed.emit(shop_id, "NO_MONEY", "Player needs %d gold" % total_price)
		return
	
	# 4. Validar que el jugador tiene espacio en inventario
	# (Nota: InventorySystem actual no tiene can_add_item, omitir por ahora)
	
	# 5. Ejecutar transacción (atómica)
	if not _execute_buy_transaction(shop, item_id, quantity, total_price, entity_id):
		EventBus.shop_trade_failed.emit(shop_id, "TRANSACTION_FAILED", "Internal error")
		return
	
	# 6. Emitir éxito
	var snapshot = _create_shop_snapshot(shop, entity_id)
	EventBus.shop_trade_success.emit("buy", shop_id, item_id, quantity, snapshot)
	
	print("[EconomySystem] Buy successful: %s x%d for %d gold" % [item_id, quantity, total_price])


## Ejecuta la transacción de compra (atómica)
func _execute_buy_transaction(shop: ShopInstance, item_id: String, quantity: int, total_price: int, entity_id: String) -> bool:
	# Paso 1: Aplicar coste al jugador
	var cost_bundle = ResourceBundle.new({"gold": total_price})
	if not resource_system.apply_cost(entity_id, cost_bundle):
		push_error("[EconomySystem] Failed to apply cost")
		return false
	
	# Paso 2: Transferir item usando InventorySystem
	var transfer_success = false
	if inventory_system and inventory_system.has_method("add_item"):
		# Firma correcta: add_item(entity_id, item_id, quantity)
		transfer_success = inventory_system.add_item(entity_id, item_id, quantity)
	
	if not transfer_success:
		push_error("[EconomySystem] Failed to transfer item to player")
		# Rollback: devolver oro
		resource_system.add_resource(entity_id, "gold", total_price)
		return false
	
	# Paso 3: Remover item del inventario de la tienda
	if not shop.remove_item(item_id, quantity):
		push_error("[EconomySystem] Failed to remove item from shop")
		# Rollback: devolver oro y remover item del jugador
		resource_system.add_resource(entity_id, "gold", total_price)
		if inventory_system and inventory_system.has_method("remove_item"):
			inventory_system.remove_item(entity_id, item_id, quantity)
		return false
	
	# Paso 4: Incrementar presupuesto de la tienda
	shop.add_budget(total_price)
	
	return true


## ============================================
## VENTA (Jugador → Tienda)
## ============================================

## Procesa solicitud de venta
func sell_item(shop_id: String, item_id: String, quantity: int, entity_id: String = "player"):
	print("[EconomySystem] Sell request: shop=%s, item=%s, qty=%d" % [shop_id, item_id, quantity])
	
	var shop = get_shop(shop_id)
	if not shop:
		EventBus.shop_trade_failed.emit(shop_id, "SHOP_NOT_FOUND", "Shop does not exist")
		return
	
	# 1. Calcular precio
	var base_value = _get_item_base_value(item_id)
	if base_value <= 0:
		EventBus.shop_trade_failed.emit(shop_id, "INVALID_ITEM", "Item has no value")
		return
	
	var unit_price = PriceCalculator.calculate_sell_price(base_value, shop.definition.buy_price_factor)
	var total_price = PriceCalculator.calculate_total_price(unit_price, quantity)
	
	# 2. Validar que la tienda puede comprar
	var can_buy = shop.can_buy_from_player(item_id, quantity, total_price)
	if not can_buy.can:
		EventBus.shop_trade_failed.emit(shop_id, can_buy.reason, can_buy.context)
		return
	
	# 3. Validar que el jugador tiene el item
	if inventory_system and inventory_system.has_method("has_item"):
		# Firma correcta: has_item(entity_id, item_id, min_quantity)
		if not inventory_system.has_item(entity_id, item_id, quantity):
			EventBus.shop_trade_failed.emit(shop_id, "PLAYER_NO_ITEM", "Player doesn't have %d x %s" % [quantity, item_id])
			return
	
	# 4. Ejecutar transacción (atómica)
	if not _execute_sell_transaction(shop, item_id, quantity, total_price, entity_id):
		EventBus.shop_trade_failed.emit(shop_id, "TRANSACTION_FAILED", "Internal error")
		return
	
	# 5. Emitir éxito
	var snapshot = _create_shop_snapshot(shop, entity_id)
	EventBus.shop_trade_success.emit("sell", shop_id, item_id, quantity, snapshot)
	
	print("[EconomySystem] Sell successful: %s x%d for %d gold" % [item_id, quantity, total_price])


## Ejecuta la transacción de venta (atómica)
func _execute_sell_transaction(shop: ShopInstance, item_id: String, quantity: int, total_price: int, entity_id: String) -> bool:
	# Paso 1: Reducir presupuesto de la tienda
	if not shop.subtract_budget(total_price):
		push_error("[EconomySystem] Shop has insufficient budget")
		return false
	
	# Paso 2: Remover item del inventario del jugador
	var remove_success = false
	if inventory_system and inventory_system.has_method("remove_item"):
		# Firma correcta: remove_item(entity_id, item_id, quantity)
		remove_success = inventory_system.remove_item(entity_id, item_id, quantity)
	
	if not remove_success:
		push_error("[EconomySystem] Failed to remove item from player")
		# Rollback: devolver presupuesto
		shop.add_budget(total_price)
		return false
	
	# Paso 3: Añadir item al inventario de la tienda
	if not shop.add_item(item_id, quantity):
		push_error("[EconomySystem] Failed to add item to shop")
		# Rollback: devolver presupuesto y devolver item al jugador
		shop.add_budget(total_price)
		if inventory_system and inventory_system.has_method("add_item"):
			inventory_system.add_item(entity_id, item_id, quantity)
		return false
	
	# Paso 4: Dar oro al jugador
	resource_system.add_resource(entity_id, "gold", total_price)
	
	return true
	
## ============================================
## GENERACIÓN DE SNAPSHOTS
## ============================================

## Crea un ShopViewState para la UI
## Genera snapshot público (llamable desde SceneOrchestrator para evitar timing issues)
func create_shop_snapshot(shop: ShopInstance, entity_id: String) -> Dictionary:
	return _create_shop_snapshot(shop, entity_id)


func _create_shop_snapshot(shop: ShopInstance, entity_id: String) -> Dictionary:
	var snapshot = {
		"shop_id": shop.definition.id,
		"shop_name": tr(shop.definition.name_key),
		"player_gold": resource_system.get_resource_amount(entity_id, "gold"),
		"shop_gold": shop.budget,
		"shop_slots_used": shop.inventory.size(),
		"shop_slots_max": shop.max_slots,
		"items_for_sale": _get_items_for_sale(shop, entity_id),
		"player_items_sellable": _get_player_items_sellable(entity_id, shop),
		"flags": _calculate_flags(shop, entity_id)
	}
	
	return snapshot


## Obtiene la lista de items en venta
func _get_items_for_sale(shop: ShopInstance, entity_id: String) -> Array:
	var items = []
	
	for item_id in shop.inventory.keys():
		var item_state = shop.inventory[item_id] as ShopItemState
		var base_value = _get_item_base_value(item_id)
		var unit_price = PriceCalculator.calculate_buy_price(base_value, shop.definition.sell_price_factor)
		
		var player_gold = resource_system.get_resource_amount(entity_id, "gold")
		
		var item_view = {
			"item_id": item_id,
			"display_name": _get_item_name(item_id),
			"quantity": item_state.quantity,
			"unit_price": unit_price,
			"is_affordable": player_gold >= unit_price
		}
		
		items.append(item_view)
	
	return items

## Obtiene la lista de items que el jugador puede vender
func _get_player_items_sellable(entity_id: String, shop: ShopInstance) -> Array:
	var items = []
	
	if not inventory_system:
		print("[EconomySystem] No inventory_system available")
		return items
	
	# ⭐ Usar get_inventory() que existe en InventorySystem
	if not inventory_system.has_method("get_inventory"):
		print("[EconomySystem] InventorySystem doesn't have get_inventory method")
		return items
	
	# Obtener inventario del jugador
	var inventory = inventory_system.get_inventory(entity_id)
	
		# ⭐ DEBUG: Ver qué tipo de dato es
	print("[EconomySystem] inventory type: %s" % typeof(inventory))
	print("[EconomySystem] inventory value: %s" % str(inventory))
	
	if inventory == null:
		print("[EconomySystem] Inventory is null")
		return items
	
	if inventory is Dictionary:
		print("[EconomySystem] Inventory is Dictionary with %d items" % inventory.size())
	elif inventory is Array:
		print("[EconomySystem] Inventory is Array with %d items" % inventory.size())
	else:
		print("[EconomySystem] Inventory is unknown type")
	
	if not inventory:
		print("[EconomySystem] No inventory returned for entity: %s" % entity_id)
		return items
	
	print("[EconomySystem] Got inventory for %s: %s" % [entity_id, inventory])
	
	# El inventario es un Dictionary { item_id: ItemInstance }
	for item_id in inventory.keys():
		var item_instance = inventory[item_id]
		
		# Obtener cantidad
		var quantity = 0
		if inventory_system.has_method("get_item_quantity"):
			quantity = inventory_system.get_item_quantity(entity_id, item_id)
		elif item_instance.has_method("get_quantity"):
			quantity = item_instance.get_quantity()
		elif item_instance is Dictionary:
			quantity = item_instance.get("quantity", 1)
		else:
			quantity = 1
		
		print("[EconomySystem] Processing: %s x%d" % [item_id, quantity])
		
		if quantity <= 0:
			print("  -> Skipped (zero quantity)")
			continue
		
		# Calcular precio de venta
		var base_value = _get_item_base_value(item_id)
		var unit_price = PriceCalculator.calculate_sell_price(base_value, shop.definition.buy_price_factor)
		var total_price = PriceCalculator.calculate_total_price(unit_price, quantity)
		
		var item_view = {
			"item_id": item_id,
			"display_name": _get_item_name(item_id),
			"quantity": quantity,
			"unit_price": unit_price,
			"total_price": total_price,
			"shop_can_afford": shop.budget >= unit_price or shop.definition.infinite_budget,  # ⭐ Comparar con unit_price, no total
			"shop_has_slot": shop.inventory.has(item_id) or shop.inventory.size() < shop.max_slots
		}
		
		items.append(item_view)
		print("  -> Added to sellable items")
	
	print("[EconomySystem] Total player items sellable: %d" % items.size())
	return items

## Calcula flags para la UI
func _calculate_flags(shop: ShopInstance, _entity_id: String) -> Dictionary:
	return {
		"can_buy": true,  # Siempre puede intentar
		"can_sell": true,  # Siempre puede intentar
		"shop_has_money": shop.budget > 0 or shop.definition.infinite_budget,
		"shop_has_slots": shop.inventory.size() < shop.max_slots
	}

## ============================================
## SAVESYSTEM INTEGRATION
## ============================================

## Implementa SaveableSystem interface
func get_save_version() -> int:
	return 1  # Versión del bloque de economy


func get_load_priority() -> int:
	return 30  # Después de ResourceSystem (10) e InventorySystem (20)


func get_dependencies() -> Array:
	return ["ResourceSystem", "InventorySystem"]


func can_recover_from_corruption() -> bool:
	return true  # Puede crear tiendas vacías si fallan

## Valida estado guardado antes de cargar
func validate_save_state(save_data: Dictionary) -> bool:
	if not save_data.has("shops"):
		push_warning("[EconomySystem] Save data has no 'shops' field")
		return false
	
	var shops_data = save_data.get("shops", {})
	
	# Validar cada tienda
	for shop_id in shops_data.keys():
		var shop_save = shops_data[shop_id]
		
		if not shop_save is Dictionary:
			push_error("[EconomySystem] Shop '%s' data is not a Dictionary" % shop_id)
			return false
		
		if not shop_save.has("budget"):
			push_error("[EconomySystem] Shop '%s' missing budget" % shop_id)
			return false
		
		if not shop_save.has("inventory"):
			push_error("[EconomySystem] Shop '%s' missing inventory" % shop_id)
			return false
	
	return true

## ============================================
## CALLBACKS DE EVENTBUS
## ============================================

## Callback: solicitud de apertura
func _on_shop_open_requested(shop_id: String, entity_id: String):
	open_shop(shop_id, entity_id)


## Callback: solicitud de cierre
func _on_shop_close_requested(shop_id: String):
	close_shop(shop_id)


## Callback: solicitud de compra
func _on_shop_buy_requested(shop_id: String, item_id: String, quantity: int):
	buy_item(shop_id, item_id, quantity, "player")


## Callback: solicitud de venta
func _on_shop_sell_requested(shop_id: String, item_id: String, quantity: int):
	sell_item(shop_id, item_id, quantity, "player")

## ============================================
## UTILIDADES INTERNAS
## ============================================

## Obtiene el valor base de un item desde ItemRegistry (autoload: Items)
func _get_item_base_value(item_id: String) -> int:
	var items: ItemRegistry = get_node_or_null("/root/Items")
	if items:
		var item_def: ItemDefinition = items.get_item(item_id)
		if item_def:
			return item_def.base_value
	
	push_warning("[EconomySystem] Item not found in registry: %s — using fallback value 10" % item_id)
	return 10


## Obtiene el nombre localizado de un item desde ItemRegistry (autoload: Items)
func _get_item_name(item_id: String) -> String:
	var items: ItemRegistry = get_node_or_null("/root/Items")
	if items:
		var item_def: ItemDefinition = items.get_item(item_id)
		if item_def:
			return tr(item_def.name_key)
	
	return item_id.capitalize()


## ============================================
## SAVE / LOAD
## ============================================
## Obtiene estado para SaveSystem
func get_save_state() -> Dictionary:
	print("[EconomySystem] Saving state of %d shops" % _shops.size())
	
	var shops_data = {}
	
	for shop_id in _shops.keys():
		var shop = _shops[shop_id] as ShopInstance
		shops_data[shop_id] = shop.to_dict()
		print("  - Saved shop: %s (budget=%d, items=%d)" % [
			shop_id,
			shop.budget,
			shop.inventory.size()
		])
	
	return {
		"version": get_save_version(),
		"shops": shops_data
	}

## Carga estado desde SaveSystem
func load_save_state(save_data: Dictionary) -> bool:
	print("[EconomySystem] Loading economy state...")
	
	# Validar versión
	var version = save_data.get("version", 0)
	if version != get_save_version():
		push_warning("[EconomySystem] Version mismatch: save=%d, current=%d" % [version, get_save_version()])
	
	var shops_data = save_data.get("shops", {})
	
	if shops_data.is_empty():
		print("[EconomySystem] No shops data in save, using defaults")
		return true
	
	var loaded_count = 0
	var failed_count = 0
	
	for shop_id in shops_data.keys():
		var shop_save = shops_data[shop_id]
		
		# Buscar la definición
		var current_shop = get_shop(shop_id)
		if not current_shop:
			push_warning("[EconomySystem] Shop '%s' not found in definitions, skipping" % shop_id)
			failed_count += 1
			continue
		
		# Restaurar desde dict
		var loaded_shop = ShopInstance.from_dict(shop_save, current_shop.definition)
		
		if not loaded_shop.validate():
			push_error("[EconomySystem] Failed to restore shop: %s" % shop_id)
			failed_count += 1
			continue
		
		# Reemplazar instancia
		_shops[shop_id] = loaded_shop
		loaded_count += 1
		
		print("  - Restored shop: %s (budget=%d, items=%d)" % [
			shop_id,
			loaded_shop.budget,
			loaded_shop.inventory.size()
		])
	
	print("[EconomySystem] Loaded %d shops (%d failed)" % [loaded_count, failed_count])
	
	return failed_count == 0

## ============================================
## DEBUG
## ============================================

## Imprime estado de todas las tiendas
func print_all_shops():
	print("\n[EconomySystem] Current shops:")
	for shop_id in _shops.keys():
		_shops[shop_id].print_state()

func _debug_inventory_system_methods():
	print("\n[EconomySystem] InventorySystem methods:")
	var methods = inventory_system.get_method_list()
	
	for method in methods:
		var method_name = method["name"]
		
		# Solo mostrar métodos relevantes
		if method_name in ["add_item", "remove_item", "has_item", "can_add_item", "get_items", "get_all_items"]:
			var params_str = ""
			for param in method["args"]:
				var param_name = param.get("name", "?")
				var param_type = _get_type_name(param.get("type", TYPE_NIL))
				params_str += "%s: %s, " % [param_name, param_type]
			
			if params_str.ends_with(", "):
				params_str = params_str.substr(0, params_str.length() - 2)
			
			print("  %s(%s)" % [method_name, params_str])
	print("")


## Convierte TYPE_* a nombre legible
func _get_type_name(type: int) -> String:
	match type:
		TYPE_NIL: return "nil"
		TYPE_BOOL: return "bool"
		TYPE_INT: return "int"
		TYPE_FLOAT: return "float"
		TYPE_STRING: return "String"
		TYPE_VECTOR2: return "Vector2"
		TYPE_RECT2: return "Rect2"
		TYPE_VECTOR3: return "Vector3"
		TYPE_TRANSFORM2D: return "Transform2D"
		TYPE_PLANE: return "Plane"
		TYPE_QUATERNION: return "Quaternion"
		TYPE_AABB: return "AABB"
		TYPE_BASIS: return "Basis"
		TYPE_TRANSFORM3D: return "Transform3D"
		TYPE_COLOR: return "Color"
		TYPE_STRING_NAME: return "StringName"
		TYPE_NODE_PATH: return "NodePath"
		TYPE_RID: return "RID"
		TYPE_OBJECT: return "Object"
		TYPE_DICTIONARY: return "Dictionary"
		TYPE_ARRAY: return "Array"
		TYPE_PACKED_BYTE_ARRAY: return "PackedByteArray"
		TYPE_PACKED_INT32_ARRAY: return "PackedInt32Array"
		TYPE_PACKED_INT64_ARRAY: return "PackedInt64Array"
		TYPE_PACKED_FLOAT32_ARRAY: return "PackedFloat32Array"
		TYPE_PACKED_FLOAT64_ARRAY: return "PackedFloat64Array"
		TYPE_PACKED_STRING_ARRAY: return "PackedStringArray"
		TYPE_PACKED_VECTOR2_ARRAY: return "PackedVector2Array"
		TYPE_PACKED_VECTOR3_ARRAY: return "PackedVector3Array"
		TYPE_PACKED_COLOR_ARRAY: return "PackedColorArray"
		_: return "Unknown(%d)" % type
