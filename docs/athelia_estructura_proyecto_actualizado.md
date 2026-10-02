# Athelia — Estructura del Proyecto

Motor: Godot 4.7.1 (Forward Plus)  
Proyecto: RPG por turnos con exploración, combate, diálogo, economía y narrativa.

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

## Estructura de carpetas

```
athelia/
├── assets/                         # Assets globales (tiles, sprites)
│   ├── map_tile.png
│   └── Tilemap_color1.png
│
├── core/                           # Núcleo del juego — sistemas puros sin UI
│   ├── event_bus.gd                # [Autoload: EventBus] Bus de eventos
│   ├── game_loop_system.gd         # [Autoload: GameLoop] Máquina de estados global + fases de turno — **Spike 13:** `VALID_STATE_TRANSITIONS`: `VICTORY → NARRATIVE_SCENE`; `start_combat(enemy_ids, encounter, victory_scene_id = "")` + `consume_pending_victory_scene()`; `_start_player_turn()` sale si el combate terminó dentro de `player_turn_started` (huida)
│   ├── scene_orchestrator.gd       # [Autoload: SceneOrchestrator] Gestión de overlays y escenas — **Spike 13:** `_on_combat_ended` abre la escena de victoria pendiente (valida que exista; si no, `push_error` y vuelve a `EXPLORATION`) y no repite `enter_exploration()` tras una huida
│   │
│   ├── characters/                 # Sistema de personajes
│   │   ├── character_system.gd     # [Autoload: Characters]
│   │   ├── character_definition.gd # Resource: definición estática del personaje — Grupo 5: + token_color (Color, centinela Color.BLACK) y type_icon (Texture2D), color de relleno e icono de tipo de la ficha en la arena de combate
│   │   ├── character_state.gd      # Resource: estado en tiempo de ejecución. character_name solo se rellena para el jugador (Character Creation) o vía load_save_state() — SIEMPRE vacío para enemigos/companions por diseño (docstring propio: "nombre fijo en su definición"). Spike 8: confirmado que nada en el proyecto caía a CharacterDefinition.name_key como fallback para esas entidades — ver combat_arena_viewmodel.gd
│   │   ├── loadout_state.gd        # Resource: estado de loadout del personaje
│   │   ├── attribute_resolver.gd   # Resolución de atributos derivados
│   │   └── modifier_applicator.gd  # [Autoload: Modifiers]
│   │
│   ├── combat/                     # Sistema de combate por turnos
│   │   ├── combat_system.gd        # [Autoload: Combat]. Grupo 5: parche en _on_skill_used() (rama dodge) para incluir "actor" en el payload de combat_action_completed/player_action_completed; _get_entity_damage_number_position() gana rama para Control (fichas UICombatToken, ya en espacio de pantalla) junto a la rama Node2D existente
│   │   ├── combat_resolver.gd      # Resolución de acciones de combate — SOSPECHA DE CÓDIGO MUERTO (Grupo 5): duplica lógica de daño con nomenclatura de fases antiguas ("FASE A/B/C", pre-Spike), no lo referencia ningún fichero activo revisado; combat_system.gd tiene su propia implementación inline
│   │   ├── combat_loot_spawner.gd  # [Autoload: CombatLootSpawner]
│   │   ├── defense_module.gd       # Módulo de defensa
│   │   ├── escape_module.gd        # Módulo de huida
│   │   ├── skill_roller.gd         # Tiradas de habilidad (RollResult: FUMBLE/FAILURE/SUCCESS/SPECIAL/CRITICAL desde Spike 2 — CRITICAL/SPECIAL dinámicos skill/20 y skill/5, FUMBLE absoluto)
│   │   ├── combat_encounter_definition.gd  # Resource opcional para start_combat() — moral de grupo (morale_threshold_pct, base dinámica desde Spike 3 Grupo A), refuerzos cronometrados, y sorpresa (Spike 3/B: surprise_favors "party"/"enemies", surprise_vulnerable_pct — vía buff staggered/vulnerable en GameLoopSystem._apply_surprise(), sin tocar turn_order); mejoras post-Spike 3, Grupo 4: + background_path (ruta res:// al mapa de combate de ese encuentro, "" = fondo sólido) — el recurso nunca carga la textura, lo hace CombatArenaViewModel
│   │   ├── enemy_world_link.gd     # [Autoload: EnemyWorldLink] ← NUEVO (Spike 3, Grupo A): hueco genérico de limpieza para enemigos que huyen
│   │   └── enemy_ai.gd             # IA de enemigos — extends Node, sin dependencia de nodo padre (confirmado Grupo 5); antes colgaba de EnemyCombatNode (visual, retirado), ahora lo instancia combat_production_scene.gd directamente
│   │
│   ├── companions/                 # Sistema de companions y party
│   │   ├── party_manager.gd        # [Autoload: Party]
│   │   ├── party_event_handler.gd  # [Autoload: PartyEventHandler]
│   │   └── companion_ai.gd         # IA de companions
│   │
│   ├── dialogue/                   # Sistema de diálogo
│   │   ├── dialogue_system.gd      # [Autoload: Dialogue]
│   │   ├── dialogue_registry.gd    # [Autoload: DialogueDB]
│   │   ├── dialogue_definition.gd  # Resource: definición de diálogo
│   │   ├── dialogue_node_definition.gd
│   │   └── dialogue_option_definition.gd
│   │
│   ├── economy/                    # Sistema económico
│   │   ├── economy_system.gd       # [Autoload: Economy]
│   │   ├── price_calculator.gd     # Cálculo de precios dinámicos
│   │   ├── shop_definition.gd      # Resource: definición de tienda
│   │   ├── shop_instance.gd        # Estado de instancia de tienda
│   │   ├── shop_item_state.gd      # Estado de ítem en tienda
│   │   └── shop_view_state.gd      # Estado de la vista de tienda
│   │
│   ├── items/                      # Sistema de ítems
│   │   ├── item_registry.gd        # [Autoload: Items]
│   │   ├── inventory_system.gd     # [Autoload: Inventory]
│   │   ├── equipment_manager.gd    # [Autoload: Equipment]
│   │   ├── item_character_bridge.gd        # [Autoload: Bridge] Adaptador entre ítems y Character/Resources/Skills — Spike 10: _apply_learning() devuelve bool; skill fuera del kit → Skills.learn_skill() + valor inicial; el libro solo se consume si el aprendizaje se aplicó
│   │   ├── item_character_integration.gd   # Integración ítems-personaje
│   │   ├── item_definition.gd      # Resource: definición de ítem
│   │   ├── item_instance.gd        # Resource: instancia de ítem en juego
│   │   └── modifier_definition.gd  # Resource: definición de modificador
│   │
│   ├── narrative/                  # Sistema narrativo (hitos recordados — NO confundir con narrative_scenes/)
│   │   ├── narrative_system.gd     # [Autoload: Narrative]
│   │   ├── narrative_registry.gd   # [Autoload: NarrativeDB]
│   │   ├── narrative_event_definition.gd
│   │   ├── narrative_state.gd
│   │   ├── checkpoint_system.gd    # [Autoload: Checkpoints]
│   │   ├── checkpoint_registry.gd  # [Autoload: CheckpointDB]
│   │   ├── checkpoint_definition.gd
│   │   └── checkpoint_state.gd
│   │
│   ├── narrative_scenes/           # ← NUEVO (Spike 1): motor narrativo base del pivote hacia RPG narrativo
│   │   ├── narrative_scene_registry.gd     # [Autoload: NarrativeSceneDB] carga JSON → Resource, sin estado runtime
│   │   ├── narrative_scene_definition.gd   # Resource: escena (imagen, texto, opciones) — mejoras post-Spike 3, Grupo 4: validate() avisa (push_warning, no error) si image_path apunta a un fichero inexistente
│   │   ├── narrative_scene_option.gd       # Resource: opción (tirada opcional, referencias a outcomes por grado)
│   │   └── narrative_scene_outcome.gd      # Resource: destino/consecuencias — Spike 3/B: + combat_encounter (CombatEncounterDefinition opcional), combat_enemy_definitions (mapeo enemy_id→definition_id, necesario porque combate disparado desde narrativa no tiene Interactable del que leerlo), grant_item_id/quantity/target — **Spike 13:** + `combat_victory_scene_id` (escena a abrir al GANAR el combate del outcome) y `take_item_id`/`take_item_quantity`/`take_item_target` (quitar un ítem; desequipa antes)
│   │
│   ├── interactive_scenes/         # ← NUEVO (Spike 12): motor de escenas interactivas (mapa de puntos de interés). Naming genérico a propósito — el mismo primitivo sirve para "buscar algo en la imagen"
│   │   ├── interactive_scene_registry.gd     # [Autoload: InteractiveSceneDB] carga JSON → Resource, sin estado runtime, sin recursión
│   │   ├── interactive_scene_definition.gd   # Resource: scene_id, image_path, hotspots[]; validate() (hotspot_id duplicado = error) — **Spike 13:** + `on_first_visit_type`/`_target_id`/`_flag` y `has_first_visit()` (acción de una sola vez al entrar por primera vez; `validate()` rechaza tipo inválido, destino vacío o flag vacío)
│   │   └── interactive_hotspot_definition.gd # Resource: hotspot_id, map_position (normalizada 0–1), icon_path, label_key, interaction_type (dialogue/shop/combat/narrative_scene), target_id, enemy_ids_override, enemy_definitions, required_flags, blocked_flags — get_effective_target_id() une IDs de combate por comas
│   │
│   ├── adventures/                 # ← NUEVO (Spike 13): arranque de partida data-driven
│   │   └── adventure_starter.gd    # `class_name AdventureStarter` (RefCounted, solo `static func apply(adventure_id)`): lee `data/adventures/<id>.json`, une companions (`Party.join_party`) y da+equipa el kit (`Inventory.add_item` + `Equipment.equip_item`). Se llama UNA vez desde `CharacterCreationViewModel.request_confirm_character()`; NO es idempotente a propósito (`add_item` suma)
│   │
│   ├── resources/                  # Sistema de recursos vitales
│   │   ├── resource_system.gd      # [Autoload: Resources]
│   │   ├── resource_definition.gd  # Resource: definición (vida, stamina, oro...)
│   │   ├── resource_state.gd       # Estado en tiempo de ejecución
│   │   └── resource_bundle.gd      # Conjunto de recursos
│   │
│   ├── save/                       # Sistema de guardado
│   │   ├── save_system.gd          # [Autoload: SaveManager]
│   │   └── save_data.gd            # Resource: datos serializados de partida
│   │
│   ├── skills/                     # Sistema de habilidades
│   │   ├── skill_system.gd         # [Autoload: Skills] — Spike 10: + learn_skill(); load_save_state() recrea instancias aprendidas en runtime
│   │   ├── skill_progression_service.gd  # [Autoload: SkillProgression] — notify_skill_outcome() solo combate (ticks + roll al cerrar combate); execute_learning_session() es el camino fuera de combate (libros/entrenadores; candidato de enganche para progresión narrativa en Spike 2)
│   │   ├── skill_event_handler.gd  # [Autoload: SkillEventHandler]
│   │   ├── stress_system.gd        # [Autoload: Stress]
│   │   ├── skill_definition.gd     # Resource: definición de habilidad
│   │   ├── skill_instance.gd       # Estado de habilidad del personaje
│   │   └── learning_session.gd     # Sesión de aprendizaje de habilidad. source_level debe ser > 0 (is_valid() lo exige) — SourceType: TRAINER, BOOK, PRACTICE, NARRATIVE (desde Spike 2)
│   │
│   └── world_objects/              # Objetos interactuables del mundo
│       ├── world_object_system.gd  # [Autoload: WorldObjectSystem]
│       ├── world_object_registry.gd # [Autoload: WorldObjects]
│       ├── world_object_definition.gd
│       ├── world_object_state.gd
│       ├── world_object_bridge.gd
│       ├── interaction_definition.gd
│       ├── interaction_outcome.gd
│       ├── loot_table_definition.gd
│       └── loot_entry.gd
│
├── data/                           # Datos del juego (Resources .tres y JSON)
│   ├── characters/                 # Definiciones de personajes
│   │   ├── player_base.tres        # Plantilla de TEST/DEBUG — usada por combat_test_scene y exploration_test, NO para partidas reales
│   │   ├── player_new.tres         # ← Plantilla real para Character Creation (atributos placeholder, kit fijo de skills — Spike 3/B: kit leído directo de aquí, ya no de una constante duplicada en el ViewModel)
│   │   ├── enemy_base.tres
│   │   ├── wolf_test.tres
│   │   ├── telmori/                # Spike 3, Grupo B/C — personajes específicos de "Los Telmori"
│   │   │   ├── telmori_warrior_base.tres
│   │   │   ├── telmori_wolf_base.tres
│   │   │   ├── telmori_warrior_weak.tres   # ← NUEVO (Spike 3, Grupo C): Habitación Elevada — stats reducidos de la transcripción, único tipo usado como reinforcement_definition_id en telmori_lair_stealth (ver más abajo, no admite mezclar tipos en una misma oleada)
│   │   │   ├── telmori_wolf_weak.tres      # ← NUEVO (Spike 3, Grupo C): Habitación Elevada — solo se usa en el roster inicial de telmori_lair_alerted, no en refuerzo (misma razón)
│   │   │   └── icons/                      # ← NUEVO (mejoras post-Spike 3, Grupo 4): iconos de tipo (type_icon) de la aventura, PNG 128×128 con transparencia real — telmori_warrior_icon.png (warrior_base/weak), telmori_wolf_icon.png (wolf_base/weak)
│   │   ├── icons/                  # ← NUEVO (Grupo 4): iconos de tipo de enemigos genéricos, carpeta aparte de las de aventura — si el arte coincide se COPIA el fichero, nunca se apunta a la carpeta de una aventura desde un .tres genérico. Hoy: copia del icono de lobo para wolf_gray; enemy_base sin icono por decisión
│   │   ├── companions/
│   │   │   ├── companion_base.tres
│   │   │   └── companion_mira.tres # Spike 3/B: kit de skills ampliado (+ track/search); Spike 3/C: + skill.exploration.stealth
│   │   └── portrait/               # Retratos de personajes (PNG)
│   │       ├── guard.png
│   │       ├── merchant.png
│   │       ├── mira.png
│   │       ├── orco.png
│   │       ├── [otros portraits...]
│   │       └── telmori/            # ← NUEVO (Spike 11) — retratos de "Los Telmori", por aventura (portrait_folder): guard.png (neutral) + guard_<mood>.png (serious/happy/worried/angry)
│   │
│   ├── combat/                     # ← NUEVO (mejoras post-Spike 3, Grupo 4)
│   │   └── backgrounds/
│   │       └── telmori/            # Mapas de batalla cenitales (tinta y aguada sobre pergamino, sin cuadrícula), uno por encuentro, referenciados por combat_encounter.background_path: telmori_battle_forest (emboscada), telmori_battle_lair (guarida)
│   │
│   ├── adventures/                 # ← NUEVO (Spike 13): arranque de partida por aventura
│   │   └── telmori.json            # `schema_version` 1: `companions` (["companion_mira"]) + `starting_gear` por entidad (player y companion_mira: casco, armadura de cuero, botas, escudo y espada de hierro; un ejemplar de cada uno)
│   │
│   ├── dialogue/                   # Ficheros JSON de diálogos
│   │   ├── dialogue_prince_intro.json
│   │   ├── dlg_companion_mira_01.json
│   │   ├── dlg_maestro_01.json
│   │   ├── dlg_trainer_01.json
│   │   ├── [otros diálogos...]
│   │   ├── telmori/                # Diálogos de "Los Telmori" (Grupo 2, Spike 10) — DialogueRegistry escanea subcarpetas de forma recursiva desde Grupo 2
│   │   │   ├── [briefing del sheriff — Grupo 2, DLG_TELMORI_SHERIFF_BRIEFING] — **Spike 13:** es ahora el diálogo del hotspot del sheriff (hub con guardado, `triggers_save`): + opción `O_LEAVE` ("Salir"); `O4` (aceptar) con `blocked_flags: [flag.telmori_sheriff_briefed]`; `O1`–`O3` con `blocked_flags: [flag.telmori_adventure_completed]`
│   │   │   ├── dlg_telmori_sheriff_reward.json     # ← NUEVO (Spike 10) — DLG_TELMORI_SHERIFF_REWARD: hub de 2 ramas (trofeo, pueblo) + cierre; solo conversa, sin entregas
│   │   │   ├── dlg_telmori_sheriff_training.json   # ← NUEVO (Spike 10) — DLG_TELMORI_SHERIFF_TRAINING: hub de 2 ramas (pieles, libro) + cierre; solo conversa, sin entregas
│   │   │   └── dlg_telmori_tavern_keeper.json      # ← NUEVO (Spike 13) — DLG_TELMORI_TAVERN_KEEPER: esqueleto del posadero (rumores, sobre el sheriff, salir); retrato (`guard`), fondo (`sheriff_office`) y hablante (`innkeeper`) PROVISIONALES
│   │   └── backgrounds/            # ← NUEVO (Spike 11) — fondo de ambiente del DialoguePanel, pre-difuminado en la generación
│   │       ├── telmori.png         # Fondo genérico de la aventura (respaldo si no hay background_id o no existe el fichero de escena)
│   │       └── telmori/
│   │           └── sheriff_office.png  # Fondo de escena concreto (background_id = "sheriff_office")
│   │
│   ├── formulas/
│   │   └── derived_attributes.json # Fórmulas de atributos derivados
│   │
│   ├── items/                      # Definiciones de ítems (.tres y PNG)
│   │   ├── book_combat_basic.tres / .png
│   │   ├── health_potion.tres
│   │   ├── stamina_potion_small.tres
│   │   ├── lockpick_quality.tres
│   │   ├── steel_sword.tres / .png
│   │   ├── telmori/                # Spike 3, Grupo B — ítems específicos de una aventura
│   │   │   ├── silver_arrow.tres   # Sin ranura de equipo — va por aventura, no por tipo de arma
│   │   │   ├── telmori_magic_bag.tres     # ← NUEVO (Spike 3, Grupo D) — botín de la guarida, item_type MISC, sin mecánica
│   │   │   ├── obsidian_spearhead.tres    # ← NUEVO (Spike 3, Grupo D) — botín de la guarida, item_type MISC, sin mecánica
│   │   │   ├── wolf_tail_trophy.tres      # ← NUEVO (Spike 3, Grupo D) — trofeo de la recompensa del sheriff, item_type MISC
│   │   │   └── book_tanning_basics.tres   # ← NUEVO (Spike 3, Grupo D) — libro de aprendizaje (learning_data → skill.exploration.tanning), sigue el patrón de book_combat_basic.tres — pero su localización va en items.csv general, no en items_telmori.csv (ver localization/ abajo)
│   │   └── weapons/                # Por slot: weapon, body, head, feet, shield, accesory
│   │       ├── weapon/
│   │       │   ├── iron_sword.tres / .png
│   │       │   ├── shortbow.tres
│   │       │   └── enchanted_spear.tres   # Spike 3, Grupo B — ítem de ranura manda sobre aventura
│   │       ├── body/
│   │       │   └── leather_armor.tres / .png
│   │       ├── head/
│   │       │   └── iron_helmet.tres / .png
│   │       ├── feet/
│   │       │   └── leather_boots.tres / .png
│   │       ├── shield/
│   │       │   └── wooden_shield.tres / .png
│   │       └── accesory/
│   │           ├── amulet_strength.tres / .png
│   │           ├── ring_health.tres / .png
│   │           └── ring_stamina.tres / .png
│   │
│   ├── narrative/
│   │   ├── checkpoints.json
│   │   └── narrative_events.json
│   │
│   ├── interactive_scenes/         # ← NUEVO (Spike 12): un JSON por localización interactiva
│   │   ├── poi_test_map.json       # mapa de PRUEBA (6 hotspots: dialogue, shop, narrative_scene, combat con enemy_definitions, uno con required_flags y otro con blocked_flags) — Spike 13 añade el del pueblo
│   │   ├── telmori_village.json    # ← NUEVO (Spike 13) — el pueblo real: `on_first_visit` (llegada, `flag.telmori_village_visited`) + 11 hotspots en 4 posiciones (sheriff ×3, herrería, taberna, salida ×6), mutuamente excluyentes por flags según la etapa de la aventura
│   │   ├── images/
│   │   │   └── mapa_aldea_telmori.jpg   # ← NUEVO (Spike 13) — fondo del pueblo, 1376×768, tinta y aguada sobre pergamino
│   │   └── icons/telmori/               # ← NUEVO (Spike 13) — medallones PNG con transparencia: icon_sheriff / icon_blacksmith / icon_tavern / icon_exit (el de sheriff sirve a sus 3 hotspots; el de salida, a los 6). Ruta según lo acordado — verificar
│   │
│   ├── narrative_scenes/           # Un JSON por escena narrativa de contenido real
│   │   # Spike 3, Grupo B — primer contenido real: 11 escenas de "Los Telmori"
│   │   # (village_arrival, sheriff_briefing, equipment_arrows, equipment_spear,
│   │   # hills_search_day1 + 3 intermedias por grado — nothing/tracks/mauled_sheep,
│   │   # day2_approach, post_ambush_tracking, guarida_door). Ver
│   │   # docs/spike_3_grupoB_pueblo_guarida_informe_cierre.md para el detalle completo.
│   │   # Spike 3, Grupo C — 4 escenas más: telmori_lair_approach (sigilo de
│   │   # grupo), telmori_lair_alerted / telmori_lair_stealth (las dos
│   │   # versiones de la guarida, fusionando las dos salas de la aventura
│   │   # original en un combate por rama), telmori_lair_victory (cierre,
│   │   # flag.telmori_lair_cleared para Grupo D). Ver
│   │   # docs/spike_3_grupoC_guarida_informe_cierre.md para el detalle completo.
│   │   # Spike 3, Grupo D — 6 escenas de cierre: telmori_lair_loot_obsidian
│   │   # (botín mágico, encadenada tras telmori_lair_victory — bolsa +
│   │   # punta de obsidiana, ahí se marca flag.telmori_lair_cleared de
│   │   # verdad, no en telmori_lair_victory), telmori_sheriff_reward_intro
│   │   # (bounty + trofeo), telmori_sheriff_training (tomo de Curtidor),
│   │   # telmori_sheriff_pelts (venta de pieles, tirada real contra
│   │   # skill.exploration.tanning), telmori_epilogue_hook (gancho del
│   │   # hombre-lobo, flavor puro, flag.telmori_adventure_completed). Ver
│   │   # docs/spike_3_grupoD_cierre_informe_cierre.md para el detalle completo.
│   │   # (Los JSON de prueba de Spike 1, más los de Spike 2, se eliminaron en Spike 3, Grupo A.)
│   │   # Mejoras post-Spike 3, Grupo 4 — las 21 escenas tienen image_path real
│   │   # (4 fondos: pueblo, camino, entrada de la guarida, interior). Ojo:
│   │   # telmori_lair_loot_obsidian está como .json.json en el proyecto —
│   │   # carga igual, pendiente de renombrar.
│   │   # Spike 10 — telmori_sheriff_reward_intro y telmori_sheriff_training abren
│   │   # un diálogo (dialogue_id → DLG_TELMORI_SHERIFF_REWARD / _TRAINING) con las
│   │   # entregas (oro, trofeo, tomo) en ese mismo outcome, y siguen encadenando a
│   │   # training / pelts al cerrarse el diálogo. telmori_sheriff_pelts (tirada de
│   │   # Curtido, no convertible a diálogo) y telmori_epilogue_hook no cambian.
│   │   # Spike 13 — el pueblo pasa a hub (motor de escenas interactivas). NUEVAS:
│   │   # telmori_exit_locked_briefing / telmori_exit_locked_reward (avisos de salida
│   │   # bloqueada: un nodo, una opción que cierra) y telmori_village_departure
│   │   # (MARCADOR de la salida final). EDITADAS: telmori_village_arrival
│   │   # (next_scene_id vacío: termina en el mapa), telmori_day2_approach
│   │   # (combat_victory_scene_id → telmori_post_ambush_tracking; sin flag de disparo),
│   │   # telmori_post_ambush_tracking (el fallo marca flag.telmori_ambush_won),
│   │   # telmori_lair_alerted / _stealth (combat_victory_scene_id → telmori_lair_victory;
│   │   # sin flag de disparo), telmori_sheriff_reward_intro (take_item: devuelve
│   │   # enchanted_spear). SIN USO desde Spike 13: la escena envoltorio
│   │   # telmori_sheriff_briefing (el sheriff abre el diálogo directamente) y
│   │   # telmori_equipment_arrows / _spear (las compra el jugador en la herrería).
│   │   └── images/
│   │       └── telmori/            # ← NUEVO (Grupo 4): fondos de escena 16:9, catálogo reutilizable por TIPO de escenario, no por escena (telmori_bg_village.jpg y demás)
│   │
│   ├── resources/                  # Definiciones de recursos
│   │   ├── gold.tres
│   │   ├── health.tres
│   │   └── stamina.tres
│   │
│   ├── shops/                      # Definiciones de tiendas
│   │   ├── blacksmith_01.tres
│   │   └── blacksmith_telmori.tres   # ← NUEVO (Spike 13) — tienda propia de la aventura: stock de blacksmith_01 + `enchanted_spear` (valor 0, `quest_loan`: sale gratis) y 20 `silver_arrow` (2 de oro c/u); `max_slots` 16 (con 12 no cabían las dos armas nuevas)
│   │
│   ├── skills/                     # Habilidades por categoría
│   │   ├── combat/
│   │   │   ├── melee/
│   │   │   │   ├── attack_light.tres
│   │   │   │   ├── attack_heavy.tres
│   │   │   │   ├── attack_power_strike.tres
│   │   │   │   ├── attack_bleeding_strike.tres
│   │   │   │   ├── attack_reckless_strike.tres
│   │   │   │   ├── attack_stunning_blow.tres
│   │   │   │   ├── attack_sweep.tres
│   │   │   │   ├── dodge.tres
│   │   │   │   ├── throw_rock.tres
│   │   │   │   └── attack_ranged.tres
│   │   │   └── ranged/
│   │   │       └── fireball.tres
│   │   ├── enemy/
│   │   │   └── enemy_basic_attack.tres
│   │   └── exploration/
│   │       ├── brute_force.tres
│   │       ├── dash.tres
│   │       ├── lockpick.tres
│   │       ├── perception.tres
│   │       ├── search.tres         # Spike 3, Grupo B — skill.exploration.search (Buscar)
│   │       ├── sprint.tres
│   │       ├── stealth.tres        # ← NUEVO (Spike 3, Grupo C) — skill.exploration.stealth (Deslizarse en Silencio), calcada de track.tres
│   │       ├── tanning.tres        # ← NUEVO (Spike 3, Grupo D) — skill.exploration.tanning (Curtido), base_success_rate bajo (15), sin skill de "craft" en ningún kit inicial (probabilidad casi nula sin gating de visibilidad nuevo)
│   │       └── track.tres          # Spike 3, Grupo B — skill.exploration.track (Rastrear)
│   │
│   └── world_objects/              # Definiciones de objetos y loot tables
│       ├── chest_01.tres
│       ├── loot_bag_01.tres
│       ├── loot_chest_iron_broken.tres
│       ├── loot_chest_iron_normal.tres
│       ├── loot_chest_iron_rich.tres
│       └── loot_enemy_base_drops.tres
│
├── debug/                          # Herramientas de debug (no activas en producción)
│
├── docs/                           # Documentación del proyecto
│   ├── athelia_ui_architecture.md  # Arquitectura MVVM de UI
│   ├── characters.md
│   ├── referencia_buff_types.md    # Documentación de tipos de buff
│   ├── referencia_skill_definition.md  # Estructura de SkillDefinition
│   ├── spike_buffs_debuffs.md      # Spike de sistema de buffs/debuffs
│   ├── spike_skill_tree_screen.md  # Spike de pantalla de skill tree
│   ├── spike_companions_fase1.docx
│   ├── spike_companions_fase2_*.md
│   ├── SPIKE_ITEM_SYSTEM.md
│   ├── spike_player_ui_informe_cierre.md
│   ├── spike_main_menu_informe_cierre.md
│   ├── spike_character_creation_informe_cierre.md
│   ├── spike_1_motor_narrativo_informe_cierre.md  # pivote hacia RPG narrativo, motor base
│   ├── spike_2_reglas_runequest_informe_cierre.md  # reglas de RuneQuest sobre el motor narrativo (seis puntos), moral/refuerzos en combate
│   ├── spike_3_grupoA_motor_limpieza_informe_cierre.md  # moral dinámica, EnemyWorldLink, retirada de andamiaje Spike 1
│   ├── spike_3_grupoB_pueblo_guarida_informe_cierre.md  # primer contenido real, "Los Telmori" hasta la puerta de la guarida
│   ├── spike_3_grupoC_guarida_informe_cierre.md  # la guarida jugable de principio a fin, fusión de las dos salas, reconexión narrativa tras combate generalizada
│   ├── spike_3_grupoD_cierre_informe_cierre.md  # cierre completo — recompensa multicapa, botín mágico, otorgar recurso, "Los Telmori" jugable de principio a fin
│   ├── mejoras_grupo2_dialogo_narrativa_informe_cierre.md
│   ├── mejoras_grupo3_overlays_narrativa_informe_cierre.md
│   ├── mejoras_grupo5_combate_produccion_informe_cierre.md  # ← NUEVO: pantalla de combate de producción completa — UIRadialGauge/UICombatToken, CombatArenaViewModel/Panel, combat_production_scene.gd, integración real en SceneOrchestrator, jugado de principio a fin en "Los Telmori"
│   └── spike_13_reautoria_pueblo_telmori.md  # ← NUEVO (Spike 13): el pueblo de Los Telmori sobre el motor de escenas interactivas — resultado, plan frente a lo hecho, validación
│
├── localization/                   # Sistema de localización (ES/EN)
│   ├── translations.csv            # Textos generales
│   ├── translations.en.translation
│   ├── translations.es.translation
│   ├── dialogues.csv               # Textos de diálogos
│   ├── dialogues.en.translation
│   ├── dialogues.es.translation
│   ├── dialogues_scenes_telmori.csv    # Grupo 2 (briefing del sheriff) + Spike 10 (+12 claves: los dos diálogos de recompensa y entrenamiento) — CSV propio por aventura — **Spike 13:** +7 claves (`DLG_SHERIFF_OPT_LEAVE` y las 6 del posadero `DLG_TAVERN_*`); modificadas `DLG_SHERIFF_04_WEAPONS` (ahora remite a la herrería) y `DLG_SHERIFF_REWARD_01_GREET` (frase de devolución de la lanza)
│   ├── dialogues_scenes_telmori.en.translation
│   ├── dialogues_scenes_telmori.es.translation
│   ├── items.csv                   # Nombres y descripciones de ítems — Spike 3, Grupo D añade ITEM_BOOK_TANNING_NAME/DESC (libro sin ranura, en el CSV general, no en items_telmori.csv — misma práctica que silver_arrow/enchanted_spear de Grupo B). Spike 10 añade ITEM_SILVER_ARROW_NAME/DESC e ITEM_ENCHANTED_SPEAR_NAME/DESC, que faltaban desde Grupo B
│   ├── items.en.translation
│   ├── items.es.translation
│   ├── world_objects.csv           # Textos de objetos del mundo
│   ├── world_objects.en.translation
│   ├── world_objects.es.translation
│   ├── menus.csv                   # Textos de menús (menú principal, opciones, créditos)
│   ├── menus.en.translation
│   ├── menus.es.translation
│   ├── character_creation.csv      # Textos de creación de personaje
│   ├── character_creation.en.translation
│   ├── character_creation.es.translation
│   ├── narrative_scenes.csv        # Textos de escenas narrativas (solo cabecera hasta Spike 3/B — claves de test de Spike 1/2 retiradas en Grupo A)
│   ├── narrative_scenes.en.translation
│   ├── narrative_scenes.es.translation
│   ├── narrative_scenes_telmori.csv    # Spike 3, Grupo B (22 claves) + Grupo C (7 más, 29 en total) + Grupo D (6 escenas + prompt del interactuable del sheriff) + Spike 10 (+11 claves: textos de reward_intro/training/pelts/epílogo, el prompt `UI_TELMORI_SHERIFF_REWARD_INTERACT` y la escena `telmori_lair_loot_obsidian`, que Grupo D daba por localizados pero no lo estaban) — CSV propio por aventura — **Spike 13:** +10 claves (4 etiquetas `TELMORI_HOTSPOT_*`, las 2 escenas de aviso de salida bloqueada y la de salida final provisional, cada una con su `_OPTION_CLOSE`); modificada `TELMORI_VILLAGE_ARRIVAL_OPTION_CONTINUE` ("Entrar en la aldea"). Las 2 de tienda (`SHOP_TELMORI_BLACKSMITH_NAME/DESC`) van junto a `SHOP_BLACKSMITH_NAME`
│   ├── narrative_scenes_telmori.en.translation
│   ├── narrative_scenes_telmori.es.translation
│   ├── characters_telmori.csv          # Spike 3, Grupo B — nombre/desc de telmori_warrior/wolf
│   ├── characters_telmori.en.translation
│   ├── characters_telmori.es.translation
│   ├── items_telmori.csv               # ← NUEVO (Spike 3, Grupo D) — nombre/desc de telmori_magic_bag, obsidian_spearhead, wolf_tail_trophy (botín/trofeo, sin ranura). Requiere alta manual en Project Settings → Localization → Translations, igual que narrative_scenes_telmori.csv en su momento. Spike 10: el alta NO se había hecho — hasta entonces los tres ítems mostraban la clave cruda; además dos descripciones con comas iban sin entrecomillar (fila con columnas de más)
│   ├── items_telmori.en.translation
│   ├── items_telmori.es.translation
│   ├── combat.csv                      # ← NUEVO (Grupo 5) — 13 claves del log de combate: ATTACK graduado por SkillRoller (5 claves: FUMBLE/FAILURE/SUCCESS/SPECIAL/CRITICAL), DODGE/DEFEND(x2)/FLEE(x3)/STAGGERED/DISARMED sin grado. Requiere alta manual en Project Settings → Localization → Translations
│   ├── combat.en.translation
│   └── combat.es.translation
│
├── scenes/                         # Escenas del juego
│   ├── combat/
│   │   ├── combat_production_scene.gd   # ← NUEVO (Grupo 5): pieza de PRODUCCIÓN real — sustituye a combat_test_scene.gd como SceneOrchestrator.SCENE_COMBAT. Sin UI: solo instancia PlayerCombatController + EnemyAI/CompanionAI (roster inicial y refuerzos vía reinforcement_spawned) y registra Skills para enemigos (NarrativeSceneViewModel/ExplorationController pre-registran Characters/Resources pero nunca Skills). Se auto-libera en combat_ended (SceneOrchestrator no guarda referencia a SCENE_COMBAT ni la libera — fuga preexistente, no arreglada ahí)
│   │   ├── combat_production_scene.tscn # Un único nodo, sin hijos, sin UI
│   │   ├── combat_test.tscn        # Escena de TEST de combate — ya NO es la de producción desde Grupo 5, sigue existiendo tal cual (propia UI de barras ProgressBar) para depurar sin la maquinaria nueva encima
│   │   ├── combat_test_scene.gd
│   │   ├── enemy_combat_node.gd    # Nodo visual 2D de enemigo (sprite + AnimationController) — YA NO se usa en producción desde Grupo 5 (UICombatToken cubre su único rol funcional real); sigue vivo para combat_test.tscn
│   │   └── enemy_combat_node.tscn
│   │
│   ├── companions/
│   │   ├── companion_base.tscn
│   │   └── companion_mira.tscn
│   │
│   ├── exploration/                 # scripts COMPARTIDOS entre todas las zonas de exploración
│   │   ├── exploration_test.tscn    # sandbox de desarrollo — nodo raíz debe llamarse "ExplorationScene" para que SceneOrchestrator._handle_exploration() lo reconozca al ejecutarlo suelto (F6); si no, intenta instanciar otra copia de la escena de producción encima y crashea ("Parent node is busy setting up children") — **Spike 13: DESCARTADA** (no es escena de producción); candidata a borrar
│   │   ├── exploration_test.gd
│   │   ├── exploration_controller.gd  # Input de exploración (interact, inventory, party, player_menu, F9 quickload) — tecla F1 de debug de Spike 1 retirada en Spike 3, Grupo A; Spike 3/B: _on_interaction_requested() gana el caso "narrative_scene" (ver Interactable abajo); mejoras post-Spike 3, Grupo 1: F5 (quicksave) retirado por completo, sustituido por tecla de debug F2 configurable por fichero (user://debug_shortcut.json) — **Spike 12: `request_interaction(type, target_id, enemy_definitions := {})` es el ÚNICO punto de routing de interacciones; `_on_interaction_requested()` (camino de `Interactable`) delega en él con las definiciones del nodo**
│   │   ├── exploration_hud.gd
│   │   ├── player_exploration.gd
│   │   ├── companion_follow_node.gd
│   │   ├── interactable.gd            # interaction_type: "dialogue"/"shop"/"combat"/"item"/"narrative_scene" (el último, Spike 3/B — antes solo existía como tecla de debug temporal en Spike 1, ya retirada)
│   │   │
│   │   ├── tutorial/                # zona de producción original (mini-tutorial) — OBSOLETA desde Spike 3/B, pendiente de retirar
│   │   │   ├── exploration_tutorial.tscn
│   │   │   └── exploration_tutorial.gd
│   │   │
│   │   ├── telmori_village/         # ← NUEVO (Spike 3, Grupo B): primera zona de producción real — **Spike 12: ya no es `SCENE_EXPLORATION` (línea comentada, revertible); se retira o migra en Spike 13** — **Spike 13: OBSOLETA**, sustituida por `data/interactive_scenes/telmori_village.json`; candidata a retirada (ver pendientes, punto 10)
│   │   │   ├── exploration_telmori_village.tscn
│   │   │   └── exploration_telmori_village.gd
│   │   │
│   │   └── interactive_map/         # ← NUEVO (Spike 12): escena raíz de exploración basada en un mapa de puntos de interés (sin Player, sin Camera2D)
│   │       ├── exploration_interactive_map.tscn  # ExplorationController + ExplorationHUD + MapLayer (CanvasLayer -1) con InteractiveSceneView; raíz libre (SceneOrchestrator fuerza name = "ExplorationScene")
│   │       └── exploration_interactive_map.gd    # composición pura: crea el ViewModel, lo enlaza y reenvía hotspot_activated → request_interaction(); @export interactive_scene_id (**Spike 13: la escena carga `"telmori_village"`**; `poi_test_map` queda para pruebas cambiando el id); en `_ready()` llama a `_view_model.call_deferred("request_first_visit")`
│   │
│   ├── player/                      # ⚠️ player.gd/player.tscn: código muerto, limpieza APARCADA
│   │   ├── player.gd                #    (bloqueada por test/test_shop_ui.gd, que aún los referencia)
│   │   ├── player.tscn
│   │   ├── player_combat_controller.gd  # Único dueño real del targeting (auto-target en _on_combat_started(), ciclado con Tab) y del despacho completo de player_action_requested (request_skill()). Spike 8: + add_to_group("player_combat_controller") en _ready(), para que combat_arena_panel.gd pueda localizarlo sin acoplarse a una ruta de nodo fija — antes los botones de UI construían su propio action_data incompleto (sin "target"), en vez de llamar a request_skill()
│   │   ├── player_ui.gd
│   │   ├── player_ui.tscn
│   │   ├── save_feedback_ui.gd
│   │   └── save_feedback_ui.tscn
│   │
│   └── test/                       # Escenas de prueba
│       └── test.tscn
│
├── test/                           # Tests unitarios e integración
│   ├── test_character_creation_viewmodel.gd  # 30 asserts, ViewModel aislado
│   ├── test_narrative_scene_viewmodel.gd     # 23 asserts — fixtures en código (sin JSON ni NarrativeSceneDB), outcome_default, fallback de get_outcome_for_grade(), contador de racha
│   ├── test_group_morale.gd                  # 11 asserts — reproduce los dos ejemplos numéricos de la base de moral dinámica, manipulando estado interno de GameLoop directamente
│   ├── test_character_persistence.gd         # Roundtrip save/load de CharacterSystem
│   ├── test_narrative_system.gd              # Sistema de EVENTOS narrativos (NarrativeSystem/NarrativeDB) — NO el motor de escenas narrativas de Grupo B, fácil de confundir por el nombre
│   └── [otros test_*.gd por sistema]
│
└── ui/                             # Componentes de interfaz de usuario
    ├── damage_number.gd
    ├── damage_number.tscn
    ├── entity_animation_controller.gd
    │
    ├── combat/                     # UI de combate
    │   ├── combat_hub_viewmodel.gd     # Menú de 8 acciones del jugador (3 ataque configurables + 3 defensivas fijas + 2 ítems) — sin cambios de contrato, Grupo 5 lo compone como action_menu dentro de CombatArenaViewModel
    │   ├── combat_hud.gd               # YA NO es la pantalla de producción desde Grupo 5 (ver combat_arena_panel.gd) — sigue vivo solo para combat_test.tscn
    │   ├── combat_hud.tscn
    │   ├── combat_arena_viewmodel.gd   # ← NUEVO (Grupo 5): ViewModel de la arena — fichas de party/enemigos (dinámicas: companions/refuerzos a mitad de combate) + log narrado. Compone a combat_hub_viewmodel.gd como action_menu, sin tocarlo. Se conecta a Resources.resource_changed directamente (la señal de ResourceSystem, NO EventBus.resource_changed — ver hallazgo de motor abajo). Grupo 4: + background_texture / razón "background" (lee GameLoop.get_current_encounter() con call_deferred); fill_color resuelto también para enemigos (antes Color.WHITE por defecto) y centinela Color.BLACK de token_color respetado. Spike 8: _initials_for()/_display_name() solo leían CharacterState.character_name (vacío para toda entidad no-jugador) — arreglado con fallback a tr(CharacterDefinition.name_key), cierra a la vez el "??" de fichas y los IDs sin localizar en el log (misma causa). _on_combat_started() sincroniza is_targeted leyendo PlayerCombatController.get_current_target() directamente al construir las fichas, en vez de depender del orden de conexión a combat_started entre nodos distintos (el auto-target de PlayerCombatController se perdía si su señal target_changed llegaba antes de que las fichas existieran)
    │   ├── combat_token_data.gd        # ← NUEVO (Grupo 5): data class — snapshot de una ficha (entity_id, is_party, HP/EN actual+máximo, turno, objetivo, color/icono)
    │   ├── log_entry_data.gd           # ← NUEVO (Grupo 5): data class — una línea del log (text_key + format_args + grade)
    │   ├── combat_arena_panel.gd       # ← NUEVO (Grupo 5): View de producción, sustituye a combat_hud.tscn como SceneOrchestrator.OVERLAY_COMBAT_HUD. Fichas dinámicas en PartyColumn(VBoxContainer)/EnemyColumn(GridContainer 2 columnas — VBoxContainer no cabía con 6 enemigos reales), log con autoscroll, menú de 8 UIButton fijos, fondo opaco (tapa la escena de exploración, que sigue viva debajo por diseño de SceneOrchestrator). Grupo 4: BackgroundImage (TextureRect) debajo de Background (ColorRect, ahora %), que pasa a ser velo con alfa UITokens.COMBAT_BACKGROUND_SCRIM_ALPHA si el encuentro trae imagen, opaco si no; color desde UITokens.COLOR_PANEL (ya no fijo en el .tscn); contorno en las líneas del log. Spike 8, Punto 4: EnemyColumn sin límite de altura se desbordaba por arriba con 6-8 fichas — cada ficha enemiga se instancia ahora dentro de un Control envoltorio (_enemy_slots[entity_id]) que es lo único que _rescale_enemy_tokens() redimensiona; UICombatToken en sí nunca cambia de tamaño real, solo se escala visualmente (.scale) — ver antipatrón nuevo en athelia_ui_architecture.md. Spike 8, Punto 5: _on_slot_action_pressed() ya no construye su propio action_data (nunca incluía "target") — delega en PlayerCombatController.request_skill() vía get_tree().get_first_node_in_group("player_combat_controller")
    │   ├── combat_arena_panel.tscn
    │   └── damage_number.tscn
    │
    ├── character_creation/         # Creación de personaje (patrón MVVM)
    │   ├── character_creation_viewmodel.gd  # Spike 3/B: kit inicial de skills leído de player_new.tres, ya no de una constante duplicada (STARTING_SKILL_VALUES, eliminada) — **Spike 13:** llama a `AdventureStarter.apply(DEFAULT_ADVENTURE_ID)` tras `_create_player_entity()` (companions y kit salen a `data/adventures/`); `STARTING_ITEMS` vaciado
    │   ├── character_creation_screen.gd
    │   └── character_creation_screen.tscn
    │
    ├── design_system/              # Sistema de diseño centralizado
    │   ├── components/
    │   │   ├── ui_button/
    │   │   │   ├── ui_button.gd   # Spike 13: + `min_square` (botón cuadrado de solo icono) e `icon_backdrop` (disco oscuro semitransparente tras el icono) — ambos opt-in, apagados por defecto
    │   │   │   └── ui_button.tscn
    │   │   ├── ui_panel/           # Spike 9: + decorative_frame / corner_texture (marco ornamental opt-in, _draw() sobre el propio panel; con el marco activo anula borde y corner_radius del stylebox)
    │   │   │   ├── ui_panel.gd
    │   │   │   └── ui_panel.tscn
    │   │   ├── ui_slot/
    │   │   │   ├── ui_slot.gd
    │   │   │   └── ui_slot.tscn
    │   │   ├── ui_resource_bar/
    │   │   │   ├── ui_resource_bar.gd
    │   │   │   └── ui_resource_bar.tscn
    │   │   ├── ui_radial_gauge/    # ← NUEVO (Grupo 5): anillo de progreso radial parametrizable (progress/ring_color/track_color/thickness), sin precedente previo de _draw()/arcos en el Design System (todo lo demás usa StyleBoxFlat). Un único anillo por instancia — una ficha de party lo instancia dos veces (PV+EN), una de enemigo una vez (solo PV)
    │   │   │   ├── ui_radial_gauge.gd
    │   │   │   └── ui_radial_gauge.tscn
    │   │   └── ui_combat_token/    # ← NUEVO (Grupo 5): ficha de combate (party o enemigo), compone dos UIRadialGauge + relleno central (iniciales o icono de tipo) + triángulo de turno + retícula de objetivo. 3 scripts helper internos sin class_name (no reutilizables fuera de este componente): ui_combat_token_center_fill.gd, ui_combat_token_turn_triangle.gd, ui_combat_token_target_reticle.gd. Grupo 4: _apply_text_outline() en _ready() — contorno (UITokens.TEXT_OUTLINE_SIZE / COLOR_TEXT_OUTLINE) en iniciales y cifras de PV/EN. Spike 8: + const BASE_SIZE (96×144) — su tamaño de diseño, del que combat_arena_panel.gd deriva el factor de escala en vez de duplicar el número; todo su anclaje interno usa desplazamientos en píxeles fijos calculados para ESE tamaño exacto (ver antipatrón nuevo en athelia_ui_architecture.md), por lo que el propio nodo nunca debe redimensionarse directamente
    │   │       ├── ui_combat_token.gd
    │   │       ├── ui_combat_token_center_fill.gd
    │   │       ├── ui_combat_token_turn_triangle.gd
    │   │       ├── ui_combat_token_target_reticle.gd
    │   │       └── ui_combat_token.tscn
    │   ├── assets/
    │   │   └── frames/             # ← NUEVO (Spike 9)
    │   │       ├── frame_corner_64x64.png   # en uso: esquinera única, se rota en las 4 esquinas
    │   │       └── frame_corner_96x96.png   # reserva; invadía el texto del panel narrativo
    │   ├── theme/
    │   │   └── main_theme.tres     # Tema global de UI
    │   └── tokens/
    │       └── ui_tokens.gd        # [Autoload: UITokens] Tokens de diseño — Grupo 5: + COLOR_GAUGE_HP_PARTY/EN_PARTY/HP_ENEMY, COLOR_TURN_INDICATOR, COLOR_TOKEN_FILL_DEFAULT, COLOR_LOG_FUMBLE/FAILURE/CRITICAL (SPECIAL reutiliza COLOR_TURN_INDICATOR, SUCCESS reutiliza el font_color normal del tema). Spike 9: + COLOR_FRAME_OUTER/FILLET/INNER, FRAME_OUTER_WIDTH/FILLET_WIDTH/INNER_WIDTH/GAP (marco decorativo de UIPanel)
    │
    ├── dialogue/                   # Panel de diálogo (patrón MVVM)
    │   ├── dialogue_viewmodel.gd
    │   ├── dialogue_panel.gd
    │   ├── dialogue_panel.tscn
    │   ├── dialogue_panel_test.gd
    │   ├── dialogue_panel_test.tscn
    │   └── option_button.tscn
    │
    ├── gameover/                   # Pantalla de Game Over
    │   ├── game_over_ui.gd         # Spike 3/B: _on_new_game_pressed() reinicia vía enter_main_menu()+enter_character_creation() (antes saltaba a exploration_test.tscn sin re-registrar al jugador)
    │   └── game_over_ui.tscn
    │
    ├── inventory/                  # Pantalla de inventario (patrón MVVM)
    │   ├── inventory_viewmodel.gd
    │   ├── inventory_screen.gd
    │   ├── inventory_ui.gd
    │   ├── inventory_ui.tscn
    │   ├── item_slot.gd
    │   ├── item_slot.tscn
    │   ├── equip_slot.gd
    │   ├── equip_slot.tscn
    │   ├── item_detail_panel.gd
    │   ├── item_detail_panel.tscn
    │   ├── feedback_popup.gd
    │   └── feedback_popup.tscn
    │
    ├── loadout/                    # Pantalla de loadout (patrón MVVM)
    │   ├── loadout_viewmodel.gd     # Spike 8: SlotData.display_name se fijaba ya traducido (tr(def.name_key)) en _refresh_slots(), a diferencia de SkillSlotData/ConsumableSlotData en el mismo fichero (clave sin traducir, "se traduce en la View") — loadout_screen.gd hacía tr() una segunda vez sobre el resultado. Sin efecto visible (tr() sobre un string no-clave devuelve el string tal cual) pero es un doble-tr() real; arreglado para seguir el mismo patrón que las otras dos data class
    │   ├── loadout_screen.gd        # Selección en dos pasos (clic en slot → clic en skill/ítem de la lista) sin ninguna pista visual de que hace falta el primer clic — confundió la validación de Spike 8 hasta confirmarlo en juego. Candidato a mejora de UX menor, aparcado
    │   └── loadout_screen.tscn
    │
    ├── loading_screen/             # Pantalla de carga
    │   ├── loading_screen.gd
    │   └── loading_screen.tscn
    │
    ├── main_menu/                  # Menú principal (patrón MVVM)
    │   ├── main_menu_viewmodel.gd
    │   ├── main_menu_screen.gd
    │   └── main_menu_screen.tscn   # ← Main Scene del proyecto
    │
    ├── narrative_scene/             # Escena narrativa (patrón MVVM)
    │   ├── narrative_scene_viewmodel.gd  # enum PanelState (no SceneState) — Spike 3/B: _apply_outcome() resuelve grant_item_*/combat_encounter, registra enemigos antes de start_combat() — Spike 10: orden real flag → ítem → recurso → dialogue_id (retorno temprano) → combate → next_scene_id; bloque grant_item_* RESTAURADO (se había perdido) con log de cada entrega
    │   ├── narrative_scene_panel.gd      # Spike 3/B: consume "streak_progress" (hueco abierto desde Spike 2); UIPanel anclado a tamaño fijo (bug de autowrap sin ancho)
    │   └── narrative_scene_panel.tscn    # Grupo 4: layout B1 — SceneImage a pantalla completa detrás, UIPanel anclado al tercio inferior (anclas relativas, grow_vertical = BEGIN), texto y opciones en HBoxContainer. Cero cambios en el script. Spike 9: nodo Root/UIPanel con decorative_frame = true y corner_texture = frame_corner_64x64.png (solo inspector, sin script)
    │
    ├── interactive_scene/           # ← NUEVO (Spike 12): vista PERMANENTE dentro de la escena de exploración (no es overlay)
    │   ├── interactive_scene_viewmodel.gd  # changed(reason: scene_loaded/hotspots_refreshed) + hotspot_activated(type, target_id, enemy_definitions); filtra hotspots por flags; guard GameState == EXPLORATION — **Spike 13:** + `request_first_visit()` (acción de `on_first_visit`; solo en EXPLORATION, marca el flag antes de actuar, reutiliza `hotspot_activated`)
    │   └── interactive_scene_view.gd       # vista pasiva: Fallback + Background + un `UIButton` por hotspot visible (**Spike 13:** con `icon_path` válido, solo icono — `GHOST` + `min_square` + `icon_backdrop`, nombre en tooltip —; sin él, botón de texto `SECONDARY`), posiciones normalizadas sobre el rectángulo real de la imagen
    │
    ├── party/                      # Pantalla de party (patrón MVVM)
    │   ├── party_viewmodel.gd
    │   ├── party_ui.gd
    │   └── party_ui.tscn
    │
    ├── player_menu/                # Menú del jugador (patrón MVVM)
    │   ├── player_menu_viewmodel.gd
    │   ├── player_menu_screen.gd
    │   └── player_menu_screen.tscn
    │
    ├── shop/                       # Tienda (patrón MVVM)
    │   ├── shop_viewmodel.gd
    │   ├── shop_ui.gd
    │   ├── shop_ui.tscn
    │   ├── shop_item_slot.gd
    │   └── shop_item_slot.tscn
    │
    ├── skill_tree/                 # Pantalla de skill tree (patrón MVVM)
    │   ├── skill_tree_viewmodel.gd
    │   ├── skill_tree_screen.gd
    │   └── skill_tree_screen.tscn
    │
    └── world_objects/              # Panel de interacción con objetos (patrón MVVM)
        ├── world_object_panel_viewmodel.gd
        ├── world_object_interaction_panel.gd
        └── world_object_interaction_panel.tscn
```

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

