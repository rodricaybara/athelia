# Spike 19b — Party: transferencia entre mochilas, detalle con comparación, estado del compañero y regla de préstamo

**Hito:** rediseño de interfaces · **Riesgo:** medio · **Depende de:** Spike 19a (cerrado). **No depende** de los spikes 20-24, y el 20 no depende de este: el orden entre 19b y 20 es libre (el plan no los encadena).
**Fuentes leídas en esta sesión:** `docs/spike_19_party.md` (informe del 19a, §3, §5, §7, §8, §11 y §12), informe del Spike 18 (`ItemDetailPanel`, `UISlot`, bonos del equipo), plan del hito y `party_viewmodel.gd`/`party_ui.gd` **anteriores al 19a** (los reescribió el 19a).
**No he visto** el `PartyViewModel`/`PartyUI` reescritos, `UISlot` tras los parches del 19a, `ItemDetailPanel` ni `Inventory.add_item`. Lo que dependa de ellos va marcado **[sin verificar]** y se cierra en la Fase 0.

---

## 1. Qué es el 19b

El 19a rehízo Party con el Design System y dejó fuera cuatro cosas que no eran «rediseño» sino **funcionalidad nueva o reglas**. Este spike las cubre:

| Bloque | Qué es | Naturaleza |
|---|---|---|
| **A** | Transferencia **mochila a mochila** entre jugador y compañero (hoy solo se transfiere soltando una pieza sobre un slot de equipo) | Lógica de ViewModel + gesto nuevo en `UISlot` |
| **B** | **Cajetín de detalle** del ítem seleccionado, con comparación (reutiliza `ItemDetailPanel`) | Visual + estado de selección |
| **C** | **Estado del compañero** (HP, estamina, atributos con `UIResourceBar`) | Visual + datos de recursos |
| **D** | **Regla de objetos `quest_loan` / misión** en transferencias y equipado | Regla de juego (relacionada con la **16c**) |

Más una **limpieza** de lo que el 19a dejó sin confirmar (§5.A).

## 2. Problema (por bloque)

### A. Mochila a mochila
- La única vía de transferir es soltar el ítem sobre un **slot de equipo** de la otra entidad. No se puede pasar una poción a Mira sin intentar equiparla; si el ítem no es equipable no hay forma de transferirlo.
- Al arrastrar una pieza sobre la mochila de la otra entidad, el cursor de prohibido **no da feedback**.
- Riesgos de datos que el 19a registró y que este bloque **expone**: `Inventory.add_item` **no valida capacidad** y **sobrescribe la instancia si `can_stack_with` falla** [sin verificar el detalle]. Una transferencia de mochila a mochila de un ítem apilable con propiedades distintas podría **perder cantidad**.
- Estado de partida del 19a: el origen desequipa antes de transferir (Q1), el destino con copia equipa la suya sin transferir (Q2), el payload lleva `owner_id` y existe `slot_item_dropped(slot, source_item_id, from_owner_id)`.

### B. Detalle con comparación
- Party solo ofrece **tooltips con nombre y cantidad**. El inventario tiene `ItemDetailPanel` (modificadores, comparación con lo equipado, acciones) y Party no.
- **Espacio:** el 19a calculó ≈280 px libres bajo las columnas a pantalla completa (1680×1050) y solo **≈47 px a 1152×648** (cálculo, no medición en pantalla). A 648 no cabe un cajetín fijo.
- Hace falta un **estado de selección** en el ViewModel (ítem + dueño) que hoy Party no tiene: el clic en un slot **actúa** (equipa/usa) en vez de seleccionar [sin verificar en el código del 19a].

### C. Estado del compañero
- No se ve la salud ni la estamina del compañero en Party, y el jugador tampoco. `UIResourceBar` sigue **sin ningún consumidor real**.
- La columna del compañero a 1152×648 con pestañas y estrategia **ya llega justo al borde inferior**; no hay sitio sin decidir qué se sacrifica.
- Pendiente del 18 relacionado: estadísticas **efectivas frente a base** (`AttributeResolver`).

