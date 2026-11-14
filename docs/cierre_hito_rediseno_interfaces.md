# Cierre del hito de rediseño de interfaces (Spikes 14-24)

*Cerrado: 2026-11-11. Los once spikes del hito están cerrados y validados en partida real. Este documento es el resumen de cierre; el detalle de cada spike está en su informe `docs/spike_N_*.md` y el plan original en `plan_hito_rediseno_interfaces_spikes_14_24.md`.*

## 1. Qué se consiguió

Se rehicieron y homogeneizaron ocho pantallas (tienda, inventario, Party, Loadout, árbol de habilidades, menú del jugador, pantalla de inicio y Game Over) sobre un Design System común, con contrato MVVM, localización por pantalla y reglas de layout para una ventana mínima de 1152×648 (referencia de diseño 1680×1050, sin estiramiento). Antes de ellas se resolvió el reinicio de sesión (14) y los cimientos del Design System (15).

| # | Spike | Resultado en una línea | Informe |
|---|---|---|---|
| 14 | Reinicio de sesión | Perder un combate lleva al menú con la sesión limpia (`SessionReset`, `EntityLifecycle`) | `spike_14_reinicio_sesion.md` |
| 15 | Cimientos del DS | Tokens fusionados con alias, `UIPanel` corregido, diálogo en rejilla, localización limpia | `spike_15_cimientos_design_system.md` |
| 16 | Tienda (+16b) | Primera adopción del DS; préstamo `quest_loan` | `spike_16_tienda.md` |
| 17 | Inventario A | Contrato MVVM sin cambio visual | `spike_17_inventario_mvvm.md` |
| 18 | Inventario B | `UIPanel`, `UISlot`, categorías, comparación y bonos | `spike_18_inventario_rediseno.md` |
| 19 | Party (19a, 19b) | `UISlot`, mochila a mochila, detalle, regla de préstamo, 16c resuelta | `spike_19_party.md`, `spike_19b_party.md` |
| 20 | Loadout | Tarjetas, estado de selección en el ViewModel, 41 claves | `spike_20_loadout.md` |
| 21 | Árbol de habilidades | Lista por niveles, detalle con pie fijo, modo Comparar | `spike_21_arbol_habilidades.md` |
| 22 | Menú del jugador | Hub con recursos, atributos y efectos; regla de navegación del orquestador | `spike_22_menu_jugador.md` |
| 23 | Pantalla de inicio | `TitleBackdrop`, `OptionsPanel` + `GameSettings`, persistencia de opciones | `spike_23_pantalla_inicio.md` |
| 24 | Game Over | Pantalla con `TitleBackdrop`, limpieza y auditoría de cierre | `spike_24_game_over.md` |

## 2. Estado final de las ocho pantallas

| Pantalla | Raíz visual | Componentes del DS | Textos |
|---|---|---|---|
| Tienda | `UIPanel` OVERLAY con marco | `UIButton`, `ShopItemSlot` | `shops.csv` |
| Inventario | `Backdrop` + `Frame` con marco | `UIButton`, `UISlot`, `ItemDetailPanel` | `inventory.csv` |
| Party | `Backdrop` + `Frame` con marco | `UIButton`, `UISlot`, `UIResourceBar`, `ItemDetailPanel` | `party.csv` |
| Loadout | `Backdrop` + `Frame` con marco | `UIButton`, `UISlot`, `LoadoutCard` | `loadout.csv` |
| Árbol de habilidades | `Backdrop` + `Frame` con marco | `UIButton`, `SkillCard` | `skill_tree.csv` |
| Menú del jugador | `Backdrop` + `Frame` con marco | `UIButton`, `UIResourceBar`, `PlayerMenuRow` | `player_menu.csv` |
| Pantalla de inicio | `TitleBackdrop` | `UIButton`, `UIPanel` con marco, `OptionsPanel` | `main_menu.csv`, `options.csv` |
| Game Over | `TitleBackdrop` | `UIButton` | `game_over.csv` |

Todas con View pasiva, ViewModel hijo, razones de `changed` con caso en la View, nodos `%`, `closed` si son anidables y tokens en lugar de colores o tamaños sueltos.

## 3. Componentes del Design System que quedan

`UIPanel` (variantes, marco decorativo opt-in), `UIButton` (variantes, tamaños, modo solo icono), `UISlot` (arrastre, `owner_id`, estados), `UIResourceBar` (`set_values()`), `TitleBackdrop` (fondo, título y `title_tone`) y `ShopItemSlot` (fila de lista). Componentes de pantalla propios: `LoadoutCard`, `SkillCard`, `PlayerMenuRow`, `OptionsPanel`. Helpers: `BagCapacity`, `ItemDetailBuilder`, `GameSettings`.

## 4. Cambios fuera de `ui/` durante el hito

- **Core:** `SessionReset`, `EntityLifecycle`, `Economy.reset_session()`, `Combat.clear_buffs()` en el reinicio (14); `quest_loan` en `EconomySystem` (16b); `take_item` busca en toda la party (19b).
- **`SceneOrchestrator`:** `closed` conectado en `open_inventory/party/skill_tree/player_menu` y regla de toggle `_handle_overlay_toggle()` (17, 21, 22); liberación de escenas de sesión y reinicio al entrar en `MENU` (14).
- **Spike 24:** ningún cambio de comportamiento; solo dos comentarios de `scene_orchestrator.gd`.

