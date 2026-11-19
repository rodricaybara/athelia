extends Node

## IA-0d — Prueba de datos de combate: constitución y recursos derivados, kits de skills
## de enemigos y de Mira, campos nuevos de CharacterDefinition, dodge unificado,
## AREA por bando, focus de fireball y DefenseModule.
##
## Patrón del proyecto: F6 en ia0d_test.tscn, _assert(), contadores [PASS]/[FAIL] y
## get_tree().quit(código) al final (0 = todo bien) para poder lanzarla con --headless.
##
## Bloques:
##   A. Máximos de vida y estamina de los 5 enemigos, registro de refuerzos, kits
##   B. Campos behavior_profile_id / threat_hint y duplicate_definition()
##   C. Skills nuevas: heavy_attack, defend/recover de Mira, fireball sin focus, textos
##   D. get_candidates de enemigos y de Mira según estamina
##   E. dodge: sus dos buffs se consumen al primer uso
##   F. Skill multi-objetivo (sweep) según el bando del atacante
##   G. DefenseModule: overflow de estamina (daño 10, estamina 3 → 7 a la vida)

# --- Datos del proyecto (ajusta si tus ids son otros) -------------------------------
const PLAYER_ID: String = "player"
const MIRA_DEFINITION: String = "companion_mira"
const PARTY_DEFINITION: String = "companion_base"
const PARTY_ID: String = "ia0d_comp"
const PARTY_ID_2: String = "ia0d_comp2"
const AREA_ATTACKER: String = "ia0d_area"
const DEFENSE_ENTITY: String = "ia0d_def"

const SKILL_BASIC: String = "skill.enemy.basic_attack"
const SKILL_HEAVY: String = "skill.enemy.heavy_attack"
const SKILL_DEFEND: String = "skill.enemy.defend"
const SKILL_RECOVER: String = "skill.enemy.recover"
const SKILL_COMP_DEFEND: String = "skill.companion.defend"
const SKILL_COMP_RECOVER: String = "skill.companion.recover"
const SKILL_LIGHT: String = "skill.attack.light"
const SKILL_SWEEP: String = "skill.attack.sweep"
const SKILL_DODGE: String = "skill.combat.dodge"
const SKILL_FIREBALL: String = "skill.magic.fireball"

## Los cinco enemigos reales: vida y estamina máximas y kit esperados.
const ENEMIES: Array[Dictionary] = [
	{"def": "enemy_base", "hp": 40.0, "st": 28.0, "kit": [SKILL_BASIC, SKILL_DEFEND, SKILL_RECOVER]},
	{"def": "telmori_warrior_base", "hp": 60.0, "st": 45.0, "kit": [SKILL_BASIC, SKILL_HEAVY, SKILL_DEFEND]},
	{"def": "telmori_warrior_weak", "hp": 60.0, "st": 40.5, "kit": [SKILL_BASIC, SKILL_HEAVY, SKILL_DEFEND]},
	{"def": "telmori_wolf_base", "hp": 50.0, "st": 35.0, "kit": [SKILL_BASIC, SKILL_HEAVY, SKILL_RECOVER]},
	{"def": "telmori_wolf_weak", "hp": 45.0, "st": 31.5, "kit": [SKILL_BASIC, SKILL_HEAVY, SKILL_RECOVER]},
]

var _passed: int = 0
var _failed: int = 0
var _enemy_ids: Array[String] = []