### D. Objetos de préstamo
- Confirmado en partida (19a): Party permite **pasar la lanza prestada a Mira y equiparla** (`Transferido: enchanted_spear × 1 player → companion_mira`).
- `take_item` del sheriff (`narrative_scene_viewmodel.gd`) solo actúa sobre `"player"`; con la lanza en Mira imprime «nada que quitar». Es la **hipótesis de la 16c**, **todavía no probada hablando con el sheriff**.
- El tag `quest_loan` ya significa «se toma gratis y no se vende» (16b). No significa nada en Party.

### Limpieza (heredada del 19a, sin confirmar)
Inventario, Party y tienda sin errores tras borrar `item_slot`/`equip_slot`; idioma inglés de Party; transferencias con ítem en ambas mochilas (Output); Mira con mochila llena (15) junto al jugador a 20 huecos a 1152×648; **retirada de `debug_party_tool.gd` y su autoload** (el informe dice que no entra en el entregable). Además: el mensaje «Equipado en Jugador: …» usa un nombre genérico.

## 3. Objetivo

Que Party permita **gestionar el grupo de verdad** (pasar cualquier ítem entre mochilas, inspeccionarlo y compararlo, ver cómo está cada personaje) **sin perder datos** y con una **regla clara** sobre los objetos de préstamo, manteniendo el contrato MVVM del 19a.

## 4. Decisiones ya tomadas (no reabrir)

1. **Base del 19a intacta:** layout L3, `UIPanel` OVERLAY con marco (fracción 0,9, tope 1400×820, fondo opaco), `UISlot` de 64 px, máximo 2 compañeros con pestañas, referencia 1680×1050 y mínimo 1152×648, contratos públicos y `SceneOrchestrator` sin tocar.
2. **MVVM:** la View sigue sin acceder a ningún sistema; todo pasa por `PartyViewModel`. Razón nueva de `changed` ⇒ caso en la View **en el mismo cambio**.
3. **Reglas de transferencia ya decididas en el 19a** (Q1, Q2, D3): el origen desequipa antes de transferir; si el destino ya tiene copia **para equipar**, se equipa la suya; **no se bloquea** la transferencia por mochila llena (el ítem sale con borde de desbordamiento). Solo se reabren si el usuario lo pide en R3.
4. **Capacidad:** un único punto, `BagCapacity` (`ui/inventory/bag_capacity.gd`). No se duplica.
5. **Componentes del DS:** `UISlot` sigue sin acceder a sistemas; `owner_id` es un id opaco; los cambios en `UISlot` son **aditivos**. `UIResourceBar` se usa tal cual (si le falta algo, parche aditivo documentado).
6. **Solo tokens y `tr()` con claves `PARTY_*`** (`party.csv`, `id,en,es`); sin `Color(...)` ni tamaños de fuente sueltos.
7. **No se toca el core sin aprobación explícita** (`equip_item` con slot de destino, códigos de motivo de `equip_failed`, `Inventory.add_item`). Si el bloque A obliga a tocar `Inventory`, se **propone aparte** y se aprueba antes (como la 16b).
8. **La 16c no se arregla aquí por defecto.** Este spike **prueba la hipótesis** y aplica solo la regla del bloque D que se decida; el cambio en `take_item` (narrativa) es otro spike salvo decisión R8.
9. **Maqueta antes de código** para B y C (2-3 layouts) y espera de la elección.
10. **Partir si crece:** si A+D (lógica) y B+C (presentación) resultan demasiado juntos, se dividen en 19b-1 y 19b-2.

## 5. Fase 0 — comprobaciones antes de escribir código

Cada punto termina como "confirmado", "descartado" o "cambia el diseño".

