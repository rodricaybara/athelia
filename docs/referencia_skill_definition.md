# Referencia de Parámetros — SkillDefinition

**Proyecto:** RPG 2D — Godot 4.5  
**Fecha:** Abril 2026 — actualizado tras spike SkillTreeScreen  
**Archivo:** `res://core/skills/skill_definition.gd`

Cada habilidad del juego es un fichero `.tres` que instancia `SkillDefinition`. Los parámetros se dividen en dos bloques: el **bloque base** define qué es la skill y cómo se usa en combate; el **bloque de progresión** controla cómo mejora con el tiempo.

---

## Bloque base

### `id`
**Tipo:** `String` — **Obligatorio**

Identificador único de la habilidad en todo el juego. Lo usan todos los sistemas para referenciarla: combate, progresión, desbloqueo narrativo, saves, diálogos.

**Convención de nombres:** `skill.categoria.nombre`

```
skill.attack.light
skill.attack.heavy
skill.combat.dodge
skill.exploration.lockpick
skill.magic.fireball
```

---

### `name_key`
**Tipo:** `String` — **Obligatorio**

Clave del sistema de localización para el nombre visible de la habilidad, que aparece en la UI de combate, inventario de skills y tooltips.

```
SKILL_ATTACK_LIGHT_NAME
SKILL_DODGE_NAME
```

> ⚠️ Nunca escribir el nombre directamente. Siempre usar una clave de localización.

---

### `description_key`
**Tipo:** `String` — **Opcional** (recomendado)

Clave de localización para la descripción larga de la habilidad. Se muestra en tooltips y pantallas de información de skill.

```
SKILL_ATTACK_LIGHT_DESC
SKILL_DODGE_DESC
```

---

### `mode`
**Tipo:** `String` (enum) — **Default:** `"EXPLORATION"`

Determina en qué contexto de juego está disponible la habilidad. El sistema de combate y el de exploración filtran las skills por modo antes de ofrecerlas al jugador.

| Valor | Cuándo está disponible |
|---|---|
| `COMBAT` | Solo durante combate — aparece en la barra de acciones de combate |
| `EXPLORATION` | Solo en el mapa de exploración — movimiento, interacción, sigilo |
| `DIALOGUE` | Solo durante conversaciones — persuasión, intimidación, engaño |
| `NARRATIVE` | Gestionada exclusivamente por el sistema narrativo — no aparece en UI |

---

### `category`
**Tipo:** `String` (enum) — **Default:** `"PHYSICAL"`

Categoría temática de la habilidad. Influye en qué tipo de cansancio genera al usarse (ver `stress_type` en el bloque de progresión) y puede usarse para filtrado en la UI.

| Valor | Descripción |
|---|---|
| `PHYSICAL` | Habilidades corporales — combate, atletismo, resistencia |
| `MENTAL` | Habilidades cognitivas — percepción, conocimiento, voluntad |
| `MAGIC` | Habilidades mágicas — hechizos, rituales, encantamientos |
| `UTILITY` | Habilidades de apoyo sin categoría clara — esquiva, defensa táctica |

---

### `subcategory`
**Tipo:** `String` (enum) — **Default:** `"NONE"`

Subcategoría de la habilidad para agrupación en la UI del árbol de habilidades. Independiente de `mode` — permite mayor granularidad que este. Por ejemplo, `mode = COMBAT` puede tener `subcategory = MELEE` o `subcategory = RANGED`.

| Valor | Descripción |
|---|---|
| `MELEE` | Combate cuerpo a cuerpo |
| `RANGED` | Combate a distancia |
| `EXPLORATION` | Habilidades de exploración y mundo |
| `DIALOGUE` | Habilidades sociales y conversación |
| `NARRATIVE` | Gestionadas por el sistema narrativo |
| `ENEMY` | Exclusivas de enemigos — no aparecen en el árbol del jugador |
| `NONE` | Sin subcategoría — aparecen en tab "General" |

