# Spike 21 — Árbol de habilidades: rediseño con el Design System

**Hito:** rediseño de interfaces · **Riesgo:** medio-alto · **Depende de:** Spike 15 (cerrado). Aprovecha lo aprendido en 18 (`UISlot`), 19b (`UIResourceBar`, `ItemDetailPanel`, pestañas de entidad) y 20 (tarjeta propia de pantalla, estado de selección en el ViewModel). **No depende** de 22-24; el 22 (Menú del jugador) sí depende de este.
**Fuentes leídas en esta sesión:** paquete Fase 0 del árbol (`skill_tree_screen.gd`, `skill_tree_screen.tscn`, `skill_tree_viewmodel.gd`), extractos del orquestador y del PlayerMenu, `ui_tokens.gd` (versión del paquete), `estado_actual.md`, informe del Spike 20, plan del hito.
**Aviso:** el paquete Fase 0 es **anterior** a los spikes 15-20 y la documentación ya describió el código de forma incorrecta varias veces. No he visto `SkillSystem.get_entity_skill_snapshot()`, `SkillProgression.execute_learning_session()`, `skills.csv` actual, `UITokens` actual ni `UISlot`/`UIResourceBar` tras 19b. Todo lo que dependa de ello va marcado **[sin verificar]** y se cierra en la Fase 0.

---

## 1. Qué es el Spike 21

El árbol de habilidades es la pantalla donde se consultan las skills de un personaje (jugador y compañeros) agrupadas por subcategoría y *tier*, se ve el detalle de cada una (efectos, uso, requisitos) y se «entrena» la seleccionada. También tiene un modo comparativa de party. Es la **pantalla más grande del hito** (~810 líneas de View que construyen la interfaz por código) y la última «de datos» antes del menú del jugador. Este spike la lleva al Design System, arregla sus fallos de uso y completa su localización, **sin cambiar las reglas de progresión** (que viven en `SkillProgression`).

## 2. Problema (lo leído en el paquete Fase 0)

### 2.1 Estructura y estilo (`skill_tree_screen.gd` / `.tscn`)
- **No usa `UIPanel`:** `CanvasLayer` + `Control` + `ColorRect` de fondo con **`Color(...)` literal en el `.tscn`**; los fondos y bordes de cabecera, pestañas, filtros y detalle se emulan con `_add_bg_rect()` / `_add_border_rect()` (ColorRect con `z_index`). Sin marco decorativo.
- **El botón de cierre probablemente está fuera de pantalla.** `CloseBtn` tiene `anchor_top = anchor_bottom = 1.0` y `offset_top = 4`, `offset_bottom = 36`: queda **por debajo** del borde inferior. El comentario de cabecera dice «ni el botón de cierre, que no tiene». Hoy solo se cierra con Esc. **[verificar en partida con captura]**
- **Sin título** de pantalla. Cabecera = selector de entidad + botón de modo.
- **Mezcla de `Button` raw y `UIButton`:** `ModeToggleBtn`, `TrainBtn` y `CloseBtn` son `Button` del `.tscn`; selector de entidad, pestañas y filtros sí son `UIButton` instanciados.
- **Tarjetas de skill construidas con `PanelContainer.new()`** y estados por `StyleBox` de `UITokens.make_stylebox()`; **`modulate.a`** para las bloqueadas; `ProgressBar.new()` sin estilo propio (apariencia por defecto de Godot).
- **Literales de estilo:** `DetailPct` con color y `font_size = 28` en el `.tscn`; `Vector2(110, 0)`, `Vector2(36, 0)`, `Vector2(200, 0)`, 3 px de barra y alturas 40/34/28 de cabeceras.
- **Tokens de la familia antigua:** `ACCENT_GREEN/AMBER/DANGER`, `ACCENT_*_B`, `BG_SELECTED`, `BORDER_PANEL`, `RADIUS_CARD`, `DISABLED_ALPHA`, `TEXT_GOLD` («usar solo ahí»). El Spike 15 fusionó vocabularios con alias; hay que decidir si se migran a los canónicos `COLOR_*` o se conservan los alias **[sin verificar el estado actual de `ui_tokens.gd`]**.
- **Árbol de nodos con 3-4 niveles bajo `Root/MainLayout/...`** pero casi todos los accesos ya son `%` (bien). La escena usa `HSeparator` por defecto entre barras.
- **Construcción dinámica con `queue_free()` sin `remove_child()`** previo (selector, pestañas, filtros, rejilla, comparativa) y `free()` en `_clear_dynamic_detail()`.

