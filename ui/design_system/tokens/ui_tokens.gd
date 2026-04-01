extends Node
## UITokens - Tokens de diseño centralizados para Athelia
## Autoload recomendado: /root/UITokens
##
## REGLA: Ningún archivo de UI puede usar valores de color, spacing o
## tipografía hardcodeados. Siempre referenciar estas constantes.
##
## Uso:
##   panel.add_theme_color_override("bg_color", UITokens.COLOR_PANEL)
##   margin.add_theme_constant_override("margin_left", UITokens.SPACE_MD)


# ============================================================
# COLORES — Paleta base
# ============================================================

## Fondo principal de la aplicación (el más oscuro)
const COLOR_BG          := Color("#1A1816")

## Fondo de paneles y ventanas
const COLOR_PANEL       := Color("#2E2A26")

## Fondo de paneles secundarios / anidados
const COLOR_PANEL_ALT   := Color("#252220")

## Borde sutil de paneles
const COLOR_BORDER      := Color("#3D3830")

## Borde destacado (slots seleccionados, hover)
const COLOR_BORDER_FOCUS := Color("#6B5A3E")


# ============================================================
# COLORES — Marca
# ============================================================

## Color primario — usado en elementos interactivos principales
const COLOR_PRIMARY     := Color("#8C6A3B")

## Color primario hover
const COLOR_PRIMARY_HOVER := Color("#A07A46")

## Color primario pressed
const COLOR_PRIMARY_PRESSED := Color("#735630")

## Color acento — highlights, selección activa, iconos importantes
const COLOR_ACCENT      := Color("#C9A96E")

## Color acento suave — para texto secundario importante
const COLOR_ACCENT_SOFT := Color("#B09060")


# ============================================================
# COLORES — Texto
# ============================================================

## Texto principal
const COLOR_TEXT        := Color("#E0D8C3")

## Texto secundario / muted
const COLOR_TEXT_MUTED  := Color("#7A756A")

## Texto deshabilitado
const COLOR_TEXT_DISABLED := Color("#4A4640")

## Texto sobre fondo primario (botones)
const COLOR_TEXT_ON_PRIMARY := Color("#F0E8D4")


# ============================================================
# COLORES — Semánticos
# ============================================================

## Peligro / error / vida baja
const COLOR_DANGER      := Color("#A13C2E")
const COLOR_DANGER_SOFT := Color("#C04535")

## Éxito / confirmación
const COLOR_SUCCESS     := Color("#6E8B3D")
const COLOR_SUCCESS_SOFT := Color("#85A84A")

## Advertencia
const COLOR_WARNING     := Color("#C9872E")

## Información / neutral
const COLOR_INFO        := Color("#4A7A9B")


# ============================================================
# COLORES — Recursos del personaje
# ============================================================

## Vida
const COLOR_HEALTH      := Color("#A13C2E")
const COLOR_HEALTH_BG   := Color("#3D1810")

## Stamina
const COLOR_STAMINA     := Color("#6E8B3D")
const COLOR_STAMINA_BG  := Color("#1E2D10")

## Oro
const COLOR_GOLD        := Color("#C9A96E")
const COLOR_GOLD_BG     := Color("#3D3018")

## Estrés
const COLOR_STRESS      := Color("#7A4A9B")
const COLOR_STRESS_BG   := Color("#251530")


# ============================================================
# COLORES — Slots de inventario
# ============================================================

## Slot vacío
const COLOR_SLOT_EMPTY      := Color("#1E1C1A")
const COLOR_SLOT_EMPTY_BORDER := Color("#2E2A26")

## Slot ocupado
const COLOR_SLOT_OCCUPIED   := Color("#252220")
const COLOR_SLOT_OCCUPIED_BORDER := Color("#4A4030")

## Slot seleccionado
const COLOR_SLOT_SELECTED   := Color("#2A2418")
const COLOR_SLOT_SELECTED_BORDER := Color("#C9A96E")

## Slot hover
const COLOR_SLOT_HOVER      := Color("#2E2820")
const COLOR_SLOT_HOVER_BORDER := Color("#8C6A3B")

## Slot equipado (en panel de equipo)
const COLOR_SLOT_EQUIPPED   := Color("#1E2410")
const COLOR_SLOT_EQUIPPED_BORDER := Color("#6E8B3D")


# ============================================================
# ESPACIADO
# ============================================================

const SPACE_XS  := 4
const SPACE_SM  := 8
const SPACE_MD  := 12
const SPACE_LG  := 16
const SPACE_XL  := 24
const SPACE_XXL := 32


# ============================================================
# BORDES
# ============================================================

const BORDER_RADIUS_SM  := 3
const BORDER_RADIUS_MD  := 5
const BORDER_RADIUS_LG  := 8
const BORDER_WIDTH      := 1
const BORDER_WIDTH_FOCUS := 2


# ============================================================
# TAMAÑOS DE COMPONENTES
# ============================================================

## Tamaño estándar de slot de inventario
const SLOT_SIZE         := Vector2(64, 64)

