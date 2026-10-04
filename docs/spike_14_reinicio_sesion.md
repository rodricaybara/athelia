# Spike 14 — Reinicio de sesión y teardown (motor)

**Hito:** rediseño de interfaces (spikes 14-24). **Cambio visual:** ninguno
(salvo la anchura del botón del Game Over, ver "Hallazgos").
**Estado:** cerrado y validado en partida real, con tres comprobaciones menores
pendientes de confirmar (ver "Validación").

---

## 1. Qué se resolvió

Perder un combate no tenía salida: el botón "Nueva partida" del Game Over
fallaba con `Invalid state transition: DEFEAT → CHARACTER_CREATION`, el Game Over
no se liberaba, la escena de exploración seguía viva detrás y las entidades del
jugador muerto seguían registradas. Ahora el Game Over tiene un único botón hacia
el menú principal, y al entrar en `MENU` se destruyen las escenas de la partida y
se reinicia el estado de sesión.

## 2. Causa raíz

1. `SceneOrchestrator._show_game_over()` colgaba `GameOverUI` de `root` sin
   guardar referencia: `_hide_current_overlay()` nunca lo liberaba.
2. `_handle_main_menu()` solo ocultaba el overlay. Nadie liberaba
   `ExplorationScene` (hermana de `current_scene` bajo `root`) y ningún sistema
   reaccionaba a `GameState.MENU`.
