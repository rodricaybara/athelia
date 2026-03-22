# Companions — Fase 2.5 — Estrategias de IA

## Objetivo

Reemplazar la IA de companions hardcodeada (siempre atacar al enemigo con menor HP
con `skill.attack.light`) por un sistema de estrategias configurables en tiempo de
ejecución, seleccionables desde la `PartyUI`.

## Archivos modificados

| Archivo | Cambio |
|---------|--------|
| `core/companions/party_manager.gd` | Enum `CompanionStrategy`, dict `_strategies`, API `get/set_strategy`, save/load |
| `core/companions/companion_ai.gd` | Lee estrategia de `Party.get_strategy()`, selección dinámica de skill y target |
| `ui/party/party_ui.gd` | `OptionButton` de estrategia en columna companion |

## Estrategias disponibles

| Estrategia | Selección de skill | Selección de target |
|------------|--------------------|---------------------|
| `AGGRESSIVE` | Ataque principal (SINGLE_ENEMY preferido) | Enemigo con **menor HP** |
| `DEFENSIVE` | Ataque principal | Enemigo con **mayor HP** |
| `AREA_FOCUS` | Skill de área si disponible, si no ataque principal | Cualquier enemigo (ref) |
| `BERSERKER` | Skill con mayor coste de stamina disponible | Enemigo con menor HP |

## Arquitectura

### Dónde vive la estrategia

`PartyManager._strategies: Dictionary` — `{ companion_id: CompanionStrategy }`.
Es el único lugar de verdad. No vive en `CharacterDefinition` ni en `CompanionAI`.

```gdscript
# Acceso desde cualquier sistema:
Party.get_strategy("companion_mira")          # → CompanionStrategy.AGGRESSIVE
Party.set_strategy("companion_mira", Party.CompanionStrategy.DEFENSIVE)
```

El enum `CompanionStrategy` está definido en `PartyManager` y es accesible
globalmente como `Party.CompanionStrategy.X` al ser `Party` un autoload.

### Estrategia por defecto

Al unirse al grupo (`join_party()`), el companion recibe `AGGRESSIVE` si no tiene
ya una estrategia asignada (caso de carga de partida).

### Cómo la lee CompanionAI

En cada turno, `CompanionAI._decide_and_act()` consulta `Party.get_strategy(companion_id)`
— no almacena la estrategia localmente. Cambiar la estrategia desde `PartyUI`
tiene efecto inmediato en el siguiente turno.

```gdscript
func _decide_and_act() -> void:
    var strategy: Party.CompanionStrategy = Party.get_strategy(companion_id)
    var skill_id: String = _pick_best_skill(strategy)
    var target: String   = _pick_best_target(skill_id, strategy)
    ...
```

### Selección de skill

`_pick_best_skill(strategy)` delega según estrategia:
- `AREA_FOCUS` → `_pick_area_skill_or_fallback()`: busca `target_type == AREA` o
  `MULTI_ENEMY` entre las skills disponibles del companion; si no hay, cae a ataque principal.
- `BERSERKER` → `_pick_heaviest_skill()`: itera skills de combate disponibles y
  devuelve la de mayor coste de stamina.
- El resto → `_pick_primary_attack()`: prioriza skills con `target_type == SINGLE_ENEMY`
  entre los ataques disponibles.

En todos los casos se verifica que la skill esté desbloqueada y sin cooldown
(`instance.is_available()`).

### Selección de target

`_pick_best_target(skill_id, strategy)`:
- Si la skill es `AREA` → cualquier enemigo vivo como referencia.
- `DEFENSIVE` → `_pick_strongest_enemy()` (mayor HP).
- El resto → `_pick_weakest_enemy()` (menor HP).

### PartyUI — selector de estrategia

`OptionButton` en la columna del companion, poblado con `Party.CompanionStrategy.keys()`.
Se actualiza al cambiar de companion (`_refresh_companion_column`) y al abrir el panel.

```gdscript
func _on_strategy_selected(index: int) -> void:
    if _current_companion.is_empty():
        return
    Party.set_strategy(_current_companion, index as Party.CompanionStrategy)
```

La señal se desconecta y reconecta en `_ready()` para evitar duplicados al
reinstanciar el overlay (`SceneOrchestrator` destruye y recrea el panel en cada apertura).

## Persistencia

`PartyManager.get_save_state()` incluye el campo `strategy` por companion:

```gdscript
members_data.append({
    ...
    "strategy": _strategies.get(companion_id, CompanionStrategy.AGGRESSIVE),
    ...
})
```

`load_save_state()` lo restaura con fallback a `AGGRESSIVE` si el campo no existe
(compatibilidad con saves anteriores a esta subfase).

## Log de verificación

```
[CompanionAI] companion_mira deciding (strategy: DEFENSIVE)...
[CompanionAI] companion_mira → skill.attack.light on enemy_1
```

Con `AGGRESSIVE` atacaría al enemigo con menor HP; con `DEFENSIVE` ataca al de mayor HP.
