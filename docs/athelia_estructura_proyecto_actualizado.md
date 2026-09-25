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
| `Resources` | `core/resources/resource_system.gd` | Gestión de recursos vitales (vida, stamina, oro). |
| `Skills` | `core/skills/skill_system.gd` | Sistema de habilidades: registro, acceso y uso. `SkillRoller` (no autoload, `class_name` estático) resuelve las tiradas D100: 5 grados desde Spike 2 (`FUMBLE/FAILURE/SUCCESS/SPECIAL/CRITICAL`), con `CRITICAL`/`SPECIAL` dinámicos (skill/20, skill/5) y `FUMBLE` absoluto (≥98). |
| `SkillProgression` | `core/skills/skill_progression_service.gd` | Progresión y aprendizaje de habilidades. |
| `SkillEventHandler` | `core/skills/skill_event_handler.gd` | Manejo de eventos relacionados con habilidades. |
| `Stress` | `core/skills/stress_system.gd` | Sistema de estrés del personaje. |

### Sistemas de ítems y equipo
| Singleton | Script | Descripción |
|-----------|--------|-------------|
| `Items` | `core/items/item_registry.gd` | Registro global de definiciones de ítems. |
| `Inventory` | `core/items/inventory_system.gd` | Gestión del inventario del jugador. |
| `Equipment` | `core/items/equipment_manager.gd` | Gestión del equipo equipado por el personaje. |
| `Bridge` | `core/items/item_character_bridge.gd` | Adaptador puro entre el sistema de ítems y los sistemas de personaje/recursos. Escucha `item_use_requested` y aplica los modificadores del ítem sobre `Characters`, `Resources` o `Skills` según el tipo (`CONSUMABLE` / `EQUIPMENT`). También gestiona libros de aprendizaje delegando a `SkillProgression`. No modifica `ItemSystem`, `CharacterSystem` ni `InventorySystem` directamente. |

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
│   ├── game_loop_system.gd         # [Autoload: GameLoop] Máquina de estados global + fases de turno
│   ├── scene_orchestrator.gd       # [Autoload: SceneOrchestrator] Gestión de overlays y escenas
│   │
│   ├── characters/                 # Sistema de personajes
│   │   ├── character_system.gd     # [Autoload: Characters]
│   │   ├── character_definition.gd # Resource: definición estática del personaje — Grupo 5: + token_color (Color, centinela Color.BLACK) y type_icon (Texture2D), color de relleno e icono de tipo de la ficha en la arena de combate
│   │   ├── character_state.gd      # Resource: estado en tiempo de ejecución
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
│   │   ├── item_character_bridge.gd        # [Autoload: Bridge] Adaptador entre ítems y Character/Resources/Skills
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
│   │   └── narrative_scene_outcome.gd      # Resource: destino/consecuencias — Spike 3/B: + combat_encounter (CombatEncounterDefinition opcional), combat_enemy_definitions (mapeo enemy_id→definition_id, necesario porque combate disparado desde narrativa no tiene Interactable del que leerlo), grant_item_id/quantity/target
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
│   │   ├── skill_system.gd         # [Autoload: Skills]
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
│   │       └── [otros portraits...]
│   │
│   ├── combat/                     # ← NUEVO (mejoras post-Spike 3, Grupo 4)
│   │   └── backgrounds/
│   │       └── telmori/            # Mapas de batalla cenitales (tinta y aguada sobre pergamino, sin cuadrícula), uno por encuentro, referenciados por combat_encounter.background_path: telmori_battle_forest (emboscada), telmori_battle_lair (guarida)
│   │
│   ├── dialogue/                   # Ficheros JSON de diálogos
│   │   ├── dialogue_prince_intro.json
│   │   ├── dlg_companion_mira_01.json
│   │   ├── dlg_maestro_01.json
│   │   ├── dlg_trainer_01.json
│   │   └── [otros diálogos...]
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
│   │   └── images/
│   │       └── telmori/            # ← NUEVO (Grupo 4): fondos de escena 16:9, catálogo reutilizable por TIPO de escenario, no por escena (telmori_bg_village.jpg y demás)
│   │
│   ├── resources/                  # Definiciones de recursos
│   │   ├── gold.tres
│   │   ├── health.tres
│   │   └── stamina.tres
│   │
│   ├── shops/                      # Definiciones de tiendas
│   │   └── blacksmith_01.tres
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
│   └── mejoras_grupo5_combate_produccion_informe_cierre.md  # ← NUEVO: pantalla de combate de producción completa — UIRadialGauge/UICombatToken, CombatArenaViewModel/Panel, combat_production_scene.gd, integración real en SceneOrchestrator, jugado de principio a fin en "Los Telmori"
│
├── localization/                   # Sistema de localización (ES/EN)
│   ├── translations.csv            # Textos generales
│   ├── translations.en.translation
│   ├── translations.es.translation
│   ├── dialogues.csv               # Textos de diálogos
│   ├── dialogues.en.translation
│   ├── dialogues.es.translation
│   ├── items.csv                   # Nombres y descripciones de ítems — Spike 3, Grupo D añade ITEM_BOOK_TANNING_NAME/DESC (libro sin ranura, en el CSV general, no en items_telmori.csv — misma práctica que silver_arrow/enchanted_spear de Grupo B)
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
│   ├── narrative_scenes_telmori.csv    # Spike 3, Grupo B (22 claves) + Grupo C (7 más, 29 en total) + Grupo D (6 escenas + prompt del interactuable del sheriff) — CSV propio por aventura
│   ├── narrative_scenes_telmori.en.translation
│   ├── narrative_scenes_telmori.es.translation
│   ├── characters_telmori.csv          # Spike 3, Grupo B — nombre/desc de telmori_warrior/wolf
│   ├── characters_telmori.en.translation
│   ├── characters_telmori.es.translation
│   ├── items_telmori.csv               # ← NUEVO (Spike 3, Grupo D) — nombre/desc de telmori_magic_bag, obsidian_spearhead, wolf_tail_trophy (botín/trofeo, sin ranura). Requiere alta manual en Project Settings → Localization → Translations, igual que narrative_scenes_telmori.csv en su momento
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
│   │   ├── exploration_test.tscn    # sandbox de desarrollo — nodo raíz debe llamarse "ExplorationScene" para que SceneOrchestrator._handle_exploration() lo reconozca al ejecutarlo suelto (F6); si no, intenta instanciar otra copia de la escena de producción encima y crashea ("Parent node is busy setting up children")
│   │   ├── exploration_test.gd
│   │   ├── exploration_controller.gd  # Input de exploración (interact, inventory, party, player_menu, F9 quickload) — tecla F1 de debug de Spike 1 retirada en Spike 3, Grupo A; Spike 3/B: _on_interaction_requested() gana el caso "narrative_scene" (ver Interactable abajo); mejoras post-Spike 3, Grupo 1: F5 (quicksave) retirado por completo, sustituido por tecla de debug F2 configurable por fichero (user://debug_shortcut.json)
│   │   ├── exploration_hud.gd
│   │   ├── player_exploration.gd
│   │   ├── companion_follow_node.gd
│   │   ├── interactable.gd            # interaction_type: "dialogue"/"shop"/"combat"/"item"/"narrative_scene" (el último, Spike 3/B — antes solo existía como tecla de debug temporal en Spike 1, ya retirada)
│   │   │
│   │   ├── tutorial/                # zona de producción original (mini-tutorial) — OBSOLETA desde Spike 3/B, pendiente de retirar
│   │   │   ├── exploration_tutorial.tscn
│   │   │   └── exploration_tutorial.gd
│   │   │
│   │   └── telmori_village/         # ← NUEVO (Spike 3, Grupo B): primera zona de producción real
│   │       ├── exploration_telmori_village.tscn
│   │       └── exploration_telmori_village.gd
│   │
│   ├── player/                      # ⚠️ player.gd/player.tscn: código muerto, limpieza APARCADA
│   │   ├── player.gd                #    (bloqueada por test/test_shop_ui.gd, que aún los referencia)
│   │   ├── player.tscn
│   │   ├── player_combat_controller.gd
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
    │   ├── combat_arena_viewmodel.gd   # ← NUEVO (Grupo 5): ViewModel de la arena — fichas de party/enemigos (dinámicas: companions/refuerzos a mitad de combate) + log narrado. Compone a combat_hub_viewmodel.gd como action_menu, sin tocarlo. Se conecta a Resources.resource_changed directamente (la señal de ResourceSystem, NO EventBus.resource_changed — ver hallazgo de motor abajo). Grupo 4: + background_texture / razón "background" (lee GameLoop.get_current_encounter() con call_deferred); fill_color resuelto también para enemigos (antes Color.WHITE por defecto) y centinela Color.BLACK de token_color respetado
    │   ├── combat_token_data.gd        # ← NUEVO (Grupo 5): data class — snapshot de una ficha (entity_id, is_party, HP/EN actual+máximo, turno, objetivo, color/icono)
    │   ├── log_entry_data.gd           # ← NUEVO (Grupo 5): data class — una línea del log (text_key + format_args + grade)
    │   ├── combat_arena_panel.gd       # ← NUEVO (Grupo 5): View de producción, sustituye a combat_hud.tscn como SceneOrchestrator.OVERLAY_COMBAT_HUD. Fichas dinámicas en PartyColumn(VBoxContainer)/EnemyColumn(GridContainer 2 columnas — VBoxContainer no cabía con 6 enemigos reales), log con autoscroll, menú de 8 UIButton fijos, fondo opaco (tapa la escena de exploración, que sigue viva debajo por diseño de SceneOrchestrator). Grupo 4: BackgroundImage (TextureRect) debajo de Background (ColorRect, ahora %), que pasa a ser velo con alfa UITokens.COMBAT_BACKGROUND_SCRIM_ALPHA si el encuentro trae imagen, opaco si no; color desde UITokens.COLOR_PANEL (ya no fijo en el .tscn); contorno en las líneas del log
    │   ├── combat_arena_panel.tscn
    │   └── damage_number.tscn
    │
    ├── character_creation/         # Creación de personaje (patrón MVVM)
    │   ├── character_creation_viewmodel.gd  # Spike 3/B: kit inicial de skills leído de player_new.tres, ya no de una constante duplicada (STARTING_SKILL_VALUES, eliminada)
    │   ├── character_creation_screen.gd
    │   └── character_creation_screen.tscn
    │
    ├── design_system/              # Sistema de diseño centralizado
    │   ├── components/
    │   │   ├── ui_button/
    │   │   │   ├── ui_button.gd
    │   │   │   └── ui_button.tscn
    │   │   ├── ui_panel/
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
    │   │   └── ui_combat_token/    # ← NUEVO (Grupo 5): ficha de combate (party o enemigo), compone dos UIRadialGauge + relleno central (iniciales o icono de tipo) + triángulo de turno + retícula de objetivo. 3 scripts helper internos sin class_name (no reutilizables fuera de este componente): ui_combat_token_center_fill.gd, ui_combat_token_turn_triangle.gd, ui_combat_token_target_reticle.gd. Grupo 4: _apply_text_outline() en _ready() — contorno (UITokens.TEXT_OUTLINE_SIZE / COLOR_TEXT_OUTLINE) en iniciales y cifras de PV/EN
    │   │       ├── ui_combat_token.gd
    │   │       ├── ui_combat_token_center_fill.gd
    │   │       ├── ui_combat_token_turn_triangle.gd
    │   │       ├── ui_combat_token_target_reticle.gd
    │   │       └── ui_combat_token.tscn
    │   ├── theme/
    │   │   └── main_theme.tres     # Tema global de UI
    │   └── tokens/
    │       └── ui_tokens.gd        # [Autoload: UITokens] Tokens de diseño — Grupo 5: + COLOR_GAUGE_HP_PARTY/EN_PARTY/HP_ENEMY, COLOR_TURN_INDICATOR, COLOR_TOKEN_FILL_DEFAULT, COLOR_LOG_FUMBLE/FAILURE/CRITICAL (SPECIAL reutiliza COLOR_TURN_INDICATOR, SUCCESS reutiliza el font_color normal del tema)
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
    │   ├── loadout_viewmodel.gd
    │   ├── loadout_screen.gd
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
    │   ├── narrative_scene_viewmodel.gd  # enum PanelState (no SceneState) — Spike 3/B: _apply_outcome() resuelve grant_item_*/combat_encounter, registra enemigos antes de start_combat()
    │   ├── narrative_scene_panel.gd      # Spike 3/B: consume "streak_progress" (hueco abierto desde Spike 2); UIPanel anclado a tamaño fijo (bug de autowrap sin ancho)
    │   └── narrative_scene_panel.tscn    # Grupo 4: layout B1 — SceneImage a pantalla completa detrás, UIPanel anclado al tercio inferior (anclas relativas, grow_vertical = BEGIN), texto y opciones en HBoxContainer. Cero cambios en el script
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
- `start_combat()` acepta como estado de origen `EXPLORATION`, `DIALOGUE`, `MENU` y `NARRATIVE_SCENE` (guard explícito, independiente de `VALID_STATE_TRANSITIONS` — `start_combat()` transiciona directo con `_transition_game_state()`, no pasa por `request_state_change()`).
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
└── telmori_village/             ← NUEVO (Spike 3, Grupo B) — zona de producción real
    ├── exploration_telmori_village.tscn
    └── exploration_telmori_village.gd
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

