# Spike 18 — Inventario B: rediseño con el Design System

**Estado:** cerrado y validado por Fernando (2026-10-22). Partida real a 1152×648 y 1680×1050, en los tres contextos de apertura, más el bloque «Bonos del equipo».
**Hito:** rediseño de interfaces, spikes 14–24. **Depende de:** 15 (Design System) y 17 (contrato MVVM del inventario).
**Resumen:** la pantalla de inventario se rehace con `UIPanel` (OVERLAY + marco decorativo), `UIButton`, `UISlot` (primer consumidor real) y solo `UITokens`. Añade categorías, capacidad y peso, comparación de equipo, bloque de estadísticas, bonos del equipo y marca de «equipado». El contrato MVVM del Spike 17 no cambia.

---

## 1. Alcance y reglas respetadas

- Vista pasiva; `InventoryViewModel` es hijo de la View y es el único que habla con los sistemas core.
- Se conservan los contratos públicos: `open_inventory()`, `close_inventory()`, `toggle()`, `closed`, `@export entity_id`.
- Tres contextos de apertura sin cambios: overlay del orquestador (`I`), subpantalla de PlayerMenu (`P`) y sub-overlay de narrativa. Esc cierra solo la capa más profunda.
- `SceneOrchestrator` no se toca.
- `item_slot` y `equip_slot` antiguos se quedan: los sigue usando Party (Spike 19).
- Sin `Color(...)` literales ni tamaños de fuente sueltos; todo texto por `tr()` con claves `INVENTORY_*`.
- Layout con anclas y fracciones para 1152×648 mínimo; probado a 1680×1050.

## 2. Decisiones de diseño

| Tema | Decisión |
|---|---|
| Categorías | Pestañas de `UIButton` SM: Todo, Armas, Armadura, Consumibles, Misión. Se definen en datos (`data/ui/inventory_categories.json`, versión 1, primera coincidencia por prioridad: quest 10, weapons 20, armor 30, consumables 40). |
| Capacidad | `inventory_slots` de `CharacterDefinition` (20 por defecto; Mira 15). Un único punto de cálculo: `_compute_capacity()`. |
| Desbordamiento | Los ítems que no caben se muestran igualmente, con borde discontinuo de peligro (antes se perdían con un `push_warning`). |
| Equipado | Marca «E» y tooltip en la mochila; `equip_item` no saca el objeto del inventario. |
| Comparación | El detalle muestra la diferencia de modificadores frente al ítem equipado en el mismo slot. |
| Estadísticas | Bloque inferior con valores **base** (salud, aguante, atributos); el foco existe pero está oculto. |
| Fullscreen | Marco con tamaño máximo (1400×820) centrado y fondo opaco para que no se vea la pantalla de atrás. |
| Bonos del equipo | Bloque entre el detalle y las estadísticas: suma por objetivo de los modificadores `add` de todo lo equipado (mismo criterio que la comparación), verde si suma y rojo si resta; «Sin bonos de equipo» si no hay. Se añadió tras ver el espacio libre a pantalla completa, con OK explícito de Fernando. |
| Feedback | `FeedbackPopup` centrado sobre la parte baja de la columna de la mochila, para no tapar HP/ST. |

## 3. Layout final

```
InventoryUi (CanvasLayer, layer 10)
├── Backdrop (ColorRect, COLOR_BG oscurecido 0,4, opaco, mouse STOP)
├── Frame (UIPanel OVERLAY, padding 16, marco decorativo; rect calculado en código)
│   └── Root (VBox)
│       ├── Header: TitleLabel · GoldLabel · WeightLabel · SlotsLabel · CloseButton (UIButton GHOST, min_square 32)
│       └── Content (HBox)
│           ├── EquipColumn: 6 UISlot (head, body, hands, feet, weapon, shield), etiqueta dentro del slot
│           ├── BagColumn (ratio 0,42): CategoryTabs (HFlow) · BagScroll > BagGrid (pool de UISlot) · EmptyCategoryLabel
│           └── RightColumn (ratio 0,58): DetailPanel · BonusBlock (UIPanel DEFAULT: BonusHeader, BonusFlow, BonusEmptyLabel) · StatsBlock (UIPanel DEFAULT, StatsGrid)
└── FeedbackPopup
```

