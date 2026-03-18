class_name CompanionFollowNode
extends CharacterBody2D

## CompanionFollowNode - Nodo visual de companion en exploración
##
## Sigue al jugador con offset fijo según índice en la formación.
## Usa lerp para suavizar el movimiento.
##
## Uso desde ExplorationTest:
##   var node = CompanionFollowNode.new()
##   node.setup("companion_mira", player_node, 0)
##   add_child(node)

# ============================================
# CONFIGURACIÓN
# ============================================

## Offsets de formación por índice (hasta 3 companions)
## Índice 0: izquierda-atrás, 1: derecha-atrás, 2: centro-más-atrás
const FORMATION_OFFSETS: Array[Vector2] = [
	Vector2(-28, 12),
	Vector2( 28, 12),
	Vector2(  0, 24),
]

## Velocidad de interpolación del seguimiento (mayor = más pegado)
@export var follow_speed: float = 8.0

## Distancia mínima para empezar a moverse (evita vibración)
@export var follow_threshold: float = 2.0

# ============================================
# ESTADO
# ============================================

var companion_id: String = ""
var _player_node: Node2D = null
var _formation_index: int = 0
var _target_position: Vector2 = Vector2.ZERO
var _sprite: Sprite2D = null

# ============================================
# SETUP
# ============================================

## Configurar antes de add_child()
func setup(p_companion_id: String, player_node: Node2D, formation_index: int) -> void:
	companion_id = p_companion_id
	_player_node = player_node
	_formation_index = clamp(formation_index, 0, FORMATION_OFFSETS.size() - 1)

	name = p_companion_id
	add_to_group(p_companion_id)
	add_to_group("companion")

	# Sprite placeholder — la escena real cargará el sprite correcto
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	add_child(_sprite)

	# Intentar cargar sprite del companion si existe
	var portrait_path := "res://data/characters/portrait/%s.png" % p_companion_id.replace("companion_", "")
	if ResourceLoader.exists(portrait_path):
		_sprite.texture = load(portrait_path)
		_sprite.scale = Vector2(0.3, 0.3)
	else:
		# Placeholder de color si no hay sprite
		_sprite.texture = load("res://icon.svg")
		_sprite.modulate = Color(0.4, 0.8, 1.0)  # azul claro para distinguir
		_sprite.scale = Vector2(0.3, 0.3)

	# CollisionShape para no bloquear el movimiento del jugador
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	col.shape = circle
	add_child(col)

	print("[CompanionFollowNode] Setup: %s (index %d)" % [companion_id, _formation_index])


func _ready() -> void:
	if _player_node:
		# Posición inicial: directamente en el offset para evitar el "viaje" inicial
		var offset := FORMATION_OFFSETS[_formation_index]
		global_position = _player_node.global_position + offset
		_target_position = global_position

	# Escuchar incapacitación para mostrar estado visual
	EventBus.companion_incapacitated.connect(_on_companion_incapacitated)
	EventBus.companion_revived.connect(_on_companion_revived)


func _physics_process(delta: float) -> void:
	if not _player_node or not is_instance_valid(_player_node):
		return

	# Posición objetivo: posición del jugador + offset de formación
	var offset := FORMATION_OFFSETS[_formation_index]
	_target_position = _player_node.global_position + offset

	# Solo mover si está suficientemente lejos (evita vibración)
	var dist := global_position.distance_to(_target_position)
	if dist > follow_threshold:
		var new_pos := global_position.lerp(_target_position, follow_speed * delta)
		velocity = (new_pos - global_position) / delta
		move_and_slide()
	else:
		velocity = Vector2.ZERO


# ============================================
# VISUAL — ESTADO
# ============================================

func _on_companion_incapacitated(cid: String) -> void:
	if cid != companion_id:
		return
	# Visual: semi-transparente y grisáceo
	if _sprite:
		_sprite.modulate = Color(0.5, 0.5, 0.5, 0.5)
	print("[CompanionFollowNode] %s incapacitated — visual updated" % companion_id)


func _on_companion_revived(cid: String) -> void:
	if cid != companion_id:
		return
	# Restaurar visual
	if _sprite:
		_sprite.modulate = Color(0.4, 0.8, 1.0)
	print("[CompanionFollowNode] %s revived — visual updated" % companion_id)