### 2.2 Interacción
- **Las skills bloqueadas no se pueden seleccionar** (`gui_input` solo se conecta si `is_unlocked`). El panel de detalle tiene sección de requisitos con ✓/✗ y `missing_prereqs`, pero **solo se ve para skills ya desbloqueadas**: el jugador no puede consultar qué le falta para desbloquear una.
- **Las tarjetas son `PanelContainer` con `gui_input`:** sin foco de teclado ni estado hover/pulsado; no son `UIButton`.
- **`TrainBtn` muestra «bloqueado» (`SKILL_TREE_BTN_LOCKED`) cuando no se puede entrenar por cualquier motivo** (sin progresión, prerrequisitos…), sin explicar cuál.
- **Resultado del entrenamiento opaco:** `request_train_selected_skill()` devuelve `""` tanto en `improved` como en `roll_failed`, y la View muestra siempre `SKILL_TREE_TRAIN_OK`. El jugador no sabe si la skill mejoró. **[verificar qué datos devuelve `execute_learning_session()`]**
- **«Entrenamiento» gratuito y sin límite:** el ViewModel construye un `LearningSession` de tipo `"PRACTICE"` con `source_level = max(valor actual, 20)` y lo ejecuta; `training_cost` está vacío («preparado para futuro»). Es regla de juego, **fuera de alcance**, pero hay que describirla bien en pantalla.

### 2.3 ViewModel (`skill_tree_viewmodel.gd`)
- Razones de `changed`: `opened`, `entity_changed`, `mode_changed`, `filter_changed`, `training_done`, `closed`. **`entity_changed` se usa para cualquier cosa** (cambio de entidad, de pestaña, de selección de skill, mejora o desbloqueo externo): la View repinta selector, pestañas, rejilla y detalle enteros por cada clic en una tarjeta.
- **`training_done` solo repinta el detalle:** la tarjeta de la rejilla conserva el porcentaje viejo hasta el siguiente repintado completo. **[verificar]**
- **`_on_skill_improved` / `_on_skill_unlocked`** refrescan el snapshot pero **no** refrescan `selected_skill` (queda el diccionario viejo) y emiten `entity_changed`. Con la pantalla modal hoy casi no ocurren, pero el listener existe.
- `available_entities` con `display_name = companion_id` («la View localizará esto»): el id sale crudo en la pestaña (pendiente heredado del Spike 15). Hay que resolver el nombre real (`Characters`/`CharacterDefinition.name_key`) **en el ViewModel**.
- `training_cost`, `_ai_suggestions` («Badge IA», borde ámbar): infraestructura **preparada y sin datos**. Código y claves (`SKILL_TREE_AI_BADGE`) para algo que no existe todavía.
- `get_filtered_skills()` **no la usa la View** (código muerto); el filtro «Entrenables» de `get_skills_by_tier()` (`unlocked and has_progression`) **no coincide** con `is_trainable` de la tarjeta (`… and prereqs_met`) **[verificar]**.
- Accede a `Skills`, `Party` y `SkillProgression` con `get_node_or_null("/root/...")` y construye el `LearningSession` con literales («PRACTICE», 20, 30). Funciona; la lógica de «qué sesión de entrenamiento» debería vivir en `SkillProgression` **[no se toca sin aprobación]**.
- Tier calculado por el ViewModel recorriendo prerrequisitos (límite 10); `canonical_order` de subcategorías hardcodeado en código (`MELEE`, `RANGED`, `EXPLORATION`, `DIALOGUE`, `NARRATIVE`, `ENEMY`).

