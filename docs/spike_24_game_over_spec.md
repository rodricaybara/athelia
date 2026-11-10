# Spike 24 — Game Over: rediseño visual y limpieza de cierre del hito

**Hito:** rediseño de interfaces · **Riesgo:** bajo (pantalla) / bajo-medio (limpieza, por tocar varios ficheros ajenos) · **Depende de:** Spikes 14 (lógica de derrota y reinicio de sesión), 15 (Design System) y 23 (`TitleBackdrop`, tokens `FONT_SIZE_DISPLAY`/`COLOR_SCRIM`/`COLOR_MODAL_VEIL`), todos cerrados. **Es el último spike del hito:** además del rediseño, cierra el hito (limpieza y documentación).
**Fuentes leídas en esta sesión:** informe del Spike 14 (diseño final del Game Over y del reinicio de sesión), informe del Spike 23 (`TitleBackdrop`, `OptionsPanel`, `GameSettings`, pendientes), informes de los Spikes 20-22 (pendientes de limpieza), plan del hito (§6 «Abiertos» y §8) y el `game_over_ui.tscn` del paquete inicial.
**Aviso:** no he visto el código **actual** de `GameOverUI` ni de `GameOverViewModel`. El `game_over_ui.gd` que tengo es **anterior al Spike 14** (contenía lógica de juego y un botón «Nueva partida»); el `.tscn` también es anterior (se renombró `NewGameButton` → `ReturnToMenuButton`, se vaciaron los textos y `TitleLabel` pasó a nombre único). Todo lo que describo del estado actual lo extraigo del informe del Spike 14 y va marcado **[sin verificar]** hasta la Fase 0.

---

## 1. Qué es el Spike 24

El Game Over es la pantalla de derrota: se muestra cuando caen todos los aliados en combate y ofrece un único botón hacia el menú principal. La **lógica ya está resuelta** (Spike 14): `GameOverViewModel.request_return_to_menu()` → `transitioning` → un frame → `GameLoop.enter_main_menu()`, y al entrar en `MENU` el orquestador libera la pantalla y las escenas de sesión y ejecuta `SessionReset`. Falta lo visual: es la única de las ocho pantallas del hito que sigue **sin tokens, sin `UIPanel` y sin identidad**, y debe heredar el estilo de arte del Spike 23. El spike añade una **segunda parte de cierre del hito**: limpieza de restos de depuración y de documentación, y una auditoría global de contrato.

## 2. Problema

### 2.1 Pantalla (`game_over_ui.tscn` / `.gd`) **[sin verificar el estado actual]**
- **Fondo** `ColorRect` con **`Color(0, 0, 0, 0.85)` literal** (velo sobre la escena de combate que sigue detrás).
- **Tamaños de fuente sueltos** en la escena: 48 (título) y 20 (mensaje y botón); `theme_override_constants/separation = 24`; botón con `custom_minimum_size = (240, 48)` fijo.
- **`Button` estándar** (no `UIButton`), sin variante ni tamaño del Design System; **sin `UIPanel`**, sin marco.
- **Estructura** `CanvasLayer` (`layer = 100`) → `CenterContainer` → `VBox` con `Label`/`Label`/`Button`, sin `TitleBackdrop` ni arte.
- **Foco:** el botón **no pide foco** (según el análisis previo al Spike 14).
- **Botón ancho:** «Volver al menú principal» es más largo que el texto anterior; hoy `custom_minimum_size.x = 240` fijo (el plan lo deja para resolver en la maqueta).
- **Entrada:** la versión anterior bloqueaba todo el input con `_unhandled_input` + `set_input_as_handled()`. No sé si se conservó ni si el botón se activa con Intro/Espacio **[verificar]**.
- **Textos:** `GAMEOVER_TITLE`, `GAMEOVER_MESSAGE` y `GAMEOVER_BUTTON_MENU` viven en `localization/menus.csv` (columnas `id,es,en`), junto con `LOADING_LABEL`. Tras el Spike 23, `menus.csv` solo conserva estas claves y `LOADING_LABEL`. El mensaje tiene salto de línea (`\n`) y autowrap en el `Label`.
- **Sin ViewModel nuevo que hacer:** `GameOverViewModel` existe (Spike 14) con una intención y las razones `opened` / `transitioning` (reabre el botón si la transición a `MENU` falla).