Ver `docs/spike_character_creation_informe_cierre.md` para el detalle completo.

### Skills — dos sistemas paralelos de valores (aclarado en Spike 3, Grupo B)

Dos accesores distintos para lo que parece "lo mismo", sin relación entre sí:

- **`CharacterState.skill_values`** (vía `Characters.get_skill_value()` / `Characters.list_known_skills()`) — se inicializa desde `CharacterDefinition.starting_skill_values` dentro de `CharacterState.new(definition)`, en el propio `register_entity()`. Es lo que leen tanto combate como las tiradas narrativas para resolver el % de una tirada.
- **`SkillSystem._entity_skills`** (vía `Skills.get_skill_instance()` / `Skills.register_entity_skills()`) — registro separado, una sola vez (`register_entity_skills()` tiene guard de registro único: `if _entity_skills.has(entity_id): return`), usado solo para desbloqueo (`is_unlocked`) y conteo de progresión (`SkillProgressionService._process_improvement_rolls()` itera `list_known_skills()` pero busca la instancia aquí).

Si el registro de `SkillSystem` no incluye una skill que sí aparece en `list_known_skills()` (porque se pasó una lista distinta a `register_entity_skills()`), el síntoma es un aviso de `SkillSystem` ("Skill not found for entity") al terminar combate, sin que las tiradas en sí se vean afectadas — fácil de pasar por alto. Tanto `CharacterCreationViewModel` (jugador) como `PartyManager._register_in_systems()` (companions) deben pasar `definition.skills` explícitamente a `register_entity_skills()`, nunca una lista propia ni el array vacío por defecto (que registra el catálogo entero).

