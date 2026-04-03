class_name SkillTreeScreen
extends CanvasLayer

## SkillTreeScreen - View del árbol de habilidades
## Patrón MVVM — ver athelia_ui_architecture.md
##
## DESIGN SYSTEM:
##   - Botones: UIButton instanciado desde ui_button.tscn
##   - Colores: UITokens exclusivamente — sin valores hardcodeados
##   - StyleBoxes: UITokens.make_stylebox() — sin StyleBoxFlat.new() directo
##   - Fondos de panel: UIPanel o make_stylebox vía theme_override en _ready()


# ============================================
# PRELOADS
# ============================================

const UI_BUTTON := preload("res://ui/design_system/components/ui_button/ui_button.tscn")


# ============================================
# NODOS — @onready
# ============================================

@onready var _entity_selector: HBoxContainer        = %EntitySelector
@onready var _mode_toggle_btn: Button               = %ModeToggleBtn
@onready var _close_btn: Button                     = %CloseBtn
@onready var _tab_bar: HBoxContainer                = %TabBar
@onready var _filter_bar: HBoxContainer             = %FilterBar
@onready var _main_container: HBoxContainer         = %MainContainer
@onready var _skill_grid: VBoxContainer             = %SkillGrid
@onready var _detail_panel: VBoxContainer           = %DetailPanel
@onready var _detail_name: Label                    = %DetailName
@onready var _detail_pct: Label                     = %DetailPct
@onready var _detail_content: VBoxContainer 		= %DetailContent
@onready var _train_btn: Button                     = %TrainBtn
@onready var _feedback_label: Label                 = %FeedbackLabel
@onready var _comparison_container: ScrollContainer = %ComparisonContainer
@onready var _comparison_grid: GridContainer        = %ComparisonGrid


# ============================================
# VIEWMODEL
# ============================================

var _vm: SkillTreeViewModel = null


# ============================================
# ESTADO INTERNO
# ============================================

var _feedback_timer: SceneTreeTimer = null
var _entity_buttons: Array[UIButton] = []
var _tab_buttons: Array[UIButton] = []
var _filter_buttons: Array[UIButton] = []


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	visible = false

	_vm = SkillTreeViewModel.new()
	_vm.name = "ViewModel"
	add_child(_vm)
	_vm.changed.connect(_on_vm_changed)

	_close_btn.pressed.connect(func(): _vm.request_close())
	_mode_toggle_btn.pressed.connect(func(): _vm.request_toggle_comparison_mode())
	_train_btn.pressed.connect(_on_train_pressed)

	_apply_panel_styles()


func _unhandled_input(event: InputEvent) -> void:
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
			visible = true
			_render_all()
		"entity_changed":
			_render_entity_selector()
			_render_tabs()
			_render_skills()
			_render_detail()
		"mode_changed":
			_render_mode_toggle()
			_render_skills()
			_render_comparison()
		"filter_changed":
			_render_filter_bar()
			_render_skills()
		"training_done":
			_render_detail()
		"closed":
			visible = false
		_:
			push_warning("[SkillTreeScreen] Razón desconocida: %s" % reason)


# ============================================
# RENDERS
# ============================================

func _render_all() -> void:
	_render_entity_selector()
	_render_mode_toggle()
	_render_tabs()
	_render_filter_bar()
	_render_skills()
	_render_detail()
	_render_comparison()


func _render_entity_selector() -> void:
	for btn in _entity_buttons:
		btn.queue_free()
	_entity_buttons.clear()

	for entry in _vm.available_entities:
		var entity_id: String = entry.get("entity_id", "")
		var display_key: String = entry.get("display_name", entity_id)
		var is_active: bool = entity_id == _vm.selected_entity_id

		var btn: UIButton = UI_BUTTON.instantiate()
		btn.text = tr(display_key)
		btn.variant = UIButton.Variant.PRIMARY if is_active else UIButton.Variant.GHOST
		btn.btn_size = UIButton.Size.SM
		btn.pressed.connect(func(): _vm.request_select_entity(entity_id))
		_entity_selector.add_child(btn)
		_entity_buttons.append(btn)


