# Spike 19 — Party: rediseño con el Design System (19a)

**Estado:** cerrado en código y validado en partida real por Fernando el 2026-10-26, con las excepciones de la §9 (pruebas no reportadas).
**Hito:** rediseño de interfaces, spikes 14–24. **Depende de:** 18 (`UISlot`, patrón de overlay a pantalla completa).
**Partición:** este informe es el **19a**. Lo que quedó fuera (mochila a mochila, cajetín de detalle, estado del compañero, regla de objetos de préstamo) pasa al **19b** (§11).
**Resumen:** Party se rehace con `UIPanel` (OVERLAY + marco), `UIButton`, `UISlot` y solo `UITokens`. Muestra la capacidad real de cada personaje, cumple el contrato MVVM, da feedback localizado y corrige el orden de la transferencia. `item_slot` y `equip_slot` quedan retirados.

---

## 1. Alcance y reglas respetadas

- Vista pasiva; `PartyViewModel` es hijo de la View y el único que habla con los sistemas core.
- Contratos públicos intactos: `open()`, `close()`, `toggle()`, `closed`, `layer = 10`, cierre por `open_party` y `ui_cancel` (la View consume la tecla).
- `SceneOrchestrator` no se toca. Dos contextos de apertura: overlay del orquestador (`O`) y sub-overlay narrativo.
- Referencia de diseño: **1680×1050 a pantalla completa** (decidido durante el spike); mínimo 1152×648.
- Sin `Color(...)` literales ni tamaños de fuente sueltos; todo texto por `tr()` con claves `PARTY_*`.
- No se corrige lo que exige cambio de core (ver §11).

## 2. Decisiones tomadas

| Tema | Decisión |
|---|---|
| P1 transferencia entre mochilas | Fuera del 19a (→ 19b). Hoy solo se transfiere soltando una pieza sobre un slot de equipo |
| P2 capacidad | «Huecos usados/capacidad» por columna; sin peso |
| P3 estrategia | `OptionButton` estilizado por código, mapeado por id de enum; solo nombres (no existen descripciones en datos) |
| P4 detalle | Solo tooltips con nombre y cantidad; el `ItemDetailPanel` con comparación → 19b |
| P5 estado del compañero | → 19b |
| P6 feedback | `FeedbackPopup` del inventario, alimentado por la razón `feedback` |
| P7 varios compañeros | Máximo 2 (decidido). Con 1 compañero, rótulo con su nombre; con 2 o más, pestañas |
| P8 objetos de préstamo | Sin cambio de comportamiento; documentado (§8) → 19b |
| D1 capacidad compartida | Helper estático `BagCapacity` fuera de ambos ViewModels (no toca el core) |
| D3 mochila llena | No se bloquea la transferencia; el ítem sale con borde de desbordamiento |
| Q1 | El origen desequipa el ítem antes de transferirlo |
| Q2 | Si el destino ya tiene una copia, se equipa la suya y no se transfiere |
| Layout | **L3**: equipo en columna vertical de 6 `UISlot` de 64 px a la izquierda de cada mochila |
| Estrategias | Aggressive/Agresiva, Defensive/Defensiva, Area attack/Ataque en área, Berserker/Berserker (el id interno sigue siendo `AREA_FOCUS`) |

## 3. Layout final

```
PartyUi (CanvasLayer, layer 10)
├── Backdrop (ColorRect, opaco, mouse STOP)
├── Frame (UIPanel OVERLAY, padding 16, marco decorativo; rect calculado en código)
│   └── Root (VBox)
│       ├── Header: TitleLabel · Spacer · CloseButton (UIButton GHOST, min_square 32)
│       └── Content (HBox)
│           ├── PlayerColumn: PlayerHeader (nombre · huecos) / PlayerBody (PlayerEquipList | PlayerBagScroll > PlayerBagGrid)
│           ├── Separator (VSeparator)
│           └── CompanionColumn: CompanionTabs (≥2 compañeros) / CompanionHeader (nombre · estrategia · huecos)
│                                / CompanionBody (CompanionEquipList | CompanionBagScroll > CompanionBagGrid) / NoCompanionsLabel
└── FeedbackPopup
```

