extends Node

## Test End-to-End Manual - Día 7
## Validación completa del flujo: jugar → guardar → cargar

func _ready():
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("\n" + "=".repeat(60))
	print("TEST END-TO-END MANUAL - DÍA 7")
	print("=".repeat(60))
	
	_setup_test_scenario()
	_print_instructions()


func _setup_test_scenario():
	# Registrar player
	var res_system = get_node("/root/Resources")
	if not res_system._entities.has("player"):
		res_system.register_entity("player")
	
	if not Inventory.get_inventory("player"):
		Inventory.register_entity("player")
	
	# Escenario de prueba
	Inventory.add_item("player", "stamina_potion_small", 8)
	res_system.set_resource("player", "stamina", 60.0)
	res_system.set_resource("player", "health", 80.0)
	
	print("\n📦 ESCENARIO INICIAL:")
	print("  - Pociones: 8")
	print("  - Stamina: 60")
	print("  - Health: 80")


func _print_instructions():
	print("\n📋 INSTRUCCIONES DEL TEST:")
	print("=".repeat(50) + "\n")
	print("1️⃣  FASE 1: USAR ÍTEMS")
	print("   - Pulsa I para abrir inventario")
	print("   - Usa 3 pociones")
	print("   - Verifica que quedan 5 pociones")
	print("   - Cierra inventario")
	print()
	print("2️⃣  FASE 2: GUARDAR")
	print("   - Pulsa F5 (quicksave)")
	print("   - Espera mensaje 'Partida guardada'")
	print("   - Anota mentalmente: 5 pociones, stamina alta")
	print()
	print("3️⃣  FASE 3: MODIFICAR ESTADO")
	print("   - Abre inventario (I)")
	print("   - Usa 2 pociones más")
	print("   - Deberían quedar 3 pociones")
	print("   - Cierra inventario")
	print()
	print("4️⃣  FASE 4: CARGAR")
	print("   - Pulsa F9 (quickload)")
	print("   - Espera mensaje 'Partida cargada'")
	print()
	print("5️⃣  FASE 5: VERIFICAR")
	print("   - Abre inventario (I)")
	print("   - ✅ ESPERADO: 5 pociones (estado guardado)")
	print("   - ✅ ESPERADO: Stamina restaurada al valor guardado")
	print("   - ❌ INCORRECTO: 3 pociones (estado no restaurado)")
	print()
	print("6️⃣  VALIDACIÓN:")
	print("   - Si tienes 5 pociones → ✅ SAVE/LOAD FUNCIONAL")
	print("   - Si tienes 3 pociones → ❌ PROBLEMA DE PERSISTENCIA")
	print("=".repeat(50) + "\n")
	print("\n🎯 ¡Comienza el test!\n")


func _input(event):
	# Atajos de debug
	if event.is_action_pressed("ui_home"):
		print("\n[DEBUG] Estado actual:")
		Inventory.print_inventory("player")
		
		var res_system = get_node("/root/Resources")
		var stamina = res_system.get_resource_amount("player", "stamina")
		print("  Stamina: %.0f" % stamina)
