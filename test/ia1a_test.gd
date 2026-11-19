extends Node

## IA-1a — Prueba de contratos puros de la IA de combate: BehaviorProfile y su validación,
## BehaviorProfileRegistry, perfiles y threat_hint de los .tres, CombatAIState/Context, RNG
## de IA, snapshot congelado en profundidad y API pública nueva de Combat.
##
## Patrón del proyecto: F6 en ia1a_test.tscn, _assert(), contadores [PASS]/[FAIL] y
## get_tree().quit(código) al final (0 = todo bien) para poder lanzarla con --headless.
##
## No intenta modificar nada congelado (daría errores rojos en el Depurador): comprueba
## is_read_only() de forma recursiva. Los avisos de perfil inexistente se silencian con
## warn = false: el aviso real se ve en partida.
##
## Bloques:
##   A. Los 4 perfiles de data/ai/profiles/: carga, validez, valores y duplicado independiente
##   B. validate(): casos válidos e inválidos (preferencia, números, pesos, moral)
##   C. Registry: perfil seguro, rechazo, duplicados y carga recursiva con rechazos
##   D. CombatAIState / CombatAIContext
##   E. Datos de los .tres de personaje (behavior_profile_id, threat_hint) y resolución real
##   F. RNG de IA: reproducible, independiente, estado como texto
##   G. API pública nueva de Combat y snapshot congelado
##   H. Contrato: ningún fichero de core/ai/ usa miembros privados de otro sistema

const PLAYER_ID: String = "player"
const TEMP_DIR: String = "user://ia1a_test_profiles"

const PROFILE_IDS: Array[StringName] = [&"beast", &"bandit", &"soldier", &"coward"]

## Los cinco enemigos y Mira: perfil y threat_hint esperados (decisión 5 y 7 de IA-1).
const CHARACTERS: Array[Dictionary] = [
	{"path": "res://data/characters/enemy_base.tres", "profile": &"bandit", "hint": "low"},
	{"path": "res://data/characters/telmori/telmori_warrior_base.tres", "profile": &"soldier", "hint": "high"},
	{"path": "res://data/characters/telmori/telmori_warrior_weak.tres", "profile": &"bandit", "hint": "low"},
	{"path": "res://data/characters/telmori/telmori_wolf_base.tres", "profile": &"beast", "hint": "medium"},
	{"path": "res://data/characters/telmori/telmori_wolf_weak.tres", "profile": &"beast", "hint": "low"},
	{"path": "res://data/characters/companions/companion_mira.tres", "profile": &"soldier", "hint": ""},
]

const AI_FILES: Array[String] = [
	"res://core/ai/behavior_profile.gd",
	"res://core/ai/behavior_profile_registry.gd",
	"res://core/ai/combat_ai_state.gd",
	"res://core/ai/combat_ai_context.gd",
	"res://core/ai/combat_snapshot.gd",
]

var _passed: int = 0
var _failed: int = 0
var _created_entities: Array[String] = []


func _ready() -> void:
	_run()
	print("")
	print("==== IA-1a: %d OK · %d FALLOS ====" % [_passed, _failed])
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
	BehaviorProfileRegistry.reload()
	_test_a_profile_files()
	_test_b_validation()
	_test_c_registry()
	_test_d_state_and_context()
	_test_e_character_data()
	_test_f_rng()
	_test_g_snapshot()
	_test_h_contract()
	_cleanup()
	BehaviorProfileRegistry.reload()


func _preflight() -> bool:
	var ok: bool = true
	for autoload_name in ["Combat", "Characters", "Resources", "Skills", "GameLoop", "Party"]:
		if get_node_or_null("/root/%s" % autoload_name) == null:
			print("[PREFLIGHT] Falta el autoload %s" % autoload_name)
			ok = false
	_assert(ok, "Preflight: los autoloads necesarios existen")
	return ok


# ======================================================================
# A. Perfiles de data/ai/profiles/
# ======================================================================

