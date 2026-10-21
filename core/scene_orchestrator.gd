extends Node

## SceneOrchestrator - Gestor de escenas y overlays según GameState
## Singleton: /root/SceneOrchestrator  (añadir en Project → Autoloads)
##
## Responsabilidades:
## - Escuchar game_state_changed y mostrar/ocultar la UI correcta
## - Gestionar overlays (Shop, Inventory) como hijos del CanvasLayer
## - Gestionar transición a escena de combate
## - NO modifica GameState directamente — solo reacciona
##
## Flujo:
##   EventBus.game_state_changed → _on_game_state_changed()
##     → _show_overlay() / _hide_current_overlay() / _load_combat_scene()
##
## Sistemas activos por estado (doc Fase 9.1):
##   EXPLORATION : Character, Inventory, Narrative, Resource
##   DIALOGUE    : Dialogue, Narrative
##   SHOP        : Inventory, Resource
##   COMBAT      : Character, Skill, Resource

# ============================================
# RUTAS DE ESCENAS / OVERLAYS
# Cambiar aquí si se mueven los archivos — no hay rutas hardcodeadas en lógica
# ============================================

const SCENE_MAIN_MENU          := "res://ui/main_menu/main_menu_screen.tscn"
const SCENE_CHARACTER_CREATION := "res://ui/character_creation/character_creation_screen.tscn"
const SCENE_COMBAT             := "res://scenes/combat/combat_production_scene.tscn"
#const SCENE_EXPLORATION        := "res://scenes/exploration/tutorial/exploration_tutorial.tscn"
const SCENE_EXPLORATION        := "res://scenes/exploration/interactive_map/exploration_interactive_map.tscn"
#const SCENE_EXPLORATION        := "res://scenes/exploration/telmori_village/exploration_telmori_village.tscn"

const OVERLAY_SHOP       := "res://ui/shop/shop_ui.tscn"
const OVERLAY_INVENTORY  := "res://ui/inventory/inventory_ui.tscn"
const OVERLAY_DIALOGUE   := "res://ui/dialogue/dialogue_panel.tscn"
const OVERLAY_NARRATIVE_SCENE  := "res://ui/narrative_scene/narrative_scene_panel.tscn"
const OVERLAY_PARTY      := "res://ui/party/party_ui.tscn"
const OVERLAY_GAME_OVER  := "res://ui/gameover/game_over_ui.tscn"
const OVERLAY_SKILL_TREE := "res://ui/skill_tree/skill_tree_screen.tscn"
const OVERLAY_PLAYER_MENU := "res://ui/player_menu/player_menu_screen.tscn"
const OVERLAY_LOADOUT    := "res://ui/loadout/loadout_screen.tscn"
const OVERLAY_COMBAT_HUD := "res://ui/combat/combat_arena_panel.tscn"

## Grupo 3 (mejoras post-Spike 3) — estados desde los que puede abrirse un
## overlay "ligero" (Inventory/Party/PlayerMenu). NARRATIVE_SCENE se añade
## aquí solo como parte del chequeo de estado — la apertura real durante
## narrativa NUNCA pasa por open_inventory()/open_party()/open_player_menu():
## la gestiona NarrativeScenePanel como sub-overlay propio, precisamente
## para no tocar _current_overlay (que en NARRATIVE_SCENE apunta al propio
## panel narrativo — ver narrative_scene_panel.gd). El guard explícito
## dentro de cada open_X() de más abajo es una red de seguridad: si algo
## llegara a invocar estos métodos durante NARRATIVE_SCENE, se bloquea con
## un aviso en vez de destruir el panel narrativo por el toggle de
## _current_overlay.
const LIGHT_OVERLAY_ALLOWED_STATES: Array = [
	GameLoopSystem.GameState.EXPLORATION,
	GameLoopSystem.GameState.NARRATIVE_SCENE,
]

# ============================================
# ESTADO INTERNO
# ============================================

## Overlay actualmente visible (puede ser null)
## Tipado como Node porque las escenas de overlay pueden ser CanvasLayer, Control, etc.
var _current_overlay: Node = null

## CanvasLayer raíz donde se instancian overlays
## Se asigna en _ready() buscando el nodo en el árbol
var _overlay_layer: CanvasLayer = null

var _combat_hud: Node = null

## Contexto de la última transición (shop_id, dialogue_id, etc.)
var _pending_context: Dictionary = {}