### 2.4 Localización
- Pendientes ya anotados en `estado_actual.md`: `T%d` suelto sin localizar; claves sin definición `SKILL_META_COST_<RECURSO>`, `SKILL_NOT_FOUND`, `SKILL_NOT_LEARNED`, `SKILL_SLOTS`, `SKILL_A`, `SKILL_B`, `SKILL_CATEGORY`; revisar los textos nuevos de `skills.csv` y **`SKILL_ATTACK_LIGHT_DESC`** («atack», espacios); la descripción de la poción de vida (datos de ítems) **[sin verificar el estado actual]**.
- En el código: `tr(prereq_id)` sobre un **id de skill** (no una clave de nombre) → probablemente sale el id crudo; `tr(resource_id)` con `"stamina"` (existen `RESOURCE_*_NAME`; falta `RESOURCE_FOCUS_NAME`, también anotado en el Spike 20); `SKILL_SUBCATEGORY_<X>` generado por concatenación; `ATTR_ABBR_<X>`; `"%s ≥ %d%%"`, `"×%.1f"`, `"%d%%"`, `"%.1fs"` con formato fijo.
- Glifos `✓`, `✗`, `✕`, `—` como texto (dependen de la fuente) **[verificar que se ven]**.

### 2.5 Contexto de uso
- **Dos puntos de entrada:** subpantalla de PlayerMenu (`request_open_skill_tree` → `changed("open_skill_tree")` → `_open_subscreen`) y **`SceneOrchestrator.open_skill_tree(entity_id)`** (EXPLORATION, con *toggle*). En el paquete **no aparece ningún llamador de `open_skill_tree()`** [la Fase 0 debe buscarlo: lo mismo que `open_loadout()` en el Spike 20, código probablemente muerto]. El comentario habla de «ExplorationHUD pasa un companion_id» y de «cierre vía EventBus», **sin comprobar**.
- `closed` ya existe y la pantalla no se libera sola (documentado en el `.gd`).
- `_unhandled_input` con `ui_cancel` (el Loadout usó `_input` + `set_input_as_handled()`; **verificar por qué** y si Esc se pierde con un botón enfocado).

## 3. Objetivo

Que el árbol de habilidades sea **visualmente homogéneo** con Inventario/Party/Loadout (marco `UIPanel` OVERLAY, `UIButton`, tarjetas propias con tokens, `UIResourceBar`/barra con token, cierre visible), que **todas las skills sean seleccionables** (las bloqueadas muestran por qué), que el **resultado del entrenamiento se entienda** y que la pantalla esté **completamente localizada**, sin tocar las reglas de progresión ni los contratos públicos.

## 4. Decisiones ya tomadas (no reabrir)

1. **Contratos públicos intactos:** `SkillTreeScreen.open(entity_id := "player")`, señal `closed` (quien instancia hace `queue_free()`; la pantalla nunca se libera), `_open_subscreen` del PlayerMenu, `SceneOrchestrator.open_skill_tree()` (**solo se toca si la Fase 0 lo exige y con aviso**). `PlayerMenu` y `SceneOrchestrator` sin tocar salvo hallazgo.
2. **MVVM:** la View no accede a ningún sistema ni a clases de core. ViewModel hijo de la View; `changed(reason)`. **Cada razón nueva lleva su caso en la View en el mismo cambio.** El ViewModel entrega **claves**; la View traduce (o un solo criterio, el mismo que en Loadout).
3. **Reglas de progresión intactas:** `SkillProgression`, `Skills`, requisitos, valores, anti-grinding. No se tocan `core/` sin aprobación expresa.
4. **Marco:** `UIPanel` OVERLAY con marco decorativo (padding 16, fracción 0,9, tope 1400×820, fondo opaco), como Inventario/Party/Loadout. Referencia 1680×1050, mínimo 1152×648; anclas y fracciones, no píxeles fijos.
5. **Componentes del DS:** `UIButton` (variantes y tamaños existentes), `UIResourceBar.set_values()` si encaja (S4), tarjeta propia de pantalla `SkillCard` (patrón de `LoadoutCard`: `class_name`, en `ui/skill_tree/`). Cambios en componentes del DS **aditivos** y con aprobación.
6. **Solo tokens** (`BG_/BORDER_/TEXT_` y `COLOR_*`); sin `Color(...)`, sin `modulate` para estados, sin tamaños de fuente sueltos. Todo texto con `tr()` y claves `SKILL_TREE_*` (`skills.csv` o `skill_tree.csv` nuevo, ver 0.x), sin claves comunes.
7. **Nodos únicos `%`**, nunca rutas `$A/B/C`. Contenido de cada panel en **un único contenedor**.
8. **Maqueta antes de código:** 2-3 layouts a 1680×1050 y 1152×648 y espera de la elección.
9. **Absorbe del 15/16:** nombre real del compañero, `T1` localizado, claves sin definir, `SKILL_ATTACK_LIGHT_DESC`, `RESOURCE_FOCUS_NAME`.

