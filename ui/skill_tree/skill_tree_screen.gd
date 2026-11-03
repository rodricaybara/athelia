class_name SkillTreeScreen
extends CanvasLayer

## SkillTreeScreen — View del árbol de habilidades (Spike 21a: Design System)
##
## Responsabilidades:
##   - Pintar cabecera, pestañas, filtros, rejilla de SkillCard y cajetín de detalle
##   - Traducir clics en intenciones del ViewModel
##   - NADA más
##
## Nunca accede a Skills, SkillProgression, Party ni Characters.
## Todo pasa por SkillTreeViewModel, que entrega claves; la View traduce con tr().
##
## Contratos públicos (intactos): open(entity_id) y señal `closed`.
## SkillTreeScreen NUNCA se autolibera: quien la instancia (PlayerMenuScreen,
## SceneOrchestrator) hace queue_free() al recibir `closed`.
##
## Modo "Comparar" (Spike 21b): tabla de la party con una columna por personaje.
## Sustituye a la rejilla y al detalle; pestañas y filtros se ocultan.


signal closed


const UI_BUTTON: PackedScene = preload("res://ui/design_system/components/ui_button/ui_button.tscn")
const UI_RESOURCE_BAR: PackedScene = preload("res://ui/design_system/components/ui_resource_bar/ui_resource_bar.tscn")

const FRAME_FRACTION: float = 0.9
const FRAME_MAX_SIZE: Vector2 = Vector2(1400, 820)
## Marco ancho (≥ esto) → cajetín de detalle ancho; si no, estrecho.
const FRAME_WIDE_MIN_WIDTH: float = 1200.0
const DETAIL_WIDTH_WIDE: int = 500
const DETAIL_WIDTH_NARROW: int = 380
const SKILL_CARD_WIDTH: int = 260
const DETAIL_BAR_HEIGHT: int = 8
const FEEDBACK_DURATION: float = 2.5
const COMPARISON_NAME_MIN_WIDTH: int = 180
const COMPARISON_BAR_MIN_WIDTH: int = 80
const COMPARISON_BAR_HEIGHT: int = 6
const COMPARISON_PCT_MIN_WIDTH: int = 48


@onready var backdrop: ColorRect = %Backdrop
@onready var frame: Control = %Frame
@onready var title_label: Label = %TitleLabel
@onready var entity_box: HBoxContainer = %EntityBox
@onready var prev_button: Button = %PrevButton
@onready var entity_label: Label = %EntityLabel
@onready var next_button: Button = %NextButton
@onready var compare_button: Button = %CompareButton
@onready var close_button: Button = %CloseButton
@onready var nav_row: HBoxContainer = %NavRow
@onready var tab_bar: HBoxContainer = %TabBar
@onready var filter_bar: HBoxContainer = %FilterBar
@onready var skill_scroll: ScrollContainer = %SkillScroll
@onready var skill_box: VBoxContainer = %SkillBox
@onready var detail_panel: Control = %DetailPanel
@onready var detail_header: PanelContainer = %DetailHeader
@onready var detail_name: Label = %DetailName
@onready var detail_pct: Label = %DetailPct
@onready var detail_content: VBoxContainer = %DetailContent
@onready var detail_footer: PanelContainer = %DetailFooter
@onready var reason_title: Label = %ReasonTitle
@onready var reason_hint: Label = %ReasonHint
@onready var feedback_label: Label = %FeedbackLabel
@onready var train_button: Button = %TrainButton
@onready var comparison_panel: Control = %ComparisonPanel
@onready var comparison_grid: GridContainer = %ComparisonGrid
@onready var feedback_timer: Timer = %FeedbackTimer


var _vm: SkillTreeViewModel = null

## Tarjetas visibles: { skill_id: SkillCard }. Se vacía en cada repintado.
var _cards: Dictionary = {}
var _render_pending: bool = false
var _keep_scroll: bool = true


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	visible = false
	backdrop.color = UITokens.BG_VOID
	_style_static()

	_vm = SkillTreeViewModel.new()
	_vm.name = "ViewModel"
	add_child(_vm)
	_vm.changed.connect(_on_vm_changed)

	close_button.pressed.connect(func() -> void: _vm.request_close())
	prev_button.pressed.connect(func() -> void: _vm.request_step_entity(-1))
	next_button.pressed.connect(func() -> void: _vm.request_step_entity(1))
	compare_button.pressed.connect(func() -> void: _vm.request_toggle_comparison_mode())
	train_button.pressed.connect(func() -> void: _vm.request_train_selected_skill())
	feedback_timer.timeout.connect(_hide_feedback)

	get_viewport().size_changed.connect(_update_frame_rect)
	_update_frame_rect()

	print("[SkillTreeScreen] Ready")


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_vm.request_close()
		get_viewport().set_input_as_handled()


