extends Node

## test_narrative_scene_viewmodel.gd — Spike 3, Grupo A
##
## Test aislado de NarrativeSceneViewModel y NarrativeSceneOption. No depende
## de NarrativeSceneDB ni de ningún JSON de autoría — todos los fixtures
## (NarrativeSceneDefinition/Option/Outcome) se construyen en código con
## new() + asignación de campos, mismo patrón que
## test_character_creation_viewmodel.gd.
##
## Dos decisiones que se apartan de ese patrón, explicadas porque no son
## triviales:
##
## 1. Los outcomes de los fixtures usan siempre next_scene_id = "" (la
##    escena se cierra al resolver, nunca encadena a otro scene_id). Ir a
##    otro nodo pasaría por NarrativeSceneDB.get_scene() dentro de
##    _apply_outcome() — probar eso sería un test del registry, no del
##    ViewModel. Por la misma razón, current_node/state se asignan
##    directamente en vez de llamar a open(scene_id) (que sí usa la DB).
##
## 2. _test_racha_* llaman directamente a _handle_accumulative_roll()
##    (privado por convención, no por el lenguaje) con un Dictionary de
##    tirada construido a mano. SkillRoller.roll_skill() no tiene ningún
##    parámetro para forzar un grado — es aleatorio — así que no hay forma
##    determinista de probar el contador de racha (3 éxitos seguidos, un
##    fallo que lo reinicia, una pifia que ignora retry_policy) pasando por
##    request_option() sin depender de la suerte del D100. Mismo espíritu
##    que las secciones ya señaladas y opcionales de
##    test_character_creation_viewmodel.gd, aplicado aquí porque el origen
##    del problema es el mismo: una dependencia externa no determinista.
##
## Ningún fixture usa flag_to_set ni combat_enemy_ids — mantiene el test
## desacoplado de Narrative/GameLoop, ninguno de los dos necesario para
## validar la máquina de estados del ViewModel en sí.
##
## Uso: adjuntar este script a un Node en una escena vacía y correrla (F6).

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	print("\n" + "=".repeat(50))
	print("TEST — NarrativeSceneViewModel")
	print("=".repeat(50))

	_test_outcome_default_sin_skill_id()
	_test_request_option_ignorado_fuera_de_showing()
	_test_get_outcome_for_grade_fallback()
	_test_get_outcome_for_grade_sin_fallback()
	_test_racha_immediate_se_reinicia_y_completa()
	_test_racha_blocked_transiciona_en_fallo()
	_test_racha_pifia_siempre_transiciona()

	print("=".repeat(50))
	print("RESULTADO: %d/%d tests pasados" % [_passed, _passed + _failed])
	print("=".repeat(50))


# ============================================
# HELPERS
# ============================================

func _new_vm() -> NarrativeSceneViewModel:
	var vm := NarrativeSceneViewModel.new()
	add_child(vm)
	return vm


func _assert(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] %s" % description)
	else:
		_failed += 1
		print("  [FAIL] %s" % description)


func _make_outcome(next_scene_id: String = "") -> NarrativeSceneOutcome:
	var o := NarrativeSceneOutcome.new()
	o.next_scene_id = next_scene_id
	return o


func _make_scene(scene_id: String, options: Array[NarrativeSceneOption]) -> NarrativeSceneDefinition:
	var s := NarrativeSceneDefinition.new()
	s.scene_id = scene_id
	s.text_key = "TEST_FIXTURE_TEXT"
	s.options = options
	return s


## Dictionary mínimo con la forma que _handle_accumulative_roll() lee de un
## roll de SkillRoller.roll_skill() real — solo "result" y "success".
func _make_mock_roll(result: SkillRoller.RollResult) -> Dictionary:
	var is_success: bool = result in [
		SkillRoller.RollResult.SUCCESS,
		SkillRoller.RollResult.SPECIAL,
		SkillRoller.RollResult.CRITICAL
	]
	return {"result": result, "success": is_success}


# ============================================
# TESTS — resolución sin skill_id (outcome_default)
# ============================================