Determina en qué tab aparece la skill en `SkillTreeScreen`. Las skills con `subcategory = NONE` se agrupan en una tab genérica.

```gdscript
subcategory = "MELEE"        # ataque ligero, ataque pesado, esquiva
subcategory = "RANGED"       # arco, honda, lanzar objeto
subcategory = "EXPLORATION"  # ganzúa, sigilo, percepción
```

---

### `costs`
**Tipo:** `Dictionary` — **Default:** `{}`

Coste en recursos que paga el personaje cada vez que usa la habilidad. El sistema verifica que el personaje tenga suficiente antes de permitir el uso. Si no puede pagarlo, la habilidad no se ejecuta.

El formato es `{ "recurso": cantidad }`. Se pueden declarar costes en varios recursos a la vez.

```gdscript
costs = { "stamina": 10.0 }          # ataque ligero
costs = { "stamina": 25.0 }          # ataque pesado
costs = { "mana": 30.0 }             # hechizo
costs = { "stamina": 5.0, "mana": 15.0 }   # skill mixta
costs = {}                            # sin coste
```

Los recursos disponibles dependen de `ResourceDefinition`. Los habituales son `health`, `stamina`, `gold` y `mana`.

---

### `base_cooldown`
**Tipo:** `float` — **Mínimo:** `0.0` — **Default:** `0.0`

Tiempo en segundos que debe esperar el personaje antes de poder usar la habilidad de nuevo. Durante el cooldown la habilidad aparece desactivada en la UI.

`0.0` significa que no tiene cooldown — se puede usar en cada turno sin restricción.

| Referencia | Valor |
|---|---|
| Sin cooldown | `0.0` |
| Ataque básico | `1.5` |
| Esquiva | `2.0` |
| Ataque pesado | `3.0` |
| Hechizo poderoso | `5.0` |

---

### `target_type`
**Tipo:** `String` (enum) — **Default:** `"SELF"`

A quién afecta la habilidad cuando se usa. Determina si el jugador necesita seleccionar un objetivo antes de usarla.

| Valor | Descripción |
|---|---|
| `SELF` | Se aplica sobre el propio personaje (buffs, pociones, esquiva) |
| `SINGLE_ENEMY` | Requiere seleccionar un enemigo concreto |
| `MULTI_ENEMY` | Afecta a todos los enemigos presentes |
| `AREA` | Afecta a un área — tanto enemigos como aliados dentro de ella |

---

### `range_type`
**Tipo:** `String` (enum) — **Default:** `"MELEE"`

Alcance de la habilidad. En combate puede determinar si el personaje necesita estar adyacente al objetivo.

| Valor | Alcance |
|---|---|
| `MELEE` | Cuerpo a cuerpo — contacto directo |
| `SHORT` | Corto alcance — 1 a 3 metros |
| `MEDIUM` | Alcance medio — 3 a 10 metros |
| `LONG` | Largo alcance — más de 10 metros |

---

### `effects`
**Tipo:** `Array` — **Default:** `[]`

Lista de efectos que produce la habilidad al usarse con éxito. Cada efecto es un `Dictionary` con una clave `type` que determina qué hace.

El `CombatSystem` procesa esta lista en orden cuando la habilidad se resuelve. Un mismo array puede combinar varios efectos.

---

#### Efecto de tipo `DAMAGE`

Inflige daño al objetivo. El daño final se calcula multiplicando el atributo base del atacante por el `value` declarado.

| Clave | Tipo | Descripción |
|---|---|---|
| `type` | String | `"DAMAGE"` |
| `value` | float | Multiplicador sobre el atributo de daño base del personaje. `1.0` = daño base, `2.0` = doble daño |
| `duration` | float | Duración de la animación de impacto en segundos (visual, no afecta al daño) |
| `base_damage_attribute` | String | Atributo que se usa como base. Default: `"base_damage"` |
| `critical_multiplier` | float | Multiplicador adicional en golpe crítico. Default: `2.0` |

