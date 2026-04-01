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


enum Variant { DEFAULT, POPUP, OVERLAY }

@export var variant: Variant = Variant.DEFAULT
@export var padding: int = -1  # -1 = usar default según variante


func _ready() -> void:
	_apply_style()


func _apply_style() -> void:
	var effective_padding := padding if padding >= 0 else _default_padding()

	match variant:
		Variant.DEFAULT:
			add_theme_stylebox_override("panel", UITokens.make_stylebox(
				UITokens.COLOR_PANEL,
				UITokens.COLOR_BORDER,
				UITokens.BORDER_WIDTH,
				UITokens.BORDER_RADIUS_MD,
				effective_padding
			))

		Variant.POPUP:
			add_theme_stylebox_override("panel", UITokens.make_stylebox(
				UITokens.COLOR_PANEL_ALT,
				UITokens.COLOR_BORDER_FOCUS,
				UITokens.BORDER_WIDTH_FOCUS,
				UITokens.BORDER_RADIUS_SM,
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
