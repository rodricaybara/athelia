# Referencia de buff_type — SkillDefinition.effects

Tabla de referencia para definir efectos BUFF en los `.tres` de habilidades.

---

## Estructura base de un efecto BUFF

```gdscript
{
    "type":        "BUFF",
    "buff_type":   String,   # ver tabla
    "value":       float,    # magnitud (ver columna Valor)
    "duration":    int,      # turnos. 0 = expires_on:use (se consume al activarse)
    "target":      String,   # "self" | "target"
    "resource_id": String    # solo para resource_regen / resource_drain: "health" | "stamina"
}
```

> **Nota:** `expires_on` no se escribe en el `.tres` — se infiere automáticamente de `duration`:
> - `duration == 0` → `expires_on: use` (se consume al activarse)
> - `duration > 0` → `expires_on: turn` (decrementa cada turno)

---

## Buffs de ataque
**Estado: ✅ implementado**

| buff_type | target | value | duration | Efecto | Ejemplo `.tres` |
|-----------|--------|-------|----------|--------|-----------------|
| `damage_bonus` | self | % | > 0 | `damage * (1 + value/100)` | `{"type":"BUFF","buff_type":"damage_bonus","value":20.0,"duration":2,"target":"self"}` |
| `precision_up` | self | flat | 0 | `skill_value += value` antes de tirada, se consume | `{"type":"BUFF","buff_type":"precision_up","value":15.0,"duration":0,"target":"self"}` |
| `guaranteed_hit` | self | — | 0 | fuerza SUCCESS en la tirada, se consume | `{"type":"BUFF","buff_type":"guaranteed_hit","value":0.0,"duration":0,"target":"self"}` |
| `critical_bonus` | self | flat | > 0 | umbral crítico = `2 + value` para todas las skills del actor | `{"type":"BUFF","buff_type":"critical_bonus","value":18.0,"duration":2,"target":"self"}` |

> `critical_bonus` afecta a **todas las skills** del actor durante los turnos que dure, no solo a la que lo aplica. Para efecto de un solo uso, usar `duration: 0`.

---

## Buffs defensivos
**Estado: ✅ implementado** (`damage_reduction`, `evasion`) · **⏳ pendiente** (`parry_bonus`, `block_guaranteed`)

| buff_type | target | value | duration | Efecto | Ejemplo `.tres` |
|-----------|--------|-------|----------|--------|-----------------|
| `damage_reduction` | self | % | > 0 | `damage * (1 - value/100)` tras armor | `{"type":"BUFF","buff_type":"damage_reduction","value":25.0,"duration":2,"target":"self"}` |
| `parry_bonus` | self | flat | 0 | `+value` a skill de parada antes de tirada | `{"type":"BUFF","buff_type":"parry_bonus","value":20.0,"duration":0,"target":"self"}` |
| `block_guaranteed` | self | — | 0 | fuerza bloqueo del siguiente ataque | `{"type":"BUFF","buff_type":"block_guaranteed","value":0.0,"duration":0,"target":"self"}` |
| `evasion` | self | — | 0 | evita el siguiente ataque recibido, se consume | `{"type":"BUFF","buff_type":"evasion","value":0.0,"duration":0,"target":"self"}` |

> `parry_bonus` y `block_guaranteed` — pendientes. Requieren skill de parada activa en el flujo de resolución.

---

## Debuffs
**Estado: ✅ implementado**

| buff_type | target | value | duration | Efecto | Ejemplo `.tres` |
|-----------|--------|-------|----------|--------|-----------------|
| `vulnerable` | target | % | > 0 | `damage * (1 + value/100)` recibido | `{"type":"BUFF","buff_type":"vulnerable","value":25.0,"duration":2,"target":"target"}` |
| `weakened` | target | % | > 0 | `damage * (1 - value/100)` infligido | `{"type":"BUFF","buff_type":"weakened","value":20.0,"duration":2,"target":"target"}` |
| `staggered` | target | — | 0 | cancela la siguiente acción del objetivo | `{"type":"BUFF","buff_type":"staggered","value":0.0,"duration":0,"target":"target"}` |
| `disarmed` | target | — | > 0 | bloquea skills con tags attack/melee/ranged | `{"type":"BUFF","buff_type":"disarmed","value":0.0,"duration":2,"target":"target"}` |

---

## Utilidad / recursos
**Estado: ✅ implementado**

| buff_type | target | value | resource_id | duration | Efecto | Ejemplo `.tres` |
|-----------|--------|-------|-------------|----------|--------|-----------------|
| `resource_regen` | self | flat | `health`\|`stamina` | > 0 | `+value` al recurso por turno | `{"type":"BUFF","buff_type":"resource_regen","value":5.0,"duration":3,"target":"self","resource_id":"stamina"}` |
| `resource_drain` | target | flat | `health`\|`stamina` | > 0 | `-value` al recurso por turno | `{"type":"BUFF","buff_type":"resource_drain","value":8.0,"duration":3,"target":"target","resource_id":"stamina"}` |
| `bleeding` | target | flat | `health` | > 0 | `-value` HP por turno | `{"type":"BUFF","buff_type":"bleeding","value":5.0,"duration":3,"target":"target"}` |

---

## Notas

- `bleeding` no necesita `resource_id` — siempre drena `health`.
- `resource_regen` y `resource_drain` requieren `resource_id` obligatoriamente — sin él el sistema emite warning y omite el tick.
- Los buffs de tick (`bleeding`, `resource_regen`, `resource_drain`) no hacen efecto en el turno en que se aplican (`skip_first_tick`). El primer tick ocurre al inicio del siguiente turno de la entidad afectada.
- `staggered`, `disarmed`, `guaranteed_hit`, `evasion`, `block_guaranteed` no necesitan `value` — se puede omitir o dejar en `0.0`.
- `staggered` emite `character_staggered(entity_id)` al cancelar la acción.
- `disarmed` emite `character_disarmed(entity_id, skill_id)` al bloquear una skill.
- `critical_bonus` es un buff de estado sobre el actor — afecta a todas sus skills mientras esté activo.

---

## Pendiente de implementación

| buff_type | Motivo |
|-----------|--------|
| `parry_bonus` | Requiere skill de parada activa en el flujo de resolución |
| `block_guaranteed` | Requiere skill de parada activa en el flujo de resolución |
| `counter_ready` | Requiere infraestructura de evaluación de condiciones reactivas |
| `riposte_ready` | Requiere infraestructura de evaluación de condiciones reactivas |
| `extra_action` | Requiere modificación de `TurnPhase` en `GameLoop` |
