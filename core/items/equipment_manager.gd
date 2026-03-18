class_name EquipmentManager
extends Node

## EquipmentManager - Gestor de equipamiento (FASE 2 del Spike)
##
## RESPONSABILIDAD:
##   - Mantener estado de equipamiento por entidad
##   - Validar slots disponibles según CharacterDefinition
##   - Equipar/desequipar con aplicación de modificadores
##   - Emitir eventos de equipamiento
##
## INTEGRACIÓN:
##   - Lee slots desde CharacterDefinition.equipment_slots
##   - Aplica modificadores vía Characters.add_equipped_modifier()
##   - Valida tags de ítems contra slots disponibles
##
## NO MODIFICA:
##   - ItemSystem
##   - CharacterSystem
##   - InventorySystem

# ============================================
# SEÑALES
# ============================================

## Emitido cuando se equipa un ítem exitosamente
signal item_equipped(entity_id: String, item_id: String, slot: String)

## Emitido cuando se desequipa un ítem exitosamente
signal item_unequipped(entity_id: String, item_id: String, slot: String)

## Emitido cuando falla equipar (slot no válido, requisitos, etc.)
signal equip_failed(entity_id: String, item_id: String, reason: String)


# ============================================
# ESTADO
# ============================================

## Equipamiento actual: { entity_id: { slot: item_id } }
var _equipped: Dictionary = {}


# ============================================
# INICIALIZACIÓN
# ============================================

func _ready():
	# Conectar al bridge para interceptar ítems de tipo EQUIPMENT
	print("[EquipmentManager] FASE 2 - Equipment system ready")


# ============================================
# REGISTRO DE ENTIDADES
# ============================================

## Registra una entidad para equipamiento
## Se llama automáticamente al intentar equipar por primera vez
func register_entity(entity_id: String):
	if _equipped.has(entity_id):
		return
	
	_equipped[entity_id] = {}
	print("[EquipmentManager] Registered entity: %s" % entity_id)


## Desregistra una entidad
func unregister_entity(entity_id: String):
	if _equipped.erase(entity_id):
		print("[EquipmentManager] Unregistered entity: %s" % entity_id)


# ============================================
# EQUIPAR / DESEQUIPAR
# ============================================

## Intenta equipar un ítem
## Retorna true si se equipó correctamente
func equip_item(entity_id: String, item_id: String) -> bool:
	# 1. Validar que la entidad existe en CharacterSystem
	if not Characters.has_entity(entity_id):
		equip_failed.emit(entity_id, item_id, "Entity not in CharacterSystem")
		return false
	
	# 2. Obtener definición del ítem
	var item_def = Items.get_item(item_id)
	if not item_def:
		equip_failed.emit(entity_id, item_id, "Item definition not found")
		return false
	
	# 3. Validar que es equipable
	if item_def.item_type != "EQUIPMENT":
		equip_failed.emit(entity_id, item_id, "Item is not equipment type")
		return false
	
	# 4. Determinar slot del ítem
	var slot = _determine_slot(entity_id, item_def)
	if slot.is_empty():
		equip_failed.emit(entity_id, item_id, "No valid equipment slot for this item")
		return false
	
	# 5. Auto-registrar si es necesario
	if not _equipped.has(entity_id):
		register_entity(entity_id)
	
	# 6. Desequipar ítem actual en ese slot (si existe)
	var current_item = _equipped[entity_id].get(slot, "")
	if not current_item.is_empty():
		_unequip_internal(entity_id, slot)
	
	# 7. Equipar nuevo ítem
	_equipped[entity_id][slot] = item_id
	
	# 8. Aplicar modificadores
	var modifiers = item_def.get_modifiers_for_condition("equipped")
	for mod in modifiers:
		Characters.add_equipped_modifier(entity_id, mod)
	
	# 9. Emitir evento
	item_equipped.emit(entity_id, item_id, slot)
	
	print("[EquipmentManager] ✓ Equipped '%s' in slot '%s' for '%s' (%d mods)" % [
		item_id, slot, entity_id, modifiers.size()
	])
	
	return true


