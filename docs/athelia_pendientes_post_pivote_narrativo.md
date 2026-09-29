# Athelia — Pendientes tras el pivote narrativo

*Recopilación para arrancar nuevos spikes. Estado a fecha de cierre del
Grupo 4 de mejoras post-Spike 3 — "Los Telmori" jugable de principio a fin,
con arte real, guardado real y pantalla de combate de producción.
Actualizado tras el Spike 10: el punto 1 (Grupo 2, diálogo con NPCs) queda completo; antes, tras el Spike 9, el punto 6 (marco decorativo) quedó hecho.
Actualizado tras el Spike 11: el punto 6 (marco decorativo) activa
`DialoguePanel` además de `NarrativeScenePanel`; nuevo punto 8 con el
rediseño de la ventana de diálogo y su deuda técnica.*

---

## 1. Contenido incompleto — Grupo 2 COMPLETO (Spike 10)

- **Grupo 2 (diálogo con NPCs desde narrativa): completo.** Con el Spike 10
  la recompensa (`DLG_TELMORI_SHERIFF_REWARD`) y el entrenamiento
  (`DLG_TELMORI_SHERIFF_TRAINING`) del sheriff están convertidos a
  `DialogueSystem`, además del briefing. Las entregas (oro, trofeo, tomo) se
  quedaron en el outcome narrativo (camino A: `DialogueOptionDefinition` no
  tiene entregas y no se ampliaron). `telmori_sheriff_pelts` (venta de
  pieles) **no se convierte**: necesita una tirada real contra
  `skill.exploration.tanning`, que `DialogueOptionDefinition` no soporta — se
  queda como escena narrativa para siempre, no es una tarea pendiente.
  `telmori_epilogue_hook` es flavor puro y no cambia.
- Detalle en `docs/spike_10_dialogos_sheriff.md`.

---

## 2. Bugs de motor de combate (encontrados en Grupo 5, sin tratar)

1. **`ResourceSystem.resource_changed` no se reenvía a `EventBus.resource_changed`.**
   `combat_hub_viewmodel.gd` (menú de acciones, compuesto dentro de la
   pantalla de combate de producción) se conecta a la señal de `EventBus`
   — probablemente el HP/EN mostrado ahí no se actualiza en vivo. La arena
   de combate (`CombatArenaViewModel`) ya evita esto conectándose directo a
   `Resources.resource_changed`, así que el impacto real podría estar
   limitado a esa sub-parte. **Arreglo probablemente trivial** (puentear la
   señal o cambiar el punto de conexión).
2. **Typo `combat_scape`/`combat_escape`.** `combat_hud.gd` (el HUD viejo,
   compuesto dentro de la arena) mapea el slot `"escape"` a la acción
   `"combat_escape"`, pero el InputMap real usa `"combat_scape"` — el botón
   de huir por teclado probablemente no responde. **Arreglo trivial** (una
   línea).
3. **Desync `AttributeResolver` / `ResourceState.max_effective`.** El
   máximo de PV/EN derivado del personaje y el máximo genérico de
   `ResourceDefinition` (típicamente 100) no se sincronizan en ningún punto
   visible — nada llama a `Resources.set_max_effective()`. Se ha visto como
   desajustes tipo `50/60` o `50/45` (actual por encima del máximo),
   confirmado y más visible tras Grupo 4. Fernando no recuerda cómo quedó
   montado originalmente. **Necesita investigación** antes de decidir el
   arreglo — no está claro si Character Creation sí sincroniza esto en
   algún flujo y el gap es solo de un camino concreto, o si es un problema
   general.
4. **`GameLoopSystem._transition_to_phase()`: `Invalid transition: ROUND_END → TURN_END`.**
   Reproducido en combate real — las rondas se saltan número y "Round N
   ended" se imprime dos veces seguidas. No se ha confirmado si afecta al
   contador real que usan los refuerzos cronometrados (la validación de
   Grupo 5 sugiere que no, el refuerzo llegó en la ronda esperada) o si es
   puramente cosmético en el log. **Necesita investigación.**
5. **Fuga de memoria en `SceneOrchestrator._handle_combat()`.** Nunca
   guarda ni libera la instancia de `SCENE_COMBAT` — se acumula una copia
   por combate. Ya mitigada en la práctica: `combat_production_scene.gd`
   se autolibera en `combat_ended`. El problema de fondo en
   `SceneOrchestrator` sigue sin arreglar, pero no sangra hoy. **Sin
   urgencia.**
