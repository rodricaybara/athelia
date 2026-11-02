# Spike 20 — Loadout: rediseño con el Design System y selección con pista visual

**Hito:** rediseño de interfaces · **Riesgo:** medio-bajo · **Depende de:** Spike 18 (cerrado; `UISlot`, `ItemDetailPanel`). Los spikes 19a/19b ya están cerrados y aportan `UIResourceBar` usable, `drop_exclude_owner`, `highlight_drop_targets` y `ItemDetailBuilder`. **No depende** de 21-24.
**Fuentes leídas en esta sesión:** paquete Fase 0 del Loadout (`loadout_screen.gd`, `loadout_screen.tscn`, `loadout_viewmodel.gd`), plan del hito (sección Spike 20), informes 18, 19 y 19b.
**Aviso:** el paquete Fase 0 es **anterior** a los spikes 14-19b. No he visto `LoadoutState`, `SkillDefinition`, `UISlot` tras 19b, `UIButton` ni `loadout.csv` actuales. Lo que dependa de ello va marcado **[sin verificar]** y se cierra en la Fase 0 (la documentación ha descrito el código mal más de una vez).

---

## 1. Qué es el Spike 20

Loadout es la pantalla donde un personaje asigna **skills de combate** a los slots `attack_1..3`, `dodge`, `defense`, `escape` y **consumibles** a los slots de consumible. Es la última pantalla «de datos de personaje» que sigue con la arquitectura anterior al hito. Este spike la lleva al Design System **sin cambiar las reglas de asignación** (que ya están en el ViewModel) y resuelve dos problemas de uso: la selección en dos pasos **sin pista visual** y las claves sin traducir.

## 2. Problema (lo leído en el paquete Fase 0)

### View (`loadout_screen.gd` / `.tscn`)
- **Rutas largas `$Root/Panel/MarginContainer/VBox/...`** (6-7 niveles) para 8 nodos: frágiles. Hay que migrar a nombres únicos `%`.
- **Botones creados por código** (`Button.new()`, mínimo 80×60) para los slots y para cada entrada de la lista; `_clear_container` usa `free()`.
- **Literales de color y estado por `modulate`:** `Color(0.3,0.9,0.3)` (lleno), `Color(0.6,0.6,0.6)` (vacío), `Color(0.9,0.2,0.2)` (error), `Color(1.0,0.85,0.0)` (seleccionado). Rompe la regla de tokens.
- **Raíz `CanvasLayer` + `Control` + `PanelContainer` propios**, sin `UIPanel`/marco; no usa `UIButton` (ni el cierre «X» es el del Design System).
- **La View lee `LoadoutState.SKILL_SLOTS` y `CONSUMABLE_SLOTS`** (clase de core) para saber qué slots pintar y en qué fila va cada uno. Es un acoplamiento menor (constantes), pero la lista de slots y su agrupación deberían venir del ViewModel.
- **Selección en dos pasos sin pista visual:** se pulsa un slot (se «selecciona» solo como color), luego una entrada de la lista. Un segundo clic en el mismo slot lo **vacía** (`request_clear_slot`): una acción destructiva escondida en un gesto de selección. Sin ninguna indicación de qué se puede asignar al slot elegido. El estado `_selected_slot_id` vive **en la View**, no en el ViewModel.
- **Texto:** `"%s  [ST:%d]"` con «ST» fijo (sin `tr()`); los tooltips mezclan `tr()` con concatenación (`tr(...) + ": " + tag`); `FEEDBACK_DURATION = 2.5` con `SceneTreeTimer` y error por `modulate`.
- **Claves sin traducir** que arrastra la recopilación: `LOADOUT_TITLE`, `LOADOUT_SLOT_EMPTY`, `LOADOUT_SKILLS_AVAILABLE` **[sin verificar el estado actual en `loadout.csv`]**.