### Exploration Tutorial — Arquitectura (OBSOLETA desde Spike 3, Grupo B)

> **Spike 13: DESCARTADA** por Fernando (no era escena de producción). Pendiente de borrar junto a `exploration_test` (ver pendientes, punto 10).

```
ExplorationTutorial (Node2D)              ← script: exploration_tutorial.gd
├── ExplorationController (Node)          ← compartido, sin cambios respecto a exploration_test
├── ExplorationHUD (CanvasLayer)          ← compartido
├── World (Node2D)
│   └── TileMapLayer
├── Player (CharacterBody2D, grupo "player")
│   ├── CollisionShape2D
│   ├── InteractRange (Area2D)
│   ├── Personaje (Sprite2D)
│   └── Camera2D                          ← hija del Player (sigue su movimiento automáticamente)
└── WorldObjects (Node2D)
    ├── Chest_A / Chest_B
    │   ├── Interactable (Area2D)         ← detección/prompt — NUNCA bloquea movimiento
    │   ├── CollisionBody (StaticBody2D)  ← bloqueo físico real, radio menor que el de detección
    │   └── Sprite2D
```

Pensada originalmente para enseñar mecánicas de un mundo 2D más amplio que dejó de ser el centro de la jugabilidad tras el pivote narrativo. `SCENE_EXPLORATION` ya no apunta aquí (ver `Telmori Village` abajo) — pendiente de retirar del proyecto.

