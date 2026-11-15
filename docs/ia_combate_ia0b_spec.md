# Athelia — IA-0b: combate puramente por turnos (especificación)

**Fecha:** 2026-11-14 · **Base:** `docs/ia_combate_spec_v1_7_1.md` (principio 7, §12), `ia_combate_ia0_plan.md` (IA-0b) y `docs/ia_combate_ia0a_informe.md`
**Estado:** Fase 0 hecha sobre ficheros anteriores a los parches de IA-0a; **pendiente de repetirla con los ficheros actuales** y de cerrar las 3 decisiones (sección 3).

IA-0b quita el reloj de las reglas del combate: ni la estamina ni los cooldowns pueden depender del tiempo real. No añade IA.

## 1. Fase 0: lo que hay hoy

| Tema | Estado real (ficheros previos a IA-0a) |
|---|---|
| Regeneración | `ResourceSystem._process` regenera cada frame todos los recursos de todas las entidades. Solo `stamina` tiene `regen_rate` (5/s tras `regen_delay` 2 s); `health` y `gold` no regeneran. `set_regen_paused(entity, resource, paused)` existe, actúa sobre un recurso de una entidad y **nadie lo llama**. |
| Cooldowns | **Dos sistemas que no se hablan.** `SkillSystem`: segundos reales (`SkillInstance.current_cooldown` float, `process_cooldown(delta)` desde `_process`); decide `can_use`/`request_use`. `CombatHudViewModel`: contador propio en rondas por slot, `int(base_cooldown)`, que baja en `round_started` y se inicia con `EventBus.skill_used`. |
| Datos | `base_cooldown`: ligero 1,5 · esquiva 2,0 · barrido 2,5 · pesado 3,0 · golpe aturdidor 2,0. Costes de estamina: ligero 10 · esquiva 15 · barrido 20 · pesado 25. Estamina máxima del jugador ≈ 30-45. |
| Efecto actual | Con turnos de 0,5-0,8 s de retardo y 2 s de cooldown real, el cooldown casi nunca bloquea. El HUD sí bloquea el botón; `PlayerCombatController` no lo comprueba. |
| HUD | `CombatHudViewModel` lee la estamina de `CharacterState.resources`, que nadie actualiza (`is_available` no cambia al gastar). `EventBus.skill_used`: **emisor sin confirmar**. |
| Iniciativa | `_calculate_initiative()` ordena con `sort_custom(a.initiative > b.initiative)`, sin desempate explícito. |
| Retardos | `GameLoop`: `enemy_turn_delay` 0,8, `companion_turn_delay` 0,5 y un `create_timer(0.3)` fijo. `EnemyAI.decision_delay` 0,5; `CompanionAI.decision_delay` 0,6. |

## 2. Hallazgo que corrige la spec v1.7.1

La spec fija `combat_regen_per_round` en **0**. Con los datos actuales el jugador (≈30-45 de estamina, ataque ligero a 10, combates de 12-22 rondas, **sin acción `recover`**) se quedaría sin aguante en 3-4 rondas y no podría hacer nada. Hoy no ocurre porque 5/s en tiempo real le da estamina casi ilimitada. Hay que corregir el principio 7 y la tarea 2 del plan según la decisión 1.

## 3. Decisiones (pendientes de Fernando)

| # | Pregunta | Opciones | Recomendación |
|---|---|---|---|
| 1 | Regeneración por ronda | **A)** 10 por ronda (sostiene un ataque ligero por ronda; ritmo parecido al actual). **B)** 0 y skill `recover` para el jugador (exige slot en el Loadout y UI) | **A**; `recover` llega con la IA (IA-0c/IA-3) y el valor se afina en IA-5 |
| 2 | Conversión `base_cooldown` → rondas | **A)** truncar, `int()`: ligero 1 (sin bloqueo), esquiva 2, barrido 2, pesado 3 (lo que ya enseña el HUD). **B)** `ceil` (plan original): el ataque ligero quedaría bloqueado una ronda de cada dos. **C)** campo nuevo `cooldown_rounds` en `SkillDefinition` (exige declaración + lectura en el registry) | **A** ahora; reconsiderar C en IA-5 |
| 3 | Cómo suspender la regeneración | **A)** interruptor global en `ResourceSystem` que `GameLoop` activa al empezar y desactiva al acabar el combate. **B)** `set_regen_paused` entidad a entidad (hay que cubrir refuerzos) | **A** |

Regla de cooldown (fija, no depende de la decisión 2): se fija a N al usar la skill, baja 1 en cada `round_started` y la skill queda disponible al llegar a 0. Usada en la ronda R con cooldown 2, vuelve a estar disponible en R+2.

## 4. Tareas

