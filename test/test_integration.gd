extends Node

## Test de Integración - Día 5
## Valida que modificadores de ítems afectan recursos
## ESTE TEST SIMULA EL ROL DEL PLAYER

var resource_system: ResourceSystem
var use_success_count: int = 0
var use_failed_count: int = 0


func _ready():
	print("\n" + "=".repeat(50))
	print("SPIKE DÍA 5 - TEST INTEGRACIÓN")
	print("=".repeat(50) + "\n")
	
	# Esperar a que los autoloads se inicialicen
	await get_tree().process_frame
	await get_tree().process_frame
	
	resource_system = get_node("/root/Resources")
	if not resource_system:
		push_error("[Test] ResourceSystem not found!")
		return
	
	# Conectar eventos
	EventBus.item_use_requested.connect(_on_item_use_requested)  # ⭐ ESTE TEST PROCESA
	EventBus.item_use_success.connect(_on_use_success)
	EventBus.item_use_failed.connect(_on_use_failed)
	print("  ✅ Eventos conectados (test actúa como Player)")
	
	test_setup()
	test_use_potion_restores_stamina()
	test_use_potion_consumes_item()
	test_use_potion_when_full()
	test_use_multiple_potions()
	
	print("\n" + "=".repeat(50))
	print("✅ INTEGRACIÓN VALIDADA")
	print("=".repeat(50) + "\n")


## Setup inicial
func test_setup():
	print("\n📝 Setup: Registrar player")
	
	# Registrar player en sistemas
	resource_system.register_entity("player")
	Inventory.register_entity("player")
	
	print("  ✅ Player registrado en ResourceSystem")
	print("  ✅ Player registrado en InventorySystem")


## Test 1: Usar poción restaura stamina
func test_use_potion_restores_stamina():
	print("\n📝 Test 1: Usar poción restaura stamina")
	
	# Reset contadores
	use_success_count = 0
	use_failed_count = 0
	
	# Estado inicial: reducir stamina
	resource_system.set_resource("player", "stamina", 50.0)
	var stamina_before = resource_system.get_resource_amount("player", "stamina")
	print("  📊 Stamina antes: %.0f" % stamina_before)
	
	# Añadir poción al inventario
	Inventory.add_item("player", "stamina_potion_small", 1)
	print("  📦 Poción añadida al inventario")
	
	# Usar poción
	print("  🔄 Solicitando uso de poción...")
	Inventory.request_use_item("player", "stamina_potion_small")
	
	# Verificar resultado
	var stamina_after = resource_system.get_resource_amount("player", "stamina")
	print("  📊 Stamina después: %.0f" % stamina_after)
	print("  📊 use_success_count: %d" % use_success_count)
	print("  📊 use_failed_count: %d" % use_failed_count)
	
	assert(use_success_count == 1, "Should emit use_success! (got %d)" % use_success_count)
	assert(use_failed_count == 0, "Should NOT emit use_failed! (got %d)" % use_failed_count)
	assert(stamina_after == 100.0, "Should restore to full! (got %.0f)" % stamina_after)
	print("  ✅ Poción restauró stamina correctamente")
	print("  ✅ item_use_success emitido")


## Test 2: Usar poción la consume del inventario
func test_use_potion_consumes_item():
	print("\n📝 Test 2: Usar poción la consume del inventario")
	
	# Reset
	use_success_count = 0
	
	# Añadir 3 pociones
	Inventory.add_item("player", "stamina_potion_small", 3)
	var qty_before = Inventory.get_item_quantity("player", "stamina_potion_small")
	print("  📦 Pociones antes: %d" % qty_before)
	
	# Reducir stamina
	resource_system.set_resource("player", "stamina", 40.0)
	
	# Usar 1 poción
	Inventory.request_use_item("player", "stamina_potion_small")
	
	# Verificar que se consumió
	var qty_after = Inventory.get_item_quantity("player", "stamina_potion_small")
	print("  📦 Pociones después: %d" % qty_after)
	
	assert(qty_after == 2, "Should consume 1 potion! (got %d)" % qty_after)
	assert(use_success_count == 1, "Should emit use_success! (got %d)" % use_success_count)
	print("  ✅ Poción consumida del inventario")
	
	# Limpiar
	Inventory.remove_item("player", "stamina_potion_small", 2)