Constantes: `FRAME_FRACTION = 0.9`, `FRAME_MAX_SIZE = Vector2(1400, 820)`, `POPUP_MARGIN = 8`, `BAG_GAP = 8`, `SCROLLBAR_RESERVE = 12`. `_update_frame_rect()` se conecta a `size_changed` y se llama al abrir; `_update_grid_columns()` ajusta las columnas de la mochila al ancho real.

## 4. Ficheros

**Nuevos**
- `data/ui/inventory_categories.json`
- `ui/design_system/assets/icons/icon_item_placeholder.png` (64×64, silueta de bolsa)
- `ui/design_system/tests/ui_slot_drag_test.gd/.tscn` (prueba aislada de `UISlot`, solo desarrollo)

**Reescritos o ampliados**
- `ui/design_system/components/ui_slot/ui_slot.gd/.tscn`
- `ui/inventory/inventory_viewmodel.gd`, `inventory_ui.gd/.tscn`, `item_detail_panel.gd/.tscn`, `feedback_popup.gd/.tscn`
- `localization/inventory.csv`: de 29 a 58 claves (`id,en,es`; las dos últimas, `INVENTORY_BONUS_HEADER` e `INVENTORY_BONUS_EMPTY`, del bloque de bonos)

**Sin tocar:** `item_slot`, `equip_slot`, `scene_orchestrator.gd`, `player_menu_*`, `narrative_scene_panel.gd`.

## 5. ViewModel

- Data classes nuevas: `BagEntry`, `CategoryData`, `StatEntry`, `ModLine`, `CompareLine`; `DetailData` gana `category`, `modifier_lines` y `comparison`.
- Estado nuevo: `capacity`, `used_slots`, `total_weight`, `categories`, `active_category`, `bag_entries`, `equipment_slot_ids`, `stat_entries`.
- Razones de `changed`: `opened, inventory, equipment, stats, selection, categories, feedback, closed` (`categories` es la nueva). La View tiene su caso para cada una.
- Bonos del equipo: `equipment_bonuses: Array[ModLine]`, reconstruido en `_rebuild_equipment_bonuses()` dentro de `_rebuild_equipment()`, así que sale con la razón `equipment` (sin razón nueva).
- Intención nueva: `select_category()`. Ayudas: `slot_display_name()`, `is_over_capacity()`.
- Escucha `Equipment.equip_failed` (mensaje genérico, sin duplicados). Los motivos de fallo siguen siendo texto libre en inglés, así que no se muestran.
- El peso usa `instance.definition.get_total_weight(instance.quantity)`.

## 6. `UISlot` — API tras este spike

- **Contenido:** `set_item(ItemInstance)`, `set_definition(definition, quantity = 1)`, `clear()`, `get_item_id()`, `is_empty()` (por `_item_id`).
- **Exports:** `slot_size`, `accept_drops`, `draggable`, `drop_source_filter`, `equipment_slot_id`, `border_color_override`, `slot_label_text`, `equipped_mark_text`.
- **Estado visual:** `set_selected()`, `set_equipped_mark()`, `set_overflow()` (borde discontinuo con `_draw`).
- **Señales:** `slot_clicked(slot)`, `slot_drop_received(slot, item_id)`, hover.
- **Comportamiento:** el clic se emite al **soltar** el botón dentro del slot (así no compite con el arrastre). Sin icono se usa el placeholder, teñido con `COLOR_TEXT_MUTED`. Arrastre y drop con `_get_drag_data` / `_can_drop_data` / `_drop_data`.
- **Hijos por nombre único:** `Content/Icon`, `Overlay` con `QuantityLabel`, `SlotLabel`, `EquippedMark`.
- **Limitación conocida:** el estado `DISABLED` usa `modulate`.

## 7. Validación en partida real

