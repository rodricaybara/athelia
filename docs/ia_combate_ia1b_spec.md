# Athelia — IA-1b: telemetría mínima de combate (especificación)

**Fecha:** 2026-11-19 · **Base:** `docs/ia_combate_ia1_spec.md` (§1b), `docs/ia_combate_spec_v1_7_1.md` (§11.1 a §11.3), `docs/ia_combate_ia1a_informe.md`
**Estado:** borrador revisado el 2026-11-19 (se corrigieron 14 puntos tras compararlo con el informe de IA-1a y la spec v1.7.1). Fase 0 pendiente; 7 decisiones por cerrar (sección 3).

IA-1b da al combate un **registro incremental en disco** (`.jsonl`) para poder analizar después qué pasó y con qué versión del código y de los datos. Solo escribe: **no cambia el combate jugable** ni toma decisiones. La IA todavía no decide nada (eso es 1c), así que el fichero contiene la cabecera, el cierre y los errores; los eventos `decision` y `action_result` llegan con 1c.

## 1. Alcance

**Entra:** `CombatTelemetry` (`RefCounted`); eventos `combat_start`, `combat_end` y `error`; envoltorio común (`event`, `event_seq`, `elapsed_ms`, `round`); bloque `version` (`schema_version`, `ai_version`, `config_hash`, git, `scenario_hash`, `run_label`); `config_hash` y `scenario_hash` con SHA-256 sobre serialización canónica; git por `OS.execute` con `null` si falla; valores no finitos a `null`; rotación (últimos 50); «Abrir carpeta de logs»; creado por `CombatProductionScene` y cerrado antes del `queue_free()` y por cualquier otra ruta de fin; prueba automática `ia1b_test`.

**No entra:** `decision`, `action_result`, `order_changed`, `morale_change`, `flee` (1c, IA-3, IA-4); suscripción a todas las señales de `EventBus` (se añadirán con 1c, cuando haya algo que correlacionar); análisis de logs; `docs/ai_changelog.md` más allá de su primera entrada (decisión 3); cambios en `EnemyAI`/`CompanionAI`; moral y resultado (IA-4).

## 2. Punto de partida (hipótesis a verificar en la Fase 0)

| Tema | Hipótesis |
|---|---|
| Orden de creación | `CombatProductionScene._ready()` se ejecuta **antes** de que se emita `combat_started` (en el log de IA-1a, `contexto de IA creado` sale antes de `Combat started` del controlador). Si es así, el logger se crea y escribe `combat_start` desde `_ready()`, tras registrar a todos los combatientes del roster. |
| Fin del combate | `combat_ended` llega a la escena, que se libera de forma diferida: `combat_end` se escribe antes del `queue_free()` (el contexto de IA ya se libera ahí). Hay otras rutas: `end_combat()` directo, Game Over, salida del árbol de escena (`_exit_tree`). |
| Datos de `combat_ended` | Hay que ver qué lleva la señal (resultado, ids). Si solo trae el `outcome`, las rondas y los vivos se leen de `GameLoop`/`Combat` por API pública. |
| Rondas | Existe `GameLoop` ronda actual (`round_started`); `round` en el envoltorio es la ronda en curso y `0` antes de la primera. `GameLoop` puede haber reiniciado el contador cuando llega `combat_ended`: la escena guarda la última ronda vista por `round_started` y de ella sale `rounds`. |
| Encuentro en la cabecera | `GameLoop.start_combat()` fija el encuentro (y aplica la sorpresa) **antes** de que exista la escena; `configure_active_encounter()` puede adjuntarlo después, y entonces la cabecera de `_ready()` lleva `encounter: null`. Hay que comprobar el orden real y, si ocurre, anotarlo en el informe. |
| Semilla del RNG de combate | `SkillRoller` tiene RNG inyectable (IA-0c); hay que ver si expone un getter de la semilla/estado. Si no, el campo sale `null` y se anota (no se lee un miembro privado). |
| Refuerzos | Un refuerzo se registra en la escena tras `_ready()`: no está en la cabecera. |
| Git | `git` funciona desde la consola de Fernando; hay que comprobar que `OS.execute("git", …)` lo encuentra **desde el editor de Godot** (el `PATH` del editor puede diferir), cuánto tarda y **en qué carpeta ejecuta** (no tiene por qué ser la del proyecto: se usa `git -C <ruta global del proyecto>`). En una exportación no hay carpeta de proyecto en disco: git no aplica y los campos salen `null`. |
| Hash y JSON | `HashingContext` (SHA-256) y `JSON.stringify(dict, "", true, true)` (claves ordenadas **y `full_precision`**) existen en 4.7.2; hay que comprobar el orden en diccionarios anidados, el comportamiento con `StringName`, `int` frente a `float` (`1` frente a `1.0`), valores no finitos y que sin `full_precision` se redondean los decimales (dos valores que difieren en la 7.ª cifra darían el mismo hash). |
| Ficheros | `user://` es escribible; `FileAccess.flush()` deja la línea legible desde fuera mientras el fichero sigue abierto en Windows; `DirAccess` lista y borra en `user://logs/combat/`. |
| `config_hash` | Los datos de IA (perfiles, `ai_scales.json`) se pueden serializar de forma canónica con APIs públicas (`BehaviorProfileRegistry.get_profile_ids()`/`get_profile()`, `AIScales`). Las skills evaluadas (costes, efectos, cooldowns, etiquetas) necesitan un accesor público a sus definiciones. |
| `scenario_hash` | Se puede construir por combatiente con APIs públicas: `Characters` (definición, atributos, valores de skill), `Resources`, `Equipment`, `Combat.get_visible_conditions()` y `GameLoop.get_current_encounter()`. |

