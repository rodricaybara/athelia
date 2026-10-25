# Spike 18 — Inventario B: rediseño con el Design System

**Hito:** rediseño de interfaces · **Riesgo:** medio · **Depende de:** Spike 17 (cerrado en código, 17a)
**Fuentes:** `plan_hito_rediseno_interfaces_spikes_14_24.md` (Spike 18 y pendientes heredados), `docs/spike_17_inventario_mvvm.md`, README del Design System (migración `item_slot`/`equip_slot` → `UISlot` prevista en este spike), y el `inventory_ui.tscn` / `equip_slot.gd` anteriores al 17.
**Advertencia sobre lo leído:** no he visto en esta sesión `ui_slot.gd`, `item_slot.gd` ni el `InventoryViewModel` reconstruido en el 17, y el `.tscn`/`equip_slot.gd` que sí he visto son **anteriores al Spike 17** (los nombres de nodo cambiaron). Lo que depende de ellos está marcado **[sin verificar]** y se cierra en la Fase 0.

---

## 1. Problema

El 17 dejó la pantalla de inventario **correcta en arquitectura pero con el aspecto original**, es decir, fuera del Design System:

- **Panel fijo de 860×600** (`anchors_preset 8` con offsets ≈ ±430/±300). A 1152×648 deja ~24 px de margen vertical por lado; con marco decorativo y `FRAME_MIN_PADDING` = 16 px el margen es insuficiente. En pantalla completa queda pequeño.
- **No usa `UIPanel`, `UIButton`, `UISlot` ni `UITokens`.** El botón de cierre es un `Button` "X" de 32×32; el panel, un `PanelContainer` con tema por defecto.
- **Tres columnas rígidas** (estructura anterior al 17, a confirmar): *Equipo* (6 `EquipSlot`: cabeza, torso, manos, pies, arma, escudo; mínimo 100 px), *Mochila* (rejilla de **20** `ItemSlot` predefinidos en el `.tscn`, 5 columnas, más una rejilla de estadísticas de 6 columnas) y *Panel derecho* (mínimo 300 px: detalle + `FeedbackPopup`).
- **`ItemSlot` y `EquipSlot` tienen su propio estilo** con `Color(...)` literales (en `EquipSlot`: `COLOR_EMPTY`, `COLOR_OCCUPIED`, `COLOR_HOVER`, `BORDER_EMPTY`, `BORDER_OCCUPIED`) y `StyleBox` propio; un ítem sin icono muestra el logo de Godot teñido.
- **Pendientes heredados del 17** que son de esta pantalla:
  - El ítem equipado **sigue en la mochila sin marca de «equipado»** (`DetailData.is_equipped` ya existe).
  - `equip_item` **ignora el slot donde se suelta** el objeto (elige el primer slot con tag coincidente).
  - `ItemSlot` **pierde el resaltado** al salir el ratón.
  - Con **más de 20 ítems** los sobrantes no se ven (solo `push_warning`).
  - **No existen** comparación de ítems ni selector de compañero.
  - Nombres de modificadores sin localizar («Armor Rating»); motivos de `item_use_failed`/`equip_failed` en inglés libre (`equip_failed` no se escucha); `AnimationPlayer` de `feedback_popup.tscn` sin uso.
- **`UISlot` no tiene ningún consumidor real** y esta es la pantalla para la que se diseñó.

## 2. Objetivo

Rehacer la pantalla de inventario con `UIPanel` (marco), `UIButton`, `UISlot` y `UITokens`, con layout por anclas y fracciones que funcione a 1152×648 y a pantalla completa, **manteniendo el contrato MVVM del Spike 17** (View pasiva, ViewModel hijo, `closed`, `open_inventory()`, tres contextos). Cierra los pendientes visuales heredados y, **si el usuario lo decide en la maqueta**, añade funcionalidades de diseño (categorías, comparación, compañero), siempre que el ViewModel y el core las soporten.

## 3. Decisiones ya tomadas (no reabrir)

