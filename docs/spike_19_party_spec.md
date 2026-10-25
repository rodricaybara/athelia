# Spike 19 — Party: adopción del Design System y retirada de `item_slot` / `equip_slot`

**Hito:** rediseño de interfaces · **Riesgo:** medio-alto · **Depende de:** Spike 18 (cerrado)
**Fuentes leídas en esta sesión:** `party_ui.gd`, `party_ui.tscn` y `party_viewmodel.gd` (paquete `fase0_party.txt`, de la Fase 0 del hito; **los Spikes 17 y 18 no tocaron estos ficheros**, pero hay que confirmar que siguen así), el informe del Spike 18 y el plan del hito. **No he visto** `item_slot.gd`, `equip_slot.gd` (solo la versión previa al 17), `ui_slot.gd` tras el 18 ni el `InventoryViewModel` actual. Lo que dependa de ellos va marcado **[sin verificar]** y se cierra en la Fase 0.

---

## 1. Problema

### 1.1 Estado visual (heredado de la Fase 0 del hito)
- **Panel fijo de 1000×640** (`anchors_preset 8`, offsets ±500 / ±320): a 1152×648 deja 4 px de margen vertical por lado; no admite marco decorativo ni `FRAME_MIN_PADDING` = 16.
- `PanelContainer` y `Button` sin Design System: ni `UIPanel`, ni `UIButton`, ni tokens. `Background` es un `ColorRect` con `Color(0,0,0,0.6)` literal, semitransparente (el resto de overlays del hito usan fondo opaco).
- **Textos sin localizar** en escena y script: "PARTY", "Jugador", "Mochila", "X", "Sin companions"; el nombre de la columna del jugador está **fijo en el ViewModel** (`display_name = "Jugador"`); los nombres de estrategia del `OptionButton` son las **claves crudas del enum** `Party.CompanionStrategy` (`strategy_names` se rellena con `.keys()`).
- **Tamaños de fuente sueltos** (18, 14, 12) y `EquipSlot` con colores literales (ver Spike 18).

### 1.2 Contrato MVVM (no es tan limpio como parece)
- El docstring de `party_ui.gd` dice «No accede a Inventory, Equipment, Characters, Party ni Items directamente», pero **`_render_column()` llama a `Inventory.get_inventory(data.entity_id).get(slot_data.item_id)`** para obtener la `ItemInstance` que necesita `ItemSlot.set_item()`. Es una violación real del contrato, hoy sin auditar porque la búsqueda por clases no la distingue.
- `request_equip_drop` devuelve una clave de error (`PARTY_ERROR_*`) que la View solo **imprime por consola** (`print`): el jugador no recibe ningún aviso cuando un drop se rechaza. No hay feedback tampoco al usar o equipar con un clic.
- `_on_bag_slot_clicked` se cablea **dentro de `_render_column`** desconectando y reconectando la señal en cada refresco, con la entidad vinculada por `bind()`.

### 1.3 Capacidad y mochila (el hallazgo funcional)
- `PartyViewModel.MAX_BAG_SLOTS = 8` y la escena trae 8 `ItemSlot` por columna: **cualquier ítem más allá del octavo no se ve ni se puede gestionar**, mientras que el inventario (Spike 18) ya usa la capacidad real por personaje (`inventory_slots`: 20 por defecto, Mira 15).
- Consecuencia: la mochila completa de Mira solo es accesible a medias; el 18 dejó «la mochila de Mira no es accesible desde `InventoryUI`» **asignada a este spike**.
- El cálculo de capacidad vive en el `InventoryViewModel` (`_compute_capacity()`, «un único punto»). Party no puede duplicarlo sin romper esa regla.

