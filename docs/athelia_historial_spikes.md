# Athelia — Historial de spikes
 
Relato cronológico, un párrafo por spike, desde el pivote hacia RPG narrativo. Cada entrada resume qué se hizo y qué decisiones o hallazgos importan hoy, y remite a su informe en `docs/` para el detalle. Este fichero es historia, no referencia vigente: para el estado actual de los sistemas, ver `athelia_referencia_sistemas.md`; para las lecciones reutilizables, `athelia_lecciones_tecnicas.md`.
 
Godot 4.7.x desde el Spike 1 (4.7.1 al inicio, 4.7.2 después).
 
---
 
## Arquitecturas superadas
 
Se conserva solo la lista de lo que existió y por qué dejó de usarse; su descripción completa ya no hace falta.
 
- **`exploration_tutorial`** (mini-tutorial 2D): obsoleta desde el Spike 3/B; descartada por Fernando en el Spike 13 (no era escena de producción).
- **`exploration_telmori_village`** (pueblo 2D con `Interactable` creados por código y cinco listeners de reconexión): sustituida en el Spike 13 por el hub declarativo `data/interactive_scenes/telmori_village.json`. Su inicialización de partida pasó a `AdventureStarter` + `on_first_visit`.
- **Patrones de reconexión narrativa con `Interactable`** (tras combate y por flag): sustituidos por `combat_victory_scene_id` y por hotspots con `required_flags`/`blocked_flags`. Las lecciones que dejaron (desconectar listeners de `combat_ended`, enganchar a `narrative_flag_set` y no a `narrative_scene_closed`, exploits por interactuables de recompensa sin retirar) siguen en `athelia_lecciones_tecnicas.md`.
- **Convención de colisión** de objetos sólidos (`Interactable` Area2D + `StaticBody2D` aparte): aplicaba a esas escenas; `Interactable` queda vestigial.
---
 
## Spike 1 — Motor narrativo base (pivote hacia RPG narrativo)
 
Nuevo sistema `core/narrative_scenes/` + `ui/narrative_scene/` (MVVM, sin sistema runtime propio: `NarrativeSceneDB` es una consulta síncrona sobre JSON). Se añade `GameState.NARRATIVE_SCENE` con integración de combate y cierre desacoplado por `EventBus.narrative_scene_closed`. Escena de prueba desechable y tecla de debug F1 (retiradas en el 3/A). Lecciones: autorreferencia por `class_name`, colisión del enum `SceneState` con una clase nativa, y nodo raíz `"ExplorationScene"` al ejecutar escenas sueltas. Incluye el «spike de producción post-Character Creation» (escena de exploración de producción, registro en frío de Resources/Skills al cargar, nombre del personaje visible en PlayerMenu). Informe: `docs/spike_1_motor_narrativo_informe_cierre.md`.
 
## Spike 2 — Reglas de RuneQuest para el motor narrativo (6 de 6)
 
1. **Grado «especial»:** `RollResult` pasa a 5 grados; `CRITICAL` (skill/20) y `SPECIAL` (skill/5) dinámicos, `FUMBLE` absoluto. En combate `SPECIAL` multiplica el daño ×1,2.
2. **Progresión de skill narrativa:** `challenge_level` por opción (0 = sin progresión), vía `execute_learning_session()` con `SourceType.NARRATIVE`, solo en éxito.
3. **Tiradas acumulativas:** `required_successes` + `retry_policy`; el contador vive en el ViewModel; una pifia siempre transiciona.
4. **Tiradas agregadas de grupo:** `group_aggregate` (`worst`/`best`); la oposición se codifica en `roll_modifier`, sin tabla de resistencia.
5. **Modificadores dinámicos:** cerrado sin código (`roll_modifier` ya cubre el caso narrativo); el multiplicativo de combate se aplazó y luego se descartó.
6. **Moral y refuerzos:** `CombatEncounterDefinition` (opcional en `start_combat()`), moral de **grupo** (señal `enemy_group_fled`, sin pasar por `character_died`) y refuerzos cronometrados; `configure_active_encounter()` adjunta un encuentro a un combate ya en marcha.
Informe: `docs/spike_2_reglas_runequest_informe_cierre.md`.
 
