# Spike 16 — Tienda (primera adopción real del Design System)

**Hito:** rediseño de interfaces · **Riesgo:** bajo · **Depende de:** Spike 15 (cerrado)
**Estado de esta spec:** redactada a partir de la lectura de `shop_ui.gd`, `shop_viewmodel.gd`,
`shop_item_slot.gd`, `shop_ui.tscn` y `shop_item_slot.tscn`. Lo no leído se marca como
**[sin verificar]** y se cierra en la Fase 0.

---

## 1. Problema

La tienda funciona (MVVM correcto, cierre por `shop_closed`), pero es la pantalla que
menos se parece al resto del juego y no usa nada del Design System:

- **No usa `UIPanel`, `UIButton` ni `UITokens`.** Todo es `PanelContainer` y `Button` con el
  tema por defecto de Godot.
- **Layout rígido.** `ShopPanel` tiene `anchors_preset 8` con offsets fijos ±400 / ±300
  (800×600). En 1152×648 deja poco margen vertical y en pantalla completa queda pequeño.
- **Texto sin localizar** en la View: `"Gold: %d"`, `"Shop: %d gold"`, `"Slots: %d/%d"`
  (`shop_ui.gd`), `"%s%d gold"`, `"x%d"`, `"BUY"`, `"SELL"`, tooltips `"Not enough gold"`,
  `"Out of stock"`, `"Shop has no slots"` (`shop_item_slot.gd`), y en la escena `"CLOSE"`,
  `"Your Inventory"`, `"Shop Inventory (3/10 slots)"`, `"Shop Name"`, `"✓ Transaction successful"`.
  El ViewModel sí usa claves `SHOP_*`.
- **Literales de estilo:** `COLOR_FEEDBACK_OK/ERR` (`Color(0.3,0.9,0.3)` / `Color(0.9,0.3,0.3)`),
  `modulate Color(0.5,0.5,0.5,1)` y `Color(1,0.8,0.8,1)` en `ShopItemSlot`, `Color.RED` en el
  precio, tamaños de fuente en `.tscn` (24, 18).
- **`ShopItemSlot` es una tarjeta de 120×140** con un `ColorRect` de 24×24 como icono falso.
  En un `HFlowContainer` con muchos objetos crece en filas impredecibles y es difícil de
  comparar de un vistazo (nombre, precio, cantidad, acción).
- **El estado "no disponible / no asequible" se expresa con `modulate`** sobre toda la
  tarjeta, lo que también apaga el botón y el texto de forma no controlada por tokens.

## 2. Objetivo

Rehacer la vista de la tienda con `UIPanel`, `UIButton` y `UITokens`, con layout por
anclas y fracciones, textos localizados (`SHOP_*`) y `ShopItemSlot` convertido en una
**fila** homogénea del Design System. **No cambia el comportamiento**: mismo ViewModel,
misma API pública, mismo flujo de apertura y cierre.

## 3. Decisiones ya tomadas (no reabrir)

1. **Contrato intacto:** se conservan `show_shop_direct(shop_id, entity_id, snapshot)`, el cierre
   por `EventBus.shop_closed` → `enter_exploration()` y todos los nombres únicos `%`
   (`ShopNameLabel, PlayerGoldLabel, ShopGoldLabel, ShopSlotsLabel, ShopItemsContainer,
   PlayerItemsContainer, CloseButton, FeedbackLabel`). Si un nodo cambia de tipo, el `%` se
   mantiene.
2. **MVVM sin cambios de responsabilidad:** `ShopViewModel` no se toca salvo, si hace falta,
   para exponer datos ya existentes. La View sigue sin acceder a `EconomySystem` ni a `EventBus`.
3. **Resolución:** sin estiramiento, ventana por defecto 1152×648, mínimo de diseño 1152×648
   y pantalla completa (probada a 1680×1050). Anclas y fracciones; nada de offsets grandes
   fijos.
4. **Marco decorativo opt-in** (`decorative_frame = true`) en el panel principal; esquinera
   por defecto del DS. `FRAME_MIN_PADDING` = 16 aplica con marco y `padding = -1`.
