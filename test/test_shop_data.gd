extends Node

## Test de ShopDefinition + ShopInstance
## Validar integridad, stacking, budget, slots

func _ready():
	print("\n=== Testing Shop Data Model ===")
	
	test_shop_definition()
	test_shop_instance_creation()
	test_inventory_operations()
	test_budget_operations()
	test_slot_limits()
	test_save_load()
	
	print("\n=== Shop Data tests complete ===\n")


func test_shop_definition():
	print("\n--- Test: ShopDefinition ---")
	
	var shop_def = ShopDefinition.new()
	shop_def.id = "test_shop"
	shop_def.name_key = "SHOP_TEST"
	shop_def.initial_budget = 1000
	shop_def.max_slots = 5
	
	if shop_def.validate():
		print("✓ ShopDefinition validation OK")
		print("  ", shop_def)
	else:
		push_error("✗ ShopDefinition validation failed")


func test_shop_instance_creation():
	print("\n--- Test: ShopInstance Creation ---")
	
	var shop_def = ShopDefinition.new()
	shop_def.id = "test_shop"
	shop_def.name_key = "SHOP_TEST"
	shop_def.initial_budget = 500
	shop_def.max_slots = 3
	shop_def.initial_inventory = {
		"health_potion": 10,
		"mana_potion": 5
	}
	
	var instance = ShopInstance.new(shop_def)
	
	if instance.budget == 500:
		print("✓ Budget initialized correctly: %d" % instance.budget)
	else:
		push_error("✗ Budget incorrect: expected 500, got %d" % instance.budget)
	
	if instance.inventory.size() == 2:
		print("✓ Initial inventory loaded: %d items" % instance.inventory.size())
	else:
		push_error("✗ Inventory size incorrect")
	
	instance.print_state()


func test_inventory_operations():
	print("\n--- Test: Inventory Operations ---")
	
	var shop_def = ShopDefinition.new()
	shop_def.id = "test_shop"
	shop_def.name_key = "SHOP_TEST"
	shop_def.max_slots = 3
	
	var instance = ShopInstance.new(shop_def)
	
	# Añadir item nuevo
	if instance.add_item("iron_sword", 1):
		print("✓ Added new item")
	else:
		push_error("✗ Failed to add item")
	
	# Incrementar cantidad (stacking)
	if instance.add_item("iron_sword", 2):
		print("✓ Stacked item (should be 3 now)")
		var qty = instance.get_item_quantity("iron_sword")
		if qty == 3:
			print("  Quantity correct: %d" % qty)
		else:
			push_error("  Quantity incorrect: expected 3, got %d" % qty)
	
	# Remover parcialmente
	if instance.remove_item("iron_sword", 2):
		print("✓ Removed 2 units")
		var qty = instance.get_item_quantity("iron_sword")
		if qty == 1:
			print("  Remaining: %d" % qty)
	
	# Remover completamente (debería eliminar slot)
	instance.remove_item("iron_sword", 1)
	if not instance.inventory.has("iron_sword"):
		print("✓ Item removed from inventory when quantity reached 0")


func test_budget_operations():
	print("\n--- Test: Budget Operations ---")
	
	var shop_def = ShopDefinition.new()
	shop_def.id = "test_shop"
	shop_def.name_key = "SHOP_TEST"
	shop_def.initial_budget = 100
	
	var instance = ShopInstance.new(shop_def)
	
	# Añadir presupuesto
	instance.add_budget(50)
	if instance.budget == 150:
		print("✓ Budget increased: %d" % instance.budget)
	
	# Restar presupuesto exitoso
	if instance.subtract_budget(50):
		print("✓ Budget decreased: %d" % instance.budget)
	
	# Intentar restar más de lo disponible
	if not instance.subtract_budget(200):
		print("✓ Prevented negative budget")
	else:
		push_error("✗ Budget went negative!")


func test_slot_limits():
	print("\n--- Test: Slot Limits ---")
	
	var shop_def = ShopDefinition.new()
	shop_def.id = "test_shop"
	shop_def.name_key = "SHOP_TEST"
	shop_def.max_slots = 2
	
	var instance = ShopInstance.new(shop_def)
	
	# Llenar slots
	instance.add_item("item_1", 1)
	instance.add_item("item_2", 1)
	
	# Intentar exceder slots
	if not instance.add_item("item_3", 1):
		print("✓ Prevented exceeding max_slots")
	else:
		push_error("✗ Exceeded max_slots!")
	
	# Verificar que stacking no consume slots adicionales
	instance.add_item("item_1", 5)
	if instance.inventory.size() == 2:
		print("✓ Stacking doesn't consume additional slots")


func test_save_load():
	print("\n--- Test: Save/Load ---")
	
	# Crear shop original
	var shop_def = ShopDefinition.new()
	shop_def.id = "test_shop"
	shop_def.name_key = "SHOP_TEST"
	shop_def.initial_budget = 1000
	
	var original = ShopInstance.new(shop_def)
	original.add_item("health_potion", 5)
	original.add_item("mana_potion", 3)
	original.subtract_budget(200)
	
	print("  Original state:")
	original.print_state()
	
	# Serializar
	var save_data = original.to_dict()
	
	# Cargar en nueva instancia
	var loaded = ShopInstance.from_dict(save_data, shop_def)
	
	print("  Loaded state:")
	loaded.print_state()
	
	# Validar
	if loaded.budget == original.budget:
		print("✓ Budget preserved")
	else:
		push_error("✗ Budget mismatch")
	
	if loaded.inventory.size() == original.inventory.size():
		print("✓ Inventory size preserved")
	else:
		push_error("✗ Inventory size mismatch")
	
	if loaded.validate():
		print("✓ Loaded state is valid")