## 3. Decisiones (a cerrar tras la Fase 0; recomendación entre paréntesis)

| # | Pregunta | Opciones | Recomendación |
|---|---|---|---|
| 1 | Cuándo se escribe `combat_start` | **A)** Al final de `_ready()` de la escena, con el roster ya registrado y antes de `combat_started`. **B)** Al recibir `combat_started` | **A**, si la Fase 0 confirma que `_ready()` precede a la señal; es lo que fija §11.1. Con B, cualquier evento previo se pierde |
| 2 | Activación | **A)** `CombatTelemetry.enabled` por defecto `OS.is_debug_build()` con un interruptor estático para forzarlo en las pruebas. **B)** Ajuste de proyecto | **A**: no hay exportación todavía; cero ajustes nuevos |
| 3 | `ai_version` y registro de cambios | **A)** Constante `AI_VERSION = "0.1.0"` en `CombatTelemetry`, con una primera entrada en `docs/ai_changelog.md`; el tag `ai-vX.Y.Z` se pone cuando exista evaluador (IA-2). **B)** Sin changelog hasta IA-2 | **A**: cuesta una entrada y deja la convención establecida |
| 4 | Refuerzos en el log | **A)** `combat_end` lleva `reinforcements` (ids y ronda de llegada), sin eventos nuevos. **B)** Evento `reinforcement_spawned` ya en 1b | **A**: no amplía el contrato de §11.3; el evento llega con la suscripción general en 1c |
| 5 | «Abrir carpeta de logs» | **A)** Botón en `OptionsPanel`, solo en compilación de depuración (`UIButton`, clave en el CSV de opciones, `tr()`), **como intención de `OptionsViewModel`** (`request_open_combat_logs()`, que llama a `CombatTelemetry.open_logs_folder()`); la View no referencia `CombatTelemetry`. **B)** Solo el helper y el botón con la UI de pausa | **A**: está en la spec de IA-1, el panel ya es reutilizable y el ViewModel es quien habla con sistemas; es el único cambio visual de la fase |
| 6 | Coste de arranque (git y hashes) | **A)** Consultar git una vez por proceso y cachear (`OS.execute` es síncrono); lo mismo para `config_hash` si pasa de ~50 ms, invalidándolo al recargar el registry. **B)** Calcular todo en cada combate | **A** si la Fase 0 mide más de ~150 ms en git o ~50 ms en el hash; **B** si es inapreciable |
| 7 | Nombres de bando en `sides` | **A)** Los del código (`CombatTags` `ally`/`enemy`, lo que devuelve `Combat.get_side()`). **B)** Los de §10 (`player`/`enemy`) | **A** ahora; IA-4 decidirá si §10 se alinea con el código. Anotarlo en el informe |

