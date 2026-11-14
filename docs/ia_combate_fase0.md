# Athelia — Informe de Fase 0 de la IA de combate

**Fecha:** 2026-11-11 · **Spec revisada:** `docs/ia_combate_spec_v1_6.md` · **Motor:** Godot 4.7.2

**Estado:** **Fase 0 cerrada** el 2026-11-11. Las 7 decisiones están tomadas (sección 11) y las búsquedas están hechas. Quedan 5 comprobaciones en el editor (sección 9). **IA-1 no debe empezar hasta completar la fase IA-0** (`docs/ia_combate_ia0_plan.md`, spec en `docs/ia_combate_spec_v1_7.md`).

Marcas de fiabilidad: ✅ verificado con la salida de PowerShell · 📖 deducido de leer el código · ❓ por comprobar.

---

## 1. Resumen

- **Reutilizable tal cual:** `SkillRoller` (tirada y grados), `AttributeResolver`, `ResourceSystem`, `SkillSystem.can_use` y `get_entity_skill_snapshot`, el sistema de buffs de `CombatSystem`, el flujo por fases de `GameLoop`, `EventBus` como fuente de telemetría, `CombatEncounterDefinition`/`NarrativeSceneOutcome` como cadena de datos del encuentro.
- **No existe y hay que crear:** candidatas, daño esperado, probabilidad de éxito expuesta, snapshot de condiciones visibles, RNG de combate sembrable, telemetría, perfiles de comportamiento.
- **Contradice la spec:** D2 (el *last stand* ya existe), el contrato `Combat` ↔ IA síncrono (hoy es asíncrono por `EventBus`), la moral (ya hay moral de grupo), la huida y la defensa (solo del jugador), el guardado a mitad de combate (no existe).
- **Defectos de motor que bloquean la IA** (sección 6): turno colgado ante un fallo de acción, estado de combate que se arrastra al siguiente combate, guarda contradictoria en `_incapacitate_player`, tiempo real en cooldowns y regeneración.

---

## 2. Los 12 puntos

### 1. Combatientes y orden de turno ✅📖
- Los combatientes son `String` ids. Los roles se definen por exclusión: `GameLoop.get_active_enemies()` = `turn_order` sin el jugador ni los miembros de `Party`.
- El orden es por fases fijas: jugador → companions (orden de `Party.get_active_members()`) → enemigos (orden de `turn_order`).
- `turn_order` se calcula una vez por iniciativa (`dexterity + 0,5·wisdom`, descendente). Solo ordena a los enemigos entre sí. `sort_custom` no es estable y los enemigos del mismo tipo empatan, así que **el orden entre ellos no es reproducible**.
- Los refuerzos se añaden al final de `turn_order` y actúan desde la ronda siguiente.
- Estados: el jugador incapacitado se queda en `turn_order`; el companion incapacitado es un flag en `Party`; el enemigo muerto o huido se borra de `participants` y `turn_order`.

### 2. Dónde se decide el objetivo enemigo ✅
- `EnemyAI._pick_target()`: el jugador si tiene PV; si no, el primer companion activo con PV. **Hoy los enemigos nunca atacan a Mira mientras el jugador está en pie.**
- Cadena de ejecución: `enemy_turn_started(id)` → `EnemyAI` (espera 0,5 s) → `player_action_requested {actor, skill_id, target}` (nombre heredado, lo usan también los enemigos y Mira) → `GameLoop._on_player_action_requested` (valida fase) → `execute_combat_action` → `CombatSystem`.
- **Punto de inserción:** sustituir `_pick_target()` y `_decide_and_act()` de `EnemyAI` por una llamada a `CombatAI`, sin tocar `CombatSystem`. El perfil se asigna en `CombatProductionScene._spawn_enemy_ai()`, que ya crea un nodo por enemigo.
- Único camino de producción hacia el combate: `NarrativeSceneViewModel` → `GameLoop.start_combat(ids, encounter, victory_scene_id)`. La llamada de `ExplorationController:189` es el camino vestigial.

### 3. Candidatas, probabilidad y daño esperado ✅📖
**No existe API de candidatas ni de estimaciones.**

