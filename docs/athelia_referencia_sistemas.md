# Athelia — Referencia de sistemas (estado actual)
 
Motor: Godot 4.7.2 (Forward Plus)
Proyecto: RPG por turnos con exploración, combate, diálogo, economía y narrativa.
 
Este fichero describe el estado ACTUAL de los sistemas del proyecto — qué
existe y cómo se comporta hoy. No lleva historial de spikes: el porqué de
cada decisión y la narrativa de cómo se llegó aquí vive en
`athelia_historial_spikes.md`. Las lecciones técnicas reutilizables (bugs,
patrones, antipatrones de motor) viven en `athelia_lecciones_tecnicas.md`.
La estructura de carpetas completa vive en `athelia_estructura_carpetas.md`.
El Design System y el patrón MVVM de UI viven solo en
`athelia_ui_architecture.md` — no se duplican aquí.
 
---
 
## Autoloads (Singletons globales)
 
Estos sistemas están disponibles globalmente en todo el proyecto sin necesidad de referencia explícita.
 
### Infraestructura base
| Singleton | Script | Descripción |
|-----------|--------|-------------|
| `EventBus` | `core/event_bus.gd` | Bus de eventos desacoplado. Canal de comunicación entre sistemas sin dependencias directas. |
| `GameLoop` | `core/game_loop_system.gd` | Máquina de estados global del juego. Gestiona los estados (`MENU`, `CHARACTER_CREATION`, `EXPLORATION`, `DIALOGUE`, `SHOP`, `NARRATIVE_SCENE`, `COMBAT_ACTIVE`, `VICTORY`, `DEFEAT`, `PAUSE`, `SAVE_TRANSITION`) y las fases de turno del combate (`ROUND_START → PLAYER_TURN → COMPANION_ACTION_RESOLVE → ENEMY_TURN → ROUND_END`). Controla la iniciativa, el orden de turno y las condiciones de victoria/derrota. |
| `SceneOrchestrator` | `core/scene_orchestrator.gd` | Reacciona a cambios de `GameState` (vía EventBus) para mostrar/ocultar overlays de UI (diálogo, tienda, inventario, escena narrativa) y cargar/descargar la escena de combate. No modifica el estado del juego directamente, solo responde a él. |
| `SaveManager` | `core/save/save_system.gd` | Sistema de guardado y carga de partida. Slot único: `"quicksave"`. |
| `UITokens` | `ui/design_system/tokens/ui_tokens.gd` | Sistema de tokens de diseño (colores, espaciado, tamaños). Usado por todos los componentes del Design System. |
 
### Sistemas de personaje
| Singleton | Script | Descripción |
|-----------|--------|-------------|
| `Characters` | `core/characters/character_system.gd` | Gestión de personajes: creación, acceso y ciclo de vida. |
| `Modifiers` | `core/characters/modifier_applicator.gd` | Aplicación de modificadores sobre atributos de personajes. |
| `Resources` | `core/resources/resource_system.gd` | Gestión de recursos vitales (vida, stamina, oro). **Desde Spike 6**: `register_entity()` depende de `Characters`/`AttributeResolver` (llama a `AttributeResolver.resolve_resource_max()` para sincronizar `max_effective` de cualquier entidad) — requiere que `Characters.register_entity()` ya se haya llamado antes para esa entidad, o se queda sin sincronizar (con warning). Primera dependencia real de `ResourceSystem` hacia otro sistema; antes era autocontenido. |
| `Skills` | `core/skills/skill_system.gd` | Sistema de habilidades: registro, acceso y uso. `SkillRoller` (no autoload, `class_name` estático) resuelve las tiradas D100: 5 grados desde Spike 2 (`FUMBLE/FAILURE/SUCCESS/SPECIAL/CRITICAL`), con `CRITICAL`/`SPECIAL` dinámicos (skill/20, skill/5) y `FUMBLE` absoluto (≥98). `learn_skill()` (Spike 10) enseña a una entidad una skill fuera de su kit inicial (p. ej. desde un libro). |
| `SkillProgression` | `core/skills/skill_progression_service.gd` | Progresión y aprendizaje de habilidades. |
| `SkillEventHandler` | `core/skills/skill_event_handler.gd` | Manejo de eventos relacionados con habilidades. |
| `Stress` | `core/skills/stress_system.gd` | Sistema de estrés del personaje. |
 
### Sistemas de ítems y equipo
| Singleton | Script | Descripción |
|-----------|--------|-------------|
| `Items` | `core/items/item_registry.gd` | Registro global de definiciones de ítems. |
| `Inventory` | `core/items/inventory_system.gd` | Gestión del inventario del jugador. |
| `Equipment` | `core/items/equipment_manager.gd` | Gestión del equipo equipado por el personaje. |
| `Bridge` | `core/items/item_character_bridge.gd` | Adaptador puro entre el sistema de ítems y los sistemas de personaje/recursos. Escucha `item_use_requested` y aplica los modificadores del ítem sobre `Characters`, `Resources` o `Skills` según el tipo (`CONSUMABLE` / `EQUIPMENT`). También gestiona libros de aprendizaje: mejora la skill vía `SkillProgression` si la entidad ya la tiene, o la enseña vía `Skills.learn_skill()` si no (Spike 10); el libro solo se consume si el aprendizaje se aplicó. No modifica `ItemSystem`, `CharacterSystem` ni `InventorySystem` directamente. |
 
### Sistemas de mundo y combate
| Singleton | Script | Descripción |
|-----------|--------|-------------|
| `Combat` | `core/combat/combat_system.gd` | Sistema de combate por turnos. |
| `CombatLootSpawner` | `core/combat/combat_loot_spawner.gd` | Generación de loot al finalizar combate. |
| `Economy` | `core/economy/economy_system.gd` | Sistema económico: compra, venta y precios. |
| `WorldObjects` | `core/world_objects/world_object_registry.gd` | Registro de objetos interactuables del mundo. |
| `WorldObjectSystem` | `core/world_objects/world_object_system.gd` | Lógica de interacción con objetos del mundo. |
| `EnemyWorldLink` | `core/combat/enemy_world_link.gd` | **[Spike 3, Grupo A]** Hueco genérico para limpiar la representación en exploración/world objects de un enemigo que huye (`EventBus.enemy_group_fled`). Guarda un `Callable` de limpieza por `entity_id` vía `register_fled_cleanup()` — no conoce WorldObjectSystem ni ningún tipo de representación concreta. No-op si nadie registró nada. |
 
