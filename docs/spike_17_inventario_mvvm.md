# Spike 17 — Inventario A: contrato MVVM, sin cambio visual

**Estado:** cerrado en la parte de código (17a). Validado en partida real en el contexto de overlay (tecla `I`); contextos PlayerMenu, narrativa y Esc anidado **sin confirmar** (ver §7).
**Fecha:** 2026-10-21 · **Godot:** 4.7.x
**Spec:** `spike_17_inventario_mvvm_spec.md` · **Plan del hito:** `plan_hito_rediseno_interfaces_spikes_14_24.md` §4

---

## 1. Resultado en una frase

La pantalla de inventario de producción (`ui/inventory/inventory_ui.gd`, raíz `CanvasLayer` `InventoryUi`) cumple ahora el contrato MVVM: la View es pasiva, todo acceso a sistemas core vive en `InventoryViewModel` (hijo de la View), con una única señal `changed(reason)`, intenciones `request_*()`, señal `closed`, nodos por nombre único `%`, textos con `tr()` y claves `INVENTORY_*`, y el código muerto eliminado. El aspecto no cambia salvo los cambios acordados (§6).

## 2. Decisión estructural (5.A)

Opciones: (A) reconstruir el ViewModel sobre el esqueleto muerto y mantener `inventory_ui.gd` como única View; (B) revivir `InventoryScreen` + `InventoryViewModel` tal cual.

**Se eligió A.** Motivos:
- La escena de producción (`inventory_ui.tscn`) ya existe, con su grid de 20 `ItemSlot`, y los tres contextos de apertura la instancian por ruta. Revivir `InventoryScreen` obligaba a una escena nueva con nodos distintos (cambio visual, riesgo alto en el spike de más riesgo del hito).
- El `InventoryViewModel` muerto no cubría lo que la pantalla hace hoy (estado de espera que podía quedarse atascado, lista fija de slots de equipo, comparación inexistente en producción).
- `inventory_screen.gd` no tenía ningún consumidor (comprobado con `Select-String`; no existe `.tscn`).

**Borrados:** `ui/inventory/inventory_screen.gd` y `inventory_screen.gd.uid`; `SceneOrchestrator.close_inventory()` (no la llamaba nadie y comparaba con `"InventoryUI"` mientras el nodo se llama `InventoryUi`).

## 3. Qué hay ahora

### `inventory_viewmodel.gd` (reconstruido)
- `enum InventoryState { HIDDEN, BROWSING, ITEM_SELECTED }` · data class `DetailData` · `signal changed(reason)` con razones `opened`, `inventory`, `equipment`, `stats`, `selection`, `feedback`, `closed`.
- Intenciones: `open()`, `request_close()`, `select_item()`, `request_use()`, `request_equip()`, `request_unequip_item()`, `request_unequip_slot()`, `request_equip_drop()`.
- Se suscribe a `EventBus` (`item_added/removed`, `item_use_success/failed`, `resource_changed`) y a `Equipment.item_equipped/item_unequipped` (el equipo tiene sus propias señales).
- Refrescos agrupados con `_mark_dirty()` + `call_deferred("_flush_dirty")`: equipar sobre un slot ocupado emite dos eventos seguidos y se pinta una sola vez, con el estado ya coherente.
- El mensaje de feedback lo decide el ViewModel (ya traducido): «X usado», «X equipado», «X desequipado», errores.
- `request_equip()` marca `_equip_request_item_id` para ignorar el `item_use_success` que el puente de ítems emite al equipar (si no, salía «usado»).

### `inventory_ui.gd` (View pasiva)
- Sin referencias a `Inventory`, `Equipment`, `Characters`, `Resources`, `Items`, `Party`, `Skills` ni `EventBus` (búsqueda con distinción de mayúsculas: vacía).
- Conserva `signal closed`, `@export entity_id`, `open_inventory()`, `close_inventory()`, `toggle()`.
- `_on_vm_changed(reason)` → `match` → `_render_*()`; razón desconocida → `push_warning`.
- Maneja `ui_cancel` (`set_input_as_handled()` + `close_inventory()`) solo cuando es visible.
- Si hay más ítems que huecos (20), `push_warning` en lugar de ocultarlos en silencio.