## 5. Fase 0 — comprobaciones antes de escribir código

Cada punto termina como «confirmado», «descartado» o «cambia el diseño». **Empieza por 5.A.**

### 5.A Línea base y estado real

| # | Comprobación | Por qué |
|---|---|---|
| 0.1 | Capturas «antes» a 1680×1050 y 1152×648, ES y EN: modo individual con una skill seleccionada y sin selección, cada pestaña, cada filtro, modo comparativa con 0 y con 1-2 compañeros. | Referencia y medidas reales. |
| 0.2 | **¿Está el botón de cierre fuera de pantalla?** Captura y comprobación de `CloseBtn.global_position`. Probar cierre con Esc estando un botón enfocado. | Hallazgo 2.1 y 2.5. |
| 0.3 | Reproducir y anotar: seleccionar una skill bloqueada (no responde); entrenar con éxito, con tirada fallida, `challenge_too_low`, sin progresión; ver si el porcentaje de la tarjeta se actualiza tras entrenar. | Hallazgos 2.2 y 2.3. |
| 0.4 | Comprobar que los ficheros del paquete **coinciden con el código actual** (`Get-FileHash` o `Select-String` de `class_name SkillTreeScreen`, `signal closed`, `request_train_selected_skill`). | El paquete es anterior al hito. |
| 0.5 | Comportamiento actual de los contextos de apertura: desde PlayerMenu (¿entidad inicial?), y búsqueda de **llamadores de `open_skill_tree` / `close_skill_tree`** (HUD, atajos, `EventBus`, `InputMap`). | Si no hay llamadores, es código muerto (como `open_loadout()`). |

### 5.B Código

