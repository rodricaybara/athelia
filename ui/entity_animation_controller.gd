extends Node
class_name EntityAnimationController

## EntityAnimationController - Maneja animaciones procedurales de entidades
## Se adjunta como hijo de cada entidad (Player, Enemy)
##
## Uso:
##   var anim = entity.get_node("AnimationController")
##   anim.play_attack_light()

# ============================================
# CONFIGURACIÃ“N
# ============================================

## Referencia al nodo visual (Sprite2D o Control)
@export var visual_node: Node2D

## PosiciÃ³n original (guardada en _ready)
var original_position: Vector2
var original_scale: Vector2
var original_rotation: float


# ============================================
# INICIALIZACIÃ“N
# ============================================

func _ready():
	if not visual_node:
		push_error("[AnimationController] visual_node not set!")
		return
	
	# Guardar estado original
	original_position = visual_node.position
	original_scale = visual_node.scale
	original_rotation = visual_node.rotation
	
	print("[AnimationController] Initialized for %s" % visual_node.name)


# ============================================
# ANIMACIONES DE ATAQUE
# ============================================

## Ataque ligero - Bounce rÃ¡pido
func play_attack_light() -> void:
	if not visual_node:
		return
	
	var tween = create_tween()
	tween.set_parallel(false)
	
	# Forward (0.1s)
	tween.tween_property(visual_node, "position:x", original_position.x + 30, 0.1).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(visual_node, "scale", original_scale * 1.1, 0.1)
	
	# Hold (0.05s)
	tween.tween_interval(0.05)
	
	# Back (0.15s)
	tween.tween_property(visual_node, "position:x", original_position.x, 0.15).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(visual_node, "scale", original_scale, 0.15)


## Ataque pesado - Bounce lento y dramÃ¡tico
func play_attack_heavy() -> void:
	if not visual_node:
		return
	
	var tween = create_tween()
	tween.set_parallel(false)
	
	# Windup (0.15s) - retrocede ligeramente
	tween.tween_property(visual_node, "position:x", original_position.x - 15, 0.15).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(visual_node, "scale", original_scale * 0.9, 0.15)
	
	# Strike (0.12s) - golpe fuerte
	tween.tween_property(visual_node, "position:x", original_position.x + 50, 0.12).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(visual_node, "scale", original_scale * 1.3, 0.12)
	tween.parallel().tween_property(visual_node, "rotation", 0.2, 0.12)
	
	# Hold (0.1s)
	tween.tween_interval(0.1)
	
	# Recover (0.2s)
	tween.tween_property(visual_node, "position:x", original_position.x, 0.2).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(visual_node, "scale", original_scale, 0.2)
	tween.parallel().tween_property(visual_node, "rotation", original_rotation, 0.2)


