class_name ItemCharacterBridge
extends Node

## ItemCharacterBridge - Integración Item→Character (FASE 1+2 del Spike)
##
## RESPONSABILIDAD:
##   - Escuchar eventos de uso de ítems
##   - Aplicar modificadores a CharacterSystem y ResourceSystem (FASE 1)
##   - Delegar equipamiento a EquipmentManager (FASE 2)
##   - Emitir eventos de resultado
##
## NO MODIFICA:
##   - ItemSystem
##   - CharacterSystem  
##   - InventorySystem
##   - AttributeResolver
##
## Este es código de integración puro - actúa como adaptador entre sistemas

# ============================================
# INICIALIZACIÓN
# ============================================

func _ready():
	# Conectar al evento de uso de ítems
	EventBus.item_use_requested.connect(_on_item_use_requested)
	
	print("[ItemCharacterBridge] FASE 1+2 - Consumibles + Equipment integration ready")


# ============================================
# CASO 1: CONSUMIBLES (FASE 1)
# ============================================

## Callback: usuario solicita usar un ítem
func _on_item_use_requested(entity_id: String, item_id: String):
	# 1. Validar que la entidad existe en CharacterSystem
	if not Characters.has_entity(entity_id):
		EventBus.item_use_failed.emit(entity_id, item_id, "Entity not registered in CharacterSystem")
		print("[ItemCharacterBridge] ✗ Entity '%s' not found in CharacterSystem" % entity_id)
		return
	
	# 2. Obtener definición del ítem
	var item_def = Items.get_item(item_id)
	if not item_def:
		EventBus.item_use_failed.emit(entity_id, item_id, "Item definition not found")
		print("[ItemCharacterBridge] ✗ Item '%s' not found in ItemRegistry" % item_id)
		return
	
	# 3. Validar que sea usable
	if not item_def.usable:
		EventBus.item_use_failed.emit(entity_id, item_id, "Item is not usable")
		print("[ItemCharacterBridge] ✗ Item '%s' is not usable" % item_id)
		return
	
	# 4. Aplicar según tipo de ítem
	match item_def.item_type:
		"CONSUMABLE":
			_apply_consumable(entity_id, item_def)
		
		"EQUIPMENT":
			_handle_equipment(entity_id, item_def)
		
		_:
			EventBus.item_use_failed.emit(entity_id, item_id, "Unknown item type: %s" % item_def.item_type)
			print("[ItemCharacterBridge] ✗ Unknown item type: %s" % item_def.item_type)


# ============================================
# CASO 2: EQUIPAMIENTO (FASE 2)
# ============================================

## Maneja solicitud de equipar/desequipar
func _handle_equipment(entity_id: String, item_def: ItemDefinition):
	# Verificar que el jugador tenga el ítem en inventario
	if not Inventory.has_item(entity_id, item_def.id):
		EventBus.item_use_failed.emit(entity_id, item_def.id, "Item not in inventory")
		print("[ItemCharacterBridge] ✗ Item '%s' not in inventory" % item_def.id)
		return
	
	# Delegar a EquipmentManager (toggle: equipa si no está, desequipa si está)
	var success = Equipment.toggle_equipment(entity_id, item_def.id)
	
	if success:
		EventBus.item_use_success.emit(entity_id, item_def.id)
	else:
		# EquipmentManager ya emitió equip_failed con razón específica
		EventBus.item_use_failed.emit(entity_id, item_def.id, "Equipment operation failed")


# ============================================
# CASO 1: CONSUMIBLES (FASE 1)
# ============================================


## Aplica los modificadores de un consumible.
## Si el ítem tiene learning_data, ejecuta una LearningSession además.
func _apply_consumable(entity_id: String, item_def: ItemDefinition):
	# ── Ruta A: Libro de aprendizaje ──────────────────────────────────────────
	# Si el ítem declara learning_data, construimos y ejecutamos una LearningSession.
	# El ítem se consume igualmente al final (item_use_success lo gestiona).
	if not item_def.learning_data.is_empty():
		_apply_learning(entity_id, item_def)
		# Un libro puede tener también modificadores de recurso (por ejemplo +stamina).
		# Si los tiene, los aplicamos también. Si no, simplemente consumimos.
		var modifiers = item_def.get_modifiers_for_condition("on_use")
		if not modifiers.is_empty():
			for mod in modifiers:
				_apply_single_modifier(entity_id, mod, item_def.id)
		EventBus.item_use_success.emit(entity_id, item_def.id)
		return

	# ── Ruta B: Consumible estándar (poción, etc.) ────────────────────────────
	var modifiers = item_def.get_modifiers_for_condition("on_use")

	if modifiers.is_empty():
		print("[ItemCharacterBridge] ⚠ Warning: Consumable '%s' has no 'on_use' modifiers" % item_def.id)
		EventBus.item_use_success.emit(entity_id, item_def.id)
		return

	var applied_count = 0
	for mod in modifiers:
		if _apply_single_modifier(entity_id, mod, item_def.id):
			applied_count += 1

	EventBus.item_use_success.emit(entity_id, item_def.id)

	print("[ItemCharacterBridge] ✓ Consumable '%s' applied %d modifiers to '%s'" % [
		item_def.id, applied_count, entity_id
	])