## Spike 3, Grupo A — Motor y limpieza
 
Moral con base dinámica (`_group_morale_base_hp` recalculada al llegar un refuerzo, nunca golpe a golpe), autoload `EnemyWorldLink` como hueco genérico de limpieza (sin casos de uso reales después) y retirada del andamiaje del Spike 1 con test `test_narrative_scene_viewmodel.gd` (fixtures en código). Informe: `docs/spike_3_grupoA_motor_limpieza_informe_cierre.md`.
 
## Spike 3, Grupo B — Del pueblo a la puerta de la guarida
 
Primer contenido real: 11 escenas de «Los Telmori», jugable de principio a fin. `NarrativeSceneOutcome` gana `combat_encounter`, `combat_enemy_definitions` y `grant_item_*`. **Sorpresa de combate** con el buff `staggered`/`vulnerable` existente, sin tocar `turn_order`. Nuevo `interaction_type` `"narrative_scene"` en `Interactable`. Se corrigieron cuelgues de turno (`STAGGERED`/`DISARMED`), registro de enemigos en combate disparado desde narrativa, reinicio tras Game Over, dimensionado del panel narrativo y la duplicación del kit de skills (`STARTING_SKILL_VALUES` hardcodeado → se lee de `CharacterDefinition`). Convención de carpetas por aventura. Informe: `docs/spike_3_grupoB_pueblo_guarida_informe_cierre.md`.
 
## Spike 3, Grupo C — La guarida
 
Aproximación sigilosa y combate final. Las dos salas de la aventura original se fundieron en **un combate por rama** (`alerted` sin sorpresa ni refuerzo; `stealth` con supervivientes de la emboscada y refuerzo en la ronda 4). Tirada opuesta con `group_aggregate: "worst"` (confirmado por la transcripción). Nueva skill `skill.exploration.stealth`. Se decidió **no** implementar el modificador multiplicativo de combate. Cuatro bugs preexistentes de reconexión tras combate corregidos (encadenado suelto, ausencia de reconexión tras el segundo combate, listener que nunca se desconectaba, limpieza enganchada a la señal equivocada). Informe: `docs/spike_3_grupoC_guarida_informe_cierre.md`.
 
## Spike 3, Grupo D — Cierre de «Los Telmori»
 
Recompensa multicapa (bounty, trofeo, venta de pieles con Curtido real), botín mágico y gancho final. `NarrativeSceneOutcome` gana `grant_resource_*`. Reconexión narrativa sin combate (por `narrative_flag_set`) con su riesgo identificado de exploit económico. El camino de Curtidor se resolvió sin gating nuevo (`get_skill_value()` devuelve 0 fuera del kit). Mini-acertijo de la bolsa mágica descartado. Reflavor del entrenamiento de magia como libro de aprendizaje (corregido en el Spike 10: el camino no funcionaba). Bugs: propiedad declarada a medias en `NarrativeSceneOutcome` y JSON de contenido desactualizado. Con este grupo la aventura queda completa. Informe: `docs/spike_3_grupoD_cierre_informe_cierre.md`.
 
---
 
## Mejoras post-Spike 3
 
### Grupo 3 — Overlays de inventario/party/stats durante narrativa
`NarrativeScenePanel` gestiona Inventory/Party/PlayerMenu como **sub-overlay propio** (hijo directo, nunca vía `SceneOrchestrator`, cuyo `_current_overlay` es un slot único y habría destruido el panel narrativo con su racha en curso). Tres intenciones nuevas en el ViewModel sin tocar `current_node` ni la racha. Bugs preexistentes corregidos: cuatro pantallas no se auto-liberaban y `PlayerMenu._open_subscreen()` dependía de `tree_exiting` (nunca se disparaba) → señal `closed` explícita; `ExplorationHUD._unhandled_input()` ignoraba `is_input_blocked()`. Informe: `docs/mejoras_grupo3_overlays_narrativa_informe_cierre.md`.
 