### Exploration Tutorial — Arquitectura (OBSOLETA desde Spike 3, Grupo B)

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
    └── UIPanel                              ← Grupo 4: tercio inferior (anclas 0.04/0.66/0.96/0.96), crece hacia arriba
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

**Mejoras post-Spike 3, Grupo 2 — `NarrativeSceneOutcome` extendido con diálogo:**
- `dialogue_id: String` (vacío por defecto) — cuando está relleno, la opción abre `DialoguePanel` como sub-overlay encima del panel narrativo (mismo patrón que Inventory/Party/PlayerMenu de Grupo 3: hijo directo de `NarrativeScenePanel`, nunca vía `SceneOrchestrator`), llamando directamente a `Dialogue.start_dialogue(dialogue_id)` sobre el autoload — sin transición de `GameState`, se queda en `NARRATIVE_SCENE` durante toda la conversación.
- `next_scene_id` del mismo outcome cambia de significado cuando `dialogue_id` no está vacío: deja de aplicarse al instante y pasa a ser la escena a la que avanzar **cuando se cierre el diálogo** — `NarrativeSceneViewModel.resume_after_dialogue()`, llamado por `NarrativeScenePanel` solo si el sub-overlay que se cerró era Diálogo (nuevo flag interno `_sub_overlay_is_dialogue`, distinto de Inventory/Party/PlayerMenu, que nunca disparan el reenganche).
- Hallazgo crítico: `SceneOrchestrator._on_dialogue_ended()` escuchaba `EventBus.dialogue_ended` (global) y forzaba `enter_exploration()` sin condición — habría destruido la escena narrativa en curso al cerrar un diálogo abierto como sub-overlay. Corregido con guard: `current_game_state == GameState.DIALOGUE`.
- Tres comprobaciones de código previas al diseño (paso obligado del spec): `GameState.DIALOGUE` no tiene ninguna dependencia real más allá de lo genérico (`is_input_blocked()` lo trata igual que `NARRATIVE_SCENE`); `DialogueSystem.start_dialogue()` es una llamada directa al autoload sin ninguna lectura de `GameState`, lo que hace viable el sub-overlay; y no existía ningún mecanismo de "combate desde diálogo" en el proyecto — confirmado también por la transcripción real de "Los Telmori", cuyo contenido candidato (diálogos con el sheriff) es puramente expositivo, así que combate-desde-diálogo queda fuera de alcance por ausencia de caso real.
- Gating de opciones narrativas por flag (`required_flags`/`blocked_flags` en `NarrativeSceneOption`, como sí tiene `DialogueOptionDefinition`) se evaluó y se descartó — el diseño de `resume_after_dialogue()` no lo necesita.
- Validado en partida real contra `sheriff_briefing` de "Los Telmori": apertura del sub-overlay, navegación por las tres ramas de pregunta sin perder el hub, cierre sin disparo indebido de `enter_exploration()`, reenganche automático a `telmori_equipment_arrows`. Ver `docs/mejoras_grupo2_dialogo_narrativa_informe_cierre.md` para el detalle completo.