## Pantalla de Game Over actualmente instanciada (puede ser null).
## La necesita el teardown de _handle_main_menu() para liberarla (Spike 14).
var _game_over_ui: Node = null

# ============================================
# INICIALIZACIÓN
# ============================================

func _ready() -> void:
	# Crear CanvasLayer dedicado para overlays si no existe
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "OverlayLayer"
	_overlay_layer.layer = 10  # Por encima de HUD estándar
	add_child(_overlay_layer)

	# Conectar señales
	if EventBus:
		EventBus.game_state_changed.connect(_on_game_state_changed)
		EventBus.game_state_context.connect(_on_game_state_context)
		EventBus.dialogue_ended.connect(_on_dialogue_ended)
		EventBus.shop_closed.connect(_on_shop_closed)
		EventBus.narrative_scene_closed.connect(_on_narrative_scene_closed)
		EventBus.combat_ended.connect(_on_combat_ended)
		EventBus.player_incapacitated.connect(_on_player_incapacitated)
	else:
		push_error("[SceneOrchestrator] EventBus not found!")

	print("[SceneOrchestrator] Initialized")


# ============================================
# CALLBACKS PRINCIPALES
# ============================================

func _on_game_state_context(_new_state: int, context: Dictionary) -> void:
	_pending_context = context


func _on_game_state_changed(new_state: int) -> void:
	# Sin variable intermedia tipada como GameLoopSystem.GameState: un enum
	# anidado en otra clase no se puede anotar de forma fiable como tipo
	# explícito en esta versión de GDScript (falla incluso con ": Tipo",
	# no solo con ":="). new_state ya es int, y un enum es un int por
	# debajo — comparar contra GameLoopSystem.GameState.MENU en el match
	# funciona igual sin necesidad de castear ni tipar nada.
	print("[SceneOrchestrator] Handling state: %s" % GameLoopSystem.GameState.keys()[new_state])

	match new_state:
		GameLoopSystem.GameState.MENU:
			_handle_main_menu()

		GameLoopSystem.GameState.CHARACTER_CREATION:
			_handle_character_creation()

		GameLoopSystem.GameState.EXPLORATION:
			_handle_exploration()

		GameLoopSystem.GameState.DIALOGUE:
			var dialogue_id: String = _pending_context.get("dialogue_id", "")
			_handle_dialogue(dialogue_id)

		GameLoopSystem.GameState.SHOP:
			var shop_id: String = _pending_context.get("shop_id", "")
			_handle_shop(shop_id)

		GameLoopSystem.GameState.NARRATIVE_SCENE:
			var scene_id: String = _pending_context.get("scene_id", "")
			_handle_narrative_scene(scene_id)

		GameLoopSystem.GameState.COMBAT_ACTIVE:
			_handle_combat()

		GameLoopSystem.GameState.VICTORY, GameLoopSystem.GameState.DEFEAT:
			# El combate gestiona su propio resultado visualmente.
			# Cuando GameLoop haga la transición final, llegará EXPLORATION.
			pass

	# Limpiar contexto tras procesar
	_pending_context = {}

	EventBus.emit_signal("scene_transition_completed", new_state)


# ============================================
# HANDLERS POR ESTADO
# ============================================

func _handle_main_menu() -> void:
	# Cerrar cualquier overlay activo (ej: llegamos desde DEFEAT).
	_hide_current_overlay()
 
	# Spike 14 — teardown de las escenas de la sesión anterior. Síncrono:
	# queue_free() es diferido, así que no rompe a los listeners que aún
	# reciban game_state_changed(MENU) en este mismo frame.
	_free_session_scenes()
 
	# La escena raíz ya es main_menu_screen.tscn — no hay que instanciar nada.
	print("[SceneOrchestrator] Main menu active")
 
	# Spike 14 — reinicio de sesión tras un frame. Se llama SIN await a
	# propósito: dispara y olvida; _handle_main_menu() sigue siendo síncrono.
	# Nadie escucha scene_transition_completed, así que emitirse antes de que
	# acabe el reinicio no afecta a nada.
	_run_session_reset()

