# Spike 13 — Reautoría: pueblo de "Los Telmori" sobre el motor de escenas interactivas

**Estado:** Cerrado. Validación parcial (ver "Resultado del spike", al final de este documento)
**Origen:** Cierre de contenido pendiente tras Spike 12 (motor de escenas
interactivas, cerrado). El motor está validado con un mapa de prueba
(`poi_test_map`); este spike aplica ese motor al contenido real del pueblo.
**Riesgo:** Medio-alto. No es solo reautoría de datos — hay una
inicialización de partida real que vive hoy en código de la escena a
migrar (`TelmoriVillage._ready()`), un bug real a corregir (flag de
victoria de la emboscada), y un camino sin validar de extremo a extremo
(`Interactable` físico) que este spike sí ejercitará al fin en partida
real.
**Depende de:** Spike 12 (motor), cerrado.
**Tipo de spike:** Contenido de motor + migración, no investigación.

---

## Contexto

Spike 12 dejó `SCENE_EXPLORATION` apuntando al mapa de prueba
(`exploration_interactive_map.tscn` con `interactive_scene_id =
"poi_test_map"`), con la línea del pueblo comentada y revertible. Este
spike decide el estado final: sustituir el contenido real del pueblo de
"Los Telmori" (hoy en `exploration_telmori_village.gd`/`.tscn`) por una
`InteractiveSceneDefinition` real, con sus hotspots correspondientes.

## Deudas heredadas de Spike 12 (alcance de este spike)

1. **Inicialización de partida que vive en `TelmoriVillage._ready()`**:
   `party.join_party("companion_mira")`, `_equip_starter_gear` (player y
   companion), y la primera entrada a `telmori_village_arrival`
   (guardada tras `flag.telmori_village_visited`). El mapa de prueba las
   omite por completo — hay que decidir dónde viven ahora que la escena de
   exploración es genérica y data-driven, no un script específico del
   pueblo.
2. **Los 3 `Interactable` creados por código en `exploration_telmori_village.gd`**
   pasan a hotspots declarativos en el JSON:
   - Rastro: `required_flags: [flag.telmori_ambush_triggered]`,
     `blocked_flags: [flag.telmori_tracked_to_lair]`
   - Aftermath: `required_flags: [flag.telmori_lair_combat_won]`,
     `blocked_flags: [flag.telmori_lair_cleared]`
   - Recompensa del sheriff: `required_flags: [flag.telmori_lair_cleared]`,
     `blocked_flags: [flag.telmori_adventure_completed]`

   Los 5 listeners de `combat_ended`/`narrative_flag_set` que hoy
   gestionan estos spawns en el pueblo se eliminan junto con la escena —
   la visibilidad declarativa del motor de Spike 12 los sustituye.
3. **Bug real a corregir, no solo migrar:** `flag.telmori_ambush_triggered`
   se marca al *disparar* el combate de la emboscada, no al ganarlo. Migrado
   tal cual a hotspot declarativo, el rastro aparecería también tras una
   derrota (que hoy no es posible porque el spawn está atado a
   `combat_ended "victory"`, evento que solo llega si se gana). Hace falta
   un flag nuevo puesto específicamente al ganar ese combate concreto, y
   usar ESE en `required_flags` del hotspot de rastro — no
   `telmori_ambush_triggered`.
4. **Arte real:** fondo del pueblo e iconos por hotspot, sustituyendo los
   placeholders de prueba. Mismo método que Grupo 4: prompts con el primer
   de estilo ya usado, generados por Fernando fuera de la conversación.
5. **Sustituir `Button` estándar por el componente real del Design System**
   (`UIButton` o el que corresponda) en `HotspotLayer`.
6. **Localización real**, sustituyendo las claves de prueba
   (`POI_TEST_DIALOGUE`, `POI_TEST_SHOP`, `POI_TEST_NARRATIVE`,
   `POI_TEST_COMBAT`, `POI_TEST_GATED`, `POI_TEST_BLOCKED`).