5. **`UIPanel` variante `OVERLAY` (opaca)** para el panel principal de la tienda; `POPUP`
   no se usa aquí.
6. **Tokens:** `BG_/BORDER_/TEXT_` para superficies, bordes y texto; `COLOR_*` para
   semántica (OK, error, oro). Ningún `Color(...)` literal en los ficheros de la tienda.
7. **Localización:** claves `SHOP_*` en el CSV de la tienda (o el que ya contenga las
   `SHOP_*`, ver Fase 0), sin claves comunes. Con parámetros mediante `tr()` +
   `%` (p. ej. `tr("SHOP_PLAYER_GOLD") % gold`).
8. **`ShopItemSlot` pasa a fila.** Se mantiene `class_name ShopItemSlot`, la señal
   `item_clicked(item_id, is_buy)` y `setup(item_data, buy_mode)`.
9. **El retrato del posadero es un placeholder** (muestra el del sheriff). **No es parte de
   este spike**: se diseñará uno propio más adelante. Se anota en el plan como pendiente de
   arte; la tienda no muestra retratos.

## 4. Fase 0 — comprobaciones antes de escribir código

Cada punto termina como "confirmado", "descartado" o "cambia el diseño".

| # | Comprobación | Por qué importa |
|---|---|---|
| 0.1 | Quién instancia/usa `ShopUI` y `ShopItemSlot` (orchestrator, tests, otras escenas). | Cambiar tipos o nombres sin romper consumidores. |
| 0.2 | Formato exacto del snapshot de `EconomySystem` (`items_for_sale`, `player_items_sellable`, claves de `item_data`: `item_id, display_name, quantity, unit_price, is_affordable, shop_can_afford, shop_has_slot`, ¿icono?, ¿categoría?). | La fila solo puede mostrar lo que hay. Si falta el icono, **no se añade al snapshot en este spike** (ver §7). |
| 0.3 | Claves `SHOP_*` existentes en los `.csv`, en qué fichero están y en qué orden de columnas (`id,en,es` o `id,es,en`). | Evitar duplicados (el último gana en silencio) y filas mal formadas. |
| 0.4 | Cómo recibe la tienda el foco/`ui_cancel` mientras es `CanvasLayer`: ¿otro nodo (orchestrator, pausa) también escucha Esc? | Esc debe cerrar una sola vez. |
| 0.5 | `layer` del `CanvasLayer` de la tienda frente a otros overlays y al HUD. | Que el panel opaco tape lo que debe. |
| 0.6 | Cómo se construye el `ShopItemSlot` en `_render_items` (instancia + `add_child` + `setup`) y si hay referencias externas a `has_method("_update_display")` (usado en `_set_all_buttons_enabled`). | Esa comprobación por nombre de método es frágil; decidir si se sustituye por un método público `set_action_enabled()`. |
| 0.7 | Comportamiento del préstamo `quest_loan` de la lanza: ¿qué aparece en `player_items_sellable` cuando la lanza está equipada y cuando está en el inventario? | Absorbido de la recopilación §6 (Spike 13). Ver §9. |
| 0.8 | Qué tiendas existen en `res://data/shops/*.tres` y cuál es la herrería de Los Telmori (`shop_id`). | Para la validación en partida. |
| 0.9 | Si `UIButton` emite `pressed` como `Button` (herencia) y cómo gestiona `disabled` y `tooltip_text`. | La fila depende de ello. |
| 0.10 | Capacidad real de la zona de lista: nº máximo de objetos de una tienda y del jugador vendibles. | Dimensionar el scroll y decidir lista única vs. dos columnas. |

**Paquete de comandos (cada uno en su bloque, PowerShell):**

