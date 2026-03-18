extends Node

## Test del EconomySystem con InventorySystem real

var player_scene = preload("res://scenes/player/player.tscn")
var player: Node

func _ready():
	# Instanciar jugador
	player = player_scene.instantiate()
	add_child(player)
	
	# Esperar a que sistemas se inicialicen
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("\n=== Testing EconomySystem with InventorySystem ===")
	
	test_inventory_integration()
	await test_buy_with_inventory()
	await test_sell_with_inventory()
	
	print("\n=== EconomySystem integration tests complete ===\n")


func test_inventory_integration():
	print("\n--- Test: InventorySystem Integration ---")
	
	var economy = get_node("/root/Economy")
	if economy.inventory_system:
		print("✓ InventorySystem found: %s" % economy.inventory_system.name)
	else:
		push_error("✗ InventorySystem not found")


func test_buy_with_inventory():
	print("\n--- Test: Buy with Real Inventory ---")
	
	# Dar oro al jugador
	var resource_system = get_node("/root/Resources")
	resource_system.set_resource("player", "gold", 1000)
	
	# Conectar listener
	EventBus.shop_trade_success.connect(_on_trade_success)
	
	# Comprar item
	var economy = get_node("/root/Economy")
	economy.buy_item("blacksmith_01", "stamina_potion_small", 2, "player")
	
	await get_tree().process_frame
	
	# Verificar que el item está en el inventario
	if economy.inventory_system and economy.inventory_system.has_method("has_item"):
		if economy.inventory_system.has_item("player", "stamina_potion_small", 2):
			print("✓ Item added to player inventory")
		else:
			push_error("✗ Item NOT in inventory")
	
	EventBus.shop_trade_success.disconnect(_on_trade_success)


func test_sell_with_inventory():
	print("\n--- Test: Sell with Real Inventory ---")
	
	var economy = get_node("/root/Economy")
	
	# Añadir item al inventario del jugador primero
	if economy.inventory_system and economy.inventory_system.has_method("add_item"):
		economy.inventory_system.add_item("player","iron_sword", 1)
		print("  Added iron_sword to player inventory")
	
	# Conectar listener
	EventBus.shop_trade_success.connect(_on_trade_success)
	
	# Vender item
	economy.sell_item("blacksmith_01", "iron_sword", 1, "player")
	
	await get_tree().process_frame
	
	EventBus.shop_trade_success.disconnect(_on_trade_success)


func _on_trade_success(trade_type: String, shop_id: String, item_id: String, quantity: int, snapshot: Dictionary):
	print("  [SUCCESS] %s: %d x %s" % [trade_type.capitalize(), quantity, item_id])
	print("  Player gold: %d" % snapshot.player_gold)
	print("  Shop gold: %d" % snapshot.shop_gold)
