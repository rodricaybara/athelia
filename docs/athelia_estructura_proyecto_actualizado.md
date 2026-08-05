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
| `GameLoop` | `core/game_loop_system.gd` | Máquina de estados global del juego. Gestiona los estados (`MENU`, `CHARACTER_CREATION`, `EXPLORATION`, `DIALOGUE`, `SHOP`, `COMBAT_ACTIVE`, `VICTORY`, `DEFEAT`, `PAUSE`, `SAVE_TRANSITION`) y las fases de turno del combate (`ROUND_START → PLAYER_TURN → COMPANION_ACTION_RESOLVE → ENEMY_TURN → ROUND_END`). Controla la iniciativa, el orden de turno y las condiciones de victoria/derrota. |
| `SceneOrchestrator` | `core/scene_orchestrator.gd` | Reacciona a cambios de `GameState` (vía EventBus) para mostrar/ocultar overlays de UI (diálogo, tienda, inventario) y cargar/descargar la escena de combate. No modifica el estado del juego directamente, solo responde a él. |
| `SaveManager` | `core/save/save_system.gd` | Sistema de guardado y carga de partida. Slot único: `"quicksave"`. |
| `UITokens` | `ui/design_system/tokens/ui_tokens.gd` | Sistema de tokens de diseño (colores, espaciado, tamaños). Usado por todos los componentes del Design System. |

### Sistemas de personaje
| Singleton | Script | Descripción |
|-----------|--------|-------------|
| `Characters` | `core/characters/character_system.gd` | Gestión de personajes: creación, acceso y ciclo de vida. |
| `Modifiers` | `core/characters/modifier_applicator.gd` | Aplicación de modificadores sobre atributos de personajes. |
| `Resources` | `core/resources/resource_system.gd` | Gestión de recursos vitales (vida, stamina, oro). |
| `Skills` | `core/skills/skill_system.gd` | Sistema de habilidades: registro, acceso y uso. |
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
| `Narrative` | `core/narrative/narrative_system.gd` | Sistema narrativo principal. |
| `NarrativeDB` | `core/narrative/narrative_registry.gd` | Base de datos de eventos narrativos. |
| `Dialogue` | `core/dialogue/dialogue_system.gd` | Sistema de diálogo con NPCs. |
| `DialogueDB` | `core/dialogue/dialogue_registry.gd` | Base de datos de diálogos. |
| `Checkpoints` | `core/narrative/checkpoint_system.gd` | Sistema de checkpoints narrativos. |
| `CheckpointDB` | `core/narrative/checkpoint_registry.gd` | Base de datos de checkpoints. |

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
│   │   ├── skill_roller.gd         # Tiradas de habilidad en combate
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
│   ├── narrative/                  # Sistema narrativo
│   │   ├── narrative_system.gd     # [Autoload: Narrative]
│   │   ├── narrative_registry.gd   # [Autoload: NarrativeDB]
│   │   ├── narrative_event_definition.gd
│   │   ├── narrative_state.gd
│   │   ├── checkpoint_system.gd    # [Autoload: Checkpoints]
│   │   ├── checkpoint_registry.gd  # [Autoload: CheckpointDB]
│   │   ├── checkpoint_definition.gd
│   │   └── checkpoint_state.gd
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
│   │   ├── skill_progression_service.gd  # [Autoload: SkillProgression]
│   │   ├── skill_event_handler.gd  # [Autoload: SkillEventHandler]
│   │   ├── stress_system.gd        # [Autoload: Stress]
│   │   ├── skill_definition.gd     # Resource: definición de habilidad
│   │   ├── skill_instance.gd       # Estado de habilidad del personaje
│   │   └── learning_session.gd     # Sesión de aprendizaje de habilidad
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
│   └── spike_character_creation_informe_cierre.md  # ← NUEVO
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
│   ├── character_creation.csv      # ← NUEVO: textos de creación de personaje
│   ├── character_creation.en.translation
│   └── character_creation.es.translation
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
│   ├── exploration/
│   │   ├── exploration_test.tscn
│   │   ├── exploration_test.gd
│   │   ├── exploration_controller.gd
│   │   ├── exploration_hud.gd
│   │   ├── player_exploration.gd
│   │   ├── companion_follow_node.gd
│   │   └── interactable.gd
│   │
│   ├── player/
│   │   ├── player.gd
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
│   ├── test_character_creation_viewmodel.gd  # ← NUEVO: 30 asserts, ViewModel aislado
│   ├── test_character_persistence.gd         # ← NUEVO: roundtrip save/load de CharacterSystem
│   └── [otros test_*.gd por sistema]
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
    ├── character_creation/         # ← NUEVO (movido desde scenes/): creación de personaje (patrón MVVM)
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
    ├── loading_screen/             # ← NUEVO: pantalla de carga
    │   ├── loading_screen.gd
    │   └── loading_screen.tscn
    │
    ├── main_menu/                  # ← NUEVO: menú principal (patrón MVVM)
    │   ├── main_menu_viewmodel.gd
    │   ├── main_menu_screen.gd
    │   └── main_menu_screen.tscn   # ← Main Scene del proyecto
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
EXPLORATION → DIALOGUE, SHOP, COMBAT_ACTIVE, PAUSE, SAVE_TRANSITION
DIALOGUE → EXPLORATION, COMBAT_ACTIVE
SHOP → EXPLORATION
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

