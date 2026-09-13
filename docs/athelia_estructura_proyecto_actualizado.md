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
│   │   ├── character_definition.gd # Resource: definición estática del personaje
│   │   ├── character_state.gd      # Resource: estado en tiempo de ejecución
│   │   ├── loadout_state.gd        # Resource: estado de loadout del personaje
│   │   ├── attribute_resolver.gd   # Resolución de atributos derivados
│   │   └── modifier_applicator.gd  # [Autoload: Modifiers]
│   │
│   ├── combat/                     # Sistema de combate por turnos
│   │   ├── combat_system.gd        # [Autoload: Combat]
│   │   ├── combat_resolver.gd      # Resolución de acciones de combate
│   │   ├── combat_loot_spawner.gd  # [Autoload: CombatLootSpawner]
│   │   ├── defense_module.gd       # Módulo de defensa
│   │   ├── escape_module.gd        # Módulo de huida
│   │   ├── skill_roller.gd         # Tiradas de habilidad (RollResult: FUMBLE/FAILURE/SUCCESS/SPECIAL/CRITICAL desde Spike 2 — CRITICAL/SPECIAL dinámicos skill/20 y skill/5, FUMBLE absoluto)
│   │   ├── combat_encounter_definition.gd  # ← NUEVO (Spike 2): Resource opcional para start_combat() — moral de grupo (morale_threshold_pct) y refuerzos cronometrados (reinforcement_trigger/delay_rounds/enemy_ids)
│   │   └── enemy_ai.gd             # IA de enemigos
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
│   │   ├── narrative_scene_definition.gd   # Resource: escena (imagen, texto, opciones)
│   │   ├── narrative_scene_option.gd       # Resource: opción (tirada opcional, referencias a outcomes por grado)
│   │   └── narrative_scene_outcome.gd      # Resource: destino/consecuencias (fichero propio, no clase interna — ver lecciones del spike)
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
│   │   ├── player_new.tres         # ← NUEVO: plantilla real para Character Creation (atributos placeholder, kit fijo de skills)
│   │   ├── enemy_base.tres
│   │   ├── wolf_test.tres
│   │   ├── companions/
│   │   │   ├── companion_base.tres
│   │   │   └── companion_mira.tres
│   │   └── portrait/               # Retratos de personajes (PNG)
│   │       ├── guard.png
│   │       ├── merchant.png
│   │       ├── mira.png
│   │       ├── orco.png
│   │       └── [otros portraits...]
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
│   │   └── weapons/                # Por slot: weapon, body, head, feet, shield, accesory
│   │       ├── weapon/
│   │       │   ├── iron_sword.tres / .png
│   │       │   └── shortbow.tres
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
│   ├── narrative_scenes/           # ← NUEVO (Spike 1): un JSON por escena narrativa
│   │   ├── test_scene_intro.json   # Escena de prueba desechable — eliminar antes de Spike 3
│   │   ├── test_scene_success.json
│   │   └── test_scene_failure.json
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
│   │       └── sprint.tres
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
│   └── spike_2_reglas_runequest_informe_cierre.md  # ← NUEVO: reglas de RuneQuest sobre el motor narrativo (seis puntos), moral/refuerzos en combate
│
├── localization/                   # Sistema de localización (ES/EN)
│   ├── translations.csv            # Textos generales
│   ├── translations.en.translation
│   ├── translations.es.translation
│   ├── dialogues.csv               # Textos de diálogos
│   ├── dialogues.en.translation
│   ├── dialogues.es.translation
│   ├── items.csv                   # Nombres y descripciones de ítems
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
│   ├── narrative_scenes.csv        # ← NUEVO (Spike 1): textos de escenas narrativas (solo escena de prueba por ahora)
│   ├── narrative_scenes.en.translation
│   └── narrative_scenes.es.translation
│
├── scenes/                         # Escenas del juego
│   ├── combat/
│   │   ├── combat_test.tscn        # Escena de test de combate
│   │   ├── combat_test_scene.gd
│   │   ├── enemy_combat_node.gd
│   │   └── enemy_combat_node.tscn
│   │
│   ├── companions/
│   │   ├── companion_base.tscn
│   │   └── companion_mira.tscn
│   │
│   ├── exploration/                 # scripts COMPARTIDOS entre todas las zonas de exploración
│   │   ├── exploration_test.tscn    # sandbox de desarrollo — nodo raíz debe llamarse "ExplorationScene" para que SceneOrchestrator._handle_exploration() lo reconozca al ejecutarlo suelto (F6); si no, intenta instanciar otra copia de la escena de producción encima y crashea ("Parent node is busy setting up children")
│   │   ├── exploration_test.gd
│   │   ├── exploration_controller.gd  # Input de exploración (interact, inventory, party, player_menu, F5/F9 quicksave/quickload) — incluye tecla F1 de debug temporal para probar NarrativeScene (Spike 1), a eliminar antes de Spike 3
│   │   ├── exploration_hud.gd
│   │   ├── player_exploration.gd
│   │   ├── companion_follow_node.gd
│   │   ├── interactable.gd
│   │   │
│   │   └── tutorial/                # primera zona de PRODUCCIÓN (mini-tutorial)
│   │       ├── exploration_tutorial.tscn
│   │       └── exploration_tutorial.gd
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
│   ├── test_character_persistence.gd         # Roundtrip save/load de CharacterSystem
│   └── [otros test_*.gd por sistema]          # NarrativeSceneViewModel no tiene test unitario todavía — candidato para Spike 2
│
└── ui/                             # Componentes de interfaz de usuario
    ├── damage_number.gd
    ├── damage_number.tscn
    ├── entity_animation_controller.gd
    │
    ├── combat/                     # UI de combate
    │   ├── combat_hub_viewmodel.gd
    │   ├── combat_hud.gd
    │   ├── combat_hud.tscn
    │   └── damage_number.tscn
    │
    ├── character_creation/         # Creación de personaje (patrón MVVM)
    │   ├── character_creation_viewmodel.gd
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
    │   │   └── ui_resource_bar/
    │   │       ├── ui_resource_bar.gd
    │   │       └── ui_resource_bar.tscn
    │   ├── theme/
    │   │   └── main_theme.tres     # Tema global de UI
    │   └── tokens/
    │       └── ui_tokens.gd        # [Autoload: UITokens] Tokens de diseño
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
    │   ├── game_over_ui.gd
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
    ├── narrative_scene/             # ← NUEVO (Spike 1): escena narrativa (patrón MVVM)
    │   ├── narrative_scene_viewmodel.gd  # enum PanelState (no SceneState — colisiona con clase nativa)
    │   ├── narrative_scene_panel.gd
    │   └── narrative_scene_panel.tscn
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
MENU → EXPLORATION, CHARACTER_CREATION
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

