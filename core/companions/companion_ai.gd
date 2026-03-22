extends Node
## CompanionAI - IA de combate para companions del grupo
##
## Escucha companion_turn_started y decide una acción automáticamente
## según la estrategia configurada en PartyManager para este companion.
##
## La estrategia se lee en tiempo de ejecución: Party.get_strategy(companion_id)
## Se puede cambiar en cualquier momento vía Party.set_strategy() o PartyUI.

@export var companion_id: String = "companion_mira"
@export var attack_skill_id: String = "skill.attack.light"  ## fallback si no hay skill disponible
@export var decision_delay: float = 0.6

const PLAYER_ID: String = "player"


func _ready() -> void:
	if EventBus:
		EventBus.companion_turn_started.connect(_on_companion_turn_started)
	else:
		push_error("[CompanionAI] EventBus not found!")
	print("[CompanionAI] Initialized — %s" % companion_id)


func _on_companion_turn_started(acting_companion_id: String) -> void:
	if acting_companion_id != companion_id:
		return

	if Party.is_incapacitated(companion_id):
		print("[CompanionAI] %s is incapacitated — skipping turn" % companion_id)
		_end_turn_empty()
		return

	var strategy: Party.CompanionStrategy = Party.get_strategy(companion_id)
	print("[CompanionAI] %s deciding (strategy: %s)..." % [
		companion_id, Party.CompanionStrategy.keys()[strategy]
	])

	await get_tree().create_timer(decision_delay).timeout
	_decide_and_act()


func _decide_and_act() -> void:
	var strategy: Party.CompanionStrategy = Party.get_strategy(companion_id)
	var skill_id: String = _pick_best_skill(strategy)
	var target: String   = _pick_best_target(skill_id, strategy)

	if target.is_empty() and not _is_self_target_skill(skill_id):
		print("[CompanionAI] %s: no valid target found" % companion_id)
		_end_turn_empty()
		return

	var action_data: Dictionary = {
		"actor":    companion_id,
		"skill_id": skill_id,
		"target":   target,
	}

	print("[CompanionAI] %s → %s on %s" % [
		companion_id, skill_id, target if not target.is_empty() else "SELF"
	])
	EventBus.emit_signal("player_action_requested", action_data)


# ============================================
# SELECCIÓN DE SKILL
# ============================================

func _pick_best_skill(strategy: Party.CompanionStrategy) -> String:
	match strategy:
		Party.CompanionStrategy.AREA_FOCUS:
			return _pick_area_skill_or_fallback()
		Party.CompanionStrategy.BERSERKER:
			return _pick_heaviest_skill()
		_:
			return _pick_primary_attack()


func _pick_primary_attack() -> String:
	var skills_node: Node = get_node_or_null("/root/Skills")
	if not skills_node:
		return attack_skill_id

	var candidates: Array[String] = []
	var known: Array[String] = Characters.list_known_skills(companion_id)

	for skill_id in known:
		var instance: SkillInstance = skills_node.get_skill_instance(companion_id, skill_id)
		if not instance or not instance.is_available():
			continue
		var def: SkillDefinition = skills_node.get_skill_definition(skill_id)
		if not def or def.mode != "COMBAT":
			continue
		if "attack" in skill_id or "attack" in def.tags:
			candidates.append(skill_id)

	if candidates.is_empty():
		return attack_skill_id

	for skill_id in candidates:
		var def: SkillDefinition = Skills.get_skill_definition(skill_id)
		if def and def.target_type == "SINGLE_ENEMY":
			return skill_id

	return candidates[0]


func _pick_area_skill_or_fallback() -> String:
	var skills_node: Node = get_node_or_null("/root/Skills")
	if not skills_node:
		return _pick_primary_attack()

	var known: Array[String] = Characters.list_known_skills(companion_id)
	for skill_id in known:
		var instance: SkillInstance = skills_node.get_skill_instance(companion_id, skill_id)
		if not instance or not instance.is_available():
			continue
		var def: SkillDefinition = skills_node.get_skill_definition(skill_id)
		if not def or def.mode != "COMBAT":
			continue
		if def.target_type in ["AREA", "MULTI_ENEMY"]:
			return skill_id

	return _pick_primary_attack()


func _pick_heaviest_skill() -> String:
	var skills_node: Node = get_node_or_null("/root/Skills")
	if not skills_node:
		return _pick_primary_attack()

	var best_skill: String = ""
	var best_cost: float   = -1.0
	var known: Array[String] = Characters.list_known_skills(companion_id)

	for skill_id in known:
		var instance: SkillInstance = skills_node.get_skill_instance(companion_id, skill_id)
		if not instance or not instance.is_available():
			continue
		var def: SkillDefinition = skills_node.get_skill_definition(skill_id)
		if not def or def.mode != "COMBAT":
			continue
		var cost: float = def.get_cost("stamina")
		if cost > best_cost:
			best_cost  = cost
			best_skill = skill_id

	return best_skill if not best_skill.is_empty() else _pick_primary_attack()


# ============================================
# SELECCIÓN DE TARGET
# ============================================

func _pick_best_target(skill_id: String, strategy: Party.CompanionStrategy) -> String:
	var def: SkillDefinition = Skills.get_skill_definition(skill_id)
	if def and def.target_type == "AREA":
		return _get_any_enemy()

	match strategy:
		Party.CompanionStrategy.DEFENSIVE:
			return _pick_strongest_enemy()
		_:
			return _pick_weakest_enemy()


func _pick_weakest_enemy() -> String:
	var enemies: Array[String] = _get_active_enemies()
	var best: String = ""
	var lowest_hp: float = INF
	for enemy_id in enemies:
		var hp: float = Resources.get_resource_amount(enemy_id, "health")
		if hp > 0.0 and hp < lowest_hp:
			lowest_hp = hp
			best = enemy_id
	return best


func _pick_strongest_enemy() -> String:
	var enemies: Array[String] = _get_active_enemies()
	var best: String = ""
	var highest_hp: float = -1.0
	for enemy_id in enemies:
		var hp: float = Resources.get_resource_amount(enemy_id, "health")
		if hp > highest_hp:
			highest_hp = hp
			best = enemy_id
	return best


func _get_any_enemy() -> String:
	var enemies: Array[String] = _get_active_enemies()
	return enemies[0] if not enemies.is_empty() else ""


func _get_active_enemies() -> Array[String]:
	var game_loop: GameLoopSystem = get_node_or_null("/root/GameLoop")
	if not game_loop:
		return []
	return game_loop.get_active_enemies()


func _is_self_target_skill(skill_id: String) -> bool:
	var def: SkillDefinition = Skills.get_skill_definition(skill_id)
	return def != null and def.target_type == "SELF"


func _end_turn_empty() -> void:
	EventBus.companion_action_completed.emit(companion_id, {"skipped": true})
