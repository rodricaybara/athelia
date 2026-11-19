# Athelia — Plan de la fase IA-0 (prerrequisitos de motor de la IA de combate)

**Fecha:** 2026-11-11 (IA-0b y IA-0c actualizadas el 2026-11-15; IA-0d cerrada el 2026-11-16) · **Base:** `docs/ia_combate_fase0.md` y `docs/ia_combate_spec_v1_7_1.md`

IA-0 no añade IA. Deja el motor de combate en un estado en el que la IA se pueda construir encima: acciones que no cuelgan el turno, estado que no se arrastra entre combates, reglas por turnos, estimaciones públicas y datos coherentes. Se divide en 4 spikes. Cada uno sigue el flujo habitual (Fase 0 con búsquedas → implementación → validación en partida → informe), y el orden fue **0a → 0b → 0c → 0d**. **IA-0 está cerrada; el siguiente paso es IA-1.**

**No se toca en IA-0:** la fórmula de daño (solo se separa la parte pura), las skills del jugador, la moral de grupo (se elimina en IA-4), la pantalla Party (IA-3), la huida del jugador (solo su estado).

---

## IA-0a — Robustez de acciones y estado de combate

**Estado: cerrada el 2026-11-14** (`docs/ia_combate_ia0a_informe.md`). Cambios respecto a lo previsto: la tarea 5d (`_evaluate_outcome()`) pasa a **IA-4**; de la tarea 7 solo se aplicó `Skills.has_entity` (la lectura de skills desde `CharacterDefinition.skills` se hizo en **IA-0d**); se añadieron 5c (`get_last_attacker`), `Combat` deja de emitir dos veces el fallo de una skill y la baja de enemigos se difiere.

| # | Tarea | Ficheros |
|---|---|---|
| 1 | Corregir la guarda de `_incapacitate_player()`, que sale siempre porque el jugador ya está a 0 PV. Debe emitir `player_incapacitated` y poner `flag.player_downed` una sola vez | `game_loop_system.gd` |
| 2 | Reiniciar al **empezar y al acabar** cada combate: `_active_buffs` de todos los participantes, `EscapeModule`, `DefenseModule` | `combat_system.gd`, `game_loop_system.gd` |
| 3 | Dar de baja a los enemigos al acabar el combate (`EntityLifecycle.unregister_everywhere`), después de que telemetría y victoria lean sus datos | `combat_production_scene.gd` |
| 4 | `EnemyAI`, `CompanionAI` y el salto de turno emiten siempre un fin **con `actor`** | `enemy_ai.gd`, `companion_ai.gd` |
| 5 | Códigos de motivo en `combat_action_failed` y `skill_failed` (spec 6) | `combat_system.gd`, `skill_system.gd`, `event_bus.gd` |
| 5b | **`request_id`** y señal genérica: renombrar `player_action_requested` → `combat_action_requested` (1 señal, 3 emisores —`player_combat_controller`, `enemy_ai`, `companion_ai`— y 1 oyente, `game_loop_system`, ya localizados) y añadir `Combat.next_request_id()`. `combat_action_executed/completed/failed` devuelven el `request_id` de la petición; `GameLoop` descarta las respuestas con un id ajeno. Es un cambio de firma en `EventBus`: buscar con `Select-String` todos los oyentes (`combat_arena_viewmodel` escucha `executed` y `completed`) antes de aplicarlo | `event_bus.gd`, `combat_system.gd`, `game_loop_system.gd`, `enemy_ai.gd`, `companion_ai.gd`, `player_combat_controller.gd`, `combat_arena_viewmodel.gd` |
| 5c | `Combat` registra el **último atacante** de cada combatiente al aplicar daño (`get_last_attacker(id)`); se reinicia al empezar el combate | `combat_system.gd` |
| 5d | Resolución del fin de combate en un solo punto: `_evaluate_outcome()` tras cada acción cerrada, con prioridad `escaped > victory > defeat`; el rescate a 1 PV se aplica **antes** de construir el resultado | `game_loop_system.gd` |
| 6 | `PlayerCombatController` valida con `Skills.can_use` antes de pedir; si falla, `GameLoop` devuelve la fase a `PLAYER_ACTION_SELECT` (nueva transición permitida) | `player_combat_controller.gd`, `game_loop_system.gd` |
| 7 | `CombatProductionScene`: `Skills.has_entity()` en vez de `_entity_skills`, y skills desde `CharacterDefinition.skills` | `combat_production_scene.gd` |
| 8 | `SaveSystem.save_game` rechaza guardar con `GameLoop.is_in_combat()` | `save_system.gd` |