```powershell
Get-ChildItem -Recurse -Include *.gd,*.tscn -Path . | Where-Object { $_.FullName -notmatch '\\(test|debug)' } | Select-String -Pattern 'ShopUI|ShopItemSlot|shop_ui|shop_item_slot|show_shop_direct' | Select-Object Path,LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Get-ChildItem -Recurse -Include *.csv -Path .\localization | Select-String -Pattern '^SHOP_' | Select-Object Path,LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Get-ChildItem -Recurse -Include *.csv -Path .\localization | ForEach-Object { $_.Name + ': ' + (Get-Content $_.FullName -TotalCount 1) }
```

```powershell
Select-String -Path .\systems\economy\*.gd -Pattern 'items_for_sale|player_items_sellable|unit_price|is_affordable|shop_can_afford|shop_has_slot|get_shop_snapshot|build_snapshot' | Select-Object Path,LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Get-ChildItem -Recurse -Path .\data\shops -Include *.tres | Select-Object FullName
```

```powershell
Select-String -Path .\autoload\*.gd,.\systems\*\*.gd -Pattern 'quest_loan' | Select-Object Path,LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Select-String -Path .\autoload\scene_orchestrator.gd -Pattern 'shop' -SimpleMatch | Select-Object LineNumber,Line | Format-Table -AutoSize -Wrap
```

*(Las rutas son orientativas: ajusta a la estructura real; si un comando no devuelve nada,
dímelo y lo reformulamos. Ignora ficheros `test*` y `debug*`.)*

Ficheros a adjuntar además de los ya conocidos: `ui_panel.gd`, `ui_button.gd`,
`ui_tokens.gd` (versión post-Spike 15), la salida de las búsquedas anteriores y el
`.csv` donde viven las `SHOP_*`.

## 5. Alcance

### 5.A Maqueta antes de código (obligatoria)

Antes de tocar nada, presentar **2-3 layouts** comparados contra tres casos reales
(tienda con 3 objetos / tienda con 10 / jugador con inventario largo):

- **Layout 1 — Dos columnas:** izquierda "Tienda" (objetos a la venta), derecha "Tu inventario"
  (vendibles); cabecera con nombre de la tienda, oro de ambos y huecos; pie con botón Cerrar.
- **Layout 2 — Pestañas Comprar / Vender** sobre una sola lista ancha (ahorra espacio, cuesta
  comparar y ver ambas bolsas de oro).
- **Layout 3 — Lista apilada** (tienda arriba, inventario abajo, como ahora, pero con filas).

La maqueta se evalúa en 1152×648 y en pantalla completa. **Espera mi elección antes de implementar.**
Hipótesis de partida **[a validar]**: el Layout 1 encaja mejor con filas y con 648 de alto,
porque el scroll vertical es independiente por columna.

### 5.B `shop_ui.tscn` y `shop_ui.gd`

- Raíz `CanvasLayer` se mantiene. Fondo atenuado opcional (token) detrás del panel.
- Panel principal: `UIPanel` variante `OVERLAY`, `decorative_frame = true`, centrado con anclas
  y tamaño por fracción de pantalla (p. ej. ancho ≈ 80 %, alto ≈ 85 %, con mínimos), no
  offsets fijos.
- Cabecera: nombre (token de tamaño de título), oro del jugador, oro de la tienda, huecos.
- Listas: `ScrollContainer` por columna con `VBoxContainer` de filas. Recordatorio de lecciones:
  **`ScrollContainer` con `size_flags_vertical = 3` reparte a partes iguales**; cuidar que el
  contenedor de scroll no colapse y comprobar los mínimos.
- Pie: `UIButton` (SECONDARY o GHOST, tamaño MD) "Cerrar", conservando `%CloseButton`.
- `FeedbackLabel`: se mantiene como `%FeedbackLabel`; colores desde tokens semánticos
  (`COLOR_*` de éxito/error) en lugar de `COLOR_FEEDBACK_OK/ERR`. Posición anclada dentro del
  panel (no flotando fuera de la caja).
- `_render_snapshot()` pasa a usar `tr()` con parámetros para oro, oro de la tienda y huecos.
- Sustituir la comprobación `slot.has_method("_update_display")` por un método público de
  `ShopItemSlot` (`set_action_enabled(bool)`), si 0.6 lo confirma.
