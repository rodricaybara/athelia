# Athelia — Historial de spikes
 
Relato cronológico de cada spike desde el pivote hacia RPG narrativo:
primero las arquitecturas archivadas (sistemas ya superados, conservados
por valor arqueológico), después el resumen por spike/grupo, y al final
el changelog completo en orden cronológico inverso (el más reciente
primero). Para el estado ACTUAL de los sistemas, ver
`athelia_referencia_sistemas.md` — este fichero es historia, no
referencia vigente.
 
---
 
## Arquitecturas archivadas (superadas por Spike 12/13)
 
### Exploration Tutorial — Arquitectura (OBSOLETA desde Spike 3, Grupo B)
 
> **Spike 13: DESCARTADA** por Fernando (no era escena de producción). Pendiente de borrar junto a `exploration_test` (ver pendientes, punto 10).
 
```
ExplorationTutorial (Node2D)              ← script: exploration_tutorial.gd
├── ExplorationController (Node)          ← compartido, sin cambios respecto a exploration_test
├── ExplorationHUD (CanvasLayer)          ← compartido
├── World (Node2D)
│   └── TileMapLayer
├── Player (CharacterBody2D, grupo "player")
│   ├── CollisionShape2D
│   ├── InteractRange (Area2D)
│   ├── Personaje (Sprite2D)
│   └── Camera2D                          ← hija del Player (sigue su movimiento automáticamente)
└── WorldObjects (Node2D)
    ├── Chest_A / Chest_B
    │   ├── Interactable (Area2D)         ← detección/prompt — NUNCA bloquea movimiento
    │   ├── CollisionBody (StaticBody2D)  ← bloqueo físico real, radio menor que el de detección
    │   └── Sprite2D
```
 
Pensada originalmente para enseñar mecánicas de un mundo 2D más amplio que dejó de ser el centro de la jugabilidad tras el pivote narrativo. `SCENE_EXPLORATION` ya no apunta aquí (ver `Telmori Village` abajo) — pendiente de retirar del proyecto.
 
**A diferencia de `exploration_test.gd`, esta escena NO registra al jugador** — asume que `CharacterCreationViewModel._create_player_entity()` ya lo dejó registrado en `Characters`/`Resources`/`Skills`/`Equipment`/`Inventory` antes de que `GameLoop.enter_exploration()` la cargue. Sí registra los `WorldObjects` propios de la zona (`WorldObjectSystem.register_instance()`, `WorldObjectBridge`, `WorldObjectInteractionPanel`).
 
**Convención de colisión para objetos de mundo sólidos:** todo objeto interactuable necesita **dos** cuerpos separados — `Interactable` (`Area2D`, detección de proximidad/prompt) y un `StaticBody2D` adicional (bloqueo físico). Un `Area2D` nunca bloquea movimiento por diseño de Godot; ambos roles no deben mezclarse en el mismo nodo.
 
Ver `docs/spike_produccion_post_character_creation_informe_cierre.md` para el detalle completo (bugs corregidos, hallazgos aparcados).
 
### Telmori Village — Arquitectura (Spike 3, Grupo B — escena de producción real; ampliada en Grupo C)
 
> **Spike 12:** esta escena ya no es `SCENE_EXPLORATION` (comentada, revertible). Su `_ready()` hace inicialización de PARTIDA (companion, equipo inicial, primera entrada narrativa) y sus 5 listeners de reconexión (`combat_ended`/`narrative_flag_set`) son la lógica que Spike 13 debe migrar a datos (hotspots con `required_flags`/`blocked_flags`) antes de retirarla.
 
> **Spike 13: OBSOLETA.** El pueblo vive ahora en `data/interactive_scenes/telmori_village.json` (hub declarativo). La inicialización de partida pasó a `AdventureStarter` + `on_first_visit`; los 3 `Interactable` y los 5 listeners de reconexión desaparecen con esta escena. Candidata a retirada.
 
```
TelmoriVillage (Node2D)                   ← script: exploration_telmori_village.gd
├── ExplorationController (Node)          ← compartido
├── ExplorationHUD (CanvasLayer)          ← compartido
├── World (Node2D)                        ← vacío, sin arte todavía
├── Player (CharacterBody2D, grupo "player")
│   ├── CollisionShape2D
│   ├── InteractRange (Area2D)
│   ├── Personaje (Sprite2D)
│   └── Camera2D
└── WorldObjects (Node2D)
    └── TrailSpawnPoint (Marker2D)        ← posición base de los interactuables de reconexión (rastro de Grupo B + aftermath de Grupo C, offset +120px en X entre ellos)
```
 
Igual que `ExplorationTutorial`, no registra al jugador (ya lo hace Character Creation). Sin `WorldObjectBridge`/panel — no hay ningún `WorldObject` real todavía en esta escena.
 
Dos cosas propias, al entrar (`_ready()`):
1. Dispara `telmori_village_arrival` automáticamente, guardado por `flag.telmori_village_visited` (para no repetirse en visitas posteriores).
2. Añade a `companion_mira` al grupo (`Party.join_party()`) y equipa a jugador+companion (`Equipment.equip_item()` directo, sin pasar por `ItemCharacterBridge` — ese camino es para cuando el jugador usa un ítem desde la UI, no para setup por código).
Escucha `EventBus.combat_ended` dos veces (emboscada de Grupo B, combate final de la guarida de Grupo C) para la reconexión narrativa tras combate, y `EventBus.narrative_flag_set` dos veces para la limpieza de cada interactuable de reconexión una vez su arco queda resuelto (ver ambas secciones más abajo).
 
### Reconexión narrativa tras combate (Spike 3, Grupo B; generalizada en Grupo C)
 
Un combate disparado desde una escena narrativa (`NarrativeSceneOutcome.combat_encounter`) cierra el panel y, al terminar, vuelve a `EXPLORATION` como cualquier otro combate — pero no hay ningún camino directo de vuelta a la escena narrativa. Resuelto sin extender `VALID_STATE_TRANSITIONS` ni tocar el contrato de victoria: al ganar, se spawnea dinámicamente un `Node2D` con un `Interactable` (`interaction_type = "narrative_scene"`) en la escena de exploración — mismo patrón que ya usa `_on_combat_loot_bag_spawned()` para la bolsa de loot, sin pasar por `WorldObjectSystem` (no hace falta tirada de habilidad ni loot table para esto). Grupo C reutilizó el patrón tal cual para el combate final de la guarida (`flag.telmori_lair_combat_won` → spawn de `telmori_lair_aftermath`) — es ahora el único mecanismo validado del proyecto para esto, y cualquier combate futuro disparado desde narrativa (Grupo D incluido) debería seguir el mismo camino en vez de inventar uno nuevo.
 
`InteractionOutcome.narrative_event_id` no sirve para esto — dispara `NarrativeSystem.apply_event()` (el sistema de eventos/checkpoints), no `GameLoop.enter_narrative_scene()` (el motor de escenas narrativas). Dos sistemas narrativos distintos en el proyecto, fácil de confundir.
 
**Lección de Grupo C — el listener de `combat_ended` debe desconectarse al completar su arco, no vivir para siempre.** El primer bug real que salió al jugar la cadena completa de Grupo C: el listener de la emboscada de Grupo B (`_on_combat_ended_telmori_ambush`) nunca se desconectaba, y su guardia contra duplicados solo comprobaba "¿existe ya el nodo?" — una vez que el nodo se retira (al completar el arco), *cualquier* combate posterior que termine en victoria, sin relación alguna con la emboscada, reactiva el listener y **resucita** el interactuable obsoleto apuntando a una escena ya completada. El flag que lo guardaba (`flag.telmori_ambush_triggered`) nunca se desactiva, así que por sí solo no protege nada una vez el nodo desaparece. Arreglado desconectando cada listener de reconexión (`EventBus.combat_ended.disconnect(...)`) en el mismo punto donde se retira su interactuable — aplicado preventivamente también al listener nuevo de Grupo C, para que Grupo D no herede el mismo patrón de bug con su propio contenido de combate.
 
**Lección de Grupo C — limpiar un interactuable de reconexión debe engancharse a `EventBus.narrative_flag_set`, no a `EventBus.narrative_scene_closed`.** Un intento inicial de retirar el rastro obsoleto escuchaba `narrative_scene_closed`, pero cuando una escena resuelve su rama de éxito **encadenando internamente** a otra vía `next_scene_id` (sin pasar por `EXPLORATION` de por medio), el `ViewModel` no cierra el panel — solo cambia de contenido — así que esa señal nunca llega a emitirse con el `scene_id` de la escena origen en ese camino (solo en una rama que sí cierra de verdad, p. ej. un fallo con `next_scene_id` vacío). El flag que la propia rama de éxito pone (`flag.set_to` del outcome) sí es fiable independientemente de cómo encadene el panel por dentro — es la señal correcta para detectar "este arco narrativo se completó", no el cierre del panel.
 
### Reconexión narrativa sin combate (Spike 3, Grupo D)
 
Variante del patrón anterior para cuando el disparador **no** es un combate: la cadena de cierre (`telmori_lair_victory` → `telmori_lair_loot_obsidian`) termina marcando `flag.telmori_lair_cleared` sin pasar por `COMBAT_ACTIVE`, así que `exploration_telmori_village.gd` escucha directamente `EventBus.narrative_flag_set` para spawnear el interactuable de recompensa del sheriff — sin necesitar ningún listener de `EventBus.combat_ended` de por medio. A diferencia de los listeners de `combat_ended` (genéricos, se reactivan con cualquier combate no relacionado — la lección de Grupo C), un listener de `narrative_flag_set` filtrado por `flag_name` no necesita desconectarse a sí mismo: solo reacciona al flag exacto que le importa, y ese flag se marca una única vez en toda la partida.
 
**Riesgo nuevo, distinto al de Grupo C — exploit económico, no contenido resucitado.** Si el interactuable de recompensa se queda disponible para siempre, el jugador puede reentrar en la cadena del sheriff indefinidamente y acumular oro/ítems sin límite. Cubierto con el mismo mecanismo (un segundo listener de `narrative_flag_set`, esta vez para `flag.telmori_adventure_completed`, que retira el interactuable al completar el arco) — pero identificado por diseño antes de escribir el código, no descubierto en playtest como los cuatro bugs de Grupo C.
 
 
---
 
## Spikes y grupos de mejora, por orden
 
### Spike 2 — Reglas de RuneQuest para el Motor Narrativo (seis de seis puntos cerrados)
 
Las seis piezas que Spike 1 dejó diferidas quedan implementadas y validadas.
Ninguna toca contenido real de "Los Telmori" (eso llegó en Spike 3, Grupos A y B).
 
1. **Grado "especial"** — `SkillRoller.RollResult` pasa a 5 grados. `CRITICAL` y `SPECIAL` son dinámicos (`skill/20`, `skill/5`, fórmulas RuneQuest clásicas), `FUMBLE` se queda absoluto. En combate, `SPECIAL` aplica un multiplicador de daño propio (x1.2, vs x2 de crítico) vía `special_multiplier` en el effect. Cuenta como `"success"` en progresión, sin tick diferenciado.
2. **Progresión de skill narrativa** — `NarrativeSceneOption.challenge_level: int` (0 = sin progresión, opt-in explícito) engancha a `SkillProgression.execute_learning_session()` con `SourceType.NARRATIVE`, gateado en éxito, nunca vía `notify_skill_outcome()` (hard-gated a combate).
3. **Tiradas acumulativas** — `NarrativeSceneOption.required_successes`/`retry_policy` (`"immediate"`/`"blocked"`). El contador de racha vive en `NarrativeSceneViewModel`, nunca en `NarrativeSceneDB` ni en la propia `NarrativeSceneOption`. Una pifia siempre transiciona, ignorando `retry_policy`. La progresión solo se intenta al completar la racha entera, nunca en un éxito parcial. `changed("streak_progress")` expone `streak_current`/`streak_required`/`streak_option_id` — **la View no lo consumía hasta Spike 3, Grupo B** (ver antipatrón correspondiente en `athelia_ui_architecture.md`).
4. **Tiradas agregadas de grupo** — `NarrativeSceneOption.group_aggregate` (`""`/`"worst"`/`"best"`). Sin tabla de resistencia real (decisión de coste-beneficio): la oposición se codifica en `roll_modifier`, no en un valor de NPC calculado por el motor. Sin cambios en `PartyManager` — la agregación vive en el ViewModel. Si hay progresión, cada miembro del grupo intenta su propia mejora de forma independiente.
5. **Modificadores dinámicos** — cerrado sin código: `roll_modifier` (Spike 1) ya cubre el caso narrativo. El caso de combate (multiplicativo, ej. "mitad de puntería en oscuridad") se aplaza a Spike 3.
6. **Moral y refuerzos cronometrados** — fichero nuevo `core/combat/combat_encounter_definition.gd` (Resource), parámetro opcional en `GameLoopSystem.start_combat(enemy_ids, encounter = null)`. Moral de **grupo** (no individual): los enemigos supervivientes huyen juntos cuando el HP total del grupo cae bajo `morale_threshold_pct`, vía una señal nueva (`enemy_group_fled`) que nunca pasa por `character_died` (sin loot, sin animación de muerte). Refuerzos genéricos vía `reinforcement_trigger`/`reinforcement_delay_rounds`, disparables por cualquier sistema con `GameLoop.trigger_combat_event()`. `GameLoopSystem.configure_active_encounter()` permite adjuntar un encuentro a un combate ya en marcha (necesario porque `ExplorationController` arranca combate sin pasar ningún encuentro — y, desde Spike 3/B, también necesario para que la sorpresa se aplique en ese camino).
**Hallazgos de GDScript reutilizables fuera de este spike:** un `match` sin rama `_:` no avisa si le falta un caso al crecer un enum (encontrado en `SkillRoller._is_success()`, que habría tratado un `SPECIAL` como fallo en combate); un array indexado directamente por el valor entero de un enum (`LearningSession._to_string()`) se sale de rango en silencio si el enum crece sin ampliar el array. Ambos son el mismo tipo de riesgo en dos formas distintas: cualquier extensión de un enum obliga a repasar *todos* sus consumidores, no solo los que parecen relevantes a simple vista.
 