### 5.A Línea base (primero, antes de diseñar)
| # | Comprobación | Por qué |
|---|---|---|
| 0.1 | Resolver lo que el 19a dejó **sin confirmar** (§2 «Limpieza»): inventario/Party/tienda sin errores, inglés, transferencias con ítem en ambas mochilas, Mira llena a 1152×648. | La base debe estar sana antes de añadir funcionalidad. |
| 0.2 | **Probar la hipótesis de la 16c:** pasar la lanza a Mira, avanzar hasta la entrega al sheriff y comprobar si imprime «nada que quitar» y la conserva. Anotar el Output. | Decide el alcance del bloque D (¿regla de Party suficiente o hace falta cambiar `take_item`?). |
| 0.3 | Capturas «antes» de Party a 1680×1050 y 1152×648 (con 1 y con 2 compañeros, con ítem seleccionado/sin seleccionar). | Referencia visual y medida **real** del espacio libre (el 19a lo calculó, no lo midió). |
| 0.4 | Retirar `debug_party_tool.gd` y el autoload `DebugPartyTool` **solo al final**, pero decidir ahora cómo se probarán 2 compañeros mientras tanto. | Sin él no se puede probar el caso de 2 compañeros. |

### 5.B Código
| # | Comprobación | Por qué |
|---|---|---|
| 0.5 | **`PartyViewModel` y `PartyUI` actuales**: `request_equip_drop`, `request_slot_action`, `ColumnData`/`BagEntry`, razones de `changed`, `ColumnView` interna, qué hace hoy un **clic** en un slot de mochila (¿equipa/usa directamente?). | Punto de partida de los bloques A y B; el clic puede entrar en conflicto con «seleccionar para ver el detalle». |
| 0.6 | **`UISlot` tras los parches del 19a**: `owner_id`, payload del arrastre, `slot_item_dropped`, `accept_drops`, `drop_source_filter`, `draggable`, estados; cómo se comporta un drop **sobre un slot vacío o sobre uno ocupado** de la mochila. | El gesto mochila-a-mochila se apoya en ello; ¿se suelta sobre un hueco concreto o sobre toda la mochila? |
| 0.7 | **`Inventory.add_item` / `remove_item` / `has_item` / `can_stack_with`**: qué pasa al sumar a una pila con propiedades distintas, valor devuelto, señales emitidas (`item_added`/`item_removed`), si valida capacidad. **Reproducir** una transferencia que pueda perder cantidad. | Riesgo de **pérdida de datos** en el bloque A. Si se confirma, hace falta pre-comprobación en el ViewModel o un parche de core aprobado. |
| 0.8 | **`ItemDetailPanel`** (Spike 18): API (`show_item`/datos, comparación, botones), dependencia del `InventoryViewModel` (`DetailData`, `ModLine`, `CompareLine`), y cuánto del cálculo de **detalle y comparación** es reutilizable sin duplicar. | Evitar **lógica duplicada**: la comparación debe vivir en un único sitio (¿helper compartido como `BagCapacity`?). |
| 0.9 | **Comparación en Party:** ¿contra el equipo de qué entidad? (la dueña del ítem, o la que lo recibiría). Cómo se obtiene el ítem equipado en el mismo slot de cada una. | Decisión R5. |
| 0.10 | **Recursos del compañero:** cómo se leen HP y estamina (`Resources`, `Characters`), señales `resource_changed`, máximos, y **atributos base vs efectivos** (`AttributeResolver`). | Datos del bloque C y pendiente del 18. |
| 0.11 | **`UIResourceBar`**: API real, tamaños mínimos, tipos de recurso (`resource_type`), coste de altura. Primer consumidor real. | Puede faltarle algo. |
| 0.12 | **Etiquetas de ítems de misión:** tags usados (`quest_loan`, `quest`, etc.), de dónde salen (datos) y cómo los consulta hoy `EconomySystem` (16b). | La regla D debe ser **data-driven** por tag, no un id fijo. |
| 0.13 | **`take_item`** en `narrative_scene_viewmodel.gd` (≈ líneas 365-374 en el momento de la 16c): `take_item_target`, qué haría falta para buscar en toda la party. | Solo lectura; informa la decisión R7/R8. |
| 0.14 | **Nombre del jugador:** de dónde sale el nombre real del personaje para sustituir el «Jugador» genérico en los mensajes. | Pendiente cosmético del 19a. |

