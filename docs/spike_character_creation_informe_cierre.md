# Athelia — Informe de Cierre: Spike Character Creation

**Fecha:** Agosto 2026
**Estado:** ✅ Completado
**Rama de trabajo:** `ui/character-creation`

---

## Objetivo

Implementar la lógica real de la pantalla de creación de personaje (hasta ahora un stub): tirada de atributos, asignación, nombre, resumen y creación de la entidad jugable. Integrar con `CharacterSystem`, `ResourceSystem`, `SkillSystem`, `Equipment` e `Inventory`. De forma no planeada pero necesaria, el spike se amplió para cerrar la persistencia completa del personaje (guardado/carga) y corregir varios bugs de navegación entre pantallas que solo se manifestaban al completar el flujo real de punta a punta por primera vez.

---

## Decisiones de diseño tomadas

| Decisión | Opción elegida | Motivo |
|---|---|---|
| Atributos | 6 reales del proyecto (STR/DEX/CON/INT/WIS/CHA) | El sistema **no** es el de 7 de RuneQuest — no existe SIZ ni POW; se descubrió al inspeccionar `player_base.tres` |
| Fórmulas de dados | 3D6 en STR/DEX/CHA, 2D6+6 en CON/INT/WIS | Mantener un suelo alto (mín. 8) en supervivencia/mente |
| Método de asignación | Roll-and-assign en dos pools separados | Preserva la garantía del suelo alto mientras da elección real al jugador |
| Reroll | Limitado a 1 uso sobre el set completo | Balance entre control y aleatoriedad |
| Habilidades iniciales | Kit fijo: `attack.light`, `combat.dodge`, `exploration.perception` | Coherente con progresión por uso — sin desbloqueo de catálogo completo |
| Oro inicial | Fijo, 50 | Scope mínimo viable |
| Equipo inicial | Kit fijo (espada + armadura), sin equipar | Va al inventario; un tutorial futuro enseña a equipar |
| CharacterDefinition | `player_new.tres` nueva, separada de `player_base.tres` | `player_base` es una plantilla de test/debug con ~15 skills desbloqueadas — no debía tocarse |
| Interacción de asignación | Click (chip → slot), no drag & drop | Más simple de implementar con `UIButton`, sin lógica de drag&drop nueva |
| Persistencia | Conectar `CharacterSystem.get/load_save_state()` (ya existían, sin usar) a `SaveSystem` | Evitar reinventar lo que ya estaba diseñado |

---

## Archivos creados

### Nuevos
| Archivo | Ruta | Descripción |
|---|---|---|
| `character_creation_viewmodel.gd` | `ui/character_creation/` | ViewModel: estados, tirada, asignación, creación de la entidad |
| `character_creation_screen.gd` | `ui/character_creation/` | View — reemplaza el stub |
| `character_creation_screen.tscn` | `ui/character_creation/` | Escena — movida desde `scenes/character_creation/` para ser consistente con el resto de pantallas MVVM |
| `character_creation.csv` | `localization/` | Claves de localización de la pantalla |
| `player_new.tres` | `data/characters/` | CharacterDefinition dedicada a personajes nuevos (atributos placeholder, kit fijo de skills) |
| `test_character_creation_viewmodel.gd` | `test/` | Test aislado del ViewModel (30 asserts) |
| `test_character_persistence.gd` | `test/` | Test aislado del roundtrip guardado/carga de `CharacterSystem` |

