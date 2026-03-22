# Spike — Companions Fase 2.7: Assets y Escenas de Companions

**Fecha:** 2026-03-22  
**Estado:** ✅ COMPLETADA Y VERIFICADA  
**Dependencias:** Fase 2.2 (NavigationAgent2D), Fase 2.6 (last stand)

---

## Objetivo

Integrar el sprite definitivo de Mira y establecer una arquitectura de escenas reutilizable para todos los companions futuros, eliminando la construcción de sprites por código.

---

## Decisiones de diseño

### Escenas por companion en lugar de código

La primera implementación construía `SpriteFrames` en `_ready()` vía `AtlasTexture` por código. Esto causaba un artefacto visual: los frames se desplazaban lateralmente en lugar de cortarse limpiamente, porque Godot interpola entre regiones de atlas durante la transición de frame.

La solución correcta es delegar la configuración del sprite al editor mediante escenas heredadas:

```
scenes/companions/
├── companion_base.tscn    ← CharacterBody2D + NavigationAgent2D + CollisionShape2D
└── companion_mira.tscn    ← hereda base, añade AnimatedSprite2D configurado en editor
```

Ventajas:
- Las animaciones se configuran visualmente en el editor
- Escala, offset y FPS ajustables sin tocar código
- Añadir un nuevo companion = crear una escena hija, sin cambios en sistemas core
- Sin artefactos de interpolación entre frames

### Separación script / escena

`companion_follow_node.gd` se convierte en script puro de lógica (movimiento, formación, estados). No sabe nada del sprite — busca un nodo `"AnimatedSprite"` por nombre en `_ready()` y lo usa si existe. Si no existe, funciona igual sin visuales (útil para tests).

### Centrado del sprite en GIMP

El spritesheet original tenía el personaje descentrado dentro de cada frame (80×169px de contenido dentro de un frame de 352×192px, con el centro en x=127 en lugar de x=176). En lugar de compensar con `offset` en el editor, se recentra el sprite directamente en GIMP antes de importar. Esto mantiene el `.tscn` limpio y sin valores de compensación hardcodeados.

---

## Especificaciones del spritesheet

| Propiedad | Valor |
|-----------|-------|
| Resolución total | 1408 × 768 px |
| Frames por fila | 4 |
| Filas | 4 |
| Tamaño de frame | 352 × 192 px |
| Formato | PNG con transparencia (RGBA) |
| Fila 0 | walk_down (frente) |
| Fila 1 | walk_up (espalda) |
| Fila 2 | walk_left |
| Fila 3 | walk_right |

**Ruta de destino:** `res://data/characters/portrait/mira_sprite.png`

---

## Archivos nuevos/modificados

### `scenes/exploration/companion_follow_node.gd` (modificado)

Eliminada toda la lógica de construcción de `SpriteFrames`. El script ahora:
- Busca `"AnimatedSprite"` como hijo en `_ready()`
- Llama `_anim_sprite.play(anim_name)` / `_anim_sprite.stop()` según dirección de movimiento
- Emite warning si no encuentra el nodo (no rompe)

Animaciones esperadas: `walk_down`, `walk_up`, `walk_left`, `walk_right`

### `scenes/companions/companion_base.tscn` (nuevo)

Escena base con:
- `CharacterBody2D` + `companion_follow_node.gd`
- `NavigationAgent2D` (avoidance habilitado)
- `CollisionShape2D` (círculo radio 8px)

Sin `AnimatedSprite2D` — cada escena hija añade el suyo.

### `scenes/companions/companion_mira.tscn` (nuevo)

Hereda `companion_base.tscn`. Añade:
- `AnimatedSprite2D` con nombre `"AnimatedSprite"`
- `SpriteFrames` con 4 animaciones × 4 frames configuradas en editor
- `scale = Vector2(0.25, 0.25)` (ajustable en editor)
- Animación por defecto: `walk_down`

### `scenes/exploration/exploration_test.gd` (modificado)

`_spawn_companion_node()` reemplazado:

```gdscript
func _spawn_companion_node(companion_id: String) -> void:
    if get_node_or_null("NPCs/%s" % companion_id):
        return

    var party: Node = get_node_or_null("/root/Party")
    var formation_index: int = party.get_formation_index(companion_id) if party else 0

    # Buscar escena específica, fallback a base genérica
    var scene_path: String = "res://scenes/companions/companion_%s.tscn" % companion_id.replace("companion_", "")
    if not ResourceLoader.exists(scene_path):
        scene_path = "res://scenes/companions/companion_base.tscn"

    var packed: PackedScene = load(scene_path)
    var node: CompanionFollowNode = packed.instantiate() as CompanionFollowNode

    # setup() ANTES de add_child()
    node.setup(companion_id, $Player, formation_index)
    $NPCs.add_child(node)
}
```

El naming convention `companion_<nombre>.tscn` permite añadir companions futuros sin tocar este método.

---

## Preparación del spritesheet en GIMP

Para centrar el personaje dentro de cada frame:

1. Abrir `mira_sprite.png` en GIMP
2. Script-Fu console o manualmente: ampliar lienzo a 1408×768 si hace falta
3. Para cada frame de 352×192px, centrar el contenido visible horizontalmente
4. Exportar como PNG con transparencia
5. Copiar a `res://data/characters/portrait/mira_sprite.png`

Referencia de centrado (medido del spritesheet original):
- Contenido visible: 80×169px por frame
- Centro del contenido en frame original: x=127, y=102
- Centro del frame: x=176, y=96
- Desplazamiento necesario: +49px en X, -6px en Y

---

## Cómo añadir un companion futuro

1. Preparar spritesheet con el mismo layout (4 cols × 4 filas, mismas animaciones)
2. Copiar a `res://data/characters/portrait/<nombre>_sprite.png`
3. Crear `res://scenes/companions/companion_<nombre>.tscn` heredando `companion_base.tscn`
4. Añadir `AnimatedSprite2D` con nombre `"AnimatedSprite"` y configurar frames en editor
5. Crear `res://data/characters/companions/companion_<nombre>.tres` (CharacterDefinition)
6. Crear evento narrativo `EVT_COMPANION_<NOMBRE>_JOINS` en `narrative_events.json`

No se requiere ningún cambio en sistemas core.

---

## Log de verificación

```
[CompanionFollowNode] Setup: companion_mira (index 0)
[CompanionFollowNode] No NavigationRegion2D — using lerp fallback
[ExplorationTest] Companion spawned: companion_mira (scene: companion_mira.tscn)
```

Animación correcta al moverse en las 4 direcciones. Sin artefactos de interpolación entre frames. Incapacitación y recuperación visual funcionales.
