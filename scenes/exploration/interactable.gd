class_name Interactable
extends Area2D

## Interactable - Componente para objetos interactuables en exploración
##
## Uso en escena:
##   Añadir como hijo de NPC/cofre/puerta en el editor.
##   Configurar interaction_type y target_id en el inspector.
##   El ExplorationController detecta este componente y gestiona la interacción.
##
## interaction_type válidos:
##   "dialogue"  → entra en DIALOGUE con target_id como dialogue_id
##   "shop"      → entra en SHOP con target_id como shop_id
##   "combat"    → inicia COMBAT con target_id como enemy definition id
##   "item"      → recoge item con target_id como item_id (sin cambio de estado)
##
## Nunca llama a GameLoop directamente — solo emite interaction_requested.

# ============================================
# PROPIEDADES EXPORTADAS (configurables en editor)
# ============================================

## Tipo de interacción — define qué transición ocurrirá
@export_enum("dialogue", "shop", "combat", "item") var interaction_type: String = "dialogue"

## ID del objetivo: dialogue_id, shop_id, enemy_definition_id, o item_id
@export var target_id: String = ""

## Para combate con múltiples enemigos: IDs del encuentro completo.
## Si está vacío, se usa [target_id]. Si está relleno, sobreescribe target_id.
## Ejemplo: ["enemy_1", "enemy_2", "enemy_3"]
@export var enemy_ids_override: Array[String] = []

## Mapeo enemy_id → definition_id para encuentros con tipos distintos.
## Si está vacío, todos los enemigos del encuentro usan "enemy_base".
## Ejemplo: {"enemy_1": "orc_grunt", "enemy_2": "orc_shaman"}
@export var enemy_definitions: Dictionary = {}

## Texto de prompt que se muestra cuando el jugador está en rango
## Usar clave de localización (ej: "UI_INTERACT_TALK")
@export var prompt_key: String = "UI_INTERACT_DEFAULT"

## Si es false, ya fue usado y no puede volver a activarse (ej: cofre ya abierto)
@export var is_active: bool = true

# ============================================
# SEÑALES
# ============================================

## Emitida cuando el jugador entra en rango — para mostrar prompt en HUD
signal player_in_range(interactable: Interactable)

## Emitida cuando el jugador sale del rango
signal player_out_of_range(interactable: Interactable)

# ============================================
# ESTADO INTERNO
# ============================================

var _player_inside: bool = false

# ============================================
# INICIALIZACIÓN
# ============================================

func _ready() -> void:
	if target_id.is_empty():
		push_warning("[Interactable] target_id not set on %s" % get_parent().name)
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


# ============================================
# DETECCIÓN DE PROXIMIDAD
# ============================================

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = true
	emit_signal("player_in_range", self)


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = false
	emit_signal("player_out_of_range", self)


# ============================================
# API PÚBLICA
# ============================================

## Llamado por ExplorationController cuando el jugador pulsa Interact
## Valida estado y emite el evento al EventBus
func interact() -> void:
	if not is_active:
		print("[Interactable] Already used: %s" % name)
		return
	
	if not _player_inside:
		push_warning("[Interactable] interact() called but player not in range")
		return
	
	if target_id.is_empty():
		push_error("[Interactable] Cannot interact: target_id is empty on %s" % get_parent().name)
		return
	
	# Verificar que el GameLoop no bloquea input
	var game_loop := get_node_or_null("/root/GameLoop") as GameLoopSystem
	if game_loop and game_loop.is_input_blocked():
		print("[Interactable] Input blocked by GameLoop state: %s" % game_loop.get_state_name())
		return
	
	# Para combate: si hay enemy_ids_override, emitir como CSV para pasar múltiples IDs
	var effective_target = target_id
	if interaction_type == "combat" and not enemy_ids_override.is_empty():
		effective_target = ",".join(enemy_ids_override)
	
	print("[Interactable] Interaction: type=%s, target=%s" % [interaction_type, effective_target])
	EventBus.emit_signal("interaction_requested", interaction_type, effective_target)


## Desactiva el interactuable (ej: cofre ya abierto, enemigo derrotado)
func deactivate() -> void:
	is_active = false
	if _player_inside:
		emit_signal("player_out_of_range", self)
	_player_inside = false
