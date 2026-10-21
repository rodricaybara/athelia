extends PanelContainer
class_name UIPanel
## UIPanel - Contenedor base para todas las ventanas y paneles del juego
##
## Uso:
##   Instanciar ui_panel.tscn como raíz visual de cualquier pantalla.
##   Configurar padding y variant desde el inspector o por código.
##
## Variantes (docstring corregido en el Spike 15 contra los consumidores reales):
##   DEFAULT  → panel estándar: fondo COLOR_PANEL con borde. Lo usan Character
##              Creation (3 paneles), Dialogue, Narrative, los sub-paneles del
##              menú principal y la tienda (cabeceras y filas). Inventario, party
##              y menú del jugador NO usan UIPanel todavía.
##   POPUP    → panel pequeño flotante: fondo COLOR_PANEL_ALT, borde de foco,
##              padding 8. Sin consumidores hoy.
##   OVERLAY  → fondo OPACO (COLOR_BG oscurecido un 20 %, alfa 1,0), sin borde,
##              padding 24. Lo usa el panel principal de la tienda (con marco).
##
## Marco decorativo (Spike 9, ampliado en el Spike 15):
##   decorative_frame = true añade un marco ornamental (doble filete +
##   esquineras) dibujado POR ENCIMA del stylebox de fondo. Opt-in
##   explícito, false por defecto — ningún panel existente cambia de
##   aspecto sin activarlo a propósito por pantalla.
##
##   Al activarlo, el propio panel suprime su borde y su corner_radius
##   (pasan a 0): el marco los sustituye, evita duplicar líneas y evita
##   fondo redondeado bajo un marco de esquina viva.
##
##   Esquinera: si corner_texture no está asignada, se usa la esquinera por
##   defecto del Design System (UITokens.FRAME_CORNER_TEXTURE_PATH, 64x64).
##   Solo si tampoco se puede cargar esa, el marco se dibuja solo con los
##   filetes y se avisa UNA vez por warning (no bloquea, no rompe nada).
##
##   Padding con marco: cuando padding = -1 (valor por defecto), el padding
##   efectivo no baja de UITokens.FRAME_MIN_PADDING. Un padding explícito
##   (>= 0) nunca se modifica.
##
##   Activación en runtime: decorative_frame y corner_texture tienen setter;
##   cambiarlos con el nodo ya en el árbol reaplica el estilo y redibuja.


enum Variant { DEFAULT, POPUP, OVERLAY }

@export var variant: Variant = Variant.DEFAULT
@export var padding: int = -1  # -1 = usar default según variante

@export_group("Marco decorativo (Spike 9)")
@export var decorative_frame: bool = false:
	set(value):
		if decorative_frame == value:
			return
		decorative_frame = value
		_on_frame_config_changed()
@export var corner_texture: Texture2D:
	set(value):
		if corner_texture == value:
			return
		corner_texture = value
		_on_frame_config_changed()


## Esquinera que realmente se dibuja: corner_texture, o la por defecto del
## Design System, o null (solo filetes). Se resuelve fuera de _draw().
var _active_corner: Texture2D = null

## El aviso de "no hay esquinera por defecto" sale una sola vez por ejecución.
static var _warned_missing_default_corner: bool = false


func _ready() -> void:
	resized.connect(_on_resized)
	_refresh_frame()
	_apply_style()


func _apply_style() -> void:
	var effective_padding: int = _effective_padding()

	match variant:
		Variant.DEFAULT:
			add_theme_stylebox_override("panel", UITokens.make_stylebox(
				UITokens.COLOR_PANEL,
				UITokens.COLOR_BORDER,
				0 if decorative_frame else UITokens.BORDER_WIDTH,
				0 if decorative_frame else UITokens.BORDER_RADIUS_MD,
				effective_padding
			))

		Variant.POPUP:
			add_theme_stylebox_override("panel", UITokens.make_stylebox(
				UITokens.COLOR_PANEL_ALT,
				UITokens.COLOR_BORDER_FOCUS,
				0 if decorative_frame else UITokens.BORDER_WIDTH_FOCUS,
				0 if decorative_frame else UITokens.BORDER_RADIUS_SM,
				effective_padding
			))

		Variant.OVERLAY:
			add_theme_stylebox_override("panel", UITokens.make_stylebox(
				UITokens.COLOR_BG.darkened(0.2),
				Color.TRANSPARENT,
				0,
				0,
				effective_padding
			))


