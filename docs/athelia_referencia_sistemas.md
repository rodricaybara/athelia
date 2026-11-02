# Athelia — Referencia de sistemas (estado actual)
 
Motor: Godot 4.7.2 (Forward Plus). RPG por turnos con escenas narrativas e interactivas, combate, diálogo, economía y guardado.
 
Este fichero describe **qué existe hoy y cómo se comporta**. El porqué de cada decisión está en `athelia_historial_spikes.md`; las lecciones reutilizables en `athelia_lecciones_tecnicas.md`; el árbol de ficheros en `athelia_estructura_carpetas.md`; el patrón MVVM y el Design System en `athelia_ui_architecture.md` (no se duplican aquí).
 
---
 
## Autoloads
 
### Infraestructura base
| Singleton | Script | Descripción |
|---|---|---|
| `EventBus` | `core/event_bus.gd` | Bus de eventos desacoplado. |
| `GameLoop` | `core/game_loop_system.gd` | Máquina de estados global y fases de turno de combate. Ver «GameLoop». |
| `SceneOrchestrator` | `core/scene_orchestrator.gd` | Reacciona a `game_state_changed` para mostrar/ocultar overlays y cargar/descargar escenas. Nunca modifica `GameState`. Ver «SceneOrchestrator». |
| `SaveManager` | `core/save/save_system.gd` | Guardado/carga. Slot único `"quicksave"`. Ver «Guardado». |
| `UITokens` | `ui/design_system/tokens/ui_tokens.gd` | Tokens de diseño. |
 
### Personaje
| Singleton | Script | Descripción |
|---|---|---|
| `Characters` | `core/characters/character_system.gd` | Creación, acceso y ciclo de vida de personajes. |
| `Modifiers` | `core/characters/modifier_applicator.gd` | Aplica modificadores sobre atributos. |
| `Resources` | `core/resources/resource_system.gd` | Recursos vitales (vida, stamina, oro). `register_entity()` depende de `Characters`/`AttributeResolver` (sincroniza `max_effective` vía `AttributeResolver.resolve_resource_max()`): `Characters.register_entity()` debe haberse llamado antes. Su lista de recursos en `_load_resource_definitions()` está hardcodeada (`health`, `stamina`, `gold`), a diferencia de Skills/Items. `_emit_resource_changed()` reenvía a `EventBus.resource_changed`. |
| `Skills` | `core/skills/skill_system.gd` | Registro, acceso y uso de habilidades. `SkillRoller` (estático, no autoload) resuelve D100 con 5 grados: `FUMBLE`/`FAILURE`/`SUCCESS`/`SPECIAL`/`CRITICAL`; `CRITICAL` (skill/20) y `SPECIAL` (skill/5) dinámicos, `FUMBLE` absoluto (≥98). `learn_skill()` enseña una skill fuera del kit inicial. |
| `SkillProgression` | `core/skills/skill_progression_service.gd` | Progresión y aprendizaje. `notify_skill_outcome()` solo combate; `execute_learning_session()` es el camino fuera de combate (libros, entrenadores, narrativa con `SourceType.NARRATIVE`). |
| `SkillEventHandler` | `core/skills/skill_event_handler.gd` | Eventos de habilidades. |
| `Stress` | `core/skills/stress_system.gd` | Estrés del personaje (escucha `character_unregistered`). |
 
### Ítems y equipo
| Singleton | Script | Descripción |
|---|---|---|
| `Items` | `core/items/item_registry.gd` | Registro de definiciones (escaneo recursivo de `data/items/`). |
| `Inventory` | `core/items/inventory_system.gd` | Inventario por entidad. `add_item` no valida capacidad y devuelve `true` aunque sobrescriba una pila no apilable existente o recorte al tope de pila (quien transfiera pre-valida). |
| `Equipment` | `core/items/equipment_manager.gd` | Equipo por entidad. **Independiente de `Inventory` por diseño:** equipar no saca el ítem de la mochila y quitarlo de la mochila no lo desequipa. |
| `Bridge` | `core/items/item_character_bridge.gd` | Adaptador ítems ↔ Characters/Resources/Skills. Ver «ItemCharacterBridge». |
 
