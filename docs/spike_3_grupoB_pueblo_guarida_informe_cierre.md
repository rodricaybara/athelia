# Spike 3 — Grupo B: Del pueblo a la puerta de la guarida — Informe de cierre

*Athelia — Pivote hacia RPG narrativo*

---

## Contexto y objetivo

Primer tramo de contenido real de "Los Telmori": desde que el sheriff encarga
la misión hasta que el grupo llega a la puerta de la guarida, incluyendo la
emboscada en el camino. Construido sobre el motor narrativo de Spike 1 y las
reglas de RuneQuest de Spike 2, sin ninguna pieza de contenido real todavía
en el proyecto antes de este grupo.

Cerrado de principio a fin, jugable en una partida completa sin errores.

---

## Diseño de los cinco puntos de alcance

### 1. Otorgar ítem

`NarrativeSceneOutcome` gana tres campos: `grant_item_id`, `grant_item_quantity`,
`grant_item_target` (entity_id destino, `"player"` por defecto pero
decidible en el JSON — pensado en su momento para poder dar un ítem a un
companion en vez de al jugador). Resuelto en
`NarrativeSceneViewModel._apply_outcome()` vía `Inventory.add_item()`.
Deliberadamente mínimo — un solo ítem por outcome, sin tabla de botín ni
condiciones. Entregar dos ítems (como las flechas de plata y la lanza)
significa dos outcomes encadenados, no una lista.

### 2. `CombatEncounterDefinition` opcional en `NarrativeSceneOutcome`

Campo `combat_encounter: CombatEncounterDefinition = null`, pasado directo
a `GameLoop.start_combat()` cuando el outcome dispara combate — sustituye
la necesidad de `configure_active_encounter()` para este caso. `null` =
comportamiento idéntico a antes de Spike 3 (sin moral/refuerzos/sorpresa).

### 3. Sorpresa en combate

Campo nuevo en `CombatEncounterDefinition`: `surprise_favors` (`""` /
`"party"` / `"enemies"`) y `surprise_vulnerable_pct` (0.0 = sin debuff
extra, >0.0 = además del staggered, el bando perjudicado recibe
`vulnerable` con ese porcentaje).

**Decisión de diseño clave:** no toca `turn_order` ni la máquina de
`TurnPhase`. La estructura de fases ya obliga a jugador+companions a
actuar antes que los enemigos cada ronda — reordenar iniciativa no habría
tenido ningún efecto real. En su lugar, reutiliza el buff `staggered` ya
existente en `CombatSystem` (el bando sorprendido pierde su primera
acción) y, opcionalmente, `vulnerable` (daño extra recibido). Lógica
compartida en `GameLoopSystem._apply_surprise()`, llamada tanto desde
`start_combat()` como desde `configure_active_encounter()` — esta segunda
llamada hizo falta porque el camino de pruebas con companion
(`ExplorationController` ya había arrancado combate antes de adjuntar el
encounter) no pasa por `start_combat()`.

**`turns_left` asimétrico, hallazgo no obvio:** el buff `"turn"` expira en
el propio turno de quien lo lleva, no en el de quien le ataca.
Jugador/companions actúan *antes* que los enemigos cada ronda → si son
ellos los sorprendidos, necesitan `turns_left = 2` para sobrevivir a su
propio tick y seguir aturdidos cuando les toque ser atacados. Los
enemigos actúan al final → su propio tick ya llega después de haber sido
atacados, `turns_left = 1` basta. Validado explícitamente en las dos
direcciones sobre `combat_test_scene`.