```gdscript
# Ataque ligero — daño base × 1.2
{ "type": "DAMAGE", "value": 1.2, "duration": 0.4 }

# Ataque pesado — daño base × 2.0, crítico × 2.5
{ "type": "DAMAGE", "value": 2.0, "duration": 0.6, "critical_multiplier": 2.5 }
```

---

#### Efecto de tipo `BUFF`

Aplica un efecto temporal al personaje que lo usa. Los buffs se almacenan y el sistema los consume cuando se activan.

| Clave | Tipo | Descripción |
|---|---|---|
| `type` | String | `"BUFF"` |
| `buff_type` | String | Tipo de buff (ver tabla abajo) |
| `duration` | float | Duración en segundos o turnos según el buff |
| `value` | float | Magnitud del efecto (opcional según el buff) |
| `description` | String | Texto descriptivo — solo informativo, no afecta al juego |

**Tipos de buff disponibles:**

| `buff_type` | Efecto |
|---|---|
| `"evasion"` | El siguiente ataque recibido falla automáticamente. Se consume al esquivar. |
| `"guaranteed_hit"` | El siguiente ataque del personaje impacta con seguridad, ignorando la tirada de éxito. Se consume al atacar. |

```gdscript
# Esquiva — evita el siguiente golpe y garantiza el siguiente ataque propio
{ "type": "BUFF", "buff_type": "evasion", "duration": 0.5, "value": 100.0,
  "description": "Dodge next incoming attack" }
{ "type": "BUFF", "buff_type": "guaranteed_hit", "duration": 1,
  "description": "Next attack has 100% hit chance" }
```

---

### `tags`
**Tipo:** `Array[String]` — **Default:** `[]`

Etiquetas que clasifican la habilidad para filtrado, búsqueda y lógica de juego. No afectan al comportamiento directamente, pero pueden usarse en condiciones de diálogos, eventos narrativos y filtros de UI.

```gdscript
tags = ["attack", "melee", "basic", "physical"]   # ataque ligero
tags = ["attack", "melee", "heavy", "physical"]   # ataque pesado
tags = ["dodge", "defensive", "buff", "tactical"] # esquiva
tags = ["magic", "fire", "aoe", "mental"]         # hechizo de fuego
```

---

## Bloque de progresión

Estos parámetros controlan si la habilidad puede mejorar con el uso y cómo lo hace. Todos son opcionales con defaults seguros: una skill sin estos campos se comporta exactamente igual que antes de que existiera el sistema de progresión.

**La clave que activa la progresión es `base_success_rate > 0`.** Si es `0` (el default), la skill no participa en ningún sistema de mejora.

---

### `base_success_rate`
**Tipo:** `int` — **Rango:** `0–100` — **Default:** `0`

Valor inicial de la habilidad al registrar al personaje, expresado como porcentaje de éxito (0–100). Este es el valor que subirá con la práctica, los libros y los entrenadores.

Determina además la dificultad de mejorar mediante la **tirada inversa**: cuanto más alto es el valor, más difícil es que la tirada lo supere y por tanto más difícil mejorar.

`0` significa que la skill no tiene progresión — no genera ticks, no se puede mejorar, no aparece en el sistema de aprendizaje.

| Referencia | Valor |
|---|---|
| Habilidad difícil de dominar (ataque pesado) | `25` |
| Habilidad estándar (ataque básico) | `40` |
| Habilidad de apoyo (esquiva) | `50` |
| Habilidad innata (sprinting) | `60` |

---

### `stress_type`
**Tipo:** `String` (enum) — **Default:** `"PHYSICAL"`

Tipo de cansancio que acumula el personaje cada vez que usa la habilidad con éxito en combate. El `StressSystem` gestiona dos barras separadas de fatiga.

| Valor | Cuándo usarlo |
|---|---|
| `PHYSICAL` | Habilidades de combate físico, movimiento, atletismo |
| `MENTAL` | Habilidades mágicas, de concentración o cognitivas |