# ============================================
# API PÚBLICA
# ============================================

func open(entity_id: String = "player") -> void:
	_vm.open(entity_id)


# ============================================
# CALLBACK ÚNICO DEL VIEWMODEL
# ============================================

func _on_vm_changed(reason: String) -> void:
	match reason:
		"opened":
			_hide_feedback()
			_render_all()
			_update_frame_rect()
			visible = true
		"entity_changed":
			# Los botones < > son nodos fijos: no se destruyen al repintar.
			_hide_feedback()
			_render_all()
		"tab", "filter_changed":
			# Diferido: el clic viene de un botón de la barra que vamos a destruir.
			_hide_feedback()
			_schedule_render(false)
		"selection":
			# Sin repintar la rejilla: solo cambia la marca de selección.
			_hide_feedback()
			_refresh_card_selection()
			_render_detail()
		"training_done":
			if _vm.train_result != null:
				_show_train_result(_vm.train_result)
			_schedule_render(true)
		"error":
			_show_feedback(tr(_vm.error_message), UITokens.COLOR_DANGER_SOFT)
		"mode_changed":
			# El clic viene del botón fijo "Comparar", o el refresco es externo.
			_hide_feedback()
			_render_header()
			_render_mode()
			_render_comparison()
		"closed":
			visible = false
			closed.emit()
		_:
			push_warning("[SkillTreeScreen] Razón desconocida: %s" % reason)


func _schedule_render(keep_scroll: bool) -> void:
	if _render_pending:
		# Varias razones en el mismo frame: basta que una pida reiniciar el scroll.
		_keep_scroll = _keep_scroll and keep_scroll
		return
	_keep_scroll = keep_scroll
	_render_pending = true
	call_deferred("_flush_render")


func _flush_render() -> void:
	_render_pending = false
	if not visible:
		return
	var scroll_position: int = skill_scroll.scroll_vertical
	_render_all()
	if _keep_scroll:
		# El layout de la rejilla nueva aún no existe: se restaura al siguiente frame.
		await get_tree().process_frame
		skill_scroll.scroll_vertical = scroll_position


# ============================================
# RENDERS
# ============================================

func _render_all() -> void:
	_render_header()
	_render_mode()
	_render_tabs()
	_render_filters()
	_render_skills()
	_render_detail()
	_render_comparison()


func _render_header() -> void:
	title_label.text = tr("SKILL_TREE_TITLE")
	entity_label.text = tr(_vm.selected_entity_name_key)
	var has_party: bool = _vm.entities.size() > 1
	entity_box.visible = has_party and not _vm.comparison_mode
	compare_button.text = tr("SKILL_TREE_MODE_INDIVIDUAL") if _vm.comparison_mode else tr("SKILL_TREE_MODE_PARTY")
	compare_button.visible = has_party


## Individual: pestañas + rejilla + detalle. Comparar: solo la tabla.
func _render_mode() -> void:
	var individual: bool = not _vm.comparison_mode
	nav_row.visible = individual
	skill_scroll.visible = individual
	detail_panel.visible = individual
	comparison_panel.visible = not individual


func _render_tabs() -> void:
	_clear_container(tab_bar)
	for subcategory in _vm.available_subcategories:
		var is_active: bool = subcategory == _vm.active_subcategory
		var button: UIButton = _make_nav_button(tr("SKILL_SUBCATEGORY_%s" % subcategory), is_active, UIButton.Size.MD)
		button.pressed.connect(_vm.request_select_subcategory.bind(subcategory))
		tab_bar.add_child(button)