## Spike 14 — Libera las escenas que pertenecen a una sesión terminada:
## Game Over, CombatHud, CombatScene y ExplorationScene. Idempotente.
func _free_session_scenes() -> void:
	if _game_over_ui and is_instance_valid(_game_over_ui):
		_game_over_ui.queue_free()
	_game_over_ui = null
 
	if _combat_hud and is_instance_valid(_combat_hud):
		_combat_hud.queue_free()
	_combat_hud = null
 
	for scene_name: String in ["CombatScene", "ExplorationScene"]:
		var node := get_tree().root.get_node_or_null(scene_name)
		if node:
			node.queue_free()
			print("[SceneOrchestrator] Session scene freed: %s" % scene_name)
 
## Spike 14 — Espera un frame (las escenas liberadas ya no existen y ningún
## HUD puede leer entidades que están a punto de darse de baja) y reinicia la
## sesión. Si entre medias el estado ya no es MENU ni CHARACTER_CREATION
## (p.ej. el jugador ya está cargando una partida), NO reinicia: borrar
## entidades de una partida recién cargada sería peor que no reiniciar.
func _run_session_reset() -> void:
	await get_tree().process_frame
 
	var game_loop := get_node_or_null("/root/GameLoop") as GameLoopSystem
	if not game_loop:
		push_error("[SceneOrchestrator] GameLoop not found — session reset skipped")
		return
 
	var state: int = game_loop.current_game_state
	if state != GameLoopSystem.GameState.MENU \
			and state != GameLoopSystem.GameState.CHARACTER_CREATION:
		push_warning("[SceneOrchestrator] Session reset skipped — state is already %s" % GameLoopSystem.GameState.keys()[state])
		return
 
	SessionReset.apply()

func _handle_character_creation() -> void:
	_hide_current_overlay()
	_show_overlay(SCENE_CHARACTER_CREATION)
	if _current_overlay and _current_overlay.has_method("open"):
		_current_overlay.open()
	print("[SceneOrchestrator] Character creation screen loaded")


func _handle_exploration() -> void:
	# Cerrar cualquier overlay activo
	_hide_current_overlay()

	_ensure_exploration_scene_instantiated()

	print("[SceneOrchestrator] Exploration active — overlays cleared")


## Mejoras post-Spike 3, Grupo 1 — factorizado de _handle_exploration(), y
## llamado también desde _handle_narrative_scene(). Necesario porque cargar
## una partida directo en NARRATIVE_SCENE (MENU → NARRATIVE_SCENE, camino
## nuevo de este grupo) podía dejar ExplorationScene sin instanciar todavía
## si el jugador entraba en combate antes de volver nunca a EXPLORATION en
## esa sesión. Sin la escena instanciada, ninguno de los listeners de
## continuación que registra su propio _ready() (ej.
## TelmoriVillage._register_telmori_ambush_continuation() escuchando
## EventBus.combat_ended) llega a conectarse a tiempo — el combate termina,
## emite combat_ended, y nadie lo escucha todavía. El contenido de
## continuación (ej. "Rastros") se perdía en silencio.
## IMPORTANTE: requiere que TelmoriVillage._ready() (y cualquier escena de
## exploración equivalente) NO llame a enter_exploration() salvo cuando
## current_game_state == MENU — si lo hiciera para cualquier otro estado,
## instanciarla aquí en mitad de _handle_narrative_scene() dispararía una
## transición de vuelta a EXPLORATION reentrante, cerrando el propio panel
## narrativo que se está abriendo.
func _ensure_exploration_scene_instantiated() -> void:
	var existing := get_tree().root.get_node_or_null("ExplorationScene")
	if existing:
		return

	var packed := load(SCENE_EXPLORATION) as PackedScene
	if not packed:
		push_error("[SceneOrchestrator] Cannot load exploration scene: %s" % SCENE_EXPLORATION)
		return
	var instance := packed.instantiate()
	instance.name = "ExplorationScene"
	get_tree().root.add_child(instance)
	print("[SceneOrchestrator] Exploration scene instantiated")


func _handle_dialogue(dialogue_id: String) -> void:
	if dialogue_id.is_empty():
		push_warning("[SceneOrchestrator] enter_dialogue called with empty dialogue_id")
		return

	_hide_current_overlay()
	_show_overlay(OVERLAY_DIALOGUE)

	# DialogueSystem es autoload — llamar directamente evita problemas de timing.
	# El panel escucha dialogue_started/dialogue_node_shown vía EventBus.
	var dialogue_system := get_node_or_null("/root/Dialogue") as DialogueSystem
	if dialogue_system:
		dialogue_system.start_dialogue(dialogue_id)
	else:
		push_error("[SceneOrchestrator] DialogueSystem not found at /root/Dialogue")

	print("[SceneOrchestrator] Dialogue overlay shown for: %s" % dialogue_id)

