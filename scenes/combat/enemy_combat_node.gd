extends Node2D
class_name EnemyCombatNode

## EnemyCombatNode - Nodo visual reutilizable para un enemigo en combate
##
## Instanciado dinámicamente por CombatTestScene según los participantes
## que GameLoop recibe de ExplorationController.
##
## Uso:
##   var node = ENEMY_COMBAT_NODE.instantiate()
##   node.setup(enemy_id)        ← ANTES de add_child()
##   $EnemyContainer.add_child(node)
##
## setup() debe llamarse ANTES de add_child() para que visual_node esté
## asignado cuando AnimationController._ready() se dispare al entrar al árbol.
## Por eso NO usamos @onready — get_node() funciona sobre hijos aunque el
## nodo raíz aún no esté en el árbol de escena.

# ============================================
# API PÚBLICA
# ============================================

## Configura el nodo para un enemy_id concreto.
## Llamar ANTES de add_child().
func setup(enemy_id: String) -> void:
	name = enemy_id
	add_to_group(enemy_id)

	# Resolver hijos por nombre — válido aunque el nodo no esté en el árbol aún
	var lbl: Label = get_node_or_null("Label")
	var sprite: Sprite2D = get_node_or_null("SpriteEnemy")
	var anim_controller: EntityAnimationController = get_node_or_null("AnimationController")

	if lbl:
		lbl.text = enemy_id

	# Asignar visual_node ANTES de add_child() para que AnimationController._ready()
	# lo encuentre ya configurado cuando Godot lo llame al entrar al árbol.
	if anim_controller and sprite:
		anim_controller.visual_node = sprite
	else:
		push_warning("[EnemyCombatNode] Missing AnimationController or SpriteEnemy on %s" % enemy_id)

	print("[EnemyCombatNode] Setup complete: %s" % enemy_id)