## Dodge - Dash lateral con fade
func play_dodge() -> void:
	if not visual_node:
		return
	
	var tween = create_tween()
	tween.set_parallel(false)
	
	# Dash lateral rÃ¡pido (0.15s)
	tween.tween_property(visual_node, "position:y", original_position.y - 40, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(visual_node, "modulate:a", 0.5, 0.15)
	
	# Hold (0.2s)
	tween.tween_interval(0.2)
	
	# Volver (0.15s)
	tween.tween_property(visual_node, "position:y", original_position.y, 0.15).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(visual_node, "modulate:a", 1.0, 0.15)


# ============================================
# ANIMACIONES DE REACCIÃ“N
# ============================================

## Hit recibido - Shake rÃ¡pido
func play_hit_reaction() -> void:
	if not visual_node:
		return
	
	var tween = create_tween()
	tween.set_parallel(false)
	
	# Flash rojo
	tween.tween_property(visual_node, "modulate", Color.RED, 0.05)
	tween.tween_property(visual_node, "modulate", Color.WHITE, 0.1)
	
	# Shake horizontal
	for i in range(3):
		tween.tween_property(visual_node, "position:x", original_position.x + 5, 0.03)
		tween.tween_property(visual_node, "position:x", original_position.x - 5, 0.03)
	
	tween.tween_property(visual_node, "position:x", original_position.x, 0.05)


## Muerte - Fade out y caÃ­da
func play_death() -> void:
	if not visual_node:
		return
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Caer
	tween.tween_property(visual_node, "position:y", original_position.y + 30, 0.5).set_ease(Tween.EASE_IN)
	
	# Fade + shrink
	tween.tween_property(visual_node, "modulate:a", 0.3, 0.5)
	tween.tween_property(visual_node, "scale", original_scale * 0.7, 0.5)
	
	# Rotar ligeramente
	tween.tween_property(visual_node, "rotation", -0.3, 0.5)



## Defend - Retroceso y pose defensiva
func play_defend() -> void:
	if not visual_node:
		return
	
	var tween = create_tween()
	tween.set_parallel(false)
	
	# Retroceso rapido (0.1s)
	tween.tween_property(visual_node, "position:x", original_position.x - 20, 0.1).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(visual_node, "scale", original_scale * 0.9, 0.1)
	
	# Flash azul defensivo
	tween.tween_property(visual_node, "modulate", Color(0.4, 0.6, 1.0, 1.0), 0.08)
	tween.tween_property(visual_node, "modulate", Color(0.6, 0.8, 1.0, 1.0), 0.1)
	
	# Volver a posicion (0.15s) — el color azul lo mantiene start_defend_effect
	tween.tween_property(visual_node, "position:x", original_position.x, 0.15).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(visual_node, "scale", original_scale, 0.15)


# ============================================
# EFECTOS VISUALES PERSISTENTES DE BUFF
# ============================================

## Tween activo del efecto de esquiva (para poder matarlo)
var _evasion_tween: Tween = null

## Tween activo del efecto de defensa
var _defend_tween: Tween = null


## Inicia el efecto visual de esquiva activa: parpadeo cian
func start_evasion_effect() -> void:
	if not visual_node:
		return
	_stop_buff_tween(_evasion_tween)
	_evasion_tween = create_tween()
	_evasion_tween.set_loops()
	_evasion_tween.tween_property(visual_node, "modulate", Color(0.3, 1.0, 0.9, 0.5), 0.25).set_ease(Tween.EASE_IN_OUT)
	_evasion_tween.tween_property(visual_node, "modulate", Color(0.3, 1.0, 0.9, 1.0), 0.25).set_ease(Tween.EASE_IN_OUT)


## Detiene el efecto de esquiva y restaura color
func stop_evasion_effect() -> void:
	_stop_buff_tween(_evasion_tween)
	_evasion_tween = null
	if visual_node:
		visual_node.modulate = Color.WHITE


## Inicia el efecto visual de defensa activa: pulso azul
func start_defend_effect() -> void:
	if not visual_node:
		return
	_stop_buff_tween(_defend_tween)
	_defend_tween = create_tween()
	_defend_tween.set_loops()
	_defend_tween.tween_property(visual_node, "modulate", Color(0.5, 0.7, 1.0, 1.0), 0.4).set_ease(Tween.EASE_IN_OUT)
	_defend_tween.tween_property(visual_node, "modulate", Color(0.8, 0.9, 1.0, 1.0), 0.4).set_ease(Tween.EASE_IN_OUT)


## Detiene el efecto de defensa y restaura color
func stop_defend_effect() -> void:
	_stop_buff_tween(_defend_tween)
	_defend_tween = null
	if visual_node:
		visual_node.modulate = Color.WHITE


## Para un tween de buff de forma segura
func _stop_buff_tween(t: Tween) -> void:
	if t and t.is_valid():
		t.kill()


# ============================================
# UTILIDADES
# ============================================

## Resetea el visual al estado original (Ãºtil si algo falla)
func reset_visual() -> void:
	if not visual_node:
		return
	
	visual_node.position = original_position
	visual_node.scale = original_scale
	visual_node.rotation = original_rotation
	visual_node.modulate = Color.WHITE


## Verifica si hay una animaciÃ³n en curso
func is_animating() -> bool:
	# Los tweens creados con create_tween() no se pueden trackear fÃ¡cilmente
	# Para el spike, asumimos que no overlap
	return false
