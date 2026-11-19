# Athelia — IA-1a: contratos de la IA de combate (informe de cierre)

**Fecha de cierre:** 2026-11-19 · **Spec:** `docs/ia_combate_ia1_spec.md` (§1, §3 y §4, IA-1a) · **Base:** `docs/ia_combate_spec_v1_7_1.md` (§4, §5.3, §6, §7)
**Estado:** cerrada. `ia1a_test` **159 OK · 0 fallos**; Depurador sin avisos en la prueba; partida de seis enemigos con Mira jugada igual que en IA-0d.

IA-1a deja los **contratos puros** sobre los que se apoyarán la telemetría (1b), la decisión de objetivo (1c) y el evaluador (IA-2): perfiles de comportamiento en datos, estado de IA por combatiente, contexto de IA por combate con su RNG, y el snapshot congelado en profundidad. **No cambia el combate jugable**: nada de esto decide todavía.

## 1. Qué se entregó

| Pieza | Fichero | Notas |
|---|---|---|
| `BehaviorProfile` | `core/ai/behavior_profile.gd` | `Resource` con `class_name`; `validate() -> Array[String]`; `make_safe_default()`; `duplicate_profile()` (`duplicate(true)`); `summary()`. |
| `BehaviorProfileRegistry` | `core/ai/behavior_profile_registry.gd` | Estático con caché. Carga recursiva de `data/ai/profiles/`, rechaza perfiles inválidos, id distinto del nombre del fichero e ids duplicados. `get_profile()` entrega un duplicado profundo; id vacío o inexistente → perfil seguro con aviso una sola vez por id. |
| `CombatAIState` | `core/ai/combat_ai_state.gd` | Perfil duplicado por combatiente; `requested_profile_id`, `used_fallback`; campos reservados (`active_order`, `processed_morale_events`, `morale_state`). |
| `CombatAIContext` | `core/ai/combat_ai_context.gd` | **Decisión nueva (8):** reúne el RNG de IA del combate y un `CombatAIState` por combatiente. `register_entity()` idempotente, `release()`. |
| `CombatSnapshot` | `core/ai/combat_snapshot.gd` | `build(actor_id) -> Dictionary` congelado en profundidad; `deep_freeze`, `is_deep_frozen`, `is_plain_data`. |
| Perfiles base | `data/ai/profiles/{beast,bandit,soldier,coward}.tres` | Valores provisionales (IA-5), `weights` vacío. |
| Datos de personaje | `behavior_profile_id` y `threat_hint` en 6 `.tres` | Ver 3.3. |
| API pública de `Combat` | `combat_tags.gd` (`SIDE_ALLY`/`SIDE_ENEMY`) y `combat_system.gd` (`get_side()`, `get_combatant_ids()`) | Dos envoltorios de solo lectura; ver 2. |
| Escena de combate | `scenes/combat/combat_production_scene.gd` (completo) | Crea el contexto en `_ready()`, registra un estado por IA (roster y refuerzos), lo libera en `combat_ended`. |
| Prueba | `test/ia1a_test.gd` + `.tscn` | Bloques A–H. |

## 2. Fase 0: lo que contradecía la spec

| Spec | Código real | Resolución |
|---|---|---|
| §5.2 «sano/herido/gravemente herido», amenaza «baja/media/alta» | `healthy/hurt/badly_hurt`, `low/medium/high` (`CombatTags`) | Manda el código. |
| La candidata no menciona `costs` | Además de lo descrito lleva `costs`, `tags: Array[StringName]`, `target_ids: Array[String]` (tipados) | El snapshot copia las candidatas con `duplicate(true)`. |
| `last_attacker` como dato de IA | `Combat.get_last_attacker(id) -> String`, `""` si nadie ha dañado; solo se registra cuando el daño se aplica | La validez del atacante la decide quien consulta (1c). |
| Snapshot con «API pública de `Combat`» | `_is_ally()` y `_get_opponents()` son privadas: no había forma pública de saber el bando ni de listar combatientes | `Combat.get_side()` y `Combat.get_combatant_ids()`. |
| `estimate_threat(observer_side, …)` | El primer parámetro no se usa hoy | El snapshot pasa el bando del actor; sin efecto hasta que se use. |
| Snapshot al recibir `combat_started` | `combat_started` solo se emite en `game_loop_system.gd:315` y la escena de combate ya existe antes | El contexto se crea en `CombatProductionScene._ready()` y en cada refuerzo, donde ya se spawnea cada IA. |
| `make_read_only()` congela | **Superficial** (verificado en 4.7.2) | `deep_freeze` recursivo (4 niveles, arrays tipados incluidos). |
| §15 lista «resultado» entre los contratos de IA-1 | §10 y la fila IA-4 lo sitúan en IA-4 | Decisión 3-A: el contrato de resultados queda en IA-4. La tabla de §15 se corrige (parche entregado). |

