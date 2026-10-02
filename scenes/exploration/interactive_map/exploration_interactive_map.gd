extends Node

## ExplorationInteractiveMap — Spike 12: escena raíz de exploración basada
## en un mapa de puntos de interés (sin jugador, sin física, sin cámara).
##
## Sustituye a exploration_telmori_village.tscn como SCENE_EXPLORATION.
## SceneOrchestrator le pone name = "ExplorationScene" al instanciarla, así
## que el nombre del nodo raíz de este .tscn es libre.
##
## Es ÚNICAMENTE composición (igual que el script del pueblo lo era para
## Interactable): crea el ViewModel, lo enlaza con la vista y reenvía
## hotspot_activated → ExplorationController.request_interaction().
## No contiene lógica de juego. La inicialización de partida que hacía el
## pueblo (companion, equipo inicial, listeners de continuación,
## telmori_village_arrival) NO está aquí: pendiente para Spike 13.
##
## Contenido: el scene_id se elige por export — cambiar de mapa de prueba
## a mapa real es cambiar este valor (o el JSON), no el código.

@export var interactive_scene_id: String = "poi_test_map"

@onready var exploration_controller: ExplorationController = $ExplorationController
@onready var exploration_hud: ExplorationHUD = $ExplorationHUD
@onready var map_layer: CanvasLayer = $MapLayer
@onready var map_view: InteractiveSceneView = $MapLayer/InteractiveSceneView

var _view_model: InteractiveSceneViewModel = null


func _ready() -> void:
	print("[ExplorationInteractiveMap] Initializing — scene: %s" % interactive_scene_id)

	# Mismo cableado que _inject_hud() del pueblo.
	exploration_controller.exploration_hud = exploration_hud

	_view_model = InteractiveSceneViewModel.new()
	_view_model.name = "InteractiveSceneViewModel"
	add_child(_view_model)

	map_view.bind(_view_model)
	_view_model.hotspot_activated.connect(_on_hotspot_activated)

	if not _view_model.load_scene(interactive_scene_id):
		push_error("[ExplorationInteractiveMap] No se pudo cargar la escena interactiva '%s'" % interactive_scene_id)

	# El mapa vive bajo el combate (CanvasLayer -1), pero se oculta además
	# durante combate/victoria/derrota para que sus botones nunca queden
	# visibles ni clicables a través de la escena de combate.
	EventBus.game_state_changed.connect(_on_game_state_changed)

	# El HUD no refresca en su propio _ready() (el player aún no existe);
	# la escena raíz lo hace — mismo contrato que en el pueblo.
	exploration_hud.refresh()

	# Spike 13 — diferido: que SceneOrchestrator termine de atender EXPLORATION antes
	# de abrir la escena narrativa (evita una transición reentrante).
	_view_model.call_deferred("request_first_visit")

	print("[ExplorationInteractiveMap] Ready")


func _on_hotspot_activated(interaction_type: String, target_id: String, enemy_definitions: Dictionary) -> void:
	exploration_controller.request_interaction(interaction_type, target_id, enemy_definitions)


func _on_game_state_changed(new_state: int) -> void:
	var state := new_state as GameLoopSystem.GameState
	map_layer.visible = state != GameLoopSystem.GameState.COMBAT_ACTIVE \
		and state != GameLoopSystem.GameState.VICTORY \
		and state != GameLoopSystem.GameState.DEFEAT
