extends Node

## Test de ShopUI
## Valida renderizado, eventos y estados visuales

var player_scene = preload("res://scenes/player/player.tscn")
var player: Node

func _ready():
	# Instanciar jugador solo si no existe
	player = get_node_or_null("Player/Player")
	
	if not player:
		var player_container = Node2D.new()
		player_container.name = "PlayerContainer"
		add_child(player_container)
		
		player = player_scene.instantiate()
		player_container.add_child(player)
	
	# Esperar inicialización
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Dar oro al jugador
	var resource_system = get_node("/root/Resources")
	resource_system.set_resource("player", "gold", 500)
	
	# Añadir algunos items al jugador para vender
	var inventory_system = get_node("/root/Inventory")
	if inventory_system:
		inventory_system.add_item("player", "stamina_potion_small", 3)
		inventory_system.add_item("player", "iron_sword", 1)
		print("[Test] Added items to player inventory")
	
	print("\n=== Testing ShopUI ===")
	print("Press SPACE to open shop")
	print("Press Q to quit test")
	print("ESC closes the shop when open")


func _unhandled_input(event):
	if event.is_action_pressed("ui_accept"):  # SPACE
		_open_test_shop()
		get_viewport().set_input_as_handled()
	
	# Q para cerrar test
	if event is InputEventKey:
		if event.keycode == KEY_Q and event.pressed:
			print("[Test] Quitting...")
			get_tree().quit()


func _open_test_shop():
	var shop_ui = $ShopUI
	if shop_ui:
		shop_ui.open_shop("blacksmith_01", "player")
		print("[Test] Opening blacksmith_01")