func _test_a_profile_files() -> void:
	print("\n--- A. Perfiles base ---")
	var ids: Array[StringName] = BehaviorProfileRegistry.get_profile_ids()
	for profile_id in PROFILE_IDS:
		_assert(ids.has(profile_id), "El registry cargó el perfil '%s'" % String(profile_id))
		var profile: BehaviorProfile = BehaviorProfileRegistry.get_profile(profile_id)
		_assert(profile.id == profile_id, "'%s': el id cargado coincide" % String(profile_id))
		_assert(profile.validate().is_empty(), "'%s': validate() sin errores" % String(profile_id))
		print("[IA-1a] Valores cargados: %s" % profile.summary())

	var beast: BehaviorProfile = BehaviorProfileRegistry.get_profile(&"beast")
	var bandit: BehaviorProfile = BehaviorProfileRegistry.get_profile(&"bandit")
	var soldier: BehaviorProfile = BehaviorProfileRegistry.get_profile(&"soldier")
	var coward: BehaviorProfile = BehaviorProfileRegistry.get_profile(&"coward")
	_assert(beast.target_preference == &"random", "bestia: objetivo random")
	_assert(bandit.target_preference == &"weakest", "bandido: objetivo weakest")
	_assert(soldier.target_preference == &"most_dangerous", "soldado: objetivo most_dangerous")
	_assert(coward.target_preference == &"weakest", "cobarde: objetivo weakest")
	_assert(beast.morale.is_empty() and not beast.can_flee, "bestia: sin moral y sin huida")
	_assert(not bandit.morale.is_empty() and not soldier.morale.is_empty() and not coward.morale.is_empty(),
		"bandido, soldado y cobarde tienen moral")
	_assert(soldier.target_bonus > soldier.decision_flexibility,
		"soldado: target_bonus supera la flexibilidad (la preferencia decide sola)")
	_assert(beast.target_bonus < beast.decision_flexibility,
		"bestia: la flexibilidad supera el bonus (no decide sola)")
	_assert(soldier.weights.is_empty(), "los pesos están vacíos en IA-1a (son de IA-2)")

	# Duplicado independiente: tocar la copia no cambia el original ni la siguiente copia.
	var copy_a: BehaviorProfile = BehaviorProfileRegistry.get_profile(&"soldier")
	var original_bonus: float = copy_a.target_bonus
	copy_a.target_bonus = 99.0
	copy_a.weights["expected_damage"] = 5.0
	(copy_a.morale["thresholds"] as Dictionary)["broken"] = 1
	var copy_b: BehaviorProfile = BehaviorProfileRegistry.get_profile(&"soldier")
	_assert(copy_b.target_bonus == original_bonus, "duplicado: un campo escalar no se comparte")
	_assert(not copy_b.weights.has("expected_damage"), "duplicado: weights no se comparte")
	_assert(int((copy_b.morale["thresholds"] as Dictionary)["broken"]) != 1, "duplicado: un diccionario anidado de morale no se comparte")


# ======================================================================
# B. validate()
# ======================================================================

func _good_morale() -> Dictionary:
	return {
		"base": 100,
		"events": {"ally_died": 15},
		"big_hit_pct": 25,
		"shaken_modifiers": {"offensive_mult": 0.7, "defensive_mult": 1.3, "flexibility_add": 5},
		"health_tiers": [{"below": 0.5, "penalty": 20}],
		"conditions": {"outnumbered": 15},
		"thresholds": {"shaken_enter": 70, "shaken_exit": 75, "broken": 35},
	}


func _valid_profile() -> BehaviorProfile:
	var profile: BehaviorProfile = BehaviorProfile.new()
	profile.id = &"ia1a_valid"
	profile.target_preference = &"weakest"
	profile.morale = _good_morale()
	return profile


func _expect_invalid(profile: BehaviorProfile, text: String) -> void:
	var errors: Array[String] = profile.validate()
	_assert(not errors.is_empty(), "validate() rechaza: %s" % text)
	if not errors.is_empty():
		print("        ↳ %s" % errors[0])