Constantes: `FRAME_FRACTION = 0.9`, `FRAME_MAX_SIZE = Vector2(1400, 820)`, `BAG_GAP = 8`, `SCROLLBAR_RESERVE = 12`, `POPUP_MARGIN = 8`.
`_update_frame_rect()` se conecta a `size_changed`; `_update_grid_columns()` ajusta las columnas de cada mochila al ancho real (8 a 1680×1050, 5 a 1152×648). El aviso se ancla al borde inferior del marco.

Medidas calculadas (no tomadas en pantalla): altura útil bajo la cabecera ≈744 px a pantalla completa y ≈507 px a 1152×648; la columna de equipo ocupa 424 px, y con pestañas y estrategia el compañero llega justo al borde inferior a 1152×648 (cabe). A pantalla completa sobran ≈280 px bajo las columnas, reservados para el cajetín del 19b.

## 4. Ficheros

**Nuevos**
- `ui/inventory/bag_capacity.gd` (`class_name BagCapacity`)
- `localization/party.csv` (`id,en,es`; 27 claves `PARTY_*`)

**Reescritos**
- `ui/party/party_viewmodel.gd`, `ui/party/party_ui.gd`, `ui/party/party_ui.tscn` (conserva el UID de la escena)

**Modificados**
- `ui/design_system/components/ui_slot/ui_slot.gd` (4 parches, ver §7)
- `ui/inventory/inventory_viewmodel.gd` (`_compute_capacity()` delega en `BagCapacity`)
- `localization/translations.csv` (retiradas las 3 claves `PARTY_ERROR_*` de las líneas 18–20; ahora viven en `party.csv`)

**Retirados:** `ui/inventory/item_slot.gd/.uid/.tscn` y `ui/inventory/equip_slot.gd/.uid/.tscn` (copia en `ui_slots_retirados`).

**Sin tocar:** `scene_orchestrator.gd`, `narrative_scene_panel.gd`, `inventory_ui.gd/.tscn`, `player_menu_*`.

**Temporal, no entra en el entregable:** `debug_party_tool.gd` (autoload `DebugPartyTool`; F10 saca a Mira, F11/F12 entra y sale un compañero de prueba). Se retira al cerrar.

## 5. `PartyViewModel`

- Data classes propias: `BagEntry` (definición, cantidad, `is_equipped`, `is_overflow`), `EquipEntry`, `ColumnData` (nombre, capacidad, huecos usados, estrategia activa, equipo y mochila), `StrategyOption`, `CompanionTab`. La View no necesita `ItemInstance` ni toca `Inventory`.
- Razones de `changed`: `opened`, `player_column`, `companion_column`, `companion_changed`, `party_changed` (nueva: entra o sale un compañero con la pantalla abierta), `feedback` (nueva), `closed`. La View tiene su caso para cada una.
- Refresco agrupado con `_mark_dirty()` diferido (una transferencia emite varias señales seguidas).
- Intenciones: `open`, `request_close`, `select_companion`, `request_set_strategy(id)`, `request_slot_action`, `request_unequip`, `request_equip_drop(slot, ítem, destino, origen)`.
- Feedback: escucha `item_equipped`, `item_unequipped`, `equip_failed`, `item_use_success`/`failed`, filtrando por las dos entidades visibles. Los motivos de fallo (texto libre en inglés del core) solo van a la consola; el jugador ve un mensaje genérico localizado. Un mismo mensaje repetido en el mismo frame se descarta.
- No hace falta el filtro de eco de `equip_failed` del inventario: Party equipa con `Equipment` directamente y no pasa por el puente de ítems.

### Orden de `request_equip_drop`

