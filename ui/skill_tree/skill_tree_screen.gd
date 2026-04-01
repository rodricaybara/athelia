class_name SkillTreeScreen
extends CanvasLayer

## SkillTreeScreen - View del árbol de habilidades
## Patrón MVVM — ver athelia_ui_architecture.md
##
## RESPONSABILIDAD:
##   Renderizar el estado que expone SkillTreeViewModel.
##   Traducir input del jugador en llamadas al ViewModel.
##   No accede a ningún sistema core directamente.
##
## ESTRUCTURA DEL .tscn (ver comentario al final del fichero):
##   SkillTreeScreen (CanvasLayer)
##   └── Root (Control, full rect)
##       ├── Header (HBoxContainer)
##       │   ├── EntitySelector (HBoxContainer)
##       │   └── ModeToggleBtn (Button)
##       ├── TabBar (HBoxContainer)
##       ├── FilterBar (HBoxContainer)
##       ├── MainContainer (HBoxContainer)
##       │   ├── SkillArea (ScrollContainer)
##       │   │   └── SkillGrid (VBoxContainer)  ← tiers generados por código
##       │   └── DetailPanel (VBoxContainer)
##       │       ├── DetailName (Label)
##       │       ├── DetailPct (Label)
##       │       ├── DetailPctLabel (Label)
##       │       ├── ReqsSection (Label)  ← header sección
##       │       ├── ReqsList (VBoxContainer)
##       │       ├── LastTrainSection (Label)
##       │       ├── LastTrainLabel (Label)
##       │       ├── CostSection (VBoxContainer)  ← oculto si training_cost vacío
##       │       │   ├── CostHeader (Label)
##       │       │   └── CostList (VBoxContainer)
##       │       └── TrainBtn (Button)
##       └── ComparisonContainer (ScrollContainer)  ← visible solo en modo comparativa
##           └── ComparisonGrid (GridContainer)  ← generado por código


# ============================================
# NODOS — @onready
# ============================================

@onready var _entity_selector: HBoxContainer   = %EntitySelector
@onready var _mode_toggle_btn: Button          = %ModeToggleBtn
@onready var _tab_bar: HBoxContainer           = %TabBar
@onready var _filter_bar: HBoxContainer        = %FilterBar
@onready var _main_container: HBoxContainer    = %MainContainer
@onready var _skill_area: ScrollContainer      = %SkillArea
@onready var _skill_grid: VBoxContainer        = %SkillGrid
@onready var _detail_panel: VBoxContainer      = %DetailPanel
@onready var _detail_name: Label               = %DetailName
@onready var _detail_pct: Label                = %DetailPct
@onready var _reqs_list: VBoxContainer         = %ReqsList
@onready var _last_train_label: Label          = %LastTrainLabel
@onready var _cost_section: VBoxContainer      = %CostSection
@onready var _cost_list: VBoxContainer         = %CostList
@onready var _train_btn: Button                = %TrainBtn
@onready var _comparison_container: ScrollContainer = %ComparisonContainer
@onready var _comparison_grid: GridContainer   = %ComparisonGrid
@onready var _feedback_label: Label            = %FeedbackLabel


# ============================================
# VIEWMODEL
# ============================================

var _vm: SkillTreeViewModel = null


# ============================================
# ESTADO INTERNO DE LA VIEW
# ============================================

var _feedback_timer: SceneTreeTimer = null
var _entity_buttons: Array[Button] = []
var _tab_buttons: Array[Button] = []
var _filter_buttons: Array[Button] = []


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	visible = false
 
	_vm = SkillTreeViewModel.new()
	_vm.name = "ViewModel"
	add_child(_vm)
	_vm.changed.connect(_on_vm_changed)
 
	_mode_toggle_btn.pressed.connect(func(): _vm.request_toggle_comparison_mode())
	_train_btn.pressed.connect(_on_train_pressed)
 
	# Aplicar estilos de fondo por código — los VBoxContainer/HBoxContainer
	# no tienen panel por defecto, hay que asignarlo via theme_override.
	_apply_panel_styles()


