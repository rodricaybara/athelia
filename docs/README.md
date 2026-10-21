# Athelia — Design System: Guía de implementación

*Última actualización: Spike 16 — Tienda, primera pantalla del Design System (2026-10-21). Anterior: Spike 15 — Cimientos del Design System (2026-10-20).*

## Estructura de archivos

```
ui/design_system/
├── tokens/
│   └── ui_tokens.gd              ← Autoload: UITokens
│
├── components/
│   ├── ui_panel/
│   │   ├── ui_panel.gd
│   │   └── ui_panel.tscn         ← PanelContainer + ui_panel.gd
│   │
│   ├── ui_button/
│   │   ├── ui_button.gd
│   │   └── ui_button.tscn        ← Button + ui_button.gd
│   │
│   ├── ui_slot/
│   │   ├── ui_slot.gd
│   │   └── ui_slot.tscn          ← Ver estructura abajo
│   │
│   └── ui_resource_bar/
│       ├── ui_resource_bar.gd
│       └── ui_resource_bar.tscn  ← Ver estructura abajo
│
├── assets/
│   └── frames/
│       ├── frame_corner_64x64.png  ← esquinera por defecto del marco decorativo
│       └── frame_corner_96x96.png  ← reserva (invadía el texto del panel narrativo)
│
└── theme/
    └── main_theme.tres           ← Configurar manualmente (ver instrucciones)
```

---

## Paso 1 — Añadir UITokens como Autoload

En **Project Settings → Autoload**:

| Nombre    | Script                                          |
|-----------|------------------------------------------------|
| UITokens  | res://ui/design_system/tokens/ui_tokens.gd     |

Orden recomendado: antes de EventBus o inmediatamente después.

---

## Tokens: dos vocabularios y una regla de uso (Spike 15)

`ui_tokens.gd` tiene **dos familias de nombres**:

| Familia | Para qué |
|---|---|
| `COLOR_*` | Marca, semánticos, recursos del personaje, slots y la paleta base original |
| `BG_*` / `BORDER_*` / `TEXT_*` / `ACCENT_*` / `RADIUS_*` | Superficies, bordes y texto con más capas (`VOID`, `BASE`, `PANEL`, `SURFACE`, `RAISED`, `SELECTED`). Nació en el árbol de habilidades |

**Regla de uso**

- **Código nuevo:** superficies, bordes y texto → `BG_*` / `BORDER_*` / `TEXT_*`.
  Marca, semánticos, recursos y slots → `COLOR_*`.
- **Nada se migra a la fuerza:** los nombres antiguos siguen funcionando.
- **Un valor, un sitio:** lo que existía en las dos familias con el mismo valor es
  ahora **un alias**, no dos valores. Los alias apuntan siempre **hacia atrás**
  (a una constante ya declarada: en GDScript el orden de declaración importa).
  Para cambiar un valor se edita el `COLOR_*` de origen.

**Alias entre familias**

| Alias | Apunta a |
|---|---|
| `BG_BASE` | `COLOR_BG` |
| `BG_PANEL` | `COLOR_PANEL` |
| `BG_SURFACE` | `COLOR_PANEL_ALT` (`#252220`) |
| `BORDER_DEFAULT` | `COLOR_BORDER` |
| `TEXT_PRIMARY` | `COLOR_TEXT` |
| `TEXT_MUTED` | `COLOR_TEXT_MUTED` (`#9A8E78`) |
| `COLOR_SLOT_OCCUPIED` | `COLOR_PANEL_ALT` |

**Radios:** sin cambios de valor. La tabla de equivalencias entre
`BORDER_RADIUS_*` y `RADIUS_*` está en el comentario de `ui_tokens.gd`
(`BORDER_RADIUS_SM` 3 · `RADIUS_CARD` 4 · `BORDER_RADIUS_MD` 5 · `RADIUS_PANEL` 6 · `BORDER_RADIUS_LG` 8).