### ViewModel (`loadout_viewmodel.gd`)
- **Bien estructurado:** valida antes de escribir, expone `slots`, `available_skills`, `available_consumables`, `error_message` (claves `LOADOUT_ERROR_*`), razones `opened`/`slots`/`error`/`closed`. La View **no** toca Skills/Inventory/Characters.
- **Inconsistencia de traducción:** `SlotData.display_name` se rellena **ya traducido** (`tr(def.name_key)` en `_refresh_slots`), mientras `SkillSlotData`/`ConsumableSlotData.display_name` guardan la **clave** («Sin tr() — se traduce en la View»). La View hace `tr(...)` sobre ambos (la doble traducción de Spike 8 parece resuelta de forma implícita: `tr()` sobre un texto ya traducido lo devuelve igual). Conviene unificar: **el ViewModel entrega claves, la View traduce** (o al revés, pero uno solo).
- **Sin estado de selección** (ver arriba) y **sin información de «qué lista corresponde al slot elegido»**: la lista muestra todas las skills aprendidas y todos los consumibles aunque el slot elegido sea incompatible; el rechazo llega solo después de intentar (`LOADOUT_ERROR_WRONG_TAG`).
- **`error_message` no se limpia** tras un error si la siguiente operación tiene éxito por otra vía (`request_clear_slot` no lo reinicia) **[sin verificar el efecto]**.
- **`open()` con personaje inexistente** hace `push_error` y vuelve **sin emitir `changed`**: la pantalla podría quedar visible y vacía **[sin verificar quién la hace visible]**.
- **`request_assign_*` ignoran el retorno** de `_loadout.assign_skill/assign_consumable` **[sin verificar si devuelven bool]**.
- **Consumible duplicado:** nada impide asignar el mismo consumible a dos slots, ni comprueba que la cantidad total alcance **[sin verificar la regla deseada]**.
- **Lista de consumibles** recorre `Inventory.get_inventory(id)` y llama a `get_item_quantity` por cada ítem; sin ordenar (el orden de un `Dictionary.keys()` no es de diseño). Las skills tampoco se ordenan.
- El ViewModel no se suscribe a `EventBus` («se refresca entero al abrirse»). Con Loadout abierto, un cambio de inventario/skills no se refleja; hoy no ocurre porque la pantalla es modal, pero hay que confirmarlo.

### Contexto de uso
- Dos puntos de entrada: **subpantalla de PlayerMenu** (`_open_subscreen`) y **`open_loadout()`** del orquestador (solo EXPLORATION). `closed` lo conecta quien la instancia; la pantalla nunca se libera a sí misma. **[sin verificar el cableado actual]**.
- `open(character_id)`: la interfaz **no ofrece selector de personaje**; se abre para el que se le pase **[sin verificar quién pasa qué id: jugador, compañero activo]**.

## 3. Objetivo

Que Loadout sea **visualmente homogéneo** con Inventario/Party/Tienda (UIPanel OVERLAY con marco, `UIButton`, `UISlot` o equivalente, solo tokens, `%` en todos los nodos), que **la selección tenga pista visual** (qué slot está elegido y qué entradas de la lista son compatibles), y que **no cambie ninguna regla de asignación ni contrato público**.

## 4. Decisiones ya tomadas (no reabrir)

1. **Contratos públicos intactos:** `LoadoutScreen.open(character_id: String)`, señal `closed` (quien instancia hace `queue_free()`; la pantalla nunca se libera), `open_loadout()` del orquestador (EXPLORATION) y apertura desde PlayerMenu (`_open_subscreen`). `SceneOrchestrator` y `PlayerMenu` **sin tocar** salvo que la Fase 0 demuestre lo contrario (se avisa antes).
2. **MVVM:** la View no accede a ningún sistema ni a clases de core. El ViewModel es hijo de la View, con `changed(reason)`. **Cada razón nueva lleva su caso en la View en el mismo cambio.**
3. **Reglas de asignación del ViewModel intactas:** validación de tag del slot, skill aprendida, modo COMBAT, consumible en inventario. Cualquier regla nueva (consumible duplicado, etc.) es decisión del usuario (L6), no se cuela.
4. **Marco:** `UIPanel` OVERLAY con marco decorativo (padding 16, fracción 0,9, tope 1400×820, fondo opaco), como Inventario/Party. Referencia 1680×1050, mínimo 1152×648; anclas y fracciones, no píxeles fijos.
5. **Componentes del DS:** `UIButton` (variantes y tamaños existentes), `UISlot` si el gesto lo permite (L1). Cambios en componentes **aditivos** y solo con aprobación.
6. **Solo tokens** (`BG_/BORDER_/TEXT_` para superficies; `COLOR_*` para semántico) y **`tr()` con claves `LOADOUT_*`** en `loadout.csv` (`id,en,es`; verificar el orden real de columnas). Sin claves comunes.
7. **Nodos con nombre único `%`**, nunca rutas `$A/B/C`. Contenido de cada panel en **un único contenedor** (un `PanelContainer` apila todos sus hijos).
8. **Maqueta antes de código:** 2-3 layouts a 1680×1050 y 1152×648, y espera de la elección.
9. **Absorbe:** pista visual del primer clic y claves `LOADOUT_TITLE`, `LOADOUT_SLOT_EMPTY`, `LOADOUT_SKILLS_AVAILABLE`.