### Modificados
| Archivo | Cambios |
|---|---|
| `scene_orchestrator.gd` | `_handle_character_creation()` usa `_show_overlay()` en vez de instanciación manual (para que `_hide_current_overlay()` la limpie al salir); `_handle_exploration()` ahora instancia `SCENE_EXPLORATION` de verdad si no existe |
| `main_menu_viewmodel.gd` | Escucha `EventBus.game_state_changed`; vuelve a `"main"` al reentrar en `MENU`, se oculta (`"hidden"`) al salir |
| `main_menu_screen.gd` | Nuevo caso `"hidden"` → `visible = false`; `_render_main()` fuerza `visible = true` |
| `character_state.gd` | + campo `character_name`, incluido en `get_save_state()`/`load_save_state()` |
| `character_system.gd` | + `set_character_name()` / `get_character_name()` |
| `save_data.gd` | `SAVE_VERSION` 4→5, `player_state.character` por defecto, migración v4→v5 |
| `save_system.gd` | Conecta `character_system.get_save_state()`/`load_save_state()` (existían, nunca se llamaban); `_restore_state()` restaura `character` primero; `_find_player()` corregido — buscaba en `current_scene`, que nunca apunta a la escena de exploración (instanciada aditivamente, no vía `change_scene_to_file()`) |
| `exploration_controller.gd` | + `_quicksave()`/`_quickload()` en `_unhandled_input()` — el código original en `player.gd` (Día 2-5) estaba muerto: el nodo `Player` real usa `PlayerExploration`, no `player.gd` |

---

## Arquitectura de Character Creation

```
CharacterCreationScreen (CanvasLayer)
└── Root (Control, full rect)
    ├── AttributeRollPanel
    │   ├── PhysicalPoolContainer (3 chips — 3D6: STR/DEX/CHA)
    │   ├── ResilientPoolContainer (3 chips — 2D6+6: CON/INT/WIS)
    │   ├── AttributeSlotsContainer (6 slots, click-to-assign)
    │   ├── BtnRoll / BtnReroll (aparecen/desaparecen, no solo se deshabilitan)
    │   └── BtnContinueAssign
    ├── NamePanel
    │   ├── NameLineEdit
    │   └── BtnContinueName
    ├── SummaryPanel (RichTextLabel + BBCode — tabla de atributos, no lista plana)
    │   ├── BtnBackToNaming
    │   └── BtnConfirm
    ├── ErrorFeedbackLabel
    └── BtnBackToMenu
```

### Estados del ViewModel

```
ROLLING → ASSIGNING → NAMING → SUMMARY → TRANSITIONING
                ↑___________________|
              (reroll, 1 uso)
```

### Razones de `changed()`

| Razón | Efecto en la View |
|---|---|
| `"opened"` | Reset completo, panel de tirada visible |
| `"rolled"` / `"rerolled"` | Refresca pools, muestra/oculta BtnRoll/BtnReroll |
| `"assigned"` | Refresca chips y slots, habilita continuar si están los 6 |
| `"error_incomplete_assignment"` | Feedback temporal |
| `"naming"` | Panel de nombre visible |
| `"error_empty_name"` / `"error_name_too_long"` | Feedback temporal |
| `"summary"` | Panel de resumen con tabla BBCode |
| `"transitioning"` | Deshabilita todos los botones |

### `_create_player_entity()` — orden crítico

```gdscript
Characters.register_entity("player", "player_new")
Resources.register_entity("player")          # ← ANTES de tocar atributos
for attr in assigned_attributes:
    Characters.set_base_attribute("player", attr, value)   # dispara ModifierApplicator síncronamente
Resources.restore_resource("player", "health")   # curar al nuevo máximo derivado
Resources.restore_resource("player", "stamina")
Skills.register_entity_skills("player", KIT_FIJO)   # lista explícita, NO array vacío
Resources.set_resource("player", "gold", 50.0)
Equipment.register_entity("player")
Inventory.register_entity("player")
Inventory.add_item("player", "iron_sword", 1)
Inventory.add_item("player", "leather_armor", 1)
Characters.set_character_name("player", character_name)
```

---

## Claves de localización añadidas (`character_creation.csv`)

```
CC_ROLL_TITLE, CC_BTN_ROLL, CC_BTN_REROLL, CC_BTN_CONTINUE, CC_BTN_BACK, CC_BTN_BACK_TO_MENU, CC_BTN_CONFIRM
CC_NAME_TITLE, CC_NAME_PLACEHOLDER
CC_SUMMARY_TITLE, CC_SUMMARY_SKILLS_TITLE, CC_SUMMARY_SKILLS, CC_SUMMARY_EQUIPMENT_TITLE, CC_SUMMARY_EQUIPMENT
CC_ERROR_INCOMPLETE, CC_ERROR_EMPTY_NAME, CC_ERROR_NAME_TOO_LONG, CC_ERROR_NO_CHIP_SELECTED, CC_ERROR_WRONG_POOL
CC_ATTR_STRENGTH, CC_ATTR_DEXTERITY, CC_ATTR_CONSTITUTION, CC_ATTR_INTELLIGENCE, CC_ATTR_WISDOM, CC_ATTR_CHARISMA
```

