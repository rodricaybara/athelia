# Spike 16 — Tienda (informe de cierre; incluye la 16b)

**Fecha de cierre:** 2026-10-21 · **Godot:** 4.7.x · **Estado:** cerrado y validado en partida real
**Hito:** rediseño de interfaces · **Riesgo:** bajo · **Dependía de:** Spike 15
**Partes:** **A** (Spike 16) rediseño de la tienda con el Design System · **B** (Spike 16b) préstamo `quest_loan`.
**Fuera de este informe:** Spike 16c (devolución del préstamo al sheriff), sin planificar (ver §7).

---

## 1. Resumen

**Parte A.** La tienda es la primera pantalla del hito que adopta el Design System de verdad: `UIPanel`
(variante `OVERLAY`, con marco decorativo), `UIButton`, `UITokens`, layout por anclas y fracciones,
textos localizados (`SHOP_*`) y `ShopItemSlot` convertido en una fila. Mismo flujo de apertura y
cierre, misma API pública. Disposición tomada de una captura de The Witcher 3 (sin copiarla): dos
columnas, inventario del jugador a la izquierda, tienda a la derecha, oro en la cabecera de cada
columna y botón de cierre arriba a la derecha.

**Parte B.** La lanza encantada de la herrería de Los Telmori no se podía comprar ni vender
(`base_value = 0` → `INVALID_ITEM`) y, al ser la herrería el único camino para conseguirla,
bloqueaba la aventura. `EconomySystem` pasa a tratar el tag `quest_loan` como préstamo: se toma sin
coste, no se vende, y la fila muestra "Préstamo" y "Tomar". Es el primer cambio del hito que toca el
core.

## 2. Parte A — Rediseño de la tienda

### 2.1 Decisiones finales y cambios respecto a la spec

| # | Decisión | Spec |
|---|---|---|
| 1 | Layout de dos columnas: jugador a la izquierda, tienda a la derecha | La spec no fijaba el orden |
| 2 | Panel al 90 % × 90 % (anclas 0.05–0.95) | Ejemplo: 80 % × 85 % |
| 3 | Cierre arriba a la derecha, sin pie (gana ~52 px: 9 filas visibles a 648, 17 a 1050) | Pie con botón |
| 4 | `%IconRect` pasa de `ColorRect` a `TextureRect` oculto (gancho para iconos) | Quitar, cuadro neutro o `UISlot` |
| 5 | `layer = 10` (lo fija el script) | Pendiente de la Fase 0 |
| 6 | `set_busy(bool)` en la fila sustituye a `has_method("_update_display")`; los botones ya no se reactivan por encima del estado de la fila | §5.B |
| 7 | Mensaje en listas vacías (`SHOP_EMPTY_STOCK`, `SHOP_EMPTY_INVENTORY`) | Elemento nuevo, aprobado |
| 8 | Tooltip `SHOP_TOOLTIP_NO_BUDGET` en venta cuando la tienda no puede pagar | La spec lo trataba como "sin oro" |
| 9 | `ShopViewModel._on_trade_success`: distingue compra/venta y muestra el nombre visible (antes, siempre "Comprado" y el id interno) | §3.2: ViewModel intacto |
| 10 | Hover de fila (`BG_RAISED` / `BORDER_ACCENT`) y tooltip con el nombre completo | Añadidos al validar |
| 11 | La tienda no toma foco de teclado al abrir | Como hasta ahora |
| 12 | Tira de mensaje de altura reservada (texto vacío en lugar de `visible = false`) | `FeedbackLabel` flotante |

### 2.2 Lo que la Fase 0 corrigió de la spec

- **Los botones nunca quedaban deshabilitados:** `_render_snapshot` terminaba con
  `_set_all_buttons_enabled(true)` y pisaba el estado de cada fila.
- **El snapshot no es homogéneo:** `shop_can_afford`, `shop_has_slot` y `total_price` solo existen en
  `player_items_sellable`. Sin icono ni categoría; `ItemDefinition.icon` existe, pero el snapshot no
  lo transporta.
- **Tooltip equivocado:** en venta, "la tienda no puede pagar" decía "Not enough gold".
- **Capas:** `ShopUI` no fijaba `layer` (1) frente a los overlays (10) y el HUD (5). `SceneOrchestrator`
  cuelga los `CanvasLayer` del `root`, no del layer del orquestador.
