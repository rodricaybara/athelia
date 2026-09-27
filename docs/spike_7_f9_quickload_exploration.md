# Spike 7 — F9 quickload bloquea input en EXPLORATION

**Estado:** Cerrado sin arreglo — funcionalidad marcada como no operativa
**Origen:** Bug de motor documentado en `current-state.md` y en
`athelia_pendientes_post_pivote_narrativo.md` (punto 4, "Otros bugs
sueltos"). Anterior al pivote narrativo.
**Cierre:** El síntoma original (bloqueo total de input) no se reprodujo
tras el pivote. Se encontró y arregló un bug real distinto en el mismo
área (F9 no restauraba el punto narrativo correcto), pero ese arreglo
introdujo un segundo bug — un panel narrativo que se abre pero no responde
a clics — que quedó sin resolver pese a una investigación extensa. Se
decide no seguir invirtiendo tiempo y dejar F9/quickload en sesión activa
no operativo.

---

## Fase 0 — Reproducción y actualización de hipótesis (completada)

Resultado: el síntoma original documentado antes del pivote narrativo
(bloqueo total de input al pulsar F9 en `EXPLORATION`) **no se reprodujo**
tal cual. Se comprobaron dos escenarios que parecían el mismo bug y no lo
eran:

- F9 pulsado mientras el `GameState` real era `NARRATIVE_SCENE` (por una
  escena narrativa sin fondo asignado, fácil de confundir con
  "input bloqueado"): comportamiento correcto y esperado —
  `GameLoopSystem.is_input_blocked()` bloquea F9 igual que cualquier otra
  acción en ese estado, a propósito. No es un bug.
- F9 pulsado en `EXPLORATION` real, tras ganar el combate de la emboscada:
  aquí sí había un bug, pero no era un bloqueo de input — la carga
  funcionaba, pero el jugador no acababa en el punto narrativo correcto.

## Fase 1 — Primer arreglo: F9 no restauraba el punto narrativo (resuelto)

**Causa raíz:** `ExplorationController._quickload()` llamaba a
`SaveSystem.load_game()` pero nunca consultaba
`SaveSystem.get_pending_narrative_scene_id()` — a diferencia de
`MainMenuViewModel.request_load_game()`, que sí lo hacía y decidía entre
`GameLoop.enter_narrative_scene()` / `enter_exploration()`. Si el save
correspondía a un punto dentro de una escena narrativa (guardado en un NPC
savepoint), F9 restauraba todos los datos (flags, posición, equipo, party)
pero dejaba al jugador deambulando en `EXPLORATION` en vez de llevarlo a
la escena narrativa que le correspondía.

**Arreglo aplicado:** se centralizó la decisión en un método nuevo,
`GameLoopSystem.enter_post_load_state(save_manager)`, consumido tanto por
`MainMenuViewModel.request_load_game()` como por
`ExplorationController._quickload()` — evita duplicar ese criterio en cada
punto de carga presente o futuro.

Este arreglo funcionó correctamente y sigue en el código.

## Fase 2 — Segundo bug descubierto: panel narrativo sin respuesta (sin resolver)

Al validar el arreglo de la Fase 1 apareció un bug nuevo: tras F9 en una
sesión que acababa de pasar por el combate de la emboscada, el panel
narrativo correcto se abría (contenido visible, texto y botón
renderizados con normalidad) pero **el botón de opción no respondía a
clics** — ni hover, ni clic, ningún rastro en el Output. Cargar la misma
partida desde el menú principal siempre funcionó sin problema.

### Investigación realizada (todo descartado, en orden)

1. `GameState` incorrecto en el momento del clic — descartado, confirmado
   `NARRATIVE_SCENE` correcto vía debug print.
2. Árbol pausado (`get_tree().paused`) — descartado, confirmado `false`
   vía `StateDebugLabel` en el HUD.
3. Ratón capturado (`Input.MOUSE_MODE_CAPTURED`) — descartado, grep de
   todo el proyecto sin resultados para `MOUSE_MODE`.
4. `mouse_filter` / `disabled` / `focus_mode` del botón y sus contenedores
   padre — descartado, todos con valores normales y esperados para el
   Design System.
5. Nodos residuales de la sesión anterior (`CombatHud`, `CombatScene`,
   `NarrativeScenePanel` duplicado, `MainMenuScreen` visible de fondo) —
   descartado en el árbol Remote, un único nodo de cada tipo en todo
   momento.
6. `mouse_passthrough` / `WINDOW_FLAG_MOUSE_PASSTHROUGH` a nivel de
   ventana — descartado, grep sin resultados.
7. `ExplorationScene` y sus overlays viven como hermanos de
   `current_scene` bajo `get_tree().root` (no como hijos) —
   `get_tree().reload_current_scene()` no los destruye, así que una
   recarga de escena "limpia" no lo era: el `ExplorationScene` viejo (con
   todo el estado de la sesión de combate) sobrevivía y se reutilizaba.
   **Este fue el hallazgo más sólido de toda la investigación** — se
   corrigió liberando explícitamente ese nodo antes de la recarga — pero
   **el bug persistió incluso con esta corrección aplicada y verificada**
   (confirmado que `ExplorationScene` se recreaba desde cero en la
   siguiente reproducción).
8. Ningún autoload del proyecto define `_input()` / `_unhandled_input()`
   (grep completo del proyecto) — descarta cualquier interferencia de
   input a nivel de autoload, incluido el autoload `Bridge`
   (`item_character_bridge.gd`, sin relación con input).
9. Ni siquiera `_input()` (el nivel más bajo de entrada de Godot, previo a
   la GUI) se disparaba al hacer clic, con foco de ventana confirmado y
   ventana de proceso separada del editor — indica que el evento no
   llegaba al proceso del juego en absoluto, por una vía que no se llegó
   a identificar.

### Estado final

No se encontró la causa raíz. Se agotaron las vías investigables
razonables (estructura del árbol de escena, estado del juego, todos los
autoloads, input a nivel de motor) sin dar con el punto exacto donde se
pierde el evento de clic.

## Decisión de cierre

- F9/quickload en sesión activa (`EXPLORATION`) queda **no operativo**:
  el arreglo de la Fase 1 sigue en el código (correcto en su lógica) pero
  el flujo completo se ve bloqueado por este segundo bug sin resolver.
- **"Cargar Partida" desde el menú principal no está afectada** — es el
  único camino de carga fiable en este momento y sigue funcionando con
  normalidad.
- Pendiente de decisión de producto: retirar la hotkey F9 por completo, o
  dejarla tal cual con este problema conocido (actualmente, pulsarla tras
  combate dejaría al jugador con un panel sin respuesta — peor
  experiencia que si no hiciera nada. Recomendación: si no se retoma la
  investigación a corto plazo, desactivar la hotkey F9 en
  `ExplorationController` en vez de dejarla en este estado).

## Fuera de alcance (sigue igual)

- Cualquier otro bug de motor no relacionado con F9/quickload
- El guard `_is_processing` muerto de `GameLoopSystem` (Spike 6)
- La fuga de memoria de `SceneOrchestrator._handle_combat()` y
  `combat_resolver.gd`
- El warning `[PartyManager] 'companion_mira' already in party` observado
  durante esta investigación (aparece también en el camino del menú
  principal, que sí funciona — no es parte de este bug, pero es un bug
  real menor a registrar aparte: `PartyManager` no limpia su lista de
  companions al cargar partida)
