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

## Spike 8, Punto 4 — con 6-8 enemigos el GridContainer de 2 columnas no
## tiene alto real para todas las fichas a tamaño base y se desborda por
## arriba (decisión de Fernando: encoger ficha, no scroll). Piso mínimo
## de escala para que siga siendo legible con 8 enemigos a la vez.
const TOKEN_MIN_SCALE: float = 0.6

@onready var party_column: VBoxContainer = %PartyColumn
@onready var enemy_column: Container = %EnemyColumn
@onready var log_scroll: ScrollContainer = %LogScroll
@onready var log_list: VBoxContainer = %LogList
@onready var action_grid: HBoxContainer = %ActionGrid
@onready var damage_numbers: Control = %DamageNumbers
@onready var background_image: TextureRect = %BackgroundImage  # Grupo 4
@onready var background_scrim: ColorRect = %Background         # Grupo 4 — fondo sólido sin imagen, velo con imagen

var _vm: CombatArenaViewModel = null

## entity_id → UICombatToken instanciado. Nunca se borra una entrada
## (fichas muertas se quedan a 0 PV, decisión ya tomada) — solo crece.
var _tokens: Dictionary = {}

## entity_id → Control envoltorio de un token ENEMIGO (ver
## _instantiate_token). Solo enemigos lo tienen — party no se redimensiona.
var _enemy_slots: Dictionary = {}

## slot_id → UIButton, uno de los 8 fijos del .tscn.
var _slot_buttons: Dictionary = {}

## Evita recalcular en cada tick de HP/EN — solo cuando cambia el número
## de fichas enemigas (nueva, refuerzo). Las muertas se quedan en el
## array (decisión ya tomada en Grupo 5), así que esto nunca decrece
## salvo que entren refuerzos.
var _last_enemy_count: int = -1

func _ready() -> void:
	visible = false

	_vm = CombatArenaViewModel.new()
	_vm.name = "ViewModel"
	add_child(_vm)
	_vm.changed.connect(_on_vm_changed)
	_render_background()  # estado inicial: sin imagen, fondo sólido desde UITokens
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

	# SceneOrchestrator instancia OVERLAY_COMBAT_HUD sin llamar a ningún
	# método de apertura (igual que hace hoy con combat_hud.gd, puramente
	# reactivo) — se abre solo al entrar en el árbol. open() se queda
	# público e idempotente para los arneses de prueba que sí lo llaman
	# explícitos.
	open()


func open() -> void:
	visible = true
	# combat_system.gd necesita esto para _spawn_damage_number() — sin
	# asignar, nunca sabe dónde instanciar el número flotante.
	var combat: Node = get_node_or_null("/root/Combat")
	if combat:
		combat.damage_numbers_parent = damage_numbers


# ============================================
# CALLBACK ÚNICO DEL VIEWMODEL
# ============================================

func _on_vm_changed(reason: String) -> void:
	match reason:
		"tokens":
			_render_tokens()
		"log_entry":
			_render_new_log_entry()
		"background":
			_render_background()
		"combat_ended":
			_render_combat_ended()
		"slots", "opened":
			_render_action_slots()
		"resources":
			pass  # el menú de acciones no muestra PV/EN aparte, solo cooldowns/disponibilidad
		_:
			push_warning("[CombatArenaPanel] Razón desconocida: %s" % reason)


# ============================================
# FONDO (Grupo 4)
# ============================================

## Sin imagen: Background es el fondo opaco de siempre (tapa la exploración,
## que sigue viva debajo). Con imagen: Background pasa a ser un velo
## semitransparente ENCIMA de la ilustración, para que fichas y log se lean.
func _render_background() -> void:
	var texture: Texture2D = _vm.background_texture
	background_image.texture = texture

	var scrim_color: Color = UITokens.COLOR_PANEL
	scrim_color.a = 1.0 if texture == null else UITokens.COMBAT_BACKGROUND_SCRIM_ALPHA
	background_scrim.color = scrim_color

# ============================================
# FICHAS — party/enemigos
# ============================================

func _render_tokens() -> void:
	for data in _vm.combat_tokens:
		var token: UICombatToken = _tokens.get(data.entity_id)
		if token == null:
			token = _instantiate_token(data)
		_apply_token_data(token, data)
	_rescale_enemy_tokens()