**Validación:**
- Derrota con companion: el Output muestra «Player incapacitated — last stand begins» **una vez** y aparece `flag.player_downed`.
- Pedir huir con un enemigo casi muerto que remata Mira, y entrar en un segundo combate: **no** debe terminar como `escaped` en su primer turno.
- Dos combates seguidos con los mismos ids de enemigo (`telmori_1`...): sin buffs ni estamina heredados.
- Con menos estamina de la necesaria, la tecla de ataque no cuelga el turno.
- Cada respuesta de acción en el Output lleva su `request_id`; una respuesta con id ajeno se descarta con un aviso.
- Depurador → Errores sin avisos nuevos.

## IA-0b — Combate por turnos

**Estado: cerrada el 2026-11-14 (confirmada el 2026-11-15)**, validada en partida (`docs/ia_combate_ia0b_informe.md`; spec en `docs/ia_combate_ia0b_spec.md`). Decisiones confirmadas por Fernando: **1-A** 10 de estamina por ronda · **2-A** `int(base_cooldown)` · **3-A** interruptor global. Pendiente que deja: un enemigo o Mira sin estamina pasando el turno no se ejercitó (IA-0d no lo ejercita en partida: queda para cuando la IA elija skills con coste). Cambios respecto al plan original: el valor inicial de `combat_regen_per_round` **no** es 0 (con 0 y sin `recover` el jugador se queda sin estamina en 3-4 rondas); la conversión es `int()` y no `ceil` (con `ceil` el ataque ligero quedaría bloqueado una ronda de cada dos); el interruptor es global en `ResourceSystem` y no `set_regen_paused` entidad a entidad; la regeneración por ronda va en `GameLoop` y no en `combat_system.gd`.

| # | Tarea | Ficheros |
|---|---|---|
| 1 | Interruptor global `ResourceSystem.set_regen_suspended(bool)`; `_process` no regenera mientras esté activo. `GameLoop` lo activa/desactiva en `_transition_game_state()` al entrar y salir de `COMBAT_ACTIVE` (cubre victoria, derrota, huida y cualquier cambio directo) | `resource_system.gd`, `game_loop_system.gd` |
| 2 | Recuperación fija por ronda: campo `combat_regen_per_round` en `ResourceDefinition` (`stamina.tres` = **10**), `ResourceSystem.apply_combat_round_regen(entity_id)` y `GameLoop._apply_round_regen()` al empezar cada ronda salvo la primera, solo a participantes con PV > 0 | `resource_definition.gd`, `stamina.tres`, `resource_system.gd`, `game_loop_system.gd` |
| 3 | Cooldowns en rondas: `SkillSystem` entra en modo combate con `combat_started` (y sale con `combat_ended` o al dejar `COMBAT_ACTIVE`); `_process` no avanza; `SkillInstance.start_cooldown_rounds()` fija el valor con **una sola conversión** (`cooldown_rounds_for()`, `int()`); `round_started` baja 1 y se emite `combat_cooldowns_ticked`; cooldowns a 0 al empezar y al acabar. Regla: se fija a N al usar la skill, baja 1 en cada `round_started` y la skill está disponible al llegar a 0 (cooldown 2 usado en la ronda R → disponible en R+2) | `skill_system.gd`, `skill_instance.gd` |
| 4 | El HUD lee cooldown y disponibilidad de `Skills` (`get_cooldown_remaining`, `can_use`) y vida y estamina de **`ResourceState`**, no de `CharacterState.resources`; refresca slots al cambiar la estamina | `combat_hub_viewmodel.gd` |
| 5 | `EventBus.skill_used`: en los ficheros revisados `SkillSystem` solo emite su señal local. Se resuelve **dejando de depender de ella** en el HUD (sin puente); queda por confirmar con la búsqueda 1 si alguien más la emite | `combat_hub_viewmodel.gd` |
| 6 | Desempate determinista de la iniciativa (por id) | `game_loop_system.gd` |
| 7 | `presentation_time_scale` en `GameLoop` (1.0 por defecto, 0 sin interfaz) con `presentation_delay()` y `ROUND_END_PAUSE`; `GameLoop`, `EnemyAI` y `CompanionAI` lo usan | `game_loop_system.gd`, `enemy_ai.gd`, `companion_ai.gd` |
| 8 | *(Añadida)* `EnemyAI` y `CompanionAI` no piden una acción que no pueden pagar y pasan el turno con `actor`: sin regeneración continua, el fallo de un actor de IA (sin gestor hasta IA-1) colgaría el turno | `enemy_ai.gd`, `companion_ai.gd` |