| # | Comprobación | Por qué |
|---|---|---|
| 0.6 | `SkillSystem.get_entity_skill_snapshot(entity_id)`: campos reales del diccionario (`skill_id`, `name_key`, `description_key`, `subcategory`, `mode`, `is_unlocked`, `current_value`, `has_progression`, `prereqs_met`, `missing_prereqs`, `prerequisite_requirements`, `effects`, `target_type`, `range_type`, `base_cooldown`, `costs`, `attribute_weights`, `training_cost`). | Contrato del que depende toda la pantalla. [sin verificar] |
| 0.7 | `SkillProgression.execute_learning_session()`: estructura del resultado (`reason`, valor anterior/nuevo, tirada), códigos de motivo, qué significa `challenge_too_low` y cómo se ve el anti-grinding. | Decide S7 (resultado visible). |
| 0.8 | Qué es un prerrequisito: ¿clave `skill_id` → umbral? ¿existe la definición para obtener su `name_key`? | `tr(prereq_id)` imprime el id crudo. |
| 0.9 | `Party.get_active_members()`: ¿incluye al jugador o solo companions?; origen del nombre real (`Characters.get_character_state(id)`, `CharacterDefinition.name_key`). | Nombre del compañero (S8). |
| 0.10 | Tokens: ¿siguen existiendo `ACCENT_*`, `ACCENT_*_B`, `BG_SELECTED`, `BORDER_PANEL`, `DISABLED_ALPHA`, `TEXT_GOLD`, `RADIUS_CARD`, `FONT_SIZE_XS/SM`, `SPACE_*` y a qué apuntan? ¿existe equivalente semántico para «mejorable» (verde), «sugerencia» (ámbar) y «peligro»? | Migración de tokens. |
| 0.11 | `UIButton`: ¿variante/estado «seleccionado» (toggle) para pestañas y filtros? ¿`min_square`, `icon_backdrop`, ancho completo? ¿Hay componente de pestañas en el DS (cómo lo hizo Party)? | Pestañas, filtros y selector de entidad. |
| 0.12 | `UIResourceBar`: ¿`set_values()` sirve para un 0-100 de skill y admite color/variante por token? Alternativa: barra propia con tokens. | S4. |
| 0.13 | Localización: `skills.csv` (y cualquier CSV del árbol): claves existentes y faltantes (`SKILL_TREE_*`, `SKILL_SUBCATEGORY_*`, `SKILL_EFFECT_*`, `SKILL_TARGET_*`, `SKILL_RANGE_*`, `SKILL_META_*`, `ATTR_ABBR_*`, `RESOURCE_*_NAME`); duplicados con `Group-Object`; registro del CSV en Project Settings. | Localización completa. |
| 0.14 | Datos: ¿qué subcategorías y cuántas skills tiene hoy cada entidad? ¿hay skills con `mode` ≠ COMBAT sin efectos (nota de exploración)? Máximo de tarjetas por fila a 1152×648. | Dimensionar la rejilla y las pestañas (hasta 6 subcategorías). |
| 0.15 | Contrato: `Select-String -CaseSensitive 'Skills\.|Party\.|Characters\.|SkillProgression|Color\(|StyleBoxFlat|ProgressBar|Button\.new|modulate'` en `skill_tree_screen.gd`, y `get_node_or_null\("/root` en el ViewModel. | Línea base de la auditoría de cierre. |
| 0.16 | Tamaño: contar líneas por responsabilidad (entidades, pestañas, filtros, rejilla, detalle, comparativa) para decidir la partición (S1). | Riesgo principal del spike. |
| 0.17 | Ruta de `SceneOrchestrator._show_overlay(OVERLAY_SKILL_TREE)` y `PlayerMenu._open_subscreen`: ¿cómo se instancia, cuándo se hace visible, quién conecta `closed`? | Mantener el contrato. |

## 6. Decisiones abiertas que resuelve el usuario al empezar

Preguntar **de una vez**, con lo que el código permite en cada una:

| # | Pregunta | Condicionante |
|---|---|---|
| S1 | **Partición.** (a) Una sola pasada; (b) **21a** = marco, cabecera, pestañas, filtros, rejilla de tarjetas, selección (incl. bloqueadas), detalle y localización; **21b** = modo comparativa, resultado del entrenamiento y limpieza del ViewModel. | 0.16; ~810 líneas de View. |
| S2 | **Layout.** (A) conservar estructura: cabecera arriba, pestañas y filtros en barras, rejilla a la izquierda, detalle a la derecha; (B) pestañas de subcategoría en columna izquierda y entidad como pestañas en la cabecera; (C) detalle como cajetín reutilizando el patrón de `ItemDetailPanel`. | 0.1, 0.14. |
| S3 | **Skills bloqueadas.** (a) seleccionables, con detalle de requisitos y «Entrenar» desactivado con el motivo; (b) no seleccionables (como hoy) pero con tooltip de requisitos. | Cambio de comportamiento. Recomiendo (a). |
| S4 | **Barra de progreso de la tarjeta.** `UIResourceBar` (`set_values`) o barra propia con tokens; ¿porcentaje numérico dentro o debajo? | 0.12. |
| S5 | **Estados de la tarjeta.** Mantener los cinco (bloqueada, seleccionada, sugerencia IA, entrenable, normal) con tokens, o **simplificar** (¿se elimina el estado «sugerencia IA» y el badge, que no tienen datos?). | `_ai_suggestions` vacío. |
| S6 | **Cabecera.** Título localizado + selector de entidad (pestañas con nombre real) + toggle comparativa + cierre `UIButton` visible arriba a la derecha. ¿Se confirma? ¿Se oculta el toggle y el selector si no hay compañeros? | 0.9. |
| S7 | **Resultado del entrenamiento.** (a) como hoy («Entrenado») pero con texto veraz; (b) distinguir «mejoró (+N)» y «no mejoró esta vez»; (c) además mostrar el motivo cuando no se puede entrenar (botón desactivado + línea explicativa). | 0.7: depende del resultado que devuelve el core. |
| S8 | **Nombre del compañero** y sus iniciales/retrato en la pestaña: solo nombre localizado, o nombre + estado (HP) como en Party. Recomiendo solo nombre. | 0.9. |
| S9 | **Infraestructura sin datos** (`training_cost`, `_ai_suggestions`, `selected_skill_has_ai_suggestion`, `get_filtered_skills`): (a) mantenerla; (b) retirar el código muerto y el badge en este spike. | S5. |
| S10 | **`open_skill_tree()` del orquestador** si no tiene llamadores (0.5): dejarlo como está y anotarlo (como en Loadout, L8) o eliminarlo en este spike. | Recomiendo anotarlo. |