El cansancio acumulado penaliza la tirada de mejora: cuanto más fatigado está el personaje, más difícil es aprender. Ver el documento de sistema de aprendizaje para más detalle.

---

### `attribute_weights`
**Tipo:** `Dictionary` — **Default:** `{}`

Pesos de los atributos del personaje que influyen en la velocidad de mejora de la skill. Un personaje con los atributos adecuados tiene un pequeño bonus en el umbral de la tirada de mejora — no garantiza el éxito, pero lo facilita ligeramente.

El formato es `{ "atributo": peso }`. Los pesos no necesitan sumar 1.0 — el sistema los normaliza automáticamente.

```gdscript
# Ataque ligero — depende más de la destreza que de la fuerza
attribute_weights = { "dexterity": 0.6, "strength": 0.4 }

# Ataque pesado — depende más de la fuerza
attribute_weights = { "strength": 0.7, "dexterity": 0.3 }

# Hechizo de fuego — depende de la inteligencia y la sabiduría
attribute_weights = { "intelligence": 0.8, "wisdom": 0.2 }

# Sin pesos — no usa atributos (skill sin attribute_weights)
attribute_weights = {}
```

**Cálculo del bonus:**
```
media_ponderada = Σ(valor_atributo × peso) / Σ(pesos)
bonus = int(media_ponderada × 0.5)
umbral_efectivo = valor_skill + bonus
```

Ejemplo con STR=12, DEX=14 y `{ dexterity: 0.6, strength: 0.4 }`:
```
media = (14×0.6 + 12×0.4) / 1.0 = 13.2
bonus = int(13.2 × 0.5) = 6
```

---

### `prerequisite_requirements`
**Tipo:** `Dictionary` — **Default:** `{}`

Requisitos que deben cumplirse para que esta skill pueda desbloquearse. El formato es `{ "skill_id": umbral_int }` donde `umbral_int` es el porcentaje mínimo que debe tener esa skill.

Reemplaza al antiguo campo `prerequisites: Array[String]` — más expresivo porque incluye el umbral de porcentaje, no solo la presencia de la skill.

```gdscript
# Ataque pesado — requiere Ataque ligero con al menos 50%
prerequisite_requirements = { "skill.attack.light": 50 }

# Hechizo avanzado — requiere dos skills con umbrales distintos
prerequisite_requirements = {
    "skill.magic.fireball": 60,
    "skill.magic.mana_control": 40
}

# Umbral 0 — solo necesita estar desbloqueada, sin mínimo de porcentaje
prerequisite_requirements = { "skill.attack.light": 0 }

# Sin prerequisitos — se puede desbloquear directamente
prerequisite_requirements = {}
```

`SkillSystem.unlock_skill()` comprueba para cada entrada que:
1. La skill prereq esté desbloqueada (`is_unlocked = true`)
2. Su valor actual sea `>= umbral` (si el umbral es `> 0`)

Si alguna condición falla, rechaza la operación y emite `skill_unlock_failed`.

**Relación con `requires_unlock`:**

| `requires_unlock` | `prerequisite_requirements` | Comportamiento |
|---|---|---|
| `false` | `{}` | Disponible desde el inicio |
| `false` | `{ "x": 50 }` | Se desbloquea automáticamente cuando se cumplen los prereqs |
| `true` | `{}` | Requiere evento narrativo — no se desbloquea automáticamente |
| `true` | `{ "x": 50 }` | Requiere evento narrativo Y que los prereqs estén cumplidos |

**Helpers disponibles en `SkillDefinition`:**
```gdscript
has_prerequisites()                          # → bool
get_prerequisite_ids()                       # → Array de IDs
get_prerequisite_threshold("skill.attack.light")  # → int
```

**Impacto en la UI del árbol de habilidades:**

Los prerequisitos determinan el **tier visual** de la skill en `SkillTreeScreen`. El tier se infiere automáticamente — no es un campo separado:
- Sin prerequisitos → tier 1 (fila superior)
- Prerequisitos en tier 1 → tier 2
- Prerequisitos en tier 2 → tier 3