**A diferencia de `exploration_test.gd`, esta escena NO registra al jugador** — asume que `CharacterCreationViewModel._create_player_entity()` ya lo dejó registrado en `Characters`/`Resources`/`Skills`/`Equipment`/`Inventory` antes de que `GameLoop.enter_exploration()` la cargue. Sí registra los `WorldObjects` propios de la zona (`WorldObjectSystem.register_instance()`, `WorldObjectBridge`, `WorldObjectInteractionPanel`).

**Convención de colisión para objetos de mundo sólidos:** todo objeto interactuable necesita **dos** cuerpos separados — `Interactable` (`Area2D`, detección de proximidad/prompt) y un `StaticBody2D` adicional (bloqueo físico). Un `Area2D` nunca bloquea movimiento por diseño de Godot; ambos roles no deben mezclarse en el mismo nodo.

Ver `docs/spike_produccion_post_character_creation_informe_cierre.md` para el detalle completo (bugs corregidos, hallazgos aparcados).

### Telmori Village — Arquitectura (Spike 3, Grupo B — escena de producción real; ampliada en Grupo C)

> **Spike 12:** esta escena ya no es `SCENE_EXPLORATION` (comentada, revertible). Su `_ready()` hace inicialización de PARTIDA (companion, equipo inicial, primera entrada narrativa) y sus 5 listeners de reconexión (`combat_ended`/`narrative_flag_set`) son la lógica que Spike 13 debe migrar a datos (hotspots con `required_flags`/`blocked_flags`) antes de retirarla.

> **Spike 13: OBSOLETA.** El pueblo vive ahora en `data/interactive_scenes/telmori_village.json` (hub declarativo). La inicialización de partida pasó a `AdventureStarter` + `on_first_visit`; los 3 `Interactable` y los 5 listeners de reconexión desaparecen con esta escena. Candidata a retirada.

```
TelmoriVillage (Node2D)                   ← script: exploration_telmori_village.gd
├── ExplorationController (Node)          ← compartido
├── ExplorationHUD (CanvasLayer)          ← compartido
├── World (Node2D)                        ← vacío, sin arte todavía
├── Player (CharacterBody2D, grupo "player")
│   ├── CollisionShape2D
│   ├── InteractRange (Area2D)
│   ├── Personaje (Sprite2D)
│   └── Camera2D
└── WorldObjects (Node2D)
    └── TrailSpawnPoint (Marker2D)        ← posición base de los interactuables de reconexión (rastro de Grupo B + aftermath de Grupo C, offset +120px en X entre ellos)
```

Igual que `ExplorationTutorial`, no registra al jugador (ya lo hace Character Creation). Sin `WorldObjectBridge`/panel — no hay ningún `WorldObject` real todavía en esta escena.

Dos cosas propias, al entrar (`_ready()`):
1. Dispara `telmori_village_arrival` automáticamente, guardado por `flag.telmori_village_visited` (para no repetirse en visitas posteriores).
2. Añade a `companion_mira` al grupo (`Party.join_party()`) y equipa a jugador+companion (`Equipment.equip_item()` directo, sin pasar por `ItemCharacterBridge` — ese camino es para cuando el jugador usa un ítem desde la UI, no para setup por código).

Escucha `EventBus.combat_ended` dos veces (emboscada de Grupo B, combate final de la guarida de Grupo C) para la reconexión narrativa tras combate, y `EventBus.narrative_flag_set` dos veces para la limpieza de cada interactuable de reconexión una vez su arco queda resuelto (ver ambas secciones más abajo).

### Reconexión narrativa tras combate (Spike 3, Grupo B; generalizada en Grupo C)

Un combate disparado desde una escena narrativa (`NarrativeSceneOutcome.combat_encounter`) cierra el panel y, al terminar, vuelve a `EXPLORATION` como cualquier otro combate — pero no hay ningún camino directo de vuelta a la escena narrativa. Resuelto sin extender `VALID_STATE_TRANSITIONS` ni tocar el contrato de victoria: al ganar, se spawnea dinámicamente un `Node2D` con un `Interactable` (`interaction_type = "narrative_scene"`) en la escena de exploración — mismo patrón que ya usa `_on_combat_loot_bag_spawned()` para la bolsa de loot, sin pasar por `WorldObjectSystem` (no hace falta tirada de habilidad ni loot table para esto). Grupo C reutilizó el patrón tal cual para el combate final de la guarida (`flag.telmori_lair_combat_won` → spawn de `telmori_lair_aftermath`) — es ahora el único mecanismo validado del proyecto para esto, y cualquier combate futuro disparado desde narrativa (Grupo D incluido) debería seguir el mismo camino en vez de inventar uno nuevo.

`InteractionOutcome.narrative_event_id` no sirve para esto — dispara `NarrativeSystem.apply_event()` (el sistema de eventos/checkpoints), no `GameLoop.enter_narrative_scene()` (el motor de escenas narrativas). Dos sistemas narrativos distintos en el proyecto, fácil de confundir.

**Lección de Grupo C — el listener de `combat_ended` debe desconectarse al completar su arco, no vivir para siempre.** El primer bug real que salió al jugar la cadena completa de Grupo C: el listener de la emboscada de Grupo B (`_on_combat_ended_telmori_ambush`) nunca se desconectaba, y su guardia contra duplicados solo comprobaba "¿existe ya el nodo?" — una vez que el nodo se retira (al completar el arco), *cualquier* combate posterior que termine en victoria, sin relación alguna con la emboscada, reactiva el listener y **resucita** el interactuable obsoleto apuntando a una escena ya completada. El flag que lo guardaba (`flag.telmori_ambush_triggered`) nunca se desactiva, así que por sí solo no protege nada una vez el nodo desaparece. Arreglado desconectando cada listener de reconexión (`EventBus.combat_ended.disconnect(...)`) en el mismo punto donde se retira su interactuable — aplicado preventivamente también al listener nuevo de Grupo C, para que Grupo D no herede el mismo patrón de bug con su propio contenido de combate.

**Lección de Grupo C — limpiar un interactuable de reconexión debe engancharse a `EventBus.narrative_flag_set`, no a `EventBus.narrative_scene_closed`.** Un intento inicial de retirar el rastro obsoleto escuchaba `narrative_scene_closed`, pero cuando una escena resuelve su rama de éxito **encadenando internamente** a otra vía `next_scene_id` (sin pasar por `EXPLORATION` de por medio), el `ViewModel` no cierra el panel — solo cambia de contenido — así que esa señal nunca llega a emitirse con el `scene_id` de la escena origen en ese camino (solo en una rama que sí cierra de verdad, p. ej. un fallo con `next_scene_id` vacío). El flag que la propia rama de éxito pone (`flag.set_to` del outcome) sí es fiable independientemente de cómo encadene el panel por dentro — es la señal correcta para detectar "este arco narrativo se completó", no el cierre del panel.

### Reconexión narrativa sin combate (Spike 3, Grupo D)

Variante del patrón anterior para cuando el disparador **no** es un combate: la cadena de cierre (`telmori_lair_victory` → `telmori_lair_loot_obsidian`) termina marcando `flag.telmori_lair_cleared` sin pasar por `COMBAT_ACTIVE`, así que `exploration_telmori_village.gd` escucha directamente `EventBus.narrative_flag_set` para spawnear el interactuable de recompensa del sheriff — sin necesitar ningún listener de `EventBus.combat_ended` de por medio. A diferencia de los listeners de `combat_ended` (genéricos, se reactivan con cualquier combate no relacionado — la lección de Grupo C), un listener de `narrative_flag_set` filtrado por `flag_name` no necesita desconectarse a sí mismo: solo reacciona al flag exacto que le importa, y ese flag se marca una única vez en toda la partida.

**Riesgo nuevo, distinto al de Grupo C — exploit económico, no contenido resucitado.** Si el interactuable de recompensa se queda disponible para siempre, el jugador puede reentrar en la cadena del sheriff indefinidamente y acumular oro/ítems sin límite. Cubierto con el mismo mecanismo (un segundo listener de `narrative_flag_set`, esta vez para `flag.telmori_adventure_completed`, que retira el interactuable al completar el arco) — pero identificado por diseño antes de escribir el código, no descubierto en playtest como los cuatro bugs de Grupo C.

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

### Spike 2 — Reglas de RuneQuest para el Motor Narrativo (seis de seis puntos cerrados)

Las seis piezas que Spike 1 dejó diferidas quedan implementadas y validadas.
Ninguna toca contenido real de "Los Telmori" (eso llegó en Spike 3, Grupos A y B).

1. **Grado "especial"** — `SkillRoller.RollResult` pasa a 5 grados. `CRITICAL` y `SPECIAL` son dinámicos (`skill/20`, `skill/5`, fórmulas RuneQuest clásicas), `FUMBLE` se queda absoluto. En combate, `SPECIAL` aplica un multiplicador de daño propio (x1.2, vs x2 de crítico) vía `special_multiplier` en el effect. Cuenta como `"success"` en progresión, sin tick diferenciado.
2. **Progresión de skill narrativa** — `NarrativeSceneOption.challenge_level: int` (0 = sin progresión, opt-in explícito) engancha a `SkillProgression.execute_learning_session()` con `SourceType.NARRATIVE`, gateado en éxito, nunca vía `notify_skill_outcome()` (hard-gated a combate).
3. **Tiradas acumulativas** — `NarrativeSceneOption.required_successes`/`retry_policy` (`"immediate"`/`"blocked"`). El contador de racha vive en `NarrativeSceneViewModel`, nunca en `NarrativeSceneDB` ni en la propia `NarrativeSceneOption`. Una pifia siempre transiciona, ignorando `retry_policy`. La progresión solo se intenta al completar la racha entera, nunca en un éxito parcial. `changed("streak_progress")` expone `streak_current`/`streak_required`/`streak_option_id` — **la View no lo consumía hasta Spike 3, Grupo B** (ver antipatrón correspondiente en `athelia_ui_architecture.md`).
4. **Tiradas agregadas de grupo** — `NarrativeSceneOption.group_aggregate` (`""`/`"worst"`/`"best"`). Sin tabla de resistencia real (decisión de coste-beneficio): la oposición se codifica en `roll_modifier`, no en un valor de NPC calculado por el motor. Sin cambios en `PartyManager` — la agregación vive en el ViewModel. Si hay progresión, cada miembro del grupo intenta su propia mejora de forma independiente.
5. **Modificadores dinámicos** — cerrado sin código: `roll_modifier` (Spike 1) ya cubre el caso narrativo. El caso de combate (multiplicativo, ej. "mitad de puntería en oscuridad") se aplaza a Spike 3.
6. **Moral y refuerzos cronometrados** — fichero nuevo `core/combat/combat_encounter_definition.gd` (Resource), parámetro opcional en `GameLoopSystem.start_combat(enemy_ids, encounter = null)`. Moral de **grupo** (no individual): los enemigos supervivientes huyen juntos cuando el HP total del grupo cae bajo `morale_threshold_pct`, vía una señal nueva (`enemy_group_fled`) que nunca pasa por `character_died` (sin loot, sin animación de muerte). Refuerzos genéricos vía `reinforcement_trigger`/`reinforcement_delay_rounds`, disparables por cualquier sistema con `GameLoop.trigger_combat_event()`. `GameLoopSystem.configure_active_encounter()` permite adjuntar un encuentro a un combate ya en marcha (necesario porque `ExplorationController` arranca combate sin pasar ningún encuentro — y, desde Spike 3/B, también necesario para que la sorpresa se aplique en ese camino).

**Hallazgos de GDScript reutilizables fuera de este spike:** un `match` sin rama `_:` no avisa si le falta un caso al crecer un enum (encontrado en `SkillRoller._is_success()`, que habría tratado un `SPECIAL` como fallo en combate); un array indexado directamente por el valor entero de un enum (`LearningSession._to_string()`) se sale de rango en silencio si el enum crece sin ampliar el array. Ambos son el mismo tipo de riesgo en dos formas distintas: cualquier extensión de un enum obliga a repasar *todos* sus consumidores, no solo los que parecen relevantes a simple vista.

Ver `docs/spike_2_reglas_runequest_informe_cierre.md` para el detalle completo, decisión por decisión, y la validación realizada en cada punto.

### Spike 3, Grupo A — Motor y limpieza (los tres puntos de alcance cerrados)

Grupo deliberadamente aislado del contenido de "Los Telmori" (Grupos B/C/D) — solo motor y retirada de andamiaje de Spike 1. Sin cambios al contrato MVVM ni a ningún patrón de arquitectura UI.