**Recomendación a confirmar:** S1 (b), S2 (A) salvo que la maqueta diga otra cosa, S3 (a), S4 `UIResourceBar` si 0.12 lo permite, S5 simplificar a cuatro estados sin IA, S6 confirmada, S7 (c), S8 solo nombre, S9 (b), S10 anotar.

## 7. Alcance

### 7.A Estructura y componentes (21a si se parte)
- Raíz `UIPanel` OVERLAY (marco, fondo opaco) sustituyendo a `Root`/`Background`/`MainLayout`; **elimina** `_apply_panel_styles()`, `_add_bg_rect()` y `_add_border_rect()`.
- Cabecera con título, selector de entidad, toggle de modo y cierre `UIButton` visible.
- Pestañas de subcategoría y filtros como `UIButton` con variante activa/inactiva por token (sin `modulate`).
- Rejilla por tiers con etiqueta `T<n>` localizada (`SKILL_TREE_TIER` con parámetro); sin `HSeparator` por defecto: separador con token.
- `SkillCard` (nuevo, `class_name`): nombre, barra de progreso, porcentaje, estados con tokens, foco/hover, `signal card_pressed(skill_id)`.
- Panel de detalle en **un único contenedor** dentro de un `ScrollContainer`: nombre, porcentaje (token de fuente, no 28 fijo), descripción, efectos, uso, requisitos, botón de entrenar `UIButton`. Las filas de detalle se reconstruyen con `remove_child()` + `queue_free()`.
- Todos los nodos con `%`.

### 7.B Selección y datos que pasan al ViewModel
- Razones de `changed` más finas: `selection` (clic en una skill: repinta tarjetas afectadas y detalle), `tab`, `entity_changed` (solo cambio de personaje), `training_done` (repinta detalle **y** la tarjeta), además de las actuales. Cada una con su caso en la View.
- El ViewModel entrega estados de tarjeta ya calculados (`is_locked`, `is_trainable`, `is_selected`), el nombre real del compañero (clave o texto, un solo criterio), el nombre de cada prerrequisito y un campo con el **motivo** por el que no se puede entrenar.
- `selected_skill` se **refresca** tras mejoras/desbloqueos externos.
- Unificar el criterio del filtro «Entrenables» con `is_trainable`.

### 7.C Detalle y requisitos
- Requisitos con el **nombre localizado** de la skill, ✓/✗ con tokens (o icono), y umbral con formato localizado.
- Costes: `SKILL_META_COST_*` completas (o un único formato con el nombre del recurso `RESOURCE_*_NAME`).
- Si la skill es bloqueada (S3 a): detalle completo y «Entrenar» desactivado con motivo.

### 7.D Entrenamiento y feedback (21b si se parte)
- Línea de feedback en zona fija del marco, con token semántico y `Timer` (sin `SceneTreeTimer` suelto ni `add_theme_color_override`).
- Resultado según S7. El ViewModel sigue llamando a `SkillProgression`; si el core no devuelve el dato necesario, **se propone aparte**.