**Paquete de comandos (PowerShell, cada uno en su bloque; rutas orientativas; ignorar `test*` y `debug*`):**

```powershell
Get-ChildItem -Recurse -Path .\ui\party | Select-Object FullName,Length,LastWriteTime | Format-Table -AutoSize
```

```powershell
Select-String -Path .\ui\party\party_viewmodel.gd -Pattern 'func |signal |class |changed.emit|_mark_dirty|owner_id|request_' | Select-Object LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Select-String -Path .\ui\party\party_ui.gd -Pattern 'Inventory\.|Equipment\.|Characters\.|Resources\.|Items\.|Party\.|Skills\.|EventBus' -CaseSensitive | Select-Object LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Select-String -Path .\ui\design_system\components\ui_slot\ui_slot.gd -Pattern 'signal |@export|func |owner_id|_get_drag_data|_can_drop_data|_drop_data|drop_source_filter' | Select-Object LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Select-String -Path .\core\**\*.gd -Pattern 'func add_item|func remove_item|func has_item|func get_inventory|can_stack_with|item_added|item_removed' -ErrorAction SilentlyContinue | Select-Object Path,LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Select-String -Path .\ui\inventory\item_detail_panel.gd,.\ui\inventory\inventory_viewmodel.gd -Pattern 'func |class |DetailData|CompareLine|ModLine|comparison' | Select-Object Path,LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Select-String -Path .\ui\design_system\components\ui_resource_bar\ui_resource_bar.gd -Pattern '@export|func |signal |resource_type' | Select-Object LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Get-ChildItem -Recurse -Include *.gd,*.tres,*.json -Path .\core,.\data | Select-String -Pattern 'quest_loan|quest_item|"quest"' | Select-Object Path,LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Select-String -Path .\ui\narrative_scene\narrative_scene_viewmodel.gd -Pattern 'take_item' | Select-Object LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Get-ChildItem -Recurse -Include *.gd -Path . | Where-Object { $_.FullName -notmatch '\\(test|debug)' } | Select-String -Pattern 'DebugPartyTool|debug_party_tool' | Select-Object Path,LineNumber,Line | Format-Table -AutoSize -Wrap
```

**Ficheros a adjuntar:** `party_ui.gd/.tscn`, `party_viewmodel.gd` (actuales, post-19a), `ui_slot.gd/.tscn`, `item_detail_panel.gd/.tscn`, `inventory_viewmodel.gd`, `ui_resource_bar.gd/.tscn`, `bag_capacity.gd`, `party.csv`, `ui_tokens.gd`, y las capturas «antes». Para el bloque D, el fragmento de `take_item`.

## 6. Decisiones abiertas que resuelve el usuario al empezar

Preguntar **de una vez**, con lo que el código permite en cada una:

| # | Pregunta | Condicionante (a verificar) |
|---|---|---|
| R1 | **Gesto** mochila a mochila: arrastre entre mochilas, doble clic/atajo «pasar al otro», un botón por ítem, o varias. | `UISlot` ya transporta `owner_id`; falta el drop sobre mochila (0.6). |
| R2 | **Cantidad:** ¿se transfiere 1, toda la pila, o se elige (modificador de teclado, mini-selector)? | La transferencia actual es de 1 (`_transfer_item(..., quantity = 1)`). |
| R3 | **Mochila destino llena:** ¿se mantiene «no bloquear, mostrar desbordamiento» (19a) o se bloquea con mensaje? | `Inventory.add_item` no valida capacidad (0.7). |
| R4 | **Detalle:** franja inferior, popup junto al slot, panel lateral plegable, o solo a pantalla completa. | ≈280 px libres a 1680×1050 y ≈47 px a 1152×648 (medir, 0.3). |
| R5 | **Comparación:** ¿contra el equipo de la entidad dueña, o contra la que recibiría el ítem (la otra columna)? | 0.9. |
| R6 | **Estado:** ¿qué mostrar? HP y estamina con `UIResourceBar` en la cabecera de cada columna (jugador y compañero), ¿y atributos? ¿base o efectivos? ¿en la cabecera, en un cajetín o en el tooltip del nombre? | Altura de la columna del compañero a 648 (0.3). `AttributeResolver` (0.10). |
| R7 | **Regla de préstamo:** (a) bloquear transferir/equipar objetos con tag `quest_loan` en compañeros; (b) permitirlo y arreglar la 16c (`take_item` busca en toda la party); (c) ambos. | 0.2 (¿se reproduce el fallo?), 0.12, 0.13. |
| R8 | ¿Se incluye el arreglo de la **16c** en este spike o se mantiene aparte? | Depende de R7. |