**Tokens del marco decorativo:** `COLOR_FRAME_OUTER`, `COLOR_FRAME_FILLET`,
`COLOR_FRAME_INNER`, `FRAME_OUTER_WIDTH`, `FRAME_FILLET_WIDTH`,
`FRAME_INNER_WIDTH`, `FRAME_GAP`, `FRAME_MIN_PADDING` (= `SPACE_LG`, 16) y
`FRAME_CORNER_TEXTURE_PATH` (esquinera por defecto).

---

## Resolución de referencia (Spike 15)

- **Sin estiramiento:** el proyecto usa los valores por defecto (ventana de
  1152×648, sin `stretch/mode`). Se probó `canvas_items` con base 1280×720 y se
  descartó porque ablanda el texto (≈ 15 % más suave en la medición).
- **Las pantallas nuevas se diseñan con anclas y fracciones**, no con tamaños en
  píxeles fijos, para una **ventana mínima de 1152×648**. Todo debe verse bien en
  1152×648 y adaptarse al crecer la ventana (p. ej. 1680×1050 a pantalla completa).
- Si algo (como el hueco de un retrato) depende del tamaño de otro nodo, se calcula
  desde el borde real de ese nodo, no con un número fijo.

---

## Paso 2 — Crear `ui_panel.tscn`

Estructura del nodo:
```
PanelContainer          ← script: ui_panel.gd
└── (sin hijos — el contenido va en la pantalla que lo instancia)
```

Configuración en Inspector:
- Script: `ui_panel.gd`
- `variant`: DEFAULT
- `padding`: -1 (usa el default del variant)

### Variantes

| Variante | Qué es | Consumidores hoy |
|---|---|---|
| `DEFAULT` | Fondo `COLOR_PANEL` con borde, padding 16 | Character Creation (3 paneles), Diálogo, Narrativa, sub-paneles del menú principal, cabeceras de columna y filas (`ShopItemSlot`) de la tienda |
| `POPUP` | Fondo `COLOR_PANEL_ALT`, borde de foco, padding 8 | ninguno |
| `OVERLAY` | Fondo **opaco** (`COLOR_BG` oscurecido un 20 %, alfa 1,0), sin borde, padding 24 | Tienda (panel principal, con marco decorativo) |

`OVERLAY` se documentaba como semitransparente, pero nunca lo fue. Si hiciera falta
transparencia, hay que añadirla de forma explícita.

### Marco decorativo (opt-in)

`decorative_frame = true` dibuja un marco ornamental (tres filetes concéntricos +
cuatro esquineras) **por encima** del fondo. Es **opt-in por instancia**: `false`
por defecto, ningún panel cambia de aspecto sin activarlo a propósito.

- **Esquinera por defecto:** si `corner_texture` no está asignada se usa
  `UITokens.FRAME_CORNER_TEXTURE_PATH` (64×64). Solo si tampoco carga esa, se
  dibujan los filetes sin esquinas y se avisa una vez por ejecución.
- **Padding con marco:** con `padding = -1`, el padding efectivo no baja de
  `FRAME_MIN_PADDING` (16). Un `padding` explícito (≥ 0) nunca se modifica.
- **Activación en runtime:** `decorative_frame` y `corner_texture` tienen setter;
  cambiarlos con el nodo ya en el árbol reaplica estilo y redibuja.
- Con el marco activo, el panel anula su borde y su `corner_radius` (el marco los sustituye).
- Para activarlo en una pantalla: en el inspector de la instancia, grupo «Marco
  decorativo (Spike 9)», marcar `Decorative Frame` y **guardar la escena**. No
  requiere cambios de script en la View.

---

## Paso 3 — Crear `ui_button.tscn`

Estructura del nodo:
```
Button                  ← script: ui_button.gd
```

Configuración en Inspector:
- Script: `ui_button.gd`
- `variant`: PRIMARY
- `size`: MD
- Text: (vacío — se asigna en la pantalla)

Modo solo icono (Spike 13, opt-in): `min_square` e `icon_backdrop`. Las propiedades
`variant`, `btn_size`, `min_square` e `icon_backdrop` se fijan **antes** de `add_child()`.

---

## Paso 4 — Crear `ui_slot.tscn`