### 1.4 Transferencia entre entidades
- La **única vía de transferencia** es arrastrar un ítem sobre un slot de equipo de la otra entidad: `request_equip_drop` mueve el ítem y luego equipa. No existe transferencia entre mochilas.
- **Orden peligroso:** el ítem se transfiere **antes** de comprobar `can_equip_in_slot`. Si el slot es incorrecto, el ítem **ya cambió de dueño** y la función devuelve `PARTY_ERROR_WRONG_SLOT` **sin deshacer la transferencia** (no hay rollback en ese tramo; el rollback existente solo cubre el fallo de `add_item`).
- `_find_item_owner()` busca primero en el jugador y luego en los compañeros: si **ambos tienen copias** del mismo ítem (apilables), toma siempre la del jugador, aunque el arrastre venga del compañero. El payload del arrastre no identifica la entidad de origen **[sin verificar]**.
- `equip_item` no recibe el slot de destino (limitación de core registrada en el 18): arrastrar a un slot concreto equipa «donde decida el sistema».
- Relación con la **16c**: Party permite pasar a un compañero un objeto de préstamo (`quest_loan`) y `take_item` del sheriff solo actúa sobre `"player"`. Es una **hipótesis** (no confirmada) de cómo se produjo el fallo de la lanza.

### 1.5 Duplicación de data classes
El plan pedía resolver la duplicación de `ColumnData` / `EquipSlotData` / `SlotData` con el `InventoryViewModel` muerto. **Esa duplicación pudo desaparecer en el Spike 17** (el ViewModel se reconstruyó con `BagEntry`, `CategoryData`, etc.). Hay que comprobarlo; si es así, el punto se da por resuelto y queda solo el trabajo de que Party consuma los datos de forma coherente.

## 2. Objetivo

Rehacer Party con el Design System (`UIPanel` + marco, `UIButton`, `UISlot`, tokens), con layout por anclas y fracciones, **cumpliendo de verdad el contrato MVVM** (sin accesos a sistemas en la View), mostrando la **capacidad real** de cada personaje, con **feedback** al jugador y textos localizados. Al terminar, `item_slot` y `equip_slot` antiguos quedan **sin consumidores y se retiran**.

## 3. Decisiones ya tomadas (no reabrir)

1. **Contrato público:** `open()`, `close()`, `toggle()`, señal `closed`, `layer = 10`, nombres `%` existentes que la View o el orquestador usen; el cierre por tecla `open_party`/`ui_cancel` (la View consume el input). `SceneOrchestrator` no se toca (ya conecta `closed` desde el 17).
2. **Design System:** raíz `UIPanel` `OVERLAY` con `decorative_frame = true`; `UIButton` (cierre, navegación, acciones); `UISlot` para equipo y mochila; solo tokens, sin `Color(...)` ni tamaños de fuente sueltos; `Backdrop` **opaco** como en inventario y tienda.
3. **Layout:** anclas y fracciones para 1152×648 mínimo, probado a 1680×1050; marco con fracción 0,9 y tope **1400×820** centrado, igual que el inventario (Spike 18).
4. **Dos columnas simétricas** (jugador | compañero activo), con el patrón de columnas del inventario (equipo, mochila con pool de `UISlot`).
5. **La View no accede a ningún sistema.** `_render_column` deja de llamar a `Inventory`: el ViewModel entrega datos suficientes para `UISlot.set_definition(definition, quantity)` (o equivalente) sin que la View toque instancias.
6. **Capacidad:** se usa la capacidad real (`inventory_slots`) con un **único punto de cálculo**; Party no copia `_compute_capacity()`. Cómo se comparte (helper compartido, método de sistema) se decide en la Fase 0.
7. **Localización:** claves `PARTY_*` (convención `PANTALLA_ELEMENTO`), sin claves comunes, en un `party.csv` (o el fichero que ya contenga las `PARTY_*`, ver Fase 0). Incluye nombres de estrategia, «Jugador» y «Sin compañeros».
8. **`item_slot` / `equip_slot` se retiran** al final del spike (y sus `.uid`), solo tras comprobar con búsqueda que no quedan consumidores, ni en escenas ni en comentarios.
9. **No se corrige** lo que requiere cambio de core: `equip_item` sin slot de destino, motivos de `equip_failed`. Sí se corrige lo que es **lógica de la pantalla** (orden de validación/transferencia, ownership del arrastre), con aprobación tras la Fase 0.
10. **Maqueta antes de código** (2-3 layouts) y espera de la elección.