### Mundo y combate
| Singleton | Script | Descripción |
|---|---|---|
| `Combat` | `core/combat/combat_system.gd` | Combate por turnos. `_active_buffs` no se limpia al terminar un combate (`clear_buffs()` solo lo llama `SessionReset`). |
| `CombatLootSpawner` | `core/combat/combat_loot_spawner.gd` | Loot al terminar combate. `spawn_pending_loot()` no tiene llamador en producción. |
| `Economy` | `core/economy/economy_system.gd` | Compra, venta y precios. `reset_session()` recarga las `ShopInstance`. El tag `quest_loan` se trata como préstamo (sin coste, no vendible; `trade_type = "loan"`, error `LOAN_ITEM`). |
| `WorldObjects` / `WorldObjectSystem` | `core/world_objects/` | Objetos interactuables del mundo. Sin uso en el camino jugable actual. |
| `EnemyWorldLink` | `core/combat/enemy_world_link.gd` | Hueco para limpiar la representación de enemigos que huyen (`enemy_group_fled`). Sin casos de uso reales. |
 
### Narrativa y diálogo
| Singleton | Script | Descripción |
|---|---|---|
| `Narrative` | `core/narrative/narrative_system.gd` | Almacén de flags y variables (`set_flag`, `clear_flag`, `set_variable`, `get_variable`, `get_active_flags`). |
| `NarrativeDB` | `core/narrative/narrative_registry.gd` | Eventos narrativos. |
| `Checkpoints` / `CheckpointDB` | `core/narrative/` | Hitos narrativos; no es el almacén de flags. |
| `Dialogue` / `DialogueDB` | `core/dialogue/` | Sistema y registro de diálogos. El registro escanea subcarpetas de forma recursiva. |
| `NarrativeSceneDB` | `core/narrative_scenes/narrative_scene_registry.gd` | Escenas narrativas desde JSON. Consulta local síncrona, sin estado runtime. |
| `InteractiveSceneDB` | `core/interactive_scenes/interactive_scene_registry.gd` | Escenas interactivas (mapa de puntos de interés) desde `data/interactive_scenes/*.json`. **Escaneo sin recursión.** Sin estado runtime. |
 
**No confundir:** `core/narrative/` (hitos/eventos recordados) y `core/narrative_scenes/` (qué nodo de escena se muestra ahora). `InteractionOutcome.narrative_event_id` dispara `NarrativeSystem.apply_event()`, no `GameLoop.enter_narrative_scene()`.
 
### Companions
| Singleton | Script | Descripción |
|---|---|---|
| `Party` | `core/companions/party_manager.gd` | Grupo de personajes. `MAX_PARTY_SIZE = 3` (la decisión de diseño era 2: pendiente de decidir; la interfaz de Party no impone máximo). Party no deja pasar un `quest_loan` a un compañero. |
| `PartyEventHandler` | `core/companions/party_event_handler.gd` | Eventos de party. |
 
### Clases estáticas y helpers (no autoload)
- `SessionReset.apply()` y `EntityLifecycle.unregister_everywhere(id)` (`core/session/`). Ver «Reinicio de sesión».
- `AdventureStarter.apply(adventure_id)` (`core/adventures/`). Ver «Arranque de aventura».
- `BagCapacity.compute(...)` (`ui/inventory/`): único punto de cálculo de capacidad de mochila.
---
 
## GameLoop — estados y fases de turno
 
Transiciones válidas de `GameState`:
```
MENU               → EXPLORATION, CHARACTER_CREATION, NARRATIVE_SCENE
CHARACTER_CREATION → EXPLORATION, MENU
EXPLORATION        → DIALOGUE, SHOP, NARRATIVE_SCENE, COMBAT_ACTIVE, PAUSE, SAVE_TRANSITION
DIALOGUE           → EXPLORATION, COMBAT_ACTIVE
SHOP               → EXPLORATION
NARRATIVE_SCENE    → EXPLORATION, COMBAT_ACTIVE
COMBAT_ACTIVE      → VICTORY, DEFEAT, EXPLORATION
VICTORY            → EXPLORATION, NARRATIVE_SCENE
DEFEAT             → EXPLORATION, MENU
```
Una transición nueva debe comprobarse contra `VALID_STATE_TRANSITIONS`; una inválida solo emite `push_warning` y es fácil de perder. `DEFEAT` nunca va directo a `CHARACTER_CREATION`.
 
