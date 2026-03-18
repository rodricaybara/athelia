class_name WorldObjectBridge
extends Node

## WorldObjectBridge - Adaptador de efectos de interacción con WorldObjects
##
## RESPONSABILIDAD:
##   - Escuchar world_object_interaction_resolved del EventBus
##   - Aplicar efectos del outcome:
##       · loot_table_id   → entregar ítems vía InventorySystem
##       · narrative_event_id → disparar evento vía NarrativeSystem
##       · revealed_info_key  → emitir señal para UI (el panel lo muestra)
##       · feedback_key       → emitir señal para UI (feedback al jugador)
##
## NO HACE:
##   - Lógica de tiradas (eso es WorldObjectSystem)
##   - Gestión de flags (eso es WorldObjectSystem)
##   - Renderizado (eso es WorldObjectInteractionPanel)
##
## PATRÓN: Idéntico a ItemCharacterBridge — puro adaptador entre sistemas.
## Se instancia como nodo hijo en ExplorationTest (no es Autoload).

# ============================================
# CONFIGURACIÓN
# ============================================

## ID de la entidad que recibe el loot (en exploración, siempre "player")
@export var entity_id: String = "player"


# ============================================
# INICIALIZACIÓN
# ============================================

func _ready() -> void:
	EventBus.world_object_interaction_resolved.connect(_on_interaction_resolved)
	print("[WorldObjectBridge] Ready — listening for interaction results")


# ============================================
# CALLBACK PRINCIPAL
# ============================================

## Punto de entrada: WorldObjectSystem resolvió una interacción
func _on_interaction_resolved(
		instance_id: String,
		interaction_id: String,
		outcome: String,
		effect_data: Dictionary) -> void:

	print("[WorldObjectBridge] Resolved: instance=%s, interaction=%s, outcome=%s" % [
		instance_id, interaction_id, outcome
	])

	# Aplicar cada efecto presente en effect_data de forma independiente.
	# El orden importa: primero loot (recompensa visible), luego narrativa.

	if effect_data.has("loot_table_id"):
		_apply_loot(effect_data["loot_table_id"])

	if effect_data.has("narrative_event_id"):
		_apply_narrative_event(effect_data["narrative_event_id"])

	# revealed_info_key y feedback_key se re-emiten para que la UI los consuma.
	# El Bridge no renderiza texto — solo propaga la señal con los datos necesarios.
	if effect_data.has("revealed_info_key") or effect_data.has("feedback_key"):
		_emit_ui_feedback(instance_id, interaction_id, outcome, effect_data)


# ============================================
# APLICAR LOOT
# ============================================

## Resuelve una loot table y entrega los ítems al inventario de entity_id
func _apply_loot(loot_table_id: String) -> void:
	var loot_table: LootTableDefinition = WorldObjects.get_loot_table(loot_table_id)
	if loot_table == null:
		push_error("[WorldObjectBridge] Loot table not found: %s" % loot_table_id)
		return

	var delivered_count := 0

	for entry in loot_table.entries:
		# Tirar dado de chance
		if randf() > entry.chance:
			print("[WorldObjectBridge]   skip %s (chance %.2f)" % [entry.item_id, entry.chance])
			continue

		# Gold y otros recursos van a ResourceSystem, no a Inventory
		var resources = get_node_or_null("/root/Resources")
		if entry.item_id == "gold" and resources:
			resources.add_resource(entity_id, "gold", float(entry.quantity))
			print("[WorldObjectBridge]   ✓ loot: %dx gold → ResourceSystem (%s)" % [
				entry.quantity, entity_id
			])
			delivered_count += 1
			continue

		# Ítems normales: validar en ItemRegistry y añadir a Inventory
		if not Items.has_item(entry.item_id):
			push_warning("[WorldObjectBridge] Item not in registry: %s — skipped" % entry.item_id)
			continue

		var added := Inventory.add_item(entity_id, entry.item_id, entry.quantity)
		if added:
			print("[WorldObjectBridge]   ✓ loot: %dx %s → %s" % [
				entry.quantity, entry.item_id, entity_id
			])
			delivered_count += 1
		else:
			push_warning("[WorldObjectBridge]   ✗ failed to add %s to inventory" % entry.item_id)

	print("[WorldObjectBridge] Loot resolved: %d/%d entries delivered from '%s'" % [
		delivered_count, loot_table.entries.size(), loot_table_id
	])


# ============================================
# APLICAR NARRATIVA
# ============================================

## Dispara un evento narrativo en NarrativeSystem
func _apply_narrative_event(narrative_event_id: String) -> void:
	var narrative = get_node_or_null("/root/Narrative")
	if narrative == null:
		push_warning("[WorldObjectBridge] NarrativeSystem not found — skipping event '%s'" % narrative_event_id)
		return

	var success: bool = narrative.apply_event(narrative_event_id)
	if success:
		print("[WorldObjectBridge]   ✓ narrative event triggered: %s" % narrative_event_id)
	else:
		push_warning("[WorldObjectBridge]   ✗ narrative event not found: %s" % narrative_event_id)


# ============================================
# PROPAGAR FEEDBACK A UI
# ============================================

## Re-emite los datos de UI para que WorldObjectInteractionPanel los muestre
## El Bridge no sabe cómo renderizar — solo propaga lo que tiene
func _emit_ui_feedback(
		instance_id: String,
		interaction_id: String,
		outcome: String,
		effect_data: Dictionary) -> void:

	# La señal world_object_feedback_ready lleva todo lo que la UI necesita
	# para mostrar el resultado sin consultar otros sistemas
	EventBus.world_object_feedback_ready.emit(
		instance_id,
		interaction_id,
		outcome,
		effect_data.get("feedback_key", ""),
		effect_data.get("revealed_info_key", "")
	)
