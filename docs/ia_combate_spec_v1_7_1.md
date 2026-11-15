# Athelia — Especificación de IA de combate (MVP) · v1.7.1

**Estado:** Fase 0 cerrada (`docs/ia_combate_fase0.md`); decisiones de diseño tomadas el 2026-11-11; fase IA-0 en curso: IA-0a e IA-0b cerradas (2026-11-14 y 2026-11-15) · **Motor:** Godot 4.7.2

> Lo que se dice del código actual está verificado en la Fase 0. Nombres de señales, clases y campos **nuevos** siguen siendo propuestas.

## 0. Cambios

### Corrección posterior a v1.7.1 (IA-0b, cerrada y validada; decisiones 1-A, 2-A y 3-A confirmadas)

La fila j de v1.7.1 fijaba la regeneración por ronda en **0** sin acción `recover` disponible para el jugador. Con los datos actuales (estamina ≈30-45, ataque ligero a 10, combates de 12-22 rondas) eso deja al jugador sin aguante en 3-4 rondas: hoy no ocurre solo porque 5/s en tiempo real le da estamina casi ilimitada. **Corregido:** `combat_regen_per_round` de la estamina vale **10** (sostiene un ataque ligero por ronda) hasta que exista `recover` (IA-0c/IA-3); se afina en IA-5. Además: la conversión `base_cooldown` → rondas queda fijada (`int()`, una sola línea en `SkillInstance`), el interruptor de la regeneración continua es global en `ResourceSystem`, y quitar el reloj deja al descubierto que un actor de IA sin estamina cuelga el turno (los fallos de enemigos y companions no tienen gestor hasta IA-1): IA-0b añade una guarda mínima de coste. Detalle en `docs/ia_combate_ia0b_spec.md`.

### v1.7 → v1.7.1 (revisión de consistencia)

| # | Cambio | Sección |
|---|---|---|
| a | **Flexibilidad 0:** solo son elegibles las acciones de puntuación máxima; los empates se resuelven con el RNG de IA | 5.5, 12 |
| b | **`request_id`** en cada petición de acción y en todas sus respuestas; la señal de petición pasa a llamarse `combat_action_requested` | 6, 11.3 |
| c | **`last_attacker`** lo registra `Combat` por combatiente (ya no vive en `CombatAIState`); el snapshot expone el último atacante del propio actor y del protagonista; `protect` usa el del protagonista | 4, 5.3, 8 |
| d | **`action_utility`** en una escala común («PV equivalentes») que entrega `Combat`; `reference_effect` desaparece y se normaliza con `reference_damage` | 5.2 |
| e | **`ally_in_danger`** queda reservada e inactiva en el MVP (sin acciones sobre aliados) | 5.2 |
| f | Tabla de **resolución del resultado**, prioridad `escaped > victory > defeat` y orden del rescate a 1 PV | 10 |
| g | Mira **no tiene huida** en el MVP; `survival_bonus` no crea acciones | 5.4, 8 |
| h | Moral: `big_hit_taken` con umbral porcentual, `is_leader` y modificadores configurables de `SHAKEN` | 9 |
| i | La retirada por huida la ejecuta `GameLoop` al oír `enemy_fled`, aplazada hasta cerrar la acción en curso | 9 |
| j | Regeneración por ronda (**valor corregido en IA-0b: 10 para la estamina**, ver arriba); cooldown con regla de conteo explícita | 3, 12 |
| k | Telemetría: `request_id`, `decision_seq` nulo para el jugador, un `action_result` por intento, valores no finitos, logger creado antes de `combat_started`, `config_hash` con las skills | 11 |
| l | Vida y estamina derivadas: sin redondeo, mínimo 1 | 4.2 |

### v1.6 → v1.7

| # | Cambio | Sección |
|---|---|---|
| 1 | **D2 sustituida:** el *last stand* existente pasa a ser la regla (el protagonista caído no termina el combate si queda un aliado en pie). Mira combatiendo sola entra en el MVP | 1, 2, 10, 16 |
| 2 | **Combate puramente por turnos** (principio 7): regeneración y cooldowns por ronda, sin reloj | 3, 6, 15 |
| 3 | Las **órdenes sustituyen a las estrategias** de `Party`; Mira gana 2 skills | 4, 8 |
| 4 | Enemigos con estamina y 2-3 skills; habilidades de utilidad como datos | 5.2, 6, 15 |
| 5 | **Moral individual** sustituye a la moral de grupo por PV | 9 |
| 6 | Contrato `Combat` ↔ IA adaptado a `EventBus` asíncrono con códigos de motivo | 6 |
| 7 | RNG de combate inyectable en `SkillRoller`; sin guardado del estado de IA | 11 |
| 8 | **Sin guardado a mitad de combate** (solo savepoints) | 11, 12 |
| 9 | `outcome` usa las cadenas existentes (`escaped`) y una señal nueva con el resultado completo | 10 |
| 10 | `reference_damage` vive en el perfil (el daño típico varía de ≈5 a ≈20 según el actor) | 4, 5.2 |
| 11 | `git_dirty` calculado solo sobre las rutas relevantes | 11.2 |
| 12 | Nueva fase **IA-0** antes de IA-1 | 15 |
| 13 | Pruebas con el patrón del proyecto (escena + `_assert` + `quit`) | 12 |
| 14 | La vida de los enemigos es **siempre derivada** de la constitución | 4.2, 16 |

---

## 1. Objetivo y alcance

Sustituir la IA actual (los enemigos atacan siempre al jugador; Mira no elige objetivo) por una IA pequeña, definida en datos y diagnosticable, que deje preparado el camino hacia un tablero con distancias y alcances.

**Entra en el MVP:** perfil de comportamiento en datos (4 perfiles base), puntuación de acciones con elección ponderada, elección de objetivo entre jugador y Mira, Mira con órdenes generales (una orden activa por ronda) **y combatiendo sola cuando el protagonista cae (*last stand*)**, moral individual enemiga con vacilación y huida, contrato de resultados, log de decisiones, RNG de combate inyectable y pruebas deterministas.

**Fuera del MVP:** tablero y todo lo espacial, Momentos de Reacción, percepción con memoria por NPC, rendición y prisioneros (solo se reserva el valor), moral del jugador o de Mira, acciones multiobjetivo y con objetivo aliado (`SINGLE_ALLY`), guardado del combate, y un simulador masivo dentro de Godot (el análisis se hace con scripts externos sobre los `.jsonl`).

## 2. Decisiones ya tomadas