## 4. Diseño

### 4.1 `CombatTelemetry` (`core/ai/combat_telemetry.gd`, `RefCounted`, `class_name`)
- `static var enabled: bool = OS.is_debug_build()`; `const SCHEMA_VERSION = 1`, `AI_VERSION`, `MAX_FILES = 50`. **Puntos de inyección para las pruebas** (valores de producción por defecto): `static var log_dir: String = "user://logs/combat"` y `static var git_command: String = "git"`; las pruebas los sobrescriben y los restauran.
- `begin(header: Dictionary) -> bool`: crea el directorio, nombra el fichero `combat_<AAAAMMDD_HHMMSS>_<combat_id>.jsonl` (fecha formateada a mano con `Time.get_datetime_dict_from_system()`: el string de Godot lleva `:` y `T`, no válidos en Windows), abre, escribe `combat_start`. Devuelve `false` (y deja de registrar) si algo falla; nunca lanza.
- `log_error(code: String, details: Dictionary = {})`, `end(result: Dictionary)` (idempotente: escribe `combat_end` una sola vez, cierra el fichero y aplica la rotación), `is_active()`, `current_path()`.
- **`event_seq` lo incrementa solo el logger**, desde 0 y sin huecos; `elapsed_ms` desde `combat_start`; `round` lo pasa quien llama (`0` antes de la primera ronda).
- **Serialización:** una línea por evento, `JSON.stringify` con claves ordenadas; `StringName` a `String`; `NAN`/`INF` a `null` antes de serializar (recursivo); `flush()` tras cada línea.
- **Fallo de escritura:** desactiva el logger con un `push_warning`, sin interrumpir el combate.
- **`combat_id`:** `<unix_ms>-<4 hex>` generado con un `RandomNumberGenerator` **propio** del logger (o `unix_ms` + contador). **Nunca `randi()`/`randf()` globales** (`SkillRoller` usa el global si no tiene uno inyectado: consumirlo desplazaría las tiradas y rompería la reproducibilidad con semilla) **ni el RNG de IA**.
- **Sin `await`:** `begin()`, `end()` y la rotación son síncronos; el cierre ocurre dentro del manejador de `combat_ended`, antes del `queue_free()`.

### 4.2 Contenido de los eventos
| Evento | Contenido |
|---|---|
| `combat_start` | `combat_id`, bloque `version`, `scene_id`/`adventure_id` si se conocen (`null` si no), `ai_seed` y `ai_rng_state` como **texto**, semilla del RNG de combate (`null` si es el global), `sides` (por bando, nombres de la decisión 7; lista de `{id, definition_id, profile_id, used_fallback, hp_state}`; **el jugador no tiene `.tres` ni `CombatAIState`: `definition_id`, `profile_id` y `used_fallback` van a `null`**), `mira_order: null` (hasta IA-3), `encounter` (resumen de `GameLoop.get_current_encounter()` o `null`). La configuración efectiva (perfiles y escalas) va **embebida**, además del hash. |
| `combat_end` | `outcome` (`victory`/`defeat`/`escaped`; `aborted` es un valor **solo de telemetría**, fuera del contrato de §10), `rounds` (última ronda vista por la escena), `ai_rng_state` final como texto, `reinforcements` (decisión 4), `statuses` mínimos por combatiente (`id`, `hp_state`, condiciones visibles). El contrato completo de resultados es de IA-4. |
| `error` | `code`, `details`. En 1b: `profile_fallback` (un `CombatAIState` con `used_fallback`), `telemetry_write_failed`, `git_unavailable`. |

