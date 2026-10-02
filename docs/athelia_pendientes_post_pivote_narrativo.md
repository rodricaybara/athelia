# Athelia — Pendientes tras el pivote narrativo

*Recopilación para arrancar nuevos spikes. Estado a fecha de cierre del
Grupo 4 de mejoras post-Spike 3 — "Los Telmori" jugable de principio a fin,
con arte real, guardado real y pantalla de combate de producción.
Actualizado tras el Spike 10: el punto 1 (Grupo 2, diálogo con NPCs) queda completo; antes, tras el Spike 9, el punto 6 (marco decorativo) quedó hecho.
Actualizado tras el Spike 11: el punto 6 (marco decorativo) activa
`DialoguePanel` además de `NarrativeScenePanel`; nuevo punto 8 con el
rediseño de la ventana de diálogo y su deuda técnica.
Actualizado tras el Spike 12: nuevo punto 9 (motor de escenas interactivas /
mapa de puntos de interés, cerrado) con el trabajo que deja abierto para el
Spike 13; el punto 5 gana una nota (`SaveSystem` ya no exige nodo `Player`).
Actualizado tras el Spike 13: el punto 9 queda HECHO (el pueblo de "Los Telmori"
está migrado al motor de escenas interactivas y se juega completo); nuevo punto 10
con lo que el spike deja abierto — sobre todo limpieza de `Interactable` y del
pueblo antiguo, una guarda general de ids narrativos inexistentes, marcadores de
contenido y validaciones sin confirmar.*

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
- **Actualizado en el Spike 12:** `SaveSystem._collect_player_state()` ya no
  exige un nodo `Player` — si falta (mapa de puntos de interés, sin jugador
  físico) guarda sin la clave `position` y sigue guardando; antes abortaba
  con `Player node not found`. La restauración ya toleraba `Player` ausente.
  `position` sigue vestigial, pero ahora es una clave OPCIONAL: retirarla del
  schema ya no bloquea nada, solo requiere quitar escritura/lectura y decidir
  si hace falta migración de `SAVE_VERSION`.

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

## 9. Motor de escenas interactivas (Spike 12) — HECHO; contenido real hecho en el Spike 13 (ver punto 10)

Mapa de puntos de interés: fondo + hotspots clicables posicionados por datos
+ visibilidad por flags, sin jugador ni física. Cerrado y validado en partida
real con `poi_test_map` (dialogue, shop, narrative_scene, combat con
`enemy_definitions`, `required_flags`/`blocked_flags`, guardado y carga sin
`Player`). Detalle en `docs/spike_12_motor_mapa_poi.md`.

**Estado actual (tras el Spike 13):** `SceneOrchestrator.SCENE_EXPLORATION` apunta a
`exploration_interactive_map.tscn`, que ahora carga `telmori_village`; el mapa de PRUEBA
(`poi_test_map`) queda disponible cambiando `interactive_scene_id`.

**Spike 13 — HECHO (ver punto 10).** Lo que dejó abierto el Spike 12 y cómo se resolvió:
inicialización de partida → `AdventureStarter` + `on_first_visit`; spawns por evento →
hotspots declarativos (en realidad un hub completo con sheriff, herrería, taberna y salida);
flag de victoria → escena de victoria de combate; arte, `UIButton` y localización → hechos;
pueblo antiguo → obsoleto. Texto original del trabajo pendiente, conservado como historia:

- **Inicialización de partida que vivía en `TelmoriVillage._ready()`:**
  `Party.join_party("companion_mira")`, equipo inicial de `player` y
  `companion_mira`, y la primera entrada narrativa
  (`telmori_village_arrival`, guard `flag.telmori_village_visited`). El mapa de
  prueba las omite (por eso el guardado muestra `Equipment 0 slots` /
  `Party 0 companions`). Decidir dónde viven — fuera de la escena y
  data-driven.