### Grupo 2 — Diálogo con NPCs desde narrativa
`NarrativeSceneOutcome.dialogue_id` abre `DialoguePanel` como sub-overlay con reenganche automático (`resume_after_dialogue()`, reutilizando `next_scene_id` con significado condicional). Hallazgo crítico: `SceneOrchestrator._on_dialogue_ended()` forzaba `enter_exploration()` de forma incondicional (ahora gateado a `GameState.DIALOGUE`). `DialogueRegistry` no escaneaba subcarpetas (corregido). Informe: `docs/mejoras_grupo2_dialogo_narrativa_informe_cierre.md`.
 
### Grupo 5 — Pantalla de combate de producción
Sustituye `combat_test_scene`/`combat_hud.tscn` por una de producción sin cambiar reglas. `UIRadialGauge` y `UICombatToken` (Design System), `CombatArenaViewModel` (**primer caso de composición de ViewModels**: compone `CombatHudViewModel` como `action_menu`), log narrado con 4 categorías, `combat_production_scene.gd` como nueva `SCENE_COMBAT`. El menú real son 8 slots, no 6. Hallazgos: Skills nunca se registraba para enemigos pre-registrados, `EnemyCombatNode` prescindible, fuga de la instancia de `SCENE_COMBAT` (mitigada localmente), `ResourceSystem.resource_changed` sin reenviar a `EventBus` (Spike 5), typo `combat_escape`/`combat_scape` (Spike 5), `AttributeResolver` y `ResourceState.max_effective` desconectados (Spike 6). Informe: `docs/mejoras_grupo5_combate_produccion_informe_cierre.md`.
 
### Grupo 1 — Guardado de partida
Corrige un supuesto erróneo de la documentación: `SaveManager` ya guardaba flags, variables, eventos, checkpoints y party; el hueco era solo «a qué escena narrativa volver». Guardar deja de ser hotkey libre (F5 retirado): solo con una opción de diálogo `triggers_save` de NPCs savepoint (sin exploit posible al ser NPCs sin peso en la historia). `SaveData.narrative_state` gana `current_narrative_scene_id`; `SAVE_VERSION` 5 → 6. `MainMenuViewModel.request_load_game()` decide entre `enter_narrative_scene()` y `enter_exploration()`. Hallazgos: `MENU → NARRATIVE_SCENE` no existía (fallaba en silencio) y `ExplorationScene` podía no estar instanciada cuando terminaba un combate tras cargar (listeners de continuación perdidos) → `_ensure_exploration_scene_instantiated()`, que a su vez expuso una trampa de reentrada en `TelmoriVillage._ready()`. Atajo de desarrollo F2 (`user://debug_shortcut.json`). Informe: `docs/mejoras_grupo1_guardado_informe_cierre.md`.
 
### Grupo 4 — Arte narrativo
Fondos de escena (layout B1: imagen a pantalla completa, panel en el tercio inferior), fondos de combate por encuentro (`background_path`; **mapas cenitales de batalla**, no las láminas de escena) e iconos de tipo para los enemigos. `image_path` validado al cargar. Velo de la arena a 0,2 y contorno de texto desde tokens. Corregido: las fichas enemigas nunca recibían `fill_color` y el centinela `Color.BLACK` de `token_color` no se respetaba. Informe: `docs/mejoras_grupo4_arte_narrativo_informe_cierre.md`.
 
---
 
## Spikes 5-10
 
### Spike 5 — Arreglos rápidos de motor
Cinco bugs preexistentes: typo `combat_escape` → `combat_scape`; puente `ResourceSystem.resource_changed` → `EventBus.resource_changed` (dos consumidores reales, `combat_hub_viewmodel.gd` y `player_menu_viewmodel.gd`, así que reenvío centralizado); `telmori_lair_loot_obsidian.json.json`; `CharacterDefinition.duplicate_definition()` con los cuatro campos que faltaban; `combat_resolver.gd` eliminado (código muerto). Informe: `docs/spike_5_arreglos_motor_informe_cierre.md`.
 
### Spike 6 — Investigación de motor de combate
Dos bugs independientes bajo el mismo síntoma («número mostrado ≠ real»). **A:** `ModifierApplicator` solo sincroniza `max_effective` como efecto de `set_base_attribute()`, que solo llamaba Character Creation para `"player"` (y el HP de enemigos estaba hardcodeado a 50.0); arreglado sincronizando dentro de `ResourceSystem.register_entity()`. **B:** `player_menu_viewmodel.gd` leía el HP/EN actual de un accesor fósil de `CharacterState`; ahora de `Resources.get_resource_amount()`. Y rondas que saltaban número (`ROUND_END → TURN_END`): `_transition_to_phase()` pasa a devolver `bool`, `_on_combat_action_completed()` compara el `actor`. Test `test_spike6_investigacion.gd`. Informe: `docs/spike_6_investigacion_motor_combate.md`.
 
