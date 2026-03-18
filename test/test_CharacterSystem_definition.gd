extends Node

## Test de Validación - FASE 1
## CharacterDefinition + CharacterState

func _ready():
	print("\n" + "=".repeat(50))
	print("FASE 1 - TEST DE VALIDACIÓN")
	print("CharacterDefinition + CharacterState")
	print("\n" + "=".repeat(50))
	
	await get_tree().create_timer(0.2).timeout
	
	test_character_definition_validation()
	await get_tree().create_timer(0.2).timeout
	
	test_character_definition_loading()
	await get_tree().create_timer(0.2).timeout
	
	test_character_state_creation()
	await get_tree().create_timer(0.2).timeout
	
	test_character_state_attributes()
	await get_tree().create_timer(0.2).timeout
	
	test_character_state_resources()
	await get_tree().create_timer(0.2).timeout
	
	test_character_state_modifiers()
	await get_tree().create_timer(0.2).timeout
	
	print("\n" + "=".repeat(50))
	print("✅ FASE 1 COMPLETADA - TODOS LOS TESTS PASARON")
	print("\n" + "=".repeat(50))
	
	print("Siguiente paso: Implementar FASE 2 (CharacterSystem)")


## TEST 1: Validación de CharacterDefinition
func test_character_definition_validation():
	print("\n--- TEST 1: Validación de CharacterDefinition ---")
	
	# Crear definición válida
	var valid_def = CharacterDefinition.new()
	valid_def.id = "test_char"
	valid_def.name_key = "test.name"
	valid_def.base_attributes = {
		"strength": 10,
		"dexterity": 10,
		"constitution": 10
	}
	valid_def.starting_resources = {
		"health": 30,
		"stamina": 20
	}
	
	assert(valid_def.validate(), "Valid definition should pass")
	print("✓ Definición válida pasó la validación")
	
	# Crear definición inválida (sin ID)
	var invalid_def = CharacterDefinition.new()
	invalid_def.name_key = "test.name"
	invalid_def.base_attributes = { "strength": 10 }
	
	assert(not invalid_def.validate(), "Invalid definition should fail")
	print("✓ Definición sin ID falló correctamente")
	
	# Definición con atributo negativo
	var negative_def = CharacterDefinition.new()
	negative_def.id = "test"
	negative_def.name_key = "test.name"
	negative_def.base_attributes = { "strength": -5 }
	
	assert(not negative_def.validate(), "Negative attribute should fail")
	print("✓ Atributo negativo rechazado correctamente")
	
	print("✅ Test 1 PASSED")


## TEST 2: Carga de definiciones desde archivos
func test_character_definition_loading():
	print("\n--- TEST 2: Carga de Definiciones ---")
	
	# Intentar cargar player_base.tres
	var player_def = load("res://data/characters/player_base.tres") as CharacterDefinition
	
	if player_def == null:
		print("⚠️  No se pudo cargar player_base.tres (archivo no existe aún)")
		print("   Esto es normal si no se ha copiado a res://data/characters/")
		return
	
	assert(player_def.validate(), "player_base.tres debe ser válido")
	print("✓ player_base.tres cargado: %s" % player_def.id)
	print("  STR=%d, DEX=%d, CON=%d" % [
		player_def.get_base_attribute("strength"),
		player_def.get_base_attribute("dexterity"),
		player_def.get_base_attribute("constitution")
	])
	
	# Intentar cargar wolf_test.tres
	var wolf_def = load("res://data/characters/wolf_test.tres") as CharacterDefinition
	
	if wolf_def:
		assert(wolf_def.validate(), "wolf_test.tres debe ser válido")
		print("✓ wolf_test.tres cargado: %s" % wolf_def.id)
	
	print("✅ Test 2 PASSED")


## TEST 3: Creación de CharacterState
func test_character_state_creation():
	print("\n--- TEST 3: Creación de CharacterState ---")
	
	# Crear definición mock
	var def = CharacterDefinition.new()
	def.id = "test_warrior"
	def.name_key = "test.warrior.name"
	def.base_attributes = {
		"strength": 15,
		"dexterity": 10,
		"constitution": 12
	}
	def.starting_resources = {
		"health": 40,
		"stamina": 30
	}
	
	assert(def.validate(), "Mock definition should be valid")
	
	# Crear estado
	var state = CharacterState.new(def)
	
	assert(state != null, "State should be created")
	assert(state.definition == def, "State should reference definition")
	print("✓ CharacterState creado correctamente")
	
	# Verificar que los atributos se copiaron
	assert(state.get_base_attribute("strength") == 15, "STR should be 15")
	assert(state.get_base_attribute("dexterity") == 10, "DEX should be 10")
	assert(state.get_base_attribute("constitution") == 12, "CON should be 12")
	print("✓ Atributos base copiados correctamente")
	
	# Verificar que los recursos se copiaron
	assert(state.get_resource("health") == 40, "HP should be 40")
	assert(state.get_resource("stamina") == 30, "STA should be 30")
	print("✓ Recursos iniciales copiados correctamente")
	
	print("✅ Test 3 PASSED")


