# Spike 15 — Cimientos del Design System (informe de cierre)

**Fecha de cierre:** 2026-10-20 · **Hito:** rediseño de interfaces (spikes 14-24) · **Godot:** 4.7.x
**Estado:** cerrado. Validado en partida real salvo lo anotado en §9 («Sin confirmar»).

Spike previo a cualquier rediseño de pantalla: resuelve de una vez lo que
comparten las pantallas del hito. No se rediseña ninguna pantalla.

---

## 1. Resumen

| Bloque | Resultado |
|---|---|
| A. Resolución | **Sin estiramiento.** Se mantienen los valores por defecto (ventana de 1152×648, sin sección `[display]` de estiramiento). Las pantallas del hito se diseñan con anclas para una ventana mínima de 1152×648. |
| B. Tokens | Dos vocabularios fusionados con alias. Dos cambios de valor visibles: `COLOR_TEXT_MUTED` y `COLOR_PANEL_ALT`/`BG_SURFACE`. |
| C. `UIPanel` | Esquinera por defecto, padding mínimo con marco, warning fuera de `_draw()`, activación en runtime, docstring corregido. |
| D. Diálogo | Opciones en rejilla (1 columna hasta 3, 2 columnas desde 4), altura de opciones reservada, margen del texto proporcional al retrato, foco de teclado con aspecto de hover. |
| E. `UISlot` | Solo el docstring (ruta antigua). |
| F. Documentación | Contrato de pantalla, resolución de referencia, tokens, marco, lecciones. |
| G. Localización | Duplicados y filas mal formadas corregidos, `skills.csv` nuevo, convención de claves fijada. |

## 2. Lo que la Fase 0 corrigió de la spec

Antes de escribir código se contrastó la spec con el proyecto real:

- `MENU_CONFIRM_YES` **no** estaba roto. La fila mal formada real era
  `DLG_SHERIFF_REWARD_01_GREET` (`dialogues_scenes_telmori.csv`, línea 13: dos
  campos con comas sin comillas, 5 columnas en vez de 3).
- Las cifras de altura del diálogo de la spec (216 px necesarios / 252
  disponibles) no encajaban con el árbol de nodos real.
- La hipótesis «solo hay scroll en ventana de 648» era falsa: a 1050 de alto
  se ven 4 opciones y un trozo de la quinta; a 648, solo dos y parte de la tercera.
- `translations.csv` tenía **29 claves duplicadas** (líneas 79-107), todas
  idénticas a su primera copia. Godot resuelve los duplicados en silencio
  (gana la última).
- `UIPanel` en el diálogo: warning de `push_warning` en cada `_draw()` por no
  tener `corner_texture`, y por eso el diálogo no mostraba esquineras.
- Los dos vocabularios de tokens (`COLOR_*` frente a `BG_*`/`BORDER_*`/`TEXT_*`)
  tenían valores distintos para lo que era el mismo concepto
  (`COLOR_TEXT_MUTED` frente a `TEXT_MUTED`, `COLOR_PANEL_ALT` frente a
  `BG_SURFACE`).

## 3. Resolución y estiramiento (decisión)

**Decisión: sin estiramiento, valores por defecto.** Se priorizó la nitidez
del texto sobre el escalado automático.

**Experimento.** En una copia del proyecto (`athelia_exp`) se probó base
1280×720 con `stretch/mode = canvas_items` y aspecto mantenido, frente a la
configuración por defecto, en ventana y a pantalla completa, sobre las pantallas
existentes (inventario, party, tienda, combate, diálogo).

| Aspecto | Con estiramiento (1280×720, `canvas_items`) | Sin estiramiento (1152×648 por defecto) |
|---|---|---|
| Texto a pantalla completa | Más borroso: ancho de borde 1,53 → 1,72/1,78 px (≈ 15 % más suave) | Nítido |
| Pantallas existentes | La mayoría sin problema visible | La mayoría sin problema visible |
| Diálogo con 4 opciones | **Se monta** el texto con el retrato | Ver §6 (el mismo solape aparece al ampliar la ventana, no por el estiramiento) |
| Combate a pantalla completa | Fondo menos nítido | Sin cambio |
| Monitor de prueba | HP de 22", 1680×1050, escalado de Windows al 100 % | idem |

