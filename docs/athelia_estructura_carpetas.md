# Athelia — Estructura de carpetas
 
Árbol de carpetas y ficheros con una línea por entrada. El comportamiento de cada sistema está en `athelia_referencia_sistemas.md`; la historia de cada cambio, en `athelia_historial_spikes.md`.
 
Leyenda: `[Autoload: X]` = singleton global · `[obsoleto]` = candidato a borrar, sin uso en el camino jugable · `[test]` = solo desarrollo.
 
```
athelia/
├── assets/                          # Assets globales (tiles, sprites)
│
├── core/                            # Núcleo: sistemas puros sin UI
│   ├── event_bus.gd                 # [Autoload: EventBus]
│   ├── game_loop_system.gd          # [Autoload: GameLoop] estados globales + fases de turno
│   ├── scene_orchestrator.gd        # [Autoload: SceneOrchestrator] overlays y escenas
│   │
│   ├── characters/
│   │   ├── character_system.gd      # [Autoload: Characters]
│   │   ├── character_definition.gd  # Resource estático (+ token_color, type_icon)
│   │   ├── character_state.gd       # Resource runtime (character_name solo se rellena para el jugador)
│   │   ├── loadout_state.gd         # estado de loadout (campo de CharacterState)
│   │   ├── attribute_resolver.gd    # atributos derivados
│   │   └── modifier_applicator.gd   # [Autoload: Modifiers]
│   │
│   ├── combat/
│   │   ├── combat_system.gd         # [Autoload: Combat]
│   │   ├── combat_loot_spawner.gd   # [Autoload: CombatLootSpawner]
│   │   ├── enemy_world_link.gd      # [Autoload: EnemyWorldLink] sin casos de uso reales
│   │   ├── combat_encounter_definition.gd  # moral, refuerzos, sorpresa, background_path
│   │   ├── defense_module.gd
│   │   ├── escape_module.gd
│   │   ├── skill_roller.gd          # tiradas D100 de 5 grados
│   │   └── enemy_ai.gd              # IA de enemigos (extends Node)
│   │
│   ├── companions/
│   │   ├── party_manager.gd         # [Autoload: Party]
│   │   ├── party_event_handler.gd   # [Autoload: PartyEventHandler]
│   │   └── companion_ai.gd
│   │
│   ├── dialogue/
│   │   ├── dialogue_system.gd       # [Autoload: Dialogue]
│   │   ├── dialogue_registry.gd     # [Autoload: DialogueDB] escaneo recursivo
│   │   ├── dialogue_definition.gd   # + portrait_folder, background_id
│   │   ├── dialogue_node_definition.gd  # + mood
│   │   └── dialogue_option_definition.gd  # + triggers_save
│   │
│   ├── economy/
│   │   ├── economy_system.gd        # [Autoload: Economy] (incluye préstamos quest_loan y reset_session())
│   │   ├── price_calculator.gd
│   │   ├── shop_definition.gd
│   │   ├── shop_instance.gd
│   │   ├── shop_item_state.gd
│   │   └── shop_view_state.gd
│   │
│   ├── items/
│   │   ├── item_registry.gd         # [Autoload: Items]
│   │   ├── inventory_system.gd      # [Autoload: Inventory]
│   │   ├── equipment_manager.gd     # [Autoload: Equipment]
│   │   ├── item_character_bridge.gd # [Autoload: Bridge] ítems ↔ Character/Resources/Skills
│   │   ├── item_character_integration.gd  # [obsoleto] código muerto
│   │   ├── item_definition.gd
│   │   ├── item_instance.gd
│   │   └── modifier_definition.gd
│   │
│   ├── narrative/                   # hitos y eventos recordados (NO confundir con narrative_scenes/)
│   │   ├── narrative_system.gd      # [Autoload: Narrative] flags y variables
│   │   ├── narrative_registry.gd    # [Autoload: NarrativeDB]
│   │   ├── narrative_event_definition.gd
│   │   ├── narrative_state.gd
│   │   ├── checkpoint_system.gd     # [Autoload: Checkpoints]
│   │   ├── checkpoint_registry.gd   # [Autoload: CheckpointDB]
│   │   ├── checkpoint_definition.gd
│   │   └── checkpoint_state.gd
│   │
│   ├── narrative_scenes/            # motor de escenas narrativas
│   │   ├── narrative_scene_registry.gd    # [Autoload: NarrativeSceneDB]
│   │   ├── narrative_scene_definition.gd
│   │   ├── narrative_scene_option.gd
│   │   └── narrative_scene_outcome.gd     # combate, victoria, dialogo, grant/take item, grant recurso
│   │
│   ├── interactive_scenes/          # motor de escenas interactivas (mapa de puntos de interés)
│   │   ├── interactive_scene_registry.gd  # [Autoload: InteractiveSceneDB] sin recursión
│   │   ├── interactive_scene_definition.gd  # scene_id, image_path, hotspots, on_first_visit
│   │   └── interactive_hotspot_definition.gd
│   │
│   ├── adventures/
│   │   └── adventure_starter.gd     # AdventureStarter.apply(): companions y kit inicial (no idempotente)
│   │
│   ├── resources/
│   │   ├── resource_system.gd       # [Autoload: Resources]
│   │   ├── resource_definition.gd
│   │   ├── resource_state.gd
│   │   └── resource_bundle.gd
│   │
│   ├── save/
│   │   ├── save_system.gd           # [Autoload: SaveManager]
│   │   └── save_data.gd
│   │
│   ├── session/
│   │   ├── entity_lifecycle.gd      # EntityLifecycle.unregister_everywhere()
│   │   └── session_reset.gd         # SessionReset.apply() al entrar en MENU
│   │
│   ├── skills/
│   │   ├── skill_system.gd          # [Autoload: Skills] (+ learn_skill())
│   │   ├── skill_progression_service.gd  # [Autoload: SkillProgression]
│   │   ├── skill_event_handler.gd   # [Autoload: SkillEventHandler]
│   │   ├── stress_system.gd         # [Autoload: Stress]
│   │   ├── skill_definition.gd
│   │   ├── skill_instance.gd
│   │   └── learning_session.gd      # SourceType: TRAINER, BOOK, PRACTICE, NARRATIVE
│   │
│   └── world_objects/               # sin uso en el camino jugable
│       ├── world_object_system.gd   # [Autoload: WorldObjectSystem]
│       ├── world_object_registry.gd # [Autoload: WorldObjects]
│       ├── world_object_definition.gd
│       ├── world_object_state.gd
│       ├── world_object_bridge.gd
│       ├── interaction_definition.gd
│       ├── interaction_outcome.gd
│       ├── loot_table_definition.gd
│       └── loot_entry.gd
│
├── data/
│   ├── characters/
│   │   ├── player_base.tres         # plantilla de TEST/DEBUG
│   │   ├── player_new.tres          # plantilla real de Character Creation (kit fijo de skills)
│   │   ├── enemy_base.tres
│   │   ├── wolf_test.tres
│   │   ├── telmori/                 # personajes de la aventura Los Telmori
│   │   │   ├── telmori_warrior_base.tres / telmori_warrior_weak.tres
│   │   │   ├── telmori_wolf_base.tres / telmori_wolf_weak.tres
│   │   │   └── icons/               # iconos de tipo 128×128 PNG
│   │   ├── icons/                   # iconos de tipo de enemigos genéricos (se COPIA el fichero, no se apunta a carpetas de aventura)
│   │   ├── companions/
│   │   │   ├── companion_base.tres
│   │   │   └── companion_mira.tres
│   │   └── portrait/                # retratos PNG
│   │       └── telmori/             # por aventura (portrait_folder): <id>.png + <id>_<mood>.png
│   │
│   ├── combat/backgrounds/telmori/  # mapas de batalla cenitales, uno por encuentro (background_path)
│   │
│   ├── adventures/
│   │   └── telmori.json             # companions + starting_gear por entidad
│   │
│   ├── dialogue/                    # JSON de diálogos
│   │   ├── dialogue_prince_intro.json, dlg_companion_mira_01.json, dlg_maestro_01.json, dlg_trainer_01.json, …
│   │   ├── telmori/
│   │   │   ├── (briefing del sheriff)            # hub con guardado, DLG_TELMORI_SHERIFF_BRIEFING
│   │   │   ├── dlg_telmori_sheriff_reward.json
│   │   │   ├── dlg_telmori_sheriff_training.json
│   │   │   └── dlg_telmori_tavern_keeper.json    # esqueleto; retrato/fondo provisionales
│   │   └── backgrounds/
│   │       ├── telmori.png          # fondo genérico de la aventura
│   │       └── telmori/sheriff_office.png
│   │
│   ├── ui/
│   │   └── inventory_categories.json  # categorías del inventario (versión 1, por prioridad)
│   │
│   ├── formulas/derived_attributes.json
│   │
│   ├── items/                       # .tres y PNG
│   │   ├── book_combat_basic, health_potion, stamina_potion_small, lockpick_quality, steel_sword …
│   │   ├── telmori/                 # ítems de la aventura: silver_arrow, telmori_magic_bag, obsidian_spearhead, wolf_tail_trophy, book_tanning_basics
│   │   └── weapons/<slot>/          # por slot: weapon, body, head, feet, shield, accesory
│   │       └── weapon/enchanted_spear.tres   # tag quest_loan (préstamo)
│   │
│   ├── narrative/
│   │   ├── checkpoints.json
│   │   └── narrative_events.json
│   │
│   ├── interactive_scenes/
│   │   ├── poi_test_map.json        # mapa de PRUEBA
│   │   ├── telmori_village.json     # el pueblo real (hub, 11 hotspots)
│   │   ├── images/mapa_aldea_telmori.jpg
│   │   └── icons/telmori/           # medallones PNG: icon_sheriff / blacksmith / tavern / exit
│   │
│   ├── narrative_scenes/            # un JSON por escena (Los Telmori: pueblo, guarida, recompensa)
│   │   │                            # sin uso: telmori_sheriff_briefing, telmori_equipment_arrows/_spear
│   │   │                            # marcador: telmori_village_departure (salida final)
│   │   │                            # renombrar: telmori_lair_loot_obsidian.json.json
│   │   └── images/telmori/          # fondos de escena 16:9, por TIPO de escenario (no por escena)
│   │
│   ├── resources/                   # gold.tres, health.tres, stamina.tres
│   ├── shops/                       # blacksmith_01.tres, blacksmith_telmori.tres
│   ├── skills/                      # combat/ (melee, ranged), enemy/, exploration/ (incl. search, track, stealth, tanning)
│   └── world_objects/               # chest, loot tables
│
├── debug/                           # herramientas de debug (no activas en producción)
│
├── docs/                            # informes de cierre y referencias (ver nota abajo)
│
├── localization/                    # CSV → .translation (ES/EN)
│   ├── translations.csv             # textos generales (+ SKILL_TREE_*, SKILL_SUBCATEGORY_*, SKILL_FILTER_*)
│   ├── dialogues.csv
│   ├── dialogues_scenes_telmori.csv
│   ├── skills.csv                   # SKILL_<ID>_NAME / _DESC de todas las habilidades
│   ├── shops.csv                    # SHOP_*
│   ├── inventory.csv                # INVENTORY_* (58 claves)
│   ├── party.csv                    # PARTY_* (34 claves)
│   ├── items.csv
│   ├── items_telmori.csv
│   ├── world_objects.csv
│   ├── menus.csv                    # menú + GAMEOVER_*  (columnas id,es,en)
│   ├── character_creation.csv
│   ├── narrative_scenes.csv
│   ├── narrative_scenes_telmori.csv
│   ├── characters_telmori.csv
│   ├── combat.csv                   # log de combate
│   └── (cada .csv genera .en.translation y .es.translation; alta manual en Project Settings → Localization)
│
├── scenes/
│   ├── combat/
│   │   ├── combat_production_scene.gd / .tscn  # producción: sin UI (IA + PlayerCombatController); es SCENE_COMBAT
│   │   ├── combat_test.tscn, combat_test_scene.gd  # escena de test independiente
│   │   └── enemy_combat_node.gd / .tscn         # sin uso en producción; solo combat_test
│   ├── companions/                  # companion_base.tscn, companion_mira.tscn
│   ├── exploration/
│   │   ├── exploration_controller.gd   # input y request_interaction() (único punto de routing)
│   │   ├── exploration_hud.gd
│   │   ├── player_exploration.gd
│   │   ├── companion_follow_node.gd
│   │   ├── interactable.gd             # [obsoleto] vestigial
│   │   ├── interactive_map/            # escena raíz de producción (sin Player ni cámara)
│   │   │   ├── exploration_interactive_map.tscn   # es SCENE_EXPLORATION
│   │   │   └── exploration_interactive_map.gd
│   │   ├── exploration_test.tscn / .gd # [obsoleto]
│   │   ├── tutorial/                   # [obsoleto]
│   │   └── telmori_village/            # [obsoleto] sustituida por telmori_village.json
│   ├── player/
│   │   ├── player.gd / player.tscn     # [obsoleto] código muerto (los referencia test/test_shop_ui.gd)
│   │   ├── player_combat_controller.gd # dueño del targeting y de request_skill()
│   │   ├── player_ui.gd / .tscn
│   │   └── save_feedback_ui.gd / .tscn
│   └── test/test.tscn
│
├── test/                            # [test] unitarios e integración
│   ├── test_character_creation_viewmodel.gd, test_narrative_scene_viewmodel.gd,
│   │   test_group_morale.gd, test_character_persistence.gd, test_spike6_investigacion.gd,
│   │   test_tokens_alias.gd, …
│   └── test_narrative_system.gd     # eventos narrativos, NO el motor de escenas
│
└── ui/
    ├── damage_number.gd / .tscn     # (duplicado en ui/combat/: limpieza pendiente)
    ├── entity_animation_controller.gd
    │
    ├── combat/
    │   ├── combat_arena_viewmodel.gd    # compone a combat_hub_viewmodel como action_menu
    │   ├── combat_arena_panel.gd / .tscn  # pantalla de producción (OVERLAY_COMBAT_HUD)
    │   ├── combat_hub_viewmodel.gd      # menú de 8 acciones
    │   ├── combat_token_data.gd, log_entry_data.gd
    │   ├── combat_hud.gd / .tscn        # solo para combat_test
    │   └── damage_number.tscn
    │
    ├── character_creation/          # viewmodel + screen + tscn
    ├── dialogue/                    # viewmodel, panel (.gd/.tscn), dialogue_panel_test, option_button.tscn
    ├── gameover/                    # game_over_viewmodel.gd, game_over_ui.gd / .tscn
    ├── interactive_scene/           # interactive_scene_viewmodel.gd, interactive_scene_view.gd (vista permanente, capa -1)
    ├── inventory/
    │   ├── inventory_viewmodel.gd
    │   ├── inventory_ui.gd / .tscn
    │   ├── bag_capacity.gd          # BagCapacity: único punto de capacidad
    │   ├── item_detail_panel.gd / .tscn   # extends UIPanel; set_compact() para Party
    │   ├── item_detail_data.gd            # ItemDetailData (+ ModLine, CompareLine)
    │   ├── item_detail_builder.gd         # ItemDetailBuilder: modificadores, comparación y formato por entidad
    │   └── feedback_popup.gd / .tscn
    ├── loadout/                     # viewmodel + screen + tscn  (pendiente de rediseño: Spike 20)
    ├── loading_screen/              # loading_screen.gd / .tscn  (sin conectar al orquestador)
    ├── main_menu/                   # viewmodel + screen + tscn  (Main Scene del proyecto)
    ├── narrative_scene/             # viewmodel, panel (.gd/.tscn)
    ├── party/
    │   ├── party_viewmodel.gd
    │   └── party_ui.gd / .tscn
    ├── player_menu/                 # viewmodel + screen + tscn
    ├── shop/
    │   ├── shop_viewmodel.gd
    │   ├── shop_ui.gd / .tscn
    │   └── shop_item_slot.gd / .tscn  # fila de lista (extends UIPanel)
    ├── skill_tree/                  # viewmodel + screen + tscn  (pendiente de rediseño: Spike 21)
    ├── world_objects/               # panel vestigial
    │
    └── design_system/
        ├── components/
        │   ├── ui_button/           # + min_square, icon_backdrop
        │   ├── ui_panel/            # + decorative_frame, corner_texture
        │   ├── ui_slot/             # + owner_id, slot_item_dropped
        │   ├── ui_resource_bar/
        │   ├── ui_radial_gauge/     # anillo de progreso (_draw())
        │   └── ui_combat_token/     # ficha de combate (3 scripts helper sin class_name)
        ├── assets/
        │   ├── icons/icon_item_placeholder.png   # silueta 64×64, se tiñe con COLOR_TEXT_MUTED
        │   └── frames/frame_corner_64x64.png     # en uso (96×96 de reserva)
        ├── tests/                   # [test] ui_slot_drag_test.gd / .tscn
        ├── theme/main_theme.tres    # sin aplicar al proyecto
        └── tokens/ui_tokens.gd      # [Autoload: UITokens]
```
 
## Notas
 
- **Documentos de `docs/`:** un informe de cierre por spike (`docs/spike_N_*.md`) más referencias (`characters.md`, `referencia_buff_types.md`, `referencia_skill_definition.md`) y especificaciones. Los ficheros del tipo `spike_N_actualizaciones_docs.md` son bloques de inserción de trabajo, no documentación vigente.
- **Convención de nombres de escena:** `<tipo>_<identificador_semántico>.tscn`, nunca numeración secuencial. Scripts compartidos en la raíz de `scenes/<tipo>/`; cada zona en su subcarpeta.
- **Datos por aventura:** personajes e ítems propios van en subcarpeta de la aventura; ítems de arma con ranura se agrupan por tipo en `data/items/weapons/<slot>/`. Localización en un CSV propio por aventura.
- **Ficheros `*_bak.*`** son backups; `.gd.uid` es metadato de Godot. `.tres` son Resources de Godot; `.json` son datos legibles de narrativa, diálogos y escenas.