Estructura de nodos:
```
PanelContainer                    ← script: ui_slot.gd
├── MarginContainer
│   └── VBoxContainer
│       ├── Icon (TextureRect)
│       │   expand_mode: FIT_WIDTH_PROPORTIONAL
│       │   stretch_mode: KEEP_ASPECT_CENTERED
│       └── QuantityLabel (Label)
│           horizontal_alignment: RIGHT
│           vertical_alignment: BOTTOM
│           visible: false
├── SlotLabel (Label)             ← para slots de equipamiento
│   anchors: BOTTOM_CENTER
│   visible: false
└── Overlay (Control)             ← para futuros highlights/animaciones
    layout_mode: anchors full
    mouse_filter: IGNORE
```

Configuración en Inspector:
- `slot_size`: Vector2(64, 64)
- `accept_drops`: true
- `equipment_slot_id`: "" (vacío para slots de inventario)

---

## Paso 5 — Crear `ui_resource_bar.tscn`

Estructura de nodos:
```
Control                           ← script: ui_resource_bar.gd
├── BgRect (ColorRect)
│   anchors: FULL_RECT
│   mouse_filter: IGNORE
├── FillRect (ColorRect)
│   anchors: LEFT, TOP, LEFT, BOTTOM (ancho se actualiza por código)
│   size_flags: FILL vertical
│   mouse_filter: IGNORE
└── ValueLabel (Label)            ← opcional
    anchors: FULL_RECT
    horizontal_alignment: CENTER
    vertical_alignment: CENTER
    mouse_filter: IGNORE
    visible: false (por defecto)
```

Configuración en Inspector:
- `show_value`: false
- `show_max`: false
- `resource_type`: "health"

---

## Paso 6 — Configurar `main_theme.tres`

Crear en **Project Settings → GUI → Theme** o manualmente:

1. En el FileSystem, click derecho → New Resource → Theme → guardar como `main_theme.tres`
2. Abrir el Theme Editor

*Nota (Spike 15): hoy `main_theme.tres` no está aplicado como tema del proyecto;
los componentes se estilan por código con `UITokens`. Aplicar tema y familias de
fuentes queda fuera del hito.*

### Configuraciones requeridas:

#### Default Font
- Si tienes una fuente custom: asignarla aquí
- Si no: dejar vacío (usa la fuente del sistema de Godot)

#### Panel (PanelContainer)
- `panel` StyleBoxFlat:
  - bg_color: `#2E2A26`
  - border_color: `#3D3830`
  - border_width_all: 1
  - corner_radius_all: 5

**NOTA:** Los componentes del Design System sobrescriben este tema con
`add_theme_stylebox_override()`. El tema global sirve como fallback para
nodos que NO usen los componentes del Design System.

#### Label
- `font_color`: `#E0D8C3`
- `font_size`: 14

#### Button
**NOTA:** `UIButton` gestiona sus propios estilos. Configurar el tema
global de Button solo para botones que NO usen `UIButton`:
- `font_color`: `#E0D8C3`

#### ScrollContainer
- `panel` StyleBoxFlat:
  - bg_color: `#1A1816`
  - draw_center: true

#### HSeparator / VSeparator
- `separator` StyleBoxLine:
  - color: `#3D3830`
  - thickness: 1

---

## Tienda — primera pantalla del Design System (Spike 16)

Ejemplo de referencia de una pantalla completa con `UIPanel` `OVERLAY` + marco
decorativo (anclas 0.05–0.95), cabeceras `UIPanel`, `UIButton` y tokens, y del
patrón de **fila de lista** (`ShopItemSlot`). Reutilizable en Party (Spike 19) e
Inventario (Spike 18).

### Fila de lista: `ShopItemSlot`

`[icono opcional] [nombre] [xN] [precio] [botón]`

- **Raíz:** `PanelContainer` con script que `extends UIPanel` (variante `DEFAULT`).
  Fija `padding = UITokens.SPACE_XS` **antes** de `super._ready()`: el estilo se
  aplica en el `_ready()` de `UIPanel` con el padding que tenga en ese momento.
- **Contrato:** `setup(item_data, buy_mode)` **después** de `add_child()`; señal
  `item_clicked(item_id, is_buy)`; `set_busy(bool)` bloquea la acción durante una
  transacción y nunca habilita lo que la fila no permite.