func _render_mode_toggle() -> void:
	if _vm.comparison_mode:
		_mode_toggle_btn.text = tr("SKILL_TREE_MODE_INDIVIDUAL")
		_main_container.visible = false
		_comparison_container.visible = true
	else:
		_mode_toggle_btn.text = tr("SKILL_TREE_MODE_PARTY")
		_main_container.visible = true
		_comparison_container.visible = false


func _render_tabs() -> void:
	for btn in _tab_buttons:
		btn.queue_free()
	_tab_buttons.clear()

	for subcategory in _vm.available_subcategories:
		var is_active: bool = subcategory == _vm.active_subcategory

		var btn: UIButton = UI_BUTTON.instantiate()
		btn.text = tr("SKILL_SUBCATEGORY_%s" % subcategory)
		btn.variant = UIButton.Variant.SECONDARY if is_active else UIButton.Variant.GHOST
		btn.btn_size = UIButton.Size.SM
		btn.pressed.connect(func(): _vm.request_select_subcategory(subcategory))
		_tab_bar.add_child(btn)
		_tab_buttons.append(btn)


func _render_filter_bar() -> void:
	for btn in _filter_buttons:
		btn.queue_free()
	_filter_buttons.clear()

	var filters: Array = [
		{ "mode": SkillTreeViewModel.FilterMode.ALL,       "key": "SKILL_FILTER_ALL" },
		{ "mode": SkillTreeViewModel.FilterMode.TRAINABLE, "key": "SKILL_FILTER_TRAINABLE" },
		{ "mode": SkillTreeViewModel.FilterMode.UNLOCKED,  "key": "SKILL_FILTER_UNLOCKED" },
		{ "mode": SkillTreeViewModel.FilterMode.LOCKED,    "key": "SKILL_FILTER_LOCKED" },
	]

	for filter_data in filters:
		var fmode: SkillTreeViewModel.FilterMode = filter_data["mode"]
		var is_active: bool = fmode == _vm.active_filter

		var btn: UIButton = UI_BUTTON.instantiate()
		btn.text = tr(filter_data["key"])
		btn.variant = UIButton.Variant.SECONDARY if is_active else UIButton.Variant.GHOST
		btn.btn_size = UIButton.Size.SM
		btn.pressed.connect(func(): _vm.request_set_filter(fmode))
		_filter_bar.add_child(btn)
		_filter_buttons.append(btn)


func _render_skills() -> void:
	for child in _skill_grid.get_children():
		child.queue_free()

	if _vm.comparison_mode:
		return

	var skills_by_tier: Dictionary = _vm.get_skills_by_tier()
	if skills_by_tier.is_empty():
		var empty_label := Label.new()
		empty_label.text = tr("SKILL_TREE_NO_SKILLS")
		empty_label.add_theme_color_override("font_color", UITokens.TEXT_MUTED)
		_skill_grid.add_child(empty_label)
		return

	var tiers: Array = skills_by_tier.keys()
	tiers.sort()

	for i in tiers.size():
		var tier: int = tiers[i]
		var tier_skills: Array = skills_by_tier[tier]

		if i > 0:
			var sep := HSeparator.new()
			sep.add_theme_stylebox_override("separator",
				UITokens.make_stylebox(Color.TRANSPARENT, UITokens.BORDER_SUBTLE, 1, 0, 0))
			_skill_grid.add_child(sep)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", UITokens.SPACE_XS)

		var tier_label := Label.new()
		tier_label.text = "T%d" % tier
		tier_label.custom_minimum_size = Vector2(36, 0)
		tier_label.add_theme_color_override("font_color", UITokens.TEXT_MUTED)
		tier_label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_XS)
		row.add_child(tier_label)

		var cards_container := HBoxContainer.new()
		cards_container.add_theme_constant_override("separation", UITokens.SPACE_XS)
		for skill_data in tier_skills:
			var card := _make_skill_card(skill_data)
			cards_container.add_child(card)

		row.add_child(cards_container)
		_skill_grid.add_child(row)