### Sistemas de narrativa y diálogo
| Singleton | Script | Descripción |
|-----------|--------|-------------|
| `Narrative` | `core/narrative/narrative_system.gd` | Sistema narrativo principal. Almacén real de flags/variables (`set_flag`, `clear_flag`, `set_variable`, `get_variable`, `get_active_flags`). |
| `NarrativeDB` | `core/narrative/narrative_registry.gd` | Base de datos de eventos narrativos. |
| `Dialogue` | `core/dialogue/dialogue_system.gd` | Sistema de diálogo con NPCs. |
| `DialogueDB` | `core/dialogue/dialogue_registry.gd` | Base de datos de diálogos. |
| `Checkpoints` | `core/narrative/checkpoint_system.gd` | Sistema de checkpoints narrativos. Consolida/limpia vectores narrativos en transiciones de acto — no es el almacén de flags de uso general (eso es `Narrative`). |
| `CheckpointDB` | `core/narrative/checkpoint_registry.gd` | Base de datos de checkpoints. |
| `NarrativeSceneDB` | `core/narrative_scenes/narrative_scene_registry.gd` | **[Spike 1]** Registro de escenas narrativas (imagen + texto + opciones), cargadas desde JSON. Sin estado runtime — consulta local síncrona por `scene_id`. El estado de progreso por una escena vive en `NarrativeSceneViewModel`, no aquí. |
| `InteractiveSceneDB` | `core/interactive_scenes/interactive_scene_registry.gd` | **[Spike 12]** Registro de escenas interactivas (imagen de fondo + puntos clicables con visibilidad por flags), cargadas desde `data/interactive_scenes/*.json` (escaneo SIN recursión). Sin estado runtime — mismo patrón que `NarrativeSceneDB`. |
 
### Companions y party
| Singleton | Script | Descripción |
|-----------|--------|-------------|
| `Party` | `core/companions/party_manager.gd` | Gestión del grupo de personajes (party). |
| `PartyEventHandler` | `core/companions/party_event_handler.gd` | Manejo de eventos relacionados con la party. |
 
---
 
## Notas arquitectónicas clave
 
### GameLoop — Estados y fases de turno
 
Estados del juego (`GameState`) y transiciones válidas:
```
MENU → EXPLORATION, CHARACTER_CREATION, NARRATIVE_SCENE  ⭐ NARRATIVE_SCENE añadido en mejoras post-Spike 3, Grupo 1
CHARACTER_CREATION → EXPLORATION, MENU
EXPLORATION → DIALOGUE, SHOP, NARRATIVE_SCENE, COMBAT_ACTIVE, PAUSE, SAVE_TRANSITION
DIALOGUE → EXPLORATION, COMBAT_ACTIVE
SHOP → EXPLORATION
NARRATIVE_SCENE → EXPLORATION, COMBAT_ACTIVE
COMBAT_ACTIVE → VICTORY, DEFEAT, EXPLORATION
VICTORY / DEFEAT → EXPLORATION / MENU
```
 
Fases de turno de combate (`TurnPhase`) en orden:
```
ROUND_START → PLAYER_TURN_START → PLAYER_ACTION_SELECT → PLAYER_ACTION_RESOLVE
→ COMPANION_ACTION_RESOLVE (uno por companion activo)
→ ENEMY_TURN_START → ENEMY_ACTION_RESOLVE (uno por enemigo)
→ TURN_END → ROUND_END → ROUND_START
```
 
- La iniciativa se calcula al inicio del combate y determina el `turn_order`. Se calcula una sola vez en `_calculate_initiative()`, llamada solo desde `start_combat()` — nunca se recalcula ronda a ronda.
- Los companions actúan **después del jugador, antes de los enemigos**.
- Un companion incapacitado permanece en `turn_order` pero `CompanionAI` skipea su turno.
- Victoria: todos los enemigos muertos. Derrota: jugador muerto (los companions no evitan la derrota actualmente).
- `start_combat()` acepta como estado de origen `EXPLORATION`, `DIALOGUE`, `MENU` y `NARRATIVE_SCENE` (guard explícito, independiente de `VALID_STATE_TRANSITIONS` — `start_combat()` transiciona directo con `_transition_game_state()`, no pasa por `request_state_change()`). **Spike 13:** firma `start_combat(enemy_ids, encounter = null, victory_scene_id = "")` — la escena a abrir al ganar vive en `_pending_victory_scene_id` (ver "Spike 13").
- **`_transition_to_phase()` devuelve `bool` desde Spike 6** (antes `void`) — `_end_turn()`/`_end_round()` abortan sin reemitir señales si la transición es rechazada. Causa raíz confirmada de un bug de motor real: una invocación duplicada de `_end_turn()` (candidato: señal `combat_action_completed` de un actor equivocado, mal atribuida por fase en vez de por `actor`) dejaba pasar el error de transición y seguía igual, duplicando `round_ended` y el incremento de `round_number` a la vez. `_on_combat_action_completed()` ahora compara `result["actor"]` contra el actor que realmente tiene el turno (`_current_acting_entity`) antes de procesar — requirió añadir `"actor"` al payload de la resolución normal de skill en `CombatSystem`, que no lo llevaba (solo las ramas de excepción staggered/disarmed/dodge sí). Ver `docs/spike_6_investigacion_motor_combate.md` para el detalle completo.
- **Nota sobre `request_state_change()` (confirmado en Spike 3/B):** `DEFEAT` solo tiene transición válida hacia `EXPLORATION`/`MENU` — nunca directo a `CHARACTER_CREATION`. Cualquier flujo de reinicio de partida tras Game Over debe pasar por `enter_main_menu()` antes de `enter_character_creation()`, igual que el camino real de "Nueva Partida" desde el menú.
- **`MENU → NARRATIVE_SCENE` (mejoras post-Spike 3, Grupo 1):** habilita "Cargar Partida" para resumir directamente dentro de una escena narrativa, si el save se hizo desde ahí. Antes de este grupo era un camino inexistente — la única entrada a `NARRATIVE_SCENE` era desde `EXPLORATION`. Ver sección propia de Grupo 1 más abajo para el hallazgo de reentrada que este camino nuevo expuso en `SceneOrchestrator`/`TelmoriVillage._ready()`.
- **Sorpresa de combate (Spike 3, Grupo B):** `CombatEncounterDefinition.surprise_favors` no toca `turn_order` ni `TurnPhase` — la estructura de fases ya obliga a jugador+companions a actuar antes que los enemigos cada ronda, así que reordenar iniciativa no tendría ningún efecto real. En su lugar, el bando sorprendido recibe el buff `staggered` ya existente en `CombatSystem` (pierde su primera acción) y, opcionalmente, `vulnerable` (`surprise_vulnerable_pct`, daño extra recibido). Lógica compartida en `GameLoopSystem._apply_surprise()`, llamada desde `start_combat()` y `configure_active_encounter()` — esta segunda ruta hace falta porque un combate disparado desde `ExplorationController` ya está en marcha antes de que se le adjunte el encounter. El `turns_left` del buff `vulnerable` es asimétrico: 2 si perjudica a jugador/companions (actúan antes en la ronda, necesitan sobrevivir a su propio tick), 1 si perjudica a enemigos (actúan al final, su tick ya llega después del ataque).
### Nomenclatura y organización de escenas de juego
 
