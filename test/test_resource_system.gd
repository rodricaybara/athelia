extends Node

## Test del ResourceSystem
## Crear una escena con este script adjunto y ejecutar

var resource_system: ResourceSystem

func _ready():
	# Crear el ResourceSystem como nodo hijo
	resource_system = ResourceSystem.new()
	add_child(resource_system)
	
	# Esperar un frame para que se inicialice
	await get_tree().process_frame
	
	print("\n=== Testing ResourceSystem ===")
	
	test_entity_registration()
	test_resource_operations()
	test_bundle_payment()
	test_regeneration()
	test_events()
	
	print("\n=== ResourceSystem tests complete ===\n")


func test_entity_registration():
	print("\n--- Test: Entity Registration ---")
	
	# Registrar jugador con todos los recursos
	resource_system.register_entity("player")
	resource_system.print_entity_resources("player")
	
	# Registrar enemigo solo con health y stamina
	resource_system.register_entity("enemy_01", ["health", "stamina"])
	resource_system.print_entity_resources("enemy_01")
	
	print("✓ Entity registration OK")


func test_resource_operations():
	print("\n--- Test: Resource Operations ---")
	
	# Obtener valor
	var health = resource_system.get_resource_amount("player", "health")
	print("Player health: ", health)
	assert(health == 100.0, "Should start at max")
	
	# Restar vida
	resource_system.set_resource("player", "health", 50.0)
	health = resource_system.get_resource_amount("player", "health")
	print("After damage: ", health)
	assert(health == 50.0, "Should be 50")
	
	# Añadir vida (curación)
	var healed = resource_system.add_resource("player", "health", 30.0)
	print("Healed: ", healed)
	assert(healed == 30.0, "Should heal 30")
	
	# Restaurar al máximo
	resource_system.restore_resource("player", "health")
	health = resource_system.get_resource_amount("player", "health")
	print("After restore: ", health)
	assert(health == 100.0, "Should be full")
	
	print("✓ Resource operations OK")


func test_bundle_payment():
	print("\n--- Test: Bundle Payment ---")
	
	# Crear un coste mixto (habilidad que cuesta stamina + gold)
	var skill_cost = ResourceBundle.new()
	skill_cost.add_cost("stamina", 25.0)
	skill_cost.add_cost("gold", 10.0)
	
	print("Skill cost: ", skill_cost)
	
	# Verificar que puede pagar
	var can_pay = resource_system.can_pay("player", skill_cost)
	print("Can pay: ", can_pay)
	assert(can_pay, "Should be able to pay")
	
	# Aplicar coste
	var paid = resource_system.apply_cost("player", skill_cost)
	print("Payment success: ", paid)
	assert(paid, "Should succeed")
	
	resource_system.print_entity_resources("player")
	
	# Intentar pagar sin suficiente stamina
	var expensive_cost = ResourceBundle.new()
	expensive_cost.add_cost("stamina", 200.0)
	
	can_pay = resource_system.can_pay("player", expensive_cost)
	print("\nCan pay expensive cost: ", can_pay)
	assert(not can_pay, "Should not be able to pay")
	
	print("✓ Bundle payment OK")


func test_regeneration():
	print("\n--- Test: Regeneration ---")
	
	# Consumir stamina
	resource_system.set_resource("player", "stamina", 50.0)
	print("Stamina before regen: ", resource_system.get_resource_amount("player", "stamina"))
	
	# Esperar 3 segundos para regeneración
	print("Waiting 3 seconds for regeneration...")
	await get_tree().create_timer(3.0).timeout
	
	var stamina_after = resource_system.get_resource_amount("player", "stamina")
	print("Stamina after 3s: ", stamina_after)
	assert(stamina_after > 50.0, "Should have regenerated")
	
	print("✓ Regeneration OK")


func test_events():
	print("\n--- Test: Events ---")
	
	# Conectar a señales
	resource_system.resource_changed.connect(_on_resource_changed)
	resource_system.resource_depleted.connect(_on_resource_depleted)
	resource_system.payment_failed.connect(_on_payment_failed)
	
	print("Listening for events...")
	
	# Provocar cambio
	resource_system.set_resource("player", "health", 10.0)
	
	# Provocar agotamiento
	resource_system.set_resource("player", "health", 0.0)
	
	# Provocar fallo de pago
	var impossible_cost = ResourceBundle.new()
	impossible_cost.add_cost("stamina", 999.0)
	resource_system.apply_cost("player", impossible_cost)
	
	await get_tree().create_timer(0.5).timeout
	
	print("✓ Events OK")


func _on_resource_changed(entity_id: String, resource_id: String, current: float, max_value: float):
	print("  [EVENT] ResourceChanged: %s.%s = %.1f/%.1f" % [entity_id, resource_id, current, max_value])


func _on_resource_depleted(entity_id: String, resource_id: String):
	print("  [EVENT] ResourceDepleted: %s.%s" % [entity_id, resource_id])


func _on_payment_failed(entity_id: String, bundle: ResourceBundle):
	print("  [EVENT] PaymentFailed: %s cannot pay %s" % [entity_id, bundle])