## 4. Decisiones abiertas que resuelve el usuario al empezar (antes de la maqueta)

| # | Pregunta | Condicionante técnico (a verificar) |
|---|---|---|
| P1 | **Transferencia entre mochilas:** hoy solo se transfiere arrastrando a un slot de equipo. ¿Se añade arrastrar de mochila a mochila y/o un botón «Pasar a [compañero]»? | Requiere intención nueva en el ViewModel; `Inventory.add_item` puede fallar por capacidad (¿valida espacio? ver pendiente «comprar con inventario lleno»). |
| P2 | **Capacidad por columna:** ¿se muestra «Huecos usados/capacidad» (y peso) como en el inventario? | Depende de cómo se comparta el cálculo (decisión 6). |
| P3 | **Estrategia del compañero:** ¿`OptionButton` estilizado o botones segmentados (`UIButton`)? ¿Se muestra una descripción de cada estrategia? | Nombres hoy = claves de enum; hay que localizar. `UIButton` no tiene variante «segmento» [sin verificar]. |
| P4 | **Detalle de ítem:** ¿tooltip simple, o reutilizar `ItemDetailPanel` (con comparación) del inventario? | Reutilizar implica un panel dentro de Party y su ViewModel; el detalle ya está en `UIPanel`. |
| P5 | **Estado del compañero:** ¿se muestran HP/estamina con `UIResourceBar` (primer consumidor real) y/o atributos base? | Fuera de alcance por defecto; abre acceso a recursos desde el ViewModel. |
| P6 | **Feedback:** ¿popup como el del inventario (`FeedbackPopup`) o tira de mensaje de altura reservada como la tienda? | Hoy no hay ninguno; los errores solo van a `print`. |
| P7 | **Varios compañeros:** ¿navegación `<` `>` (actual), pestañas con nombre, o lista lateral? | `companion_count`, hoy normalmente 1-2 [sin verificar]. |
| P8 | **Objetos de misión / préstamo:** ¿se permite pasarlos a un compañero? | Relación con 16c; decisión de reglas, no de UI. |

**Recomendación de alcance (a confirmar):** si P1, P4, P5 o P8 implican cambios de core, de reglas o de ViewModel grandes, dividir en **19a** (rediseño con el DS, capacidad, contrato MVVM, feedback, localización, retirada de `item_slot`/`equip_slot`) y **19b** (transferencia entre mochilas, detalle/comparación, estado del compañero).

## 5. Fase 0 — comprobaciones antes de escribir código

Cada punto termina como "confirmado", "descartado" o "cambia el diseño".

### 5.A Línea base
| # | Comprobación | Por qué |
|---|---|---|
| 0.1 | Confirmar que `party_ui.gd`, `party_ui.tscn` y `party_viewmodel.gd` **no cambiaron** desde el paquete `fase0_party.txt` (comparar con los actuales). | La spec parte de esa versión. |
| 0.2 | Capturas «antes» de Party a 1152×648 y 1680×1050: con 0 compañeros, con 1 y con varios; con la mochila llena (más de 8 ítems) y con ítems equipados. | Referencia y demostración del límite de 8. |
| 0.3 | **Reproducir con datos reales:** (a) con más de 8 ítems, los sobrantes no aparecen; (b) arrastre a un slot de equipo incorrecto con ítem del otro dueño: ¿queda transferido pese al error?; (c) ¿se puede pasar la lanza `quest_loan` a Mira? | Confirma los hallazgos 1.3, 1.4 y la hipótesis de la 16c. |