Notas del experimento:
- El primer intento fue **inválido**: la copia no había guardado la
  configuración (`Select-String` sobre `project.godot` no devolvía la sección
  `[display]`). Se repitió verificando `[display]` con 1280/720/`canvas_items`
  antes de medir.
- La nitidez se midió además de mirarla (anchura de borde de glifo), porque la
  percepción de Fernando («a 1152 se ve mejor, aunque puede ser subjetivo») y la
  medición coincidieron.
- Consecuencia para los spikes 16-24: pantallas con **anclas y fracciones**, no
  tamaños en píxeles fijos, para una ventana mínima de 1152×648. Las pantallas
  de píxeles fijos existentes (lista en el plan del hito, §3.2) no se arreglan
  aquí.
- Ningún cambio en *Project Settings*: no hay nada que aplicar.

## 4. Tokens (`ui_tokens.gd`, fichero completo)

- Cabecera con los dos vocabularios, la **regla de uso** y la tabla de alias.
- **Regla:** código nuevo usa `BG_*`/`BORDER_*`/`TEXT_*` para superficies, bordes
  y texto, y `COLOR_*` para marca, semánticos, recursos y slots. Nada se migra.
  Los duplicados exactos son **un alias**, no dos valores; los alias apuntan
  siempre hacia atrás (constantes ya declaradas); para cambiar un valor se edita
  el `COLOR_*` de origen.
- Alias: `BG_BASE→COLOR_BG`, `BG_PANEL→COLOR_PANEL`, `BG_SURFACE→COLOR_PANEL_ALT`,
  `BORDER_DEFAULT→COLOR_BORDER`, `TEXT_PRIMARY→COLOR_TEXT`,
  `TEXT_MUTED→COLOR_TEXT_MUTED`, `COLOR_SLOT_OCCUPIED→COLOR_PANEL_ALT`.
- **Dos cambios de valor, ambos visibles:**
  1. `COLOR_TEXT_MUTED` y `TEXT_MUTED` → `#9A8E78` (texto apagado algo más claro,
     p. ej. botones `GHOST` en reposo).
  2. `COLOR_PANEL_ALT` y `BG_SURFACE` → `#252220` (cambio menor en el árbol de
     habilidades).
- Radios: sin cambios; solo una tabla de equivalencias en comentarios
  (`BORDER_RADIUS_SM` 3, `RADIUS_CARD` 4, `BORDER_RADIUS_MD` 5, `RADIUS_PANEL` 6,
  `BORDER_RADIUS_LG` 8).
- Nuevos: `FRAME_MIN_PADDING` (= `SPACE_LG` = 16) y `FRAME_CORNER_TEXTURE_PATH`
  (`res://ui/design_system/assets/frames/frame_corner_64x64.png`).
- Validación: `test_tokens_alias.gd` (EditorScript, 12 comprobaciones) → `OK: 12/12`.

## 5. `UIPanel` (`ui_panel.gd`, fichero completo)

- **Esquinera por defecto:** si `corner_texture` no está asignada se usa
  `UITokens.FRAME_CORNER_TEXTURE_PATH`. Solo si tampoco carga esa, se dibujan
  los filetes sin esquinas y se avisa **una vez por ejecución** (`static var`).
  El aviso ya no sale de `_draw()`: se resuelve en `_refresh_frame()`.
- **Padding mínimo con marco:** con `padding = -1` y `decorative_frame = true`,
  el padding efectivo no baja de `FRAME_MIN_PADDING` (16). Un `padding` explícito
  (≥ 0) nunca se toca.
- **Activación en runtime:** `decorative_frame` y `corner_texture` tienen setter.
  Los setters de un `@export` se ejecutan al cargar la escena **antes de
  `_ready()`**, así que usan `is_node_ready()` y dejan el estado inicial a
  `_ready()`.