Convención para toda escena de tipo exploración/combate/narrativa (no aplica a pantallas de `ui/`, que siguen su propia convención MVVM):
 
```
<tipo>_<identificador_semántico>.tscn        # nunca numeración secuencial (ej. NO "_1", "_2")
```
 
Organización de carpetas: scripts **compartidos** por todas las escenas de ese tipo viven en la raíz de `scenes/<tipo>/`; cada zona/contexto concreto vive en su propia subcarpeta:
 
```
scenes/exploration/
├── interactable.gd              ← compartido por todas las zonas
├── exploration_controller.gd    ← compartido
├── exploration_hud.gd           ← compartido
├── player_exploration.gd        ← compartido
├── tutorial/                    ← una zona = una subcarpeta (OBSOLETA desde Spike 3/B)
│   ├── exploration_tutorial.tscn
│   └── exploration_tutorial.gd
├── telmori_village/             ← NUEVO (Spike 3, Grupo B) — zona de producción real (Spike 12: ya no es SCENE_EXPLORATION)
│   ├── exploration_telmori_village.tscn
│   └── exploration_telmori_village.gd
└── interactive_map/             ← NUEVO (Spike 12) — escena de exploración basada en mapa de puntos de interés
    ├── exploration_interactive_map.tscn
    └── exploration_interactive_map.gd
```
 
Mismo patrón previsto para `scenes/combat/arena_<nombre>/` y una futura `scenes/narrative/<evento>/`. El orden de progresión del jugador (qué zona sigue a cuál) debe vivir en datos (futuro registro de niveles/zonas), no en el nombre del archivo — un número no comunica contenido y se rompe al reordenar. Decidido en `docs/spike_produccion_post_character_creation_informe_cierre.md`.
 
### SceneOrchestrator — Gestión de overlays
 
- Escucha `game_state_changed` vía EventBus y **nunca modifica GameState**.
- Los overlays (diálogo, tienda, inventario, escena narrativa) se instancian y destruyen en cada apertura/cierre (`queue_free`).
- La escena de combate se carga de forma **aditiva** (la escena de exploración permanece en memoria debajo) — `SCENE_COMBAT` y `OVERLAY_COMBAT_HUD` son dos piezas separadas, instanciadas ambas en `_handle_combat()`. **Desde Grupo 5**: `SCENE_COMBAT` apunta a `combat_production_scene.tscn` (sin UI, solo IA de enemigos/companions + `PlayerCombatController`) y `OVERLAY_COMBAT_HUD` a `combat_arena_panel.tscn` (la pantalla real, fichas+log+menú). `combat_test.tscn`/`combat_hud.tscn` dejan de ser producción pero no se retiran, siguen como escena de test independiente. **Fuga preexistente encontrada en Grupo 5, no arreglada**: `_handle_combat()` guarda referencia a la instancia de `OVERLAY_COMBAT_HUD` (`_combat_hud`, liberada en `_on_combat_ended()`) pero nunca a la de `SCENE_COMBAT` — esa instancia no se libera nunca desde `SceneOrchestrator`. `combat_production_scene.gd` se libera a sí misma escuchando `combat_ended` directamente, como mitigación local; el fondo del problema (mismo patrón ya existía con `combat_test_scene.gd`) sigue sin resolver a nivel de `SceneOrchestrator`.
- El inventario es especial: se abre como overlay dentro de `EXPLORATION` sin cambiar `GameState`. Se accede vía `SceneOrchestrator.open_inventory()`.
- Hay un problema de timing conocido con la tienda (el evento `shop_opened` se emite antes de que el overlay exista); se resuelve llamando directamente a `show_shop_direct()` con un snapshot del `EconomySystem`. **NarrativeScene no tiene este problema** — `NarrativeSceneDB.get_scene()` es una consulta local síncrona, así que `_handle_narrative_scene()` no necesita ningún `show_X_direct()` especial, el `scene_id` llega vía `_pending_context` igual que `dialogue_id`/`shop_id`.
- El menú principal es la **Main Scene** del proyecto. `_handle_main_menu()` solo limpia overlays residuales; no instancia nada.
- `_handle_character_creation()` usa `_show_overlay()` (igual que Shop/Inventory/Party) — importante: instanciarla manualmente contra `get_tree().root` sin pasar por `_show_overlay()` deja la escena huérfana de `_current_overlay`, y `_hide_current_overlay()` nunca la destruye al salir.
- `_handle_exploration()` instancia `SCENE_EXPLORATION` si no existe ya en el árbol (comprobando por nombre de nodo `"ExplorationScene"`) — necesario para el flujo real Menú → Character Creation → Exploration, no solo para correr una escena de exploración de forma aislada. El nodo instanciado se **renombra** a `"ExplorationScene"` en el propio `_handle_exploration()`, independientemente del nombre que tenga el nodo raíz dentro del `.tscn` — así que el nombre interno del `.tscn` no tiene que coincidir. **Importante para pruebas manuales:** si ejecutas `exploration_test.tscn` suelto (F6), su nodo raíz debe llamarse literalmente `"ExplorationScene"` o esta búsqueda falla y el sistema intenta instanciar otra copia de la escena de producción encima, en medio del arranque del árbol (`add_child()` con "Parent node is busy setting up children").
- **`SCENE_EXPLORATION` apunta ahora a `res://scenes/exploration/telmori_village/exploration_telmori_village.tscn`** (Spike 3, Grupo B) — antes apuntaba a `exploration_tutorial.tscn`, que queda obsoleta (pensada para un mundo 2D más amplio que ya no es el centro de la jugabilidad tras el pivote narrativo) y pendiente de retirar del proyecto.
- **`SCENE_EXPLORATION` apunta ahora (Spike 12) a `res://scenes/exploration/interactive_map/exploration_interactive_map.tscn`** — el mapa de PRUEBA (`poi_test_map`). La línea del pueblo queda comentada justo debajo (revertible descomentándola; mismo patrón que ya se usó con el tutorial). El nombre del nodo raíz del `.tscn` es libre: `_ensure_exploration_scene_instantiated()` fuerza `instance.name = "ExplorationScene"` al instanciar. Spike 13 decide el estado final.
- **Spike 13:** `SCENE_EXPLORATION` sigue apuntando a `exploration_interactive_map.tscn`, que ahora carga `telmori_village` (el mapa de prueba queda para pruebas cambiando `interactive_scene_id`). Las líneas comentadas de `SCENE_EXPLORATION` (pueblo antiguo, tutorial), si siguen ahí, son restos candidatos a limpieza.
- `_handle_narrative_scene(scene_id)` — calcado de `_handle_dialogue()`: `_hide_current_overlay()` → `_show_overlay(OVERLAY_NARRATIVE_SCENE)` → `open(scene_id)` en el overlay instanciado. Cierre vía `EventBus.narrative_scene_closed` → `_on_narrative_scene_closed()` → `GameLoop.enter_exploration()`, mismo patrón que `_on_shop_closed()`.
### Interactable — tipos de interacción (Spike 3, Grupo B)
 