func _test_b_validation() -> void:
	print("\n--- B. validate() ---")
	_assert(_valid_profile().validate().is_empty(), "un perfil correcto no da errores")

	var no_morale: BehaviorProfile = _valid_profile()
	no_morale.morale = {}
	_assert(no_morale.validate().is_empty(), "un perfil sin moral es válido")

	var with_reserved: BehaviorProfile = _valid_profile()
	with_reserved.weights = {"expected_damage": 10, &"self_risk": -8.0, "ally_in_danger": 0.0}
	_assert(with_reserved.validate().is_empty(), "pesos con claves conocidas (String o StringName, y la reservada) son válidos")

	var p: BehaviorProfile = _valid_profile()
	p.id = &""
	_expect_invalid(p, "id vacío")

	p = _valid_profile()
	p.target_preference = &"strongest"
	_expect_invalid(p, "target_preference fuera del conjunto cerrado")

	p = _valid_profile()
	p.decision_flexibility = -1.0
	_expect_invalid(p, "decision_flexibility negativa")

	p = _valid_profile()
	p.target_bonus = -0.5
	_expect_invalid(p, "target_bonus negativo")

	p = _valid_profile()
	p.survival_threshold = 1.5
	_expect_invalid(p, "survival_threshold > 1")

	p = _valid_profile()
	p.obedience = NAN
	_expect_invalid(p, "obedience NaN")

	p = _valid_profile()
	p.weights = {"expected_damage": 10.0, "daño_magico": 3.0}
	_expect_invalid(p, "peso de una consideración desconocida")

	p = _valid_profile()
	p.weights = {"expected_damage": "alto"}
	_expect_invalid(p, "peso no numérico")

	p = _valid_profile()
	(p.morale["thresholds"] as Dictionary)["broken"] = 70
	_expect_invalid(p, "broken == shaken_enter")

	p = _valid_profile()
	(p.morale["thresholds"] as Dictionary)["shaken_enter"] = 80
	_expect_invalid(p, "shaken_enter > shaken_exit")

	p = _valid_profile()
	(p.morale["thresholds"] as Dictionary)["shaken_exit"] = 120
	_expect_invalid(p, "shaken_exit por encima de morale.base")

	p = _valid_profile()
	(p.morale["thresholds"] as Dictionary).erase("broken")
	_expect_invalid(p, "falta morale.thresholds.broken")

	p = _valid_profile()
	p.morale.erase("thresholds")
	_expect_invalid(p, "falta morale.thresholds")

	p = _valid_profile()
	p.morale["umbrales"] = {}
	_expect_invalid(p, "clave desconocida en morale")

	p = _valid_profile()
	p.morale["big_hit_pct"] = 0
	_expect_invalid(p, "big_hit_pct = 0")

	p = _valid_profile()
	p.morale["health_tiers"] = [{"below": 0.5}]
	_expect_invalid(p, "tramo de salud sin penalty")

	p = _valid_profile()
	(p.morale["events"] as Dictionary)["traicion"] = 5
	_expect_invalid(p, "evento de moral desconocido")

	var safe: BehaviorProfile = BehaviorProfile.make_safe_default()
	_assert(safe.validate().is_empty(), "el perfil seguro por defecto es válido")
	_assert(safe.id == BehaviorProfile.SAFE_DEFAULT_ID and safe.target_preference == &"none" and not safe.can_flee,
		"el perfil seguro: preferencia none, sin huida")


# ======================================================================
# C. Registry
# ======================================================================