- **Docstring corregido contra los consumidores reales:** `DEFAULT` lo usan
  Character Creation (3 paneles), Diálogo, Narrativa y los sub-paneles del menú
  principal; `POPUP` y `OVERLAY` no tienen consumidores. **`OVERLAY` es opaco**
  (`COLOR_BG` oscurecido un 20 %, alfa 1,0), no semitransparente como se
  documentaba; si hiciera falta transparencia habrá que añadirla explícitamente.
- Marco decorativo sigue siendo **opt-in** (`false` por defecto).
- Validado: sin warning al abrir un diálogo ni al redimensionar; esquineras en
  el diálogo; panel narrativo, Character Creation y menú principal sin cambios;
  `ConfirmQuitPanel` con y sin marco activado en runtime (aparece sin reiniciar).

## 6. Diálogo (`dialogue_panel.gd` completo + `.tscn`)

**Problema:** el `sheriff_briefing` (6 opciones) se cortaba en ventana; los de
3 opciones también perdían la tercera a 648 de alto; con ventanas más anchas el
texto quedaba debajo del retrato.

**Opciones en rejilla (L1).** `OptionsContainer` pasa de `VBoxContainer` a
`GridContainer`: 1 columna hasta 3 opciones, 2 columnas desde 4, relleno por
filas (el orden no cambia). El `ScrollContainer` se mantiene como red de
seguridad. La franja de opciones **reserva siempre su altura natural**
(`custom_minimum_size.y` = filas × alto de botón + separaciones). Sin esa
reserva, `DialogueText` y `OptionsScroll` (ambos `size_flags_vertical = 3`) se
reparten el hueco a partes iguales y a 648 se cortaba la tercera opción: un
fallo anterior al spike, descubierto al validar. Se cuenta con los botones
añadidos (no con los hijos), porque los pendientes de `queue_free()` no son
filas; `_clear_options()` los saca del árbol antes de liberarlos.

Cálculo a 648 de alto (panel ≈ 252,7 px, interior ≈ 220,7): 6 opciones en 3 filas
= 3 × 36 + 2 × 4 = 116 px; texto ≈ 62 px; sobran ≈ 5 px.

**Margen del texto proporcional (P2).** El margen izquierdo fijo de 240 px solo
era correcto a 1152 de ancho: el retrato va por fracciones (0,06-0,26 de
pantalla). Ahora se calcula desde el borde derecho real del retrato
(+ `PORTRAIT_TEXT_GAP` = 3 px) y se recalcula en `resized` del panel y del retrato:

| Ancho de ventana | Margen del texto |
|---|---|
| 1152 | 240 px (idéntico al valor fijo anterior) |
| 1280 | 269 px |
| 1680 | 357 px |
| 1920 | 409 px |

Antes, el texto se solapaba con el arte a partir de 1280 (≈ 12 px a 1280, ≈ 98 px a 1680).
Sin retrato visible, el margen es 0. Esto acopla de paso el cálculo a
`%MarginContainer` (nombre único) y elimina el `get_node("MarginContainer")` por ruta.

**Teclado.** Sin foco inicial las flechas y Enter no llegaban a ninguna opción;
ahora la primera opción toma el foco (`grab_focus` diferido). El foco usa el
estilo `hover` del propio botón (`add_theme_stylebox_override("focus", …)`): el
reborde por defecto se recortaba. La navegación 2D de la rejilla (incluidas
izquierda y derecha) la resuelve Godot.

**Cambios en `dialogue_panel.tscn` (a mano, nodo a nodo):**
- `OptionsContainer`: tipo `GridContainer`, `columns = 1`, `h_separation = 4`,
  `v_separation = 4` (se quita el override `separation`).
- `MarginContainer` y `OptionsScroll`: marcados como nombre único (`%`).
- `MarginContainer`: se quita el `margin_left = 240` del editor (lo calcula el script).
- Anclas de `Panel` y `Portrait` sin cambios.

