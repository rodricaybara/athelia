# Spike 1 — Motor Narrativo Base — Informe de Cierre

*Athelia — Pivote hacia RPG narrativo*

Estado: **Validado**. Escena de prueba recorrida de punta a punta en ambas
ramas (éxito/fallo), flag aplicado, vuelta a exploración limpia, cero
warnings en el Output.

---

## Alcance completado

Contra el documento de spec original (`spike1_motor_narrativo_spec.md`):

| Punto del alcance | Estado |
|---|---|
| `narrative_scene_definition.gd` (Resource: imagen, texto, opciones) | ✅ |
| Opción con texto, requisito de tirada opcional, destino por grado, consecuencias simples | ✅ |
| ViewModel + View siguiendo contrato MVVM (`enum` de estados, `changed(reason)`, ViewModel hijo de la View, sin `await` en la View) | ✅ |
| Integración con `SkillRoller` sin tocar su lógica de cálculo | ✅ |
| Registro en `SceneOrchestrator`, patrón Shop/Inventory/Party | ✅ |
| Escena de prueba mínima y desechable | ✅ — `test_intro` → tirada de percepción → `test_success` / `test_failure` → cierre |

## Diferido explícitamente a Spike 2

Dos decisiones se discutieron a fondo durante el diseño, quedaron
técnicamente resueltas (el enganche está identificado y validado en el
diseño, no en código), y se aparcan deliberadamente para no mezclar riesgo
de reglas de RuneQuest con el riesgo de motor que este spike debía validar:

- **Grado de resultado "especial".** `SkillRoller.RollResult` solo tiene
  `FUMBLE`, `FAILURE`, `SUCCESS`, `CRITICAL` — 4 grados, no los 5 que el
  spec original asumía (herencia de RuneQuest clásico). El contrato de
  datos de `NarrativeSceneOption` refleja esto: no existe
  `outcome_special`. Si Spike 2 añade el grado, hay que tocar
  `skill_roller.gd` (afecta también a combate, no es un cambio aislado a
  narrativa) y añadir el campo correspondiente aquí.
- **Progresión de skill narrativa.** Análisis completo ya hecho:
  `SkillProgression.notify_skill_outcome()` NO sirve (hard-gated a
  `_combat_active`, modelo de ticks pensado para el ciclo de vida de un
  combate). El punto de enganche correcto es
  `SkillProgression.execute_learning_session()` — ya usado por libros/
  entrenadores, sin requerir combate, sin generar estrés. Falta decidir:
  `SourceType` (reusar `PRACTICE` vs. añadir `NARRATIVE` — 3 líneas en
  `learning_session.gd`) y añadir `challenge_level: int` a
  `NarrativeSceneOption` (no puede defaultear a `0` —
  `LearningSession.is_valid()` exige `source_level > 0`).

---

## Inventario de ficheros

### Nuevos

```
core/narrative_scenes/
├── narrative_scene_definition.gd     # Resource: escena (imagen, texto, opciones)
├── narrative_scene_option.gd         # Resource: opción (tirada, referencias a outcomes)
├── narrative_scene_outcome.gd        # Resource: destino/consecuencias (fichero propio, ver Lecciones)
└── narrative_scene_registry.gd       # [Autoload: NarrativeSceneDB] carga JSON → Resource

ui/narrative_scene/
├── narrative_scene_viewmodel.gd      # enum PanelState, changed(reason), open()/request_option()
├── narrative_scene_panel.gd          # View — %SceneImage, %SceneText, %OptionsContainer
└── narrative_scene_panel.tscn        # Montado a mano, ver estructura en el propio spike

data/narrative_scenes/
├── test_scene_intro.json             # Escena de prueba desechable
├── test_scene_success.json
└── test_scene_failure.json

localization/
└── narrative_scenes.csv              # Claves de la escena de prueba
```

### Ficheros existentes con parche aplicado

| Fichero | Cambio |
|---|---|
| `core/game_loop_system.gd` | `GameState.NARRATIVE_SCENE` (enum + `VALID_STATE_TRANSITIONS` en ambas direcciones), `enter_narrative_scene()`, `is_input_blocked()`, guard de `start_combat()` |
| `core/event_bus.gd` | `signal narrative_scene_closed(scene_id: String)` + debug listener |
| `core/scene_orchestrator.gd` | `OVERLAY_NARRATIVE_SCENE`, `_handle_narrative_scene()`, `_on_narrative_scene_closed()` |
| `scenes/exploration/exploration_controller.gd` | Tecla de debug F1 — **temporal, a eliminar antes de Spike 3** |

### Autoload nuevo registrado

`NarrativeSceneDB` → `res://core/narrative_scenes/narrative_scene_registry.gd`

---

## Decisiones de diseño de este spike

- **Vive fuera de `core/narrative/`** (que aloja `NarrativeSystem`/
  `CheckpointSystem`, responsables de hitos recordados) — este sistema
  resuelve "qué nodo se muestra ahora", responsabilidad distinta.
- **Sin "system" runtime propio** — solo un registry (`NarrativeSceneDB`,
  consulta local síncrona). El estado de progreso por la escena vive
  enteramente en el ViewModel, igual que cualquier otra pantalla MVVM del
  proyecto. A diferencia de `DialogueSystem`, no hace falta un autoload
  con estado propio porque no hay ningún timing problem que resolver (ver
  siguiente punto).
