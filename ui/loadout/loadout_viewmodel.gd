class_name LoadoutViewModel
extends Node

## LoadoutViewModel - Lógica y estado de la pantalla de Loadout
##
## Responsabilidades:
##   - Exponer los slots actuales del LoadoutState del personaje
##   - Exponer las skills disponibles (aprendidas por el personaje)
##   - Exponer los consumibles disponibles (del inventario)
##   - Validar restricciones por tag antes de asignar
##   - Escribir en LoadoutState tras validación
##
## La View nunca accede a Skills, Inventory ni CharacterState directamente.
##
## Razones de changed():
##   "opened"      → renderizar todo
##   "slots"       → un slot cambió (asignación o limpieza)
##   "error"       → asignación rechazada, leer error_message
##   "closed"      → ocultar panel

# ============================================
# SEÑAL
# ============================================

signal changed(reason: String)


# ============================================
# ESTADO INTERNO
# ============================================

var _character_id: String = ""
var _loadout: LoadoutState = null


# ============================================
# DATOS PÚBLICOS (read-only para la View)
# ============================================

## Slots actuales. Clave: slot_id. Valor: SlotData.
var slots: Dictionary = {}

## Skills disponibles para asignar (aprendidas por el personaje).
var available_skills: Array[SkillSlotData] = []

## Consumibles disponibles en el inventario.
var available_consumables: Array[ConsumableSlotData] = []

## Mensaje de error de la última operación fallida. "" si no hay error.
var error_message: String = ""


# ============================================
# DATA CLASSES
# ============================================

class SlotData:
	var slot_id: String = ""
	var assigned_id: String = ""      ## skill_id o item_id. "" si vacío.
	var display_name: String = ""     ## Nombre localizado. "" si vacío.
	var slot_type: String = ""        ## "skill" o "consumable"
	var required_tag: String = ""     ## Tag requerido para skills. "" para consumibles.
	var is_empty: bool = true

	static func make_skill(sid: String, tag: String) -> SlotData:
		var d := SlotData.new()
		d.slot_id = sid
		d.slot_type = "skill"
		d.required_tag = tag
		return d

	static func make_consumable(sid: String) -> SlotData:
		var d := SlotData.new()
		d.slot_id = sid
		d.slot_type = "consumable"
		return d


class SkillSlotData:
	var skill_id: String = ""
	var display_name: String = ""     ## Nombre localizado
	var tags: Array[String] = []
	var stamina_cost: int = 0

	static func from_definition(def: SkillDefinition) -> SkillSlotData:
		var d := SkillSlotData.new()
		d.skill_id = def.id
		d.display_name = def.name_key  ## Sin tr() — se traduce en la View con tr()
		d.tags = def.tags.duplicate()
		d.stamina_cost = int(def.get_cost("stamina"))
		return d


class ConsumableSlotData:
	var item_id: String = ""
	var display_name: String = ""     ## Nombre localizado
	var quantity: int = 0

	static func from_definition(def: ItemDefinition, qty: int) -> ConsumableSlotData:
		var d := ConsumableSlotData.new()
		d.item_id = def.id
		d.display_name = def.name_key  ## Sin tr() — se traduce en la View con tr()
		d.quantity = qty
		return d


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	pass
	# El loadout no escucha EventBus mientras está cerrado.
	# Se refresca entero al abrirse.


# ============================================
# API PÚBLICA — llamada desde SceneOrchestrator / View
# ============================================

## Abre el loadout para un personaje concreto.
func open(character_id: String) -> void:
	_character_id = character_id

	var state: CharacterState = Characters.get_character_state(character_id)
	if state == null:
		push_error("[LoadoutViewModel] Personaje no encontrado: %s" % character_id)
		return

	_loadout = state.loadout
	_refresh_all()
	changed.emit("opened")


func request_close() -> void:
	_character_id = ""
	_loadout = null
	changed.emit("closed")


# ============================================
# INTENCIONES
# ============================================

## Asigna una skill a un slot de skill.
## Valida restricción de tag. Emite "slots" o "error".
func request_assign_skill(slot_id: String, skill_id: String) -> void:
	if _loadout == null:
		return

	if not _validate_skill_for_slot(slot_id, skill_id):
		changed.emit("error")
		return

	_loadout.assign_skill(slot_id, skill_id)
	_refresh_slots()
	changed.emit("slots")


## Asigna un consumible a un slot de consumible.
## Valida que el ítem sea CONSUMABLE y esté en el inventario.
func request_assign_consumable(slot_id: String, item_id: String) -> void:
	if _loadout == null:
		return

	if not _validate_consumable_for_slot(slot_id, item_id):
		changed.emit("error")
		return

	_loadout.assign_consumable(slot_id, item_id)
	_refresh_slots()
	changed.emit("slots")


