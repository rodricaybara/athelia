extends CanvasLayer
class_name CombatArenaPanel

## CombatArenaPanel — Pantalla de combate de producción (Grupo 5)
##
## Sustituye a combat_hud.tscn. Renderiza CombatArenaViewModel: fichas de
## party/enemigos (dinámicas — companions/refuerzos pueden unirse a mitad
## de combate), log narrado con autoscroll, y el menú de 8 acciones del
## jugador (vía _vm.action_menu, el CombatHudViewModel existente sin
## tocar). Mismo contrato MVVM de siempre — esta View no accede a
## sistemas core salvo donde combat_hud.gd ya lo hacía (loadout lookup
## al pulsar un botón, ver nota en _on_slot_action_pressed()).

const SLOT_ORDER: Array[String] = [
	"attack_1", "attack_2", "attack_3",
	"dodge", "defense", "escape",
	"consumable_1", "consumable_2",
]

@onready var party_column: VBoxContainer = %PartyColumn
@onready var enemy_column: VBoxContainer = %EnemyColumn
@onready var log_scroll: ScrollContainer = %LogScroll
@onready var log_list: VBoxContainer = %LogList
@onready var action_grid: HBoxContainer = %ActionGrid

var _vm: CombatArenaViewModel = null

## entity_id → UICombatToken instanciado. Nunca se borra una entrada
## (fichas muertas se quedan a 0 PV, decisión ya tomada) — solo crece.
var _tokens: Dictionary = {}

## slot_id → UIButton, uno de los 8 fijos del .tscn.
var _slot_buttons: Dictionary = {}


func _ready() -> void:
	visible = false

	_vm = CombatArenaViewModel.new()
	_vm.name = "ViewModel"
	add_child(_vm)
	_vm.changed.connect(_on_vm_changed)
	# action_menu es un ViewModel hijo con su PROPIA señal changed,
	# independiente de _vm.changed — sin esto, "slots"/"resources"
	# nunca llegan y los botones se quedan vacíos.
	_vm.action_menu.changed.connect(_on_vm_changed)

	# ActionGrid debe tener exactamente 8 UIButton, en el .tscn, en el
	# mismo orden que SLOT_ORDER — se emparejan por posición, no por
	# nombre de nodo (evita depender de una convención de nombres frágil).
	for i in range(SLOT_ORDER.size()):
		if i >= action_grid.get_child_count():
			push_warning("[CombatArenaPanel] ActionGrid tiene menos de 8 botones")
			break
		var btn: Button = action_grid.get_child(i)
		var slot_id: String = SLOT_ORDER[i]
		btn.custom_minimum_size = Vector2(80, 70)
		_slot_buttons[slot_id] = btn
		btn.pressed.connect(_on_slot_action_pressed.bind(slot_id))


func open() -> void:
	visible = true


# ============================================
# CALLBACK ÚNICO DEL VIEWMODEL
# ============================================

func _on_vm_changed(reason: String) -> void:
	match reason:
		"tokens":
			_render_tokens()
		"log_entry":
			_render_new_log_entry()
		"combat_ended":
			_render_combat_ended()
		"slots":
			_render_action_slots()
		"resources":
			pass  # el menú de acciones no muestra PV/EN aparte, solo cooldowns/disponibilidad
		_:
			push_warning("[CombatArenaPanel] Razón desconocida: %s" % reason)


# ============================================
# FICHAS — party/enemigos
# ============================================

func _render_tokens() -> void:
	for data in _vm.combat_tokens:
		var token: UICombatToken = _tokens.get(data.entity_id)
		if token == null:
			token = _instantiate_token(data)
		_apply_token_data(token, data)


func _instantiate_token(data: CombatTokenData) -> UICombatToken:
	var token: UICombatToken = preload("res://ui/design_system/components/ui_combat_token/ui_combat_token.tscn").instantiate()
	_tokens[data.entity_id] = token
	if data.is_party:
		party_column.add_child(token)
	else:
		enemy_column.add_child(token)
	return token


func _apply_token_data(token: UICombatToken, data: CombatTokenData) -> void:
	token.is_party = data.is_party
	token.fill_color = data.fill_color
	if data.is_party:
		token.display_initials = data.display_initials
	else:
		token.type_icon = data.type_icon
	token.set_hp(data.hp_current, data.hp_max)
	if data.is_party:
		token.set_stamina(data.stamina_current, data.stamina_max)
	token.is_current_turn = data.is_current_turn
	token.is_targeted = data.is_targeted


# ============================================
# LOG — append + autoscroll
# ============================================

func _render_new_log_entry() -> void:
	var entry: LogEntryData = _vm.log_entries[-1]

	var label := Label.new()
	label.text = tr(entry.text_key) % entry.format_args
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", _color_for_grade(entry.grade))
	label.add_theme_font_size_override("font_size", 14)  # mismo tamaño que main_theme.tres, sin depender de herencia del tema a través de CanvasLayer
	log_list.add_child(label)

	# Autoscroll al final — un frame de margen para que el ScrollContainer
	# ya conozca la altura del Label recién añadido.
	await get_tree().process_frame
	log_scroll.scroll_vertical = int(log_list.size.y)


func _color_for_grade(grade: int) -> Color:
	match grade:
		SkillRoller.RollResult.FUMBLE:
			return UITokens.COLOR_LOG_FUMBLE
		SkillRoller.RollResult.FAILURE:
			return UITokens.COLOR_LOG_FAILURE
		SkillRoller.RollResult.SPECIAL:
			return UITokens.COLOR_TURN_INDICATOR
		SkillRoller.RollResult.CRITICAL:
			return UITokens.COLOR_LOG_CRITICAL
		_:
			return UITokens.COLOR_TEXT  # SUCCESS y sin grado (-1): texto normal del tema


# ============================================
# MENÚ DE ACCIONES — 8 slots fijos
# ============================================

func _render_action_slots() -> void:
	for slot_data in _vm.action_menu.action_slots:
		var btn: Button = _slot_buttons.get(slot_data.slot_id)
		if btn == null:
			continue
		btn.disabled = slot_data.is_empty or not slot_data.is_available
		btn.text = "" if slot_data.is_empty else _label_for_slot(slot_data)


func _label_for_slot(slot_data: CombatHudViewModel.ActionSlotData) -> String:
	if slot_data.cooldown_remaining > 0:
		return "%s (%d)" % [slot_data.display_name, slot_data.cooldown_remaining]
	return slot_data.display_name


## Réplica del dispatch que ya hace combat_hud.gd — mismo comportamiento,
## no lo cambio sin que se pida, aunque resuelve el loadout aquí en la
## View en vez de en el ViewModel (contrato roto ya en el original).
func _on_slot_action_pressed(slot_id: String) -> void:
	var slot_data: CombatHudViewModel.ActionSlotData = null
	for s in _vm.action_menu.action_slots:
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
			"actor": "player",
			"skill_id": skill_id,
			"slot_id": slot_id,
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
# CIERRE
# ============================================

func _render_combat_ended() -> void:
	for token in _tokens.values():
		token.queue_free()
	_tokens.clear()
	for child in log_list.get_children():
		child.queue_free()
	visible = false