### 2.2 Restos del hito que quedan por limpiar (inventario recogido de los informes)
| Resto | Origen | Detalle |
|---|---|---|
| Autoload `DebugPartyTool` | 19b, 20 | El 19b lo retiró (fichero y autoload) pero el informe del 20 lo sigue viendo en `project.godot` (línea 56) y la traza `[DBG] tecla:` en el Output. **[verificar]** |
| Traza `[DBG] tecla:` | 22 | En `ExplorationController`. |
| Traza `[DIAG]` | 22 | En `narrative_scene_panel.gd`. |
| Etiqueta de depuración visible en el HUD de exploración (`estado \| paused=`) | 14/15 (§6 del plan) | «barrido final». |
| Duplicado `damage_number.tscn` (`ui\` y `ui\combat\`) | 14/15 (§6 del plan) | Toca combate: en el plan figura también en el §8 (barrido opcional). |
| `localization/menus.csv.bak` | 23 | Fichero de ayuda. |
| `menus.csv` | 23 | Quedan `LOADING_LABEL` y `GAMEOVER_*`; fila `MENU_CONFIRM_YES` con comas sin comillas (ya resuelta o retirada: **verificar**). |
| Comentarios obsoletos | 20, 22 | `open_loadout()` («llamado desde `PlayerMenuViewModel.request_open_loadout()`»), «Tecla I / Tab» en `ExplorationController` (Tab no está enlazada; acción `toggle_inventory` sin uso), comentarios de `athelia_ui_architecture.md`. |
| `TRANSITIONING` atascado en el menú principal | 23 | Si `enter_post_load_state()` o `enter_character_creation()` rechazan la transición, el menú no se recupera (patrón que el 14 resolvió en el Game Over con `opened`). |
| Líneas de documentación | todos | README del Design System: «Pantallas pendientes de migrar: menú del jugador, Loadout, árbol de habilidades y Game Over»; tabla de `athelia_ui_architecture.md` (fila de Game Over: «pendiente»); `estado_actual.md`. |

### 2.3 Contexto de uso (a validar)
1. **Derrota en combate de producción** (`combat_ended("defeat")` → `_show_game_over()`).
2. **Derrota en un combate lanzado desde una escena narrativa** (el Spike 14 no lo probó por separado).
3. **Derrota con 0, 1 y 2 compañeros.**
4. **Botón → `MENU`:** el orquestador libera `GameOverUI`, `CombatHud`, `CombatScene` y `ExplorationScene`, ejecuta `SessionReset` y el menú principal (Spike 23) vuelve a `MAIN`.
5. **Nueva partida / Cargar partida tras la derrota** (sin entidades ni estado heredados).

## 3. Objetivo

Que el Game Over sea **visualmente homogéneo** con el resto del hito (tokens, `UIButton` `LG`, `UIPanel` o `TitleBackdrop` según la maqueta, título con `FONT_SIZE_DISPLAY`, foco inicial, botón de ancho acorde al texto, textos en CSV propio), **heredando el estilo del Spike 23**, sin cambiar la lógica del Spike 14 ni el flujo de reinicio de sesión; y que el hito quede **cerrado**: restos de depuración fuera, auditoría global de contrato hecha, documentación al día.

## 4. Decisiones ya tomadas (no reabrir)

1. **Lógica y flujo intactos:** `GameOverViewModel` (intención `request_return_to_menu()`, razones `opened`/`transitioning`), `SceneOrchestrator._show_game_over()` / `_handle_main_menu()` / `_free_session_scenes()` / `_run_session_reset()`, `SessionReset`. Sin cambios de core. Botón único hacia el menú (decisión del Spike 14) salvo que lo reabra el usuario en G5.
2. **MVVM:** la View no accede a sistemas; cualquier razón nueva de `changed` lleva su caso en la View en el mismo cambio. La pantalla **nunca se libera a sí misma**: la libera el orquestador al entrar en `MENU`.
3. **Estilo del Spike 23:** se reutiliza `TitleBackdrop` (fondo y título) y los tokens `FONT_SIZE_DISPLAY`, `COLOR_SCRIM`, `COLOR_MODAL_VEIL`; botón `UIButton` `LG` instanciado desde `ui_button.tscn`; sin `Color(...)`, sin `modulate`, sin tamaños de fuente sueltos.
4. **Nodos únicos `%`**, contenido de cada panel en un único contenedor; anclas y fracciones (referencia 1680×1050, mínimo 1152×648, sin estiramiento).
5. **Textos con `tr()`** y claves con prefijo de pantalla en un CSV propio (`game_over.csv`, `GAME_OVER_*`, `id,en,es`; alta manual en Project Settings → Localization); las `GAMEOVER_*` salen de `menus.csv`.
6. **Maqueta antes de código:** 2-3 layouts a 1680×1050 y 1152×648 y espera de la elección.
7. **Cambios en componentes del DS aditivos y con aprobación** (p. ej. un parche de `TitleBackdrop` si hace falta un fondo translúcido o otro color de título).
8. **Limpieza de cierre acotada:** solo retiradas y correcciones triviales con ancla única y lista cerrada de ficheros (§7.F); nada de refactors ni cambios de comportamiento.

## 5. Fase 0 — comprobaciones antes de escribir código

Cada punto termina como «confirmado», «descartado» o «cambia el diseño». **Empieza por 5.A.**

### 5.A Línea base y estado real

| # | Comprobación | Por qué |
|---|---|---|
| 0.1 | Cómo provocar la derrota en partida (combate de producción, combate narrativo, 0/1/2 compañeros) y capturas «antes» de la pantalla a 1152×648 y 1680×1050, ES y EN. | Referencia y que los pasos sean repetibles. |
| 0.2 | Comprobar que los ficheros actuales (`game_over_ui.gd`, `.tscn`, `game_over_viewmodel.gd`, `_show_game_over()` del orquestador) **coinciden con el informe del Spike 14** (`Select-String` de `class_name GameOverUI`, `ReturnToMenuButton`, `request_return_to_menu`, `layer`). | El paquete es anterior al 14. |
| 0.3 | Qué hace hoy la pantalla con el input: Esc, Intro, Espacio, clics fuera del botón, teclas `I`/`H`/`O`/`P`; ¿llegan a la exploración o al orquestador en estado `DEFEAT`? | Bloqueo de entrada y foco. |
| 0.4 | `layer` de `GameOverUI` (100) frente a `CombatHud`, overlays (10) y menú; qué se ve detrás (¿combate congelado?, ¿HUD de combate?). | Decide G2 (velo translúcido u opaco). |
| 0.5 | Mapa de flujos con el Output: derrota → botón → menú → Nueva partida / Cargar; doble clic rápido en el botón; `Return to menu requested` repetido. | No regresionar el 14. |

### 5.B Código y datos

| # | Comprobación | Por qué |
|---|---|---|
| 0.6 | `TitleBackdrop`: exports (`background_texture`, `title_text`, `show_title`, `title_top_fraction`), color base, velo, color/tamaño del título, mouse_filter, si es opaco por defecto, si acepta un título distinto de «ATHELIA» y un color por token. | Qué hace falta parchear (G2/G3). |
| 0.7 | `UIButton`: variantes y tamaños (`LG`, `PRIMARY`/`DANGER`), estilo de foco, ancho mínimo; `UIPanel`: variantes (marco, `OVERLAY`, modal pequeño del Spike 23) y cómo se centra por contenido (anclas al centro + `grow` a ambos lados + offsets a 0). | Layout A/B/C. |
| 0.8 | `ui_tokens.gd`: tokens de color para título de derrota (peligro/acento), texto secundario del mensaje, espaciados. | Solo tokens. |
| 0.9 | `menus.csv`: claves actuales (`GAMEOVER_*`, `LOADING_LABEL`), duplicados con `Group-Object`, filas con comas sin comillas, orden de columnas (`id,es,en`); quién usa `LOADING_LABEL` (`LoadingScreen` no conectada). | Migración a `game_over.csv`. |
| 0.10 | Quién llama a `_show_game_over()` y desde dónde se emite `combat_ended("defeat")` (producción y narrativa); qué estado tiene `GameLoop` (`DEFEAT`). | Contextos 2.3. |
| 0.11 | `GameOverViewModel`: datos que podría exponer (nº de caídos, escena, etc.) y confirmación de que `opened` reabre el botón si la transición falla. | Alcance del mensaje (G4). |

### 5.C Cierre del hito (inventario real)

| # | Comprobación | Por qué |
|---|---|---|
| 0.12 | `Select-String -Path .\project.godot -Pattern 'DebugPartyTool|\[autoload\]' -Context 0,40` y `Get-ChildItem -Recurse -Include *.gd,*.tscn | Select-String -CaseSensitive 'DebugPartyTool|\[DBG\]|\[DIAG\]|estado \| paused'` | Inventario exacto de restos de depuración. |
| 0.13 | `Get-ChildItem -Recurse -Filter damage_number.tscn` y quién referencia cada ruta (`Select-String 'damage_number'`). | Decidir si se retira un duplicado (G8). |
| 0.14 | **Auditoría global de contrato** sobre `ui\` y `core\` (excluyendo `test*`, `debug*` y las pantallas fuera del hito): `Select-String -CaseSensitive 'Color\(|StyleBoxFlat\.new|Button\.new|Label\.new|\$Root|modulate'` por pantalla; accesos a core desde Views (`Skills\.|Inventory\.|Characters\.|Items\.|Party\.|Economy\.|Narrative\.|Resources\.`). | Informe de lo que queda (CharacterCreation, HUD, combate, narrativa). |
| 0.15 | Comentarios obsoletos y acciones sin uso: `open_loadout`, «I / Tab», `toggle_inventory`, `open_skill_tree`/`close_skill_tree`, `SceneOrchestrator.close_*` sin llamadores. | Qué se retira y qué se anota. |
| 0.16 | Estado de la documentación: README del DS (línea de pantallas pendientes), fila de GameOver en `athelia_ui_architecture.md`, tabla y pendientes de `estado_actual.md`, `athelia_estructura_carpetas.md` (rutas nuevas de los Spikes 18-23). | Lista de ediciones de cierre. |
| 0.17 | `menus.csv.bak` y otros `.bak` o ficheros temporales en el repo. | Limpieza. |

## 6. Decisiones abiertas que resuelve el usuario al empezar

Preguntar **de una vez**, con lo que el código permite en cada una:

| # | Pregunta | Condicionante |
|---|---|---|
| G1 | **Layout.** (A) Título grande de derrota arriba y, centrados bajo él, mensaje y botón sobre el fondo (como el menú principal); (B) modal con `UIPanel` y marco centrado sobre un velo (título, mensaje y botón dentro); (C) título arriba y mensaje en un `UIPanel` con marco, botón debajo. | 0.6, 0.7; la maqueta decide. |
| G2 | **Fondo.** (a) `TitleBackdrop` opaco con el placeholder del 23 (misma identidad; oculta el combate congelado); (b) velo translúcido (`COLOR_SCRIM`) sobre la escena de combate, como hoy (0,85), que exigiría un parche aditivo de `TitleBackdrop` (base translúcida). | 0.4. Recomiendo (a). |
| G3 | **Título.** Texto localizable («Game Over» / «Fin de la partida» / otro) con `FONT_SIZE_DISPLAY` y color de peligro por token, o `COLOR_ACCENT` como el menú. | 0.8. |
| G4 | **Mensaje.** Se mantiene el texto actual («Todos han caído. No queda nadie que pueda continuar.»); ¿se añade algún dato (escena, caídos)? | 0.11. Por defecto, no. |
| G5 | **Botones.** Único «Volver al menú principal» (decisión del 14) o, además, «Cargar última partida» (si hay guardado). | Reabriría la decisión del 14; exigiría `SaveSystem` desde el ViewModel. Por defecto, único. |
| G6 | **Entrada y foco.** Foco inicial en el botón; Intro/Espacio lo activan; Esc no hace nada; el input de debajo queda bloqueado. ¿Se confirma? | 0.3. |
| G7 | **Aparición.** Inmediata (hoy) o con un fundido breve (Tween con duración en token). | Alcance: por defecto, inmediata. |
| G8 | **Limpieza del hito.** (a) Solo restos de depuración y comentarios: `DebugPartyTool`, `[DBG]`, `[DIAG]`, `menus.csv.bak`, comentarios obsoletos; (b) además la etiqueta de depuración del HUD de exploración; (c) además el duplicado de `damage_number.tscn`; (d) además el arreglo de `TRANSITIONING` atascado del menú principal (patrón de `opened` del Game Over). | 0.12-0.17. Recomiendo (a)+(b)+(d); (c) queda para el barrido por tocar combate. |
| G9 | **Informe y cierre del hito.** Además del informe del spike, ¿preparo un resumen de cierre del hito (lista consolidada de pendientes por área, estado final de las ocho pantallas y lecciones transversales)? | Recomiendo sí (lo prepara el plan/estado). |

**Recomendación a confirmar:** G1 (A), G2 (a), G3 título localizable con color de peligro, G4 sin datos nuevos, G5 botón único, G6 confirmado, G7 inmediata, G8 (a)+(b)+(d), G9 sí.

## 7. Alcance

### 7.A Estructura y componentes (pantalla)
- Raíz `CanvasLayer` (se conserva su `layer`, 0.4) con `TitleBackdrop` (fondo y título; título de derrota por token) y contenido centrado por contenido (anclas al centro + `grow` a ambos lados + offsets a 0, lección del 23).
- Mensaje en `Label` con ancho máximo acotado por fracción de pantalla y **sin autowrap desproporcionado** (lección del 23: autowrap en textos cortos de modales da mínimos enormes); si el texto necesita varias líneas, el salto lo da el texto, no el autowrap.
- `UIButton` `LG` `PRIMARY` instanciado desde `ui_button.tscn`, ancho mínimo por fracción de pantalla (no 240 px fijo), foco visible.
- Todos los nodos con `%`; sin `Color(...)`, `font_size` ni `separation` sueltos en la escena.
- El `MouseFilter` del fondo bloquea clics a lo que haya debajo.

### 7.B ViewModel y entrada
- `GameOverViewModel` se conserva; solo se añade lo que decidan G4/G5. La View reacciona a `opened` (foco) y `transitioning` (botón deshabilitado: usar `SECONDARY` o un estado legible, lección del 21).
- Foco inicial en el botón en `opened`; Intro/Espacio por el propio foco de `UIButton`; `ui_cancel` no se consume salvo para bloquear fugas (según 0.3).

### 7.C Localización
- `game_over.csv` (`id,en,es`; claves `GAME_OVER_TITLE`, `GAME_OVER_MESSAGE`, `GAME_OVER_BUTTON_MENU` y las que añada G4/G5), alta manual en Project Settings; las `GAMEOVER_*` salen de `menus.csv` (que queda con `LOADING_LABEL`). Revisión de duplicados con `Group-Object`; `NOTIFICATION_TRANSLATION_CHANGED` para retraducir en caliente (patrón del 23).

### 7.D Maqueta
- 2-3 layouts a 1680×1050 y 1152×648 con el placeholder del 23 y con una textura de prueba (velo y legibilidad); mensaje de dos líneas en ES y EN.

### 7.E Auditoría global y documentación de cierre
- Auditoría de contrato de todo `ui\` con los comandos de 0.14; informe de lo que queda **fuera del hito** y por qué (CharacterCreation, HUD de exploración, combate, narrativa).
- Actualizar el README del DS (retirar la línea de pantallas pendientes), la fila de Game Over en `athelia_ui_architecture.md`, `athelia_estructura_carpetas.md`, `estado_actual.md` (hito cerrado, pendientes consolidados) y el plan.

### 7.F Limpieza de cierre (según G8)
- **Siempre:** retirada de `DebugPartyTool` (autoload de `project.godot` y fichero si queda), trazas `[DBG] tecla:` y `[DIAG]`, `menus.csv.bak`, comentarios obsoletos listados en 0.15 (solo texto).
- **Según G8:** etiqueta de depuración del HUD de exploración; duplicado de `damage_number.tscn`; arreglo de `TRANSITIONING` atascado del menú principal (`request_new_game()` y `request_load_game()` vuelven a `MAIN` con `opened` si el estado no cambia, como el Game Over).
- Cada retirada con búsqueda previa de referencias, ancla única y comprobación de que el proyecto arranca y el Output queda limpio.

## 8. Cambio visual y funcional esperado

| Antes | Después |
|---|---|
| Velo `Color(0,0,0,0.85)` literal y fuentes 48/20 sueltas | `TitleBackdrop` y tokens (`FONT_SIZE_DISPLAY`, colores semánticos) |
| `Button` estándar de 240×48 | `UIButton` `LG` `PRIMARY` con ancho por fracción |
| Sin foco inicial | Foco en el botón; Intro/Espacio lo activan |
| Textos en `menus.csv` (`GAMEOVER_*`) | `game_over.csv` (`GAME_OVER_*`) |
| Trazas y herramientas de depuración en el proyecto | Retiradas |
| Hito sin informe de cierre | Auditoría global, documentación y pendientes consolidados |

**No cambian:** `GameOverViewModel`, `SceneOrchestrator`, `SessionReset`, `GameLoop`, el flujo derrota → menú → partida nueva.

## 9. Fuera de alcance
- Cambiar la lógica de derrota, el reinicio de sesión o `SaveSystem`.
- Pantallas de Game Over distintas por causa, estadísticas de la partida, música, animaciones elaboradas.
- Arte definitivo (se deja `background_texture` preparado, como en el 23).
- Rediseño de CharacterCreation, HUD de exploración, combate, narrativa (barrido opcional posterior, §8 del plan).
- Menú de pausa y audio (pendientes del 23).
- Cambios en los pendientes de motor de los informes (buffs, bonos de atributos base, loot, listador de `SkillSystem`…).

## 10. Reglas a respetar
- MVVM y antipatrones de `athelia_ui_architecture.md`; ViewModel hijo de la View; la pantalla nunca se libera a sí misma.
- Componentes del DS sin acceso a sistemas; setters de `@export` con `is_node_ready()`; centrar por contenido con anclas al centro + `grow` a ambos lados + offsets a 0.
- Evitar autowrap en textos cortos de modales; `UIButton` instanciado desde su `.tscn`; el `PRIMARY` deshabilitado es ilegible (usar `SECONDARY` mientras esté deshabilitado).
- Un parche, un único camino (ancla **o** bloque final, nunca ambos): un `const` duplicado en `UITokens` rompe la compilación de todos los consumidores (lección del 23).
- Antes de borrar un fichero o autoload: búsqueda de referencias; después: arrancar el proyecto y revisar Output y *Errores*.
- `tr()` no existe en funciones estáticas; `.csv` con campos con comas entre comillas, claves únicas, alta manual del CSV nuevo, orden real de columnas (`menus.csv` es `id,es,en`; los CSV nuevos `id,en,es`).
- PowerShell 5.1: scripts sin acentos; cada comando en su propio bloque.
- Commit o copia de `ui/gameover/`, `ui/design_system/` y de los ficheros de limpieza antes de empezar. ViewModel y View se entregan juntos.

## 11. Validación en partida real

A 1152×648 y 1680×1050, ES y EN, con capturas antes/después:
1. **Línea base (0.1-0.5):** pasos para provocar la derrota y mapa de flujos con el Output.
2. **Derrota en combate de producción:** aparece la pantalla con título, mensaje y botón; foco en el botón; sin escena visible por debajo (si G2 (a)); sin avisos nuevos.
3. **Derrota en combate narrativo** (el que el 14 no probó por separado) y con 0, 1 y 2 compañeros.
4. **Botón** (clic, Intro y Espacio): `Return to menu requested` → `State: DEFEAT → MENU` → `SessionReset` con `remaining_in_characters=0`; menú principal operativo.
5. **Doble clic rápido:** una sola transición, sin errores.
6. **Esc, `I`/`H`/`O`/`P` y clics fuera:** sin efecto sobre la partida.
7. **Nueva partida y Cargar partida** tras la derrota (sin entidades ni estado heredados, tienda con su stock original).
8. **Dos derrotas seguidas:** una sola `ExplorationScene`, una sola pantalla de Game Over.
9. **Localización:** sin claves crudas en ES ni EN; botón sin truncar; mensaje en dos líneas.
10. **Resolución:** 1152×648 sin recortes ni solapes; ventana redimensionada con la pantalla abierta.
11. **Limpieza:** el proyecto arranca; Output sin `[DBG]`/`[DIAG]`; *Errores* vacío; `DebugPartyTool` sin referencias; el HUD de exploración sin etiqueta de depuración (si G8 (b)).
12. **Menú principal:** si G8 (d), forzar el rechazo de la transición y comprobar que vuelve a `MAIN`.
13. **Contrato:** `Select-String -CaseSensitive 'Color\(|StyleBoxFlat|Button\.new|Label\.new|modulate|SceneTreeTimer|\$Root'` y accesos a core en `game_over_ui.gd` vacíos.
14. Regresión rápida de las ocho pantallas del hito (abrir y cerrar cada una) sin avisos.

## 12. Riesgos conocidos
- **Código actual no visto:** la View puede haber cambiado desde el Spike 14 (0.2).
- **Pantalla sobre una escena congelada:** un fondo translúcido deja ver el combate; uno opaco cambia la sensación (G2).
- **Fuga de entrada** (`I`, `H`, `P`, Esc) hacia exploración o el orquestador en estado `DEFEAT`.
- **Doble transición** por doble clic (el ViewModel ya protege con `transitioning`).
- **Autowrap y centrado por contenido**: los dos fallos del 23.
- **Limpieza que toca ficheros ajenos** (`project.godot`, `ExplorationController`, `narrative_scene_panel.gd`, `ExplorationHUD`): un borrado con referencias vivas rompe el arranque; se hace una por una y con búsqueda previa.
- **Parche de tokens duplicado** (lección del 23).
- **Cierre del hito demasiado pronto:** tareas de documentación sin la auditoría 0.14 hecha.

## 13. Entregables

**Código (completo):** `game_over_ui.gd` (y `game_over_viewmodel.gd` solo si G4/G5 lo exigen; entregados juntos). **Escenas:** `game_over_ui.tscn` (completa o como árbol de nodos legible, con el padre de cada nodo verificado; conserva el uid). **Parches:** `ui_tokens.gd` (si falta un token), `title_backdrop.gd`/`.tscn` (aditivo, con aprobación), y los de limpieza (§7.F) con ancla única. **Datos:** `game_over.csv` (ES y EN) y limpieza de `menus.csv`; alta manual en Project Settings → Localization.

**Documentación:**
- `docs/spike_24_game_over.md` (informe de cierre: respuestas G1-G9, qué se encontró en la Fase 0, validación, lecciones y pendientes).
- `athelia_ui_architecture.md` (fila de GameOver y comentarios obsoletos), README del DS (retirar la línea de pantallas pendientes), `athelia_estructura_carpetas.md`, `athelia_historial_spikes.md` (un párrafo con enlace), `athelia_lecciones_tecnicas.md` (solo lecciones nuevas).
- `estado_actual.md`: tabla final (hito cerrado) y pendientes consolidados por área (audio, menú de pausa, equipo en el menú del jugador, árbol visual, combate, motor, Character Creation y barrido).
- Plan del hito: cerrar el 24 y marcar el hito como terminado; resumen de cierre del hito si G9 = sí.
