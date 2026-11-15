# Athelia — Estado actual (hito de rediseño de interfaces cerrado)
 
*Actualizado: 2026-11-15, tras cerrar y validar IA-0b (IA de combate: combate puramente por turnos).*
Contrato de pantalla, tokens, resolución y antipatrones: ver `athelia_ui_architecture.md`. Historia y diagnósticos de los spikes cerrados: `athelia_historial_spikes.md` y `docs/spike_N.md`. Resumen del hito: `docs/cierre_hito_rediseno_interfaces.md`.
 
## Spikes del hito
 
| # | Spike | Estado | Depende de |
|---|---|---|---|
| 14 | Reinicio de sesión y teardown | cerrado | — |
| 15 | Cimientos del Design System | cerrado | — |
| 16 | Tienda (A y B) | cerrado | 15 |
| 16c | Devolución del préstamo `quest_loan` al sheriff | cerrado (resuelto en el 19b) | 16 |
| 17 | Inventario A (MVVM) | cerrado | 15 |
| 18 | Inventario B (rediseño con `UISlot`) | cerrado | 17 |
| 19a | Party | cerrado | 18 |
| 19b | Party: mochila a mochila, detalle, estado del compañero, regla de préstamo | cerrado | 19a |
| 20 | Loadout | cerrado | 18 |
| 21 | Árbol de habilidades (21a pantalla, 21b comparación) | cerrado | 15 |
| 21c | Árbol visual con relaciones (selector Lista/Árbol) | propuesto, fuera del hito; numeración por decidir | 21 |
| 22 | Menú del jugador | cerrado | 18, 20, 21 |
| 23 | Pantalla de inicio | cerrado | 15 |
| 24 | Game Over: rediseño visual y cierre del hito | cerrado | 14, 15, 23 |
 
**El hito está terminado:** las ocho pantallas usan el Design System y cumplen el contrato de `athelia_ui_architecture.md`. Lo que sigue son spikes independientes, sin orden fijado.
 
## IA de combate

Spec vigente: `docs/ia_combate_spec_v1_7_1.md`. Prerrequisitos de motor: `docs/ia_combate_ia0_plan.md`. Fase 0: `docs/ia_combate_fase0.md`.

| Fase | Contenido | Estado |
|---|---|---|
| Fase 0 | Código real y 7 decisiones de diseño | cerrada (2026-11-11) |
| IA-0a | Robustez de acciones y estado de combate | **cerrada** (2026-11-14), `docs/ia_combate_ia0a_informe.md` |
| IA-0b | Combate por turnos: regeneración y cooldowns por ronda, HUD desde `ResourceSystem`, iniciativa determinista, retardos anulables | **cerrada** (2026-11-15), validada en partida (Output y pruebas manuales) y decisiones 1-A, 2-A, 3-A confirmadas: `docs/ia_combate_ia0b_informe.md` |
| IA-0c | Estimaciones y candidatas de `Combat`, RNG inyectable, skills `SELF`/`RESTORE`/`FLEE` | pendiente |
| IA-0d | Datos: PV derivados, skills de enemigos y de Mira, `behavior_profile_id` (decidir antes la constitución de los enemigos: números declarados o los jugados; comprobar el coste de `basic_attack` frente a la estamina del enemigo: en las partidas de IA-0b los enemigos nunca recuperan estamina porque no la gastan) | pendiente |
| IA-1 a IA-5 | Contratos, evaluador, órdenes de Mira, moral y huida (incluye `_evaluate_outcome()` y `combat_result_ready`), ajuste | pendiente |

## Alcance de lo pendiente
 
**21c — Árbol visual (propuesto, fuera del hito).** Nodos y líneas de prerrequisitos con un selector «Lista/Árbol» en la cabecera, sobre el `SkillTreeViewModel` del 21 (ya entrega niveles, requisitos y estado). Decidir en la Fase 0 la disposición (por nivel/subcategoría) y qué hace el scroll/zoom.
 
**24 — Game Over (cerrado, 2026-11-11).** `TitleBackdrop` opaco con título en tono `DANGER`, mensaje de dos líneas y `UIButton` `LG` con foco inicial; `GameOverViewModel` intacto. Limpieza de cierre del hito (trazas, etiqueta de depuración, `.bak`/`.tmp`, comentarios) y arreglo del `TRANSITIONING` atascado del menú principal. Ver `docs/spike_24_game_over.md`.
 
## Pendientes sin spike asignado
 