1. **Moral con base dinámica** — la limitación explícita que dejó Spike 2 (base de moral fija, capturada solo al iniciar combate) queda resuelta. `GameLoopSystem._group_initial_max_hp` se renombra a `_group_morale_base_hp` (deja de ser "inicial") y se añade `_group_morale_base_dirty: bool`. Al llegar un refuerzo (`_spawn_reinforcements()`), la base no se recalcula ahí mismo — el refuerzo puede no estar registrado todavía en `ResourceSystem` (su registro lo hace la escena en respuesta a `reinforcement_spawned`, fuera de control de `GameLoopSystem`) — sino que se marca `_group_morale_base_dirty = true`. La recalculación real ocurre en la siguiente llamada a `_check_group_morale()` (que solo se dispara cuando muere alguien, vía `_check_combat_conditions()` — nunca golpe a golpe), y reutiliza el mismo `current_total_hp` que ya calcula el propio chequeo de umbral: como un refuerzo recién llegado tiene HP actual = HP máximo, ese total ya *es* "HP de supervivientes + HP máximo del refuerzo" sin necesidad de resolverlo por separado. `_check_combat_conditions()` no cambia su frecuencia de evaluación. Validado exactamente contra los dos ejemplos numéricos de la spec del grupo (500→400→refuerzo 100→base 500→umbral 200; 350→refuerzo 100→base 450→umbral 180) — ver `test/test_group_morale.gd`.
2. **Hueco genérico de limpieza en mundo** — nuevo autoload `EnemyWorldLink` (`core/combat/enemy_world_link.gd`). Escucha `EventBus.enemy_group_fled` (que ya llevaba los `entity_ids` desde Spike 2, sin cambio de firma) y, por cada uno, invoca un `Callable` de limpieza si alguien lo registró vía `register_fled_cleanup(entity_id, cleanup)` — no-op si nadie lo hizo. No conoce `WorldObjectSystem` ni ningún tipo de representación concreta: quien registra decide qué significa "limpiar". Sin ningún caso de uso real todavía en el propio grupo — lo ejerció la emboscada de Grupo B.
3. **Limpieza de Spike 1** — eliminados sin más: tecla F1 y `_debug_test_narrative_scene()` de `exploration_controller.gd`, los 5 JSON de `data/narrative_scenes/test_scene_*.json` (intro/success/failure de Spike 1, streak/group_check de Spike 2), y las claves `TEST_NARRATIVE_*` de `narrative_scenes.csv` (queda solo la cabecera). El hueco de test pendiente para `NarrativeSceneViewModel` se resuelve con `test/test_narrative_scene_viewmodel.gd`: fixtures de `NarrativeSceneDefinition`/`Option`/`Outcome` construidos en código con `new()`, sin JSON ni `NarrativeSceneDB`.

**Hallazgo de GDScript nuevo (Spike 3, Grupo A):** un enum anidado en otra clase vía `class_name` (p. ej. `GameLoopSystem.GameState`) no se puede usar de forma fiable como anotación de tipo explícita en una variable (`var x: GameLoopSystem.GameState`) en esta versión de GDScript — falla con "Could not find type... in the current scope" incluso cuando la misma ruta funciona perfectamente como valor (`as GameLoopSystem.GameState` sin tipar, o dentro de un `match`). Además, si el propio script `class_name` tiene un error de compilación en cualquier punto — o su contenido se sobrescribe por error con el de otro fichero —, su nombre de clase global deja de resolverse en *todo* el proyecto, y el síntoma es "Identifier not declared" en decenas de ficheros no relacionados con la causa real. Solución práctica: no anotar el tipo del enum anidado, trabajar con `int` a secas.

Ver `docs/spike_3_grupoA_motor_limpieza_informe_cierre.md` para el detalle completo.

### Spike 3, Grupo B — Del pueblo a la puerta de la guarida

Primer contenido real del pivote narrativo: 11 escenas de "Los Telmori", desde el gancho del sheriff hasta la puerta de la guarida, jugable de principio a fin. Ver `docs/spike_3_grupoB_pueblo_guarida_informe_cierre.md` para el detalle completo (diseño de los cinco puntos de alcance, hallazgos de motor corregidos, contenido de datos creado). Resumen de lo más relevante a nivel de motor:

- `NarrativeSceneOutcome` extendido con `combat_encounter`, `combat_enemy_definitions` y `grant_item_id/quantity/target`.
- `CombatEncounterDefinition.surprise_favors`/`surprise_vulnerable_pct` — sorpresa de combate implementada vía el buff `staggered`/`vulnerable` ya existente, sin tocar `turn_order` ni `TurnPhase` (la estructura de fases ya obliga a jugador+companions a actuar antes que los enemigos, reordenar iniciativa no tendría efecto).
- Nuevo `interaction_type` `"narrative_scene"` en `Interactable` — antes no existía ningún camino de producción para entrar en una escena narrativa desde exploración (solo una tecla de debug de Spike 1, ya retirada en Grupo A).
- Corregidos dos bugs de cuelgue de turno (`STAGGERED`/`DISARMED` en `CombatSystem._on_execute_combat_action()` no emitían `player_action_completed`), uno de registro de enemigos en combate disparado desde narrativa, uno de reinicio tras Game Over, uno de dimensionado del panel narrativo, y uno de doble sistema de valores de skill desincronizado entre `CharacterState` y `SkillSystem` (`STARTING_SKILL_VALUES` hardcodeado en `CharacterCreationViewModel`, ahora lee de la propia `CharacterDefinition`).
- `SCENE_EXPLORATION` apunta a la nueva `exploration_telmori_village.tscn`, primera zona de producción real.
- Convención nueva: carpeta por aventura para personajes/ítems específicos (`data/characters/telmori/`, `data/items/telmori/`) y para localización (`_telmori.csv`), salvo ítems de arma con ranura, que siguen agrupándose por tipo de arma.

### Spike 3, Grupo C — La guarida

Segundo tramo de contenido real del pivote narrativo: la aproximación sigilosa a la guarida y su combate final, jugable de principio a fin desde `telmori_guarida_door` (cierre de Grupo B) hasta `flag.telmori_lair_cleared` (gancho de entrada para Grupo D). Ver `docs/spike_3_grupoC_guarida_informe_cierre.md` para el detalle completo. Resumen de lo más relevante a nivel de motor:

- **Fusión de las dos salas de la aventura original en un combate por rama**, en vez de dejar al jugador elegir entre dos salas separadas: `telmori_lair_alerted` junta ambas fuerzas desde el inicio (sin sorpresa, sin refuerzo — la transcripción ya las describe convergiendo juntas al sonar la alarma); `telmori_lair_stealth` usa los supervivientes de la emboscada como roster inicial (`surprise_favors: "party"`) y la Habitación Elevada como refuerzo a la ronda 4 (`reinforcement_delay_rounds: 4`, `reinforcement_trigger: ""` — el contador arranca con el propio combate, no espera un evento externo).
- **Tirada opuesta de grupo con `group_aggregate: "worst"` confirmado por la fuente**, no por preferencia de diseño: la transcripción original reduce la Escucha de los lobos según el Deslizarse en Silencio del aventurero *más torpe* del grupo — el eslabón más débil decide, al contrario que el `"best"` usado para el rastreo de Grupo B.
- **Nueva skill `skill.exploration.stealth`** ("Deslizarse en Silencio"), calcada de `track.tres`.
- **Modificador multiplicativo de combate, decidido explícitamente NO implementarlo** — las dos salas tácticas de la aventura original (techo bajo, ventaja de tirar rocas desde una elevación) se resuelven sin tocar `CombatSystem`: el combate del proyecto es de acciones fijas por tecla, no hay "opciones de escena" contra las que restringir un arma concreta dentro de un combate en marcha. Sigue diferido desde Spike 2, ahora sin ningún caso de uso real pendiente.
- **`EnemyWorldLink` confirmado innecesario** — igual que la emboscada de Grupo B, el combate final se dispara directo desde narrativa, sin capa de exploración 2D dentro de la guarida de la que limpiar una representación de un Telmori huido. Termina la aventura piloto completa sin ningún caso de uso real, resultado aceptado como válido, no señal de sobre-ingeniería.
- Cuatro bugs de motor preexistentes encontrados y corregidos al jugar la cadena completa por primera vez: un encadenado suelto en `telmori_guarida_door` (escrito antes de que existiera Grupo C, sin `next_scene_id` hacia la guarida); ausencia total de reconexión narrativa tras el combate final (nadie había replicado el patrón de Grupo B para el segundo combate del proyecto); un listener de reconexión que nunca se desconectaba y resucitaba un interactuable ya retirado ante cualquier combate posterior; y una limpieza enganchada a la señal equivocada (`narrative_scene_closed` en vez de `narrative_flag_set`) que nunca se disparaba en el camino de encadenado interno de una escena a otra. Detalle completo de los cuatro en la sección "Reconexión narrativa tras combate" más arriba y en el informe de cierre.

### Spike 3, Grupo D — Cierre

Último grupo del Spike 3: recompensa multicapa, entrega del botín mágico de la guarida y gancho de continuidad final, jugable de principio a fin desde `flag.telmori_lair_cleared` hasta `flag.telmori_adventure_completed`. **Con este grupo, "Los Telmori" queda completa.** Ver `docs/spike_3_grupoD_cierre_informe_cierre.md` para el detalle completo. Resumen de lo más relevante a nivel de motor:

- `NarrativeSceneOutcome` extendido con `grant_resource_id/amount/target` ("otorgar recurso", análogo a `grant_item_*` vía `Resources.add_resource()`) — ver detalle y el bug de declaración encontrado en la sección "Narrative Scene — Arquitectura" más arriba.
- Nuevo patrón de reconexión narrativa **sin combate de por medio** (`EventBus.narrative_flag_set` directo, sin `combat_ended`) — ver "Reconexión narrativa sin combate" más arriba, con su propio riesgo identificado (exploit económico por interactuable de recompensa sin limpiar) y su propia solución (segundo listener de flag para la limpieza).
- **Camino de Curtidor resuelto sin gating de visibilidad de opción nuevo** — `Characters.get_skill_value()` devuelve 0 para una skill fuera del kit inicial, así que una tirada normal contra `skill.exploration.tanning` ya da la probabilidad casi nula buscada sin construir nada. Confirmado en playtest: `SkillRoller` registró `vs 0% → FAILURE` para el jugador sin el tomo leído.
- **Mini-acertijo de la bolsa mágica, decidido explícitamente NO implementarlo** — mismo criterio que el modificador multiplicativo de combate descartado en Grupo C: sin un segundo caso de uso de "interacción objeto sobre objeto" en el proyecto, se resuelve como flavor narrativo puro. El mecanismo de "otorgar ítem" existente entrega la bolsa sin más.
- **Reflavor del entrenamiento de magia** — el tomo (`book_tanning_basics.tres`) enseña Curtidor directamente vía `learning_data`, reutilizando el mecanismo de libro de aprendizaje ya existente desde `book_combat_basic.tres`, sin sistema de magia nuevo (sigue aparcado). Orden de las escenas del sheriff decidido para que el tomo se entregue **antes** de la venta de pieles, así el jugador puede usar la skill recién aprendida en la misma sesión de recompensa. **Corrección (Spike 10):** en la práctica este camino no funcionaba — el jugador no tenía la skill registrada, así que la lectura del tomo fallaba y consumía el libro sin enseñar nada (ver "Spike 10" más abajo); además `grant_item_*` no se ejecutaba en el ViewModel, por lo que el tomo ni llegaba al inventario.
- `ItemDefinition.item_type` confirmado como enum cerrado (`CONSUMABLE`/`EQUIPMENT`/`MISC`, sin tipo "genérico decorativo") — los tres ítems de botín/trofeo sin mecánica (`telmori_magic_bag`, `obsidian_spearhead`, `wolf_tail_trophy`) usan `MISC`.
- `SkillSystem`/`ItemRegistry` confirmados como escaneo recursivo real de `data/skills/`/`data/items/` (sin lista hardcodeada, a diferencia de `ResourceSystem._load_resource_definitions()`, que sí tiene una lista fija pero no se ve afectada porque `gold` ya estaba en ella) — la skill y los ítems nuevos de este grupo se cargaron sin tocar ningún registro de motor.
- Un bug real de contenido (no de motor): `telmori_lair_victory.json` se quedó con el contenido original en el proyecto tras diseñar la cadena de botín en conversación — el flag se marcaba igual, así que el fallo (botín nunca entregado) no producía ningún error visible. Detectado revisando qué `scene_id` traía `narrative_scene_closed` en el log: si una cadena multi-escena se corta antes de tiempo, el `scene_id` de cierre delata en qué nodo se quedó de verdad.

### Mejoras post-Spike 3, Grupo 3 — Overlays de inventario/party/stats durante narrativa

Primer grupo del ciclo de mejoras posterior al cierre de Spike 3. Objetivo: poder abrir Inventory/Party/PlayerMenu desde dentro de `NARRATIVE_SCENE` sin salir de la escena narrativa ni perder su progreso (nodo actual, racha de tiradas acumulativas en curso). Ver `docs/mejoras_grupo3_overlays_narrativa_informe_cierre.md` para el detalle completo. Resumen de lo más relevante a nivel de motor:

- **Las dos comprobaciones de código obligadas por el spec, resueltas antes de diseñar nada:** `open_inventory()`/`open_party()`/`open_player_menu()` en `SceneOrchestrator` comparten exactamente el mismo guard manual (`current_game_state != EXPLORATION`), ninguno usa `VALID_STATE_TRANSITIONS` — no hay bifurcación real entre los tres, así que el alcance no se reduce a solo Inventory. Y `ExplorationController._unhandled_input()` bloquea todo su input con `GameLoop.is_input_blocked()` fuera de `EXPLORATION` — las teclas de inventory/party/player_menu no "funcionaban ya sin querer" en narrativa, estaban activamente bloqueadas.
- **Hallazgo crítico no anticipado por el spec:** `SceneOrchestrator._current_overlay` es un slot único, no una pila. Abrir Inventory desde narrativa por el camino normal (`SceneOrchestrator.open_inventory()`) habría interpretado el panel narrativo ya abierto como "hay un overlay, toggle" y lo habría `queue_free()`eado, destruyendo `NarrativeSceneViewModel` y con él la racha en curso.
- **Diseño adoptado:** `NarrativeScenePanel` gestiona Inventory/Party/PlayerMenu como sub-overlay propio (`_open_sub_overlay()`/`_close_sub_overlay()`), instanciándolos como hijos directos — nunca a través de `SceneOrchestrator`. Mismo patrón que ya usaba `PlayerMenuScreen._open_subscreen()` para sus propias subpantallas (Loadout/Inventory/SkillTree), extendido aquí a un segundo nivel de anidamiento. `SceneOrchestrator._current_overlay` sigue apuntando al panel narrativo durante todo el proceso — nunca se toca.
- `NarrativeSceneViewModel` gana tres intenciones (`request_open_inventory/party/player_menu`), guardadas igual que `request_option()` (solo con `PanelState.SHOWING`). No tocan `current_node` ni `_success_streaks` — el sub-overlay es responsabilidad íntegra de la View.
- `SceneOrchestrator.open_inventory()`/`open_party()`/`open_player_menu()` ganan `LIGHT_OVERLAY_ALLOWED_STATES` (`EXPLORATION` + `NARRATIVE_SCENE`) y un guard explícito que bloquea la ruta de `_current_overlay` en `NARRATIVE_SCENE` — red de seguridad defensiva: en la práctica ninguno de los tres se invoca desde narrativa (lo resuelve `NarrativeScenePanel` internamente), pero si algo lo hiciera por error, se bloquea con aviso en vez de destruir el panel narrativo.
- **Bug de motor preexistente, confirmado en playtest real, no introducido por este grupo:** `InventoryUI`, `PlayerMenuScreen`, `LoadoutScreen` y `SkillTreeScreen` no se auto-liberan (`queue_free()`) en ningún camino de cierre — solo ponen `visible = false`. `PlayerMenuScreen._open_subscreen()` dependía de `tree_exiting` para saber cuándo destruir una subpantalla cerrada, señal que por tanto nunca se disparaba. Reproducido en juego: abrir Inventory/Loadout/SkillTree desde dentro de PlayerMenu (siendo PlayerMenu a su vez sub-overlay de `NarrativeScenePanel`) y cerrarlos dejaba las tres capas (subpantalla, PlayerMenu, panel narrativo) colgadas invisibles, sin ninguna forma de volver atrás — indistinguible de un crash desde fuera, aunque sin ninguna excepción real del motor. Corregido añadiendo `signal closed` a las cuatro pantallas (`PartyUI` ya la tenía), emitida junto a su `visible = false`, y hacer que tanto `NarrativeScenePanel._open_sub_overlay()` como `PlayerMenuScreen._open_subscreen()` prioricen `closed` sobre `tree_exiting` (con `has_signal("closed")` como comprobación, cayendo a `tree_exiting` con aviso si algún día falta).
- **Segundo bug de motor preexistente encontrado de paso:** `ExplorationHUD._unhandled_input()` (a diferencia de `ExplorationController`) no comprobaba `GameLoop.is_input_blocked()` — disparaba `open_skill_tree`/`open_player_menu` sin importar el `GameState`. Inofensivo mientras `EXPLORATION` era el único origen legítimo (el guard de `SceneOrchestrator` ya bloqueaba la llamada), pero generaba ruido real (warning) al pulsar la tecla de PlayerMenu durante `NARRATIVE_SCENE`, porque el evento lo procesaban a la vez `NarrativeScenePanel` (correcto) y `ExplorationHUD` (bloqueado). Mismo guard añadido que ya tenía `ExplorationController`.
- Validado en partida real: apertura de Inventory/Party/PlayerMenu desde narrativa sin recargar el nodo ni perder racha; navegación completa Loadout→Inventory→SkillTree dentro de PlayerMenu (siendo este a su vez sub-overlay de narrativa) sin colgarse en ningún punto de cierre; regresión confirmada del camino normal desde `EXPLORATION`, sin cambios de comportamiento.

### Mejoras post-Spike 3, Grupo 5 — Pantalla de combate de producción

Sustituye la pantalla de combate de test (`combat_test_scene`/`combat_hud.tscn`) por una de producción real, sin cambiar ninguna regla de combate. El más grande de los cinco grupos de mejoras — diseño visual cerrado de antemano en conversación (arena de fichas circulares, party izquierda/enemigos derecha, log narrado, menú de 8 acciones). Ver `docs/mejoras_grupo5_combate_produccion_informe_cierre.md` para el detalle completo. Resumen de lo más relevante a nivel de motor:

- **Fase 5A — Design System**: `UIRadialGauge` (anillo de progreso radial, primer componente `_draw()`/arcos del Design System) y `UICombatToken` (ficha de party/enemigo, compone dos `UIRadialGauge` + relleno central + triángulo de turno + retícula de objetivo). `CharacterDefinition` gana `token_color`/`type_icon` para personalizar cada ficha desde el `.tres`, mismo criterio que retratos/nombres.
- **Fase 5B — MVVM**: `CombatArenaViewModel` (nuevo) **compone** a `CombatHudViewModel` (existente, sin tocar) como `action_menu`, en vez de sustituirlo — primer caso de composición de ViewModels del proyecto. Fichas dinámicas (`combat_tokens: Array[CombatTokenData]`) porque companions/enemigos pueden unirse a mitad de combate (rescate narrativo, refuerzos cronometrados vía `reinforcement_spawned`). Log narrado (`log_entries: Array[LogEntryData]`) con 4 categorías reales: `ATTACK` graduado por `SkillRoller` (5 claves), `DODGE`/`DEFEND`/`FLEE` sin grado (caminos de motor completamente distintos entre sí — dodge no tira, defend/flee no pasan por `combat_action_completed` en absoluto, van por señales propias de `DefenseModule`/`EscapeModule`).
- **El menú de acciones real son 8 slots, no 6** (spec original se olvidó los 2 de ítem) — ya modelado tal cual por `ActionSlotData`/`LoadoutState` existente, sin cambio de arquitectura.
- **Punto 8 — integración real en `SceneOrchestrator`**: `SCENE_COMBAT` → `combat_production_scene.tscn` (nueva pieza sin UI, solo IA + `PlayerCombatController`); `OVERLAY_COMBAT_HUD` → `combat_arena_panel.tscn`. `combat_test.tscn`/`combat_hud.tscn` no se retiran, quedan como escena de test independiente.
- **Hallazgo real en combate de producción, no anticipado**: `NarrativeSceneViewModel`/`ExplorationController` pre-registran `Characters`/`Resources` para enemigos pero **nunca `Skills`** — falso supuesto inicial de "ya está todo registrado" al diseñar `combat_production_scene.gd`. Corregido registrando Skills ahí mismo, con guard idempotente, para roster inicial y refuerzos por igual.
- **`EnemyCombatNode` (visual 2D, sprite+`AnimationController`) confirmado prescindible en producción**: ni `EnemyAI` ni `CompanionAI` dependen de él (ambos `extends Node`, sin `get_parent()`/dependencia de nodo padre) — `UICombatToken` cubre su único rol funcional real. `_get_entity_damage_number_position()` en `combat_system.gd` gana rama para `Control` junto a la `Node2D` existente.
- **Bug de motor preexistente confirmado, no arreglado en este grupo**: `ResourceSystem.resource_changed` (señal propia del autoload `Resources`) nunca se reenvía a `EventBus.resource_changed` — `combat_hub_viewmodel.gd` se conecta a la señal equivocada, así que el HP/EN del jugador probablemente no se actualiza en vivo en la pantalla de test. `CombatArenaViewModel` se conecta directamente a `Resources.resource_changed`, evitando el mismo bug.
- **Otro bug de motor preexistente confirmado**: `combat_hud.gd` mapea el slot `"escape"` a la action `"combat_escape"`, pero el InputMap real usa `"combat_scape"` (typo/mismatch) — el botón de huir por teclado probablemente no respondía en la pantalla de test.
- **Fuga de memoria preexistente confirmada**: `SceneOrchestrator._handle_combat()` nunca guarda referencia a la instancia de `SCENE_COMBAT` ni la libera en `_on_combat_ended()` (a diferencia de `OVERLAY_COMBAT_HUD`, sí liberada) — se acumula una copia por combate. `combat_production_scene.gd` se libera a sí misma como mitigación local, el problema de fondo en `SceneOrchestrator` sigue sin arreglar.
- **`AttributeResolver` (máximo derivado real del personaje) y `ResourceState.max_effective` (máximo genérico de `ResourceDefinition.max_base`, típicamente 100) confirmados como dos números desconectados** — nada llama a `Resources.set_max_effective()` para sincronizarlos, al menos en el camino de `combat_test_scene.gd`. **Resuelto en Spike 6**: causa raíz completa (no solo el camino de `combat_test_scene.gd`) era que `ModifierApplicator` solo sincroniza como efecto de `Characters.set_base_attribute()`, y el único caller de eso en todo el proyecto era `character_creation_viewmodel.gd` para `"player"` — enemigos/refuerzos/companions nunca pasaban por ahí. Arreglado sincronizando dentro de `ResourceSystem.register_entity()` mismo (ver tabla de autoloads arriba), no en cada punto de registro por separado. Ver `docs/spike_6_investigacion_motor_combate.md` para el detalle completo, incluido el segundo bug independiente que compartía síntoma (el HP fijo a 50.0 en el registro de enemigos, origen real del patrón `50/60` reportado).
- Validado jugando la aventura completa de "Los Telmori" de principio a fin, incluidos refuerzos reales a mitad de combate en la guarida (ronda 4).