func _render_detail() -> void:
	if _vm.selected_skill.is_empty():
		_detail_name.text = tr("SKILL_TREE_SELECT_HINT")
		_detail_pct.text = "—"
		_clear_dynamic_detail()
		_train_btn.disabled = true
		_train_btn.text = tr("SKILL_TREE_BTN_LOCKED")
		return
 
	var skill: Dictionary = _vm.selected_skill
	var is_unlocked: bool = skill.get("is_unlocked", false)
 
	_detail_name.text = tr(skill.get("name_key", skill.get("skill_id", "")))
	_detail_pct.text = "%d%%" % skill.get("current_value", 0) if is_unlocked else "—"
 
	_clear_dynamic_detail()
 
	# Descripción
	_add_section_header(tr("SKILL_TREE_SECTION_DESC"))
	var desc_lbl := Label.new()
	desc_lbl.text = tr(skill.get("description_key", ""))
	desc_lbl.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_SM)
	desc_lbl.add_theme_color_override("font_color", UITokens.TEXT_SECONDARY)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_content.add_child(desc_lbl)
 
	# Efectos
	var effects: Array = skill.get("effects", [])
	if not effects.is_empty():
		_add_section_header(tr("SKILL_TREE_SECTION_EFFECTS"))
		for effect in effects:
			_detail_content.add_child(_make_effect_row(effect))
 
	# Metadatos de uso
	var mode: String = skill.get("mode", "")
	_add_section_header(
		tr("SKILL_TREE_SECTION_COMBAT_USE") if mode == "COMBAT"
		else tr("SKILL_TREE_SECTION_EXPLORATION_USE")
	)
	_detail_content.add_child(_make_meta_grid(skill))
 
	# Nota exploración sin efectos
	if mode != "COMBAT" and effects.is_empty():
		var note := Label.new()
		note.text = tr("SKILL_TREE_EXPLORATION_NOTE")
		note.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_XS)
		note.add_theme_color_override("font_color", UITokens.TEXT_MUTED)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_content.add_child(note)
 
	# Requisitos
	_add_section_header(tr("SKILL_TREE_SECTION_REQS"))
	var prereqs: Dictionary = skill.get("prerequisite_requirements", {})
	if prereqs.is_empty():
		var lbl := Label.new()
		lbl.text = tr("SKILL_TREE_NO_PREREQS")
		lbl.add_theme_color_override("font_color", UITokens.TEXT_MUTED)
		lbl.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_SM)
		_detail_content.add_child(lbl)
	else:
		var missing: Array = skill.get("missing_prereqs", [])
		for prereq_id in prereqs.keys():
			var threshold: int = prereqs[prereq_id]
			var is_met: bool = prereq_id not in missing
			var req_row := HBoxContainer.new()
			req_row.add_theme_constant_override("separation", UITokens.SPACE_XS)
			var icon_lbl := Label.new()
			icon_lbl.text = "✓" if is_met else "✗"
			icon_lbl.add_theme_color_override("font_color",
				UITokens.ACCENT_GREEN if is_met else UITokens.ACCENT_DANGER)
			icon_lbl.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_XS)
			req_row.add_child(icon_lbl)
			var req_lbl := Label.new()
			req_lbl.text = "%s ≥ %d%%" % [tr(prereq_id), threshold] if threshold > 0 else tr(prereq_id)
			req_lbl.add_theme_color_override("font_color", UITokens.TEXT_SECONDARY)
			req_lbl.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_SM)
			req_row.add_child(req_lbl)
			_detail_content.add_child(req_row)
 
	# Coste de entrenamiento — preparado para futuro
	var training_cost: Dictionary = _vm.training_cost
	if not training_cost.is_empty():
		_add_section_header(tr("SKILL_TREE_SECTION_COST"))
		for cost_key in training_cost.keys():
			var cost_lbl := Label.new()
			cost_lbl.text = "%s: %s" % [tr(cost_key), str(training_cost[cost_key])]
			cost_lbl.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_SM)
			_detail_content.add_child(cost_lbl)
 
	# Botón entrenar — nodo fijo, solo actualizar estado
	var can_train: bool = is_unlocked \
		and skill.get("has_progression", false) \
		and skill.get("prereqs_met", false)
	_train_btn.disabled = not can_train
	_train_btn.text = tr("SKILL_TREE_BTN_TRAIN") if can_train else tr("SKILL_TREE_BTN_LOCKED")
 