func _test_c_registry() -> void:
	print("\n--- C. Registry ---")
	var missing: BehaviorProfile = BehaviorProfileRegistry.get_profile(&"ia1a_no_existe", false)
	_assert(missing.id == BehaviorProfile.SAFE_DEFAULT_ID, "id inexistente → perfil seguro")
	var empty: BehaviorProfile = BehaviorProfileRegistry.get_profile(&"", false)
	_assert(empty.id == BehaviorProfile.SAFE_DEFAULT_ID, "id vacío → perfil seguro")
	_assert(not BehaviorProfileRegistry.has_profile(&"ia1a_no_existe"), "has_profile() es falso para un id inexistente")

	var bad: BehaviorProfile = _valid_profile()
	bad.id = &"ia1a_bad_mem"
	(bad.morale["thresholds"] as Dictionary)["broken"] = 90
	var bad_errors: Array[String] = BehaviorProfileRegistry.try_register(bad)
	_assert(not bad_errors.is_empty() and not BehaviorProfileRegistry.has_profile(&"ia1a_bad_mem"),
		"un perfil con umbrales inválidos se rechaza y no entra en la caché")

	var good: BehaviorProfile = _valid_profile()
	good.id = &"ia1a_good_mem"
	_assert(BehaviorProfileRegistry.try_register(good).is_empty() and BehaviorProfileRegistry.has_profile(&"ia1a_good_mem"),
		"un perfil válido se registra")
	var again: BehaviorProfile = _valid_profile()
	again.id = &"ia1a_good_mem"
	_assert(not BehaviorProfileRegistry.try_register(again).is_empty(), "un id duplicado se rechaza")
	var delivered: BehaviorProfile = BehaviorProfileRegistry.get_profile(&"ia1a_good_mem")
	_assert(delivered != good, "get_profile() entrega una copia, no el original registrado")

	# Carga recursiva con rechazos, a través del cargador real.
	_make_temp_profiles()
	var report: Dictionary = BehaviorProfileRegistry.load_directory(TEMP_DIR, false)
	var loaded: Array = report["loaded"]
	var rejected: Dictionary = report["rejected"]
	_assert(loaded.has(&"ia1a_nested"), "la carga recorre las subcarpetas (ia1a_nested está en sub/)")
	_assert(rejected.size() == 2, "se rechazan 2 ficheros (umbrales inválidos e id distinto del nombre): %d" % rejected.size())
	_assert(BehaviorProfileRegistry.has_profile(&"ia1a_nested"), "el perfil anidado queda registrado")
	_assert(not BehaviorProfileRegistry.has_profile(&"ia1a_file_bad"), "el perfil de umbrales inválidos no queda registrado")
	_assert(not BehaviorProfileRegistry.has_profile(&"ia1a_other_id"), "el perfil con id distinto del fichero no queda registrado")
	_remove_dir_recursive(TEMP_DIR)
	BehaviorProfileRegistry.reload()


func _make_temp_profiles() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_DIR + "/sub"))

	var nested: BehaviorProfile = _valid_profile()
	nested.id = &"ia1a_nested"
	_assert(ResourceSaver.save(nested, TEMP_DIR + "/sub/ia1a_nested.tres") == OK, "prueba: guardado de ia1a_nested.tres")

	var file_bad: BehaviorProfile = _valid_profile()
	file_bad.id = &"ia1a_file_bad"
	(file_bad.morale["thresholds"] as Dictionary)["broken"] = 90
	_assert(ResourceSaver.save(file_bad, TEMP_DIR + "/ia1a_file_bad.tres") == OK, "prueba: guardado de ia1a_file_bad.tres")

	var mismatch: BehaviorProfile = _valid_profile()
	mismatch.id = &"ia1a_other_id"
	_assert(ResourceSaver.save(mismatch, TEMP_DIR + "/ia1a_mismatch.tres") == OK, "prueba: guardado de ia1a_mismatch.tres")


func _remove_dir_recursive(dir_path: String) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub_dir in dir.get_directories():
		_remove_dir_recursive(dir_path.path_join(sub_dir))
	for file_name in dir.get_files():
		DirAccess.remove_absolute(dir_path.path_join(file_name))
	DirAccess.remove_absolute(dir_path)


# ======================================================================
# D. CombatAIState / CombatAIContext
# ======================================================================

func _test_d_state_and_context() -> void:
	print("\n--- D. Estado y contexto de IA ---")
	var context: CombatAIContext = CombatAIContext.new()
	context.set_seed(123)

	var state: CombatAIState = context.register("ia1a_e1", &"beast")
	_assert(state.profile.id == &"beast" and not state.used_fallback, "register(): perfil pedido aplicado")
	_assert(context.register("ia1a_e1", &"soldier") == state, "register() es idempotente: devuelve el estado existente")
	_assert(state.active_order == &"" and state.processed_morale_events.is_empty() and state.morale_state == CombatAIState.MORALE_STEADY,
		"campos reservados (orden, eventos de moral, estado de moral) con su valor inicial")

	state.profile.target_bonus = 77.0
	var other: CombatAIState = context.register("ia1a_e2", &"beast")
	_assert(other.profile.target_bonus != 77.0, "dos combatientes con el mismo perfil no comparten el duplicado")
	_assert(BehaviorProfileRegistry.get_profile(&"beast").target_bonus != 77.0, "modificar el perfil de un estado no toca el registry")

	var fallback: CombatAIState = context.register("ia1a_e3", &"ia1a_perfil_que_no_existe", false)
	_assert(fallback.used_fallback and fallback.profile.id == BehaviorProfile.SAFE_DEFAULT_ID,
		"perfil inexistente → perfil seguro con used_fallback")

	_assert(",".join(context.get_state_ids()) == "ia1a_e1,ia1a_e2,ia1a_e3", "get_state_ids() ordenados")
	_assert(context.get_state("ia1a_zzz") == null and not context.has_state("ia1a_zzz"), "un id sin estado devuelve null")
	_assert(state.describe().contains("ia1a_e1") and state.describe().contains("beast"), "describe() nombra al combatiente y su perfil")
	context.release()
	_assert(context.size() == 0, "release() suelta todos los estados")


