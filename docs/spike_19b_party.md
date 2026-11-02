# Spike 19b — Party: mochila a mochila, detalle con comparación, estado del compañero y regla de préstamo

**Hito:** rediseño de interfaces · **Cerrado:** 2026-11-01 · **Depende de:** Spike 19a · **Spec:** `spike_19b_party_spec.md`
**Partido en dos entregas (decisión R9):** 19b-1 (bloques A y D, 16c y limpieza) y 19b-2 (bloques B y C).

---

## 1. Resumen

Party pasa de «pantalla de equipo» a pantalla de gestión del grupo:

- **A.** Transferencia **mochila a mochila** por arrastre (1 unidad, o la pila entera con Mayús), con resaltado de destinos y pre-validación de integridad.
- **B.** **Cajetín de detalle** por columna (`ItemDetailPanel`), con modificadores y comparación; el clic en un slot de mochila pasa de «actuar» a «seleccionar».
- **C.** **Estado**: barras de HP y estamina (`UIResourceBar`, primer consumidor real) en la cabecera de cada columna y atributos base en el tooltip del nombre.
- **D.** **Regla de préstamo**: un objeto con tag `quest_loan` no puede pasar a un compañero. Además se corrige la **16c**: el sheriff retira la lanza aunque la tenga un compañero.

## 2. Decisiones del usuario (R1-R12)

| | Decisión |
|---|---|
| R1 | Gesto: arrastre entre mochilas (soltar sobre cualquier slot de la mochila destino) |
| R2 | 1 unidad por defecto, Mayús al soltar para la pila entera |
| R3 | Mochila destino llena: se bloquea con mensaje si el ítem ocupa pila nueva; sumar a una pila existente no se bloquea |
| R4 | (a) El clic selecciona; usar/equipar/desequipar van en los botones del detalle (cambio de comportamiento del 19a, aprobado) |
| R5 | Comparación contra el equipo del dueño del ítem |
| R6 | HP y estamina con `set_values()` desde el ViewModel; atributos base en tooltip |
| R7 | Regla de préstamo solo para el tag `quest_loan`; bloqueo jugador→compañero, compañero→jugador permitido |
| R8 | La 16c entra en este spike |
| R9 | Separados en 19b-1 y 19b-2 |
| R10 | Pre-validación en el ViewModel (sin tocar el core) y `DebugPartyTool` para las pruebas |
| R11 | Cálculo de detalle y comparación extraído a un helper compartido |
| R12 | Parche aditivo de `UIResourceBar` |
| Extra | Rebaba del 19a (destino con copia ya equipada): no hace nada y no da mensaje. Bloqueo también al equipar con clic un `quest_loan` ya presente en un compañero |

## 3. Hallazgos de la Fase 0 (lo que corrigió a la spec)

1. **`Inventory.add_item` pierde datos sin avisar** (leído en código y reproducido con sondas F6-F8). Devuelve `true` en los tres casos: (a) destino con un ítem **no apilable** que ya tiene: sobrescribe la instancia (se pierde una copia); (b) **tope de pila**: `add_quantity` recorta y `add_item` lo ignora (9+3 en `max_stack` 10 pierde 2); (c) instancia con `custom_state`: el destino se crea sin él. Hoy ningún código escribe `custom_state`. El rollback de `_transfer_item` no se dispara nunca.
2. **16c confirmada.** `take_item` solo buscaba en `take_item_target` (`"player"`): con la lanza en Mira imprimía «nada que quitar» y la aventura terminaba sin devolverla. Reproducido en partida (lanza equipada en Mira).
3. **`PartyManager.MAX_PARTY_SIZE = 3`**, no 2 como decía la documentación. La interfaz no impone máximo (las pestañas son un `HFlowContainer`).
4. **`UIResourceBar` no era usable tal cual:** el `.tscn` nacía `visible = false`, `FillRect` tenía 40 px fijos de alto, el ancho se calculaba con un `bg_rect.size.x` aún sin layout y cada refresco apilaba tweens. `bind()` accede al juego (rompe MVVM): las Views usan `set_values()`.
5. **`UISlot` no filtraba por dueño** (`drop_source_filter` filtra por `source`). Se añadió `drop_exclude_owner`.
6. **El detalle y la comparación eran privados de `InventoryViewModel`** y usaban su `entity_id`. Extraerlos obligó a mover las clases de datos a un fichero propio (evita la referencia circular).
7. **`tr()` no existe en funciones estáticas:** el helper es una instancia `RefCounted`.
8. **F8 es «Detener» en el editor de Godot:** las teclas de depuración evitan F5-F8 del editor (se usó Insert/Inicio para las sondas que chocaban).
9. `DebugPartyTool` no estaba registrado como autoload (la spec lo daba por hecho).

## 4. Cambios por fichero