func _render_filters() -> void:
	_clear_container(filter_bar)
	var filters: Array[Dictionary] = [
		{ "mode": SkillTreeViewModel.FilterMode.ALL, "key": "SKILL_FILTER_ALL" },
		{ "mode": SkillTreeViewModel.FilterMode.TRAINABLE, "key": "SKILL_FILTER_TRAINABLE" },
		{ "mode": SkillTreeViewModel.FilterMode.UNLOCKED, "key": "SKILL_FILTER_UNLOCKED" },
		{ "mode": SkillTreeViewModel.FilterMode.LOCKED, "key": "SKILL_FILTER_LOCKED" },
	]
	for entry in filters:
		var mode: SkillTreeViewModel.FilterMode = entry["mode"]
		var button: UIButton = _make_nav_button(tr(entry["key"] as String), mode == _vm.active_filter, UIButton.Size.SM)
		button.pressed.connect(_vm.request_set_filter.bind(mode))
		filter_bar.add_child(button)


func _make_nav_button(text: String, active: bool, button_size: UIButton.Size) -> UIButton:
	var button: UIButton = UI_BUTTON.instantiate() as UIButton
	button.text = text
	button.variant = UIButton.Variant.PRIMARY if active else UIButton.Variant.SECONDARY
	button.btn_size = button_size
	return button


func _render_skills() -> void:
	_clear_container(skill_box)
	_cards.clear()

	if _vm.tier_groups.is_empty():
		var empty := Label.new()
		empty.text = tr("SKILL_TREE_NO_SKILLS")
		_style_label(empty, UITokens.FONT_SIZE_MD, UITokens.TEXT_MUTED)
		skill_box.add_child(empty)
		return

	# Con un solo nivel la cabecera sería ruido.
	var show_headers: bool = _vm.tier_groups.size() > 1
	for group: SkillTreeViewModel.TierGroup in _vm.tier_groups:
		if show_headers:
			var header := Label.new()
			header.text = tr("SKILL_TREE_TIER_HEADER") % group.tier
			_style_label(header, UITokens.FONT_SIZE_SM, UITokens.COLOR_ACCENT)
			skill_box.add_child(header)

		var flow := HFlowContainer.new()
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_theme_constant_override("h_separation", UITokens.SPACE_SM)
		flow.add_theme_constant_override("v_separation", UITokens.SPACE_SM)
		skill_box.add_child(flow)
		for skill: SkillTreeViewModel.SkillData in group.skills:
			flow.add_child(_make_skill_card(skill))


func _make_skill_card(skill: SkillTreeViewModel.SkillData) -> SkillCard:
	var card := SkillCard.new()
	card.custom_minimum_size.x = SKILL_CARD_WIDTH
	card.data = skill

	var pct_text: String = "%d %%" % skill.current_value if skill.is_unlocked else "—"
	card.setup(tr(skill.name_key), pct_text, skill.current_value if skill.is_unlocked else 0,
		not skill.is_unlocked, skill.is_trainable, _card_tooltip(skill))
	card.set_selected(_vm.selected_skill != null and _vm.selected_skill.skill_id == skill.skill_id)
	card.pressed.connect(_on_card_pressed)
	_cards[skill.skill_id] = card
	return card


## Tooltip de una skill bloqueada con requisitos: "Requiere: A ≥ 50 %, B ≥ 20 %".
func _card_tooltip(skill: SkillTreeViewModel.SkillData) -> String:
	if skill.is_unlocked or skill.prereqs.is_empty():
		return ""
	var parts: PackedStringArray = []
	for prereq: SkillTreeViewModel.PrereqData in skill.prereqs:
		parts.append("%s ≥ %d %%" % [tr(prereq.name_key), prereq.threshold])
	return tr("SKILL_TREE_REQUIRES_TOOLTIP") % ", ".join(parts)


func _refresh_card_selection() -> void:
	var selected_id: String = _vm.selected_skill.skill_id if _vm.selected_skill != null else ""
	for skill_id: String in _cards.keys():
		var card: SkillCard = _cards[skill_id] as SkillCard
		if is_instance_valid(card):
			card.set_selected(skill_id == selected_id)


# ============================================
# DETALLE
# ============================================