**Recomendación de partición (a confirmar):** **19b-1** = A + D (+ limpieza): lógica, reglas y gesto. **19b-2** = B + C: presentación (cajetín, comparación, estado). Si el usuario prefiere una sola pasada, hacerlo por fases dentro del mismo informe.

## 7. Alcance

### 7.A Transferencia mochila a mochila
- **Gesto** según R1 en `UISlot` (aditivo, sin acceso a sistemas): los slots de mochila pasan a aceptar drops con `drop_source_filter` por `owner_id` **distinto** del propio.
- **ViewModel:** intención `request_transfer(item_id, from_owner, to_owner, quantity)`. Orden obligatorio, igual que el del 19a: **validar todo antes de mover**; si el ítem está equipado en el origen, **desequipar primero**; transferir **con rollback**; refrescar ambas columnas con `_mark_dirty()`; **un único mensaje final**.
- **Integridad de datos:** comprobar antes de transferir que el destino puede apilar (`can_stack_with`) para no sobrescribir instancias (0.7). Si el core no ofrece esa comprobación, hacerla en el ViewModel o proponer el parche mínimo de core (aprobado aparte).
- **Feedback** para todo caso rechazado (destino lleno si R3 lo bloquea, ítem no transferible por la regla D, ítem inexistente), localizado en `PARTY_*`, sin `print` como único canal.
- **Cursor/zona de drop**: resaltado de los slots que aceptan el ítem arrastrado.
- Retirar el comportamiento «cursor de prohibido sin feedback».

### 7.B Cajetín de detalle con comparación
- **Selección** en el ViewModel (ítem + dueño + razón `selection`); definir qué hace un clic (seleccionar) frente a la acción (equipar/usar), probablemente con botones del propio cajetín o doble clic (a confirmar con 0.5, porque hoy el clic puede actuar).
- **Reutilizar `ItemDetailPanel`**; la comparación y los modificadores salen de **un único cálculo compartido** con el inventario (helper o servicio, no una copia) — decidir en 0.8.
- **Ubicación y comportamiento** según R4 y las medidas reales; a 1152×648 debe seguir cabiendo la pantalla (sin recortes), aunque el detalle se muestre de otra forma.
- Acciones del cajetín: Usar / Equipar / Desequipar / Pasar al otro (si R1 lo incluye), con `UIButton`.

### 7.C Estado del compañero (y del jugador, si R6 lo incluye)
- `UIResourceBar` (primer consumidor real) para HP y estamina, alimentadas por el ViewModel (datos listos, sin que la View lea `Resources`); actualización en vivo al usar un consumible.
- Atributos: según R6 y 0.10 (base o efectivos); si se muestran los efectivos, el cálculo va en el ViewModel con `AttributeResolver`.
- El layout no puede desbordar la columna a 1152×648; si no cabe, pasar a tooltip, fila compacta o cajetín (según maqueta).

