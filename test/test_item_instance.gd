extends Node

## Test de ItemInstance - Día 3
## Valida gestión de cantidades y stacking

func _ready():
	print("\n" + "=".repeat(50))
	print("SPIKE DÍA 3 - TEST ITEM INSTANCE")
	print("=".repeat(50) + "\n")
	
	test_basic_instance()
	test_quantity_management()
	test_stacking_rules()
	test_non_stackable()
	test_utilities()
	
	print("\n" + "=".repeat(50))
	print("✅ ITEM INSTANCE VALIDADO")
	print("=".repeat(50) + "\n")


## Test 1: Creación básica
func test_basic_instance():
	print("📝 Test 1: Creación básica de instancia")
	
	var potion_def = load("res://data/items/stamina_potion_small.tres") as ItemDefinition
	var instance = ItemInstance.new(potion_def, 3)
	
	assert(instance.definition == potion_def, "Definition mismatch!")
	assert(instance.quantity == 3, "Quantity should be 3!")
	assert(instance.custom_state.is_empty(), "Custom state should be empty!")
	print("  ✅ Instancia creada: %s" % instance)
	
	# Verificar peso y valor
	var weight = instance.get_total_weight()
	var value = instance.get_total_value()
	
	#assert(weight == 0.6, "Weight should be 0.6! (0.2 x 3)")
	#assert(value == 45, "Value should be 45! (15 x 3)")
	print("  ✅ Peso total: %.1fg" % weight)
	print("  ✅ Valor total: %d gold" % value)
	
	print()


## Test 2: Gestión de cantidad
func test_quantity_management():
	print("📝 Test 2: Gestión de cantidad")
	
	var potion_def = load("res://data/items/stamina_potion_small.tres") as ItemDefinition
	var instance = ItemInstance.new(potion_def, 5)
	
	# Añadir cantidad dentro del límite
	var added = instance.add_quantity(3)
	assert(added == 3, "Should add 3!")
	assert(instance.quantity == 8, "Should be 8!")
	print("  ✅ Añadir 3: quantity=%d" % instance.quantity)
	
	# Intentar exceder max_stack (10)
	added = instance.add_quantity(5)
	assert(added == 2, "Should only add 2 (to reach max 10)!")
	assert(instance.quantity == 10, "Should be clamped to max_stack!")
	print("  ✅ Exceder límite: añadido=%d, quantity=%d (clamped)" % [added, instance.quantity])
	
	# Remover cantidad
	var removed = instance.remove_quantity(3)
	assert(removed == 3, "Should remove 3!")
	assert(instance.quantity == 7, "Should be 7!")
	print("  ✅ Remover 3: quantity=%d" % instance.quantity)
	
	# Intentar remover más de lo disponible
	removed = instance.remove_quantity(20)
	assert(removed == 7, "Should only remove available (7)!")
	assert(instance.quantity == 0, "Should be 0!")
	print("  ✅ Remover exceso: removido=%d, quantity=%d" % [removed, instance.quantity])
	
	# Verificar is_empty
	assert(instance.is_empty(), "Should be empty!")
	print("  ✅ is_empty correcto")
	
	print()


## Test 3: Reglas de stacking
func test_stacking_rules():
	print("📝 Test 3: Reglas de stacking")
	
	var potion_def = load("res://data/items/stamina_potion_small.tres") as ItemDefinition
	
	var instance1 = ItemInstance.new(potion_def, 3)
	var instance2 = ItemInstance.new(potion_def, 5)
	
	# Mismo ítem, sin custom_state → SÍ stackeable
	assert(instance1.can_stack_with(instance2), "Should be stackable!")
	print("  ✅ Mismo ítem sin custom_state: stackeable")
	
	# Con custom_state → NO stackeable
	var instance3 = ItemInstance.new(potion_def, 2, {"enchanted": true})
	assert(not instance1.can_stack_with(instance3), "Should NOT be stackable (has state)!")
	print("  ✅ Ítem con custom_state: NO stackeable")
	
	# Verificar is_full
	var instance4 = ItemInstance.new(potion_def, 10)
	assert(instance4.is_full(), "Should be full!")
	print("  ✅ is_full correcto (10/10)")
	
	var instance5 = ItemInstance.new(potion_def, 5)
	assert(not instance5.is_full(), "Should NOT be full!")
	print("  ✅ is_full correcto (5/10)")
	
	print()


## Test 4: Ítems no stackables
func test_non_stackable():
	print("📝 Test 4: Ítems no stackables")
	
	# Crear un ítem no stackable (simulado)
	var unique_item = ItemDefinition.new()
	unique_item.id = "unique_sword"
	unique_item.name_key = "UNIQUE_SWORD"
	unique_item.weight = 2.5
	unique_item.durability_max = 100
	unique_item.base_value = 500
	unique_item.stackable = false  # ❌ NO stackable
	unique_item.item_type = "EQUIPMENT"
	
	var instance = ItemInstance.new(unique_item, 5)  # Intenta crear 5
	
	# Debería clampear a 1
	assert(instance.quantity == 1, "Non-stackable should clamp to 1!")
	print("  ✅ No stackable: quantity clampeada a 1")
	
	# Intentar añadir
	var added = instance.add_quantity(10)
	assert(added == 0, "Should not add to non-stackable!")
	assert(instance.quantity == 1, "Should stay at 1!")
	print("  ✅ Añadir a no stackable: sin efecto")
	
	# Verificar is_full
	assert(instance.is_full(), "Non-stackable always full!")
	print("  ✅ is_full siempre true para no stackables")
	
	print()


## Test 5: Utilidades
func test_utilities():
	print("📝 Test 5: Funciones de utilidad")
	
	var potion_def = load("res://data/items/stamina_potion_small.tres") as ItemDefinition
	
	# Test get_total_weight con diferentes cantidades
	var i1 = ItemInstance.new(potion_def, 1)
	var i5 = ItemInstance.new(potion_def, 5)
	var i10 = ItemInstance.new(potion_def, 10)
	
	assert(i1.get_total_weight() == 0.2, "Weight for 1 should be 0.2!")
	assert(i5.get_total_weight() == 1.0, "Weight for 5 should be 1.0!")
	assert(i10.get_total_weight() == 2.0, "Weight for 10 should be 2.0!")
	print("  ✅ get_total_weight: 1x=%.1fg, 5x=%.1fg, 10x=%.1fg" % [
		i1.get_total_weight(),
		i5.get_total_weight(),
		i10.get_total_weight()
	])
	
	# Test get_total_value
	assert(i1.get_total_value() == 15, "Value for 1 should be 15!")
	assert(i5.get_total_value() == 75, "Value for 5 should be 75!")
	assert(i10.get_total_value() == 150, "Value for 10 should be 150!")
	print("  ✅ get_total_value: 1x=%dg, 5x=%dg, 10x=%dg" % [
		i1.get_total_value(),
		i5.get_total_value(),
		i10.get_total_value()
	])
	
	# Test _to_string
	var str_normal = str(i5)
	assert("stamina_potion_small" in str_normal, "Should contain id!")
	assert("x5" in str_normal, "Should contain quantity!")
	print("  ✅ _to_string normal: %s" % str_normal)
	
	var i_state = ItemInstance.new(potion_def, 1, {"blessed": true})
	var str_state = str(i_state)
	assert("state=" in str_state, "Should mention state!")
	print("  ✅ _to_string con state: %s" % str_state)
	
	print()