func _render_detail() -> void:
	_clear_container(detail_content)
	var skill: SkillTreeViewModel.SkillData = _vm.selected_skill

	if skill == null:
		detail_name.text = tr("SKILL_TREE_SELECT_HINT")
		detail_pct.text = ""
		reason_title.visible = false
		reason_hint.visible = false
		train_button.text = tr("SKILL_TREE_BTN_TRAIN")
		_set_train_button_enabled(false)
		return

	detail_name.text = tr(skill.name_key)
	detail_pct.text = "%d %%" % skill.current_value if skill.is_unlocked else "—"

	_add_detail_bar(skill.current_value if skill.is_unlocked else 0, not skill.is_unlocked)
	_add_text(_detail_subtitle(skill), UITokens.FONT_SIZE_SM, UITokens.TEXT_MUTED)

	var description: String = _translate_or_empty(skill.description_key)
	if description != "":
		_add_text(description, UITokens.FONT_SIZE_MD, UITokens.TEXT_PRIMARY)

	_add_section_header(tr("SKILL_TREE_SECTION_COMBAT_USE") if skill.mode == "COMBAT" else tr("SKILL_TREE_SECTION_EXPLORATION_USE"))
	detail_content.add_child(_make_meta_grid(skill))
	if skill.mode != "COMBAT" and skill.effects.is_empty():
		_add_text(tr("SKILL_TREE_EXPLORATION_NOTE"), UITokens.FONT_SIZE_SM, UITokens.TEXT_MUTED)

	if not skill.effects.is_empty():
		_add_section_header(tr("SKILL_TREE_SECTION_EFFECTS"))
		for effect: SkillTreeViewModel.EffectData in skill.effects:
			detail_content.add_child(_make_effect_row(effect))

	_add_section_header(tr("SKILL_TREE_SECTION_REQS"))
	if skill.prereqs.is_empty():
		_add_text(tr("SKILL_TREE_NO_PREREQS"), UITokens.FONT_SIZE_SM, UITokens.TEXT_MUTED)
	else:
		for prereq: SkillTreeViewModel.PrereqData in skill.prereqs:
			detail_content.add_child(_make_prereq_row(prereq))

	# Pie fijo: motivo (si no se puede entrenar) y botón.
	var blocked: bool = skill.block_reason_key != ""
	reason_title.visible = blocked
	reason_hint.visible = blocked
	if blocked:
		reason_title.text = tr(skill.block_reason_key)
		reason_hint.text = tr(skill.block_reason_key + "_HINT")
	train_button.text = tr("SKILL_TREE_BTN_TRAIN")
	_set_train_button_enabled(skill.is_trainable)


## Desactivado → SECONDARY: el PRIMARY apagado deja el texto casi ilegible.
func _set_train_button_enabled(enabled: bool) -> void:
	train_button.disabled = not enabled
	(train_button as UIButton).set_variant(UIButton.Variant.PRIMARY if enabled else UIButton.Variant.SECONDARY)


func _detail_subtitle(skill: SkillTreeViewModel.SkillData) -> String:
	var parts: PackedStringArray = []
	parts.append(tr("SKILL_SUBCATEGORY_%s" % skill.subcategory))
	parts.append(tr("SKILL_TREE_TIER_HEADER") % skill.tier)
	parts.append(tr("SKILL_TREE_STATE_UNLOCKED") if skill.is_unlocked else tr("SKILL_TREE_STATE_LOCKED"))
	return " · ".join(parts)


func _add_detail_bar(value: int, locked: bool) -> void:
	var bar: UIResourceBar = UI_RESOURCE_BAR.instantiate() as UIResourceBar
	bar.resource_type = "custom"
	bar.custom_bg_color = UITokens.COLOR_BG
	bar.custom_fill_color = UITokens.COLOR_SLOT_OCCUPIED_BORDER if locked else UITokens.COLOR_PRIMARY
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.set_values(float(value), 100.0)
	detail_content.add_child(bar)
	# Tras su _ready() (que fija 14 px): barra fina.
	bar.custom_minimum_size.y = DETAIL_BAR_HEIGHT


func _add_section_header(text: String) -> void:
	_add_text(text.to_upper(), UITokens.FONT_SIZE_SM, UITokens.COLOR_ACCENT)