| Dato de la spec | Cómo se obtiene hoy | Acción |
|---|---|---|
| Lista de acciones | `Skills.get_entity_skill_snapshot(id)` (pública: tags, costes, `target_type`, `is_unlocked`) | Reutilizar. Falta cooldown restante y legalidad |
| Legalidad y coste | `Skills.can_use(id, skill)` (cooldown en segundos + `ResourceSystem.can_pay`) | Reutilizar; ver D4 (reloj) |
| `success_chance` | Solo atacante: acierto si `roll ≤ skill_value` (+`precision_up`), pifia con `roll ≥ 98`; `guaranteed_hit` lo fuerza | Exponer una función en `SkillRoller`, junto a `_determine_result`, para no duplicar la fórmula |
| `expected_damage` | `_process_skill_effects` (base × valor × crítico/especial) + `_apply_damage` (armadura, 4 buffs, defensa, evasión). Está mezclado con efectos secundarios | Extraer la parte pura. **No copiar la fórmula en la IA** |
| `threat` | No existe | Definir en `Combat` con datos observables |
| Condiciones visibles | `CombatSystem._active_buffs` es privado; solo `has_buff`. `_get_buff_value` es privado | API pública de lectura + lista de buffs «visibles» en datos |

**D1 (información observable):**
- La probabilidad de acierto depende solo del atacante → cumple D1.
- `armor_rating` sale solo del equipo (fórmula con base 0 y sin términos) → observable. Los enemigos tienen `equipment_slots` vacío, así que su armadura es 0 y `threat` basada en arma no tiene de dónde salir; hace falta un dato en la definición del enemigo.
- Efectos del objetivo sobre el daño: `vulnerable`, `damage_reduction`, `weakened`, evasión del jugador y defensa del jugador. Hay que decidir cuáles son visibles.
- `CompanionAI` ya usa PV exactos del enemigo (`_pick_weakest_enemy`). Pasarlo a `hp_state` cambia su comportamiento.

**Magnitudes reales** (para elegir `reference_damage`): con `base_damage = 5 + 0,8·fue + 0,2·des`, un guerrero Telmori hace ≈5,5 por golpe (×0,3, acierto 55 %); un lobo ≈4,7 (acierto 50 %); Mira con ataque ligero ≈19 (acierto 75 %); el jugador, ≈22. **Un único `reference_damage` global dejaría los golpes enemigos casi siempre en C ≈ 0,2.** Conviene normalizar contra los PV máximos del objetivo.

### 4. Acción de Mira y qué ve el ViewModel ✅
- Cadena: `companion_turn_started(id)` → `CompanionAI` (espera 0,6 s) → `player_action_requested` → `execute_combat_action`. `GameLoop` descarta acciones fuera de fase y señales de un actor que no es el del turno.
- La estrategia es de `Party` (`AGGRESSIVE`, `DEFENSIVE`, `AREA_FOCUS`, `BERSERKER`), con UI en la pantalla Party y guardado. **Las órdenes de la spec se solapan con una función que ya existe.**
- El kit de Mira en combate es solo `attack.light` (75 %) y `dodge`. `BERSERKER` elige la skill de mayor coste, y como `dodge` (15) cuesta más que `attack.light` (10), **alterna esquiva y ataque**. `dodge` solo da evasión al jugador, aunque `guaranteed_hit` sí funciona para ella.
- `CombatArenaViewModel` ya compone fichas, log y menú del jugador desde `EventBus`. El selector de órdenes va ahí, con el ViewModel como único contacto con el motor.

### 5. Huida del jugador ✅
- `flee_requested` → `EscapeModule.attempt_escape(nº de enemigos)`. El umbral es `20 + 10·enemigos` de estamina y se calcula al pedir huir, no al resolver.
- Se resuelve al inicio del siguiente turno del jugador: si hay estamina suficiente, se consume y `GameLoop.end_combat("escaped")`; si no, solo se emite `escape_failed`.
- Con 4 enemigos el umbral es 60, mayor que la estamina máxima típica (~40, `con·2 + fue·1,5`): la huida de una guarida grande es imposible por números.
- Con Mira incapacitada: `PartyManager` revive a los incapacitados con 1 PV en `victory` y `escaped`. Nadie queda atrás.
- Resultado: `"escaped"` (la spec dice `"player_fled"`).