### Spike 7 — F9 quickload en EXPLORATION (cerrado sin arreglo)
F9 en sesión activa cargaba los datos pero no la escena narrativa (arreglado con `GameLoopSystem.enter_post_load_state()`), lo que destapó un segundo bug sin resolver: el panel narrativo abría pero su botón no respondía a clics, solo tras combate en sesión activa. Sin causa raíz tras una investigación extensa. Hallazgo real: `ExplorationScene` y sus overlays viven como hermanos de `current_scene` bajo `root`, invisibles a `reload_current_scene()`. **Decisión: F9 queda no operativo y no se vuelve a tratar.** Hallazgo colateral: `PartyManager` no limpiaba su lista de companions al cargar. Informe: `docs/spike_7_f9_quickload_exploration.md`.
 
### Spike 8 — UI/UX de combate (5 puntos)
1–2: nombres no-jugador resueltos con fallback a `tr(CharacterDefinition.name_key)` (misma causa para el `??` de las fichas y los IDs sin localizar en el log). 3: los 8 botones del menú sin nombre no eran bug de código: el `LoadoutState` del jugador nunca se asignaba. 4: columna enemiga desbordada con 6-8 fichas → patrón «Control envoltorio + `.scale`» (redimensionar `UICombatToken` directamente descoloca su contenido). 5: «No target specified» al atacar → `combat_arena_panel.gd` duplicaba el despacho que ya resolvía `PlayerCombatController.request_skill()`; y el auto-target se perdía por orden de señales. Informe: `docs/spike_8_ui_ux_combate.md`.
 
### Spike 9 — Marco decorativo de `UIPanel`
`decorative_frame` (opt-in, apagado por defecto) dibujado con `_draw()` sobre el propio panel (un `StyleBoxFlat` no admite varios filetes) con una única esquinera rotada en las 4 esquinas; siete tokens nuevos. Activado en el panel narrativo solo desde el inspector. Esquinera de 64×64 en uso (la de 96×96 invadía el texto). Informe: `docs/spike_9_marco_decorativo_ui_panel.md`.
 
### Spike 10 — Diálogos restantes del sheriff
Reutiliza el sub-overlay del Grupo 2 para `telmori_sheriff_reward_intro` y `telmori_sheriff_training` (**camino A:** el diálogo solo conversa; las entregas viven en el outcome que lo abre, antes del diálogo; `telmori_sheriff_pelts` no se convierte por la tirada de Curtido). Dos fallos previos destapados: `grant_item_*` había desaparecido de `_apply_outcome()` (ningún ítem llegaba al inventario) y un libro no podía enseñar una skill fuera del kit (se consumía sin efecto) → `SkillSystem.learn_skill()`, `initial_value` en `learning_data`, consumo condicionado a que el aprendizaje se aplique. Localización completada. Sin probar en partida: camino de fallo del libro y guardado/carga con Curtido. Informe: `docs/spike_10_dialogos_sheriff.md`.
 
---
 
## Spikes 11-20
 
### Spike 11 — Rediseño de la ventana de diálogo
`DialoguePanel` pasa de `PanelContainer` plano a `UIPanel` con marco (cierra el pendiente del Spike 9). **Un único retrato** del NPC (se descarta definitivamente el layout de dos retratos), hermano del panel para sobresalir por el marco (layout C de la maqueta), y fondo de ambiente propio (`BackgroundImage` + velo, mismo patrón que la arena de combate; imagen pre-difuminada en la generación). Datos: `DialogueNodeDefinition.mood` (por nodo, no por diálogo), `DialogueDefinition.portrait_folder` y `background_id`, todos opcionales y con respaldo; retrato resuelto por cascada `<portrait_id>_<mood>.png` → `<portrait_id>.png` → ninguno, con `push_warning` en cada salto. `EventBus.dialogue_node_shown` pasa de 4 a 7 argumentos sin romper oyentes. Antipatrón nuevo: un `PanelContainer` no se encoge por debajo de sus hijos, así que un número variable de opciones va en `ScrollContainer`. Deuda anotada: tests de `dialogue_node_shown` sin adaptar a 7 argumentos. Informe: `docs/spike_11_ventana_dialogo.md`.
 