### 5.B Código
| # | Comprobación | Por qué |
|---|---|---|
| 0.4 | **API actual de `UISlot`** tras el 18: `set_item`, `set_definition`, `set_selected`, `set_equipped_mark`, `set_overflow`, señales (`slot_clicked(slot)`, `slot_drop_received(slot, item_id)`), `draggable`, `accept_drops`, `drop_source_filter`, `equipment_slot_id`; **payload del arrastre** (¿incluye la entidad de origen?). | La señal pasa el *slot*, no el `item_id`; el payload decide si se resuelve el ownership (1.4). |
| 0.5 | Cómo se calcula hoy la capacidad en `InventoryViewModel` (`_compute_capacity()`) y de dónde sale `inventory_slots` (`CharacterDefinition`); quién más lo necesita. | Decisión 6: compartir sin duplicar. Opciones: helper estático, o método en `Inventory`/`Characters` (cambio de core, a aprobar). |
| 0.6 | Si el `InventoryViewModel` actual aún define `ColumnData` / `EquipSlotData` / `SlotData` o equivalentes duplicados (§1.5). | Resolver o descartar el punto del plan. |
| 0.7 | `Equipment.can_equip_in_slot(entity, item, slot)`: ¿exige que el ítem esté ya en el inventario del objetivo? `Equipment.toggle_equipment`, `equip_item`, `unequip_slot`: qué devuelven y qué señales emiten. | Determina si se puede validar **antes** de transferir (1.4). |
| 0.8 | `Inventory.add_item(entity, item_id, qty)`: ¿valida capacidad? ¿qué devuelve en fallo? Reglas de apilado. | Transferencias y rollback; relación con «comprar con inventario lleno». |
| 0.9 | `Party.CompanionStrategy` (valores, orden), `Party.set_strategy/get_strategy/get_party_members` y claves `PARTY_*` existentes (errores, estrategia) en los `.csv`; orden de columnas y duplicados. | Localizar las estrategias y los errores; evitar duplicados (gana la última). |
| 0.10 | **Consumidores de `item_slot.tscn` y `equip_slot.tscn`** (escenas, scripts, comentarios como «UISlot.setup()» en combate) y sus `.uid`. | Condición para retirarlos con seguridad. |
| 0.11 | Dónde se abre Party: orquestador (`open_party`, tecla `O`), sub-overlay de la narrativa, y si PlayerMenu la abre. Cómo se cierra cada uno. | Los dos contextos de validación. |
| 0.12 | Cómo `item_use_requested` y `toggle_equipment` informan del resultado (señales de éxito/fallo) para mostrar feedback desde el ViewModel. | Feedback localizado sin acceder a sistemas desde la View. |
| 0.13 | Cuántos compañeros puede haber a la vez, y cuántos tiene la partida real. | P7. |

**Paquete de comandos (PowerShell, cada uno en su bloque; rutas orientativas; ignorar `test*` y `debug*`):**

```powershell
Get-ChildItem -Recurse -Path .\ui\party | Select-Object FullName,Length,LastWriteTime | Format-Table -AutoSize
```

```powershell
Select-String -Path .\ui\party\party_ui.gd -Pattern 'Inventory\.|Equipment\.|Characters\.|Resources\.|Items\.|Party\.|Skills\.|EventBus' -CaseSensitive | Select-Object LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Get-ChildItem -Recurse -Include *.gd,*.tscn -Path . | Where-Object { $_.FullName -notmatch '\\(test|debug)' } | Select-String -Pattern 'item_slot|equip_slot|ItemSlot|EquipSlot' | Select-Object Path,LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Select-String -Path .\ui\design_system\components\ui_slot\ui_slot.gd -Pattern 'signal |@export|func |enum |_get_drag_data|_can_drop_data|_drop_data' | Select-Object LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Select-String -Path .\ui\inventory\inventory_viewmodel.gd -Pattern '_compute_capacity|inventory_slots|class .*Data|class BagEntry|ColumnData|EquipSlotData|SlotData' | Select-Object LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Select-String -Path .\core\**\*.gd -Pattern 'func can_equip_in_slot|func equip_item|func toggle_equipment|func unequip_slot|func add_item|func remove_item|func has_item|CompanionStrategy|func get_party_members|func set_strategy|func get_strategy|inventory_slots' -ErrorAction SilentlyContinue | Select-Object Path,LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Get-ChildItem -Recurse -Include *.csv -Path .\localization | Select-String -Pattern '^PARTY_' | Select-Object Path,LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Select-String -Path .\core\scene_orchestrator.gd,.\ui\narrative_scene\*.gd,.\ui\player_menu\*.gd -Pattern 'party|Party' | Select-Object Path,LineNumber,Line | Format-Table -AutoSize -Wrap
```