# ======================================================================
# E. Datos de personajes
# ======================================================================

func _test_e_character_data() -> void:
	print("\n--- E. Datos de los .tres de personaje ---")
	for entry in CHARACTERS:
		var path: String = entry["path"]
		var definition: CharacterDefinition = load(path) as CharacterDefinition
		_assert(definition != null, "carga %s" % path.get_file())
		if definition == null:
			continue
		print("[IA-1a] Definición cargada: %s (behavior_profile_id=%s, threat_hint=%s)" % [
			String(definition.id), String(definition.behavior_profile_id), definition.threat_hint])
		_assert(definition.behavior_profile_id == entry["profile"], "%s: behavior_profile_id = %s" % [String(definition.id), String(entry["profile"])])
		_assert(BehaviorProfileRegistry.has_profile(definition.behavior_profile_id), "%s: su perfil existe en el registry" % String(definition.id))
		_assert(definition.threat_hint == entry["hint"], "%s: threat_hint = '%s'" % [String(definition.id), String(entry["hint"])])
		_assert(definition.validate(), "%s: validate() de la definición" % String(definition.id))

	# Resolución real a través de Characters.
	_register_character("ia1a_wolf", "telmori_wolf_base")
	_register_character("ia1a_warrior", "telmori_warrior_base")
	_assert(CombatAIContext.resolve_profile_id("ia1a_wolf") == &"beast", "resolve_profile_id: lobo → beast")
	_assert(CombatAIContext.resolve_profile_id("ia1a_warrior") == &"soldier", "resolve_profile_id: guerrero → soldier")
	_assert(CombatAIContext.resolve_profile_id("ia1a_no_registrado") == &"", "resolve_profile_id: entidad no registrada → vacío")
	var context: CombatAIContext = CombatAIContext.new()
	var wolf_state: CombatAIState = context.register_entity("ia1a_wolf")
	_assert(wolf_state.profile.id == &"beast", "register_entity(): perfil desde la definición del combatiente")


func _register_character(entity_id: String, definition_id: String) -> bool:
	if not Characters.has_definition(definition_id):
		_assert(false, "existe la definición %s" % definition_id)
		return false
	if not Characters.has_entity(entity_id):
		Characters.register_entity(entity_id, definition_id)
		_created_entities.append(entity_id)
	if not Resources.has_entity(entity_id):
		Resources.register_entity(entity_id)
	return true


# ======================================================================
# F. RNG de IA
# ======================================================================

