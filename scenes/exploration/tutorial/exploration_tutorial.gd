extends Node2D

## ExplorationTutorial — Escena raíz de la zona tutorial de exploración
##
## A diferencia de ExplorationTest, esta escena NO registra al jugador.
## En el flujo real, CharacterCreationViewModel._create_player_entity()
## ya deja a "player" completamente registrado en Characters/Resources/
## Skills/Equipment/Inventory ANTES de que GameLoop.enter_exploration()
## dispare la carga de esta escena.
##
## El caso de arranque en frío (Cargar Partida sin pasar por Character
## Creation) se resuelve en SaveSystem vía el bootstrap compartido
## (Fase 2/3 del spike de producción) — no aquí.

@onready var player: PlayerExploration = $Player
@onready var exploration_controller: ExplorationController = $ExplorationController
@onready var exploration_hud: ExplorationHUD = $ExplorationHUD


func _ready() -> void:
	print("\n" + "=".repeat(50))
	print("EXPLORATION TUTORIAL — INITIALIZING")
	print("=".repeat(50))

	_register_world_objects()
	_connect_interactables()
	_inject_hud()

	var game_loop: GameLoopSystem = get_node_or_null("/root/GameLoop")
	if game_loop:
		if game_loop.current_game_state != GameLoopSystem.GameState.EXPLORATION:
			game_loop.enter_exploration()
	else:
		push_error("[ExplorationTutorial] GameLoop not found — inventory will be blocked")

	if exploration_hud:
		exploration_hud.refresh()

	print("[ExplorationTutorial] Ready")


func _register_world_objects() -> void:
	var wo_system: Node = get_node_or_null("/root/WorldObjectSystem")
	if not wo_system:
		push_warning("[ExplorationTutorial] WorldObjectSystem not found — world objects will not work")
		return

	# ── Registrar instancias de WorldObject presentes en la escena ──────────
	wo_system.register_instance("chest_01_a", "chest_01")
	wo_system.register_instance("chest_01_b", "chest_01")

	# ── Instanciar WorldObjectBridge (aplica loot + narrativa) ──────────────
	var bridge_script := load("res://core/world_objects/world_object_bridge.gd")
	if bridge_script:
		var bridge := Node.new()
		bridge.name = "WorldObjectBridge"
		bridge.set_script(bridge_script)
		add_child(bridge)
		print("[ExplorationTutorial] WorldObjectBridge instantiated")
	else:
		push_error("[ExplorationTutorial] world_object_bridge.gd not found")

	# ── Instanciar WorldObjectInteractionPanel (UI overlay) ─────────────────
	var panel_scene := load("res://ui/world_objects/world_object_interaction_panel.tscn")
	if panel_scene:
		var panel: CanvasLayer = panel_scene.instantiate() as CanvasLayer
		panel.name = "WorldObjectInteractionPanel"
		add_child(panel)
		print("[ExplorationTutorial] WorldObjectInteractionPanel instantiated")

		panel.visibility_changed.connect(func():
			if exploration_controller:
				exploration_controller.set_process_unhandled_input(not panel.visible)
		)
	else:
		push_error("[ExplorationTutorial] world_object_interaction_panel.tscn not found")

	print("[ExplorationTutorial] WorldObjects registered")


func _connect_interactables() -> void:
	var interactables := _find_interactables(self)
	for interactable in interactables:
		interactable.player_in_range.connect(exploration_controller.register_interactable)
		interactable.player_out_of_range.connect(exploration_controller.unregister_interactable)
	print("[ExplorationTutorial] Connected %d interactables" % interactables.size())


func _inject_hud() -> void:
	if exploration_controller and exploration_hud:
		exploration_controller.exploration_hud = exploration_hud
	else:
		push_warning("[ExplorationTutorial] Cannot inject HUD — node missing")


func _find_interactables(node: Node) -> Array[Interactable]:
	var result: Array[Interactable] = []
	for child in node.get_children():
		if child is Interactable:
			result.append(child)
		result.append_array(_find_interactables(child))
	return result