func _test_outcome_default_sin_skill_id() -> void:
	print("\n-- outcome_default sin skill_id --")
	var vm := _new_vm()
	var opt := NarrativeSceneOption.new()
	opt.option_id = "continue"
	opt.text_key = "TEST_FIXTURE_CONTINUE"
	opt.outcome_default = _make_outcome()  # next_scene_id vacío → cierra

	vm.current_node = _make_scene("fixture_default", [opt])
	vm.state = NarrativeSceneViewModel.PanelState.SHOWING

	var closed_received: Array[bool] = [false]
	vm.changed.connect(func(reason):
		if reason == "closed":
			closed_received[0] = true
	)

	vm.request_option("continue")

	_assert(closed_received[0], "changed('closed') emitido al resolver outcome_default")
	_assert(vm.state == NarrativeSceneViewModel.PanelState.HIDDEN, "Estado pasa a HIDDEN")
	_assert(vm.current_node == null, "current_node se limpia al cerrar")

	vm.queue_free()


func _test_request_option_ignorado_fuera_de_showing() -> void:
	print("\n-- request_option() con state != SHOWING --")
	var vm := _new_vm()
	var opt := NarrativeSceneOption.new()
	opt.option_id = "continue"
	opt.outcome_default = _make_outcome()

	vm.current_node = _make_scene("fixture_hidden", [opt])
	vm.state = NarrativeSceneViewModel.PanelState.HIDDEN  # nunca se abrió

	vm.request_option("continue")

	_assert(vm.state == NarrativeSceneViewModel.PanelState.HIDDEN, "Estado no cambia si no está SHOWING")
	_assert(vm.current_node != null, "current_node no se toca si el guard bloquea la llamada")

	vm.queue_free()


# ============================================
# TESTS — get_outcome_for_grade() y su fallback
# ============================================

func _test_get_outcome_for_grade_fallback() -> void:
	print("\n-- get_outcome_for_grade() con fumble/special/critical SIN definir --")
	var opt := NarrativeSceneOption.new()
	opt.option_id = "roll_opt"
	var out_failure := _make_outcome()
	var out_success := _make_outcome()
	opt.outcome_failure = out_failure
	opt.outcome_success = out_success
	# outcome_fumble / outcome_special / outcome_critical se dejan null a propósito

	_assert(
		opt.get_outcome_for_grade(SkillRoller.RollResult.FUMBLE) == out_failure,
		"FUMBLE sin definir cae a FAILURE"
	)
	_assert(
		opt.get_outcome_for_grade(SkillRoller.RollResult.FAILURE) == out_failure,
		"FAILURE devuelve outcome_failure"
	)
	_assert(
		opt.get_outcome_for_grade(SkillRoller.RollResult.SUCCESS) == out_success,
		"SUCCESS devuelve outcome_success"
	)
	_assert(
		opt.get_outcome_for_grade(SkillRoller.RollResult.SPECIAL) == out_success,
		"SPECIAL sin definir cae a SUCCESS"
	)
	_assert(
		opt.get_outcome_for_grade(SkillRoller.RollResult.CRITICAL) == out_success,
		"CRITICAL sin definir cae a SUCCESS"
	)


func _test_get_outcome_for_grade_sin_fallback() -> void:
	print("\n-- get_outcome_for_grade() con los 5 grados definidos --")
	var opt := NarrativeSceneOption.new()
	opt.option_id = "roll_opt_full"
	var out_fumble := _make_outcome()
	var out_failure := _make_outcome()
	var out_success := _make_outcome()
	var out_special := _make_outcome()
	var out_critical := _make_outcome()
	opt.outcome_fumble = out_fumble
	opt.outcome_failure = out_failure
	opt.outcome_success = out_success
	opt.outcome_special = out_special
	opt.outcome_critical = out_critical

	_assert(opt.get_outcome_for_grade(SkillRoller.RollResult.FUMBLE) == out_fumble, "FUMBLE definido no usa fallback")
	_assert(opt.get_outcome_for_grade(SkillRoller.RollResult.SPECIAL) == out_special, "SPECIAL definido no usa fallback")
	_assert(opt.get_outcome_for_grade(SkillRoller.RollResult.CRITICAL) == out_critical, "CRITICAL definido no usa fallback")


# ============================================
# TESTS — tiradas acumulativas (contador de racha)
# ============================================

