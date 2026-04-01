## ui_tokens_patch.gd
## PARCHE para ui_tokens.gd — Spike SkillTreeScreen
##
## INSTRUCCIONES:
##   Añadir estas constantes al autoload UITokens (ui/design_system/tokens/ui_tokens.gd).
##   Si UITokens no existe aún, crear el fichero con estas constantes como base.

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