---

## Bugs corregidos durante el spike

### Colisión de nombre de método con `Node.name`
**Causa:** `CharacterCreationViewModel.set_name()` pisaba el setter nativo `Node.set_name(StringName)` — warning tratado como error por el proyecto.
**Fix:** Renombrado a `set_character_name()`.

### `ModifierApplicator` no encontraba la entidad en `ResourceSystem`
**Causa:** `_create_player_entity()` llamaba `set_base_attribute()` antes de `Resources.register_entity()`. `set_base_attribute()` dispara `ModifierApplicator` de forma síncrona, que necesita la entidad ya registrada en `ResourceSystem` para actualizar `health_max`/`stamina_max`.
**Fix:** Reordenar — `Resources.register_entity()` antes del bucle de atributos.

### Health/Stamina no se curaban al nuevo máximo
**Causa:** `ModifierApplicator` actualiza `max_effective` pero no el valor `current`.
**Fix:** `Resources.restore_resource()` explícito tras fijar atributos.

### `register_entity_skills()` registraba las 17 skills del catálogo en vez del kit fijo
**Causa:** Llamada con el array de skills vacío (comportamiento por defecto = todo el catálogo).
**Fix:** Pasar la lista explícita del kit fijo.

### Botón "Volver al Menú" y "Confirmar" no cerraban la pantalla de Character Creation
**Causa:** `_handle_character_creation()` instanciaba la escena manualmente contra `get_tree().root`, sin pasar por `_show_overlay()` — nunca quedaba registrada en `_current_overlay`, así que `_hide_current_overlay()` (ya llamado correctamente por `_handle_main_menu()`/`_handle_exploration()`) no la encontraba.
**Fix:** Usar `_show_overlay()`, igual que Shop/Inventory/Party.

### Menú principal se quedaba con los botones deshabilitados para siempre tras la primera transición
**Causa:** `MainMenuViewModel` solo llamaba a `open()` una vez, en `_ready()` de la View. Tras `request_new_game()` quedaba en `TRANSITIONING` permanentemente — nada le decía que volviera a `MENU`.
**Fix:** `MainMenuViewModel` escucha `EventBus.game_state_changed`; vuelve a `"main"` al reentrar en `MENU`, se oculta en cualquier otro estado.

### `_handle_exploration()` nunca cargaba una escena de exploración real
**Causa:** Comentario explícito en el código: *"no necesitamos recargar la escena de exploración en el spike"* — válido cuando se probaba `exploration_test.tscn` directamente, roto en el flujo real Menú → Character Creation → Exploration.
**Fix:** Instanciar `SCENE_EXPLORATION` si no existe ya en el árbol.

### Guardado fallaba con "Player node not found"
**Causa:** `SaveSystem._find_player()` busca bajo `get_tree().current_scene` — pero `SceneOrchestrator` instancia la exploración de forma aditiva (`get_tree().root.add_child()`), no con `change_scene_to_file()`. `current_scene` nunca deja de ser `MainMenuScreen` (la Main Scene del proyecto).
**Fix:** Buscar primero bajo el nodo `"ExplorationScene"` que `SceneOrchestrator` crea explícitamente.

### F5/F9 (quicksave/quickload) no hacían nada
**Causa:** La lógica vivía en `player.gd` (script de una fase muy temprana del proyecto, "Día 2-5"), que ya no está en el árbol de ninguna escena activa — el nodo `Player` real usa `PlayerExploration`.
**Fix:** Movido a `ExplorationController._unhandled_input()` — ya tenía la responsabilidad de input de exploración y usa correctamente `_unhandled_input()`.

### `CharacterSystem` tenía `get_save_state()`/`load_save_state()` completos, nunca conectados
**Causa:** Preparados de antemano ("SAVE/LOAD — Preparación futura") pero `save_system.gd` nunca los invocaba. Como consecuencia, `base_attributes` no se guardaba en ningún sitio, y `_restore_state()` no registraba a `"player"` si no existía ya — asumía una entidad pre-registrada por otra vía (ej. `exploration_test.gd`).
**Fix:** Conectados en `save_system.gd`, con `character_system.load_save_state()` como primer paso de la restauración (puede bootstrapear la entidad vía `definition_id` si no existe).