| Fichero | Cambio |
|---|---|
| `ui/design_system/components/ui_slot/ui_slot.gd` | `drop_exclude_owner` y `highlight_drop_targets` (ambos apagados por defecto); resaltado vía `NOTIFICATION_DRAG_BEGIN/END` |
| `ui/design_system/components/ui_resource_bar/ui_resource_bar.gd/.tscn` | Relleno anclado al alto y ajustado por `offset_right`, repinta al redimensionar, cancela el tween anterior, pinta el último valor al entrar en el árbol; raíz visible. API sin cambios |
| `ui/inventory/item_detail_data.gd` (nuevo) | `ItemDetailData` con `ModLine` y `CompareLine` |
| `ui/inventory/item_detail_builder.gd` (nuevo) | `ItemDetailBuilder`: modificadores, comparación y formato, por entidad. Lo usan inventario y Party |
| `ui/inventory/inventory_viewmodel.gd` | Delega en el builder; quita las clases `ModLine`/`CompareLine`/`DetailData`. Sin cambio de comportamiento |
| `ui/inventory/item_detail_panel.gd/.tscn` | `show_detail(ItemDetailData)`; `set_compact(bool)` (apagado por defecto); `InfoScroll` con nombre único |
| `ui/party/party_viewmodel.gd` | `request_transfer`, selección por columna, `request_use/equip/unequip_item`, regla de préstamo, recursos (razón `resources`), atributos, nombre real en los mensajes |
| `ui/party/party_ui.gd/.tscn` | Slots de mochila con drops, resaltado y Mayús; cajetín por columna (compacto bajo 700 px de marco, completo con 340 px mínimos); barras en cabeceras; tooltip de atributos |
| `ui/narrative_scene/narrative_scene_viewmodel.gd` | `take_item` delega en `_take_item_from_party()` (16c) |
| `localization/party.csv` | 7 claves nuevas (34 en total) |
| `test/debug_party_tool.gd` | Retirado, con su autoload |

Razón nueva de `changed`: `"resources"` (solo barras, una vez por frame; la estamina se regenera y emite con frecuencia). Su caso está en la View en el mismo cambio.

## 5. Validación

Hecha en partida real a 1152×648 y 1680×1050, ES y EN, con `DebugPartyTool`:

- **Integridad (sondas):** F6 PERDIDA=1, F7 PERDIDA=2, control PERDIDA=0. Con la pre-validación, el arrastre rechaza ambos casos con mensaje y sin cambios.
- **16c:** con la lanza equipada en Mira, `Unequipped … for 'companion_mira'` y `Item taken: enchanted_spear x1 ← companion_mira`. Con la lanza en el jugador, `← player`.
- **Mochila a mochila:** ambos sentidos, con y sin Mayús, equipado en el origen, mochila destino llena (Mira 15/15), préstamo bloqueado, regla de equipar en compañero.
- **Detalle y barras:** selección por columna, deselección, limpieza al cambiar de pestaña, equipar/desequipar/usar desde el detalle, comparación, barras en vivo, tooltip de atributos con 1 y 2 compañeros. Sin scroll en el cajetín a las dos resoluciones.
- **Regresión del 19a:** equipar/desequipar, arrastre al slot de equipo y slot equivocado, estrategia, 0 y 2 compañeros, `O`, Esc, Party desde narrativa y desde el menú del jugador, reapertura y reinicio de sesión.
- **Inventario** idéntico en exploración, menú del jugador y narrativa.
- **Contrato:** la búsqueda `-CaseSensitive` de sistemas core en `party_ui.gd` sale vacía. Errors sin avisos nuevos.

**Sin validar:** Party con 2 compañeros **y** un ítem seleccionado a 1152×648 (el margen vertical de esa configuración es de ≈2 px); un tercer compañero.

## 6. Lecciones nuevas

Añadidas a `athelia_lecciones_tecnicas.md` y `athelia_ui_architecture.md` (ver sus entradas «S19b»).

## 7. Pendientes

**Motor (sin tocar, anotados):**
- `Inventory.add_item`: sobrescribe una pila no apilable existente y recorta al tope devolviendo `true` (Party lo evita con pre-validación).
- `PartyManager.MAX_PARTY_SIZE = 3` frente a «máximo 2»: decidir. A 1152×648, con 2 compañeros el margen vertical es ≈2 px.
- `InventorySystem.load_save_state()` comprueba `item_added` pero desconecta/reconecta `item_use_success`.
- Una poción se consume aunque no tenga efecto (ya anotado).

**Interfaz:**
- El cajetín de Party no muestra la línea «Categoría» a pantalla completa (las categorías se cargan en `InventoryViewModel`).
- A pantalla completa el modificador sale repetido (en el detalle y en la comparación), igual que en el inventario.
- Con selección a 1152×648 la mochila del jugador (4 filas) muestra una barra de scroll vertical mínima.
- `I` con Party abierta la cierra (Spike 22).

## 8. Documentación actualizada

`athelia_historial_spikes.md`, `athelia_referencia_sistemas.md`, `athelia_ui_architecture.md`, `README.md` (Design System), `athelia_estructura_carpetas.md`, `athelia_lecciones_tecnicas.md` y `estado_actual.md` (16c y 19b cerrados; 20 es el siguiente).
