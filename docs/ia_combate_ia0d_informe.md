# Athelia — IA-0d: informe de cierre

**Fecha:** 2026-11-16 · **Spec:** `docs/ia_combate_ia0d_spec.md` · **Estado:** cerrada y validada. Prueba automática `test/ia0d_test.tscn` 85 OK / 0 FALLOS tras la limpieza (84 OK / 1 FALLO antes: el de `DefenseModule`, esperado), `test/ia0c_test.tscn` 67 OK / 0 FALLOS tras ajustar la prueba (ver §4.7), Depurador → Errores sin avisos y validada en partida (combate de seis enemigos con Mira, esquiva y victoria). Decisiones 1-A, 2-A, 3-A, 4-B y 5-A adoptadas, más la 6 (activar `DefenseModule`) añadida durante la Fase 0. Con IA-0d se cierra la fase IA-0: el siguiente paso es IA-1.

## 1. Qué cambia

- **Constitución y vida derivada.** Los números jugados ya salían de la constitución real (`con` 8 / 12 / 12 / 10 / 9 y fuerza 8 / 14 / 11 / 10 / 9), así que **no cambió ningún atributo**. Lo que se hizo fue quitar `health` y `stamina` de `starting_resources` en los cinco `.tres` de enemigo (`enemy_base` y los cuatro `telmori_*`), que eran datos inertes. Los máximos salen de `AttributeResolver` y se verificaron por el log de registro: vida/estamina 40/28, 60/45, 60/40,5, 50/35 y 45/31,5.
- **Registro completo.** Los refuerzos de `combat_production_scene.gd` dejan de registrarse con `["health"]` y usan `Resources.register_entity(enemy_id)` sin lista (salud, estamina y oro: «with 3 resources»). El roster inicial, narrativa y exploración ya lo hacían, y Mira entra por `PartyManager` con los tres recursos.
- **Kits desde la definición.** `combat_production_scene.gd` gana `_get_enemy_kit(enemy_id)`, que lee `CharacterDefinition.skills` (sin definición o con la lista vacía cae a `basic_attack` con un aviso). Mira ya recibía su kit de `definition.skills` en `PartyManager._register_in_systems()`.
- **Campos nuevos en `CharacterDefinition`.** `behavior_profile_id: StringName = &""` y `threat_hint: String = ""`, copiados por `duplicate_definition()`; `validate()` avisa (`push_warning`) si `threat_hint` no es `""`/`low`/`medium`/`high`. Sin `from_dict` ni registry (la definición se carga como `.tres`). `Combat.estimate_threat()` ya leía `threat_hint` con `definition.get()`: no cambia. **No se asigna ningún valor a ningún `.tres`** (llegan con IA-1/IA-5) ni se valida el perfil.
- **Skills nuevas** (en `data/skills/enemy/`, que el cargador recorre de forma recursiva):

| Skill | Coste | Cooldown | Efecto |
|---|---|---|---|
| `skill.enemy.heavy_attack` | 15 de estamina | 3 | `DAMAGE` 0,6 (el doble que `basic_attack`), `SINGLE_ENEMY` |
| `skill.companion.defend` | 10 de estamina | 2 | `BUFF damage_reduction` 50, 1 turno |
| `skill.companion.recover` | sin coste | 2 | `RESTORE` de 20 de estamina |

  Claves `SKILL_ENEMY_HEAVY_ATTACK_*` y `SKILL_COMPANION_{DEFEND,RECOVER}_*` en `skills.csv` (ES y EN).
- **Kits asignados** (decisión 1-A): guerreros `basic_attack` + `heavy_attack` + `defend`; lobos `basic_attack` + `heavy_attack` + `recover`; `enemy_base` `basic_attack` + `defend` + `recover`; `flee` sin asignar hasta IA-4. `heavy_attack` hereda el valor de habilidad de su `basic_attack` (55 / 45 / 50 / 40). Mira recibe `defend` y `recover` en `skills` **sin** entrada en `starting_skill_values`, así que los selectores heredados de `CompanionAI` (`list_known_skills`) no las ven y no hizo falta tocar `companion_ai.gd`. Sostenibilidad: con 10 de estamina por ronda un guerrero que alterne `heavy_attack` (15) y `defend` (10) gasta unos 12,5 por ronda de media frente a 10 de recuperación, y siempre tiene `basic_attack` gratuito.
- **`dodge` unificado.** `dodge.tres` declara `"expires_on": "use"` en sus dos efectos, `_build_buff()` respeta un `expires_on` explícito (sin él se deriva de `duration` como antes) y `_process_dodge()` llama a `_build_buff()` conservando la animación, el log y el efecto visual de evasión.
- **`AREA`/`MULTI_ENEMY` por bando.** `_get_hit_targets(attacker_id, target_id, skill_def)` usa el nuevo `_get_hit_pool(attacker_id)`: un aliado conserva `GameLoop.get_active_enemies()` y un enemigo golpea al jugador y a los compañeros activos (`_get_opponents`).
- **`fireball`** pierde el coste de `focus` (decisión 4-B) y sigue costando 15 de estamina; `focus` no se define como recurso.
- **`DefenseModule` real activado.** `defense_module.gd` pasa a declarar `class_name DefenseModule` y se borran los cinco respaldos con sus `.uid`: `defense_module_bak.gd`, `enemy_ai_backup.gd`, `entity_animation_controller_bak.gd`, `combat_system_bak.gd` y `player_combat_controller_bak.gd`. `combat_test` y `combat_hud.tscn` se dejan; `economy_system_bak.gd` queda fuera del alcance.
- **Prueba automática** `test/ia0d_test.tscn`: 85 comprobaciones (ver §3). Además, `test/ia0c_test.gd` recibe un ajuste de una línea para el barrido (§4.7).