### Spike 12 — Motor de escenas interactivas (mapa de puntos de interés)
Primitivo genérico: imagen de fondo + puntos clicables posicionados por datos + visibilidad por flags + un clic dispara una acción (`dialogue`, `shop`, `combat`, `narrative_scene`). Sustituye al pueblo 2D como `SCENE_EXPLORATION` (sin jugador, física ni cámara). Sistema nuevo y dedicado (`core/interactive_scenes/`, `ui/interactive_scene/`, escena raíz `exploration_interactive_map`); `Interactable`/`WorldObjectSystem` no se tocan. `ExplorationController.request_interaction()` pasa a ser el **único punto de routing** (`enemy_definitions` llega como parámetro: la señal `interaction_requested` no puede llevarlo y sin él el combate degradaba a `enemy_base`). `SaveSystem._collect_player_state()` deja de exigir nodo `Player`. Fase 0 corrigió cuatro supuestos de la documentación (`Interactable` solo con `narrative_scene` y por código, su `@export_enum` no lista `narrative_scene`, el nombre del nodo raíz lo fuerza el orquestador, `TelmoriVillage._ready()` hacía inicialización de partida). No validado: el camino físico de `Interactable` tras el refactor (nunca se validará). Informe: `docs/spike_12_motor_mapa_poi.md`.
 
### Spike 13 — Reautoría del pueblo sobre el motor interactivo
El pueblo pasa a un **hub persistente** (`telmori_village.json`): 11 hotspots en 4 posiciones (sheriff, herrería, taberna, salida) mutuamente excluyentes por flags según la etapa. El flujo real que quería Fernando difería de la spec: tras la llegada se visita sheriff, herrería y taberna; la salida está visible pero bloqueada hasta aceptar el encargo (y de nuevo hasta cobrar), y al ganar un combate se encadena la siguiente escena en vez de volver al pueblo. Cambios de motor y de contrato: `VICTORY → NARRATIVE_SCENE`; `start_combat(..., victory_scene_id)` + `NarrativeSceneOutcome.combat_victory_scene_id` (si el id no existe, vuelve a `EXPLORATION`: una prueba con un id mal escrito dejaba un panel vacío sin salida); `take_item_*`; `on_first_visit` + `request_first_visit()`; `AdventureStarter` + `data/adventures/telmori.json`; `UIButton.min_square`/`icon_backdrop`. Defecto de la spec: `flag.telmori_ambush_triggered` y `telmori_lair_combat_won` se ponían al DISPARAR el combate, no al ganarlo. Tienda propia `blacksmith_telmori.tres` (lanza en préstamo y flechas). `Interactable` queda vestigial y se descartan el tutorial y el test. Dos mensajes preexistentes al huir corregidos. Validación parcial (sin confirmar: segundo punto de guardado, ganar sin escena de victoria, derrota, lanza equipada frente a vendida). Informe: `docs/spike_13_reautoria_pueblo_telmori.md`.
 
### Spike 14 — Reinicio de sesión y teardown (motor)
Primer spike del hito de rediseño de interfaces. Causa raíz: `_show_game_over()` colgaba `GameOverUI` de `root` sin guardar referencia, `_handle_main_menu()` solo ocultaba overlays (nadie liberaba `ExplorationScene` ni reiniciaba nada), el guard `has_entity("player")` de Character Creation dejaba al jugador muerto con HP 0, `AdventureStarter` no es idempotente y la View del Game Over contenía lógica de juego. Solución: coordinador explícito de orden fijo `SessionReset.apply()` + `EntityLifecycle.unregister_everywhere()` (que ahora también usa `PartyManager`), lanzado por `SceneOrchestrator` al entrar en `MENU` tras liberar las escenas de la partida; `Economy.reset_session()`; `Combat.clear_buffs()` entra en el reinicio; `GameOverViewModel` con una intención y un botón hacia el menú principal. Fase 0 de diez comprobaciones. Informe: `docs/spike_14_reinicio_sesion.md`.
 
