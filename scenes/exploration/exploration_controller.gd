class_name ExplorationController
extends Node

## ExplorationController - Orquestador de exploración
## Nodo hijo de la escena de exploración principal.
##
## Responsabilidades:
## - Escuchar EventBus.interaction_requested y delegar a GameLoop
## - Mostrar/ocultar prompts de interacción (vía HUD)
## - Gestionar apertura de inventario (overlay, sin cambio de GameState)
## - NO mueve al jugador (eso es PlayerMovement en el nodo Player)
## - NO instancia escenas (eso es SceneOrchestrator)
##
## Flujo de interacción:
##   Interactable.interact()
##     → EventBus.interaction_requested(type, target_id)
##       → ExplorationController._on_interaction_requested()
##         → GameLoop.enter_dialogue() / enter_shop() / start_combat()

# ============================================
# REFERENCIAS
# ============================================

@onready var game_loop: GameLoopSystem = get_node("/root/GameLoop")
@onready var scene_orchestrator = get_node("/root/SceneOrchestrator")

## Referencia al HUD de exploración — asignar en el editor o en _ready
@export var exploration_hud: ExplorationHUD = null

# ============================================
# ESTADO INTERNO
# ============================================

## Interactuable actualmente en rango (puede ser null)
var _current_interactable: Interactable = null

## Mapeo enemy_id → definition_id leído del Interactable antes de start_combat().
## Se limpia al inicio de cada encuentro para evitar datos de combates anteriores.
var _pending_enemy_definitions: Dictionary = {}

# ============================================
# INICIALIZACIÓN
# ============================================

func _ready() -> void:
	if not game_loop:
		push_error("[ExplorationController] GameLoop autoload not found!")
		return
	
	if not scene_orchestrator:
		push_error("[ExplorationController] SceneOrchestrator autoload not found!")
		return
	
	# Escuchar interacciones del mundo
	EventBus.interaction_requested.connect(_on_interaction_requested)
	
	# Escuchar cambios de estado para habilitar/deshabilitar input
	EventBus.game_state_changed.connect(_on_game_state_changed)
	
	# Notificar al GameLoop que entramos en exploración
	# (si llegamos aquí es porque la escena de exploración se cargó)
	if game_loop.current_game_state == GameLoopSystem.GameState.MENU:
		game_loop.enter_exploration()
	
	print("[ExplorationController] Ready")


# ============================================
# INPUT
# ============================================

func _unhandled_input(event: InputEvent) -> void:
	# Bloquear todo input si el GameLoop no está en EXPLORATION
	if game_loop.is_input_blocked():
		return
	
	# Acción de interacción
	if event.is_action_pressed("interact"):  # Tecla E (definida en InputMap)
		_try_interact()
	
	# Toggle inventario — solo en EXPLORATION, nunca en otro estado
	if event.is_action_pressed("open_inventory"):  # Tecla I / Tab
		scene_orchestrator.open_inventory()


# ============================================
# CALLBACKS DE INTERACTUABLES
# ============================================

## Llamado por Interactable cuando el jugador entra en rango
func register_interactable(interactable: Interactable) -> void:
	_current_interactable = interactable
	_show_interact_prompt(interactable.prompt_key)


## Llamado por Interactable cuando el jugador sale del rango
func unregister_interactable(interactable: Interactable) -> void:
	if _current_interactable == interactable:
		_current_interactable = null
		_hide_interact_prompt()


func _try_interact() -> void:
	if _current_interactable and is_instance_valid(_current_interactable):
		_current_interactable.interact()


# ============================================
# CALLBACK DE interaction_requested
# Única lógica de routing: qué tipo de interacción va a qué sistema
# ============================================