**Ficheros a adjuntar:** los tres de `ui/party/` actuales, `ui_slot.gd` y `.tscn`, `inventory_ui.gd` y `.tscn` (patrón de columnas y marco), `inventory_viewmodel.gd`, `item_slot.gd`/`equip_slot.gd` y sus `.tscn`, `ui_panel.gd`, `ui_tokens.gd`, los `.csv` con las `PARTY_*`, y las capturas «antes».

## 6. Alcance

### 6.A Maqueta (obligatoria, antes de código)
Tras responder P1-P8, presentar **2-3 layouts** comparados contra cuatro casos: 0 compañeros; 1 compañero con mochila corta; 1 compañero con la mochila llena (15) y el jugador con 20; 2 o más compañeros. A 1152×648 y a pantalla completa, con medidas reales de altura útil con marco y padding 16. Hipótesis de partida **[a validar]**:
- **Layout 1 — Dos columnas simétricas (continuidad con hoy):** cabecera por columna (nombre, y en el compañero `<` `>` + estrategia), equipo en rejilla de 3×2, mochila con scroll debajo.
- **Layout 2 — Equipo como «muñeco» entre dos mochilas:** equipo de cada entidad en una banda superior y las dos mochilas enfrentadas (favorece la transferencia visual si se aprueba P1).
- **Layout 3 — Compañero como pestaña:** columna del jugador fija y panel del compañero con selector de pestañas (útil con 3+ compañeros).

### 6.B Componentes
- **Raíz:** `UIPanel` `OVERLAY` con marco decorativo; `Backdrop` opaco; `_update_frame_rect()` conectado a `size_changed` (mismo patrón del inventario).
- **Slots:** `UISlot` para los 6 slots de equipo (`equipment_slot_id`, etiqueta dentro) y para la mochila, con **pool dinámico** según la capacidad de la entidad (no 8 nodos fijos), scroll si hace falta, borde de desbordamiento si hay más ítems que huecos, marca «E» de equipado si procede.
- **Cabecera de compañero:** `UIButton` para `<`/`>` y cierre; nombre localizado; selector de estrategia según P3; mensaje «Sin compañeros» localizado.
- **Feedback:** según P6, alimentado por el ViewModel (no `print`).
- **Foco/teclado:** Esc y `open_party` siguen cerrando; el foco inicial no debe robar la tecla de toggle.

### 6.C ViewModel
- Entrega a la View datos listos para pintar (sin necesidad de `ItemInstance`): id, definición/nombre/icono, cantidad, marca de equipado y capacidad por columna.
- Sustituir `MAX_BAG_SLOTS` por la capacidad real; cálculo único (decisión 6).
- Reordenar `request_equip_drop`: **validar el slot antes de transferir** si la Fase 0 (0.7) lo permite; si no, **rollback** de la transferencia cuando falla el equipado. Resolver el **ownership** del arrastre (origen explícito en el payload o parámetro) para no tomar siempre el ítem del jugador.
- Mensajes de resultado por **clave `tr()`** con parámetros (`PARTY_*`), emitidos con una razón de `changed` nueva (`feedback`), con su caso en la View en el mismo cambio.
- Nombre del jugador y nombres de estrategia por clave, no texto fijo.
- Sin `print` de depuración sobrante.