func _effective_padding() -> int:
	if padding >= 0:
		return padding
	var base_padding: int = _default_padding()
	if decorative_frame:
		return maxi(base_padding, UITokens.FRAME_MIN_PADDING)
	return base_padding


func _default_padding() -> int:
	match variant:
		Variant.POPUP:    return UITokens.SPACE_SM
		Variant.OVERLAY:  return UITokens.SPACE_XL
		_:                return UITokens.SPACE_LG


## Cambia la variante en runtime (útil para animaciones de apertura)
func set_variant(new_variant: Variant) -> void:
	variant = new_variant
	_apply_style()


# ============================================
# MARCO DECORATIVO (Spike 9 / Spike 15)
# ============================================

## Los setters se ejecutan también al cargar la escena, ANTES de _ready():
## en ese caso no hacen nada y _ready() aplica el estado inicial.
func _on_frame_config_changed() -> void:
	if not is_node_ready():
		return
	_refresh_frame()
	_apply_style()
	queue_redraw()


func _on_resized() -> void:
	if decorative_frame:
		queue_redraw()


## Resuelve la esquinera efectiva. Aquí —y no en _draw()— es donde se avisa.
func _refresh_frame() -> void:
	_active_corner = null
	if not decorative_frame:
		return

	if corner_texture != null:
		_active_corner = corner_texture
		return

	_active_corner = _load_default_corner()
	if _active_corner == null and not _warned_missing_default_corner:
		_warned_missing_default_corner = true
		push_warning("UIPanel: decorative_frame activo, sin corner_texture y sin esquinera por defecto en '%s' — solo se dibujan los filetes." % UITokens.FRAME_CORNER_TEXTURE_PATH)


func _load_default_corner() -> Texture2D:
	var path: String = UITokens.FRAME_CORNER_TEXTURE_PATH
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _draw() -> void:
	if decorative_frame:
		_draw_decorative_frame()


func _draw_decorative_frame() -> void:
	var rect := Rect2(Vector2.ZERO, size)

	# Filete exterior oscuro
	draw_rect(rect, UITokens.COLOR_FRAME_OUTER, false, UITokens.FRAME_OUTER_WIDTH)

	# Filete bronce intermedio
	rect = rect.grow(-(UITokens.FRAME_OUTER_WIDTH + UITokens.FRAME_GAP))
	draw_rect(rect, UITokens.COLOR_FRAME_FILLET, false, UITokens.FRAME_FILLET_WIDTH)

	# Línea interior tenue
	rect = rect.grow(-(UITokens.FRAME_FILLET_WIDTH + UITokens.FRAME_GAP))
	draw_rect(rect, UITokens.COLOR_FRAME_INNER, false, UITokens.FRAME_INNER_WIDTH)

	if _active_corner != null:
		_draw_frame_corners()


## Esquinera única rotada en las 4 esquinas (sin estirar, sin 4 variantes
## de imagen — decisión tomada aquí, ver spec del spike). El origen local
## (0,0) de la textura queda anclado a cada esquina del panel; al rotar,
## la textura se extiende hacia dentro por los dos bordes que forman esa
## esquina (0°, 90°, 180°, 270°) sin necesidad de offset manual.
func _draw_frame_corners() -> void:
	var corners := [
		[Vector2.ZERO, 0.0],
		[Vector2(size.x, 0.0), PI / 2.0],
		[Vector2(size.x, size.y), PI],
		[Vector2(0.0, size.y), -PI / 2.0],
	]
	for corner in corners:
		draw_set_transform(corner[0], corner[1])
		draw_texture(_active_corner, Vector2.ZERO)
	draw_set_transform(Vector2.ZERO, 0.0)
