# Mejoras post-Spike 3 — Grupo 3: Overlays de inventario y stats durante narrativa — Informe de cierre

*Athelia — sesión de mejoras posterior al cierre de Spike 3*

---

## Objetivo del grupo

Poder abrir Inventory (y Party/PlayerMenu, si el código lo permitía sin más
alcance del previsto) desde dentro de una escena narrativa (`GameState.NARRATIVE_SCENE`),
sin salir de la escena ni perder su progreso — incluida una racha de tiradas
acumulativas en curso.

Spec de partida: `mejoras_grupo3_overlays_narrativa_spec.md`.

---

## Comprobaciones de código obligadas (primer paso, antes de diseñar nada)

El spec exigía resolver dos preguntas contra el código real antes de proponer
ningún diseño:

**1. ¿Party y PlayerMenu siguen el mismo patrón que Inventory (overlay sin
cambio de `GameState`), o requieren un estado propio de
`VALID_STATE_TRANSITIONS`?**

Los tres — `open_inventory()`, `open_party()`, `open_player_menu()` en
`scene_orchestrator.gd` — son overlays que no cambian `GameState` (ninguno
llama a `request_state_change()`), y comparten literalmente el mismo guard
manual copiado tres veces:

```gdscript
if game_loop.current_game_state != GameLoopSystem.GameState.EXPLORATION:
    push_warning(...)
    return
```

Ninguno usa `VALID_STATE_TRANSITIONS`. No hay bifurcación real entre los
tres — el alcance del grupo **no** se redujo a solo Inventory, como
contemplaba el spec como posibilidad.

Hallazgo adicional no pedido por el spec: dentro de `PlayerMenuScreen`, las
subpantallas (Loadout, Inventory-como-subpantalla, SkillTree) no pasan por
`SceneOrchestrator.open_X()` en absoluto — `_open_subscreen()` las instancia
directamente como hijas de `PlayerMenuScreen`, sin ningún chequeo de
`GameState`. Un segundo patrón de "overlay anidado" ya existente en el
proyecto, relevante para el diseño final (ver más abajo).

**2. ¿`ExplorationController` condiciona las teclas de
inventory/party/player_menu a `GameState == EXPLORATION` explícitamente, o
solo escucha la tecla sin comprobar el estado?**