### 7.E Modo comparativa (21b si se parte)
- Cuadrícula con cabeceras de entidad (nombre real), subcategorías localizadas, celdas con valor y barra por token; estado vacío cuando no hay compañeros; scroll sin desbordes a 1152×648 con 1-2 compañeros.

### 7.F Localización
- Claves `SKILL_TREE_*` completas (ES y EN), definición de las faltantes (`SKILL_META_COST_*`, `SKILL_NOT_FOUND`, `SKILL_NOT_LEARNED`, `SKILL_SLOTS`, `SKILL_A`, `SKILL_B`, `SKILL_CATEGORY` o su retirada si no se muestran), `SKILL_ATTACK_LIGHT_DESC` corregida, `RESOURCE_FOCUS_NAME`, revisión de los textos nuevos de `skills.csv`. Revisión de duplicados con `Group-Object`.

### 7.G Documentación del pendiente
- Anotar en `estado_actual.md` lo que se decida no tratar aquí (código muerto del orquestador, `training_cost`, regla de progresión).

## 8. Cambio visual y funcional esperado

| Antes | Después |
|---|---|
| `ColorRect` + bordes emulados, sin marco | `UIPanel` con marco y tokens |
| Cierre probablemente fuera de pantalla | Botón de cierre visible; Esc igual |
| Solo las skills desbloqueadas se seleccionan | Todas se seleccionan; las bloqueadas muestran requisitos y motivo |
| Tarjeta `PanelContainer` + `ProgressBar` por defecto + `modulate` | `SkillCard` con tokens y barra del DS |
| «Entrenado» siempre | Resultado veraz (S7) |
| Tarjeta con % viejo tras entrenar | Se repinta la tarjeta |
| Compañero con id crudo | Nombre real localizado |
| `T1`, claves sin definir, id crudo en requisitos | Todo localizado |

**No cambian:** reglas de progresión, contratos públicos, `PlayerMenu`, `SceneOrchestrator` (salvo hallazgo), snapshots de `Skills`.

## 9. Fuera de alcance
- Cambios en `SkillProgression`, `Skills`, datos de skills o combate (solo se registran).
- Costes de entrenamiento reales, entrenadores, libros, límites de práctica (diseño).
- Sugerencias IA reales (solo se retira o se mantiene la infraestructura según S9).
- Pila de overlays del orquestador y `I`/`P` dentro del PlayerMenu (→ Spike 22).
- Retratos, iconos de skill definitivos y animaciones.

## 10. Reglas a respetar
- MVVM y antipatrones de `athelia_ui_architecture.md`; ViewModel hijo de la View; `closed` nunca se libera a sí mismo.
- Componentes del DS sin acceso a sistemas; setters de `@export` con `is_node_ready()`; subclase de `UIPanel` llama a `super._ready()` y fija `padding` antes.
- Un `PanelContainer` apila todos sus hijos; `ScrollContainer` con `size_flags_vertical = 3` reparte a partes iguales; `Label` con elipsis tiene ancho mínimo 0; el clic de un nodo arrastrable se emite al soltar.
- `remove_child()` antes de `queue_free()`; `Dictionary.get()` tipado con `as`, nunca `:=`; `tr()` no existe en funciones estáticas.
- Repintado diferido cuando el clic nace en un nodo que el propio repintado destruye (lección del Spike 20): **la tarjeta pulsada se destruye al repintar la rejilla**.
- Un ViewModel nuevo no se instala antes que su View si la View antigua usa su API: se entregan **juntos**.
- Auditar el contrato con `Select-String -CaseSensitive`. Teclas de depuración fuera de F5-F8.
- `.csv` con campos con comas entre comillas; claves únicas; registro manual del CSV si es nuevo.
- Commit o copia de `ui/skill_tree/` y `ui/design_system/` antes de empezar.

## 11. Validación en partida real