`CharacterState` serializa `definition_id`, `character_name` y `attributes` vía `get_save_state()`/`load_save_state()`. Conectado a `SaveSystem` desde `SAVE_VERSION = 5` — `_restore_state()` restaura el snapshot de `CharacterSystem` **primero**, antes de recursos/skills, porque `load_save_state()` puede bootstrapear el registro de la entidad vía `definition_id` si no existe todavía.

**Registro en frío — resuelto para 4 de los 5 sistemas.** `EquipmentManager` e `InventorySystem` ya se auto-registraban dentro de su propio `load_save_state()` (no requería cambios). `ResourceSystem` y `SkillSystem` **no** lo hacían — su `load_save_state()` no hacía nada en silencio si la entidad no existía. Desde el spike de producción, ambos exponen `has_entity(entity_id) -> bool`, y `SaveSystem._restore_state()` registra la entidad en frío antes de restaurar si hace falta (el universo de skills a registrar sale de las propias keys del snapshot guardado, no de un kit hardcodeado). "Cargar Partida" desde un arranque en frío real ya funciona con HP/Stamina/Gold/Skills correctos.

**Actualizado en mejoras post-Spike 3, Grupo 1 — pendiente de posición cerrado, no por arreglo sino por irrelevancia:** con el pivote a RPG narrativo por eventos/flags (sin exploración espacial), `player_state["position"]` (x,y) sigue guardándose/restaurándose exactamente igual que antes (sin cambios de código), pero es dato vestigial — el jugador ya no se mueve por posición, así que el hueco de "no se restaura en arranque en frío" deja de tener ningún efecto observable en el juego. Candidato a limpieza futura (retirar el campo del schema), fuera de alcance de este grupo. `SAVE_VERSION` pasa a `6` en este mismo grupo — ver sección propia más abajo.

`SaveSystem._find_player()` busca primero bajo el nodo `"ExplorationScene"` (creado explícitamente por `SceneOrchestrator`), no bajo `get_tree().current_scene` — este último nunca cambia mientras `MainMenuScreen` siga siendo la Main Scene, ya que la exploración se instancia de forma aditiva (`get_tree().root.add_child()`), no con `change_scene_to_file()`.

### Mejoras post-Spike 3, Grupo 1 — Guardado de partida

Objetivo del grupo: que la partida guardada recuerde el progreso narrativo real (no solo personaje/recursos/skills/inventario/equipo) y se pueda reanudar exactamente donde se dejó, más un atajo barato de desarrollo para probar tramos avanzados sin jugar la aventura entera. Ver `docs/mejoras_grupo1_guardado_informe_cierre.md` para el detalle completo.

- **Comprobación de código — corrige un supuesto erróneo de la documentación previa:** `SaveManager`/`SaveData` **ya** guardaban flags/variables/eventos completados/checkpoints/party antes de este grupo (`narrative_state`, vía `_collect_narrative_state()`/`_restore_narrative_state()`) — la documentación de arquitectura decía lo contrario (desactualizada en este punto concreto, ya corregida). El hueco real no eran los flags en sí, era únicamente "a qué escena narrativa volver al cargar".
- **Decisión de diseño que cambia el mecanismo original del spec:** guardar deja de ser una hotkey libre (F5) disponible en cualquier `NARRATIVE_SCENE` — solo se puede guardar seleccionando una opción de diálogo ofrecida por NPCs concretos marcados como savepoint (ej. el sheriff en "Los Telmori"), no todos los NPCs. Al ser NPCs "sin peso en la historia" los que la ofrecen, que el diálogo sea repetible no abre ningún exploit (a diferencia del caso del sheriff con recompensas económicas en Grupo 5). F5 se retira del todo de `ExplorationController`; F9 (cargar) se queda sin restricción de estado, igual que "Cargar Partida" desde el menú.
- **`DialogueOptionDefinition` gana `triggers_save: bool = false`.** En `DialogueSystem.select_option()`, justo después de `_trigger_narrative_events()` y antes de navegar a `next_node_id`/terminar el diálogo: si `triggers_save`, llamada directa a `SaveManager.save_game()` — mismo nivel de acoplamiento que ese método ya tiene con `Narrative.apply_event()`. `DialogueRegistry._load_option_from_dict()` necesitó una línea nueva (`option.triggers_save = data.get("triggers_save", false)`) — construye cada opción campo a campo, sin mapeo genérico de claves JSON, así que un campo nuevo en el Resource no se lee solo por añadirlo al JSON de contenido.
- **`SaveData.narrative_state` gana `current_narrative_scene_id: String`. `SAVE_VERSION` sube de 5 a 6**, con migración (`_migrate_from_version()`) que rellena `""` en saves antiguos. Se recoge en `_collect_narrative_state()` vía `SceneOrchestrator.get_current_overlay()` (getter nuevo) + `NarrativeScenePanel.get_current_scene_id()` (getter nuevo, lee `_vm.current_node.scene_id`) — duck-typing con `has_method()`, mismo estilo que ya usa `SceneOrchestrator` internamente. Sigue siendo válido aunque el panel esté detrás de un sub-overlay de Diálogo (`visible = false`, pero `_vm.current_node` no se toca — ver Grupo 3).
- **Al cargar, `SaveSystem` no transiciona `GameState` directamente** — nunca lo ha hecho (el punto de cambio de escena en `_restore_state()` sigue comentado). Expone `get_pending_narrative_scene_id()`, y es `MainMenuViewModel.request_load_game()` quien decide `enter_narrative_scene(scene_id)` vs `enter_exploration()` tras `load_game()`.
- **Hallazgo no anticipado — `MENU → NARRATIVE_SCENE` no existía en `VALID_STATE_TRANSITIONS`.** `enter_narrative_scene()` llamado desde `MENU` caía en `push_warning()` sin transicionar nada ni avisar de forma ruidosa — silencioso hasta comparar logs. Corregido añadiendo `NARRATIVE_SCENE` a las transiciones válidas desde `MENU`.
- **Segundo hallazgo no anticipado, más profundo — orden de instanciación de `ExplorationScene`.** Con `MENU → NARRATIVE_SCENE` directo, es la primera vez que un combate puede dispararse desde una escena narrativa sin que `ExplorationScene` (y con ella, `_ready()` de la escena de exploración real, ej. `TelmoriVillage`) se haya instanciado todavía. Los listeners de continuación que ese `_ready()` registra (ej. `_register_telmori_ambush_continuation()` escuchando `EventBus.combat_ended` para spawnear "Rastros" tras la emboscada) se conectaban **después** de que el combate ya hubiera terminado y emitido su propia `combat_ended` — señal perdida en silencio, contenido de continuación nunca aparecía. Corregido factorizando `_ensure_exploration_scene_instantiated()` en `SceneOrchestrator`, llamado tanto desde `_handle_exploration()` como desde `_handle_narrative_scene()`.
- **Trampa de reentrada descubierta al aplicar el fix anterior, resuelta antes de que llegara a producción:** `TelmoriVillage._ready()` tenía su propio guard `if current_game_state != EXPLORATION: enter_exploration()`, pensado para cuando la escena se ejecuta suelta en el editor. Instanciar `ExplorationScene` dentro de `_handle_narrative_scene()` sin corregir ese guard habría hecho que `_ready()` viera `NARRATIVE_SCENE` (`!= EXPLORATION`) y llamara a `enter_exploration()` **en mitad de la propia apertura de la escena narrativa** — transición reentrante que habría cerrado el panel narrativo justo después de abrirlo. Corregido cambiando la condición a `== MENU` (el único caso real que necesitaba cubrir: arranque sin `GameLoop`/`SceneOrchestrator` de por medio).
- **Falsa alarma descartada:** el warning `[InventorySystem] Entity not registered for load` al cargar no es un bug — `InventorySystem.load_save_state()` ya se auto-registra (`register_entity()`) si la entidad no existe, a diferencia de lo que en un primer momento se sospechó por analogía con `ResourceSystem`/`SkillSystem` (que si necesitaron ese fix, en el spike de producción). El inventario se carga bien pese al warning.
- **Hallazgo de paso, sin código:** `SaveFeedbackUI` ya existía y ya escuchaba `save_completed`/`save_failed` de `SaveSystem` — el feedback visual de "partida guardada" al usar la opción de diálogo del NPC savepoint no necesitó código nuevo.
- **Atajo de desarrollo** (mecanismo aparte del guardado real, nunca toca `SaveManager`/`SaveData`): tecla F2, ver sección "Input en exploración" más abajo para el detalle.
- Validado en partida real completa: guardar desde el sheriff en `NARRATIVE_SCENE` → cerrar el juego → "Cargar Partida" desde el menú resume exactamente en esa escena narrativa, con todo el estado restaurado (personaje, recursos, skills, equipo, inventario, party, economía, flags) → seguir jugando con normalidad, incluida una mejora de skill post-combate (`SkillProgressionService`) y el combate final de la guarida, hasta completar la aventura entera de "Los Telmori" de principio a fin.

### Mejoras post-Spike 3, Grupo 4 — Arte narrativo

Fondos de escena, fondos de combate reales (Grupo 5 los había dejado como `ColorRect` fijo) e iconos de tipo de enemigo para "Los Telmori", generados con IA bajo una dirección de arte acordada en conversación. Sin animación. Ver `docs/mejoras_grupo4_arte_narrativo_informe_cierre.md` para el detalle completo (catálogo, primers de estilo, mapeo escena → fondo). Resumen de lo más relevante a nivel de motor:

- **Layout narrativo B1** — imagen a pantalla completa detrás, panel en el tercio inferior (ver árbol en "Narrative Scene — Arquitectura" arriba). Solo `.tscn`, cero líneas de script.
- **`image_path` validado al cargar**: `NarrativeSceneDefinition.validate()` emite `push_warning` si la ruta no existe — antes solo fallaba al llegar a la escena en partida.
- **Fondo de combate por encuentro**: `CombatEncounterDefinition.background_path` (clave del `combat_encounter` inline del outcome). `GameLoopSystem.get_current_encounter()` (getter nuevo, solo lectura) lo expone; `CombatArenaViewModel` carga la textura con `call_deferred()` desde `_on_combat_started()` — `combat_started` no se emite desde `game_loop_system.gd`, así que no hay orden garantizado frente a la asignación de `_current_encounter`. Limitación conocida: un encuentro sustituido a mitad de combate vía `configure_active_encounter()` no actualiza el fondo (no hay señal); ningún contenido lo usa.
- **Los fondos de combate son mapas cenitales, no las láminas de escena** — decisión tomada durante el grupo (el spec proponía reutilizar el catálogo de escena): tinta y aguada sobre pergamino, sin cuadrícula porque las fichas no se mueven por el mapa. Uno por encuentro, en `data/combat/backgrounds/<aventura>/`.
- **Velo y contorno**: `Background` pasa a ser velo (`COLOR_PANEL` con alfa `COMBAT_BACKGROUND_SCRIM_ALPHA = 0.2`) encima de la imagen, opaco si no la hay. Contorno oscuro (`TEXT_OUTLINE_SIZE`/`COLOR_TEXT_OUTLINE`, tokens nuevos) en el texto de `UICombatToken` y del log. El alfa es una constante global válida mientras todos los fondos de combate sean mapas claros del mismo estilo — si conviven con láminas oscuras, tendrá que pasar a dato por encuentro.
- **Bug preexistente corregido**: las fichas enemigas nunca recibían `fill_color` (quedaban en el `Color.WHITE` por defecto de `CombatTokenData`) — un icono claro habría sido invisible. Y `_resolve_fill_color()` no respetaba el centinela `Color.BLACK` de `token_color` (ficha negra en vez de color neutro).
- **Iconos de tipo**: carpeta por aventura (`data/characters/telmori/icons/`) + carpeta genérica (`data/characters/icons/`); si el arte coincide se copia el fichero. `enemy_base` sin icono por decisión.
- **Latente, no corregido**: `CharacterDefinition.duplicate_definition()` no copia `token_color`/`type_icon`/`starting_skill_values`/`loot_table_id` — sin llamadas en el proyecto, sin efecto hoy.
- **Hallazgos preexistentes fuera de alcance, sin corregir**: los 8 botones de acción de la arena no muestran nombre; la columna enemiga se desborda por arriba con 6-8 enemigos; el log muestra IDs internos en vez de nombres localizados; el desajuste PV actual/máximo de Grupo 5 (visible como `50/45`).
- Validado en partida completa de "Los Telmori": las 21 escenas con fondo, los dos combates con su mapa, iconos reales en todas las variantes de enemigo.

### Spike 10 — Diálogos restantes del sheriff (Los Telmori)

Aplica a `telmori_sheriff_reward_intro` y `telmori_sheriff_training` el patrón de Grupo 2 (sub-overlay de diálogo desde `NarrativeScenePanel`, `dialogue_id` en el outcome, `resume_after_dialogue()`). `telmori_sheriff_pelts` no se convierte (tirada real de Curtido, `DialogueOptionDefinition` no soporta tiradas) y `telmori_epilogue_hook` no se toca. Con esto el **Grupo 2 queda completo**. Ver `docs/spike_10_dialogos_sheriff.md` para el detalle completo.

- **Decisión de diseño (camino A):** el diálogo solo conversa; las entregas se quedan en el outcome narrativo que abre el diálogo (`grant_resource_*`/`grant_item_*` + `dialogue_id` + `next_scene_id`). Comprobado con el código real que `DialogueOptionDefinition`/`DialogueSystem` no tienen mecanismo de entrega (solo `narrative_events`, `triggers_save` y navegación) — no se añadió, porque no hacía falta. Las entregas ocurren al pulsar la opción, **antes** del diálogo; el texto de la escena narra el traspaso.
- **Exploit cubierto por diseño:** la entrega vive fuera del hub, así que volver a una rama del diálogo no puede reclamarla dos veces; la protección contra reentrada de la cadena sigue siendo la limpieza del interactuable con `flag.telmori_adventure_completed`.
- **Hallazgo 1 — `grant_item_*` no se ejecutaba.** El bloque de entrega de ítems se había perdido de `NarrativeSceneViewModel._apply_outcome()` (quedaba el comentario con la entrega de recurso debajo), sin ningún error visible: ningún ítem de ningún outcome llegaba al inventario, incluidos la bolsa mágica y la punta de obsidiana de Grupo D. Con toda probabilidad se perdió al parchear el método en el Grupo 2. Restaurado antes del retorno temprano de `dialogue_id`, con `print` por entrega y `push_warning` si `Inventory.add_item()` devuelve `false`.
- **Hallazgo 2 — un libro no podía enseñar una skill fuera del kit.** `register_entity_skills()` solo crea instancias del kit; `execute_learning_session()` no encontraba la de Curtido (`skill_locked`) y `_apply_consumable()` emitía `item_use_success` incondicionalmente, consumiendo el libro sin efecto. Los libros anteriores solo mejoraban skills ya poseídas. Arreglo: `SkillSystem.learn_skill()`, `initial_value` en `learning_data`, `_apply_learning()` devuelve `bool` y el libro solo se consume si el aprendizaje se aplicó (`item_use_failed` en caso contrario; una tirada de mejora fallida sigue consumiéndolo). Detalle en "Skills — dos sistemas paralelos de valores" arriba.
- **Localización:** faltaban textos de cuatro escenas del Grupo D, la escena de botín y las flechas/lanza de Grupo B. Un `.csv` nuevo necesita alta manual en Project Settings (`items_telmori.csv` no la tenía).
- **Validado en partida real** (F2 con `flag.telmori_lair_cleared`): entregas una sola vez cada una, ambos diálogos como sub-overlay con reenganche automático, tomo leído desde el inventario en pleno `NARRATIVE_SCENE` → `APRENDIDA (valor inicial 15%)`, Curtido visible y entrenable desde el panel de habilidades, tirada de venta contra el valor real, `flag.telmori_adventure_completed` marcado e interactuable retirado.
- **Sin probar en partida:** el camino de fallo del libro (`item_use_failed`, libro no consumido) y el guardado/carga con Curtido aprendido (solo comprobado por código).

### Spike 11 — Rediseño de la ventana de diálogo (fondo, retrato, estado de ánimo)

Rediseña `DialoguePanel`, mínimo y sin decoración desde su creación: fondo
propio, marco decorativo del Spike 9 y un único retrato del NPC (se
descarta definitivamente el layout de dos retratos original — el jugador
ya "habla" a través de las opciones). Ver `spike_11_ventana_dialogo.md`
para la maqueta y el detalle completo de la Fase 1.

- **Comprobación de código previa (Fase 0):** `portrait_id` ya existía y se
  consumía de verdad (JSON → `DialogueRegistry` → `DialogueNodeDefinition`
  → `DialogueSystem` → `EventBus.dialogue_node_shown` →
  `DialogueViewModel` → `DialoguePanel`) — no era un campo huérfano como
  `grant_item_*` en Spike 10. No existía ningún campo de estado de ánimo.
  Las dos claves crudas vistas en captura (`SPEAKER_SHERIFF`,
  `DLG_SHERIFF_OPT_SAVE`) eran huecos reales en
  `dialogues_scenes_telmori.csv`, no un problema de alta del `.csv` en
  Project Settings (ya estaba dado de alta desde Spike 10) — corregidas
  añadiendo las dos filas.
- **`DialogueNodeDefinition` gana `mood: String = "neutral"`** (por nodo,
  no por diálogo: cambia a mitad de conversación). Resuelto en
  `DialogueViewModel._resolve_portrait()` con cascada de respaldo:
  `"<portrait_id>_<mood>.png"` → `"<portrait_id>.png"` (neutral) → sin
  retrato, con `push_warning` en cada salto — nunca falla en silencio como
  hacía antes la resolución de `portrait_id`.
- **`DialogueDefinition` gana `portrait_folder: String = ""`** (subcarpeta
  de retratos por aventura, bajo `res://data/characters/portrait/`) **y
  `background_id: String = ""`** (escena de fondo dentro de la aventura).
  Ambos opcionales y con respaldo — vacíos, el comportamiento es el de
  antes de este spike, ningún diálogo existente necesitó tocarse.
  `background_id` cae al fondo genérico de la aventura
  (`res://data/dialogue/backgrounds/<portrait_folder>.png`) si está vacío
  o el fichero de escena no existe.
- **`EventBus.dialogue_node_shown` pasa de 4 a 7 argumentos** (`portrait_id`,
  `mood`, `portrait_folder`, `background_id`). Los oyentes existentes que
  declaraban menos parámetros —incluidos los tests— siguieron compilando
  sin tocarlos: GDScript descarta los argumentos de más al emitir una
  señal si el callback conectado acepta menos. `DialogueSystem` expone
  `mood` en `get_current_node_info()` y en el nuevo getter
  `get_current_mood()`.
