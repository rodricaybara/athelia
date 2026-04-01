class_name ExplorationHUD
extends CanvasLayer

## ExplorationHUD - UI mínima durante exploración

@onready var interact_prompt: Label = $InteractPrompt
@onready var hp_label: Label = $ResourcesPanel/HP
@onready var stamina_label: Label = $ResourcesPanel/Stamina
@onready var gold_label: Label = $ResourcesPanel/Gold
@onready var state_debug_label: Label = $StateDebugLabel

func _ready() -> void:
	if interact_prompt:
		interact_prompt.visible = false
	
	if EventBus:
		EventBus.game_state_changed.connect(_on_game_state_changed)

	# Escuchar cambios de recursos para refrescar el HUD en tiempo real.
	var res_system: ResourceSystem = get_node_or_null("/root/Resources")
	if res_system:
		res_system.resource_changed.connect(_on_resource_changed)

	# NO llamar a _refresh_resources() aquí — el player aún no está registrado.
	# La escena raíz llamará a refresh() desde _ready() tras registrar al player.
	print("[ExplorationHUD] Ready")


# ============================================
# API PÚBLICA
# ============================================

func show_interact_prompt(_localization_key: String) -> void:
	if interact_prompt:
		interact_prompt.text = "[E] Interactuar"
		interact_prompt.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_skill_tree"):
		var orchestrator := get_node_or_null("/root/SceneOrchestrator")
		if orchestrator:
			orchestrator.open_skill_tree("player")
		get_viewport().set_input_as_handled()

func hide_interact_prompt() -> void:
	if interact_prompt:
		interact_prompt.visible = false


## Llamado explícitamente desde ExplorationTest tras registrar al player
func refresh() -> void:
	_refresh_resources()


# ============================================
# RECURSOS
# ============================================

func _refresh_resources() -> void:
	var res_system: ResourceSystem = get_node_or_null("/root/Resources")
	if not res_system:
		return
	
	var hp: float = res_system.get_resource_amount("player", "health")
	var stamina: float = res_system.get_resource_amount("player", "stamina")
	var gold: float = res_system.get_resource_amount("player", "gold")
	
	if hp_label:
		hp_label.text = "HP: %d" % hp
	if stamina_label:
		stamina_label.text = "ST: %d" % stamina
	if gold_label:
		gold_label.text = "G: %d" % gold


func _on_game_state_changed(new_state: int) -> void:
	if state_debug_label:
		state_debug_label.text = GameLoopSystem.GameState.keys()[new_state]
	
	if new_state == GameLoopSystem.GameState.EXPLORATION:
		_refresh_resources()


func _on_resource_changed(entity_id: String, _resource_id: String, _current: float, _max: float) -> void:
	# Refrescar solo cuando cambia un recurso del player
	if entity_id == "player":
		_refresh_resources()