1. **El contrato público no cambia:** `open_inventory()`, señal `closed`, `@export entity_id`, `toggle()`, los tres contextos de apertura (overlay vía orquestador con tecla `I`, subpantalla de PlayerMenu, sub-overlay narrativo) y el cierre con Esc que consume `ui_cancel`.
2. **MVVM intacto:** la View sigue sin referencias a `Inventory`, `Equipment`, `Characters`, `Resources`, `Items`, `Party`, `Skills` ni `EventBus` (auditoría con `-CaseSensitive`). Las funcionalidades nuevas pasan por el ViewModel.
3. **Design System:** raíz `UIPanel` variante `OVERLAY` (opaca) con `decorative_frame = true`; `UIButton` para cerrar y para acciones; `UISlot` para ítems y equipo; solo tokens (`BG_/BORDER_/TEXT_` para superficies, bordes y texto; `COLOR_*` para semánticos, recursos y slots). Sin `Color(...)` ni `StyleBoxFlat.new()` fuera de `UITokens.make_stylebox()`.
4. **Resolución:** sin estiramiento; layout con **anclas y fracciones** para ventana mínima de 1152×648, probado también a pantalla completa (1680×1050). Nada de offsets grandes fijos.
5. **`item_slot` y `equip_slot` antiguos se quedan** hasta el Spike 19, porque Party los usa. El inventario deja de usarlos; **no se tocan** salvo que la Fase 0 demuestre que es imprescindible, y en ese caso Party debe seguir funcionando.
6. **Localización:** claves `INVENTORY_*` en `localization/inventory.csv` (`id,en,es`); sin claves comunes.
7. **Nodos `%`** (nombre único), sin rutas `$A/B/C/...`.
8. **Maqueta antes de código** (2-3 layouts) y espera de la elección del usuario.
9. **El boceto de partida se inspira en la disposición del inventario de The Witcher 3** (referencia que aportó Fernando): se toma la *idea* de organización, no se copia el arte.
10. **Orquestador:** no se toca la pila de overlays (`_current_overlay` de slot único). Cualquier ajuste se limita a lo imprescindible.

## 4. Decisiones abiertas que resuelve el usuario al empezar (antes de la maqueta)

El plan pide **preguntarlas al abrir el spike**. Son de diseño; la Fase 0 aporta lo que el código permite:

| # | Pregunta | Condicionante técnico (a verificar) |
|---|---|---|
| D1 | **Categorías / pestañas** (todo, armas, armadura, consumibles, misión...) | ¿Qué campo de `ItemDefinition` permite clasificar (tags, tipo)? ¿Debe vivir en el ViewModel? |
| D2 | **Peso / capacidad**: ¿se muestra un indicador? ¿se limita por peso o por huecos? | Si hoy solo hay `MAX_SLOTS = 20`, el peso **no existe** en el core: sería sistema nuevo (fuera de este spike, salvo decisión explícita). |
| D3 | **Comparación** de un ítem de la mochila con el equipado | No existe en producción; el cálculo debe ir en el ViewModel con datos de `ItemDefinition`. |
| D4 | **Orden** (manual, por tipo, por nombre, últimos) | ¿Orden estable? ¿Se guarda? |
| D5 | **Aspecto de slots y ficha** (tamaño, marcos por rareza o tipo, cantidad, marca de equipado) | `UISlot` define tamaño 64×64 y estados; tamaño final por maqueta. |
| D6 | **Selector de compañero**: ¿ver/equipar el inventario de un compañero desde esta pantalla? | Hoy `entity_id` es un `@export`; Party ya gestiona transferencias (Spike 19). Riesgo de solapamiento. |
| D7 | **Más de 20 ítems**: ¿paginación, scroll o rejilla dinámica? | `MAX_SLOTS` y el grid fijo del `.tscn`. |

**Recomendación de alcance (a confirmar):** dividir el spike si D2, D6 o el orden implican cambios de core o de Party:
- **18a — Rediseño visual y pendientes de la pantalla:** `UIPanel`/`UIButton`/`UISlot`/tokens, layout proporcional, marca de «equipado», resaltado, mochila con scroll o rejilla dinámica, localización restante, categorías y comparación si solo dependen del ViewModel.
- **18b — Funcionalidades que tocan core o Party:** peso/capacidad, selector de compañero, equipar en un slot concreto (`equip_item`), orden persistente.

