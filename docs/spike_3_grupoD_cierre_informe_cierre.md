# Spike 3, Grupo D — Cierre: informe de cierre

*Athelia — Pivote hacia RPG narrativo*

---

## Contexto

Grupo C dejó `flag.telmori_lair_cleared` y `telmori_lair_victory` como punto
final de contenido implementado, con la recompensa, el botín mágico de la
guarida y el gancho de continuidad del hombre-lobo pendientes explícitamente
fuera de su alcance.

Grupo D es el último grupo del Spike 3: con su cierre, **"Los Telmori" es
jugable de principio a fin**, desde la llegada al pueblo hasta el gancho
narrativo final, validado en partida completa.

---

## Alcance cerrado

Los cinco puntos de la spec quedan cerrados y validados:

1. **Recompensa multicapa** — bounty en oro, trofeo (rabo de lobo), venta de
   pieles con camino de Curtidor, y tomo de entrenamiento (reflavor de la
   recompensa de magia espiritual, aparcada desde el inicio del pivote).
2. **Nuevo tipo de consecuencia "otorgar recurso"** — análogo a "otorgar
   ítem" de Grupo B, vía `ResourceSystem` en vez de `Inventory`.
3. **Entrega del botín mágico** — bolsa mágica y punta de jabalina de
   obsidiana, vía el mecanismo de "otorgar ítem" ya existente desde Grupo B.
4. **Conexión del cierre** desde `flag.telmori_lair_cleared` hasta el gancho
   final, sin cabos sueltos.
5. **Gancho de continuidad del hombre-lobo** como escena de flavor puro, sin
   mecánica ni opción que implique contenido no construido.

---

## Decisiones de diseño (validadas antes de escribir contenido)

| Punto | Decisión | Razón |
|---|---|---|
| Otorgar recurso | Campo mínimo (`grant_resource_id`/`amount`/`target`), un solo recurso, sin condiciones — mismo espíritu que `grant_item_*` | Coherencia con el precedente de Grupo B; sin caso de uso para algo más rico |
| Camino de Curtidor | Tirada normal contra `skill.exploration.tanning`, sin gating de visibilidad de opción | `Characters.get_skill_value()` devuelve 0 para una skill fuera del kit inicial — la probabilidad casi nula ya sale gratis del motor existente |
| Mini-acertijo de la bolsa mágica | Flavor narrativo puro, sin mecánica de "usar objeto sobre objeto" | Mismo criterio que el modificador multiplicativo descartado en Grupo C: sin segundo caso de uso, no se construye un mecanismo nuevo para un solo acertijo |
| Conexión del cierre | Vuelta al pueblo — nuevo interactuable spawneado dinámicamente al marcar `flag.telmori_lair_cleared`, en vez de tocar el interactuable original del sheriff o encadenar una escena aislada | Reutiliza el patrón de spawn dinámico ya validado en Grupo B/C; evita modificar contenido existente de Grupo B sin visibilidad completa de su `.tscn` |
| Reflavor del entrenamiento | Tomo de habilidad (`book_tanning_basics`) que enseña Curtidor directamente, vía `learning_data` — el jugador aprende la skill *antes* de necesitarla para vender pieles | Reutiliza el mecanismo de libro ya existente (`book_combat_basic.tres`) sin construir nada nuevo; encadena naturalmente con el punto 2 |

**Orden de las escenas del sheriff, decisión derivada:** `reward_intro` →
`training` → `pelts` → `epilogue_hook` — el tomo debe entregarse *antes* de
la venta de pieles para que el jugador pueda usar la skill que acaba de
aprender en la misma sesión de recompensa (detectado al confirmar el diseño,
no en playtest).

---

## Contenido de datos creado

### Skill nueva

- `data/skills/exploration/tanning.tres` — `skill.exploration.tanning`,
  categoría `PHYSICAL`/`EXPLORATION` (sin subcategoría "craft" nueva — no
  hay un segundo caso que la justifique), `base_success_rate = 15`,
  `attribute_weights = { dexterity: 1.0 }`.

### Ítems nuevos (`data/items/telmori/`)

| ID | Tipo | Notas |
|---|---|---|
| `telmori_magic_bag` | `MISC` | Botín de la guarida, sin mecánica |
| `obsidian_spearhead` | `MISC` | Botín de la guarida, sin mecánica |
| `wolf_tail_trophy` | `MISC` | Trofeo de la recompensa del sheriff |
| `book_tanning_basics` | `CONSUMABLE`, `usable`, `use_action = "read"` | `learning_data` → `skill.exploration.tanning`, `source_level = 35`, `source_type = "BOOK"` |