func _render_comparison() -> void:
	if not _vm.comparison_mode:
		return

	for child in _comparison_grid.get_children():
		child.queue_free()

	var entities: Array = _vm.available_entities
	_comparison_grid.columns = 1 + entities.size()

	# Cabecera vacía
	_comparison_grid.add_child(Label.new())

	for entry in entities:
		var header_lbl := Label.new()
		header_lbl.text = tr(entry.get("display_name", entry.get("entity_id", "")))
		header_lbl.add_theme_color_override("font_color", UITokens.TEXT_GOLD)
		header_lbl.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_SM)
		header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_comparison_grid.add_child(header_lbl)

	var last_sub: String = ""

	for row_data in _vm.comparison_data:
		var sub: String = row_data.get("subcategory", "")

		if sub != last_sub:
			last_sub = sub
			var sub_lbl := Label.new()
			sub_lbl.text = tr("SKILL_SUBCATEGORY_%s" % sub)
			sub_lbl.add_theme_color_override("font_color", UITokens.TEXT_MUTED)
			sub_lbl.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_XS)
			_comparison_grid.add_child(sub_lbl)
			for _i in entities.size():
				_comparison_grid.add_child(Label.new())

		var name_lbl := Label.new()
		name_lbl.text = tr(row_data.get("name_key", row_data.get("skill_id", "")))
		name_lbl.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_SM)
		_comparison_grid.add_child(name_lbl)

		for entry in entities:
			var eid: String = entry.get("entity_id", "")
			var entity_data: Dictionary = row_data.get("entities", {}).get(eid, {})
			_comparison_grid.add_child(_make_comparison_cell(entity_data))


# ============================================
# CONSTRUCTORES DE NODOS
# ============================================

func _make_skill_card(skill_data: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(110, 0)

	# Estado → tokens Athelia via make_stylebox()
	var is_unlocked: bool = skill_data.get("is_unlocked", false)
	var is_selected: bool = skill_data.get("skill_id", "") == _vm.selected_skill.get("skill_id", "___")
	var is_trainable: bool = skill_data.get("is_trainable", false)
	var has_ai: bool = skill_data.get("has_ai_suggestion", false)

	var bg: Color
	var border: Color

	if not is_unlocked:
		bg = UITokens.BG_SURFACE
		border = UITokens.BORDER_SUBTLE
		card.modulate.a = UITokens.DISABLED_ALPHA
	elif is_selected:
		bg = UITokens.BG_SELECTED
		border = UITokens.BORDER_ACCENT
	elif has_ai:
		bg = UITokens.BG_SURFACE
		border = UITokens.ACCENT_AMBER_B
	elif is_trainable:
		bg = UITokens.BG_SURFACE
		border = UITokens.ACCENT_GREEN_B
	else:
		bg = UITokens.BG_SURFACE
		border = UITokens.BORDER_DEFAULT

	card.add_theme_stylebox_override("panel",
		UITokens.make_stylebox(bg, border, UITokens.BORDER_WIDTH, UITokens.RADIUS_CARD, UITokens.SPACE_SM))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UITokens.SPACE_XS)

	# Badge IA
	if has_ai and is_unlocked:
		var badge := Label.new()
		badge.text = tr("SKILL_TREE_AI_BADGE")
		badge.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_XS)
		badge.add_theme_color_override("font_color", UITokens.ACCENT_AMBER)
		vbox.add_child(badge)

	# Nombre
	var name_lbl := Label.new()
	name_lbl.text = tr(skill_data.get("name_key", skill_data.get("skill_id", "")))
	name_lbl.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_SM)
	name_lbl.add_theme_color_override("font_color",
		UITokens.TEXT_PRIMARY if is_unlocked else UITokens.TEXT_MUTED)
	vbox.add_child(name_lbl)

	# Barra de progreso
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = skill_data.get("current_value", 0) if is_unlocked else 0
	bar.custom_minimum_size = Vector2(0, 3)
	bar.show_percentage = false
	vbox.add_child(bar)

	# Porcentaje
	var pct_lbl := Label.new()
	pct_lbl.text = "%d%%" % skill_data.get("current_value", 0) if is_unlocked else "—"
	pct_lbl.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_XS)
	pct_lbl.add_theme_color_override("font_color", UITokens.TEXT_MUTED)
	vbox.add_child(pct_lbl)

	card.add_child(vbox)

	# Input — solo en skills desbloqueadas
	if is_unlocked:
		var skill_id: String = skill_data.get("skill_id", "")
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton \
					and event.pressed \
					and event.button_index == MOUSE_BUTTON_LEFT:
				_vm.request_select_skill(skill_id)
		)

	return card