**Motor**
- IA de combate (IA-0a): `DISARMED` del jugador sin probar (hoy consume el turno); `Combat.get_last_attacker()` solo comprobado vacío al terminar; `Skills.can_use` no comprueba `is_unlocked`; el jugador no tiene registrada `skill.attack.stunning_blow` aunque la tecla 3 apunta a ella (da `SKILL_NOT_FOUND`); sin `INVALID_TARGET` (un enemigo que apunte a alguien a 0 PV completa su turno sin daño); los fallos de acción de enemigos y companions no tienen gestor (lo resuelve la IA desde IA-1; mientras tanto IA-0b hace que `EnemyAI` y `CompanionAI` no pidan lo que no pueden pagar); el HUD (`combat_hud.gd`) emite `combat_action_requested` sin pasar por el controlador (solo cuenta la recuperación de `GameLoop`).
- IA de combate (IA-0b): `EventBus.skill_used` no tiene emisor en `SkillSystem` (emite una señal local del mismo nombre) y el HUD ya no depende de ella; queda por confirmar con la búsqueda 1 de la spec si lo emite otro sitio (si no, la señal está huérfana) y los oyentes de `cooldown_started`/`cooldown_finished`. Ya comprobado: el combate pasa por `Skills.request_use` (`combat_system.gd:_on_execute_combat_action`) y los buffs de sorpresa sobreviven a `combat_started`.
- Equilibrio de combate (IA-5): `armor_rating = 12` del jugador y de Mira reduce todo daño enemigo (4,7–6,6) al mínimo de 1,0; los combates duran 12–22 rondas y los enemigos no amenazan. Condiciona cualquier estimación de amenaza. Con IA-0b además: valor de `combat_regen_per_round` (10 por defecto) y conversión de cooldown (`int()`); el umbral de huida crece con los enemigos vivos (60 contra 6, 40 contra 3, con ≈ 46 de estamina máxima), así que huir de un grupo grande es casi inalcanzable.
- Combate/Loadout (replantear con el combate): `skill.combat.defend`/`flee` sin `.tres`; ids hardcodeados en el controlador (`combat_defense` → defend, `combat_scape` → flee, `SPECIAL_ACTIONS`); sin skill COMBAT con tag `escape`; el HUD muestra vacíos los slots de Defensa y Huida con el loadout actual (la tarjeta de Huida del Loadout dice «Acción de combate»); preselección de Defender/Esquiva/Huida; el combate solo lee el loadout del jugador (`PLAYER_ID`); `SLOT_KEYBIND_LABEL` vive en `CombatHudViewModel` (moverlo a un sitio compartido).
- Una skill aprendida con requisitos no cumplidos se puede asignar y sale atenuada en el HUD; la lista del Loadout no muestra disponibilidad.
- `fireball` (tags `magic`, `ranged`) no es asignable a ningún slot.
- Teclas F y G de consumibles sin acción en el InputMap (la etiqueta se muestra igualmente).
- `CombatLootSpawner.spawn_pending_loot()` solo se llama desde `scenes/exploration/exploration_test.gd`, y `combat_loot_bag_spawned` solo lo escucha esa escena de prueba: el botín no aparece en producción ni hay quién cree la bolsa visible. Decidir dónde se llama en el flujo real (al volver a exploración tras la escena de victoria) y quién la crea. No depende de la IA de combate.
- `ItemCharacterIntegration` es código muerto (el autoload `Bridge` es `item_character_bridge.gd`).
- `PartyManager._register_in_systems()` conserva un acceso privado (`_entity_skills.get(...).keys()`): falta un listador público en `SkillSystem`.
- `equip_item` ignora el slot de destino; motivos de `equip_failed`/`item_use_failed` en texto libre en inglés (hace falta código de motivo).
- Una poción se consume aunque no tenga efecto (puente de ítems).
- Los modificadores `attribute.<base>` no afectan a los derivados (`_resolve_linear_combination` lee `state.get_base_attribute()`); el menú del jugador muestra el bono declarado (Spike 22). Arreglarlo es un cambio de motor con spike propio.
- `ModifierApplicator` no emite `temporary_state_added/removed/expired` y nadie aplica estados temporales en producción (el menú del jugador sondea con un `Timer`).
- `Inventory.add_item` sobrescribe una pila no apilable ya existente y recorta al tope de pila devolviendo `true` (reproducido en el 19b; Party lo evita con pre-validación en el ViewModel; sin arreglar en el core).
- `PartyManager.MAX_PARTY_SIZE = 3` (la documentación decía 2): decidir. La interfaz no impone máximo; a 1152×648 con 2 compañeros el margen vertical es ≈2 px.
- `InventorySystem.load_save_state()` comprueba `item_added` pero desconecta y reconecta `item_use_success`.
- Cajetín de Party: sin línea «Categoría» a pantalla completa (las categorías se cargan en `InventoryViewModel`); con selección a 1152×648 la mochila del jugador muestra un scroll vertical mínimo.
- `Inventory.add_item` no valida capacidad y sobrescribe si `can_stack_with` falla; `buy_item` omite validación de espacio.
- Vender un objeto equipado sin resolver (`sell_item` solo comprueba `has_item`).
- `accepted_tags` sin aplicar en `ShopInstance.can_buy_from_player` (`TODO`); `INSUFFICIENT_STOCK` sin traducir en `ShopViewModel._error_message`.
- Un `NarrativeScene` con id inexistente abre un panel vacío sin salida desde cualquier origen (solo se protegió la ruta de victoria).
- Capacidad de mochila: cualquier mecanismo de ampliación (premium, monedas, magia) entra por `BagCapacity`.
- `base_damage` frente a `melee_damage` incoherentes (`steel_sword`/`iron_sword`); `amulet_strength` sin tag de slot.
**Pantalla de inicio y opciones (Spike 23)**
- Audio: no existe ni audio ni buses `Music`/`SFX`. Diseñarlo, crear los buses, dar estilo a los sliders y poner `OptionsPanel.SHOW_VOLUME_SLIDERS = true` (hoy `false`). La persistencia de volúmenes ya está preparada en `GameSettings`.
- Menú de pausa / Opciones desde la partida: reutiliza `OptionsPanel`; exige orquestador y `GameLoop` (spike propio) y que cada pantalla retraduzca al cambiar de idioma.
- `fullscreen` se guarda aunque no se aplique (ventana incrustada del editor, que solo admite modo ventana): mejora opcional, guardar el modo realmente aplicado.
- Tiempo jugado del guardado: `playtime_seconds` suma también el tiempo de menú y no se reinicia en una partida nueva (core). Por eso «Cargar partida» no lo muestra.
- Limpieza de quickload: `consume_pending_quickload()` (`MainMenuViewModel`) y `_quickload()` (`ExplorationController`) siguen vivos, aunque F9 está desestimado.
- Versión en el pie (requiere `config/version` en `project.godot`); sustituir los «Por definir» de Créditos; asignar arte a `TitleBackdrop` (compartido con el Game Over) y comprobar la legibilidad con el velo.
**Contenido y datos**
- Marcador `telmori_village_departure` (salida final del pueblo): sale un aviso al cargar la exploración; decidir qué ocurre al salir.
- Retrato del posadero es un placeholder (muestra el del sheriff).
- Menú del jugador (Spike 22): los seis slots de equipo no se muestran (spike propio); Loadout sin atajo de teclado (exige una acción nueva en el InputMap); los atributos base mostrados no aplican `mul` ni `override`.
- Falta `RESOURCE_FOCUS_NAME` (el coste de `focus` en el Loadout cae a `id.capitalize()`); solo existen las claves de salud, estamina y oro.
- `ITEM_HEALTH_POTION_DESC`: espacio inicial en ES y efecto inconsistente (EN «10», ES «50», `value = 10.0`).
- `telmori_lair_loot_obsidian.json.json` pendiente de renombrar (carga igual).
- Claves `INVENTORY_BAG_HEADER`/`INVENTORY_STATS_HEADER` sin uso; `INVENTORY_STAT_FOCUS` oculta.
- Descripciones de estrategia inexistentes en datos; `PARTY_*`: el mensaje «Equipado en Jugador» usa nombre genérico.
- Spike 21: unidad de `duration` de los buffs sin confirmar (se muestra «s»; si son turnos, cambiar `SKILL_TREE_EFFECT_DURATION`); «Evasión 100» sin unidad; `SKILL_ATTACK_LIGHT_DESC` («atack», espacios); subcategoría de la esquiva `EXPLORATION` (la documentación dice `MELEE`); `NONE`/`ENEMY` tratados al revés de la documentación; entrenamiento `PRACTICE` ilimitado y gratuito (decisión de diseño).
- `UIButton` `PRIMARY` deshabilitado es ilegible (las pantallas lo evitan pasando a `SECONDARY`); arreglarlo en el componente afecta a todas las pantallas.
**Auditoría de contrato del cierre del hito (fuera de las ocho pantallas)**
- Literales de color: `dialogue_panel.tscn:30` (`Color(0,0,0,1)`), `loading_screen.tscn:25`, y constantes y `modulate` en `world_object_interaction_panel` (vestigial).
- `interactive_scene_view.gd:78` crea `UIButton.new()` en vez de instanciar `ui_button.tscn`.
- `narrative_scene_panel.gd:118` llama a `Dialogue.start_dialogue()` desde la View (su docstring dice lo contrario).
- `combat_hud.gd` y `combat_arena_panel.gd` acceden a `Characters`, `Inventory` y `EventBus` directamente (UI de combate, fuera del hito).
**Limpieza (barrido final)**
- Candidatos a borrar: `exploration_tutorial`, `exploration_test`, `exploration_test_bak` (+ su `StateDebugLabel`), `exploration_telmori_village` (+ líneas comentadas de `SCENE_EXPLORATION`), `player.gd`/`player.tscn` (bloqueado por `test/test_shop_ui.gd`), `combat_test.tscn`/`combat_hud.tscn` si se deja de usar.
- Ficheros `*_bak`: `core/combat/combat_system_bak.gd`, `scenes/player/player_combat_controller_bak.gd`, `ui/entity_animation_controller_bak.gd` (los dos primeros emiten la señal antigua; confirmar y borrar). `scenes/combat/combat_test.gd` conecta `Combat.combat_action_executed`, que no existe.
- `ui/dialogue/dialogue_panel_test.gd` (fichero de prueba en carpeta de producción).
- `Interactable` vestigial; su camino físico nunca se validó y ya no se va a validar.
- `SceneOrchestrator.open_loadout()` y `close_skill_tree()` sin llamadores (comentarios ya actualizados; estudiar su eliminación).
- Acción `toggle_inventory` del InputMap sin uso.
- Duplicado `damage_number.tscn` (`ui\` y `ui\combat\`); doble `create_shop_snapshot` y `print` de depuración en la tienda.
- Fuga de la instancia de `SCENE_COMBAT` en `SceneOrchestrator` (mitigada localmente en `combat_production_scene.gd`).
- `docs/athelia_estructura_proyecto_actualizado.md`: nombre antiguo del documento de estructura (el vigente es `athelia_estructura_carpetas.md`).
- Fuera del hito, para el final: CharacterCreation (6 offsets fijos y fondo gris plano sin el estilo del hito), HUD de exploración, combate (`UICombatToken` de tamaño fijo), `main_theme.tres` sin aplicar (fuentes y tema sin decidir), comentario erróneo en `interactive_scene_view.gd:15`.
- Decisión cerrada: F9/quickload en sesión activa queda no operativo; no se vuelve a tratar.
## Sin validar en partida (no es trabajo de código)
 
- **IA-0b:** solo queda que un enemigo o Mira sin estamina pasen el turno sin colgarlo (no se ejercita con los datos actuales; revisar en IA-0d).
- Spike 16 (parte B): puntos 4-7 del plan de validación, tooltips `NO_BUDGET`/`NO_SLOTS`, tienda vacía, camino `LOAN_ITEM`.
- Spike 17/18: mochila con más de 20 ítems con redimensionado en caliente.
- Saludo del sheriff de 3 líneas con 6 opciones a 648 de alto (recorte previsto de ~4 px, no observado).
- Idioma inglés de lo tocado en el Spike 15.
- Spike 19b: Party con 2 compañeros y un ítem seleccionado a 1152×648 (margen vertical ≈2 px); un tercer compañero.
- Spike 14 y 24: derrota en un combate lanzado desde narrativa (mismo código que producción) y con 0 o 2 compañeros (solo se probó con `companion_mira`); rescate y muerte permanente de un companion (sin camino jugable).
- Spike 10: camino de fallo del libro (`item_use_failed`) y guardado/carga con Curtido aprendido.
- Spike 21: detalle de Ataque Pesado, refresco ante una mejora externa con la pantalla abierta, contexto PlayerMenu → SkillTree, 1680×1050 de la versión final, lista larga (>15 habilidades).
- Spike 20: el contexto `open_loadout()` (sin llamadores) y los errores de asignación (`LOADOUT_ERROR_*`), que la interfaz no puede provocar porque la lista ya filtra; asignación con un compañero en la party (el Loadout es solo del jugador).
- Spike 22: scroll de la lista de buffs con más de seis, captura en inglés a 1680×1050 y buffs con modificadores reales sobre atributos (los de depuración llevan lista vacía).
- Spike 24: Game Over con arte real de fondo (hoy plano) y captura en inglés a 1680×1050.