| Tema | Decisión |
|---|---|
| Sorpresa | Elección ponderada entre las mejores candidatas |
| Mira | Órdenes generales, gratuitas, persistentes durante el combate, una orden activa por ronda. **Sustituyen a las estrategias de `Party`** |
| Moral | Solo enemigos, individual |
| Huida enemiga | Efectiva e inmediata mientras no haya tablero, ejecutada por `Combat` |
| Rendición | Fuera del MVP; `SURRENDERED` reservado |
| Perfiles base | 4: bestia, bandido, soldado, cobarde |
| Caída del protagonista | *Last stand*: el combate continúa mientras algún aliado esté en pie |
| Reloj | Combate por turnos puro |
| Guardado | Solo en savepoints narrativos; nunca a mitad de combate |
| Destino final | Tablero con distancias y alcances, por fases |

## 3. Principios de arquitectura

1. `Combat` valida y resuelve; la IA solo propone.
2. La IA no duplica reglas: usa los datos que le entrega `Combat`.
3. Data-driven: perfiles, pesos, escalas, umbrales y órdenes en datos.
4. Sin acoplamiento: API pública de `Combat` y `EventBus`.
5. Lista de candidatas abierta: con tablero se añaden movimiento y consideraciones de distancia.
6. Ligero: clases pequeñas (`Resource`/`RefCounted`), no autoloads ni nodos nuevos.
7. **Combate por turnos puro:** dentro del combate nada de las reglas depende del reloj.
   - **Estamina.** No hay regeneración continua en combate (`ResourceSystem` la suspende mientras dura `COMBAT_ACTIVE`; fuera de combate sigue en tiempo real). La estamina solo cambia por costes, por la acción `recover` (cuando exista) y por una recuperación fija por ronda: `combat_regen_per_round` en `ResourceDefinition`, **10 para la estamina** (corregido en IA-0b: con 0 y sin `recover` el jugador se queda sin aguante en 3-4 rondas; se afina en IA-5). Se aplica al empezar cada ronda **salvo la primera**, antes de `round_started`, y solo a los participantes en pie.
   - **Cooldowns en rondas.** Se fijan a N al usar la skill, bajan 1 en cada `round_started` y la skill vuelve a estar disponible al llegar a 0 (usada en la ronda R con cooldown 2, vuelve a estar disponible en la ronda R+2). N sale de una conversión única, `int(base_cooldown)` (1,5→1 · 2,0→2 · 2,5→2 · 3,0→3), definida en un solo sitio (`SkillInstance`). Al empezar y al acabar el combate todos los cooldowns se ponen a 0.
   - **Una sola fuente de verdad.** `SkillSystem` lleva los cooldowns y `ResourceSystem` la estamina; el HUD los lee, no los recalcula.
   - **Presentación.** Las esperas de presentación (retardos de `GameLoop`, `EnemyAI` y `CompanionAI`) no afectan a las reglas y se anulan con un único ajuste (`GameLoop.presentation_time_scale`, 0 en modo sin interfaz).

## 4. Piezas y responsabilidades

| Pieza | Naturaleza | Responsabilidad |
|---|---|---|
| `BehaviorProfile` | `Resource` (`.tres`) con `validate()`; se duplica al iniciar el combate | Parámetros estáticos |
| `BehaviorProfileRegistry` | Clase estática (`RefCounted`) con caché | Carga y valida perfiles; perfil seguro por defecto |
| `CombatAIState` | Objeto por combatiente, vive lo que dura el combate | Orden activa, eventos de moral procesados, estado de moral. El último atacante lo registra `Combat` |
| `CombatSnapshot` | Estructura congelada | Lo que la IA puede conocer (sección 7) |
| `CombatAI` | Lógica sin estado propio | Puntúa y elige |
| `Combat` | `CombatSystem` existente | Candidatas, estimaciones, validación y ejecución |

La moral **actual** nunca se guarda en el perfil. Ningún dato de IA entra en el guardado de partida.

```gdscript
# core/ai/behavior_profile.gd
class_name BehaviorProfile
extends Resource

@export var id: StringName
@export var weights: Dictionary = {}            # consideración -> peso con signo
@export var target_preference: StringName       # weakest | most_dangerous | last_attacker | random | none
@export var target_bonus: float = 6.0
@export var decision_flexibility: float = 10.0
@export var survival_threshold: float = 0.3
@export var survival_bonus: float = 8.0
@export var reference_damage: float = 0.0       # 0 = usar el valor por defecto de ai_scales
@export var obedience: float = 0.0              # solo lo usan los aliados con orden
@export var can_flee: bool = true
@export var morale: Dictionary = {}             # configuración estática (sección 9)
```

Todo campo nuevo exige su declaración, su carga en el registry y **validación de datos al cargar** (perfil inexistente o mal formado → perfil seguro por defecto o rechazo con error claro en Depurador).

### 4.1 Perfiles base (valores orientativos)

| Perfil | Preferencia | Objetivo | Flexibilidad | Reacción al peligro |
|---|---|---|---|---|
| **Bestia** | Agresión | `random` / `last_attacker` | Alta | Sin moral |
| **Bandido** | Agresión oportunista | `weakest` | Media | Moral frágil |
| **Soldado** | Eficacia y protección | `most_dangerous` | Baja | Moral firme |
| **Cobarde** | Supervivencia | `weakest` | Media | Moral muy frágil |

No son cuatro niveles de inteligencia, sino cuatro formas de afrontar el peligro.

### 4.2 Datos de los combatientes

- **Perfil:** `CharacterDefinition.behavior_profile_id` (el mismo tipo de enemigo comparte perfil). Todo campo nuevo de la definición se añade también a `duplicate_definition()`.
- **Orden de Mira:** sustituye a `Party.CompanionStrategy`. `Party` guarda `default_order` por companion (la elige la pantalla Party); al empezar cada combate la orden activa vuelve a `default_order`. Migración de partidas guardadas: `AGGRESSIVE` → `attack_weakest`, `DEFENSIVE` → `attack_dangerous`, `AREA_FOCUS` y `BERSERKER` → `free`. (Verificado en `CompanionAI`: `DEFENSIVE` elegía como objetivo al enemigo con más PV; no era un comportamiento defensivo, por eso va a `attack_dangerous`.)
- **Vida y estamina:** los máximos son siempre derivados (`health_max = con × 5`, `stamina_max = con × 2 + fue × 1,5`; sin redondeo, mínimo 1 en ambos; la interfaz redondea solo al mostrar). Los `starting_resources` de salud y estamina de los `.tres` no se usan y se eliminan. Los enemigos, **incluidos los refuerzos**, se registran con todos los recursos.
- **Skills del enemigo:** salen de `CharacterDefinition.skills` y `starting_skill_values`, nunca de una constante en la escena.
- **Amenaza observable:** `CharacterDefinition.threat_hint` (opcional; `low`/`medium`/`high`) para enemigos sin equipo.

