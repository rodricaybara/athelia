extends Node

## Script de inicialización para la escena de debug
## Solo para desarrollo

func _ready():
	# Verificar que ResourceSystem existe
	if not has_node("ResourceSystem"):
		push_error("[DebugGame] ResourceSystem node not found! Check scene hierarchy.")
		return
	
	var resource_system = $ResourceSystem
	
	# Esperar a que ResourceSystem se inicialice
	await get_tree().process_frame
	
	# Registrar jugador con todos los recursos
	resource_system.register_entity("player")
	print("[DebugGame] Player registered with resources")
	
	# Opcional: Registrar un enemigo de prueba
	# resource_system.register_entity("enemy_01", ["health", "stamina"])
