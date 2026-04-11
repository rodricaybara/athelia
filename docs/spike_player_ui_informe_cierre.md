# Spike: Player UI — Informe de Cierre

## Estado: COMPLETADO

---

## 1. Resumen

Spike que implementa la interfaz de personaje del jugador, compuesta por tres artefactos independientes: menú de personaje (`PlayerMenuScreen`), configuración de loadout (`LoadoutScreen`) y HUD de combate (`CombatHUD`). Incluye el nuevo tipo de dato `LoadoutState` integrado en `CharacterState`.

---

## 2. Artefactos implementados

### Datos
| Archivo | Descripción |
|---|---|
| `core/characters/loadout_state.gd` | Nuevo Resource. Estado persistente de slots de combate. Referenciado desde `CharacterState`. |

### UI
| Archivo | Descripción |
|---|---|
| `ui/player_menu/player_menu_viewmodel.gd` | ViewModel reactivo. Escucha EventBus. Expone atributos derivados, buffs, recursos y oro. |
| `ui/player_menu/player_menu_screen.gd` | View. Gestiona subpantallas como hijos propios (Opción A). |
| `ui/loadout/loadout_viewmodel.gd` | ViewModel con validación por tags. Escribe en `LoadoutState`. |
| `ui/loadout/loadout_screen.gd` | View. Selección en dos pasos. `call_deferred` para rerenderizado. |
| `ui/combat_hud/combat_hud_viewmodel.gd` | ViewModel de solo lectura. Trackea cooldowns por rondas. |
| `ui/combat_hud/combat_hud.gd` | View. Input por teclado vía InputMap. |

### Patches
| Archivo | Cambios |
|---|---|
| `core/characters/character_state.gd` | Campo `loadout: LoadoutState`. Integrado en `get_save_state()` / `load_save_state()`. |
| `core/scene_orchestrator.gd` | `open_player_menu()`, `open_loadout()`. `_handle_combat()` instancia `CombatHUD`. `_on_combat_ended()` lo destruye. |
| `scenes/exploration/exploration_controller.gd` | Tecla `P` → `open_player_menu()`. Tecla `O` → `open_party()` (reasignada). |
| `scenes/exploration/exploration_hud.gd` | `_unhandled_input` añade `open_player_menu`. |

---

## 3. Decisiones de diseño tomadas

### LoadoutState es estado persistente, no configuración de UI
Vive en `CharacterState`, se serializa en `SaveData`. El ViewModel es solo la capa de edición. Compatible con jugador y companions desde el diseño inicial.

### Snapshot inmutable en combate
`CombatSystem` recibe un diccionario `{slot_id: skill_id}` al inicio del combate. No conoce `LoadoutState`. El `CombatHUD` lee el estado directamente de `CharacterState` al iniciarse.

### Pantallas independientes con menú ligero
No hay `PlayerScreen` monolítica con pestañas. `PlayerMenuScreen` es el punto de entrada y gestiona sus subpantallas internamente (Opción A) sin pasar por `SceneOrchestrator`.

### Subpantallas como hijos propios (Opción A)
`PlayerMenuScreen` instancia `LoadoutScreen`, `InventoryScreen` y `SkillTreeScreen` como hijos propios. Al abrir una subpantalla se oculta (`visible = false`). Al cerrarse la subpantalla (`tree_exiting`) vuelve a mostrarse y refresca el estado.

### Cooldowns por rondas en CombatHUD
`CombatHudViewModel` trackea cooldowns internamente con un `Dictionary {slot_id: rondas_restantes}`. Se decrementa en cada `round_started`. No depende del sistema de cooldowns de `SkillSystem` que opera en tiempo real.

### Keybindings semánticos en InputMap
Acciones: `combat_attack_1/2/3`, `combat_dodge`, `combat_defense`, `combat_escape`, `combat_consumable_1/2`, `open_player_menu`. Remappables sin tocar código.

---

## 4. Bugs encontrados y resueltos durante el spike

| Bug | Causa | Solución |
|---|---|---|
| Métodos incorrectos de autoloads | `Skills.get_definition()`, `Inventory.get_item_count()`, `Inventory.get_all_items()`, `Characters.get_state()` no existían | Corregidos a `get_skill_definition()`, `get_item_quantity()`, `get_inventory()`, `get_character_state()` |
| Señales inexistentes en EventBus | `equipment_changed`, `buff_removed`, `open_*_requested` no declaradas | Sustituidas por `item_equipped/unequipped`, `temporary_state_removed`. Navegación vía `changed()` interno. |
| `tr()` en función estática | `from_definition()` era `static` y no puede llamar a `tr()` | Movida la traducción a `_refresh_slots()` (función normal) |
| Panel no ocupa pantalla completa | `PanelContainer` hijo directo de `CanvasLayer` no respeta anchors | Añadido nodo `Root (Control)` con `layout_mode = 3` y `anchors_preset = 15` entre `CanvasLayer` y `Panel`. `layer = 10` en el `CanvasLayer`. |
| Botones de subpantalla cerraban `PlayerMenuScreen` | `SceneOrchestrator.open_inventory()` tenía lógica de toggle sobre `_current_overlay` | Opción A: subpantallas gestionadas internamente, sin pasar por `SceneOrchestrator` |
| `Object is locked` al pulsar slot de loadout | `free()` llamado sobre botón que estaba ejecutando su callback `pressed` | `call_deferred("_render_slots")` en `_on_slot_pressed()` y en `changed("slots")` |
| Señales del EventBus ya conectadas al reabrir | `_vm.open()` llamado desde `_on_subscreen_closed()` reconectaba sin desconectar antes | `_disconnect_events()` antes de `_connect_events()` en `open()` |
| `open_inventory()` con argumento incorrecto | Firma real es `open_inventory()` sin parámetros | Eliminado `_character_id` del callback |

---

## 5. Claves de localización añadidas

```
ATTR_HEALTH_MAX, ATTR_STAMINA_MAX, ATTR_INITIATIVE, ATTR_MELEE_DAMAGE, ATTR_ARMOR_RATING
MENU_NO_BUFFS, MENU_HEALTH, MENU_STAMINA, MENU_GOLD
MENU_LOADOUT, MENU_INVENTORY, MENU_SKILL_TREE
LOADOUT_TITLE, LOADOUT_SLOT_EMPTY, LOADOUT_REQUIRES_TAG
LOADOUT_SELECT_SLOT_FIRST, LOADOUT_SKILLS_AVAILABLE, LOADOUT_CONSUMABLES_AVAILABLE
HUD_COOLDOWN
SKILL_BLEEDING_STRIKE_NAME/DESC, SKILL_ATTACK_HEAVY_NAME/DESC
SKILL_POWER_STRIKE_NAME/DESC, SKILL_RECKLESS_STRIKE_NAME/DESC
SKILL_STUNNING_BLOW_NAME/DESC, SKILL_DODGE_NAME/DESC, SKILL_FIREBALL_NAME/DESC
```

---

## 6. Lo que queda fuera de este spike

- Pantalla de loadout para companions (diseño idéntico, spike separado)
- Serialización completa de `LoadoutState` en `SaveData`
- Integración del loadout con `CombatSystem` (el HUD envía acciones pero `CombatSystem` aún no lee el snapshot del loadout)
- Remapping de teclas en runtime
- Múltiples loadouts / builds por personaje
- Edición de atributos desde `PlayerMenuScreen`
- Visualización de buffs con nombre localizado (actualmente muestra el `buff_id` raw)
- `CombatHUD` visual: barras de recursos en lugar de labels de texto

---

*Spike cerrado. Todos los artefactos implementados y probados en exploración.*
