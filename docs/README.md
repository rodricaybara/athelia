# Athelia — Design System: guía de montaje
 
Cómo se construyen los componentes (`ui/design_system/`), qué tokens existen y qué reglas se cumplen al usarlos. El comportamiento y la API de cada componente (variantes y marco de `UIPanel`, modo solo icono de `UIButton`, `UISlot`, fila de lista, patrón de overlay a pantalla completa, `BagCapacity`) están en `athelia_ui_architecture.md`, sección «Design System»; no se repiten aquí.
 
## Estructura de archivos
 
```
ui/design_system/
├── tokens/ui_tokens.gd              ← Autoload: UITokens
├── components/
│   ├── ui_panel/      (ui_panel.gd + .tscn)       ← PanelContainer
│   ├── ui_button/     (ui_button.gd + .tscn)      ← Button
│   ├── ui_slot/       (ui_slot.gd + .tscn)        ← PanelContainer
│   ├── ui_resource_bar/ (ui_resource_bar.gd + .tscn) ← Control
│   ├── ui_radial_gauge/                           ← anillo de progreso (_draw())
│   └── ui_combat_token/                           ← ficha de combate
├── assets/
│   ├── icons/icon_item_placeholder.png   ← silueta de bolsa 64×64 (se tiñe con COLOR_TEXT_MUTED)
│   └── frames/frame_corner_64x64.png     ← esquinera por defecto (la de 96×96 es reserva: invadía el texto)
└── theme/main_theme.tres            ← sin aplicar al proyecto (ver abajo)
```
 
## Puesta en marcha
 
**UITokens como Autoload** (Project Settings → Autoload): nombre `UITokens`, script `res://ui/design_system/tokens/ui_tokens.gd`. Orden recomendado: antes de `EventBus` o justo después.
 
## Tokens
 
`ui_tokens.gd` tiene **dos familias de nombres**:
 
| Familia | Para qué |
|---|---|
| `COLOR_*` | Marca, semánticos, recursos del personaje, slots y la paleta base original |
| `BG_*` / `BORDER_*` / `TEXT_*` / `ACCENT_*` / `RADIUS_*` | Superficies, bordes y texto con más capas (`VOID`, `BASE`, `PANEL`, `SURFACE`, `RAISED`, `SELECTED`) |
 
**Regla de uso:** código nuevo → `BG_*`/`BORDER_*`/`TEXT_*` para superficies, bordes y texto; `COLOR_*` para marca, semánticos, recursos y slots. Nada se migra a la fuerza. **Un valor, un sitio:** lo que existe en las dos familias con el mismo valor es un **alias** que apunta siempre hacia atrás (a una constante ya declarada: en GDScript el orden de declaración importa). Para cambiar un valor se edita el `COLOR_*` de origen.
 
| Alias | Apunta a |
|---|---|
| `BG_BASE` | `COLOR_BG` |
| `BG_PANEL` | `COLOR_PANEL` |
| `BG_SURFACE` | `COLOR_PANEL_ALT` (`#252220`) |
| `BORDER_DEFAULT` | `COLOR_BORDER` |
| `TEXT_PRIMARY` | `COLOR_TEXT` |
| `TEXT_MUTED` | `COLOR_TEXT_MUTED` (`#9A8E78`) |
| `COLOR_SLOT_OCCUPIED` | `COLOR_PANEL_ALT` |
 
**Radios:** equivalencias `BORDER_RADIUS_SM` 3 · `RADIUS_CARD` 4 · `BORDER_RADIUS_MD` 5 · `RADIUS_PANEL` 6 · `BORDER_RADIUS_LG` 8 (tabla también en el comentario de `ui_tokens.gd`).
 
**Marco decorativo:** `COLOR_FRAME_OUTER`, `COLOR_FRAME_FILLET`, `COLOR_FRAME_INNER`, `FRAME_OUTER_WIDTH`, `FRAME_FILLET_WIDTH`, `FRAME_INNER_WIDTH`, `FRAME_GAP`, `FRAME_MIN_PADDING` (= `SPACE_LG`, 16), `FRAME_CORNER_TEXTURE_PATH`.
 
**Contorno de texto sobre imagen:** `TEXT_OUTLINE_SIZE`, `COLOR_TEXT_OUTLINE`. **Velo de combate:** `COMBAT_BACKGROUND_SCRIM_ALPHA` (0,2).
 
### Cómo añadir un token
 
1. Abrir `ui_tokens.gd` y añadir la constante en la sección apropiada.
2. Si el concepto ya existe en la otra familia, **definir un alias** (apuntando hacia atrás), no un segundo valor.
3. Documentar con un comentario qué componente lo usa.
No crear tokens sin uso: un token existe cuando al menos un componente lo necesita.
 
## Escenas de los componentes
 
### `ui_panel.tscn`
```
PanelContainer          ← script: ui_panel.gd
└── (sin hijos — el contenido va en la pantalla que lo instancia)
```
Inspector: `variant` DEFAULT, `padding` -1 (usa el default de la variante). Un `PanelContainer` apila todos sus hijos en el mismo rectángulo: el contenido de un panel va dentro de un único `VBoxContainer`/`HBoxContainer`.
 
