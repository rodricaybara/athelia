# Spike 11 — Rediseño de la ventana de diálogo (fondo, retrato y estado de ánimo)

**Estado:** Cerrado
**Origen:** Idea 1 surgida tras el pivote narrativo: la ventana de diálogo
sigue en su versión inicial, mínima y sin decoración. Se aplica a ella el
mismo tratamiento que ya recibieron las escenas narrativas (Grupo 4) y el
marco decorativo (Spike 9).
**Riesgo:** Medio. Tiene dos fases muy distintas: una de dirección de arte
(sin tocar el proyecto) y otra de implementación, que depende de lo que la
comprobación de código diga sobre el soporte de retratos en el sistema de
diálogo.
**Depende de:** Spike 9 (marco decorativo de `UIPanel`, cerrado) y Spike 10
(diálogos del sheriff migrados, cerrado).
**Precede a:** Spikes 12/13 (mapa de puntos de interés): esa pantalla
abrirá diálogos con NPCs, así que conviene que la ventana ya esté rediseñada.

---

## Contexto

Estado actual de la ventana, según captura de partida:

- Panel plano oscuro, sin fondo propio ni marco.
- Un sprite de cuerpo entero en pixel art como retrato, cortado por abajo y
  con un cuadrado de fondo de tono distinto; no encaja con el arte pintado
  del resto del juego.
- Un segundo sprite pequeño y semitransparente flotando entre el texto y las
  opciones (resto del diseño original de dos retratos).
- Claves de localización sin traducir visibles: `SPEAKER_SHERIFF` y
  `DLG_SHERIFF_OPT_SAVE` (esta última es la opción de guardar partida).
- La etiqueta de estado dice `EXPLORATION` con el diálogo abierto. Puede ser
  solo la etiqueta de depuración, o indicar que este diálogo no se abrió como
  sub-overlay de una escena narrativa.

## Decisiones de diseño ya tomadas

1. **Un único retrato: el del NPC.** El jugador ya "habla" a través de las
   opciones. Se descarta el layout de dos retratos; si una escena futura lo
   necesita, se amplía entonces.
2. **Marco decorativo** del Spike 9 activado en este panel
   (`decorative_frame = true` + `corner_texture`). Tener en cuenta la lección
   del Spike 9: si la esquinera tapa contenido, se sube el `padding` de esta
   instancia, no se toca el componente.
3. **Fondo propio del panel.** El panel no puede depender de lo que haya
   detrás: en una escena narrativa detrás hay una ilustración, pero abierto
   desde exploración solo hay gris plano.
4. **Retratos cargables según el diálogo, con estado de ánimo del NPC.**
   Fernando cree que el `DialogueSystem` y las definiciones ya contemplan esta
   opción. **No está confirmado**: es la primera comprobación de la Fase 0.

## Propuesta de layout (a validar en la maqueta de la Fase 1)

- Retrato grande a la izquierda, con el busto sobresaliendo un poco por el
  borde superior del panel para dar profundidad.
- Placa con el nombre del hablante sobre el marco y el texto a su derecha.
- Opciones debajo del texto.
- Sin retrato disponible, el panel ocupa todo el ancho, sin hueco.

---

## Fase 0 — Comprobación de código (antes de diseñar el modelo de datos)

Confirmar qué existe hoy, sin asumirlo:

1. ¿`DialogueDefinition`/nodos de diálogo y sus loaders tienen algún campo de
   retrato o de expresión/estado de ánimo? ¿Por diálogo, por nodo o por
   hablante? ¿Lo lee `DialogueSystem` y lo expone al panel, o es un campo
   huérfano que nadie consume (como `grant_item_*` en Spike 10)?
2. Cómo resuelve hoy `DialoguePanel` el retrato y el segundo sprite: de
   dónde salen las texturas y qué controla su visibilidad.
3. Si `DialoguePanel` usa `UIPanel` como base (de eso depende heredar el
   marco casi gratis) y con qué padding.
4. Causa de las dos claves sin traducir: ¿la clave no existe en el `.csv`, no
   coincide con la del JSON, o el `.csv` no está dado de alta en Project
   Settings (lección de Spike 10)?
5. Por qué el estado es `EXPLORATION` con el diálogo abierto: ¿etiqueta de
   depuración o camino distinto de apertura?

**Salida de la fase:** lista de qué existe, qué falta y qué es un cambio de
motor. Si hace falta ampliar el modelo de datos, la decisión se confirma
con Fernando antes de implementar.

## Fase 1 — Dirección de arte (sin tocar el proyecto)

Sesión de diseño, mismo método que el Grupo 4:

- **Maqueta de 2-3 variantes de layout** para elegir antes de escribir código.
- **Fondo del panel:** color, textura o imagen; cómo convive con el marco.
- **Formato del retrato:** busto con transparencia (como los iconos de tipo de
  enemigo del Grupo 4), tamaño en píxeles y contraste sobre el fondo
  elegido. Incluir cómo se ve el busto sobresaliendo del borde.
- **Catálogo de estados de ánimo:** decidir el conjunto pequeño de
  expresiones (por ejemplo, neutral, alegre, serio, enfadado, preocupado)
  y qué NPCs necesitan cuáles. Una expresión neutral siempre existe como
  respaldo.
- **Prompts de generación** para los retratos y el fondo, con el primer de
  estilo ya usado, que Fernando genera fuera de la conversación.

## Fase 2 — Implementación

Según lo que arroje la Fase 0 y la maqueta elegida:

- Retrato resuelto desde datos, nunca hardcodeado, y por línea/nodo cuando el
  estado de ánimo cambie a mitad de conversación.
- Estado de ánimo como dato del diálogo, con respaldo a la expresión neutral
  si falta la imagen concreta, y `push_warning` (no error) si falta el archivo.
- Comportamiento sin retrato: panel a todo el ancho.
- Fondo propio del panel y marco activado.
- Corrección de las claves sin traducir.
- Rediseño con tokens del Design System, sin colores ni tamaños literales.
- Aplicar a `DialoguePanel` el mismo cuidado de `expand_mode` explícito en
  cualquier `TextureRect` de contenido (lección del Grupo 4).

## Fase 3 — Validación

En partida real con el diálogo del sheriff (briefing, recompensa y
entrenamiento): apertura desde escena narrativa y, si existe ese camino,
desde exploración; cambio de expresión a mitad de conversación; hablante sin
retrato; textos localizados; el marco no tapa texto. Comprobar que el rediseño
no rompe el contrato de sub-overlay de Grupo 2 (`signal closed`,
`resume_after_dialogue()`).

---

## Fuera de alcance
- Layout de dos retratos.
- Arte del mapa de puntos de interés (Spikes 12/13).
- Convertir más diálogos o escenas a `DialogueSystem`.
- Cualquier pendiente de la recopilación final.

## Cierre del spike

### Fase 0 — lo que había de verdad
`portrait_id` existía y se consumía (JSON → `DialogueRegistry` →
`DialogueNodeDefinition` → `DialogueSystem` → `EventBus.dialogue_node_shown`
→ `DialogueViewModel` → `DialoguePanel`). No existía ningún campo de ánimo.
Las dos claves crudas (`SPEAKER_SHERIFF`, `DLG_SHERIFF_OPT_SAVE`) eran
huecos reales en `dialogues_scenes_telmori.csv`, ya corregidos. El estado
`EXPLORATION` visto con el diálogo abierto resultó ser una transición
anidada en el arranque (`TelmoriVillage._ready()` disparando la escena
narrativa mientras `_handle_exploration()` seguía instanciando la
`ExplorationScene`), ajena al diálogo — no bloqueaba este spike.

### Modelo de datos — decisión final (opción B, con dos extensiones)
Tres campos nuevos, cada uno con su propia cascada de respaldo, sin romper
diálogos existentes que no los usen:

- **`mood`** (por nodo, en `DialogueNodeDefinition`): `"<portrait_id>_<mood>.png"`
  → `"<portrait_id>.png"` (neutral) → sin retrato. `push_warning` en cada
  salto, nunca falla en silencio.
- **`portrait_folder`** (por diálogo, en `DialogueDefinition`): subcarpeta
  de retratos por aventura — `res://data/characters/portrait/<portrait_folder>/`.
  Vacío = carpeta raíz de retratos (compatible con diálogos previos).
- **`background_id`** (por diálogo, en `DialogueDefinition`): escena de
  fondo dentro de la aventura — `res://data/dialogue/backgrounds/<portrait_folder>/<background_id>.png`,
  con respaldo al fondo genérico de aventura
  `res://data/dialogue/backgrounds/<portrait_folder>.png` si está vacío o
  no existe el archivo.

`dialogue_node_shown` pasó de 4 a 7 argumentos (`portrait_id`, `mood`,
`portrait_folder`, `background_id`). Los 5 oyentes existentes de la señal
siguen compilando sin tocarlos — GDScript descarta los argumentos de más
en una señal si el callback conectado declara menos parámetros.

### Layout — variante C implementada
Franja inferior con retrato grande del NPC sobresaliendo por el borde
superior del marco. Base migrada de `PanelContainer` plano a `UIPanel`
(`decorative_frame = true`, marco del Spike 9). Único retrato — se
descarta definitivamente el layout de dos retratos original. Exports
muertos retirados (`background_texture`, `portrait_frame_texture`,
`text_color`, `text_font_size`, `speaker_name_color`,
`speaker_name_font_size`).