6. **`combat_resolver.gd` (`class_name CombatResolver`) parece código
   muerto.** Duplica lógica de daño con nomenclatura de fases antiguas
   ("FASE A/B/C", pre-Spike). Confirmado sin ningún fichero activo que lo
   referencie. **Limpieza, no bug.**

---

## 3. Pendientes menores de UI/UX (Grupos 4 y 5)

- Ficha de `companion_mira` muestra `??` en vez de sus iniciales —
  `CharacterState.character_name` le llega vacío. Sin investigar.
- Los 8 botones del menú de acciones de combate no muestran nombre —
  según Fernando, nunca lo han mostrado. Sospechas sin confirmar: timing
  de señales `"slots"`/`"opened"` de `CombatHudViewModel`, o `UIButton`
  gestionando el texto por su cuenta.
- La columna de enemigos se desborda por arriba con 6-8 enemigos —
  `CombatArenaPanel` no limita la altura del `GridContainer`.
- El log de combate muestra IDs internos (`telmori_warrior_3`,
  `companion_mira`) en vez de nombres localizados — incumple la regla de
  localización del proyecto.
- `telmori_lair_loot_obsidian.json.json` — doble extensión en el fichero
  real del proyecto. Carga igual (termina en `.json`), pendiente de
  renombrar.
- `CharacterDefinition.duplicate_definition()` no copia `token_color`,
  `type_icon`, `starting_skill_values` ni `loot_table_id` — confirmado sin
  ninguna llamada real a ese método en el proyecto hoy, así que sin efecto
  observable, pero latente si algo empieza a usarlo.

---

## 4. Otros bugs sueltos

- **F9 (quickload) en una sesión ya activa en `EXPLORATION` provoca
  bloqueo total de input.** Causa raíz sin confirmar. Referenciado también
  en el informe de un spike anterior (producción post-character-creation),
  así que no es nuevo de esta ronda.

---

## 5. Limpieza de schema

- `SaveData.player_state["position"]` (x, y) queda vestigial desde el
  pivote a RPG narrativo por eventos/flags — se sigue guardando/
  restaurando sin ningún efecto observable en el juego. Candidato a
  limpieza futura del schema de guardado, sin fecha decidida.

---

## 6. Marco decorativo de ventanas (Design System) — HECHO (Spike 9)

Surgido al ver el panel narrativo con fondo real por primera vez (Grupo 4).
Cerrado y validado en el Spike 9.

- **Resultado:** `UIPanel.decorative_frame` (opt-in, `false` por defecto) +
  `corner_texture`. Doble filete dibujado con `_draw()` y una única
  esquinera rotada en las 4 esquinas. Tokens `COLOR_FRAME_*`/`FRAME_*` en
  `UITokens`. Arte en `res://ui/design_system/assets/frames/`
  (`frame_corner_64x64.png` en uso, `frame_corner_96x96.png` de reserva).
- **Integración:** `NarrativeScenePanel` ya usaba `UIPanel`, así que se
  activó desde el inspector sin tocar su script. La ventana de inventario
  no cambia (el opt-in funciona).
- **Activado en diálogo (Spike 11):** `DialoguePanel` migró de
  `PanelContainer` plano a `UIPanel` como parte de su propio rediseño —
  ya con el marco activado. Detalle en el punto 8.
- **Trabajo que sigue abierto:** activar el marco en el resto de
  pantallas (inventario, party, etc.), pantalla a pantalla — nada
  específico detectado que lo bloquee, solo falta hacerlo.
- Detalle completo en `docs/spike_9_marco_decorativo_ui_panel.md`.

---

## 7. Pendientes surgidos en el Spike 10

- **Claves sin traducir en el panel de habilidades:** `SKILL_PERCEPTION_NAME`,
  `SKILL_SEARCH_NAME`, `SKILL_STEALTH_NAME` y `SKILL_TRACK_NAME` se ven como
  clave cruda en la pestaña de exploración (Esquiva y Curtido sí están
  traducidas). Anteriores al Spike 10, vistas al validar. Probablemente solo
  filas que faltan en el `.csv` de skills — sin comprobar.
