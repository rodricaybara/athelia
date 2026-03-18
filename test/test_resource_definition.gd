extends Node

## Script de prueba temporal para ResourceDefinition
## Adjuntar a un Node en la escena y ejecutar

func _ready():
	print("=== Testing ResourceDefinition ===")
	
	# Cargar definición de vida
	var health_def = load("res://data/resources/health.tres") as ResourceDefinition
	if health_def:
		print("✓ Health loaded: ", health_def)  # Godot llamará automáticamente a _to_string()
		print("  Valid: ", health_def.validate())
	else:
		print("✗ Failed to load health.tres")
	
	# Cargar definición de stamina
	var stamina_def = load("res://data/resources/stamina.tres") as ResourceDefinition
	if stamina_def:
		print("✓ Stamina loaded: ", stamina_def)
		print("  Valid: ", stamina_def.validate())
		print("  Regenerates: ", stamina_def.regen_rate, " per second")
	else:
		print("✗ Failed to load stamina.tres")
	
	# Cargar definición de oro
	var gold_def = load("res://data/resources/gold.tres") as ResourceDefinition
	if gold_def:
		print("✓ Gold loaded: ", gold_def)
		print("  Valid: ", gold_def.validate())
	else:
		print("✗ Failed to load gold.tres")
	
	# Test de validación con recurso inválido
	var invalid_res = ResourceDefinition.new()
	invalid_res.id = ""  # inválido
	print("\n✓ Invalid resource correctly fails validation: ", !invalid_res.validate())
	
	print("\n=== ResourceDefinition tests complete ===")