# ============================================
# API PÚBLICA — llamada desde SceneOrchestrator
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
	# Limpiar botones anteriores
	for btn in _entity_buttons:
		btn.queue_free()
	_entity_buttons.clear()

	for entry in _vm.available_entities:
		var entity_id: String = entry.get("entity_id", "")
		var display_key: String = entry.get("display_name", entity_id)

		var btn := Button.new()
		btn.text = tr(display_key)
		btn.toggle_mode = false

		if entity_id == _vm.selected_entity_id:
			btn.add_theme_stylebox_override("normal", _make_entity_btn_active_style())
		else:
			btn.add_theme_stylebox_override("normal", _make_entity_btn_style())

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
		var btn := Button.new()
		btn.text = tr("SKILL_SUBCATEGORY_%s" % subcategory)

		if subcategory == _vm.active_subcategory:
			btn.add_theme_stylebox_override("normal", _make_tab_active_style())
		else:
			btn.add_theme_stylebox_override("normal", _make_tab_style())

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
		var btn := Button.new()
		btn.text = tr(filter_data["key"])
		var fmode: SkillTreeViewModel.FilterMode = filter_data["mode"]

		if fmode == _vm.active_filter:
			btn.add_theme_stylebox_override("normal", _make_filter_active_style())
		else:
			btn.add_theme_stylebox_override("normal", _make_filter_style())

		btn.pressed.connect(func(): _vm.request_set_filter(fmode))
		_filter_bar.add_child(btn)
		_filter_buttons.append(btn)


func _render_skills() -> void:
	# Limpiar grid anterior
	for child in _skill_grid.get_children():
		child.queue_free()

	if _vm.comparison_mode:
		return

	var skills_by_tier: Dictionary = _vm.get_skills_by_tier()
	if skills_by_tier.is_empty():
		var empty_label := Label.new()
		empty_label.text = tr("SKILL_TREE_NO_SKILLS")
		_skill_grid.add_child(empty_label)
		return

	var tiers: Array = skills_by_tier.keys()
	tiers.sort()

	for i in tiers.size():
		var tier: int = tiers[i]
		var tier_skills: Array = skills_by_tier[tier]

		# Separador de tier (salvo el primero)
		if i > 0:
			var sep := HSeparator.new()
			sep.add_theme_stylebox_override("separator", _make_separator_style())
			_skill_grid.add_child(sep)

		# Fila del tier
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		# Etiqueta de tier
		var tier_label := Label.new()
		tier_label.text = "T%d" % tier
		tier_label.custom_minimum_size = Vector2(36, 0)
		tier_label.add_theme_color_override("font_color", UITokens.TEXT_MUTED)
		tier_label.add_theme_font_size_override("font_size", 10)
		row.add_child(tier_label)

		# Cards de skills
		var cards_container := HBoxContainer.new()
		cards_container.add_theme_constant_override("separation", 6)
		for skill_data in tier_skills:
			var card := _make_skill_card(skill_data)
			cards_container.add_child(card)

		row.add_child(cards_container)
		_skill_grid.add_child(row)


