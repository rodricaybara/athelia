extends Node

## test/test_spike6_investigacion.gd
##
## Valida, SIN combate real, el mecanismo central de dos de los parches
## de Spike 6:
##
##   A) ResourceSystem.register_entity() sincroniza max_effective vía
##      AttributeResolver para una entidad no-player (Punto 1, Opción B).
##      Registra una entidad de prueba ("enemy_base"), pide su
##      ResourceState y comprueba que max_effective coincide con el
##      máximo derivado real — no con el genérico de la definición ni
##      con el 50.0 fijo del bug original.
##
##   B) GameLoopSystem._transition_to_phase() rechaza una transición
##      inválida devolviendo false y SIN mover current_phase. Reproduce
##      exactamente la secuencia del log real: ENEMY_ACTION_RESOLVE →
##      TURN_END → ROUND_END → (segundo intento) TURN_END, que antes del
##      parche era donde se disparaba el "Invalid transition: ROUND_END →
##      TURN_END" y, sin guard, dejaba que _end_turn()/_end_round()
##      siguieran igual, duplicando round_ended y round_number.
##
## Deliberadamente NO llama a _end_turn()/_end_round()/_start_new_round()
## completos — encadenarían a _start_player_turn() y tocarían sistemas
## que esperan un combate real activo (PlayerCombatController, etc.).
## Ejercita _transition_to_phase() directamente, que es donde vive el fix,
## y restaura current_phase al valor que tenía antes de correr el test.
##
## Ejecutar: escena suelta con este script en la raíz, F6. Requiere que
## los autoloads (Characters, Resources, AttributeResolver, GameLoop)
## estén cargados — cualquier escena del proyecto los tiene disponibles,
## no hace falta estar en combate ni en ningún GameState concreto.

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("[TestSpike6] Iniciando validación de parches...")
	print("=".repeat(60))

	_test_resource_max_sync()
	_test_phase_guard()

	print("=".repeat(60))
	print("[TestSpike6] Resultado: %d/%d asserts pasados" % [_passed, _passed + _failed])
	print("=".repeat(60))


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
		print("  ✅ %s" % description)
	else:
		_failed += 1
		print("  ❌ %s" % description)


# ============================================
# A) Punto 1 — sincronización de max_effective
# ============================================

func _test_resource_max_sync() -> void:
	print("\n--- A) ResourceSystem.register_entity() sincroniza max_effective ---")

	const TEST_ID := "test_spike6_dummy"

	# Limpieza defensiva por si quedó algo de una ejecución anterior interrumpida
	if Resources.has_entity(TEST_ID):
		Resources.unregister_entity(TEST_ID)
	if Characters.has_entity(TEST_ID) and Characters.has_method("unregister_entity"):
		Characters.unregister_entity(TEST_ID)

	if not Characters.has_definition("enemy_base"):
		print("  ⚠️  'enemy_base' no encontrado en este proyecto — test A omitido (no es un fallo del parche)")
		return

	# Orden correcto: Characters ANTES que Resources — el que exige el parche
	Characters.register_entity(TEST_ID, "enemy_base")
	Resources.register_entity(TEST_ID, ["health"])

	var state := Resources.get_resource_state(TEST_ID, "health")
	var expected_max: float = AttributeResolver.resolve_resource_max(TEST_ID, "health")

	_check(state != null, "ResourceState creado para '%s'" % TEST_ID)
	if state:
		_check(
			is_equal_approx(state.max_effective, expected_max),
			"max_effective (%.1f) == máximo derivado real (%.1f) — antes se habría quedado en el genérico de ResourceDefinition.max_base" % [state.max_effective, expected_max]
		)

	# Limpieza — no dejar el dummy registrado en los autoloads
	Resources.unregister_entity(TEST_ID)
	if Characters.has_method("unregister_entity"):
		Characters.unregister_entity(TEST_ID)


# ============================================
# B) Punto 2 — guard de transición de fase
# ============================================

func _test_phase_guard() -> void:
	print("\n--- B) GameLoopSystem._transition_to_phase() rechaza transición inválida sin romper estado ---")

	var original_phase = GameLoop.current_phase

	# Preparar el escenario exacto del log: fase actual ENEMY_ACTION_RESOLVE
	GameLoop.current_phase = GameLoop.TurnPhase.ENEMY_ACTION_RESOLVE

	var ok1: bool = GameLoop._transition_to_phase(GameLoop.TurnPhase.TURN_END)
	_check(ok1 == true, "ENEMY_ACTION_RESOLVE → TURN_END (transición legítima) devuelve true")
	_check(GameLoop.current_phase == GameLoop.TurnPhase.TURN_END, "current_phase avanza a TURN_END")

	var ok2: bool = GameLoop._transition_to_phase(GameLoop.TurnPhase.ROUND_END)
	_check(ok2 == true, "TURN_END → ROUND_END (transición legítima) devuelve true")
	_check(GameLoop.current_phase == GameLoop.TurnPhase.ROUND_END, "current_phase avanza a ROUND_END")

	# Aquí es exactamente donde el log real mostraba el error: una segunda
	# llamada a _end_turn() con la fase ya en ROUND_END (mientras la
	# primera aún esperaba su timer de 0.3s). Se simula el mismo intento
	# directamente sobre _transition_to_phase().
	var ok3: bool = GameLoop._transition_to_phase(GameLoop.TurnPhase.TURN_END)
	_check(ok3 == false, "ROUND_END → TURN_END (la transición inválida del log real) devuelve false")
	_check(
		GameLoop.current_phase == GameLoop.TurnPhase.ROUND_END,
		"current_phase NO cambia tras el intento rechazado — antes de este parche, _end_turn()/_end_round() seguían igual y duplicaban round_ended/round_number pese al error"
	)

	# Restaurar el estado original — este test no debe dejar el singleton
	# en una fase distinta a la que tenía antes de correr.
	GameLoop.current_phase = original_phase