Fases de turno de combate:
```
ROUND_START → PLAYER_TURN_START → PLAYER_ACTION_SELECT → PLAYER_ACTION_RESOLVE
→ COMPANION_ACTION_RESOLVE (uno por companion activo)
→ ENEMY_TURN_START → ENEMY_ACTION_RESOLVE (uno por enemigo)
→ TURN_END → ROUND_END → ROUND_START
```
 
- La iniciativa se calcula una sola vez (`_calculate_initiative()`, solo desde `start_combat()`). Los companions actúan después del jugador y antes de los enemigos; un companion incapacitado permanece en `turn_order` y `CompanionAI` salta su turno.
- Victoria: todos los enemigos muertos. Derrota: jugador muerto (los companions no la evitan).
- `start_combat(enemy_ids, encounter = null, victory_scene_id = "")` acepta como origen `EXPLORATION`, `DIALOGUE`, `MENU` y `NARRATIVE_SCENE` (guard propio; transiciona con `_transition_game_state()`, sin pasar por `request_state_change()`).
- **Escena de victoria:** `victory_scene_id` vive en `GameLoop._pending_victory_scene_id` (no en el encuentro, que puede ser `null` y se limpia en `end_combat()`). `consume_pending_victory_scene()` lo devuelve y vacía; `end_combat()` lo descarta tras emitir `combat_ended`, para que no se fugue al combate siguiente.
- `_transition_to_phase()` devuelve `bool`; `_end_turn()`/`_end_round()` abortan si la transición es rechazada. `_on_combat_action_completed()` compara `result["actor"]` con `_current_acting_entity`.
- `_start_player_turn()` sale si el combate terminó dentro de `player_turn_started` (la huida se resuelve ahí).
- `GameLoop.enter_post_load_state()` decide tras cargar entre `enter_narrative_scene(scene_id)` y `enter_exploration()`.
### Encuentros de combate (`CombatEncounterDefinition`, opcional)
- **Moral de grupo:** `morale_threshold_pct`. Los enemigos supervivientes huyen juntos cuando el HP total del grupo cae bajo el umbral (señal `enemy_group_fled`; nunca pasa por `character_died`: sin loot ni animación de muerte). La base (`_group_morale_base_hp`) es dinámica: un refuerzo marca `_group_morale_base_dirty` y se recalcula en el siguiente `_check_group_morale()` (solo tras una muerte, nunca golpe a golpe).
- **Refuerzos cronometrados:** `reinforcement_trigger` / `reinforcement_delay_rounds` (disparables con `GameLoop.trigger_combat_event()`); `reinforcement_definition_id` es un único id (un refuerzo no admite tipos mixtos).
- **Sorpresa:** `surprise_favors` (`"party"`/`"enemies"`) y `surprise_vulnerable_pct`. No toca `turn_order`: el bando sorprendido recibe el buff `staggered` y, opcionalmente, `vulnerable` (`turns_left` 2 si perjudica a jugador/companions, 1 si perjudica a enemigos). Lógica en `_apply_surprise()`, llamada desde `start_combat()` y `configure_active_encounter()` (necesaria cuando el combate ya está en marcha).
- **Fondo:** `background_path`; lo carga `CombatArenaViewModel` con `call_deferred()` desde `GameLoop.get_current_encounter()`. Un encuentro sustituido a mitad de combate no actualiza el fondo.
---
 
## SceneOrchestrator
 