El panel lateral del árbol muestra cada prerequisito con ✓/✗ según si está cumplido.

---

### `difficulty`
**Tipo:** `float` — **Mínimo:** `> 0.0` — **Default:** `1.0`

Multiplicador base de dificultad de la skill. Modifica el umbral de la tirada de mejora de forma global.

`1.0` es la dificultad estándar. Valores mayores hacen la skill más difícil de mejorar en todo su rango. En la mayoría de los casos conviene ajustar la dificultad con `difficulty_scaling` en vez de con este campo.

```
difficulty = 1.0    # dificultad estándar
difficulty = 1.5    # 50% más difícil de mejorar
difficulty = 2.0    # el doble de difícil
```

---

### `max_ticks_per_combat`
**Tipo:** `int` — **Default:** `0`

Número máximo de ticks de mejora que se pueden acumular por combate. Evita el grinding: no importa cuántas veces se use la habilidad con éxito en el mismo combate, solo contarán hasta este límite.

`0` usa el valor global por defecto (`3`). Cualquier valor mayor que `0` sobreescribe ese global para esta skill concreta.

| Referencia | Valor |
|---|---|
| Usar el global (3 ticks) | `0` |
| Skill de ataque estándar | `2` |
| Skill muy repetitiva | `1` |
| Skill que permite más práctica | `4` o `5` |

---

### `difficulty_scaling`
**Tipo:** `Dictionary` — **Default:** `{}`

Penalizaciones adicionales al umbral de mejora que se activan cuando la habilidad supera ciertos valores. Implementa los **soft caps**: a partir de ciertos niveles, mejorar se vuelve progresivamente más difícil.

El formato es `{ "umbral": penalización }` donde ambas son strings que se convierten a int. El sistema aplica la penalización más alta cuyo umbral sea menor o igual al valor actual.

```gdscript
# Soft cap a partir de 70 (+5 al umbral) y otro a partir de 90 (+15)
difficulty_scaling = { "70": 5, "90": 15 }
```

Con un valor actual de 75 y `difficulty_scaling = { "70": 5, "90": 15 }`:
```
umbral_base  = 75 (valor actual)
penalización = 5  (se activa el umbral de 70, el de 90 todavía no)
umbral_final = 75 + 5 = 80
→ la tirada necesita sacar más de 80 para mejorar
```

Con valor actual de 92:
```
umbral_base  = 92
penalización = 15 (se activa el umbral de 90)
umbral_final = 92 + 15 = 107
→ casi imposible mejorar sin bonus de atributos o entrenador de alto nivel
```

Si el diccionario está vacío, no hay soft cap — la dificultad crece solo por la tirada inversa natural.

---

### `requires_unlock`
**Tipo:** `bool` — **Default:** `false`

Determina si la skill comienza bloqueada y necesita un evento narrativo para poder usarse y mejorarse.

| Valor | Comportamiento |
|---|---|
| `false` | La skill se registra disponible directamente al crear al personaje |
| `true` | La skill empieza bloqueada. No aparece en la barra de combate ni puede mejorarse hasta que un NPC (maestro) o evento narrativo la desbloquee |

Compatible hacia atrás: todos los `.tres` existentes sin este campo se comportan como `false`.

Cuando `requires_unlock = true`, los `prerequisites` se comprueban en el momento del desbloqueo.

---

## Resumen rápido — campos por tipo de skill

