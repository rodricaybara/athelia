# Spike 17 — Inventario A: contrato MVVM (sin cambio visual)

**Hito:** rediseño de interfaces · **Riesgo:** alto (el de más riesgo del hito) · **Depende de:** Spike 15 (cerrado; el 16 no es requisito)
**Origen de los datos:** Fase 0 del hito (`plan_hito_rediseno_interfaces_spikes_14_24.md`, §3.4), `athelia_ui_architecture.md` y `athelia_estructura_carpetas.md`.
**No he leído en esta sesión** `inventory_ui.gd`, `inventory_viewmodel.gd`, `inventory_screen.gd` ni los `.tscn`: todo lo que dependa de su contenido real está marcado **[sin verificar]** y se cierra en la Fase 0.

---

## 1. Problema

La pantalla de inventario que ve el jugador **rompe el contrato MVVM** que el resto del proyecto cumple:

- La View de producción es `inventory_ui.gd` (`extends CanvasLayer`, nodo raíz `InventoryUi`): **no tiene ViewModel** y accede directamente a `Inventory`, `Equipment`, `Characters`, `Resources`, `Items` y `EventBus` (unas 22 líneas según la Fase 0 del hito).
- Existe una versión MVVM, `InventoryScreen` + `InventoryViewModel`, pero **ningún otro fichero la referencia**: es código muerto, con una cobertura real desconocida (arrastre, comparación) **[sin verificar]**.
- **El detalle de ítem está duplicado** en `inventory_screen.gd` y `item_detail_panel.gd`.
- **Textos sin localizar:** `HP/ST/G/STR/DEX/CON`, "Item not in inventory", "no encaja en", "usado", "Error:", y "INVENTARIO" fijo en el `.tscn`.
- **El grid de slots viene predefinido en el `.tscn`**, y `MAX_SLOTS = 20` puede no coincidir con él **[sin verificar]**.
- **`SceneOrchestrator.close_inventory()` es código muerto** (nadie lo llama) y compara con `"InventoryUI"` mientras el nodo se llama `InventoryUi`.
- **Tres contextos de apertura** que deben seguir funcionando: overlay vía orquestador (tecla con toggle), subpantalla de `PlayerMenu` y sub-overlay de la narrativa (este último gestionado por `narrative_scene_panel.gd` sin pasar por el orquestador, porque `_current_overlay` es un slot único, no una pila).
- Documentación desfasada: `athelia_estructura_carpetas.md` ya avisa de que `inventory_viewmodel.gd` y `inventory_screen.gd` están sin uso y de que la corrección llega "con el Spike 17".

## 2. Objetivo

Que la pantalla de inventario **cumpla el contrato MVVM sin que el jugador note ningún cambio de aspecto ni de comportamiento**: View pasiva, ViewModel hijo de la View que concentra todo el acceso a sistemas core, señal `closed`, textos localizados y código muerto retirado. Este spike **prepara el terreno del Spike 18** (rediseño con `UISlot`); no rediseña nada.

## 3. Decisiones ya tomadas (no reabrir)

1. **Sin cambio visual.** Layout, tamaños, colores y arte se quedan como están. La única diferencia visible permitida es el **idioma** de los textos que hoy están fijos (ver §6).
2. **Se conservan los contratos públicos:** `open_inventory()` (orquestador), la señal `closed` y los **tres contextos de apertura**. Si el nombre público actual de apertura difiere, se conserva el que usan los llamadores.
3. **ViewModel hijo de la View** (`add_child(_vm)`), una sola señal `changed(reason: String)`, métodos de intención `request_*()`, View con `_on_vm_changed(reason)` → `match` → `_render_*()` (patrón de `athelia_ui_architecture.md`).
4. **La View no toca sistemas core.** Tras el spike, `inventory_ui.gd` no contiene ninguna referencia a `Inventory`, `Equipment`, `Characters`, `Resources`, `Items`, `Party`, `Skills` ni `EventBus`.
5. **Nodos `%` (nombres únicos)**, sin rutas `$A/B/C/...`. Nada depende del nombre del nodo raíz.
6. **Localización:** claves `INVENTORY_*` (convención `PANTALLA_ELEMENTO`), sin claves comunes. Ficheros `.csv`: respetar el orden de columnas real del que se use.
7. **Sin `Color(...)` ni tamaños de fuente nuevos.** Lo que ya exista y no se toque, se queda para el 18; lo que se escriba nuevo usa `UITokens`.
8. **No se rediseña ni se adopta `UISlot`/`UIPanel` aquí** (Spike 18). `item_slot` y `equip_slot` no se tocan salvo lo imprescindible para el contrato (p. ej. que emitan señales en vez de llamar a sistemas, si hoy lo hacen **[sin verificar]**). `equip_slot` lo comparte `party`: **cualquier cambio en él debe seguir funcionando en Party**.
9. **El módulo muerto no se «revive» por defecto: se decide en la Fase 0** (§5.A) con criterios explícitos, y lo que no se reutilice se elimina.
10. **Orquestador:** solo se retira `close_inventory()` y se corrige lo imprescindible para los tres contextos. La pila de overlays (slot único) **no se rediseña** aquí.