func _make_comparison_cell(entity_data: Dictionary) -> Control:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", UITokens.SPACE_XS)

	if not entity_data.get("is_unlocked", false):
		var lock_lbl := Label.new()
		lock_lbl.text = "—"
		lock_lbl.add_theme_color_override("font_color", UITokens.TEXT_MUTED)
		lock_lbl.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_SM)
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		container.add_child(lock_lbl)
		return container

	var pct_lbl := Label.new()
	pct_lbl.text = "%d%%" % entity_data.get("current_value", 0)
	pct_lbl.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_SM)
	pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if entity_data.get("has_ai_suggestion", false):
		pct_lbl.add_theme_color_override("font_color", UITokens.ACCENT_AMBER)
	elif entity_data.get("is_trainable", false):
		pct_lbl.add_theme_color_override("font_color", UITokens.ACCENT_GREEN)
	else:
		pct_lbl.add_theme_color_override("font_color", UITokens.TEXT_PRIMARY)

	container.add_child(pct_lbl)

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = entity_data.get("current_value", 0)
	bar.custom_minimum_size = Vector2(60, 3)
	bar.show_percentage = false
	container.add_child(bar)

	return container

## Vacía únicamente DetailContent — nunca toca nodos fijos del .tscn.
## Usa free() inmediato en lugar de queue_free() para evitar referencias
## colgantes dentro del mismo frame.
func _clear_dynamic_detail() -> void:
	for child in _detail_content.get_children():
		child.free()
  
## Añade un Label de cabecera de sección al DetailPanel.
func _add_section_header(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_XS)
	lbl.add_theme_color_override("font_color", UITokens.TEXT_MUTED)
	_detail_content.add_child(lbl)
 
 
## Construye una fila de efecto para el panel lateral.
## effect: Dictionary con type, value, base_damage_attribute, max_targets...
func _make_effect_row(effect: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITokens.SPACE_SM)
 
	# Fondo de tarjeta de efecto
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		UITokens.make_stylebox(
			UITokens.BG_SURFACE,
			UITokens.BORDER_DEFAULT,
			UITokens.BORDER_WIDTH,
			UITokens.RADIUS_CARD,
			UITokens.SPACE_XS
		)
	)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", UITokens.SPACE_SM)
 
	# Tipo de efecto → icono y texto
	var effect_type: String = effect.get("type", "")
	var type_lbl := Label.new()
	type_lbl.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_SM)
	type_lbl.add_theme_color_override("font_color", UITokens.TEXT_SECONDARY)
 
	match effect_type:
		"DAMAGE":
			type_lbl.text = tr("SKILL_EFFECT_DAMAGE")
		"HEAL":
			type_lbl.text = tr("SKILL_EFFECT_HEAL")
		"BUFF":
			type_lbl.text = tr("SKILL_EFFECT_BUFF")
		"DEBUFF":
			type_lbl.text = tr("SKILL_EFFECT_DEBUFF")
		_:
			type_lbl.text = effect_type
 
	inner.add_child(type_lbl)
 
	# max_targets si está definido y > 1
	var max_targets: int = effect.get("max_targets", 1)
	if max_targets > 1:
		var targets_lbl := Label.new()
		targets_lbl.text = "(%d)" % max_targets
		targets_lbl.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_XS)
		targets_lbl.add_theme_color_override("font_color", UITokens.TEXT_MUTED)
		inner.add_child(targets_lbl)
 
	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(spacer)
 
	# Valor multiplicador — alineado a la derecha
	var value: float = effect.get("value", 0.0)
	var val_lbl := Label.new()
	val_lbl.text = "×%.1f" % value
	val_lbl.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_SM)
	val_lbl.add_theme_color_override("font_color", UITokens.TEXT_GOLD)
	inner.add_child(val_lbl)
 
	panel.add_child(inner)
	row.add_child(panel)
	return row
 
 