## Tamaño de slot de equipamiento
const EQUIP_SLOT_SIZE   := Vector2(72, 72)

## Tamaño de icono dentro de slot
const ICON_SIZE_SM      := Vector2(32, 32)
const ICON_SIZE_MD      := Vector2(48, 48)
const ICON_SIZE_LG      := Vector2(64, 64)

## Altura mínima de barra de recurso
const RESOURCE_BAR_HEIGHT := 14

## Alto mínimo de botón
const BUTTON_HEIGHT_SM  := 28
const BUTTON_HEIGHT_MD  := 36
const BUTTON_HEIGHT_LG  := 44


# ============================================================
# TIPOGRAFÍA — tamaños
# ============================================================

const FONT_SIZE_XS      := 10
const FONT_SIZE_SM      := 12
const FONT_SIZE_MD      := 14
const FONT_SIZE_LG      := 16
const FONT_SIZE_XL      := 20
const FONT_SIZE_TITLE   := 24


# ============================================================
# ESTADOS DE COMPONENTES — helpers
# ============================================================

const HOVER_BRIGHTNESS  := 1.12
const PRESSED_DARKNESS  := 0.85
const DISABLED_ALPHA    := 0.45
const SELECTED_ALPHA    := 1.0


# ============================================================
# ANIMACIONES
# ============================================================

const ANIM_DURATION_FAST   := 0.08
const ANIM_DURATION_NORMAL := 0.15
const ANIM_DURATION_SLOW   := 0.25

# ============================================
# FONDOS — capas de profundidad
# ============================================
const BG_VOID     := Color("#111009")  ## Fondo más profundo — detrás de todo
const BG_BASE     := Color("#1A1816")  ## Fondo de pantalla base
const BG_PANEL    := Color("#2E2A26")  ## Fondo de paneles (header, detail)
const BG_SURFACE  := Color("#252118")  ## Fondo de tarjetas de skill
const BG_RAISED   := Color("#3A3428")  ## Fondo de elementos elevados (btn activo)
const BG_SELECTED := Color("#332C24")  ## Fondo de skill seleccionada
 
# ============================================
# BORDES — jerarquía de énfasis
# ============================================
const BORDER_SUBTLE  := Color("#2A2620")  ## Separadores muy sutiles
const BORDER_DEFAULT := Color("#3D3830")  ## Borde por defecto de tarjetas
const BORDER_PANEL   := Color("#5C4E38")  ## Borde de paneles principales
const BORDER_ACCENT  := Color("#8A7050")  ## Borde de elementos activos/seleccionados
const BORDER_GOLD    := Color("#D4C49A")  ## Borde decorativo (usar con moderación)
 
# ============================================
# TEXTO
# ============================================
const TEXT_PRIMARY   := Color("#E0D8C3")  ## Texto principal
const TEXT_SECONDARY := Color("#B8A98A")  ## Texto secundario
const TEXT_MUTED     := Color("#9A8E78")  ## Texto apagado (labels, hints)
const TEXT_GOLD      := Color("#D4C49A")  ## Porcentaje en panel lateral — usar solo ahí
 
# ============================================
# ACENTOS SEMÁNTICOS
# ============================================
const ACCENT_GREEN     := Color("#6A9A4A")  ## Mejorable ahora
const ACCENT_GREEN_BG  := Color("#1A2E14")  ## Fondo badge mejorable
const ACCENT_GREEN_B   := Color("#5A7A3A")  ## Borde mejorable
 
const ACCENT_AMBER     := Color("#C0A040")  ## Sugerencia IA
const ACCENT_AMBER_BG  := Color("#2E2010")  ## Fondo badge IA
const ACCENT_AMBER_B   := Color("#7A6020")  ## Borde sugerencia IA
 
const ACCENT_DANGER    := Color("#C07060")  ## Error, prereq no cumplido
const ACCENT_DANGER_BG := Color("#2E1010")  ## Fondo badge error
const ACCENT_DANGER_B  := Color("#7A3A2A")  ## Borde error
 
const ACCENT_INFO      := Color("#6A90C0")  ## Información neutral
const ACCENT_INFO_BG   := Color("#1A2030")  ## Fondo badge info
 
# ============================================
# RADIOS DE ESQUINA
# ============================================
const RADIUS_CARD  : int = 4   ## Tarjetas de skill, badges
const RADIUS_PANEL : int = 6   ## Paneles y overlays
## Sin border-radius > 8px — piedra y madera no son suaves.

# ============================================================
# UTILIDADES
# ============================================================

## Crea un StyleBoxFlat con los valores del sistema de diseño
func make_stylebox(
	bg_color: Color,
	border_color: Color = Color.TRANSPARENT,
	border_width: int = BORDER_WIDTH,
	radius: int = BORDER_RADIUS_MD,
	padding: int = SPACE_SM
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style


## Crea un StyleBoxFlat vacío (solo borde, fondo transparente)
func make_stylebox_outline(
	border_color: Color,
	border_width: int = BORDER_WIDTH,
	radius: int = BORDER_RADIUS_MD
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.draw_center = false
	return style