**Esquema JSON real, confirmado en Grupo C contra ejemplos reales de Grupo B** (útil documentarlo aquí porque no coincidía con lo que se había inferido solo de la descripción de arriba): raíz `scene_id`/`image_path`/`text_key`/`options[]`; opción `option_id`/`text_key`/`skill_id`/`roll_modifier`/`challenge_level`/`required_successes`/`retry_policy`/`group_aggregate`. Sin `skill_id` resuelve por `outcome_default`; con `skill_id`, ramas **planas** en la propia opción — `outcome_failure`/`outcome_success`/`outcome_special`/`outcome_critical` (sin `outcome_fumble` explícito — cae a `outcome_failure`, fallback ya documentado arriba). Cada outcome lleva `next_scene_id`, `flag_to_set` (string único con prefijo `flag.`, solo activa un flag, nunca lo desactiva), `combat_enemy_ids` (array de strings — quiénes están presentes al *empezar* el combate) y `combat_enemy_definitions` (diccionario `entity_id → definition_id` de *todo* lo que hay que registrar, inicial o de refuerzo). `combat_encounter`, cuando aparece, es un **diccionario inline dentro del propio outcome** — nunca una ruta a un `.tres` — con las claves de `CombatEncounterDefinition` (`morale_threshold_pct`, `reinforcement_trigger`, `reinforcement_delay_rounds`, `reinforcement_enemy_ids`, `reinforcement_definition_id`, `surprise_favors`, `surprise_vulnerable_pct`, y desde mejoras post-Spike 3, Grupo 4, `background_path`). No hace falta crear ningún recurso `CombatEncounterDefinition` aparte para contenido disparado desde una escena narrativa.