func _handle_narrative_scene(scene_id: String) -> void:
	if scene_id.is_empty():
		push_warning("[SceneOrchestrator] enter_narrative_scene called with empty scene_id")
		return

	# Mejoras post-Spike 3, Grupo 1 — ver _ensure_exploration_scene_instantiated().
	# Garantiza que la escena de exploración (y sus listeners de continuación)
	# existen ANTES de que pueda dispararse ningún combate desde esta escena
	# narrativa, sin importar si se llegó aquí desde EXPLORATION (ya existía)
	# o directo desde MENU al cargar una partida (no existía todavía).
	_ensure_exploration_scene_instantiated()

	_hide_current_overlay()
	_show_overlay(OVERLAY_NARRATIVE_SCENE)

	if _current_overlay and _current_overlay.has_method("open"):
		_current_overlay.open(scene_id)

	print("[SceneOrchestrator] Narrative scene overlay shown for: %s" % scene_id)

func _handle_shop(shop_id: String) -> void:
	if shop_id.is_empty():
		push_warning("[SceneOrchestrator] enter_shop called with empty shop_id")
		return

	_hide_current_overlay()
	_show_overlay(OVERLAY_SHOP)

	# PROBLEMA DE TIMING: game_state_changed llega DESPUÉS de que GameLoop
	# ya emitió shop_open_requested y EconomySystem procesó la apertura.
	# El overlay no existía aún → se perdió el evento shop_opened.
	#
	# SOLUCIÓN: El overlay pide el snapshot directamente al EconomySystem
	# sin emitir shop_open_requested de nuevo (evita el doble disparo).
	if _current_overlay and _current_overlay.has_method("show_shop_direct"):
		var economy = get_node_or_null("/root/Economy")
		if economy:
			var shop = economy.get_shop(shop_id)
			if shop:
				var snapshot = economy.create_shop_snapshot(shop, "player")
				_current_overlay.show_shop_direct(shop_id, "player", snapshot)
			else:
				push_error("[SceneOrchestrator] Shop not found in EconomySystem: %s" % shop_id)
		else:
			push_error("[SceneOrchestrator] EconomySystem autoload not found at /root/Economy")

	print("[SceneOrchestrator] Shop overlay shown for: %s" % shop_id)


func _handle_combat() -> void:
	_hide_current_overlay()

	# Cargar escena de combate (additive)
	var combat_scene := load(SCENE_COMBAT) as PackedScene
	if not combat_scene:
		push_error("[SceneOrchestrator] Cannot load combat scene: %s" % SCENE_COMBAT)
		return

	var combat_instance := combat_scene.instantiate()
	combat_instance.name = "CombatScene"
	get_tree().root.add_child(combat_instance)

	# Instanciar CombatHud — debe estar en el árbol antes de que
	# GameLoop emita combat_started, para no perder la señal.
	var hud_scene := load(OVERLAY_COMBAT_HUD) as PackedScene
	if not hud_scene:
		push_error("[SceneOrchestrator] Cannot load CombatHud: %s" % OVERLAY_COMBAT_HUD)
		return

	_combat_hud = hud_scene.instantiate()
	_combat_hud.name = "CombatHud"
	get_tree().root.add_child(_combat_hud)

	print("[SceneOrchestrator] Combat scene + CombatHud loaded")


# ============================================
# API PÚBLICA - INVENTORY OVERLAY
# (Acceso desde exploración, no cambia GameState)
# ============================================