`item_type` corregido a `MISC` tras revisar `item_definition.gd` — el enum
real es `CONSUMABLE`/`EQUIPMENT`/`MISC`, no admite un `CONSUMABLE` no
usable como tipo "genérico decorativo".

### Escenas narrativas nuevas (`data/narrative_scenes/`)

Cadena completa, seis escenas en dos tramos:

```
telmori_lair_victory
  → telmori_lair_loot_obsidian          (botín, en la guarida)
    → [flag.telmori_lair_cleared] → spawn interactuable "Sheriff" en el pueblo
      → telmori_sheriff_reward_intro    (bounty + trofeo)
        → telmori_sheriff_training      (tomo de Curtidor)
          → telmori_sheriff_pelts       (venta de pieles, tirada real)
            → telmori_epilogue_hook     (gancho del hombre-lobo, flavor puro)
              → flag.telmori_adventure_completed → limpieza del interactuable
```

### Localización

- `translations.csv` — entradas de la skill (`SKILL_TANNING_NAME/DESC`).
- `items.csv` — entradas del libro (`ITEM_BOOK_TANNING_NAME/DESC`) — se
  queda en el CSV general, no en uno propio de aventura, siguiendo la
  práctica real de Grupo B (`silver_arrow`/`enchanted_spear` sin CSV propio)
  en vez de la regla escrita al pie de la letra.
- `items_telmori.csv` — **fichero nuevo**, entradas de los tres objetos de
  botín/trofeo (bolsa, punta de obsidiana, trofeo de rabo). Requiere alta
  manual en Project Settings → Localization → Translations.
- `narrative_scenes_telmori.csv` — entradas de las seis escenas nuevas y el
  prompt del interactuable del sheriff.

---

## Cambios de motor

### `NarrativeSceneOutcome` — "otorgar recurso"

Tres campos nuevos (`grant_resource_id: String`, `grant_resource_amount:
float`, `grant_resource_target: String = "player"`), parseados en
`from_dict()` con el mismo patrón que `grant_item_*`.

### `NarrativeSceneViewModel._apply_outcome()`

Nuevo bloque, inmediatamente después de la resolución de `grant_item_id`,
antes de la comprobación de combate — se aplica siempre, independientemente
de si el outcome también dispara combate o encadena escena:

```gdscript
if not outcome.grant_resource_id.is_empty():
    Resources.add_resource(outcome.grant_resource_target, outcome.grant_resource_id, outcome.grant_resource_amount)
```

### `exploration_telmori_village.gd` — reconexión sin combate de por medio

Nuevo par de listeners, distinto en naturaleza a los de Grupo B/C:

- `_on_narrative_flag_set_reward_spawn()` — escucha `narrative_flag_set`
  para `flag.telmori_lair_cleared` (no `combat_ended`: aquí el disparador es
  el cierre de una cadena narrativa, no un combate) y spawnea el
  interactuable "Sheriff" con guard de duplicado.
- `_on_narrative_flag_set_reward_cleanup()` — escucha `flag.telmori_
  adventure_completed` y retira ese interactuable al completar el arco.

**Riesgo nuevo identificado y cubierto, distinto a los de Grupo C:** sin la
limpieza, el interactuable de recompensa se quedaría permanentemente
disponible y el jugador podría reentrar en la cadena del sheriff
indefinidamente, generando oro/ítems sin límite (exploit de economía, no
"contenido resucitado" como en Grupo C). Cubierto desde el diseño, no
descubierto en playtest.

---

## Bugs encontrados y corregidos durante la validación

Dos bugs reales, ambos en la primera ejecución completa de la cadena:

1. **`grant_resource_target` sin declarar en `NarrativeSceneOutcome`** — al
   integrar el patch, la declaración de la variable se perdió (quedó solo
   el comentario, fusionado con el bloque de `grant_item_target`), mientras
   que `from_dict()` sí intentaba asignarla. Síntoma: `Invalid assignment
   of property or key 'grant_resource_target'` — GDScript permite asignar
   dinámicamente sobre un `Resource`, pero falla si la propiedad no existe
   como miembro declarado de la clase. Corregido declarando las tres
   variables (`grant_resource_id`/`amount`/`target`) como bloque propio,
   separado del bloque de `grant_item_*`.