## Vacía un slot (skill o consumible).
func request_clear_slot(slot_id: String) -> void:
	if _loadout == null:
		return

	_loadout.clear_slot(slot_id)
	_refresh_slots()
	changed.emit("slots")


# ============================================
# VALIDACIÓN
# ============================================

func _validate_skill_for_slot(slot_id: String, skill_id: String) -> bool:
	# ¿Es un slot de skill válido?
	if not slot_id in LoadoutState.SKILL_SLOTS:
		error_message = "LOADOUT_ERROR_INVALID_SLOT"
		return false

	# ¿Existe el personaje y tiene la skill aprendida?
	if Characters.get_character_state(_character_id) == null or not Skills.has_skill(_character_id, skill_id):
		error_message = "LOADOUT_ERROR_SKILL_NOT_LEARNED"
		return false

	# ¿La skill cumple el tag requerido por el slot?
	var skill_def: SkillDefinition = Skills.get_skill_definition(skill_id)
	if skill_def == null:
		error_message = "LOADOUT_ERROR_SKILL_NOT_FOUND"
		return false

	var required_tag: String = _loadout.get_required_tag(slot_id)
	if not required_tag in skill_def.tags:
		error_message = "LOADOUT_ERROR_WRONG_TAG"
		return false

	error_message = ""
	return true


func _validate_consumable_for_slot(slot_id: String, item_id: String) -> bool:
	# ¿Es un slot de consumible válido?
	if not slot_id in LoadoutState.CONSUMABLE_SLOTS:
		error_message = "LOADOUT_ERROR_INVALID_SLOT"
		return false

	# ¿Existe la definición y es CONSUMABLE?
	var item_def: ItemDefinition = Items.get_item(item_id)
	if item_def == null:
		error_message = "LOADOUT_ERROR_ITEM_NOT_FOUND"
		return false

	if item_def.item_type != "CONSUMABLE":
		error_message = "LOADOUT_ERROR_NOT_CONSUMABLE"
		return false

	# ¿El personaje tiene al menos uno en el inventario?
	var qty: int = Inventory.get_item_quantity(_character_id, item_id)
	if qty <= 0:
		error_message = "LOADOUT_ERROR_ITEM_NOT_IN_INVENTORY"
		return false

	error_message = ""
	return true


# ============================================
# REFRESCO INTERNO
# ============================================

func _refresh_all() -> void:
	_refresh_slots()
	_refresh_available_skills()
	_refresh_available_consumables()


func _refresh_slots() -> void:
	slots.clear()

	# Slots de skill
	for slot_id in LoadoutState.SKILL_SLOTS:
		var data := SlotData.make_skill(slot_id, _loadout.get_required_tag(slot_id))
		var skill_id: String = _loadout.get_skill(slot_id)

		if skill_id != "":
			var def: SkillDefinition = Skills.get_skill_definition(skill_id)
			if def != null:
				data.assigned_id = skill_id
				data.display_name = tr(def.name_key)
				data.is_empty = false

		slots[slot_id] = data

	# Slots de consumible
	for slot_id in LoadoutState.CONSUMABLE_SLOTS:
		var data := SlotData.make_consumable(slot_id)
		var item_id: String = _loadout.get_consumable(slot_id)

		if item_id != "":
			var def: ItemDefinition = Items.get_item(item_id)
			if def != null:
				data.assigned_id = item_id
				data.display_name = tr(def.name_key)
				data.is_empty = false

		slots[slot_id] = data


func _refresh_available_skills() -> void:
	available_skills.clear()

	var state: CharacterState = Characters.get_character_state(_character_id)
	if state == null:
		return

	for skill_id in state.list_known_skills():
		var def: SkillDefinition = Skills.get_skill_definition(skill_id)
		if def == null:
			continue
		# Solo skills con modo COMBAT (las únicas asignables al loadout)
		if def.mode != "COMBAT":
			continue
		available_skills.append(SkillSlotData.from_definition(def))


func _refresh_available_consumables() -> void:
	available_consumables.clear()

	var inventory: Dictionary = Inventory.get_inventory(_character_id)
	for item_id in inventory.keys():
		var def: ItemDefinition = Items.get_item(item_id)
		if def == null:
			continue
		if def.item_type != "CONSUMABLE":
			continue
		var qty: int = Inventory.get_item_quantity(_character_id, def.id)
		available_consumables.append(ConsumableSlotData.from_definition(def, qty))
