class_name ItemDetailBuilder
extends RefCounted

## ItemDetailBuilder (Spike 19b-2)
##
## Único punto donde se calculan los modificadores, la comparación con lo
## equipado y el formato de un ítem. Lo usan InventoryViewModel y
## PartyViewModel (cada uno con su entidad), para no duplicar la lógica.
##
## Es una instancia (RefCounted) y no un conjunto de funciones estáticas porque
## usa tr(), que no existe en contexto estático. Cada ViewModel crea la suya.
##
## No guarda estado: todo lo que necesita llega por parámetro.
## La categoría (viene de un JSON que carga el ViewModel) la rellena quien llama.


## Detalle de `item_def` para `entity_id`: modificadores y, si es equipo no
## equipado con un slot válido, la comparación con lo que esa entidad lleva.
func build(entity_id: String, item_def: ItemDefinition, quantity: int, is_equipped: bool) -> ItemDetailData:
	var data := ItemDetailData.new()
	data.item_def = item_def
	data.quantity = quantity
	data.is_equipped = is_equipped
	data.modifier_lines = build_modifier_lines(item_def)
	_fill_comparison(entity_id, data)
	return data


func build_modifier_lines(item_def: ItemDefinition) -> Array[ItemDetailData.ModLine]:
	var lines: Array[ItemDetailData.ModLine] = []
	for mod in item_def.get_modifiers_for_condition("equipped"):
		var line := ItemDetailData.ModLine.new()
		line.label = modifier_label(mod.target)
		line.text = format_modifier(mod)
		line.value = mod.value
		lines.append(line)
	return lines


## Compara con lo equipado en el slot que le correspondería. Solo cuenta la
## operación "add": restar un "mul" o un "override" no tiene sentido (hoy no
## hay ítems con esas operaciones).
func _fill_comparison(entity_id: String, data: ItemDetailData) -> void:
	var item_def: ItemDefinition = data.item_def
	if item_def.item_type != "EQUIPMENT" or data.is_equipped:
		return

	var slot_id: String = slot_for_item(entity_id, item_def)
	if slot_id.is_empty():
		return

	data.has_comparison = true
	data.compare_slot_id = slot_id

	var candidate: Dictionary = sum_add_modifiers(item_def)
	var current: Dictionary = {}

	var equipped_id: String = Equipment.get_equipped_item(entity_id, slot_id)
	var equipped_def: ItemDefinition = Items.get_item(equipped_id) if not equipped_id.is_empty() else null
	if equipped_def == null:
		data.compare_slot_free = true
	else:
		data.compare_against_name = tr(equipped_def.name_key)
		current = sum_add_modifiers(equipped_def)

	var targets: Array[String] = []
	for target in candidate.keys():
		targets.append(str(target))
	for target in current.keys():
		if not targets.has(str(target)):
			targets.append(str(target))

	for target in targets:
		var delta: float = float(candidate.get(target, 0.0)) - float(current.get(target, 0.0))
		if is_zero_approx(delta):
			continue
		var line := ItemDetailData.CompareLine.new()
		line.label = modifier_label(target)
		line.delta = delta
		line.text = format_signed(delta)
		data.compare_lines.append(line)


## Slot donde el sistema de equipo colocaría el ítem: el primer tag del ítem que
## el propio Equipment valida (mismo criterio que EquipmentManager._determine_slot,
## sin duplicar su regla).
func slot_for_item(entity_id: String, item_def: ItemDefinition) -> String:
	for tag in item_def.tags:
		if Equipment.can_equip_in_slot(entity_id, item_def.id, tag):
			return tag
	return ""


## target → suma de valores de los modificadores "add" aplicados al equipar
func sum_add_modifiers(item_def: ItemDefinition) -> Dictionary:
	var sums: Dictionary = {}
	for mod in item_def.get_modifiers_for_condition("equipped"):
		if mod.operation != "add":
			continue
		sums[mod.target] = float(sums.get(mod.target, 0.0)) + mod.value
	return sums


## "attribute.armor_rating" → INVENTORY_MOD_ARMOR_RATING; sin clave, "Armor Rating"
func modifier_label(target: String) -> String:
	var segment: String = target.get_slice(".", target.get_slice_count(".") - 1)
	var key: String = "INVENTORY_MOD_" + segment.to_upper()
	var text: String = tr(key)
	return text if text != key else segment.capitalize()


func format_modifier(mod: ModifierDefinition) -> String:
	match mod.operation:
		"add":
			return format_signed(mod.value)
		"mul":
			return "x%.2f" % mod.value
		"override":
			return "= %s" % format_number(mod.value)
	return format_number(mod.value)


func format_signed(value: float) -> String:
	var sign_text: String = "+" if value >= 0.0 else "-"
	return sign_text + format_number(absf(value))


func format_number(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%d" % int(roundf(value))
	return "%.1f" % value