1. Valida `can_equip_in_slot` antes de mover nada; si falla, mensaje y fin.
2. Si el destino ya tiene copia del ítem, equipa la suya (Q2) y no transfiere.
3. Si no: origen real del payload (`owner_id`), desequipa en el origen si estaba equipado (Q1), transfiere con rollback y equipa en el destino. Si el equipado falla, revierte la transferencia y reequipa en el origen.
4. Un indicador suprime los mensajes intermedios; sale uno solo al final.

## 6. `BagCapacity`

`BagCapacity.compute(definition, used_count, entity_id = "")` devuelve `definition.inventory_slots`, o `used_count` con aviso si no hay definición. Cada ViewModel resuelve la definición con `Characters.get_character_definition()` y delega solo la regla. Es el punto único donde entrará cualquier mecanismo futuro de aumento de capacidad.

## 7. `UISlot` — cambios (aditivos)

- `@export var owner_id: String = ""`: id opaco de la entidad dueña del slot. El componente no lo interpreta ni accede a sistemas.
- El payload del arrastre incluye `"owner_id"`.
- Señal nueva `slot_item_dropped(slot, source_item_id, from_owner_id)`, emitida justo después de `slot_drop_received`, que sigue existiendo. El inventario no cambia (owner vacío, sin oyentes de la nueva).

## 8. Comportamiento corregido

Reproducido en partida real antes de tocar código (a 1680×1050) y verificado después.

| Hallazgo previo | Antes | Ahora |
|---|---|---|
| Límite de 8 ítems por mochila | El noveno ítem no se veía | Capacidad real (20 jugador, 15 Mira); desbordamiento con borde discontinuo |
| Drop rechazado que ya transfería | `Transferido: health_potion … → companion_mira` seguido de `Drop rechazado` | Se valida el slot antes; el ítem no cambia de dueño |
| Origen conservaba el ítem equipado | La lanza quedaba equipada en el jugador y en Mira a la vez | El origen desequipa antes de transferir |
| Ownership del arrastre | Se tomaba siempre la copia del jugador | El origen sale del payload (`owner_id`) |
| Textos sin localizar | «Jugador», «Mochila», «Sin companions», estrategias con claves crudas del enum | Claves `PARTY_*` |
| Drops rechazados solo por consola | `print` | Feedback visible |
| `_render_column()` llamaba a `Inventory.get_inventory()` | Violaba el contrato | La View no accede a ningún sistema |
| Celdas que se estiraban | `ItemSlot`/`EquipSlot` crecían con la columna | `UISlot` de 64 px fijos |

**Objetos `quest_loan` (P8):** Party sigue permitiendo pasar la lanza prestada a un compañero y equiparla (confirmado en partida: `Transferido: enchanted_spear × 1 player → companion_mira`). Es coherente con la hipótesis de la 16c (`take_item` del sheriff solo actúa sobre `"player"`), que **no se ha probado hablando con el sheriff**. Solo se documenta; la regla es del 19b.

## 9. Validación en partida real

Hecha por Fernando a 1680×1050 y 1152×648, con capturas antes/después:
- Arranque limpio, sin errores ni avisos.
- Overlay (`O`): abre y cierra con `O`, Esc y X, y reabre a la primera. Sub-overlay narrativo: igual, y la escena no avanza.
- Capacidad y contenido: los 9 ítems del jugador visibles, capacidad 20 y 15, celdas sin estirarse.
- Equipar y desequipar por clic, y arrastre al slot correcto.
- Transferencia soltando sobre un slot de equipo, de jugador a Mira y de Mira al jugador, con el origen desequipado (Output).
- Consumibles, estrategia (se mantiene al cerrar y reabrir) y reinicio de sesión tras la derrota (las mochilas se reinician).
- Dos compañeros con el script de depuración: pestañas con cambio de equipo, mochila y estrategia, a 1152×648 (cabe, justo en el borde).
- Cero compañeros: mensaje «Sin compañeros en el grupo», sin cabecera ni equipo en la columna derecha.
- Inventario (`I`) y `BagCapacity`: idéntico tras el cambio (fase 1).
- (e) Poción con cantidad 2: se consume una por uso y cura 10 cada una; no hay efecto duplicado entre `player.gd` y el puente.

