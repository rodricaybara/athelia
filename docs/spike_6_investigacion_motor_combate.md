# Spike 6 — Investigación de motor de combate

**Estado:** CERRADO — causa raíz confirmada y arreglada en los dos puntos, sin necesidad de spike aparte para ninguno de los dos.
**Origen:** Bugs de motor detectados en Grupo 5 de mejoras post-Spike 3,
sin tratar en su momento. Recopilados en
`athelia_pendientes_post_pivote_narrativo.md`. Ampliado con un hallazgo
del cierre de Spike 5.
**Precede a:** Spike 8 (UI/UX de combate) — comparte pantallas con el
punto 3 de este spike.

---

## Punto 1 — Desync `AttributeResolver` / `ResourceState.max_effective`

### Causa raíz confirmada
Dos bugs independientes bajo el mismo síntoma visible (número mostrado ≠ número real):

**Sub-bug A — el desync `50/60`, `50/45` original.** `ModifierApplicator._recalculate_resource_maxes()` solo se dispara como efecto secundario de `Characters.set_base_attribute()`. El único punto del proyecto que llama a `set_base_attribute()` es `character_creation_viewmodel.gd`, para `"player"`, tras el reparto de atributos — por eso el player siempre estuvo bien sincronizado. Enemigos, refuerzos y companions se registran vía `Characters.register_entity()`/`Resources.register_entity()` directo (copian `definition.base_attributes` en `CharacterState._init()` sin pasar nunca por `set_base_attribute()`), así que su `max_effective` se quedaba congelado en el genérico de `ResourceDefinition.max_base` para siempre. Confirmado en 3 call sites de registro de enemigos: `exploration_controller.gd` y `narrative_scene_viewmodel.gd` (roster inicial, código duplicado línea por línea) y `combat_production_scene.gd` (refuerzos, con el orden de registro además invertido — Resources antes que Characters).

Más concreto todavía: `exploration_controller.gd`/`narrative_scene_viewmodel.gd` tenían además `resources.set_resource(enemy_id, "health", 50.0)` — un HP inicial fijo, hardcodeado, sin relación con el máximo real del enemigo. Es literalmente el origen del "50" que aparecía en el patrón `50/60`/`50/45` reportado.

**Sub-bug B — el hallazgo ampliado de `player_menu` (cierre de Spike 5).** Bug distinto, sin relación con el sub-bug A. `player_menu_viewmodel._refresh_resources()` leía el `current` desde `CharacterState.get_resource()` — un accesor fósil, congelado en el valor de `definition.starting_resources` desde la creación del personaje, que nadie vuelve a escribir nunca (mismo patrón que `skill_values` vs. `SkillSystem._entity_skills` de Spike 3/Grupo B). El `max` mostrado (75 en el ejemplo original) ya era correcto, porque venía de `AttributeResolver.resolve()` directo, no de `max_effective` — el desync estaba solo en el `current` (20 mostrado vs. 54 real).

### Arreglo aplicado
- **`resource_system.gd`** — `register_entity()` sincroniza `max_effective` con `AttributeResolver.resolve_resource_max()` para CUALQUIER entidad, no solo player. Guard defensivo: si `Characters` todavía no tiene la entidad registrada, no sincroniza y avisa por warning en vez de sincronizar a un valor inventado.
- **`combat_production_scene.gd`** — orden de registro corregido en `_on_reinforcement_spawned()` (Characters antes que Resources, como en los otros 3 call sites), requisito del punto anterior.
- **`exploration_controller.gd` y `narrative_scene_viewmodel.gd`** — el `set_resource(enemy_id, "health", 50.0)` fijo sustituido por `restore_resource(enemy_id, "health")`, que ahora llena al máximo real ya sincronizado.
- **`player_menu_viewmodel.gd`** — `_refresh_resources()` lee `Resources.get_resource_amount()` (el estado vivo) en vez del fósil de `CharacterState`.

### Validado
Partida real: HP/EN de `player_menu` coincide con el HUD de combate durante todo el combate; ningún enemigo mostró ya el `50/50` fijo; los HP de enemigos bajan a 0 sin problema. Test de regresión (`test/test_spike6_investigacion.gd`, sección A) confirma que `max_effective` de una entidad de prueba registrada como enemigo coincide con el máximo derivado real tras el parche.

