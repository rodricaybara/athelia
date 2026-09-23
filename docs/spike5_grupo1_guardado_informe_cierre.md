# Informe de cierre — Mejoras post-Spike 3, Grupo 1: Guardado de partida

*Athelia — cierre del último de los tres grupos de mejoras abordados tras Spike 3 (3, 2, 5 ya cerrados; Grupo 4, arte, sin empezar)*

---

## Objetivo del grupo

Que la partida guardada recuerde el progreso narrativo real (no solo personaje/recursos/skills/inventario/equipo) y se pueda reanudar exactamente donde se dejó, más un atajo de desarrollo barato para probar tramos avanzados sin jugar la aventura entera. Ver `mejoras_grupo1_guardado_spec.md` para el planteamiento original con el que arrancó el grupo.

## Comprobaciones de código obligadas — resueltas antes de diseñar nada

1. **Qué guarda hoy `SaveManager`.** Corrige un supuesto erróneo de la documentación de arquitectura existente: `SaveData.narrative_state` **ya** incluía flags, variables, eventos completados, checkpoints y party antes de este grupo, vía `_collect_narrative_state()`/`_restore_narrative_state()`. La documentación decía que solo se guardaba personaje/recursos/skills/inventario/equipo — desactualizada en este punto concreto. El hueco real no eran los flags en sí: era únicamente "a qué escena narrativa (y, si la hubiera, a qué nodo dentro de ella) volver al cargar".
2. **Dónde viven F5/F9 y sus condiciones.** Confirmado en `ExplorationController._unhandled_input()`, compartiendo guard (`GameLoop.is_input_blocked()`, bloqueado fuera de `EXPLORATION`) con `interact`/`open_inventory`/`open_party`/`open_player_menu`. Migradas ahí desde `player.gd` (ya fuera del árbol de escena activo) en el spike de producción.

## Decisión de diseño que cambia el mecanismo original del spec

El spec original planteaba F5 como hotkey libre, disponible en cualquier `NARRATIVE_SCENE` sin racha de tiradas en curso ni sub-overlay abierto. Durante el grupo se decidió algo más restrictivo: **guardar deja de ser una tecla libre y pasa a ser una acción que ofrece explícitamente el contenido narrativo** — solo NPCs concretos marcados como savepoint (ej. el sheriff en "Los Telmori"), no todos. Al ser NPCs "sin peso en la historia" los que la ofrecen, que su diálogo sea repetible no abre ningún exploit (a diferencia del caso del sheriff con recompensas económicas de Grupo 5, donde sí hubo que cerrar ese riesgo). F5 se retira del todo de `ExplorationController`; F9 (cargar) se queda sin restricción de estado, igual que "Cargar Partida" desde el menú.

Consecuencia de simplificación: con el mecanismo antiguo hacía falta guardar contra racha-en-curso y sub-overlay-abierto porque el jugador podía pulsar F5 en cualquier momento. Con el guardado atado a una opción de diálogo concreta, esas dos condiciones dejan de tener sentido — no puede haber una racha en curso mientras se está dentro de un diálogo, ni otro sub-overlay pesado abierto a la vez (slot único de `NarrativeScenePanel`). El único guard que queda es implícito, garantizado por el propio flujo.

## Cambios implementados