### Spike 15 — Cimientos del Design System
Segundo spike del hito: resuelve una vez lo que comparten las pantallas, sin rediseñar ninguna. **Resolución sin estiramiento** (el experimento con `canvas_items` a 1280×720 ablandaba el texto ≈15 %). Tokens: los dos vocabularios (`COLOR_*` y `BG_*`/`BORDER_*`/`TEXT_*`) se fusionan con alias; dos cambios de valor visibles (`COLOR_TEXT_MUTED` → `#9A8E78`, `COLOR_PANEL_ALT`/`BG_SURFACE` → `#252220`); nuevos `FRAME_MIN_PADDING` y `FRAME_CORNER_TEXTURE_PATH`. `UIPanel`: esquinera por defecto, padding mínimo con marco, activación en runtime, `push_warning` fuera de `_draw()`, `OVERLAY` documentado como opaco. Diálogo: opciones en rejilla (1 columna hasta 3, 2 desde 4), altura reservada (corrige la tercera opción cortada a 648 desde el Spike 11), margen del texto proporcional al retrato, foco de teclado. Localización limpia: 29 claves duplicadas, fila con comas sin comillas (`DLG_SHERIFF_REWARD_01_GREET`, no `MENU_CONFIRM_YES`), nuevo `skills.csv`, `SPEAKER_INNKEEPER`. La Fase 0 corrigió la spec (cifras de altura inexactas, hipótesis del scroll falsa). Informe: `docs/spike_15_cimientos_design_system.md`.
 
### Spike 16 — Tienda (incluye la 16b)
Primera adopción real del Design System: `UIPanel` OVERLAY con marco, `UIButton`, tokens, dos columnas por anclas, 23 claves `SHOP_*` y `ShopItemSlot` como fila (`extends UIPanel`, `set_busy()`, gancho de icono). La Fase 0 corrigió la spec (los botones nunca quedaban deshabilitados, snapshot no homogéneo, tooltip equivocado en venta). **16b:** la lanza `quest_loan` (`base_value = 0`) no se podía comprar ni vender y bloqueaba la aventura; `EconomySystem` trata el tag como préstamo (sin coste, no vendible), la fila muestra «Préstamo»/«Tomar»; primer cambio del hito que toca el core. **16c** (devolución del préstamo cuando la tiene un compañero) abierta, sin planificar. Informe: `docs/spike_16_tienda.md`.
 
### Spike 17 — Inventario A: contrato MVVM, sin cambio visual
La pantalla de producción (`inventory_ui.gd`) accedía a ~30 líneas de sistemas core sin ViewModel. **Decisión 5.A:** reconstruir `InventoryViewModel` sobre el esqueleto muerto y mantener `inventory_ui.gd` como única View (revivir `InventoryScreen` obligaba a una escena nueva). Se borran `inventory_screen.gd` y `SceneOrchestrator.close_inventory()`. ViewModel con `InventoryState`, refrescos agrupados con `call_deferred` y feedback traducido; 29 claves `INVENTORY_*`. Hallazgo de motor (afecta también a Party): `SceneOrchestrator` no conectaba `closed`, así que una pantalla cerrada seguía ocupando `_current_overlay` y la siguiente pulsación de la tecla la destruía (dos pulsaciones). Otros: Esc no cerraba el inventario, cabecera obsoleta tras usar una poción, «HP: HP:» duplicado, popup que nunca se ocultaba. Los contextos PlayerMenu y narrativa se validaron en el 18. Informe: `docs/spike_17_inventario_mvvm.md`.
 
### Spike 18 — Inventario B: rediseño con el Design System
`UIPanel` OVERLAY con marco, `UIButton`, `UISlot` (primer consumidor real) y solo tokens, sobre el contrato MVVM del 17 sin cambiarlo. Nuevo: pestañas de categoría en datos (`data/ui/inventory_categories.json`), cabecera con oro/peso/huecos, marca «E» de equipado, desbordamiento visible, comparación con lo equipado, bonos del equipo (suma de modificadores `add`) y estadísticas base. A 1680×1050 el panel se veía vacío: decisión de Fernando de tope 1400×820 con fondo opaco. `inventory.csv` pasa a 58 claves. Validado en partida a 1152×648 y 1680×1050 en los tres contextos. Informe: `docs/spike_18_inventario_rediseno.md`.
 