## 2. Desviaciones respecto a la spec

1. **No hubo cambio de constitución.** La spec y el plan hablaban de «poner `con` = 8 / 12 / 12 / 10 / 9»: ya estaban así, y la fuerza real de cada `.tres` coincidía con la hipótesis (la estamina no cambia).
2. **Decisión 6 (nueva):** activar el `DefenseModule` real. La clase global que resolvía el código de producción era la del `_bak`, que no detecta el desbordamiento de estamina (ver §4.1). Es una corrección intencionada, sin efecto jugable hoy.
3. **Skills de Mira sin valor de habilidad** (no previsto): así `CompanionAI` no necesita parche (en el borrador se había pensado uno para `BERSERKER`).
4. **Skills de Mira en `data/skills/enemy/`**, junto a las de los enemigos, para no suponer la carpeta del cargador.
5. **`sweep` es `MULTI_ENEMY` (máx. 2 objetivos), no `AREA`.** La prueba lo lee de la definición. Ninguna skill cargada es `AREA` pura, así que esa rama no se ejercita por separado; `AREA` y `MULTI_ENEMY` comparten `_get_hit_pool()`.
6. **`dodge`:** se esperaba un resultado idéntico; el único cambio visible es el texto del log (`0 turns` en vez de `1 turns` en `Buff applied`), porque los buffs de uso no consumen `turns_left`.
7. **`narrative_scene_viewmodel.gd` y `exploration_controller.gd` no se tocaron** (ya registraban todos los recursos).
8. **`estimate_threat()` no cambia**: ya leía `threat_hint`; solo faltaba el campo.
9. **`companion_mira.tres` está en `data/characters/companions/`** (no en `data/characters/`): una búsqueda con `data\characters\*.tres` no entra en subcarpetas.
10. **«Actor sin estamina pasa el turno» no se ejercita en partida:** `basic_attack` no cuesta nada, y `EnemyAI` solo pide `basic_attack`. La prueba automática comprueba que con estamina 0 las candidatas del actor son solo gratuitas.
11. **`test/ia0c_test.gd` tuvo que tocarse** (no previsto): ver §4.7.

## 3. Validación

**Prueba automática** (`test/ia0d_test.tscn`, 85 OK · 0 FALLOS tras la limpieza):

- [x] A. Máximos de los cinco enemigos (vida y estamina, actual igual al máximo), `starting_resources` sin `health`/`stamina`, registro de las tres reservas sin lista, kits y valor de `heavy_attack`.
- [x] B. Campos nuevos con valores por defecto y copia por `duplicate_definition()`.
- [x] C. `heavy_attack`, `companion.defend`/`recover`, `fireball` sin `focus` (15 de estamina) y seis textos localizados.
- [x] D. `get_candidates` por estamina: guerrero (llena / 12 / 0), lobo (5 / llena), `enemy_base` (5) y Mira como aliada (llena / 5); `defend` de Mira aplica `damage_reduction` y `recover` sube de 5 a 25.
- [x] E. `dodge`: aplica `guaranteed_hit` y `evasion`, cobra 15 y cada buff desaparece con un consumo.
- [x] F. Multi-objetivo por bando con 3 aliados y 3 enemigos: un enemigo golpea solo aliados (2 de 3, objetivo principal incluido) y el jugador solo enemigos (2 de 3).
- [x] G. `DefenseModule`: daño 10 con estamina 20 → 3 a la vida; con estamina 3 → 7 a la vida y estamina 0 (antes de la limpieza daba 3: absorbía gratis).

**Regresión de IA-0c** (`test/ia0c_test.tscn`):

- [x] 67 OK · 0 FALLOS tras el ajuste de §4.7: ligero y pesado con error de estimación 0,17 % y 0,59 %, `sweep` 0,59 % (sin buffs y con `damage_reduction`), `defend`/`recover`/`flee` y `INVALID_TARGET` intactos.

**En partida real** (combate de seis enemigos con Mira, dos veces):