- **`DialogueOptionDefinition.triggers_save: bool = false`** (nuevo campo). `DialogueRegistry._load_option_from_dict()` necesitó una línea nueva (`option.triggers_save = data.get("triggers_save", false)`) — construye cada opción campo a campo sin mapeo genérico de claves JSON, así que el campo no se lee solo por añadirlo al contenido.
- **`DialogueSystem.select_option()`**: tras `_trigger_narrative_events()` y antes de navegar a `next_node_id`/terminar el diálogo, si `option.triggers_save`, llamada directa a `SaveManager.save_game()` — mismo nivel de acoplamiento que ya tiene ese método con `Narrative.apply_event()`.
- **`ExplorationController`**: rama de F5 retirada de `_unhandled_input()`. F9 sin cambios.
- **`SaveData`**: nuevo campo `narrative_state["current_narrative_scene_id"]`. `SAVE_VERSION` sube de 5 a 6, con migración (`_migrate_from_version()`) que rellena `""` en saves antiguos.
- **`SceneOrchestrator.get_current_overlay()`** (getter nuevo) y **`NarrativeScenePanel.get_current_scene_id()`** (getter nuevo, lee `_vm.current_node.scene_id`) — usados por `SaveSystem._collect_narrative_state()` vía duck-typing (`has_method()`), mismo estilo que ya usa `SceneOrchestrator` internamente. Sigue siendo válido aunque el panel esté detrás de un sub-overlay de Diálogo.
- **`SaveSystem`**: nueva var `_pending_narrative_scene_id` + getter `get_pending_narrative_scene_id()`, rellenada en `_restore_narrative_state()`. No transiciona `GameState` directamente — nunca lo ha hecho.
- **`MainMenuViewModel.request_load_game()`**: tras `load_game()`, decide `enter_narrative_scene(scene_id)` vs `enter_exploration()` según ese getter, en vez de `enter_exploration()` incondicional.
- **Atajo de desarrollo**: tecla F2 (keycode crudo, sin InputMap) en `ExplorationController`, detrás de `OS.is_debug_build()` desde el primer commit — misma disciplina que evitó que F1 (Spike 1) se quedara viva en producción. Lee `user://debug_shortcut.json` en cada pulsación (no cacheado en `_ready()`), aplica `Narrative.set_flag()` por cada entrada de `"flags"` y `Characters.set_skill_value("player", skill_id, value)` por cada entrada de `"skills"`. Comprobado antes del guard `is_input_blocked()`, deliberadamente — funciona en cualquier `GameState`. Mecanismo aparte del guardado real, nunca toca `SaveManager`/`SaveData`.

## Hallazgos no anticipados por el spec, encontrados en playtest real

1. **`MENU → NARRATIVE_SCENE` no existía en `VALID_STATE_TRANSITIONS`.** Antes de este grupo era un camino inexistente — la única entrada a `NARRATIVE_SCENE` era desde `EXPLORATION`. `enter_narrative_scene()` llamado desde `MENU` caía en `_can_transition_state() == false` → `push_warning()`, no `push_error()` — sin ningún otro síntoma que "Cargar Partida" no hiciera nada visible. Corregido añadiendo `NARRATIVE_SCENE` a las transiciones válidas desde `MENU`.
2. **Orden de instanciación de `ExplorationScene`, con efecto real en el juego.** Tras corregir el hallazgo 1, cargar directo en `NARRATIVE_SCENE` seguido de un combate (ej. la emboscada) hacía que `ExplorationScene` (y con ella, `TelmoriVillage._ready()`) no se instanciara hasta **después** de terminar el combate. Los listeners de continuación que ese `_ready()` registra (ej. `_register_telmori_ambush_continuation()`, escuchando `EventBus.combat_ended` para spawnear el interactuable "Rastros") se conectaban demasiado tarde — la señal del combate ya se había emitido y consumido sin nadie escuchando. Síntoma observado: "Rastros" no aparecía tras ganar la emboscada, sin ningún error en el log.
   - **Fix**: `SceneOrchestrator._ensure_exploration_scene_instantiated()` (factorizado de `_handle_exploration()`), llamado también desde `_handle_narrative_scene()` — garantiza que la escena de exploración exista antes de que pueda dispararse cualquier combate desde una escena narrativa, sea cual sea el camino de entrada.
   - **Trampa de reentrada descubierta al aplicar este fix, resuelta antes de llegar a producción real**: `TelmoriVillage._ready()` tenía su propio guard `if current_game_state != EXPLORATION: enter_exploration()`, pensado para cuando la escena se ejecuta suelta en el editor sin pasar por `GameLoop`/`SceneOrchestrator`. Instanciar `ExplorationScene` dentro de `_handle_narrative_scene()` sin corregir ese guard habría hecho que `_ready()` viera `current_game_state == NARRATIVE_SCENE` (`!= EXPLORATION`) y llamara a `enter_exploration()` **en mitad de la propia apertura de la escena narrativa** — una transición reentrante (`NARRATIVE_SCENE → EXPLORATION`, válida en `VALID_STATE_TRANSITIONS`) que habría cerrado el panel narrativo justo después de abrirlo, dejando `GameState` y `_current_overlay` desincronizados. Corregido cambiando la condición a `== MENU`, el único caso real que el guard necesitaba cubrir.