### Otros ficheros
- `item_detail_panel.gd`: textos por `tr()` (`INVENTORY_BUTTON_*`, `INVENTORY_DETAIL_*`).
- `feedback_popup.gd`: se oculta solo a los 2 s con un `Timer` creado por código (sin `await`, sin tocar la escena; un mensaje nuevo reinicia la cuenta); API intacta (`show_success`, `show_error`, `hide_message`). Nadie más lo usa (comprobado).
- `inventory_ui.tscn`: 10 nodos renombrados con `unique_name_in_owner` y sin texto fijo, 6 `slot_label_key` pasan a `INVENTORY_SLOT_*`. `item_detail_panel.tscn`: 2 textos retirados. Aplicado con `patch_spike17_scenes.ps1` (copias en `%TEMP%\athelia_spike17_*`).
- `localization/inventory.csv` (`id,en,es`, 29 claves `INVENTORY_*`). Alta manual en Project Settings → Localization → Translations.
- `core/scene_orchestrator.gd`: ver §4.

## 4. Hallazgos de motor (el spike los destapó)

1. **Dos pulsaciones para reabrir (inventario y Party).** `SceneOrchestrator` guarda un único `_current_overlay` y nunca escuchaba `closed`. Al cerrar con X o Esc la pantalla solo se ocultaba y seguía ocupando el slot; la siguiente pulsación de la tecla la tomaba por «overlay abierto, toggle» y la destruía. Arreglo: `open_inventory()` y `open_party()` conectan `closed` a un manejador genérico `_on_overlay_closed(overlay)` que libera la instancia (`_hide_current_overlay()` si sigue siendo la actual, `queue_free()` si no). Party ya emitía `closed`; solo faltaba el oyente. Comprobado en partida: «I» y «O» abren a la primera tras cerrar por cualquier vía.
2. **Esc no cerraba el inventario** (la spec lo daba por hecho). Nadie manejaba `ui_cancel` para esta pantalla. Ahora lo hace la View.
3. **Cabecera y detalle obsoletos tras usar una poción** (14 → 24 en el HUD, sin cambio en el inventario) y duplicado «HP: HP: 14». Resueltos al mover el refresco al ViewModel (`resource_changed` → `stats`; cambios de mochila/equipo → `selection`).
4. **Feedback**: sin mensaje al desequipar, «usado» al equipar y popup que nunca se ocultaba. Resueltos (§3).

## 5. Accesos a sistemas movidos al ViewModel

Unas 30 líneas de la View original: `Inventory.get_inventory/has_item/get_item_quantity/request_use_item`, `Equipment.get_equipped_item/is_item_equipped/can_equip_in_slot/equip_item/unequip_item/unequip_slot`, `Items.get_item`, `Resources.get_resource_amount`, `Characters.get_base_attribute` (antes con `get_node_or_null("/root/…")`), y las conexiones a `EventBus` y a las señales de `Equipment`.

## 6. Cambios visibles (acordados)

- Textos fijos en el idioma activo (título, cabeceras, etiquetas de estadísticas, nombres de slot, botones, detalle, mensajes).
- Desaparece el «HP: HP: 14» duplicado.
- Nombres de slot localizados y capitalizados («Cabeza», «Torso»…; en el mensaje de «no encaja» ya no sale el id crudo).
- Mensajes nuevos al equipar/desequipar y popup que se oculta solo.
- Esc cierra la pantalla.

## 7. Validación

**Confirmado en partida real (Fernando):**
- Overlay con la tecla `I`: abre y cierra sin doble pulsación; reabre varias veces sin problema.
- Esc cierra el inventario (overlay).
- Equipar y desequipar (botón); «X no encaja en Y» al arrastrar un ítem a un slot incorrecto.
- Poción: HP actualizado en el HUD y en la cabecera del inventario, y detalle al día.
- Mochila vacía: mensaje de «sin ítems».
- Party funciona; «O» abre a la primera tras el parche del orquestador (log: sin reaperturas fantasma, porque `party_ui.gd` consume la tecla con `set_input_as_handled()`).
- Pestaña Errors limpia; búsqueda de contrato vacía; feedback de equipar/desequipar y ocultado automático correctos.

