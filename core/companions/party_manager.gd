extends Node

## PartyManager - Gestor del grupo activo de companions
## Autoload: /root/Party
##
## v2: Añadido sistema de estrategias de IA por companion.
##     CompanionStrategy es accesible globalmente como Party.CompanionStrategy.X

# ============================================
# ENUM ESTRATEGIAS (accesible como Party.CompanionStrategy)
# ============================================

enum CompanionStrategy {
	AGGRESSIVE,   ## Ataca al enemigo con menor HP (más cerca de morir)
	DEFENSIVE,    ## Ataca al enemigo con mayor HP (mayor amenaza)
	AREA_FOCUS,   ## Prioriza skills de área; si no hay, cae a AGGRESSIVE
	BERSERKER,    ## Usa la skill con mayor coste de stamina disponible
}

# ============================================
# CONSTANTES
# ============================================

const MAX_PARTY_SIZE: int = 3

# ============================================
# ESTADO
# ============================================

var _party_members: Array[String] = []
var _incapacitated: Array[String] = []

## Estrategias por companion: { companion_id: CompanionStrategy }
var _strategies: Dictionary = {}

# ============================================
# INICIALIZACIÓN
# ============================================

func _ready() -> void:
	EventBus.combat_ended.connect(_on_combat_ended)
	print("[PartyManager] Initialized — max party size: %d" % MAX_PARTY_SIZE)


# ============================================
# API PÚBLICA — GESTIÓN DEL GRUPO
# ============================================

func join_party(companion_id: String, definition_id: String = "") -> bool:
	if _party_members.has(companion_id):
		push_warning("[PartyManager] '%s' already in party" % companion_id)
		return false

	if _party_members.size() >= MAX_PARTY_SIZE:
		push_warning("[PartyManager] Party is full (%d/%d)" % [_party_members.size(), MAX_PARTY_SIZE])
		return false

	var def_id := definition_id if not definition_id.is_empty() else companion_id

	if not _register_in_systems(companion_id, def_id):
		push_error("[PartyManager] Failed to register '%s' in systems" % companion_id)
		return false

	_party_members.append(companion_id)
	# Estrategia por defecto al unirse
	if not _strategies.has(companion_id):
		_strategies[companion_id] = CompanionStrategy.AGGRESSIVE

	EventBus.companion_joined.emit(companion_id)
	print("[PartyManager] '%s' joined the party (%d/%d)" % [
		companion_id, _party_members.size(), MAX_PARTY_SIZE
	])
	return true


func leave_party(companion_id: String) -> bool:
	if not _party_members.has(companion_id):
		push_warning("[PartyManager] '%s' is not in party" % companion_id)
		return false

	_party_members.erase(companion_id)
	_incapacitated.erase(companion_id)
	_strategies.erase(companion_id)
	_unregister_from_systems(companion_id)

	EventBus.companion_left.emit(companion_id)
	print("[PartyManager] '%s' left the party" % companion_id)
	return true


func die_permanently(companion_id: String) -> void:
	if not _party_members.has(companion_id):
		push_warning("[PartyManager] '%s' is not in party, cannot die permanently" % companion_id)
		return

	_party_members.erase(companion_id)
	_incapacitated.erase(companion_id)
	_strategies.erase(companion_id)
	_unregister_from_systems(companion_id)

	var flag_id := "flag.companion_%s_dead" % companion_id.replace("companion_", "")
	Narrative.set_flag(flag_id)

	EventBus.companion_died_permanently.emit(companion_id)
	EventBus.companion_left.emit(companion_id)

	print("[PartyManager] '%s' died permanently — flag '%s' set" % [companion_id, flag_id])


# ============================================
# API PÚBLICA — ESTRATEGIAS
# ============================================

## Devuelve la estrategia activa de un companion.
## Si no tiene asignada, devuelve AGGRESSIVE por defecto.
func get_strategy(companion_id: String) -> CompanionStrategy:
	return _strategies.get(companion_id, CompanionStrategy.AGGRESSIVE) as CompanionStrategy


