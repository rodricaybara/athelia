class_name LoadoutViewModel
extends Node

## LoadoutViewModel — lógica y estado de la pantalla de Loadout (Spike 20)
##
## Responsabilidades:
##   - Exponer los slots agrupados (ataque / defensa / consumibles) con su tecla
##   - Mantener el slot seleccionado y la lista de candidatos de ESE slot
##   - Validar antes de escribir en LoadoutState (tag, aprendida, consumible,
##     existencias y, desde el Spike 20, sin duplicados)
##
## La View nunca accede a Skills, Inventory, Characters ni LoadoutState.
## El ViewModel entrega CLAVES de localización; la View traduce. La única
## excepción es el orden alfabético de candidatos, que usa tr() solo como
## clave de ordenación.
##
## Razones de changed():
##   "opened"    → renderizar todo
##   "selection" → cambió el slot elegido (slots + lista + detalle)
##   "slots"     → se asignó o vació un slot (slots + lista + detalle)
##   "error"     → asignación rechazada, leer error_message (clave)
##   "closed"    → ocultar panel (también si open() falla)
##
## Slots fijos (Spike 20, O1): FIXED_SLOTS no se pueden elegir ni asignar
## desde esta pantalla. Hoy solo "escape" (acción de combate). Decisión
## provisional hasta replantear el combate.


signal changed(reason: String)


const FIXED_SLOTS: Array[String] = ["escape"]


# ============================================
# DATOS PÚBLICOS (read-only para la View)
# ============================================

var selected_slot_id: String = ""
var groups: Array[GroupData] = []
var slots: Dictionary = {}                       ## slot_id -> SlotData
var candidates: Array[CandidateData] = []
var list_header_key: String = "LOADOUT_AVAILABLE"
var list_message_key: String = ""                ## "" si hay candidatos que mostrar
var error_message: String = ""                   ## clave LOADOUT_ERROR_*


# ============================================
# ESTADO INTERNO
# ============================================

var _character_id: String = ""
var _loadout: LoadoutState = null


# ============================================
# DATA CLASSES
# ============================================

class CostData:
	var resource_id: String = ""
	var amount: int = 0


## Campos comunes de lo que la View puede mostrar en el cajetín.
class EntryData:
	var id: String = ""                  ## skill_id o item_id ("" si vacío)
	var slot_type: String = ""           ## "skill" o "consumable"
	var name_key: String = ""
	var description_key: String = ""
	var costs: Array[CostData] = []
	var tag_keys: Array[String] = []     ## claves LOADOUT_TAG_*
	var tag_mode: String = ""            ## "requires" (slot) o "fits" (candidato)
	var quantity: int = 0
	var definition: ItemDefinition = null


class SlotData extends EntryData:
	var slot_id: String = ""
	var label_key: String = ""           ## LOADOUT_SLOT_*
	var keybind_label: String = ""
	var is_empty: bool = true
	var is_selected: bool = false
	var is_fixed: bool = false


class CandidateData extends EntryData:
	var is_assigned_here: bool = false


class GroupData:
	var group_id: String = ""
	var title_key: String = ""
	var slot_type: String = ""
	var slot_ids: Array[String] = []


# ============================================
# API PÚBLICA
# ============================================

func open(character_id: String) -> void:
	_character_id = character_id

	var state: CharacterState = Characters.get_character_state(character_id)
	if state == null:
		push_error("[LoadoutViewModel] Personaje no encontrado: %s" % character_id)
		_character_id = ""
		_loadout = null
		changed.emit("closed")
		return

	_loadout = state.loadout
	selected_slot_id = ""
	error_message = ""
	_build_groups()
	_refresh_slots()
	_refresh_candidates()
	changed.emit("opened")


func request_close() -> void:
	_character_id = ""
	_loadout = null
	selected_slot_id = ""
	error_message = ""
	changed.emit("closed")


## Contenido del slot elegido (null si no hay selección).
func get_selected_slot() -> SlotData:
	return slots.get(selected_slot_id) as SlotData


# ============================================
# INTENCIONES
# ============================================

## Alterna la selección de un slot. Nunca vacía nada.
func request_select_slot(slot_id: String) -> void:
	if _loadout == null:
		return
	if slot_id in FIXED_SLOTS:
		return
	if not (slot_id in LoadoutState.SKILL_SLOTS or slot_id in LoadoutState.CONSUMABLE_SLOTS):
		return

	selected_slot_id = "" if selected_slot_id == slot_id else slot_id
	error_message = ""
	_refresh_slots()
	_refresh_candidates()
	changed.emit("selection")


func request_assign_skill(slot_id: String, skill_id: String) -> void:
	if _loadout == null:
		return
	if _loadout.get_skill(slot_id) == skill_id:
		return  # ya está aquí: sin efecto

	if not _validate_skill_for_slot(slot_id, skill_id):
		changed.emit("error")
		return

	_loadout.assign_skill(slot_id, skill_id)
	_after_change()


