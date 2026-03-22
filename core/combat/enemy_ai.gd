extends Node
#class_name EnemyAI

@export var enemy_id: String = "enemy_1"
@export var attack_skill_id: String = "skill.enemy.basic_attack"
@export var decision_delay: float = 0.5

const PLAYER_ID: String = "player"

func _ready():
	if EventBus:
		EventBus.enemy_turn_started.connect(_on_enemy_turn_started)
	else:
		push_error("[EnemyAI] EventBus not found!")
	print("[EnemyAI] Initialized - %s" % enemy_id)

func _on_enemy_turn_started(acting_enemy_id: String) -> void:
	if acting_enemy_id != enemy_id:
		return
	
	print("[EnemyAI] %s deciding..." % enemy_id)
	await get_tree().create_timer(decision_delay).timeout
	_decide_and_act()

func _decide_and_act() -> void:
	var target := _pick_target()
	if target.is_empty():
		print("[EnemyAI] %s: no valid target — skipping" % enemy_id)
		EventBus.emit_signal("combat_action_completed", {"skipped": true})
		return

	var action_data = {
		"actor": enemy_id,
		"skill_id": attack_skill_id,
		"target": target
	}
	print("[EnemyAI] %s attacks %s" % [enemy_id, target])
	EventBus.emit_signal("player_action_requested", action_data)


func _pick_target() -> String:
	# Jugador si está vivo
	if Resources.get_resource_amount(PLAYER_ID, "health") > 0:
		return PLAYER_ID
	
	# Si el jugador está incapacitado, atacar companions activos
	var party: Node = Engine.get_main_loop().root.get_node_or_null("/root/Party")
	if party:
		for companion_id in party.get_active_members():
			if Resources.get_resource_amount(companion_id, "health") > 0:
				return companion_id
	
	return ""