## 5. Evaluación

### 5.1 Fórmula

```
score(a) = Σ w_i · C_i(a) + target_bonus(a) + order_bonus(a) + survival_bonus(a)
```

- `C_i(a)` siempre en 0..1 (sección 5.2). Pesos con signo: positivo lo deseable, negativo riesgo y coste.
- No hay término base por acción: lo cubre `action_utility`.
- El log muestra la contribución de cada término (`w_i · C_i`), no los valores crudos.

### 5.2 Datos de `Combat` → consideraciones normalizadas

`Combat` entrega valores absolutos; **la IA los normaliza**. Las escalas viven en datos (`ai_scales`) y se ajustan en IA-5.

| Consideración | Entrada | Normalización |
|---|---|---|
| `expected_damage` | `expected_damage` de la candidata, **ya ponderado por `success_chance`** | `clamp(daño / reference_damage, 0, 1)`; `reference_damage` del perfil (o de `ai_scales`) |
| `resource_cost` | coste absoluto y recurso actual del propio actor (dato exacto) | `clamp(coste / recurso_actual, 0, 1)` |
| `action_utility` | `effect_estimate` de la candidata, **en PV equivalentes** (escala común, la calcula `Combat`) | `clamp(efecto / reference_damage, 0, 1)` |
| `target_vulnerability` | Condiciones **visibles** del objetivo en el snapshot y `kill_possible` | 1,0 si está incapacitado/derribado/aturdido o `kill_possible`; 0,5 si tiene otra condición debilitante visible; 0 si no |
| `threat_level` | `threat` del objetivo (baja/media/alta) | 0,33 / 0,66 / 1,0 |
| `self_risk` | `hp_ratio` propio y etiqueta de la candidata | `(1 − hp_ratio) × factor_riesgo[tag]` (attack 1,0 · recover 0,5 · defense 0,2 · flee 0) |
| `ally_in_danger` | **Reservada, inactiva en el MVP** (sin acciones sobre aliados): no entra en los pesos efectivos ni en el log. Se activará con las skills `SINGLE_ALLY` | 0..1 cuando se active; un protagonista caído contaría como 1,0 |

Reglas anti-solapamiento (sin cambios respecto a v1.6):
- `target_vulnerability` **no mide PV bajos**: mide indefensión, condiciones y oportunidad de remate.
- `threat_level` mide el peligro del objetivo; `target_bonus` es un empujón pequeño por preferencia del perfil, no una segunda medida de amenaza.
- `target_bonus` y `decision_flexibility` se ajustan **conjuntamente**: si el bonus supera la flexibilidad, la preferencia de objetivo decide sola el conjunto de elegibles (válido para un soldado, no para una bestia).

Ejemplo ilustrativo de pesos (soldado): `expected_damage +10`, `target_vulnerability +5`, `threat_level +4`, `self_risk −8`, `resource_cost −3`, `action_utility +5`.

#### Precisiones de datos y orden
- **`expected_damage`:** `Combat` lo entrega ya multiplicado por `success_chance` y la IA no vuelve a multiplicar. `expected_damage`, `success_chance` y `kill_possible` son tres datos distintos y se registran los tres. `success_chance` sale de `SkillRoller` (acierto = `roll ≤ skill_value`, con la pifia `roll ≥ 98` que tiene prioridad; `guaranteed_hit` lo fuerza). La parte pura del daño se extrae de `CombatSystem`; la IA nunca implementa una segunda fórmula.
- **`resource_cost` con recurso 0:** nunca se divide por cero. Si el recurso actual es 0, `C = 1` cuando el coste es > 0 y `C = 0` cuando es 0. `Combat` no lista candidatas que el actor no pueda pagar.
- **`effect_estimate` en PV equivalentes:** `Combat` convierte cada efecto a una escala común para que no se comparen unidades distintas. Defensa/reducción de daño: daño esperado evitado durante la duración del buff, estimado con las mismas funciones de daño sobre las amenazas visibles. Recuperación de salud: la cantidad restaurada. Recuperación de estamina: cantidad × `stamina_value` (tabla de datos `effect_value`, valor inicial a fijar en IA-0c y afinar en IA-5). Un efecto nuevo debe declarar cómo se convierte antes de poder usarse en una candidata.
- **`action_utility`:** `effect_estimate` es siempre ≥ 0. Un valor negativo es un error de datos: se corta a 0 y se registra un aviso.
- **`threat`:** lo calcula `Combat` (`estimate_threat(observer_side, target_id)`) con información observable (arma equipada, condiciones visibles, `threat_hint`) y lo clasifica con umbrales de `ai_scales`. El constructor del snapshot lo copia.
- **Orden canónico de candidatas:** antes de puntuar y sortear, se ordenan por `action_id` y después por `target_ids[0]` (cadena vacía si no hay objetivo). Es la clave de desempate explícita porque `sort_custom` no es estable.
- **`hp_state`:** sano / herido / gravemente herido, con umbrales en `ai_scales` (`hp_state_thresholds`).

### 5.3 Objetivo preferido (procedimiento)

Se calcula **una vez por decisión**:

1. Obtener los objetivos válidos de las candidatas ofensivas (según `Combat`). **Un combatiente a 0 PV no es objetivo válido.**
2. Aplicar `target_preference` sobre el snapshot:
   - `weakest`: menor `hp_state`.
   - `most_dangerous`: mayor `threat`.
   - `last_attacker`: último atacante del propio actor, que `Combat` entrega en el snapshot (`self.last_attacker_id`); si ya no es válido (huyó, murió, incapacitado) **no hay preferido**, no se sustituye por otro.
   - `random`: uno de los válidos, con el RNG de IA.
   - `none`: sin preferido.
3. **Empates** resueltos con el RNG de IA.
4. Aplicar `target_bonus` a las candidatas cuyo objetivo es el preferido.

En el MVP cada candidata ofensiva tiene un único objetivo; `target_ids` sigue siendo array para no cerrar la ampliación.

### 5.4 Bonificación de supervivencia

Si `hp_ratio` propio < `survival_threshold`, las candidatas con etiqueta `defense`, `recover` o `flee` reciben `survival_bonus`. No crea acciones: en el MVP **Mira no tiene acción de huida** y solo los enemigos pueden recibir el bono sobre `flee`. No restringe acciones legales: es una prioridad superable por una oportunidad muy buena. Aplica a enemigos y a Mira.

### 5.5 Selección ponderada