## 5. Fase 0 — comprobaciones antes de escribir código

Cada punto termina como «confirmado», «descartado» o «cambia el diseño». **Empieza por 5.A.**

### 5.A Línea base y estado real

| # | Comprobación | Por qué |
|---|---|---|
| 0.1 | Capturas «antes» de Loadout a 1680×1050 y 1152×648, ES y EN, con slots vacíos y llenos y con un slot seleccionado. | Referencia y medidas reales. |
| 0.2 | Comportamiento actual de los dos puntos de entrada: abrir desde PlayerMenu y con `open_loadout()` (¿qué atajo/llamada?), cerrar con X y con Esc, volver al juego. Anotar el Output. | Los dos contextos son la validación central. |
| 0.3 | Reproducir y anotar: clic en slot → clic en la lista; segundo clic en el mismo slot (¿vacía?); asignar skill con tag incorrecto; consumible sin cantidad; el **mismo consumible en dos slots**. | Fija qué es comportamiento y qué es accidente (L6). |
| 0.4 | Comprobar que los ficheros del paquete Fase 0 **coinciden con el código actual** (`Get-FileHash` o `Select-String` de `class_name LoadoutScreen`, `signal closed`, `LoadoutState`). | El paquete es anterior al hito. |

### 5.B Código

| # | Comprobación | Por qué |
|---|---|---|
| 0.5 | `LoadoutState`: constantes `SKILL_SLOTS`, `CONSUMABLE_SLOTS`, `get_required_tag`, `assign_*`/`clear_slot` (¿devuelven bool?), `get_skill/get_consumable`, serialización. Y quién escribe el loadout fuera de esta pantalla (combate lo lee). | Contrato del que depende la pantalla. [sin verificar] |
| 0.6 | Datos de los slots: ¿qué tag exige cada uno? ¿existe orden o agrupación en datos o solo en el código de la View (attack→fila 1; dodge/defense/escape→fila 2)? | Decide si la agrupación pasa al ViewModel o a datos. |
| 0.7 | `loadout.csv`: claves existentes, columnas y estado de `LOADOUT_TITLE`, `LOADOUT_SLOT_EMPTY`, `LOADOUT_SKILLS_AVAILABLE`, `LOADOUT_CONSUMABLES_AVAILABLE`, `LOADOUT_SELECT_SLOT_FIRST`, `LOADOUT_REQUIRES_TAG`, los seis `LOADOUT_ERROR_*`; duplicados con `Group-Object`; registro en Project Settings → Localization. | Localización completa. |
| 0.8 | Quién instancia Loadout y con qué id en cada contexto; conexión de `closed`; `_current_overlay` del orquestador; manejo de Esc anidado y de `I` dentro del PlayerMenu. | Contrato público. |
| 0.9 | `UISlot` actual: ¿admite mostrar una **skill** (sin `ItemDefinition`) con texto/icono? ¿`set_definition` solo acepta ítems? ¿hay `slot_label_text` útil para «ataque 1»? ¿`set_selected` y estados vacío/lleno/desbordado? | Decide L1: `UISlot` o botones anchos. |
| 0.10 | `UIButton`: ¿variante/estado «seleccionado» (toggle)? ¿`min_square`, `icon_backdrop`? ¿ancho completo para filas de lista? | Idem. |
| 0.11 | `SkillDefinition`: campos reales (`name_key`, `tags`, `mode`, `get_cost`), descripción localizada y recursos (¿solo estamina o también otros?) para sustituir el «ST» fijo. | Texto del coste y detalle. |
| 0.12 | `ItemDetailBuilder`/`ItemDetailPanel` (Spike 19b): ¿sirven para mostrar un consumible seleccionado? ¿hay equivalente para una skill o hay que crear un detalle mínimo? | Cajetín de detalle (L3). |
| 0.13 | `Characters` y `Party`: forma de obtener los ids de personajes jugables y su nombre, por si L5 incluye selector de personaje. Ya hay `PartyManager.MAX_PARTY_SIZE = 3` frente al «2» de diseño. | Alcance de L5. |
| 0.14 | Quién más refresca Loadout: ¿algún sistema modifica el loadout o el inventario mientras la pantalla está abierta (efecto de combate, narrativa)? | Decide si el ViewModel necesita escuchar `EventBus`. |
| 0.15 | Contratos: `Select-String -CaseSensitive` de `Skills\.|Inventory\.|Characters\.|Items\.|LoadoutState` en `loadout_screen.gd` (y los resultados esperados: solo `LoadoutState`). | Línea base de la auditoría de cierre. |