### SceneOrchestrator — Gestión de overlays

- Escucha `game_state_changed` vía EventBus y **nunca modifica GameState**.
- Los overlays (diálogo, tienda, inventario) se instancian y destruyen en cada apertura/cierre (`queue_free`).
- La escena de combate se carga de forma **aditiva** (la escena de exploración permanece en memoria debajo).
- El inventario es especial: se abre como overlay dentro de `EXPLORATION` sin cambiar `GameState`. Se accede vía `SceneOrchestrator.open_inventory()`.
- Hay un problema de timing conocido con la tienda (el evento `shop_opened` se emite antes de que el overlay exista); se resuelve llamando directamente a `show_shop_direct()` con un snapshot del `EconomySystem`.
- El menú principal es la **Main Scene** del proyecto. `_handle_main_menu()` solo limpia overlays residuales; no instancia nada.
- `_handle_character_creation()` usa `_show_overlay()` (igual que Shop/Inventory/Party) — importante: instanciarla manualmente contra `get_tree().root` sin pasar por `_show_overlay()` deja la escena huérfana de `_current_overlay`, y `_hide_current_overlay()` nunca la destruye al salir.
- `_handle_exploration()` instancia `SCENE_EXPLORATION` si no existe ya en el árbol (comprobando por nombre de nodo `"ExplorationScene"`) — necesario para el flujo real Menú → Character Creation → Exploration, no solo para correr `exploration_test.tscn` de forma aislada.

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

### Persistencia de personaje — CharacterSystem ↔ SaveSystem

`CharacterState` serializa `definition_id`, `character_name` y `attributes` vía `get_save_state()`/`load_save_state()`. Conectado a `SaveSystem` desde `SAVE_VERSION = 5` — `_restore_state()` restaura el snapshot de `CharacterSystem` **primero**, antes de recursos/skills, porque `load_save_state()` puede bootstrapear el registro de la entidad vía `definition_id` si no existe todavía.

**Pendiente conocido:** este bootstrap solo cubre `CharacterSystem`. `ResourceSystem`, `SkillSystem`, `Equipment` e `Inventory` siguen asumiendo que la entidad ya está registrada por otra vía al cargar — bloquea "Cargar Partida" desde un arranque en frío real (sin pasar antes por una escena que registre al jugador, como `exploration_test.gd`).

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

`player.gd`/`player.tscn` (`scenes/player/`) quedan como código candidato a limpieza — no se usan en ninguna escena activa actualmente.

---

## Notas de convenciones

- Los ficheros `*_bak.gd` y `*_bak.tscn` son backups de versiones anteriores, no están en uso activo.
- Los ficheros `.gd.uid` son metadatos de Godot, no contienen lógica.
- Los `_definition.gd` son Resources estáticos (datos). Los `_state.gd` son Resources dinámicos (runtime). Los `_system.gd` son los sistemas lógicos (autoloads o managers).
- La carpeta `test/` contiene tests unitarios y de integración, no se usa en producción.
- La carpeta `debug/` contiene herramientas de debug no activas en builds de producción.
- La localización cubre ES y EN con ficheros `.csv` compilados a `.translation`. Los `.csv` se registran en Project Settings → Localization → Translations; Godot genera los `.translation` automáticamente al recargar el proyecto.
- Todas las cadenas visibles en UI deben tener su clave en los `.csv` de localización. Nunca hardcodear texto en `.tscn` ni en scripts.
- Los `.tres` son Resources binarios de Godot; los `.json` son datos legibles para narrativa/diálogos.
- **Main Scene del proyecto:** `res://ui/main_menu/main_menu_screen.tscn`

---

*Última actualización: Spike Character Creation — flujo completo Menú → Character Creation → Exploration con persistencia de personaje (nombre, atributos, inventario) funcional de punta a punta. SAVE_VERSION 5.*