- Entrada: mantener `_unhandled_input` con `ui_cancel`; verificar 0.4.

### 5.C `ShopItemSlot` como fila

Estructura propuesta (árbol de nodos para montar a mano):

```
ShopItemSlot (PanelContainer / UIPanel DEFAULT)
└─ MarginContainer
   └─ HBoxContainer
      ├─ IconRect            (se conserva %IconRect; ver nota)
      ├─ NameLabel           (expand, recorta con elipsis)
      ├─ QuantityLabel       ("x3", oculto si ≤ 1)
      ├─ PriceLabel          (alineado a la derecha, color por token)
      └─ ActionButton        (UIButton PRIMARY SM; "Comprar"/"Vender")
```

- Se conservan `%NameLabel, %PriceLabel, %QuantityLabel, %ActionButton, %IconRect`.
- **Estados** (no con `modulate` global): normal; **no asequible** (precio en color de error,
  botón deshabilitado, tooltip `SHOP_TOOLTIP_NO_GOLD`); **no disponible**
  (texto en `TEXT_MUTED`, botón deshabilitado, tooltip por `SHOP_TOOLTIP_NO_STOCK` o
  `SHOP_TOOLTIP_NO_SLOTS`).
- Hover/foco de teclado de la fila con tokens del DS; el foco debe verse.
- **Icono:** hoy es un `ColorRect` sin significado. Opciones a decidir en la maqueta:
  quitarlo, dejar un cuadro neutro con la inicial, o usar `UISlot` si el snapshot trae
  icono (0.2). **No se amplía el snapshot en este spike.**

### 5.D Localización (`SHOP_*`)

Claves nuevas mínimas (nombres orientativos; confirmar contra las existentes en 0.3):
`SHOP_PLAYER_GOLD` ("Oro: %d"), `SHOP_SHOP_GOLD` ("Oro de la tienda: %d"),
`SHOP_SLOTS` ("Huecos: %d/%d"), `SHOP_PLAYER_INVENTORY`, `SHOP_STOCK_TITLE`,
`SHOP_PRICE` ("%d de oro"), `SHOP_PRICE_SELL` ("+%d de oro"), `SHOP_BUY`, `SHOP_SELL`,
`SHOP_CLOSE`, `SHOP_TOOLTIP_NO_GOLD`, `SHOP_TOOLTIP_NO_STOCK`, `SHOP_TOOLTIP_NO_SLOTS`.
Convención `PANTALLA_ELEMENTO`; sin claves comunes; ES y EN. Campos con comas, entre
comillas. Si se crea un CSV nuevo, registrarlo a mano en *Project Settings → Localization →
Translations*. Godot resuelve claves duplicadas en silencio (gana la última): comprobar
duplicados con la búsqueda de 0.3.

### 5.E Tokens

Solo usar los de `UITokens` fusionado en el Spike 15. Si falta un color semántico (éxito,
error, oro), **se añade en `UITokens` con alias** y se documenta, no se deja como literal en
la tienda.

## 6. Cambio visual esperado (lista completa)

- Panel con marco decorativo opaco; botones y filas con el aspecto del DS.
- `ShopItemSlot` pasa de tarjeta 120×140 a fila.
- Textos de la tienda en el idioma del jugador (hoy mezcla inglés).
- Layout proporcional a la pantalla (hoy 800×600 fijo).
- Cualquier otro cambio visual es regresión.

## 7. Fuera de alcance

- Iconos reales de objetos o ampliación del snapshot de `EconomySystem`.
- Retratos (incluido el del posadero, placeholder pendiente de diseño propio).
- Cambios de reglas de comercio, precios, stock o `ShopViewModel`.
- Arrastrar y soltar, comparación de objetos, filtros u ordenación (→ Inventario, Spike 17).
- Cambios en `SceneOrchestrator` más allá de lo imprescindible tras la Fase 0.
- Sonidos y animaciones nuevas.

## 8. Reglas a respetar

