extends Node

## IA-0c — Prueba de estimaciones, candidatas, RNG inyectable, skills SELF y huida.
##
## Patrón del proyecto: F6 en ia0c_test.tscn, _assert(), contadores [PASS]/[FAIL] y
## get_tree().quit(código) al final (0 = todo bien) para poder lanzarla con --headless.
##
## Necesita dos definiciones de personaje REALES del proyecto (constantes de abajo) y que
## CharacterSystem tenga una API para fijar el valor de una skill (set_skill_value). Si
## algo falta, la prueba lo dice con un [FAIL] claro y sigue con lo demás.
##
## Bloques:
##   A. SkillRoller: probabilidades, semilla y vuelta al RNG global
##   B. Estimación vs media real (ataque ligero, pesado y barrido, con y sin defensa)
##   C. get_candidates, get_hp_state, get_visible_conditions, estimate_threat
##   D. Skills SELF de datos (defender, recuperar) y huida (FLEE) + INVALID_TARGET
##   E. GameLoop: el enemigo que huye se retira sin saltarse al siguiente
##
## La parte B ejecuta acciones por el camino REAL (EventBus.execute_combat_action → Combat)
## con el RNG de SkillRoller sembrado, y silencia el Output mientras dura.

# --- Datos del proyecto (ajusta si tus ids son otros) -------------------------------
const ATTACKER_DEFINITION: String = "companion_mira"        # id de CharacterDefinition con skills de ataque
const TARGET_DEFINITION: String = "telmori_wolf_base"    # id de CharacterDefinition de un enemigo

const SKILL_LIGHT: String = "skill.attack.light"
const SKILL_HEAVY: String = "skill.attack.heavy"
const SKILL_SWEEP: String = "skill.attack.sweep"
const SKILL_DEFEND: String = "skill.enemy.defend"
const SKILL_RECOVER: String = "skill.enemy.recover"
const SKILL_FLEE: String = "skill.enemy.flee"
const SKILL_ENEMY_BASIC: String = "skill.enemy.basic_attack"

const PLAYER_ID: String = "player"
const ATTACKER: String = "ia0c_attacker"   # no aliado: sin progresión de skills ni reglas del jugador
const TARGETS: Array[String] = ["ia0c_t1", "ia0c_t2", "ia0c_t3"]

const RUNS: int = 40000            # ejecuciones reales por caso (error típico ≈ 0,5 %)
const SEED: int = 20261115
const MAX_ERROR: float = 0.02      # 2 % de la validación de la spec
const BIG_HP: float = 1000000.0    # nadie muere durante las ejecuciones
const MIN_SKILL_VALUE: int = 40

## E arranca un combate real con GameLoop. Si al empezarlo SceneOrchestrator carga la
## arena de producción (EnemyAI y controlador del jugador propios), harían de segundo
## jugador y falsearían la prueba: déjalo en false y valida la huida en partida (paso de
## validación manual del informe). Ponlo a true solo si esta escena corre sin arena.
const RUN_GAMELOOP_TEST: bool = false

var _passed: int = 0
var _failed: int = 0

# captura de señales
var _fled_ids: Array[String] = []
var _failures: Array[Array] = []        # [actor, reason]
var _completed: Array[Dictionary] = []
var _executed_count: int = 0