### 7.D Regla de objetos de préstamo / misión
- **Data-driven por tag** (0.12): un objeto con `quest_loan` (y, si procede, un tag de misión) **no se puede transferir ni equipar en un compañero** (opción a de R7), con mensaje claro y marca visual en la mochila (icono o tooltip «Préstamo»).
- Si R7 es (b) o (c): el cambio en `take_item` es de **narrativa/core** y se hace en la 16c o aquí solo si R8 lo aprueba.
- **No hardcodear** `enchanted_spear`.

### 7.E Limpieza
Cerrar los pendientes del 19a (§2), retirar `DebugPartyTool` y su autoload al final, sustituir «Jugador» por el nombre real en los mensajes (0.14), y actualizar los comentarios obsoletos «UISlot.setup()» si el usuario lo aprueba (están en `combat_arena_test_scene.gd` y `combat_production_scene.gd`; son comentarios, no lógica).

## 8. Cambio visual y funcional esperado
- Nuevo: cajetín/panel de detalle con comparación, barras de recurso, marca de «Préstamo», resaltado de destinos de drop, gesto de transferencia entre mochilas.
- Funcional: las transferencias mochila a mochila existen; los objetos de préstamo se comportan según R7; ningún otro comportamiento del 19a cambia.
- Cualquier otra diferencia es una regresión.

## 9. Fuera de alcance
- Cambios de core no aprobados: `equip_item` con slot de destino, códigos de motivo de `equip_failed`/`item_use_failed`, validación de capacidad en `Inventory.add_item` (solo se registran, o se proponen aparte).
- El arreglo de la **16c** salvo R8.
- Descripciones de estrategia (no existen en datos) y selector de compañero en `InventoryUI`.
- Peso en Party; estadísticas completas del personaje (hoja de personaje); retratos.
- La pila de overlays del orquestador (`I` con Party abierta la cierra → Spike 22).
- Una poción que se consume sin efecto (puente de ítems).

## 10. Reglas a respetar
- MVVM y antipatrones de `athelia_ui_architecture.md`; ViewModel hijo de la View; una pantalla con `closed` nunca se libera a sí misma.
- Componentes del DS sin acceso a sistemas; setters de `@export` con `is_node_ready()`; subclase de `UIPanel` llama a `super._ready()` y fija `padding` antes.
- **Validar todo antes de mover nada; revertir cada paso si una operación compuesta falla a mitad.** `Equipment` e `Inventory` son independientes: desequipar antes de transferir.
- El payload de arrastre lleva el dueño de origen (`owner_id`).
- Un `PanelContainer` apila todos sus hijos; `ScrollContainer` con `size_flags_vertical = 3` reparte a partes iguales; el clic de un slot arrastrable se emite al soltar.
- Reconstruir listas con `remove_child()` antes de `queue_free()`; `Dictionary.get()` tipado con `as`.
- Sin `modulate` del contenedor para estados; todo texto con `tr()`; sin lógica duplicada con el inventario.
- Auditar el contrato con `Select-String -CaseSensitive`.
- Commit o copia de `ui/party/`, `ui/inventory/` y `ui/design_system/` antes de empezar.
- Un ViewModel nuevo no se instala antes que su View si la View antigua usa su API: se entregan juntos.

