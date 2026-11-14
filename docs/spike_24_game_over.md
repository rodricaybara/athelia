# Spike 24 — Game Over: rediseño visual y cierre del hito (informe de cierre)

*Cerrado: 2026-11-11. Validado por Fernando en partida real (1152×648 y 1680×1050, ES y EN).*

## Objetivo

Llevar la pantalla de derrota al Design System con el estilo del Spike 23 (`TitleBackdrop`, `UIButton` `LG`, tokens), sin tocar la lógica del Spike 14 ni el flujo de reinicio de sesión, y **cerrar el hito de rediseño de interfaces**: retirar los restos de depuración, auditar el contrato de `ui/` y dejar la documentación y los pendientes consolidados.

## Decisiones (G1-G9)

| # | Decisión |
|---|---|
| G1 | Layout **A**: título arriba (`TitleBackdrop`) y, centrados bajo él, mensaje y botón |
| G2 | (a) `TitleBackdrop` opaco con el placeholder del 23; oculta el HUD de exploración que seguía vivo detrás |
| G3 | Título «GAME OVER» localizable, en `COLOR_DANGER_SOFT` (parche aditivo `title_tone` de `TitleBackdrop`) |
| G4 | Sin datos nuevos: se mantiene el mensaje de dos líneas |
| G5 | Botón único hacia el menú principal (decisión del Spike 14) |
| G6 | Foco inicial en el botón; Intro/Espacio lo activan; el input de debajo sigue bloqueado |
| G7 | Aparición inmediata |
| G8 | (a) trazas, (b) etiqueta del HUD, (d) `TRANSITIONING` del menú, (e) `.bak`/`.tmp`, (f) comentarios (incluidos dos de core, solo texto) y (h) literales de `inventory_ui.tscn` y `party_ui.tscn`. Quedan fuera (c) duplicado de `damage_number.tscn` y (g) `dialogue_panel_test.gd`, para el barrido |
| G9 | Resumen de cierre del hito: `docs/cierre_hito_rediseno_interfaces.md` |

Ajuste de Fernando: el título se queda en `title_top_fraction = 0.28` (no se baja a 0.32).

## Entregado

### Pantalla
- `ui/gameover/game_over_ui.gd` y `.tscn` (uid conservado, `layer = 100`). Árbol: `Backdrop` (instancia de `TitleBackdrop`, `mouse_filter = STOP`, `title_tone = DANGER`, `title_top_fraction = 0.28`) y `ContentBox` (`VBoxContainer`, anclas al centro con `anchor_top/bottom = 0.6` y `grow` a ambos lados) con `MessageLabel` y `ReturnToMenuButton` (`UIButton` `LG`, `SHRINK_CENTER`).
- Ancho del botón = máx(280, 0,2 × ancho del viewport), recalculado en `size_changed`. Mensaje sin autowrap (el salto lo da el texto). Separación, fuente y colores desde tokens, asignados por código.
- `opened`: visible, botón `PRIMARY` habilitado y foco diferido. `transitioning`: botón deshabilitado y `SECONDARY` (el `PRIMARY` deshabilitado es ilegible). Retraducción en caliente con `NOTIFICATION_TRANSLATION_CHANGED`.
- `GameOverViewModel` sin cambios.
- `localization/game_over.csv` (`id,en,es`, 3 claves `GAME_OVER_*`). Salen de `menus.csv` las tres `GAMEOVER_*` (queda `LOADING_LABEL`).

### Design System
- `TitleBackdrop`: `enum TitleTone { ACCENT, DANGER }` y `@export title_tone` (por defecto `ACCENT`, así que el menú principal no cambia). Tres parches con ancla única.

### Limpieza de cierre
- Trazas `[DBG]` (`exploration_controller.gd`) y dos `[DIAG]` (`narrative_scene_panel.gd`: función `_input` entera y el lambda de las opciones).
- Etiqueta `StateDebugLabel`: `@onready` y usos de `exploration_hud.gd` y nodo en tres escenas (`interactive_map`, `telmori_village`, `tutorial`).
- 5 `.bak` de `localization/` y 4 `.tmp`, retirados con `git rm`.
- Comentarios obsoletos: «Tecla I / Tab», docstring de `UIPanel`, comentarios de `close_skill_tree()` y `open_loadout()` en `scene_orchestrator.gd` (core, solo texto) y dos menciones a `UISlot.setup()` en escenas de combate.
- Literal `Color(0.05, 0.04, 0.04, 1)` del `Backdrop` de `inventory_ui.tscn` y `party_ui.tscn`.
- `MainMenuViewModel`: `_recover_if_transition_rejected()` (arreglo del `TRANSITIONING` atascado).

Sin cambios de comportamiento en `GameLoop`, `SaveSystem`, `SessionReset` ni en la lógica de `SceneOrchestrator`.

## Fase 0: lo que el código decía frente a la spec

- **`DebugPartyTool` ya no existía** (ni en `[autoload]` ni en ningún fichero), aunque `estado_actual.md` y el informe del 20 lo daban por presente.
- **Dos trazas `[DIAG]`, no una**, y una de ellas obligaba a quitar una función entera.
- **Había 5 `.bak` y 4 `.tmp`**, no solo `menus.csv.bak`; todos estaban en git.
- **`TitleBackdrop` y todos sus hijos ignoran el ratón**: la spec daba por hecho que bloqueaba clics. Se resolvió poniendo `STOP` en la instancia.
- **Un literal muerto en `inventory_ui.tscn` y `party_ui.tscn`**: el código sobrescribe el color del `Backdrop` en `_ready()`, de modo que nunca se veía, pero rompía el contrato «sin `Color(...)`» de los Spikes 18-19.
- **Un solo camino de derrota** en `GameLoop` (jugador a 0 PV sin compañeros, o todos los aliados caídos): el combate narrativo converge con el de producción.
- **El HUD de exploración seguía vivo detrás** del Game Over (se veía `HP: 0` y `DEFEAT | paused=false` con el velo de 0,85).
- **El nodo `StateDebugLabel` estaba referenciado por `$StateDebugLabel`**: quitarlo exigía tocar primero el script y después las escenas.
- **`enter_character_creation()` y `enter_post_load_state()` ignoran el `bool`** de `request_state_change()`: si se rechaza la transición, nadie emite `game_state_changed`.