```gdscript
func pick(scored: Array, flexibility: float, rng: RandomNumberGenerator) -> Dictionary:
    # scored: ordenado de mayor a menor puntuación; nunca vacío
    var best: float = scored[0].score
    var floor_v: float = best - flexibility   # con flexibilidad 0 solo pasan las empatadas con la mejor
    var pool: Array = []
    var total: float = 0.0
    for c in scored:
        if c.score < floor_v - 0.000001:   # tolerancia para empates con decimales
            break
        var w: float = (c.score - floor_v) + 1.0
        pool.append({"c": c, "w": w})
        total += w
    if pool.size() == 1:
        return pool[0].c
    var roll: float = rng.randf() * total
    for p in pool:
        roll -= p.w
        if roll <= 0.0:
            return p.c
    return pool[-1].c
```

Una sola elegible → sin sorteo; puntuaciones iguales → sorteo uniforme; con flexibilidad 0 solo son elegibles las acciones de puntuación máxima; si hay varias empatadas, se elige una con el RNG de IA. Ejemplo: 20/18/15/12 con flexibilidad 5 → pesos 6/4/1 → 54,5 % / 36,4 % / 9,1 %.

## 6. Contrato `Combat` ↔ IA

Hoy la ejecución es **asíncrona por `EventBus`** y así se queda: la IA no se bloquea esperando.

```
Combat.get_candidates(actor_id)       -> Array[Candidate]   # síncrono, solo lectura
Combat.get_visible_conditions(id)     -> Array[StringName]  # condiciones observables
EventBus.combat_action_requested      <- action_data {request_id, actor, skill_id, target, source}   # petición (antes player_action_requested)
EventBus.combat_action_executed       -> (actor, skill_id, target, result)       # resultado de un ataque; result incluye request_id
EventBus.combat_action_completed      -> result {actor, request_id, ...}         # fin de la acción
EventBus.combat_action_failed         -> (actor_id, reason_code, request_id)     # fallo
Combat.next_request_id()              -> int                                      # contador creciente, único
```

```gdscript
# Candidata (propuesta). Generada por Combat; la IA la copia al recibirla y la trata como solo lectura.
{
  "action_id": "skill.enemy.heavy_attack",
  "actor_id": "telmori_1",
  "target_ids": ["companion_mira"],   # [] si no hay objetivo
  "tags": [TAG_ATTACK, TAG_COSTLY],   # conjunto cerrado de constantes
  "resource_cost": 15,
  "success_chance": 0.55,
  "expected_damage": 3.0,             # ya ponderado por success_chance
  "kill_possible": false,
  "effect_estimate": 0.0,
  "action_data": {}
}
```

**Códigos de motivo** (sustituyen al texto libre de `combat_action_failed` y `skill_failed`):

| Código | Clase |
|---|---|
| `ON_COOLDOWN`, `INSUFFICIENT_RESOURCES`, `INVALID_TARGET`, `NO_TARGET`, `DISARMED` | **STALE**: la candidata ya no es legal |
| `SKILL_NOT_FOUND`, `NO_DEFINITION`, `INTERNAL` | **ERROR** |

- **Correlación (`request_id`):** todo productor (jugador, enemigo, Mira) pide un `request_id` a `Combat.next_request_id()` y lo incluye en la petición; `Combat` lo devuelve tal cual en `combat_action_executed`, `combat_action_completed` y `combat_action_failed`. Un reintento por `STALE` es una petición nueva con otro `request_id` y `decision_seq` igual. `GameLoop` y la IA descartan toda respuesta cuyo `request_id` no sea el de la petición en curso. `source` es `player` o `ai`. El contrato no cambia de dueño: el productor emite, `GameLoop` filtra por fase y reenvía a `Combat` (que sigue siendo la autoridad de ejecución).
- **Quién gestiona el fallo:** la IA. Ante `STALE` pide un snapshot y candidatas nuevas y recalcula, con **máximo 2 reintentos adicionales (3 intentos)**; si se agotan, ejecuta una acción de reserva legal (defender o pasar) y registra el error. `ERROR` no se reintenta y aplica la misma acción de reserva. Si no hay ninguna, emite `combat_action_completed` con `{"skipped": true, "actor": id}` (siempre con `actor` y `request_id`). *Hasta IA-1 esta gestión no existe:* `EnemyAI` y `CompanionAI` solo evitan pedir lo que no pueden pagar (guarda de IA-0b) y pasan el turno.
- `GameLoop` **no** avanza el turno de un actor de IA ante `combat_action_failed`; avanza con `combat_action_completed`. Para el jugador, `PlayerCombatController` valida antes de pedir (`Skills.can_use`) y, si aun así falla, `GameLoop` devuelve la fase a `PLAYER_ACTION_SELECT`.
- Etiquetas: conjunto cerrado de constantes en un solo sitio.
- **Información de las estimaciones (D1):** `Combat` calcula con las reglas existentes, pero del objetivo solo usa información **observable**: equipo, condiciones visibles (lista en datos), estado aparente. Del propio actor puede usar sus valores exactos. La resolución real sigue usando todos los valores reales.
- **Acciones de utilidad como datos** (propuesta técnica, a validar en IA-0c): las skills `SELF` (defender, recuperar, huir) no tiran dado de ataque, igual que hoy `dodge`; sus efectos son `BUFF` (p. ej. `damage_reduction`), un efecto inmediato `RESTORE` de recurso y, para la huida, `FLEE`. La rama actual de `dodge` se generaliza a toda skill `SELF`.

## 7. Snapshot

Generado por un constructor de la IA a través de la API pública de `Combat` (nunca accede a miembros privados), al inicio de cada decisión.

- **De sí mismo:** exacto (PV, estamina, recursos, condiciones).
- **De los demás:** aparente (`hp_state`, `threat`, condiciones visibles).
- **Último atacante:** `Combat` lo registra por combatiente al aplicar daño; el snapshot incluye `self.last_attacker_id` y `player.last_attacker_id`.
- **Inmutable por implementación:** se congela en profundidad al construirlo (`Dictionary.make_read_only()` / `Array.make_read_only()` recursivos; verificar en 4.7.2 y probar con datos anidados). El evaluador no consulta `Combat` mientras puntúa.

## 8. Órdenes a Mira

Mira usa el mismo evaluador. La orden activa vive en su `CombatAIState` y **sustituye a la estrategia de `Party`**.

