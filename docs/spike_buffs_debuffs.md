# Spike: Sistema de Buffs y Debuffs
**Fecha:** Abril 2026  
**Estado:** ✅ Fase 1 · ✅ Fase 2 · ✅ Fase 3 · ✅ Fase 4  
**Archivos modificados:** `core/combat/combat_system.gd`, `core/combat/skill_roller.gd`, `core/event_bus.gd`  
**Archivos nuevos:** `power_strike.tres`, `bleeding_strike.tres`, `stunning_blow.tres`, `reckless_strike.tres`

---

## Contexto

El sistema de combate de Athelia ya tenía infraestructura básica para buffs (`_active_buffs`, `apply_buff`, `has_buff`, `consume_buff`) pero solo cubría dos casos concretos hardcodeados: `evasion` y `guaranteed_hit`. Este spike extiende el sistema para soportar un catálogo de buffs y debuffs genéricos, data-driven, definidos en los `.tres` de habilidades.

---

## Decisiones de diseño

### 1. Buffs como efectos en el `.tres` de la skill

Los buffs se definen como entradas adicionales en el array `effects` de `SkillDefinition`, con `"type": "BUFF"`. Todo el diseño de una habilidad vive en un único archivo de datos, sin tablas externas.

Estructura estándar:

```gdscript
{
    "type":        "BUFF",
    "buff_type":   "vulnerable",
    "value":       25.0,           # magnitud (% o flat según buff_type)
    "duration":    2,              # turnos. 0 = expires_on:use
    "target":      "target",       # "self" | "target"
    "resource_id": "stamina"       # solo para resource_regen / resource_drain
}
```

### 2. `duration` determina `expires_on` automáticamente

`_process_skill_effects` infiere `expires_on` de `duration`:
- `duration == 0` → `expires_on: "use"` — se consume al activarse
- `duration > 0` → `expires_on: "turn"` — decrementa cada turno

No es necesario escribir `expires_on` en el `.tres`.

### 3. Orden de operaciones en `_on_skill_used`

```
1. Calcular daño         (_process_skill_effects)
2. Aplicar daño          (_apply_damage_by_target_type)
3. Filtrar buffs si el target murió
4. Aplicar buffs         (apply_buff)
```

Garantiza que un buff no afecta al golpe que lo causa y que no se aplican buffs sobre entidades muertas.

### 4. Hooks de tick por entidad

- **Jugador:** `_on_player_turn_started`
- **Enemigos:** `_on_enemy_turn_started` → conectado a `EventBus.enemy_turn_started`
- **Companions:** `_on_companion_turn_started` → conectado a `EventBus.companion_turn_started`

La llamada a `_expire_turn_buffs` en `_on_execute_combat_action` fue eliminada para evitar doble decremento.

### 5. Orden dentro del hook de turno

```
inicio turno → _process_resource_ticks  (aplica efectos)
             → _expire_turn_buffs        (decrementa / elimina)
             → acción de la entidad
```

### 6. `skip_first_tick`

`apply_buff` marca todo buff nuevo con `skip_first_tick: true`. El primer tick real ocurre en el siguiente turno de la entidad afectada, no en el mismo turno en que se aplica.

### 7. `staggered` — feedback UI

Emite `character_staggered` al cancelar la acción. El flujo de turno es idéntico a un fallo normal — `GameLoop` no requiere cambios.

### 8. `disarmed` — validación por tags

Bloquea skills con tags `["attack", "melee", "ranged"]`. No requiere campo nuevo en `SkillDefinition`.

### 9. `critical_bonus` — buff de estado sobre el actor

`critical_bonus` amplía el umbral crítico del actor para **todas sus skills** durante X turnos. No es específico de la skill que lo aplica — es un estado ofensivo temporal del personaje. Si se quiere efecto de un solo uso, basta con `duration: 0` en el `.tres`.

---

## Catálogo implementado

### Fase 1 — Buffs numéricos de daño

| buff_type | target | Efecto |
|-----------|--------|--------|
| `damage_bonus` | self | `damage * (1 + value/100)` |
| `weakened` | self | `damage * (1 - value/100)` |
| `vulnerable` | target | `damage * (1 + value/100)` recibido |
| `damage_reduction` | target | `damage * (1 - value/100)` recibido |
| `precision_up` | self | `skill_value += value` (se consume al usarse) |
| `guaranteed_hit` | self | fuerza SUCCESS en la tirada |
| `evasion` | self | evita el siguiente ataque recibido |

Orden en `_apply_damage`: weakened → damage_bonus → vulnerable → damage_reduction.

### Fase 2 — Ticks de recurso por turno

| buff_type | target | Efecto | Requiere |
|-----------|--------|--------|----------|
| `bleeding` | target | `−value` HP por turno | — |
| `resource_regen` | self | `+value` al recurso por turno | `resource_id` |
| `resource_drain` | target | `−value` al recurso por turno | `resource_id` |

### Fase 3 — Control de acción