## Asigna una estrategia a un companion.
func set_strategy(companion_id: String, new_strategy: CompanionStrategy) -> void:
	if not _party_members.has(companion_id):
		push_warning("[PartyManager] set_strategy: '%s' not in party" % companion_id)
		return
	_strategies[companion_id] = new_strategy
	print("[PartyManager] '%s' strategy → %s" % [
		companion_id, CompanionStrategy.keys()[new_strategy]
	])


# ============================================
# API PÚBLICA — INCAPACITACIÓN
# ============================================

func set_incapacitated(companion_id: String) -> void:
	if not _party_members.has(companion_id):
		return
	if not _incapacitated.has(companion_id):
		_incapacitated.append(companion_id)
	EventBus.companion_incapacitated.emit(companion_id)
	print("[PartyManager] '%s' incapacitated" % companion_id)


func revive(companion_id: String, hp_restored: float = 5.0) -> void:
	if not _incapacitated.has(companion_id):
		push_warning("[PartyManager] '%s' is not incapacitated" % companion_id)
		return

	_incapacitated.erase(companion_id)
	Resources.set_resource(companion_id, "health", hp_restored)
	EventBus.companion_revived.emit(companion_id)
	print("[PartyManager] '%s' revived with %.0f HP" % [companion_id, hp_restored])


func is_incapacitated(companion_id: String) -> bool:
	return _incapacitated.has(companion_id)


func is_active(companion_id: String) -> bool:
	return _party_members.has(companion_id) and not _incapacitated.has(companion_id)


# ============================================
# API PÚBLICA — CONSULTAS
# ============================================

func get_party_members() -> Array[String]:
	return _party_members.duplicate()


func get_active_members() -> Array[String]:
	var result: Array[String] = []
	for id in _party_members:
		if not _incapacitated.has(id):
			result.append(id)
	return result


func has_companions() -> bool:
	return not _party_members.is_empty()


func is_in_party(companion_id: String) -> bool:
	return _party_members.has(companion_id)


func get_formation_index(companion_id: String) -> int:
	return _party_members.find(companion_id)


func all_incapacitated() -> bool:
	if _party_members.is_empty():
		return false
	for id in _party_members:
		if not _incapacitated.has(id):
			return false
	return true


# ============================================
# REGISTRO EN SISTEMAS
# ============================================

func _register_in_systems(companion_id: String, definition_id: String) -> bool:
	if not Characters.has_entity(companion_id):
		if not Characters.has_definition(definition_id):
			push_error("[PartyManager] CharacterDefinition '%s' not found" % definition_id)
			return false
		if not Characters.register_entity(companion_id, definition_id):
			push_error("[PartyManager] Failed to register '%s' in CharacterSystem" % companion_id)
			return false
	else:
		print("[PartyManager] '%s' already in CharacterSystem — skipping" % companion_id)

	Resources.register_entity(companion_id)

	var skills_node: Node = get_node_or_null("/root/Skills")
	if skills_node:
		if not skills_node._entity_skills.has(companion_id):
			skills_node.register_entity_skills(companion_id)
			for skill_id in skills_node._entity_skills.get(companion_id, {}).keys():
				var instance: SkillInstance = skills_node.get_skill_instance(companion_id, skill_id)
				if instance:
					instance.is_unlocked = true
		else:
			print("[PartyManager] '%s' already in SkillSystem — skipping" % companion_id)

	var inventory: Node = get_node_or_null("/root/Inventory")
	if inventory:
		inventory.register_entity(companion_id)

	var equipment: Node = get_node_or_null("/root/Equipment")
	if equipment:
		equipment.register_entity(companion_id)

	print("[PartyManager] '%s' registered in all systems" % companion_id)
	return true


func _unregister_from_systems(companion_id: String) -> void:
	if Characters.has_entity(companion_id):
		Characters.unregister_entity(companion_id)

	Resources.unregister_entity(companion_id)

	var skills_node: Node = get_node_or_null("/root/Skills")
	if skills_node:
		skills_node.unregister_entity(companion_id)

	var equipment: Node = get_node_or_null("/root/Equipment")
	if equipment:
		equipment.unregister_entity(companion_id)

	var inventory: Node = get_node_or_null("/root/Inventory")
	if inventory and inventory._inventories.has(companion_id):
		inventory._inventories.erase(companion_id)

	print("[PartyManager] '%s' unregistered from all systems" % companion_id)