### `ui_button.tscn`
```
Button                  ← script: ui_button.gd
```
Inspector: `variant` PRIMARY, `size` MD, `text` vacío (se asigna en la pantalla). `variant`, `btn_size`, `min_square` e `icon_backdrop` se fijan **antes** de `add_child()`.
 
### `ui_slot.tscn` (estructura real)
```
PanelContainer                    ← script: ui_slot.gd
├── Content (MarginContainer, margen 4, mouse_filter IGNORE)
│   └── Icon (TextureRect, %Icon, expand IGNORE_SIZE, KEEP_ASPECT_CENTERED)
└── Overlay (Control, %Overlay, mouse_filter IGNORE, cubre el slot entero)
    ├── QuantityLabel (%)   ← cantidad, solo si > 1
    ├── SlotLabel (%)       ← etiqueta del slot de equipo (texto ya traducido)
    └── EquippedMark (%)    ← marca «E» de equipado
```
Todos los hijos por nombre único (`%`). Inspector: `slot_size` Vector2(64, 64), `accept_drops` true, `equipment_slot_id` vacío para slots de inventario. Los textos los pone la View ya traducidos.
 
### `ui_resource_bar.tscn`
```
Control                           ← script: ui_resource_bar.gd
├── BgRect (ColorRect)            anchors FULL_RECT, mouse_filter IGNORE
├── FillRect (ColorRect)          anchors LEFT, TOP, LEFT, BOTTOM (el ancho lo actualiza el código)
│                                 size_flags FILL vertical, mouse_filter IGNORE
└── ValueLabel (Label)            opcional, anchors FULL_RECT, centrado, mouse_filter IGNORE, visible false
```
Inspector: `show_value` false, `show_max` false, `resource_type` `"health"`. La raíz es visible; `FillRect` va anclado a izquierda y alto y su ancho se fija con `offset_right`. Desde una View se usa `set_values()` (primer consumidor: Party); `bind()` accede al juego y queda para contextos sin MVVM.
 
## Tema global (`main_theme.tres`)
 
Hoy **no está aplicado como tema del proyecto**: los componentes se estilan por código con `UITokens`. Aplicar tema y familias de fuentes queda fuera del hito. Si se aplica, sirve como fallback para nodos que no usen los componentes (los componentes lo sobrescriben con `add_theme_stylebox_override()`):
 
- **Panel:** `StyleBoxFlat` con `bg_color` `#2E2A26`, `border_color` `#3D3830`, borde 1, radio 5.
- **Label:** `font_color` `#E0D8C3`, `font_size` 14.
- **Button:** `font_color` `#E0D8C3` (solo para botones que no usen `UIButton`, que gestiona sus propios estilos).
- **ScrollContainer:** `panel` con `bg_color` `#1A1816`, `draw_center` true.
- **HSeparator/VSeparator:** `StyleBoxLine` color `#3D3830`, grosor 1.
## Reglas de uso
 
### ✅ Obligatorio
 
- Todo color, spacing o tamaño referencia `UITokens`.
- Las ventanas y paneles nuevos usan `UIPanel` como raíz visual.
- Todo botón de acción nuevo usa `UIButton`; todo slot de inventario/equipo usa `UISlot`; toda barra de recurso usa `UIResourceBar`.
- Layouts con anclas y fracciones para una ventana mínima de 1152×648 (referencia de diseño 1680×1050; sin estiramiento).
- Todo texto visible con `tr()` y clave `PANTALLA_ELEMENTO` (prefijo de pantalla en mayúsculas).
### ❌ Prohibido
 
- Valores hardcodeados de color (`Color("#2E2A26")` en una pantalla).
- `StyleBoxFlat.new()` fuera de `UITokens.make_stylebox()`.
- Crear nodos `Button`/`Panel` «raw» en pantallas de juego nuevas.
- Acceder a sistemas core desde componentes del Design System.
- Definir un mismo valor en las dos familias de tokens: se usa un alias.
Pantallas pendientes de migrar al Design System: menú del jugador, Loadout, árbol de habilidades y Game Over (Spikes 20-24, ver `estado_actual.md`). Tienda, inventario y Party ya migraron.
 
## Cómo crear un nuevo componente
 
1. Carpeta `ui/design_system/components/nombre_componente/`.
2. El script hereda del nodo Godot apropiado.
3. En `_ready()` aplicar estilos con `UITokens`.
4. Señales con nombre de intención (`slot_clicked`, no `pressed`).
5. Nunca acceder a autoloads de sistemas de juego (`Inventory`, `Characters`, …): un componente del DS no conoce el juego.
6. Si un `@export` tiene setter, corre **antes de `_ready()`** al cargar la escena: protegerlo con `is_node_ready()`.
7. Toda opción visual nueva entra como flag apagado por defecto.
8. Documentar en `athelia_ui_architecture.md` (API y comportamiento) y, si cambia la estructura de nodos, en este fichero.