## Abre el inventario como overlay dentro de EXPLORATION.
## Grupo 3 (mejoras post-Spike 3): el chequeo de estado acepta también
## NARRATIVE_SCENE, pero la apertura real durante narrativa NUNCA pasa por
## aquí — la gestiona NarrativeScenePanel como sub-overlay propio (ver
## narrative_scene_panel.gd). El guard explícito de NARRATIVE_SCENE de
## abajo es una red de seguridad: evita que, si algo llamara a este método
## por error durante narrativa, el toggle de _current_overlay termine
## destruyendo el panel narrativo (que es quien ocupa ese slot en ese
## estado).
func open_inventory() -> void:
	var game_loop := get_node_or_null("/root/GameLoop") as GameLoopSystem
	if not game_loop:
		push_error("[SceneOrchestrator] GameLoop not found")
		return

	if not LIGHT_OVERLAY_ALLOWED_STATES.has(game_loop.current_game_state):
		push_warning("[SceneOrchestrator] Inventory blocked: state is %s" % GameLoopSystem.GameState.keys()[game_loop.current_game_state])
		return

	if game_loop.current_game_state == GameLoopSystem.GameState.NARRATIVE_SCENE:
		push_warning("[SceneOrchestrator] open_inventory() ignorado en NARRATIVE_SCENE — lo gestiona NarrativeScenePanel internamente")
		return

	if _current_overlay and is_instance_valid(_current_overlay):
		# Ya está abierto — cerrar (toggle)
		_hide_current_overlay()
		return

	_show_overlay(OVERLAY_INVENTORY)
	# El inventario se oculta al cerrarse, pero seguiría ocupando _current_overlay
	# y la siguiente pulsación de la tecla lo destruiría (había que pulsar dos veces).
	# Quien instancia la pantalla es quien la libera al recibir "closed".
	if _current_overlay and _current_overlay.has_signal("closed"):
		_current_overlay.closed.connect(_on_overlay_closed.bind(_current_overlay))

	# InventoryUI nace con visible=false — hay que abrirlo explícitamente
	if _current_overlay and _current_overlay.has_method("open_inventory"):
		_current_overlay.open_inventory()

	print("[SceneOrchestrator] Inventory overlay shown")


## Un overlay ligero (inventario, party) avisa con "closed": se libera aquí.
## Quien instancia es quien libera; la pantalla nunca se destruye a sí misma.
func _on_overlay_closed(overlay: Node) -> void:
	if overlay == _current_overlay:
		_hide_current_overlay()
	elif is_instance_valid(overlay):
		overlay.queue_free()

## Grupo 3: mismo criterio que open_inventory() — ver comentario de ese
## método para el porqué del guard de NARRATIVE_SCENE.
func open_party() -> void:
	var game_loop := get_node_or_null("/root/GameLoop") as GameLoopSystem
	if not game_loop:
		return
	if not LIGHT_OVERLAY_ALLOWED_STATES.has(game_loop.current_game_state):
		return

	if game_loop.current_game_state == GameLoopSystem.GameState.NARRATIVE_SCENE:
		push_warning("[SceneOrchestrator] open_party() ignorado en NARRATIVE_SCENE — lo gestiona NarrativeScenePanel internamente")
		return

	if _current_overlay and is_instance_valid(_current_overlay):
		_hide_current_overlay()
		return

	_show_overlay(OVERLAY_PARTY)
	if _current_overlay and _current_overlay.has_signal("closed"):
		_current_overlay.closed.connect(_on_overlay_closed.bind(_current_overlay))
	if _current_overlay and _current_overlay.has_method("open"):
		_current_overlay.open()

	print("[SceneOrchestrator] Party overlay shown")

## Abre el árbol de habilidades como overlay dentro de EXPLORATION.
## entity_id: personaje cuyas habilidades se muestran al abrir.
##   Por defecto "player" — el ExplorationHUD puede pasar un companion_id.
## Solo válido en estado EXPLORATION.
func open_skill_tree(entity_id: String = "player") -> void:
	var game_loop := get_node_or_null("/root/GameLoop") as GameLoopSystem
	if not game_loop:
		push_error("[SceneOrchestrator] GameLoop not found")
		return

	if game_loop.current_game_state != GameLoopSystem.GameState.EXPLORATION:
		push_warning("[SceneOrchestrator] SkillTree blocked: state is %s, expected EXPLORATION" % \
			GameLoopSystem.GameState.keys()[game_loop.current_game_state])
		return

	# Toggle: si ya está abierto, cerrar
	if _current_overlay and is_instance_valid(_current_overlay):
		_hide_current_overlay()
		return

	_show_overlay(OVERLAY_SKILL_TREE)

	# SkillTreeScreen nace con visible=false — abrir explícitamente
	# pasando la entidad inicial para que el ViewModel la seleccione.
	if _current_overlay and _current_overlay.has_method("open"):
		_current_overlay.open(entity_id)

	print("[SceneOrchestrator] SkillTree overlay shown for entity: %s" % entity_id)