func _render_detail() -> void:
	if _vm.selected_skill.is_empty():
		_detail_name.text = tr("SKILL_TREE_SELECT_HINT")
		_detail_pct.text = "—"
		_reqs_list.visible = false
		_cost_section.visible = false
		_train_btn.disabled = true
		return

	var skill: Dictionary = _vm.selected_skill
	_detail_name.text = tr(skill.get("name_key", skill.get("skill_id", "")))

	var is_unlocked: bool = skill.get("is_unlocked", false)
	_detail_pct.text = "%d%%" % skill.get("current_value", 0) if is_unlocked else "—"

	# Requisitos
	_reqs_list.visible = true
	for child in _reqs_list.get_children():
		child.queue_free()

	var prereqs: Dictionary = skill.get("prerequisite_requirements", {})
	if prereqs.is_empty():
		var lbl := Label.new()
		lbl.text = tr("SKILL_TREE_NO_PREREQS")
		lbl.add_theme_color_override("font_color", UITokens.TEXT_MUTED)
		lbl.add_theme_font_size_override("font_size", 12)
		_reqs_list.add_child(lbl)
	else:
		var missing: Array = skill.get("missing_prereqs", [])
		for prereq_id in prereqs.keys():
			var threshold: int = prereqs[prereq_id]
			var is_met: bool = prereq_id not in missing

			var req_row := HBoxContainer.new()
			req_row.add_theme_constant_override("separation", 6)

			var icon_lbl := Label.new()
			icon_lbl.text = "✓" if is_met else "✗"
			icon_lbl.add_theme_color_override("font_color",
				UITokens.ACCENT_GREEN if is_met else UITokens.ACCENT_DANGER)
			icon_lbl.add_theme_font_size_override("font_size", 10)
			req_row.add_child(icon_lbl)

			var req_lbl := Label.new()
			req_lbl.text = "%s ≥ %d%%" % [tr(prereq_id), threshold] if threshold > 0 else tr(prereq_id)
			req_lbl.add_theme_color_override("font_color", UITokens.TEXT_SECONDARY)
			req_lbl.add_theme_font_size_override("font_size", 12)
			req_row.add_child(req_lbl)

			_reqs_list.add_child(req_row)

	# Coste de entrenamiento — oculto si vacío
	var cost: Dictionary = _vm.training_cost
	_cost_section.visible = not cost.is_empty()
	if not cost.is_empty():
		for child in _cost_list.get_children():
			child.queue_free()
		for cost_key in cost.keys():
			var cost_lbl := Label.new()
			cost_lbl.text = "%s: %s" % [tr(cost_key), str(cost[cost_key])]
			cost_lbl.add_theme_font_size_override("font_size", 12)
			_cost_list.add_child(cost_lbl)

	# Botón entrenar
	var can_train: bool = is_unlocked and skill.get("has_progression", false) and skill.get("prereqs_met", false)
	_train_btn.disabled = not can_train
	_train_btn.text = tr("SKILL_TREE_BTN_TRAIN") if can_train else tr("SKILL_TREE_BTN_LOCKED")


func _render_comparison() -> void:
	if not _vm.comparison_mode:
		return

	for child in _comparison_grid.get_children():
		child.queue_free()

	var entities: Array = _vm.available_entities
	# Columnas: nombre skill + una por entidad
	_comparison_grid.columns = 1 + entities.size()

	# Cabecera
	var header_empty := Label.new()
	header_empty.text = ""
	_comparison_grid.add_child(header_empty)

	for entry in entities:
		var header_lbl := Label.new()
		header_lbl.text = tr(entry.get("display_name", entry.get("entity_id", "")))
		header_lbl.add_theme_color_override("font_color", UITokens.TEXT_GOLD)
		header_lbl.add_theme_font_size_override("font_size", 12)
		header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_comparison_grid.add_child(header_lbl)

	# Separador de subcategoría previo
	var last_sub: String = ""

	for row_data in _vm.comparison_data:
		var sub: String = row_data.get("subcategory", "")

		# Cabecera de subcategoría cuando cambia
		if sub != last_sub:
			last_sub = sub
			var sub_lbl := Label.new()
			sub_lbl.text = tr("SKILL_SUBCATEGORY_%s" % sub)
			sub_lbl.add_theme_color_override("font_color", UITokens.TEXT_MUTED)
			sub_lbl.add_theme_font_size_override("font_size", 10)
			# Ocupar todas las columnas con un separator visual
			_comparison_grid.add_child(sub_lbl)
			for _i in entities.size():
				var spacer := Label.new()
				spacer.text = ""
				_comparison_grid.add_child(spacer)

		# Nombre de la skill
		var name_lbl := Label.new()
		name_lbl.text = tr(row_data.get("name_key", row_data.get("skill_id", "")))
		name_lbl.add_theme_font_size_override("font_size", 12)
		_comparison_grid.add_child(name_lbl)

		# Celda por entidad
		for entry in entities:
			var eid: String = entry.get("entity_id", "")
			var entity_data: Dictionary = row_data.get("entities", {}).get(eid, {})
			var cell := _make_comparison_cell(entity_data)
			_comparison_grid.add_child(cell)


# ============================================
# CONSTRUCTORES DE NODOS
# ============================================

