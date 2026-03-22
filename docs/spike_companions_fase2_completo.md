# Spike — Sistema de Companions: Fase 2

**Fecha de inicio:** 2026-03-20  
**Fecha de cierre:** 2026-03-22  
**Estado:** ✅ COMPLETADA Y VERIFICADA  
**Dependencia:** Fase 1 (PartyManager, CompanionAI básica, registro en sistemas)

---

## Resumen ejecutivo

La Fase 2 completa el sistema de companions iniciado en Fase 1. Cubre movimiento orgánico con navegación, progresión de skills, gestión de equipamiento desde una pantalla de party, estrategias de IA configurables, mecánica de last stand / game over, y la integración del sprite definitivo de Mira con una arquitectura de escenas reutilizable para futuros companions.

---

## Subfases completadas

| Subfase | Feature | Estado |
|---------|---------|--------|
| 2.2 | Seguimiento con NavigationAgent2D | ✅ |
| 2.3 | Progresión de skills para companions | ✅ |
| 2.4 | Pantalla de equipamiento de party | ✅ |
| 2.5 | Estrategias de IA configurables | ✅ |
| 2.6 | Last stand y Game Over | ✅ |
| 2.7 | Assets y escenas de companions | ✅ |

---

## Subfase 2.2 — Seguimiento con NavigationAgent2D

### Objetivo

Reemplazar el seguimiento lineal por lerp por movimiento que respeta la geometría del mapa usando el sistema de navegación de Godot 4.

### Cambios

`CompanionFollowNode` pasó de extender `Node2D` a `CharacterBody2D`, permitiendo `move_and_slide()` y el agente de navegación.

En `_ready()` se detecta si hay un `NavigationRegion2D` en la escena. Si lo hay, activa modo navegación. Si no, cae automáticamente al modo lerp (degradación elegante).

**Offsets de formación:**
```
Índice 0: Vector2(-32,  16)  ← izquierda-atrás
Índice 1: Vector2( 32,  16)  ← derecha-atrás
Índice 2: Vector2(  0,  28)  ← centro-más-atrás
```

**Configuración requerida para activar navegación:**
1. Añadir `NavigationRegion2D` en la escena de exploración
2. Crear `NavigationPolygon` cubriendo el área caminable
3. Hacer Bake del polígono
4. Añadir el nodo al grupo `"navigation_region"`

**Archivos modificados:** `scenes/exploration/companion_follow_node.gd`

---

## Subfase 2.3 — Progresión de skills para companions

### Objetivo

Que los companions generen ticks de progresión y accedan a tiradas de mejora al final del combate, igual que el jugador.

### Bugs corregidos

**Bug 1 — `combat_system.gd` · `_on_skill_used()`**  
Guard `if entity_id == PLAYER_ID` impedía notificar al servicio de progresión cuando un companion usaba una skill. Reemplazado por check `Party.is_in_party(entity_id)`.

**Bug 2 — `skill_progression_service.gd` · `notify_skill_outcome()`**  
Segundo guard con `PLAYER_ID` en el propio servicio. Mismo fix.

**Bug 3 — `skill_progression_service.gd` · `_on_combat_ended()`**  
Solo procesaba `_process_improvement_rolls(PLAYER_ID)`. Fix: iterar también `party.get_active_members()`.

**Bug 4 — `skill_progression_service.gd` · `_reset_all_combat_state()`**  
Usaba `_skill_system.list_skills()` (lista global) en lugar de `_character_system.list_known_skills(entity_id)`. Al procesar el reset del jugador se borraban los ticks de Mira.

**Archivos modificados:** `core/combat/combat_system.gd`, `core/skills/skill_progression_service.gd`

### Comportamiento resultante

- Companions generan ticks por uso exitoso de skills en combate
- Anti-grinding, pity system y cap de ticks aplican por entidad de forma independiente
- Las tiradas de mejora al final del combate aplican a jugador + todos los companions activos

**Log de verificación:**
```
[SkillProgressionService] [player] skill.attack.ranged: no improvement (roll 2 vs threshold 56)
[SkillProgressionService] [companion_mira] skill.attack.light IMPROVED: 40 → 42 (roll 47 vs threshold 46)
```

---

## Subfase 2.4 — Pantalla de equipamiento de party

### Objetivo

Permitir gestionar el equipamiento y la mochila de cada companion desde una pantalla dedicada accesible con tecla `P`.

### Layout

```
┌─────────────────────────────────────────┐
│  PARTY                              [X] │
├──────────────────┬──────────────────────┤
│  Jugador         │  < Mira >            │
│  [head][body][…] │  [head][body][…]     │
│  Mochila         │  Mochila             │
│  [·][·][·][·]    │  [·][·][·][·]        │
└──────────────────┴──────────────────────┘
```

Navegación `<` / `>` entre companions si hay más de uno en el grupo.

### Decisiones de diseño