- La iniciativa se calcula al inicio del combate y determina el `turn_order`.
- Los companions actúan **después del jugador, antes de los enemigos**.
- Un companion incapacitado permanece en `turn_order` pero `CompanionAI` skipea su turno.
- Victoria: todos los enemigos muertos. Derrota: jugador muerto (los companions no evitan la derrota actualmente).
- `start_combat()` acepta como estado de origen `EXPLORATION`, `DIALOGUE`, `MENU` y `NARRATIVE_SCENE` (guard explícito, independiente de `VALID_STATE_TRANSITIONS` — `start_combat()` transiciona directo con `_transition_game_state()`, no pasa por `request_state_change()`).

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
└── tutorial/                    ← una zona = una subcarpeta
    ├── exploration_tutorial.tscn
    └── exploration_tutorial.gd
```

Mismo patrón previsto para `scenes/combat/arena_<nombre>/` y una futura `scenes/narrative/<evento>/`. El orden de progresión del jugador (qué zona sigue a cuál) debe vivir en datos (futuro registro de niveles/zonas), no en el nombre del archivo — un número no comunica contenido y se rompe al reordenar. Decidido en `docs/spike_produccion_post_character_creation_informe_cierre.md`.

### SceneOrchestrator — Gestión de overlays

- Escucha `game_state_changed` vía EventBus y **nunca modifica GameState**.
- Los overlays (diálogo, tienda, inventario, escena narrativa) se instancian y destruyen en cada apertura/cierre (`queue_free`).
- La escena de combate se carga de forma **aditiva** (la escena de exploración permanece en memoria debajo).
- El inventario es especial: se abre como overlay dentro de `EXPLORATION` sin cambiar `GameState`. Se accede vía `SceneOrchestrator.open_inventory()`.
- Hay un problema de timing conocido con la tienda (el evento `shop_opened` se emite antes de que el overlay exista); se resuelve llamando directamente a `show_shop_direct()` con un snapshot del `EconomySystem`. **NarrativeScene no tiene este problema** — `NarrativeSceneDB.get_scene()` es una consulta local síncrona, así que `_handle_narrative_scene()` no necesita ningún `show_X_direct()` especial, el `scene_id` llega vía `_pending_context` igual que `dialogue_id`/`shop_id`.
- El menú principal es la **Main Scene** del proyecto. `_handle_main_menu()` solo limpia overlays residuales; no instancia nada.
- `_handle_character_creation()` usa `_show_overlay()` (igual que Shop/Inventory/Party) — importante: instanciarla manualmente contra `get_tree().root` sin pasar por `_show_overlay()` deja la escena huérfana de `_current_overlay`, y `_hide_current_overlay()` nunca la destruye al salir.
- `_handle_exploration()` instancia `SCENE_EXPLORATION` si no existe ya en el árbol (comprobando por nombre de nodo `"ExplorationScene"`) — necesario para el flujo real Menú → Character Creation → Exploration, no solo para correr una escena de exploración de forma aislada. **`SCENE_EXPLORATION` apunta a `res://scenes/exploration/tutorial/exploration_tutorial.tscn`** (escena de producción) desde el spike de producción — `exploration_test.tscn` queda como sandbox de desarrollo, ya no en la ruta de producción. **Importante para pruebas manuales:** si ejecutas `exploration_test.tscn` suelto (F6), su nodo raíz debe llamarse literalmente `"ExplorationScene"` o esta búsqueda falla y el sistema intenta instanciar otra copia de la escena de producción encima, en medio del arranque del árbol (`add_child()` con "Parent node is busy setting up children").
- `_handle_narrative_scene(scene_id)` — nuevo en Spike 1, calcado de `_handle_dialogue()`: `_hide_current_overlay()` → `_show_overlay(OVERLAY_NARRATIVE_SCENE)` → `open(scene_id)` en el overlay instanciado. Cierre vía `EventBus.narrative_scene_closed` → `_on_narrative_scene_closed()` → `GameLoop.enter_exploration()`, mismo patrón que `_on_shop_closed()`.

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

