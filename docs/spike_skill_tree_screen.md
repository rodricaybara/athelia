# Athelia — Spike: SkillTreeScreen

## Índice

1. [Objetivo](#objetivo)
2. [Decisiones de diseño](#decisiones-de-diseño)
3. [Arquitectura implementada](#arquitectura-implementada)
4. [Cambios por fichero](#cambios-por-fichero)
5. [Design System](#design-system)
6. [Tokens visuales Athelia](#tokens-visuales-athelia)
7. [Conceptos clave: habilidades, tier y prerequisitos](#conceptos-clave)
8. [Flujo de apertura](#flujo-de-apertura)
9. [Pendiente — fuera de este spike](#pendiente)
10. [Ficheros nuevos y modificados](#ficheros-nuevos-y-modificados)

---

## Objetivo

Implementar la pantalla de árbol de habilidades de Athelia con:
- Vista individual por personaje (jugador y companions)
- Vista comparativa de party
- Integración completa con `SkillSystem`, `SkillProgressionService` y `CharacterSystem`
- Estética Athelia definida y codificada en tokens
- Cumplimiento del Design System (`UIButton`, `UIPanel`, `UITokens`)

---

## Decisiones de diseño

### Organización visual

**Tabla por categorías con progresión horizontal** — filas agrupadas por tier, columnas de izquierda a derecha. Mismo patrón que Darkest Dungeon / Disco Elysium pero con la paleta cálida de BG3.

Alternativas descartadas:
- Árbol jerárquico top-down — rígido en layout, difícil de mantener con datos dinámicos
- Red de nodos libre — legible solo con pocas habilidades, complejo de posicionar desde `.tres`

### Tier

**Inferido de prerequisitos en el ViewModel**, no como campo en `SkillDefinition`.

- Sin prerequisitos → tier 1
- Con prerequisitos → `max(tier de cada prereq directo) + 1`
- Recursivo con límite de profundidad 10

Ventaja: no hay datos extra que mantener sincronizados. El tier emerge solo de la estructura.

### Prerequisitos

Campo `prerequisite_requirements: Dictionary` en `SkillDefinition`:

```gdscript
# Formato: { "skill_id": umbral_porcentaje_int }
prerequisite_requirements = { "espada": 50 }
```

Reemplaza al antiguo `prerequisites: Array[String]`. Un umbral de 0 significa "solo necesita estar desbloqueada, sin mínimo de porcentaje".

Hay dos niveles de bloqueo:

| Campo | Comportamiento |
|---|---|
| `prerequisite_requirements` | Se desbloquea automáticamente al cumplirse |
| `requires_unlock: bool` | Requiere además evento narrativo explícito |

### Subcategoría

Nuevo campo `subcategory` en `SkillDefinition` con valores `MELEE`, `RANGED`, `EXPLORATION`, `DIALOGUE`, `NARRATIVE`, `ENEMY`, `NONE`. Independiente de `mode` — permite mayor granularidad para tabs de UI.

### Un solo screen, dos modos

`SkillTreeScreen` con `SkillTreeViewModel` gestiona ambas vistas:
- **Modo individual** — árbol completo de un personaje, tabs por subcategoría, panel lateral de detalle
- **Modo comparativa** — tabla con filas=habilidades, columnas=personajes. Solo muestra habilidades desbloqueadas por al menos una entidad

### Coste de entrenamiento

**Preparado pero invisible.** `SkillTreeViewModel` expone `training_cost: Dictionary`, vacío por defecto. La View renderiza la sección de coste solo si el diccionario tiene contenido. Cuando se implemente el sistema de costes, los datos llegan desde los `.tres` sin tocar la View.

```gdscript
# SkillDefinition — campo preparado, vacío por ahora
# training_cost = {}
# Futuro: { "gold": 50, "days": 3, "requires_trainer": true }
```

---

## Arquitectura implementada

```
SkillTreeScreen (CanvasLayer)          ← View — nunca accede a sistemas core
└── SkillTreeViewModel (Node hijo)     ← ViewModel — único punto de acceso a sistemas

Sistemas accedidos solo desde ViewModel:
  /root/Skills    (SkillSystem)
  /root/Party     (PartyManager)
  /root/SkillProgression (SkillProgressionService)
```

### Señal única del ViewModel

```gdscript
signal changed(reason: String)
```

| Razón | Cuándo se emite | Qué renderiza la View |
|---|---|---|
| `"opened"` | Al abrir la pantalla | Todo |
| `"entity_changed"` | Cambio de personaje, subcategoría o skill seleccionada | Selector, tabs, skills, detalle |
| `"mode_changed"` | Toggle individual/comparativa | Toggle, skills, comparativa |
| `"filter_changed"` | Cambio de filtro activo | FilterBar, skills |
| `"training_done"` | Entrenamiento ejecutado | Solo panel lateral |
| `"closed"` | Al cerrar | `visible = false` |

### Query centralizada

`SkillSystem.get_entity_skill_snapshot(entity_id)` devuelve un `Array` de `Dictionary` con todo lo que el ViewModel necesita en una sola llamada:

```gdscript
{
  "skill_id":                   String,
  "name_key":                   String,
  "description_key":            String,
  "subcategory":                String,
  "mode":                       String,
  "current_value":              int,       # de CharacterSystem
  "base_success_rate":          int,
  "is_unlocked":                bool,
  "requires_unlock":            bool,
  "has_progression":            bool,
  "prerequisite_requirements":  Dictionary,
  "prereqs_met":                bool,      # calculado en la query
  "missing_prereqs":            Array,
  "effects":                    Array,
  "costs":                      Dictionary,
  "target_type":                String,
  "range_type":                 String,
  "base_cooldown":              float,
  "attribute_weights":          Dictionary,
  "tags":                       Array,
  "training_cost":              Dictionary, # vacío hasta implementar costes
}
```

`prereqs_met` se calcula comparando el `current_value` de cada prereq contra su umbral en `prerequisite_requirements`. La View nunca hace este cálculo.

---

## Cambios por fichero

### `core/skills/skill_definition.gd` — reemplazar completo

**Añadidos:**
- `subcategory: String` con `@export_enum`
- `prerequisite_requirements: Dictionary` — reemplaza `prerequisites: Array[String]`
- Helpers: `has_prerequisites()`, `get_prerequisite_ids()`, `get_prerequisite_threshold()`
- Validación de umbrales en `validate()`
- `duplicate_definition()` actualizado con los nuevos campos

**Eliminado:**
- `prerequisites: Array[String]`

### `core/skills/skill_system.gd` — parche (dos métodos)

**`unlock_skill()` — reemplazado:**
Lee `prerequisite_requirements` en lugar de `prerequisites`. Valida tanto `is_unlocked` del prereq como su `current_value >= threshold`.

**`get_entity_skill_snapshot()` — nuevo:**
Query centralizada para el ViewModel. Calcula `prereqs_met` y `missing_prereqs` internamente consultando `CharacterSystem`.

### `core/scene_orchestrator.gd` — parche (constante + 2 métodos)

```gdscript
const OVERLAY_SKILL_TREE := "res://ui/skill_tree/skill_tree_screen.tscn"

func open_skill_tree(entity_id: String = "player") -> void
func close_skill_tree() -> void
```

Mismo patrón que `open_inventory()` y `open_party()`. Solo válido en estado `EXPLORATION`.

### `scenes/exploration/exploration_hud.gd` — parche (1 método)

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("open_skill_tree"):
        SceneOrchestrator.open_skill_tree("player")
```

**Input Map:** añadir acción `open_skill_tree` con tecla `H`.

### `ui/design_system/tokens/ui_tokens.gd` — ampliado

Añadidas dos familias de tokens que coexisten con la familia original:

**Fondos por profundidad:**
`BG_VOID`, `BG_BASE`, `BG_PANEL`, `BG_SURFACE`, `BG_RAISED`, `BG_SELECTED`

**Bordes por énfasis:**
`BORDER_SUBTLE`, `BORDER_DEFAULT`, `BORDER_PANEL`, `BORDER_ACCENT`, `BORDER_GOLD`

**Texto:**
`TEXT_PRIMARY`, `TEXT_SECONDARY`, `TEXT_MUTED`, `TEXT_GOLD`

**Acentos semánticos:**
`ACCENT_GREEN/_BG/_B`, `ACCENT_AMBER/_BG/_B`, `ACCENT_DANGER/_BG/_B`, `ACCENT_INFO/_BG`

**Radios:**
`RADIUS_CARD` (4px), `RADIUS_PANEL` (6px)

### Ficheros nuevos

| Fichero | Tipo | Descripción |
|---|---|---|
| `ui/skill_tree/skill_tree_viewmodel.gd` | Nuevo | ViewModel completo |
| `ui/skill_tree/skill_tree_screen.gd` | Nuevo | View — modo individual y comparativa |
| `ui/skill_tree/skill_tree_screen.tscn` | Nuevo | Escena — creada en el editor |

---

## Design System

`SkillTreeScreen` es la primera pantalla que cumple el Design System al 100%:

| Regla | Cumplimiento |
|---|---|
| Colores via `UITokens` | ✅ Sin valores hardcodeados |
| `StyleBoxFlat` via `UITokens.make_stylebox()` | ✅ Sin `StyleBoxFlat.new()` directo en la View |
| Botones via `UIButton` instanciado | ✅ `UI_BUTTON.instantiate()` con variante y tamaño |
| Sin acceso a sistemas core desde la View | ✅ Todo pasa por el ViewModel |
| Sin `await` en la View | ✅ Feedback con `SceneTreeTimer` + referencia |

Los botones de navegación (entity selector, tabs, filtros) usan:
- Activo → `UIButton.Variant.PRIMARY` o `SECONDARY`, `Size.SM`
- Inactivo → `UIButton.Variant.GHOST`, `Size.SM`
- Entrenar → `UIButton.Variant.PRIMARY`, `Size.MD`

---

## Tokens visuales Athelia

Paleta completa definida y codificada. Registro visual: **neutro funcional con toques medievales**. Referencia: BG3. Ornamentación: bordes con textura sutil de pergamino. Paleta: marrones y ocres cálidos.

### Técnica de borde doble (pergamino)

Los paneles principales usan dos capas:
- Borde exterior `#5C4E38` (1px) — solidez
- Línea interior `rgba(210,180,130,0.10)` (0.5px via `ColorRect`) — textura de pergamino

En Godot implementado con `_add_bg_rect()` + `_add_border_rect()` en `_apply_panel_styles()`.

### Semántica de color en tarjetas de skill

| Estado | Borde | Fondo |
|---|---|---|
| Normal | `BORDER_DEFAULT` `#3D3830` | `BG_SURFACE` `#252118` |
| Mejorable ahora | `ACCENT_GREEN_B` `#5A7A3A` | `BG_SURFACE` |
| Sugerencia IA | `ACCENT_AMBER_B` `#7A6020` | `BG_SURFACE` |
| Seleccionada | `BORDER_ACCENT` `#8A7050` | `BG_SELECTED` `#332C24` |
| Bloqueada | `BORDER_SUBTLE` `#2A2620` | `BG_SURFACE` + opacidad 45% |

El porcentaje en el panel lateral usa `TEXT_GOLD` `#D4C49A` — único elemento con dorado puro, le da peso visual sin saturar.

---

## Conceptos clave

### Cómo se calculan los tiers

```
_compute_tier(skill_data, snapshot):
  si sin prereqs → 1
  si con prereqs → max(_compute_tier(cada prereq)) + 1
```

El ViewModel calcula esto al construir `skills_by_subcategory`. El resultado es un `Dictionary` `{ tier_int: [skill_data, ...] }` que la View renderiza en orden con separadores entre tiers.

### Cómo se evalúan los prerequisitos

`SkillSystem.get_entity_skill_snapshot()` evalúa en cada llamada:

```gdscript
for prereq_id in definition.prerequisite_requirements.keys():
    var threshold = definition.prerequisite_requirements[prereq_id]
    var prereq_ok = is_skill_unlocked(entity_id, prereq_id)
                    and (threshold == 0 or current_value >= threshold)
    if not prereq_ok:
        prereqs_met = false
        missing_prereqs.append(prereq_id)
```

### Cómo funciona el entrenamiento desde la UI

```
Jugador pulsa "Entrenar"
  → SkillTreeScreen._on_train_pressed()
  → SkillTreeViewModel.request_train_selected_skill()
      → LearningSession.create(entity_id, skill_id, source_level, "PRACTICE")
      → SkillProgressionService.execute_learning_session(session)
          → tirada de mejora inversa (roll > threshold → mejora 1-2%)
      → _refresh_snapshot(entity_id)
      → changed.emit("training_done")
  → SkillTreeScreen._render_detail()  ← muestra nuevo valor
```

`source_level = max(current_value, 20)` — mínimo 20 para no bloquear skills recién desbloqueadas con el anti-grinding.

### Panel lateral — zona fija vs zona dinámica

```
DetailPanel (VBoxContainer)
├── DetailName     ← fijo en .tscn
├── DetailPct      ← fijo en .tscn
├── DetailContent  ← VBoxContainer vaciado con free() en cada render
├── FeedbackLabel  ← fijo en .tscn, visible=false
└── TrainBtn       ← fijo en .tscn
```

`_clear_dynamic_detail()` usa `free()` inmediato (no `queue_free()`) para evitar referencias colgantes dentro del mismo frame al cambiar de tab o skill.

---

## Flujo de apertura

```
Jugador pulsa H
  → ExplorationHUD._unhandled_input("open_skill_tree")
  → SceneOrchestrator.open_skill_tree("player")
      → _show_overlay(OVERLAY_SKILL_TREE)    ← instancia el .tscn
      → _current_overlay.open("player")
          → SkillTreeViewModel.open("player")
              → _load_available_entities()
              → _select_entity("player")
                  → Skills.get_entity_skill_snapshot("player")
                  → _build_skills_by_subcategory()
                  → _update_available_subcategories()
              → changed.emit("opened")
          → SkillTreeScreen._on_vm_changed("opened")
              → visible = true
              → _render_all()

Jugador pulsa H de nuevo / Escape / botón X
  → SkillTreeViewModel.request_close()
  → changed.emit("closed")
  → SkillTreeScreen: visible = false
```

---

## Pendiente — fuera de este spike

| Tema | Notas |
|---|---|
| Sistema de costes de entrenamiento | `training_cost: Dictionary` preparado en snapshot y ViewModel. La View ya tiene la sección condicional. Solo falta definir el sistema y poblar el campo en los `.tres` |
| Sugerencias IA | `_ai_suggestions: Dictionary` preparado en ViewModel. Solo falta el sistema que las genera |
| Límite de companions en party | Sin definir. La vista comparativa usa scroll horizontal si hay muchos |
| Actualizar `.tres` de skills existentes | Añadir `subcategory` a todos los ficheros. Los que no lo tengan aparecen en tab `NONE` |
| Migración de otras pantallas al Design System | `InventoryScreen`, `ShopUI`, `PartyUI` aún usan botones y paneles raw. Migrar pantalla a pantalla |

---

## Ficheros nuevos y modificados

| Fichero | Estado | Acción |
|---|---|---|
| `core/skills/skill_definition.gd` | Modificado | Reemplazar completo |
| `core/skills/skill_system.gd` | Modificado | Parche: `unlock_skill()` + `get_entity_skill_snapshot()` |
| `core/scene_orchestrator.gd` | Modificado | Parche: constante + `open_skill_tree()` + `close_skill_tree()` |
| `scenes/exploration/exploration_hud.gd` | Modificado | Parche: `_unhandled_input()` |
| `ui/design_system/tokens/ui_tokens.gd` | Modificado | Ampliado con tokens Athelia |
| `ui/skill_tree/skill_tree_viewmodel.gd` | Nuevo | ViewModel completo |
| `ui/skill_tree/skill_tree_screen.gd` | Nuevo | View completa |
| `ui/skill_tree/skill_tree_screen.tscn` | Nuevo | Creada en editor |
| `localization/translations.csv` | Modificado | ~50 claves nuevas |

---

*Spike cerrado. Última iteración: fix "previously freed" en DetailPanel al cambiar de tab.*
