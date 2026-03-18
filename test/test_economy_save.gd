extends Node

## Test de persistencia del EconomySystem
## Valida guardado/carga de tiendas

var player_scene = preload("res://scenes/player/player.tscn")
var player: Node

func _ready():
	# Instanciar jugador
	player = player_scene.instantiate()
	add_child(player)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("\n=== Testing Economy SaveSystem Integration ===")
	
	await test_save_and_load()
	
	print("\n=== Economy Save/Load tests complete ===\n")


func test_save_and_load():
	print("\n--- Test: Save and Load Economy ---")
	
	var resource_system = get_node("/root/Resources")
	var economy_system = get_node("/root/Economy")
	var save_system = get_node("/root/SaveManager")
	
	# Setup inicial
	resource_system.set_resource("player", "gold", 1000)
	
	# Modificar tienda
	print("\n1. Modifying shop state...")
	var shop = economy_system.get_shop("blacksmith_01")
	var initial_budget = shop.budget
	var initial_stock = shop.inventory.size()
	
	print("  Initial: budget=%d, stock=%d items" % [initial_budget, initial_stock])
	
	# Comprar algo
	economy_system.buy_item("blacksmith_01", "health_potion", 1, "player")
	await get_tree().process_frame
	
	# Vender algo
	var inventory_system = get_node("/root/Inventory")
	inventory_system.add_item("player", "iron_sword", 1)
	economy_system.sell_item("blacksmith_01", "iron_sword", 1, "player")
	await get_tree().process_frame
	
	shop = economy_system.get_shop("blacksmith_01")
	var modified_budget = shop.budget
	var modified_stock = shop.inventory.size()
	
	print("  Modified: budget=%d, stock=%d items" % [modified_budget, modified_stock])
	
	# Guardar
	print("\n2. Saving game...")
	save_system.save_game("economy_test")
	await get_tree().process_frame
	
	# Modificar más (para verificar que la carga funciona)
	print("\n3. Modifying again (to verify load works)...")
	economy_system.buy_item("blacksmith_01", "stamina_potion_small", 5, "player")
	await get_tree().process_frame
	
	shop = economy_system.get_shop("blacksmith_01")
	print("  After 2nd modification: budget=%d, stock=%d items" % [shop.budget, shop.inventory.size()])
	
	# Cargar
	print("\n4. Loading game...")
	save_system.load_game("economy_test")
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Verificar
	shop = economy_system.get_shop("blacksmith_01")
	var loaded_budget = shop.budget
	var loaded_stock = shop.inventory.size()
	
	print("  Loaded: budget=%d, stock=%d items" % [loaded_budget, loaded_stock])
	
	# Validar
	if loaded_budget == modified_budget and loaded_stock == modified_stock:
		print("\n✓ Save/Load works correctly!")
		print("  Budget: %d → %d ✓" % [modified_budget, loaded_budget])
		print("  Stock: %d → %d ✓" % [modified_stock, loaded_stock])
	else:
		push_error("\n✗ Save/Load failed!")
		print("  Budget: expected %d, got %d" % [modified_budget, loaded_budget])
		print("  Stock: expected %d, got %d" % [modified_stock, loaded_stock])
