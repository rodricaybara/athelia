extends Node

## Debug Script - Test de Señales de CharacterSystem
## Usa este script si tienes problemas con las señales en el Test 7

var Characters: CharacterSystem

func _ready():
	print("\n" + "=".repeat(50))
	print("DEBUG - Test de Señales CharacterSystem")
	print("\n" + "=".repeat(50))
	
	await get_tree().create_timer(0.5).timeout
	
	# Obtener singleton
	Characters = get_node_or_null("/root/Characters")
	
	if not Characters:
		print("❌ CharacterSystem no encontrado como autoload")
		return
	
	print("✓ CharacterSystem encontrado\n")
	
	# Crear entidad de prueba
	var test_def = CharacterDefinition.new()
	test_def.id = "debug_test"
	test_def.name_key = "debug.test"
	test_def.base_attributes = {
		"strength": 10,
		"dexterity": 10,
		"constitution": 10,
		"intelligence": 10,
		"wisdom": 10,
		"charisma": 10
	}
	test_def.starting_resources = { "health": 30 }
	
	Characters._definitions["debug_test"] = test_def
	Characters.register_entity("debug_entity", "debug_test")
	
	print("✓ Entidad de debug creada\n")
	
	test_signal_basic()
	await get_tree().create_timer(0.5).timeout
	
	test_signal_with_lambda()
	await get_tree().create_timer(0.5).timeout
	
	test_signal_with_method()
	await get_tree().create_timer(0.5).timeout
	
	print("\n" + "=".repeat(50))
	print("Debug completado")
	print("\n" + "=".repeat(50))


## Test 1: Señal básica sin callback
func test_signal_basic():
	print("\n--- DEBUG 1: Señal Básica ---")
	
	print("Lista de señales del CharacterSystem:")
	for sig in Characters.get_signal_list():
		print("  - %s" % sig["name"])
	
	print("\n¿Tiene la señal 'base_attribute_changed'?")
	print("  → %s" % Characters.has_signal("base_attribute_changed"))
	
	print("\nConexiones actuales de 'base_attribute_changed':")
	var connections = Characters.get_signal_connection_list("base_attribute_changed")
	print("  → %d conexiones" % connections.size())


## Test 2: Con lambda callback
func test_signal_with_lambda():
	print("\n--- DEBUG 2: Callback con Lambda ---")
	
	var event_received = false
	var details = {}
	
	var callback = func(entity_id: String, attr_id: String, old_val: float, new_val: float):
		print("  [Lambda] ¡Evento recibido!")
		print("    entity_id: %s" % entity_id)
		print("    attr_id: %s" % attr_id)
		print("    old_val: %.1f" % old_val)
		print("    new_val: %.1f" % new_val)
		event_received = true
		details = {
			"entity": entity_id,
			"attr": attr_id,
			"old": old_val,
			"new": new_val
		}
	
	print("Conectando callback lambda...")
	Characters.base_attribute_changed.connect(callback)
	
	print("Modificando atributo...")
	var before = Characters.get_base_attribute("debug_entity", "strength")
	print("  Valor antes: %.1f" % before)
	
	Characters.modify_base_attribute("debug_entity", "strength", 5)
	
	var after = Characters.get_base_attribute("debug_entity", "strength")
	print("  Valor después: %.1f" % after)
	
	print("\n¿Evento recibido? %s" % ("SÍ" if event_received else "NO"))
	if event_received:
		print("Detalles del evento:")
		print("  %s" % details)
	
	Characters.base_attribute_changed.disconnect(callback)


## Test 3: Con método de instancia
func test_signal_with_method():
	print("\n--- DEBUG 3: Callback con Método ---")
	
	print("Conectando método _on_attribute_changed...")
	Characters.base_attribute_changed.connect(_on_attribute_changed)
	
	print("Modificando atributo...")
	Characters.modify_base_attribute("debug_entity", "dexterity", 3)
	
	await get_tree().create_timer(0.1).timeout
	
	Characters.base_attribute_changed.disconnect(_on_attribute_changed)


func _on_attribute_changed(entity_id: String, attr_id: String, old_val: float, new_val: float):
	print("  [Método] ¡Evento recibido!")
	print("    %s.%s: %.1f → %.1f" % [entity_id, attr_id, old_val, new_val])