- **Sin probar en partida (solo por código):**
  - El camino de fallo del libro de aprendizaje (`item_use_failed`, libro no
    consumido): se puede forzar poniendo temporalmente un `skill_id`
    inexistente en `book_tanning_basics.tres`.
  - Guardar y cargar con Curtido aprendido: `CharacterState` guarda
    `skill_values` entero y `SkillSystem.load_save_state()` recrea la
    instancia, pero no se ha visto en partida (solo se guarda desde el
    diálogo del sheriff, al principio de la aventura).
- **`challenge_too_low` sigue consumiendo el libro** (comportamiento previo
  del puente, no tocado): un libro demasiado básico para una skill alta se
  gasta sin efecto. Decidir si debería quedarse en la mochila.
- **Avisos de estilo ya existentes en `item_character_bridge.gd`**
  (`CONFUSABLE_LOCAL_DECLARATION` de `modifiers` en `_apply_consumable()`;
  `item_id` sin usar en `_apply_to_resource()`/`_apply_to_attribute()`).
  Triviales, sin efecto en ejecución.
- **Comentarios desactualizados heredados:** la cabecera de
  `narrative_scene_outcome.gd` sigue diciendo que los campos de ítem/combate
  son "inertes hasta que se cablee su aplicación" (llevan cableados desde
  Spike 3), y `_on_narrative_flag_set_lair_aftermath_cleanup()` (Grupo C)
  sigue atribuyendo `flag.telmori_lair_cleared` a `telmori_lair_victory.json`
  en vez de a `telmori_lair_loot_obsidian.json`.
- **Nombres de fichero de diálogo:** los dos diálogos nuevos se llaman
  `dlg_telmori_sheriff_*.json`, distinto del patrón del briefing; unificar es
  solo renombrar (el `id` interno manda, no el nombre de fichero).
- **Lección para futuros parches de `_apply_outcome()`:** el bloque
  `grant_item_*` desapareció en silencio. Ahora todo `grant_*` deja línea de
  log; al parchear ese método, comprobar por log que cada tipo de entrega
  sigue apareciendo.

---

## 8. Ventana de diálogo (Spike 11) — HECHO, con deuda técnica anotada

Rediseño completo de `DialoguePanel`: fondo propio, marco decorativo del
Spike 9, retrato único del NPC (se descarta el layout de dos retratos) con
estado de ánimo y fondo de ambiente por aventura/escena. Validado en
partida real de principio a fin, apertura desde escena narrativa y desde
`EXPLORATION`. Detalle completo en `docs/spike_11_ventana_dialogo.md`.

- **Tests sin adaptar:** `dialogue_node_shown` pasó de 4 a 7 argumentos
  (`mood`, `portrait_folder`, `background_id`). `dialogue_panel_test.gd`,
  `test_dialogue_system.gd` y `test_eventbus.gd` no se tocaron —
  GDScript descarta los argumentos de más al emitir una señal si el
  callback conectado acepta menos, así que deberían seguir compilando y
  pasando, pero no se ha confirmado ejecutándolos. Decidir si se adaptan
  a la firma nueva o se dejan así conscientemente.
- **Resolución de ventana pequeña (1153×643).** Con 5 opciones, el panel
  de diálogo necesita scroll incluso con la altura ya corregida (caben 3
  sin scroll). Subir la resolución base daría más margen, pero afecta a
  toda pantalla con posiciones en píxeles fijos, no solo a este panel —
  se aparcó deliberadamente como tarea de proyecto propia, fuera de
  alcance de este spike.
- **`UIPanel.Variant.OVERLAY` documentada como semitransparente pero con
  stylebox opaco en la práctica** — discrepancia menor de documentación,
  detectada en la comprobación de código previa (Fase 0) de este spike,
  sin corregir.
- **Marco decorativo activado en `DialoguePanel`** — ver punto 6, arriba.

---


Todo lo anterior salió de comprobar código real y jugar partidas
completas, no de teoría — varios de estos bugs (sobre todo los de
motor de combate) llevaban preexistiendo desde antes del pivote narrativo
y solo se hicieron visibles al ejercitar caminos reales por primera vez.
Para cualquiera de estos puntos, sigue aplicando lo que ha funcionado en
todo este pivote: comprobación de código como paso obligado antes de
diseñar, y dividir en spikes/grupos separados cuando el alcance mezcla
piezas de riesgo distinto (aquí, al menos, "arreglo trivial" vs. "necesita
investigación" es una división natural).