## Cierra el árbol de habilidades si está abierto.
## Llamado desde el botón de cierre de SkillTreeScreen vía EventBus
## o directamente desde ExplorationHUD.
func close_skill_tree() -> void:
	if _current_overlay and is_instance_valid(_current_overlay) \
			and _current_overlay is SkillTreeScreen:
		_hide_current_overlay()

## Abre el menú de personaje del jugador.
## Grupo 3: mismo criterio que open_inventory() — ver comentario de ese
## método para el porqué del guard de NARRATIVE_SCENE.
func open_player_menu() -> void:
	var game_loop := get_node_or_null("/root/GameLoop") as GameLoopSystem
	if not game_loop:
		push_error("[SceneOrchestrator] GameLoop not found")
		return

	if not LIGHT_OVERLAY_ALLOWED_STATES.has(game_loop.current_game_state):
		push_warning("[SceneOrchestrator] PlayerMenu blocked: state is %s" % \
			GameLoopSystem.GameState.keys()[game_loop.current_game_state])
		return

	if game_loop.current_game_state == GameLoopSystem.GameState.NARRATIVE_SCENE:
		push_warning("[SceneOrchestrator] open_player_menu() ignorado en NARRATIVE_SCENE — lo gestiona NarrativeScenePanel internamente")
		return

	if _current_overlay and is_instance_valid(_current_overlay):
		_hide_current_overlay()
		return

	_show_overlay(OVERLAY_PLAYER_MENU)

	if _current_overlay and _current_overlay.has_method("open"):
		_current_overlay.open("player")

	print("[SceneOrchestrator] PlayerMenu overlay shown")


## Abre la pantalla de loadout para un personaje concreto.
## Solo válido en EXPLORATION.
## Llamado desde PlayerMenuViewModel.request_open_loadout().
func open_loadout(character_id: String) -> void:
	var game_loop := get_node_or_null("/root/GameLoop") as GameLoopSystem
	if not game_loop:
		push_error("[SceneOrchestrator] GameLoop not found")
		return

	if game_loop.current_game_state != GameLoopSystem.GameState.EXPLORATION:
		push_warning("[SceneOrchestrator] Loadout blocked: state is %s" % \
			GameLoopSystem.GameState.keys()[game_loop.current_game_state])
		return

	if _current_overlay and is_instance_valid(_current_overlay):
		_hide_current_overlay()

	_show_overlay(OVERLAY_LOADOUT)

	if _current_overlay and _current_overlay.has_method("open"):
		_current_overlay.open(character_id)

	print("[SceneOrchestrator] Loadout overlay shown for: %s" % character_id)

# ============================================
# GESTIÓN DE OVERLAYS
# ============================================

## Mejoras post-Spike 3, Grupo 1 — expone el overlay actualmente activo.
## Usado por SaveSystem._collect_narrative_state() para preguntar, vía
## duck-typing (has_method), si es un NarrativeScenePanel y así obtener el
## scene_id activo en el momento de guardar. SceneOrchestrator sigue siendo
## la única fuente de verdad de qué overlay hay abierto — este getter no
## añade estado nuevo, solo lo expone de forma controlada.
func get_current_overlay() -> Node:
	return _current_overlay


func _show_overlay(scene_path: String) -> void:
	var packed := load(scene_path) as PackedScene
	if not packed:
		push_error("[SceneOrchestrator] Cannot load overlay: %s" % scene_path)
		return

	_current_overlay = packed.instantiate()
	if not _current_overlay:
		push_error("[SceneOrchestrator] Failed to instantiate overlay: %s" % scene_path)
		return

	# Si el overlay es un CanvasLayer, añadirlo al root directamente.
	# Anidar CanvasLayer dentro de otro CanvasLayer causa problemas de visibilidad.
	# Si es un Control u otro nodo, añadirlo al _overlay_layer.
	if _current_overlay is CanvasLayer:
		get_tree().root.add_child(_current_overlay)
	else:
		_overlay_layer.add_child(_current_overlay)

	print("[SceneOrchestrator] Overlay shown: %s" % scene_path.get_file())


func _hide_current_overlay() -> void:
	if _current_overlay and is_instance_valid(_current_overlay):
		_current_overlay.queue_free()
	_current_overlay = null


# ============================================
# CALLBACKS DE CIERRE
# ============================================

