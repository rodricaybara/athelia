# Spike 16b — Préstamo de la lanza en la tienda (informe de cierre)

**Fecha de cierre:** 2026-10-21 · **Godot:** 4.7.x · **Estado:** cerrado; validado en partida real salvo lo marcado en §5
**Origen:** pendiente abierto en el Spike 16 (§7 y §9 de `docs/spike_16_tienda.md`) · **Siguiente:** Spike 16c

---

## 1. Problema

La herrería de Los Telmori tenía `enchanted_spear` en su stock, pero `buy_item` y `sell_item`
rechazan cualquier objeto con `base_value <= 0` (`INVALID_ITEM`) y la lanza tiene `base_value = 0`.
Resultado: aparecía con "0 de oro" y el botón activo, y al pulsarlo salía "Ítem inválido". Como
la herrería sustituyó a las escenas de equipamiento (decisión del Spike 13, opción A) y las
escenas `telmori_equipment_*` son huérfanas (`telmori_equipment_arrows` solo se referencia a sí
misma), la lanza **no se podía conseguir**: un bloqueo de la aventura, no una rareza.

## 2. Decisión (opción B)

La tienda usa el tag `quest_loan`, que ya tenía la lanza, para tratarla como préstamo:

- Se toma de la tienda **sin coste** (sin oro, sin presupuesto, sin `PriceCalculator`).
- **No se puede vender**, ni estando en el inventario del jugador.
- La fila muestra "Préstamo" en lugar del precio y el botón dice "Tomar".

Las opciones descartadas: dar un `base_value` pequeño (se cobraría y se podría vender, y el tag
seguiría sin significar nada) y quitar la lanza del stock (deshace parte de la decisión del
Spike 13). La devolución al sheriff queda fuera de este spike (Spike 16c).

## 3. Cambios

| Fichero | Cambio |
|---|---|
| `core/economy/economy_system.gd` | Constante `LOAN_TAG`; `_is_loan_item()`, `_take_loan()` y `_execute_loan_transaction()` nuevos; desvío en `buy_item()`; rechazo `LOAN_ITEM` en `sell_item()`; `is_loan` en los dos snapshots, con precio 0 sin pasar por `PriceCalculator` |
| `ui/shop/shop_viewmodel.gd` | `_success_message_key()` (`"loan"` → mensaje de préstamo) y `LOAN_ITEM` en `_error_message()` |
| `ui/shop/shop_item_slot.gd` | `is_loan`: precio "Préstamo" (`COLOR_INFO`), botón "Tomar" en la tienda y botón de vender deshabilitado con tooltip en el inventario |
| `localization/shops.csv` | 5 claves nuevas (`id,en,es`) |

La escena `shop_item_slot.tscn` y `shop_ui.gd` no cambian. `trade_type` gana el valor `"loan"`;
solo `ShopViewModel` y el log de `EventBus` escuchan `shop_trade_success`, así que no rompe a
nadie. Se ha comprobado con búsqueda en el código.

## 4. Claves nuevas (`shops.csv`)

`SHOP_PRICE_LOAN` (Préstamo), `SHOP_TAKE` (Tomar), `SHOP_TOOLTIP_LOAN` (Es un préstamo: no se
puede vender), `SHOP_TRADE_LOANED` (Recibido en préstamo: %s x%d), `SHOP_ERROR_LOAN_ITEM`.

## 5. Validación en partida real

| # | Prueba | Resultado |
|---|---|---|
| 1 | La lanza en la tienda | "Préstamo" (azul) y "Tomar" activo |
| 2 | Pulsar "Tomar" | Mensaje "Recibido en préstamo: Lanza encantada x1"; oro sin cambio (6); "Huecos" 12/16 → 11/16; la lanza aparece en el inventario con "Préstamo" y "Vender" apagado; tooltip "Es un préstamo: no se puede vender". Log: `shop_trade_success ← type=loan` y `Loan successful: enchanted_spear x1` |
| 3 | Aventura completa y entrega al sheriff | El sheriff **no** quita la lanza: `take_item: enchanted_spear no está en el inventario de player — nada que quitar` (ver §6) |
| 4 | Ausencia del warning de `PriceCalculator` en *Errors* | Sin confirmar |
| 5 | Equipar la lanza y comprobar que no se vende | Sin confirmar |
| 6 | Derrota → partida nueva: la herrería recupera la lanza | Sin confirmar |
| 7 | Compra y venta normales tras el parche | Sin confirmar (no hay transacciones en el log) |

El camino `LOAN_ITEM` de `sell_item` no se puede provocar desde la UI (el botón está apagado):
queda como código de seguridad sin probar.

## 6. Hallazgo: la devolución no funciona si la lanza no está en el inventario del jugador

`narrative_scene_viewmodel.gd:365-374` ejecuta `take_item` solo sobre `take_item_target` (por
defecto `"player"`): desequipa y quita el objeto de ese inventario, y si no lo encuentra imprime
"nada que quitar" y continúa. En la partida validada ocurrió exactamente eso al terminar la
aventura. Se interpreta (inferido, a confirmar) que la lanza estaba con la compañera Mira, que es
lo previsto. Es el caso del **Spike 16c**: el préstamo no se devuelve, y la aventura termina sin
avisar.

## 7. Lecciones técnicas

1. **El orden de las validaciones define el comportamiento.** La regla de negocio que ya estaba
   en los datos (el tag `quest_loan`) debía consultarse **antes** de la comprobación genérica
   (`base_value <= 0`) y no al final.
2. **Un valor nuevo en un `String` de contrato** (`trade_type = "loan"`) es compatible solo si
   se verifica quién escucha la señal; aquí, ViewModel y log. Se comprobó con búsqueda.
3. **Parchear funciones largas de un fichero grande** funciona mejor con bloques
   «buscar → sustituir» que con el fichero completo, vigilando las comas al añadir claves a un
   diccionario.
4. **Mover objetos entre entidades invalida suposiciones de contenido:** una acción narrativa que
   asume el inventario del jugador falla en silencio cuando el jugador ha traspasado el objeto.

## 8. Pendientes

- **Spike 16c:** devolución del préstamo cuando la lanza la tiene un compañero (o si ya no existe).
- Sin confirmar en partida: puntos 4–7 de §5.
- Siguen abiertos los pendientes de `docs/spike_16_tienda.md` que no tocan al préstamo:
  vender objeto equipado, comprar con inventario lleno, `accepted_tags` sin aplicar,
  `INSUFFICIENT_STOCK` sin traducir, doble `create_shop_snapshot`, contraste de botones
  deshabilitados, efecto de la poción de vida (10 vs 50) y `ITEM_HEALTH_POTION_*` en `items.csv`.