func _on_interaction_requested(interaction_type: String, target_id: String) -> void:
	print("[ExplorationController] Interaction: %s → %s" % [interaction_type, target_id])
	
	match interaction_type:
		"dialogue":
			game_loop.enter_dialogue(target_id)
		
		"shop":
			game_loop.enter_shop(target_id)
		
		"combat":
			# target_id puede ser un único ID ("enemy_1") o varios separados
			# por coma ("enemy_1,enemy_2,enemy_3") si Interactable usa enemy_ids_override.
			var enemy_ids: Array[String] = []
			if "," in target_id:
				for part in target_id.split(","):
					var trimmed = part.strip_edges()
					if not trimmed.is_empty():
						enemy_ids.append(trimmed)
			else:
				enemy_ids.append(target_id)
			
			# Leer el mapeo enemy_id → definition_id del Interactable que disparó la señal.
			# _current_interactable sigue válido aquí porque interact() lo emite síncronamente.
			_pending_enemy_definitions.clear()
			if _current_interactable and not _current_interactable.enemy_definitions.is_empty():
				_pending_enemy_definitions = _current_interactable.enemy_definitions.duplicate()
				print("[ExplorationController] Enemy definitions loaded: %s" % str(_pending_enemy_definitions))
			else:
				print("[ExplorationController] No enemy_definitions on interactable — all will use fallback")
			
			# Informar al CombatLootSpawner qué definitions participan en este encuentro
			var loot_spawner = get_node_or_null("/root/CombatLootSpawner")
			if loot_spawner:
				loot_spawner.register_combat_enemies(_pending_enemy_definitions)

			# Registrar enemigos ANTES de start_combat() para que
			# _calculate_initiative() los encuentre en CharacterSystem.
			_register_combat_enemies(enemy_ids)
			game_loop.start_combat(enemy_ids)
		
		"item":
			# WorldObject interactuable (cofre, pergamino, etc.)
			# target_id es el instance_id registrado en WorldObjectSystem.
			# El panel escucha world_object_interaction_requested y muestra las opciones.
			# No hay cambio de GameState — la interacción se resuelve como overlay.
			EventBus.world_object_interaction_requested.emit("player", target_id)
			print("[ExplorationController] WorldObject interaction: %s" % target_id)
		
		_:
			push_warning("[ExplorationController] Unknown interaction_type: %s" % interaction_type)


# ============================================
# RESPUESTA A CAMBIOS DE ESTADO
# ============================================

func _on_game_state_changed(new_state: int) -> void:
	var state := new_state as GameLoopSystem.GameState
	
	# Cuando volvemos a exploración, limpiar prompt si quedó activo
	if state == GameLoopSystem.GameState.EXPLORATION:
		if _current_interactable == null:
			_hide_interact_prompt()


# ============================================
# HUD — PROMPT DE INTERACCIÓN
# ============================================

func _show_interact_prompt(key: String) -> void:
	if exploration_hud and exploration_hud.has_method("show_interact_prompt"):
		exploration_hud.show_interact_prompt(key)


func _hide_interact_prompt() -> void:
	if exploration_hud and exploration_hud.has_method("hide_interact_prompt"):
		exploration_hud.hide_interact_prompt()


## Registra los enemigos en CharacterSystem y ResourceSystem antes de
## que GameLoop calcule la iniciativa. Sin esto, _calculate_initiative()
## falla porque las entidades no existen aún.
## Usa _pending_enemy_definitions para resolver la CharacterDefinition de cada enemigo.
## Fallback a "enemy_base" si un enemy_id no está en el dict o el dict está vacío.
func _register_combat_enemies(enemy_ids: Array[String]) -> void:
	var chars: CharacterSystem = get_node_or_null("/root/Characters")
	var resources: ResourceSystem = get_node_or_null("/root/Resources")
	
	for enemy_id in enemy_ids:
		# Resolver definition_id: del dict si existe, fallback a "enemy_base"
		var def_id: String = _pending_enemy_definitions.get(enemy_id, "enemy_base")
		
		# CharacterSystem — necesario para calcular iniciativa
		if chars and not chars.has_entity(enemy_id):
			if chars.has_definition(def_id):
				chars.register_entity(enemy_id, def_id)
			else:
				push_warning("[ExplorationController] definition '%s' not found for %s — falling back to enemy_base" % [def_id, enemy_id])
				if chars.has_definition("enemy_base"):
					chars.register_entity(enemy_id, "enemy_base")
		
		# ResourceSystem — necesario para HP
		# No hay has_entity() público: registrar y dejar que el sistema
		# emita su propio warning si ya estaba registrado (es inofensivo)
		resources.register_entity(enemy_id)
		resources.set_resource(enemy_id, "health", 50.0)
		
		print("[ExplorationController] Pre-registered enemy: %s (def: %s)" % [enemy_id, def_id])
