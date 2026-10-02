# Spike 12 — Motor de escenas interactivas (mapa de puntos de interés)

**Estado:** CERRADO (motor validado con mapa de prueba; contenido real → Spike 13)
**Origen:** Idea 2 surgida tras el pivote narrativo: sustituir el acceso al
pueblo por un mapa navegable con puntos de interés clicables (tienda,
herrero...), sin movimiento de personaje ni posición espacial.
**Precede a:** Spike 13 (reautoría del pueblo de "Los Telmori" sobre este motor).

**Decisiones de Fernando (respetadas):**
- Sin movimiento de personaje ni posición — clic directo sobre el punto.
- Sistema nuevo y dedicado; `WorldObjectSystem`/`Interactable` quedan como están.
- Sustituye la apertura del pueblo (no es un prototipo aparte).
- Visibilidad por flags declarativa (se recalcula al volver a EXPLORATION), no
  dinámica por evento.
- Naming genérico (`InteractiveScene*`/`InteractiveHotspot*`) para no excluir
  futuras escenas de "buscar en la imagen". Esa mecánica NO se decidió aquí.

---

## Fase 0 — respuestas reales

| # | Pregunta | Respuesta |
|---|---|---|
| 0 | ¿`Interactable`/`interaction_requested` siguen vivos? | **Vivos**, pero en el pueblo solo se ejercitan con `narrative_scene` y siempre creados por código (3 spawns en `exploration_telmori_village.gd`); el `.tscn` del pueblo no tiene ninguno. `ExplorationController` escucha la señal (línea 55). |
| 1 | ¿`"narrative_scene"` es un `interaction_type` real? | Sí. Funciona porque el pueblo lo asigna con `area.set(...)`, saltándose el `@export_enum` de `interactable.gd:24` (solo lista dialogue/shop/combat/item). El enum es solo cosmético; la doc que decía lo contrario estaba equivocada. |
| 2 | ¿Cómo llega `enemy_definitions` en un combate? | `ExplorationController` lo leía de `_current_interactable` (solo existe con el jugador en rango). Sin nodo físico, degradaba en silencio a `enemy_base`. **Resuelto** con `request_interaction(type, target_id, enemy_definitions)` (ver abajo). |
| 3 | ¿Quién escucha `interaction_requested`? | `ExplorationController._on_interaction_requested()` → `match` sobre el tipo → `GameLoop.enter_dialogue/enter_shop/start_combat/enter_narrative_scene` o `world_object_interaction_requested`. |
| 4 | ¿Cómo entra hoy el jugador a una escena narrativa desde el pueblo? | Primera vez: `_ready()` de `exploration_telmori_village.gd` (guard `flag.telmori_village_visited`) → `enter_narrative_scene("telmori_village_arrival")`. Resto de la cadena: encadenada dentro del panel narrativo. Los 3 `Interactable` por código solo sirven para reentrar tras combate/al final de arco. |

**Correcciones a la spec original**
- El punto 5 de "Lo confirmado" era falso: `SceneOrchestrator` hace
  `instance.name = "ExplorationScene"` al instanciar (scene_orchestrator.gd:213);
  el nodo raíz del `.tscn` puede llamarse como se quiera.
- El disparo NO puede ser solo `EventBus.interaction_requested`: la señal no lleva
  `enemy_definitions` y un signal de GDScript no admite parámetros opcionales.
- `NarrativeSceneDB` sí es un autoload (`Node` sin estado runtime), no "sin autoload".
- Ruta única: `core/interactive_scenes/` (el cierre original decía `core/poi_maps/`).
- `item` queda fuera de los tipos de hotspot en v1 (exige `WorldObject` registrado).

---

## Diseño final

### Datos — `core/interactive_scenes/`
- `InteractiveHotspotDefinition` (`Resource`): `hotspot_id`, `map_position`
  (normalizada 0–1 sobre el rectángulo de la imagen), `icon_path`, `label_key`,
  `interaction_type` (`dialogue`/`shop`/`combat`/`narrative_scene`), `target_id`,
  `enemy_ids_override`, `enemy_definitions`, `required_flags`, `blocked_flags`.
  `get_effective_target_id()` une los IDs de combate por comas (igual que
  `Interactable.interact()`). `validate(scene_id)` con errores/warnings.
- `InteractiveSceneDefinition` (`Resource`): `scene_id`, `image_path`,
  `hotspots`. Valida ids duplicados.
- `InteractiveSceneRegistry` (autoload **`InteractiveSceneDB`**): carga
  `res://data/interactive_scenes/*.json` sin recursión; sin estado runtime.

### Vista — `ui/interactive_scene/`
- `InteractiveSceneViewModel` (`Node`): `changed(reason)` con razones
  `scene_loaded` / `hotspots_refreshed`; señal `hotspot_activated(type,
  target_id, enemy_definitions)`. Filtra hotspots contra `Narrative.has_flag`.
  Se recalcula al cargar y en `game_state_changed → EXPLORATION`.
  `activate_hotspot()` exige `state == EXPLORATION` (no solo `is_input_blocked()`,
  que deja pasar PAUSE/MENU). Avisa al cargar de `scene_id` narrativos inexistentes.