## 4. Fuera de alcance

- Cualquier rediseño visual, `UISlot`, marco decorativo, anclas/fracciones del panel (860×600 fijos hoy → Spike 18).
- Iconos y descripciones nuevos en el snapshot de otras pantallas (tienda → 18).
- Party: `ColumnData` / `EquipSlotData` / `SlotData` duplicadas y retirada de `item_slot`/`equip_slot` antiguos (→ 19).
- **Vender un objeto equipado** y **comprar con inventario lleno** (pendientes del 16): solo se *registra* lo que se observe; no se arregla aquí.
- Cambios de reglas de equipo, consumibles o capacidad del inventario.
- La devolución del préstamo (16c).

## 5. Fase 0 — comprobaciones antes de escribir código

Cada punto termina como "confirmado", "descartado" o "cambia el diseño". Si algo contradice la spec, avisar antes de seguir.

### 5.A Decisión estructural: revivir o reconstruir

Comparar `inventory_ui.gd` (producción), `inventory_screen.gd` y `inventory_viewmodel.gd` (muertos) y decidir con estos criterios:

| Criterio | Pregunta |
|---|---|
| Cobertura | ¿El `InventoryViewModel` cubre lo que hace hoy la View de producción: equipar/desequipar por botón y por arrastre, usar consumible, comparación, errores, estadísticas de cabecera? |
| Compatibilidad de escena | ¿`InventoryScreen` espera el mismo árbol de nodos que `inventory_ui.tscn`, o uno distinto? (Cambiar el `.tscn` de producción contradice "sin cambio visual".) |
| Contrato | ¿Usa data classes (snapshots) y `changed(reason)` como pide la arquitectura? ¿Accede a sistemas desde la View? |
| Antigüedad | ¿Sigue las APIs actuales de `Inventory`/`Equipment` o está desfasado? |

Salida esperada: «se reutiliza el ViewModel con estos cambios» o «se reconstruye usando el muerto como referencia», más la lista de lo que se borra.

### 5.B Tabla de comprobaciones

| # | Comprobación | Por qué importa |
|---|---|---|
| 0.1 | Inventario completo de **cada acceso a un sistema core** en `inventory_ui.gd` (las ~22 líneas): qué llama, para qué, y qué señal de `EventBus` escucha. | Es el contrato que hay que mover al ViewModel sin perder ninguno. |
| 0.2 | Quién instancia/abre el inventario en los **tres contextos** (orquestador, `PlayerMenu._open_subscreen`, `narrative_scene_panel.gd`) y con qué método/señal: ¿existe hoy `closed`? ¿quién hace `queue_free()`? | Regla del proyecto: toda pantalla anidable expone `closed`, y quien la instancia libera. |
| 0.3 | Comportamiento de **Esc / tecla de inventario** en cada contexto (toggle, anidado) y quién consume `ui_cancel`. | En el anidado narrativa → PlayerMenu → Inventory debe cerrarse solo la capa más profunda. |
| 0.4 | Semántica real de **equipar / desequipar / usar** en `Equipment`/`Inventory`/`Items`: ¿`equip_item` saca el objeto del inventario o no? ¿qué devuelve cada llamada en fallo? ¿qué entidad es el objetivo (jugador, companion)? | Define las intenciones del ViewModel y confirma o descarta el pendiente «vender objeto equipado». |
| 0.5 | **Arrastre:** cómo se implementa hoy (`_get_drag_data` / `_drop_data` / `can_drop_data` en `item_slot`/`equip_slot`) y qué payload lleva. | El arrastre es la funcionalidad con más riesgo de regresión; el payload no debe contener referencias a sistemas. |
| 0.6 | `MAX_SLOTS` frente al número de slots del grid del `.tscn`; qué pasa con inventarios con más ítems que huecos. | Evitar que el ViewModel y la View discrepen en la capacidad. |
| 0.7 | **Comparación** (ítem frente a equipado): dónde se calcula hoy y con qué datos. | Debe vivir en el ViewModel, no en la View. |
| 0.8 | Estadísticas de cabecera (`HP/ST/G/STR/DEX/CON`): de qué sistemas salen y cuándo se refrescan. | Son los textos sin localizar y los accesos a `Characters`/`Resources`. |
| 0.9 | Duplicación **`inventory_screen.gd` ↔ `item_detail_panel.gd`**: cuál es la fuente de verdad del panel de detalle en producción y si `item_detail_panel.gd` accede a sistemas. | Hay que evitar dejar un segundo foco de acceso a sistemas fuera del ViewModel. |
| 0.10 | `feedback_popup.gd`: ¿accede a sistemas? ¿qué mensajes muestra? | Textos de feedback ("usado", "Error:") y su origen. |
| 0.11 | `equip_slot.gd`/`item_slot.gd` y su uso en `party_ui`: señales, métodos públicos y accesos a sistemas. | Cualquier cambio debe ser compatible con Party. |
| 0.12 | Claves `INVENTORY_*` ya existentes, fichero y orden de columnas; duplicados. | Godot resuelve claves duplicadas en silencio (gana la última). |
| 0.13 | Referencias a `close_inventory()`, `"InventoryUI"` e `InventoryUi` en todo el código (GDScript, escenas, JSON). | Confirmar que retirarla no rompe nada. |
| 0.14 | Tests existentes que toquen el inventario (se ignoran `test*`/`debug*`, pero confirmar que ninguno se usa en producción). | No borrar algo que se usa. |