- Se abre como overlay en `EXPLORATION` sin cambio de `GameState`, igual que el inventario
- Reutiliza `ItemSlot` y `EquipSlot` existentes sin modificaciones
- Drop en columna contraria → transferencia automática entre inventarios vía `_transfer_item(from, to, item_id)`
- `InventorySystem` y `EquipmentManager` ya registraban companions en `PartyManager._register_in_systems()` — sin cambios en sistemas core

**Archivos nuevos:** `ui/party/party_ui.gd`, `ui/party/party_ui.tscn`  
**Archivos modificados:** `core/scene_orchestrator.gd`, `scenes/exploration/exploration_controller.gd`, `project.godot`

---

## Subfase 2.5 — Estrategias de IA configurables

### Objetivo

Reemplazar la IA hardcodeada por un sistema de estrategias seleccionables en tiempo de ejecución desde la `PartyUI`.

### Estrategias

| Estrategia | Selección de skill | Selección de target |
|------------|--------------------|---------------------|
| `AGGRESSIVE` | Ataque SINGLE_ENEMY preferido | Enemigo con menor HP |
| `DEFENSIVE` | Ataque principal | Enemigo con mayor HP |
| `AREA_FOCUS` | Skill de área si disponible, si no ataque principal | Cualquier enemigo |
| `BERSERKER` | Skill con mayor coste de stamina | Enemigo con menor HP |

### Arquitectura

El enum `CompanionStrategy` vive en `PartyManager` y es accesible globalmente como `Party.CompanionStrategy.X`. `CompanionAI` consulta `Party.get_strategy(companion_id)` en cada turno — no almacena la estrategia localmente, por lo que un cambio desde `PartyUI` tiene efecto inmediato.

La estrategia se persiste en `PartyManager.get_save_state()` con fallback a `AGGRESSIVE` para saves anteriores.

**Archivos modificados:** `core/companions/party_manager.gd`, `core/companions/companion_ai.gd`, `ui/party/party_ui.gd`

---

## Subfase 2.6 — Last Stand y Game Over

### Objetivo

Cuando el jugador cae a 0 HP, los companions continúan luchando. Victoria → jugador rescatado. Derrota total → pantalla de Game Over.

### Estado nuevo: `PLAYER_INCAPACITATED`

Se añadió al enum `TurnPhase` como fase explícita en lugar de hackear el grafo existente. Esto permite transiciones limpias y prepara el terreno para `ENEMY_INCAPACITATED` (stuns/derribos futuros).

**Grafo de fases actualizado:**
```
ROUND_START → PLAYER_TURN_START → PLAYER_ACTION_SELECT → PLAYER_ACTION_RESOLVE
                    ↓ (si incapacitado)
             PLAYER_INCAPACITATED → COMPANION_ACTION_RESOLVE → ENEMY_TURN_START → ...
```

### Flujos

**Last stand → victoria:**
```
Jugador HP=0 → _incapacitate_player() → flag.player_downed
Turno siguiente: PLAYER_TURN_START → PLAYER_INCAPACITATED (skip, sin input)
Companion elimina último enemigo → _resolve_last_stand_victory()
Jugador recupera 1 HP, flag borrado → end_combat("victory")
```

**Last stand → derrota:**
```
Jugador incapacitado → Enemies retargetean a companions (_pick_target)
Todos los companions caen → all_incapacitated() == true
end_combat("defeat") → SceneOrchestrator._show_game_over()
```

### Cambios clave

- `_apply_damage()` en `CombatSystem`: ignora daño a entidades ya a 0 HP (evita spam de eventos)
- `_incapacitate_player()` es idempotente (guard al inicio)
- `EnemyAI._pick_target()`: jugador primero si está vivo, sino primer companion activo
- `flag.player_downed`: persiste si hay derrota, se limpia en rescate o nueva partida

**Señales nuevas en `event_bus.gd`:**
```gdscript
signal player_incapacitated()
signal player_rescued_by_companions()
```

**Archivos nuevos:** `ui/game_over_ui.gd`, `ui/game_over_ui.tscn`  
**Archivos modificados:** `core/game_loop_system.gd`, `core/combat/combat_system.gd`, `core/combat/enemy_ai.gd`, `core/event_bus.gd`, `core/scene_orchestrator.gd`

**Log de verificación:**
```
[GameLoopSystem] 💀 Player incapacitated — last stand begins
[GameLoopSystem] Player incapacitated — skipping to PLAYER_INCAPACITATED
[CompanionAI] companion_mira → skill.attack.light on enemy_5
[GameLoopSystem] ✨ Player rescued by companions — revived with 1 HP
[GameLoopSystem] Combat ended: victory
```

---

## Subfase 2.7 — Assets y escenas de companions

### Objetivo

Integrar el sprite definitivo de Mira y establecer una arquitectura de escenas reutilizable para todos los companions futuros.

### Problema con la implementación anterior

La primera versión construía `SpriteFrames` en `_ready()` via `AtlasTexture` por código. Esto causaba un artefacto visual: los frames se desplazaban lateralmente en lugar de cortarse limpiamente, porque Godot interpola entre regiones de atlas durante la transición de frame.