## Construye el grid de metadatos de uso (target, range, cooldown, coste stamina).
func _make_meta_grid(skill: Dictionary) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UITokens.SPACE_SM)
	grid.add_theme_constant_override("v_separation", UITokens.SPACE_XS)
 
	var mode: String = skill.get("mode", "")
 
	# Target type — solo en combate
	if mode == "COMBAT":
		_add_meta_cell(grid, tr("SKILL_META_TARGET"),
			_localize_target_type(skill.get("target_type", "")))
		_add_meta_cell(grid, tr("SKILL_META_RANGE"),
			_localize_range_type(skill.get("range_type", "")))
		var cooldown: float = skill.get("base_cooldown", 0.0)
		if cooldown > 0.0:
			_add_meta_cell(grid, tr("SKILL_META_COOLDOWN"), "%.1fs" % cooldown)
 
	# Coste de stamina (combate y exploración)
	var costs: Dictionary = skill.get("costs", {})
	for resource_id in costs.keys():
		var amount: float = costs[resource_id]
		_add_meta_cell(grid,
			tr("SKILL_META_COST_%s" % resource_id.to_upper()),
			"%d %s" % [int(amount), tr(resource_id)],
			UITokens.ACCENT_AMBER
		)
 
	# Atributos que influyen
	var weights: Dictionary = skill.get("attribute_weights", {})
	if not weights.is_empty():
		var attr_abbrs: Array = []
		for attr_id in weights.keys():
			attr_abbrs.append(tr("ATTR_ABBR_%s" % attr_id.to_upper()))
		_add_meta_cell(grid, tr("SKILL_META_ATTRIBUTES"), " · ".join(attr_abbrs))
 
	return grid
 
 
func _add_meta_cell(
	grid: GridContainer,
	label_text: String,
	value_text: String,
	value_color: Color = UITokens.TEXT_SECONDARY
) -> void:
	var label_lbl := Label.new()
	label_lbl.text = label_text
	label_lbl.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_XS)
	label_lbl.add_theme_color_override("font_color", UITokens.TEXT_MUTED)
	grid.add_child(label_lbl)
 
	var value_lbl := Label.new()
	value_lbl.text = value_text
	value_lbl.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_SM)
	value_lbl.add_theme_color_override("font_color", value_color)
	grid.add_child(value_lbl)
 
 
func _localize_target_type(target_type: String) -> String:
	match target_type:
		"SELF":         return tr("SKILL_TARGET_SELF")
		"SINGLE_ENEMY": return tr("SKILL_TARGET_SINGLE")
		"MULTI_ENEMY":  return tr("SKILL_TARGET_MULTI")
		"AREA":         return tr("SKILL_TARGET_AREA")
		_:              return target_type
 
 
func _localize_range_type(range_type: String) -> String:
	match range_type:
		"MELEE":  return tr("SKILL_RANGE_MELEE")
		"SHORT":  return tr("SKILL_RANGE_SHORT")
		"MEDIUM": return tr("SKILL_RANGE_MEDIUM")
		"LONG":   return tr("SKILL_RANGE_LONG")
		_:        return range_type
 
# ============================================
# ESTILOS DE PANEL — via UITokens, sin StyleBoxFlat.new() directo
# ============================================