7. **Validar de extremo a extremo el camino físico de `Interactable`**
   tras el refactor de `request_interaction()` en Spike 12 — quedó
   revisado por inspección, no jugado en partida real, porque
   `SCENE_EXPLORATION` ya apuntaba al mapa de prueba cuando se cerró ese
   spike. Este spike sí lo ejercita, porque el pueblo real vuelve a usar
   `Interactable` para los tres hotspots dinámicos... **o no, si se decide
   convertirlos también a declarativos (punto 2)** — en ese caso, la
   validación de `Interactable` físico necesita un camino alternativo
   (revisar si algún otro punto del juego lo sigue usando, o forzarlo con
   una prueba dedicada aparte).

## Punto de diseño a decidir en sesión

Con los 3 `Interactable` migrados a hotspots declarativos (punto 2), el
pueblo real dejaría de usar `Interactable` físico por completo. Eso deja
sin validar en partida real el camino que Spike 12 dejó pendiente (punto
7), y además vacía de uso real el componente `Interactable` en todo el
proyecto salvo que exista otra localización que lo use. Antes de migrar
los 3 puntos, confirmar con Find in Files si `Interactable` tiene algún
otro consumidor real en el proyecto — si el pueblo era su único uso,
migrar los 3 puntos lo deja completamente vestigial, y eso es una decisión
que vale la pena que Fernando confirme explícitamente antes de aplicarla,
no algo que se decida solo por conveniencia de reautoría.

---

## Alcance

### 1. Inicialización de partida (deuda 1)
Decidir y aplicar dónde vive ahora `join_party`, `_equip_starter_gear` y la
entrada inicial a `telmori_village_arrival`. Candidatos a valorar en
sesión: un paso explícito de `CharacterCreationViewModel` al terminar
creación de personaje (ligado a la aventura elegida, si el proyecto
contempla más de una en el futuro), o un campo de arranque en la propia
`InteractiveSceneDefinition` del pueblo (`on_first_visit`, análogo a
`required_flags` pero para efectos de una sola vez). Sea cual sea, debe
quedar data-driven, no en el script de una escena de exploración genérica.

### 2. Hotspots declarativos del pueblo
JSON real (`data/interactive_scenes/telmori_village.json`) con: los
hotspots permanentes del pueblo real (sheriff, tienda, herrero si existe
contenido para él, cualquier otro NPC/lugar del pueblo original) más los 3
migrados de `Interactable` a declarativo, con el flag de victoria nuevo
del punto 3 anterior aplicado al hotspot de rastro.

### 3. Flag de victoria de la emboscada
Confirmar dónde se marca hoy `combat_ended "victory"` para ese combate
concreto (probablemente en el mismo sitio que hoy dispara el spawn del
rastro) y añadir el flag nuevo específico en ese punto, sin tocar el
significado de `telmori_ambush_triggered` (sigue usándose donde ya se usa
hoy, si algo más depende de él).

### 4. Arte y componente de UI
Fondo del pueblo, iconos por hotspot, `UIButton`/componente real.

### 5. Localización real
Claves reales para cada hotspot del pueblo, sustituyendo las de prueba.

### 6. Validación del camino `Interactable` físico (según lo decidido)
Si se confirma que el pueblo era su único uso real y se migra igualmente,
documentar explícitamente que `Interactable` queda vestigial (candidato a
limpieza futura, no de este spike) y validar el motor nuevo por otra vía.
Si se decide conservar algún hotspot como `Interactable` físico (por
ejemplo, si hay razón de diseño para que alguno siga necesitando
proximidad), validarlo en partida real aquí.

### 7. Revertir el estado de prueba
`SceneOrchestrator.SCENE_EXPLORATION` pasa a apuntar a la escena real del
pueblo (mismo componente `exploration_interactive_map.tscn`, con
`interactive_scene_id` apuntando al pueblo en vez de `poi_test_map`) o a
una instancia dedicada, según cómo quedara montado en Spike 12.