### Solución: escenas heredadas

```
scenes/companions/
├── companion_base.tscn    ← CharacterBody2D + NavigationAgent2D + CollisionShape2D
└── companion_mira.tscn    ← hereda base, AnimatedSprite2D configurado en editor
```

`companion_follow_node.gd` se convierte en script de lógica pura — busca un nodo `"AnimatedSprite"` por nombre en `_ready()` y lo usa si existe. Sin ese nodo funciona igual sin visuales.

### Especificaciones del spritesheet de Mira

| Propiedad | Valor |
|-----------|-------|
| Resolución | 1408 × 768 px |
| Grid | 4 columnas × 4 filas |
| Frame | 352 × 192 px |
| Formato | PNG RGBA |
| Fila 0 | walk_down |
| Fila 1 | walk_up |
| Fila 2 | walk_left |
| Fila 3 | walk_right |
| FPS animación | 8 |
| Scale en escena | 0.25 |

**Ruta:** `res://data/characters/portrait/mira_sprite.png`  
**Nota:** El sprite debe estar centrado dentro de cada frame (recentrado en GIMP antes de importar).

### Naming convention para companions futuros

`exploration_test._spawn_companion_node()` busca automáticamente `res://scenes/companions/companion_<nombre>.tscn`. Si no existe, usa `companion_base.tscn` como fallback. Para añadir un companion nuevo basta crear su escena siguiendo el mismo patrón — sin cambios en código.

### Cómo añadir un companion futuro

1. Preparar spritesheet centrado (mismo layout 4×4)
2. Copiar a `res://data/characters/portrait/<nombre>_sprite.png`
3. Crear `scenes/companions/companion_<nombre>.tscn` heredando `companion_base.tscn`
4. Añadir `AnimatedSprite2D` con nombre `"AnimatedSprite"` y configurar frames en editor
5. Crear `data/characters/companions/companion_<nombre>.tres` (CharacterDefinition)
6. Crear evento narrativo `EVT_COMPANION_<NOMBRE>_JOINS` en `narrative_events.json`

No se requiere ningún cambio en sistemas core.

**Archivos nuevos:** `scenes/companions/companion_base.tscn`, `scenes/companions/companion_mira.tscn`  
**Archivos modificados:** `scenes/exploration/companion_follow_node.gd`, `scenes/exploration/exploration_test.gd`

---

## Mapa completo de archivos modificados

| Archivo | Subfases | Tipo |
|---------|----------|------|
| `scenes/exploration/companion_follow_node.gd` | 2.2, 2.7 | Reescritura completa |
| `scenes/exploration/exploration_test.gd` | 2.7 | `_spawn_companion_node` |
| `core/combat/combat_system.gd` | 2.3, 2.6 | Guards progresión + daño a 0 HP |
| `core/combat/enemy_ai.gd` | 2.6 | `_pick_target()` |
| `core/skills/skill_progression_service.gd` | 2.3 | 4 bugs corregidos |
| `core/companions/party_manager.gd` | 2.5 | Enum estrategias + save/load |
| `core/companions/companion_ai.gd` | 2.5, 2.6 | Estrategias + skip si incapacitado |
| `core/game_loop_system.gd` | 2.6 | `PLAYER_INCAPACITATED` + last stand |
| `core/scene_orchestrator.gd` | 2.4, 2.6 | Party overlay + Game Over |
| `core/event_bus.gd` | 2.6 | 2 señales nuevas |
| `scenes/exploration/exploration_controller.gd` | 2.4 | Tecla P |
| `ui/party/party_ui.gd` | 2.4, 2.5 | Nuevo + estrategia |
| `ui/party/party_ui.tscn` | 2.4 | Nuevo |
| `ui/game_over_ui.gd` | 2.6 | Nuevo |
| `ui/game_over_ui.tscn` | 2.6 | Nuevo |
| `scenes/companions/companion_base.tscn` | 2.7 | Nuevo |
| `scenes/companions/companion_mira.tscn` | 2.7 | Nuevo |
| `project.godot` | 2.4 | Action `open_party` |

---

## Extensibilidad futura

- **Stun / derribo de enemigos:** añadir `ENEMY_INCAPACITATED` con el mismo patrón entre `ENEMY_TURN_START` y `ENEMY_ACTION_RESOLVE`
- **Resurrecciones narrativas:** `flag.player_downed` permite que NPCs reaccionen o que habilidades/ítems restauren al jugador durante el last stand
- **Penalización por caída:** modificar `_resolve_last_stand_victory()` para aplicar debuffs temporales
- **Override manual de IA:** en `CompanionAI`, antes de llamar `_pick_best_skill()`, comprobar si hay una acción pendiente en `PartyManager` (cola de órdenes manuales)
- **Nuevos companions:** naming convention `companion_<nombre>.tscn` + `CharacterDefinition` + evento narrativo — sin cambios en sistemas core