Ver `docs/spike_2_reglas_runequest_informe_cierre.md` para el detalle completo, decisión por decisión, y la validación realizada en cada punto.
 
### Spike 3, Grupo A — Motor y limpieza (los tres puntos de alcance cerrados)
 
Grupo deliberadamente aislado del contenido de "Los Telmori" (Grupos B/C/D) — solo motor y retirada de andamiaje de Spike 1. Sin cambios al contrato MVVM ni a ningún patrón de arquitectura UI.
 
1. **Moral con base dinámica** — la limitación explícita que dejó Spike 2 (base de moral fija, capturada solo al iniciar combate) queda resuelta. `GameLoopSystem._group_initial_max_hp` se renombra a `_group_morale_base_hp` (deja de ser "inicial") y se añade `_group_morale_base_dirty: bool`. Al llegar un refuerzo (`_spawn_reinforcements()`), la base no se recalcula ahí mismo — el refuerzo puede no estar registrado todavía en `ResourceSystem` (su registro lo hace la escena en respuesta a `reinforcement_spawned`, fuera de control de `GameLoopSystem`) — sino que se marca `_group_morale_base_dirty = true`. La recalculación real ocurre en la siguiente llamada a `_check_group_morale()` (que solo se dispara cuando muere alguien, vía `_check_combat_conditions()` — nunca golpe a golpe), y reutiliza el mismo `current_total_hp` que ya calcula el propio chequeo de umbral: como un refuerzo recién llegado tiene HP actual = HP máximo, ese total ya *es* "HP de supervivientes + HP máximo del refuerzo" sin necesidad de resolverlo por separado. `_check_combat_conditions()` no cambia su frecuencia de evaluación. Validado exactamente contra los dos ejemplos numéricos de la spec del grupo (500→400→refuerzo 100→base 500→umbral 200; 350→refuerzo 100→base 450→umbral 180) — ver `test/test_group_morale.gd`.
2. **Hueco genérico de limpieza en mundo** — nuevo autoload `EnemyWorldLink` (`core/combat/enemy_world_link.gd`). Escucha `EventBus.enemy_group_fled` (que ya llevaba los `entity_ids` desde Spike 2, sin cambio de firma) y, por cada uno, invoca un `Callable` de limpieza si alguien lo registró vía `register_fled_cleanup(entity_id, cleanup)` — no-op si nadie lo hizo. No conoce `WorldObjectSystem` ni ningún tipo de representación concreta: quien registra decide qué significa "limpiar". Sin ningún caso de uso real todavía en el propio grupo — lo ejerció la emboscada de Grupo B.
3. **Limpieza de Spike 1** — eliminados sin más: tecla F1 y `_debug_test_narrative_scene()` de `exploration_controller.gd`, los 5 JSON de `data/narrative_scenes/test_scene_*.json` (intro/success/failure de Spike 1, streak/group_check de Spike 2), y las claves `TEST_NARRATIVE_*` de `narrative_scenes.csv` (queda solo la cabecera). El hueco de test pendiente para `NarrativeSceneViewModel` se resuelve con `test/test_narrative_scene_viewmodel.gd`: fixtures de `NarrativeSceneDefinition`/`Option`/`Outcome` construidos en código con `new()`, sin JSON ni `NarrativeSceneDB`.
**Hallazgo de GDScript nuevo (Spike 3, Grupo A):** un enum anidado en otra clase vía `class_name` (p. ej. `GameLoopSystem.GameState`) no se puede usar de forma fiable como anotación de tipo explícita en una variable (`var x: GameLoopSystem.GameState`) en esta versión de GDScript — falla con "Could not find type... in the current scope" incluso cuando la misma ruta funciona perfectamente como valor (`as GameLoopSystem.GameState` sin tipar, o dentro de un `match`). Además, si el propio script `class_name` tiene un error de compilación en cualquier punto — o su contenido se sobrescribe por error con el de otro fichero —, su nombre de clase global deja de resolverse en *todo* el proyecto, y el síntoma es "Identifier not declared" en decenas de ficheros no relacionados con la causa real. Solución práctica: no anotar el tipo del enum anidado, trabajar con `int` a secas.
 
Ver `docs/spike_3_grupoA_motor_limpieza_informe_cierre.md` para el detalle completo.
 
### Spike 3, Grupo B — Del pueblo a la puerta de la guarida
 
Primer contenido real del pivote narrativo: 11 escenas de "Los Telmori", desde el gancho del sheriff hasta la puerta de la guarida, jugable de principio a fin. Ver `docs/spike_3_grupoB_pueblo_guarida_informe_cierre.md` para el detalle completo (diseño de los cinco puntos de alcance, hallazgos de motor corregidos, contenido de datos creado). Resumen de lo más relevante a nivel de motor:
 
- `NarrativeSceneOutcome` extendido con `combat_encounter`, `combat_enemy_definitions` y `grant_item_id/quantity/target`.
- `CombatEncounterDefinition.surprise_favors`/`surprise_vulnerable_pct` — sorpresa de combate implementada vía el buff `staggered`/`vulnerable` ya existente, sin tocar `turn_order` ni `TurnPhase` (la estructura de fases ya obliga a jugador+companions a actuar antes que los enemigos, reordenar iniciativa no tendría efecto).
- Nuevo `interaction_type` `"narrative_scene"` en `Interactable` — antes no existía ningún camino de producción para entrar en una escena narrativa desde exploración (solo una tecla de debug de Spike 1, ya retirada en Grupo A).
- Corregidos dos bugs de cuelgue de turno (`STAGGERED`/`DISARMED` en `CombatSystem._on_execute_combat_action()` no emitían `player_action_completed`), uno de registro de enemigos en combate disparado desde narrativa, uno de reinicio tras Game Over, uno de dimensionado del panel narrativo, y uno de doble sistema de valores de skill desincronizado entre `CharacterState` y `SkillSystem` (`STARTING_SKILL_VALUES` hardcodeado en `CharacterCreationViewModel`, ahora lee de la propia `CharacterDefinition`).
- `SCENE_EXPLORATION` apunta a la nueva `exploration_telmori_village.tscn`, primera zona de producción real.
- Convención nueva: carpeta por aventura para personajes/ítems específicos (`data/characters/telmori/`, `data/items/telmori/`) y para localización (`_telmori.csv`), salvo ítems de arma con ranura, que siguen agrupándose por tipo de arma.
### Spike 3, Grupo C — La guarida
 
Segundo tramo de contenido real del pivote narrativo: la aproximación sigilosa a la guarida y su combate final, jugable de principio a fin desde `telmori_guarida_door` (cierre de Grupo B) hasta `flag.telmori_lair_cleared` (gancho de entrada para Grupo D). Ver `docs/spike_3_grupoC_guarida_informe_cierre.md` para el detalle completo. Resumen de lo más relevante a nivel de motor:
 
- **Fusión de las dos salas de la aventura original en un combate por rama**, en vez de dejar al jugador elegir entre dos salas separadas: `telmori_lair_alerted` junta ambas fuerzas desde el inicio (sin sorpresa, sin refuerzo — la transcripción ya las describe convergiendo juntas al sonar la alarma); `telmori_lair_stealth` usa los supervivientes de la emboscada como roster inicial (`surprise_favors: "party"`) y la Habitación Elevada como refuerzo a la ronda 4 (`reinforcement_delay_rounds: 4`, `reinforcement_trigger: ""` — el contador arranca con el propio combate, no espera un evento externo).
- **Tirada opuesta de grupo con `group_aggregate: "worst"` confirmado por la fuente**, no por preferencia de diseño: la transcripción original reduce la Escucha de los lobos según el Deslizarse en Silencio del aventurero *más torpe* del grupo — el eslabón más débil decide, al contrario que el `"best"` usado para el rastreo de Grupo B.
- **Nueva skill `skill.exploration.stealth`** ("Deslizarse en Silencio"), calcada de `track.tres`.
- **Modificador multiplicativo de combate, decidido explícitamente NO implementarlo** — las dos salas tácticas de la aventura original (techo bajo, ventaja de tirar rocas desde una elevación) se resuelven sin tocar `CombatSystem`: el combate del proyecto es de acciones fijas por tecla, no hay "opciones de escena" contra las que restringir un arma concreta dentro de un combate en marcha. Sigue diferido desde Spike 2, ahora sin ningún caso de uso real pendiente.
- **`EnemyWorldLink` confirmado innecesario** — igual que la emboscada de Grupo B, el combate final se dispara directo desde narrativa, sin capa de exploración 2D dentro de la guarida de la que limpiar una representación de un Telmori huido. Termina la aventura piloto completa sin ningún caso de uso real, resultado aceptado como válido, no señal de sobre-ingeniería.
- Cuatro bugs de motor preexistentes encontrados y corregidos al jugar la cadena completa por primera vez: un encadenado suelto en `telmori_guarida_door` (escrito antes de que existiera Grupo C, sin `next_scene_id` hacia la guarida); ausencia total de reconexión narrativa tras el combate final (nadie había replicado el patrón de Grupo B para el segundo combate del proyecto); un listener de reconexión que nunca se desconectaba y resucitaba un interactuable ya retirado ante cualquier combate posterior; y una limpieza enganchada a la señal equivocada (`narrative_scene_closed` en vez de `narrative_flag_set`) que nunca se disparaba en el camino de encadenado interno de una escena a otra. Detalle completo de los cuatro en la sección "Reconexión narrativa tras combate" más arriba y en el informe de cierre.
### Spike 3, Grupo D — Cierre
 
Último grupo del Spike 3: recompensa multicapa, entrega del botín mágico de la guarida y gancho de continuidad final, jugable de principio a fin desde `flag.telmori_lair_cleared` hasta `flag.telmori_adventure_completed`. **Con este grupo, "Los Telmori" queda completa.** Ver `docs/spike_3_grupoD_cierre_informe_cierre.md` para el detalle completo. Resumen de lo más relevante a nivel de motor:
 
- `NarrativeSceneOutcome` extendido con `grant_resource_id/amount/target` ("otorgar recurso", análogo a `grant_item_*` vía `Resources.add_resource()`) — ver detalle y el bug de declaración encontrado en la sección "Narrative Scene — Arquitectura" más arriba.
- Nuevo patrón de reconexión narrativa **sin combate de por medio** (`EventBus.narrative_flag_set` directo, sin `combat_ended`) — ver "Reconexión narrativa sin combate" más arriba, con su propio riesgo identificado (exploit económico por interactuable de recompensa sin limpiar) y su propia solución (segundo listener de flag para la limpieza).
- **Camino de Curtidor resuelto sin gating de visibilidad de opción nuevo** — `Characters.get_skill_value()` devuelve 0 para una skill fuera del kit inicial, así que una tirada normal contra `skill.exploration.tanning` ya da la probabilidad casi nula buscada sin construir nada. Confirmado en playtest: `SkillRoller` registró `vs 0% → FAILURE` para el jugador sin el tomo leído.
- **Mini-acertijo de la bolsa mágica, decidido explícitamente NO implementarlo** — mismo criterio que el modificador multiplicativo de combate descartado en Grupo C: sin un segundo caso de uso de "interacción objeto sobre objeto" en el proyecto, se resuelve como flavor narrativo puro. El mecanismo de "otorgar ítem" existente entrega la bolsa sin más.
- **Reflavor del entrenamiento de magia** — el tomo (`book_tanning_basics.tres`) enseña Curtidor directamente vía `learning_data`, reutilizando el mecanismo de libro de aprendizaje ya existente desde `book_combat_basic.tres`, sin sistema de magia nuevo (sigue aparcado). Orden de las escenas del sheriff decidido para que el tomo se entregue **antes** de la venta de pieles, así el jugador puede usar la skill recién aprendida en la misma sesión de recompensa. **Corrección (Spike 10):** en la práctica este camino no funcionaba — el jugador no tenía la skill registrada, así que la lectura del tomo fallaba y consumía el libro sin enseñar nada (ver "Spike 10" más abajo); además `grant_item_*` no se ejecutaba en el ViewModel, por lo que el tomo ni llegaba al inventario.
- `ItemDefinition.item_type` confirmado como enum cerrado (`CONSUMABLE`/`EQUIPMENT`/`MISC`, sin tipo "genérico decorativo") — los tres ítems de botín/trofeo sin mecánica (`telmori_magic_bag`, `obsidian_spearhead`, `wolf_tail_trophy`) usan `MISC`.
- `SkillSystem`/`ItemRegistry` confirmados como escaneo recursivo real de `data/skills/`/`data/items/` (sin lista hardcodeada, a diferencia de `ResourceSystem._load_resource_definitions()`, que sí tiene una lista fija pero no se ve afectada porque `gold` ya estaba en ella) — la skill y los ítems nuevos de este grupo se cargaron sin tocar ningún registro de motor.
- Un bug real de contenido (no de motor): `telmori_lair_victory.json` se quedó con el contenido original en el proyecto tras diseñar la cadena de botín en conversación — el flag se marcaba igual, así que el fallo (botín nunca entregado) no producía ningún error visible. Detectado revisando qué `scene_id` traía `narrative_scene_closed` en el log: si una cadena multi-escena se corta antes de tiempo, el `scene_id` de cierre delata en qué nodo se quedó de verdad.
### Mejoras post-Spike 3, Grupo 3 — Overlays de inventario/party/stats durante narrativa
 
Primer grupo del ciclo de mejoras posterior al cierre de Spike 3. Objetivo: poder abrir Inventory/Party/PlayerMenu desde dentro de `NARRATIVE_SCENE` sin salir de la escena narrativa ni perder su progreso (nodo actual, racha de tiradas acumulativas en curso). Ver `docs/mejoras_grupo3_overlays_narrativa_informe_cierre.md` para el detalle completo. Resumen de lo más relevante a nivel de motor:
 
