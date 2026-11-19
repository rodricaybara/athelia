# Athelia — IA-1: contratos de la IA de combate (especificación)

**Fecha:** 2026-11-16 · **Base:** `docs/ia_combate_spec_v1_7_1.md` (§4, §5.3, §6, §7, §11, §15 y §16), `ia_combate_ia0_plan.md` e informes `docs/ia_combate_ia0a_informe.md` … `ia0d`
**Estado:** IA-1a **cerrada** (2026-11-19, `docs/ia_combate_ia1a_informe.md`); las 6 decisiones están cerradas (más dos nuevas, sección 3); 1b y 1c pendientes (spec de 1b: `docs/ia_combate_ia1b_spec.md`).

IA-1 construye los **contratos** sobre los que se apoyará el evaluador (IA-2): perfiles de comportamiento en datos, estado de IA por combatiente, snapshot congelado, gestión de los fallos de acción de la IA y una telemetría mínima. Añade una **primera decisión de IA muy acotada** (a quién ataca cada enemigo, según su perfil) para poder validarlo en partida, pero **no puntúa acciones**: el evaluador (consideraciones, pesos, selección ponderada) es IA-2. Los enemigos siguen pidiendo `basic_attack`.

## 1. Se divide en tres subfases (IA-1a, IA-1b, IA-1c)

Sí: IA-1 reúne cuatro piezas que se pueden entregar y validar por separado, y juntas serían la fase más grande hasta ahora (datos nuevos, un modelo de datos nuevo, un fichero en disco con git y hash, y el cambio de comportamiento de `EnemyAI`/`CompanionAI`). Orden **a → b → c**:

| Subfase | Contenido | Cambia el combate jugable | Validación |
|---|---|---|---|
| **IA-1a** — Datos y contratos puros | `BehaviorProfile` + validación, `BehaviorProfileRegistry`, los 4 perfiles base, `behavior_profile_id` y `threat_hint` asignados a los `.tres`, `CombatAIState`, `CombatSnapshot` (constructor + congelado en profundidad), RNG de IA | **No** | Prueba automática `ia1a_test` (patrón del proyecto) y Depurador sin avisos; un `print` al registrar el combate lista perfil y estado por combatiente |
| **IA-1b** — Telemetría mínima | `CombatTelemetry` (`RefCounted`): `.jsonl` incremental con `combat_start`, `combat_end`, `error`; `event_seq` sin huecos; bloque `version` (`config_hash`, git con `null` si falla); creado por `CombatProductionScene` antes de `combat_started`; rotación de ficheros; «Abrir carpeta de logs» | **No** | Un combate real deja un `.jsonl` válido y completo; sin telemetría el combate no cambia; fallo de escritura no interrumpe |
| **IA-1c** — Decisión de objetivo y fallos | `EnemyAI` construye el snapshot, elige objetivo por `target_preference` del perfil y emite el evento `decision`; gestión de `STALE`/`ERROR` en `EnemyAI` y `CompanionAI` (reintentos, acción de reserva, `skipped`); `GameLoop` sin cambios de contrato | **Sí** (a quién ataca cada enemigo) | El log muestra la decisión y el perfil; enemigos de perfiles distintos reparten ataques de forma distinta; un fallo forzado se recupera sin colgar el turno |

Cada subfase se cierra con su informe (`docs/ia_combate_ia1a_informe.md`, …) y la documentación al día; **IA-1 se da por cerrada al cerrar IA-1c**. La spec detallada de 1b y 1c se escribe al cerrar la anterior, con lo que haya enseñado (como se hizo con IA-0).

### Una inconsistencia de la spec v1.7.1 a resolver (decisión 3)
§15 lista «resultado» entre los contratos de IA-1, pero §10 y la fila IA-4 colocan `combat_result_ready`/`CombatantStatus` en IA-4 (junto a la moral y la huida, que son lo que lo hace necesario). Recomendación: **el contrato de resultados queda en IA-4** y se corrige la tabla de §15.

## 2. Punto de partida (hipótesis a verificar en la Fase 0)