- **Estados con tokens, sin `modulate`:** no asequible (precio `COLOR_DANGER_SOFT`,
  botón deshabilitado, tooltip) y no disponible (`TEXT_MUTED`).
- **Préstamo:** la clave opcional `"is_loan"` cambia el precio por «Préstamo»
  (`COLOR_INFO`) y el botón por «Tomar»; en venta el botón queda bloqueado.
- **Gancho de icono:** `%IconRect` está oculto hasta que la entrada traiga la clave
  `"icon"` (`Texture2D`).
- **Hover:** `BG_RAISED` + `BORDER_ACCENT`; `mouse_exited` se emite también al entrar
  en un hijo, así que solo cuenta como salida fuera de `get_global_rect()`.
- **Listas:** `VBoxContainer` en `ScrollContainer` (scroll horizontal desactivado);
  al reconstruir, `remove_child()` antes de `queue_free()`; mensaje de lista vacía
  en un `Label` hermano del scroll.
- **Cuidado al montar la escena a mano:** un `PanelContainer` apila todos sus hijos
  en el mismo rectángulo. El contenido de un panel va dentro de un único
  `VBoxContainer`/`HBoxContainer`.

---

## Reglas de uso

### ✅ Obligatorio

- Todo color, spacing o tamaño referencia `UITokens`
- Las **ventanas y paneles nuevos** usan `UIPanel` como raíz visual
- Todo botón de acción nuevo usa `UIButton`
- Todo slot de inventario/equipo usa `UISlot`
- Toda barra de recurso usa `UIResourceBar`
- Layouts con anclas y fracciones para ventana mínima de 1152×648 (ver arriba)
- Todo texto visible con `tr()` y clave de localización, formato `PANTALLA_ELEMENTO`
  (prefijo de pantalla en mayúsculas)

*Las pantallas anteriores al hito (inventario, party, menú del jugador…)
todavía no usan `UIPanel` (la tienda ya migró en el Spike 16); migran en el spike de cada una (ver plan del hito).*

### ❌ Prohibido

- Valores hardcodeados de color (ej: `Color("#2E2A26")` en una pantalla)
- `StyleBoxFlat.new()` fuera de `UITokens.make_stylebox()`
- Crear nodos Button/Panel "raw" en pantallas de juego nuevas
- Acceder a sistemas core desde componentes del Design System
- Definir un mismo valor en las dos familias de tokens: se usa un alias

---

## Cómo añadir un nuevo token

1. Abrir `ui_tokens.gd`
2. Añadir la constante en la sección apropiada
3. Si el concepto ya existe en la otra familia, **definir un alias** (apuntando
   hacia atrás), no un segundo valor
4. Documentar con un comentario qué componente lo usa

No crear tokens sin uso. Un token existe cuando hay al menos un componente que lo necesita.

---

## Cómo crear un nuevo componente

1. Crear carpeta en `ui/design_system/components/nombre_componente/`
2. Script hereda del nodo Godot apropiado
3. En `_ready()` aplicar estilos usando `UITokens`
4. Señales claras con nombres de intención (`slot_clicked`, no `pressed`)
5. Nunca acceder a autoloads de sistemas de juego (`Inventory`, `Characters`, etc.)
6. Si un `@export` tiene setter, recordar que corre **antes de `_ready()`** al cargar la
   escena: protegerlo con `is_node_ready()`
7. Documentar en este README

---

## Notas de migración desde UI existente

Los componentes actuales (`item_slot.gd`, `equip_slot.gd`) coexistirán con el
Design System durante la transición. La migración es pantalla a pantalla:

| Componente actual    | Migrar a   | Cuando                        |
|----------------------|------------|-------------------------------|
| `item_slot.gd`       | `UISlot`   | Al refactorizar InventoryScreen |
| `equip_slot.gd`      | `UISlot`   | Al refactorizar InventoryScreen |
| Buttons inline       | `UIButton` | Al refactorizar cada pantalla   |
| PanelContainer raw   | `UIPanel`  | Al refactorizar cada pantalla   |