`Interactable.interaction_type` (`@export_enum`) admite 5 valores:
 
| `interaction_type` | Efecto en `ExplorationController._on_interaction_requested()` |
|---|---|
| `"dialogue"` | `GameLoop.enter_dialogue(target_id)` |
| `"shop"` | `GameLoop.enter_shop(target_id)` |
| `"combat"` | Registra enemigos (`enemy_id → definition_id` leído de `Interactable.enemy_definitions`) y llama a `GameLoop.start_combat()` |
| `"item"` | Recoge ítem vía `WorldObjectSystem`, sin cambio de `GameState` |
| `"narrative_scene"` | `GameLoop.enter_narrative_scene(target_id)` — **nuevo en Spike 3/B**. Antes no existía ningún camino de producción para entrar en una escena narrativa desde exploración; la única vía que había existido nunca era una tecla de debug (F1) de Spike 1, ya retirada en Spike 3, Grupo A |
 
**Spike 12 — correcciones tras revisar el código real (Fase 0):**
 
- El routing ya no vive en `_on_interaction_requested()`, sino en `ExplorationController.request_interaction(type, target_id, enemy_definitions := {})`. `_on_interaction_requested()` delega en él pasando el `enemy_definitions` del `_current_interactable`; el comportamiento del camino físico no cambia. Motivo: la señal `interaction_requested(type, target_id)` no puede llevar `enemy_definitions` (un signal de GDScript no admite parámetros opcionales) y un punto sin nodo físico no tiene de dónde leerlo — sin el canal nuevo el combate degradaba en silencio a `enemy_base`.
- El `@export_enum` de `interactable.gd` **NO lista `"narrative_scene"`** (solo `dialogue`/`shop`/`combat`/`item`). El valor funciona porque `exploration_telmori_village.gd` lo asigna con `area.set("interaction_type", "narrative_scene")`; el enum es solo cosmético (el campo es `String`). La descripción de `interactable.gd` de más arriba y la de la tabla contaban el enum como si lo incluyera.
- En el pueblo, `Interactable` solo se usa con `narrative_scene` y siempre creado por código (rastro, aftermath, recompensa del sheriff); el `.tscn` del pueblo no tiene ninguno. Los `.tscn` de `exploration_test`/`exploration_tutorial` sí los instancian, pero ninguna de las dos es ya `SCENE_EXPLORATION`.
- **Spike 13 — `Interactable` queda VESTIGIAL.** El pueblo ya no usa ninguno (`telmori_village.json` es declarativo) y un mapa estático no puede tenerlos (sin jugador, física ni proximidad). Fernando descartó `exploration_tutorial` y `exploration_test` (no eran escenas de producción), así que no queda ningún consumidor en el camino jugable. El camino físico refactorizado en Spike 12 (`request_interaction()`) **nunca se validó en partida real y ya no se va a validar**. Candidato a limpieza en la recopilación final.
### Menú principal — Arquitectura
 
El menú principal sigue el patrón MVVM con una única escena que muestra/oculta paneles internos:
 
```
MainMenuScreen (CanvasLayer)        ← Main Scene del proyecto
└── Control
    ├── BackgroundRect              ← placeholder, futuro: ilustración
    ├── TitleLabel                  ← "ATHELIA", futuro: logo
    ├── MainPanel                   ← botones principales
    ├── OptionsPanel                ← volumen, fullscreen, idioma
    ├── CreditsPanel                ← texto scrolling
    └── ConfirmQuitPanel            ← diálogo Sí/No
```
 
Estados del `MainMenuViewModel`: `HIDDEN → MAIN ↔ OPTIONS / CREDITS / CONFIRM_QUIT / TRANSITIONING → HIDDEN`
 
**Importante:** `MainMenuViewModel` escucha `EventBus.game_state_changed` — vuelve a `"main"` al reentrar en `GameState.MENU`, y se oculta (`"hidden"`) en cualquier otro estado. Como `MainMenuScreen` es la Main Scene, nunca se destruye — sin este listener, tras la primera transición fuera de `MENU` se quedaba permanentemente en `TRANSITIONING` con los botones deshabilitados.
 
**Actualizado en mejoras post-Spike 3, Grupo 1:** el guardado **sí está disponible desde el menú principal** vía "Cargar Partida" — pero ya no se guarda con F5 desde la exploración (retirado del todo). Guardar solo es posible seleccionando una opción de diálogo ofrecida por NPCs concretos marcados como savepoint (`DialogueOptionDefinition.triggers_save`), dentro de una escena narrativa. "Cargar Partida" resume directamente en esa misma escena narrativa si el save se hizo así (`MainMenuViewModel.request_load_game()` decide entre `enter_narrative_scene()`/`enter_exploration()` según `SaveManager.get_pending_narrative_scene_id()`). Ver sección propia de Grupo 1 más abajo.
 
### LoadingScreen
 
Pantalla de carga pasiva sin ViewModel. Usa `ResourceLoader.load_threaded_request()` para carga asíncrona con barra de progreso. Emite `loading_finished(packed_scene)` al completar. Actualmente implementada pero no conectada a `SceneOrchestrator` — se integrará cuando las escenas de exploración crezcan en tamaño, o junto a la futura escena de introducción/transición narrativa entre Character Creation y Exploration.
 
### Character Creation — Arquitectura
 
Sigue el patrón MVVM estándar. Atributos reales del proyecto: **6**, no los 7 de RuneQuest — `strength, dexterity, constitution, intelligence, wisdom, charisma` (no hay `SIZ` ni `POW`).
 
```
CharacterCreationScreen (CanvasLayer)
└── Root (Control, full rect)
    ├── AttributeRollPanel   ← roll-and-assign: 3D6 (STR/DEX/CHA), 2D6+6 (CON/INT/WIS), 1 reroll
    ├── NamePanel
    └── SummaryPanel         ← RichTextLabel + BBCode
```
 
Estados del `CharacterCreationViewModel`: `ROLLING → ASSIGNING → NAMING → SUMMARY → TRANSITIONING`
 
