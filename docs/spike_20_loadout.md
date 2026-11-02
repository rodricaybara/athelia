# Spike 20 — Loadout: informe de cierre

**Estado:** cerrado, validado en partida (2026-11-02). Tercer spike del hito de rediseño que reescribe una pantalla entera sobre el Design System tras Inventario (18) y Party (19).

## 1. Qué se hizo

Se rediseñó la pantalla Loadout (asignar habilidades de combate a `attack_1..3`, `dodge`, `defense`, `escape` y consumibles a `consumable_1/2`) con el Design System y se movió el estado de selección al ViewModel.

- `UIPanel` OVERLAY con marco decorativo (`Backdrop` + `Frame`, fracción 0,9, tope 1400×820), `UIButton` y `UISlot`; solo tokens (`UITokens`), sin `Color(...)`.
- Nombres únicos `%` (adiós a las rutas `$Root/...` de 6-7 niveles).
- Localización completa: `loadout.csv` (`id,en,es`, 41 claves `LOADOUT_*`).
- Layout A (aprobado en maqueta): columna izquierda con los slots agrupados (Ataque / Defensa / Consumibles); columna derecha con la lista de candidatos y el cajetín de detalle (con «Vaciar slot»); línea de feedback inferior; Esc cierra.
- Habilidades como tarjetas anchas (`LoadoutCard`, nuevo componente de la pantalla, `class_name`, en `ui/loadout/`); consumibles como `UISlot` de 64 px con la tecla en la etiqueta.

## 2. Decisiones de Fernando

| Id | Decisión |
|---|---|
| L1 (c) | Habilidades como tarjetas, consumibles como `UISlot` |
| L2 | Clic + clic ahora; arrastre más adelante (C) |
| L3 | Mostrar todos los costes |
| L5 | La pantalla es del jugador; los loadouts de compañeros quedan pendientes |
| L6/L7 | Sin duplicados; la lista solo muestra lo compatible y no asignado en otro slot |
| L8 | `open_loadout()` se deja intacto; se estudiará eliminarlo |
| L4 | Un segundo clic en un slot seleccionado **solo deselecciona**; vaciar es un botón explícito |
| D1 (a) | Las etiquetas de tecla se leen de `CombatHudViewModel.SLOT_KEYBIND_LABEL` (b: moverla a un sitio compartido, pendiente) |
| D2 | El slot sigue seleccionado tras asignar |
| D3 | Sin duplicados ni en habilidades ni en consumibles |
| D4 | Sin mensaje de éxito; los errores salen en una línea fija (token `COLOR_DANGER_SOFT`, `Timer` de 2,5 s) |
| O1 | `escape` es un slot **fijo** (tarjeta «Acción de combate», no seleccionable ni asignable). Esquiva y Defensa sí son asignables. El combate se replanteará en otro spike |

## 3. Arquitectura resultante

- **ViewModel** (`loadout_viewmodel.gd`): `FIXED_SLOTS = ["escape"]`; estado público `selected_slot_id`, `groups`, `slots`, `candidates`, `list_header_key`, `list_message_key`, `error_message`; data classes `CostData`, `EntryData`, `SlotData`, `CandidateData`, `GroupData`. Intenciones: `request_select_slot()` (alterna, ignora los fijos), `request_assign_skill()`, `request_assign_consumable()`, `request_clear_slot()`, `request_close()`. Razones de `changed`: `opened`, `selection`, `slots`, `error`, `closed` (todas con caso en la View). Entrega **claves** de localización; la View traduce.
- **View** (`loadout_screen.gd`): `_input` con `ui_cancel` → `request_close()` + `set_input_as_handled()`; repintado diferido (`_schedule_render()` / `_flush_render()`); `_hover_entry` solo de vista; nunca accede a `Skills`, `Inventory`, `Characters`, `Items` ni `LoadoutState`.
- **Contratos conservados:** `LoadoutScreen.open(character_id)`, señal `closed` (la pantalla nunca se libera sola), `PlayerMenu._open_subscreen`, `open_loadout()` sin tocar. Sin cambios en el core.

## 4. Fase 0: hallazgos que corrigieron la spec

- El `class_name` es `CombatHudViewModel` (no `CombatHubViewModel`).
- La spec decía 6 claves `LOADOUT_ERROR_*`; el código tenía 7, y con `DUPLICATE` son 8.
- La spec afirmaba que el segundo contexto (`open_loadout()`) era alcanzable y que Esc cerraba: **`open_loadout()` no tiene llamadores ni acción de input** (código muerto; solo validable por inspección) y Esc no estaba implementado.
- La vista antigua limpiaba `_selected_slot_id` sin repintar tras una asignación rechazada (desincronización); y un segundo clic en un slot seleccionado lo vaciaba sin aviso.
- Datos: `skill.combat.defend`/`flee` no tienen `.tres`; el controlador de combate resuelve `combat_defense` → defend y `combat_scape` → flee por id hardcodeado; no existe ninguna skill COMBAT con tag `escape`; `fireball` (tags `magic`, `ranged`) no cabe en ningún slot; el loadout inicial está vacío; la escena de prueba asigna skills inexistentes; el combate solo lee el loadout del jugador (`PLAYER_ID`).

