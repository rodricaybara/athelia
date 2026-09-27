# Spike 8 — UI/UX de combate (CERRADO)

**Estado:** Cerrado — 5 puntos resueltos y validados en combate real contra
un grupo de 6-8 lobos.
**Origen:** Pendientes menores de Grupos 4 y 5 (mejoras post-Spike 3),
recopilados en `athelia_pendientes_post_pivote_narrativo.md`, punto 3.
**Añadido durante la sesión:** Punto 5, no estaba en el alcance original —
apareció al validar el Punto 4 (no se podía atacar en combate real para
comprobar las fichas) y se decidió tratarlo dentro de este mismo spike por
encajar de sobra en "UI/UX de combate".
**Relación con Spike 6:** confirmada desde el principio — ninguno de los 5
puntos dependía de la causa raíz investigada allí (`??` de `companion_mira`
y HP/EN visible en combate usan `Resources.resource_changed`/
`EventBus.resource_changed` directamente, no los accesores arreglados en
Spike 6).

---

## Punto 1 — Ficha de `companion_mira` con `??` — CERRADO

**Causa raíz confirmada:** `combat_arena_viewmodel.gd._initials_for()` solo
leía `CharacterState.character_name`. Ese campo únicamente se rellena para
el jugador (Character Creation) o vía `load_save_state()` — nunca para
companions/enemigos en su registro (`party_manager.gd` →
`Characters.register_entity()` → `CharacterState._init()`, que no lo toca).
El propio docstring de `character_state.gd` ya avisaba de que el campo
queda vacío "para entidades que no lo necesitan (enemigos, companions con
nombre fijo en su definición)" — pero nada implementaba ese fallback.

`CharacterDefinition.name_key` (campo obligatorio, validado por
`validate()`) es exactamente ese "nombre fijo": confirmado con
`companion_mira.tres` (`name_key = "character_companion_mira_name"`), dato
correcto esperando a ser leído desde el sitio equivocado.

**Arreglo:** `_initials_for()`/`_display_name()` ganan una jerarquía de
resolución común (`_resolve_name()`, mismo fichero): nombre elegido en
Character Creation si existe, si no `tr(CharacterDefinition.name_key)`.

## Punto 2 — Log con IDs internos en vez de nombres localizados — CERRADO

**Confirmado: misma causa exacta que el Punto 1.** `_display_name()` tenía
el mismo problema que `_initials_for()` — mismo arreglo, mismo commit. No
hizo falta tratarlos como dos causas independientes, la sospecha del spec
original se confirmó del todo.

## Punto 3 — Los 8 botones del menú de acciones no muestran nombre — CERRADO (no era bug)

**Investigación por capas, sin dar nada por sentado:**
- `combat_hud_viewmodel.gd._refresh_slots()` rellena `display_name`
  correctamente vía `tr(SkillDefinition.name_key)`/`tr(ItemDefinition.name_key)`
  — código correcto.
- `combat_arena_panel.gd._render_action_slots()` pinta el texto del botón
  correctamente — código correcto.
- Hipótesis inicial descartada por código: `CombatArenaViewModel._ready()`
  sí hace `add_child(action_menu)`, la señal `combat_started` sí llega a
  tiempo (las fichas se renderizan en combate real, prueba de que la cadena
  de señales funciona).
- `loadout_state.gd`: `LoadoutState._init()` inicializa los 8 slots a `""`
  — vacíos hasta que `assign_skill()`/`assign_consumable()` se llaman
  explícitamente desde `LoadoutViewModel`.
- `loadout_viewmodel.gd`/`loadout_screen.gd`: cadena de asignación
  arquitectónicamente correcta (referencia viva a `state.loadout`, sin
  copias).

**Causa real, confirmada con capturas de la pantalla de Loadout:** el
loadout del jugador nunca había sido asignado — los 8 slots aparecían en
`LOADOUT_SLOT_EMPTY` en la propia pantalla de Loadout, no solo en combate.
No era un bug de lectura/renderizado en ningún fichero de la cadena.

**Hallazgo real durante la validación en juego:** la pantalla de Loadout
requiere seleccionar el slot primero y luego la skill (selección en dos
pasos) sin ninguna pista visual de que hace falta el primer clic — confundió
la prueba hasta confirmarlo. Candidato a mejora de UX menor, aparcado para
la recopilación final.