### 6. Fin de combate y derrota ✅
- `end_combat(result)` admite `victory`, `defeat` y `escaped`; emite `combat_ended(result: String)`. Escuchan: `PartyManager`, `SceneOrchestrator`, `SkillProgression`, `PlayerCombatController`, `CombatProductionScene`, `CombatArenaViewModel`.
- **Derrota:** `_check_combat_conditions()`: con el jugador a 0 PV, derrota solo si no hay companions o todos están incapacitados (*last stand*). Si Mira sigue en pie, el combate continúa y, si gana, `_resolve_last_stand_victory` revive al jugador con 1 PV. **Esto contradice D2.**
- **Defecto:** `_incapacitate_player()` empieza con `if _is_player_incapacitated(): return`, y esa función es `hp ≤ 0`. Cuando se llama, el jugador ya está a 0 PV: **vuelve siempre sin hacer nada**. Nunca se pone `flag.player_downed` ni se emite `player_incapacitated`. El `if` del bloque «Jugador a 0 HP» (`hp ≤ 0 and not incapacitado`) es una contradicción y no se ejecuta. El *last stand* funciona solo por el tercer bloque. Comprobación: en una derrota, el Output no contiene «Player incapacitated — last stand begins».
- Los estados individuales de los combatientes no se entregan a la narrativa.

### 7. Estados de personaje ✅📖
- No hay enum de estado. Jugador incapacitado = PV ≤ 0. Companion incapacitado = lista en `Party`. Enemigo muerto o huido = fuera de `turn_order`; `DEAD` y `FLED` no se distinguen.
- Condiciones: los buffs de `_active_buffs` (`staggered`, `disarmed`, `evasion`, `guaranteed_hit`, `precision_up`, `critical_bonus`, `weakened`, `damage_bonus`, `vulnerable`, `damage_reduction`, `bleeding`, `resource_regen`, `resource_drain`).
- `CharacterState.active_states` (estados temporales) nunca se llena en producción.

### 8. Guardado y RNG ✅📖❓
- **Guardado:** `SaveSystem` guarda jugador, narrativa, economía y `Party`. **No guarda estado de combate** y `save_game` no mira el estado del juego. Los savepoints son narrativos (fuera de combate) y F9 está desestimado.
- **Guardado de Mira:** `Party.get_save_state()` no incluye sus `skill_values` ni sus atributos, y guarda `definition_id = companion_id`. La progresión de Mira se pierde al cargar. Es un defecto de motor aparte.
- **RNG existentes:** `SkillRoller.roll_skill` (global, estático; usado por `CombatSystem`, `NarrativeSceneViewModel`, `WorldObjectSystem`); `SkillProgressionService` (2 `randi_range`, solo al final del combate); `world_object_bridge` (loot, `randf`); `damage_number.gd` (`randf_range` visual, que **desplaza el RNG global**); `CharacterCreationViewModel` (único con su propio `RandomNumberGenerator`).
- **Consecuencia:** para reproducir un combate basta con inyectar un RNG en `SkillRoller` para el combate y dejar fuera lo demás. `SkillRoller` es estático: su RNG sería una variable estática.
- ❓ En el editor: `RandomNumberGenerator.seed/state` y `make_read_only()` en 4.7.2.

### 9. Datos de enemigo y perfil ✅📖
- Los enemigos son `CharacterDefinition` `.tres` (`enemy_base`, `telmori_*`). El mapa `enemy_id → definition_id` viene del JSON narrativo (`combat_enemy_definitions`); los refuerzos usan un único `reinforcement_definition_id`.
- **Fuente natural del perfil:** `behavior_profile_id` en `CharacterDefinition` (hay que añadirlo también a `duplicate_definition()`, que copia los campos a mano).
- **HP:** `ResourceSystem.register_entity` crea el recurso al máximo base y lo recorta al máximo derivado; **`starting_resources` de los `.tres` no se aplica** a `ResourceSystem`. El lobo tiene 50 PV (con 10 × 5), no 30; el guerrero «débil» tiene 60, igual que el base. El comentario «50.0 HP fijo» de `NarrativeSceneViewModel` está obsoleto. 📖 (confirmar con `max_base` en `resource_definition.gd`).
- Los enemigos de la ruta narrativa se registran con todos los recursos (`health`, `stamina`, `gold`); los **refuerzos solo con `health`**. `focus` no se carga en `ResourceSystem`: las skills con coste de foco (p. ej. `fireball`) no se pueden pagar.
- Las skills del enemigo están fijadas a mano en `CombatProductionScene` (`skill.enemy.basic_attack`); `CharacterDefinition.skills` no se lee. Esa skill no tiene coste ni cooldown.
- Datos de encuentro: la sorpresa y los refuerzos se usan en `telmori_day2_approach`, `telmori_lair_alerted` y `telmori_lair_stealth`; ❓ falta comprobar si algún contenido usa `morale_threshold_pct`.