## 5. Validación en partida (2026-11-02, 1152×648 y 1680×1050)

Validado: apertura desde PlayerMenu, selección y asignación por tipo de slot, consumibles, «Vaciar slot», un clic en el slot seleccionado solo deselecciona, lista filtrada por compatibilidad y sin duplicados, tarjeta fija de Huida, cierre con Esc y con X volviendo al menú del jugador, reapertura tras comprar en la tienda (consumibles con icono), ES y EN, ambas resoluciones, combate con el HUD leyendo el loadout (ataque ligero, esquiva y consumibles visibles en la barra).

Output: `[LoadoutScreen] Ready` y `Subpantalla abierta: loadout_screen.tscn`, sin warnings ni «Razón desconocida». Depurador → Errores: vacío. Auditoría de contrato (`Select-String -CaseSensitive 'Skills\.|Inventory\.|Characters\.|Items\.|LoadoutState|Color\(|\$Root'`): solo la línea del comentario de cabecera.

**No ejercitado por diseño:** el error `LOADOUT_ERROR_DUPLICATE` (y el resto de errores de asignación) no se puede provocar desde la interfaz, porque la lista ya filtra lo no asignable. Quedan como salvaguarda del ViewModel (válida si en el futuro otra vía, p. ej. arrastre, intenta asignar).

**Observado en el HUD de combate:** con el loadout del test, el slot de Huida (R) y el de Defensa (E) aparecen vacíos en la barra, y Ataque Pesado aparece atenuado porque el jugador no cumple sus requisitos (árbol de habilidades bloqueado). Es coherente con lo anterior (no hay datos de defend/flee) y queda como pendiente; ver 6.

## 6. Pendientes registrados (sin spike asignado salvo indicación)

- **Huida:** la tarjeta dice «Acción de combate», pero con el loadout actual el HUD muestra el slot de Huida vacío (no existe `skill.combat.flee`). Replantear con el combate; hasta entonces la tarjeta promete algo que el HUD no muestra.
- **Defensa:** `skill.combat.defend`/`flee` sin `.tres`; ids hardcodeados en el controlador de combate (`combat_defense`, `combat_scape`, `SPECIAL_ACTIONS`); preselección de Defender/Esquiva/Huida (O2/O3, spike futuro de combate).
- Una habilidad aprendida pero con requisitos no cumplidos se puede asignar y aparece atenuada en el HUD (Ataque Pesado): la lista no muestra disponibilidad.
- `fireball` no es asignable a ningún slot (sin slot para magia).
- `open_loadout()` en `SceneOrchestrator`: código muerto; estudiar eliminarlo.
- Doble pulsación de `P` tras cerrar el menú del jugador: `open_player_menu()` no conecta `_on_overlay_closed` (→ Spike 22).
- Claves de recursos: falta `RESOURCE_FOCUS_NAME` (el coste de `focus` cae a `id.capitalize()`); solo existen `RESOURCE_HEALTH/STAMINA/GOLD_NAME`.
- Teclas F y G de consumibles sin acción en el InputMap (la etiqueta se muestra igualmente).
- D1(b): mover `SLOT_KEYBIND_LABEL` a un sitio compartido (toca combate).
- Loadouts de compañeros (L5): el combate solo lee el del jugador.
- Autoload `DebugPartyTool` aún en `project.godot` (línea 56) y traza `[DBG] tecla:` en el Output: retirar antes de cerrar el hito.
- Etiqueta de tecla del `UISlot` de consumible: ligeramente solapada con el borde inferior del icono (cosmético; comprobar si procede ajustarla en el componente).
- `SKILL_ATTACK_LIGHT_DESC` y descripción de la poción de vida con inconsistencias de texto (ya en el alcance del Spike 21 / datos).
- Arrastre para asignar (L2-C): evolución prevista.

## 7. Ficheros

| Fichero | Acción |
|---|---|
| `ui/loadout/loadout_card.gd` | nuevo (`class_name LoadoutCard`) |
| `ui/loadout/loadout_viewmodel.gd` | reescrito |
| `ui/loadout/loadout_screen.gd` | reescrito |
| `ui/loadout/loadout_screen.tscn` | reescrita (conserva uid) |
| `localization/loadout.csv` | nuevo; alta manual `loadout.en`/`loadout.es` en Project Settings → Localization |

## 8. Lecciones (resumen; detalle en `athelia_lecciones_tecnicas.md`)

El estado de selección vive en el ViewModel; el repintado se difiere cuando el clic nace en un nodo que el propio repintado destruye; una acción destructiva no se esconde en un segundo clic; filtrar candidatos por compatibilidad convierte los errores de asignación en salvaguarda; una pantalla con un contexto sin llamadores no se puede validar en partida y se registra como código muerto.