## 5. Fase 0 — comprobaciones antes de escribir código

Cada punto termina como "confirmado", "descartado" o "cambia el diseño".

### 5.A Línea base

| # | Comprobación | Por qué |
|---|---|---|
| 0.1 | **Validar en partida los contextos que el 17 dejó sin confirmar:** PlayerMenu (subpantalla), narrativa (sub-overlay), Esc anidado narrativa → PlayerMenu → Inventory, mochila con más de 20 ítems y arrastre «feliz» a un slot de equipo. | El rediseño parte de una base que debe estar sana; si falla algo, es regresión del 17 y se arregla antes. |
| 0.2 | Capturas «antes» del inventario a 1152×648 y a pantalla completa (vacío, con ítems, con ítem equipado, con detalle). | Referencia para comparar. |

### 5.B Código

| # | Comprobación | Por qué |
|---|---|---|
| 0.3 | **API real de `UISlot`** (`ui_slot.gd`/`.tscn`): propiedades (`slot_size`, `accept_drops`, `equipment_slot_id`), señales, estados (vacío, ocupado, seleccionado, hover, deshabilitado), icono y cantidad, cómo gestiona el arrastre (payload, `_can_drop_data`/`_drop_data`) y el docstring con la ruta antigua `components/slot/`. | Es el primer consumidor real; puede faltarle algo (marca de equipado, resaltado persistente, `set_busy`). |
| 0.4 | **Payload de arrastre actual** y quién lo origina: `EquipSlot` acepta `{item_id, source:"inventory"}` y emite `drop_accepted(slot_id, item_id)`. ¿Qué emite hoy `ItemSlot` y qué espera `InventoryViewModel.request_equip_drop()`? | El arrastre es lo más frágil; debe seguir funcionando con `UISlot`. |
| 0.5 | **Interfaz actual de `inventory_ui.gd` e `InventoryViewModel`** reconstruidos en el 17: razones de `changed`, `DetailData`, intenciones `request_*`, cómo mapea slots de equipo. | Para saber qué cambia en la View y qué hay que ampliar en el ViewModel. |
| 0.6 | **Semántica de `equip_item`** y de los slots: cómo se elige el slot, qué devuelve, si admite un `slot_id` explícito. Hay **un solo `equip_failed` sin oyente** y los motivos llegan como texto libre en inglés. | Decide si «equipar en el slot concreto» es 18a (ViewModel) o 18b (core). |
| 0.7 | **Datos disponibles de `ItemDefinition`** (tipo, tags, rareza, `icon`, modificadores, peso si existe, `description_key`). | Condiciona categorías, comparación, marcos por rareza y el detalle. |
| 0.8 | **Consumidores de `item_slot.tscn` y `equip_slot.tscn`** (inventario y Party): señales y propiedades que usa Party. | No romper Party; saber qué se puede dejar de usar en el inventario. |
| 0.9 | `item_detail_panel.gd/.tscn` y `feedback_popup.gd/.tscn` actuales: estructura, textos, `AnimationPlayer` sin uso, escucha de `equip_failed`/`item_use_failed`. | Se rediseñan en este spike. |
| 0.10 | **Layout actual vs 648 px:** altura real de la mochila (20 huecos en 5 columnas), el bloque de estadísticas y el panel derecho; qué sobra o falta con marco y padding mínimo 16. | Dimensionar la maqueta con números. |
| 0.11 | Claves `INVENTORY_*` existentes en `inventory.csv` (29), orden de columnas (`id,en,es`), duplicados, y las que faltan para modificadores y motivos de fallo. | Evitar duplicados (gana la última) y filas mal formadas. |
| 0.12 | Qué muestra hoy un ítem **sin icono** (logo de Godot) y qué iconos reales tienen los ítems del juego. | Decidir el placeholder del DS. |
| 0.13 | Cómo se **instancia el inventario en los tres contextos** y si alguno fija tamaño o escala (PlayerMenu, narrativa). | Un panel por fracciones puede comportarse distinto dentro de una subpantalla. |

**Paquete de comandos (PowerShell, cada uno en su bloque; rutas orientativas; ignorar `test*` y `debug*`):**

