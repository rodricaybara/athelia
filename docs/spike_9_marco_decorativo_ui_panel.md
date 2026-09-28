# Spike 9 — Marco decorativo de ventana (Design System)

**Estado:** CERRADO Y VALIDADO (28 sep 2026) — ver sección «Resultado» al final
**Origen:** Spike aparcado, documentado en
`athelia_pendientes_post_pivote_narrativo.md`, punto 6. Surgido al ver el
panel narrativo con fondo real por primera vez (Grupo 4).
**Riesgo:** Bajo en diseño (ya cerrado), medio en implementación — toca
`UIPanel`, componente compartido por toda la UI del juego, así que un
error aquí tiene alcance amplio, no local a una pantalla.
**A diferencia de los spikes anteriores:** este no es un bug ni una
investigación — es contenido de diseño visual ya cerrado. La sesión puede
ir directa a implementación sin necesidad de maquetar de nuevo, salvo para
el propio recurso de la esquinera (arte, no decisión de diseño).
**Beneficia directamente a:** Spike 11 (arte de la ventana de diálogo), si
`DialoguePanel` usa `UIPanel` como base — heredaría el marco sin trabajo
adicional específico de diálogo.

---

## Contexto

Fernando quiere un marco decorativo para las ventanas del juego, empezando
por el panel narrativo pero reutilizable en cualquier pantalla — no
específico de `NarrativeScenePanel`.

## Decisión de diseño ya tomada

**Variante elegida** (de tres maquetadas): doble filete (borde oscuro
exterior + filete bronce + línea interior tenue) con esquineras
ornamentales — una única imagen pequeña de esquina reutilizada en las 4,
sin estirarse.

**Descartadas:**
- Solo doble filete, sin esquineras
- Marco ilustrado completo estilo 9-slice

## Dónde vive

En el Design System, como opción activable dentro de `UIPanel` — no
específico de `NarrativeScenePanel`. Cualquier `UIPanel` existente o
futuro puede activar el marco sin duplicar lógica.

---

## Alcance

### Implementación del marco
- `ui_panel.gd` / `ui_panel.tscn` — opción activable (flag o parámetro de
  estilo) que añade el marco decorativo a un `UIPanel` existente sin
  romper los que no lo activen
- `ui_tokens.gd`, `make_stylebox()` — generación del stylebox de doble
  filete (colores/grosores como tokens, no hardcodeados, siguiendo la
  convención del Design System)
- Esquineras: una única imagen de esquina, posicionada en las 4 esquinas
  sin estirarse (rotación o 4 variantes de imagen, a decidir según cómo
  esté montado el resto de assets del Design System)

### Recurso de arte pendiente
- La imagen de la esquinera en sí — es arte, no decisión de diseño; si no
  existe todavía, es un bloqueante de implementación real, no de esta
  spec

---

## Preguntas a resolver en la sesión (no de diseño visual, de integración)

1. ¿El marco se activa por defecto en `UIPanel` o es opt-in explícito por
   panel? Dado que hay paneles ya en producción (combate, inventario,
   loadout, menús) que no deberían cambiar de aspecto sin decisión
   explícita, el opt-in parece el default más seguro — confirmar contra
   `ui_panel.gd` real antes de asumirlo.
2. ¿El panel narrativo (`NarrativeScenePanel`) ya usa `UIPanel` como base,
   o tiene su propio `StyleBox` independiente? Si es lo segundo, activar
   el marco ahí no es gratis — hay que migrarlo a usar `UIPanel` primero,
   o replicar el stylebox fuera del componente compartido (menos deseable,
   duplica lógica).

---

## Fuera de alcance
- Aplicar el marco a ninguna pantalla concreta más allá de validar que
  funciona (esa aplicación real al panel narrativo, y luego a diálogo, es
  trabajo de Spike 11 y sesiones posteriores, no de este spike)
- Cualquier pendiente de la recopilación final (sin relación con este
  spike)

## Cierre del spike
Al terminar, actualizar:
- Este documento con el mecanismo real de activación implementado y
  cualquier decisión tomada sobre las dos preguntas de integración
- `athelia_ui_architecture.md` — nuevo componente/opción del Design System
- `athelia_pendientes_post_pivote_narrativo.md` / documentación de
  pendientes

---

## Resultado (cierre del spike)

### Respuestas a las dos preguntas de integración
1. **Activación:** opt-in explícito. `UIPanel.decorative_frame: bool = false`.
   Ningún `UIPanel` existente cambia de aspecto sin activarlo por pantalla.
   Validado: la ventana de inventario se ve idéntica a antes del spike.
2. **¿`NarrativeScenePanel` usa `UIPanel`?** Sí. `narrative_scene_panel.tscn`
   ya instanciaba `ui_panel.tscn` (nodo `Root/UIPanel`). No hubo que migrar
   nada: activar el marco fue marcar la propiedad en el inspector de esa
   instancia. Cero cambios en `narrative_scene_panel.gd`.