### 8. Validación completa en partida real
Aventura completa de "Los Telmori" de principio a fin sobre el motor
nuevo: primera entrada, emboscada, guarida, botín, recompensa del sheriff
(ya migrada a diálogo en Spike 10), epílogo. Guardado y carga en al menos
dos puntos distintos del pueblo. Sin warnings nuevos.

---

## Fuera de alcance
- Cualquier mecánica de "buscar algo oculto en la imagen" — el naming
  genérico de Spike 12 la deja abierta, pero no se decide ni se construye
  aquí.
- Nuevas localizaciones más allá del pueblo (ciudad, otra aldea) — este
  spike valida el patrón con contenido real, no lo expande a más sitios.
- F9/quickload — sigue no operativo desde Spike 7, sin relación con este
  spike.
- Cualquier pendiente de la recopilación final.

## Cierre del spike
Al terminar, actualizar:
- Este documento con el resultado del punto de diseño (si `Interactable`
  queda vestigial o conserva algún uso real) y cualquier ajuste al plan.
- `mejoras-narrativas.md` / `pivote-narrativo.md`: el pueblo de "Los
  Telmori" queda migrado al motor de escenas interactivas.
- `athelia_estructura_proyecto_actualizado.md`: contenido real en
  `data/interactive_scenes/`.
- Documentación de pendientes: si `Interactable` queda vestigial, anotarlo
  para la recopilación final como candidato a limpieza futura (no acción
  inmediata).

---

## Resultado del spike

**Estado final:** Cerrado. El pueblo de "Los Telmori" se juega de principio a fin sobre el motor de escenas interactivas. La validación es parcial: ver la tabla de validación al final de esta sección.

### Resultado del punto de diseño (`Interactable`)

El pueblo no usa ningún `Interactable`. Un mapa estático (sin jugador, física ni proximidad) no puede tenerlos, así que la opción de "conservar uno como físico" no existía en la práctica. `Interactable` sí tenía otros consumidores (`exploration_tutorial` y `exploration_test`), pero Fernando decidió **descartarlos**: no eran escenas de producción. `Interactable` queda **vestigial**, sin consumidores en el camino jugable, y el camino físico refactorizado en Spike 12 (`request_interaction()`) **nunca se validó en partida real y ya no se va a validar**. Es candidato a limpieza en la recopilación final (no acción de este spike).

### Alcance original frente a lo hecho

| Punto de la spec | Resultado |
|---|---|
| 1. Inicialización de partida | Hecho. `AdventureStarter.apply()` (companions + kit, una sola vez al confirmar el personaje) y `on_first_visit` en la escena interactiva (la llegada). Elimina el kit duplicado. |
| 2. Hotspots declarativos | Hecho, con otro diseño: un hub de 11 hotspots en 4 posiciones, exclusivos por flags (sheriff, herrería, taberna, salida). Los tres `Interactable` del plan se disuelven: la recompensa es otra etapa del sheriff; rastro y aftermath ya no son hotspots, los encadena la escena de victoria del combate. |
| 3. Flag de victoria | Resuelto de otra forma: `combat_victory_scene_id` + `flag.telmori_ambush_won`, puesto por una escena que solo se alcanza al ganar. El defecto era doble (también `flag.telmori_lair_combat_won`, mal nombrado). |
| 4. Arte y componente de UI | Hecho: fondo, 4 medallones de icono y `UIButton` (con `min_square`/`icon_backdrop`). |
| 5. Localización | Hecho: +19 claves nuevas y 3 modificadas. |
| 6. `Interactable` físico | Descartado: queda vestigial y sin validar. |
| 7. Revertir el estado de prueba | Hecho: `exploration_interactive_map` carga `telmori_village`. |
| 8. Validación completa | Parcial (ver tabla). |

### Ajustes al plan original

La spec partía de otro modelo. Lo que cambió:

- **El mapa es un hub persistente**, no un contenedor para tres hotspots dinámicos. Tras la llegada se visita el sheriff, la herrería y la taberna; la salida está visible pero bloqueada hasta aceptar el encargo (y de nuevo hasta cobrar la recompensa), con un aviso al pulsarla.
- **Tras ganar un combate se encadena la siguiente escena narrativa** en vez de volver al pueblo. Huir sí devuelve al pueblo, donde la salida de la etapa permite reintentar.
- **El defecto del flag era doble**: `flag.telmori_ambush_triggered` y `flag.telmori_lair_combat_won` se ponían al disparar el combate, no al ganarlo. Ya no los pone ni lee nadie.
- **Armas:** la herrería las vende en una tienda propia (`blacksmith_telmori`): la lanza a 0 (es un préstamo, `quest_loan`) y 20 flechas de plata a 2 de oro. La lanza se devuelve al empezar la recompensa. Las dos escenas de entrega originales quedan sin uso.
- **Guardado:** el diálogo del sheriff (`triggers_save`) es el punto de guardado del hub. La etapa 4 no ofrece guardado a propósito, porque la cadena de recompensa entrega al pulsar y un guardado dentro permitiría cobrar dos veces.

### Etapas del pueblo

| Etapa | Flags activos | Sheriff | Salida |
|---|---|---|---|
| 1 Llegada | — | diálogo (con "aceptar") | aviso: falta aceptar el encargo |
| 2 Encargo aceptado | `flag.telmori_sheriff_briefed` | diálogo (sin "aceptar") | → colinas |
| 3a Emboscada ganada, rastreo fallido | + `flag.telmori_ambush_won` | diálogo | → rastreo |
| 3b Rastro logrado | + `flag.telmori_tracked_to_lair` | diálogo | → puerta de la guarida |
| 4 Guarida limpia | + `flag.telmori_lair_cleared` | recompensa (cadena narrativa) | aviso: falta cobrar |
| 5 Completada | + `flag.telmori_adventure_completed` | diálogo final | → salida final (marcador) |

### Cambios de contrato y de motor

1. `GameLoop.VALID_STATE_TRANSITIONS`: `VICTORY → [EXPLORATION, NARRATIVE_SCENE]`.
2. `GameLoop.start_combat(enemy_ids, encounter = null, victory_scene_id = "")` y `consume_pending_victory_scene()`. La escena pendiente vive en `GameLoop` (no en `CombatEncounterDefinition`, que puede ser `null`) y se descarta tras emitir `combat_ended`, para que no se fugue al combate siguiente.
3. `SceneOrchestrator._on_combat_ended`: abre la escena de victoria; si el id no existe, `push_error` y vuelve a `EXPLORATION` (con un id mal escrito se abría un panel vacío sin salida: softlock).
4. `NarrativeSceneOutcome.combat_victory_scene_id` y `take_item_id`/`take_item_quantity`/`take_item_target` (quitar un ítem: desequipa primero; si no lo tiene, no es un error).
5. `InteractiveSceneDefinition.on_first_visit` + `InteractiveSceneViewModel.request_first_visit()`: solo en `EXPLORATION`, marca el flag antes de actuar, llamada diferida desde la escena raíz.
6. `AdventureStarter` + `data/adventures/telmori.json`, llamado desde `CharacterCreationViewModel.request_confirm_character()`. `STARTING_ITEMS` queda vacío.
7. `UIButton.min_square` e `icon_backdrop` (opt-in, apagados por defecto); los hotspots pasan de `Button` a `UIButton`.
8. Dos mensajes preexistentes al huir, corregidos de paso: `EXPLORATION → EXPLORATION` (`end_combat("escaped")` ya transicionaba y `_on_combat_ended` repetía `enter_exploration()`) y `ROUND_START → PLAYER_ACTION_SELECT` (la huida se resuelve dentro de `player_turn_started` y `_start_player_turn()` seguía transicionando de fase).