**Paquete de comandos (PowerShell, cada uno en su bloque; rutas orientativas, ajustar a la estructura real; ignorar `test*` y `debug*`):**

```powershell
Get-ChildItem -Recurse -Path .\ui\inventory | Select-Object FullName,Length,LastWriteTime | Format-Table -AutoSize
```

```powershell
Select-String -Path .\ui\inventory\inventory_ui.gd -Pattern 'Inventory\.|Equipment\.|Characters\.|Resources\.|Items\.|Party\.|Skills\.|EventBus' | Select-Object LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Get-ChildItem -Recurse -Include *.gd,*.tscn -Path . | Where-Object { $_.FullName -notmatch '\\(test|debug)' } | Select-String -Pattern 'InventoryUI|InventoryUi|InventoryScreen|InventoryViewModel|inventory_ui|inventory_screen|open_inventory|close_inventory' | Select-Object Path,LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Get-ChildItem -Recurse -Include *.gd,*.tscn -Path . | Where-Object { $_.FullName -notmatch '\\(test|debug)' } | Select-String -Pattern 'item_slot|equip_slot|item_detail_panel|feedback_popup' | Select-Object Path,LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Select-String -Path .\ui\inventory\*.gd -Pattern '_get_drag_data|_drop_data|_can_drop_data|set_drag_preview|MAX_SLOTS|signal ' | Select-Object Path,LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Get-ChildItem -Recurse -Include *.csv -Path .\localization | Select-String -Pattern '^INVENTORY_|^INV_|^ITEM_NOT|^EQUIP' | Select-Object Path,LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Select-String -Path .\autoload\scene_orchestrator.gd -Pattern 'inventory' | Select-Object LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Select-String -Path .\ui\player_menu\*.gd,.\ui\narrative_scene\*.gd,.\ui\party\*.gd -Pattern 'inventory|Inventory' | Select-Object Path,LineNumber,Line | Format-Table -AutoSize -Wrap
```

**Ficheros a adjuntar:** `inventory_ui.gd`, `inventory_ui.tscn`, `inventory_viewmodel.gd`, `inventory_screen.gd`, `item_slot.gd`, `equip_slot.gd`, `item_detail_panel.gd`, `feedback_popup.gd` (y sus `.tscn`), más la salida de los comandos. Si algo pesa demasiado, pedir primero los `.gd` y solo después las escenas.

## 6. Alcance

### 6.A Estructura final (a confirmar en la Fase 0)

```
ui/inventory/
├── inventory_viewmodel.gd     ← único punto de acceso a Inventory/Equipment/Characters/Resources/Items/EventBus
├── inventory_ui.gd            ← View pasiva (CanvasLayer), crea el VM como hijo
├── inventory_ui.tscn          ← mismo árbol visual; solo cambia lo imprescindible (p. ej. título localizable)
├── item_slot.gd / .tscn       ← sin lógica de juego; emite señales
├── equip_slot.gd / .tscn      ← idem (compartido con Party)
├── item_detail_panel.gd/.tscn ← pasivo, recibe datos del VM
└── feedback_popup.gd/.tscn    ← pasivo
```
Si la Fase 0 decide conservar el nombre `InventoryScreen`, la View de producción puede llamarse así; lo que importa es que haya **una sola** View y **un solo** ViewModel, y que el contrato público no cambie.