**Hallazgo de estructura:** `Background` y `BackgroundImage` cuelgan de la raíz
`CanvasLayer`; `Root` (Control) contiene `Panel` y `Portrait`, hermanos, y por eso
sus posiciones están en el mismo espacio.

## 7. Localización

- `translations.csv`: **29 filas duplicadas eliminadas** (149 → 120 líneas; 94 tras
  mover las habilidades a `skills.csv`), todas comprobadas idénticas a su primera copia antes de
  borrar (si hubiera diferido, el script no las toca y avisa).
- `world_objects.csv`: eliminada la segunda `WORLD_OBJECT_DEPLETED` (línea 31).
  **Cambio de texto visible:** se conserva «Nothing more to do here» / «No queda
  nada más que hacer aquí».
- `dialogues_scenes_telmori.csv`: `DLG_SHERIFF_REWARD_01_GREET` entrecomillada;
  añadida `SPEAKER_INNKEEPER,Innkeeper,Posadero` (salía la clave cruda como
  nombre del posadero).
- **`skills.csv` nuevo** (`localization/`, columnas `id,en,es`): contiene todas las
  claves `SKILL_<ID>_NAME` y `_DESC` de las habilidades. Se movieron 26 filas
  desde `translations.csv` y se añadieron 14 filas para 7 habilidades que no
  tenían traducción (`ENEMY_BASIC_ATTACK`, `LOCKPICK`, `PERCEPTION`, `SEARCH`,
  `SPRINT`, `STEALTH`, `TRACK`). Se corrigió `SKILL_ATTACK_LIGHT_NAME`
  (espacios y errata «Atack»). Se mantienen en `translations.csv`, a propósito,
  las claves de pantalla `SKILL_TREE_*`, `SKILL_SUBCATEGORY_*`, `SKILL_FILTER_*`.
  Los textos nuevos son un borrador a revisar por Fernando.
- Comprobación entre ficheros: ninguna clave repetida entre los `.csv` de
  `localization/` tras los cambios.
- **Convención de claves para pantallas del hito:** prefijo de pantalla en
  mayúsculas, formato `PANTALLA_ELEMENTO` (`SHOP_…`, `INVENTORY_…`,
  `GAMEOVER_…`). **No se crean claves comunes** (cerrar, volver…): la Fase 0 no
  mostró duplicados reales que lo justificaran.
- `menus.csv` tiene las columnas en orden `id,es,en`; el resto, `id,en,es`.
- Un `.csv` nuevo necesita alta manual en *Project Settings → Localization →
  Translations* (sus `.translation` se generan al reimportar).

## 8. Ficheros tocados

| Fichero | Tipo |
|---|---|
| `ui/design_system/tokens/ui_tokens.gd` | completo |
| `ui/design_system/components/ui_panel/ui_panel.gd` | completo |
| `ui/design_system/components/ui_slot/ui_slot.gd` | parche (docstring: ruta `components/ui_slot/`) |
| `ui/dialogue/dialogue_panel.gd` | completo |
| `ui/dialogue/dialogue_panel.tscn` | a mano (ver §6) |
| `localization/translations.csv`, `world_objects.csv`, `dialogues_scenes_telmori.csv` | datos corregidos |
| `localization/skills.csv` | **nuevo** |

Temporales, que se pueden borrar: `test_tokens_alias.gd`, `spike15_faseD_csv.ps1`,
`spike15_faseD2_skills.ps1`, los `.bak` de `localization/`.

## 9. Validación hecha

- **Tokens:** 12/12 comprobaciones; diff del fichero: solo cambian los dos valores anunciados.
- **`UIPanel`:** sin warnings, esquineras en el diálogo, panel narrativo y menú principal sin cambios, activación en runtime.
- **Diálogo:**
  - `sheriff_briefing` con 6 opciones en 1152×648: las 6 caben, sin scroll, en 2 columnas × 3 filas.
  - Posadero (3 opciones): caben completas en ventana tras reservar la altura natural.
  - Diálogos de 2-3 opciones sin cambios; ratón y cierre correctos; no quedan botones de diálogos anteriores.
  - Teclado: la primera opción toma el foco y las flechas se mueven bien por la rejilla; sin la línea blanca del foco.
  - 1680×1050 a pantalla completa: el texto empieza tras el retrato, sin solape.
