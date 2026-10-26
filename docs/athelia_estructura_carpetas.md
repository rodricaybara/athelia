# Athelia — Estructura de carpetas
 
Árbol completo de carpetas y ficheros del proyecto. Para la referencia de
autoloads, sistemas y arquitectura actual, ver
`athelia_referencia_sistemas.md`.
 
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
│   ├── scene_orchestrator.gd       # [Autoload: SceneOrchestrator] Gestión de overlays y escenas — **Spike 13:** `_on_combat_ended` abre la escena de victoria pendiente (valida que exista; si no, `push_error` y vuelve a `EXPLORATION`) y no repite `enter_exploration()` tras una huida — **Spike 14:** al entrar en `MENU`, `_handle_main_menu()` libera las escenas de la partida (`_free_session_scenes()`: GameOverUI, CombatHud, CombatScene, ExplorationScene) y lanza `_run_session_reset()` (espera un frame, comprueba que el estado sigue en `MENU`/`CHARACTER_CREATION` y llama a `SessionReset.apply()`); `_game_over_ui` guarda la referencia al Game Over; `_show_game_over()` no lo instancia dos veces — **Spike 17:** `open_inventory()` y `open_party()` conectan `closed` a `_on_overlay_closed(overlay)` (libera la instancia; evita las dos pulsaciones de tecla); `close_inventory()` retirada
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
│   │   ├── party_manager.gd        # [Autoload: Party] — **Spike 14:** `_unregister_from_systems()` delega en `EntityLifecycle.unregister_everywhere()`; `_register_in_systems()` usa `SkillSystem.has_entity()` en vez de `_entity_skills` (queda un acceso privado: `_entity_skills.get(...).keys()`)
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
│   │   ├── economy_system.gd       # [Autoload: Economy] — **Spike 14:** `reset_session()` descarta las `ShopInstance` (stock y presupuesto mutados) y recarga las definiciones de `res://data/shops/` — **Spike 16b:** el tag `quest_loan` (`ItemDefinition.has_tag`) se trata como préstamo: `LOAN_TAG`, `_is_loan_item()`, `_take_loan()` y `_execute_loan_transaction()` (se toma sin coste y sin `PriceCalculator`, `trade_type = "loan"`); `sell_item` lo rechaza con `LOAN_ITEM`; las entradas de `items_for_sale` y `player_items_sellable` llevan `is_loan`
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
│   ├── session/                    # ← NUEVO (Spike 14): reinicio de sesión
│   │   ├── entity_lifecycle.gd     # `class_name EntityLifecycle` (RefCounted, `static func unregister_everywhere(entity_id)`): baja completa en Characters (con `has_entity`) → Resources → Skills → Equipment → Inventory. Idempotente. La usan `PartyManager` y `SessionReset`
│   │   └── session_reset.gd        # `class_name SessionReset` (RefCounted, `static func apply()`): coordinador de orden fijo, solo APIs públicas — `Dialogue.reset()`, `Combat.clear_buffs()`, `Party.leave_party()`, `EntityLifecycle`, `Narrative.clear_all()`, `Checkpoints.reset()`, `Economy.reset_session()`. Lo llama `SceneOrchestrator` al entrar en `MENU` (tras liberar las escenas de la partida)
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
│   ├── ui/                         # ← NUEVO (Spike 18): datos de pantallas
│   │   └── inventory_categories.json   # categorías del inventario (versión 1; prioridad: quest 10, weapons 20, armor 30, consumables 40)
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
│   │       │   └── enchanted_spear.tres   # Spike 3, Grupo B — ítem de ranura manda sobre aventura — **Spike 16b:** tag `quest_loan` (`base_value = 0`): la tienda lo trata como préstamo (se toma sin coste, no se vende)
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
│   │   └── blacksmith_telmori.tres   # ← NUEVO (Spike 13) — tienda propia de la aventura: stock de blacksmith_01 + `enchanted_spear` (valor 0, `quest_loan`: **Spike 16b** — se toma en préstamo desde la tienda, sin coste y sin poder venderse) y 20 `silver_arrow` (2 de oro c/u); `max_slots` 16 (con 12 no cabían las dos armas nuevas)
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
│   ├── spike_13_reautoria_pueblo_telmori.md  # ← NUEVO (Spike 13): el pueblo de Los Telmori sobre el motor de escenas interactivas — resultado, plan frente a lo hecho, validación
│   ├── spike_14_reinicio_sesion.md  # ← NUEVO (Spike 14): reinicio de sesión y teardown — causa raíz, `SessionReset`/`EntityLifecycle`, Game Over con ViewModel, validación en partida real y pendientes
│   ├── spike_15_cimientos_design_system.md  # ← NUEVO (Spike 15): cimientos del Design System — resolución (sin estiramiento, con el experimento), tokens fusionados con alias, `UIPanel`, diálogo en rejilla, localización (`skills.csv`), validación y pendientes
│   ├── spike_16_tienda.md  # ← NUEVO (Spike 16, incluye la 16b): tienda sobre el Design System — decisiones y correcciones de la Fase 0, préstamo `quest_loan`, 23 claves `SHOP_*`, validación en partida real, lecciones y pendientes (16c: devolución del préstamo al sheriff, sin planificar)
│   ├── spike_17_inventario_mvvm.md  # ← NUEVO (Spike 17): inventario con contrato MVVM — decisión 5.A, accesos movidos al ViewModel, hallazgos de motor (dos pulsaciones, Esc), validación y pendientes
│   ├── spike_18_inventario_rediseno.md  # ← NUEVO (Spike 18): inventario rediseñado con el Design System — decisiones, layout, API de `UISlot`, bonos del equipo, validación, hallazgos y pendientes
│   ├── spike_18_actualizaciones_docs.md  # ← NUEVO (Spike 18): bloques de inserción usados para actualizar la documentación del proyecto
│   ├── spike_19_party.md  # ← NUEVO (Spike 19, 19a): Party sobre el Design System — decisiones (P1–P8, Q1/Q2, L3), `PartyViewModel`, `BagCapacity`, cambios en `UISlot`, bugs reproducidos y corregidos, validación en partida real, lecciones y pendientes (19b)
│   └── spike_19_actualizacion_docs.md  # ← NUEVO (Spike 19): textos usados para actualizar la documentación del proyecto
│
├── localization/                   # Sistema de localización (ES/EN)
│   ├── translations.csv            # Textos generales — **Spike 19:** retiradas las 3 claves `PARTY_ERROR_*` (ahora en `party.csv`) — **Spike 15:** 29 claves duplicadas eliminadas (idénticas a su primera copia) y las `SKILL_<ID>_NAME`/`_DESC` movidas a `skills.csv`; se quedan aquí `SKILL_TREE_*`, `SKILL_SUBCATEGORY_*` y `SKILL_FILTER_*` (textos de pantalla)
│   ├── translations.en.translation
│   ├── translations.es.translation
│   ├── dialogues.csv               # Textos de diálogos
│   ├── dialogues.en.translation
│   ├── dialogues.es.translation
│   ├── dialogues_scenes_telmori.csv    # Grupo 2 (briefing del sheriff) + Spike 10 (+12 claves: los dos diálogos de recompensa y entrenamiento) — CSV propio por aventura — **Spike 13:** +7 claves (`DLG_SHERIFF_OPT_LEAVE` y las 6 del posadero `DLG_TAVERN_*`); modificadas `DLG_SHERIFF_04_WEAPONS` (ahora remite a la herrería) y `DLG_SHERIFF_REWARD_01_GREET` (frase de devolución de la lanza) — **Spike 15:** `DLG_SHERIFF_REWARD_01_GREET` entrecomillada (la fila tenía comas sin comillas: 5 columnas en vez de 3) y + `SPEAKER_INNKEEPER` (Innkeeper / Posadero)
│   ├── dialogues_scenes_telmori.en.translation
│   ├── dialogues_scenes_telmori.es.translation
│   ├── skills.csv                  # ← NUEVO (Spike 15) — `SKILL_<ID>_NAME` / `SKILL_<ID>_DESC` de TODAS las habilidades (formato `id,en,es`): 13 que estaban en `translations.csv` + 7 que no tenían traducción (`ENEMY_BASIC_ATTACK`, `LOCKPICK`, `PERCEPTION`, `SEARCH`, `SPRINT`, `STEALTH`, `TRACK`). Requiere alta manual en Project Settings → Localization → Translations
│   ├── skills.en.translation
│   ├── skills.es.translation
│   ├── shops.csv                   # **Spike 16:** + 23 claves `SHOP_*` de la pantalla de tienda (formato `id,en,es`): título, cabeceras (oro, huecos), precio/cantidad, botones Comprar/Vender/Cerrar, tooltips (`NO_GOLD`, `NO_BUDGET`, `NO_STOCK`, `NO_SLOTS`), listas vacías y `SHOP_TRADE_SOLD`; **16b:** `SHOP_PRICE_LOAN`, `SHOP_TAKE`, `SHOP_TOOLTIP_LOAN`, `SHOP_TRADE_LOANED`, `SHOP_ERROR_LOAN_ITEM`. Ya contenía `SHOP_TELMORI_BLACKSMITH_NAME/DESC`. `translations.csv` conserva `SHOP_BLACKSMITH_*`, `SHOP_TRADE_SUCCESS` y `SHOP_ERROR_*`. Registrado en Project Settings → Localization → Translations
│   ├── shops.en.translation
│   ├── shops.es.translation
│   ├── inventory.csv               # ← NUEVO (Spike 17) — 29 claves `INVENTORY_*` (formato `id,en,es`): título, cabeceras, etiquetas de estadísticas, nombres de slot, detalle, botones y mensajes de feedback/error. Requiere alta manual en Project Settings → Localization → Translations (sin ella, `tr(key) % args` falla con error de formato) **Spike 18:** 58 claves (+29): categorías, contadores de huecos y peso, marca y tooltip de equipado, comparación, nombres de modificadores `INVENTORY_MOD_*`, estadísticas (INT/WIS/CHA/FOCUS), bonos del equipo (`INVENTORY_BONUS_*`) y `ERROR_EQUIP_FAILED`. Sin usar: `INVENTORY_BAG_HEADER`, `INVENTORY_STATS_HEADER`
│   ├── inventory.en.translation
│   ├── inventory.es.translation
│   ├── party.csv                   # ← NUEVO (Spike 19) — 27 claves `PARTY_*` (formato `id,en,es`): título, nombre del jugador, «Sin compañeros», contador de huecos, nombres de slot, estrategias (`PARTY_STRATEGY_*`; `AREA_FOCUS` = «Ataque en área»), tooltips, errores y feedback (sin género gramatical en los mensajes). Incluye las 3 `PARTY_ERROR_*` que estaban en `translations.csv`; `PARTY_ERROR_WRONG_SLOT` ahora recibe ítem y slot. Requiere alta manual en Project Settings → Localization → Translations
│   ├── party.en.translation
│   ├── party.es.translation
│   ├── items.csv                   # Nombres y descripciones de ítems — Spike 3, Grupo D añade ITEM_BOOK_TANNING_NAME/DESC (libro sin ranura, en el CSV general, no en items_telmori.csv — misma práctica que silver_arrow/enchanted_spear de Grupo B). Spike 10 añade ITEM_SILVER_ARROW_NAME/DESC e ITEM_ENCHANTED_SPEAR_NAME/DESC, que faltaban desde Grupo B
│   ├── items.en.translation
│   ├── items.es.translation
│   ├── world_objects.csv           # Textos de objetos del mundo — **Spike 15:** eliminada la segunda `WORLD_OBJECT_DEPLETED`; se conserva «Nothing more to do here» / «No queda nada más que hacer aquí»
│   ├── world_objects.en.translation
│   ├── world_objects.es.translation
│   ├── menus.csv                   # Textos de menús (menú principal, opciones, créditos) — **Spike 14:** + `GAMEOVER_TITLE`, `GAMEOVER_MESSAGE`, `GAMEOVER_BUTTON_MENU` (esta hoja tiene el orden de columnas `id,es,en`, al revés que el resto)
│   ├── menus.en.translation
│   ├── menus.es.translation
│   │                                  # Convención de claves (Spike 15): `PANTALLA_ELEMENTO`, prefijo de pantalla en mayúsculas; los campos con comas van entrecomillados; todos los CSV son `id,en,es` salvo `menus.csv` (`id,es,en`)
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
    │   ├── character_creation_viewmodel.gd  # Spike 3/B: kit inicial de skills leído de player_new.tres, ya no de una constante duplicada (STARTING_SKILL_VALUES, eliminada) — **Spike 13:** llama a `AdventureStarter.apply(DEFAULT_ADVENTURE_ID)` tras `_create_player_entity()` (companions y kit salen a `data/adventures/`); `STARTING_ITEMS` vaciado — **Spike 14:** `_create_player_entity()` usa `skills.has_entity("player")` en vez de `_entity_skills`
    │   ├── character_creation_screen.gd
    │   └── character_creation_screen.tscn
    │
    ├── design_system/              # Sistema de diseño centralizado
    │   ├── components/
    │   │   ├── ui_button/
    │   │   │   ├── ui_button.gd   # Spike 13: + `min_square` (botón cuadrado de solo icono) e `icon_backdrop` (disco oscuro semitransparente tras el icono) — ambos opt-in, apagados por defecto
    │   │   │   └── ui_button.tscn
    │   │   ├── ui_panel/           # Spike 9: + decorative_frame / corner_texture (marco ornamental opt-in, _draw() sobre el propio panel; con el marco activo anula borde y corner_radius del stylebox) — **Spike 15:** esquinera por defecto (`UITokens.FRAME_CORNER_TEXTURE_PATH`) si no hay `corner_texture`, padding mínimo con marco (`FRAME_MIN_PADDING`), setters con `is_node_ready()` (activación en runtime), `push_warning` fuera de `_draw()` y una sola vez, docstring corregido (`OVERLAY` es opaco) — **Spike 16:** consumidores reales: `DEFAULT` (cabeceras y filas `ShopItemSlot` de la tienda) y `OVERLAY` (panel principal de la tienda, con marco)
    │   │   │   ├── ui_panel.gd
    │   │   │   └── ui_panel.tscn
    │   │   ├── ui_slot/
    │   │   │   ├── ui_slot.gd             # Spike 15: solo el docstring (ruta `components/ui_slot/`). **Spike 18:** primer consumidor real (inventario) — `set_definition()`, `is_empty()`, flags `set_selected/set_equipped_mark/set_overflow`, `border_color_override`, `draggable`, `drop_source_filter`, clic al soltar, placeholder para ítems sin icono, borde discontinuo con `_draw()`. **Spike 19:** + `owner_id` (id opaco del dueño del slot; viaja en el payload del arrastre) y señal `slot_item_dropped(slot, item_id, from_owner_id)`, emitida justo después de `slot_drop_received`; Party es el segundo consumidor real
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
    │   │   ├── icons/              # ← NUEVO (Spike 18)
    │   │   │   └── icon_item_placeholder.png   # silueta de bolsa 64×64 para ítems sin icono; se tiñe con COLOR_TEXT_MUTED
    │   │   └── frames/             # ← NUEVO (Spike 9)
    │   │       ├── frame_corner_64x64.png   # en uso: esquinera única, se rota en las 4 esquinas
    │   │       └── frame_corner_96x96.png   # reserva; invadía el texto del panel narrativo
    │   ├── tests/                  # ← NUEVO (Spike 18): solo desarrollo, no entra en el juego
    │   │   ├── ui_slot_drag_test.gd    # prueba aislada de UISlot (F6): clic, selección, arrastre y drop; ítems de respaldo si no hay partida
    │   │   └── ui_slot_drag_test.tscn
    │   ├── theme/
    │   │   └── main_theme.tres     # Tema global de UI
    │   └── tokens/
    │       └── ui_tokens.gd        # [Autoload: UITokens] Tokens de diseño — Grupo 5: + COLOR_GAUGE_HP_PARTY/EN_PARTY/HP_ENEMY, COLOR_TURN_INDICATOR, COLOR_TOKEN_FILL_DEFAULT, COLOR_LOG_FUMBLE/FAILURE/CRITICAL (SPECIAL reutiliza COLOR_TURN_INDICATOR, SUCCESS reutiliza el font_color normal del tema). Spike 9: + COLOR_FRAME_OUTER/FILLET/INNER, FRAME_OUTER_WIDTH/FILLET_WIDTH/INNER_WIDTH/GAP (marco decorativo de UIPanel). **Spike 15:** dos vocabularios fusionados con alias (`BG_BASE→COLOR_BG`, `BG_PANEL→COLOR_PANEL`, `BG_SURFACE→COLOR_PANEL_ALT`, `BORDER_DEFAULT→COLOR_BORDER`, `TEXT_PRIMARY→COLOR_TEXT`, `TEXT_MUTED→COLOR_TEXT_MUTED`, `COLOR_SLOT_OCCUPIED→COLOR_PANEL_ALT`); `COLOR_TEXT_MUTED` → `#9A8E78` y `COLOR_PANEL_ALT`/`BG_SURFACE` → `#252220`; tabla de equivalencias de radios; + `FRAME_MIN_PADDING` y `FRAME_CORNER_TEXTURE_PATH`
    │
    ├── dialogue/                   # Panel de diálogo (patrón MVVM)
    │   ├── dialogue_viewmodel.gd
    │   ├── dialogue_panel.gd       # **Spike 15:** opciones en `GridContainer` (1 columna hasta 3, 2 desde 4) con altura natural reservada, margen del texto calculado desde el borde derecho real del retrato (`PORTRAIT_TEXT_GAP`), foco inicial en la primera opción con estilo de hover; `MarginContainer` y `OptionsScroll` referenciados por nombre único (`%`)
    │   ├── dialogue_panel.tscn     # **Spike 15:** `OptionsContainer` es un `GridContainer` (`columns = 1`, `h_separation`/`v_separation` 4); `MarginContainer` y `OptionsScroll` con nombre único; sin `margin_left` fijo en el editor
    │   ├── dialogue_panel_test.gd
    │   ├── dialogue_panel_test.tscn
    │   └── option_button.tscn
    │
    ├── gameover/                   # Pantalla de Game Over
    │   ├── game_over_viewmodel.gd  # ← NUEVO (Spike 14): ViewModel mínimo — `PanelState { HIDDEN, SHOWING, TRANSITIONING }`, razones `"opened"`/`"transitioning"`, una intención `request_return_to_menu()` (`await` de un frame + `GameLoop.enter_main_menu()`; reabre el botón si la transición falla)
    │   ├── game_over_ui.gd         # Spike 14: solo renderiza y delega (sin Narrative/Checkpoints/Party/GameLoop); botón único `%ReturnToMenuButton`, textos por `tr()` en `_setup_static_text()`; `show_game_over()` sigue siendo la API que llama el orquestador (antes, Spike 3/B: `_on_new_game_pressed()` hacía `enter_main_menu()` + `enter_character_creation()` — retirado)
    │   └── game_over_ui.tscn       # Spike 14: `TitleLabel`/`MessageLabel`/`ReturnToMenuButton` por nombre único, textos vacíos en el .tscn
    │
    ├── inventory/                  # Pantalla de inventario (patrón MVVM)
    │   ├── inventory_viewmodel.gd   # **Spike 17:** reconstruido. `InventoryState { HIDDEN, BROWSING, ITEM_SELECTED }`, `DetailData`, `changed(reason)` (`opened/inventory/equipment/stats/selection/feedback/closed`), intenciones `request_*()`, refrescos agrupados con `call_deferred`, feedback ya traducido. Único punto de la pantalla que habla con `Inventory`, `Equipment`, `Items`, `Resources`, `Characters` y `EventBus` **Spike 18:** + `BagEntry`, `CategoryData`, `StatEntry`, `ModLine`, `CompareLine` y `DetailData` ampliada (categoría, modificadores, comparación); capacidad/peso (`_compute_capacity()`, que desde el **Spike 19** delega en `BagCapacity`), categorías (`select_category()`), estadísticas (`stat_entries`), bonos del equipo (`equipment_bonuses`, suma de modificadores `add`), escucha `Equipment.equip_failed`; razón nueva `categories`
    │   ├── inventory_ui.gd          # **Spike 17:** View pasiva de producción (`CanvasLayer`, raíz `InventoryUi`); crea el ViewModel como hijo; conserva `closed`, `open_inventory()`, `close_inventory()`, `toggle()` y `@export entity_id`; maneja `ui_cancel` **Spike 18:** rehecha con `UIPanel`/`UIButton`/`UISlot`: `Backdrop` opaco + `Frame` con tamaño máximo (1400×820) recalculado en `size_changed`, tres columnas (equipo, mochila con pestañas, detalle + bonos + estadísticas), pool de slots, popup sobre la mochila
    │   ├── inventory_ui.tscn        # **Spike 18:** `Backdrop`, `Frame` (UIPanel OVERLAY con marco), `Header`, `EquipColumn`/`BagColumn`/`RightColumn`, `BonusBlock`, `StatsBlock`, `FeedbackPopup`; todos los nodos de la View con nombre único
    │   ├── bag_capacity.gd          # ← NUEVO (Spike 19): `class_name BagCapacity` (RefCounted), `static func compute(definition, used_count, entity_id = "")` — único punto de cálculo de la capacidad de una mochila (`definition.inventory_slots`; con definición nula devuelve `used_count` y avisa). Lo usan `InventoryViewModel` y `PartyViewModel`, que resuelven la definición y delegan solo la regla. `item_slot.*` y `equip_slot.*` se retiraron en este spike (Party pasó a `UISlot`)
    │   ├── item_detail_panel.gd     # Spike 17: textos con tr() **Spike 18:** `class_name ItemDetailPanel extends UIPanel` (`super._ready()`), `show_detail(DetailData)`, filas de modificadores y de comparación por código con tokens
    │   ├── item_detail_panel.tscn
    │   ├── feedback_popup.gd        # Spike 17: se oculta solo a los 2 s (Timer por código) **Spike 18:** colores y estilo desde tokens; script dentro de la escena
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
    │   ├── party_ui.gd              # **Spike 19 (19a):** View pasiva con `UIPanel` OVERLAY + marco, `UIButton`, `UISlot` y tokens; layout L3 (equipo en columna vertical de 6 `UISlot` de 64 px junto a la mochila de cada personaje; pool según capacidad); `ColumnView` interna para pintar las dos columnas; pestañas de compañero solo con 2 o más; `OptionButton` de estrategia estilizado por código; conserva `open()/close()/toggle()` y `closed`
    │   ├── party_ui.gd
    │   └── party_ui.tscn            # **Spike 19 (19a):** `Backdrop`, `Frame` (UIPanel OVERLAY con marco, 0,9 con tope 1400×820), `Header`, `Content` con `PlayerColumn`/`Separator`/`CompanionColumn`, `FeedbackPopup`; todos los nodos de la View con nombre único. Conserva el UID de la escena
    │
    ├── player_menu/                # Menú del jugador (patrón MVVM)
    │   ├── player_menu_viewmodel.gd
    │   ├── player_menu_screen.gd
    │   └── player_menu_screen.tscn
    │
    ├── shop/                       # Tienda (patrón MVVM) — **Spike 16:** primera pantalla del hito que adopta el Design System; **16b:** soporte de préstamo
    │   ├── shop_viewmodel.gd       # **Spike 16:** `_on_trade_success` distingue compra/venta/préstamo (`_success_message_key`) y muestra el nombre visible; **16b:** traduce `LOAN_ITEM`
    │   ├── shop_ui.gd              # **Spike 16:** `CanvasLayer` con `layer = 10`, estilo solo con tokens, dos columnas, listas vacías, `FeedbackLabel` de altura reservada
    │   ├── shop_ui.tscn            # **Spike 16:** `ShopPanel` = `ui_panel.tscn` OVERLAY con marco (anclas 0.05–0.95), `PlayerColumn`/`ShopColumn`, `CloseButton` = `ui_button.tscn`
    │   ├── shop_item_slot.gd       # **Spike 16:** fila de lista, `extends UIPanel` (`setup()`, `set_busy()`, `item_clicked`, gancho de icono); **16b:** `is_loan` («Préstamo» / «Tomar»)
    │   └── shop_item_slot.tscn     # **Spike 16:** `Row` HBox → `IconRect`, `NameLabel`, `QuantityLabel`, `PriceLabel`, `ActionButton` (`ui_button.tscn`)
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
