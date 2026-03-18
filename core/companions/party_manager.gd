extends Node

## PartyManager - Gestor del grupo activo de companions
## Autoload: /root/Party
##
## RESPONSABILIDADES:
##   - Mantener la lista de companions activos en el grupo
##   - Registrar/desregistrar companions en todos los sistemas al unirse/abandonar
##   - Trackear estado de incapacitación durante combate
##   - Emitir eventos de grupo al EventBus
##
## NO HACE:
##   - Lógica de combate (eso es CompanionAI + GameLoop)
##   - Movimiento en exploración (eso es CompanionFollowNode)
##   - Diálogos de reclutamiento (eso es NarrativeSystem + DialogueSystem)
##
## CONTRATO: companion_id sigue el patrón "companion_<nombre>"
##   Ejemplo: "companion_mira", "companion_aldric"
##   La CharacterDefinition correspondiente tiene id idéntico.

# ============================================
# CONSTANTES
# ============================================

## Máximo de companions simultáneos en el grupo
const MAX_PARTY_SIZE: int = 3

# ============================================
# ESTADO
# ============================================

## Lista de companion_ids actualmente en el grupo
## Orden importa: determina posición en formación
var _party_members: Array[String] = []

## Companions incapacitados en combate (0 HP, pendientes de reanimar)
## Se limpia al terminar el combate
var _incapacitated: Array[String] = []

# ============================================
# INICIALIZACIÓN
# ============================================

func _ready() -> void:
	EventBus.combat_ended.connect(_on_combat_ended)
	print("[PartyManager] Initialized — max party size: %d" % MAX_PARTY_SIZE)


# ============================================
# API PÚBLICA — GESTIÓN DEL GRUPO
# ============================================

## Añade un companion al grupo y lo registra en todos los sistemas.
## Retorna false si el grupo está lleno o el companion ya está dentro.
func join_party(companion_id: String, definition_id: String = "") -> bool:
	if _party_members.has(companion_id):
		push_warning("[PartyManager] '%s' already in party" % companion_id)
		return false

	if _party_members.size() >= MAX_PARTY_SIZE:
		push_warning("[PartyManager] Party is full (%d/%d)" % [_party_members.size(), MAX_PARTY_SIZE])
		return false

	# Resolver definition_id: si no se pasa, usar companion_id como id de definición
	var def_id := definition_id if not definition_id.is_empty() else companion_id

	if not _register_in_systems(companion_id, def_id):
		push_error("[PartyManager] Failed to register '%s' in systems" % companion_id)
		return false

	_party_members.append(companion_id)

	EventBus.companion_joined.emit(companion_id)
	print("[PartyManager] '%s' joined the party (%d/%d)" % [
		companion_id, _party_members.size(), MAX_PARTY_SIZE
	])
	return true


## Elimina un companion del grupo y lo desregistra de los sistemas.
## Usar para abandono narrativo — la muerte permanente usa die_permanently().
func leave_party(companion_id: String) -> bool:
	if not _party_members.has(companion_id):
		push_warning("[PartyManager] '%s' is not in party" % companion_id)
		return false

	_party_members.erase(companion_id)
	_incapacitated.erase(companion_id)
	_unregister_from_systems(companion_id)

	EventBus.companion_left.emit(companion_id)
	print("[PartyManager] '%s' left the party" % companion_id)
	return true


## Muerte permanente: abandona el grupo y activa flag narrativa.
func die_permanently(companion_id: String) -> void:
	if not _party_members.has(companion_id):
		push_warning("[PartyManager] '%s' is not in party, cannot die permanently" % companion_id)
		return

	_party_members.erase(companion_id)
	_incapacitated.erase(companion_id)
	_unregister_from_systems(companion_id)

	# Flag narrativa de muerte permanente
	var flag_id := "flag.companion_%s_dead" % companion_id.replace("companion_", "")
	Narrative.set_flag(flag_id)

	EventBus.companion_died_permanently.emit(companion_id)
	EventBus.companion_left.emit(companion_id)

	print("[PartyManager] '%s' died permanently — flag '%s' set" % [companion_id, flag_id])