El guardado **no está disponible desde el menú principal** — se guarda en checkpoints o con F5 desde la exploración.

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

Ver `docs/spike_character_creation_informe_cierre.md` para el detalle completo.

### Exploration Tutorial — Arquitectura (primera escena de exploración de producción)

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

**A diferencia de `exploration_test.gd`, esta escena NO registra al jugador** — asume que `CharacterCreationViewModel._create_player_entity()` ya lo dejó registrado en `Characters`/`Resources`/`Skills`/`Equipment`/`Inventory` antes de que `GameLoop.enter_exploration()` la cargue. Sí registra los `WorldObjects` propios de la zona (`WorldObjectSystem.register_instance()`, `WorldObjectBridge`, `WorldObjectInteractionPanel`).

**Convención de colisión para objetos de mundo sólidos:** todo objeto interactuable necesita **dos** cuerpos separados — `Interactable` (`Area2D`, detección de proximidad/prompt) y un `StaticBody2D` adicional (bloqueo físico). Un `Area2D` nunca bloquea movimiento por diseño de Godot; ambos roles no deben mezclarse en el mismo nodo.

Ver `docs/spike_produccion_post_character_creation_informe_cierre.md` para el detalle completo (bugs corregidos, hallazgos aparcados).

### Narrative Scene — Arquitectura (Spike 1, motor base del pivote hacia RPG narrativo)

Sigue el patrón MVVM estándar. Vive fuera de `core/narrative/` deliberadamente — ese paquete (`NarrativeSystem`/`CheckpointSystem`) gestiona hitos recordados; `core/narrative_scenes/` resuelve "qué nodo se muestra ahora", responsabilidad distinta. Sin "system" runtime propio: `NarrativeSceneDB` es una consulta local síncrona sobre datos cargados de JSON, sin estado — el progreso por una escena vive enteramente en `NarrativeSceneViewModel`.

```
NarrativeScenePanel (CanvasLayer)
└── Root (Control, full rect)
    └── UIPanel
        └── MarginContainer → VBoxContainer
            ├── SceneImage (TextureRect)
            ├── SceneText (Label)
            └── OptionsContainer (VBoxContainer)   ← UIButton instanciado por opción
```