## Construye y ejecuta una LearningSession a partir del learning_data del ítem.
func _apply_learning(entity_id: String, item_def: ItemDefinition) -> void:
	var data        = item_def.learning_data
	var skill_id    = data.get("skill_id", "")
	var src_level   = data.get("source_level", 30)
	var src_type    = data.get("source_type", "BOOK")

	if skill_id.is_empty():
		push_error("[ItemCharacterBridge] learning_data missing 'skill_id' in item '%s'" % item_def.id)
		return

	var session = LearningSession.create(entity_id, skill_id, src_level, src_type)

	var progression = get_node_or_null("/root/SkillProgression")
	if not progression:
		push_error("[ItemCharacterBridge] SkillProgressionService not found at /root/SkillProgression")
		return

	var result: Dictionary = progression.execute_learning_session(session)

	if result["reason"] == "challenge_too_low":
		print("[ItemCharacterBridge] 📖 '%s': fuente demasiado básica para mejorar '%s'" % [
			item_def.id, skill_id
		])
	elif result["improved"]:
		print("[ItemCharacterBridge] 📖 '%s': '%s' mejorada %d → %d" % [
			item_def.id, skill_id, result["old_value"], result["new_value"]
		])
	else:
		print("[ItemCharacterBridge] 📖 '%s': '%s' sin mejora (roll %d vs %d)" % [
			item_def.id, skill_id, result["roll"], result["threshold"]
		])


## Aplica un modificador individual.
## Retorna true si se aplicó correctamente.
##
## Formato de target:
##   "resource.health"              → tipo=resource, id=health
##   "attribute.strength"           → tipo=attribute, id=strength
##   "skill.exploration.lockpick"   → tipo=skill, id=skill.exploration.lockpick
##
## El tipo es siempre la primera sección antes del primer punto.
## El id es todo lo que viene después (puede contener más puntos).
func _apply_single_modifier(entity_id: String, mod: ModifierDefinition, item_id: String) -> bool:
	var dot_pos := mod.target.find(".")
	if dot_pos == -1:
		push_warning("[ItemCharacterBridge] Invalid modifier target (no dot): '%s'" % mod.target)
		return false

	var target_type := mod.target.left(dot_pos)           # "resource" | "attribute" | "skill"
	var target_id   := mod.target.substr(dot_pos + 1)     # "health" | "strength" | "exploration.lockpick"

	match target_type:
		"resource":
			return _apply_to_resource(entity_id, target_id, mod, item_id)
		"attribute":
			return _apply_to_attribute(entity_id, target_id, mod, item_id)
		"skill":
			return _apply_to_skill(entity_id, target_id, mod, item_id)
		_:
			push_warning("[ItemCharacterBridge] Unknown target type: '%s' in '%s'" % [target_type, mod.target])
			return false


## Aplica modificador a un RECURSO (health, stamina, etc.)
## IMPORTANTE: Afecta el valor ACTUAL, NO el máximo
func _apply_to_resource(entity_id: String, resource_id: String, mod: ModifierDefinition, item_id: String) -> bool:
	# Verificar que el recurso existe
	var resource_state = Resources.get_resource_state(entity_id, resource_id)
	if not resource_state:
		push_warning("[ItemCharacterBridge] Resource '%s' not found for entity '%s'" % [resource_id, entity_id])
		return false
	
	# Aplicar según operación
	match mod.operation:
		"add":
			var added = Resources.add_resource(entity_id, resource_id, mod.value)
			print("[ItemCharacterBridge]   resource.%s += %.1f (actual: +%.1f)" % [
				resource_id, mod.value, added
			])
			return true
		
		"mul":
			var current = Resources.get_resource_amount(entity_id, resource_id)
			var new_value = current * mod.value
			Resources.set_resource(entity_id, resource_id, new_value)
			print("[ItemCharacterBridge]   resource.%s *= %.2f (%.1f → %.1f)" % [
				resource_id, mod.value, current, new_value
			])
			return true
		
		"override":
			Resources.set_resource(entity_id, resource_id, mod.value)
			print("[ItemCharacterBridge]   resource.%s = %.1f" % [resource_id, mod.value])
			return true
		
		_:
			push_warning("[ItemCharacterBridge] Unknown operation: '%s'" % mod.operation)
			return false