## 6. Decisiones abiertas que resuelve el usuario al empezar

Preguntar **de una vez**, con lo que el código permite en cada una:

| # | Pregunta | Condicionante |
|---|---|---|
| L1 | **Forma del slot:** (a) `UISlot` cuadrado con nombre/icono y etiqueta del slot; (b) botón ancho tipo «ficha» con etiqueta del slot a la izquierda y la skill a la derecha; (c) mixto (skills en ficha, consumibles en `UISlot`). | 0.9, 0.10; un `UISlot` sin icono de skill puede quedar pobre. |
| L2 | **Mecanismo de asignación:** (a) clic en slot + clic en la lista (con pista visual y lista filtrada por compatibilidad); (b) arrastre desde la lista al slot (`UISlot` ya soporta drop y resaltado); (c) ambos. | 0.9; el clic de un slot arrastrable se emite al soltar. |
| L3 | **Detalle:** ¿cajetín con descripción/coste/tags/cantidad de lo elegido, tooltip, o nada? | 0.11, 0.12. |
| L4 | **Vaciar un slot:** hoy es el segundo clic sobre el slot seleccionado (destructivo y escondido). ¿Botón «Vaciar» en el slot/detalle, clic derecho, ambos, o se mantiene? | Cambio de comportamiento a aprobar. |
| L5 | **Personaje:** ¿Loadout se abre siempre para el id recibido (como ahora) o se añade selector/pestañas de personaje (jugador y compañeros)? | 0.8, 0.13; si hay pestañas, mismo patrón que Party. |
| L6 | **Reglas nuevas del ViewModel:** (a) ninguna (solo UI); (b) impedir el mismo consumible en dos slots; (c) avisar si la suma de slots supera la cantidad en inventario. | 0.3; (b) y (c) son lógica nueva y se aprueban aparte. |
| L7 | **Lista de disponibles:** ¿mostrar todas con las incompatibles atenuadas y motivo, o **solo las compatibles con el slot elegido** (y todas sin slot elegido)? ¿Orden alfabético? ¿Indicar en qué slot está ya asignada cada una? | Cambio de reglas de presentación. |

**Recomendación a confirmar:** L1 (c), L2 (c) si 0.9 lo permite o (a) si no, L3 cajetín compacto, L4 botón «Vaciar» **y** mantener el segundo clic sin confirmación, L5 sin selector (como hoy), L6 (a), L7 todas con las incompatibles atenuadas y motivo.

## 7. Alcance

### 7.A Estructura y componentes
- Raíz `UIPanel` OVERLAY (marco, fondo opaco) sustituyendo a `Root`/`Panel`/`MarginContainer`; cabecera con título y cierre (`UIButton` GHOST o el patrón de Party/Inventario).
- Dos columnas (slots a la izquierda, disponibles a la derecha) en contenedores propios; cada panel con **un solo hijo contenedor**.
- Todos los nodos accedidos con `%`.
- `UIButton`/`UISlot` en lugar de `Button.new()`; las filas de la lista se reconstruyen con `remove_child()` antes de `queue_free()` (no `free()`).

