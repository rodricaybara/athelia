class_name CompanionFollowNode
extends CharacterBody2D

## CompanionFollowNode - Script base para companions en exploración
##
## Gestiona movimiento, formación y estados visuales.
## NO crea sprites por código — cada escena hija configura su propio AnimatedSprite2D.
##
## Animaciones esperadas en el nodo "AnimatedSprite":
##   "walk_down", "walk_up", "walk_left", "walk_right"

const FORMATION_OFFSETS: Array[Vector2] = [
	Vector2(-32, 16),
	Vector2( 32, 16),
	Vector2(  0, 28),
]

@export var move_speed: float = 115.0
@export var arrival_threshold: float = 8.0

var companion_id: String = ""
var _player_node: Node2D = null
var _formation_index: int = 0
var _last_direction: String = "walk_down"
var _use_navigation: bool = false
var _anim_sprite: AnimatedSprite2D = null

@onready var _nav_agent: NavigationAgent2D = $NavigationAgent2D


func setup(p_companion_id: String, player_node: Node2D, formation_index: int) -> void:
	companion_id = p_companion_id
	_player_node = player_node
	_formation_index = clamp(formation_index, 0, FORMATION_OFFSETS.size() - 1)
	name = p_companion_id
	add_to_group(p_companion_id)
	add_to_group("companion")
	print("[CompanionFollowNode] Setup: %s (index %d)" % [companion_id, _formation_index])


func _ready() -> void:
	_anim_sprite = get_node_or_null("AnimatedSprite") as AnimatedSprite2D
	if not _anim_sprite:
		push_warning("[CompanionFollowNode] %s: no AnimatedSprite2D found" % companion_id)

	if _player_node:
		global_position = _player_node.global_position + FORMATION_OFFSETS[_formation_index]

	await get_tree().process_frame
	_use_navigation = not get_tree().get_nodes_in_group("navigation_region").is_empty()

	EventBus.companion_incapacitated.connect(_on_companion_incapacitated)
	EventBus.companion_revived.connect(_on_companion_revived)

	_set_idle()


func _physics_process(_delta: float) -> void:
	if not _player_node or not is_instance_valid(_player_node):
		return

	var target_pos: Vector2 = _player_node.global_position + FORMATION_OFFSETS[_formation_index]
	var dist: float = global_position.distance_to(target_pos)

	if dist < arrival_threshold:
		velocity = Vector2.ZERO
		_set_idle()
		move_and_slide()
		return

	var move_dir: Vector2
	if _use_navigation and _nav_agent:
		_nav_agent.target_position = target_pos
		move_dir = (_nav_agent.get_next_path_position() - global_position).normalized()
	else:
		move_dir = (target_pos - global_position).normalized()

	velocity = move_dir * move_speed
	_update_animation(move_dir)
	move_and_slide()


func _update_animation(direction: Vector2) -> void:
	if not _anim_sprite or direction.length() < 0.1:
		_set_idle()
		return

	var anim_name: String
	if abs(direction.x) > abs(direction.y):
		anim_name = "walk_right" if direction.x > 0 else "walk_left"
	else:
		anim_name = "walk_down" if direction.y > 0 else "walk_up"

	if _anim_sprite.animation != anim_name or not _anim_sprite.is_playing():
		_last_direction = anim_name
		_anim_sprite.play(anim_name)


func _set_idle() -> void:
	if not _anim_sprite:
		return
	if _anim_sprite.is_playing():
		_anim_sprite.stop()
	_anim_sprite.frame = 0


func _on_companion_incapacitated(cid: String) -> void:
	if cid != companion_id:
		return
	if _anim_sprite:
		_anim_sprite.modulate = Color(0.5, 0.5, 0.5, 0.5)
		_anim_sprite.stop()


func _on_companion_revived(cid: String) -> void:
	if cid != companion_id:
		return
	if _anim_sprite:
		_anim_sprite.modulate = Color.WHITE
		_anim_sprite.play(_last_direction)