### 6.D Localización (`PARTY_*`)
Título, «Jugador», «Mochila», «Sin compañeros», nombres y descripciones de estrategia, errores (`PARTY_ERROR_ITEM_NOT_FOUND`, `PARTY_ERROR_TRANSFER_FAILED`, `PARTY_ERROR_WRONG_SLOT` — comprobar si existen), mensajes de feedback y huecos/capacidad. ES y EN; campos con comas entre comillas; si se crea un `.csv` nuevo, registrarlo a mano en *Project Settings → Localization → Translations*; comprobar duplicados con `Group-Object`.

### 6.E Retirada de componentes antiguos
Tras 0.10: eliminar `item_slot.gd/.tscn` y `equip_slot.gd/.tscn` con sus `.uid`, actualizar comentarios obsoletos («UISlot.setup()» en escenas de combate, si procede) y la tabla de migración del README del Design System.

### 6.F Pendientes que se resuelven aquí
Mochila de Mira accesible y completa; límite de 8 ítems; violación de contrato en `_render_column`; texto «Jugador» fijo y estrategias crudas; feedback de drops rechazados; (según Fase 0) transferencia antes de validar y ownership del arrastre; duplicación de data classes (si sigue).

## 7. Cambio visual esperado
Todo el aspecto de la pantalla cambia (es un rediseño); la lista cerrada es la maqueta aprobada. **No cambia el comportamiento funcional** salvo lo declarado: capacidad real en la mochila, feedback visible, corrección del orden de validación/transferencia y del ownership del arrastre. Cualquier otra diferencia es una regresión.

## 8. Fuera de alcance
- Loadout, árbol de habilidades, menú del jugador (spikes 20-22).
- Cambios de core: `equip_item` con slot de destino, códigos de motivo en `equip_failed`, reglas de capacidad nuevas (peso) y validación de espacio en `Inventory.add_item` (solo se **registran**, salvo aprobación explícita y entonces pasa a 19b).
- Arte nuevo y retratos de compañeros.
- Estadísticas efectivas (`AttributeResolver`) y estado del compañero (P5) salvo decisión explícita.
- Cualquier arreglo de la 16c (devolución del préstamo); solo se **documenta** si Party reproduce el fallo.
- Rediseño de la pila de overlays del orquestador.

## 9. Reglas a respetar
- MVVM y antipatrones de `athelia_ui_architecture.md`; ViewModel hijo de la View; razón nueva de `changed` ⇒ caso en la View en el mismo cambio; una pantalla con `closed` nunca se libera a sí misma.
- Componentes del DS no acceden a sistemas; setters de `@export` con `is_node_ready()`; una raíz que `extends UIPanel` fija `padding` antes de `super._ready()`.
- Un `PanelContainer` apila todos sus hijos: el contenido va en **un único** contenedor; verificar el padre de cada nodo al montar a mano.
- `ScrollContainer` con `size_flags_vertical = 3` reparte a partes iguales; un `Label` con elipsis tiene anchura mínima 0; el clic de un slot arrastrable se emite al soltar.
- Reconstruir listas: `remove_child()` antes de `queue_free()`; `Dictionary.get()` tipado con `as`, nunca `:=`.
- Sin `modulate` del contenedor para estados; todo texto con `tr()`.
- Auditar el contrato con `Select-String -CaseSensitive`.
- Commit o copia de `ui/party/`, `ui/inventory/` y de los componentes a retirar antes de empezar.
- Avisar de inmediato si algo rompe un contrato.