**Restricción real de `reinforcement_definition_id` (Grupo C):** es un único string, no un diccionario por entidad — todo un refuerzo sale de la misma `CharacterDefinition`, no admite mezclar tipos de enemigo en la misma oleada (a diferencia del roster *inicial*, que sí admite tipos mixtos vía `combat_enemy_definitions` normal). Si un contenido necesita refuerzo de tipos mixtos, hay que elegir entre extender el recurso a un diccionario (cambio de motor, no hecho todavía) o simplificar el contenido a un refuerzo homogéneo (la opción que tomó Grupo C).

`_apply_outcome()` en el ViewModel resuelve todo esto en orden: flag → otorgar ítem → si hay combate, registrar enemigos (`_register_combat_enemies()`, réplica deliberada — no compartida — de la misma lógica en `ExplorationController`) y avisar a `CombatLootSpawner` antes de `start_combat()`.

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
- **Reflavor del entrenamiento de magia** — el tomo (`book_tanning_basics.tres`) enseña Curtidor directamente vía `learning_data`, reutilizando el mecanismo de libro de aprendizaje ya existente desde `book_combat_basic.tres`, sin sistema de magia nuevo (sigue aparcado). Orden de las escenas del sheriff decidido para que el tomo se entregue **antes** de la venta de pieles, así el jugador puede usar la skill recién aprendida en la misma sesión de recompensa.
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
- **`AttributeResolver` (máximo derivado real del personaje) y `ResourceState.max_effective` (máximo genérico de `ResourceDefinition.max_base`, típicamente 100) confirmados como dos números desconectados** — nada llama a `Resources.set_max_effective()` para sincronizarlos, al menos en el camino de `combat_test_scene.gd`. Sin resolver, origen histórico desconocido.
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

### ItemCharacterBridge — Aplicación de modificadores

El target de un modificador sigue el formato `tipo.id`:
- `resource.health` → afecta el valor **actual** del recurso (no el máximo)
- `attribute.strength` → modifica el atributo **base** del personaje
- `skill.exploration.lockpick` → modifica el valor de la habilidad (el id puede contener puntos)

Operaciones soportadas: `add`, `mul`, `override`.