## Intenta desequipar un ítem de un slot
## Retorna true si se desequipó correctamente
func unequip_slot(entity_id: String, slot: String) -> bool:
	if not _equipped.has(entity_id):
		return false
	
	if not _equipped[entity_id].has(slot):
		return false
	
	return _unequip_internal(entity_id, slot)


## Intenta desequipar un ítem específico (busca en qué slot está)
## Retorna true si se desequipó correctamente
func unequip_item(entity_id: String, item_id: String) -> bool:
	if not _equipped.has(entity_id):
		return false
	
	# Buscar en qué slot está equipado
	for slot in _equipped[entity_id].keys():
		if _equipped[entity_id][slot] == item_id:
			return _unequip_internal(entity_id, slot)
	
	return false


## Implementación interna de desequipar
func _unequip_internal(entity_id: String, slot: String) -> bool:
	var item_id = _equipped[entity_id].get(slot, "")
	if item_id.is_empty():
		return false
	
	# Obtener definición del ítem
	var item_def = Items.get_item(item_id)
	if not item_def:
		push_warning("[EquipmentManager] Cannot find definition for equipped item: %s" % item_id)
		_equipped[entity_id].erase(slot)
		return false
	
	# Remover modificadores
	var modifiers = item_def.get_modifiers_for_condition("equipped")
	for mod in modifiers:
		Characters.remove_equipped_modifier(entity_id, mod)
	
	# Limpiar slot
	_equipped[entity_id].erase(slot)
	
	# Emitir evento
	item_unequipped.emit(entity_id, item_id, slot)
	
	print("[EquipmentManager] ✓ Unequipped '%s' from slot '%s' for '%s'" % [
		item_id, slot, entity_id
	])
	
	return true


# ============================================
# TOGGLE (Equipar/Desequipar según estado)
# ============================================

## Toggle: equipa si no está equipado, desequipa si está equipado
## Usado por el Bridge cuando el usuario hace clic en "Usar" un ítem equipable
func toggle_equipment(entity_id: String, item_id: String) -> bool:
	# Verificar si ya está equipado
	if is_item_equipped(entity_id, item_id):
		return unequip_item(entity_id, item_id)
	else:
		return equip_item(entity_id, item_id)


# ============================================
# CONSULTAS
# ============================================

## Verifica si un ítem específico está equipado
func is_item_equipped(entity_id: String, item_id: String) -> bool:
	if not _equipped.has(entity_id):
		return false
	
	for slot_item in _equipped[entity_id].values():
		if slot_item == item_id:
			return true
	
	return false


## Verifica si un slot tiene algo equipado
func is_slot_occupied(entity_id: String, slot: String) -> bool:
	if not _equipped.has(entity_id):
		return false
	
	return _equipped[entity_id].has(slot) and not _equipped[entity_id][slot].is_empty()


## Obtiene el ítem equipado en un slot
## Retorna "" si el slot está vacío
func get_equipped_item(entity_id: String, slot: String) -> String:
	if not _equipped.has(entity_id):
		return ""
	
	return _equipped[entity_id].get(slot, "")


## Obtiene todos los slots con sus ítems equipados
func get_all_equipment(entity_id: String) -> Dictionary:
	if not _equipped.has(entity_id):
		return {}
	
	return _equipped[entity_id].duplicate()


## Obtiene slots disponibles para una entidad (desde CharacterDefinition)
func get_available_slots(entity_id: String) -> Array[String]:
	var char_def = Characters.get_character_definition(entity_id)
	if not char_def:
		return []
	
	var result: Array[String] = []
	result.assign(char_def.equipment_slots)
	return result


# ============================================
# VALIDACIÓN DE SLOTS
# ============================================

## Determina en qué slot se debe equipar un ítem
## Retorna el slot válido o "" si no hay ninguno
func _determine_slot(entity_id: String, item_def: ItemDefinition) -> String:
	# Obtener slots disponibles de la definición del personaje
	var available_slots = get_available_slots(entity_id)
	
	if available_slots.is_empty():
		push_warning("[EquipmentManager] Entity '%s' has no equipment slots defined" % entity_id)
		return ""
	
	# Buscar el primer tag del ítem que matchee con un slot disponible
	for tag in item_def.tags:
		if tag in available_slots:
			return tag
	
	# No encontró ningún slot válido
	return ""


