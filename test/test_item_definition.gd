extends Node

## Test de ItemDefinition - Día 2
## Valida propiedades v2 (peso, durabilidad, valor)

func _ready():
	print("\n" + "=".repeat(50))
	print("SPIKE DÍA 2 - TEST ITEM DEFINITION")
	print("=".repeat(50) + "\n")
	
	test_load_potion()
	test_validation_rules()
	test_modifiers()
	test_utilities()
	
	print("\n" + "=".repeat(50))
	print("✅ ITEM DEFINITION VALIDADO")
	print("=".repeat(50) + "\n")


## Test 1: Cargar poción desde .tres
func test_load_potion():
	print("📝 Test 1: Cargar Poción de Estamina")
	
	var potion = load("res://data/items/stamina_potion_small.tres") as ItemDefinition
	
	assert(potion != null, "Failed to load potion!")
	print("  ✅ Archivo .tres cargado correctamente")
	
	# Validar estructura
	assert(potion.validate(), "Potion validation failed!")
	print("  ✅ Validación pasada")
	
	# Verificar propiedades v2
	assert(potion.weight == 0.2, "Weight mismatch!")
	assert(potion.durability_max == 1, "Durability mismatch!")
	assert(potion.base_value == 15, "Value mismatch!")
	print("  ✅ Propiedades v2 correctas: %.1fg, durability=%d, value=%d" % [
		potion.weight,
		potion.durability_max,
		potion.base_value
	])
	
	# Verificar clasificación
	assert(potion.item_type == "CONSUMABLE", "Type mismatch!")
	assert(potion.stackable == true, "Should be stackable!")
	assert(potion.max_stack == 10, "Max stack mismatch!")
	print("  ✅ Clasificación correcta: CONSUMABLE, stackable, max=10")
	
	# Verificar tags
	assert(potion.has_tag("consumable"), "Missing tag: consumable")
	assert(potion.has_tag("potion"), "Missing tag: potion")
	assert(potion.has_tag("stamina"), "Missing tag: stamina")
	print("  ✅ Tags correctos: %s" % ", ".join(potion.tags))
	
	print("  ✅ Poción: %s" % potion)
	print()


## Test 2: Reglas de validación
func test_validation_rules():
	print("📝 Test 2: Reglas de validación")
	
	# Test: peso mínimo
	var item1 = ItemDefinition.new()
	item1.id = "test_item"
	item1.name_key = "TEST"
	item1.weight = 0.05  # ❌ < 0.1
	
	assert(not item1.validate(), "Should fail: weight < 0.1")
	print("  ✅ Rechaza peso < 0.1")
	
	# Test: durabilidad mínima
	var item2 = ItemDefinition.new()
	item2.id = "test_item"
	item2.name_key = "TEST"
	item2.weight = 0.1
	item2.durability_max = 0  # ❌ < 1
	
	assert(not item2.validate(), "Should fail: durability < 1")
	print("  ✅ Rechaza durabilidad < 1")
	
	# Test: valor negativo
	var item3 = ItemDefinition.new()
	item3.id = "test_item"
	item3.name_key = "TEST"
	item3.weight = 0.1
	item3.durability_max = 1
	item3.base_value = -10  # ❌ negativo
	
	assert(not item3.validate(), "Should fail: negative value")
	print("  ✅ Rechaza valor negativo")
	
	# Test: ID vacío
	var item4 = ItemDefinition.new()
	item4.id = ""  # ❌ vacío
	item4.name_key = "TEST"
	
	assert(not item4.validate(), "Should fail: empty id")
	print("  ✅ Rechaza ID vacío")
	
	# Test: name_key vacío
	var item5 = ItemDefinition.new()
	item5.id = "test"
	item5.name_key = ""  # ❌ vacío
	
	assert(not item5.validate(), "Should fail: empty name_key")
	print("  ✅ Rechaza name_key vacío")
	
	print()


## Test 3: Modificadores
func test_modifiers():
	print("📝 Test 3: Modificadores de la poción")
	
	var potion = load("res://data/items/stamina_potion_small.tres") as ItemDefinition
	
	assert(potion.has_modifiers(), "Potion should have modifiers!")
	print("  ✅ Tiene modificadores")
	
	assert(potion.modifiers.size() == 1, "Should have exactly 1 modifier!")
	print("  ✅ Tiene exactamente 1 modificador")
	
	var mod = potion.modifiers[0]
	assert(mod.target == "resource.stamina", "Target mismatch!")
	assert(mod.operation == "add", "Operation mismatch!")
	assert(mod.value == 50.0, "Value mismatch!")
	assert(mod.condition == "on_use", "Condition mismatch!")
	print("  ✅ Modificador correcto: %s" % mod)
	
	# Test: obtener modificadores por condición
	var on_use_mods = potion.get_modifiers_for_condition("on_use")
	assert(on_use_mods.size() == 1, "Should have 1 on_use modifier!")
	print("  ✅ get_modifiers_for_condition funcional")
	
	print()


## Test 4: Utilidades
func test_utilities():
	print("📝 Test 4: Funciones de utilidad")
	
	var potion = load("res://data/items/stamina_potion_small.tres") as ItemDefinition
	
	# Test: peso total
	var weight_1 = potion.get_total_weight(1)
	var weight_5 = potion.get_total_weight(5)
	
	assert(weight_1 == 0.2, "Weight for 1 should be 0.2!")
	assert(weight_5 == 1.0, "Weight for 5 should be 1.0!")
	print("  ✅ get_total_weight: 1x=%.1fg, 5x=%.1fg" % [weight_1, weight_5])
	
	# Test: tags
	assert(potion.has_tag("potion"), "Should have 'potion' tag!")
	assert(not potion.has_tag("weapon"), "Should NOT have 'weapon' tag!")
	print("  ✅ has_tag funcional")
	
	# Test: _to_string
	var str_repr = str(potion)
	assert("stamina_potion_small" in str_repr, "String should contain id!")
	print("  ✅ _to_string: %s" % str_repr)
	
	print()