# ============================================
# API PÚBLICA — INCAPACITACIÓN
# ============================================

## Marca un companion como incapacitado (0 HP en combate).
## NO lo desregistra de los sistemas — puede ser reanimado.
func set_incapacitated(companion_id: String) -> void:
	if not _party_members.has(companion_id):
		return
	if not _incapacitated.has(companion_id):
		_incapacitated.append(companion_id)
	EventBus.companion_incapacitated.emit(companion_id)
	print("[PartyManager] '%s' incapacitated" % companion_id)


## Reactiva un companion incapacitado (reanimado en combate).
func revive(companion_id: String, hp_restored: float = 5.0) -> void:
	if not _incapacitated.has(companion_id):
		push_warning("[PartyManager] '%s' is not incapacitated" % companion_id)
		return

	_incapacitated.erase(companion_id)

	# Restaurar HP mínimo para que pueda actuar
	Resources.set_resource(companion_id, "health", hp_restored)

	EventBus.companion_revived.emit(companion_id)
	print("[PartyManager] '%s' revived with %.0f HP" % [companion_id, hp_restored])


## ¿Está incapacitado?
func is_incapacitated(companion_id: String) -> bool:
	return _incapacitated.has(companion_id)


## ¿Está activo (en el grupo y no incapacitado)?
func is_active(companion_id: String) -> bool:
	return _party_members.has(companion_id) and not _incapacitated.has(companion_id)


# ============================================
# API PÚBLICA — CONSULTAS
# ============================================

## Lista de todos los companions en el grupo (activos + incapacitados)
func get_party_members() -> Array[String]:
	return _party_members.duplicate()


## Lista solo los companions que pueden actuar (no incapacitados)
func get_active_members() -> Array[String]:
	var result: Array[String] = []
	for id in _party_members:
		if not _incapacitated.has(id):
			result.append(id)
	return result


## ¿Hay companions en el grupo?
func has_companions() -> bool:
	return not _party_members.is_empty()


## ¿Está en el grupo?
func is_in_party(companion_id: String) -> bool:
	return _party_members.has(companion_id)


## Índice de posición en el grupo (para offset de formación)
func get_formation_index(companion_id: String) -> int:
	return _party_members.find(companion_id)


## ¿Todos los companions están incapacitados?
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

## Registra el companion en CharacterSystem, ResourceSystem, SkillSystem,
## InventorySystem y EquipmentManager.
func _register_in_systems(companion_id: String, definition_id: String) -> bool:
	# 1. CharacterSystem — necesario para atributos y skills
	if not Characters.has_entity(companion_id):
		if not Characters.has_definition(definition_id):
			push_error("[PartyManager] CharacterDefinition '%s' not found" % definition_id)
			return false
		if not Characters.register_entity(companion_id, definition_id):
			push_error("[PartyManager] Failed to register '%s' in CharacterSystem" % companion_id)
			return false
	else:
		print("[PartyManager] '%s' already in CharacterSystem — skipping" % companion_id)

	# 2. ResourceSystem — HP, stamina, gold
	Resources.register_entity(companion_id)

	# 3. SkillSystem — habilidades según definición
	var skills_node = get_node_or_null("/root/Skills")
	if skills_node:
		if not skills_node._entity_skills.has(companion_id):
			skills_node.register_entity_skills(companion_id)
			# Desbloquear todas las skills de partida (no requieren narrativa)
			for skill_id in skills_node._entity_skills.get(companion_id, {}).keys():
				var instance = skills_node.get_skill_instance(companion_id, skill_id)
				if instance:
					instance.is_unlocked = true
		else:
			print("[PartyManager] '%s' already in SkillSystem — skipping" % companion_id)

	# 4. InventorySystem
	var inventory = get_node_or_null("/root/Inventory")
	if inventory:
		inventory.register_entity(companion_id)

	# 5. EquipmentManager
	var equipment = get_node_or_null("/root/Equipment")
	if equipment:
		equipment.register_entity(companion_id)

	print("[PartyManager] '%s' registered in all systems" % companion_id)
	return true


