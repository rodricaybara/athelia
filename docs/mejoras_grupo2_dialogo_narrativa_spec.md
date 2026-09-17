# Mejoras del pivote narrativo — Grupo 2: Diálogo con NPCs desde narrativa

*Athelia — tras el cierre de Spike 3 y del Grupo 3*

---

## Contexto

Grupo 3 (overlays de inventario/stats durante narrativa) cerró con un
hallazgo importante que cambia cómo hay que plantear este grupo: en vez de
tocar la máquina de estados, resolvió el problema haciendo que
`NarrativeScenePanel` gestione Inventory/Party/PlayerMenu como **sub-overlay
propio**, instanciado como hijo directo — sin pasar nunca por
`SceneOrchestrator` ni por `VALID_STATE_TRANSITIONS`.

Cuando se planteó la división original en 5 grupos, se asumió que el
diálogo necesitaría tocar la máquina de estados (`NARRATIVE_SCENE` solo
transiciona hoy a `EXPLORATION`/`COMBAT_ACTIVE`, no a `DIALOGUE`) y por eso
se separó de Grupo 3. Esa suposición **sigue sin confirmarse contra el
código real** — y dado que Grupo 3 demostró que el patrón barato de
sub-overlay puede aplicar donde en principio no parecía obvio, este grupo
debe volver a evaluar si el mismo patrón sirve para diálogo antes de asumir
que hace falta el camino caro.

## Objetivo de este grupo

Poder mantener una conversación real (vía `DialogueSystem`) con un NPC
desde dentro de una escena narrativa, y convertir los tramos de "Los
Telmori" que hoy son diálogo simulado en texto narrativo (el sheriff, sobre
todo) al sistema de diálogo real.

---

## Alcance

### Incluye

1. **Comprobación de código, paso 1 obligado:** revisar todos los
   consumidores de `GameState.DIALOGUE` en el proyecto — determinar si algo
   depende de que sea un estado real y distinto, o si en la práctica solo
   significa "hay un panel de diálogo abierto".
2. **Comprobación de código, paso 2 obligado:** revisar cómo
   `SceneOrchestrator._handle_dialogue()` obtiene el `dialogue_id` hoy (vía
   `_pending_context`, poblado por `request_state_change()`) y si
   `DialogueViewModel`/`DialoguePanel` podrían abrirse con una llamada
   directa parametrizada, al estilo de `open_inventory(entity_id)`, sin
   pasar por ninguna transición de estado. Esto determina si el patrón de
   sub-overlay de Grupo 3 es aplicable tal cual o exige antes construir una
   vía de apertura directa para diálogo.
3. **Comprobación de código, paso 3 obligado:** confirmar cómo se dispara
   combate desde un diálogo hoy — si ya llama a `GameLoop.start_combat()`
   de forma independiente del estado de origen (como ya hace narrativa),
   la ruta "diálogo como sub-overlay sin cambiar `GameState`" seguiría
   permitiendo que un diálogo hostil derive en combate sin fricción
   adicional.
4. Según el resultado de las tres comprobaciones, diseñar e implementar el
   mecanismo real: sub-overlay de `NarrativeScenePanel` (si es viable,
   mismo patrón que Grupo 3) o transición de estado real `NARRATIVE_SCENE
   ↔ DIALOGUE` (solo si alguna comprobación lo exige).
5. Identificar qué tramos de "Los Telmori" son conversación real con un
   personaje (el sheriff, sobre todo) y convertirlos de escena narrativa de
   texto a `DialogueSystem`.
6. Confirmar el comportamiento al volver del diálogo: la escena narrativa
   debe seguir en el mismo nodo/estado, igual que se validó para los
   overlays de Grupo 3.

### No incluye (fuera de alcance de este grupo)

- Overlays de inventario/stats — ya resuelto en Grupo 3, que sirve aquí
  como patrón de referencia, no como trabajo pendiente.
- Guardado de partida, arte narrativo, pantalla de combate — grupos aparte.
- Reescribir contenido de "Los Telmori" más allá de los tramos que resulten
  ser diálogo real — no tocar investigación, emboscada, guarida ni cierre
  salvo en las partes que se conviertan.

---

## Diseño propuesto (a validar/discutir durante el grupo, no cerrado)