| # | Tarea | Ficheros |
|---|---|---|
| 1 | Interruptor de regeneración en `ResourceSystem` (p. ej. `set_regen_suspended(bool)`); `_process` no regenera mientras esté activo. `GameLoop` lo activa en `start_combat()` y lo desactiva en `end_combat()` (también con huida y derrota) | `resource_system.gd`, `game_loop_system.gd` |
| 2 | Campo `combat_regen_per_round` en `ResourceDefinition` (valor según decisión 1; `stamina.tres`). `ResourceSystem` expone `apply_combat_round_regen(entity_id)`; `GameLoop` lo llama para cada participante vivo al empezar cada ronda **excepto la primera**. Si el campo es un `@export` de un `.tres`, no hay `from_dict`; si `ResourceDefinition` se carga por otro camino, comprobarlo | `resource_definition.gd`, `stamina.tres`, `resource_system.gd`, `game_loop_system.gd` |
| 3 | Cooldowns en rondas: `SkillSystem` entra en modo combate con `combat_started` y sale con `combat_ended`; dentro, `_process` no avanza el reloj, `start_cooldown()` fija el valor convertido (decisión 2) y `round_started` baja 1 en todas las instancias. Se ponen a 0 al empezar y al acabar el combate (para que las rondas no se arrastren como segundos). Revisar qué significa `duration` en `cooldown_started` | `skill_system.gd`, `skill_instance.gd` |
| 4 | El HUD deja de llevar su propio contador: lee `Skills.get_cooldown_remaining()` y la estamina de `ResourceSystem` (no de `CharacterState`); `is_available` cambia al gastar. `PlayerCombatController` ya valida con `Skills.can_use` desde IA-0a | `combat_hub_viewmodel.gd` |
| 5 | Confirmar el emisor de `EventBus.skill_used`; si no existe, puente desde `CombatSystem` (o dejar de depender de él tras la tarea 4) | `skill_system.gd` / `combat_system.gd` |
| 6 | Desempate determinista de la iniciativa: a igual valor, por id | `game_loop_system.gd` |
| 7 | Retardos de presentación anulables con un único ajuste (`presentation_time_scale` en `GameLoop`, 1.0 por defecto, 0 en modo sin interfaz); `GameLoop`, `EnemyAI` y `CompanionAI` lo multiplican; el `0.3` fijo pasa a una constante | `game_loop_system.gd`, `enemy_ai.gd`, `companion_ai.gd` |

## 5. Validación

- Combate parado 30 s: la estamina **no** cambia. Al empezar cada ronda (salvo la primera) sube exactamente `combat_regen_per_round`.
- Fuera de combate la estamina sigue regenerando en tiempo real (exploración); al acabar el combate se reactiva.
- Un ataque con cooldown 2 usado en la ronda R: no disponible en R+1, disponible en R+2, y el HUD y `Skills.can_use` coinciden.
- Dos combates seguidos: cooldowns a 0 al empezar; ninguna cifra en rondas queda como segundos.
- Los botones del HUD cambian de estado al gastar estamina.
- Dos enemigos iguales: mismo orden de turno en cada ejecución (Output).
- Con `presentation_time_scale = 0` el combate completo se resuelve sin esperas.
- Depurador → Errores sin avisos nuevos. Huida y derrota también reactivan la regeneración.

## 6. Cambios de comportamiento a avisar

- La estamina deja de regenerarse durante el combate (compensado por la regeneración por ronda).
- El cooldown de las skills pasa a bloquear de verdad (hoy casi no bloquea).
- La huida contra 4 enemigos (umbral 60) sigue siendo inalcanzable; no cambia aquí.

## 7. Fuera de alcance

Skill `recover` del jugador, `SELF`/`RESTORE`/`FLEE` (IA-0c), PV derivados y datos de enemigos (IA-0d), equilibrio (IA-5).

## 8. Ficheros necesarios para la Fase 0 definitiva

Actuales (IA-0a los modificó): `game_loop_system.gd`, `skill_system.gd`, `enemy_ai.gd`, `companion_ai.gd`. Nunca vistos o sin cambios: `resource_definition.gd`, `combat_hub_viewmodel.gd`, `skill_instance.gd`, `resource_system.gd`, `resource_state.gd`.

Búsquedas:

```powershell
Get-ChildItem -Recurse -Filter *.gd | Select-String -Pattern 'skill_used|cooldown_started|cooldown_finished|get_cooldown|process_cooldown|start_cooldown'
Get-ChildItem -Recurse -Filter *.gd | Select-String -Pattern 'regen_rate|regen_delay|process_regeneration|set_regen_paused|create_timer'
```

## 9. Al cerrar

Informe en `docs/ia_combate_ia0b_informe.md`; corregir spec v1.7.1 (principio 7 y §12) y plan; `estado_actual.md`, `athelia_referencia_sistemas.md` (reglas por turnos), lecciones nuevas e historial (un párrafo).