func _test_racha_immediate_se_reinicia_y_completa() -> void:
	print("\n-- required_successes=3, retry_policy=immediate --")
	var vm := _new_vm()
	var opt := NarrativeSceneOption.new()
	opt.option_id = "track"
	opt.skill_id = "skill.exploration.perception"
	opt.required_successes = 3
	opt.retry_policy = "immediate"
	opt.outcome_failure = _make_outcome()
	opt.outcome_success = _make_outcome()

	vm.current_node = _make_scene("fixture_streak", [opt])
	vm.state = NarrativeSceneViewModel.PanelState.SHOWING

	var last_reason: Array[String] = [""]
	vm.changed.connect(func(reason): last_reason[0] = reason)

	vm._handle_accumulative_roll(opt, _make_mock_roll(SkillRoller.RollResult.SUCCESS))
	_assert(vm.streak_current == 1 and last_reason[0] == "streak_progress", "1er éxito: streak_current=1, streak_progress")

	vm._handle_accumulative_roll(opt, _make_mock_roll(SkillRoller.RollResult.SUCCESS))
	_assert(vm.streak_current == 2, "2º éxito: streak_current=2")
	_assert(vm.state == NarrativeSceneViewModel.PanelState.SHOWING, "Sigue en el mismo nodo (SHOWING)")

	vm._handle_accumulative_roll(opt, _make_mock_roll(SkillRoller.RollResult.FAILURE))
	_assert(
		last_reason[0] == "streak_progress" and vm.streak_current == 0,
		"Fallo normal con 'immediate' reinicia el contador sin transicionar"
	)
	_assert(vm.state == NarrativeSceneViewModel.PanelState.SHOWING, "Sigue SHOWING tras el fallo immediate")

	vm._handle_accumulative_roll(opt, _make_mock_roll(SkillRoller.RollResult.SUCCESS))
	vm._handle_accumulative_roll(opt, _make_mock_roll(SkillRoller.RollResult.SUCCESS))
	vm._handle_accumulative_roll(opt, _make_mock_roll(SkillRoller.RollResult.SUCCESS))
	_assert(vm.state == NarrativeSceneViewModel.PanelState.HIDDEN, "Racha completa (3/3) aplica outcome_success y cierra")

	vm.queue_free()


func _test_racha_blocked_transiciona_en_fallo() -> void:
	print("\n-- required_successes=3, retry_policy=blocked --")
	var vm := _new_vm()
	var opt := NarrativeSceneOption.new()
	opt.option_id = "track_blocked"
	opt.skill_id = "skill.exploration.perception"
	opt.required_successes = 3
	opt.retry_policy = "blocked"
	opt.outcome_failure = _make_outcome()
	opt.outcome_success = _make_outcome()

	vm.current_node = _make_scene("fixture_streak_blocked", [opt])
	vm.state = NarrativeSceneViewModel.PanelState.SHOWING

	vm._handle_accumulative_roll(opt, _make_mock_roll(SkillRoller.RollResult.SUCCESS))
	_assert(vm.streak_current == 1, "1 éxito registrado antes del fallo")

	vm._handle_accumulative_roll(opt, _make_mock_roll(SkillRoller.RollResult.FAILURE))
	_assert(
		vm.state == NarrativeSceneViewModel.PanelState.HIDDEN,
		"Fallo normal con 'blocked' transiciona de verdad (aplica outcome_failure)"
	)

	vm.queue_free()


func _test_racha_pifia_siempre_transiciona() -> void:
	print("\n-- PIFIA ignora retry_policy incluso en 'immediate' --")
	var vm := _new_vm()
	var opt := NarrativeSceneOption.new()
	opt.option_id = "track_fumble"
	opt.skill_id = "skill.exploration.perception"
	opt.required_successes = 3
	opt.retry_policy = "immediate"
	opt.outcome_failure = _make_outcome()
	opt.outcome_success = _make_outcome()
	# outcome_fumble se deja null a propósito → fallback a outcome_failure

	vm.current_node = _make_scene("fixture_streak_fumble", [opt])
	vm.state = NarrativeSceneViewModel.PanelState.SHOWING

	vm._handle_accumulative_roll(opt, _make_mock_roll(SkillRoller.RollResult.SUCCESS))
	vm._handle_accumulative_roll(opt, _make_mock_roll(SkillRoller.RollResult.SUCCESS))
	_assert(vm.streak_current == 2, "2 éxitos registrados antes de la pifia")

	vm._handle_accumulative_roll(opt, _make_mock_roll(SkillRoller.RollResult.FUMBLE))
	_assert(
		vm.state == NarrativeSceneViewModel.PanelState.HIDDEN,
		"PIFIA transiciona ignorando retry_policy 'immediate' (fallback a outcome_failure)"
	)

	vm.queue_free()
