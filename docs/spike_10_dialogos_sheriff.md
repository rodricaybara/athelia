# Spike 10 — Diálogos restantes del sheriff (recompensa y entrenamiento)

**Estado:** Cerrado (2026-09-28) — camino A, validado en partida real
**Origen:** Parte pendiente del Grupo 2 de mejoras post-Spike 3 (diálogo
con NPCs desde narrativa), recogida en
`athelia_pendientes_post_pivote_narrativo.md`, punto 1. Solo
`sheriff_briefing` quedó convertido a `DialogueSystem`.
**Riesgo:** Medio-bajo. El patrón de conversión ya está validado en
partida real, pero estas dos escenas, a diferencia del briefing, **entregan
recompensas** (oro/recurso, ítems, tomo de entrenamiento), y no está
confirmado que `DialogueSystem` sepa entregarlas (ver Punto 2).
**Tipo de spike:** Contenido sobre motor existente, con una comprobación de
código previa que puede convertirlo en spike con cambio de motor.
**Precede a:** Spike 12/13 (mapa de puntos de interés y reautoría del
pueblo) — conviene que el arco del sheriff esté ya migrado a diálogo antes
de reautorar la entrada al pueblo.

---

## Contexto

En el Grupo 2 se estableció el patrón para abrir un diálogo desde una
escena narrativa sin salir de `NARRATIVE_SCENE`:

- `NarrativeScenePanel` instancia `DialoguePanel` como sub-overlay hijo y
  llama a `Dialogue.start_dialogue()` directo, sin pasar por
  `GameState.DIALOGUE` ni por `SceneOrchestrator`.
- `NarrativeSceneOutcome.dialogue_id`: cuando está relleno, el
  `next_scene_id` del mismo outcome deja de aplicarse al instante y pasa a
  significar "escena a la que avanzar cuando se cierre el diálogo".
- `resume_after_dialogue()` en `NarrativeSceneViewModel`, invocado por el
  panel solo si el sub-overlay cerrado era un diálogo
  (`_sub_overlay_is_dialogue`).
- Diálogos en `data/dialogue/telmori/` (el registry ya escanea
  subcarpetas de forma recursiva).
- Caso de referencia validado: `sheriff_briefing` — una escena narrativa
  con una única opción que abre `DLG_TELMORI_SHERIFF_BRIEFING` (hub de 4
  ramas), dispara un evento narrativo al aceptar y, al cerrar el diálogo,
  encadena a la siguiente escena sin intervención manual.

Este spike aplica ese mismo patrón a las dos escenas restantes del sheriff.

## Estado actual de la cadena de cierre (Grupo D de Spike 3)

Cadena de 4 escenas, entrada por el interactuable `telmori_sheriff_reward`
(spawneado al marcarse `flag.telmori_lair_cleared`, retirado al completarse
`flag.telmori_adventure_completed`):

1. `telmori_sheriff_reward_intro` — recompensa (bounty + trofeo) → **a convertir**
2. `telmori_sheriff_training` — entrenamiento (tomo `book_tanning_basics`,
   que enseña Curtido) → **a convertir**
3. `telmori_sheriff_pelts` — venta de pieles con tirada real contra
   `skill.exploration.tanning` → **se queda como escena narrativa**
4. `telmori_epilogue_hook` — gancho del hombre-lobo, flavor puro → sin cambios

`telmori_sheriff_pelts` **no se puede convertir y no es una tarea
pendiente**: `DialogueOptionDefinition` no soporta tiradas de skill.

---

## Alcance

### 1. Comprobación previa obligatoria (antes de diseñar nada)

Leer el contenido real de las dos escenas y confirmar qué hacen hoy, sin
asumirlo por su nombre:

- Qué outcomes tiene cada una (entregas, flags, cadenas) y cuántas opciones.
- Si alguna opción tiene tirada de skill o `challenge_level` (si la
  tuviera, esa parte no cabe en diálogo, igual que las pieles).
- Cómo se entrega hoy cada recompensa (`grant_item_*`, `grant_resource_*`,
  y por qué mecanismo llega el tomo de Curtido).
- Dónde se marca cada flag de progreso de la cadena
  (`flag.telmori_adventure_completed` en concreto) para no romper la
  limpieza del interactuable.

### 2. Decisión de diseño: dónde viven las entregas de recompensa

Punto crítico. Los campos `grant_item_*`/`grant_resource_*` pertenecen a
`NarrativeSceneOutcome`; **no está confirmado que
`DialogueOptionDefinition`/`DialogueSystem` tengan equivalente**. Hay dos
caminos, y hay que decidir cuál tras la comprobación de código:

- **A. El diálogo solo conversa; las entregas se quedan en outcomes
  narrativos** (antes o después del diálogo, encadenados como ya se hace:
  un ítem por outcome). Sin cambios de motor. Es el camino por defecto si
  encaja con la conversación.