```powershell
Get-ChildItem -Recurse -Path .\ui\design_system\components\ui_slot | Select-Object FullName,Length | Format-Table -AutoSize
```

```powershell
Select-String -Path .\ui\design_system\components\ui_slot\ui_slot.gd -Pattern 'signal |@export|func |enum |_get_drag_data|_can_drop_data|_drop_data' | Select-Object LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Select-String -Path .\ui\inventory\*.gd -Pattern 'signal |_get_drag_data|_can_drop_data|_drop_data|drop_accepted|unequip_requested|slot_clicked|request_equip_drop|MAX_SLOTS' | Select-Object Path,LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Get-ChildItem -Recurse -Include *.gd,*.tscn -Path . | Where-Object { $_.FullName -notmatch '\\(test|debug)' } | Select-String -Pattern 'item_slot|equip_slot|ItemSlot|EquipSlot|UISlot|ui_slot' | Select-Object Path,LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Select-String -Path .\core\**\*.gd -Pattern 'func equip_item|func unequip_item|func unequip_slot|func can_equip_in_slot|equip_failed|item_use_failed' -ErrorAction SilentlyContinue | Select-Object Path,LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Select-String -Path .\core\**\item_definition.gd -Pattern '@export|var ' -ErrorAction SilentlyContinue | Select-Object LineNumber,Line | Format-Table -AutoSize -Wrap
```

```powershell
Get-Content .\localization\inventory.csv
```

```powershell
Select-String -Path .\ui\player_menu\*.gd,.\ui\narrative_scene\*.gd -Pattern 'inventory|Inventory' | Select-Object Path,LineNumber,Line | Format-Table -AutoSize -Wrap
```

**Ficheros a adjuntar:** `ui_slot.gd` y `.tscn`, `inventory_ui.gd` y `.tscn` actuales (post-17), `inventory_viewmodel.gd`, `item_slot.gd` y `.tscn`, `equip_slot.gd` y `.tscn`, `item_detail_panel.gd` y `.tscn`, `feedback_popup.gd` y `.tscn`, `inventory.csv`, `ui_tokens.gd` y `ui_panel.gd` vigentes, y las capturas «antes».

## 6. Alcance

### 6.A Maqueta (obligatoria, antes de código)

Tras responder D1-D7, presentar **2-3 layouts** comparados contra cuatro casos: mochila vacía; 8 ítems con 2 equipados; 20 ítems; más de 20 ítems (o el comportamiento que se elija), a 1152×648 y a pantalla completa. Hipótesis de partida **[a validar]** inspirada en la referencia:
- **Layout 1 — Tres zonas:** *Equipo* a la izquierda (siluetas o lista de slots con nombre), *Mochila* en el centro (rejilla con scroll y, si se decide, pestañas por categoría), *Ficha* a la derecha (detalle, comparación, acciones).
- **Layout 2 — Mochila ancha + ficha:** equipo en una banda superior o lateral estrecha para ganar altura útil.
- **Layout 3 — Lista con detalle:** mochila en filas (reutilizando el patrón de `ShopItemSlot`) en lugar de rejilla, ficha a la derecha.

La elección se hace antes de implementar.

### 6.B Componentes

- **Raíz:** `UIPanel` `OVERLAY` con marco, anclas por fracción (panel ≈ 90 % × 90 % como en la tienda, ajustable por maqueta) y mínimos para 1152×648.
- **Slots:** `UISlot` para mochila y equipo; marca de **equipado** en el hueco de la mochila (estado visual con tokens, no `modulate` del contenedor); resaltado de selección persistente y de hover que no se pierde al salir el ratón; placeholder de ítem sin icono definido en el DS.
- **Mochila:** rejilla dinámica creada por código a partir del snapshot (no 20 nodos en el `.tscn`), con scroll si hace falta; capacidad según lo que decida D7.
- **Detalle (`item_detail_panel`):** rehecho con `UIPanel`/tokens, modificadores con nombres localizados (`INVENTORY_MOD_*`), botones `UIButton` (Usar/Equipar/Desequipar), comparación si se aprueba D3.
- **`feedback_popup`:** con tokens (éxito/error), sin `AnimationPlayer` muerto; mantiene `show_success`, `show_error`, `hide_message`.
- **Cabecera:** título localizado, estadísticas con tokens de recursos (`COLOR_*` de HP/estamina/oro), cierre con `UIButton` GHOST/SECONDARY.
- **Foco/teclado:** Esc cierra (ya implementado en el 17), y el foco inicial no debe robar la tecla de toggle (`I`).