func _on_dialogue_ended(_dialogue_id: String) -> void:
	var game_loop := get_node_or_null("/root/GameLoop") as GameLoopSystem
	if not game_loop:
		return
 
	# Spike 4 Grupo 2 (mejoras post-Spike 3): dialogue_ended es una señal GLOBAL de
	# EventBus. Si el diálogo se abrió como sub-overlay de NarrativeScenePanel
	# (GameState se queda en NARRATIVE_SCENE, _current_overlay sigue apuntando
	# al panel narrativo — nunca a este diálogo), forzar enter_exploration()
	# aquí destruiría la escena narrativa en curso al cerrar el diálogo.
	# Solo tocamos GameState/_current_overlay si el diálogo se abrió por el
	# camino normal de GameState.DIALOGUE (Interactable "dialogue" desde
	# EXPLORATION). Si estamos en NARRATIVE_SCENE, el cierre lo gestiona
	# NarrativeScenePanel internamente vía su propia señal `closed`.
	if game_loop.current_game_state == GameLoopSystem.GameState.DIALOGUE:
		_hide_current_overlay()
		game_loop.enter_exploration()

func _on_narrative_scene_closed(_scene_id: String) -> void:
	# NarrativeSceneViewModel emite narrative_scene_closed al llegar a un
	# nodo final (sin next_scene_id, sin combate) → volvemos a EXPLORATION.
	# _hide_current_overlay() ya se dispara dentro de _handle_exploration().
	var game_loop := get_node_or_null("/root/GameLoop") as GameLoopSystem
	if game_loop:
		game_loop.enter_exploration()

func _on_shop_closed(_shop_id: String) -> void:
	# EconomySystem emite shop_closed → SceneOrchestrator devuelve a EXPLORATION
	var game_loop := get_node_or_null("/root/GameLoop") as GameLoopSystem
	if game_loop:
		game_loop.enter_exploration()


func _on_combat_ended(result: String) -> void:
	# Destruir CombatHud
	if _combat_hud and is_instance_valid(_combat_hud):
		_combat_hud.queue_free()
	_combat_hud = null

	# Limpiar escena de combate
	var combat_node := get_tree().root.get_node_or_null("CombatScene")
	if combat_node:
		combat_node.queue_free()
		print("[SceneOrchestrator] Combat scene removed")

	match result:
		"victory", "escaped":
			var game_loop := get_node_or_null("/root/GameLoop") as GameLoopSystem
			if game_loop:
				var victory_scene_id := ""
				if result == "victory":
					victory_scene_id = game_loop.consume_pending_victory_scene()

				# Un id mal escrito abriría un panel vacío sin salida (softlock
				# justo tras el combate). Si la escena no existe, degradamos
				# al comportamiento de siempre.
				if not victory_scene_id.is_empty():
					var narrative_db := get_node_or_null("/root/NarrativeSceneDB") as NarrativeSceneRegistry
					if narrative_db and not narrative_db.has_scene(victory_scene_id):
						push_error("[SceneOrchestrator] Escena de victoria inexistente '%s' — vuelvo a EXPLORATION" % victory_scene_id)
						victory_scene_id = ""
				if victory_scene_id.is_empty():
					# En "escaped", end_combat() ya transicionó a EXPLORATION.
					if game_loop.current_game_state != GameLoopSystem.GameState.EXPLORATION:
						game_loop.enter_exploration()
				else:
					game_loop.enter_narrative_scene(victory_scene_id)
		"defeat":
			_show_game_over()

func _show_game_over() -> void:
	_hide_current_overlay()
 
	if _game_over_ui and is_instance_valid(_game_over_ui):
		push_warning("[SceneOrchestrator] Game Over ya está visible — ignorado")
		return
 
	var packed := load(OVERLAY_GAME_OVER) as PackedScene
	if not packed:
		push_error("[SceneOrchestrator] Cannot load game over: %s" % OVERLAY_GAME_OVER)
		return
 
	_game_over_ui = packed.instantiate()
	_game_over_ui.name = "GameOverUI"
	get_tree().root.add_child(_game_over_ui)
	if _game_over_ui.has_method("show_game_over"):
		_game_over_ui.show_game_over()
	print("[SceneOrchestrator] Game Over shown")

func _on_player_incapacitated() -> void:
	# Feedback visual opcional — el combate continúa automáticamente
	# El HUD puede reaccionar a este evento para mostrar estado "downed"
	print("[SceneOrchestrator] Player incapacitated — last stand active")