func _test_f_rng() -> void:
	print("\n--- F. RNG de IA ---")
	var a: CombatAIContext = CombatAIContext.new()
	var b: CombatAIContext = CombatAIContext.new()
	a.set_seed(42)
	b.set_seed(42)
	var seq_a: Array[int] = []
	var seq_b: Array[int] = []
	for i in 6:
		seq_a.append(a.roll_int(0, 1000))
		randf()   # el RNG global no debe influir en el de la IA
		seq_b.append(b.roll_int(0, 1000))
	_assert(seq_a == seq_b, "misma semilla → misma secuencia, aunque se use el RNG global entre medias")

	var c: CombatAIContext = CombatAIContext.new()
	c.set_seed(43)
	var seq_c: Array[int] = []
	for i in 6:
		seq_c.append(c.roll_int(0, 1000))
	_assert(seq_c != seq_a, "otra semilla → otra secuencia")

	var d: CombatAIContext = CombatAIContext.new()
	d.set_seed(7)
	for i in 3:
		d.roll_int(0, 10000)
	var saved_state: String = d.rng_state_string()
	var expected_next: int = d.roll_int(0, 10000)
	_assert(saved_state.is_valid_int(), "el estado del RNG se expone como texto de entero: %s" % saved_state)
	var e: CombatAIContext = CombatAIContext.new()
	e.set_seed(1)
	_assert(e.restore_rng_state(saved_state), "restore_rng_state() acepta el texto guardado")
	_assert(e.roll_int(0, 10000) == expected_next, "reanudar desde el estado guardado continúa la misma secuencia")
	_assert(not e.restore_rng_state("no es un numero"), "restore_rng_state() rechaza un texto inválido")
	_assert(d.rng_seed_string() == "7", "rng_seed_string() devuelve la semilla fijada")

	var default_context: CombatAIContext = CombatAIContext.new()
	_assert(default_context.seed_value == default_context.rng.seed, "sin semilla fijada, seed_value refleja la semilla aleatoria")

	var f: CombatAIContext = CombatAIContext.new()
	f.set_seed(5)
	var before: String = f.rng_state_string()
	_assert(f.pick_one([]) == null, "pick_one() de una lista vacía → null")
	_assert(f.pick_one(["solo"]) == "solo" and f.rng_state_string() == before, "pick_one() con una sola opción no consume el RNG")
	var options: Array = ["a", "b", "c", "d"]
	var g: CombatAIContext = CombatAIContext.new()
	var h: CombatAIContext = CombatAIContext.new()
	g.set_seed(9)
	h.set_seed(9)
	var picks_g: Array = []
	var picks_h: Array = []
	for i in 8:
		picks_g.append(g.pick_one(options))
		picks_h.append(h.pick_one(options))
	_assert(picks_g == picks_h and options.has(picks_g[0]), "pick_one() es reproducible con la misma semilla")


# ======================================================================
# G. API pública de Combat y snapshot
# ======================================================================