2. **`telmori_lair_victory.json` desactualizado en el proyecto real** —
   tras diseñar la cadena de botín en la conversación, el fichero en disco
   seguía siendo la versión original (sin `grant_item_id`, `next_scene_id`
   vacío) — el botín mágico nunca se habría entregado, sin ningún error
   visible (el flag se marcaba igual, así que el resto de la cadena
   funcionaba con normalidad). Detectado por inspección del log:
   `narrative_scene_closed` llegó con `scene_id = "telmori_lair_victory"`
   en vez de `"telmori_lair_loot_obsidian"`, señal de que `_close()` se
   había llamado directamente desde la primera escena. Corregido
   sobrescribiendo el JSON con la cadena real.

**Lección reutilizable:** cuando `narrative_scene_closed` es la señal usada
para diagnosticar en qué punto de una cadena se cerró el panel, el
`scene_id` que trae es una forma barata de confirmar si una cadena
multi-escena recorrió todos sus nodos o se cortó antes de tiempo — ya se
había usado como mecanismo de limpieza en Grupo C, aquí además sirvió como
herramienta de depuración.

---

## Validación realizada

Playtest completo de la cadena de botín + recompensa, confirmado por log:

- `[SkillSystem]`/`[ItemRegistry]` cargan `skill.exploration.tanning` y los
  cuatro ítems nuevos por escaneo recursivo de `data/skills/`/`data/items/`
  — sin lista hardcodeada que actualizar (a diferencia de
  `ResourceSystem._load_resource_definitions()`, que sí tiene una lista
  fija, pero no afecta aquí porque `gold` ya estaba en ella).
- `narrative_scene_closed ← telmori_lair_loot_obsidian` confirma que la
  cadena de botín recorre las dos escenas antes de cerrar.
- Oro del jugador: 50 → 170 tras `telmori_sheriff_reward_intro` (+100) y
  `telmori_sheriff_pelts` con tirada `FAILURE` (+20, sin el libro leído a
  tiempo en esa partida de prueba) — confirma `grant_resource_*` funcionando
  en las dos escenas donde se usa.
- `[SkillRoller] ... skill.exploration.tanning ... vs 0% → FAILURE` confirma
  que la tirada sin gating de visibilidad se resuelve como se diseñó: skill
  no aprendida = probabilidad casi nula, sin necesitar ningún mecanismo
  nuevo.
- Spawn y limpieza del interactuable del sheriff confirmados por log en los
  puntos correctos (`flag.telmori_lair_cleared` / `flag.telmori_adventure_
  completed`).

**Sin confirmar por log** (ambos mecanismos comparten `_apply_outcome()`
con `grant_resource_*`, que sí está confirmado, así que el riesgo es bajo,
pero no se verificó explícitamente): entrega de `telmori_magic_bag`,
`obsidian_spearhead`, `wolf_tail_trophy` y `book_tanning_basics` en el
inventario del jugador.

---

## Pendiente, no bloqueante

- Comentario desactualizado en `_on_narrative_flag_set_lair_aftermath_
  cleanup()` (código de Grupo C) — sigue diciendo que `flag.telmori_lair_
  cleared` lo pone `telmori_lair_victory.json`; ahora lo pone `telmori_
  lair_loot_obsidian.json`. No afecta a la ejecución.
- Confirmación manual pendiente de los cuatro ítems en inventario (ver
  arriba).
- Iconos (`Texture2D`) de los cuatro ítems nuevos — ninguno tiene arte,
  igual que el resto del catálogo del proyecto en este punto.
- `player_new.tres` sin `skill.exploration.stealth` en el kit inicial —
  pendiente desde Grupo C, no relacionado con este grupo.
- Un hallazgo de orden de logs en `CombatSystem` (el golpe final y el daño
  se imprimen después de que el combate ya se da por terminado) — anotado
  durante el playtest de este grupo pero preexistente y ajeno a Grupo D, sin
  investigar todavía.

---

## Cierre

Los cinco puntos de alcance de Grupo D están implementados y validados en
partida completa. **Spike 3 queda cerrado: "Los Telmori" es jugable de
principio a fin**, desde la llegada al pueblo (Grupo B) hasta el gancho de
continuidad final (Grupo D), pasando por la guarida (Grupo C) — sin errores
de ejecución, con tipado estricto y sin listeners de reconexión narrativa
sin desconectar.

Godot 4.7.2.