A 1680×1050 y 1152×648, ES y EN, con capturas antes/después:
1. **Línea base (0.1-0.5):** capturas, cierre, entrenamiento y contextos actuales, con Output.
2. **Apertura** desde PlayerMenu (cierre con X y con Esc vuelve al menú) y, si es alcanzable, con `open_skill_tree()`.
3. **Pestañas** de subcategoría y **filtros** (Todas, Entrenables, Desbloqueadas, Bloqueadas): coherentes con el estado de las tarjetas.
4. **Selección:** skill desbloqueada y skill bloqueada (detalle y requisitos), deselección, cambio de pestaña y de entidad sin selección fantasma.
5. **Entrenar:** éxito, tirada fallida, `challenge_too_low`, sin progresión, bloqueada; tarjeta y detalle actualizados; texto veraz.
6. **Entidades:** jugador y compañeros con nombre real localizado; loadout y valores propios de cada uno.
7. **Modo comparativa** con 0, 1 y 2 compañeros: cabeceras, celdas, scroll sin desbordes a 1152×648; volver a individual conserva la entidad.
8. **Detalle completo** de una skill de combate y una de exploración: efectos, uso, costes con nombre de recurso, atributos, requisitos con nombre de skill.
9. **Lista larga** y rejilla ancha a 1152×648: sin scroll horizontal ni barras espurias.
10. **Localización:** sin claves crudas en ES ni EN, sin ids crudos, sin `T1` suelto; glifos visibles.
11. **Regresión:** el HUD de combate y el Loadout (Spike 20) leen las mismas skills; entrenar no rompe el loadout.
12. **Reabrir** varias veces y tras **reinicio de sesión** (derrota → menú → partida nueva): sin tarjetas duplicadas ni selección fantasma.
13. **Contrato:** `Select-String -CaseSensitive` de sistemas core en `skill_tree_screen.gd` vacío; sin `Color(`, `StyleBoxFlat`, `ProgressBar`, `Button.new`, `modulate` ni `add_theme_*_override` con literales.
14. Pestaña *Errors* del Depurador sin avisos nuevos.

## 12. Riesgos conocidos
- **Tamaño del spike:** el mayor del hito; partir en 21a/21b (S1).
- **Paquete Fase 0 obsoleto:** el snapshot de `Skills` puede traer campos distintos de los documentados.
- **Destruir el nodo pulsado:** repintar la rejilla desde el clic de una tarjeta (repintado diferido).
- **Cambio de comportamiento (S3):** seleccionar skills bloqueadas es nuevo.
- **Resultado del entrenamiento (S7):** si el core no lo devuelve, hay que proponer un parche aparte.
- **Cantidad de tarjetas por fila** a 1152×648 y hasta 6 pestañas de subcategoría.
- **Tokens de la familia antigua:** migrar sin romper el Loadout/Inventario si comparten alias.
- **Código muerto** (`open_skill_tree()`, `get_filtered_skills()`, IA): difícil de validar en partida.
- **Doble repintado** por usar `entity_changed` para todo.

## 13. Entregables

**Código (completo):** `skill_tree_screen.gd`, `skill_tree_viewmodel.gd` (entregados juntos), `skill_card.gd` (nuevo). **Escenas:** `skill_tree_screen.tscn` (completa o como árbol de nodos legible, con el padre de cada nodo verificado; conserva uid) y, si procede, `skill_card.tscn`. **Parches:** `ui_tokens.gd` si falta algún token, componentes del DS (aditivos, con aprobación). **Datos:** `skills.csv` y/o `skill_tree.csv` ampliados (ES y EN, orden real de columnas) y registro en Project Settings si procede.

**Documentación:**
- `docs/spike_21_arbol_habilidades.md` (informe de cierre; si se parte, uno por entrega).
- `athelia_ui_architecture.md` (fila de SkillTree, estado editado en su sitio), `athelia_historial_spikes.md` (un párrafo con enlace), `athelia_estructura_carpetas.md`, README del Design System si cambia algún componente.
- `athelia_lecciones_tecnicas.md`: solo lecciones nuevas.
- `estado_actual.md`: tabla y pendientes (21 cerrado; 22 es el siguiente).
- Plan del hito: cerrar el 21 y anotar pendientes nuevos.