### 4.3 Trazabilidad (`version`)
`schema_version`, `ai_version`, `config_hash`, `git_commit`, `git_dirty`, `git_ai_path_commit`, `game_version` (`config/version` si existe, si no `null`), `godot_version`, `scenario_hash`, `run_label` (`""` por defecto). `config_hash` y `scenario_hash` son SHA-256 en hexadecimal sobre `JSON.stringify(valor_canonico, "", true, true)` (claves ordenadas y precisión completa); **nunca `hash()`**. Para que el hash no dependa de `1` frente a `1.0`, todos los números se normalizan a `float` antes de serializar. `git_dirty` y `git_ai_path_commit` solo miran `core/ai`, `core/combat`, `data/ai`, `data/characters`, `data/skills`; los comandos se lanzan con `git -C <ruta global del proyecto>` (`ProjectSettings.globalize_path("res://")`), capturando stderr y código de salida; sin git, sin repositorio o en una exportación, los tres campos son `null` y se anota un `error` `git_unavailable`.

### 4.4 Integración en `CombatProductionScene`
Un `var _telemetry: CombatTelemetry` y un `var _last_round: int` (actualizado en `round_started`); se crea con `begin()` al final de `_ready()` (decisión 1) y se cierra en un único método `_close_telemetry(outcome)` que llaman `_on_combat_ended()` (antes de `_release_ai_context()` y del `queue_free()`) y `_exit_tree()` (con `aborted` si seguía abierto). Si `enabled` es `false` o `begin()` falla, el combate sigue exactamente igual.

## 5. Tareas (orden de entrega)
1. `core/ai/combat_telemetry.gd` (fichero nuevo, con `class_name`, antes de lo que lo usa).
2. Constructor de cabecera y de hashes (en el mismo fichero o `core/ai/combat_telemetry_header.gd`; sin acceso a miembros privados de otros sistemas).
3. `combat_production_scene.gd` completo (más de cinco cambios sumando los de 1a).
4. «Abrir carpeta de logs» (decisión 5): intención en `OptionsViewModel`, botón en `OptionsPanel` solo en depuración y clave en el CSV de opciones.
5. `docs/ai_changelog.md` con la primera entrada (decisión 3).
6. `test/ia1b_test.gd` + `.tscn`.

## 6. Validación
**Prueba automática `ia1b_test` (0 fallos):**
- **A.** Envoltorio: `event_seq` 0..N sin huecos, `elapsed_ms` monótono, una línea por evento y cada línea parsea como JSON.
- **B.** Robustez: `NAN`/`INF` anidados salen como `null`; un fallo de escritura (`log_dir` inválido inyectado) desactiva el logger sin lanzar; `end()` es idempotente; `begin()` con `enabled = false` no crea fichero; **no consume el RNG global** (sembrar, llamar a `begin()` y comparar la siguiente tirada con un control sin logger).
- **C.** Hashes: SHA-256 de 64 caracteres hexadecimales; mismo contenido con distinto orden de claves → mismo hash; cambiar un valor de un perfil cambia `config_hash`; `1` y `1.0` dan el mismo hash; `0.0012345` y `0.0012346` dan hashes distintos.
- **D.** Git: con `git_command` inexistente inyectado, los campos son `null`, se anota `git_unavailable` y no hay excepción.
- **E.** Rotación con `log_dir` temporal inyectado: con 55 ficheros quedan 50 y se borran los más antiguos por nombre.
- **F.** Cabecera: `sides` con los ids de `Combat.get_combatant_ids()` y el perfil de cada uno; `ai_seed` y `ai_rng_state` son texto.
- **G.** Ningún acceso a miembros privados de otros sistemas en los ficheros nuevos (patrón del bloque H de `ia1a_test`), y `options_panel.gd` no referencia `CombatTelemetry`.
- **H.** El nombre de fichero no contiene `:` ni caracteres no válidos en Windows.