# ============================================
# CALLBACKS
# ============================================

func _on_combat_ended(result: String) -> void:
	if result == "victory" or result == "escaped":
		var to_revive := _incapacitated.duplicate()
		for companion_id in to_revive:
			revive(companion_id, 1.0)
			print("[PartyManager] '%s' survived combat (incapacitated) — revived with 1 HP" % companion_id)

	_incapacitated.clear()


# ============================================
# SAVE / LOAD
# ============================================

func get_save_state() -> Dictionary:
	var members_data: Array = []
	for companion_id in _party_members:
		members_data.append({
			"companion_id":  companion_id,
			"definition_id": companion_id,
			"strategy":      _strategies.get(companion_id, CompanionStrategy.AGGRESSIVE),
			"resources":     Resources.get_save_state(companion_id),
			"skills":        Skills.get_save_state(companion_id) if get_node_or_null("/root/Skills") else {},
			"inventory":     Inventory.get_save_state(companion_id) if get_node_or_null("/root/Inventory") else {},
			"equipment":     Equipment.get_save_state(companion_id) if get_node_or_null("/root/Equipment") else {},
		})
	return { "party_members": members_data }


func load_save_state(save_data: Dictionary) -> void:
	for companion_id in _party_members.duplicate():
		_unregister_from_systems(companion_id)
	_party_members.clear()
	_incapacitated.clear()
	_strategies.clear()

	var members_data: Array = save_data.get("party_members", [])
	for member_data in members_data:
		var companion_id: String  = member_data.get("companion_id", "")
		var definition_id: String = member_data.get("definition_id", companion_id)

		if companion_id.is_empty():
			continue

		if not _register_in_systems(companion_id, definition_id):
			push_error("[PartyManager] Failed to restore companion: %s" % companion_id)
			continue

		_party_members.append(companion_id)

		# Restaurar estrategia
		var saved_strategy: int = member_data.get("strategy", CompanionStrategy.AGGRESSIVE)
		_strategies[companion_id] = saved_strategy as CompanionStrategy

		# Restaurar estado de sistemas
		var resources_data: Dictionary = member_data.get("resources", {})
		if not resources_data.is_empty():
			Resources.load_save_state(companion_id, resources_data)

		var skills_data: Dictionary = member_data.get("skills", {})
		var skills_node: Node = get_node_or_null("/root/Skills")
		if skills_node and not skills_data.is_empty():
			skills_node.load_save_state(companion_id, skills_data)

		var inventory_data: Dictionary = member_data.get("inventory", {})
		var inventory: Node = get_node_or_null("/root/Inventory")
		if inventory and not inventory_data.is_empty():
			inventory.load_save_state(companion_id, inventory_data)

		var equipment_data: Dictionary = member_data.get("equipment", {})
		var equipment: Node = get_node_or_null("/root/Equipment")
		if equipment and not equipment_data.is_empty():
			equipment.load_save_state(companion_id, equipment_data)

		print("[PartyManager] Restored companion: %s (strategy: %s)" % [
			companion_id, CompanionStrategy.keys()[_strategies[companion_id]]
		])

	print("[PartyManager] Loaded party: %d members" % _party_members.size())


# ============================================
# DEBUG
# ============================================

func print_party_state() -> void:
	print("\n[PartyManager] === PARTY STATE ===")
	if _party_members.is_empty():
		print("  (empty)")
		return
	for companion_id in _party_members:
		var hp: float = Resources.get_resource_amount(companion_id, "health")
		var status: String = "INCAPACITATED" if _incapacitated.has(companion_id) else "active"
		var strat: String = CompanionStrategy.keys()[get_strategy(companion_id)]
		print("  - %s  HP:%.0f  [%s]  strategy:%s" % [companion_id, hp, status, strat])
	print("")
