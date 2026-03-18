extends Node

## Setup manual para probar InventoryUI
## Adjuntar como hijo de la escena de juego

func _ready():
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("\n" + "=".repeat(50))
	print("MANUAL TEST - DÍA 6: INVENTORY UI")
	print("=".repeat(50))
	
	# Esperar a que ResourceSystem y InventorySystem estén listos
	var res_system = get_node_or_null("/root/Resources")
	if not res_system:
		push_error("[ManualTest] ResourceSystem not found!")
		return
	
	# Registrar player si no está
	if not res_system._entities.has("player"):
		res_system.register_entity("player")
		print("✅ Player registrado en ResourceSystem")
	
	# Asegurarse de que player tiene inventario
	var player_inv = Inventory.get_inventory("player")
	if player_inv.is_empty() or not player_inv:
		Inventory.register_entity("player")
		print("✅ Player registrado en InventorySystem")
	
	# ⭐ CRÍTICO: Añadir pociones
	Inventory.add_item("player", "stamina_potion_small", 5)
	print("✅ Añadidas 5 pociones al inventario")
	
	# Verificar que se añadieron
	var qty = Inventory.get_item_quantity("player", "stamina_potion_small")
	print("✅ Cantidad verificada: %d pociones" % qty)
	
	# Reducir stamina para poder probar
	res_system.set_resource("player", "stamina", 40.0)
	print("✅ Stamina reducida a 40")
	
	# Imprimir inventario completo
	Inventory.print_inventory("player")
	
	print("\nINSTRUCCIONES:")
	print("1. Pulsa I para abrir inventario")
	print("2. Deberías ver 5 pociones con icono placeholder")
	print("3. Click en una poción para seleccionar")
	print("4. Click en [USAR]")
	print("5. Observa feedback verde y stamina sube")
	print("6. Inventario se actualiza automáticamente")
	print("7. Pulsa I o X para cerrar")
	print("=".repeat(50) + "\n")
