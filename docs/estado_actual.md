# Athelia — Estado actual (hito de rediseño de interfaces)
 
*Actualizado: 2026-11-02, tras el cierre del Spike 20.*
Contrato de pantalla, tokens, resolución y antipatrones: ver `athelia_ui_architecture.md`. Historia y diagnósticos de los spikes cerrados: `athelia_historial_spikes.md` y `docs/spike_N.md`.
 
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
| 21 | Árbol de habilidades | pendiente | 15 |
| 22 | Menú del jugador | pendiente | 18, 20, 21 |
| 23 | Pantalla de inicio | pendiente | 15 |
| 24 | Game Over: rediseño visual | pendiente | 14, 15, 23 |
 
El orden entre 19b, 20, 21 y 23 es flexible mientras se respeten las dependencias.
 
## Alcance de lo pendiente
 
**21 — Árbol de habilidades.** ~810 líneas de View que construye la UI por código; decidir en la Fase 0 si se parte en dos. Sustituir `_apply_panel_styles()`, `_add_bg_rect()` y `_add_border_rect()` por `UIPanel`. Los tokens `BG_*`/`TEXT_*` ya son alias de `COLOR_*`, así que la migración es mínima. Absorbe: pestaña `companion_mira` muestra el id en vez del nombre, un `T1` suelto sin localizar, claves `SKILL_META_COST_`, `SKILL_NOT_FOUND`, `SKILL_NOT_LEARNED`, `SKILL_SLOTS`, `SKILL_A`, `SKILL_B`, `SKILL_CATEGORY` sin definición, revisión de los textos de `skills.csv` y `SKILL_ATTACK_LIGHT_DESC` («atack», espacios). Validar: entrenar skill, filtros, comparación con companions, cierre; dos contextos (PlayerMenu y `open_skill_tree()`).
 
**22 — Menú del jugador.** Es el hub: integra Loadout, Inventory y SkillTree ya rediseñados; `closed` y `_open_subscreen()` son correctos y se conservan. Incluye el problema del orquestador de slot único: `I` dentro de PlayerMenu cierra el menú entero, e `I` con Party abierta la cierra; y la doble pulsación de `P` tras cerrar el menú del jugador (`open_player_menu()` no conecta `_on_overlay_closed`). Validar: anidado de tres niveles, HP/EN en vivo.
 
**23 — Pantalla de inicio.** Arte de fondo y título, `UIButton` `LG`, marco en Opciones/Créditos/Confirmar salida; mantener el ciclo de vida de Main Scene (el ViewModel escucha `game_state_changed`). Validar: nueva partida, cargar (con y sin guardado), opciones, créditos, salir, volver desde Character Creation y tras una derrota.
 
**24 — Game Over.** `UIPanel` + tokens + arte del estilo del 23; foco inicial en el botón. La lógica ya está en `GameOverViewModel` (Spike 14). El botón `ReturnToMenuButton` se ensancha («Volver al menú principal»): resolver en la maqueta.
 
## Pendientes sin spike asignado
 