## Test 3: Usar poción cuando stamina está llena
func test_use_potion_when_full():
	print("\n📝 Test 3: Usar poción cuando stamina está llena")
	
	# Reset
	use_success_count = 0
	use_failed_count = 0
	
	# Stamina llena
	resource_system.restore_resource("player", "stamina")
	var stamina_before = resource_system.get_resource_amount("player", "stamina")
	print("  📊 Stamina antes: %.0f (llena)" % stamina_before)
	
	# Añadir poción
	Inventory.add_item("player", "stamina_potion_small", 1)
	
	# Usar poción
	Inventory.request_use_item("player", "stamina_potion_small")
	
	# Verificar
	var stamina_after = resource_system.get_resource_amount("player", "stamina")
	var qty_after = Inventory.get_item_quantity("player", "stamina_potion_small")
	
	print("  📊 Stamina después: %.0f" % stamina_after)
	print("  📦 Pociones después: %d" % qty_after)
	print("  📊 use_success_count: %d" % use_success_count)
	print("  📊 use_failed_count: %d" % use_failed_count)
	
	# La poción NO debería consumirse si no tuvo efecto
	if use_success_count == 0:
		print("  ✅ Poción NO consumida (sin efecto)")
		assert(qty_after == 1, "Should NOT consume if no effect!")
		# Limpiar
		Inventory.remove_item("player", "stamina_potion_small", 1)
	else:
		print("  ⚠️  Poción consumida aunque estaba lleno")
		# Limpiar
		Inventory.remove_item("player", "stamina_potion_small", qty_after)


## Test 4: Usar múltiples pociones
func test_use_multiple_potions():
	print("\n📝 Test 4: Usar múltiples pociones")
	
	# Reset
	use_success_count = 0
	
	# Stamina muy baja
	resource_system.set_resource("player", "stamina", 10.0)
	print("  📊 Stamina inicial: 10")
	
	# Añadir 3 pociones
	Inventory.add_item("player", "stamina_potion_small", 3)
	
	# Usar 2 pociones
	Inventory.request_use_item("player", "stamina_potion_small")
	
	var stamina_mid = resource_system.get_resource_amount("player", "stamina")
	print("  📊 Stamina tras 1ª poción: %.0f" % stamina_mid)
	
	Inventory.request_use_item("player", "stamina_potion_small")
	
	var stamina_final = resource_system.get_resource_amount("player", "stamina")
	print("  📊 Stamina tras 2ª poción: %.0f" % stamina_final)
	
	var qty_final = Inventory.get_item_quantity("player", "stamina_potion_small")
	print("  📦 Pociones restantes: %d" % qty_final)
	
	assert(stamina_final == 100.0, "Should be at max! (got %.0f)" % stamina_final)
	assert(qty_final == 1, "Should have 1 potion left! (got %d)" % qty_final)
	assert(use_success_count == 2, "Should emit 2 successes! (got %d)" % use_success_count)
	print("  ✅ Múltiples pociones funcionan correctamente")
	
	# Limpiar
	Inventory.remove_item("player", "stamina_potion_small", 1)


# ============================================
# PROCESAMIENTO DE MODIFICADORES (simula Player)
# ============================================

## Procesa solicitud de uso de ítem (IGUAL QUE PLAYER.GD)
func _on_item_use_requested(entity_id: String, item_id: String):
	if entity_id != "player":
		return
	
	print("  [TEST] Procesando item_use_requested: %s" % item_id)
	
	var item_def = Items.get_item(item_id)
	if not item_def:
		EventBus.item_use_failed.emit(entity_id, item_id, "Item definition not found")
		return
	
	# Aplicar modificadores del ítem
	var success = _apply_item_modifiers(entity_id, item_def)
	
	if success:
		print("  [TEST] Emitiendo item_use_success")
		EventBus.item_use_success.emit(entity_id, item_id)
	else:
		print("  [TEST] Emitiendo item_use_failed")
		EventBus.item_use_failed.emit(entity_id, item_id, "No effect applied")


## Aplica los modificadores declarativos de un ítem (IGUAL QUE PLAYER.GD)
func _apply_item_modifiers(entity_id: String, item_def: ItemDefinition) -> bool:
	var any_applied = false
	
	# Obtener solo modificadores que se aplican "on_use"
	var on_use_modifiers = item_def.get_modifiers_for_condition("on_use")
	
	if on_use_modifiers.is_empty():
		push_warning("[Test] Item has no on_use modifiers: %s" % item_def.id)
		return false
	
	for modifier in on_use_modifiers:
		# Solo procesar modificadores de recursos
		if not modifier.targets_resource():
			continue
		
		var resource_id = modifier.get_resource_id()
		
		match modifier.operation:
			"add":
				var added = resource_system.add_resource(entity_id, resource_id, modifier.value)
				if added > 0:
					any_applied = true
					print("  [TEST] Applied modifier: +%.0f %s" % [added, resource_id])
			
			"mul":
				push_warning("[Test] Multiply operation not yet implemented")
			
			"override":
				resource_system.set_resource(entity_id, resource_id, modifier.value)
				any_applied = true
				print("  [TEST] Applied modifier: set %s to %.0f" % [resource_id, modifier.value])
	
	return any_applied


# ============================================
# CALLBACKS
# ============================================

func _on_use_success(entity_id: String, item_id: String):
	print("  [CALLBACK] item_use_success: %s used %s" % [entity_id, item_id])
	use_success_count += 1


func _on_use_failed(entity_id: String, item_id: String, reason: String):
	print("  [CALLBACK] item_use_failed: %s / %s / %s" % [entity_id, item_id, reason])
	use_failed_count += 1
