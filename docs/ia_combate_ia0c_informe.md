# Athelia — IA-0c: informe de cierre

**Fecha:** 2026-11-15 · **Spec:** `docs/ia_combate_ia0c_spec.md` · **Estado:** cerrada. Prueba automática 67 OK / 0 FALLOS, validada en partida real (Output en huida de uno, de varios y de todos los enemigos; Depurador → Errores sin avisos). Decisiones 1-A, 2-A, 3-A, 4-A y 5-A adoptadas.

## 1. Qué cambia

- **Azar inyectable.** `SkillRoller` tiene un único `_roll_d100()` y un `_rng` estático (`null` = RNG global) con `set_seed()`, `set_rng()` y `reset_rng()`. `get_grade_probabilities()` enumera los 100 resultados con la misma `_determine_result()` que la tirada real, y `get_success_chance()` se apoya en ella: una sola fórmula para tirar y para estimar.
- **Una sola fórmula de daño.** `Combat` se parte en funciones puras (`_get_roll_params`, `_effect_damage`, `_skill_raw_damage`, `_mitigate_damage`, `_get_hit_targets`); el camino real y `estimate_damage()` las llaman las dos. `_expected_on_target()` calcula el valor esperado grado a grado, porque la armadura (`max(1, daño − armadura)`) no es lineal.
- **Skills `SELF` genéricas.** Toda skill `SELF` se resuelve sin tirada de ataque con efectos `BUFF`, `RESTORE` (de un recurso, sin pasar del máximo) y `FLEE`. Solo cuando la acción en curso es esa skill (`_pending_skill_context.skill_id == skill_id`); la rama de `dodge` queda intacta. Un único constructor de buffs, `_build_buff()`, que ahora copia `resource_id`.
- **`FLEE` de enemigos.** `Combat` marca `FLED` y emite `EventBus.enemy_fled(enemy_id)`; `GameLoop` anota la retirada y la ejecuta al cerrar la acción en curso (`_pending_fled`, `_retire_fled()`), corrigiendo `current_turn_index` para no saltarse al siguiente enemigo. `EnemyWorldLink` escucha `enemy_fled` además de `enemy_group_fled`.
- **`INVALID_TARGET`.** Se comprueba antes de coste y cooldown. Es válido el objetivo vivo, no `FLED`, con entidad y salud registradas y, en combate, participante o aliado. El jugador solo recibe `combat_action_failed`; un actor no jugador recibe además `combat_action_completed {skipped: true, actor, request_id}` (como `DISARMED`), y `GameLoop` ignora el fallo de no jugadores.
- **API de solo lectura para la IA:** `get_candidates(actor_id)`, `get_visible_conditions()`, `estimate_threat()`, `get_hp_ratio()`/`get_hp_state()`, `estimate_damage()`, `is_fled()`.
- **Datos:** `data/ai/ai_scales.json` (lector estático `AIScales`), `CombatTags` (constantes), y tres skills de enemigo: `skill.enemy.defend`, `skill.enemy.recover`, `skill.enemy.flee`.

## 2. Desviaciones respecto a la spec

1. **Tercera skill de datos (`skill.enemy.flee`)**, además de `defend` y `recover` de la decisión 1-A: sin ella no había forma de validar `FLEE` por el camino real.
2. **`Resources.has_resource(entity_id, resource_id)`** (no estaba en la spec): `get_resource_state` da error si el recurso no existe, y la comprobación de costes de `get_candidates()` debe ser silenciosa.
3. **Parche en `PlayerCombatController`** (descubierto en la validación; ver §4): la lista de objetivos filtra con `Combat.is_fled()` y el controlador escucha `enemy_fled`.
4. **`INVALID_TARGET` de no jugadores** emite `combat_action_completed` con `skipped` en vez de dejar el turno sin cerrar.
5. **`estimate_threat(_observer_side, target_id)`** usa `AttributeResolver "base_damage"` como proxy del arma equipada, y `threat_hint` si existe (todavía no está en `CharacterDefinition`, IA-0d).
6. **Efecto sin conversión:** una skill `SELF` cuyos efectos no tengan entrada en `effect_value` no es candidata, y se avisa una sola vez por combate (`_note_once`).
7. **Prueba de integración con `GameLoop` desactivada** (`RUN_GAMELOOP_TEST = false` en `test/ia0c_test.gd`): el `SceneOrchestrator` carga la escena de combate y falsea el resultado. La retirada aplazada se validó en partida.
8. **Comparación de la Tanda 2 con semilla, no viable:** el estado inicial difiere entre ejecuciones (personaje creado en cada una). Se sustituye por la prueba automática y por las comprobaciones de §3. El refactor de la Tanda 1 sí se comparó (`Compare-Object` vacío).

## 3. Validación

**Prueba automática** (`test/ia0c_test.tscn`, 67 OK · 0 FALLOS): atacante `companion_mira`, objetivo `telmori_wolf_base`.

