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

const SCENE_COMBAT     := "res://scenes/combat/combat_test.tscn"
const SCENE_EXPLORATION := "res://scenes/exploration/exploration_test.tscn"

const OVERLAY_SHOP      := "res://ui/shop/shop_ui.tscn"
const OVERLAY_INVENTORY := "res://ui/inventory/inventory_ui.tscn"
const OVERLAY_DIALOGUE  := "res://ui/dialogue/dialogue_panel.tscn"
const OVERLAY_PARTY     := "res://ui/party/party_ui.tscn"
const OVERLAY_GAME_OVER := "res://ui/gameover/game_over_ui.tscn"
const OVERLAY_SKILL_TREE := "res://ui/skill_tree/skill_tree_screen.tscn"
const OVERLAY_PLAYER_MENU := "res://ui/player_menu/player_menu_screen.tscn"
const OVERLAY_LOADOUT     := "res://ui/loadout/loadout_screen.tscn"
const OVERLAY_COMBAT_HUD  := "res://ui/combat_hud/combat_hud.tscn"

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
	var state := new_state as GameLoopSystem.GameState
	
	print("[SceneOrchestrator] Handling state: %s" % GameLoopSystem.GameState.keys()[state])
	
	match state:
		GameLoopSystem.GameState.EXPLORATION:
			_handle_exploration()
		
		GameLoopSystem.GameState.DIALOGUE:
			var dialogue_id: String = _pending_context.get("dialogue_id", "")
			_handle_dialogue(dialogue_id)
		
		GameLoopSystem.GameState.SHOP:
			var shop_id: String = _pending_context.get("shop_id", "")
			_handle_shop(shop_id)
		
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

func _handle_exploration() -> void:
	# Cerrar cualquier overlay activo
	_hide_current_overlay()
	
	# Si veníamos de combate, la escena de exploración ya está bajo el combate.
	# El combat_test.tscn se habrá limpiado en _on_combat_ended.
	# No necesitamos recargar la escena de exploración en el spike.
	print("[SceneOrchestrator] Exploration active — overlays cleared")


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
## Solo válido en estado EXPLORATION — se bloquea en cualquier otro.
func open_inventory() -> void:
	var game_loop := get_node_or_null("/root/GameLoop") as GameLoopSystem
	if not game_loop:
		push_error("[SceneOrchestrator] GameLoop not found")
		return
	
	if game_loop.current_game_state != GameLoopSystem.GameState.EXPLORATION:
		push_warning("[SceneOrchestrator] Inventory blocked: state is %s, expected EXPLORATION" % GameLoopSystem.GameState.keys()[game_loop.current_game_state])
		return
	
	if _current_overlay and is_instance_valid(_current_overlay):
		# Ya está abierto — cerrar (toggle)
		_hide_current_overlay()
		return
	
	_show_overlay(OVERLAY_INVENTORY)
	
	# InventoryUI nace con visible=false — hay que abrirlo explícitamente
	if _current_overlay and _current_overlay.has_method("open_inventory"):
		_current_overlay.open_inventory()
	
	print("[SceneOrchestrator] Inventory overlay shown")


func close_inventory() -> void:
	if _current_overlay and _current_overlay.name == "InventoryUI":
		_hide_current_overlay()

func open_party() -> void:
	var game_loop := get_node_or_null("/root/GameLoop") as GameLoopSystem
	if not game_loop:
		return
	if game_loop.current_game_state != GameLoopSystem.GameState.EXPLORATION:
		return
	
	if _current_overlay and is_instance_valid(_current_overlay):
		_hide_current_overlay()
		return
		
	_show_overlay(OVERLAY_PARTY)
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
## Solo válido en EXPLORATION.
func open_player_menu() -> void:
	var game_loop := get_node_or_null("/root/GameLoop") as GameLoopSystem
	if not game_loop:
		push_error("[SceneOrchestrator] GameLoop not found")
		return
 
	if game_loop.current_game_state != GameLoopSystem.GameState.EXPLORATION:
		push_warning("[SceneOrchestrator] PlayerMenu blocked: state is %s" % \
			GameLoopSystem.GameState.keys()[game_loop.current_game_state])
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
	_hide_current_overlay()
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
				game_loop.enter_exploration()
		"defeat":
			_show_game_over()

func _show_game_over() -> void:
	_hide_current_overlay()
	var packed := load("res://ui/gameover/game_over_ui.tscn") as PackedScene
	if not packed:
		push_error("[SceneOrchestrator] Cannot load game_over_ui.tscn")
		return
	var game_over := packed.instantiate()
	game_over.name = "GameOverUI"
	get_tree().root.add_child(game_over)
	if game_over.has_method("show_game_over"):
		game_over.show_game_over()
	print("[SceneOrchestrator] Game Over shown")

func _on_player_incapacitated() -> void:
	# Feedback visual opcional — el combate continúa automáticamente
	# El HUD puede reaccionar a este evento para mostrar estado "downed"
	print("[SceneOrchestrator] Player incapacitated — last stand active")