- **Localización:** habilidades en español en el árbol de habilidades (Percepción, Buscar, Sigilo, Rastrear, resto).
- **Regresión general:** menú principal (y sub-paneles), Character Creation, inventario, party, tienda, árbol de habilidades, Loadout y menú del jugador: sin cambios salvo lo anunciado.

**Sin confirmar:**
- Idioma **inglés** de todo lo tocado, y que `DLG_SHERIFF_REWARD_01_GREET`
  (saludo del sheriff) y el nombre del posadero salen bien tras el reimportado.
- Comprobación de columnas de los `.csv` con el comando de la Fase 0 tras los cambios.
- Un saludo del sheriff de 3 líneas con las 6 opciones a 648 de alto podría
  recortarse unos 4 px (previsto por el cálculo, no observado).
- `SKILL_ATTACK_LIGHT_DESC` (espacios y «atack») por corregir a mano en `skills.csv`.

## 10. Lecciones

- Las **cifras de una spec se comprueban** contra el árbol de nodos real antes de
  diseñar (las de altura y la fila «rota» eran inexactas).
- Un **experimento hay que verificarlo antes de medir**: el primero se hizo con
  una configuración que no se había guardado.
- El estiramiento `canvas_items` ablanda el texto; **medir y mirar** antes de adoptarlo.
- Un **margen en píxeles atado a un hermano proporcional** se rompe al cambiar de
  tamaño: se calcula desde el borde real del hermano.
- **`ScrollContainer` + `size_flags_vertical = 3` reparte a partes iguales**: si
  el contenido variable es la norma, se reserva su altura natural.
- Los **setters de `@export` corren antes de `_ready()`**: protegerlos con
  `is_node_ready()`.
- Un **aviso dentro de `_draw()` se repite en cada redibujado**: se resuelve fuera
  y una vez por proceso.
- Sin **foco inicial** el teclado no tiene a quién llegar; el foco por defecto de
  un `Button` puede recortarse, se sustituye por el estilo `hover`.
- Los **CSV de Godot** resuelven duplicados en silencio (gana el último) y los
  campos con comas exigen comillas: un borrado masivo se hace con simulación,
  copia de seguridad y comprobación de que cada fila es idéntica a su original.
- Un script de **PowerShell 5.1** guardado como UTF-8 sin BOM corrompe los acentos
  si los lleva literales: se escribe en ASCII.

## 11. Pendientes

**Del hito (para el plan):**
- Los diálogos de 3 opciones ya caben (resuelto aquí); revisar el caso de 3 líneas de saludo con 6 opciones a 648.
- Retrato del posadero: muestra el del sheriff (posible placeholder de datos).
- `interactive_scene_view.gd:15`: comentario erróneo sobre `main_theme.tres`.
- Fuentes y tema: `main_theme.tres` no está aplicado (fuera de alcance de este spike).
- Revisar el significado de `SKILL_META_COST_`, `SKILL_NOT_FOUND`, `SKILL_NOT_LEARNED`, `SKILL_SLOTS`, `SKILL_A`, `SKILL_B`, `SKILL_CATEGORY` (aparecen en el código/datos sin definición en los CSV; no se sabe si se muestran al jugador).
- En el árbol de habilidades: la pestaña `companion_mira` muestra el id en lugar de un nombre localizado y hay un `T1` suelto sin localizar → spike 21.
- Pantallas de píxeles fijos ya listadas en el plan (§3.2): se arreglan en el spike de cada pantalla.

**Resueltos de la recopilación:** discrepancia de `UIPanel.Variant.OVERLAY` (documentada como opaca), warning del marco en `_draw()`, esquineras del diálogo, fila mal formada de los `.csv`, claves `SKILL_*_NAME` sin traducir (la mayoría; el resto del §5 de la recopilación sigue en el spike 21).