| Campo | Skill de combate | Skill de exploración | Skill narrativa |
|---|---|---|---|
| `id` | ✅ obligatorio | ✅ obligatorio | ✅ obligatorio |
| `name_key` | ✅ obligatorio | ✅ obligatorio | ✅ obligatorio |
| `description_key` | recomendado | recomendado | opcional |
| `mode` | `COMBAT` | `EXPLORATION` | `NARRATIVE` |
| `subcategory` | `MELEE` / `RANGED` | `EXPLORATION` | `NARRATIVE` |
| `category` | `PHYSICAL` / `MAGIC` | `PHYSICAL` / `UTILITY` | `MENTAL` / `UTILITY` |
| `costs` | stamina o mana | stamina típico | `{}` |
| `base_cooldown` | 1.0–5.0 | 0.0–2.0 | `0.0` |
| `target_type` | `SINGLE_ENEMY` típico | `SELF` típico | `SELF` |
| `range_type` | según arma | `MELEE` o `SHORT` | `MELEE` |
| `effects` | DAMAGE y/o BUFF | BUFF o vacío | vacío |
| `tags` | categoría de ataque | categoría de uso | categoría narrativa |
| `base_success_rate` | 25–60 si mejora | 40–70 si mejora | `0` |
| `stress_type` | `PHYSICAL` o `MENTAL` | `PHYSICAL` | — |
| `attribute_weights` | fuerza/destreza | según skill | — |
| `prerequisite_requirements` | `{ "skill_id": umbral }` | `{}` típico | `{}` |
| `difficulty` | `1.0` típico | `1.0` típico | — |
| `max_ticks_per_combat` | `2` típico | `0` (global) | — |
| `difficulty_scaling` | `{ "70": 5, "90": 15 }` típico | opcional | — |
| `requires_unlock` | `true` si avanzada | `false` típico | `false` |

---

## Ejemplos completos

### Ataque ligero
```
id:                       "skill.attack.light"
name_key:                 "SKILL_ATTACK_LIGHT_NAME"
mode:                     COMBAT
subcategory:              MELEE
category:                 PHYSICAL
costs:                    { stamina: 10.0 }
base_cooldown:            1.5
target_type:              SINGLE_ENEMY
range_type:               MELEE
effects:                  [ { type: DAMAGE, value: 1.2, duration: 0.4 } ]
tags:                     ["attack", "melee", "basic", "physical"]
base_success_rate:        40
stress_type:              PHYSICAL
attribute_weights:        { dexterity: 0.6, strength: 0.4 }
max_ticks_per_combat:     2
prerequisite_requirements: {}
requires_unlock:          false
```

### Ataque pesado
```
id:                       "skill.attack.heavy"
name_key:                 "SKILL_ATTACK_HEAVY_NAME"
mode:                     COMBAT
subcategory:              MELEE
category:                 PHYSICAL
costs:                    { stamina: 25.0 }
base_cooldown:            3.0
target_type:              SINGLE_ENEMY
range_type:               MELEE
effects:                  [ { type: DAMAGE, value: 2.0, duration: 0.6 } ]
tags:                     ["attack", "melee", "heavy", "physical"]
base_success_rate:        25
stress_type:              PHYSICAL
attribute_weights:        { strength: 0.7, dexterity: 0.3 }
max_ticks_per_combat:     2
prerequisite_requirements: { "skill.attack.light": 50 }  ← requiere Ataque ligero ≥ 50%
requires_unlock:          true
```

### Esquiva
```
id:                       "skill.combat.dodge"
name_key:                 "SKILL_DODGE_NAME"
mode:                     COMBAT
subcategory:              MELEE
category:                 UTILITY
costs:                    { stamina: 15.0 }
base_cooldown:            2.0
target_type:              SELF
range_type:               MELEE
effects:                  [
                            { type: BUFF, buff_type: "evasion", duration: 0.5, value: 100.0 },
                            { type: BUFF, buff_type: "guaranteed_hit", duration: 1 }
                          ]
tags:                     ["dodge", "defensive", "buff", "tactical"]
base_success_rate:        0   ← sin progresión
prerequisite_requirements: {}
requires_unlock:          false
```

---

*Los campos no declarados en un `.tres` toman el valor por defecto definido en `skill_definition.gd`. Una skill sin bloque de progresión funciona exactamente igual que antes de la v2. El campo `prerequisites: Array[String]` fue reemplazado por `prerequisite_requirements: Dictionary` en el spike SkillTreeScreen — todos los `.tres` existentes deben migrar el campo.*