- **Los 3 spawns por evento del pueblo → hotspots declarativos**, con sus
  `required_flags`/`blocked_flags`:
  rastro (`flag.telmori_ambush_triggered` / `flag.telmori_tracked_to_lair`),
  aftermath de la guarida (`flag.telmori_lair_combat_won` /
  `flag.telmori_lair_cleared`) y recompensa del sheriff
  (`flag.telmori_lair_cleared` / `flag.telmori_adventure_completed`). Los 5
  listeners de `combat_ended`/`narrative_flag_set` de `TelmoriVillage` se
  eliminan con la escena.
- **Flag de victoria de la emboscada:** hoy el rastro solo aparece tras
  *ganar* (`combat_ended "victory"`), pero `flag.telmori_ambush_triggered` se
  pone al *disparar* el combate — como hotspot, el rastro aparecería también
  tras una derrota. Hace falta un flag puesto al ganar.
- **Arte y UI:** fondo e iconos reales; sustituir los `Button` estándar por
  `UIButton`/componente del Design System; claves de localización reales (las
  `POI_TEST_*` son solo de prueba y hay que darlas de alta en un `.csv`
  registrado en Project Settings → Localization).
- **Retirar o migrar** `exploration_telmori_village.*` y decidir el estado
  final de `SCENE_EXPLORATION`. `exploration_tutorial` y `exploration_test` (que
  también instancian `Interactable`) siguen obsoletos y sin retirar.

**Sin verificar en partida:**

- El camino físico de `Interactable` tras el refactor de `ExplorationController`
  (`_on_interaction_requested()` delega ahora en `request_interaction()`).
  Revisado por inspección, comportamiento idéntico por diseño, pero no jugado de
  extremo a extremo — se cubrirá naturalmente si se rehace el arco de la
  emboscada sobre el pueblo antiguo o al migrar en Spike 13. **Spike 13: descartado** — el pueblo no usa `Interactable` y se descartaron el tutorial y el test; no se validará (ver punto 10).
- Sin cambios respecto al punto 4: F9 sigue sin operar.

**Pequeñas notas de deuda:**

- El `@export_enum` de `interactable.gd` no lista `"narrative_scene"` (solo
  `dialogue`/`shop`/`combat`/`item`); funciona porque el valor se asigna con
  `set()` desde código. Cosmético; corregible añadiendo el valor al enum.
- `ExplorationHUD` exige su jerarquía de hijos exacta (`InteractPrompt`,
  `ResourcesPanel/HP|Stamina|Gold`, `StateDebugLabel`, todos con `$` en
  `@onready`) — cualquier escena de exploración nueva debe copiarla tal cual.