### 10. Infraestructura de pruebas ✅
- Son pares `.gd` + `.tscn` que se lanzan con F6, con un `_assert(cond, texto)` y contadores `[PASS]/[FAIL]`. Sin framework, sin `addons/`, sin código de salida.
- `test_defense.gd` es un stub de 2 líneas. `test_group_morale.gd` toca campos privados de `GameLoop` y guarda/restaura su estado a mano. Hay precedente de mocks en `test_narrative_scene_viewmodel.gd`. No hay pruebas de `SkillRoller` ni de `CombatSystem`.
- Un `quit(código)` al final de cada escena permitiría ejecutarlas con `--headless`.

### 11. Log existente ✅
- Solo `print` con prefijo `[CombatSystem]`. El único `FileAccess.WRITE` del proyecto es el guardado. El «log con IDs» del Spike 8 es el log de la interfaz (`LogEntryData`) y no se reutiliza.
- **`CombatTelemetry` se escribe desde cero** y se alimenta de `EventBus`: `combat_started`, `round_started`, `combat_action_executed` (incluye el diccionario del tiro), `combat_action_failed`, `character_damaged`, `character_died`, `buff_applied/expired`, `enemy_group_fled`, `reinforcement_spawned`, `combat_ended`. Solo `decision` exige un emisor nuevo en `CombatAI`.
- Dueño natural: `CombatProductionScene` (una instancia por combate, se libera al terminar). Su `queue_free()` es diferido, así que `combat_end` se escribe antes.
- `user://` es escribible (saves y `settings.cfg`). ❓ `flush()` en 4.7.2.
- `EventBus.resource_changed` declara sus parámetros como «old/new», pero `ResourceSystem` emite «actual/máximo». Es solo un error de nombres.

### 12. Git, `build_info.json` y hashes ✅
- Git 2.53 funciona en tu PowerShell. Hay un único script de editor (`test/test_tokens_alias.gd`) y ningún `EditorExportPlugin`. `.gitignore` no incluye `build_info.json`.
- El árbol está sucio (decenas de ficheros). Con `git_dirty` global, casi todas las ejecuciones se excluirían del análisis. **Propuesta:** calcularlo solo sobre las rutas relevantes (`core/ai`, `core/combat`, datos de IA), igual que `git_ai_path_commit`.
- Mientras no haya exportación, basta `OS.execute("git", ...)` desde el editor; `build_info.json` queda para cuando se exporte.
- `config_hash`: `JSON.stringify(dict, "", true)` ordena claves por defecto; ❓ confirmar en 4.7.2 junto con `HashingContext` SHA-256.
- `scenario_hash`: se puede construir con APIs públicas (`Characters.get_all_base_attributes`, `get_all_skill_values`, `Resources`, definición del enemigo, `GameLoop.get_current_encounter()`). Faltan las condiciones iniciales (buffs) y el equipo (`Equipment` no revisado).

---

## 3. Contenido exigido del informe de cierre

| Elemento | Respuesta |
|---|---|
| Partes de `Combat` reutilizables | Sección 1 |
| Información que puede dar `Combat` sin vulnerar D1 | Sección 2.3: acierto y armadura sí; buffs visibles por decidir |
| Cálculo actual de daño y probabilidad | Sección 2.3 |
| Estado del combate y guardado | Sección 2.8: no se guarda; propuesta en D6 |
| RNG | Sección 2.8 |
| Log reutilizable | Sección 2.11: ninguno |
| Información de git | Sección 2.12 |
| Estructura JSONL | La de la spec 11.3 es viable; construible desde `EventBus` salvo `decision` |
| `config_hash` / `scenario_hash` | Sección 2.12 |
| Pruebas | Sección 2.10 |