func _add_text(text: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(label, font_size, color)
	detail_content.add_child(label)


## Objetivo, alcance, reutilización, coste y atributos.
func _make_meta_grid(skill: SkillTreeViewModel.SkillData) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", UITokens.SPACE_LG)
	grid.add_theme_constant_override("v_separation", UITokens.SPACE_SM)

	if skill.mode == "COMBAT":
		_add_meta_cell(grid, tr("SKILL_META_TARGET"), _target_text(skill.target_type))
		_add_meta_cell(grid, tr("SKILL_META_RANGE"), _range_text(skill.range_type))
		if skill.base_cooldown > 0.0:
			_add_meta_cell(grid, tr("SKILL_META_COOLDOWN"), "%s s" % _number_text(skill.base_cooldown))

	for cost: SkillTreeViewModel.CostData in skill.costs:
		if cost.amount <= 0:
			continue
		_add_meta_cell(grid, tr("SKILL_TREE_META_COST"), "%d %s" % [cost.amount, _resource_name(cost.resource_id)])

	if not skill.attribute_ids.is_empty():
		var abbreviations: PackedStringArray = []
		for attribute_id in skill.attribute_ids:
			abbreviations.append(tr("ATTR_ABBR_%s" % attribute_id.to_upper()))
		_add_meta_cell(grid, tr("SKILL_META_ATTRIBUTES"), " · ".join(abbreviations))
	return grid


func _add_meta_cell(grid: GridContainer, label_text: String, value_text: String) -> void:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 0)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(cell)

	var label := Label.new()
	label.text = label_text
	_style_label(label, UITokens.FONT_SIZE_SM, UITokens.TEXT_MUTED)
	cell.add_child(label)

	var value := Label.new()
	value.text = value_text
	_style_label(value, UITokens.FONT_SIZE_MD, UITokens.TEXT_PRIMARY)
	cell.add_child(value)


func _make_effect_row(effect: SkillTreeViewModel.EffectData) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UITokens.make_stylebox(
		UITokens.COLOR_PANEL_ALT, UITokens.COLOR_BORDER, UITokens.BORDER_WIDTH,
		UITokens.BORDER_RADIUS_SM, UITokens.SPACE_SM))

	var label := Label.new()
	label.text = _effect_text(effect)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(label, UITokens.FONT_SIZE_MD, UITokens.TEXT_PRIMARY)
	panel.add_child(label)
	return panel


## DAMAGE/HEAL: nombre + multiplicador. BUFF/DEBUFF: nombre del buff (+ valor si
## lo trae) y duración. Cualquier otro tipo: texto genérico.
func _effect_text(effect: SkillTreeViewModel.EffectData) -> String:
	var text: String = ""
	match effect.type:
		"DAMAGE":
			text = tr("SKILL_EFFECT_DAMAGE")
			if effect.has_value:
				text += " ×%s" % _number_text(effect.value)
		"HEAL":
			text = tr("SKILL_EFFECT_HEAL")
			if effect.has_value:
				text += " ×%s" % _number_text(effect.value)
		"BUFF", "DEBUFF":
			text = _buff_name(effect)
			if effect.has_value and not is_zero_approx(effect.value):
				text += " %s" % _number_text(effect.value)
			if effect.has_duration:
				text += " · " + tr("SKILL_TREE_EFFECT_DURATION") % _number_text(effect.duration)
		_:
			text = tr("SKILL_TREE_EFFECT_OTHER")

	if effect.max_targets > 1:
		text += " (%d)" % effect.max_targets
	return text


func _buff_name(effect: SkillTreeViewModel.EffectData) -> String:
	if effect.buff_type != "":
		var key: String = "SKILL_BUFF_%s" % effect.buff_type.to_upper()
		var translated: String = tr(key)
		if translated != key:
			return translated
	return tr("SKILL_EFFECT_DEBUFF") if effect.type == "DEBUFF" else tr("SKILL_EFFECT_BUFF")


func _make_prereq_row(prereq: SkillTreeViewModel.PrereqData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITokens.SPACE_SM)

	var mark := Label.new()
	mark.text = "✓" if prereq.is_met else "✗"
	_style_label(mark, UITokens.FONT_SIZE_MD, UITokens.COLOR_SUCCESS if prereq.is_met else UITokens.COLOR_DANGER_SOFT)
	row.add_child(mark)

	var label := Label.new()
	label.text = tr("SKILL_TREE_PREREQ_FORMAT") % [tr(prereq.name_key), prereq.threshold, prereq.current_value]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(label, UITokens.FONT_SIZE_MD, UITokens.TEXT_SECONDARY)
	row.add_child(label)
	return row


# ============================================
# COMPARATIVA
# ============================================

