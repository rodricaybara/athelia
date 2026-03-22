# Spike — Companions Fase 2.6: Last Stand y Game Over

**Fecha:** 2026-03-22  
**Estado:** ✅ COMPLETADA Y VERIFICADA  
**Dependencias:** Fase 2.1–2.5 (companions sistema completo)

---

## Objetivo

Implementar la mecánica de **last stand**: cuando el jugador cae a 0 HP durante el combate, los companions activos continúan luchando. Si ganan, el jugador es rescatado. Si todos caen, aparece la pantalla de Game Over.

---

## Decisiones de diseño

### Estado `PLAYER_INCAPACITATED` como fase de turno

En lugar de hackear el grafo de fases existente, se añadió `PLAYER_INCAPACITATED` como fase explícita. Esto permite:
- Transiciones limpias y validadas
- Posibilidad futura de `ENEMY_INCAPACITATED` para stuns/derribos
- El `PlayerCombatController` nunca recibe `PLAYER_ACTION_SELECT` → input bloqueado por diseño

Grafo de fases actualizado:
```
ROUND_START → PLAYER_TURN_START → PLAYER_ACTION_SELECT → PLAYER_ACTION_RESOLVE
                    ↓ (si incapacitado)
             PLAYER_INCAPACITATED → COMPANION_ACTION_RESOLVE → ENEMY_TURN_START → ...
```

### Daño ignorado a 0 HP + retarget de enemigos

Dos guards separados con responsabilidades distintas:
- `_apply_damage()` en `CombatSystem`: ignora daño a entidades ya a 0 HP (evita spam de eventos)
- `EnemyAI._pick_target()`: selecciona al jugador si está vivo, sino al primer companion activo

Se separaron deliberadamente para mantener `CombatSystem` agnóstico sobre quién vive o muere, y dejar la lógica de targeting en `EnemyAI`.

### Flag narrativo `flag.player_downed`

Se activa al incapacitarse el jugador y se limpia al ser rescatado. Persiste si el combate termina en derrota. Preparado para uso narrativo futuro (ej: NPC que comenta la caída del jugador, penalizaciones de reputación, etc.).

---

## Archivos modificados

### `core/game_loop_system.gd`

**Enum `TurnPhase`** — añadido `PLAYER_INCAPACITATED`:
```gdscript
enum TurnPhase {
    ROUND_START,
    PLAYER_TURN_START,
    PLAYER_ACTION_SELECT,
    PLAYER_ACTION_RESOLVE,
    PLAYER_INCAPACITATED,       # NUEVO
    COMPANION_ACTION_RESOLVE,
    ENEMY_TURN_START,
    ENEMY_ACTION_RESOLVE,
    TURN_END,
    ROUND_END
}
```

**`_can_transition()`** — transiciones nuevas añadidas:
```gdscript
TurnPhase.PLAYER_TURN_START: [TurnPhase.PLAYER_ACTION_SELECT,
                               TurnPhase.PLAYER_INCAPACITATED],
TurnPhase.PLAYER_INCAPACITATED: [TurnPhase.COMPANION_ACTION_RESOLVE,
                                  TurnPhase.ENEMY_TURN_START],
```

**`_start_player_turn()`** — skip limpio vía nueva fase:
```gdscript
func _start_player_turn() -> void:
    _transition_to_phase(TurnPhase.PLAYER_TURN_START)
    await get_tree().process_frame

    if _is_player_incapacitated():
        print("[GameLoopSystem] Player incapacitated — skipping to PLAYER_INCAPACITATED")
        _transition_to_phase(TurnPhase.PLAYER_INCAPACITATED)
        if not _check_combat_conditions():
            var party: Node = get_node_or_null("/root/Party")
            if party and party.has_companions():
                _start_companion_turns()
            else:
                _start_enemy_turns()
        return

    EventBus.emit_signal("player_turn_started")
    print("[GameLoopSystem] 👤 Player turn started")
    _transition_to_phase(TurnPhase.PLAYER_ACTION_SELECT)
```

**`_on_character_died()`** — jugador tratado como incapacitado (no se borra de turn_order):
```gdscript
# Jugador incapacitado
if character_id == PLAYER_ID:
    _incapacitate_player()
    if _check_combat_conditions():
        return
    EventBus.emit_signal("turn_phase_changed", TurnPhase.ENEMY_TURN_START)
    return
```

**Métodos nuevos:**
```gdscript
func _incapacitate_player() -> void:
    if _is_player_incapacitated():
        return  # idempotente
    print("[GameLoopSystem] 💀 Player incapacitated — last stand begins")
    Narrative.set_flag("flag.player_downed")
    EventBus.player_incapacitated.emit()

func _is_player_incapacitated() -> bool:
    return Resources.get_resource_amount(PLAYER_ID, "health") <= 0

func _resolve_last_stand_victory() -> void:
    print("[GameLoopSystem] ✨ Player rescued by companions — revived with 1 HP")
    Resources.set_resource(PLAYER_ID, "health", 1.0)
    Narrative.clear_flag("flag.player_downed")
    EventBus.player_rescued_by_companions.emit()
```