## TEST 4: Modificación de atributos base
func test_character_state_attributes():
	print("\n--- TEST 4: Modificación de Atributos Base ---")
	
	var def = CharacterDefinition.new()
	def.id = "test"
	def.name_key = "test.name"
	def.base_attributes = { "strength": 10, "dexterity": 10 }
	def.starting_resources = { "health": 30 }
	
	var state = CharacterState.new(def)
	
	# Modificar atributo
	var old_str = state.get_base_attribute("strength")
	state.modify_base_attribute("strength", 5)
	var new_str = state.get_base_attribute("strength")
	
	assert(new_str == old_str + 5, "STR should increase by 5")
	print("✓ modify_base_attribute: %d → %d" % [old_str, new_str])
	
	# Establecer atributo directamente
	state.set_base_attribute("dexterity", 20)
	assert(state.get_base_attribute("dexterity") == 20, "DEX should be 20")
	print("✓ set_base_attribute: DEX = 20")
	
	# Verificar mínimo (no debe ser < 1)
	state.set_base_attribute("strength", -10)
	assert(state.get_base_attribute("strength") >= 1, "Attribute should not go below 1")
	print("✓ Mínimo de atributos respetado (>= 1)")
	
	print("✅ Test 4 PASSED")


## TEST 5: Gestión de recursos
func test_character_state_resources():
	print("\n--- TEST 5: Gestión de Recursos ---")
	
	var def = CharacterDefinition.new()
	def.id = "test"
	def.name_key = "test.name"
	def.base_attributes = { "strength": 10 }
	def.starting_resources = { "health": 50, "stamina": 30, "gold": 100 }
	
	var state = CharacterState.new(def)
	
	# Obtener recurso
	assert(state.get_resource("health") == 50, "HP should be 50")
	print("✓ get_resource: health = 50")
	
	# Modificar recurso
	state.modify_resource("health", -10)
	assert(state.get_resource("health") == 40, "HP should be 40 after damage")
	print("✓ modify_resource: health -= 10 → 40")
	
	# Establecer recurso
	state.set_resource("stamina", 15)
	assert(state.get_resource("stamina") == 15, "Stamina should be 15")
	print("✓ set_resource: stamina = 15")
	
	# Recurso nuevo (no estaba en definition)
	state.set_resource("mana", 50)
	assert(state.get_resource("mana") == 50, "New resource should work")
	print("✓ Nuevo recurso creado dinámicamente: mana = 50")
	
	print("✅ Test 5 PASSED")


## TEST 6: Modificadores equipados
func test_character_state_modifiers():
	print("\n--- TEST 6: Modificadores Equipados ---")
	
	var def = CharacterDefinition.new()
	def.id = "test"
	def.name_key = "test.name"
	def.base_attributes = { "strength": 10 }
	def.starting_resources = { "health": 30 }
	
	var state = CharacterState.new(def)
	
	# Crear modificador mock
	var mod1 = ModifierDefinition.new()
	mod1.target = "attribute.health_max"
	mod1.operation = "add"
	mod1.value = 20.0
	
	var mod2 = ModifierDefinition.new()
	mod2.target = "attribute.strength"
	mod2.operation = "add"
	mod2.value = 5.0
	
	# Añadir modificadores
	state.add_equipped_modifier(mod1)
	state.add_equipped_modifier(mod2)
	
	var mods = state.get_equipped_modifiers()
	assert(mods.size() == 2, "Should have 2 modifiers")
	print("✓ Añadidos 2 modificadores equipados")
	
	# Remover modificador
	var removed = state.remove_equipped_modifier(mod1)
	assert(removed, "Should remove successfully")
	assert(state.get_equipped_modifiers().size() == 1, "Should have 1 modifier left")
	print("✓ Removido 1 modificador, queda 1")
	
	# Estados temporales (preparación para Fase 4)
	var temp_state = {
		"id": "vigor_buff",
		"modifiers": [mod1],
		"duration": 5.0,
		"time_left": 5.0
	}
	state.add_temporary_state(temp_state)
	
	var all_mods = state.get_all_active_modifiers()
	assert(all_mods.size() == 2, "Should have 2 total (1 equipped + 1 temp)")
	print("✓ Estados temporales funcionando (1 equipado + 1 temporal = 2 total)")
	
	print("✅ Test 6 PASSED")