Usa `data/characters/player_new.tres` (no `player_base.tres`, que es plantilla de test/debug con skillset completo pre-desbloqueado). `_create_player_entity()` registra la entidad en `Characters`, `Resources`, `Skills` (kit fijo explícito, no el catálogo completo), `Equipment` e `Inventory`, en un orden concreto: `Resources.register_entity()` debe preceder a `set_base_attribute()`, porque este último dispara `ModifierApplicator` de forma síncrona y necesita que `ResourceSystem` ya conozca a la entidad.
 
**Spike 3, Grupo B — el kit fijo de skills se lee de la propia `CharacterDefinition`.** Antes, `_create_player_entity()` registraba el kit vía una constante hardcodeada (`STARTING_SKILL_VALUES`) duplicada e independiente de `player_new.tres` — al añadir skills nuevas al `.tres` sin tocar la constante, `SkillSystem` nunca las registraba (aunque `CharacterState.skill_values`, que sí lee del `.tres` directamente, funcionaba bien — de ahí que las tiradas resolvieran con % correcto pero `SkillSystem.get_skill_instance()` fallara al terminar combate). Eliminada la constante; ahora se lee `chars.get_definition(PLAYER_DEFINITION_ID).skills`.
 
**Spike 13 — el arranque de aventura sale del ViewModel y de la escena.** `request_confirm_character()` llama a `AdventureStarter.apply(DEFAULT_ADVENTURE_ID)` justo después de `_create_player_entity()` y antes de `enter_exploration()`: une a `companion_mira` y da y equipa el kit inicial de `player` y de la companion, leído de `data/adventures/telmori.json`. Sustituye a `STARTING_ITEMS` (ahora vacío) y a `_equip_starter_gear()` de la escena del pueblo, que dejaba dos espadas y dos armaduras al jugador y re-añadía el kit en cada `_ready()` (también al cargar partida; no verificado en el código antiguo, eliminado de raíz).
 
Ver `docs/spike_character_creation_informe_cierre.md` para el detalle completo.
 
### Skills — dos sistemas paralelos de valores (aclarado en Spike 3, Grupo B)
 
Dos accesores distintos para lo que parece "lo mismo", sin relación entre sí:
 
- **`CharacterState.skill_values`** (vía `Characters.get_skill_value()` / `Characters.list_known_skills()`) — se inicializa desde `CharacterDefinition.starting_skill_values` dentro de `CharacterState.new(definition)`, en el propio `register_entity()`. Es lo que leen tanto combate como las tiradas narrativas para resolver el % de una tirada.
- **`SkillSystem._entity_skills`** (vía `Skills.get_skill_instance()` / `Skills.register_entity_skills()`) — registro separado, una sola vez (`register_entity_skills()` tiene guard de registro único: `if _entity_skills.has(entity_id): return`), usado solo para desbloqueo (`is_unlocked`) y conteo de progresión (`SkillProgressionService._process_improvement_rolls()` itera `list_known_skills()` pero busca la instancia aquí).
Si el registro de `SkillSystem` no incluye una skill que sí aparece en `list_known_skills()` (porque se pasó una lista distinta a `register_entity_skills()`), el síntoma es un aviso de `SkillSystem` ("Skill not found for entity") al terminar combate, sin que las tiradas en sí se vean afectadas — fácil de pasar por alto. Tanto `CharacterCreationViewModel` (jugador) como `PartyManager._register_in_systems()` (companions) deben pasar `definition.skills` explícitamente a `register_entity_skills()`, nunca una lista propia ni el array vacío por defecto (que registra el catálogo entero).
 
**Skills fuera del kit inicial (Spike 10).** Un libro (o cualquier fuente futura) puede enseñar una skill que la entidad no tiene registrada. `SkillSystem.learn_skill(entity_id, skill_id)` crea la instancia si falta y la desbloquea reutilizando `unlock_skill()` — se siguen comprobando `prerequisite_requirements`; `requires_unlock` no bloquea, porque aprenderla es lo que resuelve ese bloqueo. Si el desbloqueo falla, retira la instancia (nunca quedan skills a medias); con una skill ya registrada no salta su bloqueo. El **valor inicial** (`CharacterState.skill_values`) no lo fija `SkillSystem` sino `ItemCharacterBridge` (que ya conecta ambos sistemas): clave opcional `initial_value` en `learning_data`, por defecto el `base_success_rate` de la skill, y solo si la entidad no tenía ya un valor > 0. Persistencia: `CharacterState` guarda y restaura `skill_values` entero, y `SkillSystem.load_save_state()` recrea desde su definición las instancias que no están en el kit — sin eso una skill aprendida en runtime se perdía al cargar. Curtido (`skill.exploration.tanning`) es el primer caso real.
 
### Narrative Scene — Arquitectura (motor base del pivote hacia RPG narrativo)
 
Sigue el patrón MVVM estándar. Vive fuera de `core/narrative/` deliberadamente — ese paquete (`NarrativeSystem`/`CheckpointSystem`) gestiona hitos recordados; `core/narrative_scenes/` resuelve "qué nodo se muestra ahora", responsabilidad distinta. Sin "system" runtime propio: `NarrativeSceneDB` es una consulta local síncrona sobre datos cargados de JSON, sin estado — el progreso por una escena vive enteramente en `NarrativeSceneViewModel`.
 
```
NarrativeScenePanel (CanvasLayer, layer 10)
└── Root (Control, full rect)
    ├── SceneImage (TextureRect, %)          ← Grupo 4: fondo a pantalla completa, IGNORE_SIZE + KEEP_ASPECT_COVERED
    └── UIPanel                              ← Grupo 4: tercio inferior (anclas 0.04/0.66/0.96/0.96), crece hacia arriba; Spike 9: decorative_frame = true + esquinera 64×64
        └── MarginContainer → HBoxContainer
            ├── SceneText (Label, %)         ← ratio 1.4
            └── OptionsContainer (VBoxContainer, %)   ← ratio 1.0, UIButton instanciado por opción
```
 
**Mejoras post-Spike 3, Grupo 4 — layout B1.** Hasta este grupo, `SceneImage` vivía dentro del `VBoxContainer`, encima del texto, con `expand_mode` por defecto (`KEEP_SIZE`) — nunca se notó porque ninguna escena tenía `image_path` relleno, pero una imagen real habría reventado el panel (el tamaño mínimo de un `TextureRect` con `KEEP_SIZE` es el de su textura). El layout se eligió tras maquetar tres variantes; el cambio es solo de `.tscn` — el script sigue encontrando los tres nodos por nombre único. Una escena con `image_path` vacío muestra ahora la caja inferior con la exploración visible detrás (antes: panel centrado).
 
