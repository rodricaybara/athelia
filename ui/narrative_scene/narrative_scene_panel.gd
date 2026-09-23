extends CanvasLayer
class_name NarrativeScenePanel

## NarrativeScenePanel — Spike 1: Motor Narrativo Base
##
## View del panel narrativo. Contrato estándar del proyecto:
## %UniqueNames sobre el .tscn, textos siempre vía tr(), cero acceso a
## sistemas core (Characters, Narrative, GameLoop...) — todo pasa por
## el ViewModel. Ver estructura de nodos recomendada en la entrega del spike.
##
## Todo botón de opción usa UIButton (Design System) — nunca Button "raw".
##
## Grupo 3 (mejoras post-Spike 3) — overlays de inventario/party/stats
## durante narrativa: Inventory/Party/PlayerMenu se instancian aquí como
## hijos propios, NUNCA vía SceneOrchestrator. Esto evita pisar
## SceneOrchestrator._current_overlay, que en NARRATIVE_SCENE apunta a este
## mismo panel — si Inventory pasara por SceneOrchestrator.open_inventory(),
## su lógica de toggle (un único slot de overlay) destruiría este panel y
## con él el NarrativeSceneViewModel (racha en curso incluida). Ver
## _open_sub_overlay() más abajo.

@onready var scene_image: TextureRect = %SceneImage
@onready var scene_text: Label = %SceneText
@onready var options_container: VBoxContainer = %OptionsContainer

const UI_BUTTON_SCENE := "res://ui/design_system/components/ui_button/ui_button.tscn"

## Grupo 3 — rutas de los sub-overlays abribles desde narrativa. Mismas
## escenas que usa SceneOrchestrator para EXPLORATION, definidas aquí en
## vez de leídas de SceneOrchestrator — mismo criterio que ya usa
## PlayerMenuScreen para sus propias subpantallas (SCENE_LOADOUT, etc.).
const SCENE_INVENTORY    := "res://ui/inventory/inventory_ui.tscn"
const SCENE_PARTY        := "res://ui/party/party_ui.tscn"
const SCENE_PLAYER_MENU  := "res://ui/player_menu/player_menu_screen.tscn"
const SCENE_DIALOGUE     := "res://ui/dialogue/dialogue_panel.tscn"

var _vm: NarrativeSceneViewModel = null

## Grupo 3 — sub-overlay actualmente abierto (Inventory/Party/PlayerMenu),
## o null si no hay ninguno. Un único slot basta: los tres se abren desde
## el mismo _unhandled_input(), que ya deja de escuchar en cuanto
## visible == false (ver _open_sub_overlay()), así que nunca hay dos a la vez.
var _sub_overlay: Node = null

## Spike 4 Grupo 2 — true mientras el sub-overlay abierto es el de Diálogo. Decide
## si _on_sub_overlay_closed() debe avisar al ViewModel (resume_after_dialogue())
## o no. Inventory/Party/PlayerMenu nunca lo activan.
var _sub_overlay_is_dialogue: bool = false

func _ready() -> void:
	visible = false

	_vm = NarrativeSceneViewModel.new()
	_vm.name = "ViewModel"
	add_child(_vm)
	_vm.changed.connect(_on_vm_changed)


## API pública — llamada desde SceneOrchestrator.
func open(scene_id: String) -> void:
	visible = true
	_vm.open(scene_id)


## Mejoras post-Spike 3, Grupo 1 — expone el scene_id de la escena narrativa
## actualmente mostrada, o "" si no hay ninguna (_vm.current_node null).
## Consumido por SaveSystem._collect_narrative_state() vía
## SceneOrchestrator.get_current_overlay() + has_method() duck-typing, para
## saber a qué escena volver al cargar. Sigue siendo válido mientras el
## panel está detrás de un sub-overlay (ej. Diálogo) — visible pasa a false
## en ese caso, pero _vm.current_node no se toca (ver _open_sub_overlay()).
func get_current_scene_id() -> String:
	return _vm.current_node.scene_id if _vm.current_node else ""


# ============================================
# INPUT
# Grupo 3 — mismas acciones que ExplorationController (open_inventory/
# open_party/open_player_menu), pero mientras el panel narrativo está
# visible. ExplorationController no las procesa en este estado (su
# _unhandled_input está bloqueado por GameLoop.is_input_blocked() fuera
# de EXPLORATION), así que no hay doble disparo posible.
# ============================================

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("open_inventory"):
		_vm.request_open_inventory()
	elif event.is_action_pressed("open_party"):
		_vm.request_open_party()
	elif event.is_action_pressed("open_player_menu"):
		_vm.request_open_player_menu()