| Tema | Hipótesis |
|---|---|
| `core/ai/` | Solo existe `ai_scales.gd` (`AIScales`) y `data/ai/ai_scales.json`; no hay `BehaviorProfile`, registry ni estado de IA. `CombatTags` está en `core/combat/combat_tags.gd`. |
| `EnemyAI` | `Node` sin `class_name` (se carga por `preload`), instanciado por `combat_production_scene.gd`; hoy ataca siempre al jugador con `basic_attack`, con guarda de coste de IA-0b. No gestiona `combat_action_failed`. |
| `CompanionAI` | Elige objetivo con los selectores heredados de `Party.CompanionStrategy` y `list_known_skills()`; tampoco gestiona fallos. |
| Fallos | `GameLoop` ignora `INVALID_TARGET` de un no jugador y el resto de fallos de enemigos/companions no tiene gestor: hoy un fallo cuelga el turno si la guarda de coste no lo evita. |
| API de `Combat` | `get_candidates()`, `get_hp_state()`, `get_visible_conditions()`, `estimate_threat()`, `is_fled()`, `next_request_id()` y `get_last_attacker(id)` existen. Hay que comprobar la **forma exacta** de la candidata y de `get_last_attacker` frente a lo que dice la spec (§6, §7). |
| Perfiles | `CharacterDefinition.behavior_profile_id` y `threat_hint` existen y **ningún `.tres` les da valor**; `validate()` solo avisa de un `threat_hint` no válido. |
| Congelado | `Dictionary.make_read_only()` / `Array.make_read_only()` son superficiales: la spec exige congelado **en profundidad** y verificarlo en 4.7.2 con datos anidados. |
| RNG | `SkillRoller` tiene RNG inyectable (IA-0c); la IA necesita el suyo, independiente, con estado guardable en el log. |
| Telemetría | No existe `CombatTelemetry` ni `user://logs/combat/`. `CombatProductionScene` se libera en `combat_ended` (el `combat_end` debe escribirse antes del `queue_free()`). `git` por `OS.execute` hay que comprobarlo en el entorno de Fernando. |
| Ficheros `.tres` | Un `.tres` solo guarda lo distinto del valor por defecto: un campo de `BehaviorProfile` con su valor por defecto no aparece en el fichero; hay que verificar los valores cargados por el log, no por el inspector. |

## 3. Decisiones (cerradas tras la Fase 0; recomendación entre paréntesis)

| # | Pregunta | Opciones | Recomendación |
|---|---|---|---|
| 1 | Subdivisión de IA-1 | **A)** tres subfases 1a/1b/1c (sección 1). **B)** una sola fase | **A** |
| 2 | Formato de los perfiles | **A)** `.tres` con `validate()` (como dice la spec §4), en `data/ai/profiles/`. **B)** JSON con registry y `from_dict()` (como `ai_scales.json`) | **A**: es lo que fija la spec y `validate()` + registry bastan; el `print` de carga cubre el riesgo de «campo no guardado» |
| 3 | Contrato de resultados (`CombatantStatus`, `combat_result_ready`) | **A)** se queda en IA-4 y se corrige la tabla de §15. **B)** se hace en IA-1 | **A** |
| 4 | Alcance de la «primera decisión de IA» en 1c | **A)** solo **objetivo** (jugador o Mira) según `target_preference`; la skill sigue siendo `basic_attack`. **B)** además elegir entre las candidatas con una puntuación mínima | **A**: la puntuación es IA-2; con B se adelanta el evaluador sin sus pruebas |
| 5 | Asignación de perfiles y `threat_hint` | **A)** lobos → bestia; `warrior_base` → soldado; `warrior_weak` y `enemy_base` → bandido; cobarde creado pero sin uso hasta que haya contenido. `threat_hint`: lobos `medium`, `warrior_base` `high`, `warrior_weak` `low`, `wolf_weak` `low`, `enemy_base` `low`. **B)** otra asignación (la propones tú) | **A** como punto de partida; son valores provisionales (IA-5) |
| 6 | Alcance de `CompanionAI` en IA-1 | **A)** Mira recibe `CombatAIState`, snapshot y la gestión de fallos, pero **sigue eligiendo objetivo como hoy** (sus órdenes son IA-3). **B)** también migra su selector de objetivo | **A** |

**Cerradas (2026-11-19):** 1-A, 2-A, 3-A, 4-A, 5-A y 6-A, todas con la recomendación. Dos nuevas surgidas de la Fase 0 de 1a: **7** — Mira usa el perfil `soldier` (provisional hasta IA-3) y el jugador no tiene `CombatAIState`; **8** — un `CombatAIContext` por combate reúne el RNG de IA y los estados por combatiente (lo crea y libera `CombatProductionScene`). La Fase 0 añadió además dos envoltorios públicos a `Combat` (`get_side()`, `get_combatant_ids()`).