| Orden | Bonificación (`order_bonus`) |
|---|---|
| `free` (defecto) | Ninguna |
| `protect` | Candidatas contra el último en atacar **al protagonista** (`snapshot.player.last_attacker_id`, que sigue siendo válido aunque el protagonista esté caído). Si ese atacante murió, huyó o está incapacitado, la orden no aporta nada. `protect_ally` queda **reservado**: sin skills de ese tipo en el MVP |
| `attack_weakest` | Acciones contra el enemigo más débil |
| `attack_dangerous` | Acciones contra el más peligroso |
| `defensive` | `defense` y `recover` |
| `conserve` | Penalización a candidatas `costly` |

- `bonificación_efectiva = bonificación × obedience`: la obediencia escala la intensidad, nunca la legalidad.
- La orden **no elimina candidatas**. La supervivencia se garantiza con `survival_bonus`.
- Mira no tiene acción de huida en el MVP; si el protagonista cae, conserva la última orden activa.
- Orden no aplicable (p. ej. `protect` sin amenazas): no aporta nada; el log lo indica.
- **Temporalidad:** al empezar el combate la orden es `default_order` de `Party`. Durante la fase del jugador se elige libremente y **cuenta la última selección** al terminar su fase. Se aplica en el turno de Mira, persiste hasta el fin de ese combate y no se puede cambiar durante la resolución de una acción ni del turno enemigo. **Si el protagonista está caído, no hay fase de jugador y la orden se mantiene.** Al terminar el combate no se guarda.
- **Kit de Mira:** para que las órdenes tengan efecto se le añaden dos skills `SELF` (defender y recuperar aguante), además de `attack.light` y `dodge`.
- **UI:** selector discreto en el panel de Mira (botón y atajo), `tr()` y `UITokens`. Vive en `CombatArenaViewModel` (hijo de la View, `changed(reason)`); la View no accede a `Combat`. La pantalla Party sustituye el selector de estrategia por el de orden por defecto.

## 9. Moral enemiga

Sustituye a la moral de grupo por PV (`morale_threshold_pct`, `_check_group_morale`, `enemy_group_fled`), que **se elimina en IA-4**. Ningún contenido de la aventura la usaba.

Evaluada al inicio de cada turno enemigo. Sin configuración de moral, se omite.

```
moral = base − Σ penalización(eventos procesados) − penalización(tramo de salud) − penalización(otras condiciones)
```

```json
"morale": {
  "base": 100,
  "events": { "ally_died": 15, "leader_died": 35, "big_hit_taken": 10 },
  "big_hit_pct": 25,
  "shaken_modifiers": { "offensive_mult": 0.7, "defensive_mult": 1.3, "flexibility_add": 5 },
  "health_tiers": [ { "below": 0.5, "penalty": 20 }, { "below": 0.25, "penalty": 30 } ],
  "conditions": { "outnumbered": 15 },
  "thresholds": { "shaken_enter": 70, "shaken_exit": 75, "broken": 35 }
}
```

- **Salud: tramos excluyentes.** Se aplica solo el tramo más alto alcanzado.
- **Eventos con identidad:** `event_id = "<tipo>:<id_origen>"`; se guarda el conjunto de procesados: una señal repetida no penaliza dos veces, pero cada muerte distinta sí.
- **`big_hit_taken`:** el combatiente recibe de un solo golpe un daño ≥ `big_hit_pct` % de sus PV máximos (por defecto 25). Solo lo recibe el golpeado y solo si sobrevive.
- **Líder:** campo opcional `is_leader` (bool, por defecto `false`) en la definición del combatiente o del encuentro. Sin líder, toda muerte es `ally_died`.
- **Modificadores de `SHAKEN`:** multiplican los pesos de las consideraciones ofensivas (`expected_damage`, `target_vulnerability`) y defensivas (`self_risk`, `survival_bonus`) y suman a la flexibilidad; valores por defecto comunes, ajustables por perfil en IA-5.
- **Muerte del líder:** cuenta como `leader_died` y no además como `ally_died`.
- Los eventos no se revierten; las condiciones (como `outnumbered`) se recalculan en cada evaluación, de modo que **un refuerzo se contabiliza solo**, sin base dinámica.

| Estado | Condición | Efecto |
|---|---|---|
| `STEADY` | por encima de `shaken_enter` | Normal |
| `SHAKEN` | entra < `shaken_enter`, sale > `shaken_exit` (histéresis) | Prudencia ↑, agresividad ↓, flexibilidad ↑ |
| `BROKEN` | ≤ `broken` | Terminal en este combate |

- La crónica registra solo transiciones.
- `BROKEN` + `can_flee = true`: ejecuta `flee` (fuera del sorteo).
- `BROKEN` + `can_flee = false`: sigue combatiendo con los modificadores de `SHAKEN`.
- **La huida se ejecuta a través de `Combat`:** `flee` es una candidata más (etiqueta `flee`, skill `SELF` con efecto `FLEE`, sin tirada). `Combat` ejecuta el efecto `FLEE`, marca al combatiente `FLED` y emite `enemy_fled(enemy_id)`; `GameLoop` es el dueño de `participants` y `turn_order`: al oír la señal lo retira (aplazado hasta cerrar la acción en curso, para no tocar el orden mientras se recorre) y reevalúa la victoria. La IA nunca modifica el estado directamente.
- `EnemyWorldLink` pasa a escuchar `enemy_fled` (un id por señal).
- **Validación al cargar:** debe cumplirse `broken < shaken_enter < shaken_exit`; si no, el perfil se rechaza.

## 10. Contrato de resultados (`Combat` → narrativa)

```gdscript
enum CombatantStatus { ALIVE, INCAPACITATED, DEAD, FLED, SURRENDERED }   # SURRENDERED reservado

{
  "outcome": "victory" | "defeat" | "escaped",
  "rounds": 6,
  "player_rescued": false,
  "combatants": [
    { "id": "player",         "side": "player", "status": CombatantStatus.ALIVE },
    { "id": "companion_mira", "side": "player", "status": CombatantStatus.INCAPACITATED },
    { "id": "telmori_1",      "side": "enemy",  "status": CombatantStatus.FLED }
  ]
}
```

- `GameLoop` emite el resultado con una señal nueva (`combat_result_ready(result: Dictionary)`) justo antes de `combat_ended(String)`, que **se mantiene** porque tiene seis oyentes.
- Cadenas de `outcome`: las que ya usa el motor (`victory`, `defeat`, `escaped`).
- **D2 (sustituida) — *last stand*:** cuando el protagonista queda a 0 PV, el combate **continúa** mientras algún companion esté activo. Es `defeat` cuando el protagonista está caído y no queda ningún companion activo (o no hay companions). Si el grupo gana en *last stand*, el protagonista se levanta con 1 PV y `player_rescued = true` (antes de construir el resultado, ver el orden de cierre). El protagonista caído no puede huir ni dar órdenes.
- **Estados:** protagonista y companions a 0 PV son `INCAPACITATED`; un enemigo a 0 PV es `DEAD`; un enemigo retirado, `FLED`.
- **Condiciones de fin:** se definen antes que el resultado y no las decide la IA.