## Spike 8, Punto 4 — el TOKEN EN SÍ nunca cambia de tamaño: todo su
## contenido interno (TokenVisual, HpValueLabel, etc.) está anclado con
## desplazamientos en píxeles FIJOS calculados para un lienzo exacto de
## 96×144 (UICombatToken.BASE_SIZE). Si se le redujera su propio
## custom_minimum_size, esos offsets fijos dejarían de encajar y el
## contenido (iconos incluidos) se descoloca — confirmado en playtest.
## En vez de eso: el token vive dentro de un Control "slot" envoltorio,
## y es ESE envoltorio el que el GridContainer redimensiona de verdad.
## El token, dentro, se queda siempre a tamaño real y se encoge solo
## visualmente con .scale (transform, no relayout) — todo su anclaje
## interno sigue calculado sobre un lienzo de 96×144 válido.
func _rescale_enemy_tokens() -> void:
	var enemy_ids: Array[String] = []
	for data in _vm.combat_tokens:
		if not data.is_party:
			enemy_ids.append(data.entity_id)

	if enemy_ids.is_empty() or enemy_ids.size() == _last_enemy_count:
		return
	_last_enemy_count = enemy_ids.size()

	var rows: int = int(ceil(float(enemy_ids.size()) / float(enemy_column.columns)))

	var available_height: float = enemy_column.size.y
	if available_height <= 0.0:
		# Primer frame: el Container aún no ha calculado su tamaño real.
		await get_tree().process_frame
		available_height = enemy_column.size.y

	var target_row_height: float = available_height / float(rows)
	var scale_factor: float = clampf(target_row_height / UICombatToken.BASE_SIZE.y, TOKEN_MIN_SCALE, 1.0)
	var target_size: Vector2 = UICombatToken.BASE_SIZE * scale_factor

	for entity_id in enemy_ids:
		var slot: Control = _enemy_slots.get(entity_id)
		var token: UICombatToken = _tokens.get(entity_id)
		if slot == null or token == null:
			continue
		slot.custom_minimum_size = target_size
		slot.custom_maximum_size = target_size
		token.scale = Vector2(scale_factor, scale_factor)


func _instantiate_token(data: CombatTokenData) -> UICombatToken:
	var token: UICombatToken = preload("res://ui/design_system/components/ui_combat_token/ui_combat_token.tscn").instantiate()
	_tokens[data.entity_id] = token
	if data.is_party:
		party_column.add_child(token)
	else:
		# Punto 4 — Control envoltorio: es lo único que _rescale_enemy_tokens()
		# redimensiona de verdad. El token queda dentro a su tamaño nativo.
		var slot := Control.new()
		slot.custom_minimum_size = UICombatToken.BASE_SIZE
		slot.add_child(token)
		enemy_column.add_child(slot)
		_enemy_slots[data.entity_id] = slot
	# combat_system.gd localiza el nodo visual de una entidad por grupo
	# (_get_entity_damage_number_position, VFX de buffs) — sin esto, los
	# números de daño nunca encuentran dónde aparecer sobre la ficha.
	token.add_to_group(data.entity_id)
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
	label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_MD)  # explícito: el tema no se hereda a través del CanvasLayer
	# Grupo 4 — contorno para legibilidad sobre fondos de combate claros.
	label.add_theme_constant_override("outline_size", UITokens.TEXT_OUTLINE_SIZE)
	label.add_theme_color_override("font_outline_color", UITokens.COLOR_TEXT_OUTLINE)
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


## Spike 8, Punto 5 — antes este método construía su propio
## action_data a mano y emitía player_action_requested directamente,
## saltándose por completo a PlayerCombatController: el único sitio del
## proyecto que sabe cuál es el target actual (auto-target al entrar en
## combate, ciclado con Tab) y que ya distingue skills normales de
## SPECIAL_ACTIONS (defend/flee, camino propio sin target). Ese dict a
## mano nunca incluía "target" — de ahí el error "No target specified"
## de combat_system.gd al pulsar cualquier botón de ataque. Ahora se
## delega en request_skill(), que ya hace todo eso bien; sin duplicar
## lógica de targeting aquí.
func _on_slot_action_pressed(slot_id: String) -> void:
	var slot_data: CombatHudViewModel.ActionSlotData = null
	for s in _vm.action_menu.action_slots:
		if s.slot_id == slot_id:
			slot_data = s
			break

	if slot_data == null or slot_data.is_empty or not slot_data.is_available:
		return

	if slot_data.slot_type == "skill":
		var controller: Node = get_tree().get_first_node_in_group("player_combat_controller")
		if controller == null:
			push_error("[CombatArenaPanel] PlayerCombatController no encontrado — no se puede solicitar la skill")
			return
		var state: CharacterState = Characters.get_character_state("player")
		if state == null:
			return
		var skill_id: String = state.loadout.get_skill(slot_id)
		if skill_id == "":
			return
		controller.request_skill(skill_id)

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
	for slot in _enemy_slots.values():
		slot.queue_free()
	_enemy_slots.clear()
	_last_enemy_count = -1
	for child in log_list.get_children():
		child.queue_free()
	_render_background()  # _vm.background_texture ya es null en este punto
	visible = false