### 6.B ViewModel

- Enum de estado (`CLOSED / BROWSING / WAITING` o el que corresponda) y data classes tipo snapshot (ítems del jugador, slots de equipo, estadísticas, detalle y comparación del ítem seleccionado).
- Se suscribe al `EventBus` en su `_ready()` y emite `changed(reason)`; razones previstas **[a ajustar]**: `"opened"`, `"snapshot"` (cambió inventario o equipo), `"stats"`, `"selection"`, `"action_result"` (éxito/fallo con `feedback_message`, `feedback_is_error` y clave localizable), `"closed"`.
- Intenciones: `open()`, `request_close()`, `select_item()`, `request_equip()`, `request_unequip()`, `request_use()`, `request_drop_equip(item_id, slot_id)` (arrastre), según lo que confirme el 0.4/0.5.
- Mensajes de resultado por **clave `tr()`** con parámetros, nunca texto fijo en inglés/español.
- El ViewModel **no** crea nodos ni conoce rutas de escena.

### 6.C View

- `_ready()`: crea y añade el VM, conecta `changed`, deja `visible` según el contexto de apertura actual.
- `_render_*()` pintan solo desde el snapshot; los slots emiten señales (`item_clicked`, `slot_dropped`...) y la View las convierte en `_vm.request_*()`.
- Señal `closed` emitida al cerrar; quien instancia hace `queue_free()`.
- Se retiran todas las referencias a sistemas core.

### 6.D Orquestador y llamadores

- Retirar `SceneOrchestrator.close_inventory()` (tras 0.13).
- Comprobar que `open_inventory()`, `PlayerMenu._open_subscreen` y el sub-overlay de narrativa siguen usando el mismo contrato; ajustar el mínimo imprescindible (p. ej. conectar `closed`).
- Documentar si aparece una inconsistencia entre `InventoryUi` y el uso de nombres por cadena.

### 6.E Localización (`INVENTORY_*`)

Cubrir al menos: título ("INVENTARIO"), etiquetas de estadísticas (`HP/ST/G/STR/DEX/CON`), "Item not in inventory", "no encaja en", "usado", prefijo de error, botones y textos del panel de detalle/feedback que sigan fijos. ES y EN; campos con comas entre comillas. Si se crea un `.csv` nuevo, registrarlo a mano en *Project Settings → Localization → Translations*. Comprobar duplicados con `Group-Object`.

### 6.F Limpieza

Eliminar el código muerto que **no** se reutilice (decisión de 5.A) y actualizar la documentación. Antes de borrar: comprobar con búsqueda que no hay referencias (incluidas escenas y JSON).

## 7. Cambio visual esperado (lista completa)

- Los textos que hoy estaban fijos en un idioma se muestran en el idioma del jugador (p. ej. "INVENTARIO" y etiquetas de estadísticas).
- **Nada más.** Cualquier otra diferencia de píxeles es una regresión: avisar y arreglar antes de seguir.

## 8. Reglas a respetar

- MVVM y antipatrones de `athelia_ui_architecture.md`; ViewModel siempre hijo de la View; sistemas invisibles para la View.
- Toda pantalla anidable expone `closed`; quien la instancia hace `queue_free()`.
- Nombres `%`; ningún `$A/B/C/D`.
- Sin texto sin `tr()`; sin `Color(...)`/fuentes nuevos.
- Setters `@export` se ejecutan antes de `_ready()`: usar `is_node_ready()`.
- Reconstruir listas: `remove_child()` antes de `queue_free()`.
- `Dictionary.get()` tipado: `as int` o `Variant` explícito, nunca `:=`.
- Parches «buscar → sustituir» para ficheros grandes (`scene_orchestrator.gd`); ficheros completos para los de la pantalla.
- Antes de empezar: **commit o copia de la carpeta `ui/inventory/`** y del orquestador, por el riesgo del spike.
- Avisar de inmediato si algo rompe un contrato.

## 9. Validación en partida real

Con captura **antes y después** de cada contexto para demostrar que no cambia el aspecto (salvo textos), a 1152×648 y en pantalla completa, en ES y EN:

1. **Contexto 1 – overlay por tecla en exploración:** abre; la misma tecla (toggle) cierra; Esc cierra; vuelve a exploración sin overlays huérfanos.
2. **Contexto 2 – subpantalla de PlayerMenu:** abrir inventario desde el menú; cerrar vuelve al menú, no a exploración.
3. **Contexto 3 – sub-overlay narrativo:** abrir en una escena narrativa; cerrar devuelve a la escena, sin avanzar nodo ni racha.
4. **Anidado narrativa → PlayerMenu → Inventory:** Esc cierra solo la capa más profunda cada vez.
5. **Equipar** por botón y **por arrastre**; **desequipar** por botón y por arrastre; equipar sobre un slot ocupado; ítem que no encaja en el slot («no encaja en», localizado).
6. **Usar consumible** (la salud/energía de cabecera se actualiza); **fallo de uso** (p. ej. salud llena o sin objetivo) con mensaje de error localizado.
7. **Comparación** del ítem seleccionado con el equipado.
8. Inventario **vacío** y **lleno** (más ítems que `MAX_SLOTS`, si es posible).
9. **Companion:** si el inventario permite elegir entidad, comprobar jugador y companion.
10. **Party** sigue funcionando (usa `item_slot`/`equip_slot`): transferir y equipar en companion.
11. **Reabrir** el inventario varias veces: sin filas/slots duplicados ni errores de señal.
12. **Reinicio de sesión** (derrota → menú → partida nueva): el inventario abre vacío/limpio y sin referencias muertas.
13. **Contrato:** la búsqueda de `Inventory\.|Equipment\.|Characters\.|Resources\.|Items\.|EventBus` en la View (y en `item_detail_panel.gd`/`feedback_popup.gd`) no devuelve resultados.
14. Pestaña *Errors* del depurador sin errores nuevos (los `push_warning` van allí, no al Output).

## 10. Riesgos conocidos

- **Regresión del arrastre:** payload o `can_drop_data` dependientes de acceso directo a sistemas.
- **`equip_slot`/`item_slot` compartidos con Party:** romper Party sin notarlo.
- **Escena de producción distinta de la del módulo muerto:** forzaría cambios de nodos (y por tanto visuales).
- **Cierre en el anidado:** `ui_cancel` consumido dos veces o por la capa equivocada; el sub-overlay narrativo no pasa por el orquestador.
- **Señales del `EventBus` perdidas** al mover la suscripción al ViewModel (la View dejaba de refrescar tras un cambio externo).
- **Semántica de `equip_item`** (el objeto sigue en el inventario): un snapshot mal construido duplicaría o ocultaría ítems equipados.
- **Fuga de referencias** a `InventoryUI`/`InventoryUi` en cadenas fuera del GDScript (escenas, JSON).
- **`.csv` editado a mano** puede no reimportarse hasta que el editor recupera el foco; claves duplicadas (gana la última).
- **Tamaño del cambio:** si el spike crece, partirlo (17a ViewModel + View, 17b slots y limpieza) en lugar de entregar todo junto.

## 11. Entregables

**Código (completo):** `inventory_viewmodel.gd`, `inventory_ui.gd` (o `inventory_screen.gd` si así lo decide la Fase 0), y los `.gd` de slots/detalle/feedback que cambien. **Escenas:** `.tscn` que cambien, entregados completos o como árbol de nodos legible (cuidado: un `PanelContainer` apila hijos mal anidados). **Parche:** `scene_orchestrator.gd` (retirada de `close_inventory()` y ajustes mínimos); `player_menu_screen.gd` / `narrative_scene_panel.gd` solo si la Fase 0 lo exige. **Datos:** `.csv` con las claves `INVENTORY_*` (ES y EN). **Borrados:** lista exacta de ficheros/funciones eliminados.

**Documentación:**
- `docs/spike_17_inventario_mvvm.md` (informe de cierre: decisión 5.A con su porqué, accesos movidos al VM, ficheros tocados y borrados, claves nuevas, validación, lecciones y pendientes).
- `athelia_ui_architecture.md` y `README.md`: el inventario cumple el contrato; contextos de apertura.
- `athelia_estructura_carpetas.md`: quitar los avisos de «SIN USO» y reflejar la estructura final.
- `athelia_lecciones_tecnicas.md` y `athelia_historial_spikes.md`: entrada del Spike 17.
- `plan_hito_rediseno_interfaces_spikes_14_24.md`: marcar el 17 como cerrado, resolver «cobertura del `InventoryViewModel` muerto» y registrar lo observado sobre «vender objeto equipado».