**No reportado en esta sesión (sin confirmar):**
- Tras el borrado de `item_slot`/`equip_slot`: inventario, Party y tienda sin errores. La búsqueda de consumidores salió limpia.
- Idioma inglés de la pantalla.
- Transferencias de la prueba 14 (ítem que ambos tienen) y 15 (origen del arrastre con copia en ambas mochilas) con su Output.
- Caso de Mira con la mochila llena (15) junto al jugador a 20 huecos a 1152×648.
- Retirada del script de depuración y de su autoload.

## 10. Hallazgos y lecciones

1. **`Equipment` e `Inventory` son independientes por diseño** (nota 5 de `equipment_manager.gd`): quitar un ítem de la mochila no lo desequipa. Cualquier transferencia debe desequipar primero.
2. **Validar todo antes de mover nada**, y si una operación compuesta puede fallar a mitad, revertir cada paso.
3. **El payload de arrastre tiene que llevar el dueño del slot de origen.** El componente del Design System lo transporta como un id opaco, sin acceder a sistemas.
4. **Un ViewModel nuevo no se instala antes que su View** si la View antigua usa su API: se entregan juntos.
5. **Pestañas con el mismo nombre confunden en las pruebas.** El compañero de depuración reutiliza la definición de Mira; las dos pestañas decían «Mira» y parecía que no aparecía.
6. **`MAX_PARTY_SIZE = 3` cuenta solo compañeros** (no al jugador). El máximo de 2 es una decisión de diseño, no del core.
7. **`ColumnView` como clase interna de la View** evita duplicar el código de pintado de las dos columnas.
8. **Sin la señal vieja no se puede quitar la antigua:** `slot_drop_received` se mantiene junto a `slot_item_dropped`.

## 11. Pendientes

**Pasan al 19b**
- Transferencia mochila a mochila (hoy el cursor de prohibido no da feedback).
- `ItemDetailPanel` con comparación (cajetín). La maqueta deja libre ≈280 px bajo las columnas a pantalla completa; a 1152×648 solo sobran ≈47 px, así que habrá que decidir si es franja, popup o selección.
- Estado del compañero (HP, estamina, atributos con `UIResourceBar`).
- Regla de objetos `quest_loan`/misión (relacionada con la 16c).

**Registrados, no corregidos (core o fuera de alcance)**
- `equip_item` no recibe el slot de destino: un ítem con dos tags puede acabar en otro slot que el soltado.
- Motivos de `equip_failed` e `item_use_failed` en texto libre en inglés (hacen falta códigos de motivo).
- Una poción se consume aunque no tenga efecto (Mira con la salud al máximo), lógica del puente de ítems.
- `Inventory.add_item` no valida capacidad, y sobrescribe la instancia si `can_stack_with` falla.
- `I` con Party abierta la cierra (overlay de slot único del orquestador → Spike 22).
- Descripciones de estrategia: no existen en datos.
- Comentarios «UISlot.setup()» obsoletos en `combat_arena_test_scene.gd` y `combat_production_scene.gd`.
- La mochila de Mira ya es accesible desde Party, pero `InventoryUI` no tiene selector de compañero.
- Mensaje «Equipado en Jugador: …»: el nombre del jugador es genérico («Jugador»).

## 12. Cómo reconstruir el estado a partir de este informe

Para continuar en el 19b, partir de `PartyViewModel` (§5), `UISlot` con `owner_id` y `slot_item_dropped` (§7) y el layout L3 (§3). La transferencia mochila a mochila reutiliza `request_equip_drop` (sustituyendo el equipado final por la entrega a la mochila) y `UISlot.accept_drops` en los slots de la mochila, con el filtro por `owner_id` distinto.