- **Las dos comprobaciones de código obligadas por el spec, resueltas antes de diseñar nada:** `open_inventory()`/`open_party()`/`open_player_menu()` en `SceneOrchestrator` comparten exactamente el mismo guard manual (`current_game_state != EXPLORATION`), ninguno usa `VALID_STATE_TRANSITIONS` — no hay bifurcación real entre los tres, así que el alcance no se reduce a solo Inventory. Y `ExplorationController._unhandled_input()` bloquea todo su input con `GameLoop.is_input_blocked()` fuera de `EXPLORATION` — las teclas de inventory/party/player_menu no "funcionaban ya sin querer" en narrativa, estaban activamente bloqueadas.
- **Hallazgo crítico no anticipado por el spec:** `SceneOrchestrator._current_overlay` es un slot único, no una pila. Abrir Inventory desde narrativa por el camino normal (`SceneOrchestrator.open_inventory()`) habría interpretado el panel narrativo ya abierto como "hay un overlay, toggle" y lo habría `queue_free()`eado, destruyendo `NarrativeSceneViewModel` y con él la racha en curso.
- **Diseño adoptado:** `NarrativeScenePanel` gestiona Inventory/Party/PlayerMenu como sub-overlay propio (`_open_sub_overlay()`/`_close_sub_overlay()`), instanciándolos como hijos directos — nunca a través de `SceneOrchestrator`. Mismo patrón que ya usaba `PlayerMenuScreen._open_subscreen()` para sus propias subpantallas (Loadout/Inventory/SkillTree), extendido aquí a un segundo nivel de anidamiento. `SceneOrchestrator._current_overlay` sigue apuntando al panel narrativo durante todo el proceso — nunca se toca.
- `NarrativeSceneViewModel` gana tres intenciones (`request_open_inventory/party/player_menu`), guardadas igual que `request_option()` (solo con `PanelState.SHOWING`). No tocan `current_node` ni `_success_streaks` — el sub-overlay es responsabilidad íntegra de la View.
- `SceneOrchestrator.open_inventory()`/`open_party()`/`open_player_menu()` ganan `LIGHT_OVERLAY_ALLOWED_STATES` (`EXPLORATION` + `NARRATIVE_SCENE`) y un guard explícito que bloquea la ruta de `_current_overlay` en `NARRATIVE_SCENE` — red de seguridad defensiva: en la práctica ninguno de los tres se invoca desde narrativa (lo resuelve `NarrativeScenePanel` internamente), pero si algo lo hiciera por error, se bloquea con aviso en vez de destruir el panel narrativo.
- **Bug de motor preexistente, confirmado en playtest real, no introducido por este grupo:** `InventoryUI`, `PlayerMenuScreen`, `LoadoutScreen` y `SkillTreeScreen` no se auto-liberan (`queue_free()`) en ningún camino de cierre — solo ponen `visible = false`. `PlayerMenuScreen._open_subscreen()` dependía de `tree_exiting` para saber cuándo destruir una subpantalla cerrada, señal que por tanto nunca se disparaba. Reproducido en juego: abrir Inventory/Loadout/SkillTree desde dentro de PlayerMenu (siendo PlayerMenu a su vez sub-overlay de `NarrativeScenePanel`) y cerrarlos dejaba las tres capas (subpantalla, PlayerMenu, panel narrativo) colgadas invisibles, sin ninguna forma de volver atrás — indistinguible de un crash desde fuera, aunque sin ninguna excepción real del motor. Corregido añadiendo `signal closed` a las cuatro pantallas (`PartyUI` ya la tenía), emitida junto a su `visible = false`, y hacer que tanto `NarrativeScenePanel._open_sub_overlay()` como `PlayerMenuScreen._open_subscreen()` prioricen `closed` sobre `tree_exiting` (con `has_signal("closed")` como comprobación, cayendo a `tree_exiting` con aviso si algún día falta).
- **Segundo bug de motor preexistente encontrado de paso:** `ExplorationHUD._unhandled_input()` (a diferencia de `ExplorationController`) no comprobaba `GameLoop.is_input_blocked()` — disparaba `open_skill_tree`/`open_player_menu` sin importar el `GameState`. Inofensivo mientras `EXPLORATION` era el único origen legítimo (el guard de `SceneOrchestrator` ya bloqueaba la llamada), pero generaba ruido real (warning) al pulsar la tecla de PlayerMenu durante `NARRATIVE_SCENE`, porque el evento lo procesaban a la vez `NarrativeScenePanel` (correcto) y `ExplorationHUD` (bloqueado). Mismo guard añadido que ya tenía `ExplorationController`.
- Validado en partida real: apertura de Inventory/Party/PlayerMenu desde narrativa sin recargar el nodo ni perder racha; navegación completa Loadout→Inventory→SkillTree dentro de PlayerMenu (siendo este a su vez sub-overlay de narrativa) sin colgarse en ningún punto de cierre; regresión confirmada del camino normal desde `EXPLORATION`, sin cambios de comportamiento.
### Mejoras post-Spike 3, Grupo 5 — Pantalla de combate de producción
 
Sustituye la pantalla de combate de test (`combat_test_scene`/`combat_hud.tscn`) por una de producción real, sin cambiar ninguna regla de combate. El más grande de los cinco grupos de mejoras — diseño visual cerrado de antemano en conversación (arena de fichas circulares, party izquierda/enemigos derecha, log narrado, menú de 8 acciones). Ver `docs/mejoras_grupo5_combate_produccion_informe_cierre.md` para el detalle completo. Resumen de lo más relevante a nivel de motor:
 
- **Fase 5A — Design System**: `UIRadialGauge` (anillo de progreso radial, primer componente `_draw()`/arcos del Design System) y `UICombatToken` (ficha de party/enemigo, compone dos `UIRadialGauge` + relleno central + triángulo de turno + retícula de objetivo). `CharacterDefinition` gana `token_color`/`type_icon` para personalizar cada ficha desde el `.tres`, mismo criterio que retratos/nombres.
- **Fase 5B — MVVM**: `CombatArenaViewModel` (nuevo) **compone** a `CombatHudViewModel` (existente, sin tocar) como `action_menu`, en vez de sustituirlo — primer caso de composición de ViewModels del proyecto. Fichas dinámicas (`combat_tokens: Array[CombatTokenData]`) porque companions/enemigos pueden unirse a mitad de combate (rescate narrativo, refuerzos cronometrados vía `reinforcement_spawned`). Log narrado (`log_entries: Array[LogEntryData]`) con 4 categorías reales: `ATTACK` graduado por `SkillRoller` (5 claves), `DODGE`/`DEFEND`/`FLEE` sin grado (caminos de motor completamente distintos entre sí — dodge no tira, defend/flee no pasan por `combat_action_completed` en absoluto, van por señales propias de `DefenseModule`/`EscapeModule`).
- **El menú de acciones real son 8 slots, no 6** (spec original se olvidó los 2 de ítem) — ya modelado tal cual por `ActionSlotData`/`LoadoutState` existente, sin cambio de arquitectura.
- **Punto 8 — integración real en `SceneOrchestrator`**: `SCENE_COMBAT` → `combat_production_scene.tscn` (nueva pieza sin UI, solo IA + `PlayerCombatController`); `OVERLAY_COMBAT_HUD` → `combat_arena_panel.tscn`. `combat_test.tscn`/`combat_hud.tscn` no se retiran, quedan como escena de test independiente.
- **Hallazgo real en combate de producción, no anticipado**: `NarrativeSceneViewModel`/`ExplorationController` pre-registran `Characters`/`Resources` para enemigos pero **nunca `Skills`** — falso supuesto inicial de "ya está todo registrado" al diseñar `combat_production_scene.gd`. Corregido registrando Skills ahí mismo, con guard idempotente, para roster inicial y refuerzos por igual.
- **`EnemyCombatNode` (visual 2D, sprite+`AnimationController`) confirmado prescindible en producción**: ni `EnemyAI` ni `CompanionAI` dependen de él (ambos `extends Node`, sin `get_parent()`/dependencia de nodo padre) — `UICombatToken` cubre su único rol funcional real. `_get_entity_damage_number_position()` en `combat_system.gd` gana rama para `Control` junto a la `Node2D` existente.
- **Bug de motor preexistente confirmado, no arreglado en este grupo**: `ResourceSystem.resource_changed` (señal propia del autoload `Resources`) nunca se reenvía a `EventBus.resource_changed` — `combat_hub_viewmodel.gd` se conecta a la señal equivocada, así que el HP/EN del jugador probablemente no se actualiza en vivo en la pantalla de test. `CombatArenaViewModel` se conecta directamente a `Resources.resource_changed`, evitando el mismo bug.
- **Otro bug de motor preexistente confirmado**: `combat_hud.gd` mapea el slot `"escape"` a la action `"combat_escape"`, pero el InputMap real usa `"combat_scape"` (typo/mismatch) — el botón de huir por teclado probablemente no respondía en la pantalla de test.
- **Fuga de memoria preexistente confirmada**: `SceneOrchestrator._handle_combat()` nunca guarda referencia a la instancia de `SCENE_COMBAT` ni la libera en `_on_combat_ended()` (a diferencia de `OVERLAY_COMBAT_HUD`, sí liberada) — se acumula una copia por combate. `combat_production_scene.gd` se libera a sí misma como mitigación local, el problema de fondo en `SceneOrchestrator` sigue sin arreglar.
- **`AttributeResolver` (máximo derivado real del personaje) y `ResourceState.max_effective` (máximo genérico de `ResourceDefinition.max_base`, típicamente 100) confirmados como dos números desconectados** — nada llama a `Resources.set_max_effective()` para sincronizarlos, al menos en el camino de `combat_test_scene.gd`. **Resuelto en Spike 6**: causa raíz completa (no solo el camino de `combat_test_scene.gd`) era que `ModifierApplicator` solo sincroniza como efecto de `Characters.set_base_attribute()`, y el único caller de eso en todo el proyecto era `character_creation_viewmodel.gd` para `"player"` — enemigos/refuerzos/companions nunca pasaban por ahí. Arreglado sincronizando dentro de `ResourceSystem.register_entity()` mismo (ver tabla de autoloads arriba), no en cada punto de registro por separado. Ver `docs/spike_6_investigacion_motor_combate.md` para el detalle completo, incluido el segundo bug independiente que compartía síntoma (el HP fijo a 50.0 en el registro de enemigos, origen real del patrón `50/60` reportado).
- Validado jugando la aventura completa de "Los Telmori" de principio a fin, incluidos refuerzos reales a mitad de combate en la guarida (ronda 4).
`CharacterState` serializa `definition_id`, `character_name` y `attributes` vía `get_save_state()`/`load_save_state()`. Conectado a `SaveSystem` desde `SAVE_VERSION = 5` — `_restore_state()` restaura el snapshot de `CharacterSystem` **primero**, antes de recursos/skills, porque `load_save_state()` puede bootstrapear el registro de la entidad vía `definition_id` si no existe todavía.
 
**Registro en frío — resuelto para 4 de los 5 sistemas.** `EquipmentManager` e `InventorySystem` ya se auto-registraban dentro de su propio `load_save_state()` (no requería cambios). `ResourceSystem` y `SkillSystem` **no** lo hacían — su `load_save_state()` no hacía nada en silencio si la entidad no existía. Desde el spike de producción, ambos exponen `has_entity(entity_id) -> bool`, y `SaveSystem._restore_state()` registra la entidad en frío antes de restaurar si hace falta (el universo de skills a registrar sale de las propias keys del snapshot guardado, no de un kit hardcodeado). "Cargar Partida" desde un arranque en frío real ya funciona con HP/Stamina/Gold/Skills correctos.
 
**Actualizado en mejoras post-Spike 3, Grupo 1 — pendiente de posición cerrado, no por arreglo sino por irrelevancia:** con el pivote a RPG narrativo por eventos/flags (sin exploración espacial), `player_state["position"]` (x,y) sigue guardándose/restaurándose exactamente igual que antes (sin cambios de código), pero es dato vestigial — el jugador ya no se mueve por posición, así que el hueco de "no se restaura en arranque en frío" deja de tener ningún efecto observable en el juego. Candidato a limpieza futura (retirar el campo del schema), fuera de alcance de este grupo. `SAVE_VERSION` pasa a `6` en este mismo grupo — ver sección propia más abajo.
 
`SaveSystem._find_player()` busca primero bajo el nodo `"ExplorationScene"` (creado explícitamente por `SceneOrchestrator`), no bajo `get_tree().current_scene` — este último nunca cambia mientras `MainMenuScreen` siga siendo la Main Scene, ya que la exploración se instancia de forma aditiva (`get_tree().root.add_child()`), no con `change_scene_to_file()`.
 
### Mejoras post-Spike 3, Grupo 1 — Guardado de partida
 
Objetivo del grupo: que la partida guardada recuerde el progreso narrativo real (no solo personaje/recursos/skills/inventario/equipo) y se pueda reanudar exactamente donde se dejó, más un atajo barato de desarrollo para probar tramos avanzados sin jugar la aventura entera. Ver `docs/mejoras_grupo1_guardado_informe_cierre.md` para el detalle completo.
 