| buff_type | target | Efecto |
|-----------|--------|--------|
| `staggered` | target | Cancela la siguiente acción. Emite `character_staggered`. |
| `disarmed` | target | Bloquea skills con tags attack/melee/ranged. Emite `character_disarmed`. |

### Fase 4 — Probabilidad de crítico

| buff_type | target | Efecto |
|-----------|--------|--------|
| `critical_bonus` | self | Umbral crítico = `CRITICAL_THRESHOLD + value`. Afecta a todas las skills del actor durante X turnos. |

---

## Cambios en `combat_system.gd`

### Fase 1
- **`_process_skill_effects`** — parámetro `target_id`, construcción de `buff_data` con `recipient`, `turns_left`, `expires_on`.
- **`_on_skill_used`** — reordenado daño → filtro muerte → buffs.
- **`_apply_damage`** — consulta buffs numéricos tras `damage_after_armor`.
- **`_expire_turn_buffs`** — decremento de `turns_left` en lugar de borrado inmediato.
- **`apply_buff`** — inicialización de `turns_left`, marca `skip_first_tick`.
- **`_get_buff_value`** — nuevo helper.
- **`_on_execute_combat_action`** — eliminada llamada a `_expire_turn_buffs`.

### Fase 2
- **`_ready`** — conexiones a `enemy_turn_started` y `companion_turn_started`.
- **`_on_player_turn_started`** — añadido `_process_resource_ticks(PLAYER_ID)`.
- **`_on_enemy_turn_started`** / **`_on_companion_turn_started`** — nuevos callbacks.
- **`_process_resource_ticks`** — nuevo método para `bleeding`, `resource_regen`, `resource_drain`.
- **`_check_death_after_tick`** — nuevo helper.

### Fase 3
- **`_process_skill_effects`** — `duration == 0` asigna `expires_on: "use"`.
- **`_on_execute_combat_action`** — comprobaciones de `staggered` y `disarmed` al inicio.

### Fase 4
- **`_on_skill_used`** — lee `critical_bonus` con `_get_buff_value` y lo pasa a `SkillRoller.roll_skill`.

---

## Cambios en `skill_roller.gd`

- **`roll_skill`** — nuevo parámetro `critical_bonus: int = 0`. Lo pasa a `_determine_result`. Añade `critical_threshold` al diccionario retornado.
- **`_determine_result`** — nuevo parámetro `critical_bonus: int = 0`. Usa `CRITICAL_THRESHOLD + critical_bonus` como umbral efectivo.

---

## Cambios en `event_bus.gd`

```gdscript
signal character_staggered(entity_id: String)
signal character_disarmed(entity_id: String, skill_id: String)
```

---

## Archivos de datos

| Archivo | Fase | Descripción |
|---------|------|-------------|
| `power_strike.tres` | 1 | DAMAGE 1.5× + `vulnerable` 25% / 2 turnos al objetivo |
| `bleeding_strike.tres` | 2 | DAMAGE 1.0× + `bleeding` 5 HP/turno / 3 turnos al objetivo |
| `stunning_blow.tres` | 3 | DAMAGE 0.8× + `staggered` al objetivo (cancela siguiente acción) |
| `reckless_strike.tres` | 4 | DAMAGE 1.2× + `critical_bonus` +18 umbral / 2 turnos al actor |

---

## Comportamiento verificado

### Fase 1 — `vulnerable`
```
Turno N:   enemy_1 took 26.1 damage        ← sin buff todavía
           Buff applied: vulnerable (2 turns)
Turno N+1: vulnerable: +25% → 32.6 dmg    ← buff activo
Turno N+2: 🔴 Buff expired
```

### Fase 2 — `bleeding`
```
Turno N:   enemy_1 took 17.4 damage        ← skip_first_tick activo
Turno N+1: 🩸 bleeding tick −5.0 HP
Turno N+2: 🩸 bleeding tick −5.0 HP
Turno N+3: 🩸 bleeding tick −5.0 HP
           🔴 Buff expired
```

### Fase 3 — `staggered`
```
Turno N:   enemy_1 took 13.9 damage
           Buff applied: staggered (expires_on: use)
           😵 enemy_1 is staggered — action cancelled
```

### Fase 4 — `critical_bonus`
```
Turno N:   reckless_strike → SUCCESS
           Buff applied: critical_bonus (2 turns)
Turno N+1: 🎯 critical_bonus activo: umbral crítico → 97
           reckless_strike rolled 50 → CRITICAL
           Damage: 41.8 (x2)
Turno N+2: 🔴 Buff expired
```

---

## Pendiente

| buff_type | Motivo |
|-----------|--------|
| `parry_bonus` / `block_guaranteed` | Requieren skill de parada activa en el flujo |
| Buffs reactivos (`counter_ready`, `riposte_ready`) | Requieren infraestructura nueva de evaluación de condiciones |
| `extra_action` | Requiere modificación de `TurnPhase` en `GameLoop` |
