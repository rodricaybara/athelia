extends Node

## Script de prueba temporal para ResourceState
## Adjuntar a un Node en la escena y ejecutar

func _ready():
	print("\n=== Testing ResourceState ===")
	
	test_basic_operations()
	test_regeneration()
	test_infinite_resource()
	test_negative_resource()
	
	print("\n=== ResourceState tests complete ===\n")


func test_basic_operations():
	print("\n--- Test: Basic Operations ---")
	
	var health_def = load("res://data/resources/health.tres") as ResourceDefinition
	var state = ResourceState.new(health_def)
	
	print("Initial state: ", state)
	assert(state.current == 100.0, "Should start at max")
	assert(state.is_full(), "Should be full")
	
	# Consumir vida
	var consumed = state.subtract(30.0)
	print("After taking 30 damage: ", state)
	assert(consumed == 30.0, "Should consume exactly 30")
	assert(state.current == 70.0, "Should be at 70")
	
	# Intentar consumir más de lo disponible
	consumed = state.subtract(100.0)
	print("After trying to take 100 damage: ", state)
	assert(state.current == 0.0, "Should be at 0")
	assert(state.is_empty(), "Should be empty")
	
	# Restaurar
	state.restore_full()
	print("After restore: ", state)
	assert(state.is_full(), "Should be full again")
	
	print("✓ Basic operations OK")


func test_regeneration():
	print("\n--- Test: Regeneration ---")
	
	var stamina_def = load("res://data/resources/stamina.tres") as ResourceDefinition
	var state = ResourceState.new(stamina_def)
	
	# Consumir stamina
	state.subtract(50.0)
	print("After using 50 stamina: ", state)
	assert(state.current == 50.0, "Should be at 50")
	
	# Simular 1 segundo (no debería regenerar por el delay de 2s)
	var regen = state.process_regeneration(1.0)
	print("After 1 second: ", state, " (regen: ", regen, ")")
	assert(regen == 0.0, "Should not regen yet (delay = 2s)")
	
	# Simular 1.5 segundos más (total 2.5s, debería regenerar)
	regen = state.process_regeneration(1.5)
	print("After 2.5 seconds total: ", state, " (regen: ", regen, ")")
	assert(regen > 0.0, "Should start regenerating")
	
	# Simular regeneración completa
	for i in range(10):
		state.process_regeneration(0.5)
	print("After full regeneration: ", state)
	assert(state.is_full(), "Should be full")
	
	print("✓ Regeneration OK")


func test_infinite_resource():
	print("\n--- Test: Infinite Resource ---")
	
	# Crear un recurso infinito (como stamina de enemigos)
	var enemy_stamina_def = ResourceDefinition.new()
	enemy_stamina_def.id = "enemy_stamina"
	enemy_stamina_def.max_base = 100000.0
	enemy_stamina_def.is_infinite = true
	
	var state = ResourceState.new(enemy_stamina_def)
	
	print("Infinite resource: ", state)
	assert(state.can_pay(999999.0), "Should always be able to pay")
	
	state.subtract(500000.0)
	print("After consuming 500k: ", state)
	assert(state.can_pay(999999.0), "Should still be able to pay anything")
	
	print("✓ Infinite resource OK")


func test_negative_resource():
	print("\n--- Test: Negative Allowed ---")
	
	# Crear un recurso que permite negativos (para deudas)
	var debt_def = ResourceDefinition.new()
	debt_def.id = "debt"
	debt_def.max_base = 1000.0
	debt_def.allow_negative = true
	
	var state = ResourceState.new(debt_def, 50.0)
	
	print("Negative-allowed resource: ", state)
	state.subtract(100.0)
	print("After consuming more than available: ", state)
	assert(state.current == -50.0, "Should allow negative")
	assert(state.can_pay(999999.0), "Should always be able to pay")
	
	print("✓ Negative resource OK")