Anclas del panel por fracción de pantalla (no píxeles fijos):
`anchor_left/top/right/bottom = 0.04 / 0.57 / 0.96 / 0.96`. El primer valor
de `anchor_top` (`0.66`, copiado por error de la convención de
`NarrativeScenePanel`) se quedaba corto para el contenido real del panel de
diálogo — corregido a `0.57` tras medir en partida con resolución real
(1153×643).

`OptionsContainer` envuelto en un `ScrollContainer`: sin eso, el
`PanelContainer` crecía con el número de opciones y "subía" por encima del
resto de la pantalla (`grow_vertical = 0`). Con 5 opciones seguía
necesitando scroll incluso tras el ajuste de altura — comportamiento
correcto y deseado, no un bug.

Fondo de ambiente (`BackgroundImage` + `Background` como velo, mismo patrón
que `CombatArenaViewModel`/Grupo 4): imagen pre-difuminada en la
generación (más simple que un blur en tiempo real con `SubViewport`+shader),
`SCRIM_ALPHA_WITH_IMAGE = 0.55` validado contra el arte real, sin necesidad
de recalibrar.

### Validación (Fase 3) — todo confirmado en partida real
- Apertura como sub-overlay desde escena narrativa: OK.
- Apertura desde `EXPLORATION` vía interactuable: OK, aventura completa de
  principio a fin sin problemas.
- Cambio de expresión a mitad de conversación (`mood`): OK.
- Hablante sin retrato (fallback a ancho completo): verificado.
- Textos localizados (`SPEAKER_SHERIFF`, `DLG_SHERIFF_OPT_SAVE`): OK, filas
  añadidas al CSV.
- Marco no tapa texto: OK.
- Contrato de sub-overlay de Grupo 2 (`signal closed`,
  `resume_after_dialogue()`): intacto, confirmado tras el rediseño.

### Deuda técnica anotada, fuera de alcance de este spike
- Resolución de ventana (1153×643): se planteó subirla para que quepan más
  opciones sin scroll; aparcado como tarea de proyecto propia — afecta a
  toda pantalla con posiciones en píxeles fijos, no solo a este panel.
- `UIPanel.Variant.OVERLAY` documentada como semitransparente pero con
  stylebox opaco en la práctica — discrepancia menor de documentación,
  detectada en la Fase 0, sin corregir.
- Tests de `dialogue_node_shown` (`dialogue_panel_test.gd`,
  `test_dialogue_system.gd`, `test_eventbus.gd`): no adaptados a la firma
  de 7 argumentos.

### Actualizado al cerrar
- Este documento.
- `athelia_ui_architecture.md`: layout de la ventana de diálogo.
- `athelia_estructura_proyecto_actualizado.md`: campos nuevos
  (`mood`, `portrait_folder`, `background_id`) en las definiciones de
  diálogo.
- Hoja de ruta de spikes 5-13: Spike 11 marcado como cerrado.

---

## Prompt de inicio de sesión

Para arrancar la sesión de este spike, pegar:

```
Vamos a empezar el Spike 11 (rediseño de la ventana de diálogo) del
proyecto Athelia. Especificación adjunta: spike_11_ventana_dialogo.md

Hay que rediseñar DialoguePanel: fondo propio, marco decorativo del Spike 9
y un único retrato del NPC con estado de ánimo, cargable según el diálogo.
Se descarta el layout de dos retratos.

Empieza por la Fase 0 (comprobación de código), sin diseñar nada todavía.
Yo creo que DialogueSystem y las definiciones ya contemplan retratos y
estado de ánimo, pero no está confirmado: dime qué existe de verdad, si es
un campo que alguien consume o uno huérfano, y qué sería cambio de motor.
Confirma también por qué salen crudas las claves SPEAKER_SHERIFF y
DLG_SHERIFF_OPT_SAVE, y por qué el estado dice EXPLORATION con el diálogo
abierto.

Después pasamos a la Fase 1 (maqueta de 2-3 variantes de layout y catálogo
de estados de ánimo) antes de escribir código.

Antes de tocar nada necesito estos ficheros:

- dialogue_panel.gd / .tscn y su ViewModel
- dialogue_system.gd
- las definiciones de diálogo (DialogueDefinition, nodos y opciones) y el
  loader del registry
- un JSON de diálogo de referencia (dlg_telmori_sheriff_briefing)
- ui_panel.gd (con decorative_frame y corner_texture del Spike 9)
- ui_tokens.gd
- el .csv de localización de diálogo de Los Telmori

Si algún fichero no encaja con lo que describo, dímelo antes de asumirlo.
```