### 6.C ViewModel

Solo las ampliaciones necesarias para lo aprobado: categorías, comparación (datos de `ItemDefinition` ya traducibles), marca `is_equipped` por hueco, razones nuevas de `changed` (documentadas), mensajes de fallo con clave `tr()` en lugar de texto libre inglés (y escucha de `equip_failed`). **Ningún acceso a sistemas desde la View.**

### 6.D Localización

Claves nuevas `INVENTORY_*` para categorías, comparación, modificadores, motivos de fallo, estados («Equipado»), capacidad/orden si se aprueban. ES y EN; `inventory.csv` ya registrado en Project Settings; comprobar duplicados con `Group-Object`.

### 6.E Pendientes que se resuelven aquí

Marca de equipado; resaltado de `ItemSlot`; ítem sin icono; más de 20 ítems; modificadores sin localizar; `equip_failed` sin oyente; `AnimationPlayer` sin uso. **Si D6 o el slot concreto implican core o Party, se pasan a 18b.**

## 7. Cambio visual esperado

Todo el aspecto de la pantalla cambia (es un rediseño); la lista cerrada de cambios es la maqueta aprobada. Cualquier diferencia no recogida en ella es una regresión. **No cambia el comportamiento**: contextos, atajos, equipar/desequipar/usar y arrastre se comportan como tras el 17.

## 8. Fuera de alcance

- Party, Loadout, árbol de habilidades y menú del jugador (spikes 19-22). `item_slot`/`equip_slot` antiguos se retiran en el 19.
- Sistema de peso o capacidad nuevo en el core, salvo decisión explícita en D2 (entonces es 18b).
- Reglas de equipo, consumibles o tienda; vender un objeto equipado y comprar con inventario lleno (pendientes del 16, solo se registran).
- Iconos de objeto nuevos o arte (se usa lo que exista y un placeholder del DS); retratos.
- Rediseño de la pila de overlays del orquestador.
- Aplicar `main_theme.tres` o familias de fuentes (fuera del hito).

## 9. Reglas a respetar

- MVVM y antipatrones de `athelia_ui_architecture.md`; ViewModel hijo de la View; sistemas invisibles para la View; toda pantalla anidable expone `closed` y quien la instancia libera.
- Componentes del DS: nunca acceden a autoloads de sistemas; señales con nombre de intención; setters de `@export` protegidos con `is_node_ready()`; una raíz que `extends UIPanel` fija `padding` **antes** de `super._ready()`.
- Un `PanelContainer` apila todos sus hijos: el contenido va dentro de **un único** contenedor; verificar el padre de cada nodo al montar a mano.
- `ScrollContainer` con `size_flags_vertical = 3` reparte a partes iguales; un `Label` con elipsis tiene anchura mínima 0.
- Reconstruir listas: `remove_child()` antes de `queue_free()`.
- Sin `modulate` del contenedor para estados; sin `Color(...)` ni tamaños de fuente sueltos; todo texto con `tr()`.
- `Dictionary.get()` tipado: `as int` o `Variant` explícito, nunca `:=`.
- Entregar `.tscn` completos o árboles de nodos legibles; parches «buscar → sustituir» para ficheros grandes.
- Commit o copia de `ui/inventory/` y del orquestador antes de empezar.
- Si algo rompe un contrato, avisar de inmediato.

## 10. Validación en partida real

Con capturas «antes/después», a 1152×648 y a pantalla completa, en ES y EN:

