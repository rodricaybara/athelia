class_name CompanionFollowNode
extends CharacterBody2D

## CompanionFollowNode - Nodo visual de companion en exploración
##
## v2: Usa NavigationAgent2D para esquivar obstáculos.
## Si no hay NavigationRegion2D en la escena, hace fallback a lerp directo
## para que no rompa en escenas sin navmesh configurado.
##
## Uso desde ExplorationTest._ready():
##   var node = CompanionFollowNode.new()
##   node.setup("companion_mira", player_node, 0)
##   add_child(node)

# ============================================
# CONFIGURACIÓN
# ============================================

## Offsets de formación por índice (hasta 3 companions)
const FORMATION_OFFSETS: Array[Vector2] = [
	Vector2(-32, 16),
	Vector2( 32, 16),
	Vector2(  0, 28),
]

## Velocidad de movimiento (px/s) — misma que el jugador para no rezagarse
@export var move_speed: float = 115.0

## Distancia mínima al objetivo antes de moverse (evita vibración)
@export var arrival_threshold: float = 8.0

## Umbral para hacer fallback a lerp directo (si nav no está disponible)
@export var nav_fallback_distance: float = 600.0

# ============================================
# ESTADO
# ============================================

var companion_id: String = ""
var _player_node: Node2D = null
var _formation_index: int = 0
var _nav_agent: NavigationAgent2D = null
var _has_nav: bool = false
var _sprite: Sprite2D = null

# ============================================
# SETUP
# ============================================

## Configurar ANTES de add_child()
func setup(p_companion_id: String, player_node: Node2D, formation_index: int) -> void:
	companion_id = p_companion_id
	_player_node = player_node
	_formation_index = clamp(formation_index, 0, FORMATION_OFFSETS.size() - 1)

	name = p_companion_id
	add_to_group(p_companion_id)
	add_to_group("companion")

	# Sprite
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	add_child(_sprite)

	var portrait_path: String = "res://data/characters/portrait/%s.png" % p_companion_id.replace("companion_", "")
	if ResourceLoader.exists(portrait_path):
		_sprite.texture = load(portrait_path)
		_sprite.scale = Vector2(0.3, 0.3)
	else:
		_sprite.texture = load("res://icon.svg")
		_sprite.modulate = Color(0.4, 0.8, 1.0)
		_sprite.scale = Vector2(0.3, 0.3)

	# Collision shape — necesaria para CharacterBody2D.move_and_slide()
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	col.shape = circle
	add_child(col)

	# NavigationAgent2D
	_nav_agent = NavigationAgent2D.new()
	_nav_agent.name = "NavigationAgent2D"
	_nav_agent.path_desired_distance = arrival_threshold
	_nav_agent.target_desired_distance = arrival_threshold
	_nav_agent.max_speed = move_speed
	_nav_agent.avoidance_enabled = true  # evita colisiones con otros companions
	add_child(_nav_agent)

	print("[CompanionFollowNode] Setup: %s (formación índice %d)" % [companion_id, _formation_index])


func _ready() -> void:
	# Verificar si hay NavigationRegion2D activo en la escena
	# Lo hacemos diferido para que la escena esté completamente cargada
	call_deferred("_check_nav_available")

	if _player_node:
		var offset: Vector2 = FORMATION_OFFSETS[_formation_index]
		global_position = _player_node.global_position + offset

	EventBus.companion_incapacitated.connect(_on_companion_incapacitated)
	EventBus.companion_revived.connect(_on_companion_revived)


func _check_nav_available() -> void:
	## Busca un NavigationRegion2D en la escena para decidir si usar nav o lerp
	var regions: Array[Node] = get_tree().get_nodes_in_group("navigation_region")
	if not regions.is_empty():
		_has_nav = true
		print("[CompanionFollowNode] %s: NavigationAgent2D activo" % companion_id)
		return

	# Fallback: buscar por tipo directamente
	var scene_root: Node = get_tree().current_scene
	if scene_root:
		for child in scene_root.get_children():
			if child is NavigationRegion2D:
				_has_nav = true
				print("[CompanionFollowNode] %s: NavigationRegion2D encontrado → nav activo" % companion_id)
				return

	_has_nav = false
	print("[CompanionFollowNode] %s: sin NavigationRegion2D → modo lerp directo" % companion_id)


# ============================================
# MOVIMIENTO
# ============================================

func _physics_process(delta: float) -> void:
	if not _player_node or not is_instance_valid(_player_node):
		return

	var offset: Vector2 = FORMATION_OFFSETS[_formation_index]
	var target_pos: Vector2 = _player_node.global_position + offset
	var dist: float = global_position.distance_to(target_pos)

	# No moverse si ya está suficientemente cerca
	if dist < arrival_threshold:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _has_nav and _nav_agent:
		_move_with_nav(target_pos, delta)
	else:
		_move_lerp(target_pos, delta)


func _move_with_nav(target_pos: Vector2, _delta: float) -> void:
	## Movimiento con NavigationAgent2D — rodea obstáculos
	_nav_agent.target_position = target_pos

	if _nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var next_pos: Vector2 = _nav_agent.get_next_path_position()
	var direction: Vector2 = (next_pos - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()


func _move_lerp(target_pos: Vector2, delta: float) -> void:
	## Fallback: interpolación directa sin navmesh
	var direction: Vector2 = (target_pos - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()


# ============================================
# VISUAL — ESTADO
# ============================================

func _on_companion_incapacitated(cid: String) -> void:
	if cid != companion_id:
		return
	if _sprite:
		_sprite.modulate = Color(0.5, 0.5, 0.5, 0.5)
	print("[CompanionFollowNode] %s incapacitado — visual actualizado" % companion_id)


func _on_companion_revived(cid: String) -> void:
	if cid != companion_id:
		return
	if _sprite:
		_sprite.modulate = Color(0.4, 0.8, 1.0)
	print("[CompanionFollowNode] %s reanimado — visual actualizado" % companion_id)
