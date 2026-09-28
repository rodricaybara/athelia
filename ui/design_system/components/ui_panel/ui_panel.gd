extends PanelContainer
class_name UIPanel
## UIPanel - Contenedor base para todas las ventanas y paneles del juego
##
## Uso:
##   Instanciar ui_panel.tscn como raíz visual de cualquier pantalla.
##   Configurar padding y variant desde el inspector o por código.
##
## Variantes:
##   DEFAULT  → panel estándar (inventario, shop, party)
##   POPUP    → panel pequeño flotante (tooltips, confirmaciones)
##   OVERLAY  → panel de fondo semitransparente (diálogo)
##
## Marco decorativo (Spike 9):
##   decorative_frame = true añade un marco ornamental (doble filete +
##   esquineras) dibujado POR ENCIMA del stylebox de fondo. Opt-in
##   explícito, false por defecto — ningún panel existente cambia de
##   aspecto sin activarlo a propósito por pantalla.
##
##   Al activarlo, el propio panel suprime su borde y su corner_radius
##   (pasan a 0): el marco los sustituye, evita duplicar líneas y evita
##   fondo redondeado bajo un marco de esquina viva.
##
##   corner_texture es la esquinera única del Design System (arte
##   pendiente en el momento de este spike). Sin asignar, el marco se
##   dibuja solo con los tres filetes concéntricos, sin esquineras, y se
##   avisa por warning — no bloquea, no rompe nada.


enum Variant { DEFAULT, POPUP, OVERLAY }

@export var variant: Variant = Variant.DEFAULT
@export var padding: int = -1  # -1 = usar default según variante

@export_group("Marco decorativo (Spike 9)")
@export var decorative_frame: bool = false
@export var corner_texture: Texture2D


func _ready() -> void:
	_apply_style()
	if decorative_frame:
		resized.connect(queue_redraw)


func _apply_style() -> void:
	var effective_padding := padding if padding >= 0 else _default_padding()

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
# MARCO DECORATIVO (Spike 9)
# ============================================

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

	if corner_texture:
		_draw_frame_corners()
	else:
		push_warning("UIPanel (%s): decorative_frame activo sin corner_texture — solo se dibujan los filetes." % name)


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
		draw_texture(corner_texture, Vector2.ZERO)
	draw_set_transform(Vector2.ZERO, 0.0)