### 7.B Selección con pista visual (núcleo del spike)
- Slot seleccionado: `set_selected(true)` (borde/realce por token); sin `modulate`.
- Estado de selección **en el ViewModel** (`selected_slot_id`) con razón nueva `selection` y su caso en la View. La View solo traduce clics en intenciones (`request_select_slot`, `request_clear_slot`).
- Al elegir un slot, la lista indica **qué es compatible** (L7): tag requerido visible en el slot de skill («requiere: ataque»), consumibles solo para slots de consumible.
- Sin slot elegido, mensaje guía persistente (no solo error al intentar): clave `LOADOUT_SELECT_SLOT_FIRST`.
- Vaciar según L4. Reglas de selección al cerrar/reabrir: sin selección fantasma.

### 7.C Datos que pasan al ViewModel
- Lista de slots y su agrupación (ataque / defensa / consumibles) como datos del ViewModel, para que la View no lea `LoadoutState`.
- Nombres: unificar quién traduce (ver §2). El coste de la skill se entrega estructurado (valor + recurso) y la View compone el texto con una clave `LOADOUT_*` con parámetro (`LOADOUT_COST`, p. ej.), no «ST» fijo.
- Orden determinista de skills y consumibles.
- `open()` inválido: emitir un `changed("error")`/`closed` coherente en vez de dejar la pantalla en blanco (si 0.8 confirma el problema).

### 7.D Feedback
- Mensaje de resultado y error en una zona fija del marco, con color de **token** semántico y temporizador (se mantiene la duración o se mueve a una constante nombrada). Sin `modulate`.

### 7.E Localización
- Claves `LOADOUT_*` completas en ES y EN (título, vacío, secciones, coste, requisitos, guía, errores, nuevas del bloque L3/L4/L7). Revisión de duplicados.

### 7.F Documentación del pendiente
- Anotar en `estado_actual.md` cualquier hallazgo del núcleo (p. ej. consumible duplicado) que se decida no tratar aquí.

## 8. Cambio visual y funcional esperado

| Antes | Después |
|---|---|
| Panel plano a pantalla completa, botones por código, colores literales | `UIPanel` con marco, `UIButton`/`UISlot`, tokens |
| Selección invisible; segundo clic vacía | Slot resaltado, lista filtrada/atenuada, vaciar explícito (L4) |
| «ST:%d» fijo | Coste localizado con clave y parámetro |
| Claves sin traducir | `LOADOUT_*` completas en ES/EN |
| Rutas `$Root/...` | `%` |
| La View lee `LoadoutState` | La View solo lee datos del ViewModel |

**No cambian:** reglas de asignación, contratos públicos, `LoadoutState`, `SceneOrchestrator`, `PlayerMenu`, el uso del loadout en combate.

## 9. Fuera de alcance
- Cambios en `LoadoutState`, `Skills`, `Inventory`, combate o datos de skills (solo se registran).
- Reglas nuevas de asignación (L6 distinta de (a)) sin aprobación aparte.
- El árbol de habilidades (21) y la pila de overlays / `I` dentro del PlayerMenu (22).
- Arrastre de consumibles desde la mochila del inventario hacia Loadout.
- Retratos, iconos de skills definitivos y animaciones.

## 10. Reglas a respetar
- MVVM y antipatrones de `athelia_ui_architecture.md`; ViewModel hijo de la View; `closed` nunca se libera a sí mismo.
- Componentes del DS sin acceso a sistemas; setters de `@export` con `is_node_ready()`; subclase de `UIPanel` llama a `super._ready()` y fija `padding` antes.
- Un `PanelContainer` apila todos sus hijos; `ScrollContainer` con `size_flags_vertical = 3` reparte a partes iguales; `Label` con elipsis tiene ancho mínimo 0; el clic de un slot arrastrable se emite al soltar.
- `remove_child()` antes de `queue_free()`; `Dictionary.get()` tipado con `as`, nunca `:=`; `tr()` no existe en funciones estáticas.
- Un ViewModel nuevo no se instala antes que su View si la View antigua usa su API: se entregan **juntos**.
- Auditar el contrato con `Select-String -CaseSensitive`. Teclas de depuración fuera de F5-F8 (son del editor).
- `.csv` con campos con comas entre comillas; claves únicas (`Group-Object`); registro manual del CSV si es nuevo.
- Commit o copia de `ui/loadout/` y `ui/design_system/` antes de empezar.

