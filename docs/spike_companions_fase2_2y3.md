# Companions — Fase 2.2 y 2.3

## Subfase 2.2 — Seguimiento orgánico con NavigationAgent2D

### Objetivo

Reemplazar el seguimiento lineal por lerp por un movimiento que respeta la geometría
del mapa (paredes, obstáculos) usando el sistema de navegación de Godot 4.

### Cambios

**Archivo modificado:** `res://scenes/exploration/companion_follow_node.gd`

El nodo pasó de extender `Node2D` (sin física) a extender `CharacterBody2D`, lo que
permite usar `move_and_slide()` y el agente de navegación.

#### Arquitectura del nuevo CompanionFollowNode

```gdscript
extends CharacterBody2D

var _nav_agent: NavigationAgent2D = null
var _nav_available: bool = false
const FOLLOW_SPEED: float = 115.0
```

En `setup()` se instancia `NavigationAgent2D` como hijo y se activa `avoidance_enabled`
para evitar solapamiento entre companions.

En `_ready()` se llama a `_check_nav_available()`, que busca un `NavigationRegion2D`
en la escena activa (primero por grupo `navigation_region`, luego por tipo). Si lo
encuentra, activa el modo navegación. Si no, cae al modo lerp legacy.

En `_physics_process()` se bifurca:
- **Modo nav:** `_move_with_nav()` actualiza el target del agente y sigue el
  `get_next_path_position()` calculado por el navmesh.
- **Modo lerp:** interpolación directa hacia la posición objetivo, igual que antes.

#### Offsets de formación

```
Índice 0 (primer companion):  Vector2(-32,  16)  ← izquierda-atrás
Índice 1 (segundo companion): Vector2( 32,  16)  ← derecha-atrás
Índice 2 (tercer companion):  Vector2(  0,  28)  ← centro-más-atrás
```

#### Configuración requerida en el editor

Para activar el modo navegación en `ExplorationTest`:

1. Añadir `NavigationRegion2D` como hijo directo de `ExplorationTest`.
2. Crear un `NavigationPolygon` en su inspector.
3. Dibujar el polígono que cubre el área caminable (interior de paredes).
4. Hacer Bake del polígono.

Sin este nodo, `CompanionFollowNode` cae automáticamente al modo lerp y sigue
funcionando (degradación elegante).

#### Log de verificación exitosa

```
[CompanionFollowNode] companion_mira: NavigationRegion2D encontrado → nav activo
```

### Notas de escalado

Para mapas con múltiples salas, añadir un `NavigationRegion2D` por sala — Godot une
automáticamente los bordes que se tocan. Para mapas generados desde TileMap con
colisiones, se puede llamar `nav_region.bake_navigation_polygon()` desde código.

---

## Subfase 2.3 — Evolución de companions: skills y progresión

### Objetivo

Que los companions generen ticks de progresión en combate y accedan a tiradas de
mejora al final de cada combate, exactamente igual que el jugador.

### Bugs corregidos

#### Bug 1 — `combat_system.gd` · `_on_skill_used()`

El bloque `notify_skill_outcome` tenía un guard que solo aceptaba al jugador:

```gdscript
# ANTES (incorrecto)
if entity_id == PLAYER_ID:
    SkillProgression.notify_skill_outcome(...)
```

```gdscript
# DESPUÉS
var party: Node = get_node_or_null("/root/Party")
var is_ally: bool = entity_id == PLAYER_ID or (party != null and party.is_in_party(entity_id))
if is_ally:
    SkillProgression.notify_skill_outcome(
        entity_id,
        skill_id,
        SkillRoller.to_progression_outcome(roll_result.result)
    )
```

#### Bug 2 — `skill_progression_service.gd` · `notify_skill_outcome()`

El propio servicio tenía un segundo guard con `PLAYER_ID`:

```gdscript
# ANTES (incorrecto)
if entity_id != PLAYER_ID:
    return
```

```gdscript
# DESPUÉS
var party: Node = Engine.get_main_loop().root.get_node_or_null("/root/Party")
var is_ally: bool = entity_id == PLAYER_ID or (party != null and party.is_in_party(entity_id))
if not is_ally:
    return
```

#### Bug 3 — `skill_progression_service.gd` · `_on_combat_ended()`

Las tiradas de mejora al final del combate solo se procesaban para el jugador:

```gdscript
# ANTES (incorrecto)
_process_improvement_rolls(PLAYER_ID)
```

```gdscript
# DESPUÉS
_process_improvement_rolls(PLAYER_ID)
var party: Node = get_node_or_null("/root/Party")
if party:
    for companion_id in party.get_active_members():
        _process_improvement_rolls(companion_id)
```

#### Bug 4 — `skill_progression_service.gd` · `_reset_all_combat_state()`

El reset usaba `_skill_system.list_skills()` (lista global de todas las skills
del juego) en lugar de las skills conocidas por la entidad concreta. Esto causaba
que al procesar el reset del jugador se borraran también los ticks de Mira:

```gdscript
# ANTES (incorrecto)
for skill_id in _skill_system.list_skills():
    var instance = _get_skill_instance(entity_id, skill_id)
```

```gdscript
# DESPUÉS
var known_skills: Array[String] = _character_system.list_known_skills(entity_id)
for skill_id in known_skills:
    var instance: SkillInstance = _get_skill_instance(entity_id, skill_id)
    if instance:
        instance.reset_combat_state()
```

#### Mejora cosmética — prints con entity_id

En `_attempt_improvement`, los prints de resultado no identificaban la entidad:

```gdscript
# DESPUÉS
print("[SkillProgressionService] [%s] %s IMPROVED: %d → %d (roll %d vs threshold %d)" % [
    entity_id, skill_id, old_value, new_value, improvement_roll, threshold
])
print("[SkillProgressionService] [%s] %s: no improvement (roll %d vs threshold %d)" % [
    entity_id, skill_id, improvement_roll, threshold
])
# Idem en _get_effective_value para el print de effective_value
```

### Resultado verificado

```
[SkillProgressionService] skill.attack.ranged: tick 1/3          ← player
[SkillProgressionService] skill.attack.light: tick 1/2           ← companion_mira
[SkillProgressionService] skill.attack.ranged: tick 2/3
[SkillProgressionService] skill.attack.light: tick 2/2
[SkillProgressionService] Combat ended (victory) - processing improvement rolls
[SkillProgressionService] [player] skill.attack.ranged: no improvement (roll 2 vs threshold 56)
[SkillProgressionService] [companion_mira] skill.attack.light IMPROVED: 40 → 42 (roll 47 vs threshold 46)
```

### Comportamiento resultante

- Companions generan ticks por uso exitoso de skills en combate.
- El sistema de anti-grinding (source_level / 2) aplica por entidad.
- El pity system (3 fallos consecutivos) aplica por entidad independientemente.
- El cap de ticks por combate (`max_ticks_per_combat`) aplica por entidad.
- El reset de estado de combate es aislado — el reset de una entidad no afecta a otras.
- Las tiradas de mejora al final del combate aplican a todos los aliados activos
  (jugador + companions no incapacitados).

---

## Archivos modificados en Fase 2.2 y 2.3

| Archivo | Subfase | Tipo de cambio |
|---------|---------|----------------|
| `scenes/exploration/companion_follow_node.gd` | 2.2 | Reescritura completa |
| `core/combat/combat_system.gd` | 2.3 | Fix guard en `_on_skill_used` |
| `core/skills/skill_progression_service.gd` | 2.3 | Fix en `notify_skill_outcome`, `_on_combat_ended`, `_reset_all_combat_state`, prints |