## 10. Validación en partida real
Con capturas «antes/después», a 1152×648 y 1680×1050, en ES y EN:
1. **Contextos:** overlay con la tecla `O` (abre, cierra con la misma tecla y con Esc, reabre a la primera); sub-overlay de narrativa (cierra y vuelve a la escena sin avanzar nodo ni racha).
2. **Sin compañeros:** mensaje localizado, estrategia deshabilitada, sin errores.
3. **Con compañero(s):** navegación `<` `>` (si hay más de uno), nombre localizado, estrategia con nombres localizados que se mantiene al cambiar de compañero y al reabrir.
4. **Capacidad real:** el jugador con más de 8 ítems los ve todos; Mira muestra su capacidad (15) y todo su contenido; desbordamiento visible.
5. **Equipar y desequipar** en jugador y compañero, por clic y por arrastre; «no encaja» con feedback visible.
6. **Transferir ítems jugador ↔ compañero en ambos sentidos** por la(s) vía(s) aprobadas; el ítem se transfiere **solo** cuando procede y, si el equipado falla, **no queda movido sin avisar**.
7. **Ownership:** con el mismo ítem apilable en jugador y compañero, arrastrar desde el compañero toma el del compañero.
8. **Usar consumible** en el compañero; HUD y columna al día.
9. **Objeto de misión/préstamo:** comportamiento según la decisión P8 (y registrar si se reproduce el fallo de la 16c).
10. **Inventario intacto:** el inventario (`I`, PlayerMenu, narrativa) sigue idéntico tras retirar los componentes antiguos.
11. **Reabrir** varias veces y tras **reinicio de sesión** (derrota → menú → partida nueva): sin slots duplicados ni errores.
12. **Contrato:** búsqueda `-CaseSensitive` de `Inventory\.|Equipment\.|Characters\.|Resources\.|Items\.|Party\.|EventBus` en `party_ui.gd` vacía; búsqueda de consumidores de `item_slot`/`equip_slot` vacía.
13. Pestaña *Errors* sin warnings nuevos (marco de `UIPanel`, "Razón desconocida", `queue_free` de listas).
14. Layout sin recortes ni solapes con marco y padding 16 a 1152×648 y 1680×1050.

## 11. Riesgos conocidos
- **Último consumidor de los slots antiguos:** retirar `item_slot`/`equip_slot` puede romper escenas que los referencian por UID o comentarios; verificar antes y después.
- **Arrastre con `UISlot`:** la señal pasa el slot, no el id; el payload debe llevar entidad de origen sin referencias a sistemas.
- **Cambio de comportamiento al reordenar transferencia/validación** (un drop que antes «funcionaba a medias» ahora se rechaza entero); avisar y validar.
- **Capacidad compartida:** si se resuelve tocando core (`Inventory`/`Characters`), el spike cambia de naturaleza (como la 16b); decidirlo en la Fase 0.
- **Pool dinámico** de 20 slots × 2 columnas + equipo: coste de reconstrucción en cada `changed`; reutilizar nodos y conservar selección.
- **Altura útil a 648:** equipo + cabecera + 20 huecos en dos columnas es el caso más apretado.
- **Navegación entre compañeros** y estrategia: `request_set_strategy` no emite `changed` hoy; un cambio de estructura puede perder el estado visual.
- **Pantallas aún sin migrar** (PlayerMenu, Loadout) con otro aspecto hasta los spikes 20-22.
- **Alcance creciente** (P1, P4, P5): partir en 19a/19b.

## 12. Entregables
**Código (completo):** `party_ui.gd`, `party_viewmodel.gd`, y los scripts nuevos de la pantalla si los hay. **Escenas:** `party_ui.tscn` (y las nuevas), completas o como árbol de nodos legible. **Posible parche:** `ui_slot.gd`/`.tscn`, `ui_tokens.gd` y, solo si se aprueba, el punto de capacidad compartido. **Datos:** `party.csv` (o el fichero que corresponda) con las claves `PARTY_*` (ES y EN). **Borrados:** `item_slot` y `equip_slot` (.gd, .tscn, .uid).

**Documentación:**
- `docs/spike_19_party.md` (informe de cierre: layout elegido y por qué, decisiones P1-P8, cambios en ViewModel, comportamiento corregido, retirada de componentes, claves, validación, lecciones y pendientes).
- `athelia_ui_architecture.md` (fila de Party), `README.md` del Design System (tabla de migración y `UISlot` en Party), `athelia_estructura_carpetas.md`.
- `athelia_lecciones_tecnicas.md` y `athelia_historial_spikes.md`: entrada del Spike 19.
- `plan_hito_rediseno_interfaces_spikes_14_24.md`: cerrar el 19 (o 19a), registrar 19b y lo observado sobre la 16c.