- **B. Ampliar `DialogueOptionDefinition` con entregas** (ítem/recurso).
  Es un cambio de motor: campo nuevo con declaración **y** asignación en el
  loader en el mismo cambio (lección de Spike 3/D), y `DialogueSystem` debe
  ejecutarlo. Solo si A resulta forzado o rompe la narración.

**Riesgo de exploit a cubrir en cualquiera de los dos caminos:** un diálogo
es repetible dentro de su hub. Una recompensa enganchada a una opción de
diálogo podría reclamarse varias veces si el jugador puede volver a esa
rama. La entrega debe ser de un solo uso (flag de "ya entregado", opción
oculta tras entregarse vía `required_flags`/`blocked_flags`, o entrega
fuera del diálogo). Mismo criterio que ya evitó la reentrada indefinida a
la recompensa en Spike 3/Grupo D.

### 3. Conversión de `telmori_sheriff_reward_intro`

Seguir el patrón de `sheriff_briefing`: escena narrativa que abre el
diálogo de recompensa y, al cerrarse, avanza a `telmori_sheriff_training`
mediante `next_scene_id` + `resume_after_dialogue()`. Contenido conversacional
al diálogo; entregas según la decisión del Punto 2.

### 4. Conversión de `telmori_sheriff_training`

Igual, encadenando al cierre con `telmori_sheriff_pelts`. La entrega del
tomo de Curtido según la decisión del Punto 2.

### 5. Localización

Todo texto nuevo de diálogo con claves en el `.csv` correspondiente, sin
cadenas literales (regla del proyecto). Reutilizar las claves de las
escenas actuales cuando el texto se conserve, para no duplicar.

### 6. Validación

En partida real hasta el final del arco: interactuable del sheriff →
recompensa → entrenamiento → venta de pieles → epílogo. Comprobar:
recompensas entregadas **una sola vez**, tomo en inventario, Curtido
aprendible, `flag.telmori_adventure_completed` marcado y el interactuable
retirado, sin warnings. Para no rejugar la aventura entera, el atajo F2
(`user://debug_shortcut.json`, solo en build de debug) permite marcar
`flag.telmori_lair_cleared` y saltar directamente a este tramo.

---

## Fuera de alcance
- Convertir `telmori_sheriff_pelts` (imposible por diseño, ver arriba).
- Cambios en `telmori_epilogue_hook`.
- Marco decorativo y arte de la ventana de diálogo (Spikes 9 y 11).
- Cualquier pendiente de la recopilación final.

## Cierre del spike (checklist original)
Al terminar, actualizar:
- Este documento con la decisión tomada en el Punto 2 (A o B) y por qué,
  más el resultado de la validación.
- `mejoras-narrativas.md` / documentación de pendientes: Grupo 2 pasa de
  parcial a completo.
- Si se eligió el camino B, documentar el campo nuevo en la documentación
  de arquitectura de diálogo.

---

## Cierre del spike (resultado)

### Decisión del Punto 2: camino A

**El diálogo solo conversa; las entregas se quedan en el outcome narrativo.**
Comprobado con el código real: `DialogueOptionDefinition` y `DialogueSystem`
no tienen ningún mecanismo de entrega (`select_option()` solo dispara
`narrative_events`, guarda si `triggers_save` y navega). B habría sido un
cambio de motor sin necesidad.

- La entrega vive en el outcome de la opción que abre el diálogo
  (`grant_resource_*` / `grant_item_*` + `dialogue_id` + `next_scene_id`), no
  en ninguna opción del hub, así que **no hay rama repetible que la reclame
  dos veces**. La entrega ocurre al pulsar la opción (antes del diálogo);
  el texto de la escena narra el traspaso y el diálogo es la charla posterior.
- La protección contra reentrada no cambia: el interactuable se retira con
  `flag.telmori_adventure_completed`.
- `telmori_sheriff_pelts` (tirada de Curtido) y `telmori_epilogue_hook` no
  se tocaron en lógica.

### Hallazgos que ampliaron el alcance (dos fallos de motor previos)

1. **`grant_item_*` no se ejecutaba.** El bloque de entrega de ítems se
   había perdido de `NarrativeSceneViewModel._apply_outcome()` (quedaba solo
   el comentario, con la entrega de recurso debajo). Ningún ítem de ningún
   outcome llegaba al inventario, **sin ningún error visible**: además del
   trofeo y el tomo, tampoco se habían entregado la bolsa mágica ni la punta
   de obsidiana del Grupo D. Con toda probabilidad se perdió al parchear
   `_apply_outcome()` en el Grupo 2; el informe de Grupo D ya lo dejaba como
   "sin confirmar". Restaurado, antes del retorno temprano de `dialogue_id`,
   con `print` al entregar y `push_warning` si `Inventory.add_item()` falla.