## 11. Validación en partida real

A 1680×1050 y 1152×648, ES y EN, con capturas antes/después:
1. **Línea base (0.1-0.4):** capturas, comportamiento actual de ambos contextos, Output.
2. **Asignar una skill** a cada tipo de slot (ataque, esquiva, defensa, huida): se refleja en el slot y persiste al cerrar y reabrir.
3. **Asignar un consumible** y comprobar el nombre y la cantidad.
4. **Slot incompatible:** skill con tag equivocado → rechazo con mensaje localizado visible, slot sin cambios; si L7 atenúa, la entrada incompatible lo indica.
5. **Consumible inválido** (sin cantidad / ítem no consumible): rechazo con mensaje.
6. **Vaciar un slot** (por el mecanismo de L4) y el segundo clic si se mantiene.
7. **Pista visual:** sin slot elegido (mensaje guía), con slot elegido (realce y lista), al cambiar de slot, tras asignar (la selección se resuelve según lo decidido), tras cerrar y reabrir (sin selección fantasma).
8. **Dos contextos:** subpantalla de PlayerMenu (cerrar vuelve al menú) y `open_loadout()` en EXPLORATION (cerrar vuelve al juego); Esc anidado; `I` y `O` según lo documentado.
9. **Personaje:** jugador y, si aplica, compañero; loadout propio de cada uno, sin mezclar.
10. **Lista larga** de skills/consumibles a 1152×648: scroll sin desbordes ni barras espurias.
11. **Combate:** el loadout asignado aparece en combate y la skill asignada se usa (regresión del uso del loadout).
12. **Localización:** sin claves crudas en ES ni EN; sin dobles traducciones; sin «ST» fijo.
13. **Reabrir** varias veces y tras **reinicio de sesión** (derrota → menú → partida nueva): sin slots duplicados.
14. **Contrato:** `Select-String -CaseSensitive` de sistemas core en `loadout_screen.gd` vacío (incluido `LoadoutState`); sin `Color(` ni `$Root/` en la View.
15. Pestaña *Errors* del Depurador sin avisos nuevos.

## 12. Riesgos conocidos
- **Paquete Fase 0 obsoleto:** puede no coincidir con el código actual (0.4).
- **`UISlot` pensado para ítems:** mostrar una skill puede exigir un parche aditivo o descartar `UISlot` para skills (L1).
- **Cambio de gesto de vaciado:** altera un comportamiento existente (L4).
- **Estado de selección movido al ViewModel:** una razón nueva sin caso en la View deja la pantalla sin actualizar.
- **Doble traducción** al unificar quién traduce: probar en EN y ES, y con textos ya traducidos.
- **Dos contextos de apertura:** un cierre que no devuelva al sitio correcto; `closed` conectado por duplicado.
- **Loadout abierto durante cambios externos** (inventario/skills) sin refresco (0.14).
- **Consumible duplicado o sin existencias** en el loadout (L6) y su efecto en combate.
- **Altura a 1152×648** con tres filas de slots, cajetín y feedback.

## 13. Entregables

**Código (completo):** `loadout_screen.gd`, `loadout_viewmodel.gd` (entregados juntos). **Escenas:** `loadout_screen.tscn` (completa o como árbol de nodos legible, con el padre de cada nodo verificado). **Parches:** `ui_slot.gd`/`ui_button.gd` (aditivos, solo con aprobación), `ui_tokens.gd` si falta algún token. **Datos:** `loadout.csv` ampliado (ES y EN, orden real de columnas) y registro en Project Settings si procede.

**Documentación:**
- `docs/spike_20_loadout.md` (informe de cierre: respuestas L1-L7, cambios en View/ViewModel, validación, lecciones y pendientes).
- `athelia_ui_architecture.md` (fila de Loadout, estado editado en su sitio), `athelia_historial_spikes.md` (un párrafo con enlace), `athelia_estructura_carpetas.md`, README del Design System si cambia algún componente.
- `athelia_lecciones_tecnicas.md`: solo lecciones nuevas.
- `estado_actual.md`: tabla y pendientes (20 cerrado; 21 es el siguiente).
- Plan del hito: cerrar el 20 y anotar pendientes nuevos.