- **Nodos `%` no listados:** el `.tscn` tenía `%ShopPanel` y `%PlayerItemsScroll`.
- **Rutas del paquete de comandos:** `core/economy/`, no `systems/`.
- **Mensaje de éxito:** ignoraba `trade_type` y usaba el id crudo.

## 3. Parte B — Préstamo `quest_loan` (Spike 16b)

### 3.1 Problema

`buy_item` y `sell_item` rechazan cualquier objeto con `base_value <= 0` (`INVALID_ITEM`) y la lanza
tiene `base_value = 0`. Aparecía en el stock con "0 de oro" y el botón activo, y al pulsarlo salía
"Ítem inválido". Como la herrería sustituyó a las escenas de equipamiento (decisión del Spike 13,
opción A) y las escenas `telmori_equipment_*` son huérfanas (`telmori_equipment_arrows` solo se
referencia a sí misma), la lanza **no se podía conseguir**: un bloqueo de la aventura, no una rareza.

### 3.2 Decisión (opción B)

La tienda usa el tag `quest_loan`, que ya tenía la lanza:

- Se toma de la tienda **sin coste** (sin oro, sin presupuesto, sin `PriceCalculator`).
- **No se puede vender**, ni estando en el inventario del jugador.
- La fila muestra "Préstamo" en lugar del precio y el botón dice "Tomar".

Descartadas: dar un `base_value` pequeño (se cobraría y se podría vender, y el tag seguiría sin
significar nada) y quitar la lanza del stock (deshace parte de la decisión del Spike 13).

### 3.3 Cambios

| Fichero | Cambio |
|---|---|
| `core/economy/economy_system.gd` | Constante `LOAN_TAG`; `_is_loan_item()`, `_take_loan()` y `_execute_loan_transaction()` nuevos; desvío en `buy_item()`; rechazo `LOAN_ITEM` en `sell_item()`; `is_loan` en los dos snapshots, con precio 0 sin pasar por `PriceCalculator` |
| `ui/shop/shop_viewmodel.gd` | `_success_message_key()` (`"loan"` → mensaje de préstamo) y `LOAN_ITEM` en `_error_message()` |
| `ui/shop/shop_item_slot.gd` | `is_loan`: precio "Préstamo" (`COLOR_INFO`), botón "Tomar" en la tienda y botón de vender deshabilitado con tooltip en el inventario |

`trade_type` gana el valor `"loan"`. Solo `ShopViewModel` y el log de `EventBus` escuchan
`shop_trade_success`, así que no rompe a nadie (comprobado con búsqueda en el código).

## 4. Ficheros tocados (A y B)

- `ui/shop/shop_ui.gd` (reescrito), `ui/shop/shop_ui.tscn` (reconstruido).
- `ui/shop/shop_item_slot.gd` (reescrito, `extends UIPanel`; ampliado en la B), `ui/shop/shop_item_slot.tscn`.
- `ui/shop/shop_viewmodel.gd` (`_on_trade_success` y helpers; ampliado en la B).
- `core/economy/economy_system.gd` (solo parches de la B).
- `localization/shops.csv` (23 claves nuevas, columnas `id,en,es`).
- Sin parche en `ui_tokens.gd`: los tokens necesarios ya existían.

**Claves nuevas (`shops.csv`).** Parte A (18): `SHOP_STOCK_TITLE`, `SHOP_PLAYER_INVENTORY`,
`SHOP_PLAYER_GOLD`, `SHOP_SHOP_GOLD`, `SHOP_SLOTS`, `SHOP_PRICE`, `SHOP_PRICE_SELL`, `SHOP_QUANTITY`,
`SHOP_BUY`, `SHOP_SELL`, `SHOP_CLOSE`, `SHOP_TOOLTIP_NO_GOLD`, `SHOP_TOOLTIP_NO_STOCK`,
`SHOP_TOOLTIP_NO_SLOTS`, `SHOP_TOOLTIP_NO_BUDGET`, `SHOP_EMPTY_STOCK`, `SHOP_EMPTY_INVENTORY`,
`SHOP_TRADE_SOLD`. Parte B (5): `SHOP_PRICE_LOAN` (Préstamo), `SHOP_TAKE` (Tomar),
`SHOP_TOOLTIP_LOAN` (Es un préstamo: no se puede vender), `SHOP_TRADE_LOANED` (Recibido en préstamo:
%s x%d), `SHOP_ERROR_LOAN_ITEM`. `SHOP_TRADE_SUCCESS` (compra) sigue en `translations.csv`, sin
cambios. Sin duplicados (comprobado con `Group-Object`).