2. **Un libro no podía enseñar una skill fuera del kit inicial.**
   `register_entity_skills()` solo crea instancias para el kit, así que
   `execute_learning_session()` no encontraba la instancia de
   `skill.exploration.tanning` (`skill_locked`) y el libro se consumía igual,
   porque `_apply_consumable()` emitía `item_use_success` incondicionalmente.
   Los libros anteriores (`book_combat_basic`) solo mejoraban skills que ya
   se tenían, por eso nunca había fallado.

### Cambios de motor

- **`NarrativeSceneViewModel._apply_outcome()`** — bloque `grant_item_*`
  restaurado (ver arriba); `grant_resource_*` deja también rastro en log.
- **`SkillSystem.learn_skill(entity_id, skill_id) -> bool`** (nuevo) — crea la
  instancia si falta y la desbloquea vía `unlock_skill()` (se siguen
  comprobando `prerequisite_requirements`; `requires_unlock` no bloquea, es
  justo lo que se resuelve al aprender). Si el desbloqueo falla, retira la
  instancia. Con una skill ya registrada no salta su bloqueo.
- **`SkillSystem.load_save_state()`** — recrea las instancias que falten a
  partir de su definición; sin esto, una skill aprendida en runtime se
  perdía al cargar. (`CharacterState` ya guardaba `skill_values` entero.)
- **`ItemCharacterBridge._apply_learning()`** — ahora devuelve `bool`. Si la
  entidad no tiene la skill, la primera lectura la **enseña** (sin tirada de
  mejora en esa lectura) y le da valor inicial: clave opcional
  `"initial_value"` en `learning_data`, por defecto el `base_success_rate` de
  la skill (Curtido: 15%). Solo si la entidad no tenía ya un valor > 0.
- **`ItemCharacterBridge._apply_consumable()`** — si el aprendizaje no se
  pudo aplicar (`invalid_session`, `skill_locked`, `no_progression`, o no se
  pudo aprender), emite `item_use_failed` y el libro **no se consume**. Una
  tirada de mejora fallida sigue consumiéndolo, como antes.
- **`NarrativeSceneOutcome`** — solo el comentario de `dialogue_id`, que
  decía que no encadenaba `next_scene_id` (el ViewModel sí lo hace).

### Ficheros tocados

| Fichero | Cambio |
|---|---|
| `narrative_scene_viewmodel.gd` | Entrega de ítems restaurada + logs |
| `narrative_scene_outcome.gd` | Solo comentario |
| `skill_system.gd` | `learn_skill()`, `load_save_state()` |
| `item_character_bridge.gd` | Aprendizaje de skill nueva, no consumir si falla |
| `telmori_sheriff_reward_intro.json`, `telmori_sheriff_training.json` | + `dialogue_id`, `next_scene_id` al cierre |
| `dlg_telmori_sheriff_reward.json`, `dlg_telmori_sheriff_training.json` | Nuevos, en `data/dialogue/telmori/` |
| `narrative_scenes_telmori.csv` | +11 claves (4 escenas, epílogo, prompt del interactuable, escena de botín) |
| `dialogues_scenes_telmori.csv` | +12 claves de los dos diálogos |
| `items.csv` | +4 claves (flecha de plata, lanza encantada) |
| `items_telmori.csv` | Comillas en dos descripciones con comas; alta en Project Settings |

### Validación (partida real, F2 con `flag.telmori_lair_cleared`)

- Entregas **una sola vez** cada una: `Item granted: wolf_tail_trophy x1`,
  `Resource granted: gold 100.0`, `Item granted: book_tanning_basics x1`,
  y en el botín de la guarida `telmori_magic_bag` y `obsidian_spearhead`.
- Ambos diálogos abren como sub-overlay, las ramas vuelven al hub y el
  cierre avanza solo: `reward_intro` → `training` → `pelts` → epílogo.
- Leer el tomo desde el inventario (que sigue accesible como sub-overlay en
  narrativa): `Unlocked` / `Learned` / `APRENDIDA (valor inicial 15%)`, sin
  warning de `skill_system.gd`, inventario de 11 a 10 ítems.
- Curtido aparece en el panel de habilidades y se entrena desde ahí
  (15 → 17 → 18, y hasta 81% en la última partida). Tirada de venta contra el
  valor real: `D100=12 vs 81% → SPECIAL`, +80 de oro.
- `flag.telmori_adventure_completed` se marca y el interactuable se retira,
  sin warnings de motor.
- Localización completa tras dar de alta `items_telmori.csv` en Project
  Settings (el fallo de fondo: el fichero nuevo no estaba registrado) y
  entrecomillar las descripciones con comas.

**Sin probar en partida:** el camino de fallo del libro (`item_use_failed`,
libro no consumido) y la restauración de Curtido tras guardar/cargar (solo se
ha comprobado por código que `CharacterState` guarda y restaura
`skill_values` entero y que `SkillSystem.load_save_state()` recrea la
instancia).