func _render_comparison() -> void:
	_clear_container(comparison_grid)
	if not _vm.comparison_mode:
		return

	var entities: Array[SkillTreeViewModel.EntityData] = _vm.entities
	comparison_grid.columns = 1 + entities.size()

	# Cabecera: hueco sobre la columna de nombres + un nombre por personaje.
	comparison_grid.add_child(Control.new())
	for entity: SkillTreeViewModel.EntityData in entities:
		var header := Label.new()
		header.text = tr(entity.name_key)
		header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_label(header, UITokens.FONT_SIZE_LG, UITokens.TEXT_PRIMARY)
		comparison_grid.add_child(header)

	var last_subcategory: String = ""
	for row: SkillTreeViewModel.ComparisonRow in _vm.comparison_data:
		if row.subcategory != last_subcategory:
			last_subcategory = row.subcategory
			var group := Label.new()
			group.text = tr("SKILL_SUBCATEGORY_%s" % row.subcategory).to_upper()
			_style_label(group, UITokens.FONT_SIZE_SM, UITokens.COLOR_ACCENT)
			comparison_grid.add_child(group)
			for _i in entities.size():
				comparison_grid.add_child(Control.new())

		var name_label := Label.new()
		name_label.text = tr(row.name_key)
		name_label.custom_minimum_size.x = COMPARISON_NAME_MIN_WIDTH
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_style_label(name_label, UITokens.FONT_SIZE_MD, UITokens.TEXT_PRIMARY)
		comparison_grid.add_child(name_label)

		for entity: SkillTreeViewModel.EntityData in entities:
			var cell: SkillTreeViewModel.ComparisonCell = row.cells.get(entity.entity_id) as SkillTreeViewModel.ComparisonCell
			comparison_grid.add_child(_make_comparison_cell(cell))


## Barra fina + porcentaje; "—" si la entidad no tiene la skill desbloqueada.
## Verde = mejorable ahora (misma definición que la rejilla).
func _make_comparison_cell(cell: SkillTreeViewModel.ComparisonCell) -> Control:
	if cell == null or not cell.is_unlocked:
		var empty := Label.new()
		empty.text = "—"
		_style_label(empty, UITokens.FONT_SIZE_MD, UITokens.TEXT_MUTED)
		return empty

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", UITokens.SPACE_SM)

	var bar: UIResourceBar = UI_RESOURCE_BAR.instantiate() as UIResourceBar
	bar.resource_type = "custom"
	bar.custom_bg_color = UITokens.COLOR_BG
	bar.custom_fill_color = UITokens.COLOR_SUCCESS if cell.is_trainable else UITokens.COLOR_PRIMARY
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.set_values(float(cell.current_value), 100.0)
	row.add_child(bar)
	# La fila aún no está en el árbol: el grosor se fija tras el _ready() de la
	# barra (que lo pone a 14 px), no ahora.
	bar.ready.connect(_thin_comparison_bar.bind(bar), CONNECT_ONE_SHOT)

	var pct := Label.new()
	pct.text = "%d %%" % cell.current_value
	pct.custom_minimum_size.x = COMPARISON_PCT_MIN_WIDTH
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style_label(pct, UITokens.FONT_SIZE_MD, UITokens.COLOR_SUCCESS if cell.is_trainable else UITokens.TEXT_PRIMARY)
	row.add_child(pct)
	return row


func _thin_comparison_bar(bar: UIResourceBar) -> void:
	bar.custom_minimum_size = Vector2(COMPARISON_BAR_MIN_WIDTH, COMPARISON_BAR_HEIGHT)


# ============================================
# INPUT → INTENCIONES
# ============================================

func _on_card_pressed(card: SkillCard) -> void:
	var skill := card.data as SkillTreeViewModel.SkillData
	if skill != null:
		_vm.request_select_skill(skill.skill_id)


# ============================================
# TEXTO
# ============================================

func _target_text(target_type: String) -> String:
	match target_type:
		"SELF": return tr("SKILL_TARGET_SELF")
		"SINGLE_ENEMY": return tr("SKILL_TARGET_SINGLE")
		"MULTI_ENEMY": return tr("SKILL_TARGET_MULTI")
		"AREA": return tr("SKILL_TARGET_AREA")
	return target_type


