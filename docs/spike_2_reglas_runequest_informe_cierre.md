# Spike 2 — Reglas de RuneQuest para el Motor Narrativo — Informe de Cierre

*Athelia — Pivote hacia RPG narrativo*

---

## Contexto

El Spike 1 dejó validado el motor narrativo base (grafo de escenas, integración
con `SkillRoller`, disparo de combate, flags), con seis piezas de reglas de
RuneQuest identificadas pero diferidas explícitamente. Este spike las
implementa y valida todas, una por una, en el orden de riesgo que marcaba el
propio documento de spec: primero el cambio de mayor riesgo de regresión
(grado especial en combate), luego el resto de piezas puramente narrativas o
de combate según su dependencia entre sí.

**Alcance cerrado al 100%: las seis piezas están implementadas y validadas.**
No se ha tocado contenido real de "Los Telmori" — eso sigue siendo Spike 3.

---

## Punto 1 — Grado de resultado "especial"

`SkillRoller.RollResult` pasa de 4 a 5 grados: `FUMBLE / FAILURE / SUCCESS /
SPECIAL / CRITICAL`.

**Decisiones tomadas:**
- **CRITICAL y SPECIAL dinámicos** (`skill_value / 20` y `skill_value / 5`,
  fórmulas RuneQuest clásicas), no solo SPECIAL. Se evaluó mantener CRITICAL
  fijo (opción de menor alcance) pero el coste de hacer también CRITICAL
  dinámico resultó bajo y elimina de raíz un caso límite de bandas invertidas
  a skill bajo que la opción fija sí habría necesitado resolver con un guard
  adicional. FUMBLE se queda absoluto (≥98), fuera de alcance de este spike.
- **SPECIAL cuenta como `"success"`** en `SkillProgression` — mismo bucket que
  éxito normal, sin tick ni progresión diferenciada por grado.
- **En combate, SPECIAL aplica un multiplicador de daño propio (x1.2)**,
  menor que el x2 de crítico, configurable por skill vía `special_multiplier`
  en el effect — mismo patrón que `critical_multiplier`.

**Hallazgo crítico durante la implementación:** `SkillRoller._is_success()`
solo incluía `[SUCCESS, CRITICAL]` en su lista de resultados exitosos. Sin
corregirlo, una tirada `SPECIAL` se habría tratado como **fallo** en combate
(sin daño, sin animación) — el bug más grave posible al añadir el grado,
descubierto solo al rastrear qué determinaba `roll_result.success` en
`CombatSystem`, no visible con una lectura superficial del enum.

**Ficheros:** `skill_roller.gd`, `combat_system.gd`.

---

## Punto 2 — Progresión de skill narrativa

Enganchado vía `SkillProgression.execute_learning_session()` (no
`notify_skill_outcome()`, hard-gated a `_combat_active`).

**Decisiones tomadas:**
- `SourceType.NARRATIVE` explícito, no reutilización de `PRACTICE` —
  trazabilidad futura de qué skills se aprendieron jugando vs. entrenando.
- `NarrativeSceneOption.challenge_level: int = 0` — opt-in explícito del autor
  de la escena. `0` = sin progresión para esa opción (no toda tirada narrativa
  tiene por qué ofrecer mejora). Solo si es `> 0`, y solo en tiradas exitosas,
  se intenta la mejora — misma filosofía que combate (solo el éxito genera
  oportunidad).

**Hallazgo durante la implementación:** `LearningSession._to_string()` tenía
un array `type_names` de tamaño 3 indexado directamente por el enum — añadir
`NARRATIVE` sin ampliarlo habría producido un acceso fuera de rango en
cualquier `print()` de una sesión narrativa.

**Ficheros:** `learning_session.gd`, `narrative_scene_option.gd`,
`narrative_scene_viewmodel.gd`.

---

## Punto 3 — Tiradas acumulativas/reintentables con contador

`NarrativeSceneOption.required_successes: int` (0 = sin cambios) y
`retry_policy: String` (`"immediate"` / `"blocked"`).

**Decisiones tomadas:**
- El contador de racha vive en `NarrativeSceneViewModel`
  (`_success_streaks`, `option_id → int`) — nunca en `NarrativeSceneDB`
  (sigue siendo solo consulta síncrona) ni en `NarrativeSceneOption` (se
  recarga desde JSON en cada consulta). Se reinicia solo al completar/perder
  la racha, o implícitamente al destruirse el overlay.
- **Una PIFIA siempre transiciona**, ignorando `retry_policy` — una pifia
  narrativa suele tener consecuencia dramática propia, no un simple "vuelve a
  intentarlo".
- **La progresión de skill (punto 2) solo se intenta al completar la racha
  entera**, nunca en un éxito parcial — evita una vía de grinding que el
  anti-grind de `SkillProgressionService` no está pensado para frenar (limita
  el umbral de dificultad, no la frecuencia de intentos).
- `"blocked"`: un fallo normal (no fumble) transiciona de verdad a otro nodo —
  es el propio grafo narrativo el que impide el reintento infinito, sin
  sistema de flags nuevo.