- [x] A. `SkillRoller`: misma semilla ⇒ mismas tiradas; las probabilidades por grado suman 1.
- [x] B. Estimación frente a la media de 40 000 ejecuciones reales (por `EventBus.execute_combat_action`, RNG sembrado): error 0,17–0,59 % en los seis casos (ligero, pesado y barrido, con y sin `damage_reduction` del 30 %). Umbral exigido: < 2 %.
- [x] C. Candidatas, `hp_state`, condiciones visibles y amenaza.
- [x] D. `SELF`: defender reduce el daño recibido de 19,135 a 9,567 sin tirada de ataque; recuperar sube la estamina de 5 a 25 (máximo 35) y no pasa del máximo; `FLEE` y `INVALID_TARGET` se comportan como se diseñó.
- [ ] E. Integración con `GameLoop`: desactivada (ver §2.7).

**En partida real** (combate de 6 enemigos con Mira, con dos cambios temporales retirados al acabar: registro de `skill.enemy.flee` y una decisión forzada de huida en `EnemyAI`):

- [x] Un enemigo huye en la ronda 2: `🧪 SELF skill` → `🏃 … huye del combate (FLED)` → `Enemy action completed` → `🏃 … retirado del combate (huida)`, y sigue el siguiente (`[1/6]` → `[1/5]`) sin saltarse a nadie. Dos huidas en la misma ronda (`[3/5]` → `[3/4]`) correctas.
- [x] Todos los enemigos huyen: contador `[1/6]` … `[1/1]` y, tras el último, `All enemies defeated!` y `Combat ended: victory` con «0 enemies defeated» (los huidos no sueltan botín).
- [x] Con huidas y muertes mezcladas (6 enemigos: 4 muertos y 2 huidos), el combate termina en victoria y el botín cuenta 4.
- [x] El objetivo del jugador se reasigna al huir el actual: `Target fled: …`, y la ronda siguiente pide la skill sobre el siguiente enemigo sin `INVALID_TARGET`.
- [x] Las cifras siguen la fórmula única en partida (17,6 × 1,2 = 21,1; 19,8 × 1,2 = 23,8; `SPECIAL` multiplica otra vez por 1,2) y el buff `staggered` se aplica y consume como antes (`1 turns, expires_on: use`).
- [x] Sin temporales ni `seed(12345)` en el código (`Select-String 'TEMPORAL IA-0c|seed\(12345\)'` vacío) y las seis filas de `skills.csv` presentes.
- [x] Depurador → Errores sin avisos nuevos, durante y después de los combates.

## 4. Hallazgos durante la validación

1. **El controlador del jugador no se enteraba de la huida.** `PlayerCombatController` conservaba el objetivo automático (`telmori_wolf_1`) tras huir, y cada pulsación daba `INVALID_TARGET` y devolvía la fase a `PLAYER_ACTION_SELECT` sin salida (el turno no se colgaba, pero el jugador repetía la misma petición). La reasignación por `character_died` ya existía; faltaba la de `enemy_fled`. Como la retirada de `GameLoop` ocurre después de la señal, releer `get_active_enemies()` en el manejador no bastaba: la lista se filtra con `Combat.is_fled()`.
2. **Cualquier skill `SELF` distinta de `dodge` colgaba el turno** antes de IA-0c (no había rama que cerrara la acción). Ahora lo resuelve la rama genérica.
3. **Evasión y `DefenseModule` solo funcionan para `PLAYER_ID`:** el `dodge` de Mira solo da `guaranteed_hit`, no evasión. Para IA-3 y para la conversión en `effect_value`.
4. **`defense_module_bak.gd` declara `class_name DefenseModule`:** borrarlo (tarea 7 de IA-0d) rompe la compilación mientras el módulo real dependa de él; comprobar antes de limpiar.
5. **`AREA`/`MULTI_ENEMY` golpean siempre al bando enemigo** sea quien sea el atacante (latente para IA-0d, cuando un enemigo use una skill de área).
6. **`dodge.tres` no declara `expires_on`**: su rama propia y el `_build_buff()` genérico siguen siendo dos caminos. Unificar exige añadirlo al `.tres` (IA-0d).
7. **Registro de enemigos incompleto:** los refuerzos se registran solo con `["health"]` y los demás sin estamina real para gastar, así que `defend`/`recover` no son candidatas hasta que IA-0d registre todos los recursos.
8. **La unidad de `duration` queda confirmada:** en un `BUFF` son turnos del dueño (0 = «uso»); en un `DAMAGE`, segundos de animación. La etiqueta «s» del árbol de habilidades debería decir «turnos» (Spike 21).

## 5. Pendientes que deja

- **IA-0d:** constitución de los enemigos (números declarados o los jugados) antes de nada; registrar todos los recursos (hallazgo 7); unificar `dodge` (6); `defense_module_bak` (4); `threat_hint` y `behavior_profile_id` en la definición; coste de `basic_attack` frente a la estamina del enemigo.
- **IA-3:** evasión y defensa de Mira (hallazgo 3).
- **IA-4:** la base de moral de grupo cuenta al enemigo huido; el token `FLED` de la arena no se retira porque el ViewModel de la arena no escucha `enemy_fled`; el log de la arena no tiene líneas para defender, recuperar ni huir.
- **IA-5:** `threat_thresholds`, fracción de `costly`, valores de `effect_value` y `self_risk_factor` son provisionales; `estimate_threat` usa `base_damage` como proxy.
- **Spike 21:** etiqueta de duración de buffs en turnos (hallazgo 8).
- **Heredados sin cambio:** quién emite `EventBus.skill_used`; `Skills.can_use` no comprueba `is_unlocked`.