Estados del `NarrativeSceneViewModel`: `HIDDEN → SHOWING ↔ WAITING_ROLL → TRANSITIONING → HIDDEN` (`WAITING_ROLL` reservado, no se emite todavía — `SkillRoller.roll_skill()` es síncrono, sin ventana real de espera en Spike 1).
 
Contrato de datos (`NarrativeSceneDefinition` → `NarrativeSceneOption` → `NarrativeSceneOutcome`, todos Resource en fichero propio, no clases internas): una opción sin `skill_id` resuelve directo por `outcome_default`; con `skill_id`, tira contra `Characters.get_skill_value(entity_id, skill_id) + roll_modifier` vía `SkillRoller.roll_skill()`, y el grado de resultado (`FUMBLE`/`FAILURE`/`SUCCESS`/`SPECIAL`/`CRITICAL` desde Spike 2) determina qué `NarrativeSceneOutcome` aplicar (con fallback: fumble→failure, special→success, critical→success si no están definidos). Un outcome puede: cerrar la escena, encadenar a otro `next_scene_id`, marcar un flag vía `Narrative.set_flag()`, disparar combate vía `GameLoop.start_combat(enemy_ids)`, u **otorgar un ítem** (Spike 3/B, ver abajo).
 
**Spike 3, Grupo B — `NarrativeSceneOutcome` extendido:**
- `combat_encounter: CombatEncounterDefinition` (opcional, null por defecto) — se pasa directo a `start_combat()`, sustituye la necesidad de `configure_active_encounter()` para este caso.
- `combat_enemy_definitions: Dictionary` (enemy_id → definition_id, mismo formato que `Interactable.enemy_definitions`) — necesario porque un combate disparado desde narrativa no tiene ningún `Interactable` del que leer este mapeo. Sin él, los enemigos nunca se registrarían en `CharacterSystem`/`ResourceSystem` antes de `start_combat()`.
- `grant_item_id` / `grant_item_quantity` / `grant_item_target` — entrega puntual de un ítem, resuelto vía `Inventory.add_item()`. `grant_item_target` es configurable en el JSON (por defecto `"player"`), pensado para poder entregar a un companion.
**Spike 3, Grupo D — `NarrativeSceneOutcome` extendido de nuevo:**
- `grant_resource_id` / `grant_resource_amount` / `grant_resource_target` — "otorgar recurso", análogo a `grant_item_*` pero vía `Resources.add_resource()` en vez de `Inventory.add_item()`. Mismo criterio deliberadamente mínimo: un solo recurso por outcome, sin condiciones ni tabla de recompensas. Se resuelve en `_apply_outcome()` justo después de `grant_item_*`, con la misma independencia respecto a si el outcome también dispara combate o encadena escena.
- **Bug real al integrar el patch:** la primera versión declaró `grant_resource_id`/`grant_resource_amount` pero no `grant_resource_target` como propiedad de la clase (se quedó solo el comentario) — `from_dict()` sí intentaba asignarla, y GDScript permite asignación dinámica sobre un `Resource` pero falla en tiempo de ejecución si la propiedad no existe como miembro declarado: `Invalid assignment of property or key 'grant_resource_target'`. Lección reutilizable: al añadir un campo nuevo a una data class por parches sucesivos, verificar que la declaración y el `from_dict()` viajan juntos en el mismo cambio — un error de este tipo no lo detecta el compilador si la asignación es sobre un objeto ya tipado como `Resource` genérico en el momento de la llamada.
**Spike 13 — `NarrativeSceneOutcome` extendido de nuevo:**
- `combat_victory_scene_id: String` (vacío por defecto) — escena narrativa a abrir al GANAR el combate de este outcome, en lugar de volver a `EXPLORATION`. Va en el outcome y no en `CombatEncounterDefinition` porque el encuentro puede ser `null` y el dato se perdería en silencio. `_apply_outcome()` lo pasa a `start_combat()` y avisa (`push_warning`) si la escena no existe.
- `take_item_id` / `take_item_quantity` / `take_item_target` — quitar un ítem (devolver un préstamo). `Equipment.unequip_item()` primero y luego `Inventory.remove_item()`; si la entidad no lo tiene (vendido, ya devuelto) no es un error. Solo una entidad (`"player"` por defecto).
**Mejoras post-Spike 3, Grupo 2 — `NarrativeSceneOutcome` extendido con diálogo:**
- `dialogue_id: String` (vacío por defecto) — cuando está relleno, la opción abre `DialoguePanel` como sub-overlay encima del panel narrativo (mismo patrón que Inventory/Party/PlayerMenu de Grupo 3: hijo directo de `NarrativeScenePanel`, nunca vía `SceneOrchestrator`), llamando directamente a `Dialogue.start_dialogue(dialogue_id)` sobre el autoload — sin transición de `GameState`, se queda en `NARRATIVE_SCENE` durante toda la conversación.
- `next_scene_id` del mismo outcome cambia de significado cuando `dialogue_id` no está vacío: deja de aplicarse al instante y pasa a ser la escena a la que avanzar **cuando se cierre el diálogo** — `NarrativeSceneViewModel.resume_after_dialogue()`, llamado por `NarrativeScenePanel` solo si el sub-overlay que se cerró era Diálogo (nuevo flag interno `_sub_overlay_is_dialogue`, distinto de Inventory/Party/PlayerMenu, que nunca disparan el reenganche).
- Hallazgo crítico: `SceneOrchestrator._on_dialogue_ended()` escuchaba `EventBus.dialogue_ended` (global) y forzaba `enter_exploration()` sin condición — habría destruido la escena narrativa en curso al cerrar un diálogo abierto como sub-overlay. Corregido con guard: `current_game_state == GameState.DIALOGUE`.
- Tres comprobaciones de código previas al diseño (paso obligado del spec): `GameState.DIALOGUE` no tiene ninguna dependencia real más allá de lo genérico (`is_input_blocked()` lo trata igual que `NARRATIVE_SCENE`); `DialogueSystem.start_dialogue()` es una llamada directa al autoload sin ninguna lectura de `GameState`, lo que hace viable el sub-overlay; y no existía ningún mecanismo de "combate desde diálogo" en el proyecto — confirmado también por la transcripción real de "Los Telmori", cuyo contenido candidato (diálogos con el sheriff) es puramente expositivo, así que combate-desde-diálogo queda fuera de alcance por ausencia de caso real.
- Gating de opciones narrativas por flag (`required_flags`/`blocked_flags` en `NarrativeSceneOption`, como sí tiene `DialogueOptionDefinition`) se evaluó y se descartó — el diseño de `resume_after_dialogue()` no lo necesita.
- Validado en partida real contra `sheriff_briefing` de "Los Telmori": apertura del sub-overlay, navegación por las tres ramas de pregunta sin perder el hub, cierre sin disparo indebido de `enter_exploration()`, reenganche automático a `telmori_equipment_arrows`. Ver `docs/mejoras_grupo2_dialogo_narrativa_informe_cierre.md` para el detalle completo.
**Esquema JSON real, confirmado en Grupo C contra ejemplos reales de Grupo B** (útil documentarlo aquí porque no coincidía con lo que se había inferido solo de la descripción de arriba): raíz `scene_id`/`image_path`/`text_key`/`options[]`; opción `option_id`/`text_key`/`skill_id`/`roll_modifier`/`challenge_level`/`required_successes`/`retry_policy`/`group_aggregate`. Sin `skill_id` resuelve por `outcome_default`; con `skill_id`, ramas **planas** en la propia opción — `outcome_failure`/`outcome_success`/`outcome_special`/`outcome_critical` (sin `outcome_fumble` explícito — cae a `outcome_failure`, fallback ya documentado arriba). Cada outcome lleva `next_scene_id`, `flag_to_set` (string único con prefijo `flag.`, solo activa un flag, nunca lo desactiva), `combat_enemy_ids` (array de strings — quiénes están presentes al *empezar* el combate) y `combat_enemy_definitions` (diccionario `entity_id → definition_id` de *todo* lo que hay que registrar, inicial o de refuerzo). `combat_encounter`, cuando aparece, es un **diccionario inline dentro del propio outcome** — nunca una ruta a un `.tres` — con las claves de `CombatEncounterDefinition` (`morale_threshold_pct`, `reinforcement_trigger`, `reinforcement_delay_rounds`, `reinforcement_enemy_ids`, `reinforcement_definition_id`, `surprise_favors`, `surprise_vulnerable_pct`, y desde mejoras post-Spike 3, Grupo 4, `background_path`). No hace falta crear ningún recurso `CombatEncounterDefinition` aparte para contenido disparado desde una escena narrativa.
 
