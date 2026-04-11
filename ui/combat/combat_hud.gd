class_name CombatHud
extends CanvasLayer

## CombatHud — View
##
## Responsabilidades:
##   - Mostrar los slots del loadout activo como acciones de combate
##   - Mostrar cooldowns por rondas y disponibilidad de cada slot
##   - Mostrar barras de vida y stamina del jugador
##   - Traducir input del jugador en acciones de combate vía EventBus
##   - SOLO LECTURA respecto al loadout — no permite modificarlo
##
## Nunca accede a CharacterState, LoadoutState ni sistemas core directamente.
## Todo pasa por CombatHudViewModel.
##
## Estructura esperada del .tscn:
##
## CanvasLayer                            ← este script
## └── MarginContainer
##     └── VBox (VBoxContainer)
##         ├── ResourcesHBox (HBoxContainer)
##         │   ├── HealthBar (Control o Label)  ← HealthLabel por simplicidad
##         │   └── StaminaBar (Control o Label) ← StaminaLabel por simplicidad
##         └── SlotsHBox (HBoxContainer)        ← todos los slots en fila


# ============================================
# NODOS
# ============================================

@onready var health_label:  Label        = $MarginContainer/VBox/ResourcesHBox/HealthLabel
@onready var stamina_label: Label        = $MarginContainer/VBox/ResourcesHBox/StaminaLabel
@onready var slots_hbox:    HBoxContainer = $MarginContainer/VBox/SlotsHBox


# ============================================
# CONSTANTES VISUALES
# ============================================

const COLOR_AVAILABLE   := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_UNAVAILABLE := Color(0.4, 0.4, 0.4, 1.0)
const COLOR_COOLDOWN    := Color(0.3, 0.5, 0.9, 1.0)
const COLOR_EMPTY       := Color(0.25, 0.25, 0.25, 0.6)

## InputMap actions por slot_id
const SLOT_INPUT_ACTION: Dictionary = {
	"attack_1":    "combat_attack_1",
	"attack_2":    "combat_attack_2",
	"attack_3":    "combat_attack_3",
	"dodge":       "combat_dodge",
	"defense":     "combat_defense",
	"escape":      "combat_escape",
	"consumable_1": "combat_consumable_1",
	"consumable_2": "combat_consumable_2",
}


# ============================================
# ESTADO INTERNO
# ============================================

var _vm: CombatHudViewModel = null


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	visible = false

	_vm = CombatHudViewModel.new()
	_vm.name = "ViewModel"
	add_child(_vm)

	_vm.changed.connect(_on_vm_changed)

	print("[CombatHud] Ready")


func _input(event: InputEvent) -> void:
	if not visible:
		return

	for slot_id in SLOT_INPUT_ACTION.keys():
		var action: String = SLOT_INPUT_ACTION[slot_id]
		if not InputMap.has_action(action):
			continue
		if event.is_action_pressed(action):
			_on_slot_action_pressed(slot_id)
			get_viewport().set_input_as_handled()
			return


# ============================================
# CALLBACK ÚNICO DEL VIEWMODEL
# ============================================

func _on_vm_changed(reason: String) -> void:
	match reason:
		"opened":
			_render_all()
		"slots":
			_render_slots()
		"resources":
			_render_resources()
		_:
			push_warning("[CombatHud] Razón desconocida: %s" % reason)


# ============================================
# RENDERS
# ============================================

func _render_all() -> void:
	_render_resources()
	_render_slots()
	visible = true


func _render_resources() -> void:
	health_label.text  = "HP: %d/%d"  % [_vm.health_current, _vm.health_max]
	stamina_label.text = "ST: %d/%d"  % [_vm.stamina_current, _vm.stamina_max]


func _render_slots() -> void:
	_clear_container(slots_hbox)

	for slot_data in _vm.action_slots:
		var btn := _create_slot_button(slot_data)
		slots_hbox.add_child(btn)


# ============================================
# CONSTRUCCIÓN DE BOTONES DE SLOT
# ============================================

func _create_slot_button(data: CombatHudViewModel.ActionSlotData) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(70, 70)
	btn.disabled = true  # El HUD no permite click directo — solo teclado

	if data.is_empty:
		btn.text     = "[%s]" % data.keybind_label
		btn.modulate = COLOR_EMPTY
		return btn

	# Texto principal: keybind + nombre
	var lines: PackedStringArray = PackedStringArray()
	lines.append("[%s]" % data.keybind_label)
	lines.append(data.display_name)

	if data.cooldown_remaining > 0:
		lines.append(tr("HUD_COOLDOWN") + ": %d" % data.cooldown_remaining)
	elif data.stamina_cost > 0:
		lines.append("ST: %d" % data.stamina_cost)

	btn.text = "\n".join(lines)

	# Color según estado
	if data.cooldown_remaining > 0:
		btn.modulate = COLOR_COOLDOWN
	elif data.is_available:
		btn.modulate = COLOR_AVAILABLE
	else:
		btn.modulate = COLOR_UNAVAILABLE

	return btn


# ============================================
# INPUT — acción de combate
# ============================================

func _on_slot_action_pressed(slot_id: String) -> void:
	# Buscar el ActionSlotData correspondiente
	var slot_data: CombatHudViewModel.ActionSlotData = null
	for s in _vm.action_slots:
		if s.slot_id == slot_id:
			slot_data = s
			break

	if slot_data == null or slot_data.is_empty or not slot_data.is_available:
		return

	if slot_data.slot_type == "skill":
		var state: CharacterState = Characters.get_character_state("player")
		if state == null:
			return
		var skill_id: String = state.loadout.get_skill(slot_id)
		if skill_id == "":
			return
		EventBus.player_action_requested.emit({
			"actor":    "player",
			"skill_id": skill_id,
			"slot_id":  slot_id,
		})

	elif slot_data.slot_type == "consumable":
		var state: CharacterState = Characters.get_character_state("player")
		if state == null:
			return
		var item_id: String = state.loadout.get_consumable(slot_id)
		if item_id == "":
			return
		Inventory.request_use_item("player", item_id)


# ============================================
# UTILIDADES
# ============================================

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.free()