func _test_g_snapshot() -> void:
	print("\n--- G. Combat.get_side / get_combatant_ids y snapshot ---")
	var created_player: bool = false
	if not Characters.has_entity(PLAYER_ID) and Characters.has_definition("player_base"):
		Characters.register_entity(PLAYER_ID, "player_base")
		created_player = true
	if Characters.has_entity(PLAYER_ID) and not Resources.has_entity(PLAYER_ID):
		Resources.register_entity(PLAYER_ID)
	if not Characters.has_entity(PLAYER_ID) or not Resources.has_entity(PLAYER_ID):
		print("[SKIP] No se pudo preparar al protagonista: se omite el bloque G")
		return

	_register_character("ia1a_wolf", "telmori_wolf_base")
	_register_character("ia1a_warrior", "telmori_warrior_base")
	for enemy_id in ["ia1a_wolf", "ia1a_warrior"]:
		if not Skills.has_entity(enemy_id):
			var definition: CharacterDefinition = Characters.get_character_definition(enemy_id)
			Skills.register_entity_skills(enemy_id, definition.skills.duplicate())

	_assert(Combat.get_side(PLAYER_ID) == CombatTags.SIDE_ALLY, "get_side(player) = ally")
	_assert(Combat.get_side("ia1a_wolf") == CombatTags.SIDE_ENEMY, "get_side(enemigo) = enemy")
	_assert(Combat.get_combatant_ids(CombatTags.SIDE_ALLY).has(PLAYER_ID), "get_combatant_ids(ally) incluye al protagonista")

	var snapshot: Dictionary = CombatSnapshot.build("ia1a_wolf")
	for key in ["schema_version", "actor_id", "side", "self", "player", "allies", "opponents", "candidates"]:
		_assert(snapshot.has(key), "el snapshot tiene la clave '%s'" % key)
	_assert(snapshot["actor_id"] == "ia1a_wolf" and snapshot["side"] == CombatTags.SIDE_ENEMY, "actor y bando del snapshot")

	var self_block: Dictionary = snapshot["self"]
	_assert(self_block["id"] == "ia1a_wolf", "self.id")
	_assert(self_block["hp_state"] == CombatTags.HP_HEALTHY and is_equal_approx(float(self_block["hp_ratio"]), 1.0), "self: salud llena = healthy, ratio 1.0")
	var own_resources: Dictionary = self_block["resources"]
	_assert(own_resources.has("health") and float(own_resources["health"]) > 0.0, "self.resources.health exacto y > 0")
	_assert(own_resources.has("stamina") and float(own_resources["stamina"]) > 0.0, "self.resources.stamina exacto y > 0")
	_assert(self_block["last_attacker_id"] is String, "self.last_attacker_id es un String ('' si nadie ha dañado aún)")
	_assert((snapshot["player"] as Dictionary)["last_attacker_id"] is String, "player.last_attacker_id está presente")

	var opponents: Array = snapshot["opponents"]
	var player_entry: Dictionary = _find_entry(opponents, PLAYER_ID)
	_assert(not player_entry.is_empty(), "el protagonista aparece entre los oponentes del lobo")
	_assert(player_entry.get("threat", &"") in [CombatTags.THREAT_LOW, CombatTags.THREAT_MEDIUM, CombatTags.THREAT_HIGH],
		"oponente: amenaza aparente con el vocabulario de CombatTags")
	_assert(player_entry.get("targetable", false) == true, "oponente vivo: targetable")
	_assert(not player_entry.has("last_attacker_id") and not player_entry.has("resources"),
		"de los demás solo se ve lo aparente (sin recursos ni último atacante)")
	_assert(_find_entry(snapshot["allies"], "ia1a_wolf").is_empty(), "el propio actor no aparece entre sus aliados")

	var candidates: Array = snapshot["candidates"]
	_assert(candidates.size() > 0, "el snapshot lleva las candidatas de Combat (%d)" % candidates.size())
	var has_basic: bool = false
	for candidate in candidates:
		if (candidate as Dictionary).get("action_id", "") == "skill.enemy.basic_attack":
			has_basic = true
	_assert(has_basic, "entre las candidatas está basic_attack")

	_assert(CombatSnapshot.is_plain_data(snapshot), "el snapshot solo contiene tipos simples")
	_assert(CombatSnapshot.is_deep_frozen(snapshot), "el snapshot está congelado en profundidad")
	_assert((snapshot["opponents"] as Array).is_read_only() and (snapshot["self"] as Dictionary).is_read_only(),
		"los contenedores de primer nivel están congelados")
	if not candidates.is_empty():
		_assert((candidates[0] as Dictionary).is_read_only() and ((candidates[0] as Dictionary)["tags"] as Array).is_read_only(),
			"una candidata y sus listas internas están congeladas")

	var again: Dictionary = CombatSnapshot.build("ia1a_wolf")
	_assert(again.hash() == snapshot.hash(), "mismo estado de combate → mismo snapshot")

	var ghost: Dictionary = CombatSnapshot.build("ia1a_fantasma")
	_assert(CombatSnapshot.is_deep_frozen(ghost) and (ghost["candidates"] as Array).is_empty(),
		"un actor sin registrar da un snapshot válido, congelado y sin candidatas")

	# Sin deep_freeze, make_read_only() sería superficial: esta prueba fija por qué existe.
	var shallow: Dictionary = {"inner": {"x": 1}}
	shallow.make_read_only()
	_assert(not CombatSnapshot.is_deep_frozen(shallow), "is_deep_frozen() detecta un congelado solo superficial")

	if created_player:
		EntityLifecycle.unregister_everywhere(PLAYER_ID)


func _find_entry(entries: Array, entity_id: String) -> Dictionary:
	for entry in entries:
		if (entry as Dictionary).get("id", "") == entity_id:
			return entry
	return {}


# ======================================================================
# H. Contrato
# ======================================================================

func _test_h_contract() -> void:
	print("\n--- H. Contrato: sin miembros privados de otros sistemas ---")
	var regex: RegEx = RegEx.new()
	regex.compile("\\b(Combat|GameLoop|Party|Resources|Characters|Skills)\\._[A-Za-z]")
	for path in AI_FILES:
		var source: String = FileAccess.get_file_as_string(path)
		_assert(not source.is_empty(), "se lee %s" % path.get_file())
		_assert(regex.search(source) == null, "%s no accede a miembros privados de otros sistemas" % path.get_file())


# ======================================================================
# Limpieza
# ======================================================================

func _cleanup() -> void:
	for entity_id in _created_entities:
		EntityLifecycle.unregister_everywhere(entity_id)
	_created_entities.clear()