Batería completada (tres contextos, anidado, arrastre, Party intacto, reinicio de sesión):
- Abrir y cerrar con `I`, reabrir sin doble pulsación; Esc; subpantalla de PlayerMenu; sub-overlay de narrativa; Esc anidado cierra solo la capa más profunda.
- Equipar y desequipar por botón, por clic en slot y por arrastre; mensaje «no encaja» en slot erróneo; usar poción con HUD y cabecera actualizados.
- Pestañas de categoría; desbordamiento con `inventory_slots` = 4 y 7; Party sin cambios; reinicio de sesión limpio.
- Fase 4a: fondo opaco, marco centrado a 1152×648 y 1680×1050, popup sobre la mochila.
- Bloque «Bonos del equipo»: validado por Fernando el 2026-10-22 (sin incidencias reportadas; no se detallaron las capturas).
- **No probado:** redimensionado en caliente (el entorno de pruebas no lo permite). Cubierto por inspección: `size_changed` recalcula el marco.

## 8. Hallazgos y lecciones

1. **Un `PanelContainer` apila a sus hijos** (ya registrado en el 16): el bloque de estadísticas y el detalle exigen un único contenedor de layout por panel.
2. **El clic de un slot arrastrable debe emitirse al soltar**, no al pulsar; si no, cada arrastre dispara una selección.
3. **Una subclase de `UIPanel` debe llamar a `super._ready()`**; si no, el estilo no se aplica.
4. **Un marco sin tope se ve vacío a pantalla completa.** Tamaño máximo + fondo opaco resolvieron la queja de Fernando («en fullscreen está muy vacío»). El espacio libre restante en las columnas se aceptó.
5. **Una etiqueta bajo cada slot de equipo no cabe en 648 de alto** con seis slots: va dentro del slot (aceptado).
6. **Los valores base de las estadísticas no son los efectivos.** Falta verificar con `AttributeResolver` cuál debe mostrarse.
7. **Las UID de los `.tscn` nuevos** las regenera Godot (aviso inofensivo al abrir).

## 9. Pendientes que deja

**Del propio spike**
- Estadísticas efectivas frente a base (`AttributeResolver`).
- `INVENTORY_BAG_HEADER` e `INVENTORY_STATS_HEADER` definidas sin uso; los bonos suman solo modificadores `add` (los `mul`/`override` no se reflejan); `INVENTORY_STAT_FOCUS` definida pero oculta.
- La pestaña «Misión» pasa a una segunda fila a 1152×648 (aceptado).
- `UISlot` `DISABLED` por `modulate`.
- Comentarios obsoletos «UISlot.setup()» en escenas de combate.

**Registrados, no corregidos (decisión de alcance)**
- Vender un objeto equipado deja el slot de equipo apuntando a un objeto vendido.
- Comprar con inventario lleno está permitido (`buy_item` omite la validación de espacio).
- `equip_item` no recibe el slot de destino; un arrastre a un slot concreto equipa donde decida el sistema.
- Motivos de `equip_failed` en texto libre: hace falta un cambio de core para códigos de motivo.
- Mecanismo de aumento de capacidad (premium, monedas, magia): un único punto, `_compute_capacity()`.

**De otros spikes**
- La tecla `I` dentro de PlayerMenu cierra el menú entero (pila del orquestador).
- `base_damage` frente a `melee_damage` (`steel_sword` / `iron_sword`) incoherentes; `amulet_strength` sin tag de slot.
- Party: 8 `ItemSlot` fijos por columna frente a capacidad 20/15; la mochila de Mira no es accesible desde `InventoryUI` → Spike 19.
- `narrative_scene_panel.gd` conserva un `print` `[DIAG]` en `_input`.

## 10. Cómo reconstruir el estado a partir de este informe

Los ficheros viven en el proyecto Godot de Fernando. Para continuar en el 19, partir de `UISlot` (sección 6) y del patrón de columnas del inventario (sección 3). Party sustituye `item_slot`/`equip_slot` por `UISlot`, y entonces ambos pueden retirarse.