## Aplica modificador a un ATRIBUTO BASE (strength, dexterity, etc.)
## IMPORTANTE: Esto modifica el atributo BASE, no un derivado
## Para buffs temporales → usar FASE 5 (temporary states)
func _apply_to_attribute(entity_id: String, attr_id: String, mod: ModifierDefinition, item_id: String) -> bool:
	# Aplicar según operación
	match mod.operation:
		"add":
			var old_value = Characters.get_base_attribute(entity_id, attr_id)
			Characters.modify_base_attribute(entity_id, attr_id, mod.value)
			var new_value = Characters.get_base_attribute(entity_id, attr_id)
			print("[ItemCharacterBridge]   attribute.%s += %.1f (%.1f → %.1f)" % [
				attr_id, mod.value, old_value, new_value
			])
			return true
		
		"mul":
			var current = Characters.get_base_attribute(entity_id, attr_id)
			var new_value = current * mod.value
			Characters.set_base_attribute(entity_id, attr_id, new_value)
			print("[ItemCharacterBridge]   attribute.%s *= %.2f (%.1f → %.1f)" % [
				attr_id, mod.value, current, new_value
			])
			return true
		
		"override":
			var old_value = Characters.get_base_attribute(entity_id, attr_id)
			Characters.set_base_attribute(entity_id, attr_id, mod.value)
			print("[ItemCharacterBridge]   attribute.%s = %.1f (was %.1f)" % [
				attr_id, mod.value, old_value
			])
			return true
		
		_:
			push_warning("[ItemCharacterBridge] Unknown operation: '%s'" % mod.operation)
			return false

## Aplica un modificador a una SKILL.
## duration_type="next_skill_roll" → registra bonus pendiente, se consume en el próximo roll.
## duration_type="permanent"       → modifica skill_value directamente.
func _apply_to_skill(entity_id: String, skill_id: String, mod: ModifierDefinition, item_id: String) -> bool:
	if mod.duration_type == "next_skill_roll":
		var target_skill := mod.duration_skill_target if not mod.duration_skill_target.is_empty() else skill_id
		Characters.add_pending_skill_modifier(entity_id, target_skill, int(mod.value))
		print("[ItemCharacterBridge]   skill.%s pending +%d (next roll) for '%s'" % [
			target_skill, int(mod.value), entity_id
		])
		return true

	if mod.operation == "add":
		Characters.modify_skill_value(entity_id, skill_id, int(mod.value))
		print("[ItemCharacterBridge]   skill.%s += %d (permanent) for '%s'" % [
			skill_id, int(mod.value), entity_id
		])
		return true

	push_warning("[ItemCharacterBridge] Unsupported operation '%s' for skill modifier (item: %s)" % [
		mod.operation, item_id
	])
	return false

# ============================================
# NOTAS DE DISEÑO
# ============================================

## NOTA 1: ¿Por qué no se toca ItemDefinition ni CharacterSystem?
## 
## Separación de responsabilidades:
## - ItemDefinition: describe QUÉ ES un ítem (datos puros)
## - CharacterSystem: gestiona estado de personajes
## - ItemCharacterBridge: traduce modificadores a acciones
##
## Esto permite:
## - Cambiar cómo se aplican modificadores sin tocar ítems
## - Testear sistemas de forma aislada
## - Reemplazar el bridge si surge mejor arquitectura

## NOTA 2: ¿Por qué modificadores a recursos afectan CURRENT, no MAX?
##
## Diseño deliberado:
## - Pociones curan salud ACTUAL (no aumentan máximo)
## - Buffs de equipamiento afectan atributos base, que recalculan máximos
## - Para buffs temporales de máximos → FASE 5 (temporary states)

## NOTA 3: ¿Qué pasa con modificadores "equipped"?
##
## FASE 2 - Sistema de Equipamiento
## Por ahora solo procesamos "on_use"
## Los modificadores "equipped" se procesarán en EquipmentManager

## NOTA 4: ¿Validaciones de coste de uso?
##
## FASE 3 - Contexto de Uso
## Por ahora cualquier ítem usable se puede usar siempre
## Restricciones de combate/contexto en siguiente fase