func _ready() -> void:
	await _run()
	print("")
	print("==== IA-0d: %d OK · %d FALLOS ====" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _assert(condition: bool, text: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % text)
	else:
		_failed += 1
		print("[FAIL] %s" % text)


func _run() -> void:
	if not _preflight():
		return
	_test_a_enemies()
	_test_b_definition_fields()
	_test_c_skills()
	_test_d_candidates()
	_test_e_dodge()
	_test_f_area_by_side()
	_test_g_defense_module()
	_cleanup()


# ============================================
# Preparación
# ============================================

func _preflight() -> bool:
	var ok: bool = true
	var needed: Array[String] = [MIRA_DEFINITION, PARTY_DEFINITION]
	for entry in ENEMIES:
		needed.append(entry.def)
	for definition_id in needed:
		if not Characters.has_definition(definition_id):
			_assert(false, "definición '%s' no existe: ajusta las constantes de la prueba" % definition_id)
			ok = false
	return ok


func _sorted(values: Array) -> Array:
	var result: Array = []
	for value in values:
		result.append(String(value))
	result.sort()
	return result


## Registro como lo hace la escena de combate: Characters → Resources (sin lista) → Skills.
func _register_enemy(entity_id: String, definition_id: String, skill_ids: Array) -> void:
	if Characters.has_entity(entity_id):
		EntityLifecycle.unregister_everywhere(entity_id)
	Characters.register_entity(entity_id, definition_id)
	Resources.register_entity(entity_id)
	Skills.register_entity_skills(entity_id, skill_ids)


## Mira como "player": el jugador es aliado para Combat y así se prueba el bando aliado.
func _register_mira_as_player(skill_ids: Array) -> void:
	if Characters.has_entity(PLAYER_ID):
		EntityLifecycle.unregister_everywhere(PLAYER_ID)
	Characters.register_entity(PLAYER_ID, MIRA_DEFINITION)
	Resources.register_entity(PLAYER_ID)
	Skills.register_entity_skills(PLAYER_ID, skill_ids)
	for skill_id in skill_ids:
		var instance: SkillInstance = Skills.get_skill_instance(PLAYER_ID, skill_id)
		if instance:
			instance.is_unlocked = true   # igual que PartyManager con el kit de un companion


func _set_arena(enemy_ids: Array, extra_allies: Array = []) -> void:
	var order: Array[String] = []
	var members: Array[String] = [PLAYER_ID]
	for ally_id in extra_allies:
		members.append(ally_id)
	for enemy_id in enemy_ids:
		order.append(enemy_id)
		members.append(enemy_id)
	GameLoop.turn_order = order
	GameLoop.participants = members


func _candidate_ids(actor_id: String) -> Array:
	var ids: Array = []
	for candidate in Combat.get_candidates(actor_id):
		if not ids.has(candidate.action_id):
			ids.append(candidate.action_id)
	return ids


func _fire(actor: String, skill_id: String, target: String) -> void:
	EventBus.execute_combat_action.emit({
		"actor": actor,
		"skill_id": skill_id,
		"target": target,
		"request_id": Combat.next_request_id(),
	})


func _cleanup() -> void:
	for entity_id in _enemy_ids + [PLAYER_ID, AREA_ATTACKER, DEFENSE_ENTITY]:
		if Characters.has_entity(entity_id):
			EntityLifecycle.unregister_everywhere(entity_id)
	for companion_id in [PARTY_ID, PARTY_ID_2]:
		if Party.is_in_party(companion_id):
			Party.leave_party(companion_id)


# ============================================
# A. Máximos, refuerzos y kits de los enemigos
# ============================================

func _test_a_enemies() -> void:
	print("\n--- A. Máximos, registro completo y kits de enemigos ---")
	var index: int = 0
	for entry in ENEMIES:
		var def_id: String = entry.def
		var entity_id: String = "ia0d_e%d" % index
		index += 1
		_enemy_ids.append(entity_id)

		var definition: CharacterDefinition = Characters.get_definition(def_id)
		_assert(not definition.starting_resources.has("health") and not definition.starting_resources.has("stamina"),
			"%s: starting_resources ya no declara health/stamina (salen de la constitución)" % def_id)

		_register_enemy(entity_id, def_id, definition.skills)
		_assert(Resources.has_resource(entity_id, "health") and Resources.has_resource(entity_id, "stamina") and Resources.has_resource(entity_id, "gold"),
			"%s: register_entity sin lista registra vida, estamina y oro (también un refuerzo)" % def_id)

		var hp: ResourceState = Resources.get_resource_state(entity_id, "health")
		var st: ResourceState = Resources.get_resource_state(entity_id, "stamina")
		_assert(is_equal_approx(hp.max_effective, entry.hp) and is_equal_approx(hp.current, entry.hp),
			"%s: vida %.1f/%.1f (esperada %.1f)" % [def_id, hp.current, hp.max_effective, entry.hp])
		_assert(is_equal_approx(st.max_effective, entry.st) and is_equal_approx(st.current, entry.st),
			"%s: estamina %.1f/%.1f (esperada %.1f)" % [def_id, st.current, st.max_effective, entry.st])

		_assert(_sorted(definition.skills) == _sorted(entry.kit),
			"%s: kit de la definición %s" % [def_id, str(_sorted(definition.skills))])
		for skill_id in definition.skills:
			_assert(Skills.get_skill_instance(entity_id, skill_id) != null, "%s: skill '%s' registrada" % [def_id, skill_id])
		if definition.skills.has(SKILL_HEAVY):
			_assert(Characters.get_skill_value(entity_id, SKILL_HEAVY) > 0, "%s: heavy_attack tiene valor de habilidad > 0" % def_id)


# ============================================
# B. Campos nuevos de CharacterDefinition
# ============================================

func _test_b_definition_fields() -> void:
	print("\n--- B. behavior_profile_id y threat_hint ---")
	var definition: CharacterDefinition = Characters.get_definition("telmori_wolf_base")
	_assert(definition.behavior_profile_id == &"", "behavior_profile_id vale &\"\" por defecto")
	_assert(definition.threat_hint == "", "threat_hint vale \"\" por defecto")

	var copy: CharacterDefinition = definition.duplicate_definition()
	copy.behavior_profile_id = &"ia0d_profile"
	copy.threat_hint = "high"
	var second: CharacterDefinition = copy.duplicate_definition()
	_assert(second.behavior_profile_id == &"ia0d_profile" and second.threat_hint == "high",
		"duplicate_definition() copia behavior_profile_id y threat_hint")
	_assert(definition.threat_hint == "", "la definición original no se toca al duplicar")


# ============================================
# C. Skills nuevas y cambios de datos
# ============================================

func _test_c_skills() -> void:
	print("\n--- C. heavy_attack, skills de Mira, fireball y textos ---")
	var heavy: SkillDefinition = Skills.get_skill_definition(SKILL_HEAVY)
	_assert(heavy != null, "heavy_attack cargada")
	if heavy:
		_assert(is_equal_approx(float(heavy.costs.get("stamina", -1.0)), 15.0), "heavy_attack cuesta 15 de estamina")
		_assert(is_equal_approx(heavy.base_cooldown, 3.0), "heavy_attack tiene cooldown 3")
		_assert(heavy.target_type == "SINGLE_ENEMY", "heavy_attack es SINGLE_ENEMY")

	var comp_defend: SkillDefinition = Skills.get_skill_definition(SKILL_COMP_DEFEND)
	var comp_recover: SkillDefinition = Skills.get_skill_definition(SKILL_COMP_RECOVER)
	_assert(comp_defend != null and comp_recover != null, "las dos skills de Mira están cargadas")
	if comp_defend:
		_assert(comp_defend.target_type == "SELF" and is_equal_approx(float(comp_defend.costs.get("stamina", -1.0)), 10.0),
			"companion.defend es SELF y cuesta 10")
	if comp_recover:
		_assert(comp_recover.target_type == "SELF" and comp_recover.costs.is_empty(), "companion.recover es SELF y no cuesta nada")

	var mira: CharacterDefinition = Characters.get_definition(MIRA_DEFINITION)
	_assert(mira.skills.has(SKILL_COMP_DEFEND) and mira.skills.has(SKILL_COMP_RECOVER), "companion_mira trae defend y recover en su kit")
	_assert(not mira.starting_skill_values.has(SKILL_COMP_DEFEND) and not mira.starting_skill_values.has(SKILL_COMP_RECOVER),
		"sin valor de habilidad: los selectores heredados de CompanionAI no las ven")

	var fireball: SkillDefinition = Skills.get_skill_definition(SKILL_FIREBALL)
	_assert(fireball != null and not fireball.costs.has("focus"), "fireball ya no cuesta focus")
	if fireball:
		_assert(is_equal_approx(float(fireball.costs.get("stamina", -1.0)), 15.0), "fireball sigue costando 15 de estamina")

	for key in ["SKILL_ENEMY_HEAVY_ATTACK_NAME", "SKILL_ENEMY_HEAVY_ATTACK_DESC",
			"SKILL_COMPANION_DEFEND_NAME", "SKILL_COMPANION_DEFEND_DESC",
			"SKILL_COMPANION_RECOVER_NAME", "SKILL_COMPANION_RECOVER_DESC"]:
		_assert(tr(key) != key, "texto localizado: %s" % key)


# ============================================
# D. Candidatas según estamina
# ============================================

func _test_d_candidates() -> void:
	print("\n--- D. get_candidates de enemigos y de Mira ---")
	var mira_skills: Array = Characters.get_definition(MIRA_DEFINITION).skills
	_register_mira_as_player(mira_skills)
	_set_arena(_enemy_ids)

	# Guerrero (índice 1): basic + heavy + defend.
	var warrior: String = _enemy_ids[1]
	Resources.restore_resource(warrior, "stamina")
	var full: Array = _candidate_ids(warrior)
	_assert(full.has(SKILL_BASIC) and full.has(SKILL_HEAVY) and full.has(SKILL_DEFEND) and not full.has(SKILL_RECOVER),
		"guerrero con estamina llena: basic + heavy + defend %s" % str(full))
	Resources.set_resource(warrior, "stamina", 12.0)
	var low: Array = _candidate_ids(warrior)
	_assert(low.has(SKILL_BASIC) and low.has(SKILL_DEFEND) and not low.has(SKILL_HEAVY),
		"guerrero con 12: defend (10) sí, heavy (15) no %s" % str(low))
	Resources.set_resource(warrior, "stamina", 0.0)
	var empty: Array = Combat.get_candidates(warrior)
	var costly: bool = false
	var has_basic: bool = false
	for candidate in empty:
		if candidate.resource_cost > 0.0:
			costly = true
		if candidate.action_id == SKILL_BASIC:
			has_basic = true
	_assert(has_basic and not costly, "guerrero sin estamina: solo lo gratuito (basic_attack)")

	# Lobo (índice 3): basic + heavy + recover.
	var wolf: String = _enemy_ids[3]
	Resources.set_resource(wolf, "stamina", 5.0)
	var wolf_low: Array = _candidate_ids(wolf)
	_assert(wolf_low.has(SKILL_RECOVER) and not wolf_low.has(SKILL_HEAVY) and not wolf_low.has(SKILL_DEFEND),
		"lobo con 5: recover sí, heavy no, sin defend %s" % str(wolf_low))
	Resources.restore_resource(wolf, "stamina")
	var wolf_full: Array = _candidate_ids(wolf)
	_assert(wolf_full.has(SKILL_HEAVY) and wolf_full.has(SKILL_BASIC), "lobo con estamina llena: heavy y basic %s" % str(wolf_full))

	# enemy_base (índice 0): basic + defend + recover.
	var base: String = _enemy_ids[0]
	Resources.set_resource(base, "stamina", 5.0)
	var base_low: Array = _candidate_ids(base)
	_assert(base_low.has(SKILL_RECOVER) and base_low.has(SKILL_BASIC) and not base_low.has(SKILL_DEFEND),
		"enemy_base con 5: basic + recover, sin defend %s" % str(base_low))

	# Mira (como jugador, bando aliado): defend / recover según estamina.
	Resources.restore_resource(PLAYER_ID, "stamina")
	var mira_full: Array = _candidate_ids(PLAYER_ID)
	_assert(mira_full.has(SKILL_COMP_DEFEND) and mira_full.has(SKILL_LIGHT),
		"Mira con estamina llena: defend + ataque ligero %s" % str(mira_full))
	Resources.set_resource(PLAYER_ID, "stamina", 5.0)
	var mira_low: Array = _candidate_ids(PLAYER_ID)
	_assert(mira_low.has(SKILL_COMP_RECOVER) and not mira_low.has(SKILL_COMP_DEFEND),
		"Mira con 5 de estamina: recover sí, defend (10) no %s" % str(mira_low))
	Resources.restore_resource(PLAYER_ID, "stamina")

	# Una skill SELF de Mira se ejecuta por la vía de datos.
	Skills.get_skill_instance(PLAYER_ID, SKILL_COMP_DEFEND).reset_cooldown()
	_fire(PLAYER_ID, SKILL_COMP_DEFEND, "")
	_assert(Combat.has_buff(PLAYER_ID, "damage_reduction"), "companion.defend aplica damage_reduction")
	Combat.clear_buffs(PLAYER_ID)
	Resources.set_resource(PLAYER_ID, "stamina", 5.0)
	Skills.get_skill_instance(PLAYER_ID, SKILL_COMP_RECOVER).reset_cooldown()
	_fire(PLAYER_ID, SKILL_COMP_RECOVER, "")
	_assert(is_equal_approx(Resources.get_resource_amount(PLAYER_ID, "stamina"), 25.0), "companion.recover: 5 → 25 de estamina")
	Resources.restore_resource(PLAYER_ID, "stamina")


# ============================================
# E. dodge: buffs de un solo uso desde el .tres
# ============================================

func _test_e_dodge() -> void:
	print("\n--- E. dodge unificado ---")
	_set_arena(_enemy_ids)
	Combat.clear_buffs(PLAYER_ID)
	Resources.restore_resource(PLAYER_ID, "stamina")
	var stamina_before: float = Resources.get_resource_amount(PLAYER_ID, "stamina")
	Skills.get_skill_instance(PLAYER_ID, SKILL_DODGE).reset_cooldown()
	_fire(PLAYER_ID, SKILL_DODGE, "")
	_assert(Combat.has_buff(PLAYER_ID, "guaranteed_hit") and Combat.has_buff(PLAYER_ID, "evasion"),
		"dodge aplica guaranteed_hit y evasion")
	_assert(is_equal_approx(Resources.get_resource_amount(PLAYER_ID, "stamina"), stamina_before - 15.0), "dodge cobra 15 de estamina")
	Combat.consume_buff(PLAYER_ID, "evasion")
	Combat.consume_buff(PLAYER_ID, "guaranteed_hit")
	_assert(not Combat.has_buff(PLAYER_ID, "evasion") and not Combat.has_buff(PLAYER_ID, "guaranteed_hit"),
		"cada buff de dodge desaparece con un solo consumo (expires_on: use)")
	Combat.clear_buffs(PLAYER_ID)


# ============================================
# F. Skill de varios objetivos según el bando del atacante
# ============================================
## `sweep` es MULTI_ENEMY (hasta max_targets objetivos del bando contrario). AREA y
## MULTI_ENEMY comparten _get_hit_pool(), así que esto cubre la regla de bando de las dos.

func _test_f_area_by_side() -> void:
	print("\n--- F. Skill multi-objetivo según el bando ---")
	var sweep: SkillDefinition = Skills.get_skill_definition(SKILL_SWEEP)
	_assert(sweep != null and sweep.target_type in ["AREA", "MULTI_ENEMY"], "sweep apunta a varios objetivos (%s)" % (sweep.target_type if sweep else "no cargada"))
	if sweep == null:
		return
	var max_targets: int = 2
	for effect in sweep.effects:
		if String(effect.get("type", "")).to_lower() == "damage":
			max_targets = int(effect.get("max_targets", max_targets))
			break
	var is_area: bool = (sweep.target_type == "AREA")

	# Dos compañeros en el grupo + el jugador (3 aliados) y tres enemigos.
	for companion_id in [PARTY_ID, PARTY_ID_2]:
		if not Party.is_in_party(companion_id):
			Party.join_party(companion_id, PARTY_DEFINITION)
	_register_mira_as_player([SKILL_SWEEP])
	_register_enemy(AREA_ATTACKER, "telmori_warrior_base", [SKILL_BASIC, SKILL_SWEEP])
	for entity_id in [PLAYER_ID, AREA_ATTACKER]:
		if Characters.get_skill_value(entity_id, SKILL_SWEEP) < 40:
			Characters.set_skill_value(entity_id, SKILL_SWEEP, 40)
	var enemies: Array[String] = [AREA_ATTACKER, _enemy_ids[0], _enemy_ids[1]]
	var allies: Array[String] = [PLAYER_ID, PARTY_ID, PARTY_ID_2]
	_set_arena(enemies, [PARTY_ID, PARTY_ID_2])

	# Enemigo atacando al jugador: solo alcanza al bando aliado, con el principal primero.
	var enemy_hit: Array = Combat.estimate_damage(AREA_ATTACKER, PLAYER_ID, SKILL_SWEEP).targets
	var enemy_hits_enemy: bool = false
	for hit_id in enemy_hit:
		if not allies.has(hit_id):
			enemy_hits_enemy = true
	var expected_enemy_size: int = allies.size() if is_area else mini(max_targets, allies.size())
	_assert(not enemy_hits_enemy and enemy_hit.size() == expected_enemy_size and enemy_hit.has(PLAYER_ID),
		"un enemigo golpea solo a aliados, con el objetivo principal incluido, %d de %d %s" % [enemy_hit.size(), allies.size(), str(enemy_hit)])

	# Aliado atacando a un enemigo: solo alcanza al bando enemigo (comportamiento previo).
	var ally_hit: Array = Combat.estimate_damage(PLAYER_ID, _enemy_ids[0], SKILL_SWEEP).targets
	var ally_hits_ally: bool = false
	for hit_id in ally_hit:
		if not enemies.has(hit_id):
			ally_hits_ally = true
	var expected_ally_size: int = enemies.size() if is_area else mini(max_targets, enemies.size())
	_assert(not ally_hits_ally and ally_hit.size() == expected_ally_size and ally_hit.has(_enemy_ids[0]),
		"el jugador golpea solo a enemigos, con el objetivo principal incluido, %d de %d %s" % [ally_hit.size(), enemies.size(), str(ally_hit)])

	for companion_id in [PARTY_ID, PARTY_ID_2]:
		if Party.is_in_party(companion_id):
			Party.leave_party(companion_id)


# ============================================
# G. DefenseModule
# ============================================

func _test_g_defense_module() -> void:
	print("\n--- G. DefenseModule: overflow de estamina ---")
	_register_enemy(DEFENSE_ENTITY, "enemy_base", ["skill.enemy.basic_attack"])

	# Sin overflow: daño 10, estamina de sobra → 7 a estamina, 3 a la vida.
	var module := DefenseModule.new()
	Resources.set_resource(DEFENSE_ENTITY, "stamina", 20.0)
	module.activate_defense()
	var hp_normal: int = module.process_incoming_damage(10, DEFENSE_ENTITY)
	_assert(hp_normal == 3, "estamina suficiente: 10 de daño → 3 a la vida (%d)" % hp_normal)
	_assert(is_equal_approx(Resources.get_resource_amount(DEFENSE_ENTITY, "stamina"), 13.0), "y se gastan 7 de estamina")

	# Con overflow: daño 10, estamina 3 → absorbe 3, los otros 4 pasan a la vida (3 + 4 = 7).
	var module_b := DefenseModule.new()
	Resources.set_resource(DEFENSE_ENTITY, "stamina", 3.0)
	module_b.activate_defense()
	var hp_overflow: int = module_b.process_incoming_damage(10, DEFENSE_ENTITY)
	_assert(hp_overflow == 7, "estamina 3: 10 de daño → 7 a la vida, sin absorber gratis (%d)" % hp_overflow)
	_assert(is_equal_approx(Resources.get_resource_amount(DEFENSE_ENTITY, "stamina"), 0.0), "la estamina queda a 0")