- **Comprobación de código — corrige un supuesto erróneo de la documentación previa:** `SaveManager`/`SaveData` **ya** guardaban flags/variables/eventos completados/checkpoints/party antes de este grupo (`narrative_state`, vía `_collect_narrative_state()`/`_restore_narrative_state()`) — la documentación de arquitectura decía lo contrario (desactualizada en este punto concreto, ya corregida). El hueco real no eran los flags en sí, era únicamente "a qué escena narrativa volver al cargar".
- **Decisión de diseño que cambia el mecanismo original del spec:** guardar deja de ser una hotkey libre (F5) disponible en cualquier `NARRATIVE_SCENE` — solo se puede guardar seleccionando una opción de diálogo ofrecida por NPCs concretos marcados como savepoint (ej. el sheriff en "Los Telmori"), no todos los NPCs. Al ser NPCs "sin peso en la historia" los que la ofrecen, que el diálogo sea repetible no abre ningún exploit (a diferencia del caso del sheriff con recompensas económicas en Grupo 5). F5 se retira del todo de `ExplorationController`; F9 (cargar) se queda sin restricción de estado, igual que "Cargar Partida" desde el menú.
- **`DialogueOptionDefinition` gana `triggers_save: bool = false`.** En `DialogueSystem.select_option()`, justo después de `_trigger_narrative_events()` y antes de navegar a `next_node_id`/terminar el diálogo: si `triggers_save`, llamada directa a `SaveManager.save_game()` — mismo nivel de acoplamiento que ese método ya tiene con `Narrative.apply_event()`. `DialogueRegistry._load_option_from_dict()` necesitó una línea nueva (`option.triggers_save = data.get("triggers_save", false)`) — construye cada opción campo a campo, sin mapeo genérico de claves JSON, así que un campo nuevo en el Resource no se lee solo por añadirlo al JSON de contenido.
- **`SaveData.narrative_state` gana `current_narrative_scene_id: String`. `SAVE_VERSION` sube de 5 a 6**, con migración (`_migrate_from_version()`) que rellena `""` en saves antiguos. Se recoge en `_collect_narrative_state()` vía `SceneOrchestrator.get_current_overlay()` (getter nuevo) + `NarrativeScenePanel.get_current_scene_id()` (getter nuevo, lee `_vm.current_node.scene_id`) — duck-typing con `has_method()`, mismo estilo que ya usa `SceneOrchestrator` internamente. Sigue siendo válido aunque el panel esté detrás de un sub-overlay de Diálogo (`visible = false`, pero `_vm.current_node` no se toca — ver Grupo 3).
- **Al cargar, `SaveSystem` no transiciona `GameState` directamente** — nunca lo ha hecho (el punto de cambio de escena en `_restore_state()` sigue comentado). Expone `get_pending_narrative_scene_id()`, y es `MainMenuViewModel.request_load_game()` quien decide `enter_narrative_scene(scene_id)` vs `enter_exploration()` tras `load_game()`.
- **Hallazgo no anticipado — `MENU → NARRATIVE_SCENE` no existía en `VALID_STATE_TRANSITIONS`.** `enter_narrative_scene()` llamado desde `MENU` caía en `push_warning()` sin transicionar nada ni avisar de forma ruidosa — silencioso hasta comparar logs. Corregido añadiendo `NARRATIVE_SCENE` a las transiciones válidas desde `MENU`.
- **Segundo hallazgo no anticipado, más profundo — orden de instanciación de `ExplorationScene`.** Con `MENU → NARRATIVE_SCENE` directo, es la primera vez que un combate puede dispararse desde una escena narrativa sin que `ExplorationScene` (y con ella, `_ready()` de la escena de exploración real, ej. `TelmoriVillage`) se haya instanciado todavía. Los listeners de continuación que ese `_ready()` registra (ej. `_register_telmori_ambush_continuation()` escuchando `EventBus.combat_ended` para spawnear "Rastros" tras la emboscada) se conectaban **después** de que el combate ya hubiera terminado y emitido su propia `combat_ended` — señal perdida en silencio, contenido de continuación nunca aparecía. Corregido factorizando `_ensure_exploration_scene_instantiated()` en `SceneOrchestrator`, llamado tanto desde `_handle_exploration()` como desde `_handle_narrative_scene()`.
- **Trampa de reentrada descubierta al aplicar el fix anterior, resuelta antes de que llegara a producción:** `TelmoriVillage._ready()` tenía su propio guard `if current_game_state != EXPLORATION: enter_exploration()`, pensado para cuando la escena se ejecuta suelta en el editor. Instanciar `ExplorationScene` dentro de `_handle_narrative_scene()` sin corregir ese guard habría hecho que `_ready()` viera `NARRATIVE_SCENE` (`!= EXPLORATION`) y llamara a `enter_exploration()` **en mitad de la propia apertura de la escena narrativa** — transición reentrante que habría cerrado el panel narrativo justo después de abrirlo. Corregido cambiando la condición a `== MENU` (el único caso real que necesitaba cubrir: arranque sin `GameLoop`/`SceneOrchestrator` de por medio).
- **Falsa alarma descartada:** el warning `[InventorySystem] Entity not registered for load` al cargar no es un bug — `InventorySystem.load_save_state()` ya se auto-registra (`register_entity()`) si la entidad no existe, a diferencia de lo que en un primer momento se sospechó por analogía con `ResourceSystem`/`SkillSystem` (que si necesitaron ese fix, en el spike de producción). El inventario se carga bien pese al warning.
- **Hallazgo de paso, sin código:** `SaveFeedbackUI` ya existía y ya escuchaba `save_completed`/`save_failed` de `SaveSystem` — el feedback visual de "partida guardada" al usar la opción de diálogo del NPC savepoint no necesitó código nuevo.
- **Atajo de desarrollo** (mecanismo aparte del guardado real, nunca toca `SaveManager`/`SaveData`): tecla F2, ver sección "Input en exploración" más abajo para el detalle.
- Validado en partida real completa: guardar desde el sheriff en `NARRATIVE_SCENE` → cerrar el juego → "Cargar Partida" desde el menú resume exactamente en esa escena narrativa, con todo el estado restaurado (personaje, recursos, skills, equipo, inventario, party, economía, flags) → seguir jugando con normalidad, incluida una mejora de skill post-combate (`SkillProgressionService`) y el combate final de la guarida, hasta completar la aventura entera de "Los Telmori" de principio a fin.
### Mejoras post-Spike 3, Grupo 4 — Arte narrativo
 
Fondos de escena, fondos de combate reales (Grupo 5 los había dejado como `ColorRect` fijo) e iconos de tipo de enemigo para "Los Telmori", generados con IA bajo una dirección de arte acordada en conversación. Sin animación. Ver `docs/mejoras_grupo4_arte_narrativo_informe_cierre.md` para el detalle completo (catálogo, primers de estilo, mapeo escena → fondo). Resumen de lo más relevante a nivel de motor:
 
- **Layout narrativo B1** — imagen a pantalla completa detrás, panel en el tercio inferior (ver árbol en "Narrative Scene — Arquitectura" arriba). Solo `.tscn`, cero líneas de script.
- **`image_path` validado al cargar**: `NarrativeSceneDefinition.validate()` emite `push_warning` si la ruta no existe — antes solo fallaba al llegar a la escena en partida.
- **Fondo de combate por encuentro**: `CombatEncounterDefinition.background_path` (clave del `combat_encounter` inline del outcome). `GameLoopSystem.get_current_encounter()` (getter nuevo, solo lectura) lo expone; `CombatArenaViewModel` carga la textura con `call_deferred()` desde `_on_combat_started()` — `combat_started` no se emite desde `game_loop_system.gd`, así que no hay orden garantizado frente a la asignación de `_current_encounter`. Limitación conocida: un encuentro sustituido a mitad de combate vía `configure_active_encounter()` no actualiza el fondo (no hay señal); ningún contenido lo usa.
- **Los fondos de combate son mapas cenitales, no las láminas de escena** — decisión tomada durante el grupo (el spec proponía reutilizar el catálogo de escena): tinta y aguada sobre pergamino, sin cuadrícula porque las fichas no se mueven por el mapa. Uno por encuentro, en `data/combat/backgrounds/<aventura>/`.
- **Velo y contorno**: `Background` pasa a ser velo (`COLOR_PANEL` con alfa `COMBAT_BACKGROUND_SCRIM_ALPHA = 0.2`) encima de la imagen, opaco si no la hay. Contorno oscuro (`TEXT_OUTLINE_SIZE`/`COLOR_TEXT_OUTLINE`, tokens nuevos) en el texto de `UICombatToken` y del log. El alfa es una constante global válida mientras todos los fondos de combate sean mapas claros del mismo estilo — si conviven con láminas oscuras, tendrá que pasar a dato por encuentro.
- **Bug preexistente corregido**: las fichas enemigas nunca recibían `fill_color` (quedaban en el `Color.WHITE` por defecto de `CombatTokenData`) — un icono claro habría sido invisible. Y `_resolve_fill_color()` no respetaba el centinela `Color.BLACK` de `token_color` (ficha negra en vez de color neutro).
- **Iconos de tipo**: carpeta por aventura (`data/characters/telmori/icons/`) + carpeta genérica (`data/characters/icons/`); si el arte coincide se copia el fichero. `enemy_base` sin icono por decisión.
- **Latente, no corregido**: `CharacterDefinition.duplicate_definition()` no copia `token_color`/`type_icon`/`starting_skill_values`/`loot_table_id` — sin llamadas en el proyecto, sin efecto hoy.
- **Hallazgos preexistentes fuera de alcance, sin corregir**: los 8 botones de acción de la arena no muestran nombre; la columna enemiga se desborda por arriba con 6-8 enemigos; el log muestra IDs internos en vez de nombres localizados; el desajuste PV actual/máximo de Grupo 5 (visible como `50/45`).
- Validado en partida completa de "Los Telmori": las 21 escenas con fondo, los dos combates con su mapa, iconos reales en todas las variantes de enemigo.
### Spike 10 — Diálogos restantes del sheriff (Los Telmori)
 
Aplica a `telmori_sheriff_reward_intro` y `telmori_sheriff_training` el patrón de Grupo 2 (sub-overlay de diálogo desde `NarrativeScenePanel`, `dialogue_id` en el outcome, `resume_after_dialogue()`). `telmori_sheriff_pelts` no se convierte (tirada real de Curtido, `DialogueOptionDefinition` no soporta tiradas) y `telmori_epilogue_hook` no se toca. Con esto el **Grupo 2 queda completo**. Ver `docs/spike_10_dialogos_sheriff.md` para el detalle completo.
 
- **Decisión de diseño (camino A):** el diálogo solo conversa; las entregas se quedan en el outcome narrativo que abre el diálogo (`grant_resource_*`/`grant_item_*` + `dialogue_id` + `next_scene_id`). Comprobado con el código real que `DialogueOptionDefinition`/`DialogueSystem` no tienen mecanismo de entrega (solo `narrative_events`, `triggers_save` y navegación) — no se añadió, porque no hacía falta. Las entregas ocurren al pulsar la opción, **antes** del diálogo; el texto de la escena narra el traspaso.
- **Exploit cubierto por diseño:** la entrega vive fuera del hub, así que volver a una rama del diálogo no puede reclamarla dos veces; la protección contra reentrada de la cadena sigue siendo la limpieza del interactuable con `flag.telmori_adventure_completed`.
- **Hallazgo 1 — `grant_item_*` no se ejecutaba.** El bloque de entrega de ítems se había perdido de `NarrativeSceneViewModel._apply_outcome()` (quedaba el comentario con la entrega de recurso debajo), sin ningún error visible: ningún ítem de ningún outcome llegaba al inventario, incluidos la bolsa mágica y la punta de obsidiana de Grupo D. Con toda probabilidad se perdió al parchear el método en el Grupo 2. Restaurado antes del retorno temprano de `dialogue_id`, con `print` por entrega y `push_warning` si `Inventory.add_item()` devuelve `false`.
- **Hallazgo 2 — un libro no podía enseñar una skill fuera del kit.** `register_entity_skills()` solo crea instancias del kit; `execute_learning_session()` no encontraba la de Curtido (`skill_locked`) y `_apply_consumable()` emitía `item_use_success` incondicionalmente, consumiendo el libro sin efecto. Los libros anteriores solo mejoraban skills ya poseídas. Arreglo: `SkillSystem.learn_skill()`, `initial_value` en `learning_data`, `_apply_learning()` devuelve `bool` y el libro solo se consume si el aprendizaje se aplicó (`item_use_failed` en caso contrario; una tirada de mejora fallida sigue consumiéndolo). Detalle en "Skills — dos sistemas paralelos de valores" arriba.
- **Localización:** faltaban textos de cuatro escenas del Grupo D, la escena de botín y las flechas/lanza de Grupo B. Un `.csv` nuevo necesita alta manual en Project Settings (`items_telmori.csv` no la tenía).
- **Validado en partida real** (F2 con `flag.telmori_lair_cleared`): entregas una sola vez cada una, ambos diálogos como sub-overlay con reenganche automático, tomo leído desde el inventario en pleno `NARRATIVE_SCENE` → `APRENDIDA (valor inicial 15%)`, Curtido visible y entrenable desde el panel de habilidades, tirada de venta contra el valor real, `flag.telmori_adventure_completed` marcado e interactuable retirado.
- **Sin probar en partida:** el camino de fallo del libro (`item_use_failed`, libro no consumido) y el guardado/carga con Curtido aprendido (solo comprobado por código).
### Spike 11 — Rediseño de la ventana de diálogo (fondo, retrato, estado de ánimo)
 
Rediseña `DialoguePanel`, mínimo y sin decoración desde su creación: fondo
propio, marco decorativo del Spike 9 y un único retrato del NPC (se
descarta definitivamente el layout de dos retratos original — el jugador
ya "habla" a través de las opciones). Ver `spike_11_ventana_dialogo.md`
para la maqueta y el detalle completo de la Fase 1.
 
- **Comprobación de código previa (Fase 0):** `portrait_id` ya existía y se
  consumía de verdad (JSON → `DialogueRegistry` → `DialogueNodeDefinition`
  → `DialogueSystem` → `EventBus.dialogue_node_shown` →
  `DialogueViewModel` → `DialoguePanel`) — no era un campo huérfano como
  `grant_item_*` en Spike 10. No existía ningún campo de estado de ánimo.
  Las dos claves crudas vistas en captura (`SPEAKER_SHERIFF`,
  `DLG_SHERIFF_OPT_SAVE`) eran huecos reales en
  `dialogues_scenes_telmori.csv`, no un problema de alta del `.csv` en
  Project Settings (ya estaba dado de alta desde Spike 10) — corregidas
  añadiendo las dos filas.
- **`DialogueNodeDefinition` gana `mood: String = "neutral"`** (por nodo,
  no por diálogo: cambia a mitad de conversación). Resuelto en
  `DialogueViewModel._resolve_portrait()` con cascada de respaldo:
  `"<portrait_id>_<mood>.png"` → `"<portrait_id>.png"` (neutral) → sin
  retrato, con `push_warning` en cada salto — nunca falla en silencio como
  hacía antes la resolución de `portrait_id`.