**Partida:** un combate real completo (victoria) deja `user://logs/combat/combat_<fecha>_<id>.jsonl` con exactamente `combat_start` y `combat_end` (más los `error` que correspondan). Comprobación externa en PowerShell (carpeta `%APPDATA%\Godot\app_userdata\<proyecto>\logs\combat\`): cada línea se convierte con `ConvertFrom-Json`, los `event_seq` van de 0 a N sin huecos y `combat_start.sides` coincide con el roster. Un combate con `wolf_test` deja un `error` `profile_fallback`. Con `enabled = false` no se crea fichero y el combate no cambia. **Output y Depurador → Errores sin avisos nuevos** (el aviso de perfil de `wolf_test` ya es esperado desde IA-1a). El combate se juega igual que en IA-0d.

## 7. Cambios de comportamiento a avisar
Ninguno jugable. Aparece una carpeta de logs en `user://` (máximo 50 ficheros), un botón de depuración en Opciones (decisión 5) y un coste de arranque por combate (git, hashes), que se mide en la Fase 0 (decisión 6).

## 8. Fuera de alcance
Eventos de decisión y de resultado de acción (1c); suscripción a `EventBus` (1c); órdenes de Mira (IA-3); moral y `combat_result_ready` (IA-4); modo sin interfaz y análisis de logs (IA-5); `build_info.json` para compilaciones exportadas (cuando se exporte); `.gitignore` de `build_info.json`.

## 9. Ficheros necesarios para la Fase 0 definitiva (IA-1b)
`combat_production_scene.gd` (versión de IA-1a, ya entregada), `game_loop_system.gd` (solo `start_combat`, `end_combat`, `get_current_encounter`, el emisor de `combat_started` y de `combat_ended`, y la ronda actual), `event_bus.gd` (señales de combate: parámetros de `combat_started` y `combat_ended`), `options_panel.gd`/`options_view_model.gd`/`options_panel.tscn` y el CSV de opciones, `combat_encounter_definition.gd`, `project.godot` (`config/version`), y `ai_scales.json`.

Búsquedas:

```powershell
Get-ChildItem -Recurse -Filter *.gd | Select-String -CaseSensitive -Pattern 'signal combat_started|signal combat_ended|combat_started\.emit|combat_ended\.emit|emit_signal\("combat_(started|ended)'
Get-ChildItem -Recurse -Filter *.gd | Select-String -CaseSensitive -Pattern 'func get_current_encounter|func get_current_round|current_round|func end_combat|func start_combat'
Get-ChildItem -Recurse -Filter *.gd | Select-String -CaseSensitive -Pattern 'HashingContext|OS\.execute|FileAccess\.open|DirAccess\.open|shell_open'
Get-ChildItem -Recurse -Filter *.gd | Select-String -CaseSensitive -Pattern 'func get_skill_definition|func get_skill_def|get_all_skill_ids|func list_skills'
Get-ChildItem -Recurse -Filter *.gd | Select-String -CaseSensitive -Pattern 'func get_all_base_attributes|func get_all_skill_values|func get_definition|func get_character_definition'
Select-String -Path project.godot -Pattern 'config/version|config/name'
Get-ChildItem -Recurse -Directory -Filter logs
```

Sonda de Fase 0 (un `EditorScript` temporal marcado `TEMPORAL IA-1b`, como en IA-1a): SHA-256 de una cadena conocida; `JSON.stringify` con claves ordenadas en diccionarios anidados y con `StringName`; `1` frente a `1.0`; `OS.execute("git", ["--version"])` (salida, código y duración) desde el editor; `FileAccess.flush()` con lectura externa en Windows; creación y borrado en `user://logs/combat/`; `Time.get_datetime_string_from_system()` y su uso en un nombre de fichero.

## 10. Al cerrar la subfase
Informe `docs/ia_combate_ia1b_informe.md`; `estado_actual.md` (tabla y pendientes), `athelia_referencia_sistemas.md` (estado en su sitio), lecciones nuevas e historial (un párrafo), spec v1.7.1 §11 si cambia algo del contrato, y `docs/ai_changelog.md`. Anclas de parche de una sola línea; los cambios temporales llevan la marca `TEMPORAL IA-1b` y su retirada se comprueba antes de cerrar.
