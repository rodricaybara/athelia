extends Node

## Script de debug para inventario
## Adjuntar temporalmente al root de test.tscn

func _ready():
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("\n=== DEBUG INVENTORY ===")
	
	# 1. Verificar ItemRegistry
	print("\n1. ItemRegistry:")
	print("  Items loaded: ", Items.list_items())
	var potion = Items.get_item("stamina_potion_small")
	if potion:
		print("  ✅ Potion found: ", potion.id)
	else:
		print("  ❌ Potion NOT found!")
	
	# 2. Verificar ResourceSystem
	print("\n2. ResourceSystem:")
	var res_sys = get_node("/root/Resources")
	if res_sys:
		print("  ✅ ResourceSystem exists")
		print("  Entities: ", res_sys._entities.keys())
	else:
		print("  ❌ ResourceSystem NOT found!")
	
	# 3. Verificar InventorySystem
	print("\n3. InventorySystem:")
	print("  Entities: ", Inventory._inventories.keys())
	
	# 4. Verificar inventario de player
	print("\n4. Player Inventory:")
	var inv = Inventory.get_inventory("player")
	print("  Items: ", inv.keys())
	for item_id in inv.keys():
		var instance = inv[item_id]
		print("    - %s x%d" % [item_id, instance.quantity])
	
	# 5. Verificar InventoryUI
	print("\n5. InventoryUI:")
	var ui = get_tree().current_scene.get_node_or_null("InventoryUI")
	#var ui = get_tree().get_first_node_in_group("inventory_ui")
	if ui:
		print("  ✅ InventoryUI found")
		print("  Visible: ", ui.visible)
		print("  Slots: ", ui.slots_grid.get_child_count() if ui.slots_grid else "N/A")
	else:
		print("  ❌ InventoryUI NOT found!")
	
	print("\n=== END DEBUG ===\n")


func _input(event):
	if event.is_action_pressed("ui_page_up"):
		print("\n[DEBUG] Manual inventory test:")
		
		# Añadir poción
		Inventory.add_item("player", "stamina_potion_small", 1)
		print("  Added 1 potion")
		
		# Verificar cantidad
		var qty = Inventory.get_item_quantity("player", "stamina_potion_small")
		print("  Quantity: ", qty)
	
	if event.is_action_pressed("ui_page_down"):
		print("\n[DEBUG] Inventory status:")
		Inventory.print_inventory("player")
