extends Node

## Test de SaveSystem con ItemSystem - Día 7
## Valida que el inventario persiste correctamente

var resource_system: ResourceSystem


func _ready():
	print("\n" + "=".repeat(50))
	print("SPIKE DÍA 7 - TEST SAVE/LOAD")
	print("=".repeat(50) + "\n")
	
	# Esperar inicialización
	await get_tree().process_frame
	await get_tree().process_frame
	
	resource_system = get_node("/root/Resources")
	if not resource_system:
		push_error("[Test] ResourceSystem not found!")
		return
	
	test_setup()
	test_save_inventory()
	test_load_inventory()
	test_inventory_persistence()
	
	print("\n" + "=".repeat(50))
	print("✅ SAVE/LOAD VALIDADO")
	print("=".repeat(50) + "\n")


## Setup
func test_setup():
	print("📝 Setup: Inicializar sistemas")
	
	# Registrar player
	resource_system.register_entity("player")
	Inventory.register_entity("player")
	
	print("  ✅ Player registrado")


## Test 1: Guardar inventario
func test_save_inventory():
	print("\n📝 Test 1: Guardar inventario")
	
	# Estado inicial
	Inventory.add_item("player", "stamina_potion_small", 3)
	resource_system.set_resource("player", "stamina", 75.0)
	
	print("  📦 Estado antes de guardar:")
	print("    - Pociones: 3")
	print("    - Stamina: 75")
	
	# Obtener snapshot
	var inv_snapshot = Inventory.get_save_state("player")
	
	assert(inv_snapshot.has("stamina_potion_small"), "Should have potion in snapshot!")
	assert(inv_snapshot["stamina_potion_small"]["quantity"] == 3, "Quantity mismatch!")
	
	print("  ✅ Snapshot generado correctamente")
	print("  ✅ Snapshot: %s" % inv_snapshot)


## Test 2: Cargar inventario
func test_load_inventory():
	print("\n📝 Test 2: Cargar inventario")
	
	# Snapshot simulado
	var fake_snapshot = {
		"stamina_potion_small": {
			"quantity": 7,
			"custom_state": {}
		}
	}
	
	print("  📦 Cargando snapshot simulado:")
	print("    - Pociones: 7")
	
	# Cargar
	Inventory.load_save_state("player", fake_snapshot)
	
	# Verificar
	var qty = Inventory.get_item_quantity("player", "stamina_potion_small")
	assert(qty == 7, "Should have 7 potions! (got %d)" % qty)
	
	print("  ✅ Snapshot cargado correctamente")
	print("  ✅ Cantidad verificada: %d" % qty)


## Test 3: Persistencia completa (guardar → limpiar → cargar)
func test_inventory_persistence():
	print("\n📝 Test 3: Persistencia completa")
	
	# Estado inicial
	Inventory.add_item("player", "stamina_potion_small", 5)
	var qty_before = Inventory.get_item_quantity("player", "stamina_potion_small")
	print("  📦 Estado inicial: %d pociones" % qty_before)
	
	# Guardar snapshot
	var snapshot = Inventory.get_save_state("player")
	print("  💾 Snapshot guardado")
	
	# Simular "limpiar" (nueva partida)
	Inventory.unregister_entity("player")
	Inventory.register_entity("player")
	
	var qty_after_clear = Inventory.get_item_quantity("player", "stamina_potion_small")
	assert(qty_after_clear == 0, "Should be empty after clear!")
	print("  🗑️  Inventario limpiado: %d pociones" % qty_after_clear)
	
	# Restaurar desde snapshot
	Inventory.load_save_state("player", snapshot)
	
	var qty_restored = Inventory.get_item_quantity("player", "stamina_potion_small")
	assert(qty_restored == qty_before, "Should restore to original! (got %d)" % qty_restored)
	print("  ♻️  Inventario restaurado: %d pociones" % qty_restored)
	
	print("  ✅ Persistencia completa funcional")