### Ficheros

**Nuevos:** `data/interactive_scenes/telmori_village.json`; `data/interactive_scenes/images/mapa_aldea_telmori.jpg`; los 4 iconos (`icon_sheriff`, `icon_blacksmith`, `icon_tavern`, `icon_exit`); `data/adventures/telmori.json`; `core/adventures/adventure_starter.gd`; `data/shops/blacksmith_telmori.tres`; `data/dialogue/telmori/dlg_telmori_tavern_keeper.json` (esqueleto); escenas narrativas `telmori_exit_locked_briefing`, `telmori_exit_locked_reward` y `telmori_village_departure` (marcador); de prueba, `poi_test_combat_victory` y `poi_test_victory`.

**Editados (datos):** `telmori_sheriff_briefing` (diálogo: `O_LEAVE`, flags por opción), `telmori_village_arrival`, `telmori_day2_approach`, `telmori_post_ambush_tracking`, `telmori_lair_alerted`, `telmori_lair_stealth`, `telmori_sheriff_reward_intro`, `poi_test_map` (hotspot `test_victory_chain`) y los CSV de localización.

**Editados (código):** `game_loop_system.gd`, `scene_orchestrator.gd`, `narrative_scene_outcome.gd`, `narrative_scene_viewmodel.gd`, `interactive_scene_definition.gd`, `interactive_scene_viewmodel.gd`, `interactive_scene_view.gd`, `exploration_interactive_map.gd`/`.tscn`, `ui_button.gd` y `character_creation_viewmodel.gd`.

**Sin uso desde este spike:** el pueblo antiguo (`exploration_telmori_village.gd`/`.tscn`), `telmori_equipment_arrows`, `telmori_equipment_spear` y la escena envoltorio `telmori_sheriff_briefing`.

### Hallazgos

- **Colisión de nombres de fichero.** El diálogo y la escena narrativa del briefing se llamaban igual en carpetas distintas; al copiar el diálogo a `narrative_scenes` se pisó la escena y `NarrativeSceneDB` dio `scene_id vacío`. Los diálogos llevan prefijo `dlg_`.
- **Un `NarrativeScene` con id inexistente abre un panel vacío sin salida desde cualquier origen.** Solo se protegió la ruta de victoria; guarda general pendiente.
- **`EVT_TELMORI_SHERIFF_BRIEFED`** declara `trigger_type: DIALOGUE_END`, pero la búsqueda de código no encontró nada que consuma `dialogue_ended` para disparar eventos: se disparan desde `narrative_events` de la opción. Inferido de esa búsqueda; el caso contrario no se probó.
- **El kit estaba duplicado.** `STARTING_ITEMS` y `_equip_starter_gear()` daban dos espadas y dos armaduras al jugador, y la escena re-añadía el kit en cada `_ready()`, también al cargar partida (esto último no se verificó en el código antiguo; está eliminado de raíz).
- **Las "fichas de combate"** (`UICombatToken`) no son reutilizables como icono de mapa: están acopladas al combate. Los iconos de hotspot son PNG propios con `UIButton`.
- **Los `push_warning`/`push_error` solo salen en Depurador → Errores**, no en la salida de texto: los dos mensajes de la huida llevaban ahí desde antes y no aparecían en los logs pegados.

### Validación

| Comprobación | Estado |
|---|---|
| Aventura completa de principio a fin sobre el motor nuevo | Validado (Fernando) |
| Guardado al final de la aventura y salida del juego | Validado (Fernando) |
| La lanza prestada desaparece del inventario al empezar la recompensa | Validado (Fernando) |
| Huir de la emboscada devuelve al pueblo; ganar sigue el ciclo definido | Validado (Fernando) |
| Llegada → mapa, kit una sola vez, Mira en el grupo, bases de datos cargan | Validado (log) |
| Victoria con escena, huida, id de victoria inexistente (fallback) | Validado (log) |
| Segundo punto de guardado distinto, con carga sin duplicar kit ni repetir la llegada | **Sin confirmar** |
| Ganar un combate sin escena de victoria; derrota sin escena de victoria (solo con `poi_test_map`) | **Sin confirmar** |
| Lanza equipada frente a vendida | **Sin confirmar** |
| "Salir" del sheriff no marca `flag.telmori_sheriff_briefed` | **Sin confirmar** |
| Camino físico de `Interactable` | No validado y descartado |