**`_check_combat_conditions()`** — victoria en last stand:
```gdscript
# Victoria con jugador incapacitado — companions salvaron el combate
if active_enemies.is_empty():
    if current_game_state == GameState.COMBAT_ACTIVE:
        if _is_player_incapacitated():
            _resolve_last_stand_victory()
        end_combat("victory")
    return true
```

---

### `core/combat/combat_system.gd`

**`_apply_damage()`** — guard al inicio:
```gdscript
func _apply_damage(target_id: String, damage: float, ...) -> void:
    # No aplicar daño a entidades ya a 0 HP
    if Resources.get_resource_amount(target_id, "health") <= 0:
        print("[CombatSystem] %s already at 0 HP — damage ignored" % target_id)
        return
    # ... resto sin cambios
```

---

### `core/combat/enemy_ai.gd`

**`_decide_and_act()`** — usa `_pick_target()` en lugar de `PLAYER_ID` hardcodeado:
```gdscript
func _decide_and_act() -> void:
    var target := _pick_target()
    if target.is_empty():
        print("[EnemyAI] %s: no valid target — skipping" % enemy_id)
        EventBus.emit_signal("combat_action_completed", {"skipped": true})
        return
    var action_data = {
        "actor": enemy_id,
        "skill_id": attack_skill_id,
        "target": target
    }
    EventBus.emit_signal("player_action_requested", action_data)

func _pick_target() -> String:
    # Jugador primero si está vivo
    if Resources.get_resource_amount(PLAYER_ID, "health") > 0:
        return PLAYER_ID
    # Si no, primer companion activo
    var party: Node = Engine.get_main_loop().root.get_node_or_null("/root/Party")
    if party:
        for companion_id in party.get_active_members():
            if Resources.get_resource_amount(companion_id, "health") > 0:
                return companion_id
    return ""
```

---

### `core/event_bus.gd`

Señales nuevas:
```gdscript
signal player_incapacitated()
signal player_rescued_by_companions()
```

---

### `ui/game_over_ui.gd` + `ui/game_over_ui.tscn` (archivos nuevos)

Panel de Game Over con botón "Nueva partida":
- Limpia estado narrativo (`Narrative.clear_all()`, `Checkpoints.reset()`)
- Limpia el grupo (`Party` — elimina todos los companions)
- Cambia escena a exploración

---

### `core/scene_orchestrator.gd`

- Constante `OVERLAY_GAME_OVER = "res://ui/game_over_ui.tscn"`
- Conecta `EventBus.player_incapacitated` → muestra mensaje HUD
- En `_on_combat_ended("defeat")` → `_show_game_over()`

---

## Flujos verificados

### Last stand → victoria
```
Jugador cae (HP=0)
  → _incapacitate_player(): flag.player_downed, player_incapacitated emitido
  → Turno siguiente: PLAYER_TURN_START → PLAYER_INCAPACITATED (skip)
  → Companion actúa, elimina último enemigo
  → _resolve_last_stand_victory(): HP=1, flag borrado
  → end_combat("victory") → exploración
```

### Last stand → derrota
```
Jugador cae (HP=0)
  → Last stand activo
  → Enemigos retargetean a companions (_pick_target)
  → Companion cae → Party.set_incapacitated()
  → all_incapacitated() == true → end_combat("defeat")
  → SceneOrchestrator._show_game_over()
  → Pantalla Game Over → Nueva partida
```

### Daño ignorado (idempotencia)
```
Enemigo ataca jugador a 0 HP
  → _apply_damage(): "already at 0 HP — damage ignored"
  → No se emite character_died de nuevo
  → _incapacitate_player() es idempotente (guard al inicio)
```

---

## Log de verificación

```
[GameLoopSystem] 💀 Player incapacitated — last stand begins
[SceneOrchestrator] Player incapacitated — last stand active
[GameLoopSystem] Player incapacitated — skipping to PLAYER_INCAPACITATED
[CompanionAI] companion_mira → skill.attack.light on enemy_5
[GameLoopSystem] All enemies defeated!
[GameLoopSystem] ✨ Player rescued by companions — revived with 1 HP
[GameLoopSystem] Combat ended: victory
```

---

## Extensibilidad futura

- **Stun/derribo de enemigos**: añadir `ENEMY_INCAPACITATED` con el mismo patrón entre `ENEMY_TURN_START` y `ENEMY_ACTION_RESOLVE`
- **Resurrecciones narrativas**: `flag.player_downed` permite que NPCs reaccionen o que habilidades/ítems restauren al jugador durante el last stand
- **Penalización por caída**: modificar `_resolve_last_stand_victory()` para aplicar debuffs, reducir stamina máxima temporalmente, etc.
- **Targeting de enemigos más sofisticado**: `_pick_target()` en `EnemyAI` puede extenderse con prioridades (companion con menor HP, el que más daño hace, etc.)
