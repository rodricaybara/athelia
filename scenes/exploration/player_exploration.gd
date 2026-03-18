class_name PlayerExploration
extends CharacterBody2D

## PlayerExploration - Nodo raíz del jugador en exploración

@export var speed: float = 120.0
@export var entity_id: String = "player"

@onready var game_loop: GameLoopSystem = get_node("/root/GameLoop")

func _ready() -> void:
	add_to_group("player")

func _physics_process(_delta: float) -> void:
	if not game_loop or game_loop.is_input_blocked():
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	var direction := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	).normalized()
	
	velocity = direction * speed
	move_and_slide()