- MVVM y antipatrones de `athelia_ui_architecture.md`: la View no toca sistemas.
- Cero `Color(...)` y cero tamaños de fuente literales en los ficheros de la tienda.
- Cero texto sin `tr()`.
- Nombres `%` conservados; `class_name` conservados.
- Setters `@export` se ejecutan antes de `_ready()`: usar `is_node_ready()`.
- Ficheros `.ps1` con acentos: guardarlos en ASCII (PowerShell 5.1).
- Aviso inmediato si algo rompe un contrato.

## 9. Validación en partida real

Con capturas antes/después y a 1152×648 y en pantalla completa, en ES y EN:

1. Abrir la tienda desde un NPC (herrería de Los Telmori): se ve el panel proporcional, sin recortes.
2. **Comprar** un objeto: oro del jugador baja, huecos y stock actualizados, feedback verde.
3. **Vender** un objeto: oro sube, feedback verde.
4. **Oro insuficiente:** botón deshabilitado + tooltip; intentar vía teclado no hace nada.
5. **Tienda sin hueco** al vender: botón deshabilitado + tooltip `SHOP_TOOLTIP_NO_SLOTS`.
6. **Sin stock / sin presupuesto de la tienda:** mensaje de error correcto (claves `SHOP_ERROR_*`).
7. **Esc** cierra una sola vez; **botón Cerrar** también; tras cerrar se vuelve a exploración
   (`shop_closed` → `enter_exploration()`), sin overlays huérfanos.
8. Reabrir la tienda tras cerrar: sin filas duplicadas ni fugas (`queue_free`).
9. **Lanza `quest_loan`:** con la lanza **equipada** no debe poder venderse (o debe comportarse como
   documente la Fase 0); con la lanza **en el inventario** y vendida, el estado de la misión
   sigue coherente. Documentar el comportamiento real encontrado.
10. Cambio de idioma ES↔EN sin claves en bruto visibles.
11. Reinicio de sesión (Spike 14) tras Game Over: la tienda carga sus definiciones de
    `res://data/shops/*.tres` y abre bien.
12. Output sin warnings nuevos (especialmente del marco de `UIPanel` ni "Razón desconocida").

## 10. Riesgos conocidos

- Dos columnas con `ScrollContainer` pueden repartir la altura a partes iguales y dejar la zona
  útil pequeña a 648 de alto.
- `modulate` heredado: si se mantiene en alguna parte, apaga también el botón y distorsiona tokens.
- Cambiar `Button` por `UIButton` puede alterar `disabled`/`tooltip`/foco (0.9).
- Esc duplicado si otro nodo también escucha `ui_cancel` (0.4).
- Claves `SHOP_*` duplicadas o fila mal formada en el `.csv` (cuidar comillas).
- El snapshot puede no traer lo que la maqueta supone (0.2): limitar la maqueta a lo existente.
- La lanza `quest_loan` puede revelar un bug de lógica ajeno a la UI: se documenta y se abre
  pendiente, no se arregla dentro de este spike salvo que sea trivial.

## 11. Entregables

**Código (completo):** `shop_ui.gd`, `shop_item_slot.gd`. **Escenas** como árbol de nodos
legible: `shop_ui.tscn`, `shop_item_slot.tscn`. **Datos:** `.csv` con las claves `SHOP_*`
(ES y EN). **Posible parche:** `ui_tokens.gd` si falta algún color semántico.

**Documentación:**
- `docs/spike_16_tienda.md` (informe de cierre: layout elegido y por qué, ficheros tocados,
  claves nuevas, validación hecha, comportamiento de `quest_loan`, lecciones y pendientes).
- `athelia_ui_architecture.md` y `README.md`: la tienda como primera pantalla del DS y
  el patrón "fila".
- `athelia_lecciones_tecnicas.md` y `athelia_historial_spikes.md`: entrada del Spike 16.
- Plan del hito: marcar el 16 como cerrado y añadir pendientes nuevos.
- Recopilación de pendientes: marcar resuelto lo de la tienda y registrar lo de `quest_loan`.