---

## Punto 2 — `GameLoopSystem._transition_to_phase()`: `Invalid transition: ROUND_END → TURN_END`

### Causa raíz confirmada
`_transition_to_phase()` no devolvía si la transición había tenido éxito, y ninguno de sus llamadores (`_end_turn()`, `_end_round()`, `_start_new_round()`) comprobaba el resultado antes de seguir — emitían señales, imprimían el log y, crucialmente, `_start_new_round()` incrementaba `round_number` de forma incondicional, pasase lo que pasase con la transición de fase. Si `_end_turn()` se disparaba dos veces para lo que debía ser un solo cierre de ronda (la segunda vez con `current_phase` todavía en `ROUND_END`, porque la primera seguía esperando su timer de 0.3s), el error de transición se registraba pero el flujo continuaba igual — de ahí el log duplicado ("Round N ended" dos veces) y el salto de número de ronda a la vez, con un único mecanismo explicando ambos síntomas.

Confirmado que afecta al contador real (`round_number`, el que usan los refuerzos temporizados) — no es cosmético.

No se pudo confirmar con total certeza el disparador exacto de la doble invocación. Candidato identificado: `_on_combat_action_completed()` solo comprobaba la fase actual, nunca `_result["actor"]` — una señal tardía de un actor equivocado (companion o jugador) llegando mientras la fase ya está en `ENEMY_ACTION_RESOLVE` se habría procesado como si fuera el enemigo en turno. Se encontró además que el payload de la resolución normal de skill en `combat_system.gd` (la rama usada en la inmensa mayoría de acciones de combate) no llevaba `"actor"` en absoluto — solo las ramas de excepción (staggered/disarmed/dodge) lo llevaban. Y que el guard de reentrancia `_is_processing` existe y se consulta en dos sitios, pero nunca se asigna a `true` en ningún punto del fichero — red de seguridad muerta.

### Arreglo aplicado
- **`game_loop_system.gd`** — `_transition_to_phase()` devuelve `bool`; `_end_turn()`/`_end_round()` abortan sin reemitir señales ni seguir la cadena si la transición es rechazada. `_on_combat_action_completed()` ahora compara `result["actor"]` contra el actor que realmente tiene el turno (`_current_acting_entity`, nueva variable, fijada en `_process_next_companion()`/`_process_next_enemy()`), descartando con warning cualquier señal de un actor que no corresponde.
- **`combat_system.gd`** — añadido `"actor": entity_id` al payload de la resolución normal de skill (requisito del punto anterior).

### Validado
Partida real de varios combates completos: ningún `Invalid transition` ni warning de actor-mismatch, rondas incrementando sin saltos. Test de regresión (`test/test_spike6_investigacion.gd`, sección B) reproduce exactamente la secuencia del log real (`ENEMY_ACTION_RESOLVE → TURN_END → ROUND_END →` segundo intento `TURN_END`) y confirma que la segunda transición se rechaza sin mover `current_phase`.

**Incidente aislado durante la validación, no reproducible:** un combate se quedó esperando input del jugador tras varias rondas sin llegar a procesar la tecla de ataque. Repetido varias veces después sin volver a aparecer — no se investiga más por ahora (mismo criterio ya aplicado al bug de F9 de Grupo 1: no perseguir algo que no se puede reproducir). Si vuelve a aparecer, revisar `player_combat_controller.gd` (no incluido en este spike) y su guard de `is_input_blocked()`.

---

## Punto 3 — UI/UX ligado a este spike

Sin tocar, como estaba previsto. El `??` de `companion_mira` y el HP/EN visible en combate no dependían de la causa raíz de este spike — usan `Resources.resource_changed`/`EventBus.resource_changed` directamente (Grupo 5), no los accesores que arreglamos aquí. Ningún punto de Spike 8 queda resuelto como efecto colateral.

## Fuera de alcance (confirmado, sin cambios)
- F9 quickload (Spike 7)
- Puntos de UI puramente visuales de Spike 8
- Los otros 4 hallazgos de motor de Grupo 5 no tocados en este spike: typo `combat_scape`/`combat_escape`, puente `resource_changed`→`EventBus.resource_changed`, fuga de memoria ya mitigada, `combat_resolver.gd` código muerto sospechoso — siguen pendientes de decisión