func request_assign_consumable(slot_id: String, item_id: String) -> void:
	if _loadout == null:
		return
	if _loadout.get_consumable(slot_id) == item_id:
		return

	if not _validate_consumable_for_slot(slot_id, item_id):
		changed.emit("error")
		return

	_loadout.assign_consumable(slot_id, item_id)
	_after_change()


func request_clear_slot(slot_id: String) -> void:
	if _loadout == null:
		return
	if slot_id in FIXED_SLOTS:
		return

	_loadout.clear_slot(slot_id)
	_after_change()


func _after_change() -> void:
	error_message = ""
	_refresh_slots()
	_refresh_candidates()
	changed.emit("slots")


# ============================================
# VALIDACIÓN (reglas del Spike 3 intactas + duplicados)
# ============================================

func _validate_skill_for_slot(slot_id: String, skill_id: String) -> bool:
	if not slot_id in LoadoutState.SKILL_SLOTS:
		error_message = "LOADOUT_ERROR_INVALID_SLOT"
		return false

	if Characters.get_character_state(_character_id) == null or not Skills.has_skill(_character_id, skill_id):
		error_message = "LOADOUT_ERROR_SKILL_NOT_LEARNED"
		return false

	var skill_def: SkillDefinition = Skills.get_skill_definition(skill_id)
	if skill_def == null:
		error_message = "LOADOUT_ERROR_SKILL_NOT_FOUND"
		return false

	var required_tag: String = _loadout.get_required_tag(slot_id)
	if not required_tag in skill_def.tags:
		error_message = "LOADOUT_ERROR_WRONG_TAG"
		return false

	if _skill_assigned_elsewhere(skill_id, slot_id):
		error_message = "LOADOUT_ERROR_DUPLICATE"
		return false

	error_message = ""
	return true


func _validate_consumable_for_slot(slot_id: String, item_id: String) -> bool:
	if not slot_id in LoadoutState.CONSUMABLE_SLOTS:
		error_message = "LOADOUT_ERROR_INVALID_SLOT"
		return false

	var item_def: ItemDefinition = Items.get_item(item_id)
	if item_def == null:
		error_message = "LOADOUT_ERROR_ITEM_NOT_FOUND"
		return false

	if item_def.item_type != "CONSUMABLE":
		error_message = "LOADOUT_ERROR_NOT_CONSUMABLE"
		return false

	if Inventory.get_item_quantity(_character_id, item_id) <= 0:
		error_message = "LOADOUT_ERROR_ITEM_NOT_IN_INVENTORY"
		return false

	if _consumable_assigned_elsewhere(item_id, slot_id):
		error_message = "LOADOUT_ERROR_DUPLICATE"
		return false

	error_message = ""
	return true


func _skill_assigned_elsewhere(skill_id: String, except_slot: String) -> bool:
	for other_slot in LoadoutState.SKILL_SLOTS:
		if other_slot != except_slot and _loadout.get_skill(other_slot) == skill_id:
			return true
	return false


func _consumable_assigned_elsewhere(item_id: String, except_slot: String) -> bool:
	for other_slot in LoadoutState.CONSUMABLE_SLOTS:
		if other_slot != except_slot and _loadout.get_consumable(other_slot) == item_id:
			return true
	return false


# ============================================
# REFRESCO INTERNO
# ============================================

## Grupos derivados de LoadoutState sin tocarlo: ataque = slots cuyo tag
## requerido es "attack"; defensa = el resto de slots de skill.
func _build_groups() -> void:
	groups.clear()

	var attack := GroupData.new()
	attack.group_id = "attack"
	attack.title_key = "LOADOUT_GROUP_ATTACK"
	attack.slot_type = "skill"

	var defense := GroupData.new()
	defense.group_id = "defense"
	defense.title_key = "LOADOUT_GROUP_DEFENSE"
	defense.slot_type = "skill"

	for slot_id in LoadoutState.SKILL_SLOTS:
		if _loadout.get_required_tag(slot_id) == "attack":
			attack.slot_ids.append(slot_id)
		else:
			defense.slot_ids.append(slot_id)

	var consumables := GroupData.new()
	consumables.group_id = "consumables"
	consumables.title_key = "LOADOUT_GROUP_CONSUMABLES"
	consumables.slot_type = "consumable"
	for slot_id in LoadoutState.CONSUMABLE_SLOTS:
		consumables.slot_ids.append(slot_id)

	groups.append(attack)
	groups.append(defense)
	groups.append(consumables)