## 5. Validación en partida real

### Parte A

| # | Prueba | Resultado |
|---|---|---|
| 1 | Abrir la herrería de Los Telmori | Correcto a 1152×648 y 1680×1050 (13 filas sin scroll a 1050; ~9,5 a 648) |
| 2 | Comprar | Correcto; "Comprado: <nombre> xN" en verde |
| 3 | Vender | Correcto; "Vendido: <nombre> xN" |
| 4 | Oro insuficiente | Botón apagado + tooltip "Oro insuficiente" |
| 5 | Tienda sin presupuesto o sin hueco | **No probado:** no se puede provocar con las tiendas actuales; comparte rama de código con el punto 4 |
| 6 | Listas vacías | Inventario vacío: correcto. Tienda vacía: **no probado** (haría falta mucho oro) |
| 7 | Esc y botón Cerrar | Una sola `shop_close_requested`; vuelve a exploración; sin filas duplicadas al reabrir |
| 8 | Doble compra rápida | Funciona (la transacción es síncrona; `set_busy` dura menos que un clic) |
| 9 | ES / EN | Sin claves en bruto |
| 10 | Derrota → partida nueva | La tienda recupera su stock original |
| 11 | Pestaña *Errors* | Solo el warning de `PriceCalculator` por la lanza; ninguno de `UIPanel` ni `ShopUI` |

Los `push_warning` van a la pestaña *Errors* del depurador, no al Output.

### Parte B

| # | Prueba | Resultado |
|---|---|---|
| 1 | La lanza en la tienda | "Préstamo" (azul) y "Tomar" activo |
| 2 | Pulsar "Tomar" | Mensaje "Recibido en préstamo: Lanza encantada x1"; oro sin cambio (6); "Huecos" 12/16 → 11/16; la lanza aparece en el inventario con "Préstamo" y "Vender" apagado; tooltip "Es un préstamo: no se puede vender". Log: `shop_trade_success ← type=loan` y `Loan successful: enchanted_spear x1` |
| 3 | Aventura completa y entrega al sheriff | El sheriff **no** quita la lanza: `take_item: enchanted_spear no está en el inventario de player — nada que quitar` (ver §7, 16c) |
| 4 | El warning de `PriceCalculator` por la lanza ya no sale en *Errors* | Sin confirmar |
| 5 | Equipar la lanza y comprobar que no se vende | Sin confirmar |
| 6 | Derrota → partida nueva: la herrería recupera la lanza | Sin confirmar |
| 7 | Compra y venta normales tras el parche | Sin confirmar (no hay transacciones en el log) |

El camino `LOAN_ITEM` de `sell_item` no se puede provocar desde la UI (el botón está apagado): queda
como código de seguridad sin probar en partida.

## 6. Lecciones técnicas

**De la parte A**

1. **Un `PanelContainer` apila todos sus hijos superpuestos.** Un nodo mal anidado (dentro del panel
   de cabecera en lugar de la columna, o el mensaje fuera del `VBoxContainer`) no falla: se dibuja
   encima. Al montar una escena a mano, verificar el padre de cada nodo; mejor entregar el `.tscn`
   completo.
2. **Una raíz que `extends UIPanel` debe fijar `padding` antes de `super._ready()`:** el estilo se
   aplica en el `_ready()` de `UIPanel` con el padding que tenga en ese momento.
3. **Tipar `@onready` con una clase de componente delata instancias equivocadas:** instanciar
   `option_button.tscn` donde iba `ui_button.tscn` falla en `@implicit_ready` con "Trying to assign
   value of type 'Button' to a variable of type 'ui_button.gd'", no con un error de nodo.
4. **Reconstruir listas:** `remove_child()` antes de `queue_free()`. Si no, la fila vieja sigue
   ocupando sitio en el layout hasta el final del frame.
