extends Button
class_name UIButton
## UIButton - Botón reutilizable del sistema de diseño
##
## Variantes:
##   PRIMARY   → acción principal (Equipar, Confirmar)
##   SECONDARY → acción secundaria (Cancelar, Cerrar)
##   DANGER    → acción destructiva (Tirar, Eliminar)
##   GHOST     → botón sin relleno (navegación, tabs)
##
## Tamaños:
##   SM → acciones secundarias en paneles pequeños
##   MD → tamaño estándar
##   LG → CTAs principales


enum Variant { PRIMARY, SECONDARY, DANGER, GHOST }
enum Size    { SM, MD, LG }

@export var variant:  Variant = Variant.PRIMARY
@export var btn_size: Size   = Size.MD


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_style()


func _apply_style() -> void:
	# Altura mínima según btn_size
	var min_h := _min_height()
	custom_minimum_size.y = min_h

	# Padding horizontal
	var pad_h := _padding_h()

	# Colores según variante
	var colors := _colors()

	# Estilos de estado
	add_theme_stylebox_override("normal",   _make_btn_style(colors.normal_bg, colors.border, pad_h))
	add_theme_stylebox_override("hover",    _make_btn_style(colors.hover_bg, colors.border, pad_h))
	add_theme_stylebox_override("pressed",  _make_btn_style(colors.pressed_bg, colors.border, pad_h))
	add_theme_stylebox_override("disabled", _make_btn_style(colors.disabled_bg, colors.border, pad_h))
	add_theme_stylebox_override("focus",    _make_focus_style())

	# Color de texto
	add_theme_color_override("font_color",          colors.text)
	add_theme_color_override("font_hover_color",     colors.text)
	add_theme_color_override("font_pressed_color",   colors.text_pressed)
	add_theme_color_override("font_disabled_color",  UITokens.COLOR_TEXT_DISABLED)

	# Tamaño de fuente
	add_theme_font_size_override("font_size", _font_size())


func _make_btn_style(bg: Color, border: Color, pad_h: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(UITokens.BORDER_WIDTH)
	style.set_corner_radius_all(UITokens.BORDER_RADIUS_MD)
	style.set_content_margin(SIDE_LEFT, pad_h)
	style.set_content_margin(SIDE_RIGHT, pad_h)
	style.set_content_margin(SIDE_TOP, UITokens.SPACE_XS)
	style.set_content_margin(SIDE_BOTTOM, UITokens.SPACE_XS)
	return style


func _make_focus_style() -> StyleBoxFlat:
	return UITokens.make_stylebox_outline(
		UITokens.COLOR_ACCENT,
		UITokens.BORDER_WIDTH_FOCUS,
		UITokens.BORDER_RADIUS_MD
	)


func _colors() -> Dictionary:
	match variant:
		Variant.PRIMARY:
			return {
				"normal_bg":   UITokens.COLOR_PRIMARY,
				"hover_bg":    UITokens.COLOR_PRIMARY_HOVER,
				"pressed_bg":  UITokens.COLOR_PRIMARY_PRESSED,
				"disabled_bg": UITokens.COLOR_PRIMARY.darkened(0.4),
				"border":      UITokens.COLOR_PRIMARY_HOVER,
				"text":        UITokens.COLOR_TEXT_ON_PRIMARY,
				"text_pressed": UITokens.COLOR_TEXT_ON_PRIMARY.darkened(0.1),
			}
		Variant.SECONDARY:
			return {
				"normal_bg":   UITokens.COLOR_PANEL_ALT,
				"hover_bg":    UITokens.COLOR_PANEL_ALT.lightened(0.08),
				"pressed_bg":  UITokens.COLOR_BG,
				"disabled_bg": UITokens.COLOR_PANEL_ALT.darkened(0.3),
				"border":      UITokens.COLOR_BORDER_FOCUS,
				"text":        UITokens.COLOR_TEXT,
				"text_pressed": UITokens.COLOR_TEXT_MUTED,
			}
		Variant.DANGER:
			return {
				"normal_bg":   UITokens.COLOR_DANGER,
				"hover_bg":    UITokens.COLOR_DANGER_SOFT,
				"pressed_bg":  UITokens.COLOR_DANGER.darkened(0.2),
				"disabled_bg": UITokens.COLOR_DANGER.darkened(0.5),
				"border":      UITokens.COLOR_DANGER_SOFT,
				"text":        UITokens.COLOR_TEXT,
				"text_pressed": UITokens.COLOR_TEXT,
			}
		Variant.GHOST:
			return {
				"normal_bg":   Color.TRANSPARENT,
				"hover_bg":    UITokens.COLOR_PANEL_ALT,
				"pressed_bg":  UITokens.COLOR_BG,
				"disabled_bg": Color.TRANSPARENT,
				"border":      Color.TRANSPARENT,
				"text":        UITokens.COLOR_TEXT_MUTED,
				"text_pressed": UITokens.COLOR_TEXT,
			}
	return {}


func _min_height() -> int:
	match btn_size:
		Size.SM: return UITokens.BUTTON_HEIGHT_SM
		Size.LG: return UITokens.BUTTON_HEIGHT_LG
		_:       return UITokens.BUTTON_HEIGHT_MD


func _padding_h() -> int:
	match btn_size:
		Size.SM: return UITokens.SPACE_SM
		Size.LG: return UITokens.SPACE_XL
		_:       return UITokens.SPACE_LG


func _font_size() -> int:
	match btn_size:
		Size.SM: return UITokens.FONT_SIZE_SM
		Size.LG: return UITokens.FONT_SIZE_LG
		_:       return UITokens.FONT_SIZE_MD


## Cambia la variante en runtime
func set_variant(new_variant: Variant) -> void:
	variant = new_variant
	_apply_style()


## Cambia el tamaño en runtime
func set_size_variant(new_size: Size) -> void:
	btn_size = new_size
	_apply_style()