- **JSON como fuente de autoría** (no `.tres`), un fichero por escena —
  mismo patrón que `DialogueRegistry`, pensado para el volumen de
  contenido real de Spike 3.
- **Flags de consecuencia van directos a `Narrative.set_flag()`** — no a
  `Checkpoints` (que solo consolida en transiciones de acto). Confirmado
  contra el uso real en `game_loop_system.gd`.
- **Combate se dispara con `GameLoop.start_combat(enemy_ids: Array[String])`**
  directamente desde `NARRATIVE_SCENE` — se añadió ese estado al guard de
  `start_combat()` precisamente para evitar un salto innecesario por
  `EXPLORATION` primero.
- **Cierre desacoplado vía `EventBus.narrative_scene_closed`** — el
  ViewModel no llama a `GameLoop` para volver a `EXPLORATION`; emite un
  evento de dominio y `SceneOrchestrator` decide, mismo patrón que
  `dialogue_ended`/`shop_closed`.
- **No hace falta señal de apertura** — a diferencia de `shop_open_requested`
  (que existe porque `EconomySystem` procesa la apertura de forma
  asíncrona), `NarrativeSceneDB.get_scene()` es una consulta local
  síncrona. El `scene_id` viaja gratis por `_pending_context`, igual que
  `dialogue_id`/`shop_id`.

---

## Lecciones técnicas (para `learnings.md` / futuros spikes)

Dos gotchas reales de GDScript que costaron varias iteraciones de depuración
y no son obvios:

1. **Un script no puede referenciar de forma fiable su propio `class_name`
   dentro de sí mismo.** `NarrativeSceneOutcome.new()` dentro del propio
   `narrative_scene_outcome.gd` (y lo mismo en `NarrativeSceneOption`/
   `NarrativeSceneDefinition`) provocaba fallos de compilación en cascada
   ("Identifier not found") que además rompían la resolución del tipo
   desde *otros* ficheros. Fix: usar `new()` a secas dentro de factory
   methods estáticos — instancia el script actual sin pasar por la tabla
   global de clases. Aplica a cualquier patrón `from_dict()`/`from_json()`
   futuro en el proyecto.
2. **`SceneState` es una clase nativa del motor** (la usa `PackedScene`
   internamente) — nombrar un enum propio igual provoca
   `"The member X shadows a native class"` y errores de tipado en cascada.
   La propia guía de arquitectura ya usaba el nombre correcto en su
   ejemplo de contrato (`PanelState`) — este spike lo confirma como el
   nombre a usar siempre para el enum de estado de un ViewModel, nunca
   `SceneState`.

Un tercer hallazgo, de infraestructura de testing más que de GDScript:
**`SceneOrchestrator._handle_exploration()` busca un nodo llamado
exactamente `"ExplorationScene"`** bajo la raíz del árbol. Ejecutar
`exploration_test.tscn` suelto con F6 sin que su nodo raíz tenga ese nombre
provoca un `add_child()` en medio del arranque del árbol
("Parent node is busy setting up children"). Renombrar el nodo raíz de
`exploration_test.tscn` a `ExplorationScene` lo resuelve. No es un bug de
este spike, pero bloqueaba la validación y merece quedar anotado.

---

## Validación — log de referencia

**Rama fallo:**
```
[SkillRoller] [NarrativeScene:skill.exploration.perception] ✗ D100=54 vs 45% → FAILURE (margin: -9)
[EventBus] narrative_scene_closed ← test_failure
[GameLoopSystem] State: NARRATIVE_SCENE → EXPLORATION
```

**Rama éxito (con flag):**
```
[SkillRoller] [NarrativeScene:skill.exploration.perception] ✓ D100=35 vs 45% → SUCCESS (margin: +10)
[EventBus] narrative_flag_set ← flag.test_narrative_heard_sound
[NarrativeSystem] Flag SET: flag.test_narrative_heard_sound
[EventBus] narrative_scene_closed ← test_success
[GameLoopSystem] State: NARRATIVE_SCENE → EXPLORATION
```

Los 4 criterios de validación del spec se cumplen: recorrido completo,
lectura correcta de `SkillRoller`, cero acceso a sistemas core desde la
View, sin warnings.

Nota aparte, no atribuible a este spike: los caracteres de
`SkillRoller.print_roll_result()` (`✗`/`✓`/`→`) salen mal codificados en
la consola de Fernando (probable CP1252 en vez de UTF-8) — comportamiento
preexistente de una función que no se ha tocado.

---

## Limpieza pendiente antes de Spike 3

- Eliminar la tecla de debug F1 y `_debug_test_narrative_scene()` de
  `exploration_controller.gd`.
- Eliminar `data/narrative_scenes/test_scene_*.json` y las claves
  `TEST_NARRATIVE_*` de `localization/narrative_scenes.csv` — o dejarlas
  como fixture de test si se decide formalizar tests automatizados para
  este sistema (no se ha hecho en Spike 1, no había test unitario
  equivalente a `test_character_creation_viewmodel.gd` para este
  ViewModel — candidato a considerar).

---

## Qué abre esto para Spike 2

- Reglas de RuneQuest que "Los Telmori" exige: tiradas acumulativas,
  tiradas opuestas de grupo, modificadores dinámicos de escena, moral y
  refuerzos cronometrados en combate.
- Grado "especial" en `SkillRoller` (si el contenido real lo necesita).
- Progresión de skill narrativa — diseño ya cerrado en este spike, lista
  para implementar: `SourceType` a decidir, `challenge_level` a añadir al
  contrato de datos.