- **`DialogueDefinition` gana `portrait_folder: String = ""`** (subcarpeta
  de retratos por aventura, bajo `res://data/characters/portrait/`) **y
  `background_id: String = ""`** (escena de fondo dentro de la aventura).
  Ambos opcionales y con respaldo — vacíos, el comportamiento es el de
  antes de este spike, ningún diálogo existente necesitó tocarse.
  `background_id` cae al fondo genérico de la aventura
  (`res://data/dialogue/backgrounds/<portrait_folder>.png`) si está vacío
  o el fichero de escena no existe.
- **`EventBus.dialogue_node_shown` pasa de 4 a 7 argumentos** (`portrait_id`,
  `mood`, `portrait_folder`, `background_id`). Los oyentes existentes que
  declaraban menos parámetros —incluidos los tests— siguieron compilando
  sin tocarlos: GDScript descarta los argumentos de más al emitir una
  señal si el callback conectado acepta menos. `DialogueSystem` expone
  `mood` en `get_current_node_info()` y en el nuevo getter
  `get_current_mood()`.
- **Base de `DialoguePanel` migrada de `PanelContainer` plano a `UIPanel`**
  (`decorative_frame = true`, marco del Spike 9) — pendiente que dejó
  abierto el propio Spike 9 ("activar el marco en otras pantallas,
  pantalla a pantalla"). Exports de configuración visual declarados sin
  efecto real, retirados: `background_texture`, `portrait_frame_texture`,
  `text_color`, `text_font_size`, `speaker_name_color`,
  `speaker_name_font_size`.
- **Antipatrón nuevo, mismo patrón que "Panel sin tamaño fijo con texto
  largo" pero por número de hijos en vez de longitud de texto:** un
  `PanelContainer` no se encoge por debajo del mínimo de sus hijos: con 5
  opciones, el panel de diálogo crecía y, por `grow_vertical = BEGIN`,
  "subía" invadiendo pantalla en vez de quedarse en su franja. Arreglo:
  `OptionsContainer` envuelto en un `ScrollContainer` — no impone el
  mínimo de su contenido al padre, hace scroll en su lugar. Con la altura
  de panel definitiva (anclas `0.57`–`0.96`, corregidas desde un `0.66`
  copiado por error de la convención de `NarrativeScenePanel`, que no
  encajaba con el contenido real de este panel) caben 3 opciones sin
  scroll.
- **Fondo de ambiente:** mismo patrón que `CombatArenaViewModel`/Grupo 4
  (`BackgroundImage` detrás + `Background` como velo semitransparente
  encima, razón `"background"` de `changed()`, solo emitida cuando el path
  cambia). Imagen pre-difuminada en la generación, no blur en tiempo real
  (evita `SubViewport`+shader). `SCRIM_ALPHA_WITH_IMAGE = 0.55`, validado
  contra el arte real de Los Telmori.
- **Retrato como hermano del panel, no hijo** — layout C de la maqueta
  (franja inferior, retrato grande sobresaliendo por el borde superior del
  marco), elegida sobre las variantes A ("retrato lateral") y B ("panel
  centrado") para dar protagonismo a la imagen del NPC. Sin retrato
  disponible, el panel de texto ocupa todo el ancho.
- **Validado en partida real**, aventura completa de "Los Telmori" de
  principio a fin: apertura como sub-overlay desde escena narrativa y
  desde `EXPLORATION` vía interactuable; cambio de expresión a mitad de
  conversación; hablante sin retrato; contrato de sub-overlay de Grupo 2
  (`signal closed`, `resume_after_dialogue()`) intacto tras el rediseño.
- **Deuda técnica anotada, fuera de alcance de este spike:** tests de
  `dialogue_node_shown` (`dialogue_panel_test.gd`, `test_dialogue_system.gd`,
  `test_eventbus.gd`) no adaptados a la firma de 7 argumentos; resolución
  de ventana (afecta a toda pantalla con posiciones en píxeles fijos, no
  solo a este panel — decisión de proyecto, no de spike); documentación de
  `UIPanel.Variant.OVERLAY` como semitransparente, con stylebox opaco en
  la práctica.
### Spike 12 — Motor de escenas interactivas (mapa de puntos de interés)
 
**Qué es.** Un primitivo genérico: imagen de fondo + puntos clicables posicionados por datos + visibilidad por flags + un clic dispara una acción. Sustituye la apertura del pueblo como `SCENE_EXPLORATION` (sin jugador, sin física, sin cámara). Naming genérico (`InteractiveScene*`/`InteractiveHotspot*`) a propósito: el mismo primitivo servirá para futuras escenas de "buscar algo en la imagen" (mecánica NO decidida en este spike). Decisiones de Fernando: sin movimiento ni posición de personaje; sistema nuevo y dedicado (`WorldObjectSystem`/`Interactable` no se tocan); visibilidad declarativa, no dinámica por evento. Cerrado y validado en partida real con `poi_test_map`. Detalle en `docs/spike_12_motor_mapa_poi.md`.
 
**Flujo:**
```
InteractiveSceneView (Button por hotspot visible)
  → InteractiveSceneViewModel.activate_hotspot(id)        [guard: GameState == EXPLORATION]
    → hotspot_activated(interaction_type, target_id, enemy_definitions)
      → ExplorationInteractiveMap (composición, sin lógica)
        → ExplorationController.request_interaction(type, target_id, enemy_definitions)
          → GameLoop.enter_dialogue / enter_shop / start_combat / enter_narrative_scene
```
 
**Datos** (`core/interactive_scenes/`, JSON en `data/interactive_scenes/`): `InteractiveSceneDefinition` (scene_id, image_path, hotspots) e `InteractiveHotspotDefinition` (vocabulario de salida calcado de `Interactable` + `map_position` normalizada 0–1, `icon_path`, `label_key`, `required_flags`, `blocked_flags`). `item` queda fuera de los tipos válidos en v1 (exige un `WorldObject` registrado). `validate()` marca error por tipo inválido, `label_key`/target vacío o `hotspot_id` duplicado, y warning por posición fuera de 0–1 o icono inexistente. El `ViewModel` avisa al cargar de `scene_id` narrativos inexistentes.
 
**`ExplorationController.request_interaction()`** es ahora el ÚNICO punto de routing. Tiene guard propio (`is_input_blocked()`) por ser API pública. Para `combat`, `enemy_definitions` llega como parámetro y se copia a `_pending_enemy_definitions` antes de registrar enemigos; confirmado en log: `Enemy definitions loaded: {…: "wolf_test"}` y enemigos pre-registrados con `def: wolf_test`, no `enemy_base`.
 
**Visibilidad declarativa.** `required_flags` (todos puestos) y `blocked_flags` (ninguno puesto), evaluados contra el autoload `Narrative`. Se recalcula al cargar la escena y en cada `game_state_changed → EXPLORATION` — sin spawn/cleanup por evento ni listeners de `combat_ended`. Un flag puesto sin cambio de estado (p. ej. el atajo F2) no refresca hasta la siguiente vuelta a `EXPLORATION`.
 
**Escena raíz `exploration_interactive_map`.** `ExplorationController` + `ExplorationHUD` (misma jerarquía de hijos que el HUD del pueblo — usa `$` en `@onready`, falla en `_ready()` si falta alguno) + `MapLayer` (`CanvasLayer` capa -1, oculto en `COMBAT_ACTIVE`/`VICTORY`/`DEFEAT`; comprobado en partida que el mapa no se ve durante el combate). El HUD no necesita `Player`. La escena raíz llama a `exploration_hud.refresh()` en su `_ready()`.
 
**SaveSystem.** `_collect_player_state()` exigía un nodo `Player` (`_find_player()`) y abortaba el guardado con `Player node not found`; con esta escena habría bloqueado cualquier savepoint (`triggers_save`). Ahora guarda sin la clave `position` si no hay `Player` (clave opcional, `SAVE_VERSION` sin cambios); la restauración ya toleraba un `Player` ausente. Validado: guardado desde el NPC savepoint con el mapa activo (`Game saved successfully`) y "Cargar Partida" que reanuda en `telmori_sheriff_briefing` sobre el mapa.
 
**Correcciones a lo que se creía antes de la Fase 0:**
- `Interactable` estaba vivo, pero solo con `narrative_scene` y creado por código; el `@export_enum` no lista `narrative_scene`.
- La primera entrada narrativa del pueblo es `_ready()` + `flag.telmori_village_visited` → `enter_narrative_scene("telmori_village_arrival")`, no un `Interactable`.
- `TelmoriVillage._ready()` hace inicialización de partida (`Party.join_party("companion_mira")`, equipo inicial para `player` y `companion_mira`): lógica de juego dentro de una escena.
- El nombre del nodo raíz del `.tscn` de exploración es libre: `SceneOrchestrator` fuerza `name = "ExplorationScene"` al instanciar (solo importa al ejecutar una escena suelta con F6).
- `NarrativeSceneDB` sí es un autoload (`Node` sin estado runtime); `InteractiveSceneDB` sigue el mismo patrón.
**No verificado en partida.** El camino físico de `Interactable` tras el refactor de `ExplorationController` (revisado por inspección, comportamiento idéntico por diseño, pero no jugado de extremo a extremo). F9 queda fuera: no operativo desde el Spike 7. **Spike 13: descartado** — el pueblo no usa `Interactable` y se descartaron el tutorial y el test; no se validará (ver la sección siguiente).
 
**Pendiente (Spike 13):** *resuelto — ver la sección siguiente.* (Entonces: inicialización de partida fuera de la escena; los 3 spawns por evento del pueblo → hotspots declarativos; un flag de victoria de la emboscada; arte, `UIButton` del Design System y claves de localización reales.)
 
### Spike 13 — Reautoría del pueblo de "Los Telmori" sobre el motor de escenas interactivas
 
**Qué es.** Aplica el motor de Spike 12 al contenido real. El pueblo deja de ser una escena 2D con `Interactable` creados por código y pasa a ser un **hub persistente** (`data/interactive_scenes/telmori_village.json`) sobre una ilustración (`mapa_aldea_telmori.jpg`, tinta y aguada sobre pergamino) con cuatro lugares — sheriff, herrería, taberna y salida — que cambian de significado según la etapa de la aventura. `exploration_interactive_map.tscn` carga ahora `telmori_village`; `poi_test_map` queda para pruebas cambiando `interactive_scene_id`. Cerrado y jugado de principio a fin, con validación parcial (ver más abajo). Detalle en `docs/spike_13_reautoria_pueblo_telmori.md`.
 
**El plan original no era el real.** La spec trataba el mapa como un contenedor para tres hotspots dinámicos (rastro, aftermath, recompensa del sheriff) y planteaba un flag de victoria de la emboscada. El flujo que quería Fernando es un hub: tras la llegada se visita el sheriff, la herrería y la taberna; la salida está visible pero bloqueada hasta aceptar el encargo (y de nuevo hasta cobrar la recompensa), y al ganar un combate se encadena directamente la siguiente escena narrativa en vez de dejar al jugador en el pueblo. Eso cambió el diseño:
 
| Etapa | Flags activos | Sheriff | Salida |
|---|---|---|---|
| 1 Llegada | — | diálogo (con "aceptar") | aviso: falta aceptar el encargo |
| 2 Encargo aceptado | `flag.telmori_sheriff_briefed` | diálogo (sin "aceptar") | → colinas |
| 3a Emboscada ganada, rastreo fallido | + `flag.telmori_ambush_won` | diálogo | → rastreo |
| 3b Rastro logrado | + `flag.telmori_tracked_to_lair` | diálogo | → puerta de la guarida |
| 4 Guarida limpia | + `flag.telmori_lair_cleared` | recompensa (cadena narrativa) | aviso: falta cobrar |
| 5 Completada | + `flag.telmori_adventure_completed` | diálogo final | → salida final (marcador) |
 
**Hotspots.** 11 hotspots en 4 posiciones. Los que comparten sitio son mutuamente excluyentes por `required_flags`/`blocked_flags` (comprobado por simulación para las 7 combinaciones de flags: en cada etapa se ve una sola salida y un solo sheriff). No hizo falta motor nuevo para el "visible pero bloqueado": dos hotspots en el mismo sitio, uno de los cuales abre una escena de aviso de un nodo. Con `icon_path` válido salen como `UIButton` solo-icono (medallón) con el nombre en tooltip; sin él, botón de texto.
 
**Ciclo de combate (cambio de motor).** Con `NarrativeSceneOutcome.combat_victory_scene_id`, ganar el combate abre esa escena narrativa en lugar de volver a `EXPLORATION`: emboscada → `telmori_post_ambush_tracking` → guarida → combate → `telmori_lair_victory` → `telmori_lair_loot_obsidian` → pueblo. Huir devuelve al pueblo, donde la salida de la etapa correspondiente permite reintentar.
- `GameLoop.VALID_STATE_TRANSITIONS`: `VICTORY → [EXPLORATION, NARRATIVE_SCENE]` (**cambio de contrato**).
- `start_combat(enemy_ids, encounter = null, victory_scene_id = "")`. El id vive en `GameLoop._pending_victory_scene_id` — no en `CombatEncounterDefinition`, que puede ser `null` y cuyo `_current_encounter` se limpia en `end_combat()`. `consume_pending_victory_scene()` lo devuelve y vacía; `end_combat()` lo descarta tras emitir `combat_ended` (emisión síncrona), para que no se fugue al combate siguiente.
- `SceneOrchestrator._on_combat_ended`: abre la escena de victoria; si el id **no existe**, `push_error` y vuelve a `EXPLORATION`. Una prueba con un id mal escrito abría un panel narrativo vacío sin salida: softlock justo tras ganar.
- **El defecto de la spec era doble:** `flag.telmori_ambush_triggered` y `flag.telmori_lair_combat_won` (mal nombrado) se ponían al DISPARAR el combate, no al ganarlo. Ya no los pone ni lee nadie. `flag.telmori_ambush_won` lo pone `telmori_post_ambush_tracking` en su salida de fallo (solo se alcanza tras ganar); en la de éxito ya pone `flag.telmori_tracked_to_lair`. `flag_to_set` es un único flag por outcome, así que la visibilidad se diseñó para no necesitar dos.
**Otros cambios de motor.**
- `NarrativeSceneOutcome.take_item_*` (quitar un ítem; desequipa antes). Se usa en `telmori_sheriff_reward_intro` para devolver `enchanted_spear` (préstamo: `quest_loan`, `base_value` 0). Solo cubre una entidad: si la lanza pasa a Mira no se retira.
- `InteractiveSceneDefinition.on_first_visit` + `InteractiveSceneViewModel.request_first_visit()`: acción de una sola vez al entrar por primera vez. Solo en `EXPLORATION`, marca el flag antes de actuar, llamada con `call_deferred` desde el `_ready()` de la escena raíz para que `SceneOrchestrator` termine de atender `EXPLORATION` antes de abrir la escena narrativa. El pueblo abre así `telmori_village_arrival` (`once_flag: flag.telmori_village_visited`), lo que antes hacía `TelmoriVillage._ready()`.
- `AdventureStarter.apply()` + `data/adventures/telmori.json`: companions y kit inicial, una sola vez al confirmar el personaje.
- `UIButton`: `min_square` e `icon_backdrop` (opt-in).
- **Dos mensajes preexistentes al huir, corregidos de paso:** `EXPLORATION → EXPLORATION` (`end_combat("escaped")` ya transiciona a `EXPLORATION` y `_on_combat_ended` repetía `enter_exploration()`) y `ROUND_START → PLAYER_ACTION_SELECT` (la huida se resuelve DENTRO de la señal `player_turn_started`: el combate acaba y `_start_player_turn()` seguía transicionando de fase). Dos guardas de dos líneas.
**Datos.**
- Tienda propia `blacksmith_telmori.tres` (`max_slots` 16): stock de `blacksmith_01` + `enchanted_spear` (valor 0, sale gratis) y 20 `silver_arrow` (2 de oro cada una). El jugador empieza con 50 de oro, suficiente para las flechas.
- Sheriff: el hotspot abre `DLG_TELMORI_SHERIFF_BRIEFING` directamente (la escena narrativa envoltorio ya no se usa). `O4` (aceptar) con `blocked_flags: [flag.telmori_sheriff_briefed]` — flag puesto por `EVT_TELMORI_SHERIFF_BRIEFED`, disparado desde la opción —, nueva opción "Salir", y `O1`–`O3` bloqueadas con la aventura completada. El diálogo tiene guardado (`triggers_save`) y es el punto de guardado del hub. **La etapa 4 no ofrece guardado a propósito:** la cadena de recompensa entrega oro y trofeo al pulsar, y un guardado dentro permitiría cobrar dos veces.
- Escenas narrativas nuevas, editadas y sin uso: ver el árbol. Localización: +19 claves y 3 modificadas (ver el árbol).
**Decisión sobre `Interactable` (punto 6 de la spec).** El pueblo no usa ninguno: un mapa estático no puede tenerlos (sin jugador, física ni proximidad). Fernando descartó `exploration_tutorial` y `exploration_test` (no eran escenas de producción). `Interactable` queda **vestigial**, sin consumidores en el camino jugable, y el camino físico refactorizado en Spike 12 (`request_interaction()`) **nunca se validó en partida real y ya no se va a validar**. Candidato a limpieza en la recopilación final (ver pendientes, punto 10).
 
**Hallazgos.**
- **Colisión de nombres de fichero:** el diálogo y la escena narrativa del briefing se llamaban igual en carpetas distintas; al copiar el diálogo a `narrative_scenes` se pisó la escena y `NarrativeSceneDB` dio `scene_id vacío`. Los diálogos llevan prefijo `dlg_`.
- **Un `NarrativeScene` con id inexistente abre un panel vacío sin salida desde cualquier origen;** solo se protegió la ruta de victoria. Guarda general pendiente.
- `EVT_TELMORI_SHERIFF_BRIEFED` declara `trigger_type: DIALOGUE_END`, pero la búsqueda no encontró código que consuma `dialogue_ended` para disparar eventos: se disparan desde `narrative_events` de la opción (inferido de la búsqueda de código; el caso contrario no se probó).
- Las "fichas de combate" (`UICombatToken`) no son reutilizables como icono de mapa: están acopladas al combate. Los iconos de hotspot son PNG propios con `UIButton`.
- Los `push_warning`/`push_error` salen en la pestaña Depurador → Errores, no en la salida de texto: los dos mensajes de la huida llevaban ahí desde antes y no aparecían en los logs pegados.
**Validación.**
- **Validado en partida real (Fernando):** la aventura completa sobre el motor nuevo; guardado al final y cierre del juego; la lanza desaparece del inventario al empezar la recompensa; huir de la emboscada devuelve al pueblo y ganar sigue el ciclo definido.
- **Validado por log:** llegada → mapa; kit una sola vez y Mira en el grupo; victoria con escena; huida; id de victoria inexistente (fallback).
- **Sin confirmar:** un segundo punto de guardado distinto (la spec pide dos); ganar un combate sin escena de victoria y la derrota (solo comprobables con `poi_test_map`); lanza equipada frente a vendida; que "Salir" del sheriff no marque `sheriff_briefed`.
- Camino físico de `Interactable`: no validado y descartado.

### Spike 14 — Reinicio de sesión y teardown (motor)

**Qué es.** Primer spike del hito de rediseño de interfaces, y puramente de motor: perder un combate no tenía salida y, aun llegando al menú principal, la sesión anterior seguía viva en memoria. Cerrado y validado en partida real. Detalle en `docs/spike_14_reinicio_sesion.md`.

**Causa raíz.** (1) `_show_game_over()` colgaba `GameOverUI` de `root` sin guardar referencia: nadie lo liberaba. (2) `_handle_main_menu()` solo ocultaba el overlay y ningún sistema reaccionaba a `MENU`: `ExplorationScene` seguía viva. (3) No existía reinicio de sesión; el guard `has_entity("player")` de Character Creation dejaba al jugador muerto con HP 0 y stats viejos, y `AdventureStarter` no es idempotente. (4) La carga sobrescribe, no borra. (5) La View del Game Over contenía lógica de juego.

**Qué se hizo.** Un coordinador explícito de orden fijo, `SessionReset.apply()`, que `SceneOrchestrator` lanza al entrar en `MENU` tras liberar síncronamente las escenas de la partida y esperar un frame. Reutiliza APIs existentes (`Dialogue.reset`, `Combat.clear_buffs`, `Party.leave_party`, `Narrative.clear_all`, `Checkpoints.reset`); solo `Economy` ganó un método nuevo (`reset_session()`), y la baja de una entidad se factorizó en `EntityLifecycle.unregister_everywhere()`, que ahora usa también `PartyManager`. El Game Over pasa a tener `GameOverViewModel` (una intención, un botón hacia el menú principal) y su View ya no conoce ningún sistema de `core`. Sin cambio visual.

**Cambios respecto a la spec.** `Combat.clear_buffs()` entra en el reinicio (los buffs nunca se limpiaban entre combates y los ids de companion son fijos); el guard tras el `await` acepta `MENU` y `CHARACTER_CREATION`; el ViewModel reabre el botón si la transición a `MENU` falla; el botón se llama `ReturnToMenuButton`.

**Fase 0.** Diez comprobaciones antes de escribir código; dos hallazgos relevantes: `WorldObjectSystem`, `ItemCharacterIntegration` y `EnemyWorldLink` están sin uso en producción (no necesitan reset), y `CombatSystem._active_buffs` sí necesitaba entrar.

**Pendientes que deja.** `_active_buffs` no se limpia entre combates; `CombatLootSpawner.spawn_pending_loot()` sin llamador; `ItemCharacterIntegration` es código muerto; acceso privado residual `_entity_skills.keys()` en `PartyManager`; fila `MENU_CONFIRM_YES` de `menus.csv` con comas sin comillas; aviso en cada carga de la exploración por el marcador `telmori_village_departure` (Spike 13). El rescate narrativo y la muerte permanente de un companion no tienen camino jugable y no se probaron. La carga con F9 queda desestimada de forma definitiva.

### Spike 15 — Cimientos del Design System

**Qué es.** Segundo spike del hito de rediseño de interfaces: resuelve una vez lo que comparten las pantallas, sin rediseñar ninguna. Cerrado y validado en partida real. Detalle en `docs/spike_15_cimientos_design_system.md`.

- **Resolución: sin estiramiento.** Experimento en una copia (base 1280×720 con `canvas_items` frente a los valores por defecto): el estiramiento ablandaba el texto (≈ 15 % en la medición) y se descartó. Se mantienen 1152×648 y las pantallas del hito se diseñan con anclas para esa ventana mínima.
- **Tokens (`ui_tokens.gd`).** Los dos vocabularios (`COLOR_*` frente a `BG_*`/`BORDER_*`/`TEXT_*`) se fusionan con alias (`BG_BASE→COLOR_BG`, `BG_PANEL→COLOR_PANEL`, `BG_SURFACE→COLOR_PANEL_ALT`, `BORDER_DEFAULT→COLOR_BORDER`, `TEXT_PRIMARY→COLOR_TEXT`, `TEXT_MUTED→COLOR_TEXT_MUTED`, `COLOR_SLOT_OCCUPIED→COLOR_PANEL_ALT`). Dos cambios de valor visibles: `COLOR_TEXT_MUTED` → `#9A8E78` y `COLOR_PANEL_ALT`/`BG_SURFACE` → `#252220`. Nuevos `FRAME_MIN_PADDING` (16) y `FRAME_CORNER_TEXTURE_PATH`. Validado con `test_tokens_alias.gd` (12/12).
- **`UIPanel`.** Esquinera por defecto (el diálogo ya la muestra), padding mínimo con marco, `push_warning` fuera de `_draw()` y una sola vez, activación del marco en runtime, docstring corregido (`OVERLAY` es opaco, `POPUP`/`OVERLAY` sin consumidores).
- **Diálogo.** `OptionsContainer` pasa a `GridContainer` (1 columna hasta 3 opciones, 2 desde 4), franja de opciones con altura natural reservada (corrige también la tercera opción cortada en los diálogos de 3 opciones a 648, existente desde el Spike 11), margen del texto proporcional al borde real del retrato (adiós al 240 fijo que solapaba a partir de 1280 de ancho), foco inicial en la primera opción con estilo de hover. El `sheriff_briefing` con 6 opciones cabe sin scroll en 1152×648.
- **Localización.** 29 claves duplicadas de `translations.csv` y una `WORLD_OBJECT_DEPLETED` repetida eliminadas; `DLG_SHERIFF_REWARD_01_GREET` entrecomillada (la fila «rota» de la spec, `MENU_CONFIRM_YES`, estaba bien); `SPEAKER_INNKEEPER` añadida; nuevo `skills.csv` (26 filas movidas + 14 nuevas para 7 habilidades sin traducción).
- **`UISlot`.** Solo el docstring (ruta `components/ui_slot/`).
- **Hallazgos de la Fase 0 que corrigieron la spec:** cifras de altura inexactas, hipótesis «scroll solo en ventana de 648» falsa, fila de CSV mal identificada.
- **Pendientes que deja.** Retrato del posadero (muestra el del sheriff); pestaña `companion_mira` y `T1` sin localizar en el árbol de habilidades (spike 21); posible recorte de 4 px con saludo de 3 líneas y 6 opciones a 648; claves `SKILL_META_COST_`, `SKILL_NOT_FOUND`… por revisar; comentario erróneo en `interactive_scene_view.gd:15`; fuentes/tema sin aplicar.
---
 
## Changelog completo (orden cronológico inverso)
 
*Última actualización: Spike 15 — Cimientos del Design System (cerrado y validado en partida real). Resolución sin estiramiento (experimento con `canvas_items`, texto ≈ 15 % más blando); tokens fusionados con alias y dos cambios de valor (`COLOR_TEXT_MUTED` `#9A8E78`, `COLOR_PANEL_ALT`/`BG_SURFACE` `#252220`); `UIPanel` con esquinera por defecto, padding mínimo con marco y activación en runtime; diálogo con opciones en rejilla (1 columna hasta 3, 2 desde 4), altura reservada, margen del texto proporcional al retrato y foco de teclado; localización limpia (29 duplicados, fila rota, `skills.csv` nuevo, `SPEAKER_INNKEEPER`). Detalle en `docs/spike_15_cimientos_design_system.md`.*

*Última actualización anterior: Spike 14 — Reinicio de sesión y teardown (cerrado y validado en partida real). `SessionReset` + `EntityLifecycle` (`core/session/`), invocados por `SceneOrchestrator` al entrar en `MENU` tras liberar GameOverUI, CombatHud, CombatScene y ExplorationScene; `Economy.reset_session()`; `PartyManager._unregister_from_systems()` delega en `EntityLifecycle`; `GameOverViewModel` + View sin acceso a sistemas core, botón único hacia el menú principal y textos localizados (`GAMEOVER_*` en `menus.csv`). Corrige la afirmación de que pasar por `MENU` limpiaba al jugador. Detalle en `docs/spike_14_reinicio_sesion.md`.*

*Última actualización: Spike 13 — Reautoría del pueblo de "Los Telmori" sobre el motor de escenas interactivas (cerrado, jugado de principio a fin; validación parcial anotada en la sección propia). El pueblo pasa a ser un hub declarativo (`data/interactive_scenes/telmori_village.json`: 11 hotspots en 4 posiciones, exclusivos por flags según la etapa) sobre una ilustración, con iconos `UIButton` de solo icono. Cambios de motor y de contrato: `VICTORY → NARRATIVE_SCENE` en `VALID_STATE_TRANSITIONS`; `start_combat(..., victory_scene_id)` + `NarrativeSceneOutcome.combat_victory_scene_id` (al ganar se abre una escena narrativa; si no existe, vuelve a `EXPLORATION`); `NarrativeSceneOutcome.take_item_*`; `InteractiveSceneDefinition.on_first_visit` + `request_first_visit()`; `AdventureStarter` + `data/adventures/telmori.json` (kit y companions una sola vez; elimina el kit duplicado); `UIButton.min_square`/`icon_backdrop` (opt-in). Resuelve de paso dos mensajes preexistentes al huir. Decisión: `Interactable` queda vestigial (se descartan el tutorial y el test) y su camino físico nunca se validó. Hallazgos: colisión de nombres de fichero entre diálogo y escena, panel narrativo vacío con id inexistente, flags puestos al disparar en vez de al ganar. Detalle en `docs/spike_13_reautoria_pueblo_telmori.md` y `athelia_pendientes_post_pivote_narrativo.md` (punto 10). Godot 4.7.2.*
 
*Última actualización anterior: Spike 12 — Motor de escenas interactivas / mapa de puntos de interés (cerrado y validado en partida real con `poi_test_map`: `dialogue`, `shop`, `narrative_scene`, `combat` con `enemy_definitions`, visibilidad por `required_flags`/`blocked_flags`, guardado y carga sin nodo `Player`). Nuevo sistema `core/interactive_scenes/` (`InteractiveSceneDefinition`, `InteractiveHotspotDefinition`, autoload `InteractiveSceneDB`), `ui/interactive_scene/` (ViewModel + View) y `scenes/exploration/interactive_map/` (escena raíz de exploración sin `Player`). `ExplorationController.request_interaction()` pasa a ser el único punto de routing de interacciones (el camino de `Interactable` delega en él); `SaveSystem._collect_player_state()` ya no exige nodo `Player`. `SCENE_EXPLORATION` apunta al mapa de PRUEBA (línea del pueblo comentada, revertible). Fase 0 corrigió cuatro supuestos de la documentación: `Interactable` estaba vivo pero solo con `narrative_scene` creado por código; su `@export_enum` no lista `narrative_scene`; el nombre del nodo raíz de exploración lo fuerza el orquestador; y `TelmoriVillage._ready()` hace inicialización de partida (companion, equipo). Sin verificar en partida: el camino físico de `Interactable` tras el refactor del controlador. Pendiente para el Spike 13: inicialización de partida fuera de la escena, los 3 spawns del pueblo → hotspots declarativos, un flag de victoria de la emboscada, arte/`UIButton`/localización real. Ver `docs/spike_12_motor_mapa_poi.md` para el detalle completo. Godot 4.7.2.*
 
*Última actualización anterior: Spike 11 — Rediseño de la ventana de diálogo (fondo, retrato, estado de ánimo) — cerrado y validado en partida real de principio a fin, apertura desde escena narrativa y desde `EXPLORATION`. `DialogueNodeDefinition` gana `mood`; `DialogueDefinition` gana `portrait_folder` y `background_id`; `EventBus.dialogue_node_shown` pasa de 4 a 7 argumentos. `DialoguePanel` migra de `PanelContainer` plano a `UIPanel` (marco del Spike 9) — cierra el pendiente que dejó abierto ese spike para esta pantalla. Antipatrón nuevo: un `PanelContainer` no se encoge por debajo del mínimo de sus hijos, así que las opciones de diálogo necesitan `ScrollContainer` si su número puede variar — mismo problema de fondo que "Panel sin tamaño fijo con texto largo", por número de hijos en vez de longitud de texto. Ver `spike_11_ventana_dialogo.md` para el detalle técnico completo (maqueta de layout, catálogo de estados de ánimo, cascadas de respaldo). Godot 4.7.2.*
 
*Última actualización anterior: Spike 10 — Diálogos restantes del sheriff (cerrado, camino A, validado en partida real). `telmori_sheriff_reward_intro` y `telmori_sheriff_training` abren `DLG_TELMORI_SHERIFF_REWARD`/`_TRAINING` como sub-overlay con las entregas en el mismo outcome (el diálogo solo conversa; `DialogueOptionDefinition`/`DialogueSystem` no tienen entregas y no se ampliaron); Grupo 2 completo. Dos fallos de motor previos destapados por la validación: `grant_item_*` se había perdido de `NarrativeSceneViewModel._apply_outcome()` (ningún ítem llegaba al inventario, sin error visible) y un libro no podía enseñar una skill fuera del kit inicial, consumiéndose sin efecto — nuevo `SkillSystem.learn_skill()`, `initial_value` en `learning_data`, `load_save_state()` que recrea skills aprendidas y consumo del libro condicionado a que el aprendizaje se aplique. Localización completada (escenas del Grupo D, escena de botín, flechas/lanza de Grupo B) y alta de `items_telmori.csv`. Sin probar en partida: camino de fallo del libro y guardado/carga con Curtido. Ver `docs/spike_10_dialogos_sheriff.md`. Godot 4.7.2.*
 
*Última actualización anterior: Spike 9 — Marco decorativo de ventana en `UIPanel` (Design System). `decorative_frame` (false por defecto) + `corner_texture`: doble filete dibujado con `_draw()` sobre el propio panel (un `StyleBoxFlat` solo admite un borde de un color) y una única esquinera rotada 0°/90°/180°/270° con `draw_set_transform()`. Con el marco activo el panel anula su borde y `corner_radius`. Siete tokens nuevos en `UITokens` (`COLOR_FRAME_*`, `FRAME_*`) y arte en `ui/design_system/assets/frames/` (64×64 en uso; 96×96 de reserva por invadir el texto). Respuestas a las dos preguntas de integración de la spec: opt-in (ningún panel en producción cambia de aspecto) y `NarrativeScenePanel` ya usaba `UIPanel`, así que se activó solo desde el inspector, sin tocar su script. Validado: panel narrativo con marco correcto en las 4 esquinas; ventana de inventario sin cambios. Ver `docs/spike_9_marco_decorativo_ui_panel.md`. Godot 4.7.2.*
 
*Última actualización anterior: Spike 8 — UI/UX de combate (cinco puntos de alcance
cerrados y validados en combate real contra un grupo de 6-8 lobos). Punto 1
(ficha de `companion_mira` con `??`) y Punto 2 (log con IDs internos en vez
de nombres localizados) resultaron compartir exactamente la misma causa,
confirmada por código antes de tratarlos como un único arreglo:
`_initials_for()`/`_display_name()` en `combat_arena_viewmodel.gd` solo
leían `CharacterState.character_name` (vacío para toda entidad no-jugador
por diseño) sin caer a `tr(CharacterDefinition.name_key)` como fallback —
arreglado con esa jerarquía de resolución (nombre elegido > nombre fijo de
definición). Punto 3 (los 8 botones del menú de acciones nunca mostraban
nombre) resultó no ser un bug de código: `combat_hud_viewmodel.gd`/
`combat_arena_panel.gd` leían fielmente un `LoadoutState` del jugador que
nunca había sido asignado — confirmado con capturas de la propia pantalla
de Loadout mostrando los 8 slots vacíos. De paso, un doble-`tr()` real (sin
efecto visible) en `loadout_viewmodel.gd`. Punto 4 (columna de enemigos
desbordada con 6-8 fichas): un primer intento de redimensionar
`UICombatToken` directamente resultó incorrecto (su anclaje interno usa
píxeles fijos calculados para 96×144 — confirmado en playtest por iconos
descolocados) y se sustituyó por el patrón correcto de Control envoltorio +
`.scale`, sin tocar el tamaño real del token. Punto 5, no listado en el spec
original y añadido durante la sesión al bloquear la validación del Punto 4:
"No target specified" al atacar — causa real, `combat_arena_panel.gd`
duplicaba (incompleto, sin `"target"`) el despacho que
`PlayerCombatController.request_skill()` ya resolvía bien; arreglado
delegando en él. Expuso un segundo hallazgo encadenado: el auto-target de
`PlayerCombatController` se perdía visualmente por orden de señales entre
nodos distintos, corregido sincronizando el objetivo directamente en
`CombatArenaViewModel._on_combat_started()`. Dos antipatrones nuevos de
arquitectura UI documentados en `athelia_ui_architecture.md`. Ver
`docs/spike_8_ui_ux_combate.md` para el detalle completo. Godot 4.7.2.
 
*Última actualización anterior: Spike 7 — F9 quickload en EXPLORATION (cerrado sin
arreglo, funcionalidad NO OPERATIVA). El síntoma original documentado (bloqueo
total de input) no se reprodujo tras el pivote narrativo — resultó ser un bug
distinto: F9 en sesión activa cargaba los datos del save pero no consumía
`SaveManager.get_pending_narrative_scene_id()`, dejando al jugador en
`EXPLORATION` en vez de en el punto narrativo correcto. Arreglado
centralizando la decisión en `GameLoopSystem.enter_post_load_state()`, usado
tanto por `MainMenuViewModel.request_load_game()` como por
`ExplorationController._quickload()`. Ese arreglo destapó un segundo bug que
quedó sin resolver: el panel narrativo correcto se abre pero su botón no
responde a clics, únicamente cuando la carga ocurre en sesión activa tras
combate (nunca desde el menú principal). Investigación extensa sin causa raíz
encontrada — descartados GameState, árbol pausado, ratón capturado,
`mouse_filter`/`focus_mode`, nodos residuales de UI, `mouse_passthrough`, y
cualquier autoload con `_input()`/`_unhandled_input()` (ninguno lo tiene).
Hallazgo real y confirmado de camino (ver "Lecciones aprendidas" más abajo):
`ExplorationScene` y sus overlays viven como hermanos de `current_scene` bajo
`get_tree().root`, invisibles a `get_tree().reload_current_scene()` —
corregido liberándolos explícitamente antes de recargar, pero el bug de fondo
persistió incluso así. `_quickload()` se reenfocó por completo: ya no carga en
caliente, marca la intención en `SaveManager` (`request_pending_quickload()`)
y recarga la escena; `MainMenuViewModel._ready()` consume ese flag
(`consume_pending_quickload()`) y dispara la carga real por el único camino
que funciona de forma fiable. **Decisión: F9/quickload en sesión activa queda
no operativo**, pendiente decidir si se retira la hotkey; "Cargar Partida"
desde el menú no está afectada. Hallazgo colateral, no relacionado:
`PartyManager` no limpia su lista de companions al cargar partida (warning
`'companion_mira' already in party`, reproducido también desde el menú). Ver
`docs/spike_7_f9_quickload_exploration.md` para el detalle completo. Godot
4.7.2.
 
*Última actualización anterior: Spike 6 — Investigación de motor de combate (los dos
puntos de alcance investigados y cerrados, sin necesidad de spike aparte para
ninguno). Punto 1: dos bugs independientes bajo el mismo síntoma (número
mostrado ≠ número real). Sub-bug A, el desync `50/60`/`50/45` original —
causa raíz: `ModifierApplicator` solo sincroniza `max_effective` como efecto
de `Characters.set_base_attribute()`, y el único caller de eso en todo el
proyecto era `character_creation_viewmodel.gd` para `"player"` — enemigos,
refuerzos y companions se registran vía `register_entity()` directo, sin
pasar nunca por ahí. El "50" del patrón reportado era además literal:
`exploration_controller.gd`/`narrative_scene_viewmodel.gd` fijaban el HP
inicial de cada enemigo a `50.0` hardcodeado. Arreglado sincronizando dentro
de `ResourceSystem.register_entity()` mismo (Opción B, elegida sobre arreglar
cada punto de registro por separado — 4 call sites confirmados, 3 de ellos
bugueados, 2 con código duplicado línea por línea — para cerrar el gap de
raíz en vez de depender de que cada spawner futuro se acuerde), con guard
defensivo y orden de registro corregido en `combat_production_scene.gd`
(refuerzos). Sub-bug B, hallazgo ampliado del cierre de Spike 5 en
`player_menu` — sin relación con el sub-bug A: `player_menu_viewmodel.gd`
leía el HP/EN actual desde `CharacterState.get_resource()`, un accesor
fósil congelado desde la creación del personaje (mismo patrón que
`skill_values` vs. `SkillSystem._entity_skills` de Spike 3/Grupo B), en vez
del estado vivo de `ResourceSystem`. Punto 2: `Invalid transition: ROUND_END
→ TURN_END` y rondas que saltan número — confirmado que afecta al contador
real (`round_number`, usado por refuerzos temporizados), no es cosmético.
Causa raíz: `_transition_to_phase()` no devolvía éxito/fracaso y ningún
llamador comprobaba el resultado antes de seguir — ver nota propia en
"GameLoop — Estados y fases de turno" más abajo. Disparador exacto de la
doble invocación no confirmado al 100%; candidato identificado y mitigado
con una comprobación de actor nueva en `_on_combat_action_completed()`.
Nuevo test de regresión sin necesitar combate real,
`test/test_spike6_investigacion.gd` (8/8 asserts). Validado en varias
partidas reales completas, refuerzos incluidos. Quedan sin tocar, sin
decisión de Fernando: typo `combat_scape`/`combat_escape`, puente
`resource_changed`→`EventBus.resource_changed`, fuga de memoria ya
mitigada, `combat_resolver.gd` código muerto sospechoso (los 4 hallazgos de
motor de Grupo 5 restantes). Ver `docs/spike_6_investigacion_motor_combate.md`
para el detalle completo. Godot 4.7.2.
 
*Última actualización anterior: Spike 5 — Arreglos rápidos de motor. Cinco bugs de
motor preexistentes cerrados, documentados como pendientes desde el
Grupo 5 de mejoras post-Spike 3, sin dependencias cruzadas entre sí.
Typo `combat_escape`→`combat_scape` corregido en `combat_hud.gd` (consenso
de dos consumidores + documentación). Puente
`ResourceSystem.resource_changed` → `EventBus.resource_changed` añadido en
`_emit_resource_changed()`: Find in Files confirmó dos consumidores reales
(`combat_hub_viewmodel.gd`, `player_menu_viewmodel.gd`), no uno, así que el
mecanismo elegido fue el reenvío centralizado en el punto de emisión y no
la reconexión de un único consumidor. `telmori_lair_loot_obsidian.json.json`
renombrado sin referencias que actualizar.
`CharacterDefinition.duplicate_definition()` gana los cuatro campos que le
faltaban (`token_color`, `type_icon`, `starting_skill_values`,
`loot_table_id`), sin efecto observable todavía (sin llamada real en el
proyecto). `combat_resolver.gd` eliminado — código muerto confirmado dos
veces (Grupo 5 y de nuevo en este spike), sin ningún fichero activo que lo
referenciara. Hallazgo no anticipado, movido a Spike 6/7: desync
PV/EN confirmado en pantalla real en `player_menu` (ya listado como fuera
de alcance de este spike). Validado jugando la aventura completa de "Los
Telmori" de principio a fin, sin errores ni warnings nuevos. Ver
`docs/spike_5_arreglos_motor_informe_cierre.md` para el detalle completo.
Godot 4.7.2.
 
*Última actualización anterior: Mejoras post-Spike 3, Grupo 4 — Arte narrativo. Layout narrativo B1 (imagen a pantalla completa, panel en el tercio inferior; solo `.tscn`, el `SceneImage` original con `expand_mode` por defecto habría reventado el panel con cualquier imagen real). Fondo de combate por encuentro (`CombatEncounterDefinition.background_path`, `GameLoopSystem.get_current_encounter()`, `CombatArenaViewModel.background_texture`), con mapas de batalla cenitales en vez de reutilizar las láminas de escena; velo de la arena a 0.2 y contorno de texto en fichas y log (tokens nuevos en `UITokens`). `image_path` validado al cargar. Bug preexistente corregido: fichas enemigas sin `fill_color` (blancas) y centinela `Color.BLACK` de `token_color` ignorado. Iconos de tipo reales para todas las variantes Telmori y `wolf_gray`. Cuatro hallazgos preexistentes documentados sin corregir (botones de acción sin nombre, desborde de la columna enemiga, IDs sin localizar en el log, desajuste PV). Spike de marco decorativo de `UIPanel` aparcado. Validado en partida completa de "Los Telmori". Ver `docs/mejoras_grupo4_arte_narrativo_informe_cierre.md` para el detalle completo. Godot 4.7.2.
 
*Última actualización anterior: Mejoras post-Spike 3, Grupo 1 — Guardado de partida. Corrige un supuesto erróneo de la documentación anterior: `SaveManager` ya guardaba flags/variables/eventos/checkpoints/party antes de este grupo; el hueco real era solo "a qué escena narrativa volver al cargar". Guardar deja de ser hotkey libre (F5, retirado) — solo se guarda vía opción de diálogo (`DialogueOptionDefinition.triggers_save`, nuevo) ofrecida por NPCs savepoint concretos dentro de una escena narrativa; F9 (cargar) sin cambios. `SaveData.narrative_state` gana `current_narrative_scene_id`, `SAVE_VERSION` 5→6 con migración; `MainMenuViewModel.request_load_game()` decide `enter_narrative_scene()` vs `enter_exploration()` según `SaveManager.get_pending_narrative_scene_id()`. Dos hallazgos no anticipados por el spec, ambos corregidos: `MENU → NARRATIVE_SCENE` no existía en `VALID_STATE_TRANSITIONS` (fallaba en silencio, solo `push_warning()`); y `ExplorationScene` podía no estar instanciada todavía cuando un combate terminaba tras cargar directo en `NARRATIVE_SCENE`, perdiendo listeners de continuación de contenido (ej. "Rastros" tras la emboscada) — corregido con `SceneOrchestrator._ensure_exploration_scene_instantiated()`, lo que a su vez expuso una trampa de reentrada en `TelmoriVillage._ready()` (guard de estado demasiado laxo, corregido a `== MENU`). Nuevo atajo de desarrollo configurable (tecla F2, `user://debug_shortcut.json`), detrás de `OS.is_debug_build()`. Validado en partida real completa de "Los Telmori", de principio a fin, incluido el combate final de la guarida. Ver `docs/mejoras_grupo1_guardado_informe_cierre.md` para el detalle completo. Godot 4.7.2.
 
*Última actualización anterior: Mejoras post-Spike 3, Grupo 5 — Pantalla de combate de producción. Sustituye la pantalla de test (`combat_test_scene`/`combat_hud.tscn`) por una real: `UIRadialGauge`/`UICombatToken` (Design System), `CombatArenaViewModel` (compone a `CombatHudViewModel` existente, primer caso de composición de ViewModels del proyecto) + `CombatTokenData`/`LogEntryData`, `CombatArenaPanel` (fichas dinámicas party/enemigo, log narrado, menú de 8 acciones), `combat_production_scene.gd` (nueva pieza sin UI que sustituye a `combat_test_scene.gd` como `SceneOrchestrator.SCENE_COMBAT`). Varios bugs de motor preexistentes encontrados, algunos corregidos (payload de dodge sin `actor`, posición de damage number para fichas `Control`, Skills nunca registrado para el roster inicial de enemigos) y otros solo documentados (puente roto `ResourceSystem.resource_changed`→`EventBus`, typo `combat_escape`/`combat_scape`, fuga de la instancia de `SCENE_COMBAT` en `SceneOrchestrator`, desconexión `AttributeResolver`/`ResourceState.max_effective`). Validado jugando la aventura completa de "Los Telmori" de principio a fin, refuerzos reales incluidos. Ver `docs/mejoras_grupo5_combate_produccion_informe_cierre.md` para el detalle completo. Godot 4.7.2.
 
*Última actualización anterior: Mejoras post-Spike 3, Grupo 2 — Diálogo con NPCs desde narrativa. `NarrativeSceneOutcome` gana `dialogue_id`, resuelto como sub-overlay de `DialoguePanel` (mismo patrón de Grupo 3, ahora extendido a Diálogo) con reenganche automático vía `resume_after_dialogue()` reutilizando `next_scene_id` con significado condicional. Hallazgo crítico corregido: `SceneOrchestrator._on_dialogue_ended()` forzaba `enter_exploration()` de forma incondicional vía señal global, lo que habría roto cualquier escena narrativa con un diálogo abierto como sub-overlay — ahora gateado a `GameState.DIALOGUE`. Bug de motor preexistente encontrado y corregido: `DialogueRegistry` no escaneaba subcarpetas, a diferencia de `SkillSystem`/`ItemRegistry`. Validado en partida real contra `sheriff_briefing` de "Los Telmori". Ver `docs/mejoras_grupo2_dialogo_narrativa_informe_cierre.md` para el detalle completo. Godot 4.7.2.
 
*Última actualización anterior: Mejoras post-Spike 3, Grupo 3 — Overlays de inventario/party/stats durante narrativa. `NarrativeScenePanel` gestiona Inventory/Party/PlayerMenu como sub-overlay propio (hijo directo, nunca vía `SceneOrchestrator`), evitando así el slot único de `SceneOrchestrator._current_overlay` (hallazgo no anticipado por el spec: abrirlos por el camino normal habría destruido el panel narrativo y su ViewModel). `NarrativeSceneViewModel` gana tres intenciones nuevas sin tocar `current_node` ni la racha en curso. Dos bugs de motor preexistentes encontrados y corregidos en la validación, ninguno introducido por este grupo: cuatro pantallas (`InventoryUI`/`PlayerMenuScreen`/`LoadoutScreen`/`SkillTreeScreen`) no se auto-liberaban al cerrarse, dejando `tree_exiting` sin disparar nunca y la navegación anidada colgada sin vuelta atrás — arreglado con una señal `closed` explícita en las cuatro; y `ExplorationHUD._unhandled_input()` no respetaba `GameLoop.is_input_blocked()`, a diferencia de `ExplorationController`. Ver `docs/mejoras_grupo3_overlays_narrativa_informe_cierre.md` para el detalle completo. Godot 4.7.2.
 
*Última actualización anterior: Spike 3, Grupo D — Cierre (los cinco puntos de alcance cerrados y validados en partida completa) — recompensa multicapa (bounty, trofeo, venta de pieles con Curtidor real sin gating de visibilidad nuevo); nuevo campo "otorgar recurso" en `NarrativeSceneOutcome`/`_apply_outcome()`, análogo a "otorgar ítem"; botín mágico de la guarida entregado vía el mecanismo de otorgar ítem ya existente; reflavor del entrenamiento de magia como tomo de habilidad; nuevo patrón de reconexión narrativa sin combate de por medio, con su propio riesgo de exploit económico identificado y cubierto por diseño. **Con este grupo, "Los Telmori" es jugable de principio a fin.** Dos bugs reales encontrados y corregidos en la validación: declaración de propiedad perdida en un patch de `NarrativeSceneOutcome` (runtime error, no de compilación), y un JSON de contenido desactualizado en el proyecto tras diseñar la cadena de botín en conversación (detectado por el `scene_id` de `narrative_scene_closed` en el log). Ver `docs/spike_3_grupoD_cierre_informe_cierre.md` para el detalle completo. Godot 4.7.2.
 
*Última actualización anterior: Spike 3, Grupo C — La guarida (los cinco puntos de alcance cerrados y validados en partida completa, ambas ramas) — fusión de las dos salas de la aventura original en un combate por rama en vez de rutas separadas; `group_aggregate="worst"` para la tirada de sigilo, confirmado por la propia transcripción; nueva skill `skill.exploration.stealth`; modificador multiplicativo de combate decidido explícitamente no implementarlo; `EnemyWorldLink` confirmado innecesario en esta aventura. Cuatro bugs de motor preexistentes encontrados y corregidos, todos en la reconexión narrativa tras combate: encadenado suelto en el cierre de Grupo B, ausencia de reconexión tras el segundo combate del proyecto, listener de `combat_ended` que nunca se desconectaba y resucitaba interactuables retirados, y limpieza enganchada a una señal que no se emite cuando una escena encadena internamente a otra. Ver `docs/spike_3_grupoC_guarida_informe_cierre.md` para el detalle completo. Godot 4.7.2.
 
*Última actualización anterior: Spike 3, Grupo B — Del pueblo a la puerta de la guarida (los cinco puntos de alcance cerrados y validados en partida completa) — otorgar-ítem y combate opcional en `NarrativeSceneOutcome`; sorpresa de combate vía buffs existentes sin tocar turn_order; investigación por capas y rastreo acumulativo sobre contenido real; nuevo `interaction_type` "narrative_scene"; primera escena de exploración de producción real (`exploration_telmori_village`); varios bugs de motor preexistentes encontrados y corregidos (cuelgues de turno en STAGGERED/DISARMED, registro de enemigos en combate narrativo, reinicio tras Game Over, panel narrativo sin tamaño fijo, doble sistema de skills desincronizado). Ver `docs/spike_3_grupoB_pueblo_guarida_informe_cierre.md` para el detalle completo. Godot 4.7.2.
 
*Última actualización anterior: Spike 3, Grupo A — Motor y limpieza (los tres puntos del alcance cerrados y validados) — moral de grupo con base dinámica (`_group_morale_base_hp`, recalculada al llegar un refuerzo, nunca golpe a golpe, validada contra los dos ejemplos numéricos de la spec en `test/test_group_morale.gd`); nuevo autoload `EnemyWorldLink` como hueco genérico de limpieza para enemigos que huyen; retirada completa del andamiaje de Spike 1 (tecla F1, JSON de prueba, claves de localización de test) con su hueco de test cubierto en `test/test_narrative_scene_viewmodel.gd` (fixtures en código, sin JSON ni registry). Un hallazgo de GDScript nuevo: un enum anidado en otra clase no se puede anotar como tipo explícito de forma fiable, y un fallo de compilación (o una sobrescritura accidental) en el script dueño de un `class_name` se manifiesta como "Identifier not declared" en cualquier fichero que lo consuma, no en el fichero real con el problema. Ver `docs/spike_3_grupoA_motor_limpieza_informe_cierre.md` para el detalle completo. Godot 4.7.2.
 
*Última actualización anterior: Spike 2 — Reglas de RuneQuest para el Motor Narrativo (seis de seis puntos del alcance cerrados y validados) — `SkillRoller.RollResult` a 5 grados con `CRITICAL`/`SPECIAL` dinámicos (skill/20, skill/5); progresión de skill narrativa vía `SourceType.NARRATIVE`; tiradas acumulativas con contador de racha en el ViewModel; tiradas agregadas de grupo sin tabla de resistencia (oposición codificada en `roll_modifier`); moral de grupo y refuerzos cronometrados en combate vía `CombatEncounterDefinition` (nuevo, opcional en `start_combat()`) y `GameLoopSystem.configure_active_encounter()`. Modificador dinámico multiplicativo de combate aplazado a Spike 3 por falta de caso real. Dos hallazgos de GDScript reutilizables: un `match` sin rama `_:` y un array indexado por enum no avisan si el enum crece sin revisar todos sus consumidores. Ver `docs/spike_2_reglas_runequest_informe_cierre.md` para el detalle completo.
 
*Última actualización anterior: Spike 1 Motor Narrativo (pivote hacia RPG narrativo) — nuevo sistema `core/narrative_scenes/` + `ui/narrative_scene/` (patrón MVVM, sin system runtime propio, solo registry síncrono), `GameState.NARRATIVE_SCENE` añadido a GameLoop con integración de combate y cierre desacoplado vía EventBus, escena de prueba desechable y tecla de debug F1 temporal en ExplorationController. Dos lecciones de GDScript registradas (self-reference por class_name, colisión de SceneState con clase nativa) y una de testing (nodo raíz "ExplorationScene" requerido para ejecutar exploration_test.tscn suelto). Spike Producción Post-Character-Creation (Grupo A) — escena de exploración de producción (`exploration_tutorial.tscn`), registro en frío de Resources/Skills en `load_game()`, nombre de personaje visible en PlayerMenuScreen. Pendientes abiertos: posición no restaurada en arranque en frío, bloqueo de input tras F9 en caliente, limpieza de `player.gd` aparcada. Godot 4.7.1.*