---

## 4. Contradicciones spec ↔ código

| # | Spec | Código | Salida propuesta |
|---|---|---|---|
| A | `execute_action` síncrono con `OK/STALE/ERROR` | Asíncrono por `EventBus`; motivos en texto libre; `combat_action_failed` sin oyente | Fachada con códigos de motivo y manejo del fallo en `GameLoop` |
| B | Moral individual y huida por `Combat` | Moral de grupo por PV en `GameLoop` + `enemy_group_fled` + `test_group_morale` | Decisión D5 |
| C | Candidatas `defense`/`recover`/`flee` para todos | Defender y huir solo del jugador, con módulos únicos | Skills `.tres` o candidatas nativas |
| D | `resource_cost` y `recover` | Estamina real con regeneración continua; refuerzos sin estamina | D3 y D4 |
| E | `outcome` = `victory`/`defeat`/`player_fled` con combatientes | `combat_ended(String)`, `"escaped"` | Mantener la señal y añadir una nueva con el resultado |
| F | D2: derrota inmediata | *Last stand* con Mira en pie | D1 |
| G | `expected_damage` sin segunda fórmula | Cálculo monolítico | Extraer la parte pura |
| H | RNG propio de la IA y del combate | RNG global | Inyección en `SkillRoller` |
| I | «Mira» única | `MAX_PARTY_SIZE = 3`, `CompanionAI` por companion | MVP con una aliada; el código ya es genérico |
| J | Órdenes de Mira | Estrategias de `Party` con UI y guardado | D2 |

---

## 5. Hallazgos adicionales

- **Fuga de huida pendiente:** `end_combat` no reinicia `EscapeModule`. Si el combate termina (muere el último enemigo o rompe la moral) con la huida pendiente, el siguiente combate se resuelve como `escaped` al empezar su primer turno. Se puede reproducir pidiendo huir con un enemigo casi muerto y Mira que lo remata.
- **Entidades enemigas que no se dan de baja** ❓: los ids se repiten entre combates (`telmori_1`...). Si no se desregistran, `_active_buffs` (sin llamadores de `clear_buffs` vistos) y la estamina de un combate pasan al siguiente. Hay que confirmarlo con la búsqueda.
- **`EnemyAI` cuelga el turno si no hay objetivo:** emite `{"skipped": true}` sin `actor` y `GameLoop` lo descarta. Hoy es latente.
- **`CombatProductionScene`** lee `Skills._entity_skills` (privado) cuando existe `Skills.has_entity()`.
- **`GameLoop`** no escucha `combat_action_failed`: un fallo de `request_use` deja el turno del jugador o de Mira esperando. La skill del enemigo no cuesta, así que hoy solo afecta al jugador (los atajos de teclado no validan el coste) y, en menor grado, a Mira.
- **Duración de buffs:** en los efectos `BUFF`, `duration` son **turnos del afectado** (en `DAMAGE` es la duración de la animación en segundos). Con `duration == 0` el buff pasa a «de un uso» y solo se consume en los tipos conocidos. Resuelve el pendiente del Spike 21.
- **Progresión de Mira** no se guarda (sección 2.8).
- `consume_pending_skill_modifier` no tiene llamadores: un bono «próxima tirada» nunca se aplica en combate.

---

## 6. Prerrequisitos de motor propuestos (fase IA-0)

1. `GameLoop` reacciona a `combat_action_failed` (cierra o salta la acción) y `EnemyAI`/`CompanionAI` emiten siempre un fin con `actor`.
2. `Combat` reinicia buffs, `EscapeModule` y `DefenseModule` al acabar el combate; las entidades enemigas se dan de baja.
3. Corregir la guarda de `_incapacitate_player`.
4. Reloj de combate por turnos (D4): `set_regen_paused` ya existe.
5. API pública de candidatas: `can_use` con motivo, cooldown restante, condiciones visibles.
6. Parte pura del daño esperado y `get_success_chance` en `SkillRoller`.
7. RNG inyectable en `SkillRoller`.
8. Desempate determinista de la iniciativa.
9. Códigos de motivo en `combat_action_failed` y `skill_failed`.