## 11. Validación en partida real
A 1680×1050 y 1152×648, ES y EN, con capturas antes/después:
1. **Línea base (0.1-0.2):** los cuatro puntos sin confirmar del 19a y la prueba de la hipótesis de la 16c, con Output.
2. **Mochila a mochila**, en ambos sentidos (jugador ↔ Mira): ítem simple, ítem apilable (cantidad >1) y consumible; se transfiere solo lo que se espera (R2); orígenes y destinos actualizados.
3. **Origen correcto** con copia en ambas mochilas: se toma la del dueño del slot arrastrado.
4. **Ítem equipado en el origen:** se desequipa antes de transferir; no queda equipado en dos personajes.
5. **Integridad:** transferir una pila a un destino que ya tiene el ítem **no pierde cantidad** (suma cantidades y el total antes y después coincide).
6. **Mochila destino llena:** comportamiento según R3, con feedback.
7. **Rechazos con feedback visible** (no solo en consola): ítem no transferible, destino inválido, ítem inexistente.
8. **Rollback:** forzar un fallo a mitad (p. ej. con un ítem que no se puede añadir) y comprobar que el ítem vuelve al origen.
9. **Detalle:** seleccionar un ítem muestra el cajetín con modificadores y comparación correcta con el equipo (según R5); cambiar de pestaña de compañero actualiza; seleccionar/deseleccionar no rompe el layout a 1152×648.
10. **Estado del compañero:** HP y estamina correctos, se actualizan en vivo al usar un consumible; el jugador igual si R6 lo incluye; sin desbordes a 648.
11. **Objeto de préstamo:** intentar pasar la lanza a Mira y equiparla se comporta según R7 (bloqueo con mensaje, o permitido y entregado al sheriff si se arregla la 16c).
12. **Regresión del 19a:** equipar/desequipar, arrastre al slot de equipo, estrategia, pestañas con 2 compañeros, cero compañeros, `O` y Esc, sub-overlay narrativo.
13. **Inventario (`I`) y tienda intactos.**
14. **Reabrir** varias veces y tras **reinicio de sesión** (derrota → menú → partida nueva): sin slots duplicados ni selección fantasma.
15. **Contrato:** búsqueda `-CaseSensitive` en `party_ui.gd` vacía; `DebugPartyTool` sin referencias tras retirarlo.
16. Pestaña *Errors* sin avisos nuevos.

## 12. Riesgos conocidos
- **Pérdida de datos** por `Inventory.add_item` (sobrescritura si `can_stack_with` falla, sin validar capacidad): el riesgo principal del bloque A.
- **Clic que actúa frente a clic que selecciona:** cambiar su significado altera un comportamiento validado en el 19a.
- **Altura a 1152×648:** el cajetín y las barras compiten por los ≈47 px libres; puede exigir popup o pestañas.
- **Duplicar la lógica de detalle/comparación** del inventario en lugar de compartirla.
- **Regla de préstamo mal ubicada:** si se bloquea en Party pero no en otras vías (el inventario no transfiere, pero otros sistemas sí), queda un hueco; y si el bloqueo no se acompaña del arreglo de la 16c, el sheriff puede no encontrar la lanza por otras causas.
- **`UIResourceBar` primer consumidor:** puede faltarle algo.
- **Gesto de arrastre entre mochilas** sobre `UISlot`: el drop sobre un hueco ocupado frente a vacío, el resaltado y el filtro por dueño.
- **Probar 2 compañeros depende de `DebugPartyTool`:** retirarlo demasiado pronto bloquea la validación.
- **Alcance creciente:** partir en 19b-1 / 19b-2.

## 13. Entregables
**Código (completo):** `party_viewmodel.gd`, `party_ui.gd`, los scripts nuevos de la pantalla (cajetín, barras) si los hay. **Escenas:** `party_ui.tscn` (y las nuevas), completas o como árbol de nodos legible. **Parches:** `ui_slot.gd` (aditivo), y solo con aprobación `ItemDetailPanel`/helper compartido de comparación, `ui_tokens.gd`, y cualquier cambio de core. **Datos:** `party.csv` ampliado (ES y EN). **Borrados:** `debug_party_tool.gd` y su autoload.

**Documentación:**
- `docs/spike_19b_party.md` (informe de cierre: respuestas R1-R8, qué se probó de la 16c, cambios en ViewModel/`UISlot`, regla de préstamo, validación, lecciones y pendientes).
- `athelia_ui_architecture.md` (fila de Party), README del Design System (`UIResourceBar` y `UISlot` en uso), `athelia_estructura_carpetas.md`.
- `athelia_lecciones_tecnicas.md` y `athelia_historial_spikes.md`: entrada del 19b.
- Plan del hito: cerrar el 19b, anotar el resultado sobre la 16c y los pendientes nuevos.