- `InteractiveSceneView` (`Control`): pasiva. `Fallback` (ColorRect) +
  `Background` (TextureRect, `expand_mode`/`stretch_mode` fijados en código) +
  `HotspotLayer` con un `Button` por hotspot visible.

### Escena — `scenes/exploration/interactive_map/`
`exploration_interactive_map.tscn/.gd`: composición pura. `ExplorationController`
+ `ExplorationHUD` + `MapLayer` (CanvasLayer -1, se oculta en
COMBAT_ACTIVE/VICTORY/DEFEAT). Sin `Player`, sin `Camera2D`. El contenido se
elige con `@export var interactive_scene_id` (por defecto `"poi_test_map"`).

### Routing — `ExplorationController.request_interaction()`
Único punto de routing (extraído del antiguo `_on_interaction_requested`, que
ahora delega en él con las definiciones del `_current_interactable`).
Guard propio con `is_input_blocked()` por ser API pública. El camino de
`Interactable` no cambia de comportamiento.

### SaveSystem
`_collect_player_state()` ya no aborta si no hay nodo `Player`: guarda sin
`position` (clave opcional; `SAVE_VERSION` sin cambios). La restauración ya
toleraba `Player` ausente.

---

## Validación (partida real, Godot 4.7.2)

| Comprobación | Resultado |
|---|---|
| Registry carga `poi_test_map`; sin warnings de escenas narrativas | OK |
| Clic → `dialogue` (`DLG_TRAINER_01`) y vuelta al mapa | OK |
| Clic → `shop` (`blacksmith_01`) y vuelta al mapa | OK |
| Clic → `narrative_scene` (`telmori_village_arrival`), cadena hasta sheriff con sub-overlay | OK |
| Clic → `combat` (2 lobos): `Enemy definitions loaded: {…wolf_test…}`, enemigos pre-registrados con `def: wolf_test` (no `enemy_base`), vuelta al mapa | OK |
| Mapa no visible/clicable durante el combate | OK (captura) |
| `required_flags`/`blocked_flags`: tras `flag.poi_test_unlock` (atajo F2) aparece `test_flag_gated` y desaparece `test_flag_blocked`; el gated abre su diálogo | OK |
| Guardado desde NPC savepoint (`O_SAVE`) con el mapa activo, sin `Player` | OK (`Game saved successfully`) |
| Carga desde menú → reanuda en `telmori_sheriff_briefing` sobre el mapa | OK |
| Camino físico `Interactable` (pueblo, `narrative_scene` por código) tras el refactor del controlador | **NO probado de extremo a extremo** — refactor revisado por inspección, comportamiento idéntico por diseño |
| F9 quickload desde el mapa | Fuera de alcance (F9 no operativo desde Spike 7) |

**Estado actual de `SCENE_EXPLORATION`:** apunta al mapa de prueba
(`exploration_interactive_map.tscn`); la línea del pueblo queda comentada,
revertible. Spike 13 decide el estado final.

---

## Deudas hacia Spike 13
1. **Inicialización de partida que vivía en `TelmoriVillage._ready()`**:
   `party.join_party("companion_mira")`, `_equip_starter_gear` (player y
   companion) y la primera entrada `telmori_village_arrival` (guard
   `flag.telmori_village_visited`). El mapa de prueba las omite (por eso el
   guardado muestra `Equipment 0 slots` / `Party 0 companions`). Decidir dónde
   viven (fuera de la escena, data-driven).
2. **Los 3 spawns por evento pasan a hotspots declarativos:**
   rastro (`required: flag.telmori_ambush_triggered`, `blocked:
   flag.telmori_tracked_to_lair`), aftermath (`flag.telmori_lair_combat_won` /
   `flag.telmori_lair_cleared`), recompensa (`flag.telmori_lair_cleared` /
   `flag.telmori_adventure_completed`). Los 5 listeners de
   `combat_ended`/`narrative_flag_set` del pueblo se eliminan con la escena.
3. **Flag de victoria de la emboscada:** hoy el rastro solo aparece tras
   *ganar* (`combat_ended "victory"`); `flag.telmori_ambush_triggered` se pone al
   *disparar* el combate, así que como hotspot aparecería también tras derrota.
   Hace falta un flag puesto al ganar.
4. **Arte y UI:** fondo e iconos reales; sustituir `Button` estándar por
   `UIButton`/componente del Design System; claves de localización reales
   (`POI_TEST_*` son solo de prueba).
5. **Localización de prueba:** claves `POI_TEST_DIALOGUE`, `POI_TEST_SHOP`,
   `POI_TEST_NARRATIVE`, `POI_TEST_COMBAT`, `POI_TEST_GATED`, `POI_TEST_BLOCKED`.
6. (Opcional) `player_state["position"]` es ya vestigial; retirar en una
   limpieza de `SaveData`.