**Validación:**
- Mantener un combate parado 30 s: la estamina **no** cambia; desde la ronda 2 sube exactamente `combat_regen_per_round` (la 1 no).
- Un ataque con cooldown 2 usado en la ronda R no está disponible en R+1 y sí en R+2; el HUD y `Skills.can_use` coinciden.
- Los botones del HUD cambian de estado al gastar estamina.
- Dos combates seguidos: cooldowns a cero al empezar. Huida y derrota reactivan la regeneración continua.
- Dos enemigos iguales: mismo orden de turno en cada ejecución. Con `presentation_time_scale = 0` las pausas de IA desaparecen.
- Cambio de comportamiento a avisar: el flujo de la estamina es otro, el cooldown pasa a bloquear de verdad, y la huida contra 4 enemigos (umbral 60) sigue siendo inalcanzable.

## IA-0c — Estimaciones y candidatas de `Combat`

**Estado: cerrada el 2026-11-15** (`docs/ia_combate_ia0c_informe.md`; spec en `docs/ia_combate_ia0c_spec.md`). Prueba automática 67 OK, error de estimación 0,17–0,59 %, validada en partida (huida de uno, varios y todos los enemigos). Decisiones 1-A a 5-A. Cambios respecto a lo previsto: tercera skill de datos (`skill.enemy.flee`), `Resources.has_resource()`, `INVALID_TARGET` incluido (con `skipped` para no jugadores), parche en `PlayerCombatController` (objetivo tras huir un enemigo) y `AIScales`/`CombatTags` nuevos. Pasaron a IA-0d: registrar todos los recursos de enemigos y refuerzos, unificar `dodge` (`expires_on` en su `.tres`) y comprobar `defense_module_bak.gd` (declara `class_name DefenseModule`) antes de borrarlo.

| # | Tarea | Ficheros |
|---|---|---|
| 1 | `SkillRoller.get_success_chance(skill_value, bonus...)` junto a `_determine_result`; **una sola fórmula** | `skill_roller.gd` |
| 2 | Extraer de `_process_skill_effects`/`_apply_damage` una función pura `estimate_damage(attacker, target, skill)` que use el mismo cálculo (armadura, buffs numéricos, defensa), sin consumir buffs ni emitir señales. El camino real pasa a llamarla | `combat_system.gd` |
| 3 | `Combat.get_candidates(actor_id)` (lee `Skills.get_entity_skill_snapshot` + `can_use`; añade defender/huir como skills) | `combat_system.gd` |
| 4 | `Combat.get_visible_conditions(id)` y la lista de buffs visibles en datos | `combat_system.gd`, datos |
| 5 | `Combat.estimate_threat(observer_side, target_id)` con información observable | `combat_system.gd` |
| 6 | RNG inyectable en `SkillRoller` (variable estática); los demás llamadores (`narrative_scene_viewmodel`, `world_object_system`) siguen con el valor por defecto | `skill_roller.gd` |
| 7 | Skills `SELF` sin tirada (generalizar la rama de `dodge`), `effect_estimate` en PV equivalentes con la tabla `effect_value` (spec 5.2), efecto `RESTORE` inmediato de recurso, efecto `FLEE`, y copiar `resource_id` al buff en `_process_skill_effects` (hoy `resource_regen` no funciona desde una skill porque se pierde) | `combat_system.gd` |
| 7b | Efecto `FLEE`: `Combat` marca `FLED` y emite `enemy_fled`; `GameLoop` escucha y retira de `participants`/`turn_order` **al cerrar la acción en curso** y reevalúa el fin (spec 9). Mira no recibe la skill de huida | `combat_system.gd`, `game_loop_system.gd` |
| 8 | Pantalla/escena de prueba: compara `estimate_damage` y `get_success_chance` con la media de miles de ejecuciones reales | `test/` |