- El atajo F2 (`user://debug_shortcut.json`) NO lee la raíz del proyecto: en
  Windows `user://` es `%APPDATA%\Godot\app_userdata\<nombre del proyecto>\`
  (o Proyecto → Abrir carpeta de datos de usuario). Un fichero junto a
  `project.godot` da `file not found` — el warning prueba que la tecla sí llega.
- Los tests de Spike 12 fueron todos manuales (log + captura); no hay test

## 10. Pendientes surgidos en el Spike 13

El pueblo de "Los Telmori" está migrado y la aventura se juega completa sobre el motor
nuevo (ver `docs/spike_13_reautoria_pueblo_telmori.md`). Lo que deja abierto:

**Limpieza (sin urgencia; acción de la recopilación final, no de un spike de contenido):**

- **`Interactable` vestigial.** Sin consumidores en el camino jugable: el pueblo es
  declarativo y Fernando descartó `exploration_tutorial` y `exploration_test`. Candidatos a
  borrar: `exploration_tutorial.*`, `exploration_test.*`, `exploration_test_bak.tscn`,
  `interactable.gd` y sus referencias tipadas en `ExplorationController`
  (`_current_interactable`, `register_interactable`...); los comentarios que lo mencionan en
  `narrative_scene_outcome.gd`, `interactive_hotspot_definition.gd`, `scene_orchestrator.gd` y
  `exploration_interactive_map.gd`; y las líneas comentadas de `SCENE_EXPLORATION`. **Antes de
  borrar, buscar referencias** (escena principal, runners de test, otros `.tscn`). El camino
  físico refactorizado en Spike 12 (`request_interaction()`) nunca se validó en partida real y
  no se va a validar.
- **Pueblo antiguo:** `exploration_telmori_village.gd/.tscn` (obsoleto desde el Spike 13).
- **Escenas narrativas sin uso:** `telmori_equipment_arrows`, `telmori_equipment_spear` y su
  flag huérfano `flag.telmori_equipped`; cualquier resto de la escena envoltorio
  `telmori_sheriff_briefing`. Los flags `flag.telmori_mission_accepted`,
  `flag.telmori_ambush_triggered` y `flag.telmori_lair_combat_won` ya no los pone ni lee
  nadie (pueden quedar en saves antiguos o en atajos de `debug_shortcut.json`).
- **Escenas de prueba del motor** (`poi_test_combat_victory`, `poi_test_victory` y el hotspot
  `test_victory_chain` de `poi_test_map`): decidir si se quedan como fixture de pruebas.

**Motor / código:**

- **Guarda general de ids narrativos inexistentes** en
  `SceneOrchestrator._handle_narrative_scene()`: abrir una escena con un id que no existe deja
  un panel vacío sin salida desde cualquier origen. Solo se protegió la ruta de victoria de
  combate.
- **`take_item_target` cubre una sola entidad** (`"player"` por defecto): valorar `"party"` si
  la lanza prestada puede pasar a un companion.
- Un hotspot de tipo `combat` no puede dar una `victory_scene_id` (`request_interaction()` llama
  a `start_combat()` sin ella; hoy solo la usan los combates lanzados desde narrativa).
  Ampliar el vocabulario del hotspot si hace falta.

**Contenido y arte:**

- **`telmori_village_departure`** es un MARCADOR de una opción: decidir qué ocurre al salir del
  pueblo con la aventura completada.
- **Posadero:** esqueleto con retrato (`guard`), fondo (`sheriff_office`) y hablante
  (`innkeeper`) provisionales. Faltan arte propio, alta del hablante si procede y los textos
  definitivos (los de rumores y sheriff son una propuesta).
- **Etapa 4 sin guardado (deliberado):** la cadena de recompensa entrega oro y trofeo al
  pulsar; un guardado dentro permitiría cobrar dos veces. No abrir uno sin cerrar antes la
  reentrada.
- **Iconos:** primera tanda de 4 medallones. Pulido posible (interior más oscuro en futuras
  generaciones, un pulso en reposo). Un hotspot sin icono cae a botón de texto.
- **Escena de rastros interactiva / "buscar algo oculto en la imagen":** sigue sin decidir ni
  construir; hoy `telmori_post_ambush_tracking` es una escena narrativa con tirada de Rastrear.

**Validación sin confirmar (marcada así en el cierre del spike):** un segundo punto de
guardado distinto (la spec pedía dos); ganar un combate sin escena de victoria y la derrota
(solo comprobables con `poi_test_map`); lanza equipada frente a vendida; que "Salir" del
sheriff no marque `flag.telmori_sheriff_briefed`.

**Documentación:** el árbol de `docs/` de `athelia_estructura_proyecto_actualizado.md` no
lista los informes de los Spikes 10–12. Renombrar el diálogo del briefing a
`dlg_telmori_sheriff_briefing.json` (opcional: el cargador usa el `id` interno, pero la
colisión de nombres con la escena narrativa ya se sufrió).

**Sin cambios:** F9 (quickload) sigue no operativo desde el Spike 7. Los tests del Spike 13
fueron manuales (log y captura), sin test automatizado.

  automatizado del motor.

---

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
