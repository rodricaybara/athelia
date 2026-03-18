extends Node

## Debug para detectar congelamiento

var frame_count: int = 0

func _ready():
	print("\n[DEBUG_FREEZE] Monitoring started")
	set_process(true)


func _process(_delta: float):
	frame_count += 1
	
	# Imprimir cada 60 frames (1 segundo aprox)
	if frame_count % 60 == 0:
		print("[DEBUG_FREEZE] Frame %d - Game is running" % frame_count)


func _input(event):
	if event.is_action_pressed("ui_home"):
		print("\n[DEBUG_FREEZE] Manual status check:")
		print("  Frame count: %d" % frame_count)
		print("  Tree paused: %s" % get_tree().paused)
		
		var player = get_tree().current_scene.get_node_or_null("Player")
		if player:
			print("  Player exists: YES")
			print("  Player position: %s" % player.position)
		else:
			print("  Player exists: NO")