## 5. Auditoría final de contrato de `ui/`

**Pantallas del hito (las ocho):** sin accesos directos a sistemas core desde las Views, sin `Color(...)` literales, sin `StyleBoxFlat.new()` ni `modulate` fuera de los componentes del DS. `Label.new()`/`Button.new()` solo aparecen para contenido dinámico de listas, que no se considera violación. `item_detail_builder.gd` usa `Equipment` e `Items` porque es un helper de ViewModel, no una View.

**Fuera del hito (conocido y anotado):**

| Zona | Hallazgo |
|---|---|
| Combate (`combat_hud`, `combat_arena_panel`, `entity_animation_controller`, `damage_number`) | Acceso directo a `Characters`, `Inventory` y `EventBus`; literales de color y `modulate` |
| Narrativa (`narrative_scene_panel`) | `Dialogue.start_dialogue()` desde un lambda de la View |
| Diálogo (`dialogue_panel.tscn:30`) | Literal `Color(0,0,0,1)` |
| `loading_screen.tscn:25` | Literal de color (pantalla sin conectar) |
| Panel de objetos del mundo (vestigial) | Constantes de color y `modulate` |
| `interactive_scene_view.gd:78` | `UIButton.new()` en vez de instanciar `ui_button.tscn` |
| Character Creation | Tamaños fijos y fondo gris sin el estilo del hito |
| `dialogue_panel_test.gd` | Fichero de prueba dentro de `ui/dialogue/` |

*(Tabla elaborada con las salidas de la auditoría del 11-nov. Para confirmar el estado final tras la limpieza, repetir las búsquedas de la §0.14 de la spec.)*

## 6. Pendientes consolidados por área

El detalle vivo está en `estado_actual.md`. Resumen por área:

- **Audio y opciones:** diseñar el audio y los buses `Music`/`SFX`; menú de pausa con `OptionsPanel`; guardar el modo de pantalla realmente aplicado; `playtime_seconds` fiable.
- **Menú del jugador:** los seis slots del equipo; atajo de Loadout.
- **Árbol visual:** selector Lista/Árbol sobre el ViewModel del 21 (spike propio, fuera del hito, sin número).
- **Combate y Loadout:** Defender/Esquiva/Huida sin datos, huida fija, loadouts de compañeros, `SLOT_KEYBIND_LABEL` a un sitio compartido, UI de combate fuera del contrato.
- **Motor:** modificadores `attribute.<base>` sobre derivados, `ModifierApplicator` sin señales, `Inventory.add_item` que pierde datos, `_active_buffs`, `CombatLootSpawner.spawn_pending_loot()`, `equip_item` sin slot de destino, motivos de fallo en texto libre, máximo de compañeros.
- **Contenido:** marcador `telmori_village_departure`, retrato del posadero, textos de poción, `SKILL_ATTACK_LIGHT_DESC`, `RESOURCE_FOCUS_NAME`, unidad de `duration` de los buffs.
- **Limpieza (barrido final):** escenas obsoletas de exploración, `player.gd`/`player.tscn`, `*_bak`, duplicado de `damage_number.tscn`, `dialogue_panel_test.gd`, `StateDebugLabel` en las escenas de test, `open_loadout()` y `close_skill_tree()` sin llamadores, acción `toggle_inventory`, código de quickload, documento de estructura con nombre antiguo.
- **Fuera del hito, siguiente barrido:** Character Creation, HUD de exploración, combate, narrativa, `main_theme.tres` y fuentes.

## 7. Lecciones transversales

1. **Fase 0 antes de diseñar:** la documentación y las specs describieron el código de forma incorrecta en varios spikes (S12, S15, S19, S24). Comprobar con búsquedas.
2. **Un parche aplicado se verifica antes de probar:** una prueba «ok» no demuestra que el cambio estuviera en el fichero.
3. **Un componente compartido se corrige de forma aditiva y con la opción nueva apagada por defecto.**
4. **Dos caminos para el mismo cambio no:** un parche lleva un único camino (ancla o bloque final).
5. **El estado vive en el ViewModel y una operación que cambia de dueño un dato valida antes de mover y revierte si falla.**
6. **Una pantalla anidable expone `closed` y nunca se libera a sí misma;** con un orquestador de slot único, `closed` se conecta siempre.
7. **Centrar por contenido** con anclas al centro, `grow` a ambos lados y offsets a 0; sin autowrap en textos cortos de modales.
8. **Un mismo valor en dos familias de tokens es un alias,** y los alias apuntan hacia atrás.
9. **Una intención que pide una transición al motor comprueba que ocurrió** y vuelve a su estado si no.

## 8. Fuera del hito

Character Creation, HUD de exploración, combate (`UICombatToken` de tamaño fijo), narrativa, panel de objetos del mundo, `main_theme.tres` y la elección de fuentes. Son el barrido opcional posterior (§8 del plan).