- Escucha `game_state_changed` y nunca modifica `GameState`. Los overlays se instancian y destruyen en cada apertura (`queue_free`). Tiene un **único `_current_overlay`** (no una pila).
- **Combate:** carga aditiva (la escena de exploración sigue viva debajo). `SCENE_COMBAT` = `combat_production_scene.tscn` (sin UI: IA + `PlayerCombatController`) y `OVERLAY_COMBAT_HUD` = `combat_arena_panel.tscn`; ambas se instancian en `_handle_combat()`. Fuga conocida: no guarda referencia a `SCENE_COMBAT` ni la libera (mitigado: `combat_production_scene.gd` se libera sola en `combat_ended`). `combat_test.tscn`/`combat_hud.tscn` siguen como escena de test independiente.
- **Exploración:** `SCENE_EXPLORATION` = `scenes/exploration/interactive_map/exploration_interactive_map.tscn`, que carga `telmori_village` (para pruebas se cambia `interactive_scene_id` a `poi_test_map`). `_ensure_exploration_scene_instantiated()` la crea si no existe (tanto desde `_handle_exploration()` como desde `_handle_narrative_scene()`) y fuerza `name = "ExplorationScene"`, así que el nombre del nodo raíz del `.tscn` es libre. Al ejecutar una escena de exploración suelta con F6, su raíz debe llamarse `"ExplorationScene"`.
- **Narrativa:** `_handle_narrative_scene(scene_id)` = `_hide_current_overlay()` → `_show_overlay(OVERLAY_NARRATIVE_SCENE)` → `open(scene_id)`. El `scene_id` llega por `_pending_context`. Cierre por `EventBus.narrative_scene_closed` → `enter_exploration()`.
- **Victoria con escena:** `_on_combat_ended` abre la escena de victoria pendiente; si el id no existe, `push_error` y vuelve a `EXPLORATION`. No repite `enter_exploration()` tras una huida (`end_combat("escaped")` ya transiciona).
- **Tienda:** el evento `shop_opened` se emite antes de que exista el overlay; se resuelve con `show_shop_direct()` y un snapshot de `Economy`.
- **Character Creation:** usa `_show_overlay()` como el resto (instanciarla a mano la deja huérfana de `_current_overlay`).
- **Inventario/Party:** `open_inventory()`/`open_party()` conectan `closed` a `_on_overlay_closed(overlay)`. Los tres (`open_inventory/party/player_menu`) permiten `EXPLORATION` y `NARRATIVE_SCENE`, pero en narrativa bloquean la ruta de `_current_overlay` (lo resuelve el panel narrativo como sub-overlay).
- `_on_dialogue_ended()` solo actúa en `GameState.DIALOGUE`.
- **Game Over:** `_show_game_over()` guarda `_game_over_ui` y no lo instancia dos veces.
- **Menú principal:** `_handle_main_menu()` libera `GameOverUI`, `CombatHud`, `CombatScene` y `ExplorationScene` y lanza `_run_session_reset()`.
---
 
## Reinicio de sesión (`core/session/`)
 
Al entrar en `MENU`, `SceneOrchestrator` libera las escenas de la partida, espera un frame, comprueba que el estado sigue en `MENU`/`CHARACTER_CREATION` y llama a `SessionReset.apply()`, que ejecuta con orden fijo y solo APIs públicas: `Dialogue.reset()`, `Combat.clear_buffs()`, `Party.leave_party()` de cada miembro, baja de todas las entidades de `Characters.get_registered_entities()` con `EntityLifecycle.unregister_everywhere()` (Characters → Resources → Skills → Equipment → Inventory, idempotente; también la usa `PartyManager`), `Narrative.clear_all()`, `Checkpoints.reset()`, `Economy.reset_session()`.
 
- Pasar por `MENU` por sí solo no limpia nada: lo hace el orquestador + `SessionReset`.
- La carga **sobrescribe, no borra**: para que cargar equivalga a un arranque en frío, el reinicio debe haber ocurrido antes.
- Limitación: una entidad registrada solo en `Skills`/`Resources` y no en `Characters` no la vería el reinicio.
- Game Over: `GameOverViewModel` (una intención, `request_return_to_menu()`); la View no conoce sistemas de `core`.
---
 
## Guardado
 