Comportamientos de Godot 4.7.2 comprobados con la sonda de Fase 0 (21 PASS · 0 FAIL, ya retirada): mutar un contenedor congelado da un error rojo de runtime que aborta la función y **no se puede atrapar** (por eso las pruebas comprueban `is_read_only()` recursivo y nunca intentan mutar); `duplicate()` de un congelado devuelve una copia mutable; `Resource.duplicate()` **comparte** `Dictionary`/`Array` con el original y `duplicate(true)` los separa; las claves `String` y `StringName` son intercambiables; el estado de 64 bits del `RandomNumberGenerator` no sobrevive a JSON como número.

## 3. Decisiones

### 3.1 Las de la spec
1-A (tres subfases), 2-A (perfiles `.tres` en `data/ai/profiles/`), 3-A (resultados en IA-4), 4-A (en 1c solo objetivo), 5-A (asignación de perfiles y `threat_hint`), 6-A (Mira recibe estado y snapshot pero elige objetivo como hoy).

### 3.2 Las nuevas
- **7 — Mira usa `soldier`, provisional hasta IA-3.** El jugador no tiene `CombatAIState` (no es de IA). `soldier` lleva `obedience = 1.0` para que Mira lo herede.
- **8 — `CombatAIContext` por combate.** Un `CombatAIState` vive por combatiente, pero el RNG de IA es por combate: el contexto los reúne, lo crea la escena de combate y lo suelta en `combat_ended`.

### 3.3 Asignación (provisional, IA-5)
| Definición | Perfil | `threat_hint` |
|---|---|---|
| `enemy_base` | bandit | low |
| `telmori_warrior_base` | soldier | high |
| `telmori_warrior_weak` | bandit | low |
| `telmori_wolf_base` | beast | medium |
| `telmori_wolf_weak` | beast | low |
| `companion_mira` | soldier | (sin valor) |

`coward` queda creado y sin asignar hasta que haya contenido. La spec decía a la vez «lobos `medium`» y `wolf_weak` `low`; se tomó la lista concreta.

### 3.4 Diseño
- **Perfil seguro construido en código** (sin preferencia de objetivo, sin huida, sin moral): nunca falla y avisa una vez por id.
- **El id del perfil debe coincidir con el nombre del fichero**; así no hay duplicados silenciosos por copia de ficheros.
- **Las listas cerradas** (preferencias de objetivo, consideraciones, claves de moral) viven en el código: son contrato, no dato ajustable (`ai_scales.json` no las contiene).
- **Umbrales de moral** (`0 <= broken < shaken_enter < shaken_exit <= base`) y rangos validados en `validate()`.
- **Snapshot solo con tipos simples** (bool, int, float, String, StringName, Dictionary, Array): los `Resource` y los `Packed*Array` no se pueden congelar.
- **Estado del RNG como texto** (`rng_state_string()`, `rng_seed_string()`, `restore_rng_state()`): en 1b el log lo escribirá así.

## 4. Valores de los perfiles base (provisionales)

| Perfil | Objetivo | Bonus | Flex. | Supervivencia (umbral/bonus) | Huye | Moral (shaken_enter/exit/broken) |
|---|---|---|---|---|---|---|
| beast | random | 4,0 | 15,0 | 0,20 / 4,0 | no | sin moral |
| bandit | weakest | 6,0 | 10,0 | 0,35 / 8,0 | sí | 70 / 75 / 35 |
| soldier | most_dangerous | 8,0 | 5,0 | 0,25 / 6,0 | sí | 55 / 65 / 25 |
| coward | weakest | 6,0 | 10,0 | 0,50 / 12,0 | sí | 85 / 90 / 50 |