### Pendientes que deja

Limpieza de `Interactable` y del pueblo antiguo, guarda general de ids narrativos inexistentes, `take_item_target` para varias entidades, marcadores de contenido (salida final, posadero), escena de rastros interactiva y validaciones sin confirmar. Detalle en `athelia_pendientes_post_pivote_narrativo.md`, punto 10.

### Documentos actualizados al cierre

- Este documento (resultado del punto de diseño y ajustes al plan).
- `athelia_estructura_proyecto_actualizado.md`: sección "Spike 13", árbol de carpetas, notas de `Interactable`/tutorial/pueblo antiguo, lecciones y pie.
- `athelia_ui_architecture.md`: `UIButton` modo solo icono, sección de `InteractiveSceneView` y pie.
- `athelia_pendientes_post_pivote_narrativo.md`: punto 9 hecho y nuevo punto 10.
- `pivote-narrativo.md` y `mejoras-narrativas.md`: el pueblo queda migrado al motor de escenas interactivas (texto en `spike_13_notas_pivote_y_mejoras.md`).


---

## Prompt de inicio de sesión

Para arrancar la sesión de este spike, pegar:

```
Vamos a empezar el Spike 13 (reautoría del pueblo de "Los Telmori" sobre
el motor de escenas interactivas) del proyecto Athelia. Especificación
adjunta: spike_13_reautoria_pueblo_telmori.md

El motor ya está validado con un mapa de prueba (Spike 12, cerrado). Este
spike aplica contenido real: el pueblo completo, con las deudas que
quedaron pendientes de aquel spike.

Antes de escribir el JSON del pueblo, hay una decisión de diseño a tomar
conmigo: si migramos los 3 Interactable dinámicos del pueblo (rastro,
aftermath, recompensa del sheriff) a hotspots declarativos, Interactable
deja de tener uso real en el pueblo. Antes de hacerlo, confirma con Find
in Files si Interactable tiene algún otro consumidor en el proyecto — si
el pueblo era su único uso, decírmelo explícitamente antes de aplicar la
migración, no asumir que da igual.

También hay un bug real a corregir de camino, no solo migrar tal cual:
flag.telmori_ambush_triggered se marca al DISPARAR el combate de la
emboscada, no al ganarlo. El hotspot de rastro necesita un flag nuevo
puesto específicamente al ganar ese combate — confírmalo con el código
antes de escribir el hotspot.

Y una pieza de inicialización de partida que hoy vive en
TelmoriVillage._ready() (join_party de Mira, equipo inicial del player y
companion, primera entrada narrativa) que no tiene dueño claro en la
escena de exploración genérica nueva — propónme dónde debería vivir
antes de implementarlo, no lo decidas sin comentarlo.

Antes de tocar nada necesito estos ficheros:

- exploration_telmori_village.gd / .tscn (contenido completo a migrar)
- interactive_scene_definition.gd, interactive_hotspot_definition.gd,
  interactive_scene_registry.gd (motor de Spike 12)
- interactive_scene_viewmodel.gd, interactive_scene_view.gd (o los nombres
  reales si difieren)
- exploration_interactive_map.gd / .tscn
- exploration_controller.gd (request_interaction(), el camino de
  Interactable delegando en él)
- poi_test_map.json (referencia del formato de datos ya validado)
- character_creation_viewmodel.gd (candidato para la inicialización de
  partida, punto 1)
- scene_orchestrator.gd (SCENE_EXPLORATION, a revertir del mapa de prueba
  al pueblo real)
```