---

## 7. Pendientes de `estado_actual.md` que afectan al diseño

| Pendiente | Impacto |
|---|---|
| `_active_buffs` no se limpia | **Bloquea** la reproducibilidad y la simulación |
| Combate/Loadout: defender y huir sin `.tres`, ids hardcodeados | **Bloquea** las candidatas de Mira y los enemigos |
| Falta listador público de `SkillSystem` | Ya existe `get_entity_skill_snapshot`; faltan cooldown y legalidad |
| Motivos de fallo en texto libre | **Bloquea** `STALE`/`ERROR` |
| Skill con requisitos no cumplidos asignable | Afecta a la legalidad de las candidatas |
| `base_damage` vs `melee_damage` | Afecta a `reference_damage`, `expected_damage` y `threat` |
| Modificadores `attribute.<base>` ignorados por derivados | Bajo: la estimación hereda el mismo comportamiento |
| `ModifierApplicator` sin estados temporales | Las condiciones visibles solo salen de `_active_buffs` |
| `MAX_PARTY_SIZE = 3` | Afecta a «una sola Mira» y a las órdenes |
| Semántica de `NONE`/`ENEMY` en `target_type` | Afecta a los objetivos de las candidatas |
| `combat_hud`/`combat_arena_panel` con acceso directo a core | El selector de órdenes debe ir en el ViewModel |
| Derrota con 0 o 2 companions sin validar | Relevante para D1 |
| `combat_system_bak.gd`, `enemy_ai_backup.gd` | Borrar antes de IA-1: contaminan las búsquedas |
| F9/quickload desestimado | Condiciona el guardado de IA (D6) |

---

## 8. Decisiones (resueltas el 2026-11-11: ver sección 11)

| # | Decisión | Recomendación | ¿Bloquea? |
|---|---|---|---|
| 1 | D2 frente al *last stand* | Adaptar la spec: derrota cuando cae todo el grupo, y Mira combate sola (ya lo hace) | **Sí** |
| 2 | Órdenes de Mira frente a las estrategias de `Party` | Una sola; sustituir las estrategias, dar kit a Mira y revisar la pantalla Party | **Sí** |
| 3 | Acciones y estamina de enemigos | Estamina en todos los enemigos (también refuerzos) y 2-3 skills nuevas | IA-2 |
| 4 | Reloj: cooldowns y regeneración en segundos | Pasar a turnos dentro del combate (pausar regeneración y descontar por ronda) | **Sí** (IA-2) |
| 5 | Moral de grupo frente a individual | Mantener la de grupo sin tocar hasta IA-4 y decidir tras la búsqueda | IA-4 |
| 6 | Guardado a mitad de combate | Bloquear el guardado en `COMBAT_ACTIVE`; la orden de Mira se reinicia a `free` cada combate; sin guardado de IA | No |
| 7 | Datos de HP | Los `.tres` tienen `starting_resources` inertes; decidir si se borran o se aplican | No |

---

## 9. Verificaciones pendientes

**En el editor** (puedo preparar una escena de prueba cuando lo pidas): `seed/state` y `make_read_only()`; `FileAccess.flush()`; `OS.execute("git")` desde Godot; `HashingContext` SHA-256 con `JSON.stringify` ordenado; `max_base` de `health` y HP inicial real de un lobo.

**Búsquedas (PowerShell):**

```powershell
Get-ChildItem -Recurse -Include *.json,*.tres | Where-Object { $_.FullName -notmatch '\\.godot\\' } | Select-String -Pattern 'morale_threshold_pct' | Select-Object Path, LineNumber
Get-ChildItem -Recurse -Filter *.gd | Where-Object { $_.FullName -notmatch '\\.godot\\' } | Select-String -Pattern 'clear_buffs|unregister_entity|unregister_everywhere|SessionReset|EventBus\.skill_used|skill_used\.emit' | Select-Object Path, LineNumber, Line
Get-ChildItem -Recurse -Filter *.gd | Where-Object { $_.FullName -notmatch '\\.godot\\' } | Select-String -Pattern 'Characters\.(set_resource|modify_resource)|\.modify_resource\(|\.set_resource\(' | Select-Object Path, LineNumber, Line
```