## Validación en partida real

- **Derrota real:** `Game Over shown` una sola vez, `Return to menu requested` una sola vez, `DEFEAT → MENU` y `SessionReset` con `remaining_in_characters=0`.
- **Capturas «después»:** EN a 1152×648, ES a 1680×1050 y ES a 1152×648. Título, mensaje de dos líneas y botón con foco, sin solapes, sin HUD detrás y sin claves crudas.
- **Entrada bloqueada:** Esc, `I`, `H`, `O`, `P`, clic fuera del botón, doble clic rápido, Intro y Espacio, Nueva partida y Cargar partida tras la derrota, y dos derrotas seguidas, todo correcto (confirmado por Fernando).
- **Menú principal (d):** Nueva partida y Cargar partida normales; con la transición forzada a rechazo sale `La transición fue rechazada — volviendo al menú` y el menú vuelve a `MAIN`.
- **Limpieza:** el proyecto arranca con Output y Errors limpios; las búsquedas de `[DBG]`, `[DIAG]`, `StateDebugLabel`, `paused=`, `UISlot.setup`, `Tecla I / Tab`, `DebugPartyTool` y `GAMEOVER_` solo devuelven las etiquetas de `exploration_test*.tscn` (que se conservan).
- **Regresión de las pantallas del hito:** abrir y cerrar cada una sin avisos, con inventario y Party con el mismo fondo.
- **Contrato:** sin `Color(`, `StyleBoxFlat`, `Button.new`, `Label.new`, `modulate`, `SceneTreeTimer` ni `$Root` en `ui/gameover/`.

## Incidencias de la entrega (para no repetirlas)

1. **El parche (d) no estaba aplicado y la prueba «ok» no lo delataba.** La búsqueda de `_recover_if_transition_rejected` salió vacía aunque se había dado por probado. Se entregó el fichero completo y se verificó con `Select-String` antes de validar.
2. **Expectativa errónea sobre la previsualización:** el botón de la escena temporal no reabre el botón (el `GameLoop` ya está en `MENU`, la transición se da por buena y solo sale el aviso `MENU → MENU`). No era un fallo de la pantalla.
3. **Una pasada previa se equivocó** al decir que faltaban las capturas de la derrota real, que sí se habían entregado.
4. **Se afirmó que el literal de `inventory_ui.tscn` era un fondo visible:** el código lo sobrescribía. El cambio (h) era un literal muerto.

## Lecciones nuevas (también en `athelia_lecciones_tecnicas.md`)

1. Un `Control` con `mouse_filter = IGNORE` deja pasar los clics: la pantalla que debe bloquearlos pone `STOP` en su instancia, sin tocar el componente compartido.
2. Un valor de escena que el script sobrescribe en `_ready()` es un literal muerto que ensucia la auditoría de `Color(`: se quita del `.tscn`.
3. Un botón con ancho por fracción de pantalla (`custom_minimum_size.x` desde la View) y `SHRINK_CENTER` no depende del idioma.
4. Una pantalla que arranca oculta y la muestra el orquestador se previsualiza con una escena temporal en `test/`.
5. Una intención que pide una transición a `GameLoop` compara `current_game_state` antes y después y vuelve a su estado si no cambió.
6. Quitar un nodo de depuración referenciado por `$Nombre`: primero el script, después las escenas.
7. Tras aplicar un parche, comprobar con `Select-String` que su identificador nuevo está en el fichero antes de probar.
8. Un patrón de auditoría amplio (`Label.new`) da falsos positivos en listas dinámicas: cuenta `Color\(|modulate`; los ficheros `*_test*` y `*_bak*` se filtran por nombre.
9. Un informe puede listar como pendiente algo que ya no existe (`DebugPartyTool`): se comprueba antes de planificar su retirada.

## Pendientes (sin spike asignado)

- **Auditoría del hito, fuera de las ocho pantallas** (detalle en `docs/cierre_hito_rediseno_interfaces.md`): literal `Color(0,0,0,1)` en `dialogue_panel.tscn:30` y `Color(...)` en `loading_screen.tscn:25`; `world_object_interaction_panel` (vestigial) con constantes de color y `modulate`; `interactive_scene_view.gd:78` crea `UIButton.new()` en vez de instanciar `ui_button.tscn`; `narrative_scene_panel.gd:118` llama a `Dialogue.start_dialogue()` desde la View; `combat_hud.gd` y `combat_arena_panel.gd` acceden a `Characters`, `Inventory` y `EventBus`.
- **Ficheros candidatos a retirar:** `ui/dialogue/dialogue_panel_test.gd`, `core/combat/combat_system_bak.gd`, `ui/entity_animation_controller_bak.gd`, `scenes/exploration/exploration_test_bak.tscn`, duplicado de `damage_number.tscn`, `docs/athelia_estructura_proyecto_actualizado.md` (nombre antiguo del documento de estructura).
- **`StateDebugLabel`** sigue en `exploration_test.tscn` y `exploration_test_bak.tscn` (sin script, inofensivo).
- **Sin validar en partida:** derrota en un combate lanzado desde una escena narrativa (mismo código que producción) y con 0 o 2 compañeros (solo se probó con `companion_mira`); legibilidad del velo con arte real (hoy fondo plano).
