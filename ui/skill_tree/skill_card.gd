class_name SkillCard
extends PanelContainer

## SkillCard — ficha de habilidad del árbol de habilidades (componente local de ui/skill_tree/)
##
## Muestra nombre, porcentaje y una barra de progreso (UIResourceBar custom).
##
## Contrato:
##   - Nunca accede a sistemas core: solo recibe textos ya traducidos y valores.
##   - `data` es un payload opaco que la View guarda y recupera en la señal.
##   - `pressed` se emite al SOLTAR el botón dentro de la ficha (mismo criterio
##     que LoadoutCard / UISlot), nunca al pulsar.
##   - Estados por stylebox con tokens; nada de modulate.
##   - `setup()` se llama ANTES de añadir la ficha al árbol: los colores de la
##     barra se leen en el _ready() de UIResourceBar.
##
## Estados (de menor a mayor prioridad visual):
##   normal → mejorable (borde COLOR_SUCCESS) → bloqueada (apagada)
##   La selección y el hover se superponen al estado base.


signal pressed(card: SkillCard)

const BAR_SCENE: PackedScene = preload("res://ui/design_system/components/ui_resource_bar/ui_resource_bar.tscn")

const HEIGHT: int = 58
## UIResourceBar fija su altura mínima a RESOURCE_BAR_HEIGHT (14) en su _ready();
## aquí se rebaja a una barra fina, tras ese _ready (ver _ready de la ficha).
const BAR_HEIGHT: int = 6

## Payload opaco de la View (el componente no lo interpreta).
var data: Variant = null

var _locked: bool = false
var _trainable: bool = false
var _selected: bool = false
var _hovered: bool = false
var _pressed: bool = false

var _name_label: Label = null
var _pct_label: Label = null
var _bar: UIResourceBar = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size.y = HEIGHT

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", UITokens.SPACE_SM)
	add_child(box)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UITokens.SPACE_SM)
	box.add_child(row)

	_name_label = _make_label(UITokens.FONT_SIZE_MD)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_name_label)

	_pct_label = _make_label(UITokens.FONT_SIZE_MD)
	# Sin recorte: con OVERRUN_TRIM_ELLIPSIS su ancho mínimo es 0 y el nombre,
	# que se expande, lo dejaría sin sitio.
	_pct_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	row.add_child(_pct_label)

	_bar = BAR_SCENE.instantiate() as UIResourceBar
	_bar.resource_type = "custom"
	_bar.custom_bg_color = UITokens.COLOR_BG
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_bar)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_apply_style()


func _ready() -> void:
	# Los hijos ya hicieron su _ready(): UIResourceBar ya fijó 14 px de alto.
	_bar.custom_minimum_size.y = BAR_HEIGHT
	# Los nodos internos de la barra no deben comerse el clic de la ficha.
	_ignore_mouse(_bar)


# ============================================================
# API PÚBLICA
# ============================================================

## Textos ya traducidos. `value` es el porcentaje (0-100) de la barra.
func setup(name_text: String, pct_text: String, value: int, locked: bool,
		trainable: bool, tooltip: String) -> void:
	_name_label.text = name_text
	_pct_label.text = pct_text
	_locked = locked
	_trainable = trainable
	tooltip_text = tooltip
	_bar.custom_fill_color = UITokens.COLOR_SLOT_OCCUPIED_BORDER if locked else UITokens.COLOR_PRIMARY
	_bar.set_values(float(value), 100.0)
	_apply_style()


func set_selected(value: bool) -> void:
	_selected = value
	_apply_style()


# ============================================================
# ESTILO
# ============================================================

func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", UITokens.TEXT_PRIMARY)
	return label


func _apply_style() -> void:
	if _name_label == null:
		return

	var bg: Color = UITokens.COLOR_SLOT_OCCUPIED
	var border: Color = UITokens.COLOR_SLOT_OCCUPIED_BORDER
	var width: int = UITokens.BORDER_WIDTH

	if _trainable:
		border = UITokens.COLOR_SUCCESS
	if _locked:
		bg = UITokens.COLOR_SLOT_EMPTY
		border = UITokens.COLOR_SLOT_EMPTY_BORDER

	if _selected:
		bg = UITokens.COLOR_SLOT_SELECTED
		border = UITokens.COLOR_SLOT_SELECTED_BORDER
		width = UITokens.BORDER_WIDTH_FOCUS
	elif _hovered:
		bg = UITokens.COLOR_SLOT_HOVER
		border = UITokens.COLOR_SLOT_HOVER_BORDER

	add_theme_stylebox_override("panel", UITokens.make_stylebox(
		bg, border, width, UITokens.BORDER_RADIUS_SM, UITokens.SPACE_SM))

	var text_color: Color = UITokens.TEXT_MUTED if _locked else UITokens.TEXT_PRIMARY
	_name_label.add_theme_color_override("font_color", text_color)
	_pct_label.add_theme_color_override("font_color", UITokens.TEXT_MUTED)


func _ignore_mouse(node: Node) -> void:
	var control := node as Control
	if control != null:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


# ============================================================
# INPUT
# ============================================================

func _gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse_event.pressed:
		_pressed = true
		accept_event()
		return

	var was_pressed: bool = _pressed
	_pressed = false
	if was_pressed and Rect2(Vector2.ZERO, size).has_point(mouse_event.position):
		pressed.emit(self)
	accept_event()


func _on_mouse_entered() -> void:
	_hovered = true
	_apply_style()


func _on_mouse_exited() -> void:
	_hovered = false
	_pressed = false
	_apply_style()
