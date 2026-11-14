# Athelia — IA-0a: informe de cierre

**Fecha:** 2026-11-14 · **Base:** `docs/ia_combate_ia0_plan.md` (IA-0a) y `docs/ia_combate_spec_v1_7_1.md` §6, §7, §10
**Estado:** cerrado, con dos pendientes menores (ver «Pendientes»).

IA-0a deja el motor de combate sin acciones que cuelguen el turno ni estado que pase de un combate al siguiente. No añade IA.

## Qué se ha hecho

| Tarea del plan | Resultado |
|---|---|
| 1. Guarda de `_incapacitate_player()` | `player_incapacitated` y `flag.player_downed` se emiten **una vez** por combate (indicador `_player_downed_announced`). El bloque «jugador a 0 PV» de `_check_combat_conditions` ya se ejecuta |
| 2. Reinicio de estado | `Combat` limpia buffs, contexto de skill, módulo de defensa y de huida, y el último atacante **al acabar** el combate. No se limpia al empezar: `_apply_surprise` aplica buffs antes de `combat_started` |
| 3. Baja de enemigos | `CombatProductionScene` apunta los ids de todos los enemigos que registra (refuerzos incluidos) y los da de baja con `EntityLifecycle.unregister_everywhere`, **diferido** (`call_deferred`) |
| 4. Fin con `actor` al saltar turno | `EnemyAI` emite `{"skipped": true, "actor": id}` |
| 5. Códigos de motivo | `SkillSystem` emite `SKILL_NOT_FOUND`, `ON_COOLDOWN`, `INSUFFICIENT_RESOURCES`; `Combat` emite `NO_TARGET`; `DISARMED` sin cambios |
| 5b. Señal genérica y `request_id` | `player_action_requested` → `combat_action_requested`; `Combat.next_request_id()`; `combat_action_completed/failed` devuelven el id; `GameLoop` descarta respuestas ajenas |
| 5c. Último atacante | `Combat.get_last_attacker(id)`; se limpia al empezar y al acabar el combate |
| 6. Validación del jugador | `GameLoop` escucha `combat_action_failed`: si falla una acción del jugador, la fase vuelve a `PLAYER_ACTION_SELECT` (transición nueva). `PlayerCombatController` comprueba `Skills.has_skill` y `Skills.can_use` antes de pedir: una skill no registrada (tecla 3) se frena en el controlador sin cambiar de fase |
| 7. `Skills.has_entity` | Aplicado en `CombatProductionScene`. La lectura de skills desde `CharacterDefinition.skills` pasa a **IA-0d** |
| 8. Sin guardado en combate | `SaveSystem.save_game` rechaza con `save_failed(..., "IN_COMBAT")` |
| 5d. `_evaluate_outcome()` en un solo punto | Pasa a **IA-4** (junto con `combat_result_ready` y la huida enemiga) |

Fuera de la lista del plan: `Combat` ya no emite el fallo de una skill dos veces (antes, una desde `Skills` y otra con el texto libre `"Skill use failed"`), e ignora `skill_failed` fuera de combate.

## Validado en partida

Last stand con rescate a 1 PV y flag limpiado; derrota total (un solo Game Over); huida con y sin Mira rematando; dos combates seguidos con los mismos ids (también tras huir); recuperación de un fallo del jugador (`SKILL_NOT_FOUND` con la tecla 3, `INSUFFICIENT_RESOURCES` sin aguante) con el mismo turno aprovechable; baja de los enemigos tras victoria y tras huida; bloqueo en el controlador de una skill no registrada (`Cannot use skill ...`, sin cambio de fase); sin errores en el Depurador.

## Lecciones técnicas

1. **Todo lo que libere recursos al acabar un combate debe diferirse.** `character_died` → `GameLoop` → `end_combat()` puede dispararse **a mitad de una acción**, y `Combat` sigue leyendo al objetivo y al atacante después. Dar de baja en el mismo momento dejó `Resources` y `Characters` sin la entidad y produjo un error.
2. **`await` tras `combat_ended` no es fiable:** `SceneOrchestrator` hace `queue_free()` de `CombatScene` en esa misma emisión, y la corrutina de un nodo liberado no continúa. Una llamada diferida a una función **estática** no depende de la escena.
3. **El flujo de una petición del jugador es síncrono** (petición → fase → ejecución → posible fallo → recuperación, todo dentro del `emit_signal`). El controlador debe apagar el input **antes** de emitir: una recuperación lo reactiva dentro de esa llamada y apagarlo después lo dejaría bloqueado.
4. **Los parches «buscar → sustituir» deben usar anclas de una línea.** Las de varias líneas fallan con tabuladores y finales de línea de Windows, y un ancla mal aplicada puede borrar otra línea sin aviso.
5. **La estamina se regenera en tiempo real.** En un combate por turnos eso hace que el resultado de un turno dependa del reloj (la misma pulsación falló por falta de aguante y segundos después funcionó). Es la evidencia a favor de IA-0b (tareas 1 y 2).
6. `skill_failed` también salta con las skills de exploración. Las señales que `Combat` reenvía deben filtrarse por estado de juego.

## Pendientes

- **`DISARMED` del jugador:** sin probar (no hay forma natural de provocarlo con los datos actuales). Hoy consume el turno.
- **Loot tras la victoria:** no aparece. **No depende de IA-0a** (el loot usa sus propios datos y el catálogo de definiciones). Causa: `CombatLootSpawner.spawn_pending_loot()` solo se llama desde `scenes/exploration/exploration_test.gd` (escena de prueba, líneas 25, 388 y 397); ninguna escena de producción la invoca. Además, `combat_loot_bag_spawned` solo lo escucha esa misma escena de prueba (`_on_combat_loot_bag_spawned`), así que tampoco hay nadie que cree la bolsa visible. Falta decidir dónde se llama en el flujo real (al volver a exploración tras la escena narrativa de victoria) y quién la crea.
- `_last_attacker` con datos **durante** el combate: solo se comprobó que queda vacío al terminar.
- Los fallos de acción de enemigos y companions no tienen gestor: el turno puede quedar a la espera. Lo resolverá la IA (reintento con candidatas nuevas) a partir de IA-1.

## Observaciones para fases posteriores

- **Equilibrio (IA-5):** `armor_rating = 12` del jugador y de Mira convierte todo daño enemigo (4,7–6,6) en el mínimo de 1,0. Los combates duran 12–22 rondas y los enemigos no amenazan. Afecta a cualquier estimación de amenaza.
- El HUD que emite `combat_action_requested` directamente (`ui/combat/combat_hud.gd`) no pasa por el controlador del jugador: para esos botones solo cuenta la recuperación de `GameLoop`.
- `Skills.can_use` no comprueba `is_unlocked`: una skill con `requires_unlock` aún bloqueada podría usarse.
- El jugador no tiene registrada `skill.attack.stunning_blow` aunque la tecla 3 apunta a ella (da `SKILL_NOT_FOUND`).
- No se ha añadido `INVALID_TARGET`: un enemigo que apunte a alguien a 0 PV hoy completa su turno sin daño; con un fallo se colgaría hasta que la IA sepa reintentar.