**Bug de motor encontrado y corregido durante la validación:** la rama
`STAGGERED` de `CombatSystem._on_execute_combat_action()` solo emitía
`combat_action_completed`, nunca `player_action_completed` cuando el
actor aturdido era el jugador — sin esa segunda señal, `_end_player_turn()`
nunca se dispara y el combate se queda colgado en
`PLAYER_ACTION_RESOLVE` para siempre. No lo disparó nadie antes porque
hasta este grupo nada del juego había aturdido nunca al jugador. Se
corrigió con el mismo patrón que ya usa el camino de éxito normal. La
rama `DISARMED`, con el mismo problema de raíz (solo emite
`combat_action_failed`, que `GameLoopSystem` no escucha en absoluto — se
colgaría con cualquier actor, no solo el jugador), se corrigió también
por prevención aunque nada de Grupo B la dispare todavía.

### 4. Mapping investigación → sorpresa

La transcripción original describe **dos tiradas separadas**, no una: día
1 (Rastrear, puramente informativo) y día 2 (Buscar, con -85% de
penalización, la que de verdad dispara la emboscada). La tabla de
sorpresa se aplica sobre la tirada de **Buscar del día 2**
(`group_aggregate="best"`, `roll_modifier=-85`), no sobre Rastrear del
día 1 — matiz encontrado al leer la transcripción real, corrigiendo un
mapping inicial mal planteado sobre la tirada equivocada.

| Grado de resultado en Buscar | `surprise_favors` |
|---|---|
| Fallo (`FAILURE`/`FUMBLE`, fallback) | `"enemies"` |
| Éxito normal (`SUCCESS`) | `""` |
| Especial/Crítico (`SPECIAL`/`CRITICAL`) | `"party"` |