**Sin confirmar en partida:**
- Contexto PlayerMenu (subpantalla) y contexto narrativa (sub-overlay), incluido el cierre con Esc en el anidado (la capa más profunda debe cerrar primero: el input no manejado se propaga de hijo a padre y la View lo consume).
- Mochila llena (más de 20 ítems): solo hay `push_warning`.
- Arrastre sobre un slot de equipo por la vía correcta (comprobado el caso «no encaja»; el feliz no está anotado).

## 8. Lecciones

- **Quien instancia libera, también el orquestador.** `SceneOrchestrator` instancia overlays con un slot único; si no conecta `closed`, la instancia oculta se queda como «overlay abierto» y la siguiente tecla la destruye. Todo overlay ligero que exponga `closed` necesita ese oyente.
- **Un toggle por tecla con instancias ocultas** da el síntoma «hay que pulsar dos veces»; el log lo delata (aparece `Overlay shown` solo en la segunda pulsación).
- **`ui_cancel` en pantallas anidadas:** el input no manejado se propaga de hijo a padre; cada pantalla consume con `set_input_as_handled()` y así solo cierra la más profunda.
- **`Select-String` no distingue mayúsculas:** `Items\.` casa con `bag_items.`. Para auditar contrato usar `-CaseSensitive`.
- **Un mensaje de feedback no debe depender de una señal ambigua:** el puente de ítems emite `item_use_success` también al equipar; el mensaje de equipar sale del evento de equipo.
- **Un timer de widget se crea por código** (`Timer` hijo) si no se quiere tocar la escena ni usar `await`.

## 9. Pendientes (no se arreglan en este spike)

- **Vender un objeto equipado** y **comprar con inventario lleno**: solo registrados, sin cambios. Observación nueva: `equip_item` no saca el objeto del inventario, y la mochila muestra el ítem equipado también en su hueco, sin marca de «equipado» (`DetailData.is_equipped` ya existe) → Spike 18.
- `equip_item` ignora el slot donde se suelta (elige el primer slot con tag coincidente): arrastrar a un slot concreto equipa en el que decida el sistema.
- `item_use_failed` y `equip_failed` traen el motivo como texto libre en inglés (`INVENTORY_ERROR_PREFIX` lo antepone sin traducir el motivo); `equip_failed` no se escucha.
- Nombres de modificadores del panel de detalle sin localizar («Armor Rating»).
- `ItemSlot`: pierde el resaltado al salir el ratón; ítem sin icono muestra el logo de Godot.
- Más de 20 ítems: los sobrantes no se muestran (warning).
- El `AnimationPlayer` de `feedback_popup.tscn` queda sin uso.
- Cerrar con la tecla (toggle del orquestador) libera la instancia sin pasar por `request_close()`: el log no imprime `[InventoryUI] Closed`. Inocuo.
- Comparación de ítems y compañero (puntos 7 y 9 de la validación original): no existen en producción → Spike 18.
- Boceto de rediseño (inspirado en The Witcher 3) → Spike 18; preguntar entonces por categorías/pestañas, peso/capacidad, comparación, orden y aspecto de slots y ficha.

## 10. Ficheros

| Fichero | Cambio |
|---|---|
| `ui/inventory/inventory_viewmodel.gd` | Reconstruido |
| `ui/inventory/inventory_ui.gd` | Reescrito (View pasiva) |
| `ui/inventory/item_detail_panel.gd` | Textos con `tr()` |
| `ui/inventory/feedback_popup.gd` | Ocultado automático con `Timer` |
| `ui/inventory/inventory_ui.tscn`, `item_detail_panel.tscn` | Parcheados con script |
| `ui/inventory/inventory_screen.gd` (+ `.uid`) | Borrados |
| `localization/inventory.csv` | Nuevo (29 claves) |
| `core/scene_orchestrator.gd` | `closed` conectado en `open_inventory()` y `open_party()`; `_on_overlay_closed()`; `close_inventory()` retirada |
