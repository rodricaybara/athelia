# Companions — Fase 2.4 — Equipamiento de companions

## Objetivo

Permitir al jugador gestionar el equipamiento y la mochila de cada companion desde
una pantalla dedicada de party, con transferencia de ítems mediante drag & drop.

## Archivos nuevos

| Archivo | Descripción |
|---------|-------------|
| `res://ui/party/party_ui.gd` | Script de la pantalla de party |
| `res://ui/party/party_ui.tscn` | Escena con layout de dos columnas |

## Archivos modificados

| Archivo | Cambio |
|---------|--------|
| `core/scene_orchestrator.gd` | Añadido `OVERLAY_PARTY` y método `open_party()` |
| `scenes/exploration/exploration_controller.gd` | Tecla `P` llama a `scene_orchestrator.open_party()` |
| `project.godot` | Action `open_party` → tecla `P` |

## Arquitectura de la pantalla

### Layout

```
┌─────────────────────────────────────────┐
│  PARTY                              [X] │
├──────────────────┬──────────────────────┤
│  Jugador         │  < Mira >            │
│  [head][body][…] │  [head][body][…]     │
│  [feet][wpn][sh] │  [feet][wpn][sh]     │
│  Mochila         │  Mochila             │
│  [·][·][·][·]    │  [·][·][·][·]        │
│  [·][·][·][·]    │  [·][·][·][·]        │
└──────────────────┴──────────────────────┘
```

Navegación `<` / `>` si hay más de un companion en el grupo.

### Apertura

Se abre con tecla `P` solo desde `EXPLORATION` — sin cambio de `GameState`.
`SceneOrchestrator.open_party()` instancia el overlay igual que el inventario.
Segunda pulsación de `P` o `Escape` cierra el panel.

### Drag & drop

Reutiliza los componentes existentes `ItemSlot` y `EquipSlot` sin modificaciones:
- `ItemSlot._get_drag_data()` ya emite `{item_id, source:"inventory"}`.
- `EquipSlot._can_drop_data()` ya acepta drops con `source=="inventory"`.

El drop sobre un `EquipSlot` de la columna contraria activa la transferencia
automática: `PartyUI._transfer_item(from, to, item_id)` mueve el ítem entre
`InventorySystem` y luego llama a `Equipment.equip_item()`.

### Transferencia de ítems

```gdscript
func _transfer_item(from_entity, to_entity, item_id, quantity=1) -> bool:
    Inventory.remove_item(from_entity, item_id, quantity)
    Inventory.add_item(to_entity, item_id, quantity)
    # rollback si add falla
```

### Click en slot de mochila

- Ítem `EQUIPMENT` → `Equipment.toggle_equipment(entity_id, item_id)`
- Ítem `CONSUMABLE` → `EventBus.item_use_requested.emit(entity_id, item_id)`

## Comportamiento verificado

```
[PartyUI] Transferido: iron_sword × 1  player → companion_mira
[EquipmentManager] ✓ Equipped 'iron_sword' in slot 'weapon' for 'companion_mira' (1 mods)
```

El equipamiento de Mira aplica modificadores a sus atributos vía
`CharacterSystem.add_equipped_modifier()` igual que el jugador.

## Notas de diseño

- `InventorySystem` y `EquipmentManager` ya registran companions en
  `PartyManager._register_in_systems()` — no se necesitó ningún cambio en sistemas core.
- La pantalla es completamente pasiva: no ejecuta lógica de negocio,
  solo delega en `Equipment`, `Inventory` y `EventBus`.
- El `SaveSystem` ya guarda y restaura el equipamiento de companions
  (implementado en Fase 1 en `PartyManager.get_save_state()`).