Estados del `NarrativeSceneViewModel`: `HIDDEN → SHOWING ↔ WAITING_ROLL → TRANSITIONING → HIDDEN` (`WAITING_ROLL` reservado, no se emite todavía — `SkillRoller.roll_skill()` es síncrono, sin ventana real de espera en Spike 1).

Contrato de datos (`NarrativeSceneDefinition` → `NarrativeSceneOption` → `NarrativeSceneOutcome`, todos Resource en fichero propio, no clases internas): una opción sin `skill_id` resuelve directo por `outcome_default`; con `skill_id`, tira contra `Characters.get_skill_value(entity_id, skill_id) + roll_modifier` vía `SkillRoller.roll_skill()`, y el grado de resultado (`FUMBLE`/`FAILURE`/`SUCCESS`/`SPECIAL`/`CRITICAL` desde Spike 2) determina qué `NarrativeSceneOutcome` aplicar (con fallback: fumble→failure, special→success, critical→success si no están definidos). Un outcome puede: cerrar la escena, encadenar a otro `next_scene_id`, marcar un flag vía `Narrative.set_flag()`, o disparar combate vía `GameLoop.start_combat(enemy_ids)`.

Cierre desacoplado: `NarrativeSceneViewModel` no llama a `GameLoop` directamente al terminar una rama — emite `EventBus.narrative_scene_closed(scene_id)`, y `SceneOrchestrator._on_narrative_scene_closed()` decide volver a `EXPLORATION`. Mismo patrón que `dialogue_ended`/`shop_closed`. Cuando el outcome dispara combate, no hay paso intermedio por `EXPLORATION`: `GameLoop.start_combat()` acepta `NARRATIVE_SCENE` como estado de origen directamente.

Ver `docs/spike_1_motor_narrativo_informe_cierre.md` para el detalle completo del motor base, incluidas las lecciones de GDScript (self-reference por `class_name`, colisión de `SceneState` con clase nativa).

### Spike 2 — Reglas de RuneQuest para el Motor Narrativo (seis de seis puntos cerrados)

Las seis piezas que Spike 1 dejó diferidas quedan implementadas y validadas.
Ninguna toca contenido real de "Los Telmori" (eso sigue siendo Spike 3).

1. **Grado "especial"** — `SkillRoller.RollResult` pasa a 5 grados. `CRITICAL` y `SPECIAL` son dinámicos (`skill/20`, `skill/5`, fórmulas RuneQuest clásicas), `FUMBLE` se queda absoluto. En combate, `SPECIAL` aplica un multiplicador de daño propio (x1.2, vs x2 de crítico) vía `special_multiplier` en el effect. Cuenta como `"success"` en progresión, sin tick diferenciado.
2. **Progresión de skill narrativa** — `NarrativeSceneOption.challenge_level: int` (0 = sin progresión, opt-in explícito) engancha a `SkillProgression.execute_learning_session()` con `SourceType.NARRATIVE`, gateado en éxito, nunca vía `notify_skill_outcome()` (hard-gated a combate).
3. **Tiradas acumulativas** — `NarrativeSceneOption.required_successes`/`retry_policy` (`"immediate"`/`"blocked"`). El contador de racha vive en `NarrativeSceneViewModel`, nunca en `NarrativeSceneDB` ni en la propia `NarrativeSceneOption`. Una pifia siempre transiciona, ignorando `retry_policy`. La progresión solo se intenta al completar la racha entera, nunca en un éxito parcial.
4. **Tiradas agregadas de grupo** — `NarrativeSceneOption.group_aggregate` (`""`/`"worst"`/`"best"`). Sin tabla de resistencia real (decisión de coste-beneficio): la oposición se codifica en `roll_modifier`, no en un valor de NPC calculado por el motor. Sin cambios en `PartyManager` — la agregación vive en el ViewModel. Si hay progresión, cada miembro del grupo intenta su propia mejora de forma independiente.
5. **Modificadores dinámicos** — cerrado sin código: `roll_modifier` (Spike 1) ya cubre el caso narrativo. El caso de combate (multiplicativo, ej. "mitad de puntería en oscuridad") se aplaza a Spike 3.
6. **Moral y refuerzos cronometrados** — fichero nuevo `core/combat/combat_encounter_definition.gd` (Resource), parámetro opcional en `GameLoopSystem.start_combat(enemy_ids, encounter = null)`. Moral de **grupo** (no individual): los enemigos supervivientes huyen juntos cuando el HP total del grupo cae bajo `morale_threshold_pct`, vía una señal nueva (`enemy_group_fled`) que nunca pasa por `character_died` (sin loot, sin animación de muerte). Refuerzos genéricos vía `reinforcement_trigger`/`reinforcement_delay_rounds`, disparables por cualquier sistema con `GameLoop.trigger_combat_event()`. `GameLoopSystem.configure_active_encounter()` permite adjuntar un encuentro a un combate ya en marcha (necesario porque `ExplorationController` arranca combate sin pasar ningún encuentro).