**Motor**
- `CombatSystem._active_buffs` no se limpia al terminar un combate; `SessionReset` solo cubre entidades registradas.
- Combate/Loadout (replantear con el combate): `skill.combat.defend`/`flee` sin `.tres`; ids hardcodeados en el controlador (`combat_defense` → defend, `combat_scape` → flee, `SPECIAL_ACTIONS`); sin skill COMBAT con tag `escape`; el HUD muestra vacíos los slots de Defensa y Huida con el loadout actual (la tarjeta de Huida del Loadout dice «Acción de combate»); preselección de Defender/Esquiva/Huida; el combate solo lee el loadout del jugador (`PLAYER_ID`); `SLOT_KEYBIND_LABEL` vive en `CombatHudViewModel` (moverlo a un sitio compartido).
- Una skill aprendida con requisitos no cumplidos se puede asignar y sale atenuada en el HUD; la lista del Loadout no muestra disponibilidad.
- `fireball` (tags `magic`, `ranged`) no es asignable a ningún slot.
- Teclas F y G de consumibles sin acción en el InputMap (la etiqueta se muestra igualmente).
- `CombatLootSpawner.spawn_pending_loot()` sin llamador: el botín no se materializa en producción.
- `ItemCharacterIntegration` es código muerto (el autoload `Bridge` es `item_character_bridge.gd`).
- `PartyManager._register_in_systems()` conserva un acceso privado (`_entity_skills.get(...).keys()`): falta un listador público en `SkillSystem`.
- `equip_item` ignora el slot de destino; motivos de `equip_failed`/`item_use_failed` en texto libre en inglés (hace falta código de motivo).
- Una poción se consume aunque no tenga efecto (puente de ítems).
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
**Contenido y datos**
- Marcador `telmori_village_departure` (salida final del pueblo): sale un aviso al cargar la exploración; decidir qué ocurre al salir.
- Retrato del posadero es un placeholder (muestra el del sheriff).
- Falta `RESOURCE_FOCUS_NAME` (el coste de `focus` en el Loadout cae a `id.capitalize()`); solo existen las claves de salud, estamina y oro.
- `ITEM_HEALTH_POTION_DESC`: espacio inicial en ES y efecto inconsistente (EN «10», ES «50», `value = 10.0`).
- `telmori_lair_loot_obsidian.json.json` pendiente de renombrar (carga igual).
- Claves `INVENTORY_BAG_HEADER`/`INVENTORY_STATS_HEADER` sin uso; `INVENTORY_STAT_FOCUS` oculta.
- Descripciones de estrategia inexistentes en datos; `PARTY_*`: el mensaje «Equipado en Jugador» usa nombre genérico.
**Limpieza (barrido final)**
- Candidatos a borrar: `exploration_tutorial`, `exploration_test`, `exploration_telmori_village` (+ líneas comentadas de `SCENE_EXPLORATION`), `player.gd`/`player.tscn` (bloqueado por `test/test_shop_ui.gd`), `combat_test.tscn`/`combat_hud.tscn` si se deja de usar.
- `Interactable` vestigial; su camino físico nunca se validó y ya no se va a validar.
- `SceneOrchestrator.open_loadout()` sin llamadores ni acción de input (código muerto; estudiar su eliminación).
- Autoload `DebugPartyTool` aún en `project.godot` (línea 56) y traza `[DBG] tecla:` en el Output: retirar antes de cerrar el hito.
- Duplicado `damage_number.tscn` (`ui\` y `ui\combat\`); etiqueta de depuración `estado | paused=` en el HUD; `print` `[DIAG]` en `narrative_scene_panel.gd`; doble `create_shop_snapshot` y `print` de depuración en la tienda; comentarios «UISlot.setup()» obsoletos en `combat_arena_test_scene.gd` y `combat_production_scene.gd`.
- Fuga de la instancia de `SCENE_COMBAT` en `SceneOrchestrator` (mitigada localmente en `combat_production_scene.gd`).
- Fuera del hito, para el final: CharacterCreation (6 offsets fijos), HUD de exploración, combate (`UICombatToken` de tamaño fijo), `main_theme.tres` sin aplicar (fuentes y tema sin decidir), comentario erróneo en `interactive_scene_view.gd:15`.
- Decisión cerrada: F9/quickload en sesión activa queda no operativo; no se vuelve a tratar.
## Sin validar en partida (no es trabajo de código)
 
- Spike 16 (parte B): puntos 4-7 del plan de validación, tooltips `NO_BUDGET`/`NO_SLOTS`, tienda vacía, camino `LOAN_ITEM`.
- Spike 17/18: mochila con más de 20 ítems con redimensionado en caliente.
- Saludo del sheriff de 3 líneas con 6 opciones a 648 de alto (recorte previsto de ~4 px, no observado).
- Idioma inglés de lo tocado en el Spike 15.
- Spike 19b: Party con 2 compañeros y un ítem seleccionado a 1152×648 (margen vertical ≈2 px); un tercer compañero.
- Spike 14: combate lanzado desde narrativa; rescate y muerte permanente de un companion (sin camino jugable).
- Spike 10: camino de fallo del libro (`item_use_failed`) y guardado/carga con Curtido aprendido.
- Spike 20: el contexto `open_loadout()` (sin llamadores) y los errores de asignación (`LOADOUT_ERROR_*`), que la interfaz no puede provocar porque la lista ya filtra; asignación con un compañero en la party (el Loadout es solo del jugador).