func _refresh_slots() -> void:
	slots.clear()

	for slot_id in LoadoutState.SKILL_SLOTS:
		var data := SlotData.new()
		_init_slot(data, slot_id, "skill")

		if slot_id in FIXED_SLOTS:
			data.is_fixed = true
			data.is_empty = false
			data.name_key = "LOADOUT_FIXED_ACTION"
			data.description_key = "LOADOUT_ESCAPE_DESC"
		else:
			var required_tag: String = _loadout.get_required_tag(slot_id)
			if required_tag != "":
				data.tag_mode = "requires"
				data.tag_keys.append(_tag_key(required_tag))
			var skill_id: String = _loadout.get_skill(slot_id)
			if skill_id != "":
				var def: SkillDefinition = Skills.get_skill_definition(skill_id)
				if def != null:
					_fill_skill(data, def)
					data.is_empty = false

		slots[slot_id] = data

	for slot_id in LoadoutState.CONSUMABLE_SLOTS:
		var data := SlotData.new()
		_init_slot(data, slot_id, "consumable")

		var item_id: String = _loadout.get_consumable(slot_id)
		if item_id != "":
			var def: ItemDefinition = Items.get_item(item_id)
			if def != null:
				_fill_item(data, def, Inventory.get_item_quantity(_character_id, item_id))
				data.is_empty = false

		slots[slot_id] = data


func _refresh_candidates() -> void:
	candidates.clear()
	list_message_key = ""

	if selected_slot_id == "":
		list_header_key = "LOADOUT_AVAILABLE"
		list_message_key = "LOADOUT_SELECT_SLOT_FIRST"
		return

	if selected_slot_id in LoadoutState.SKILL_SLOTS:
		list_header_key = "LOADOUT_SKILLS_AVAILABLE"
		_collect_skill_candidates()
		if candidates.is_empty():
			list_message_key = "LOADOUT_LIST_NO_SKILLS"
	else:
		list_header_key = "LOADOUT_CONSUMABLES_AVAILABLE"
		_collect_consumable_candidates()
		if candidates.is_empty():
			list_message_key = "LOADOUT_LIST_NO_CONSUMABLES"

	candidates.sort_custom(func(a: CandidateData, b: CandidateData) -> bool:
		return tr(a.name_key).naturalnocasecmp_to(tr(b.name_key)) < 0)


## Skills COMBAT aprendidas que cumplen el tag del slot elegido y no están
## en otro slot. La que ya está en el slot elegido se marca is_assigned_here.
func _collect_skill_candidates() -> void:
	var state: CharacterState = Characters.get_character_state(_character_id)
	if state == null:
		return

	var required_tag: String = _loadout.get_required_tag(selected_slot_id)
	var slot_tags: Array = LoadoutState.SLOT_REQUIRED_TAG.values()

	for skill_id in state.list_known_skills():
		var def: SkillDefinition = Skills.get_skill_definition(skill_id)
		if def == null or def.mode != "COMBAT":
			continue
		if not required_tag in def.tags:
			continue

		var here: bool = _loadout.get_skill(selected_slot_id) == def.id
		if not here and _skill_assigned_elsewhere(def.id, selected_slot_id):
			continue

		var cand := CandidateData.new()
		cand.slot_type = "skill"
		_fill_skill(cand, def)
		cand.is_assigned_here = here
		cand.tag_mode = "fits"
		for tag in def.tags:
			if tag in slot_tags:
				var key: String = _tag_key(tag)
				if not key in cand.tag_keys:
					cand.tag_keys.append(key)
		candidates.append(cand)


func _collect_consumable_candidates() -> void:
	var inventory: Dictionary = Inventory.get_inventory(_character_id)
	for item_id in inventory.keys():
		var def: ItemDefinition = Items.get_item(item_id)
		if def == null or def.item_type != "CONSUMABLE":
			continue
		var qty: int = Inventory.get_item_quantity(_character_id, def.id)
		if qty <= 0:
			continue

		var here: bool = _loadout.get_consumable(selected_slot_id) == def.id
		if not here and _consumable_assigned_elsewhere(def.id, selected_slot_id):
			continue

		var cand := CandidateData.new()
		cand.slot_type = "consumable"
		_fill_item(cand, def, qty)
		cand.is_assigned_here = here
		candidates.append(cand)


# ============================================
# UTILIDADES
# ============================================

func _init_slot(data: SlotData, slot_id: String, slot_type: String) -> void:
	data.slot_id = slot_id
	data.slot_type = slot_type
	data.label_key = "LOADOUT_SLOT_%s" % slot_id.to_upper()
	data.keybind_label = str(CombatHudViewModel.SLOT_KEYBIND_LABEL.get(slot_id, ""))
	data.is_selected = (slot_id == selected_slot_id)


func _fill_skill(entry: EntryData, def: SkillDefinition) -> void:
	entry.id = def.id
	entry.name_key = def.name_key
	entry.description_key = def.description_key
	entry.costs.clear()
	for resource_id in def.costs.keys():
		var cost := CostData.new()
		cost.resource_id = str(resource_id)
		cost.amount = int(def.costs[resource_id])
		entry.costs.append(cost)


func _fill_item(entry: EntryData, def: ItemDefinition, qty: int) -> void:
	entry.id = def.id
	entry.name_key = def.name_key
	entry.description_key = def.description_key
	entry.definition = def
	entry.quantity = qty


func _tag_key(tag: String) -> String:
	return "LOADOUT_TAG_%s" % tag.to_upper()