### Lecciones reutilizables

- Un bloque perdido al parchear un método grande puede fallar **en
  silencio**: `grant_item_*` no daba ningún error y el resto de la cadena
  seguía funcionando. Todo efecto de un outcome debe dejar una línea de log
  al aplicarse, y tras parchear `_apply_outcome()` conviene comprobar con el
  log que cada tipo de entrega sigue apareciendo.
- Un `.csv` de localización nuevo necesita **alta manual** en Project
  Settings → Localization → Translations; sin ella todas sus claves salen
  crudas aunque el contenido y las claves sean correctos.
- En un `.csv` de localización, cualquier campo con comas debe ir
  entrecomillado; si no, la fila tiene más columnas de las declaradas.
- Un consumible con efecto condicional no debe emitir `item_use_success`
  incondicionalmente: el consumo del ítem cuelga de esa señal.

### Pendiente (fuera de este spike)

- Claves sin traducir en el panel de habilidades: `SKILL_PERCEPTION_NAME`,
  `SKILL_SEARCH_NAME`, `SKILL_STEALTH_NAME`, `SKILL_TRACK_NAME`
  (anteriores a este spike).
- Probar en partida el camino de fallo del libro y guardar/cargar con Curtido
  aprendido.
- `challenge_too_low` sigue consumiendo el libro (comportamiento previo, no
  tocado).
- Avisos de estilo ya existentes en `item_character_bridge.gd`
  (`CONFUSABLE_LOCAL_DECLARATION` de `modifiers`, `item_id` sin usar en
  `_apply_to_resource()`/`_apply_to_attribute()`) y comentarios
  desactualizados heredados (cabecera de `narrative_scene_outcome.gd`,
  `_on_narrative_flag_set_lair_aftermath_cleanup()` de Grupo C).

### Actualización de la documentación de pendientes

- **`mejoras-narrativas.md` / pendientes post-pivote:** Grupo 2 (diálogo con
  NPCs desde narrativa) pasa de **parcial a completo**: el arco del sheriff
  está íntegramente migrado a `DialogueSystem` salvo `telmori_sheriff_pelts`
  (tirada de skill, no convertible por diseño) y `telmori_epilogue_hook`
  (flavor puro).
- **`athelia_estructura_proyecto_actualizado.md`:** añadir, en las secciones
  de Narrative Scene y de Skills/Items, `SkillSystem.learn_skill()`, la clave
  opcional `initial_value` de `learning_data`, la regla "el libro solo se
  consume si el aprendizaje se aplicó", y que las entregas de recompensa
  viven en el outcome narrativo (no en `DialogueOptionDefinition`).
- **Camino B:** no se eligió; no hay campo nuevo de diálogo que documentar.

---

## Prompt de inicio de sesión

Para arrancar la sesión de este spike, pegar:

```
Vamos a empezar el Spike 10 (diálogos restantes del sheriff) del proyecto
Athelia. Especificación adjunta: spike_10_dialogos_sheriff.md

Es aplicar a telmori_sheriff_reward_intro y telmori_sheriff_training el
patrón ya validado con sheriff_briefing (sub-overlay de diálogo desde
NarrativeScenePanel, dialogue_id en el outcome, resume_after_dialogue()).
telmori_sheriff_pelts NO se convierte (necesita tirada de Curtido, el
diálogo no la soporta) y telmori_epilogue_hook no se toca.

Punto crítico: estas dos escenas entregan recompensas, y no está
confirmado que DialogueOptionDefinition/DialogueSystem sepan entregar
ítems o recursos. Antes de diseñar nada, comprueba con el código real y
dime qué camino encaja (A: el diálogo solo conversa y las entregas se
quedan en outcomes narrativos; B: ampliar el diálogo con entregas). No
elijas B sin confirmarlo conmigo. En cualquier caso, la recompensa debe
poder reclamarse una sola vez.

Antes de tocar nada necesito estos ficheros:

- las escenas JSON: telmori_sheriff_reward_intro, telmori_sheriff_training,
  telmori_sheriff_pelts (para ver la cadena completa) y sheriff_briefing
  (referencia del patrón)
- el JSON del diálogo de referencia, DLG_TELMORI_SHERIFF_BRIEFING
- dialogue_option_definition.gd y dialogue_system.gd
- narrative_scene_outcome.gd y narrative_scene_viewmodel.gd
  (resume_after_dialogue())
- exploration_telmori_village.gd (spawn/retirada del interactuable
  telmori_sheriff_reward y flags de la cadena)
- el .csv de localización de diálogo de Los Telmori

Para validar sin rejugar la aventura: F2 con user://debug_shortcut.json
marcando flag.telmori_lair_cleared.
```