Con `roll_modifier = -85` y los valores de skill reales que acabó teniendo
el jugador (Buscar 80, tras corregir el bug del punto "Skills y
progresión" más abajo), el resultado queda clampado a 0% casi siempre —
la emboscada resuelve `"enemies"` de forma consistente en la práctica.
Confirmado y aceptado como intencional, no como bug.

### 5. Estructura de escenas: pueblo/sheriff

Decisión: **varias escenas encadenadas**, no una sola — con una escena de
introducción antes del sheriff (petición explícita, no prevista en el
diseño original).

---

## Estructura final de las 11 escenas

**Sub-fase B1 — Gancho y pista falsa:**
`telmori_village_arrival` → `telmori_sheriff_briefing` →
`telmori_equipment_arrows` → `telmori_equipment_spear`

**Sub-fase B2 — Investigación, emboscada y rastreo:**
`telmori_hills_search_day1` → (`_nothing` / `_tracks` / `_mauled_sheep`,
tres escenas intermedias por grado) → `telmori_day2_approach` (dispara
combate directo, sin escena de "ambush" intermedia) → combate →
`telmori_post_ambush_tracking` (racha acumulativa, `required_successes=3`,
`retry_policy="blocked"`, `group_aggregate="best"`) →
`telmori_guarida_door` (cierre del grupo, flag `flag.telmori_reached_lair_door`
como gancho de entrada para Grupo C)

**Simplificaciones conscientes respecto a la fuente original**, aceptadas
como decisión, no como limitación a resolver:
- El rastreo acumulativo usa una sola tirada con `group_aggregate="best"`,
  no una tirada por personaje (el motor no soporta ese patrón).
- El crítico revelando el número de Telmori solo podría dispararse en la
  tirada que *completa* la racha (limitación del contrato de Spike 2,
  que solo mira el grado en la tirada de cierre) — no se modela.

---

## Combate de la emboscada — contenido y balance

6 enemigos: `telmori_warrior_1/2/3` (definición `telmori_warrior_base`) +
`telmori_wolf_1/2/3` (`telmori_wolf_base`) — 3 parejas, pensado para
jugador + 1 companion, reducido a la mitad del mínimo de la aventura
original (calibrada para grupo de mesa de 4-5).

Iteración de balance tras varias partidas de prueba:
- % de acierto de `skill.enemy.basic_attack` bajado — guerreros 80→55,
  lobos 75→50.
- Jugador y companion equipados desde el arranque de la escena
  (`iron_helmet`, `leather_armor`, `leather_boots`, `wooden_shield`,
  `iron_sword`) vía `Equipment.equip_item()` directo, sin pasar por
  `ItemCharacterBridge` (ese camino es para cuando el jugador usa un ítem
  desde la UI, no para setup por código).
- Companion (`companion_mira`) presente desde el principio de la partida
  — decisión de diseño: más simple que ofrecerla como opción narrativa.

---

## Reconexión narrativa tras combate — hallazgo de arquitectura

El combate disparado desde una escena narrativa cierra el panel y termina
en `EXPLORATION` al ganar — pero no existía ningún camino de producción
para volver a entrar en una escena narrativa desde el mundo 2D. La única
vía que había existido nunca (F1 de debug en Spike 1) ya la había quitado
Grupo A.

**Hueco más profundo de lo previsto:** no era solo "cómo se reconecta tras
el combate" — era "cómo se entra en *cualquier* escena narrativa desde
exploración, alguna vez". `Interactable.interaction_type` no tenía ninguna
opción que llamara a `GameLoop.enter_narrative_scene()` (solo `dialogue`/
`shop`/`combat`/`item`).

**Solución:** quinto valor de `interaction_type`, `"narrative_scene"`,
con su caso correspondiente en `ExplorationController._on_interaction_requested()`.
Reutilizable para cualquier entrada futura a una escena narrativa, no solo
para esta.

El rastro de continuación tras la emboscada se implementó calcando el
patrón ya existente de `_on_combat_loot_bag_spawned()` (spawn dinámico de
un `Node2D` con un `Interactable` al recibir `EventBus.combat_ended`,
sin pasar por `WorldObjectSystem` — no hace falta tirada de habilidad ni
loot table para esto).

`InteractionOutcome.narrative_event_id` (el campo que a primera vista
parecía servir para esto) resultó ser del sistema narrativo equivocado —
dispara `NarrativeSystem.apply_event()` (eventos/checkpoints), no
`GameLoop.enter_narrative_scene()` (el motor de escenas de Grupo B). Dos
sistemas narrativos distintos en el proyecto, fácil de confundir — el
mismo malentendido volvió a aparecer más tarde con `test_narrative_system.gd`,
que prueba el sistema de eventos, no el de escenas.

---

## Escena de exploración de producción

`scenes/exploration/telmori_village/exploration_telmori_village.gd` +
`.tscn` — nueva, no reutiliza `exploration_tutorial` (pensado
originalmente para un mundo 2D más amplio que ya no es el centro de la
jugabilidad tras el pivote narrativo; se retira en la próxima limpieza).

Contenido: Player + ExplorationController + ExplorationHUD, sin
`WorldObjectBridge`/panel (no hay ningún `WorldObject` real todavía en
esta escena). Dispara `telmori_village_arrival` automáticamente al
entrar, guardado por `flag.telmori_village_visited`. Añade a
`companion_mira` al grupo y equipa a jugador+companion, también al
entrar.

`SceneOrchestrator.SCENE_EXPLORATION` actualizado para apuntar aquí en
vez de a `exploration_tutorial.tscn` — único punto de entrada de
exploración real del juego.

---

## Otros bugs de motor encontrados y corregidos (no específicos de sorpresa)

- **`configure_active_encounter()` no aplicaba sorpresa** — solo
  `start_combat()` lo hacía. Resuelto extrayendo la lógica a
  `_apply_surprise()`, compartida entre ambos.
- **`NarrativeSceneViewModel` no registraba enemigos antes de
  `start_combat()`** — a diferencia de `ExplorationController`, que sí
  registra `enemy_id → definition_id` antes de arrancar combate. Sin
  esto, cualquier combate disparado desde una escena narrativa arrancaría
  con entidades sin definición ni HP. Resuelto con un campo nuevo
  (`NarrativeSceneOutcome.combat_enemy_definitions`, mismo formato que
  `Interactable.enemy_definitions`) y un método `_register_combat_enemies()`
  — réplica deliberada del de `ExplorationController`, no una llamada
  compartida, porque uno lee el mapeo de un `Interactable` que en el otro
  caso no existe.
- **`GameOverUI` reiniciaba mal** — saltaba directo a
  `exploration_test.tscn` sin pasar por Character Creation, dejando al
  jugador muerto de la partida anterior registrado con sus stats viejas.
  Corregido para pasar por el mismo camino que "Nueva Partida" del menú
  (`enter_main_menu()` → `enter_character_creation()` — `DEFEAT` no tiene
  transición válida directa a `CHARACTER_CREATION`, hace falta pasar por
  `MENU` primero).
- **Panel narrativo sin tamaño fijo** — `UIPanel` sin ancho ni anclaje se
  dimensionaba al contenido; con texto real (no las líneas cortas de test
  de Spike 1/2) el panel entero se desbordaba de la ventana. Corregido
  anclando `UIPanel` a 700×500 centrado y dándole a `SceneText` un
  `custom_minimum_size` real para que el autowrap tuviera contra qué
  envolver.
- **`"streak_progress"` sin consumidor en la View** — el ViewModel ya
  exponía `streak_current`/`streak_required` desde Spike 2, pero
  `narrative_scene_panel.gd` nunca añadió el caso al `match`. No se había
  disparado nunca porque el test de Spike 2 probaba el ViewModel con
  fixtures en código, sin View real de por medio. Cerrado con un
  `_render_streak_progress()` mínimo.

---

## Skills y progresión — el hallazgo más profundo del grupo

Al añadir `skill.exploration.track`/`search` al kit del jugador, aparecían
tiradas narrativas correctas (`vs 60%`) pero un aviso de `SkillSystem`
("Skill not found for entity") al terminar combate. La causa resultó ser
estructural, no un simple olvido:

**Dos sistemas paralelos de valores de skill, sin relación entre sí:**
- `CharacterState.skill_values` (vía `Characters.get_skill_value()`) —
  se inicializa correctamente desde `CharacterDefinition.starting_skill_values`
  en `CharacterState.new(definition)`. Es lo que leen tanto combate como
  las tiradas narrativas. **Este siempre funcionó bien.**
- `SkillSystem._entity_skills` (vía `Skills.get_skill_instance()`) — se
  registra por separado, una sola vez (`register_entity_skills()` tiene
  guard de registro único), y solo sirve para desbloqueo y conteo de
  progresión (`SkillProgressionService._process_improvement_rolls()` lo
  usa para decidir qué skills intentan mejorar tras combate).

`CharacterCreationViewModel` registraba este segundo sistema con una
constante hardcodeada (`STARTING_SKILL_VALUES`) **duplicada e
independiente** de `player_new.tres`, en vez de leer
`CharacterDefinition.skills`. Cuando se añadieron las dos skills nuevas al
`.tres`, esa copia paralela se quedó desincronizada — de ahí el aviso.
`party_manager.gd` tenía el mismo problema en la otra dirección: registraba
al companion sin pasar ninguna lista, lo que por el propio comportamiento
de `register_entity_skills()` con array vacío registra el catálogo
*entero* (19+ skills) en vez de su kit fijo — nunca dio error porque de
más no rompe nada, pero contradice el mismo principio de "kit fijo
explícito" que sí se aplicaba al jugador.

**Corregido en ambos sitios** para leer `CharacterDefinition.skills` en
vez de mantener listas paralelas — `player_new.tres`/`companion_mira.tres`
son ahora la única fuente de verdad para el kit inicial de cualquiera de
los dos.

---

## Contenido de datos creado

| Tipo | Fichero | Notas |
|---|---|---|
| Ítem | `data/items/telmori/silver_arrow.tres` | Consumible, sin modificadores (entrega sin consecuencia mecánica, según alcance) |
| Ítem | `data/items/weapons/weapon/enchanted_spear.tres` | Equipment, ranura `weapon`, sin modificadores por el mismo motivo |
| Skill | `data/skills/exploration/track.tres` | `skill.exploration.track` — Rastrear |
| Skill | `data/skills/exploration/search.tres` | `skill.exploration.search` — Buscar, deliberadamente distinta de Percepción (más analítica) |
| Personaje | `data/characters/telmori/telmori_warrior_base.tres` | Base compartida por los 3 `telmori_warrior_N` |
| Personaje | `data/characters/telmori/telmori_wolf_base.tres` | Base compartida por los 3 `telmori_wolf_N` |
| Escenas narrativas | `data/narrative_scenes/` (11 ficheros) | Ver estructura arriba |
| Localización | `localization/narrative_scenes_telmori.csv` | 22 claves, ES+EN |
| Localización | `localization/characters_telmori.csv` | 4 claves (nombre/descripción de los dos tipos de enemigo) |

**Convención nueva de este grupo:** carpeta por aventura para personajes e
ítems específicos de una aventura (`data/characters/telmori/`,
`data/items/telmori/`), en vez de todo plano en la raíz de su categoría
como hasta ahora — salvo ítems de tipo arma con ranura, que siguen
agrupándose por tipo de arma por encima de la aventura
(`data/items/weapons/<slot>/`). Skills se quedan sin carpeta de aventura,
al ser categorías generales. Mismo criterio aplicado a localización
(`_telmori.csv` en vez de añadir a los ficheros generales).

---

## Pendiente / fuera de este cierre

- **Loot table propia de Telmori** — de momento reutiliza `enemy_base_drops`
  vía `CharacterDefinition.loot_table_id`. No bloqueante.
- **Arte** — `image_path` vacío en las 11 escenas; sin pipeline de
  ilustración decidido todavía.
- **`challenge_level` de Rastrear/Buscar en Grupo B** — puesto a `0`
  (sin progresión narrativa) sin decisión explícita en su momento;
  confirmado después como intencional, no revisado más a fondo.
- **Limpieza de `exploration_tutorial`** — queda obsoleta tras el cambio
  de `SCENE_EXPLORATION`, pendiente de retirar del proyecto.
- **Grupo C** (la guarida — aproximación sigilosa, alertada/no alertada,
  combate final) — sin diseñar, se aborda en otra sesión.

---

## Hallazgos de GDScript / arquitectura reutilizables fuera de este grupo

- Un guard de registro-único (`if _entity_skills.has(id): return`)
  significa que cambios posteriores a un recurso de definición
  (`CharacterDefinition`) no se propagan a una entidad ya registrada sin
  reiniciar partida — y, peor, invita a mantener listas duplicadas "por
  si acaso" en el código que registra, que es justo la trampa en la que
  cayeron tanto `CharacterCreationViewModel` como `party_manager.gd`.
- Cuando un sistema expone dos accesores distintos para "lo mismo"
  (`Characters.get_skill_value()` vía `CharacterState` vs
  `Skills.get_skill_instance()` vía `SkillSystem`), verificar cuál lee
  cada consumidor antes de asumir que arreglar uno arregla el otro — el
  síntoma visible (tiradas con % correcto) puede ocultar que el sistema
  hermano sigue roto.
- Un buff que solo emite la señal de finalización "genérica"
  (`combat_action_completed`) sin la específica del jugador
  (`player_action_completed`) cuelga el turno en silencio, sin error —
  cualquier rama nueva de `_on_execute_combat_action()` que pueda cancelar
  la acción de cualquier actor necesita emitir las dos, condicionando la
  segunda a `actor == PLAYER_ID`.
- Un `Control` sin ancho/anclaje explícito dentro de un padre no-Container
  se dimensiona al contenido — con `autowrap_mode` activado pero sin
  límite de ancho real en ningún punto de la cadena de padres, el
  autowrap nunca tiene nada contra qué envolver.
