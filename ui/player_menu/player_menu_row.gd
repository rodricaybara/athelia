class_name PlayerMenuRow
extends VBoxContainer

## PlayerMenuRow — fila del menú del jugador (Spike 22)
##
## Componente de pantalla (no del Design System), solo script, mismo
## criterio que SkillCard: se crea con PlayerMenuRow.create(kind).
## Construye sus nodos por dentro, de modo que la View no necesita
## Label.new() ni ColorRect.new().
##
## Tipos de fila:
##   TEXT     → nombre a la izquierda, valor a la derecha (atributos, oro)
##   BUFF     → como TEXT, con una barra fina debajo (tiempo restante)
##   RESOURCE → nombre, UIResourceBar de 14 px y «actual / máx» a la derecha
##
## Todas las actualizaciones son en sitio: no se crean nodos al repintar.
## No accede a ningún sistema de juego: solo recibe valores ya calculados.


enum Kind { TEXT, BUFF, RESOURCE }

const RESOURCE_BAR_SCENE: PackedScene = preload("res://ui/design_system/components/ui_resource_bar/ui_resource_bar.tscn")
const RESOURCE_NAME_WIDTH: int = 96
const RESOURCE_VALUE_WIDTH: int = 88
const THIN_BAR_HEIGHT: int = 4

var _kind: Kind = Kind.TEXT
var _resource_type: String = "health"
var _built: bool = false

var _name_label: Label = null
var _value_label: Label = null
var _bar: UIResourceBar = null
var _thin_fill: ColorRect = null


# ============================================
# CREACIÓN
# ============================================

static func create(kind: Kind = Kind.TEXT, resource_type: String = "health") -> PlayerMenuRow:
	var row := PlayerMenuRow.new()
	row._kind = kind
	row._resource_type = resource_type
	row._build()
	return row


func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true

	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# PASS: la fila recibe el ratón (tooltip) sin bloquear la rueda del ScrollContainer
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_constant_override("separation", UITokens.SPACE_XS)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", UITokens.SPACE_MD)
	add_child(line)

	_name_label = Label.new()
	_style_label(_name_label, UITokens.COLOR_TEXT_MUTED)
	line.add_child(_name_label)

	_value_label = Label.new()
	_style_label(_value_label, UITokens.COLOR_TEXT)
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Un Label con elipsis junto a otro expansivo se colapsa (lección del Spike 21)
	_value_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING

	if _kind == Kind.RESOURCE:
		_name_label.custom_minimum_size.x = RESOURCE_NAME_WIDTH
		_bar = RESOURCE_BAR_SCENE.instantiate() as UIResourceBar
		_bar.resource_type = _resource_type
		_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(_bar)
		_value_label.custom_minimum_size.x = RESOURCE_VALUE_WIDTH
		line.add_child(_value_label)
	else:
		_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(_value_label)

	if _kind == Kind.BUFF:
		var track := ColorRect.new()
		track.color = UITokens.BORDER_DEFAULT
		track.custom_minimum_size.y = THIN_BAR_HEIGHT
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_thin_fill = ColorRect.new()
		_thin_fill.color = UITokens.COLOR_ACCENT
		_thin_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.add_child(_thin_fill)
		_thin_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_thin_fill.anchor_right = 0.0
		add_child(track)


func _style_label(label: Label, color: Color) -> void:
	label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_MD)
	label.add_theme_color_override("font_color", color)


# ============================================
# API PÚBLICA (todo en sitio)
# ============================================

func set_name_text(text: String) -> void:
	_name_label.text = text


func set_value_text(text: String) -> void:
	_value_label.text = text


func set_value_color(color: Color) -> void:
	_value_label.add_theme_color_override("font_color", color)


## Tooltip de toda la fila ("" = sin tooltip).
func set_tooltip(text: String) -> void:
	tooltip_text = text


## Solo filas RESOURCE: barra y texto «actual / máx».
func set_resource(current: int, max_value: int) -> void:
	if _bar != null:
		_bar.set_values(current, max_value)
	_value_label.text = "%d / %d" % [current, max_value]


## Solo filas BUFF: la barra fina se vacía al agotarse el tiempo.
func set_bar(current: float, max_value: float) -> void:
	if _thin_fill == null:
		return
	_thin_fill.anchor_right = clampf(current / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0