- **Base de `DialoguePanel` migrada de `PanelContainer` plano a `UIPanel`**
  (`decorative_frame = true`, marco del Spike 9) — pendiente que dejó
  abierto el propio Spike 9 ("activar el marco en otras pantallas,
  pantalla a pantalla"). Exports de configuración visual declarados sin
  efecto real, retirados: `background_texture`, `portrait_frame_texture`,
  `text_color`, `text_font_size`, `speaker_name_color`,
  `speaker_name_font_size`.
- **Antipatrón nuevo, mismo patrón que "Panel sin tamaño fijo con texto
  largo" pero por número de hijos en vez de longitud de texto:** un
  `PanelContainer` no se encoge por debajo del mínimo de sus hijos: con 5
  opciones, el panel de diálogo crecía y, por `grow_vertical = BEGIN`,
  "subía" invadiendo pantalla en vez de quedarse en su franja. Arreglo:
  `OptionsContainer` envuelto en un `ScrollContainer` — no impone el
  mínimo de su contenido al padre, hace scroll en su lugar. Con la altura
  de panel definitiva (anclas `0.57`–`0.96`, corregidas desde un `0.66`
  copiado por error de la convención de `NarrativeScenePanel`, que no
  encajaba con el contenido real de este panel) caben 3 opciones sin
  scroll.
- **Fondo de ambiente:** mismo patrón que `CombatArenaViewModel`/Grupo 4
  (`BackgroundImage` detrás + `Background` como velo semitransparente
  encima, razón `"background"` de `changed()`, solo emitida cuando el path
  cambia). Imagen pre-difuminada en la generación, no blur en tiempo real
  (evita `SubViewport`+shader). `SCRIM_ALPHA_WITH_IMAGE = 0.55`, validado
  contra el arte real de Los Telmori.
- **Retrato como hermano del panel, no hijo** — layout C de la maqueta
  (franja inferior, retrato grande sobresaliendo por el borde superior del
  marco), elegida sobre las variantes A ("retrato lateral") y B ("panel
  centrado") para dar protagonismo a la imagen del NPC. Sin retrato
  disponible, el panel de texto ocupa todo el ancho.
- **Validado en partida real**, aventura completa de "Los Telmori" de
  principio a fin: apertura como sub-overlay desde escena narrativa y
  desde `EXPLORATION` vía interactuable; cambio de expresión a mitad de
  conversación; hablante sin retrato; contrato de sub-overlay de Grupo 2
  (`signal closed`, `resume_after_dialogue()`) intacto tras el rediseño.
- **Deuda técnica anotada, fuera de alcance de este spike:** tests de
  `dialogue_node_shown` (`dialogue_panel_test.gd`, `test_dialogue_system.gd`,
  `test_eventbus.gd`) no adaptados a la firma de 7 argumentos; resolución
  de ventana (afecta a toda pantalla con posiciones en píxeles fijos, no
  solo a este panel — decisión de proyecto, no de spike); documentación de
  `UIPanel.Variant.OVERLAY` como semitransparente, con stylebox opaco en
  la práctica.

### Spike 12 — Motor de escenas interactivas (mapa de puntos de interés)

**Qué es.** Un primitivo genérico: imagen de fondo + puntos clicables posicionados por datos + visibilidad por flags + un clic dispara una acción. Sustituye la apertura del pueblo como `SCENE_EXPLORATION` (sin jugador, sin física, sin cámara). Naming genérico (`InteractiveScene*`/`InteractiveHotspot*`) a propósito: el mismo primitivo servirá para futuras escenas de "buscar algo en la imagen" (mecánica NO decidida en este spike). Decisiones de Fernando: sin movimiento ni posición de personaje; sistema nuevo y dedicado (`WorldObjectSystem`/`Interactable` no se tocan); visibilidad declarativa, no dinámica por evento. Cerrado y validado en partida real con `poi_test_map`. Detalle en `docs/spike_12_motor_mapa_poi.md`.

**Flujo:**
```
InteractiveSceneView (Button por hotspot visible)
  → InteractiveSceneViewModel.activate_hotspot(id)        [guard: GameState == EXPLORATION]
    → hotspot_activated(interaction_type, target_id, enemy_definitions)
      → ExplorationInteractiveMap (composición, sin lógica)
        → ExplorationController.request_interaction(type, target_id, enemy_definitions)
          → GameLoop.enter_dialogue / enter_shop / start_combat / enter_narrative_scene
```

**Datos** (`core/interactive_scenes/`, JSON en `data/interactive_scenes/`): `InteractiveSceneDefinition` (scene_id, image_path, hotspots) e `InteractiveHotspotDefinition` (vocabulario de salida calcado de `Interactable` + `map_position` normalizada 0–1, `icon_path`, `label_key`, `required_flags`, `blocked_flags`). `item` queda fuera de los tipos válidos en v1 (exige un `WorldObject` registrado). `validate()` marca error por tipo inválido, `label_key`/target vacío o `hotspot_id` duplicado, y warning por posición fuera de 0–1 o icono inexistente. El `ViewModel` avisa al cargar de `scene_id` narrativos inexistentes.

**`ExplorationController.request_interaction()`** es ahora el ÚNICO punto de routing. Tiene guard propio (`is_input_blocked()`) por ser API pública. Para `combat`, `enemy_definitions` llega como parámetro y se copia a `_pending_enemy_definitions` antes de registrar enemigos; confirmado en log: `Enemy definitions loaded: {…: "wolf_test"}` y enemigos pre-registrados con `def: wolf_test`, no `enemy_base`.

**Visibilidad declarativa.** `required_flags` (todos puestos) y `blocked_flags` (ninguno puesto), evaluados contra el autoload `Narrative`. Se recalcula al cargar la escena y en cada `game_state_changed → EXPLORATION` — sin spawn/cleanup por evento ni listeners de `combat_ended`. Un flag puesto sin cambio de estado (p. ej. el atajo F2) no refresca hasta la siguiente vuelta a `EXPLORATION`.

**Escena raíz `exploration_interactive_map`.** `ExplorationController` + `ExplorationHUD` (misma jerarquía de hijos que el HUD del pueblo — usa `$` en `@onready`, falla en `_ready()` si falta alguno) + `MapLayer` (`CanvasLayer` capa -1, oculto en `COMBAT_ACTIVE`/`VICTORY`/`DEFEAT`; comprobado en partida que el mapa no se ve durante el combate). El HUD no necesita `Player`. La escena raíz llama a `exploration_hud.refresh()` en su `_ready()`.

**SaveSystem.** `_collect_player_state()` exigía un nodo `Player` (`_find_player()`) y abortaba el guardado con `Player node not found`; con esta escena habría bloqueado cualquier savepoint (`triggers_save`). Ahora guarda sin la clave `position` si no hay `Player` (clave opcional, `SAVE_VERSION` sin cambios); la restauración ya toleraba un `Player` ausente. Validado: guardado desde el NPC savepoint con el mapa activo (`Game saved successfully`) y "Cargar Partida" que reanuda en `telmori_sheriff_briefing` sobre el mapa.

**Correcciones a lo que se creía antes de la Fase 0:**
- `Interactable` estaba vivo, pero solo con `narrative_scene` y creado por código; el `@export_enum` no lista `narrative_scene`.
- La primera entrada narrativa del pueblo es `_ready()` + `flag.telmori_village_visited` → `enter_narrative_scene("telmori_village_arrival")`, no un `Interactable`.
- `TelmoriVillage._ready()` hace inicialización de partida (`Party.join_party("companion_mira")`, equipo inicial para `player` y `companion_mira`): lógica de juego dentro de una escena.
- El nombre del nodo raíz del `.tscn` de exploración es libre: `SceneOrchestrator` fuerza `name = "ExplorationScene"` al instanciar (solo importa al ejecutar una escena suelta con F6).
- `NarrativeSceneDB` sí es un autoload (`Node` sin estado runtime); `InteractiveSceneDB` sigue el mismo patrón.

**No verificado en partida.** El camino físico de `Interactable` tras el refactor de `ExplorationController` (revisado por inspección, comportamiento idéntico por diseño, pero no jugado de extremo a extremo). F9 queda fuera: no operativo desde el Spike 7. **Spike 13: descartado** — el pueblo no usa `Interactable` y se descartaron el tutorial y el test; no se validará (ver la sección siguiente).

**Pendiente (Spike 13):** *resuelto — ver la sección siguiente.* (Entonces: inicialización de partida fuera de la escena; los 3 spawns por evento del pueblo → hotspots declarativos; un flag de victoria de la emboscada; arte, `UIButton` del Design System y claves de localización reales.)

### Spike 13 — Reautoría del pueblo de "Los Telmori" sobre el motor de escenas interactivas

**Qué es.** Aplica el motor de Spike 12 al contenido real. El pueblo deja de ser una escena 2D con `Interactable` creados por código y pasa a ser un **hub persistente** (`data/interactive_scenes/telmori_village.json`) sobre una ilustración (`mapa_aldea_telmori.jpg`, tinta y aguada sobre pergamino) con cuatro lugares — sheriff, herrería, taberna y salida — que cambian de significado según la etapa de la aventura. `exploration_interactive_map.tscn` carga ahora `telmori_village`; `poi_test_map` queda para pruebas cambiando `interactive_scene_id`. Cerrado y jugado de principio a fin, con validación parcial (ver más abajo). Detalle en `docs/spike_13_reautoria_pueblo_telmori.md`.

**El plan original no era el real.** La spec trataba el mapa como un contenedor para tres hotspots dinámicos (rastro, aftermath, recompensa del sheriff) y planteaba un flag de victoria de la emboscada. El flujo que quería Fernando es un hub: tras la llegada se visita el sheriff, la herrería y la taberna; la salida está visible pero bloqueada hasta aceptar el encargo (y de nuevo hasta cobrar la recompensa), y al ganar un combate se encadena directamente la siguiente escena narrativa en vez de dejar al jugador en el pueblo. Eso cambió el diseño:

| Etapa | Flags activos | Sheriff | Salida |
|---|---|---|---|
| 1 Llegada | — | diálogo (con "aceptar") | aviso: falta aceptar el encargo |
| 2 Encargo aceptado | `flag.telmori_sheriff_briefed` | diálogo (sin "aceptar") | → colinas |
| 3a Emboscada ganada, rastreo fallido | + `flag.telmori_ambush_won` | diálogo | → rastreo |
| 3b Rastro logrado | + `flag.telmori_tracked_to_lair` | diálogo | → puerta de la guarida |
| 4 Guarida limpia | + `flag.telmori_lair_cleared` | recompensa (cadena narrativa) | aviso: falta cobrar |
| 5 Completada | + `flag.telmori_adventure_completed` | diálogo final | → salida final (marcador) |

**Hotspots.** 11 hotspots en 4 posiciones. Los que comparten sitio son mutuamente excluyentes por `required_flags`/`blocked_flags` (comprobado por simulación para las 7 combinaciones de flags: en cada etapa se ve una sola salida y un solo sheriff). No hizo falta motor nuevo para el "visible pero bloqueado": dos hotspots en el mismo sitio, uno de los cuales abre una escena de aviso de un nodo. Con `icon_path` válido salen como `UIButton` solo-icono (medallón) con el nombre en tooltip; sin él, botón de texto.

**Ciclo de combate (cambio de motor).** Con `NarrativeSceneOutcome.combat_victory_scene_id`, ganar el combate abre esa escena narrativa en lugar de volver a `EXPLORATION`: emboscada → `telmori_post_ambush_tracking` → guarida → combate → `telmori_lair_victory` → `telmori_lair_loot_obsidian` → pueblo. Huir devuelve al pueblo, donde la salida de la etapa correspondiente permite reintentar.
- `GameLoop.VALID_STATE_TRANSITIONS`: `VICTORY → [EXPLORATION, NARRATIVE_SCENE]` (**cambio de contrato**).
- `start_combat(enemy_ids, encounter = null, victory_scene_id = "")`. El id vive en `GameLoop._pending_victory_scene_id` — no en `CombatEncounterDefinition`, que puede ser `null` y cuyo `_current_encounter` se limpia en `end_combat()`. `consume_pending_victory_scene()` lo devuelve y vacía; `end_combat()` lo descarta tras emitir `combat_ended` (emisión síncrona), para que no se fugue al combate siguiente.
- `SceneOrchestrator._on_combat_ended`: abre la escena de victoria; si el id **no existe**, `push_error` y vuelve a `EXPLORATION`. Una prueba con un id mal escrito abría un panel narrativo vacío sin salida: softlock justo tras ganar.
- **El defecto de la spec era doble:** `flag.telmori_ambush_triggered` y `flag.telmori_lair_combat_won` (mal nombrado) se ponían al DISPARAR el combate, no al ganarlo. Ya no los pone ni lee nadie. `flag.telmori_ambush_won` lo pone `telmori_post_ambush_tracking` en su salida de fallo (solo se alcanza tras ganar); en la de éxito ya pone `flag.telmori_tracked_to_lair`. `flag_to_set` es un único flag por outcome, así que la visibilidad se diseñó para no necesitar dos.

**Otros cambios de motor.**
- `NarrativeSceneOutcome.take_item_*` (quitar un ítem; desequipa antes). Se usa en `telmori_sheriff_reward_intro` para devolver `enchanted_spear` (préstamo: `quest_loan`, `base_value` 0). Solo cubre una entidad: si la lanza pasa a Mira no se retira.
- `InteractiveSceneDefinition.on_first_visit` + `InteractiveSceneViewModel.request_first_visit()`: acción de una sola vez al entrar por primera vez. Solo en `EXPLORATION`, marca el flag antes de actuar, llamada con `call_deferred` desde el `_ready()` de la escena raíz para que `SceneOrchestrator` termine de atender `EXPLORATION` antes de abrir la escena narrativa. El pueblo abre así `telmori_village_arrival` (`once_flag: flag.telmori_village_visited`), lo que antes hacía `TelmoriVillage._ready()`.
- `AdventureStarter.apply()` + `data/adventures/telmori.json`: companions y kit inicial, una sola vez al confirmar el personaje.
- `UIButton`: `min_square` e `icon_backdrop` (opt-in).
- **Dos mensajes preexistentes al huir, corregidos de paso:** `EXPLORATION → EXPLORATION` (`end_combat("escaped")` ya transiciona a `EXPLORATION` y `_on_combat_ended` repetía `enter_exploration()`) y `ROUND_START → PLAYER_ACTION_SELECT` (la huida se resuelve DENTRO de la señal `player_turn_started`: el combate acaba y `_start_player_turn()` seguía transicionando de fase). Dos guardas de dos líneas.

**Datos.**
- Tienda propia `blacksmith_telmori.tres` (`max_slots` 16): stock de `blacksmith_01` + `enchanted_spear` (valor 0, sale gratis) y 20 `silver_arrow` (2 de oro cada una). El jugador empieza con 50 de oro, suficiente para las flechas.
- Sheriff: el hotspot abre `DLG_TELMORI_SHERIFF_BRIEFING` directamente (la escena narrativa envoltorio ya no se usa). `O4` (aceptar) con `blocked_flags: [flag.telmori_sheriff_briefed]` — flag puesto por `EVT_TELMORI_SHERIFF_BRIEFED`, disparado desde la opción —, nueva opción "Salir", y `O1`–`O3` bloqueadas con la aventura completada. El diálogo tiene guardado (`triggers_save`) y es el punto de guardado del hub. **La etapa 4 no ofrece guardado a propósito:** la cadena de recompensa entrega oro y trofeo al pulsar, y un guardado dentro permitiría cobrar dos veces.
- Escenas narrativas nuevas, editadas y sin uso: ver el árbol. Localización: +19 claves y 3 modificadas (ver el árbol).

**Decisión sobre `Interactable` (punto 6 de la spec).** El pueblo no usa ninguno: un mapa estático no puede tenerlos (sin jugador, física ni proximidad). Fernando descartó `exploration_tutorial` y `exploration_test` (no eran escenas de producción). `Interactable` queda **vestigial**, sin consumidores en el camino jugable, y el camino físico refactorizado en Spike 12 (`request_interaction()`) **nunca se validó en partida real y ya no se va a validar**. Candidato a limpieza en la recopilación final (ver pendientes, punto 10).

**Hallazgos.**
- **Colisión de nombres de fichero:** el diálogo y la escena narrativa del briefing se llamaban igual en carpetas distintas; al copiar el diálogo a `narrative_scenes` se pisó la escena y `NarrativeSceneDB` dio `scene_id vacío`. Los diálogos llevan prefijo `dlg_`.
- **Un `NarrativeScene` con id inexistente abre un panel vacío sin salida desde cualquier origen;** solo se protegió la ruta de victoria. Guarda general pendiente.
- `EVT_TELMORI_SHERIFF_BRIEFED` declara `trigger_type: DIALOGUE_END`, pero la búsqueda no encontró código que consuma `dialogue_ended` para disparar eventos: se disparan desde `narrative_events` de la opción (inferido de la búsqueda de código; el caso contrario no se probó).
- Las "fichas de combate" (`UICombatToken`) no son reutilizables como icono de mapa: están acopladas al combate. Los iconos de hotspot son PNG propios con `UIButton`.
- Los `push_warning`/`push_error` salen en la pestaña Depurador → Errores, no en la salida de texto: los dos mensajes de la huida llevaban ahí desde antes y no aparecían en los logs pegados.

**Validación.**
- **Validado en partida real (Fernando):** la aventura completa sobre el motor nuevo; guardado al final y cierre del juego; la lanza desaparece del inventario al empezar la recompensa; huir de la emboscada devuelve al pueblo y ganar sigue el ciclo definido.
- **Validado por log:** llegada → mapa; kit una sola vez y Mira en el grupo; victoria con escena; huida; id de victoria inexistente (fallback).
- **Sin confirmar:** un segundo punto de guardado distinto (la spec pide dos); ganar un combate sin escena de victoria y la derrota (solo comprobables con `poi_test_map`); lanza equipada frente a vendida; que "Salir" del sheriff no marque `sheriff_briefed`.
- Camino físico de `Interactable`: no validado y descartado.

### ItemCharacterBridge — Aplicación de modificadores

El target de un modificador sigue el formato `tipo.id`:
- `resource.health` → afecta el valor **actual** del recurso (no el máximo)
- `attribute.strength` → modifica el atributo **base** del personaje
- `skill.exploration.lockpick` → modifica el valor de la habilidad (el id puede contener puntos)

Operaciones soportadas: `add`, `mul`, `override`.

Los ítems de tipo `EQUIPMENT` delegan a `EquipmentManager.toggle_equipment()` (equipa si no está equipado, desequipa si lo está) — este es el camino para cuando el **jugador** usa un ítem desde la UI. Para equipar por código (setup inicial, NPCs, etc.), `Equipment.equip_item(entity_id, item_id)` es directo y no exige que el ítem esté en el inventario (aunque añadirlo también, vía `Inventory.add_item()`, mantiene la coherencia si se desequipa más tarde).

Los libros de aprendizaje (`learning_data` en `ItemDefinition`: `skill_id`, `source_level`, `source_type`, y desde Spike 10 `initial_value` opcional) tienen dos caminos según si la entidad ya tiene la skill registrada: si la tiene, crean una `LearningSession` y delegan a `SkillProgression` (tirada de mejora); si no, la **primera lectura la enseña** (`Skills.learn_skill()` + valor inicial, sin tirada de mejora en esa lectura). `_apply_learning()` devuelve `bool`: si el aprendizaje no se pudo aplicar (`invalid_session`, `skill_locked`, `no_progression`, prerrequisitos sin cumplir) el ítem **no se consume** (`item_use_failed`); una tirada de mejora fallida sí lo consume, y `challenge_too_low` también (comportamiento previo, no tocado). Pueden tener también modificadores de recurso adicionales.

### Design System — Componentes reutilizables de UI

Todos los componentes de UI deben usar el Design System centralizado:

- **UITokens** (autoload): Define colores, espaciado y tamaños centralizados
- **UIPanel**: PanelContainer con estilos consistentes — **debe anclarse a un tamaño explícito** cuando contiene texto largo (ver antipatrón nuevo en `athelia_ui_architecture.md`, Spike 3/B); sin anclaje se dimensiona al contenido y puede desbordar la ventana. **Spike 9:** opción `decorative_frame` (false por defecto) que dibuja doble filete + esquineras con `_draw()`; ver sección propia en `athelia_ui_architecture.md`
- **UIButton**: Button con variants (PRIMARY, SECONDARY, etc.) y tamaños. **Spike 13:** `min_square` (botón de solo icono, cuadrado) e `icon_backdrop` (disco oscuro semitransparente tras el icono) — opt-in, apagados por defecto; `variant`/`btn_size`/`min_square` se fijan ANTES de `add_child()` (se leen en `_ready()`). Ver `athelia_ui_architecture.md`
- **UISlot**: Slot de inventario/equipo con drag & drop
- **UIResourceBar**: Barra de recurso (vida, stamina) con valores actuales/máximos
- **UIRadialGauge** (Grupo 5): Anillo de progreso radial parametrizable, un único anillo por instancia — primer componente con `_draw()`/arcos, sin precedente previo en el Design System
- **UICombatToken** (Grupo 5): Ficha de combate (party o enemigo) — compone dos `UIRadialGauge` + relleno central + triángulo de turno + retícula de objetivo. Grupo 4: contorno de texto desde tokens, para leerse sobre fondos de combate claros. **Spike 13:** acoplada al combate (anillos de vida/energía, triángulo de turno, retícula), no es reutilizable como icono de mapa; los iconos de hotspot son PNG propios con `UIButton`
- **Marco decorativo** (Spike 9, cerrado y validado): `UIPanel.decorative_frame` + `corner_texture` (doble filete + esquinera única rotada en las 4 esquinas), tokens `COLOR_FRAME_*`/`FRAME_*` en `UITokens`, arte en `ui/design_system/assets/frames/`. Activado solo en `NarrativeScenePanel`; el resto de pantallas siguen sin marco hasta decisión explícita por pantalla (opt-in)

Ver `docs/athelia_ui_architecture.md` y `README.md` para documentación completa del Design System.

### Patrón MVVM en UI

Toda pantalla de UI sigue el patrón Model-View-ViewModel:

- **ViewModel** (`*_viewmodel.gd`): Lógica de estado, escucha EventBus, emite `changed(reason)`
- **View** (`*_screen.gd` o `*_ui.gd`): Renderiza estado, reacciona a `changed()`, delega acciones al ViewModel
- **Scene** (`*_ui.tscn` o `*_screen.tscn`): Estructura de nodos con `%UniqueNames`

La View **nunca** accede a sistemas core directamente — todo pasa por el ViewModel.

El ViewModel es siempre hijo de la View y muere con ella.

**Nombrado del enum de estado:** nunca `SceneState` — es una clase nativa del motor (la usa `PackedScene`) y el nombre colisiona, con errores de tipado en cascada. Usar `PanelState` u otro nombre específico de la pantalla (lección del Spike 1 Motor Narrativo).

Ver `docs/athelia_ui_architecture.md` para guía completa del patrón.

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

## Notas de convenciones

- Los ficheros `*_bak.gd` y `*_bak.tscn` son backups de versiones anteriores, no están en uso activo.
- Los ficheros `.gd.uid` son metadatos de Godot, no contienen lógica.
- Los `_definition.gd` son Resources estáticos (datos). Los `_state.gd` son Resources dinámicos (runtime). Los `_system.gd` son los sistemas lógicos (autoloads o managers).
- La carpeta `test/` contiene tests unitarios y de integración, no se usa en producción.
- La carpeta `debug/` contiene herramientas de debug no activas en builds de producción.
- La localización cubre ES y EN con ficheros `.csv` compilados a `.translation`. Los `.csv` se registran en Project Settings → Localization → Translations; Godot genera los `.translation` automáticamente al recargar el proyecto.
- Todas las cadenas visibles en UI deben tener su clave en los `.csv` de localización. Nunca hardcodear texto en `.tscn` ni en scripts.
- Los `.tres` son Resources binarios de Godot; los `.json` son datos legibles para narrativa/diálogos/escenas narrativas.
- **Main Scene del proyecto:** `res://ui/main_menu/main_menu_screen.tscn`
- **Autoreferencia por `class_name`:** un script con `class_name X` nunca debe llamar `X.new()` dentro de sí mismo (p. ej. en un factory `from_dict()` estático) — GDScript no lo resuelve de forma fiable y provoca fallos de compilación en cascada que además rompen la resolución del tipo desde otros ficheros. Usar `new()` a secas.
- **Nombres de enum reservados:** nunca nombrar un enum propio `SceneState` — colisiona con una clase nativa del motor.
- **Datos específicos de una aventura (Spike 3, Grupo B):** personajes e ítems propios de una aventura concreta van en su propia subcarpeta por aventura (`data/characters/telmori/`, `data/items/telmori/`), no planos en la raíz de su categoría — salvo ítems de tipo arma con ranura, que se agrupan por tipo de arma por encima de la aventura (`data/items/weapons/<slot>/`). Skills se quedan sin carpeta de aventura al ser categorías generales. Mismo criterio para localización: un CSV propio por aventura (`_telmori.csv`) en vez de añadir al fichero general de la categoría.
- **Kit fijo de skills, siempre desde la `CharacterDefinition`:** nunca duplicar la lista de skills iniciales de una entidad en el código que la registra (ViewModel, PartyManager...) — leer siempre `definition.skills` en el momento de registrar. Una copia paralela se desincroniza en cuanto se edita el `.tres` sin acordarse de la copia.
- **Un listener de reconexión narrativa tras combate debe desconectarse al completar su arco (Spike 3, Grupo C):** `EventBus.combat_ended` es global — un listener que solo comprueba un flag permanente + "¿existe ya el nodo?" no protege contra combates futuros no relacionados una vez el nodo se retira. Desconectar el listener en el mismo punto donde se limpia el interactuable que gestiona.
- **Limpiar un interactuable de reconexión se engancha a `EventBus.narrative_flag_set`, no a `narrative_scene_closed` (Spike 3, Grupo C):** una escena que encadena internamente a otra vía `next_scene_id` no cierra el panel ni emite `narrative_scene_closed` con su propio `scene_id` — el flag que la rama de éxito pone es la señal fiable, independiente de cómo encadene el panel por dentro.
- **`reinforcement_definition_id` no admite tipos mixtos (Spike 3, Grupo C):** un refuerzo entero sale de una única `CharacterDefinition` — si el contenido necesita mezclar tipos de enemigo en la misma oleada, hay que elegir entre extender el recurso a un diccionario o simplificar el contenido a un refuerzo homogéneo.
- **Un campo nuevo en una data class necesita declaración + `from_dict()` en el mismo cambio (Spike 3, Grupo D):** un patch que añade la asignación en `from_dict()` pero pierde la declaración de la variable (o viceversa) no falla en compilación — falla en runtime con "Invalid assignment of property or key" en cuanto se carga el primer JSON que use ese campo. Revisar ambas partes juntas al integrar un patch, no solo la que cambió visiblemente.
- **Un listener de reconexión narrativa disparado por flag (sin combate de por medio) también necesita su propia limpieza (Spike 3, Grupo D):** el riesgo no es "contenido resucitado" (la lección de Grupo C) sino reentrada — un interactuable de recompensa sin retirar permite repetir la entrega de oro/ítems sin límite. Mismo mecanismo de solución (segundo listener de `narrative_flag_set` para el flag de cierre del arco), riesgo distinto.
- **`SkillSystem`/`ItemRegistry` escanean `data/skills/`/`data/items/` recursivamente; `ResourceSystem` no** (Spike 3, Grupo D): antes de añadir un tipo de recurso nuevo (no una skill ni un ítem), comprobar `ResourceSystem._load_resource_definitions()` — su lista de IDs es hardcodeada (`["health", "stamina", "gold"]`), a diferencia de los otros dos catálogos.
- **`ItemDefinition.item_type` es un enum cerrado, sin tipo "genérico decorativo" (Spike 3, Grupo D):** `CONSUMABLE`/`EQUIPMENT`/`MISC` únicamente. Un ítem de botín/trofeo sin mecánica (no se usa, no se equipa) es `MISC`, no `CONSUMABLE` con `usable = false`.
- **Un overlay/subpantalla anidable siempre expone su propia señal `closed`, nunca depende de `tree_exiting` (mejoras post-Spike 3, Grupo 3):** ninguna pantalla del proyecto se auto-libera (`queue_free()`) en su propio camino de cierre — todas solo hacen `visible = false`. Quien la instancia como subpantalla/sub-overlay debe escuchar una señal `closed` explícita y hacer `queue_free()` él mismo; confiar en `tree_exiting` deja el contenedor esperando una señal que nunca llega, con el síntoma de una UI que se queda colgada sin volver atrás (indistinguible de un crash desde fuera, sin ninguna excepción real del motor).
- **Un `_unhandled_input()` que dispara overlays fuera del propio `ExplorationController` necesita el mismo guard de `GameLoop.is_input_blocked()` (mejoras post-Spike 3, Grupo 3):** cualquier segundo punto de entrada de input (como `ExplorationHUD`) que llame directamente a `SceneOrchestrator` sin ese guard procesará el evento aunque el `GameState` no sea `EXPLORATION` — inofensivo si el propio método de destino ya bloquea la llamada, pero genera ruido y es una inconsistencia real frente al resto de handlers de input del proyecto.
- **Una señal global de cierre puede forzar una transición de estado que destruya un contexto anidado activo (mejoras post-Spike 3, Grupo 2):** `SceneOrchestrator._on_dialogue_ended()` escuchaba `EventBus.dialogue_ended` de forma incondicional y forzaba `enter_exploration()` — si el diálogo se abre como sub-overlay desde otro contexto (aquí, `NARRATIVE_SCENE`), esa misma señal global habría destruido el contexto anidado. Cualquier señal de cierre "global" necesita guard explícito por el `GameState` de origen si algo puede abrir esa misma pantalla como sub-overlay desde otro sitio.
- **No asumir que un catálogo de datos nuevo escanea subcarpetas recursivamente solo porque otros catálogos del proyecto lo hacen (mejoras post-Spike 3, Grupo 2):** `SkillSystem`/`ItemRegistry` recursan de verdad (Spike 3, Grupo D); `ResourceSystem` no (lista hardcodeada, también Grupo D); y `DialogueRegistry` tampoco lo hacía hasta este grupo — listaba `data/dialogue/` con `DirAccess`/`list_dir_begin()` sin bajar a subcarpetas, rompiendo en silencio la convención por-aventura al adoptarla por primera vez para diálogo. Comprobar el `_load_*_from_json()` real de cada registry, caso por caso, antes de asumirlo.
- **No asumir que "la entidad ya está registrada" cubre Skills solo porque cubre Characters/Resources (Grupo 5):** `NarrativeSceneViewModel`/`ExplorationController` pre-registran Characters/Resources para enemigos de combate, pero nunca Skills — cualquier pieza nueva que asuma "ya está todo listo" antes de `start_combat()` debe comprobar los tres registros por separado, no dar por hecho que van juntos.
- **Una escena de prueba nueva necesita un nombre de fichero (`.gd` Y `.tscn`) que no coincida con ninguno usado por una escena de producción real (Grupo 5):** sobrescribir por error el script o la estructura de nodos de una escena de producción real (`combat_test.tscn`, apuntada por `SceneOrchestrator.SCENE_COMBAT`) la deja rota hasta que se restaura desde control de versiones. Nombrar explícitamente distinto desde el principio (`combat_production_scene.gd`, no `combat_test_scene.gd`) evita el problema de raíz.
- **Un nodo `Control` vacío sin `_draw()` no se ve, aunque su posición/anchors estén bien** (Grupo 5): tanto la primera vez que una sección de layout se quedó con el tamaño por defecto del editor (40×40, esquina superior-izquierda) como la línea divisoria entre columnas de la arena de combate (`Control` sin script) fallaron por el mismo motivo — un `Control` sin contenido ni `_draw()` propio simplemente no pinta nada, por bien colocado que esté.
- **Reenviar la señal de un autoload a `EventBus` depende de cuántos consumidores reales tiene, no de cuál motivó el hallazgo (Spike 5):** `Find in Files` sobre `EventBus.resource_changed` reveló dos consumidores reales, no uno — reconectar solo el que se detectó primero (`combat_hub_viewmodel.gd`) habría dejado el segundo (`player_menu_viewmodel.gd`) sin arreglar. Con más de un consumidor real, el puente centralizado en el punto de emisión es la opción correcta; con uno solo, la reconexión directa (mismo patrón que `CombatArenaViewModel`) habría sido más simple. Confirmar el número de consumidores reales antes de elegir el mecanismo.
- **Un campo nuevo en un data class no se lee solo por añadirlo al JSON de contenido, si el registry construye cada campo explícitamente (mejoras post-Spike 3, Grupo 1):** `DialogueRegistry._load_option_from_dict()` asigna `id`/`text_key`/`next_node_id`/etc. uno a uno, sin mapeo genérico de claves — añadir `triggers_save` al JSON sin tocar también el registry se habría ignorado en silencio, sin error ni warning. Comprobar siempre el registry/parser real de un dato, no asumir que "está en el JSON" basta.
- **Una transición de `GameState` que nunca se había necesitado puede fallar en silencio (mejoras post-Spike 3, Grupo 1):** `enter_narrative_scene()` llamado desde `MENU` (camino nuevo, antes inexistente) caía en `_can_transition_state() == false` → `push_warning()`, no `push_error()` — fácil de perder en la consola, y sin ningún otro síntoma más que "no pasa nada" en el juego. Cualquier transición de `GameState` nueva (no solo las del código que se está escribiendo) debe verificarse contra `VALID_STATE_TRANSITIONS`, no darse por hecho porque el estado de destino ya existe.
- **Instanciar una escena tarde puede desconectar listeners de continuación que dependen de que existan ANTES de un evento concreto (mejoras post-Spike 3, Grupo 1):** un `EventBus.combat_ended` (u otra señal cualquiera) emitido antes de que su listener se conecte se pierde sin rastro — no hay cola ni replay. Cualquier camino nuevo que permita llegar a un punto del juego (aquí, un combate) sin pasar por la instanciación habitual de una escena puede dejar huérfanos a listeners que esa escena registra en su propio `_ready()`.
- **Corregir un orden de instanciación puede exponer una trampa de reentrada en código que llevaba tiempo sin tocarse (mejoras post-Spike 3, Grupo 1):** un guard de tipo `if current_game_state != X: transicionar_a(X)`, escrito pensando solo en "arrancar la escena sola", puede disparar una transición real e inesperada si esa misma escena se instancia ahora en un momento distinto al que el guard asumía — en este caso, en mitad de la apertura de otro estado (`NARRATIVE_SCENE`), cerrándolo justo después de abrirlo. La condición correcta era más estricta (`== MENU`, el único caso real que el guard necesitaba cubrir) que la que llevaba tiempo en el código (`!= EXPLORATION`).
- **Un campo de nombre "para entidades sin necesidad de él" (Spike 8):** `CharacterState.character_name` solo se rellena para el jugador (Character Creation) o vía `load_save_state()` — su propio docstring ya avisaba de que queda vacío para "enemigos, companions con nombre fijo en su definición", pero nada en el proyecto implementaba de verdad ese fallback a `CharacterDefinition.name_key`. Un comentario que documenta el caso vacío no es lo mismo que código que lo resuelve — comprobar ambos por separado antes de asumir que un campo "vacío a propósito" tiene también su ruta de fallback cubierta.
- **Redimensionar un `Control` cuyo contenido usa desplazamientos en píxeles fijos rompe su layout interno (Spike 8):** `UICombatToken` ancla sus hijos (`TokenVisual`, `HpValueLabel`...) con offsets absolutos calculados para un lienzo exacto de 96×144 — forzar un `.size` real menor vía `custom_minimum_size` descoloca ese contenido (iconos incluidos) en vez de reescalarlo. Arreglo: un `Control` envoltorio es lo que el `Container` redimensiona de verdad; el componente en sí se encoge solo visualmente con `.scale`, sin tocar su propio tamaño real. Ver antipatrón nuevo en `athelia_ui_architecture.md`.
- **Dos caminos para construir el mismo evento divergen — uno gana, el otro se queda incompleto (Spike 8):** `combat_arena_panel.gd` construía su propio `action_data` para `player_action_requested` en vez de llamar a `PlayerCombatController.request_skill()`, el único sitio del proyecto que resuelve el target actual — la copia manual nunca incluía `"target"`. Cualquier punto de entrada nuevo a un despacho ya resuelto en otro sitio debe llamar a su API pública, nunca reconstruir el mismo estado por su cuenta.
- **El orden de conexión entre dos nodos distintos a la misma señal no está garantizado (Spike 8):** el auto-target de `PlayerCombatController._on_combat_started()` (emitido en el mismo instante que `combat_started`) se perdía visualmente si se ejecutaba antes que `CombatArenaViewModel._on_combat_started()` — las fichas aún no existían para recibir la marca de "objetivo". Un consumidor que necesita el estado ya resuelto de otro nodo en el mismo instante de un evento compartido debe consultarlo directamente (`get_current_target()`), no fiarse de recibir también su señal derivada a tiempo.
- **`get_tree().reload_current_scene()` no destruye nodos añadidos directamente a `get_tree().root` (Spike 7):** `SceneOrchestrator` instancia `ExplorationScene` y todos sus overlays (`NarrativeScenePanel`, `CombatHud`...) como hermanos de `current_scene` bajo `root`, no como hijos suyos — un `reload_current_scene()` solo recrea `current_scene` (`MainMenuScreen`). Sin liberar esos nodos explícitamente antes de recargar, el guard de "ya existe, no instanciar otro" de `_ensure_exploration_scene_instantiated()` reutiliza el `ExplorationScene` viejo tal cual, con todo el estado de la sesión anterior — una recarga que parece "limpia" no lo es. Este hallazgo se confirmó y corrigió, pero no fue la causa raíz completa del bug que lo motivó (ver Spike 7 — bug de F9 sin resolver, en la sección "Input en exploración" más arriba).
- **Un bloque perdido al parchear un método grande puede fallar en silencio (Spike 10):** `grant_item_*` desapareció de `_apply_outcome()` sin ningún error — el resto de la cadena funcionaba y solo el inventario vacío lo delataba. Todo efecto de un outcome debe dejar una línea de log al aplicarse, y tras parchear `_apply_outcome()` conviene comprobar por log que cada tipo de entrega sigue apareciendo.
- **Un `.csv` de localización nuevo necesita alta manual en Project Settings → Localization → Translations (Spike 10):** sin ella todas sus claves salen crudas aunque los datos y las claves sean correctos (`items_telmori.csv`). Y todo campo con comas debe ir entrecomillado, o la fila tiene más columnas de las declaradas.
- **Un consumible con efecto condicional no debe emitir `item_use_success` incondicionalmente (Spike 10):** el consumo del ítem cuelga de esa señal. `_apply_consumable()` consumía el libro aunque `execute_learning_session()` hubiera devuelto `skill_locked`; ahora emite `item_use_failed` si el aprendizaje no se aplicó.
- **Un sistema que solo mejora lo que ya existe no cubre "aprender lo nuevo" (Spike 10):** los libros previos solo subían skills ya poseídas, así que `register_entity_skills()` (solo el kit) nunca había fallado. Cualquier fuente que dé algo que la entidad no tiene necesita su propio camino de alta (`learn_skill()`), con persistencia incluida (`load_save_state()` debe poder recrear lo aprendido en runtime).
- **Una señal de GDScript no admite parámetros opcionales, y un dato que viaja fuera de la señal se lee de estado ambiente — degradación silenciosa si falta (Spike 12):** `interaction_requested(type, target_id)` no lleva `enemy_definitions`; `ExplorationController` lo leía del `_current_interactable`. Sin nodo (un hotspot), el combate arrancaba igual pero con todos los enemigos como `enemy_base` — solo un `print`. Un punto de entrada nuevo debe pasar explícitamente todo lo que el camino antiguo obtenía por efecto lateral (`request_interaction()` lo recibe como parámetro).
- **Una API pública necesita su propio guard, aunque el llamador ya lo tenga (Spike 12):** `request_interaction()` comprueba `is_input_blocked()` y el ViewModel exige además `GameState == EXPLORATION` — `is_input_blocked()` por sí solo deja pasar `PAUSE` y `MENU`.
- **Una escena de exploración nueva hereda dependencias invisibles de la anterior (Spike 12):** `SaveSystem._collect_player_state()` exigía un nodo `Player` y abortaba el guardado entero; `ExplorationHUD` exige una jerarquía de hijos exacta (`$` en `@onready`). Antes de sustituir `SCENE_EXPLORATION`, buscar (`Select-String`) quién busca `Player`/grupo `"player"` y qué nodos hijos consumen los scripts compartidos.
- **La documentación del proyecto puede describir el código de forma incorrecta (Spike 12):** decía que el `@export_enum` de `Interactable` incluía `narrative_scene` (no lo incluye) y que el nombre del nodo raíz de exploración debía ser `ExplorationScene` (el orquestador lo fuerza). Una Fase 0 con `Select-String` sobre el proyecto entero antes de diseñar sigue siendo el paso obligado.
- **`user://` no es la carpeta del proyecto (Spike 12):** un fichero de configuración de desarrollo junto a `project.godot` no lo ve `FileAccess` (ver la nota de F2, más arriba).
- **Dos ficheros con el mismo nombre en carpetas distintas se pisan al copiar (Spike 13):** el diálogo y la escena narrativa del briefing eran ambos `telmori_sheriff_briefing.json`; al dejar el diálogo en `narrative_scenes` se sobrescribió la escena y `NarrativeSceneDB` dio `scene_id vacío` (el cargador del registro lo descartó sin tumbar el resto). Los diálogos llevan prefijo `dlg_`.
- **Abrir una escena narrativa con un id inexistente deja un panel vacío sin salida (Spike 13):** softlock justo tras ganar un combate, detectado probando un id mal escrito. Validar el id ANTES de abrir y degradar a `EXPLORATION` (hecho para la ruta de victoria; guarda general pendiente en `_handle_narrative_scene()`).
- **Un dato que debe sobrevivir a una señal síncrona no se guarda en el recurso que se limpia (Spike 13):** la escena de victoria vive en `GameLoop._pending_victory_scene_id`, no en `CombatEncounterDefinition` (puede ser `null`, y `_current_encounter` se limpia en `end_combat()`); se consume durante `combat_ended` y se descarta justo después, para que no se fugue al combate siguiente.
- **Un flag puesto al DISPARAR una acción no demuestra que se haya GANADO (Spike 13):** `telmori_ambush_triggered` y `telmori_lair_combat_won` se ponían al lanzar el combate; solo el `combat_ended "victory"` aparte lo disimulaba. Una puerta de "lo conseguí" necesita un flag puesto por una escena que solo se alcanza al conseguirlo.
- **Un componente del Design System lee sus propiedades en `_ready()` (Spike 13):** `UIButton` aplica `variant`, `btn_size`, `min_square` e `icon_backdrop` en `_apply_style()`, así que se fijan ANTES de `add_child()`; un `custom_minimum_size` puesto antes se pisa en parte (la altura).
- **`push_warning`/`push_error` solo aparecen en Depurador → Errores, no en la salida de texto (Spike 13):** dos mensajes de la huida llevaban ahí desde antes del spike y no se veían en los logs pegados. Para auditar "sin warnings" hay que mirar esa pestaña.

---

*Última actualización: Spike 13 — Reautoría del pueblo de "Los Telmori" sobre el motor de escenas interactivas (cerrado, jugado de principio a fin; validación parcial anotada en la sección propia). El pueblo pasa a ser un hub declarativo (`data/interactive_scenes/telmori_village.json`: 11 hotspots en 4 posiciones, exclusivos por flags según la etapa) sobre una ilustración, con iconos `UIButton` de solo icono. Cambios de motor y de contrato: `VICTORY → NARRATIVE_SCENE` en `VALID_STATE_TRANSITIONS`; `start_combat(..., victory_scene_id)` + `NarrativeSceneOutcome.combat_victory_scene_id` (al ganar se abre una escena narrativa; si no existe, vuelve a `EXPLORATION`); `NarrativeSceneOutcome.take_item_*`; `InteractiveSceneDefinition.on_first_visit` + `request_first_visit()`; `AdventureStarter` + `data/adventures/telmori.json` (kit y companions una sola vez; elimina el kit duplicado); `UIButton.min_square`/`icon_backdrop` (opt-in). Resuelve de paso dos mensajes preexistentes al huir. Decisión: `Interactable` queda vestigial (se descartan el tutorial y el test) y su camino físico nunca se validó. Hallazgos: colisión de nombres de fichero entre diálogo y escena, panel narrativo vacío con id inexistente, flags puestos al disparar en vez de al ganar. Detalle en `docs/spike_13_reautoria_pueblo_telmori.md` y `athelia_pendientes_post_pivote_narrativo.md` (punto 10). Godot 4.7.2.*

*Última actualización anterior: Spike 12 — Motor de escenas interactivas / mapa de puntos de interés (cerrado y validado en partida real con `poi_test_map`: `dialogue`, `shop`, `narrative_scene`, `combat` con `enemy_definitions`, visibilidad por `required_flags`/`blocked_flags`, guardado y carga sin nodo `Player`). Nuevo sistema `core/interactive_scenes/` (`InteractiveSceneDefinition`, `InteractiveHotspotDefinition`, autoload `InteractiveSceneDB`), `ui/interactive_scene/` (ViewModel + View) y `scenes/exploration/interactive_map/` (escena raíz de exploración sin `Player`). `ExplorationController.request_interaction()` pasa a ser el único punto de routing de interacciones (el camino de `Interactable` delega en él); `SaveSystem._collect_player_state()` ya no exige nodo `Player`. `SCENE_EXPLORATION` apunta al mapa de PRUEBA (línea del pueblo comentada, revertible). Fase 0 corrigió cuatro supuestos de la documentación: `Interactable` estaba vivo pero solo con `narrative_scene` creado por código; su `@export_enum` no lista `narrative_scene`; el nombre del nodo raíz de exploración lo fuerza el orquestador; y `TelmoriVillage._ready()` hace inicialización de partida (companion, equipo). Sin verificar en partida: el camino físico de `Interactable` tras el refactor del controlador. Pendiente para el Spike 13: inicialización de partida fuera de la escena, los 3 spawns del pueblo → hotspots declarativos, un flag de victoria de la emboscada, arte/`UIButton`/localización real. Ver `docs/spike_12_motor_mapa_poi.md` para el detalle completo. Godot 4.7.2.*

*Última actualización anterior: Spike 11 — Rediseño de la ventana de diálogo (fondo, retrato, estado de ánimo) — cerrado y validado en partida real de principio a fin, apertura desde escena narrativa y desde `EXPLORATION`. `DialogueNodeDefinition` gana `mood`; `DialogueDefinition` gana `portrait_folder` y `background_id`; `EventBus.dialogue_node_shown` pasa de 4 a 7 argumentos. `DialoguePanel` migra de `PanelContainer` plano a `UIPanel` (marco del Spike 9) — cierra el pendiente que dejó abierto ese spike para esta pantalla. Antipatrón nuevo: un `PanelContainer` no se encoge por debajo del mínimo de sus hijos, así que las opciones de diálogo necesitan `ScrollContainer` si su número puede variar — mismo problema de fondo que "Panel sin tamaño fijo con texto largo", por número de hijos en vez de longitud de texto. Ver `spike_11_ventana_dialogo.md` para el detalle técnico completo (maqueta de layout, catálogo de estados de ánimo, cascadas de respaldo). Godot 4.7.2.*

*Última actualización anterior: Spike 10 — Diálogos restantes del sheriff (cerrado, camino A, validado en partida real). `telmori_sheriff_reward_intro` y `telmori_sheriff_training` abren `DLG_TELMORI_SHERIFF_REWARD`/`_TRAINING` como sub-overlay con las entregas en el mismo outcome (el diálogo solo conversa; `DialogueOptionDefinition`/`DialogueSystem` no tienen entregas y no se ampliaron); Grupo 2 completo. Dos fallos de motor previos destapados por la validación: `grant_item_*` se había perdido de `NarrativeSceneViewModel._apply_outcome()` (ningún ítem llegaba al inventario, sin error visible) y un libro no podía enseñar una skill fuera del kit inicial, consumiéndose sin efecto — nuevo `SkillSystem.learn_skill()`, `initial_value` en `learning_data`, `load_save_state()` que recrea skills aprendidas y consumo del libro condicionado a que el aprendizaje se aplique. Localización completada (escenas del Grupo D, escena de botín, flechas/lanza de Grupo B) y alta de `items_telmori.csv`. Sin probar en partida: camino de fallo del libro y guardado/carga con Curtido. Ver `docs/spike_10_dialogos_sheriff.md`. Godot 4.7.2.*

*Última actualización anterior: Spike 9 — Marco decorativo de ventana en `UIPanel` (Design System). `decorative_frame` (false por defecto) + `corner_texture`: doble filete dibujado con `_draw()` sobre el propio panel (un `StyleBoxFlat` solo admite un borde de un color) y una única esquinera rotada 0°/90°/180°/270° con `draw_set_transform()`. Con el marco activo el panel anula su borde y `corner_radius`. Siete tokens nuevos en `UITokens` (`COLOR_FRAME_*`, `FRAME_*`) y arte en `ui/design_system/assets/frames/` (64×64 en uso; 96×96 de reserva por invadir el texto). Respuestas a las dos preguntas de integración de la spec: opt-in (ningún panel en producción cambia de aspecto) y `NarrativeScenePanel` ya usaba `UIPanel`, así que se activó solo desde el inspector, sin tocar su script. Validado: panel narrativo con marco correcto en las 4 esquinas; ventana de inventario sin cambios. Ver `docs/spike_9_marco_decorativo_ui_panel.md`. Godot 4.7.2.*

*Última actualización anterior: Spike 8 — UI/UX de combate (cinco puntos de alcance
cerrados y validados en combate real contra un grupo de 6-8 lobos). Punto 1
(ficha de `companion_mira` con `??`) y Punto 2 (log con IDs internos en vez
de nombres localizados) resultaron compartir exactamente la misma causa,
confirmada por código antes de tratarlos como un único arreglo:
`_initials_for()`/`_display_name()` en `combat_arena_viewmodel.gd` solo
leían `CharacterState.character_name` (vacío para toda entidad no-jugador
por diseño) sin caer a `tr(CharacterDefinition.name_key)` como fallback —
arreglado con esa jerarquía de resolución (nombre elegido > nombre fijo de
definición). Punto 3 (los 8 botones del menú de acciones nunca mostraban
nombre) resultó no ser un bug de código: `combat_hud_viewmodel.gd`/
`combat_arena_panel.gd` leían fielmente un `LoadoutState` del jugador que
nunca había sido asignado — confirmado con capturas de la propia pantalla
de Loadout mostrando los 8 slots vacíos. De paso, un doble-`tr()` real (sin
efecto visible) en `loadout_viewmodel.gd`. Punto 4 (columna de enemigos
desbordada con 6-8 fichas): un primer intento de redimensionar
`UICombatToken` directamente resultó incorrecto (su anclaje interno usa
píxeles fijos calculados para 96×144 — confirmado en playtest por iconos
descolocados) y se sustituyó por el patrón correcto de Control envoltorio +
`.scale`, sin tocar el tamaño real del token. Punto 5, no listado en el spec
original y añadido durante la sesión al bloquear la validación del Punto 4:
"No target specified" al atacar — causa real, `combat_arena_panel.gd`
duplicaba (incompleto, sin `"target"`) el despacho que
`PlayerCombatController.request_skill()` ya resolvía bien; arreglado
delegando en él. Expuso un segundo hallazgo encadenado: el auto-target de
`PlayerCombatController` se perdía visualmente por orden de señales entre
nodos distintos, corregido sincronizando el objetivo directamente en
`CombatArenaViewModel._on_combat_started()`. Dos antipatrones nuevos de
arquitectura UI documentados en `athelia_ui_architecture.md`. Ver
`docs/spike_8_ui_ux_combate.md` para el detalle completo. Godot 4.7.2.

*Última actualización anterior: Spike 7 — F9 quickload en EXPLORATION (cerrado sin
arreglo, funcionalidad NO OPERATIVA). El síntoma original documentado (bloqueo
total de input) no se reprodujo tras el pivote narrativo — resultó ser un bug
distinto: F9 en sesión activa cargaba los datos del save pero no consumía
`SaveManager.get_pending_narrative_scene_id()`, dejando al jugador en
`EXPLORATION` en vez de en el punto narrativo correcto. Arreglado
centralizando la decisión en `GameLoopSystem.enter_post_load_state()`, usado
tanto por `MainMenuViewModel.request_load_game()` como por
`ExplorationController._quickload()`. Ese arreglo destapó un segundo bug que
quedó sin resolver: el panel narrativo correcto se abre pero su botón no
responde a clics, únicamente cuando la carga ocurre en sesión activa tras
combate (nunca desde el menú principal). Investigación extensa sin causa raíz
encontrada — descartados GameState, árbol pausado, ratón capturado,
`mouse_filter`/`focus_mode`, nodos residuales de UI, `mouse_passthrough`, y
cualquier autoload con `_input()`/`_unhandled_input()` (ninguno lo tiene).
Hallazgo real y confirmado de camino (ver "Lecciones aprendidas" más abajo):
`ExplorationScene` y sus overlays viven como hermanos de `current_scene` bajo
`get_tree().root`, invisibles a `get_tree().reload_current_scene()` —
corregido liberándolos explícitamente antes de recargar, pero el bug de fondo
persistió incluso así. `_quickload()` se reenfocó por completo: ya no carga en
caliente, marca la intención en `SaveManager` (`request_pending_quickload()`)
y recarga la escena; `MainMenuViewModel._ready()` consume ese flag
(`consume_pending_quickload()`) y dispara la carga real por el único camino
que funciona de forma fiable. **Decisión: F9/quickload en sesión activa queda
no operativo**, pendiente decidir si se retira la hotkey; "Cargar Partida"
desde el menú no está afectada. Hallazgo colateral, no relacionado:
`PartyManager` no limpia su lista de companions al cargar partida (warning
`'companion_mira' already in party`, reproducido también desde el menú). Ver
`docs/spike_7_f9_quickload_exploration.md` para el detalle completo. Godot
4.7.2.

*Última actualización anterior: Spike 6 — Investigación de motor de combate (los dos
puntos de alcance investigados y cerrados, sin necesidad de spike aparte para
ninguno). Punto 1: dos bugs independientes bajo el mismo síntoma (número
mostrado ≠ número real). Sub-bug A, el desync `50/60`/`50/45` original —
causa raíz: `ModifierApplicator` solo sincroniza `max_effective` como efecto
de `Characters.set_base_attribute()`, y el único caller de eso en todo el
proyecto era `character_creation_viewmodel.gd` para `"player"` — enemigos,
refuerzos y companions se registran vía `register_entity()` directo, sin
pasar nunca por ahí. El "50" del patrón reportado era además literal:
`exploration_controller.gd`/`narrative_scene_viewmodel.gd` fijaban el HP
inicial de cada enemigo a `50.0` hardcodeado. Arreglado sincronizando dentro
de `ResourceSystem.register_entity()` mismo (Opción B, elegida sobre arreglar
cada punto de registro por separado — 4 call sites confirmados, 3 de ellos
bugueados, 2 con código duplicado línea por línea — para cerrar el gap de
raíz en vez de depender de que cada spawner futuro se acuerde), con guard
defensivo y orden de registro corregido en `combat_production_scene.gd`
(refuerzos). Sub-bug B, hallazgo ampliado del cierre de Spike 5 en
`player_menu` — sin relación con el sub-bug A: `player_menu_viewmodel.gd`
leía el HP/EN actual desde `CharacterState.get_resource()`, un accesor
fósil congelado desde la creación del personaje (mismo patrón que
`skill_values` vs. `SkillSystem._entity_skills` de Spike 3/Grupo B), en vez
del estado vivo de `ResourceSystem`. Punto 2: `Invalid transition: ROUND_END
→ TURN_END` y rondas que saltan número — confirmado que afecta al contador
real (`round_number`, usado por refuerzos temporizados), no es cosmético.
Causa raíz: `_transition_to_phase()` no devolvía éxito/fracaso y ningún
llamador comprobaba el resultado antes de seguir — ver nota propia en
"GameLoop — Estados y fases de turno" más abajo. Disparador exacto de la
doble invocación no confirmado al 100%; candidato identificado y mitigado
con una comprobación de actor nueva en `_on_combat_action_completed()`.
Nuevo test de regresión sin necesitar combate real,
`test/test_spike6_investigacion.gd` (8/8 asserts). Validado en varias
partidas reales completas, refuerzos incluidos. Quedan sin tocar, sin
decisión de Fernando: typo `combat_scape`/`combat_escape`, puente
`resource_changed`→`EventBus.resource_changed`, fuga de memoria ya
mitigada, `combat_resolver.gd` código muerto sospechoso (los 4 hallazgos de
motor de Grupo 5 restantes). Ver `docs/spike_6_investigacion_motor_combate.md`
para el detalle completo. Godot 4.7.2.

*Última actualización anterior: Spike 5 — Arreglos rápidos de motor. Cinco bugs de
motor preexistentes cerrados, documentados como pendientes desde el
Grupo 5 de mejoras post-Spike 3, sin dependencias cruzadas entre sí.
Typo `combat_escape`→`combat_scape` corregido en `combat_hud.gd` (consenso
de dos consumidores + documentación). Puente
`ResourceSystem.resource_changed` → `EventBus.resource_changed` añadido en
`_emit_resource_changed()`: Find in Files confirmó dos consumidores reales
(`combat_hub_viewmodel.gd`, `player_menu_viewmodel.gd`), no uno, así que el
mecanismo elegido fue el reenvío centralizado en el punto de emisión y no
la reconexión de un único consumidor. `telmori_lair_loot_obsidian.json.json`
renombrado sin referencias que actualizar.
`CharacterDefinition.duplicate_definition()` gana los cuatro campos que le
faltaban (`token_color`, `type_icon`, `starting_skill_values`,
`loot_table_id`), sin efecto observable todavía (sin llamada real en el
proyecto). `combat_resolver.gd` eliminado — código muerto confirmado dos
veces (Grupo 5 y de nuevo en este spike), sin ningún fichero activo que lo
referenciara. Hallazgo no anticipado, movido a Spike 6/7: desync
PV/EN confirmado en pantalla real en `player_menu` (ya listado como fuera
de alcance de este spike). Validado jugando la aventura completa de "Los
Telmori" de principio a fin, sin errores ni warnings nuevos. Ver
`docs/spike_5_arreglos_motor_informe_cierre.md` para el detalle completo.
Godot 4.7.2.

*Última actualización anterior: Mejoras post-Spike 3, Grupo 4 — Arte narrativo. Layout narrativo B1 (imagen a pantalla completa, panel en el tercio inferior; solo `.tscn`, el `SceneImage` original con `expand_mode` por defecto habría reventado el panel con cualquier imagen real). Fondo de combate por encuentro (`CombatEncounterDefinition.background_path`, `GameLoopSystem.get_current_encounter()`, `CombatArenaViewModel.background_texture`), con mapas de batalla cenitales en vez de reutilizar las láminas de escena; velo de la arena a 0.2 y contorno de texto en fichas y log (tokens nuevos en `UITokens`). `image_path` validado al cargar. Bug preexistente corregido: fichas enemigas sin `fill_color` (blancas) y centinela `Color.BLACK` de `token_color` ignorado. Iconos de tipo reales para todas las variantes Telmori y `wolf_gray`. Cuatro hallazgos preexistentes documentados sin corregir (botones de acción sin nombre, desborde de la columna enemiga, IDs sin localizar en el log, desajuste PV). Spike de marco decorativo de `UIPanel` aparcado. Validado en partida completa de "Los Telmori". Ver `docs/mejoras_grupo4_arte_narrativo_informe_cierre.md` para el detalle completo. Godot 4.7.2.

*Última actualización anterior: Mejoras post-Spike 3, Grupo 1 — Guardado de partida. Corrige un supuesto erróneo de la documentación anterior: `SaveManager` ya guardaba flags/variables/eventos/checkpoints/party antes de este grupo; el hueco real era solo "a qué escena narrativa volver al cargar". Guardar deja de ser hotkey libre (F5, retirado) — solo se guarda vía opción de diálogo (`DialogueOptionDefinition.triggers_save`, nuevo) ofrecida por NPCs savepoint concretos dentro de una escena narrativa; F9 (cargar) sin cambios. `SaveData.narrative_state` gana `current_narrative_scene_id`, `SAVE_VERSION` 5→6 con migración; `MainMenuViewModel.request_load_game()` decide `enter_narrative_scene()` vs `enter_exploration()` según `SaveManager.get_pending_narrative_scene_id()`. Dos hallazgos no anticipados por el spec, ambos corregidos: `MENU → NARRATIVE_SCENE` no existía en `VALID_STATE_TRANSITIONS` (fallaba en silencio, solo `push_warning()`); y `ExplorationScene` podía no estar instanciada todavía cuando un combate terminaba tras cargar directo en `NARRATIVE_SCENE`, perdiendo listeners de continuación de contenido (ej. "Rastros" tras la emboscada) — corregido con `SceneOrchestrator._ensure_exploration_scene_instantiated()`, lo que a su vez expuso una trampa de reentrada en `TelmoriVillage._ready()` (guard de estado demasiado laxo, corregido a `== MENU`). Nuevo atajo de desarrollo configurable (tecla F2, `user://debug_shortcut.json`), detrás de `OS.is_debug_build()`. Validado en partida real completa de "Los Telmori", de principio a fin, incluido el combate final de la guarida. Ver `docs/mejoras_grupo1_guardado_informe_cierre.md` para el detalle completo. Godot 4.7.2.

*Última actualización anterior: Mejoras post-Spike 3, Grupo 5 — Pantalla de combate de producción. Sustituye la pantalla de test (`combat_test_scene`/`combat_hud.tscn`) por una real: `UIRadialGauge`/`UICombatToken` (Design System), `CombatArenaViewModel` (compone a `CombatHudViewModel` existente, primer caso de composición de ViewModels del proyecto) + `CombatTokenData`/`LogEntryData`, `CombatArenaPanel` (fichas dinámicas party/enemigo, log narrado, menú de 8 acciones), `combat_production_scene.gd` (nueva pieza sin UI que sustituye a `combat_test_scene.gd` como `SceneOrchestrator.SCENE_COMBAT`). Varios bugs de motor preexistentes encontrados, algunos corregidos (payload de dodge sin `actor`, posición de damage number para fichas `Control`, Skills nunca registrado para el roster inicial de enemigos) y otros solo documentados (puente roto `ResourceSystem.resource_changed`→`EventBus`, typo `combat_escape`/`combat_scape`, fuga de la instancia de `SCENE_COMBAT` en `SceneOrchestrator`, desconexión `AttributeResolver`/`ResourceState.max_effective`). Validado jugando la aventura completa de "Los Telmori" de principio a fin, refuerzos reales incluidos. Ver `docs/mejoras_grupo5_combate_produccion_informe_cierre.md` para el detalle completo. Godot 4.7.2.

*Última actualización anterior: Mejoras post-Spike 3, Grupo 2 — Diálogo con NPCs desde narrativa. `NarrativeSceneOutcome` gana `dialogue_id`, resuelto como sub-overlay de `DialoguePanel` (mismo patrón de Grupo 3, ahora extendido a Diálogo) con reenganche automático vía `resume_after_dialogue()` reutilizando `next_scene_id` con significado condicional. Hallazgo crítico corregido: `SceneOrchestrator._on_dialogue_ended()` forzaba `enter_exploration()` de forma incondicional vía señal global, lo que habría roto cualquier escena narrativa con un diálogo abierto como sub-overlay — ahora gateado a `GameState.DIALOGUE`. Bug de motor preexistente encontrado y corregido: `DialogueRegistry` no escaneaba subcarpetas, a diferencia de `SkillSystem`/`ItemRegistry`. Validado en partida real contra `sheriff_briefing` de "Los Telmori". Ver `docs/mejoras_grupo2_dialogo_narrativa_informe_cierre.md` para el detalle completo. Godot 4.7.2.

*Última actualización anterior: Mejoras post-Spike 3, Grupo 3 — Overlays de inventario/party/stats durante narrativa. `NarrativeScenePanel` gestiona Inventory/Party/PlayerMenu como sub-overlay propio (hijo directo, nunca vía `SceneOrchestrator`), evitando así el slot único de `SceneOrchestrator._current_overlay` (hallazgo no anticipado por el spec: abrirlos por el camino normal habría destruido el panel narrativo y su ViewModel). `NarrativeSceneViewModel` gana tres intenciones nuevas sin tocar `current_node` ni la racha en curso. Dos bugs de motor preexistentes encontrados y corregidos en la validación, ninguno introducido por este grupo: cuatro pantallas (`InventoryUI`/`PlayerMenuScreen`/`LoadoutScreen`/`SkillTreeScreen`) no se auto-liberaban al cerrarse, dejando `tree_exiting` sin disparar nunca y la navegación anidada colgada sin vuelta atrás — arreglado con una señal `closed` explícita en las cuatro; y `ExplorationHUD._unhandled_input()` no respetaba `GameLoop.is_input_blocked()`, a diferencia de `ExplorationController`. Ver `docs/mejoras_grupo3_overlays_narrativa_informe_cierre.md` para el detalle completo. Godot 4.7.2.

*Última actualización anterior: Spike 3, Grupo D — Cierre (los cinco puntos de alcance cerrados y validados en partida completa) — recompensa multicapa (bounty, trofeo, venta de pieles con Curtidor real sin gating de visibilidad nuevo); nuevo campo "otorgar recurso" en `NarrativeSceneOutcome`/`_apply_outcome()`, análogo a "otorgar ítem"; botín mágico de la guarida entregado vía el mecanismo de otorgar ítem ya existente; reflavor del entrenamiento de magia como tomo de habilidad; nuevo patrón de reconexión narrativa sin combate de por medio, con su propio riesgo de exploit económico identificado y cubierto por diseño. **Con este grupo, "Los Telmori" es jugable de principio a fin.** Dos bugs reales encontrados y corregidos en la validación: declaración de propiedad perdida en un patch de `NarrativeSceneOutcome` (runtime error, no de compilación), y un JSON de contenido desactualizado en el proyecto tras diseñar la cadena de botín en conversación (detectado por el `scene_id` de `narrative_scene_closed` en el log). Ver `docs/spike_3_grupoD_cierre_informe_cierre.md` para el detalle completo. Godot 4.7.2.

*Última actualización anterior: Spike 3, Grupo C — La guarida (los cinco puntos de alcance cerrados y validados en partida completa, ambas ramas) — fusión de las dos salas de la aventura original en un combate por rama en vez de rutas separadas; `group_aggregate="worst"` para la tirada de sigilo, confirmado por la propia transcripción; nueva skill `skill.exploration.stealth`; modificador multiplicativo de combate decidido explícitamente no implementarlo; `EnemyWorldLink` confirmado innecesario en esta aventura. Cuatro bugs de motor preexistentes encontrados y corregidos, todos en la reconexión narrativa tras combate: encadenado suelto en el cierre de Grupo B, ausencia de reconexión tras el segundo combate del proyecto, listener de `combat_ended` que nunca se desconectaba y resucitaba interactuables retirados, y limpieza enganchada a una señal que no se emite cuando una escena encadena internamente a otra. Ver `docs/spike_3_grupoC_guarida_informe_cierre.md` para el detalle completo. Godot 4.7.2.

*Última actualización anterior: Spike 3, Grupo B — Del pueblo a la puerta de la guarida (los cinco puntos de alcance cerrados y validados en partida completa) — otorgar-ítem y combate opcional en `NarrativeSceneOutcome`; sorpresa de combate vía buffs existentes sin tocar turn_order; investigación por capas y rastreo acumulativo sobre contenido real; nuevo `interaction_type` "narrative_scene"; primera escena de exploración de producción real (`exploration_telmori_village`); varios bugs de motor preexistentes encontrados y corregidos (cuelgues de turno en STAGGERED/DISARMED, registro de enemigos en combate narrativo, reinicio tras Game Over, panel narrativo sin tamaño fijo, doble sistema de skills desincronizado). Ver `docs/spike_3_grupoB_pueblo_guarida_informe_cierre.md` para el detalle completo. Godot 4.7.2.

*Última actualización anterior: Spike 3, Grupo A — Motor y limpieza (los tres puntos del alcance cerrados y validados) — moral de grupo con base dinámica (`_group_morale_base_hp`, recalculada al llegar un refuerzo, nunca golpe a golpe, validada contra los dos ejemplos numéricos de la spec en `test/test_group_morale.gd`); nuevo autoload `EnemyWorldLink` como hueco genérico de limpieza para enemigos que huyen; retirada completa del andamiaje de Spike 1 (tecla F1, JSON de prueba, claves de localización de test) con su hueco de test cubierto en `test/test_narrative_scene_viewmodel.gd` (fixtures en código, sin JSON ni registry). Un hallazgo de GDScript nuevo: un enum anidado en otra clase no se puede anotar como tipo explícito de forma fiable, y un fallo de compilación (o una sobrescritura accidental) en el script dueño de un `class_name` se manifiesta como "Identifier not declared" en cualquier fichero que lo consuma, no en el fichero real con el problema. Ver `docs/spike_3_grupoA_motor_limpieza_informe_cierre.md` para el detalle completo. Godot 4.7.2.

*Última actualización anterior: Spike 2 — Reglas de RuneQuest para el Motor Narrativo (seis de seis puntos del alcance cerrados y validados) — `SkillRoller.RollResult` a 5 grados con `CRITICAL`/`SPECIAL` dinámicos (skill/20, skill/5); progresión de skill narrativa vía `SourceType.NARRATIVE`; tiradas acumulativas con contador de racha en el ViewModel; tiradas agregadas de grupo sin tabla de resistencia (oposición codificada en `roll_modifier`); moral de grupo y refuerzos cronometrados en combate vía `CombatEncounterDefinition` (nuevo, opcional en `start_combat()`) y `GameLoopSystem.configure_active_encounter()`. Modificador dinámico multiplicativo de combate aplazado a Spike 3 por falta de caso real. Dos hallazgos de GDScript reutilizables: un `match` sin rama `_:` y un array indexado por enum no avisan si el enum crece sin revisar todos sus consumidores. Ver `docs/spike_2_reglas_runequest_informe_cierre.md` para el detalle completo.

*Última actualización anterior: Spike 1 Motor Narrativo (pivote hacia RPG narrativo) — nuevo sistema `core/narrative_scenes/` + `ui/narrative_scene/` (patrón MVVM, sin system runtime propio, solo registry síncrono), `GameState.NARRATIVE_SCENE` añadido a GameLoop con integración de combate y cierre desacoplado vía EventBus, escena de prueba desechable y tecla de debug F1 temporal en ExplorationController. Dos lecciones de GDScript registradas (self-reference por class_name, colisión de SceneState con clase nativa) y una de testing (nodo raíz "ExplorationScene" requerido para ejecutar exploration_test.tscn suelto). Spike Producción Post-Character-Creation (Grupo A) — escena de exploración de producción (`exploration_tutorial.tscn`), registro en frío de Resources/Skills en `load_game()`, nombre de personaje visible en PlayerMenuScreen. Pendientes abiertos: posición no restaurada en arranque en frío, bloqueo de input tras F9 en caliente, limpieza de `player.gd` aparcada. Godot 4.7.1.*
