class_name ItemCharacterIntegration
extends Node

## SPIKE: Validar integración Item→Character
## NO modifica sistemas core, solo actúa como puente

var _equipped: Dictionary = {}  # { entity_id: { slot: item_id } }
const EQUIPMENT_SLOTS = ["weapon", "armor", "accessory"]

func _ready():
	EventBus.item_use_requested.connect(_on_item_use_requested)
	print("[SPIKE] ItemCharacterIntegration initialized")

func _on_item_use_requested(entity_id: String, item_id: String):
	# Validaciones básicas
	if not Characters.has_entity(entity_id):
		EventBus.item_use_failed.emit(entity_id, item_id, "Entity not found")
		return
	
	var item_def = Items.get_item(item_id)
	if not item_def or not item_def.usable:
		EventBus.item_use_failed.emit(entity_id, item_id, "Not usable")
		return
	
	# Routing por tipo
	match item_def.item_type:
		"CONSUMABLE": _apply_consumable(entity_id, item_def)
		"EQUIPMENT": _toggle_equipment(entity_id, item_def)

# ===== CASO 1: CONSUMIBLES =====
func _apply_consumable(entity_id: String, item_def: ItemDefinition):
	var mods = item_def.get_modifiers_for_condition("on_use")
	
	for mod in mods:
		var parts = mod.target.split(".")
		if parts.size() != 2: continue
		
		match parts[0]:
			"resource": _apply_resource_mod(entity_id, parts[1], mod)
			"attribute": _apply_attribute_mod(entity_id, parts[1], mod)
	
	EventBus.item_use_success.emit(entity_id, item_def.id)

func _apply_resource_mod(entity_id: String, res_id: String, mod: ModifierDefinition):
	match mod.operation:
		"add": Resources.add_resource(entity_id, res_id, mod.value)
		"override": Resources.set_resource(entity_id, res_id, mod.value)

func _apply_attribute_mod(entity_id: String, attr_id: String, mod: ModifierDefinition):
	match mod.operation:
		"add": Characters.modify_base_attribute(entity_id, attr_id, mod.value)
		"override": Characters.set_base_attribute(entity_id, attr_id, mod.value)

# ===== CASO 2: EQUIPAMIENTO =====
func _toggle_equipment(entity_id: String, item_def: ItemDefinition):
	var slot = _find_slot(item_def)
	if slot.is_empty():
		EventBus.item_use_failed.emit(entity_id, item_def.id, "No slot")
		return
	
	if not _equipped.has(entity_id):
		_equipped[entity_id] = {}
	
	var current = _equipped[entity_id].get(slot, "")
	
	if current == item_def.id:
		_unequip(entity_id, slot)
	else:
		if current: _unequip(entity_id, slot)
		_equip(entity_id, slot, item_def)
	
	EventBus.item_use_success.emit(entity_id, item_def.id)

func _find_slot(item_def: ItemDefinition) -> String:
	for slot in EQUIPMENT_SLOTS:
		if item_def.has_tag(slot): return slot
	return ""

func _equip(entity_id: String, slot: String, item_def: ItemDefinition):
	_equipped[entity_id][slot] = item_def.id
	
	for mod in item_def.get_modifiers_for_condition("equipped"):
		Characters.add_equipped_modifier(entity_id, mod)

func _unequip(entity_id: String, slot: String):
	var item_id = _equipped[entity_id].get(slot, "")
	if item_id.is_empty(): return
	
	var item_def = Items.get_item(item_id)
	if item_def:
		for mod in item_def.get_modifiers_for_condition("equipped"):
			Characters.remove_equipped_modifier(entity_id, mod)
	
	_equipped[entity_id].erase(slot)