| Situación | Resultado |
|---|---|
| El protagonista huye | `escaped` |
| No quedan enemigos activos (muertos o `FLED`) y el protagonista está en pie | `victory` |
| No quedan enemigos activos y el protagonista está caído con algún companion en pie | `victory`, `player_rescued = true` |
| Protagonista caído y ningún companion activo (o sin companions) con enemigos activos | `defeat` |

- **Prioridad:** se evalúa una sola vez tras cada acción cerrada, en este orden: `escaped` > `victory` > `defeat`. Que varias señales lleguen en otro orden no cambia el resultado.
- **Orden de cierre:** (1) se cumplen las condiciones; (2) si había rescate, el protagonista pasa a 1 PV; (3) se construye `combatants` con los estados ya finales; (4) `combat_result_ready`; (5) `combat_ended`.

Invariantes:
- Cada combatiente aparece una sola vez y con un identificador válido.
- El estado final coincide con el estado real de `Combat`.
- Un combatiente `FLED` no vuelve a actuar.
- `outcome` es coherente con los estados individuales.
- Se reutilizan los estados que ya existen (`Party.is_incapacitated`, PV ≤ 0); no se duplican.
- **Huida del protagonista (`escaped`):** termina el combate; cada combatiente conserva su estado. Mira no se marca `FLED`. Hoy `PartyManager` revive con 1 PV a los companions incapacitados.

Señales nuevas en `EventBus`: `ai_decision_made`, `enemy_morale_changed(enemy_id, state)`, `enemy_fled(enemy_id)`, `mira_order_changed(order_id)`, `combat_result_ready(result)`.

## 11. RNG, reproducibilidad y trazabilidad

- **RNG de combate:** `SkillRoller` pasa a usar un `RandomNumberGenerator` inyectable (variable estática con valor por defecto aleatorio). Es el único consumidor de azar que influye en el desarrollo del combate; `SkillProgressionService` solo tira al final y el loot, después.
- **RNG de la IA:** independiente del de combate; se usa también para desempates (5.3).
- **Dos garantías:**
  1. Misma entrada + mismo snapshot + mismo estado del RNG de IA ⇒ misma decisión de IA.
  2. Mismo estado inicial completo + mismas semillas ⇒ mismo desarrollo del combate (modo sin interfaz y análisis). No se garantiza tras un guardado, porque **no se guarda a mitad de combate**.
- La iniciativa tiene desempate determinista (por id: a igual valor, id ascendente) para que el orden entre enemigos iguales sea reproducible.
- **Guardado:** ningún dato de IA entra en la partida. La única excepción es `default_order` de cada companion, que vive en `Party`.
- **Log de decisiones**, con desglose por término:

```
[R3][telmori_1] perfil=bandit
Candidatas: atacar_mira=21.0  atacar_jugador=18.5  defender=14.0  recuperar=12.0
Mejor: 21.0 · flexibilidad: 5.0 · elegibles: atacar_mira, atacar_jugador
Sorteo: atacar_mira (roll=0.31)
Desglose atacar_mira: daño +8.0 | vulnerabilidad +5.0 | amenaza +3.0 | riesgo −2.0 | coste −1.0 | bonus objetivo +6.0 | total 19.0
```

(Números ilustrativos; el desglose debe sumar el total.) No es visible para el jugador salvo en depuración.

### 11.1 Telemetría de combate (fichero incremental)

- **Formato JSON Lines (`.jsonl`)**, un objeto por línea y evento; el texto de consola se genera del mismo registro.
- **Un fichero por combate:** `user://logs/combat/combat_<AAAAMMDD_HHMMSS>_<combat_id>.jsonl`.
- **Escritura incremental:** se abre al empezar, cada evento es una línea con `flush()`, se cierra en `combat_end`.
- **Eventos:** `combat_start`, `decision`, `action_result`, `order_changed`, `morale_change`, `flee`, `error`, `combat_end`. Se registran también las acciones del jugador y sus resultados. **`request_id`** va en la petición y en cada `action_result`; `decision_seq` es `null` en las acciones del jugador. `action_result` se registra **por intento**, incluidos `STALE` y `ERROR`.
- **Cabecera (`combat_start`):** `combat_id`, bloque `version`, `adventure_id`/`scene_id`, semillas y estados iniciales de los RNG, composición de los bandos y orden de Mira.
- **Control:** activado por defecto en compilaciones de depuración, desactivado en las exportadas. Se conservan los últimos N ficheros (p. ej. 50). No entran en el guardado.
- **Acceso:** opción «Abrir carpeta de logs» (`OS.shell_open(ProjectSettings.globalize_path("user://logs/combat"))`).
- **Un solo logger:** `CombatTelemetry` (`RefCounted`). **Lo crea `CombatProductionScene` (uno por combate)**, que se libera en `combat_ended`: `combat_end` se escribe antes del `queue_free()`. Casi todos los eventos salen de `EventBus` (`combat_started`, `round_started`, `combat_action_executed`, `combat_action_failed`, `character_damaged`, `character_died`, `buff_applied/expired`, `enemy_fled`, `reinforcement_spawned`, `combat_result_ready`); solo `decision` exige un emisor nuevo en `CombatAI`.
- **Orden de creación:** el logger se crea y se conecta a `EventBus` **antes** de emitir `combat_started`, y se cierra también si el combate termina por otra ruta (`end_combat` directo, Game Over, salida del árbol de escena).
- **Robustez:** `event_seq` lo incrementa solo el logger. Un fallo de escritura desactiva la telemetría con un aviso y nunca interrumpe el combate. Los valores no finitos (`NAN`, `INF`) se sustituyen por `null` antes de serializar.
- **Modo sin interfaz:** los retardos de presentación de `EnemyAI`, `CompanionAI` y `GameLoop` se anulan con un único ajuste (`GameLoop.presentation_time_scale = 0`); cada espera pasa a durar un frame para conservar el orden de las señales.

### 11.2 Trazabilidad de versiones

```json
"version": {
  "schema_version": 1,
  "ai_version": "1.0.0",
  "config_hash": "<sha256>",
  "git_commit": "a1b2c3d",
  "git_dirty": false,
  "git_ai_path_commit": "9f8e7d6",
  "game_version": "...",
  "godot_version": "4.7.2",
  "scenario_hash": "<sha256>",
  "run_label": "base"
}
```