- `SaveManager`/`SaveData`, `SAVE_VERSION = 6` (migración rellena `current_narrative_scene_id`). Guarda personaje (`definition_id`, `character_name`, `attributes`), recursos, skills, inventario, equipo, party y `narrative_state` (flags, variables, eventos completados, checkpoints, `current_narrative_scene_id`).
- **Solo se guarda eligiendo una opción de diálogo con `DialogueOptionDefinition.triggers_save`** (NPCs savepoint concretos, p. ej. el sheriff; `DialogueSystem.select_option()` llama a `SaveManager.save_game()`). F5 está retirado. «Cargar Partida» desde el menú resume en la escena narrativa guardada vía `get_pending_narrative_scene_id()`. F9 (quickload en sesión activa) **no es operativo** y no se vuelve a tratar.
- `_restore_state()` restaura primero `CharacterSystem` (puede bootstrapear la entidad por `definition_id`) y registra en frío en `ResourceSystem`/`SkillSystem` si falta (`has_entity()`); `EquipmentManager` e `InventorySystem` se auto-registran en su `load_save_state()` (el aviso «Entity not registered for load» es inofensivo). `SkillSystem.load_save_state()` recrea las skills aprendidas en runtime.
- `_collect_player_state()` guarda sin la clave `position` si no hay nodo `Player` (`position` es dato vestigial). `SaveSystem._find_player()` busca bajo `"ExplorationScene"`.
- `SaveFeedbackUI` escucha `save_completed`/`save_failed`.
- Un guardado dentro de una cadena que entrega recompensas permitiría cobrar dos veces: por eso el hub del sheriff no ofrece guardado en la etapa de recompensa.
---
 
## Escenas de exploración y mapa interactivo
 