- [x] Los máximos del log coinciden con la tabla; todos los combatientes salen con `with 3 resources`; guerreros y lobos se registran con `3 unlocked, 0 locked` y Mira con `8 unlocked, 0 locked`.
- [x] El combate de 11 rondas se juega igual que en IA-0c: los seis enemigos usan solo `basic_attack`, el daño se reduce al mínimo de 1,0 por la armadura y termina en victoria con las seis bajas.
- [x] `dodge`: la evasión se consume en el siguiente ataque enemigo (`Attack EVADED!`) y el golpe garantizado en el siguiente ataque del jugador, igual que antes.
- [x] Tras la limpieza, `[DefenseModule] Module reset` sigue apareciendo al acabar; `Select-String 'TEMPORAL IA-0d'` sobre los `.gd` queda vacío.
- [x] Depurador → Errores sin avisos nuevos tras borrar los respaldos y activar `class_name DefenseModule` (sin errores de clase global duplicada).

## 4. Hallazgos durante la fase

1. **`DefenseModule` activo era el de respaldo, con un fallo latente.** `defense_module.gd` tenía `#class_name DefenseModule` comentado y `defense_module_bak.gd` lo declaraba, así que `combat_system.gd` usaba el respaldo. Este resta la estamina antes de comprobar el desbordamiento y `ResourceState` recorta a 0: el desbordamiento nunca se detecta y, con poca estamina, la defensa absorbe daño gratis. El módulo real calcula el desbordamiento antes de tocar `Resources`. Sin efecto jugable hoy (tras la armadura el daño es 1 y `int(0.7)` es 0), pero lo ejercería cualquier cambio de equilibrio.
2. **`dodge` no es candidata de Mira:** `Combat` lo registra con `buff 'guaranteed_hit' sin conversión en effect_value`. Falta declarar en `ai_scales.json` cómo valorar `guaranteed_hit` y `evasion` (IA-1/IA-3/IA-5). Con ello, además, la evasión y la defensa solo funcionan para `PLAYER_ID`.
3. **`recover` con la estamina llena aparece en las candidatas de Mira** con valor 0 (ya lo preveía IA-0c); el evaluador (IA-2) tendrá que descartarla por utilidad.
4. **`enemy_ai.gd` se carga por ruta** (`preload` en `combat_production_scene.gd`, `combat_arena_test_scene.gd` y `combat_test.gd`), por eso su `class_name EnemyAI` comentado es seguro y el respaldo que lo declaraba no tenía usuarios.
5. **`party_manager.gd:227` sigue leyendo `skills_node._entity_skills`** (acceso privado heredado); fuera de alcance, ya listado.
6. **Fallos de entrega de esta fase** (para las lecciones): un script de PowerShell con rutas relativas escribió en `C:\Windows\system32` (la ruta de .NET no sigue a `Get-Location`; no llegó a escribir nada) y un bloque de GDScript pegado en la consola perdió las tabulaciones; el fichero que se buscaba estaba en una subcarpeta que la búsqueda no recorría.
7. **`ia0c_test` falló por la corrección de bando (no era un fallo de producción).** El atacante de la prueba, `ia0c_attacker`, no es aliado a propósito (sin progresión de skills), así que tras la decisión 3-A su `sweep` golpeaba al jugador y no a los `TARGETS`: estimación 2,9 frente a un «real» de ≈1.000.000 por medir la vida de objetivos no golpeados. `_is_ally()` solo reconoce a `player` y a los miembros de `Party._party_members` (privado), así que la prueba no puede declararlo aliado sin acceso privado. Arreglo en la prueba: antes de comprobar `sweep`, la vida del jugador sube a `BIG_HP` (en `_check_estimate`). Así la prueba cubre el barrido de bando contrario y deja el de aliado contra `GameLoop` a `ia0d_test` (bloque F) y a la partida. Una prueba que construye entidades inventadas hereda las reglas de bando del sistema que prueba.

## 5. Pendientes que deja

- **IA-1 a IA-5:** `threat_hint` y `behavior_profile_id` sin valores en ningún `.tres`; los kits (con `heavy_attack`, `defend`, `recover`) no se usan hasta que la IA elija; costes y daño del ataque fuerte y de las skills de Mira son provisionales (IA-5); conversión de `guaranteed_hit`/`evasion` en `effect_value` (hallazgo 2); `warrior_base` y `warrior_weak` tienen la misma vida y solo difieren en la estamina (equilibrio).
- **Sin ejercitar:** el camino «actor sin estamina pasa el turno» (§2.10), las skills de Mira por el camino real de `CompanionAI` (solo por la prueba automática), la rama `AREA` pura (§2.5), el barrido de aliado contra `GameLoop` en `ia0c_test` (queda en `ia0d_test` F) y cargar un guardado antiguo con Mira para ver que recibe las dos skills nuevas.
- **Heredados sin cambio:** tecla 3 del jugador → `skill.attack.stunning_blow` no registrada (`SKILL_NOT_FOUND`); `economy_system_bak.gd`, `combat_test.gd` (conecta `Combat.combat_action_executed`, que no existe) y `combat_hud.tscn`; `PartyManager._register_in_systems()` con acceso privado; `focus` sigue sin ser un recurso registrado (la magia no está diseñada).