3. No existía reinicio de sesión. El guard `has_entity("player")` de
   `CharacterCreationViewModel._create_player_entity()` ("ya registrado — no se
   recrea") dejaba al jugador muerto con HP 0 y stats viejos, y
   `AdventureStarter.apply()` no es idempotente (el kit se duplicaría).
4. La carga **sobrescribe, no borra**: `SaveSystem._restore_state()` solo
   registra al jugador si falta y aplica `load_save_state()` encima.
5. La View (`GameOverUI`) contenía lógica de juego (`Narrative`, `Checkpoints`,
   `Party`, `GameLoop`).

## 3. Diseño final

```
combat_ended("defeat")
  → SceneOrchestrator._show_game_over(): guarda _game_over_ui
  → botón → GameOverViewModel.request_return_to_menu()
       → "transitioning" → await process_frame → GameLoop.enter_main_menu()
  → DEFEAT → MENU → SceneOrchestrator._handle_main_menu():
       _hide_current_overlay() + _free_session_scenes()
         (GameOverUI, CombatHud, CombatScene, ExplorationScene)
       → _run_session_reset(): await process_frame
         → guard: GameLoop en MENU o CHARACTER_CREATION
         → SessionReset.apply()
```

`SessionReset.apply()`, orden fijo, solo APIs públicas:

1. `Dialogue.reset()`
2. `Combat.clear_buffs(id)` por cada entidad de `Characters`
3. `Party.leave_party(id)` por cada miembro
4. `EntityLifecycle.unregister_everywhere(id)` por cada entidad que quede
5. `Narrative.clear_all()`
6. `Checkpoints.reset()`
7. `Economy.reset_session()`

`EntityLifecycle.unregister_everywhere(id)`: Characters (con `has_entity`) →
Resources → Skills → Equipment → Inventory. Idempotente.

`Economy.reset_session()`: `_shops.clear()` + `_load_shop_definitions()`.

## 4. Cambios respecto a la spec

1. `Combat.clear_buffs()` entra en `SessionReset` (API pública existente; la spec
   no la nombraba). Motivo: `CombatSystem._active_buffs` nunca se limpia al
   terminar un combate y los ids de companion son fijos.
2. El guard tras el `await` acepta `MENU` y `CHARACTER_CREATION` (no solo `MENU`).
3. `GameOverViewModel` reabre el botón con `"opened"` si la transición a `MENU` no
   se produce.
4. El botón se llama `ReturnToMenuButton` (`MenuButton` es una clase nativa).
5. `PartyManager._register_in_systems`: el `.has()` sobre `_entity_skills` pasa a
   `has_entity()`. El `.keys()` queda pendiente (no hay listador público).

## 5. Ficheros

**Nuevos:** `core/session/entity_lifecycle.gd`, `core/session/session_reset.gd`,
`ui/gameover/game_over_viewmodel.gd`.

**Modificados:** `core/scene_orchestrator.gd` (variable `_game_over_ui`,
`_handle_main_menu()`, `_free_session_scenes()`, `_run_session_reset()`,
`_show_game_over()`), `core/companions/party_manager.gd`
(`_register_in_systems()`, `_unregister_from_systems()`),
`core/economy/economy_system.gd` (`reset_session()`),
`ui/character_creation/character_creation_viewmodel.gd` (una línea),
`ui/gameover/game_over_ui.gd` (completo), `ui/gameover/game_over_ui.tscn`
(`TitleLabel` con nombre único, `NewGameButton` → `ReturnToMenuButton`, textos
vacíos), `localization/menus.csv` (`GAMEOVER_TITLE`, `GAMEOVER_MESSAGE`,
`GAMEOVER_BUTTON_MENU`).

## 6. Fase 0: resultado de las comprobaciones

| # | Punto | Resultado |
|---|---|---|
| 1 | `LoadoutState` | Campo de `CharacterState`; se va con la entidad. |
| 2 | Tiendas por código | Ninguna llamada de producción a `register_shop()`; recargar definiciones basta (`ShopInstance` copia valores y crea `ShopItemState` nuevos). |
| 3 | Sistemas vestigiales | `EnemyWorldLink` sin llamadores. `WorldObjectSystem` sin registradores en producción (solo `CombatLootSpawner`, cuyo `spawn_pending_loot()` no tiene llamador, y el tutorial descartado); `SaveSystem` no lo guarda. No necesitan reset. |
| 4 | Baja de `player` y HUD | `Stress` solo borra su entrada; `Resources.unregister_entity` no emite señal; el HUD ya no existe cuando se da de baja. |
| 5 | Escena de exploración | Sus conexiones usan métodos con nombre del propio nodo; se desconectan al liberar. |
| 6 | Orden de listeners | El orquestador conecta primero; el reinicio es una llamada explícita, no depende del orden. |
| 7 | Flujos por `MENU` | Solo el Game Over y "Volver al menú" de Character Creation llaman a `enter_main_menu()`. El arranque en frío no emite `MENU`. |
| 8 | Momento del reinicio | Nadie escucha `scene_transition_completed`; `_is_processing` nunca bloquea `DEFEAT → MENU`. |
| 9 | Estado en la derrota | Los enemigos se registran por tres caminos, todos pasan por `Characters.register_entity`. |
| 10 | Localización | Claves nuevas en `menus.csv` (ya registrado), orden de columnas `id,es,en`. |

## 7. Validación en partida real

| # | Prueba de la spec | Resultado |
|---|---|---|
| 1 | Derrota → botón | Correcto. Secuencia `Return to menu requested` → `Handling state: MENU` → `Session scene freed: ExplorationScene` → `State: DEFEAT → MENU` → `SessionReset` con `buff_entities=8, companions_left=1, entities_unregistered=7, remaining_in_characters=0`. |
| 2 | Nueva partida tras derrota | Registro limpio de `player` y de un solo `companion_mira`, `ExplorationScene` nueva, primera visita al pueblo disparada de nuevo, inventario de la partida anterior no heredado. **Pendiente de confirmar:** vida completa y stock original de la herrería. |
| 3 | Derrota → menú → Cargar partida | Correcto: restaura el punto guardado, inventario incluido. |
| 4 | Primer arranque normal | Validado en la Fase 1 (código parcial). **Pendiente de confirmar** con el código final: arranque en frío → Nueva partida → pueblo. |
| 5 | "Volver al menú" desde Character Creation | Correcto. Reinicio con almacén vacío, contadores a 0, sin avisos. |
| 6 | Dos derrotas seguidas | Una sola `ExplorationScene` en el árbol remoto. |
| 7 | Derrota con companions / combate narrativo | Companion dado de baja por `leave_party` y los 6 enemigos desregistrados (`remaining_in_characters=0`). No se probó por separado un combate lanzado desde narrativa; ambos caminos de registro pasan por `Characters`. |
| 8 | Companions tras el refactor | Carga con party y baja por `leave_party` correctas. **No jugados:** rescate narrativo y muerte permanente (pasan por el mismo `_unregister_from_systems`). |
| 9 | Reinicio idempotente | Correcto (contadores a 0 sin avisos). |
| — | Idioma | El Game Over sale en inglés con el juego en inglés. |

## 8. Hallazgos y pendientes (para la recopilación)

- **`CombatSystem._active_buffs` no se limpia al terminar un combate;**
  `clear_buffs()` no tenía ningún llamador. `SessionReset` solo cubre las
  entidades registradas. Los buffs de entidades ya dadas de baja (p. ej.
  enemigos de un combate anterior con el mismo id) no se tocan.
- **`CombatLootSpawner.spawn_pending_loot()` sin llamador:** el botín de combate
  no se materializa en producción.
- **`ItemCharacterIntegration` es código muerto** (no es autoload ni se
  instancia; el autoload `Bridge` es `item_character_bridge.gd`).
- **`PartyManager._register_in_systems()` conserva un acceso privado:**
  `skills_node._entity_skills.get(...).keys()`; hace falta un listador público en
  `SkillSystem`.
- **Entidad solo en `Skills` o `Resources`:** `CombatProductionScene` registra
  en `Skills` antes que en `Characters`; si el segundo registro fallara, el
  reinicio no la vería (no hay listador público fuera de `Characters`).
- **`menus.csv`:** la fila `MENU_CONFIRM_YES` tiene comas sin comillas.
- **Aviso al cargar la exploración:** `telmori_village/exit_final: escena
  narrativa inexistente: telmori_village_departure` (escena de epílogo aún por
  crear; ajeno a este spike).
- **Botón del Game Over:** puede ensancharse porque "Volver al menú principal"
  es más largo que "Nueva partida" (rediseño en el spike 24).
- **Decisión de Fernando:** la carga con F9 en partida queda desestimada de forma
  definitiva; no se vuelve a tratar.
- **Nombre del documento de estructura:** la spec cita
  `athelia_estructura_proyecto_actualizado.md`; el proyecto adjunta
  `athelia_estructura_carpetas.md`. Confirmar cuál es el vigente.

## 9. Lecciones

- Un guard `has_entity` que no recrea protege del doble registro, pero hace que
  una sesión nueva herede una entidad vieja. Una sesión nueva exige dar de baja
  antes.
- La carga sobrescribe, no borra: lo que no está en el guardado sobrevive a una
  carga. El reinicio de sesión debe ocurrir antes.
- La lista de `get_save_state()` sirve de lista de control de qué sistemas
  vaciar al reiniciar; hay que añadirle los diccionarios de runtime que no se
  guardan (como `_active_buffs`).
- Tras `queue_free()` y un `await process_frame`, el coordinador debe comprobar
  el estado al reanudar y no asumir el que tenía al empezar.
- `_transition_game_state()` emite `game_state_changed` **antes** de imprimir
  `State: A → B`: en el Output, los logs de los handlers salen antes de esa línea.
- Una API de baja solo es idempotente si todos los sistemas lo son:
  `Characters.unregister_entity` avisa si la entidad no existe, por eso lleva
  `has_entity` delante.