| Campo | Qué identifica | Quién lo fija |
|---|---|---|
| `schema_version` | Formato del log | Constante en `CombatTelemetry` |
| `ai_version` | Lógica del evaluador | **Manual**, con entrada en `docs/ai_changelog.md` y tag `ai-vX.Y.Z` |
| `config_hash` | Datos efectivos de IA (perfiles, `ai_scales`, `effect_value`, órdenes, moral) **y de las skills que evalúa** (costes, efectos, cooldowns, etiquetas) | Automático: SHA-256 (`HashingContext`) sobre serialización canónica (`JSON.stringify` con claves ordenadas); nunca `hash()` |
| `git_commit` / `git_dirty` | Código exacto y si había cambios sin confirmar | Automático |
| `git_ai_path_commit` | Último commit que toca `core/ai`, `core/combat` y los datos de IA | Automático |
| `scenario_hash` | Composición y estadísticas de los bandos | Automático |
| `run_label` | Experimento | Opcional |

Reglas:
- La configuración efectiva completa va **embebida en la cabecera** además del hash.
- **Git:** mientras no haya exportación basta `OS.execute("git", ...)` desde el editor (git funciona en el entorno de Fernando). Para compilaciones exportadas, `build_info.json` generado al lanzar o exportar y **añadido a `.gitignore`** (hoy no está).
- **`git_dirty` solo mira las rutas relevantes** (`core/ai`, `core/combat`, `data/ai`, `data/characters`, `data/skills`). Con el árbol general sucio, casi ninguna ejecución sería comparable. `true` marca la ejecución y el análisis la excluye por defecto.
- Sin información de git, `git_commit` y `git_dirty` son `null`.
- **Límites de la comparación:** con la misma semilla, dos versiones de IA divergen en la primera decisión distinta. Solo son válidas las comparaciones agregadas (cientos de combates) con el mismo `scenario_hash`.

### 11.3 Contrato de eventos

Todos los eventos llevan: `event`, `event_seq` (desde 0, **sin huecos**), `elapsed_ms` desde `combat_start` y `round`.

| Evento | Contenido mínimo |
|---|---|
| `combat_start` | Cabecera (11.1) y bloque `version` |
| `decision` | Lo que la IA **pretendía** hacer: `actor_id`, `profile_id`, estado de moral, `rng_state_before/after`, resumen del snapshot y, por cada candidata (orden canónico) y término: `raw`, `ref`, `normalized`, `weight`, `contribution`; `target_bonus`, `order_bonus`, `survival_bonus`, `score`; `flexibility`, elegibles con pesos de sorteo, `roll`, `chosen` |
| `action_result` | Lo que **realmente ocurrió**: `request_id`, `decision_seq` (nulo en el jugador), `actor_id`, `target_ids`, `action_id`, `tags`, `status` (`OK`/`STALE`/`ERROR`), `reason_code`, tirada, coste real, daño y efectos, cambios antes → después de PV/estamina/condiciones |
| `order_changed` | `order_id`, `previous_order_id` |
| `morale_change` | `enemy_id`, moral antes/después, estado antes/después, eventos y condiciones que contribuyen |
| `flee` | `actor_id`, causa (moral o jugador) |
| `error` | Cualquier `ERROR` o aviso de datos |
| `combat_end` | Resultado completo (sección 10) |

Registrar los datos de entrada además de la contribución permite distinguir si el problema son los **pesos** o la **estimación** de `Combat`. `scenario_hash` incluye, por combatiente: tipo e id, perfil, atributos y habilidades, recursos iniciales, equipo, condiciones iniciales y la configuración del encuentro; **no incluye la semilla**.

## 12. Pruebas automatizadas (deterministas, en `test/`)

**Patrón del proyecto:** pares `.gd` + `.tscn` que se lanzan con F6 y usan `_assert(cond, texto)` con contadores `[PASS]/[FAIL]`. Se añade `get_tree().quit(código)` al final para poder ejecutarlas con `--headless`.

| Prueba | Resultado esperado |
|---|---|
| Una sola acción legal | Se selecciona |
| Flexibilidad 0 con mejor única | Siempre esa |
| Flexibilidad 0 con empate en la mejor | Solo entre las empatadas, reproducible por RNG |
| Puntuaciones iguales | Selección válida |
| Mismo snapshot + mismo RNG de IA | Misma decisión |
| `expected_damage` y `resource_cost` con valores extremos | Consideraciones siempre en 0..1 |
| Objetivo declarado ilegal por `Combat` | No se selecciona |
| Sin objetivos válidos | La IA no intenta atacar |
| Acción sin objetivo (`target_ids = []`) | Se evalúa sin error |
| Dos objetivos igualmente débiles | Desempate reproducible por RNG |
| `last_attacker` que ha huido | Sin preferido; se evalúa normal |
| Dos candidatas contra el mismo objetivo | Cada una recibe una sola vez el `target_bonus` |
| Orden `conserve` / `protect` | Penaliza `costly` / favorece proteger |
| Mira en estado crítico con orden agresiva | `survival_bonus` activo; puede elegir supervivencia |
| Muerte de un aliado / del líder | Penalización una sola vez |
| Mismo evento repetido | No penaliza dos veces |
| Salud < 25 % | Solo se aplica el tramo más alto |
| Moral bajo umbral | Entra en `BROKEN` |
| `BROKEN` con `can_flee = false` | Sigue combatiendo con modificadores de `SHAKEN` |
| Histéresis | No oscila en el umbral |
| Acción obsoleta (`STALE`) | Recalcula sin ejecutar acción ilegal; máximo 2 reintentos |
| `ERROR` | No se reintenta; aplica la acción de reserva |
| Perfil inexistente o mal formado | Perfil seguro o rechazo controlado |
| Snapshot congelado | Intentar modificarlo falla; también en datos anidados |
| **Mismo perfil, distinta situación** | La puntuación cambia con la circunstancia relevante y las decisiones siguen siendo legales |
| Candidatas barajadas | Mismo resultado |
| `effect_estimate` negativo | Se corta a 0 con aviso |
| Recurso actual 0 | Sin división por cero |
| Umbrales de moral inválidos | Perfil rechazado |
| `event_seq` | Sin huecos |
| Git desconocido | `null` |
| **Nuevas (v1.7):** regeneración continua suspendida en combate | La estamina no cambia con el tiempo; con `combat_regen_per_round = 0` solo cambia por costes y `recover`; con un valor X (corregido en IA-0b: 10 para la estamina) sube exactamente X al empezar cada ronda **salvo la primera**, y solo a los participantes en pie |
| Regeneración continua tras el combate | Se reanuda al terminar por victoria, derrota y huida |
| Cooldown 2 | Usada en la ronda R, no disponible en R+1, disponible en R+2 |
| Conversión de cooldown a rondas | `1,5→1 · 2,0→2 · 2,5→2 · 3,0→3`; un cooldown de 1 nunca bloquea |
| Respuesta con `request_id` ajeno | Se descarta |
| Reintento `STALE` | Nuevo `request_id`, mismo `decision_seq` |
| `protect` con el protagonista caído | Usa el último atacante del protagonista; sin bonus si ya no es válido |
| Último enemigo huye y Mira cae en la misma resolución | Prioridad `victory` |
| Resultado con rescate | El protagonista aparece con 1 PV y `ALIVE` |
| Mira con `survival_bonus` | Nunca elige huir (no existe la candidata) |
| `big_hit_taken` y muerte | Solo `ally_died` para los demás; sin `big_hit_taken` en el que muere |
| NaN en una estimación | Se registra como `null`; el JSON es válido |
| Cooldown en rondas | Se descuenta una vez por ronda; se reinicia al empezar y al acabar el combate |
| Actor de IA sin recursos para su acción | Pasa el turno con `actor`; el turno no se cuelga |
| *Last stand* | El combate continúa con Mira; `defeat` si ella cae; `player_rescued` al ganar |
| Huida individual | El combatiente sale de `turn_order`; `FLED`; la victoria se reevalúa |
| Iniciativa | Mismo orden entre enemigos iguales en cada ejecución |
| `SkillRoller` con RNG inyectado | Misma semilla, mismas tiradas |
| Estado de combate | Buffs, huida pendiente y defensa se reinician entre combates |