En `soldier` el `target_bonus` supera a la flexibilidad (la preferencia decide sola); en `beast` ocurre lo contrario. Todos los bloques de moral usan base 100 y `big_hit_pct` 25.

## 5. Validación

**Prueba automática (`test/ia1a_test.tscn`):** 159 OK · 0 fallos. Bloques: A perfiles base y duplicado independiente; B `validate()` (17 casos de rechazo con su mensaje); C registry (perfil seguro, rechazos, duplicados, carga recursiva de un directorio temporal con dos rechazos); D estado y contexto; E datos de los seis `.tres` y `resolve_profile_id`; F RNG (misma semilla, estado como texto, reanudación, `pick_one` sin consumo con una opción); G `get_side`/`get_combatant_ids` y snapshot (campos, observabilidad, congelado en profundidad, determinismo, actor sin registrar); H ningún acceso a miembros privados de otros sistemas en `core/ai/`.

**Parches y datos:** `SIDE_ALLY`/`SIDE_ENEMY` (2 líneas), `get_side`/`get_combatant_ids` (2 líneas), `_ai_context`/`_register_ai_state` presentes en la escena y los cuatro `.tres` de perfil en `data/ai/profiles/`. `ia1a_aplicar_datos.ps1` imprimió las asignaciones esperadas.

**Partida (combate contra 3 guerreros y 3 lobos con Mira, dos primeras rondas):** el Output muestra `contexto de IA creado (seed=7256945836632278017)`, una línea `estado de IA` por combatiente con el perfil correcto (lobos `beast`, guerreros `soldier`, Mira `soldier`) y `hp_state=healthy`, y los cuatro perfiles cargados sin rechazos. El combate se desarrolla igual que en IA-0d: los enemigos atacan solo al jugador con `basic_attack`, sorpresa, esquiva y armadura sin cambios, y Mira y el jugador resuelven sus turnos como antes.

**Sin ver todavía:** la línea `contexto de IA liberado (N estados)` al terminar el combate (el log aportado se corta en la ronda 3). El código está en `_on_combat_ended()` y la prueba D cubre `release()`; queda anotado como pendiente de comprobar en el próximo combate completo.

## 6. Pendientes que deja

- `_get_opponents()` y `Combat.get_combatant_ids()` duplican la lógica de bandos: unificarlas.
- `wolf_test.tres` (mapa `poi_test_map`) y `companion_base.tres` no tienen perfil: usarlos en combate da un aviso en el Depurador (perfil seguro) hasta asignarles uno.
- Valores de los cuatro perfiles y `threat_hint` provisionales (IA-5); `coward` sin asignar; Mira con `soldier` hasta IA-3.
- `estimate_threat()` ignora el bando del observador (aviso para IA-2).
- La línea de log `estado de IA` repite el id del perfil (`perfil soldier, soldier (…)`): cosmético, no se toca.
- ~~Corregir la tabla de §15 de `ia_combate_spec_v1_7_1.md`~~ — hecho (la tabla ya reparte IA-1 en 1a/1b/1c y deja el resultado en IA-4).
- ~~Limpieza de cierre: borrar `test/ia1a_fase0_sonda.gd` y los `fase0_ia1a_*.txt`~~ — hecho (ficheros borrados).

## 7. Lecciones nuevas

Recogidas en `athelia_lecciones_tecnicas.md`: congelado superficial y errores no atrapables al mutar; `duplicate()` frente a `duplicate(true)` en `Resource`; estado del RNG como texto; sonda `EditorScript` para contrastar hipótesis de motor; exponer una API pública mínima en lugar de leer miembros privados; comparar arrays tipados con un literal sin tipo da falso.

## 8. Lo que hereda IA-1b

- Semilla y estado del RNG de IA como **texto** (`CombatAIContext.rng_seed_string()`, `rng_state_string()`).
- Un `CombatAIState` por combatiente con `profile.id` y `used_fallback` (candidato natural al evento `error`).
- Composición de bandos con `Combat.get_combatant_ids()` y `Combat.get_side()`.
- `CombatProductionScene` ya crea y libera el contexto en los puntos donde 1b debe crear y cerrar el logger.
