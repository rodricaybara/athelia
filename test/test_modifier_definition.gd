extends Node

## Test de ModifierDefinition - Día 1
## Valida creación y validación de modificadores

func _ready():
	print("\n" + "=".repeat(50))
	print("SPIKE DÍA 1 - TEST MODIFIER DEFINITION")
	print("=".repeat(50) + "\n")
	
	test_valid_modifier()
	test_invalid_modifiers()
	test_resource_detection()
	
	print("\n" + "=".repeat(50))
	print("✅ MODIFIER DEFINITION VALIDADO")
	print("=".repeat(50) + "\n")


## Test 1: Modificador válido
func test_valid_modifier():
	print("📝 Test 1: Modificador válido")
	
	var modifier = ModifierDefinition.new()
	modifier.target = "resource.stamina"
	modifier.operation = "add"
	modifier.value = 50.0
	modifier.condition = "on_use"
	
	assert(modifier.validate(), "Valid modifier failed validation!")
	
	print("  ✅ Validación pasada")
	print("  ✅ Modifier: %s" % modifier)
	print()


## Test 2: Modificadores inválidos
func test_invalid_modifiers():
	print("📝 Test 2: Validación de errores")
	
	# Target vacío
	var mod1 = ModifierDefinition.new()
	mod1.target = ""
	mod1.operation = "add"
	mod1.value = 10.0
	mod1.condition = "on_use"
	
	assert(not mod1.validate(), "Empty target should fail!")
	print("  ✅ Target vacío detectado")
	
	# Operación inválida
	var mod2 = ModifierDefinition.new()
	mod2.target = "resource.health"
	mod2.operation = "invalid_op"  # ❌
	mod2.value = 10.0
	mod2.condition = "on_use"
	
	assert(not mod2.validate(), "Invalid operation should fail!")
	print("  ✅ Operación inválida detectada")
	
	# Condition vacía
	var mod3 = ModifierDefinition.new()
	mod3.target = "resource.health"
	mod3.operation = "add"
	mod3.value = 10.0
	mod3.condition = ""  # ❌
	
	assert(not mod3.validate(), "Empty condition should fail!")
	print("  ✅ Condition vacía detectada")
	print()


## Test 3: Detección de recursos
func test_resource_detection():
	print("📝 Test 3: Detección de tipo de target")
	
	var mod_resource = ModifierDefinition.new()
	mod_resource.target = "resource.stamina"
	mod_resource.operation = "add"
	mod_resource.value = 50.0
	mod_resource.condition = "on_use"
	
	assert(mod_resource.targets_resource(), "Should target resource!")
	assert(mod_resource.get_resource_id() == "stamina", "Resource ID mismatch!")
	print("  ✅ Detecta target de recurso")
	print("  ✅ Extrae resource_id: '%s'" % mod_resource.get_resource_id())
	
	var mod_stat = ModifierDefinition.new()
	mod_stat.target = "stat.strength"
	mod_stat.operation = "add"
	mod_stat.value = 5.0
	mod_stat.condition = "equipped"
	
	assert(not mod_stat.targets_resource(), "Should NOT target resource!")
	assert(mod_stat.get_resource_id() == "", "Should return empty!")
	print("  ✅ Detecta target NO recurso")
	print()