### Spike 19 — Party (19a)
Último consumidor de `item_slot`/`equip_slot` (retirados). `UIPanel` OVERLAY con marco, `UIButton`, `UISlot` y tokens, layout L3 (equipo en columna vertical de 6 `UISlot` junto a la mochila de cada personaje). **Bugs reproducidos en partida antes de tocar código:** límite de 8 ítems por mochila; un drop rechazado que ya había transferido el ítem; y la lanza equipada arrastrada a Mira que quedaba equipada en los dos (`EquipmentManager` e `InventorySystem` son independientes: la transferencia no desequipaba). `PartyViewModel` reescrito con datos listos para pintar; transferencia corregida (`request_equip_drop` valida antes de mover, desequipa en el origen y revierte si falla). `UISlot` gana `owner_id` y `slot_item_dropped`; `BagCapacity` como único punto de capacidad; `party.csv` con 27 claves. Party deja pasar un `quest_loan` a un compañero (coherente con la hipótesis de la 16c, no probado con el sheriff). Pasan al **19b**: transferencia mochila a mochila, detalle con comparación, estado del compañero y regla de objetos de préstamo. Informe: `docs/spike_19_party.md`.
 
---
 
### Spike 19 — Party (19b)
Cierra lo que el 19a dejó fuera. **Transferencia mochila a mochila** por arrastre (1 unidad o la pila con Mayús) con resaltado de destinos (`UISlot.drop_exclude_owner` y `highlight_drop_targets`, apagados por defecto), **cajetín de detalle** por columna con comparación (el clic en la mochila pasa a seleccionar), **barras de HP y estamina** (`UIResourceBar`, primer consumidor real, por `set_values()`) y **regla de préstamo** (`quest_loan` no pasa a un compañero). La Fase 0 destapó que `Inventory.add_item` pierde datos sin avisar (no apilable ya presente, tope de pila, `custom_state`; reproducido con sondas) y que la hipótesis de la 16c era cierta (`take_item` solo miraba al jugador): `take_item` busca ahora en toda la party. El cálculo del detalle se extrajo a `ItemDetailBuilder` (compartido con el inventario) y `UIResourceBar` se corrigió (el `.tscn` nacía invisible y con relleno de 40 px). Hallazgo de configuración: `MAX_PARTY_SIZE` es 3, no 2. Partido en 19b-1 y 19b-2. Informe: `docs/spike_19b_party.md`.

### Spike 20 — Loadout
Rediseño de la pantalla con el Design System: `UIPanel` OVERLAY con marco, `UIButton`, `UISlot` (consumibles), un componente propio `LoadoutCard` (habilidades como tarjetas), nombres únicos `%`, solo tokens y 41 claves `LOADOUT_*` (`loadout.csv`). **El estado de selección pasa al ViewModel** (la vista antigua lo limpiaba sin repintar tras una asignación rechazada) y la lista muestra solo lo compatible con el slot y no asignado en otro (sin duplicados, ni en habilidades ni en consumibles); vaciar un slot es un botón explícito (antes, un segundo clic lo vaciaba sin aviso). Decisión O1: el slot `escape` es **fijo** (tarjeta «Acción de combate», no asignable) a la espera de replantear el combate. La Fase 0 corrigió la spec: `open_loadout()` no tiene llamadores (código muerto, contexto no validable en partida), Esc no estaba implementado y el código tenía 7 claves de error, no 6. Hallazgos de datos: `skill.combat.defend`/`flee` sin `.tres` (ids hardcodeados en el controlador de combate), `fireball` no asignable a ningún slot, el HUD muestra vacíos los slots de Defensa y Huida. Sin cambios en el core. Validado a 1152×648 y 1680×1050 en el contexto de PlayerMenu. Informe: `docs/spike_20_loadout.md`.

---

El estado actual del hito (qué falta, qué sigue sin validar) está en `estado_actual.md`.