**Restricción real de `reinforcement_definition_id` (Grupo C):** es un único string, no un diccionario por entidad — todo un refuerzo sale de la misma `CharacterDefinition`, no admite mezclar tipos de enemigo en la misma oleada (a diferencia del roster *inicial*, que sí admite tipos mixtos vía `combat_enemy_definitions` normal). Si un contenido necesita refuerzo de tipos mixtos, hay que elegir entre extender el recurso a un diccionario (cambio de motor, no hecho todavía) o simplificar el contenido a un refuerzo homogéneo (la opción que tomó Grupo C).
 
`_apply_outcome()` en el ViewModel resuelve todo esto en orden: flag → otorgar ítem → **quitar ítem (Spike 13)** → otorgar recurso → si hay `dialogue_id`, abrir el diálogo y retorno temprano (`grant_*` ya se aplicaron; `next_scene_id` queda pendiente hasta cerrar el diálogo) → si hay combate, registrar enemigos (`_register_combat_enemies()`, réplica deliberada — no compartida — de la misma lógica en `ExplorationController`) y avisar a `CombatLootSpawner` antes de `start_combat()`.
 
Cierre desacoplado: `NarrativeSceneViewModel` no llama a `GameLoop` directamente al terminar una rama — emite `EventBus.narrative_scene_closed(scene_id)`, y `SceneOrchestrator._on_narrative_scene_closed()` decide volver a `EXPLORATION`. Mismo patrón que `dialogue_ended`/`shop_closed`. Cuando el outcome dispara combate, no hay paso intermedio por `EXPLORATION`: `GameLoop.start_combat()` acepta `NARRATIVE_SCENE` como estado de origen directamente.
 
Ver `docs/spike_1_motor_narrativo_informe_cierre.md` para el detalle completo del motor base, incluidas las lecciones de GDScript (self-reference por `class_name`, colisión de `SceneState` con clase nativa).
 
### ItemCharacterBridge — Aplicación de modificadores
 
El target de un modificador sigue el formato `tipo.id`:
- `resource.health` → afecta el valor **actual** del recurso (no el máximo)
- `attribute.strength` → modifica el atributo **base** del personaje
- `skill.exploration.lockpick` → modifica el valor de la habilidad (el id puede contener puntos)
Operaciones soportadas: `add`, `mul`, `override`.
 
Los ítems de tipo `EQUIPMENT` delegan a `EquipmentManager.toggle_equipment()` (equipa si no está equipado, desequipa si lo está) — este es el camino para cuando el **jugador** usa un ítem desde la UI. Para equipar por código (setup inicial, NPCs, etc.), `Equipment.equip_item(entity_id, item_id)` es directo y no exige que el ítem esté en el inventario (aunque añadirlo también, vía `Inventory.add_item()`, mantiene la coherencia si se desequipa más tarde).
 
Los libros de aprendizaje (`learning_data` en `ItemDefinition`: `skill_id`, `source_level`, `source_type`, y desde Spike 10 `initial_value` opcional) tienen dos caminos según si la entidad ya tiene la skill registrada: si la tiene, crean una `LearningSession` y delegan a `SkillProgression` (tirada de mejora); si no, la **primera lectura la enseña** (`Skills.learn_skill()` + valor inicial, sin tirada de mejora en esa lectura). `_apply_learning()` devuelve `bool`: si el aprendizaje no se pudo aplicar (`invalid_session`, `skill_locked`, `no_progression`, prerrequisitos sin cumplir) el ítem **no se consume** (`item_use_failed`); una tirada de mejora fallida sí lo consume, y `challenge_too_low` también (comportamiento previo, no tocado). Pueden tener también modificadores de recurso adicionales.
 
### Design System y patrón MVVM en UI
 
Ver `athelia_ui_architecture.md` — única fuente para componentes del
Design System (`UIPanel`, `UIButton`, `UISlot`, `UIResourceBar`,
`UIRadialGauge`, `UICombatToken`, marco decorativo, etc.) y para el
patrón MVVM completo (contrato de ViewModel/View, antipatrones,
referencia de pantallas existentes). Se eliminó la copia que vivía aquí
para no mantener dos versiones del mismo contenido.
 
---
 
### Input en combate — Godot 4.7
 
En Godot 4.7, `_input` en nodos del árbol principal tiene prioridad sobre `_unhandled_input` en nodos hijo de escenas aditivas. Todo el input de combate usa `_unhandled_input` para evitar que los eventos sean consumidos antes de llegar al `PlayerCombatController`.
 
El InputMap de combate usa estos nombres de action:
 