Los ítems de tipo `EQUIPMENT` delegan a `EquipmentManager.toggle_equipment()` (equipa si no está equipado, desequipa si lo está) — este es el camino para cuando el **jugador** usa un ítem desde la UI. Para equipar por código (setup inicial, NPCs, etc.), `Equipment.equip_item(entity_id, item_id)` es directo y no exige que el ítem esté en el inventario (aunque añadirlo también, vía `Inventory.add_item()`, mantiene la coherencia si se desequipa más tarde).

Los libros de aprendizaje (`learning_data` en `ItemDefinition`) crean una `LearningSession` y delegan a `SkillProgression`. Pueden tener también modificadores de recurso adicionales.

### Design System — Componentes reutilizables de UI

Todos los componentes de UI deben usar el Design System centralizado:

- **UITokens** (autoload): Define colores, espaciado y tamaños centralizados
- **UIPanel**: PanelContainer con estilos consistentes — **debe anclarse a un tamaño explícito** cuando contiene texto largo (ver antipatrón nuevo en `athelia_ui_architecture.md`, Spike 3/B); sin anclaje se dimensiona al contenido y puede desbordar la ventana
- **UIButton**: Button con variants (PRIMARY, SECONDARY, etc.) y tamaños
- **UISlot**: Slot de inventario/equipo con drag & drop
- **UIResourceBar**: Barra de recurso (vida, stamina) con valores actuales/máximos
- **UIRadialGauge** (Grupo 5): Anillo de progreso radial parametrizable, un único anillo por instancia — primer componente con `_draw()`/arcos, sin precedente previo en el Design System
- **UICombatToken** (Grupo 5): Ficha de combate (party o enemigo) — compone dos `UIRadialGauge` + relleno central + triángulo de turno + retícula de objetivo. Grupo 4: contorno de texto desde tokens, para leerse sobre fondos de combate claros
- **Spike aparcado — marco decorativo**: doble filete + esquineras (una única imagen de esquina reutilizada en las 4), como opción activable dentro de `UIPanel`. Surgido en Grupo 4, sin empezar

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

**Mejoras post-Spike 3, Grupo 1 — F5 retirado por completo.** Guardar deja de ser una hotkey libre en `EXPLORATION`: la única vía es seleccionar una opción de diálogo marcada `triggers_save` en NPCs concretos, dentro de una escena narrativa (ver sección de Grupo 1 más abajo). F9 (quickload) se queda exactamente igual, sin restricción de estado de origen.

**Nuevo en el mismo grupo — atajo de desarrollo (F2).** Tecla de debug, keycode crudo (sin InputMap) detrás de `OS.is_debug_build()` desde el primer commit — misma disciplina que evitó que F1 (Spike 1) se quedara viva en producción. Lee `user://debug_shortcut.json` en cada pulsación (no cacheado en `_ready()`), aplica `Narrative.set_flag()` por cada entrada de `"flags"` y `Characters.set_skill_value("player", skill_id, value)` por cada entrada de `"skills"`. Se comprueba **antes** del guard `is_input_blocked()`, deliberadamente — funciona en cualquier `GameState`, para poder forzar un tramo concreto durante una prueba sin depender de dónde esté la partida. Mecanismo aparte del guardado real: nunca toca `SaveManager`/`SaveData`, es mutación directa en memoria de la sesión ya arrancada.

`player.gd`/`player.tscn` (`scenes/player/`) no se usan en ninguna escena activa, pero **su limpieza queda aparcada**: `test/test_shop_ui.gd` sigue cargando `player.tscn` como andamiaje. No se tocan hasta una revisión general de la carpeta `test/`.

**Bug conocido, sin resolver (sin relación con el Grupo 1 — no investigado en este grupo):** F9 (quickload) en una sesión activa ya en `EXPLORATION` (a diferencia de "Cargar Partida" desde el menú, que sí funciona) provoca un bloqueo total de input — ni movimiento ni menús responden, sin errores en Output/Debugger. Se descartaron como causa: bloqueo por `GameState` (`SAVE_TRANSITION` nunca se dispara en el proyecto), `get_tree().paused`, captura de input por `WorldObjectInteractionPanel`, y pérdida de foco de ventana. Causa raíz aún no confirmada — ver `docs/spike_produccion_post_character_creation_informe_cierre.md`.

**Spike 1 Motor Narrativo añadió F1** como tecla de debug temporal en `_unhandled_input()` para disparar `GameLoop.enter_narrative_scene("test_intro")` — retirada en Spike 3, Grupo A junto con `_debug_test_narrative_scene()` y las escenas de prueba asociadas.

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

---

*Última actualización: Spike 5 — Arreglos rápidos de motor. Cinco bugs de
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