3. **Falsa alarma descartada**: el warning `[InventorySystem] Entity not registered for load` al cargar no es un bug — `InventorySystem.load_save_state()` ya se auto-registra (`register_entity()`) si la entidad no existe, a diferencia de `ResourceSystem`/`SkillSystem` (que sí necesitaron ese fix en el spike de producción, por analogía se sospechó primero de `InventorySystem` sin comprobar el código real). El inventario se carga bien pese al warning.
4. **Warning de `PartyManager.join_party()` duplicado, mismo origen que el hallazgo 2, sin efecto real**: al adelantarse la instanciación de `ExplorationScene` (fix del hallazgo 2), `_ready()` de `TelmoriVillage` corre antes, con la compañera ya restaurada del save — `party.join_party("companion_mira")` avisa "already in party", guardado explícitamente contra esto por diseño (comentario propio del código). No necesita corrección.
5. **Hallazgo de paso, sin código**: `SaveFeedbackUI` ya existía y ya escuchaba `save_completed`/`save_failed` de `SaveSystem` — el feedback visual de "partida guardada" al usar la opción de diálogo del NPC savepoint no necesitó código nuevo.

## Decisión relacionada, fuera de alcance del grupo

Con el pivote de Athelia a RPG narrativo por eventos/flags (sin exploración espacial), `player_state["position"]` (x, y) queda vestigial — sigue guardándose/restaurándose exactamente igual que antes (sin cambios de código en este grupo), pero deja de tener ningún efecto observable en el juego. Se marca como candidato a limpieza futura del schema, explícitamente fuera de alcance aquí.

## Ficheros modificados

`dialogue_option_definition.gd`, `dialogue_system.gd`, `dialogue_registry.gd`, `exploration_controller.gd`, `save_data.gd`, `save_system.gd`, `scene_orchestrator.gd`, `narrative_scene_panel.gd`, `main_menu_viewmodel.gd`, `game_loop_system.gd`, `exploration_telmori_village.gd`.

## Validación

Partida real completa: guardar desde el sheriff en `NARRATIVE_SCENE` → cerrar el juego → "Cargar Partida" desde el menú resume exactamente en esa escena narrativa, con todo el estado restaurado (personaje, recursos, skills, equipo, inventario, party, economía, flags) → seguir jugando con normalidad, incluida una mejora de skill post-combate (`SkillProgressionService`) y "Rastros" apareciendo correctamente tras ganar la emboscada → aventura completa de "Los Telmori" jugada de principio a fin, combate final de la guarida incluido, sin errores en el log.

## Pendiente / fuera de cierre

- Grupo 4 (arte narrativo): sin empezar.
- `player_state["position"]`: candidato a limpieza de schema (vestigial, ver arriba), sin fecha decidida.
- Bug conocido, sin relación con este grupo y no investigado aquí: F9 (quickload) en una sesión activa ya en `EXPLORATION` provoca bloqueo total de input — causa raíz aún no confirmada (ver `docs/spike_produccion_post_character_creation_informe_cierre.md`).

---

*Godot 4.7.2.*
