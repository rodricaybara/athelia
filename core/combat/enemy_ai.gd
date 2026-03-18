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
	var action_data = {
		"actor": enemy_id,
		"skill_id": attack_skill_id,
		"target": PLAYER_ID
	}
	
	print("[EnemyAI] %s attacks %s" % [enemy_id, PLAYER_ID])
	EventBus.emit_signal("player_action_requested", action_data)
