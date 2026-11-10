# Athelia — Estado actual (hito de rediseño de interfaces)
 
*Actualizado: 2026-11-10, tras el cierre del Spike 23.*
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
| 21 | Árbol de habilidades (21a pantalla, 21b comparación) | cerrado | 15 |
| 21c | Árbol visual con relaciones (selector Lista/Árbol) | propuesto; numeración por decidir (el 22 es el Menú del jugador) | 21 |
| 22 | Menú del jugador | cerrado | 18, 20, 21 |
| 23 | Pantalla de inicio | cerrado | 15 |
| 24 | Game Over: rediseño visual | pendiente | 14, 15, 23 |
 
El orden entre 19b, 20, 21 y 23 es flexible mientras se respeten las dependencias.
 
## Alcance de lo pendiente
 
**21c — Árbol visual (propuesto).** Nodos y líneas de prerrequisitos con un selector «Lista/Árbol» en la cabecera, sobre el `SkillTreeViewModel` del 21 (ya entrega niveles, requisitos y estado). Decidir en la Fase 0 la disposición (por nivel/subcategoría) y qué hace el scroll/zoom.
 
**22 — Menú del jugador (cerrado, 2026-11-10).** Resueltos `I` dentro del menú, `I` con Party y la doble `P`. Ver `docs/spike_22_menu_jugador.md`.
 
**23 — Pantalla de inicio (cerrado, 2026-11-10).** Layout A con `TitleBackdrop` (fondo y título reutilizables, placeholder plano), `UIButton` `LG` con jerarquía, `UIPanel` con marco en Créditos y Confirmar, foco inicial y Esc = Volver. Opciones se extrajo como componente (`OptionsPanel` + `GameSettings`, `ui/options/`) con persistencia de idioma y pantalla completa en `user://settings.cfg`; los sliders de volumen quedan ocultos hasta que exista el audio. Ver `docs/spike_23_pantalla_inicio.md`.
 
**24 — Game Over.** `UIPanel` + tokens + arte del estilo del 23 (hereda `TitleBackdrop`, que ya existe: basta instanciarlo con el título y el mensaje de derrota); foco inicial en el botón. La lógica ya está en `GameOverViewModel` (Spike 14). El botón `ReturnToMenuButton` se ensancha («Volver al menú principal»): resolver en la maqueta.
 
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
- `TRANSITIONING` atascado: si `enter_post_load_state()` o `enter_character_creation()` rechazan la transición, `MainMenuViewModel` no se recupera (mismo patrón que el 14 arregló en Game Over).
- Versión en el pie (requiere `config/version` en `project.godot`); sustituir los «Por definir» de Créditos; asignar arte a `TitleBackdrop` y comprobar la legibilidad con el velo.
- Borrar `localization/menus.csv.bak`.
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
- `UIButton` `PRIMARY` deshabilitado es ilegible (el árbol lo evita pasando a `SECONDARY`); arreglarlo en el componente afecta a todas las pantallas.
- `SceneOrchestrator.close_skill_tree()` sin llamadores.
**Limpieza (barrido final)**
- Candidatos a borrar: `exploration_tutorial`, `exploration_test`, `exploration_telmori_village` (+ líneas comentadas de `SCENE_EXPLORATION`), `player.gd`/`player.tscn` (bloqueado por `test/test_shop_ui.gd`), `combat_test.tscn`/`combat_hud.tscn` si se deja de usar.
- `Interactable` vestigial; su camino físico nunca se validó y ya no se va a validar.
- `SceneOrchestrator.open_loadout()` sin llamadores ni acción de input (código muerto; estudiar su eliminación).
- Autoload `DebugPartyTool` aún en `project.godot` (línea 56) y traza `[DBG] tecla:` en el Output: retirar antes de cerrar el hito.
- Duplicado `damage_number.tscn` (`ui\` y `ui\combat\`); etiqueta de depuración `estado | paused=` en el HUD; `print` `[DIAG]` en `narrative_scene_panel.gd`; doble `create_shop_snapshot` y `print` de depuración en la tienda; comentarios «UISlot.setup()» obsoletos en `combat_arena_test_scene.gd` y `combat_production_scene.gd`.
- Fuga de la instancia de `SCENE_COMBAT` en `SceneOrchestrator` (mitigada localmente en `combat_production_scene.gd`).
- Comentario «Tecla I / Tab» obsoleto en `ExplorationController` (Tab no está enlazada) y acción `toggle_inventory` sin uso; comentario obsoleto de `open_loadout()` («llamado desde `PlayerMenuViewModel.request_open_loadout()`»).
- Fuera del hito, para el final: CharacterCreation (6 offsets fijos y fondo gris plano sin el estilo del hito), HUD de exploración, combate (`UICombatToken` de tamaño fijo), `main_theme.tres` sin aplicar (fuentes y tema sin decidir), comentario erróneo en `interactive_scene_view.gd:15`.
- Decisión cerrada: F9/quickload en sesión activa queda no operativo; no se vuelve a tratar.
## Sin validar en partida (no es trabajo de código)
 
- Spike 16 (parte B): puntos 4-7 del plan de validación, tooltips `NO_BUDGET`/`NO_SLOTS`, tienda vacía, camino `LOAN_ITEM`.
- Spike 17/18: mochila con más de 20 ítems con redimensionado en caliente.
- Saludo del sheriff de 3 líneas con 6 opciones a 648 de alto (recorte previsto de ~4 px, no observado).
- Idioma inglés de lo tocado en el Spike 15.
- Spike 19b: Party con 2 compañeros y un ítem seleccionado a 1152×648 (margen vertical ≈2 px); un tercer compañero.
- Spike 14: combate lanzado desde narrativa; rescate y muerte permanente de un companion (sin camino jugable).
- Spike 10: camino de fallo del libro (`item_use_failed`) y guardado/carga con Curtido aprendido.
- Spike 21: detalle de Ataque Pesado, refresco ante una mejora externa con la pantalla abierta, contexto PlayerMenu → SkillTree, 1680×1050 de la versión final, lista larga (>15 habilidades).
- Spike 20: el contexto `open_loadout()` (sin llamadores) y los errores de asignación (`LOADOUT_ERROR_*`), que la interfaz no puede provocar porque la lista ya filtra; asignación con un compañero en la party (el Loadout es solo del jugador).
- Spike 22: scroll de la lista de buffs con más de seis, captura en inglés a 1680×1050 y buffs con modificadores reales sobre atributos (los de depuración llevan lista vacía).