func _make_skill_card(skill_data: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(110, 0)

	# Estilo según estado
	var style: StyleBoxFlat
	if not skill_data.get("is_unlocked", false):
		style = _make_card_style_locked()
		card.modulate.a = 0.4
	elif skill_data.get("skill_id", "") == _vm.selected_skill.get("skill_id", "___"):
		style = _make_card_style_selected()
	elif skill_data.get("has_ai_suggestion", false):
		style = _make_card_style_ai()
	elif skill_data.get("is_trainable", false):
		style = _make_card_style_trainable()
	else:
		style = _make_card_style_normal()

	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	# Badge IA si aplica
	if skill_data.get("has_ai_suggestion", false) and skill_data.get("is_unlocked", false):
		var badge := Label.new()
		badge.text = tr("SKILL_TREE_AI_BADGE")
		badge.add_theme_font_size_override("font_size", 9)
		badge.add_theme_color_override("font_color", UITokens.ACCENT_AMBER)
		vbox.add_child(badge)

	# Nombre
	var name_lbl := Label.new()
	name_lbl.text = tr(skill_data.get("name_key", skill_data.get("skill_id", "")))
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color",
		UITokens.TEXT_PRIMARY if skill_data.get("is_unlocked", false) else UITokens.TEXT_MUTED)
	vbox.add_child(name_lbl)

	# Barra de progreso
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = skill_data.get("current_value", 0) if skill_data.get("is_unlocked", false) else 0
	bar.custom_minimum_size = Vector2(0, 4)
	bar.show_percentage = false
	vbox.add_child(bar)

	# Porcentaje
	var pct_lbl := Label.new()
	pct_lbl.text = "%d%%" % skill_data.get("current_value", 0) if skill_data.get("is_unlocked", false) else "—"
	pct_lbl.add_theme_font_size_override("font_size", 11)
	pct_lbl.add_theme_color_override("font_color", UITokens.TEXT_MUTED)
	vbox.add_child(pct_lbl)

	card.add_child(vbox)

	# Icono de candado si bloqueada
	if not skill_data.get("is_unlocked", false):
		# El candado se renderiza como Label con símbolo unicode por ahora
		# Se puede reemplazar por TextureRect cuando haya assets
		var lock_lbl := Label.new()
		lock_lbl.text = "🔒"
		lock_lbl.add_theme_font_size_override("font_size", 10)
		lock_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		lock_lbl.position = Vector2(-18, 4)
		card.add_child(lock_lbl)

	# Input
	if skill_data.get("is_unlocked", false):
		var skill_id: String = skill_data.get("skill_id", "")
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_vm.request_select_skill(skill_id)
		)

	return card


func _make_comparison_cell(entity_data: Dictionary) -> Control:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	if not entity_data.get("is_unlocked", false):
		var lock_lbl := Label.new()
		lock_lbl.text = "—"
		lock_lbl.add_theme_color_override("font_color", UITokens.TEXT_MUTED)
		lock_lbl.add_theme_font_size_override("font_size", 12)
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		container.add_child(lock_lbl)
		return container

	# Porcentaje
	var pct_lbl := Label.new()
	pct_lbl.text = "%d%%" % entity_data.get("current_value", 0)
	pct_lbl.add_theme_font_size_override("font_size", 12)
	pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if entity_data.get("has_ai_suggestion", false):
		pct_lbl.add_theme_color_override("font_color", UITokens.ACCENT_AMBER)
	elif entity_data.get("is_trainable", false):
		pct_lbl.add_theme_color_override("font_color", UITokens.ACCENT_GREEN)
	else:
		pct_lbl.add_theme_color_override("font_color", UITokens.TEXT_PRIMARY)

	container.add_child(pct_lbl)

	# Mini barra
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = entity_data.get("current_value", 0)
	bar.custom_minimum_size = Vector2(60, 3)
	bar.show_percentage = false
	container.add_child(bar)

	return container


# ============================================
# HANDLERS DE INPUT
# ============================================

func _on_train_pressed() -> void:
	var error: String = _vm.request_train_selected_skill()
	if not error.is_empty():
		_show_feedback(tr(error), true)


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


# ============================================
# FÁBRICAS DE ESTILOS — tokens Athelia
# (reemplazar por UITokens.make_stylebox() cuando esté implementado)
# ============================================

