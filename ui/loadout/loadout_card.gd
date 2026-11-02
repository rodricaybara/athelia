class_name LoadoutCard
extends PanelContainer

## LoadoutCard — ficha de Loadout (componente local de ui/loadout/)
##
## Dos usos:
##   STACKED → ficha de slot: arriba etiqueta del slot (izq.) y tecla (der.),
##             abajo el nombre de la skill o "Vacío".
##   INLINE  → fila de la lista de disponibles: nombre (izq.) y detalle (der.).
##
## Contrato:
##   - Nunca accede a sistemas core: solo recibe textos ya traducidos.
##   - `data` es un payload opaco que la View guarda y recupera en las señales.
##   - `pressed` se emite al SOLTAR el botón dentro de la ficha (mismo criterio
##     que UISlot), nunca al pulsar.
##   - Estados por stylebox con tokens; nada de modulate.


signal pressed(card: LoadoutCard)
signal hover_changed(card: LoadoutCard, inside: bool)

enum Layout { STACKED, INLINE }

const HEIGHT_STACKED: int = 54
const HEIGHT_INLINE: int = 40

## Payload opaco de la View (el componente no lo interpreta).
var data: Variant = null

## false = no emite `pressed` y no reacciona al hover visualmente.
var interactive: bool = true:
	set(value):
		interactive = value
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW
		_apply_style()

var _layout: Layout = Layout.STACKED
var _selected: bool = false
var _marked: bool = false
var _empty: bool = false
var _hovered: bool = false
var _pressed: bool = false

var _lead: Label = null
var _title: Label = null
var _trail: Label = null


func _init(p_layout: Layout = Layout.STACKED) -> void:
	_layout = p_layout
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	_title = _make_label(UITokens.FONT_SIZE_MD)
	_trail = _make_label(UITokens.FONT_SIZE_SM)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", UITokens.SPACE_XS)
	add_child(box)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UITokens.SPACE_SM)
	box.add_child(row)

	if _layout == Layout.STACKED:
		_lead = _make_label(UITokens.FONT_SIZE_SM)
		_lead.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(_lead)
		row.add_child(_trail)
		box.add_child(_title)
		custom_minimum_size.y = HEIGHT_STACKED
	else:
		_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(_title)
		row.add_child(_trail)
		custom_minimum_size.y = HEIGHT_INLINE

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_apply_style()


# ============================================================
# API PÚBLICA
# ============================================================

## Textos ya traducidos. `lead_text` solo se usa en STACKED.
func setup(lead_text: String, title_text: String, trail_text: String) -> void:
	if _lead != null:
		_lead.text = lead_text
	_title.text = title_text
	_trail.text = trail_text
	_trail.visible = trail_text != ""


func set_selected(value: bool) -> void:
	_selected = value
	_apply_style()


## "Asignada aquí": la entrada ya está en el slot elegido.
func set_marked(value: bool) -> void:
	_marked = value
	_apply_style()


## Slot vacío (o acción fija): fondo y texto atenuados por token.
func set_empty(value: bool) -> void:
	_empty = value
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
	if _title == null:
		return

	var bg: Color = UITokens.COLOR_SLOT_OCCUPIED
	var border: Color = UITokens.COLOR_SLOT_OCCUPIED_BORDER
	var width: int = UITokens.BORDER_WIDTH

	if _empty:
		bg = UITokens.COLOR_SLOT_EMPTY
		border = UITokens.COLOR_SLOT_EMPTY_BORDER
	if _marked:
		bg = UITokens.COLOR_SLOT_EQUIPPED
		border = UITokens.COLOR_SLOT_EQUIPPED_BORDER
		width = UITokens.BORDER_WIDTH_FOCUS
	if _selected:
		bg = UITokens.COLOR_SLOT_SELECTED
		border = UITokens.COLOR_SLOT_SELECTED_BORDER
		width = UITokens.BORDER_WIDTH_FOCUS
	elif _hovered and interactive:
		bg = UITokens.COLOR_SLOT_HOVER
		border = UITokens.COLOR_SLOT_HOVER_BORDER

	add_theme_stylebox_override("panel", UITokens.make_stylebox(
		bg, border, width, UITokens.BORDER_RADIUS_SM, UITokens.SPACE_SM))

	var title_color: Color = UITokens.TEXT_MUTED if _empty else UITokens.TEXT_PRIMARY
	_title.add_theme_color_override("font_color", title_color)
	_trail.add_theme_color_override("font_color", UITokens.TEXT_MUTED)
	if _lead != null:
		_lead.add_theme_color_override("font_color", UITokens.TEXT_MUTED)


# ============================================================
# INPUT
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
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
	hover_changed.emit(self, true)


func _on_mouse_exited() -> void:
	_hovered = false
	_pressed = false
	_apply_style()
	hover_changed.emit(self, false)