func _on_vm_changed(reason: String) -> void:
	match reason:
		"opened", "node_changed":
			_render_node()
		"streak_progress":
			_render_streak_progress()
		"open_inventory":
			_open_sub_overlay(SCENE_INVENTORY, func(s): s.open_inventory())
		"open_party":
			_open_sub_overlay(SCENE_PARTY, func(s): s.open())
		"open_player_menu":
			_open_sub_overlay(SCENE_PLAYER_MENU, func(s): s.open("player"))
		"open_dialogue":
			# DialoguePanel no tiene open() — se alimenta de Dialogue (autoload)
			# + EventBus, no de una llamada directa sobre la instancia. El
			# init_callback por tanto ignora el sub_overlay instanciado y llama
			# al autoload directamente — mismo camino que ya usa
			# SceneOrchestrator._handle_dialogue(), sin pasar por GameState.
			_open_sub_overlay(SCENE_DIALOGUE, func(_s): Dialogue.start_dialogue(_vm.pending_dialogue_id), true)
		"closed":
			visible = false
		_:
			push_warning("[NarrativeScenePanel] Razón desconocida: %s" % reason)

## Spike 2 dejó esto expuesto en el ViewModel (streak_current/streak_required)
## sin consumidor en la View — se cierra ahora. Solo añade el progreso al
## texto ya renderizado del nodo actual, sin tocar imagen ni opciones (no
## cambian entre intentos de la misma racha).
func _render_streak_progress() -> void:
	var node := _vm.current_node
	if not node:
		return
	scene_text.text = tr(node.text_key) + "\n\n(%d/%d)" % [_vm.streak_current, _vm.streak_required]

func _render_node() -> void:
	var node := _vm.current_node
	if not node:
		push_error("[NarrativeScenePanel] _render_node: current_node es null")
		return

	if not node.image_path.is_empty():
		scene_image.texture = load(node.image_path)
	else:
		scene_image.texture = null

	scene_text.text = tr(node.text_key)

	_render_options(node.options)


func _render_options(options: Array[NarrativeSceneOption]) -> void:
	_clear_options()
	for option in options:
		options_container.add_child(_instantiate_option_button(option))


func _clear_options() -> void:
	for child in options_container.get_children():
		child.queue_free()


func _instantiate_option_button(option: NarrativeSceneOption) -> Button:
	var button_scene: PackedScene = preload(UI_BUTTON_SCENE)
	var button: Button = button_scene.instantiate()
	button.text = tr(option.text_key)
	button.pressed.connect(func(): _vm.request_option(option.option_id))
	return button


# ============================================
# GRUPO 3 — SUB-OVERLAY (Inventory/Party/PlayerMenu)
#
# Calca _open_subscreen() de PlayerMenuScreen, con una diferencia clave:
# escucha la señal "closed" del sub-overlay en vez de tree_exiting.
# Ninguno de los tres (InventoryUI, PartyUI, PlayerMenuScreen) hace
# queue_free() sobre sí mismo en ningún camino de cierre — todos solo
# ponen visible = false — así que tree_exiting nunca llegaría a
# dispararse aquí. InventoryUI y PlayerMenuScreen ganan una señal
# `closed` propia en este mismo grupo (ver sus ficheros); PartyUI ya
# la tenía.
#
# Nunca pasa por SceneOrchestrator: no toca _current_overlay (que sigue
# apuntando a este panel narrativo durante todo el proceso) ni el estado
# del NarrativeSceneViewModel — abrir/cerrar el sub-overlay es puramente
# de la View, la racha en curso y el nodo actual no se enteran.
# ============================================

func _open_sub_overlay(scene_path: String, init_callback: Callable, is_dialogue: bool = false) -> void:
	_close_sub_overlay()
	_sub_overlay_is_dialogue = is_dialogue

	var packed := load(scene_path) as PackedScene
	if not packed:
		push_error("[NarrativeScenePanel] No se puede cargar: %s" % scene_path)
		return

	_sub_overlay = packed.instantiate()
	add_child(_sub_overlay)
	init_callback.call(_sub_overlay)

	visible = false

	if _sub_overlay.has_signal("closed"):
		_sub_overlay.closed.connect(_on_sub_overlay_closed)
	else:
		push_warning("[NarrativeScenePanel] %s no expone señal 'closed' — su cierre no se detectará" % scene_path.get_file())

	print("[NarrativeScenePanel] Sub-overlay abierto: %s" % scene_path.get_file())


func _on_sub_overlay_closed() -> void:
	var was_dialogue := _sub_overlay_is_dialogue
	_close_sub_overlay()
	visible = true
	if was_dialogue:
		_vm.resume_after_dialogue()


func _close_sub_overlay() -> void:
	if _sub_overlay and is_instance_valid(_sub_overlay):
		if _sub_overlay.has_signal("closed") and _sub_overlay.closed.is_connected(_on_sub_overlay_closed):
			_sub_overlay.closed.disconnect(_on_sub_overlay_closed)
		_sub_overlay.queue_free()
	_sub_overlay = null