## 4. Tareas (orden de entrega dentro de cada subfase)

### IA-1a — Datos y contratos puros
| # | Tarea | Ficheros |
|---|---|---|
| 1 | `BehaviorProfile` (`Resource`, `class_name`) con los campos de la spec §4 y `validate() -> Array[String]` (errores claros: `target_preference` fuera del conjunto cerrado, `decision_flexibility` ≥ 0, umbrales de moral `broken < shaken_enter < shaken_exit`, pesos con claves de consideración conocidas…) | `core/ai/behavior_profile.gd` |
| 2 | `BehaviorProfileRegistry` (clase estática con caché): carga `data/ai/profiles/*.tres` **con recursión**, valida, `get_profile(id)` devuelve un duplicado; id inexistente o inválido → perfil seguro por defecto con `push_warning` una vez | `core/ai/behavior_profile_registry.gd` |
| 3 | Los 4 perfiles base (bestia, bandido, soldado, cobarde) con `target_preference`, `target_bonus`, `decision_flexibility`, `survival_*`, `can_flee` y `morale` según §4.1; **`weights` vacío o mínimo** (los pesos son IA-2) | `data/ai/profiles/*.tres` |
| 4 | Dar valor a `behavior_profile_id` y `threat_hint` en los `.tres` de enemigo (decisión 5) y verificar por el log | `data/characters/**/*.tres` |
| 5 | `CombatAIState` (`RefCounted`): perfil duplicado, orden activa (reservada), conjunto de eventos de moral procesados (reservado), estado de moral (reservado); sin guardado | `core/ai/combat_ai_state.gd` |
| 6 | `CombatSnapshot`/constructor (clase estática o `RefCounted`) que usa **solo la API pública de `Combat`**: de sí mismo, exacto; de los demás, aparente (`hp_state`, `threat`, condiciones visibles); `self.last_attacker_id` y `player.last_attacker_id`; congelado **en profundidad** (función recursiva `deep_freeze`) | `core/ai/combat_snapshot.gd` |
| 7 | RNG de IA: un `RandomNumberGenerator` independiente por combate, con semilla fijable y `state` legible (para el log de 1c); desempates con él | `core/ai/` (donde viva el estado de IA) |
| 8 | `CombatProductionScene` crea un `CombatAIState` por combatiente al empezar y los libera al acabar; un `print` por combatiente (`id`, perfil, hp_state) | `combat_production_scene.gd` |
| 9 | Prueba automática `test/ia1a_test.tscn`: validación de perfiles (válido, perfil inexistente → seguro, umbrales inválidos → rechazo), carga recursiva, duplicado independiente, snapshot (campos, observabilidad, congelado en profundidad —intentar modificar un diccionario anidado falla—, no consulta privados), RNG reproducible | `test/` |

### IA-1b — Telemetría mínima
`CombatTelemetry` según §11: `.jsonl` incremental con `flush()`, `event_seq` sin huecos y calculado solo por el logger, `elapsed_ms`, `round`; `combat_start` (cabecera con `combat_id`, `version`, composición de bandos, semillas), `combat_end` (hasta IA-4 con el resultado mínimo disponible: `outcome`, `rounds`), `error`; valores no finitos a `null`; `config_hash` (SHA-256 con `HashingContext` sobre serialización canónica de `ai_scales`, perfiles y las skills que existan); git por `OS.execute` con `null` si falla y `git_dirty` solo sobre las rutas relevantes; rotación (últimos 50); «Abrir carpeta de logs»; un fallo de escritura desactiva la telemetría con un aviso sin interrumpir el combate. Creado por `CombatProductionScene` **antes** de `combat_started` y cerrado antes del `queue_free()` y por cualquier otra ruta de fin.

### IA-1c — Decisión de objetivo y gestión de fallos
- `EnemyAI`: construir el snapshot, calcular el objetivo preferido (§5.3: `weakest`, `most_dangerous`, `last_attacker`, `random`, `none`; empates con el RNG de IA; un combatiente a 0 PV no es válido; `last_attacker` inválido → sin preferido), pedir `basic_attack` contra él y emitir el evento `decision` (sin puntuaciones: perfil, snapshot resumido, objetivo elegido, estado del RNG antes/después).
- Gestión de fallos en `EnemyAI` y `CompanionAI`: ante `STALE` pedir candidatas nuevas y reintentar (**nuevo `request_id`, mismo `decision_seq`, máximo 2 reintentos**); ante `ERROR` o reintentos agotados, acción de reserva legal (candidata con etiqueta `defense`/`recover`) o `combat_action_completed {skipped: true, actor, request_id}`; cada intento deja un `action_result` en la telemetría. `GameLoop` sigue sin avanzar el turno de una IA ante un fallo.