| Action | Tecla | Skill |
|--------|-------|-------|
| `combat_attack_1` | 1 | `skill.attack.light` |
| `combat_attack_2` | 2 | `skill.attack.heavy` |
| `combat_attack_3` | 3 | `skill.attack.stunning_blow` |
| `combat_dodge` | Q | `skill.combat.dodge` |
| `combat_defense` | E | `skill.combat.defend` |
| `combat_scape` | R | `skill.combat.flee` |
| `cycle_target` | Tab | — |
 
### Input en exploración — Quickload (F9) y atajo de desarrollo (F2)
 
Mismo patrón de bug que en combate (`_input` bloqueado por prioridad en Godot 4.7): `player.gd` (script de una fase muy temprana del proyecto) tenía la lógica de `quicksave`/`quickload` en `_input()`, pero ese script ya no está en el árbol de ninguna escena activa — el nodo `Player` real usa `PlayerExploration` (`scenes/exploration/player_exploration.gd`). La lógica se movió a `ExplorationController._unhandled_input()`, que ya gestionaba el resto del input de exploración (`interact`, `open_inventory`, `open_party`, `open_player_menu`) correctamente.
 
**Mejoras post-Spike 3, Grupo 1 — F5 retirado por completo.** Guardar deja de ser una hotkey libre en `EXPLORATION`: la única vía es seleccionar una opción de diálogo marcada `triggers_save` en NPCs concretos, dentro de una escena narrativa (ver sección de Grupo 1 más abajo). F9 (quickload) sin restricción de estado de origen — comportamiento revisado en el Spike 7 (ver bug conocido más abajo): `ExplorationController._quickload()` ya no carga en caliente sobre la sesión activa; marca la intención en `SaveManager` (`request_pending_quickload()`, autoload, sobrevive a la recarga) y libera explícitamente el `ExplorationScene` viejo antes de `get_tree().reload_current_scene()`. `MainMenuViewModel._ready()` consume ese flag (`consume_pending_quickload()`) y dispara `request_load_game()` — el mismo camino que "Cargar Partida" desde el menú, sin ninguna rama de lógica nueva. Pese a este reenfoque, la funcionalidad queda NO OPERATIVA por un segundo bug sin resolver — ver más abajo.
 
**Nuevo en el mismo grupo — atajo de desarrollo (F2).** Tecla de debug, keycode crudo (sin InputMap) detrás de `OS.is_debug_build()` desde el primer commit — misma disciplina que evitó que F1 (Spike 1) se quedara viva en producción. Lee `user://debug_shortcut.json` en cada pulsación (no cacheado en `_ready()`), aplica `Narrative.set_flag()` por cada entrada de `"flags"` y `Characters.set_skill_value("player", skill_id, value)` por cada entrada de `"skills"`. Se comprueba **antes** del guard `is_input_blocked()`, deliberadamente — funciona en cualquier `GameState`, para poder forzar un tramo concreto durante una prueba sin depender de dónde esté la partida. Mecanismo aparte del guardado real: nunca toca `SaveManager`/`SaveData`, es mutación directa en memoria de la sesión ya arrancada.
 
`player.gd`/`player.tscn` (`scenes/player/`) no se usan en ninguna escena activa, pero **su limpieza queda aparcada**: `test/test_shop_ui.gd` sigue cargando `player.tscn` como andamiaje. No se tocan hasta una revisión general de la carpeta `test/`.
 
**Spike 7 — F9 (quickload) en sesión activa: cerrado sin arreglo, NO OPERATIVO.** El síntoma original de este párrafo (bloqueo total de input) no se reprodujo tal cual tras el pivote narrativo — resultó ser un bug distinto: F9 en `EXPLORATION` cargaba los datos del save pero no consumía `SaveManager.get_pending_narrative_scene_id()`, así que no llevaba al jugador al punto narrativo correcto (arreglado, ver más abajo). Ese arreglo destapó un segundo bug que sí quedó sin resolver: tras F9 en una sesión que acaba de pasar por combate, el panel narrativo correcto se abre con normalidad pero su botón de opción no responde a clics (ni hover, ni `_input()`, sin ningún rastro en Output) — solo ocurre viniendo de sesión activa, nunca desde "Cargar Partida" en el menú. Investigación extensa (GameState, árbol pausado, ratón capturado, `mouse_filter`, nodos residuales, `mouse_passthrough`, autoloads con `_input()`) descartó todo lo investigable sin dar con la causa. Hallazgo real y sólido de camino: `ExplorationScene` y sus overlays viven como hermanos de `current_scene` bajo `get_tree().root` (no como hijos) — `get_tree().reload_current_scene()` no los toca, así que una "recarga limpia" no lo era (el `ExplorationScene` viejo, con todo el estado de la sesión de combate, sobrevivía intacto). Corregido liberándolo explícitamente antes de recargar, pero el bug de fondo persistió incluso así. **Decisión: F9/quickload en sesión activa queda no operativo** (pendiente decidir si se retira la hotkey del todo); "Cargar Partida" desde el menú no está afectada. Ver `docs/spike_7_f9_quickload_exploration.md` para el detalle completo de la investigación.
 
**Spike 1 Motor Narrativo añadió F1** como tecla de debug temporal en `_unhandled_input()` para disparar `GameLoop.enter_narrative_scene("test_intro")` — retirada en Spike 3, Grupo A junto con `_debug_test_narrative_scene()` y las escenas de prueba asociadas.
 
- **Spike 12 — el atajo F2 lee `user://debug_shortcut.json`, NO la raíz del proyecto.** En Windows `user://` es `%APPDATA%\Godot\app_userdata\<config/name>\`; un `debug_shortcut.json` junto a `project.godot` da `Debug shortcut: file not found at user://debug_shortcut.json`. Ese warning prueba que la tecla SÍ llega (el keycode crudo `KEY_F2` no necesita alta en el InputMap) y solo falla el fichero. En el editor: Proyecto → Abrir carpeta de datos de usuario.
---
 
## Arquitectura archivada (sistemas superados)
 
Las arquitecturas de `exploration_tutorial`, del pueblo de "Los Telmori"
pre-Spike 13 (`exploration_telmori_village`), y de los dos patrones de
reconexión narrativa que dependían de `Interactable` físico, quedaron
superadas por el motor de escenas interactivas (Spike 12) y su aplicación
real al pueblo (Spike 13). Su descripción completa, por valor
arqueológico, vive en `athelia_historial_spikes.md`.
 
---
 
## Notas de convenciones
 
Ver `athelia_lecciones_tecnicas.md` — lista completa de convenciones y
lecciones técnicas reutilizables, con su spike de origen.
 
## Estructura de carpetas
 
Ver `athelia_estructura_carpetas.md` — árbol completo de carpetas y
ficheros del proyecto.
 
## Historial de spikes
 
Ver `athelia_historial_spikes.md` — resumen narrativo de cada spike
(Spike 1 en adelante) y el changelog cronológico completo.