### 12.1 Niveles de prueba y métricas

| Nivel | Objetivo | Ejemplo |
|---|---|---|
| Funcional | Una regla concreta funciona | Un cobarde huye cuando su moral cae bajo el umbral |
| De comportamiento | Los perfiles se diferencian | Un soldado protege más al protagonista que una bestia |
| Estadístico | Comparar configuraciones | 300-500 combates por configuración, mismo `scenario_hash` |

Métricas mínimas: porcentaje de victorias y derrotas; porcentaje de huidas enemigas; rondas medias y distribución; PV restantes del protagonista; veces que Mira resulta incapacitada; veces que el protagonista cae y el grupo gana; acciones más usadas por perfil; frecuencia de cambio de objetivo; recursos consumidos; uso de cada orden. Primero se usan para **detectar absurdos**, no para equilibrar todo a la vez.

## 13. Extensiones previstas hacia el tablero

| Con tablero se añade… | …sin cambiar el núcleo |
|---|---|
| Acciones `move_to(casilla)` | Entran en la lista de candidatas |
| Consideraciones de distancia/posición | Funciones puras con su peso en el perfil |
| Validación de alcance | La hace `Combat` |
| Huida con carrera | Revisión de 9 y del contrato de resultados |
| «Quién actúa ahora» | La IA lo pide a una abstracción, no asume bandos |

## 14. Fase 0 — cerrada

La Fase 0 está en `docs/ia_combate_fase0.md`. Las decisiones que dejó abiertas están resueltas en la sección 16.

## 15. Fases de implementación

| Fase | Contenido | Validación |
|---|---|---|
| **IA-0** | Prerrequisitos de motor (ver `docs/ia_combate_ia0_plan.md`): robustez de acciones y estado de combate, combate por turnos, estimaciones de `Combat`, datos | Los combates actuales se comportan igual o mejor; los defectos del plan no se reproducen |
| **IA-1** | Contratos: `BehaviorProfile` (con validación), `CombatAIState`, snapshot congelado, candidatas, resultado, registry; primera decisión de objetivo; gestión de fallos de acción de IA; `CombatTelemetry` mínimo (`combat_start`, `decision`, `combat_end`) | El Output muestra el log y aparece un `.jsonl` con `event_seq` sin huecos; enemigos distintos reparten ataques de forma distinta |
| **IA-2** | Evaluador, normalizaciones, selección ponderada, RNG propio, desglose en el log; skills de enemigo (ataque fuerte, defender, recuperar) | Misma entrada y RNG = misma decisión; variación sin absurdos |
| **IA-3** | Mira con órdenes como bonificaciones, selector de UI, pantalla Party y migración de la estrategia a `default_order`, skills de Mira | La orden cambia sus decisiones; la supervivencia sigue disponible |
| **IA-4** | Moral individual, transiciones, huida (`FLEE`), `can_flee`, contrato final (`combat_result_ready`); **se elimina la moral de grupo** | Un bandido huye al caer sus compañeros; la narrativa recibe el estado de todos |
| **IA-5** | Ajuste con partidas reales, escalas, umbral de huida del jugador, HP y estamina (incluido `combat_regen_per_round`), pruebas automatizadas | Diferencias perceptibles entre los 4 perfiles |

Cada fase se cierra con prueba manual (qué debe verse en Output y en Depurador → Errores) e informe en `docs/`.

## 16. Decisiones

**Cerradas**
- **D1 — Información de las estimaciones:** `Combat` usa del objetivo solo información observable; la IA no implementa una segunda fórmula.
- **D2 (sustituye a la de v1.3) — *last stand*:** la caída del protagonista no es derrota inmediata (sección 10).
- **D3 — Orden de Mira:** las órdenes sustituyen a las estrategias de `Party`; Mira gana dos skills.
- **D4 — Enemigos:** estamina para todos (incluidos refuerzos) y 2-3 skills.
- **D5 — Reloj:** combate por turnos puro (principio 7).
- **D6 — Moral:** individual; la de grupo se elimina en IA-4.
- **D7 — Guardado:** solo en savepoints; ningún dato de IA entra en el guardado.
- **D8 — Vida:** siempre derivada de la constitución; se eliminan los `starting_resources` inertes y se ajustan las constituciones.

**Abiertas, no bloquean el MVP**
- Prisioneros y rendición.
- Huida del protagonista con Mira incapacitada (hoy se revive con 1 PV): decisión narrativa.
- Umbral de huida del jugador (`20 + 10 × enemigos`) frente a una estamina máxima de ≈40: con 4 enemigos es inalcanzable. Revisar en IA-5.
- Huida con tablero (carrera, enemigos clave que no deben escapar).
- Varios aliados: órdenes por companion (el código ya admite tres) o globales.
- Objetivo aliado (`SINGLE_ALLY`) y la orden `protect` completa.
- Conducta alternativa «desesperada» para `BROKEN` sin huida.
- Valor definitivo de `combat_regen_per_round` y conversión de cooldown (`int()` frente a campo propio `cooldown_rounds`): IA-5.