**Hallazgos de GDScript reutilizables fuera de este spike:** un `match` sin rama `_:` no avisa si le falta un caso al crecer un enum (encontrado en `SkillRoller._is_success()`, que habría tratado un `SPECIAL` como fallo en combate); un array indexado directamente por el valor entero de un enum (`LearningSession._to_string()`) se sale de rango en silencio si el enum crece sin ampliar el array. Ambos son el mismo tipo de riesgo en dos formas distintas: cualquier extensión de un enum obliga a repasar *todos* sus consumidores, no solo los que parecen relevantes a simple vista.

Ver `docs/spike_2_reglas_runequest_informe_cierre.md` para el detalle completo, decisión por decisión, y la validación realizada en cada punto.

### Persistencia de personaje — CharacterSystem ↔ SaveSystem

`CharacterState` serializa `definition_id`, `character_name` y `attributes` vía `get_save_state()`/`load_save_state()`. Conectado a `SaveSystem` desde `SAVE_VERSION = 5` — `_restore_state()` restaura el snapshot de `CharacterSystem` **primero**, antes de recursos/skills, porque `load_save_state()` puede bootstrapear el registro de la entidad vía `definition_id` si no existe todavía.

**Registro en frío — resuelto para 4 de los 5 sistemas.** `EquipmentManager` e `InventorySystem` ya se auto-registraban dentro de su propio `load_save_state()` (no requería cambios). `ResourceSystem` y `SkillSystem` **no** lo hacían — su `load_save_state()` no hacía nada en silencio si la entidad no existía. Desde el spike de producción, ambos exponen `has_entity(entity_id) -> bool`, y `SaveSystem._restore_state()` registra la entidad en frío antes de restaurar si hace falta (el universo de skills a registrar sale de las propias keys del snapshot guardado, no de un kit hardcodeado). "Cargar Partida" desde un arranque en frío real ya funciona con HP/Stamina/Gold/Skills correctos.

**Pendiente conocido (distinto al anterior):** la **posición** del jugador no se restaura en arranque en frío — `_find_player()` corre dentro de `_restore_state()`, que se ejecuta *antes* de que `SceneOrchestrator` instancie la escena de exploración (el orden en `MainMenuViewModel.request_load_game()` es `load_game()` → `enter_exploration()`). El personaje aparece en el spawn por defecto de la escena, no en la posición guardada. Sin decisión de diseño tomada todavía — ver pendientes en `docs/spike_produccion_post_character_creation_informe_cierre.md`.

`SaveSystem._find_player()` busca primero bajo el nodo `"ExplorationScene"` (creado explícitamente por `SceneOrchestrator`), no bajo `get_tree().current_scene` — este último nunca cambia mientras `MainMenuScreen` siga siendo la Main Scene, ya que la exploración se instancia de forma aditiva (`get_tree().root.add_child()`), no con `change_scene_to_file()`.

### ItemCharacterBridge — Aplicación de modificadores

El target de un modificador sigue el formato `tipo.id`:
- `resource.health` → afecta el valor **actual** del recurso (no el máximo)
- `attribute.strength` → modifica el atributo **base** del personaje
- `skill.exploration.lockpick` → modifica el valor de la habilidad (el id puede contener puntos)

Operaciones soportadas: `add`, `mul`, `override`.

Los ítems de tipo `EQUIPMENT` delegan a `EquipmentManager.toggle_equipment()` (equipa si no está equipado, desequipa si lo está).

Los libros de aprendizaje (`learning_data` en `ItemDefinition`) crean una `LearningSession` y delegan a `SkillProgression`. Pueden tener también modificadores de recurso adicionales.

### Design System — Componentes reutilizables de UI

Todos los componentes de UI deben usar el Design System centralizado:

- **UITokens** (autoload): Define colores, espaciado y tamaños centralizados
- **UIPanel**: PanelContainer con estilos consistentes
- **UIButton**: Button con variants (PRIMARY, SECONDARY, etc.) y tamaños
- **UISlot**: Slot de inventario/equipo con drag & drop
- **UIResourceBar**: Barra de recurso (vida, stamina) con valores actuales/máximos

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

### Input en exploración — Quicksave/Quickload

Mismo patrón de bug que en combate (`_input` bloqueado por prioridad en Godot 4.7): `player.gd` (script de una fase muy temprana del proyecto) tenía la lógica de `quicksave`/`quickload` en `_input()`, pero ese script ya no está en el árbol de ninguna escena activa — el nodo `Player` real usa `PlayerExploration` (`scenes/exploration/player_exploration.gd`). La lógica se movió a `ExplorationController._unhandled_input()` (F5 / F9), que ya gestionaba el resto del input de exploración (`interact`, `open_inventory`, `open_party`, `open_player_menu`) correctamente.

`player.gd`/`player.tscn` (`scenes/player/`) no se usan en ninguna escena activa, pero **su limpieza queda aparcada**: `test/test_shop_ui.gd` sigue cargando `player.tscn` como andamiaje. No se tocan hasta una revisión general de la carpeta `test/`.

**Bug conocido, sin resolver:** F9 (quickload) en una sesión activa ya en `EXPLORATION` (a diferencia de "Cargar Partida" desde el menú, que sí funciona) provoca un bloqueo total de input — ni movimiento ni menús responden, sin errores en Output/Debugger. Se descartaron como causa: bloqueo por `GameState` (`SAVE_TRANSITION` nunca se dispara en el proyecto), `get_tree().paused`, captura de input por `WorldObjectInteractionPanel`, y pérdida de foco de ventana. Causa raíz aún no confirmada — ver `docs/spike_produccion_post_character_creation_informe_cierre.md`.

**Spike 1 Motor Narrativo añadió F1** como tecla de debug temporal en `_unhandled_input()` para disparar `GameLoop.enter_narrative_scene("test_intro")` — desechable, a eliminar antes de Spike 3. No usa InputMap (tecla física directa vía `event.keycode == KEY_F1`) para no dejar una acción huérfana en Project Settings tras borrarla.

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

---

*Última actualización: Spike 2 — Reglas de RuneQuest para el Motor Narrativo (seis de seis puntos del alcance cerrados y validados) — `SkillRoller.RollResult` a 5 grados con `CRITICAL`/`SPECIAL` dinámicos (skill/20, skill/5); progresión de skill narrativa vía `SourceType.NARRATIVE`; tiradas acumulativas con contador de racha en el ViewModel; tiradas agregadas de grupo sin tabla de resistencia (oposición codificada en `roll_modifier`); moral de grupo y refuerzos cronometrados en combate vía `CombatEncounterDefinition` (nuevo, opcional en `start_combat()`) y `GameLoopSystem.configure_active_encounter()`. Modificador dinámico multiplicativo de combate aplazado a Spike 3 por falta de caso real. Dos hallazgos de GDScript reutilizables: un `match` sin rama `_:` y un array indexado por enum no avisan si el enum crece sin revisar todos sus consumidores. Ver `docs/spike_2_reglas_runequest_informe_cierre.md` para el detalle completo.

*Última actualización anterior: Spike 1 Motor Narrativo (pivote hacia RPG narrativo) — nuevo sistema `core/narrative_scenes/` + `ui/narrative_scene/` (patrón MVVM, sin system runtime propio, solo registry síncrono), `GameState.NARRATIVE_SCENE` añadido a GameLoop con integración de combate y cierre desacoplado vía EventBus, escena de prueba desechable y tecla de debug F1 temporal en ExplorationController. Dos lecciones de GDScript registradas (self-reference por class_name, colisión de SceneState con clase nativa) y una de testing (nodo raíz "ExplorationScene" requerido para ejecutar exploration_test.tscn suelto). Spike Producción Post-Character-Creation (Grupo A) — escena de exploración de producción (`exploration_tutorial.tscn`), registro en frío de Resources/Skills en `load_game()`, nombre de personaje visible en PlayerMenuScreen. Pendientes abiertos: posición no restaurada en arranque en frío, bloqueo de input tras F9 en caliente, limpieza de `player.gd` aparcada. Godot 4.7.1.*