### Mecanismo implementado
- **`StyleBoxFlat` no sirve para el doble filete**: solo admite un borde de
  un color. El marco se dibuja con `_draw()` sobre el propio `UIPanel`
  (el motor pinta primero el stylebox del tema y luego `_draw()` encima).
  Sin nodo ni escena nueva: sigue viviendo dentro de `UIPanel`.
- **Propiedades nuevas** (grupo «Marco decorativo (Spike 9)»):
  `decorative_frame: bool = false` y `corner_texture: Texture2D`.
- **Tres filetes concéntricos** con `draw_rect(..., filled=false, width)`,
  cada uno encogido con `Rect2.grow(-(ancho + gap))`.
- **Esquineras:** una única textura pensada para la esquina superior
  izquierda, rotada 0°/90°/180°/270° (se descartaron las 4 variantes de
  imagen). `draw_set_transform(esquina, rotación)` + `draw_texture(tex, ZERO)`
  ancla el origen de la textura en cada esquina y, al rotar, se extiende
  hacia dentro sin offsets manuales. Validado visualmente: las cuatro
  esquinas apuntan hacia dentro.
- **Con el marco activo, el panel anula su propio borde y `corner_radius`**
  (pasan a 0) para no duplicar líneas ni dejar fondo redondeado bajo un
  marco de esquina viva.
- **`resized` → `queue_redraw()`** (solo si el marco está activo).
- **Sin `corner_texture`:** el marco se dibuja solo con los filetes y sale
  un `push_warning` — no bloquea ni rompe nada.

### Tokens nuevos en `ui_tokens.gd`
`COLOR_FRAME_OUTER` (#100E0C), `COLOR_FRAME_FILLET` (= `COLOR_PRIMARY`),
`COLOR_FRAME_INNER` (#4A4030), `FRAME_OUTER_WIDTH` (2), `FRAME_FILLET_WIDTH`
(2), `FRAME_INNER_WIDTH` (1), `FRAME_GAP` (2). Valores iniciales dados por
buenos en playtest; ajustables como tokens si otra pantalla lo pide.

### Recurso de arte
- Generado fuera de la conversación (Gemini, fondo magenta plano, alfa
  retirado después). Ficheros en `res://ui/design_system/assets/frames/`:
  - `frame_corner_64x64.png` — **la que se usa** (asignada en el
    `UIPanel` del panel narrativo)
  - `frame_corner_96x96.png` — conservada de reserva
- Con 96 px la esquinera invadía la primera y las últimas líneas del texto;
  con 64 px las cuatro quedan legibles y no tocan el texto.

### Validación realizada
1. Panel narrativo con `decorative_frame = true` y esquinera 64×64:
   tres filetes + cuatro esquineras correctas.
2. Ventana de inventario sin activar el flag: sin ningún cambio visual.
3. `print` de diagnóstico retirado.

### Lecciones
- Un borde compuesto (varios filetes de color distinto) no cabe en un
  `StyleBoxFlat`: hay que dibujarlo. Las opciones visuales nuevas de un
  componente compartido entran como flag apagado por defecto.
- Ante «no cambia nada», un `print` en `_ready()` con el valor de la
  propiedad separa «el script nuevo no carga» de «el flag no está activo en
  esa instancia» en una sola ejecución (aquí era lo segundo: propiedad
  sin marcar en el `.tscn`).
- La esquinera puede ser mayor que el `padding` por defecto (`SPACE_LG` =
  16): si otra pantalla activa el marco con poco margen interior, la
  esquina puede tapar contenido — se resuelve subiendo el `padding` de
  esa instancia, no tocando el componente.

### Pendiente
- Activar el marco en otras pantallas (diálogo, Spike 11, etc.) es trabajo
  de esas sesiones. Si `DialoguePanel` usa `UIPanel` como base, basta con
  marcar el flag y asignar la esquinera.

---

## Prompt de inicio de sesión

Para arrancar la sesión de este spike, pegar:

```
Vamos a empezar el Spike 9 (marco decorativo de ventana, Design System)
del proyecto Athelia. Especificación adjunta: spike_9_marco_decorativo_ui_panel.md

A diferencia de los spikes anteriores, aquí el diseño visual ya está
cerrado (variante elegida: doble filete + esquineras ornamentales, ver
la spec) — se puede ir directo a implementación. Lo único por resolver
son dos preguntas de integración (activación por defecto vs. opt-in, y si
NarrativeScenePanel ya usa UIPanel como base o tiene su propio StyleBox).

Antes de tocar nada necesito estos ficheros:

- ui_panel.gd / ui_panel.tscn
- ui_tokens.gd (en concreto make_stylebox())
- narrative_scene_panel.gd / .tscn (para confirmar si ya usa UIPanel)

Si la imagen de esquinera aún no existe como asset, dímelo al principio de
la sesión — es un bloqueante de implementación real, no algo que se
resuelva con código.
```