Nueva razón de `changed()`: `"streak_progress"` (el nodo no cambia; expone
`streak_option_id`/`streak_current`/`streak_required` para que la View pinte
el progreso si quiere — no se tocó `narrative_scene_panel.gd` en este spike).

**Ficheros:** `narrative_scene_option.gd`, `narrative_scene_viewmodel.gd`.

---

## Punto 4 — Tiradas opuestas agregadas de grupo

`NarrativeSceneOption.group_aggregate: String` (`""` / `"worst"` / `"best"`).

**Decisiones tomadas:**
- **Sin tabla de resistencia real** (segunda tirada del NPC, tirada opuesta
  clásica de RuneQuest) — decisión explícita por coste-beneficio. La
  "oposición" (ej. la Escucha de los lobos) se codifica en el ya existente
  `roll_modifier`, calculado por el autor de la escena al escribir el JSON,
  no por el motor a partir de un valor de NPC almacenado en datos.
- **Sin cambios en `Party`**: `_get_group_entity_ids()` en el ViewModel
  combina `GameLoop.PLAYER_ID + Party.get_active_members()` y reduce a
  peor/mejor localmente — cero necesidad de un método de agregación nuevo en
  `PartyManager`.
- **Progresión de skill (punto 2) independiente por miembro**: si la opción
  tiene `challenge_level > 0`, cada miembro del grupo (jugador + companions
  activos) intenta su propia `LearningSession` contra su propio valor de
  skill — nunca un resultado de progresión compartido. Justificación: no hay
  ningún concepto de "resultado compartido" en `SkillProgressionService` (cada
  sesión se resuelve contra el estado individual de esa entidad), así que
  compartir un resultado habría exigido inventar un mecanismo nuevo sin
  ninguna necesidad real.

**Ficheros:** `narrative_scene_option.gd`, `narrative_scene_viewmodel.gd`.

---

## Punto 5 — Modificadores dinámicos de escena/encuentro