**Validación:** la escena de prueba muestra errores < 2 % para ataque ligero, pesado y barrido; el combate real da las mismas cifras que antes (mismo daño con la misma semilla); `dodge` sigue funcionando igual; una skill `SELF` de datos (defender) reduce el daño sin tirada.

## IA-0d — Datos

**Estado: cerrada el 2026-11-16** (`docs/ia_combate_ia0d_informe.md`; spec en `docs/ia_combate_ia0d_spec.md`). Prueba automática 85 OK y validada en partida (combate de seis enemigos con Mira, esquiva y victoria). Decisiones 1-A (kits: guerreros `basic_attack` + `heavy_attack` + `defend`, lobos `basic_attack` + `heavy_attack` + `recover`, `enemy_base` `basic_attack` + `defend` + `recover`; `flee` sin asignar), 2-A (ids `skill.companion.*` para Mira), 3-A (`_get_hit_targets` por bando), 4-B (`fireball` sin `focus`) y 5-A (borrar los cinco respaldos), más la 6 añadida en la Fase 0 (activar el `DefenseModule` real).

Cambios respecto a lo previsto:
- **Constitución:** no se cambió ningún atributo (la tabla de abajo, con las «constituciones declaradas», quedó descartada por decisión de Fernando: se mantienen los números jugados 40 / 60 / 60 / 50 / 45 y `con` 8 / 12 / 12 / 10 / 9); la tarea 1 solo quitó `health`/`stamina` inertes de `starting_resources`.
- **Mira** registra sus dos skills nuevas sin entrada en `starting_skill_values`, así que `CompanionAI` no necesitó parche.
- **`dodge`** se unificó con `expires_on: "use"` en su `.tres` y `_build_buff()` respeta el campo explícito.
- **`DefenseModule`:** el activo era el de `defense_module_bak.gd` (absorbía daño gratis con estamina insuficiente); se activó el real y se borraron los respaldos.
- `sweep` es `MULTI_ENEMY`, no `AREA`: la rama `AREA` pura no se ejercita. `narrative_scene_viewmodel.gd` y `exploration_controller.gd` no se tocaron.

| # | Tarea | Ficheros |
|---|---|---|
| 1 | Quitar `health` y `stamina` de `starting_resources` en los `.tres` de enemigo (los máximos son derivados). No se toca a Mira ni al jugador | `data/characters/**/*.tres` |
| 2 | Registrar con todos los recursos también a los refuerzos | `combat_production_scene.gd` |
| 3 | Campo `behavior_profile_id` y `threat_hint` en `CharacterDefinition` (incluidos en `duplicate_definition()`) | `character_definition.gd` |
| 4 | Skills de enemigo (`heavy_attack`) y asignación de kits desde `CharacterDefinition.skills` | `data/skills/enemy/`, `.tres` de enemigos, `combat_production_scene.gd`, `skills.csv` |
| 5 | 2 skills `SELF` para Mira: defender y recuperar aguante | `data/skills/enemy/`, `companion_mira.tres`, `skills.csv` |
| 6 | `fireball` sin coste de `focus` | `fireball.tres` |
| 7 | Unificar `dodge`; `AREA`/`MULTI_ENEMY` por bando; borrar respaldos y activar `DefenseModule` | `combat_system.gd`, `dodge.tres`, `defense_module.gd` |

**Validación:** cumplida (ver el informe). `ia0c_test` 67 OK (con el barrido ajustado) y Depurador sin avisos.

---

## Después de IA-0

Siguiente paso: **IA-1** (contratos de perfiles de comportamiento: `BehaviorProfile`, registry y validación), según `docs/ia_combate_spec_v1_7_1.md`. Los pendientes de motor que IA-0 no resolvió (progresión de Mira sin guardar, `PartyManager._register_in_systems` con acceso privado, conversión de `guaranteed_hit`/`evasion` en `effect_value`) están en `estado_actual.md`.