- **Convención de nombres:** `<tipo>_<identificador_semántico>.tscn`, nunca numeración secuencial. Scripts compartidos en la raíz de `scenes/<tipo>/`; cada zona en su subcarpeta. El orden de progresión debe vivir en datos, no en el nombre.
- **`ExplorationController.request_interaction(type, target_id, enemy_definitions := {})`** es el **único punto de routing** de interacciones (`dialogue` → `GameLoop.enter_dialogue`, `shop` → `enter_shop`, `combat` → registra enemigos y `start_combat`, `narrative_scene` → `enter_narrative_scene`). Tiene guard propio (`is_input_blocked()`); `enemy_definitions` llega como parámetro.
- **Motor de escenas interactivas** (`core/interactive_scenes/`): `InteractiveSceneDefinition` (`scene_id`, `image_path`, `hotspots`, `on_first_visit_*`) e `InteractiveHotspotDefinition` (`hotspot_id`, `map_position` normalizada 0–1, `icon_path`, `label_key`, `interaction_type`, `target_id`, `enemy_ids_override`, `enemy_definitions`, `required_flags`, `blocked_flags`). `item` no es tipo válido. `validate()` marca error por tipo inválido, `label_key`/target vacío o `hotspot_id` duplicado; warning por posición fuera de 0–1 o icono inexistente. Visibilidad declarativa, recalculada al cargar y en cada `game_state_changed → EXPLORATION` (un flag puesto sin cambio de estado no refresca hasta la siguiente vuelta a `EXPLORATION`). Flujo: View → `InteractiveSceneViewModel.activate_hotspot()` → `hotspot_activated` → escena raíz → `request_interaction()`.
- **`on_first_visit`:** acción de una sola vez al entrar (`request_first_visit()`, llamada con `call_deferred`); el pueblo abre así `telmori_village_arrival` (`flag.telmori_village_visited`).
- **El pueblo de Los Telmori** es un hub (`telmori_village.json`: 11 hotspots en 4 posiciones —sheriff, herrería, taberna, salida— mutuamente excluyentes por flags según la etapa). Las etapas se gobiernan con `flag.telmori_sheriff_briefed` → `ambush_won` → `tracked_to_lair` → `lair_cleared` → `adventure_completed`. Un flag solo demuestra que se GANÓ si lo pone una escena que solo se alcanza al ganar.
- **`Interactable` es vestigial:** ningún consumidor en el camino jugable; su camino físico nunca se validó y no se va a validar. `exploration_tutorial`, `exploration_test` y `exploration_telmori_village` están obsoletas (candidatas a borrar).
- **Input de exploración:** `ExplorationController._unhandled_input()` gestiona `interact`, `open_inventory`, `open_party`, `open_player_menu`. `ExplorationHUD` comprueba también `GameLoop.is_input_blocked()`. El nodo `Player` real usa `PlayerExploration`; `player.gd` es código muerto (limpieza bloqueada por `test/test_shop_ui.gd`).
- **Atajo de desarrollo F2** (keycode crudo, solo `OS.is_debug_build()`): lee `user://debug_shortcut.json` en cada pulsación (no la raíz del proyecto; en Windows `%APPDATA%\Godot\app_userdata\<proyecto>\`), aplica `Narrative.set_flag()` por cada entrada de `"flags"` y `Characters.set_skill_value("player", id, valor)` por cada `"skills"`. Se comprueba antes de `is_input_blocked()`; es mutación en memoria, nunca toca `SaveManager`.
---
 
## Menú principal, carga y Character Creation
 
- **Menú principal:** Main Scene (`MainMenuScreen`, `CanvasLayer`). Estados del ViewModel: `HIDDEN → MAIN ↔ OPTIONS / CREDITS / CONFIRM_QUIT / TRANSITIONING → HIDDEN`. Escucha `game_state_changed` (ver `athelia_ui_architecture.md`).
- **LoadingScreen:** carga asíncrona con barra; implementada y sin conectar al orquestador.
- **Character Creation:** MVVM. **6 atributos** (no 7 de RuneQuest): `strength, dexterity, constitution, intelligence, wisdom, charisma`. Roll-and-assign: 3D6 (STR/DEX/CHA), 2D6+6 (CON/INT/WIS), 1 reroll. Estados: `ROLLING → ASSIGNING → NAMING → SUMMARY → TRANSITIONING`. Usa `data/characters/player_new.tres` (no `player_base.tres`, plantilla de test). `_create_player_entity()` registra en `Characters`, `Resources`, `Skills`, `Equipment` e `Inventory`; `Resources.register_entity()` debe preceder a `set_base_attribute()` (este dispara `ModifierApplicator` de forma síncrona). El kit de skills se lee de `definition.skills`, nunca de una lista duplicada. Usa `skills.has_entity("player")`.
## Arranque de aventura
 
`AdventureStarter.apply(DEFAULT_ADVENTURE_ID)` se llama una sola vez desde `CharacterCreationViewModel.request_confirm_character()`, tras `_create_player_entity()`: lee `data/adventures/<id>.json` (`schema_version`, `companions`, `starting_gear` por entidad), une companions (`Party.join_party`) y da y equipa el kit (`Inventory.add_item` + `Equipment.equip_item`). **No es idempotente a propósito** (`add_item` suma).
 
---
 
## Skills — dos accesores de valores
 
- **`CharacterState.skill_values`** (`Characters.get_skill_value()`/`list_known_skills()`): se inicializa desde `CharacterDefinition.starting_skill_values`. Es lo que leen combate y tiradas narrativas. `Characters.get_skill_value()` devuelve 0 para una skill fuera del kit.
- **`SkillSystem._entity_skills`** (`Skills.get_skill_instance()`/`register_entity_skills()`): registro separado de un solo uso (`if _entity_skills.has(entity_id): return`), usado para desbloqueo y progresión.
Si una skill aparece en `list_known_skills()` pero no está en `register_entity_skills()`, el síntoma es un aviso «Skill not found for entity» al terminar combate. Jugador y companions deben pasar `definition.skills` explícitamente (nunca una lista propia ni el array vacío, que registra el catálogo entero).
 
**Skills fuera del kit:** `Skills.learn_skill(entity_id, skill_id)` crea la instancia si falta y la desbloquea con `unlock_skill()` (se siguen comprobando `prerequisite_requirements`; si falla, retira la instancia). El valor inicial lo fija `ItemCharacterBridge`: clave opcional `initial_value` en `learning_data`, por defecto `base_success_rate`, solo si la entidad no tenía ya un valor > 0. Curtido (`skill.exploration.tanning`) es el primer caso real.
 
## ItemCharacterBridge
 
Target de un modificador: `tipo.id` (`resource.health` → valor **actual**, no el máximo; `attribute.strength` → atributo **base**; `skill.exploration.lockpick` → valor de skill, el id puede contener puntos). Operaciones: `add`, `mul`, `override`.
 
- `EQUIPMENT` delega a `Equipment.toggle_equipment()` (camino del jugador desde la UI). Para equipar por código, `Equipment.equip_item(entity_id, item_id)` es directo y no exige el ítem en el inventario. El puente emite `item_use_success` también al equipar.
- **Libros de aprendizaje** (`learning_data`: `skill_id`, `source_level`, `source_type`, `initial_value` opcional): si la entidad tiene la skill, crea una `LearningSession` y delega en `SkillProgression` (tirada de mejora); si no, la primera lectura la enseña (`learn_skill()` + valor inicial, sin tirada). `_apply_learning()` devuelve `bool`: si no se aplicó (`invalid_session`, `skill_locked`, `no_progression`, prerrequisitos) el ítem **no se consume** (`item_use_failed`); una tirada de mejora fallida sí lo consume, y `challenge_too_low` también.
- `ItemDefinition.item_type` es un enum cerrado: `CONSUMABLE`/`EQUIPMENT`/`MISC` (el botín/trofeo sin mecánica es `MISC`).
---
 
## Motor narrativo (`core/narrative_scenes/` + `ui/narrative_scene/`)
 
MVVM estándar (ver `athelia_ui_architecture.md` para la pantalla). Estados del ViewModel: `HIDDEN → SHOWING ↔ WAITING_ROLL → TRANSITIONING → HIDDEN` (`WAITING_ROLL` reservado, no se emite). Sin sistema runtime propio: el progreso de una escena vive en `NarrativeSceneViewModel`.
 
**Contrato de datos** (`NarrativeSceneDefinition` → `NarrativeSceneOption` → `NarrativeSceneOutcome`, cada uno un `Resource` en fichero propio). Una opción sin `skill_id` resuelve por `outcome_default`; con `skill_id` tira contra `Characters.get_skill_value(entity_id, skill_id) + roll_modifier` y el grado decide el outcome, con fallback fumble→failure, special→success, critical→success.
 
**Esquema JSON real:**
- Escena: `scene_id`, `image_path` (validado al cargar con `push_warning`), `text_key`, `options[]`.
- Opción: `option_id`, `text_key`, `skill_id`, `roll_modifier`, `challenge_level` (0 = sin progresión; >0 engancha a `SkillProgression` con `SourceType.NARRATIVE`, solo en éxito), `required_successes`/`retry_policy` (`"immediate"`/`"blocked"`; una pifia siempre transiciona), `group_aggregate` (`""`/`"worst"`/`"best"`). El contador de racha vive en el ViewModel. La oposición se codifica en `roll_modifier`, sin tabla de resistencia. Ramas planas: `outcome_failure`/`outcome_success`/`outcome_special`/`outcome_critical` (sin `outcome_fumble`).
- Outcome: `next_scene_id`, `flag_to_set` (un único flag, prefijo `flag.`; solo activa), `combat_enemy_ids` (presentes al inicio), `combat_enemy_definitions` (`entity_id → definition_id` de todo lo que hay que registrar, inicial o de refuerzo), `combat_encounter` (diccionario **inline** con las claves de `CombatEncounterDefinition`, nunca una ruta a `.tres`), `combat_victory_scene_id`, `dialogue_id`, `grant_item_*`, `take_item_*`, `grant_resource_*`.
**Orden de `_apply_outcome()`:** flag → otorgar ítem → quitar ítem → otorgar recurso → si hay `dialogue_id`, abrir diálogo y **retorno temprano** (los `grant_*` ya se aplicaron) → si hay combate, registrar enemigos (`_register_combat_enemies()`) y avisar a `CombatLootSpawner` antes de `start_combat()` → `next_scene_id`. Todo `grant_*` deja una línea de log.
 
- **`grant_item_*`**: `Inventory.add_item()`, `grant_item_target` por defecto `"player"`.
- **`take_item_*`**: `Equipment.unequip_item()` y luego `Inventory.remove_item()`; si la entidad no lo tiene no es error; busca el ítem primero en `take_item_target` (`"player"` por defecto) y, si no lo tiene, en el resto de la party (`_take_item_from_party()`), desequipando y retirando donde lo encuentre (Spike 19b).
- **`grant_resource_*`**: `Resources.add_resource()`; un recurso por outcome.
- **`dialogue_id`**: abre `DialoguePanel` como sub-overlay llamando a `Dialogue.start_dialogue()`, sin transición de `GameState`. `next_scene_id` pasa a significar «escena a la que avanzar al cerrar el diálogo» (`resume_after_dialogue()`). El diálogo solo conversa: las entregas van en el outcome que lo abre, antes del diálogo.
- **`combat_victory_scene_id`**: se pasa a `start_combat()`; al ganar se abre esa escena en vez de volver a `EXPLORATION`. Huir devuelve al pueblo.
- **Registro de enemigos:** `NarrativeSceneViewModel` y `ExplorationController` pre-registran `Characters`/`Resources` para enemigos pero **nunca `Skills`**; `combat_production_scene.gd` registra Skills con guard idempotente para el roster inicial y los refuerzos.
- **Retorno desde combate:** hoy se hace con `combat_victory_scene_id` (encadenado directo). El patrón antiguo (spawnear un `Interactable` tras `combat_ended`) está obsoleto.
**Datos por aventura:** personajes e ítems propios en subcarpeta de la aventura (`data/characters/telmori/`, `data/items/telmori/`), salvo ítems de arma con ranura, que se agrupan por tipo (`data/items/weapons/<slot>/`). Localización en un CSV propio por aventura (`_telmori.csv`). Los diálogos llevan prefijo `dlg_` (un diálogo y una escena con el mismo nombre en carpetas distintas se pisan al copiar).
 
---
 
## Diálogo
 
- `DialogueNodeDefinition.mood` (por nodo, por defecto `"neutral"`); `DialogueDefinition.portrait_folder` y `background_id` (opcionales, con respaldo: vacíos, el comportamiento es el anterior). Fondo: `res://data/dialogue/backgrounds/<portrait_folder>/<background_id>.png`, con respaldo al genérico de la aventura.
- `EventBus.dialogue_node_shown` lleva 7 argumentos (`portrait_id`, `mood`, `portrait_folder`, `background_id`, …). GDScript descarta los de más si el callback acepta menos.
- `DialogueOptionDefinition.triggers_save` (ver «Guardado»). Los eventos narrativos se disparan desde `narrative_events` de la opción, no desde el `trigger_type: DIALOGUE_END` del evento (no hay código que consuma `dialogue_ended` para eso).
- `DialogueRegistry._load_option_from_dict()` asigna campo a campo: un campo nuevo en el JSON no se lee solo.
---
 
## Combate — entrada y arena
 
Los nombres de acción del InputMap de combate (`_unhandled_input`, no `_input`, para no perder prioridad frente a nodos de escenas aditivas):
 
| Action | Tecla | Skill |
|---|---|---|
| `combat_attack_1` | 1 | `skill.attack.light` |
| `combat_attack_2` | 2 | `skill.attack.heavy` |
| `combat_attack_3` | 3 | `skill.attack.stunning_blow` |
| `combat_dodge` | Q | `skill.combat.dodge` |
| `combat_defense` | E | `skill.combat.defend` |
| `combat_scape` | R | `skill.combat.flee` (el nombre real es `scape`, no `escape`) |
| `cycle_target` | Tab | — |
 
- `PlayerCombatController` (grupo `"player_combat_controller"`) es el **único dueño del targeting** (auto-target en `_on_combat_started()`, ciclado con Tab) y del despacho de `player_action_requested` (`request_skill()`).
- El menú del jugador son **8 slots** (3 ataque + esquiva + defensa + huida + 2 consumibles); el `LoadoutState` del jugador debe asignarse desde la pantalla de Loadout (esquiva y defensa se asignan allí; **huida es fija** y no se asigna), o los botones salen sin nombre. Con el loadout actual el HUD muestra vacíos los slots de defensa y huida: `skill.combat.defend`/`flee` no tienen `.tres` y el controlador resuelve `combat_defense`/`combat_scape` por id hardcodeado (pendiente de replantear con el combate).
- `CombatArenaViewModel` compone a `CombatHudViewModel` y se conecta a `Resources.resource_changed` directamente. `EnemyAI`/`CompanionAI` son `Node` sin dependencia de nodo padre; los instancia `combat_production_scene.gd`. `EnemyCombatNode` ya no se usa en producción.
- **Tiradas y daño:** `SPECIAL` aplica `special_multiplier` (×1.2) vs crítico (×2); en progresión cuenta como éxito sin tick diferenciado. No hay modificador multiplicativo de combate (decisión explícita: sin caso de uso real).
- **Cuidado al extender enums:** un `match` sin rama `_:` y un array indexado por enum no avisan si el enum crece; hay que revisar todos sus consumidores.
- `combat_resolver.gd` fue eliminado (código muerto).
---
 
## Nota de convenciones
 
Ver `athelia_lecciones_tecnicas.md`. Estructura de carpetas: `athelia_estructura_carpetas.md`. Historial de spikes: `athelia_historial_spikes.md`.