func _range_text(range_type: String) -> String:
	match range_type:
		"MELEE": return tr("SKILL_RANGE_MELEE")
		"SHORT": return tr("SKILL_RANGE_SHORT")
		"MEDIUM": return tr("SKILL_RANGE_MEDIUM")
		"LONG": return tr("SKILL_RANGE_LONG")
	return range_type


## Nombre localizado del recurso; si no hay clave RESOURCE_*_NAME, el id.
func _resource_name(resource_id: String) -> String:
	var key: String = "RESOURCE_%s_NAME" % resource_id.to_upper()
	var text: String = tr(key)
	return resource_id.capitalize() if text == key else text


## 1.0 → "1", 1.5 → "1,5" (coma en español).
func _number_text(value: float) -> String:
	var text: String = str(int(round(value))) if is_equal_approx(value, round(value)) else String.num(value, 1)
	if TranslationServer.get_locale().begins_with("es"):
		text = text.replace(".", ",")
	return text


func _translate_or_empty(key: String) -> String:
	if key == "":
		return ""
	var text: String = tr(key)
	return "" if text == key else text


# ============================================
# FEEDBACK
# ============================================

func _show_train_result(result: SkillTreeViewModel.TrainResult) -> void:
	if result.improved:
		_show_feedback(tr("SKILL_TREE_TRAIN_IMPROVED") % [result.old_value, result.new_value], UITokens.COLOR_SUCCESS)
	else:
		_show_feedback(tr("SKILL_TREE_TRAIN_NOT_IMPROVED"), UITokens.TEXT_SECONDARY)


func _show_feedback(message: String, color: Color) -> void:
	feedback_label.text = message
	feedback_label.add_theme_color_override("font_color", color)
	feedback_label.visible = true
	feedback_timer.start(FEEDBACK_DURATION)


func _hide_feedback() -> void:
	feedback_label.text = ""
	feedback_label.visible = false


# ============================================
# UTILIDADES
# ============================================

func _style_static() -> void:
	_style_label(title_label, UITokens.FONT_SIZE_TITLE, UITokens.TEXT_PRIMARY)
	_style_label(entity_label, UITokens.FONT_SIZE_LG, UITokens.TEXT_PRIMARY)
	_style_label(detail_name, UITokens.FONT_SIZE_XL, UITokens.TEXT_PRIMARY)
	# TEXT_GOLD: su uso documentado es justo el porcentaje del panel lateral.
	_style_label(detail_pct, UITokens.FONT_SIZE_XL, UITokens.TEXT_GOLD)
	_style_label(reason_title, UITokens.FONT_SIZE_MD, UITokens.TEXT_PRIMARY)
	_style_label(reason_hint, UITokens.FONT_SIZE_SM, UITokens.TEXT_SECONDARY)
	_style_label(feedback_label, UITokens.FONT_SIZE_MD, UITokens.COLOR_DANGER_SOFT)

	detail_header.add_theme_stylebox_override("panel", UITokens.make_stylebox(
		UITokens.COLOR_PANEL, UITokens.COLOR_BORDER, UITokens.BORDER_WIDTH, 0, UITokens.SPACE_MD))
	detail_footer.add_theme_stylebox_override("panel", UITokens.make_stylebox(
		UITokens.COLOR_PANEL, UITokens.COLOR_BORDER, UITokens.BORDER_WIDTH, 0, UITokens.SPACE_MD))


func _style_label(label: Label, font_size: int, color: Color) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)


func _clear_container(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


## Marco centrado: FRAME_FRACTION de la pantalla, con tope FRAME_MAX_SIZE
## (mismo criterio que Inventario, Party y Loadout). El cajetín de detalle se
## ensancha en marcos grandes.
func _update_frame_rect() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var target := Vector2(
		minf(screen.x * FRAME_FRACTION, FRAME_MAX_SIZE.x),
		minf(screen.y * FRAME_FRACTION, FRAME_MAX_SIZE.y))
	frame.offset_left = -target.x / 2.0
	frame.offset_right = target.x / 2.0
	frame.offset_top = -target.y / 2.0
	frame.offset_bottom = target.y / 2.0
	var detail_width: int = DETAIL_WIDTH_WIDE if target.x >= FRAME_WIDE_MIN_WIDTH else DETAIL_WIDTH_NARROW
	detail_panel.custom_minimum_size.x = detail_width