## Desregistra el companion de todos los sistemas.
## Llamado al abandonar el grupo o morir permanentemente.
func _unregister_from_systems(companion_id: String) -> void:
	# CharacterSystem
	if Characters.has_entity(companion_id):
		Characters.unregister_entity(companion_id)

	# ResourceSystem
	Resources.unregister_entity(companion_id)

	# SkillSystem
	var skills_node = get_node_or_null("/root/Skills")
	if skills_node:
		skills_node.unregister_entity(companion_id)

	# EquipmentManager
	var equipment = get_node_or_null("/root/Equipment")
	if equipment:
		equipment.unregister_entity(companion_id)

	# InventorySystem — no tiene unregister_entity público, borrado manual
	var inventory = get_node_or_null("/root/Inventory")
	if inventory and inventory._inventories.has(companion_id):
		inventory._inventories.erase(companion_id)

	print("[PartyManager] '%s' unregistered from all systems" % companion_id)


# ============================================
# CALLBACKS
# ============================================

## Al terminar el combate: limpiar incapacitados.
## Si el resultado fue victoria o escape, los incapacitados sobreviven con 1 HP.
## Si fue derrota, se decide por narrativa (no aquí).
func _on_combat_ended(result: String) -> void:
	if result == "victory" or result == "escaped":
		# Reanimar incapacitados con 1 HP — sobrevivieron
		var to_revive := _incapacitated.duplicate()
		for companion_id in to_revive:
			revive(companion_id, 1.0)
			print("[PartyManager] '%s' survived combat (incapacitated) — revived with 1 HP" % companion_id)
	# En derrota: el juego gestiona el game over, no limpiamos aquí

	_incapacitated.clear()


# ============================================
# SAVE / LOAD
# ============================================

func get_save_state() -> Dictionary:
	var members_data: Array = []
	for companion_id in _party_members:
		members_data.append({
			"companion_id": companion_id,
			"definition_id": companion_id,  # por convención son iguales
			"resources": Resources.get_save_state(companion_id),
			"skills":    Skills.get_save_state(companion_id) if get_node_or_null("/root/Skills") else {},
			"inventory": Inventory.get_save_state(companion_id) if get_node_or_null("/root/Inventory") else {},
			"equipment": Equipment.get_save_state(companion_id) if get_node_or_null("/root/Equipment") else {},
		})
	return { "party_members": members_data }


func load_save_state(save_data: Dictionary) -> void:
	# Limpiar grupo actual
	for companion_id in _party_members.duplicate():
		_unregister_from_systems(companion_id)
	_party_members.clear()
	_incapacitated.clear()

	var members_data: Array = save_data.get("party_members", [])
	for member_data in members_data:
		var companion_id: String = member_data.get("companion_id", "")
		var definition_id: String = member_data.get("definition_id", companion_id)

		if companion_id.is_empty():
			continue

		if not _register_in_systems(companion_id, definition_id):
			push_error("[PartyManager] Failed to restore companion: %s" % companion_id)
			continue

		_party_members.append(companion_id)

		# Restaurar estado
		var resources_data = member_data.get("resources", {})
		if not resources_data.is_empty():
			Resources.load_save_state(companion_id, resources_data)

		var skills_data = member_data.get("skills", {})
		var skills_node = get_node_or_null("/root/Skills")
		if skills_node and not skills_data.is_empty():
			skills_node.load_save_state(companion_id, skills_data)

		var inventory_data = member_data.get("inventory", {})
		var inventory = get_node_or_null("/root/Inventory")
		if inventory and not inventory_data.is_empty():
			inventory.load_save_state(companion_id, inventory_data)

		var equipment_data = member_data.get("equipment", {})
		var equipment = get_node_or_null("/root/Equipment")
		if equipment and not equipment_data.is_empty():
			equipment.load_save_state(companion_id, equipment_data)

		print("[PartyManager] Restored companion: %s" % companion_id)

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
		var hp := Resources.get_resource_amount(companion_id, "health")
		var status := "INCAPACITATED" if _incapacitated.has(companion_id) else "active"
		print("  - %s  HP:%.0f  [%s]" % [companion_id, hp, status])
	print("")