func _make_card_style_normal() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#252118")
	s.border_color = Color("#3D3830")
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(8)
	return s

func _make_card_style_selected() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#332C24")
	s.border_color = Color("#8A7050")
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(8)
	return s

func _make_card_style_trainable() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#252118")
	s.border_color = Color("#5A7A3A")
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(8)
	return s

func _make_card_style_ai() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#252118")
	s.border_color = Color("#7A6020")
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(8)
	return s

func _make_card_style_locked() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#1E1B17")
	s.border_color = Color("#2A2620")
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(8)
	return s

func _make_entity_btn_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.border_color = Color("#3D3830")
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.set_content_margin_all(5)
	return s

func _make_entity_btn_active_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#3A3428")
	s.border_color = Color("#8A7050")
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.set_content_margin_all(5)
	return s

func _make_tab_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.border_color = Color(0, 0, 0, 0)
	s.set_border_width_all(0)
	s.border_width_bottom = 2
	s.border_color = Color(0, 0, 0, 0)
	s.set_content_margin_all(8)
	return s

func _make_tab_active_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.border_color = Color(0, 0, 0, 0)
	s.set_border_width_all(0)
	s.border_width_bottom = 2
	s.border_color = Color("#8A7050")
	s.set_content_margin_all(8)
	return s

func _make_filter_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.border_color = Color("#3D3830")
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.set_content_margin_all(4)
	return s

func _make_filter_active_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#3A3428")
	s.border_color = Color("#8A7050")
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.set_content_margin_all(4)
	return s

func _make_separator_style() -> StyleBoxLine:
	var s := StyleBoxLine.new()
	s.color = Color("#2A2620")
	s.thickness = 1
	return s

func _apply_panel_styles() -> void:
	# Header — fondo bg-panel con borde inferior
	var header_node: HBoxContainer = %Header
	if header_node:
		var header_style := StyleBoxFlat.new()
		header_style.bg_color = Color("#2E2A26")
		header_style.border_color = Color("#5C4E38")
		header_style.border_width_bottom = 1
		header_style.set_content_margin_all(0)
		# HBoxContainer no acepta "panel" — usar draw_bg via un ColorRect hijo
		# ya existe Background en Root, así que solo necesitamos el borde inferior.
		# Lo resolvemos con un separador visual explícito bajo el Header.
		# (Ver nota abajo)
 
	# DetailPanel — fondo bg-panel con borde izquierdo
	var detail: VBoxContainer = %DetailPanel
	if detail:
		# VBoxContainer tampoco acepta StyleBox directamente.
		# Solución: insertar un ColorRect como fondo del DetailPanel.
		var bg := ColorRect.new()
		bg.color = Color("#2E2A26")
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.z_index = -1
		# Añadir como primer hijo para que quede detrás del contenido
		detail.add_child(bg)
		detail.move_child(bg, 0)
 
		# Borde izquierdo — línea vertical como separador
		var border := ColorRect.new()
		border.color = Color("#5C4E38")
		border.custom_minimum_size = Vector2(1, 0)
		border.set_anchor_and_offset(SIDE_LEFT, 0, 0)
		border.set_anchor_and_offset(SIDE_RIGHT, 0, 1)
		border.set_anchor_and_offset(SIDE_TOP, 0, 0)
		border.set_anchor_and_offset(SIDE_BOTTOM, 1, 0)
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail.add_child(border)
		detail.move_child(border, 0)
 
	# TabBar — fondo bg-panel con borde inferior
	var tab_bar: HBoxContainer = %TabBar
	if tab_bar:
		var tab_bg := ColorRect.new()
		tab_bg.color = Color("#2E2A26")
		tab_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		tab_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tab_bg.z_index = -1
		tab_bar.add_child(tab_bg)
		tab_bar.move_child(tab_bg, 0)
 
	# FilterBar — fondo bg-surface
	var filter_bar_node: HBoxContainer = %FilterBar
	if filter_bar_node:
		var filter_bg := ColorRect.new()
		filter_bg.color = Color("#252118")
		filter_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		filter_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		filter_bg.z_index = -1
		filter_bar_node.add_child(filter_bg)
		filter_bar_node.move_child(filter_bg, 0)