5. **Un `Label` con elipsis tiene anchura mínima 0:** en un contenedor que no expande, la fila
   colapsa. Hace falta un suelo (`ROW_MIN_WIDTH`) o expandir el contenedor.
6. **`mouse_exited` se emite en el padre al entrar en un hijo:** para un hover de fila, solo cuenta
   como salida si el ratón ya no está dentro de `get_global_rect()`.
7. **Altura reservada para mensajes:** vaciar el texto en lugar de ocultar el `Label` evita que el
   layout salte.
8. **Estado visual por fila con tokens y `disabled`,** no con `modulate` del contenedor: `modulate`
   apaga también botón y texto sin pasar por tokens.
9. **No comprobar métodos por nombre** (`has_method("_update_display")`): método público explícito
   (`set_busy`).
10. **`Dictionary.get()` tipado:** `x.get("k", 0) as int` o `if v is Texture2D` con `Variant`
    explícito, nunca `:=`.

**De la parte B**

11. **El orden de las validaciones define el comportamiento.** La regla de negocio que ya estaba en
    los datos (el tag `quest_loan`) debía consultarse **antes** de la comprobación genérica
    (`base_value <= 0`), no al final.
12. **Un valor nuevo en un `String` de contrato** (`trade_type = "loan"`) es compatible solo si se
    verifica quién escucha la señal; aquí, ViewModel y log.
13. **Parchear funciones largas de ficheros grandes** funciona mejor con bloques «buscar →
    sustituir» que con el fichero completo, vigilando las comas al añadir claves a un diccionario.
14. **Mover objetos entre entidades invalida suposiciones de contenido:** una acción narrativa que
    asume el inventario del jugador falla en silencio cuando el jugador ha traspasado el objeto.

## 7. Pendientes (fuera del spike)

- **Spike 16c — devolución del préstamo (sin planificar).** `take_item` del sheriff
  (`narrative_scene_viewmodel.gd:365-374`) solo actúa sobre `take_item_target` (`"player"`); si la
  lanza está en el inventario de un compañero, imprime "nada que quitar" y la aventura termina sin
  devolverla. Confirmado en partida (§5, parte B, punto 3); se interpreta, sin confirmar, que la
  lanza estaba con Mira.
- **Sin confirmar en partida:** parte B, puntos 4–7; tooltips `NO_BUDGET` / `NO_SLOTS`, tienda vacía
  y el camino `LOAN_ITEM`.
- **Vender un objeto equipado** (inferido, sin probar): `equip_item` no saca el objeto del inventario
  y `sell_item` solo comprueba `has_item`; podría quedar un slot de equipo apuntando a un objeto
  vendido.
- **Comprar con inventario lleno:** `buy_item` omite la validación de espacio ("InventorySystem no
  tiene `can_add_item`").
- **`accepted_tags` sin aplicar** en `ShopInstance.can_buy_from_player` (hay un `TODO`) e
  **`INSUFFICIENT_STOCK` sin traducir** en `ShopViewModel._error_message`.
- **Doble `create_shop_snapshot` al abrir:** el orquestador lo calcula y `shop_open_requested` vuelve
  a hacerlo. Inofensivo; limpieza.
- **`print` de depuración** en `_get_player_items_sellable` (unas 10 líneas por apertura).
- **Botones deshabilitados con poco contraste** (`COLOR_TEXT_DISABLED` sobre fondo bronce oscuro):
  es del Design System (`UIButton`), no de la tienda. Decisión aplazada.
- **Poción de vida:** `ITEM_HEALTH_POTION_NAME` (`items.csv`, línea 4) ya corregido por el autor;
  `ITEM_HEALTH_POTION_DESC` (línea 5) con espacio inicial en ES y con efecto inconsistente: EN "10",
  ES "50" y `health_potion.tres` `value = 10.0`. Decisión aplazada.
- **Iconos y descripción en tooltip:** `ItemDefinition.icon` y `description_key` existen; falta que
  `EconomySystem` los incluya en el snapshot. La fila ya muestra `icon` si llega. Spike 18.
- **Retrato del posadero:** sigue siendo un placeholder; la tienda no usa retratos.

## 8. Siguiente

Spike 17 (Inventario A: contrato MVVM). La fila de lista y el patrón de dos columnas con cabecera son
reutilizables en Party (Spike 19). La 16c se abrirá aparte, con su propia Fase 0.