## Valida si un ítem puede equiparse en un slot específico
func can_equip_in_slot(entity_id: String, item_id: String, slot: String) -> bool:
	# Verificar que el slot existe para esta entidad
	var available_slots = get_available_slots(entity_id)
	if not slot in available_slots:
		return false
	
	# Verificar que el ítem tiene el tag del slot
	var item_def = Items.get_item(item_id)
	if not item_def:
		return false
	
	return item_def.has_tag(slot)


# ============================================
# SAVE/LOAD (Preparación futura)
# ============================================

## Obtiene snapshot del equipamiento para guardar
func get_save_state(entity_id: String) -> Dictionary:
	if not _equipped.has(entity_id):
		return {}
	
	return _equipped[entity_id].duplicate()


## Restaura equipamiento desde snapshot
func load_save_state(entity_id: String, save_data: Dictionary):
	if not _equipped.has(entity_id):
		register_entity(entity_id)
	
	# Limpiar equipamiento actual
	var current_slots = _equipped[entity_id].keys()
	for slot in current_slots:
		_unequip_internal(entity_id, slot)
	
	# Re-equipar desde save
	for slot in save_data.keys():
		var item_id = save_data[slot]
		
		# Equipar directamente sin validaciones (asumimos save válido)
		_equipped[entity_id][slot] = item_id
		
		# Re-aplicar modificadores
		var item_def = Items.get_item(item_id)
		if item_def:
			var modifiers = item_def.get_modifiers_for_condition("equipped")
			for mod in modifiers:
				Characters.add_equipped_modifier(entity_id, mod)
	
	print("[EquipmentManager] Loaded equipment for '%s': %d items" % [
		entity_id, save_data.size()
	])


# ============================================
# DEBUG
# ============================================

## Imprime el equipamiento de una entidad
func print_equipment(entity_id: String):
	if not _equipped.has(entity_id):
		print("[EquipmentManager] Entity '%s' has no equipment registered" % entity_id)
		return
	
	var equipment = _equipped[entity_id]
	
	if equipment.is_empty():
		print("[EquipmentManager] Entity '%s' has no items equipped" % entity_id)
		return
	
	print("\n[EquipmentManager] Equipment for '%s':" % entity_id)
	for slot in equipment.keys():
		print("  %s: %s" % [slot, equipment[slot]])
	print("")


# ============================================
# NOTAS DE DISEÑO
# ============================================

## NOTA 1: ¿Por qué slots se leen de CharacterDefinition?
##
## Diseño data-driven:
## - Diferentes clases pueden tener slots diferentes
## - Un mago puede tener "staff" en lugar de "weapon"
## - Un archer puede tener "quiver" adicional
## - Se define en datos, no en código

## NOTA 2: ¿Cómo se determina el slot de un ítem?
##
## Por tags:
## - Un ítem con tag "weapon" se equipa en slot "weapon"
## - Un ítem con tag "head" se equipa en slot "head"
## - Si tiene múltiples tags, usa el primero que matchee

## NOTA 3: ¿Qué pasa si equipo otro ítem en el mismo slot?
##
## Auto-desequipa:
## - El ítem anterior se desequipa automáticamente
## - Sus modificadores se remueven
## - El nuevo ítem se equipa y sus modificadores se aplican
## - Solo puede haber 1 ítem por slot

## NOTA 4: ¿Los modificadores se aplican inmediatamente?
##
## Sí:
## - Al equipar → Characters.add_equipped_modifier()
## - Al desequipar → Characters.remove_equipped_modifier()
## - CharacterSystem emite evento que dispara recalculo en ModifierApplicator
## - Los atributos derivados se actualizan automáticamente

## NOTA 5: ¿Se valida que el jugador tenga el ítem en inventario?
##
## NO (por diseño):
## - EquipmentManager solo gestiona el estado de equipamiento
## - InventorySystem maneja la posesión de ítems
## - El Bridge valida ambas cosas antes de llamar a equip_item()
## - Separación de responsabilidades