func _apply_panel_styles() -> void:
	# Header — fondo BG_PANEL con borde inferior BORDER_PANEL
	var header_node: Node = get_node_or_null("%Header")
	if header_node:
		_add_bg_rect(header_node, UITokens.BG_PANEL)
		_add_border_rect(header_node, UITokens.BORDER_PANEL, false, true, false, false)

	# TabBar — fondo BG_PANEL con borde inferior
	if _tab_bar:
		_add_bg_rect(_tab_bar, UITokens.BG_PANEL)
		_add_border_rect(_tab_bar, UITokens.BORDER_PANEL, false, true, false, false)

	# FilterBar — fondo BG_SURFACE con borde inferior sutil
	if _filter_bar:
		_add_bg_rect(_filter_bar, UITokens.BG_SURFACE)
		_add_border_rect(_filter_bar, UITokens.BORDER_SUBTLE, false, true, false, false)

	# DetailPanel — fondo BG_PANEL con borde izquierdo BORDER_PANEL
	if _detail_panel:
		_add_bg_rect(_detail_panel, UITokens.BG_PANEL)
		_add_border_rect(_detail_panel, UITokens.BORDER_PANEL, false, false, false, true)


## Inserta un ColorRect de fondo como primer hijo del contenedor.
## z_index = -1 asegura que queda detrás del contenido.
func _add_bg_rect(parent: Node, color: Color) -> void:
	var bg := ColorRect.new()
	bg.color = color
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.z_index = -1
	parent.add_child(bg)
	parent.move_child(bg, 0)


## Inserta un ColorRect de 1px como borde en el lado especificado.
func _add_border_rect(
	parent: Node,
	color: Color,
	top: bool, bottom: bool, right: bool, left: bool
) -> void:
	var border := ColorRect.new()
	border.color = color
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.z_index = 1

	if bottom:
		border.set_anchor_and_offset(SIDE_LEFT,   0, 0)
		border.set_anchor_and_offset(SIDE_RIGHT,  1, 0)
		border.set_anchor_and_offset(SIDE_TOP,    1, -1)
		border.set_anchor_and_offset(SIDE_BOTTOM, 1, 0)
	elif top:
		border.set_anchor_and_offset(SIDE_LEFT,   0, 0)
		border.set_anchor_and_offset(SIDE_RIGHT,  1, 0)
		border.set_anchor_and_offset(SIDE_TOP,    0, 0)
		border.set_anchor_and_offset(SIDE_BOTTOM, 0, 1)
	elif left:
		border.set_anchor_and_offset(SIDE_LEFT,   0, 0)
		border.set_anchor_and_offset(SIDE_RIGHT,  0, 1)
		border.set_anchor_and_offset(SIDE_TOP,    0, 0)
		border.set_anchor_and_offset(SIDE_BOTTOM, 1, 0)
	elif right:
		border.set_anchor_and_offset(SIDE_LEFT,   1, -1)
		border.set_anchor_and_offset(SIDE_RIGHT,  1, 0)
		border.set_anchor_and_offset(SIDE_TOP,    0, 0)
		border.set_anchor_and_offset(SIDE_BOTTOM, 1, 0)

	parent.add_child(border)


# ============================================
# HANDLERS DE INPUT
# ============================================

func _on_train_pressed() -> void:
	var error: String = _vm.request_train_selected_skill()
	if not error.is_empty():
		_show_feedback(tr(error), true)
	else:
		_show_feedback(tr("SKILL_TREE_TRAIN_OK"), false)


# ============================================
# FEEDBACK TEMPORAL
# ============================================

func _show_feedback(message: String, is_error: bool) -> void:
	_feedback_label.text = message
	_feedback_label.visible = true
	_feedback_label.add_theme_color_override("font_color",
		UITokens.ACCENT_DANGER if is_error else UITokens.ACCENT_GREEN)

	if _feedback_timer and is_instance_valid(_feedback_timer):
		_feedback_timer.timeout.disconnect(_hide_feedback)

	_feedback_timer = get_tree().create_timer(3.0)
	_feedback_timer.timeout.connect(_hide_feedback)


func _hide_feedback() -> void:
	if _feedback_label:
		_feedback_label.visible = false