**Hallazgo de paso, sin efecto visible:** `loadout_viewmodel.gd`
(`_refresh_slots()`) fijaba `SlotData.display_name` ya traducido
(`tr(def.name_key)`), a diferencia de `SkillSlotData`/`ConsumableSlotData`
en el mismo fichero (clave sin traducir, documentado "se traduce en la
View") — `loadout_screen.gd` hacía `tr()` una segunda vez sobre el
resultado. `tr()` sobre un string que no es una clave válida devuelve el
string tal cual, así que no se notaba, pero es un doble-`tr()` real.
Arreglado para seguir el mismo patrón que las otras dos data class.

**Ninguno de los ficheros de código de este punto necesitó arreglo** más
allá del doble-`tr()`. Una vez asignado el loadout desde la pantalla
correspondiente, los botones de combate mostraron los nombres
correctamente — validado en juego.

## Punto 4 — Columna de enemigos desbordada con 6-8 enemigos — CERRADO

**Causa raíz confirmada:** `EnemyColumn` (`GridContainer`, 2 columnas) vive
dentro de `ArenaSection`, un `Control` normal posicionado por anclas fijas,
sin `ScrollContainer` ni `clip_contents`. Con 6-8 fichas, la altura mínima
calculada por el `GridContainer` supera el rect fijo disponible y se
desborda por arriba, sin nada que lo contenga.

**Decisión de Fernando:** recalcular tamaño de ficha en vez de scroll.

**Primer intento — INCORRECTO, descartado tras playtest:** redimensionar
`UICombatToken.custom_minimum_size`/`custom_maximum_size` directamente.
Todo el contenido interno del token (`TokenVisual`, `HpValueLabel`,
`TypeIcon`...) está anclado con desplazamientos en píxeles **absolutos**
calculados para un lienzo exacto de 96×144 — reducir el `.size` real del
nodo rompe ese anclaje, el contenido no se reescala junto con el círculo.
Confirmado en captura real: iconos de tipo quedando fuera del círculo de la
ficha.

**Arreglo correcto:** el `UICombatToken` en sí **nunca cambia de tamaño
real** — cada ficha enemiga se instancia dentro de un `Control` envoltorio
nuevo (`combat_arena_panel._enemy_slots[entity_id]`), y es ESE envoltorio
el que `_rescale_enemy_tokens()` redimensiona de verdad
(`custom_minimum_size`/`custom_maximum_size`, para que el `GridContainer`
reserve menos alto por fila). El token, dentro, se encoge solo
**visualmente** con `.scale` — su anclaje interno sigue siendo válido
porque su `.size` real nunca cambia. `UICombatToken` gana
`const BASE_SIZE := Vector2(96, 144)` (su tamaño de diseño), para que
`combat_arena_panel.gd` derive el factor de escala sin duplicar el número.
Escala mínima `TOKEN_MIN_SCALE = 0.6`, recalculada solo cuando cambia el
número de fichas enemigas (nueva, refuerzo — nunca decrece, las fichas
muertas se quedan en el array por diseño ya tomado en Grupo 5).

**Validado en combate real** contra 6-8 lobos: fichas encogidas, iconos ya
contenidos dentro del círculo, sin desborde por arriba.

## Punto 5 — "No target specified" al atacar (añadido durante la sesión) — CERRADO

**No estaba en el alcance original.** Apareció al validar el Punto 4:
Fernando no podía atacar en combate real, con este error:
```
[CombatSystem] No target specified in action_data for skill: skill.attack.light
```
Se decidió tratarlo como Punto 5 de este mismo spike.

**Causa raíz confirmada:** `player_combat_controller.gd` ya tenía un
sistema de targeting completo y correcto — auto-selecciona el primer
enemigo al entrar en combate (`_on_combat_started()`), permite ciclar con
Tab, y `request_skill()` construye el `action_data` completo (`actor`,
`skill_id`, `target`) antes de emitir `player_action_requested`.
`combat_arena_panel.gd._on_slot_action_pressed()` **nunca llamaba a este
método** — construía su propio `action_data` a mano, sin el campo
`"target"` en absoluto. Dos caminos distintos para el mismo despacho, y el
de los botones de UI era el incompleto.

**Arreglo:** `player_combat_controller.gd._ready()` gana
`add_to_group("player_combat_controller")`. `combat_arena_panel.gd
._on_slot_action_pressed()` ya no construye su propio dict — localiza el
controlador vía `get_tree().get_first_node_in_group(...)` y llama a
`controller.request_skill(skill_id)`, que ya distingue skills normales de
`SPECIAL_ACTIONS` (defend/flee, caminos propios) correctamente.

**Hallazgo encadenado, mismo punto:** tras el arreglo anterior, el ataque ya
funcionaba pero ningún enemigo aparecía con el anillo de objetivo marcado
al entrar en combate — solo tras la muerte del primero. Causa: el orden de
conexión a `EventBus.combat_started` entre `PlayerCombatController` y
`CombatArenaViewModel` no está garantizado; el auto-target se emitía antes
de que las fichas existieran, y `_on_target_changed()` no tenía ningún
token todavía sobre el que aplicar la marca. Arreglado sincronizando el
objetivo directamente: `CombatArenaViewModel._on_combat_started()` llama a
`PlayerCombatController.get_current_target()` justo después de construir
las fichas, sin depender de recibir la señal a tiempo.

**Validado en combate real:** ataque sin error, objetivo marcado desde el
primer frame de combate.

---

## Antipatrones de arquitectura UI documentados (`athelia_ui_architecture.md`)

1. **Redimensionar un `Control` cuyo contenido usa offsets fijos** — Punto 4.
2. **La View construye su propio payload de evento en vez de delegar en el
   dueño del estado** — Punto 5.

## Fuera de alcance (confirmado, sin tocar)

- F9/quickload (Spike 7, cerrado sin arreglo)
- Botón "Ataque Pesado" en gris durante la validación del Punto 3 — no es
  un bug, `is_available` en `combat_hud_viewmodel.gd` solo depende de
  cooldown/estamina, nunca de si la skill está "aprendida"; con estamina
  llena debería estar disponible salvo cooldown activo de esa partida
  concreta. Si se quiere investigar, es un punto nuevo, no de este spike.
- El warning `[PartyManager] 'companion_mira' already in party` — sigue sin
  relación confirmada con ningún punto de este spike, aparcado para la
  recopilación final.

## Pendiente para la recopilación final

- UX de la pantalla de Loadout: ninguna pista visual de que hace falta
  seleccionar el slot antes que la skill/ítem (Punto 3).
- Claves de localización sin traducir vistas en la propia pantalla de
  Loadout durante la validación (`LOADOUT_TITLE`, `LOADOUT_SLOT_EMPTY`,
  `LOADOUT_SKILLS_AVAILABLE`) — probablemente faltan en el `.csv`, no
  investigado en este spike.
