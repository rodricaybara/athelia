# Athelia — Plan de la fase IA-0 (prerrequisitos de motor de la IA de combate)

**Fecha:** 2026-11-11 · **Base:** `docs/ia_combate_fase0.md` y `docs/ia_combate_spec_v1_7_1.md`

IA-0 no añade IA. Deja el motor de combate en un estado en el que la IA se pueda construir encima: acciones que no cuelgan el turno, estado que no se arrastra entre combates, reglas por turnos, estimaciones públicas y datos coherentes. Se divide en 4 spikes. Cada uno sigue el flujo habitual (Fase 0 con búsquedas → implementación → validación en partida → informe), y el orden es **0a → 0b → 0c → 0d** (0d puede ir en paralelo a 0c).

**No se toca en IA-0:** la fórmula de daño (solo se separa la parte pura), las skills del jugador, la moral de grupo (se elimina en IA-4), la pantalla Party (IA-3), la huida del jugador (solo su estado).

---

## IA-0a — Robustez de acciones y estado de combate

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

| # | Tarea | Ficheros |
|---|---|---|
| 1 | Pausar la regeneración de estamina de todos los participantes durante el combate (`Resources.set_regen_paused`) y reanudarla al terminar | `game_loop_system.gd` / `combat_system.gd` |
| 2 | Recuperación fija por ronda: campo `combat_regen_per_round` en `ResourceDefinition` (**valor inicial 0**: la estamina solo sube con la acción `recover`; se decide en IA-5) | `resource_definition.gd`, `stamina.tres`, `combat_system.gd` |
| 3 | Cooldowns en rondas dentro del combate: `SkillSystem` pausa el avance por segundos de las skills de combate y las descuenta en `round_started`; se reinician al empezar el combate. Regla de conversión única `ceil(base_cooldown)`; el contador se fija a N al usar la skill, baja 1 en cada `round_started` y la skill está disponible al llegar a 0 (cooldown 2 usado en la ronda R → disponible en R+2); el HUD deja de calcularlo | `skill_system.gd`, `skill_instance.gd`, `combat_hub_viewmodel.gd` |
| 4 | El HUD lee vida, estamina y disponibilidad de **`ResourceSystem`**, no de `CharacterState.resources` (que nadie actualiza) | `combat_hub_viewmodel.gd` |
| 5 | Comprobar si `EventBus.skill_used` tiene emisor; si no, hacer el puente desde `CombatSystem` (el HUD lo escucha para iniciar cooldowns) | `skill_system.gd` |
| 6 | Desempate determinista de la iniciativa (por id) | `game_loop_system.gd` |
| 7 | Ajuste de retardos de IA (`decision_delay`, `enemy_turn_delay`, `companion_turn_delay`) para anularlos en modo sin interfaz | `enemy_ai.gd`, `companion_ai.gd`, `game_loop_system.gd` |

**Validación:**
- Mantener un combate parado 30 s: la estamina **no** cambia. Con `combat_regen_per_round = 3` de prueba, al empezar cada ronda sube exactamente 3 (volver a 0 después).
- Un ataque con cooldown 2 usado en la ronda R no está disponible en R+1 y sí en R+2.
- Los botones del HUD cambian de estado al gastar estamina.
- Dos combates seguidos: cooldowns a cero al empezar.
- Cambio de comportamiento a avisar: el flujo de la estamina es otro, y la huida contra 4 enemigos (umbral 60) sigue siendo inalcanzable.

## IA-0c — Estimaciones y candidatas de `Combat`

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

| # | Tarea | Ficheros |
|---|---|---|
| 1 | **Vida derivada (decisión D8):** eliminar `health` y `stamina` de `starting_resources` en los `.tres` de enemigo y ajustar las constituciones (ver tabla). No se toca a Mira ni al jugador sin confirmación | `data/characters/**/*.tres` |
| 2 | Registrar con todos los recursos también a los refuerzos | `combat_production_scene.gd` |
| 3 | Campo `behavior_profile_id` y `threat_hint` en `CharacterDefinition` (incluidos en `duplicate_definition()`) | `character_definition.gd` |
| 4 | 2-3 skills de enemigo: ataque fuerte, defender, recuperar (costes y valores orientativos, a tunear en IA-5) y asignación en `skills`/`starting_skill_values` de cada enemigo | `data/skills/`, `.tres` de enemigos |
| 5 | 2 skills `SELF` para Mira: defender y recuperar aguante | `data/skills/`, `companion_mira.tres` |
| 6 | `focus` en `ResourceSystem` (o sacar de `fireball` el coste de foco) para que no sea impagable | `resource_system.gd` |
| 7 | Borrar `combat_system_bak.gd`, `enemy_ai_backup.gd`, `defense_module_bak.gd` y `ui/entity_animation_controller_bak.gd` | — |

Constituciones: la vida es `con × 5` y la estamina `con × 2 + fue × 1,5`.

| Definición | HP actual | HP declarada | `con` para la declarada | Estamina actual → nueva |
|---|---|---|---|---|
| `enemy_base` | 40 | 50 | 10 | 28 → 32 |
| `telmori_warrior_base` | 60 | 45 | 9 | 45 → 39 |
| `telmori_warrior_weak` | 60 | 40 | 8 | 40,5 → 32,5 |
| `telmori_wolf_base` | 50 | 30 | 6 | 35 → 27 |
| `telmori_wolf_weak` | 45 | 25 | 5 | 31,5 → 23,5 |

Pendiente de confirmar: si el objetivo son los números **declarados** (columna 3) o los que ya has probado en partida (columna 2).

**Validación:** el log de registro muestra la vida y la estamina esperadas de cada enemigo; los refuerzos tienen estamina; el Depurador no avisa de recursos inexistentes; `fireball` ya no genera errores al comprobar su coste.

---

## Después de IA-0

Actualizar `estado_actual.md` (tabla y pendientes), `athelia_referencia_sistemas.md` (reglas por turnos, API de `Combat`), `athelia_lecciones_tecnicas.md` (guarda contradictoria, señales sin oyente, regeneración en tiempo real) y `athelia_historial_spikes.md`. Los pendientes de motor que este plan resuelve se eliminan de `estado_actual.md`; los que no (progresión de Mira sin guardar, `PartyManager._register_in_systems` con acceso privado) se mantienen.