**Cerrado sin código.** En narrativa, el campo `roll_modifier` (existente
desde Spike 1) ya cumple exactamente esta función: se suma solo dentro de la
tirada puntual, nunca toca `Characters`/`SkillInstance`, y desaparece al salir
de la escena. Los ejemplos del spec ("-85% a Buscar", "-20% a Sigilo por
terreno") son números que el autor de la aventura ya conoce al escribir esa
opción — no dependen de una condición evaluada en tiempo de ejecución que el
proyecto no tiene (no hay ciclo día/noche ni sistema de clima).

En combate, el caso "mitad de puntería en oscuridad" (multiplicativo) no
tiene hoy un buff equivalente — los buffs existentes (`precision_up`,
`weakened`, etc.) son aditivos — pero se aplaza a Spike 3, cuando haya un
encuentro real que lo necesite, en vez de construir un mecanismo genérico sin
caso de uso que valide su forma.

---

## Punto 6 — Moral y refuerzos cronometrados en combate

Fichero nuevo `core/combat/combat_encounter_definition.gd` (Resource),
parámetro **opcional** en `GameLoopSystem.start_combat(enemy_ids, encounter =
null)` — sin él, cero cambios de comportamiento respecto a antes de Spike 2.

**Decisiones tomadas:**
- **Moral de grupo, no individual**: todos los enemigos supervivientes huyen
  a la vez cuando el HP total restante del grupo cae a `morale_threshold_pct`
  % o menos del HP total inicial — capturado una vez al iniciar combate. Se
  descartó el modelo individual (cada enemigo decide por su propio HP) porque
  no encajaba narrativamente con una manada huyendo junta, y habría vivido en
  `CharacterDefinition` con el riesgo de mutación compartida entre todas las
  instancias de ese `.tres` si alguna vez se quisiera modificar en caliente
  (ver nota de intimidación más abajo).
- La huida reutiliza el mecanismo de "enemigo fuera de combate"
  (`participants.erase`/`turn_order.erase`) pero por una señal nueva
  (`enemy_group_fled`), nunca `character_died` — no dispara loot ni animación
  de muerte. Al llamarse desde el principio de `_check_combat_conditions()`,
  si huyen todos los enemigos restantes, el chequeo de victoria que ya existía
  lo detecta gratis, sin lógica de encadenamiento nueva.
- **Refuerzos genéricos, no específicos de "Los Telmori"**: `reinforcement_trigger`
  vacío = contador inmediato desde el inicio del combate; con un nombre, no
  arranca hasta que algo llame a `GameLoop.trigger_combat_event(nombre)` —
  cualquier sistema puede dispararlo sin acoplar este recurso a ningún evento
  concreto de una aventura.
- El spawn de un refuerzo reutiliza el camino exacto de
  `CombatTestScene._initialize_enemy()` (ya existente para los enemigos
  iniciales) — no se duplicó lógica de registro en
  `Characters`/`Resources`/`Skills` ni de instanciación de
  `EnemyCombatNode`.
- Se añadió `configure_active_encounter()` en `GameLoopSystem` — permite
  adjuntar un `CombatEncounterDefinition` a un combate **ya en marcha**.
  Necesario porque `ExplorationController` arranca combate llamando a
  `start_combat()` sin pasar ningún encuentro (no se tocó ese fichero en este
  spike), así que fue la única forma de validar moral/refuerzos en el camino
  real de juego sin editarlo a ciegas.

**Simplificación explícita, anotada en el propio recurso:** la moral de
grupo se calcula solo sobre el HP total del grupo **original** de enemigos —
los refuerzos que lleguen no se suman a esa base. No hay un encuentro real
todavía que diga si un refuerzo debería "diluir" la moral original o no.

**Límite conocido, fuera de alcance:** un enemigo que huye desaparece de la
contabilidad de combate pero no de la capa de exploración/world objects — su
representación en el mundo probablemente sigue ahí tras el combate. Qué le
pasa a un enemigo que sobrevivió huyendo (desaparece, se reubica, puede
volver a atacar más tarde) es una decisión de contenido, no técnica, que
queda para cuando Spike 3 la necesite.

**Nota aparcada para el futuro:** la intimidación como debuff de moral
individual (mencionada durante el diseño, no implementada) encajaría en el
sistema de buffs de combate ya existente (`_active_buffs` / `apply_buff()` /
`has_buff()`), nunca en `CharacterDefinition` — escribir ahí mutaría a *todas*
las entidades que comparten ese mismo `.tres` en memoria, no solo a la
entidad intimidada.

**Ficheros:** `combat_encounter_definition.gd` (nuevo), `game_loop_system.gd`,
`event_bus.gd`, `combat_test_scene.gd`.

---

## Validación realizada

Todos los puntos se validaron en el proyecto real (combate y narrativa vía
Output), no solo en aislado:

- **Punto 1**: simulación estadística (`SkillRoller.print_simulation`) +
  combate real con `crit`/`special` distinguibles en el log de daño +
  narrativa con los cinco grados observados, incluido el caso límite
  `SPECIAL` sin `outcome_special` definido cayendo a `outcome_success` por
  fallback.
- **Punto 2**: progresión narrativa confirmada como independiente del flag
  `_combat_active`, gateada en éxito, con `LearningSession(source=NARRATIVE)`
  visible en el log.
- **Punto 3**: racha completa, racha rota y reiniciada, `"blocked"`
  transicionando sin reintento, y pifia cortando la racha en cualquier punto
  — los cuatro casos confirmados con tiradas reales.
- **Punto 4**: agregación `"worst"`/`"best"` confirmada con y sin companion en
  el grupo, incapacitación excluida del cálculo, y progresión múltiple
  (una `LearningSession` independiente por miembro) verificada en el mismo
  éxito.
- **Punto 5**: sin validación de código (no se implementó nada).
- **Punto 6**: refuerzo llegando en la ronda programada con barra de HP nueva
  sin destruir las existentes, y huida de grupo disparándose exactamente en
  el umbral (caso límite `40.0% ≤ 40%` confirmado), encadenando a victoria
  automática sin loot para los que huyeron.

Cero warnings, tipado estricto mantenido en todo el spike.

---

## Lecciones de GDScript (para `docs/` general, no solo este spike)

- Un `match` sin rama `_:` no falla de forma ruidosa cuando le falta un caso
  — cae al código después del `match` (o, si es la última expresión de la
  función, `null`/tipo por defecto). Cualquier enum al que se le añada un
  valor nuevo exige repasar **todos** los `match`/listas de pertenencia que
  lo consumen, no solo los que "parecen" relevantes — el caso de
  `_is_success()` en este spike no se encontró leyendo el enum, se encontró
  rastreando de dónde salía un booleano.
- Un array indexado directamente por el valor entero de un enum (`type_names[enum_value]`)
  se sale de rango en silencio (error en tiempo de ejecución, no de
  compilación) si el enum crece y el array no. Mismo patrón de riesgo que el
  `match` sin `_:`, pero en una estructura de datos en vez de una rama de
  código.
- Escribir sobre un campo de una `Resource` cargada con `load()`/`preload()`
  (como `CharacterDefinition`) en tiempo de ejecución modifica esa instancia
  para **todas** las entidades que la usan, no solo la que se pretendía
  cambiar — datos verdaderamente dinámicos y por-entidad deben vivir en un
  sistema de estado aparte (el patrón `_state.gd` / sistema de buffs que el
  proyecto ya usa), nunca en el `_definition.gd`.

---

## Diferido a Spike 3

- Contenido real de "Los Telmori".
- Modificador dinámico multiplicativo en combate (punto 5, mitad de
  ejemplo) — solo si un encuentro real lo pide.
- Si un refuerzo debe sumarse a la base de moral del grupo original.
- Qué le pasa a un enemigo que huye en la capa de exploración/world objects.
- Extender `NarrativeSceneOutcome` con un `CombatEncounterDefinition` opcional,
  si algún día una escena narrativa necesita disparar un combate con moral o
  refuerzos ya configurados desde datos.

---

*Godot 4.7.1. Seis de seis puntos del alcance cerrados y validados.*