func _ready() -> void:
	await _run()
	print("")
	print("==== IA-0c: %d OK · %d FALLOS ====" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _assert(condition: bool, text: String) -> void:
	if condition:
		_passed += 1
		print("[PASS] %s" % text)
	else:
		_failed += 1
		print("[FAIL] %s" % text)


func _run() -> void:
	EventBus.enemy_fled.connect(func(id: String): _fled_ids.append(id))
	EventBus.combat_action_failed.connect(func(actor: String, reason: String, _rid: int): _failures.append([actor, reason]))
	EventBus.combat_action_completed.connect(func(result: Dictionary): _completed.append(result))
	EventBus.combat_action_executed.connect(func(_a, _s, _t, _r): _executed_count += 1)

	_test_a_roller()
	if not _setup():
		return
	_test_scales()
	_test_b_estimates()
	_test_c_candidates()
	_test_d_self_and_flee()
	await _test_e_gameloop()
	_cleanup()


# ============================================
# A. SkillRoller
# ============================================

func _test_a_roller() -> void:
	print("\n--- A. SkillRoller ---")
	var probs: Dictionary = SkillRoller.get_grade_probabilities(60)
	var total: float = 0.0
	for grade in probs.keys():
		total += float(probs[grade])
	_assert(is_equal_approx(total, 1.0), "las probabilidades de los 5 grados suman 1.0 (%.4f)" % total)
	_assert(is_equal_approx(SkillRoller.get_success_chance(50), 0.50), "skill 50 → acierto 0.50 (%.3f)" % SkillRoller.get_success_chance(50))
	_assert(is_equal_approx(SkillRoller.get_success_chance(100), 0.97), "skill 100 → acierto 0.97, pifia ≥98 (%.3f)" % SkillRoller.get_success_chance(100))
	_assert(SkillRoller.get_success_chance(0) == 0.0, "skill 0 → acierto 0.0")

	SkillRoller.set_seed(SEED)
	var first: Array[int] = []
	for i in 50:
		first.append(SkillRoller.roll_skill(55).roll)
	SkillRoller.set_seed(SEED)
	var second: Array[int] = []
	for i in 50:
		second.append(SkillRoller.roll_skill(55).roll)
	_assert(first == second, "misma semilla ⇒ mismas 50 tiradas")

	SkillRoller.set_seed(SEED + 1)
	var other: Array[int] = []
	for i in 50:
		other.append(SkillRoller.roll_skill(55).roll)
	_assert(other != first, "otra semilla ⇒ otras tiradas")

	SkillRoller.reset_rng()
	seed(77)
	var global_a: Array[int] = []
	for i in 20:
		global_a.append(SkillRoller.roll_skill(55).roll)
	seed(77)
	var global_b: Array[int] = []
	for i in 20:
		global_b.append(SkillRoller.roll_skill(55).roll)
	_assert(global_a == global_b, "tras reset_rng() vuelve al RNG global (seed() lo gobierna)")


func _test_scales() -> void:
	print("\n--- ai_scales ---")
	var errors: Array[String] = AIScales.validate()
	_assert(errors.is_empty(), "ai_scales.json válido %s" % str(errors))
	_assert(float(AIScales.get_value("effect_value.restore.stamina", -1.0)) > 0.0, "effect_value.restore.stamina declarado")
	_assert(AIScales.get_value("ruta.que.no.existe", "x") == "x", "ruta inexistente → fallback")


# ============================================
# Preparación
# ============================================

func _setup() -> bool:
	print("\n--- Preparación ---")
	var ok: bool = true
	for definition_id in [ATTACKER_DEFINITION, TARGET_DEFINITION]:
		if not Characters.has_definition(definition_id):
			_assert(false, "definición '%s' no existe: ajusta las constantes de la prueba" % definition_id)
			ok = false
	if not ok:
		return false

	var attacker_skills: Array = [SKILL_LIGHT, SKILL_HEAVY, SKILL_SWEEP]
	_register(PLAYER_ID, ATTACKER_DEFINITION, attacker_skills)
	_register(ATTACKER, ATTACKER_DEFINITION, attacker_skills)
	var enemy_skills: Array = [SKILL_ENEMY_BASIC, SKILL_DEFEND, SKILL_RECOVER, SKILL_FLEE]
	for target_id in TARGETS:
		_register(target_id, TARGET_DEFINITION, enemy_skills)
		Resources.set_max_effective(target_id, "health", BIG_HP)
		Resources.restore_resource(target_id, "health")

	for skill_id in attacker_skills:
		for entity_id in [PLAYER_ID, ATTACKER]:
			_ensure_skill_value(entity_id, skill_id)
	_ensure_skill_value(TARGETS[0], SKILL_ENEMY_BASIC)

	for skill_id in [SKILL_LIGHT, SKILL_HEAVY, SKILL_SWEEP]:
		_assert(Skills.get_skill_definition(skill_id) != null, "skill '%s' cargada" % skill_id)
	for skill_id in [SKILL_DEFEND, SKILL_RECOVER, SKILL_FLEE]:
		_assert(Skills.get_skill_definition(skill_id) != null, "skill de datos '%s' cargada (¿copiaste los .tres a data/skills/enemy/?)" % skill_id)

	_set_arena(TARGETS)
	return true


func _register(entity_id: String, definition_id: String, skill_ids: Array) -> void:
	if Characters.has_entity(entity_id):
		EntityLifecycle.unregister_everywhere(entity_id)
	Characters.register_entity(entity_id, definition_id)
	Resources.register_entity(entity_id)
	Skills.register_entity_skills(entity_id, skill_ids)


## La prueba necesita acierto > 0: si el personaje no trae valor, lo fija (si hay API).
func _ensure_skill_value(entity_id: String, skill_id: String) -> void:
	if Characters.get_skill_value(entity_id, skill_id) >= MIN_SKILL_VALUE:
		return
	if Characters.has_method("set_skill_value"):
		Characters.call("set_skill_value", entity_id, skill_id, MIN_SKILL_VALUE)
	_assert(Characters.get_skill_value(entity_id, skill_id) > 0,
		"%s tiene valor > 0 en %s (si falla: CharacterSystem no tiene set_skill_value o el valor no se fija)" % [entity_id, skill_id])


## Enemigos que ve GameLoop (turn_order) y participantes del combate simulado.
func _set_arena(enemy_ids: Array) -> void:
	var order: Array[String] = []
	var members: Array[String] = [PLAYER_ID, ATTACKER]
	for enemy_id in enemy_ids:
		order.append(enemy_id)
		members.append(enemy_id)
	GameLoop.turn_order = order
	GameLoop.participants = members


func _cleanup() -> void:
	SkillRoller.reset_rng()
	Engine.print_to_stdout = true
	for entity_id in [PLAYER_ID, ATTACKER] + TARGETS:
		if Characters.has_entity(entity_id):
			EntityLifecycle.unregister_everywhere(entity_id)


# ============================================
# B. Estimación vs media real
# ============================================

func _test_b_estimates() -> void:
	print("\n--- B. Estimación vs media real (%d ejecuciones por caso, error máximo %.1f %%) ---" % [RUNS, MAX_ERROR * 100.0])
	var main_target: String = TARGETS[0]
	for with_defense in [false, true]:
		Combat.clear_buffs(main_target)
		if with_defense:
			Combat.apply_buff(main_target, {"buff_type": "damage_reduction", "value": 30.0, "expires_on": "turn", "turns_left": 99})
		var label: String = "con damage_reduction 30 %" if with_defense else "sin buffs"
		for skill_id in [SKILL_LIGHT, SKILL_HEAVY, SKILL_SWEEP]:
			_check_estimate(skill_id, main_target, "%s · %s" % [skill_id, label])
	Combat.clear_buffs(main_target)


func _check_estimate(skill_id: String, main_target: String, label: String) -> void:
	if skill_id == SKILL_SWEEP:
		# IA-0d: ATTACKER no es aliado, así que su barrido golpea al bando contrario
		# (el jugador). Con BIG_HP no muere y el daño se mide como en los TARGETS.
		Resources.set_max_effective(PLAYER_ID, "health", BIG_HP)
		Resources.restore_resource(PLAYER_ID, "health")
	var estimate: Dictionary = Combat.estimate_damage(ATTACKER, main_target, skill_id)
	var expected: float = estimate.expected_damage
	if expected <= 0.0:
		_assert(false, "%s: estimación 0 (acierto %.2f): sin valor de skill no se puede comparar" % [label, estimate.success_chance])
		return

	var hit_targets: Array = estimate.targets
	SkillRoller.set_seed(SEED)
	var samples: PackedFloat64Array = _run_real(ATTACKER, skill_id, main_target, hit_targets)
	SkillRoller.reset_rng()

	var mean: float = 0.0
	for value in samples:
		mean += value
	mean /= samples.size()
	var variance: float = 0.0
	for value in samples:
		variance += (value - mean) * (value - mean)
	var std_error: float = sqrt(variance / samples.size()) / sqrt(float(samples.size()))
	var error: float = absf(mean - expected) / expected

	_assert(error <= MAX_ERROR, "%s: estimado %.3f vs real %.3f → error %.2f %% (error típico %.2f %%, objetivos %d)" % [
		label, expected, mean, error * 100.0, std_error / expected * 100.0, hit_targets.size()
	])


## Ejecuta `skill_id` RUNS veces por el camino real y devuelve el daño total por ejecución
## (suma de la salud perdida por los objetivos alcanzados). Silencia el Output.
func _run_real(attacker: String, skill_id: String, main_target: String, hit_targets: Array) -> PackedFloat64Array:
	var samples := PackedFloat64Array()
	var instance: SkillInstance = Skills.get_skill_instance(attacker, skill_id)
	Engine.print_to_stdout = false
	for i in RUNS:
		for target_id in hit_targets:
			Resources.restore_resource(target_id, "health")
		Resources.restore_resource(attacker, "stamina")
		instance.reset_cooldown()
		_fire(attacker, skill_id, main_target)
		var total: float = 0.0
		for target_id in hit_targets:
			total += BIG_HP - Resources.get_resource_amount(target_id, "health")
		samples.append(total)
	Engine.print_to_stdout = true
	return samples


func _fire(actor: String, skill_id: String, target: String) -> void:
	EventBus.execute_combat_action.emit({
		"actor": actor,
		"skill_id": skill_id,
		"target": target,
		"request_id": Combat.next_request_id(),
	})


# ============================================
# C. Candidatas, estado de salud, condiciones, amenaza
# ============================================

func _test_c_candidates() -> void:
	print("\n--- C. get_candidates y consultas ---")
	_set_arena(TARGETS)
	Skills.unlock_skill(PLAYER_ID, SKILL_HEAVY)
	Resources.restore_resource(PLAYER_ID, "stamina")
	Skills.get_skill_instance(PLAYER_ID, SKILL_LIGHT).reset_cooldown()

	var base: Array = Combat.get_candidates(PLAYER_ID)
	_assert(not base.is_empty(), "el jugador tiene candidatas (%d)" % base.size())
	_assert(_sorted_canonically(base), "orden canónico: action_id y después target_ids[0]")
	var shape_ok: bool = true
	for candidate in base:
		for key in ["action_id", "actor_id", "target_ids", "tags", "resource_cost", "success_chance",
				"expected_damage", "kill_possible", "effect_estimate", "action_data"]:
			if not candidate.has(key):
				shape_ok = false
	_assert(shape_ok, "cada candidata trae todos los campos del contrato")

	# Candidatas barajadas: el mismo orden aunque el actor registre sus skills al revés.
	var original_order: Array = _signature(base)
	EntityLifecycle.unregister_everywhere(PLAYER_ID)
	_register(PLAYER_ID, ATTACKER_DEFINITION, [SKILL_SWEEP, SKILL_HEAVY, SKILL_LIGHT])
	_ensure_skill_value(PLAYER_ID, SKILL_LIGHT)
	_ensure_skill_value(PLAYER_ID, SKILL_HEAVY)
	_ensure_skill_value(PLAYER_ID, SKILL_SWEEP)
	Skills.unlock_skill(PLAYER_ID, SKILL_HEAVY)
	_assert(_signature(Combat.get_candidates(PLAYER_ID)) == original_order, "candidatas con skills registradas al revés ⇒ mismo orden")

	# Sin estamina: nada que cueste estamina.
	Resources.set_resource(PLAYER_ID, "stamina", 0.0)
	var broke: Array = Combat.get_candidates(PLAYER_ID)
	var unaffordable: bool = false
	for candidate in broke:
		if candidate.resource_cost > 0.0:
			unaffordable = true
	_assert(not unaffordable, "sin estamina no se lista nada que cueste (%d candidatas)" % broke.size())
	Resources.restore_resource(PLAYER_ID, "stamina")

	# En cooldown: la skill desaparece.
	Skills.get_skill_instance(PLAYER_ID, SKILL_LIGHT).start_cooldown()
	var has_light: bool = false
	for candidate in Combat.get_candidates(PLAYER_ID):
		if candidate.action_id == SKILL_LIGHT:
			has_light = true
	_assert(not has_light, "una skill en cooldown no es candidata")
	Skills.get_skill_instance(PLAYER_ID, SKILL_LIGHT).reset_cooldown()

	# Un solo enemigo vivo.
	_set_arena([TARGETS[0]])
	var single_ok: bool = true
	var offensive: int = 0
	for candidate in Combat.get_candidates(PLAYER_ID):
		if CombatTags.TAG_ATTACK in candidate.tags:
			offensive += 1
			if candidate.target_ids != [TARGETS[0]]:
				single_ok = false
	_assert(offensive > 0 and single_ok, "con un solo enemigo vivo todas las ofensivas lo apuntan (%d)" % offensive)

	# Un objetivo a 0 PV no es objetivo.
	_set_arena(TARGETS)
	Resources.set_resource(TARGETS[1], "health", 0.0)
	var targets_dead: bool = false
	for candidate in Combat.get_candidates(PLAYER_ID):
		if TARGETS[1] in candidate.target_ids:
			targets_dead = true
	_assert(not targets_dead, "un combatiente a 0 PV no es objetivo")
	Resources.restore_resource(TARGETS[1], "health")

	# Candidatas de un enemigo (bando contrario = el jugador).
	var enemy_id: String = TARGETS[2]
	Resources.set_resource(enemy_id, "stamina", 5.0)
	var enemy_candidates: Array = Combat.get_candidates(enemy_id)
	var by_action: Dictionary = {}
	for candidate in enemy_candidates:
		by_action[candidate.action_id] = candidate
	_assert(by_action.has(SKILL_ENEMY_BASIC) and by_action[SKILL_ENEMY_BASIC].target_ids == [PLAYER_ID],
		"el enemigo ataca al jugador (única amenaza)")
	_assert(by_action.has(SKILL_RECOVER) and CombatTags.TAG_RECOVER in by_action[SKILL_RECOVER].tags,
		"recuperar es candidata con etiqueta recover")
	_assert(by_action.has(SKILL_RECOVER) and by_action[SKILL_RECOVER].effect_estimate > 0.0,
		"recuperar con estamina baja vale > 0 PV equivalentes (%.2f)" % float(by_action.get(SKILL_RECOVER, {}).get("effect_estimate", -1.0)))
	_assert(not by_action.has(SKILL_DEFEND), "defender cuesta 10 de estamina: con 5 no se lista")
	_assert(by_action.has(SKILL_FLEE) and CombatTags.TAG_FLEE in by_action[SKILL_FLEE].tags,
		"huir es candidata con etiqueta flee")
	Resources.restore_resource(enemy_id, "stamina")
	var full: Dictionary = {}
	for candidate in Combat.get_candidates(enemy_id):
		full[candidate.action_id] = candidate
	_assert(full.has(SKILL_DEFEND) and CombatTags.TAG_DEFENSE in full[SKILL_DEFEND].tags,
		"con estamina completa defender es candidata con etiqueta defense")
	_assert(full.has(SKILL_RECOVER) and full[SKILL_RECOVER].effect_estimate == 0.0,
		"recuperar con la estamina llena vale 0 (no hay hueco)")
	if full.has(SKILL_DEFEND):
		_assert(full[SKILL_DEFEND].effect_estimate >= 0.0, "effect_estimate de defender nunca es negativo (%.2f)" % full[SKILL_DEFEND].effect_estimate)

	# Estado de salud, condiciones y amenaza.
	var target_id: String = TARGETS[0]
	var hp_max: float = AttributeResolver.resolve(target_id, "health_max", {})
	Resources.set_resource(target_id, "health", hp_max)
	_assert(Combat.get_hp_state(target_id) == CombatTags.HP_HEALTHY, "100 % de salud → healthy")
	Resources.set_resource(target_id, "health", hp_max * 0.5)
	_assert(Combat.get_hp_state(target_id) == CombatTags.HP_HURT, "50 % de salud → hurt")
	Resources.set_resource(target_id, "health", hp_max * 0.1)
	_assert(Combat.get_hp_state(target_id) == CombatTags.HP_BADLY_HURT, "10 % de salud → badly_hurt")
	Resources.restore_resource(target_id, "health")

	Combat.clear_buffs(target_id)
	Combat.apply_buff(target_id, {"buff_type": "bleeding", "value": 1.0, "expires_on": "turn", "turns_left": 5})
	Combat.apply_buff(target_id, {"buff_type": "guaranteed_hit", "expires_on": "use", "uses_left": 1})
	var conditions: Array[StringName] = Combat.get_visible_conditions(target_id)
	_assert(conditions.has(&"bleeding") and not conditions.has(&"guaranteed_hit"),
		"get_visible_conditions: bleeding visible, guaranteed_hit no %s" % str(conditions))
	Combat.clear_buffs(target_id)

	var threat: StringName = Combat.estimate_threat(&"player", target_id)
	_assert(threat in [CombatTags.THREAT_LOW, CombatTags.THREAT_MEDIUM, CombatTags.THREAT_HIGH],
		"estimate_threat devuelve un nivel válido (%s)" % str(threat))


func _sorted_canonically(candidates: Array) -> bool:
	var previous_action: String = ""
	var previous_target: String = ""
	for candidate in candidates:
		var target: String = candidate.target_ids[0] if not candidate.target_ids.is_empty() else ""
		if candidate.action_id < previous_action:
			return false
		if candidate.action_id == previous_action and target < previous_target:
			return false
		previous_action = candidate.action_id
		previous_target = target
	return true


func _signature(candidates: Array) -> Array:
	var result: Array = []
	for candidate in candidates:
		result.append("%s>%s" % [candidate.action_id, ",".join(PackedStringArray(candidate.target_ids))])
	return result


# ============================================
# D. Skills SELF de datos y huida
# ============================================

func _test_d_self_and_flee() -> void:
	print("\n--- D. SELF de datos, FLEE e INVALID_TARGET ---")
	_set_arena(TARGETS)
	var defender: String = TARGETS[0]
	var flee_id: String = TARGETS[2]
	Combat.clear_buffs(defender)

	# Defender: reduce el daño recibido sin tirada de ataque.
	var before: float = _mean_damage(ATTACKER, SKILL_LIGHT, defender, 3000)
	Resources.restore_resource(defender, "stamina")
	Skills.get_skill_instance(defender, SKILL_DEFEND).reset_cooldown()
	_executed_count = 0
	_completed.clear()
	_fire(defender, SKILL_DEFEND, "")
	_assert(Combat.has_buff(defender, "damage_reduction"), "defender aplica el buff damage_reduction")
	_assert(_executed_count == 0, "defender no hace tirada de ataque (combat_action_executed = %d)" % _executed_count)
	_assert(_completed.size() == 1 and _completed[0].get("success", false) and _completed[0].get("actor", "") == defender,
		"defender cierra la acción con combat_action_completed {success, actor}")
	var after: float = _mean_damage(ATTACKER, SKILL_LIGHT, defender, 3000)
	_assert(after < before or before <= 1.01, "el daño recibido baja con defender (%.3f → %.3f; con armadura alta queda en el mínimo 1)" % [before, after])
	Combat.clear_buffs(defender)

	# Recuperar: sube la estamina y no pasa del máximo.
	var stamina_max: float = Resources.get_resource_state(defender, "stamina").max_effective
	Resources.set_resource(defender, "stamina", 5.0)
	Skills.get_skill_instance(defender, SKILL_RECOVER).reset_cooldown()
	_fire(defender, SKILL_RECOVER, "")
	_assert(is_equal_approx(Resources.get_resource_amount(defender, "stamina"), minf(25.0, stamina_max)),
		"recuperar: 5 → %.1f (máximo %.1f)" % [Resources.get_resource_amount(defender, "stamina"), stamina_max])
	Resources.set_resource(defender, "stamina", stamina_max - 3.0)
	Skills.get_skill_instance(defender, SKILL_RECOVER).reset_cooldown()
	_fire(defender, SKILL_RECOVER, "")
	_assert(is_equal_approx(Resources.get_resource_amount(defender, "stamina"), stamina_max),
		"recuperar no pasa del máximo (%.1f de %.1f)" % [Resources.get_resource_amount(defender, "stamina"), stamina_max])

	# Huida.
	_fled_ids.clear()
	_failures.clear()
	_completed.clear()
	_fire(flee_id, SKILL_FLEE, "")
	_assert(_fled_ids == [flee_id], "FLEE emite enemy_fled una vez %s" % str(_fled_ids))
	_assert(Combat.is_fled(flee_id), "Combat marca FLED")
	_assert(Combat.get_visible_conditions(flee_id).has(CombatTags.CONDITION_FLED), "get_visible_conditions incluye fled")
	_assert(_completed.size() == 1 and _completed[0].get("fled", false), "FLEE cierra la acción con fled = true")
	_fled_ids.clear()
	_fire(flee_id, SKILL_FLEE, "")
	_assert(_fled_ids.is_empty(), "un FLED no vuelve a huir")

	var targets_fled: bool = false
	for candidate in Combat.get_candidates(PLAYER_ID):
		if flee_id in candidate.target_ids:
			targets_fled = true
	_assert(not targets_fled, "un combatiente FLED no es objetivo de ninguna candidata")
	_assert(Combat.get_candidates(flee_id).is_empty(), "un FLED no tiene candidatas")

	# INVALID_TARGET: aliado → solo fallo; enemigo → fallo + cierre con skipped.
	var stamina_before: float = Resources.get_resource_amount(PLAYER_ID, "stamina")
	_failures.clear()
	_completed.clear()
	Skills.get_skill_instance(PLAYER_ID, SKILL_LIGHT).reset_cooldown()
	_fire(PLAYER_ID, SKILL_LIGHT, flee_id)
	_assert(_failures == [[PLAYER_ID, "INVALID_TARGET"]], "atacar a un FLED → INVALID_TARGET %s" % str(_failures))
	_assert(_completed.is_empty(), "el jugador no recibe cierre: GameLoop le devuelve la selección")
	_assert(is_equal_approx(Resources.get_resource_amount(PLAYER_ID, "stamina"), stamina_before), "INVALID_TARGET no cobra coste")

	_failures.clear()
	_completed.clear()
	_fire(defender, SKILL_ENEMY_BASIC, flee_id)
	_assert(_failures == [[defender, "INVALID_TARGET"]], "un enemigo contra un objetivo caído → INVALID_TARGET")
	_assert(_completed.size() == 1 and _completed[0].get("skipped", false) and _completed[0].get("actor", "") == defender,
		"el enemigo cierra su turno con {skipped, actor}")


func _mean_damage(attacker: String, skill_id: String, target_id: String, runs: int) -> float:
	SkillRoller.set_seed(SEED)
	var instance: SkillInstance = Skills.get_skill_instance(attacker, skill_id)
	var total: float = 0.0
	Engine.print_to_stdout = false
	for i in runs:
		Resources.restore_resource(target_id, "health")
		Resources.restore_resource(attacker, "stamina")
		instance.reset_cooldown()
		_fire(attacker, skill_id, target_id)
		total += BIG_HP - Resources.get_resource_amount(target_id, "health")
	Engine.print_to_stdout = true
	SkillRoller.reset_rng()
	return total / runs


# ============================================
# E. GameLoop: retirada aplazada con corrección de índice
# ============================================

var _e_turns: Array[String] = []
var _e_fleeing: Array[String] = []
var _e_victory: bool = false

func _test_e_gameloop() -> void:
	print("\n--- E. GameLoop: el que huye se retira y el siguiente enemigo no se salta ---")
	if not RUN_GAMELOOP_TEST:
		print("(omitida: RUN_GAMELOOP_TEST = false; se valida en partida)")
		return
	# Entidades nuevas: el combate real las recorre de principio a fin.
	var enemy_ids: Array[String] = ["ia0c_f1", "ia0c_f2"]
	for enemy_id in enemy_ids:
		_register(enemy_id, TARGET_DEFINITION, [SKILL_ENEMY_BASIC, SKILL_FLEE])
	Combat.clear_buffs(PLAYER_ID)
	Resources.restore_resource(PLAYER_ID, "health")
	GameLoop.presentation_time_scale = 0.0

	EventBus.player_turn_started.connect(_e_on_player_turn)
	EventBus.enemy_turn_started.connect(_e_on_enemy_turn)
	EventBus.combat_ended.connect(_e_on_combat_ended)

	GameLoop.start_combat(enemy_ids)
	var waited: float = 0.0
	while not _e_victory and waited < 8.0:
		await get_tree().process_frame
		waited += get_process_delta_time()

	_assert(_e_victory, "el combate termina en victoria cuando el último enemigo huye")
	_assert(_e_turns.size() >= 3, "los dos enemigos actúan en la ronda 1 y el segundo vuelve en la 2: %s" % str(_e_turns))
	if _e_turns.size() >= 2:
		_assert(_e_turns[0] != _e_turns[1], "tras huir el primero, el segundo NO se salta: %s" % str(_e_turns))
	_assert(not GameLoop.turn_order.has(enemy_ids[0]) and not GameLoop.turn_order.has(enemy_ids[1]), "ningún huido queda en turn_order")

	GameLoop.presentation_time_scale = 1.0
	for enemy_id in enemy_ids:
		if Characters.has_entity(enemy_id):
			EntityLifecycle.unregister_everywhere(enemy_id)


func _e_on_player_turn() -> void:
	await get_tree().process_frame
	GameLoop.end_player_turn_from_special_action()


## Hace de EnemyAI: el primer enemigo de la ronda 1 huye, el segundo pasa; en la ronda 2
## el que queda huye.
func _e_on_enemy_turn(enemy_id: String) -> void:
	_e_turns.append(enemy_id)
	await get_tree().process_frame
	if _e_turns.size() == 2:
		EventBus.emit_signal("combat_action_completed", {"skipped": true, "actor": enemy_id})
		return
	_e_fleeing.append(enemy_id)
	EventBus.emit_signal("combat_action_requested", {
		"actor": enemy_id,
		"skill_id": SKILL_FLEE,
		"target": "",
		"request_id": Combat.next_request_id(),
	})


func _e_on_combat_ended(result: String) -> void:
	_e_victory = (result == "victory")