Sí, aunque no con un chequeo inline: `_unhandled_input()` empieza con
`if game_loop.is_input_blocked(): return`, con un comentario explícito en
el propio fichero ("Bloquear todo input si el GameLoop no está en
EXPLORATION"). Las teclas no "funcionaban ya sin querer" en narrativa —
estaban activamente bloqueadas por partida doble: el propio
`is_input_blocked()` en `ExplorationController`, y el guard manual dentro
de cada `open_X()` en `SceneOrchestrator`.

---

## Hallazgo crítico no anticipado por el spec

`SceneOrchestrator._current_overlay` es un **slot único**, no una pila. La
lógica de `open_inventory()` (y equivalentes) trata "hay un overlay abierto"
como toggle, sin distinguir cuál:

```gdscript
if _current_overlay and is_instance_valid(_current_overlay):
    # Ya está abierto — cerrar (toggle)
    _hide_current_overlay()
    return
```

Si esto se hubiera dejado tal cual y se hubiera ampliado el guard de estado
sin más, abrir Inventory desde dentro de una escena narrativa habría
interpretado el panel narrativo (que ocupa `_current_overlay` en
`NARRATIVE_SCENE`) como "ya hay un overlay, toggle", y lo habría
`queue_free()`eado — destruyendo `NarrativeSceneViewModel` y con él el nodo
actual y cualquier racha en curso. Justo lo que el criterio de validación 2
del spec exigía preservar.

---

## Diseño adoptado

Confirmado con el usuario antes de implementar (opción "b" de las dos
presentadas):

- **`NarrativeScenePanel` gestiona Inventory/Party/PlayerMenu como
  sub-overlay propio** (`_open_sub_overlay()` / `_close_sub_overlay()`),
  instanciándolos como hijos directos — nunca a través de
  `SceneOrchestrator`. Mismo patrón que ya usaba
  `PlayerMenuScreen._open_subscreen()` para sus propias subpantallas,
  extendido aquí a un segundo nivel de anidamiento posible
  (`NarrativeScenePanel → PlayerMenuScreen (sub-overlay) → InventoryUI
  (subpantalla propia de PlayerMenu)`).
- `SceneOrchestrator._current_overlay` sigue apuntando al panel narrativo
  durante todo el proceso — nunca se sustituye ni se libera. El slot único
  nunca llega a ser un problema real porque el sub-overlay de narrativa
  simplemente no pasa por él.
- Entrada de input respetando MVVM: `NarrativeScenePanel._unhandled_input()`
  (nuevo — el panel no tenía ninguno) escucha las mismas acciones que
  `ExplorationController` (`open_inventory`/`open_party`/`open_player_menu`)
  solo si `visible`, y delega la intención a
  `NarrativeSceneViewModel.request_open_X()` — nunca un acceso directo de
  la View a `SceneOrchestrator` ni a ningún sistema core.
- `NarrativeSceneViewModel` gana tres intenciones (`request_open_inventory`/
  `request_open_party`/`request_open_player_menu`), guardadas igual que
  `request_option()` (solo con `PanelState.SHOWING`). Ninguna toca
  `current_node` ni `_success_streaks` — el sub-overlay es responsabilidad
  íntegra de la View, el ViewModel solo emite la intención.
- `SceneOrchestrator.open_inventory()`/`open_party()`/`open_player_menu()`
  ganan `LIGHT_OVERLAY_ALLOWED_STATES` (`EXPLORATION` + `NARRATIVE_SCENE`) y
  un guard explícito que bloquea la ruta de `_current_overlay` en
  `NARRATIVE_SCENE`. Es una red de seguridad defensiva: en el diseño final
  ninguno de los tres se invoca realmente desde narrativa — si algo lo
  hiciera por error, queda bloqueado con aviso en vez de destruir el panel
  narrativo.

---

## Bugs de motor preexistentes, encontrados y corregidos

Ninguno introducido por este grupo — ambos ya existían en el proyecto y
salieron a la luz por ser la primera vez que se anida un overlay dos
niveles de profundidad.

### 1. Ninguna pantalla se auto-libera al cerrarse

`InventoryUI`, `PlayerMenuScreen`, `LoadoutScreen` y `SkillTreeScreen` (y,
antes del fix, también hubiera afectado a `PartyUI` de no tener ya su
propia señal) solo hacen `visible = false` en su camino de cierre — ninguna
llama a `queue_free()` sobre sí misma.
`PlayerMenuScreen._open_subscreen()` dependía de `tree_exiting` para saber
cuándo destruir una subpantalla cerrada — señal que, por tanto, nunca se
disparaba. No se había detectado porque hasta este grupo nadie había
necesitado *cerrar* una subpantalla anidada y comprobar que el contenedor
volvía a aparecer.

**Reproducido en playtest real:** desde una escena narrativa, abrir
PlayerMenu (sub-overlay de `NarrativeScenePanel`), y desde dentro de
PlayerMenu abrir Inventory o Loadout (subpantalla propia de PlayerMenu).
Cerrar esa capa más profunda dejaba las tres pantallas — subpantalla,
PlayerMenu, panel narrativo — colgadas invisibles, sin ninguna forma de
volver atrás. Indistinguible de un crash desde fuera (el jugador pierde
todo input, ya que `ExplorationController` sigue bloqueado por
`is_input_blocked()` en `NARRATIVE_SCENE` y `NarrativeScenePanel` no
procesa input mientras está oculto), aunque no hay ninguna excepción real
del motor de por medio.

**Corrección:** `signal closed` añadida a las cuatro pantallas
(`InventoryUI`, `PlayerMenuScreen`, `LoadoutScreen`, `SkillTreeScreen`),
emitida junto a su `visible = false`. Tanto `NarrativeScenePanel._open_sub_overlay()`
como `PlayerMenuScreen._open_subscreen()` priorizan ahora `closed` sobre
`tree_exiting` (`has_signal("closed")` como comprobación, con
`push_warning` y fallback a `tree_exiting` si algún día faltara en una
pantalla nueva).

### 2. `ExplorationHUD` sin guard de `is_input_blocked()`

A diferencia de `ExplorationController`, `ExplorationHUD._unhandled_input()`
llamaba a `SceneOrchestrator.open_skill_tree()`/`open_player_menu()` sin
comprobar el `GameState` en absoluto. Inofensivo mientras `EXPLORATION` era
el único origen legítimo (el guard interno de `SceneOrchestrator` ya
bloqueaba la llamada), pero generaba ruido real: al pulsar la tecla de
PlayerMenu durante `NARRATIVE_SCENE`, el evento lo procesaban a la vez
`NarrativeScenePanel` (correcto) y `ExplorationHUD` (bloqueado con
warning). Corregido con el mismo guard que ya tenía `ExplorationController`.

---

## Ficheros modificados

| Fichero | Cambio |
|---|---|
| `narrative_scene_viewmodel.gd` | Tres intenciones nuevas (`request_open_inventory/party/player_menu`), mismo guard que `request_option()` |
| `narrative_scene_panel.gd` | `_unhandled_input()` nuevo; `_open_sub_overlay()`/`_close_sub_overlay()`/`_on_sub_overlay_closed()` |
| `scene_orchestrator.gd` | `LIGHT_OVERLAY_ALLOWED_STATES`; guard defensivo de `NARRATIVE_SCENE` en `open_inventory()`/`open_party()`/`open_player_menu()` |
| `inventory_ui.gd` | `signal closed`, emitida en `close_inventory()` |
| `player_menu_screen.gd` | `signal closed`, emitida en `_close_all()`; `_open_subscreen()` prioriza `closed` sobre `tree_exiting` |
| `loadout_screen.gd` | `signal closed`, emitida en el caso `"closed"` |
| `skill_tree_screen.gd` | `signal closed`, emitida en el caso `"closed"` |
| `exploration_hud.gd` | Guard `GameLoop.is_input_blocked()` en `_unhandled_input()` |

`party_ui.gd` no necesitó cambios — ya tenía `signal closed` desde antes de
este grupo.

---

## Validación realizada

- Apertura de Inventory/Party/PlayerMenu desde una escena narrativa (tecla),
  sin recargar el nodo actual ni perder la racha de tiradas acumulativas en
  curso.
- Cambio real dentro del sub-overlay (equipar/desequipar un ítem) reflejado
  correctamente.
- Navegación completa Loadout → Inventory → SkillTree dentro de PlayerMenu,
  siendo PlayerMenu a su vez sub-overlay de la escena narrativa — sin
  colgarse en ningún punto de cierre, incluyendo el cierre de SkillTree con
  ESC (sin botón de cierre propio).
- Regresión confirmada: el camino normal de apertura desde `EXPLORATION`
  (vía `SceneOrchestrator`, overlay top-level) sigue funcionando sin
  cambios de comportamiento ni warnings nuevos.
- Cero warnings ni errores en el log final de validación.

---

## Pendientes / notas para futuras sesiones

- El fallback a `tree_exiting` en `_open_sub_overlay()`/`_open_subscreen()`
  sigue ahí por si una pantalla nueva se añade sin señal `closed` — emite
  `push_warning` si se usa, para que no vuelva a pasar desapercibido.
- Diálogo con NPCs desde narrativa (Grupo 2 de las mejoras post-Spike 3)
  queda fuera de este grupo, tal como delimitaba el spec — comparte la
  pregunta de fondo ("¿qué puede interrumpir una escena narrativa sin
  romperla?") pero toca `VALID_STATE_TRANSITIONS`, cosa que este grupo
  explícitamente no tocó.

Godot 4.7.2.