1. **Tres contextos:** tecla `I` con toggle y Esc; subpantalla de PlayerMenu (cierre vuelve al menú); sub-overlay narrativo (cierre vuelve a la escena sin avanzar nodo ni racha).
2. **Anidado** narrativa → PlayerMenu → Inventory: Esc cierra solo la capa más profunda.
3. **Equipar y desequipar** por botón y **por arrastre** con los nuevos `UISlot`; «X no encaja en Y» al soltar sobre un slot incorrecto; arrastre feliz a un slot de equipo; si se resuelve, equipar en el slot concreto.
4. **Marca de equipado** en la mochila; al desequipar desaparece; equipar sobre un slot ocupado.
5. **Usar consumible** (HUD y cabecera al día) y **fallo de uso** con mensaje localizado; fallo de equipar con mensaje localizado.
6. **Mochila vacía, con pocos ítems, con 20 y con más de 20** (según D7).
7. **Hover y selección:** el resaltado se conserva/quita como indica la maqueta; no se pierde al salir el ratón.
8. **Ítem sin icono:** muestra el placeholder del DS, no el logo de Godot.
9. **Categorías, comparación, compañero/orden** solo si se aprobaron.
10. **Party** sigue funcionando intacta (usa `item_slot`/`equip_slot`): transferir y equipar en un compañero.
11. **Reabrir** varias veces y tras **reinicio de sesión** (derrota → menú → partida nueva): sin slots duplicados ni errores.
12. **Contrato:** búsqueda con `-CaseSensitive` de `Inventory\.|Equipment\.|Characters\.|Resources\.|Items\.|EventBus` en la View y en los componentes nuevos devuelve vacío.
13. **Output y pestaña *Errors*** sin warnings nuevos (ni del marco de `UIPanel` ni "Razón desconocida").
14. **Layout:** sin recortes ni solapes con marco y padding mínimo 16 a 1152×648 y a 1680×1050.

## 11. Riesgos conocidos

- **Primer consumidor real de `UISlot`:** puede faltarle algo y obligar a ampliar el DS; cualquier cambio en `UISlot` debe quedar documentado en el README y no afectar a otros usos.
- **Arrastre** con el nuevo slot: payload distinto del que espera `EquipSlot`/`request_equip_drop()`; hay que mantener un único formato.
- **Alcance creciente:** D2, D6 y el equipar en slot concreto tocan core o Party; partir en 18a/18b si ocurre.
- **Layout por fracciones dentro de subpantallas** (PlayerMenu, narrativa) con otro padre o tamaño.
- **Rejilla dinámica:** reconstruir nodos en cada `changed` puede perder selección o foco; reutilizar nodos o conservar la selección en el ViewModel.
- **Altura útil a 648:** marco y padding mínimo 16 reducen el espacio; la maqueta debe medir con números reales.
- **Regresiones de refrescos** del 17 (`_mark_dirty()` + `_flush_dirty`) si cambia el árbol de nodos.
- **`.csv` editado a mano** que no se reimporta hasta que el editor recupera el foco; claves duplicadas (gana la última).
- **Mezcla de estilos:** inventario rediseñado junto a pantallas aún sin migrar (Party, PlayerMenu) hasta los spikes 19 y 22.

## 12. Entregables

**Código (completo):** `inventory_ui.gd`, `inventory_viewmodel.gd` (ampliado), `item_detail_panel.gd`, `feedback_popup.gd`; los scripts nuevos de la pantalla (celdas de rejilla, ficha, si los hay). **Escenas:** `inventory_ui.tscn`, `item_detail_panel.tscn`, `feedback_popup.tscn` y las nuevas, completas o como árbol de nodos legible. **Posible parche:** `ui_slot.gd`/`.tscn` y `ui_tokens.gd` si falta algo. **Datos:** `inventory.csv` ampliado (ES y EN). **Documentación del README del DS:** `UISlot` en uso real (estados, arrastre, marca de equipado).

**Documentación:**
- `docs/spike_18_inventario_rediseno.md` (informe de cierre: layout elegido y por qué, decisiones D1-D7, cambios en `UISlot`/ViewModel, claves, ficheros tocados, validación, lecciones y pendientes).
- `athelia_ui_architecture.md`, `README.md` (Design System), `athelia_estructura_carpetas.md`.
- `athelia_lecciones_tecnicas.md` y `athelia_historial_spikes.md`: entrada del Spike 18.
- `plan_hito_rediseno_interfaces_spikes_14_24.md`: marcar el 18 (o 18a) como cerrado, ajustar el 19 si cambia qué componentes retirar, y registrar pendientes (18b si procede).