- **Prioridad clara:** intentar primero el patrón de sub-overlay de Grupo 3
  — más barato, ya validado, evita tocar `VALID_STATE_TRANSITIONS`. Caer al
  cambio de estado real solo si alguna de las tres comprobaciones lo hace
  necesario, no por asunción previa.
- Si se confirma que hace falta el cambio de estado: decidir cómo vuelve
  `NARRATIVE_SCENE` al cerrar el diálogo — ¿directo al mismo nodo (análogo
  a cómo `combat_encounter` ya funciona dentro de `NarrativeSceneOutcome`),
  o reutilizando el patrón de "reconexión narrativa tras combate" (spawn de
  interactuable) ya existente? El primero es más simple si resulta viable.
- Si se opta por sub-overlay: aplicar desde el principio, no redescubrir,
  la convención ya establecida tras Grupo 3 — `signal closed` en
  `DialoguePanel`, y el mismo guard de `is_input_blocked()` que cualquier
  segundo punto de entrada de input necesita.

---

## Criterios de validación

- El resultado de las tres comprobaciones de código queda documentado antes
  de implementar nada.
- Un diálogo abierto desde una escena narrativa se completa y, al
  cerrarse, la escena narrativa sigue en el mismo nodo/estado, sin perder
  ninguna racha de tiradas en curso.
- Si el diálogo deriva en combate, se dispara correctamente y, al
  terminar, el flujo vuelve a un punto coherente.
- Al menos un tramo real de "Los Telmori" (el sheriff, si aplica) queda
  convertido de escena narrativa a diálogo real, jugable de principio a
  fin.
- Ningún acceso directo de la View narrativa a un sistema core.
- Cero warnings, tipado estricto.

---

## Riesgos y decisiones abiertas

- El alcance real depende de las tres comprobaciones de código — no
  asumir de antemano que hace falta tocar la máquina de estados solo
  porque así se pensó al dividir los 5 grupos originalmente.
- Si el diálogo sí necesita ser un `GameState` real (a diferencia de
  Inventory/Party/PlayerMenu en Grupo 3), este grupo vuelve a ser más caro
  de lo que el precedente de Grupo 3 podría sugerir — aceptarlo si las
  comprobaciones lo confirman, no forzar el patrón barato si no encaja.
- Convertir contenido ya escrito de Grupo B (la escena del sheriff)
  implica tocar JSON ya validado — verificar que no rompe ninguna
  reconexión narrativa ya construida (flags, `next_scene_id`) al hacerlo.

---

## Prompt inicial para arrancar el grupo

```
Vamos a arrancar el Grupo 2 (Diálogo con NPCs desde narrativa) de las
mejoras post-Spike 3 en Athelia. Te adjunto el documento de especificaciones
de este grupo y el informe de cierre de Grupo 3 (overlays de
inventario/stats), cuyo patrón de sub-overlay es el precedente directo a
evaluar aquí.

Antes de proponer ningún diseño, resuelve las tres comprobaciones de código
que marca el documento como paso obligado:

1. ¿Algo en el proyecto depende de que GameState.DIALOGUE sea un estado
   real y distinto, más allá de "hay un panel de diálogo abierto"?
2. ¿Cómo obtiene hoy SceneOrchestrator._handle_dialogue() el dialogue_id
   (vía _pending_context / request_state_change()), y podría
   DialogueViewModel/DialoguePanel abrirse con una llamada directa
   parametrizada, sin transición de estado?
3. ¿Cómo se dispara combate desde un diálogo hoy — de forma independiente
   del estado de origen, o asumiendo que viene de DIALOGUE?

Repórtame lo que encuentres antes de proponer nada más. Según la respuesta,
el mecanismo real puede ser un sub-overlay de NarrativeScenePanel (mismo
patrón que Inventory/Party/PlayerMenu en Grupo 3) o una transición de
estado real NARRATIVE_SCENE ↔ DIALOGUE — no asumas cuál de las dos hace
falta antes de comprobarlo.

Solo después de esas tres comprobaciones, propón el diseño concreto y qué
tramo de "Los Telmori" conviene convertir primero a diálogo real. No
implementes nada todavía — espera mi validación del diseño antes de tocar
código.
```