---

## 10. Cambios propuestos para la spec v1.7

- §2 y §10: D2 pasa a *last stand*; añadir el estado «jugador caído, grupo luchando».
- §5.2: `reference_damage` relativo a los PV máximos del objetivo.
- §6: contrato asíncrono con códigos de motivo; `STALE` y `ERROR` se infieren de ellos.
- §8: reemplazar las estrategias de `Party` por las órdenes.
- §9: tratar la moral de grupo existente (D5).
- §10: mantener `combat_ended(String)` y añadir la señal con el resultado completo.
- §11: RNG de combate sin guardado; `git_dirty` por rutas.
- §12: pruebas con el patrón actual (`_assert`, escena + `quit(código)`).
- §15: añadir la fase **IA-0** de la sección 6 antes de IA-1.

## 11. Decisiones tomadas (2026-11-11)

| # | Decisión | Elección de Fernando | Consecuencia en spec v1.7 / plan IA-0 |
|---|---|---|---|
| 1 | Último aliento del jugador | **A** — se mantiene el mecanismo actual (derrota solo con jugador a 0 PV y sin compañeros operativos) | Se arregla el guard de `_incapacitate_player()` en IA-0a; `player_rescued` en el resultado |
| 2 | Estrategias de Mira | **B** — las órdenes sustituyen a las estrategias; Mira recibe 2 habilidades | `default_order` en Party con mapeo heredado (AGGRESSIVE→attack_weakest, DEFENSIVE→attack_dangerous, AREA_FOCUS/BERSERKER→libre) |
| 3 | Enemigos | **B** — stamina propia y 2-3 habilidades por enemigo | IA-0d |
| 4 | Tiempo | **B** — combate puramente por turnos. Motivo: el combate nació en tiempo real y migró a turnos por fidelidad a RuneQuest; el sistema de combate no se ha tocado desde el inicio, de ahí la discrepancia | Principio 7; IA-0b: pausa de regeneración, `combat_regen_per_round`, enfriamientos en rondas |
| 5 | Moral | **B** — moral individual sustituye a la de grupo | Se retira `_check_group_morale()` y su test; `morale_threshold_pct` no se usa en datos |
| 6 | Guardado en combate | **B** — sin guardado a mitad de combate; solo savepoints (el guardado rápido F9 no funciona) | `SaveSystem` se niega a guardar en combate; el RNG de combate no se persiste |
| 7 | PV de enemigos | **A + C** — PV derivados; se eliminan los `starting_resources` inertes y se ajusta la constitución | IA-0d |

### Resultados de las últimas búsquedas
- `morale_threshold_pct`: sin ocurrencias en JSON (solo en el recurso y el test).
- `clear_buffs`: solo se invoca desde `SessionReset`; los enemigos no se desregistran entre combates.
- `Characters.set_resource` / `modify_resource`: nadie los llama, así que `CharacterState.resources` queda obsoleto y el HUD (`CombatHudViewModel`) lee valores desfasados. Se corrige en IA-0b leyendo de `ResourceSystem`.
- `EventBus.skill_used`: **emisor aún sin confirmar** (la búsqueda anterior solo buscó `.emit`; falta `emit_signal("skill_used"`).

### Correcciones a lo dicho antes
- `reference_damage` va en el `BehaviorProfile`, no global (los PV máximos del objetivo no son observables).
- Retirados: «el `dodge` emite `player_action_completed` para cualquier actor» y «EnemyAI actúa tras el `await` sin comprobar el combate» (GameLoop descarta lo que llega fuera de fase).
- Los enemigos de la ruta narrativa sí tienen stamina (se registran con todos los recursos); solo los refuerzos se registran con `["health"]`.
- PV reales de `telmori_warrior_base` / `enemy_base`: 40 frente a los 50 declarados.

### Abierto
- Valores objetivo de constitución: ¿los **declarados** (columna 3 de la tabla del plan) o los **jugados hasta ahora** (columna 2)?
