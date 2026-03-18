extends Node

## Test de InventorySystem - Día 4
## Valida gestión centralizada y CRUD de inventarios

# Variables para Test 6 (a nivel de clase)
var use_requested: bool = false
var use_failed: bool = false
var fail_reason: String = ""


func _ready():
	print("\n" + "=".repeat(50))
	print("SPIKE DÍA 4 - TEST INVENTORY SYSTEM")
	print("=".repeat(50) + "\n")
	
	test_item_registry()
	test_entity_registration()
	test_add_items()
	test_remove_items()
	test_stacking()
	test_request_use()
	
	print("\n" + "=".repeat(50))
	print("✅ INVENTORY SYSTEM VALIDADO")
	print("=".repeat(50) + "\n")


## Test 1: ItemRegistry
func test_item_registry():
	print("📝 Test 1: ItemRegistry")
	
	# Verificar que cargó ítems
	var items = Items.list_items()
	assert(items.size() > 0, "Should have loaded items!")
	print("  ✅ Cargados %d ítems" % items.size())
	
	# Verificar poción
	var potion = Items.get_item("stamina_potion_small")
	assert(potion != null, "Should find stamina_potion_small!")
	print("  ✅ Poción encontrada: %s" % potion.id)
	
	# Verificar ítem inexistente
	var fake = Items.get_item("fake_item")
	assert(fake == null, "Should return null for fake item!")
	print("  ✅ Ítem inexistente retorna null")
	
	# Test has_item
	assert(Items.has_item("stamina_potion_small"), "Should have potion!")
	assert(not Items.has_item("fake"), "Should not have fake!")
	print("  ✅ has_item funcional")
	
	# Test get_items_by_tag
	var potions = Items.get_items_by_tag("potion")
	assert(potions.size() > 0, "Should find potions!")
	print("  ✅ get_items_by_tag encontró %d pociones" % potions.size())
	
	print()


## Test 2: Registro de entidades
func test_entity_registration():
	print("📝 Test 2: Registro de entidades")
	
	Inventory.register_entity("player")
	print("  ✅ Entidad 'player' registrada")
	
	Inventory.register_entity("npc_merchant")
	print("  ✅ Entidad 'npc_merchant' registrada")
	
	# Intentar registrar duplicado (debe avisar pero no fallar)
	Inventory.register_entity("player")
	print("  ✅ Registro duplicado manejado")
	
	print()


## Test 3: Añadir ítems
func test_add_items():
	print("📝 Test 3: Añadir ítems")
	
	# Añadir pociones
	var success = Inventory.add_item("player", "stamina_potion_small", 3)
	assert(success, "Should add item!")
	print("  ✅ Añadidas 3 pociones")
	
	var qty = Inventory.get_item_quantity("player", "stamina_potion_small")
	assert(qty == 3, "Should have 3 potions!")
	print("  ✅ Cantidad verificada: %d" % qty)
	
	# Añadir más (stack)
	success = Inventory.add_item("player", "stamina_potion_small", 5)
	assert(success, "Should stack!")
	qty = Inventory.get_item_quantity("player", "stamina_potion_small")
	assert(qty == 8, "Should have 8 potions!")
	print("  ✅ Stacking funcional: %d pociones" % qty)
	
	# Verificar has_item
	assert(Inventory.has_item("player", "stamina_potion_small", 5), "Should have at least 5!")
	assert(not Inventory.has_item("player", "stamina_potion_small", 20), "Should NOT have 20!")
	print("  ✅ has_item funcional")
	
	print()


## Test 4: Remover ítems
func test_remove_items():
	print("📝 Test 4: Remover ítems")
	
	# Estado inicial: 8 pociones
	var qty_before = Inventory.get_item_quantity("player", "stamina_potion_small")
	print("  📦 Antes: %d pociones" % qty_before)
	
	# Remover 3
	var success = Inventory.remove_item("player", "stamina_potion_small", 3)
	assert(success, "Should remove!")
	
	var qty_after = Inventory.get_item_quantity("player", "stamina_potion_small")
	assert(qty_after == 5, "Should have 5 left!")
	print("  ✅ Removidas 3: quedan %d" % qty_after)
	
	# Remover todas
	success = Inventory.remove_item("player", "stamina_potion_small", 5)
	assert(success, "Should remove all!")
	
	qty_after = Inventory.get_item_quantity("player", "stamina_potion_small")
	assert(qty_after == 0, "Should be empty!")
	print("  ✅ Removidas todas: quedan %d" % qty_after)
	
	# Verificar que se eliminó del inventario
	var inv = Inventory.get_inventory("player")
	assert(not inv.has("stamina_potion_small"), "Should be removed from inventory!")
	print("  ✅ Ítem eliminado del inventario")
	
	print()


## Test 5: Stacking complejo
func test_stacking():
	print("📝 Test 5: Stacking complejo")
	
	# Añadir hasta casi lleno (max_stack = 10)
	Inventory.add_item("player", "stamina_potion_small", 8)
	var qty = Inventory.get_item_quantity("player", "stamina_potion_small")
	print("  📦 Añadidas 8: total=%d" % qty)
	
	# Intentar añadir más de lo permitido
	Inventory.add_item("player", "stamina_potion_small", 5)
	qty = Inventory.get_item_quantity("player", "stamina_potion_small")
	assert(qty == 10, "Should be clamped to max_stack!")
	print("  ✅ Clamp a max_stack: total=%d" % qty)
	
	# Limpiar para siguiente test
	Inventory.remove_item("player", "stamina_potion_small", 10)
	print()


## Test 6: Request use item
func test_request_use():
	print("📝 Test 6: Request use item")
	
	# Reset variables
	use_requested = false
	use_failed = false
	fail_reason = ""
	
	# Conectar listeners (métodos de clase, NO lambdas)
	EventBus.item_use_requested.connect(_on_test_item_requested)
	EventBus.item_use_failed.connect(_on_test_item_failed)
	
	# Test: ítem inexistente
	Inventory.request_use_item("player", "fake_item")
	assert(use_failed, "Should fail for non-existent item! (use_failed=%s)" % use_failed)
	assert(fail_reason == "Item not found", "Reason mismatch! Got: '%s'" % fail_reason)
	print("  ✅ Ítem inexistente: fallo correcto")
	
	# Reset
	use_requested = false
	use_failed = false
	fail_reason = ""
	
	# Test: ítem válido
	Inventory.add_item("player", "stamina_potion_small", 1)
	Inventory.request_use_item("player", "stamina_potion_small")
	assert(use_requested, "Should emit item_use_requested!")
	print("  ✅ Ítem válido: request emitido")
	
	# Cleanup
	EventBus.item_use_requested.disconnect(_on_test_item_requested)
	EventBus.item_use_failed.disconnect(_on_test_item_failed)
	Inventory.remove_item("player", "stamina_potion_small", 1)
	
	print()


## Callback para test 6: item_use_requested
func _on_test_item_requested(entity_id: String, _item_id: String):
	if entity_id == "player":
		use_requested = true


## Callback para test 6: item_use_failed
func _on_test_item_failed(entity_id: String, _item_id: String, reason: String):
	if entity_id == "player":
		use_failed = true
		fail_reason = reason