## 5. Validación (resumen; el detalle se fija en la spec de cada subfase)
- **1a:** `ia1a_test` en 0 fallos; Depurador → Errores sin avisos; el `print` de combate muestra el perfil de cada enemigo; el combate se juega igual que en IA-0d.
- **1b:** un combate real deja `user://logs/combat/combat_<fecha>_<id>.jsonl` con `combat_start` y `combat_end`, `event_seq` 0..N sin huecos, JSON válido en cada línea (se comprueba con un script externo); con telemetría desactivada el combate no cambia.
- **1c:** en un combate con lobos (bestia) y guerreros (soldado) el Output y el `.jsonl` muestran el perfil y el objetivo de cada decisión y los objetivos se reparten de forma distinta; un fallo forzado (marcado `TEMPORAL IA-1c`) se recupera con reintento o reserva sin colgar el turno; un actor sin estamina pasa el turno con `actor` (el camino pendiente desde IA-0b, ya ejercitable).

## 6. Cambios de comportamiento a avisar
- 1a y 1b: ninguno jugable.
- 1c: **los enemigos dejan de atacar siempre al jugador** (también a Mira, según su perfil); con la armadura actual (`armor_rating` 12) el daño enemigo sigue siendo mínimo, así que el efecto es sobre todo visible en el log. Un fallo de acción pasa de colgar el turno a recuperarse.

## 7. Fuera de alcance
Evaluador, consideraciones, pesos y selección ponderada (IA-2); elección de skill por puntuación (IA-2); órdenes de Mira, selector de UI y `default_order` (IA-3); moral, `flee` asignada, `combat_result_ready` y eliminación de la moral de grupo (IA-4); ajuste de escalas, `threat_thresholds`, costes y `armor_rating` (IA-5); `stunning_blow` del jugador; conversión de `guaranteed_hit`/`evasion` en `effect_value` (IA-3).

## 8. Ficheros necesarios para la Fase 0 definitiva (IA-1a)
`enemy_ai.gd`, `companion_ai.gd`, `combat_production_scene.gd`, `ai_scales.gd`, `combat_tags.gd`, `combat_system.gd` (solo `get_candidates`, `get_last_attacker`, `get_hp_state`, `get_visible_conditions`, `estimate_threat`, `next_request_id`), `character_definition.gd`, los cinco `.tres` de enemigo y `companion_mira.tres`, `data/ai/ai_scales.json`, `event_bus.gd` (señales de combate) y `game_loop_system.gd` (solo el manejo de `combat_action_failed`/`completed`).

Búsquedas:

```powershell
Get-ChildItem -Recurse -Filter *.gd | Select-String -CaseSensitive -Pattern 'class_name BehaviorProfile|BehaviorProfile|CombatAIState|CombatSnapshot|CombatTelemetry'
Get-ChildItem -Recurse -Filter *.gd | Select-String -CaseSensitive -Pattern 'get_last_attacker|get_candidates|estimate_threat|get_hp_state|get_visible_conditions'
Get-ChildItem -Recurse -Filter *.gd | Select-String -CaseSensitive -Pattern 'combat_action_failed|combat_action_requested|next_request_id'
Get-ChildItem -Recurse -Filter *.gd | Select-String -CaseSensitive -Pattern 'make_read_only|RandomNumberGenerator|HashingContext|OS\.execute'
Get-ChildItem -Recurse -Filter *.gd | Select-String -CaseSensitive -Pattern 'behavior_profile_id|threat_hint|target_preference'
Get-ChildItem -Recurse -Filter *.tres | Select-String -CaseSensitive -Pattern 'behavior_profile_id|threat_hint'
Get-ChildItem -Recurse -Directory -Filter ai
```

## 9. Al cerrar cada subfase
Informe en `docs/ia_combate_ia1<x>_informe.md`; `estado_actual.md` (tabla y pendientes), `athelia_referencia_sistemas.md` (estado en su sitio), lecciones nuevas e historial (un párrafo por subfase), el plan y la spec v1.7.1 si cambian §4, §6, §11 o §15 (corregir en §15 el reparto de «resultado»). Anclas de parche de una sola línea.