---

## Aprendizajes clave de este spike

- El sistema de atributos real es de **6**, no 7 — documentar esto de forma más visible evitaría el mismo malentendido en el futuro (ej. en `athelia_estructura_proyecto_actualizado.md`).
- Existen **dos sistemas de recursos independientes**: `CharacterState.resources` (simple, incluye `focus`) y `ResourceSystem`/`Resources` autoload (real, con regeneración y máximos derivados, solo `health`/`stamina`/`gold`). No están sincronizados entre sí automáticamente.
- `player_base.tres` es una definición de **test/debug** (usada por `combat_test_scene.gd` y `exploration_test.gd`), no una plantilla para partidas reales — `player_new.tres` es la separación correcta.
- `ModifierApplicator` sí deriva `health_max`/`stamina_max` desde atributos en tiempo real (vía señal síncrona), pero **no** cura el valor actual al recalcular — hay que hacerlo explícitamente.
- El patrón de bug "`_input` bloquea `_unhandled_input` en Godot 4.7" ya apareció dos spikes seguidos (combate, ahora exploración) — vale la pena una pasada general del proyecto buscando `_input()` restantes.
- `exploration_test.tscn`/`exploration_test.gd` son spike/test: registran ítems y oro de depuración de forma incondicional, y no representan el flujo de producción.

---

## Pendiente / próximos pasos

- [ ] **Escena de exploración de producción** — separada de `exploration_test.tscn`. Necesaria para que "Cargar Partida" desde el menú principal funcione sin pisar al personaje con datos de test (500 oro, ítems fijos), y para poder cerrar el hueco de registro en frío de abajo.
- [ ] **Registro en frío de `Resources`/`Skills`/`Equipment`/`Inventory` durante `load_game()`** — `_restore_state()` solo bootstrapea `CharacterSystem` si la entidad no existe; los otros cuatro sistemas siguen asumiendo que `"player"` ya está registrado por otra vía. Bloquea "Cargar Partida" desde un arranque en frío real (sin pasar antes por una escena que registre al jugador).
- [ ] **Escena de introducción / transición narrativa** entre Character Creation y Exploration — mencionada durante el spike como el sitio natural para justificar la carga inicial del mundo. Encaja con el pendiente ya existente de `LoadingScreen` (implementada, no conectada a `SceneOrchestrator`).
- [ ] **Persistencia de `character_name`** — ya funciona en el roundtrip save/load, pero no se muestra todavía en ninguna UI in-game (HUD, menú de pausa, etc.).
- [ ] **Limpieza de código muerto** — `player.gd`/`player.tscn` (Día 2-5) ya no están en el árbol de ninguna escena activa; candidatos a revisar o eliminar.
- [ ] **Ajustes visuales pendientes de Character Creation** — tamaños de panel ya alineados manualmente; revisar si el `RichTextLabel` del resumen necesita más pulido tipográfico.
- [ ] **Companion loadout system**, **Sword skill tree**, **Training costs UI**, **Fase C de contenido** — pendientes previos al proyecto, sin relación con este spike, siguen abiertos.

---

## Resultado

Flujo completo funcional y verificado con logs reales, no solo en tests aislados:

```
Menú Principal → Nueva Partida → Character Creation
    → Tirada de atributos (roll-and-assign, 2 pools, 1 reroll) ✅
    → Nombre ✅
    → Resumen ✅
    → Confirmar → Exploration real (no MENU fantasma) ✅
                → Volver al Menú desde cualquier punto ✅ (menú ya no queda "congelado")

Exploración → Tienda → Compra de objetos → Inventario ✅
Exploración → F5 (guardar) → F9 (cargar) ✅
    → Nombre, atributos, inventario, oro, estado de tienda — todo persiste correctamente
```

Tests automatizados: `test_character_creation_viewmodel.gd` (30/30), `test_character_persistence.gd` (7/7).
