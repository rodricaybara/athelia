extends Node

## test_group_morale.gd — Spike 3, Grupo A
##
## Test de la base de moral dinámica en GameLoopSystem (recálculo al llegar
## un refuerzo). Reproduce exactamente los dos ejemplos numéricos confirmados
## en la spec del grupo: 500→400→refuerzo 100→base 500→umbral 200, y
## 350→refuerzo 100→base 450→umbral 180.
##
## GameLoop es un autoload real (singleton persistente) — no se puede
## instanciar aislado como NarrativeSceneViewModel. Este test manipula
## directamente su estado interno (_current_encounter, _group_morale_base_hp,
## _group_morale_base_dirty, _morale_broken, turn_order, participants) y
## llama a _check_group_morale() (privado por convención, no por el
## lenguaje) sin pasar por start_combat() — evita arrastrar cálculo de
## iniciativa, fases de turno o carga de escena de combate, que no son parte
## de lo que se está probando aquí. No usa CharacterSystem en absoluto:
## Resources.set_max_effective()/set_resource() bastan para fijar el HP
## exacto que pide cada ejemplo, sin resolver ningún atributo derivado.
##
## Como GameLoop persiste entre tests, cada test guarda su estado con
## _save_gameloop_state() al empezar y lo restaura con
## _restore_gameloop_state() al terminar — para no dejar el singleton sucio
## para el resto de la sesión.
##
## Entidades de prueba con IDs claramente ficticios (prefijo "test_") en
## ResourceSystem — se registran y desregistran en cada test, sin tocar
## ninguna entidad real.
##
## Uso: adjuntar este script a un Node en una escena vacía y correrla (F6).

var _passed: int = 0
var _failed: int = 0

# Snapshot del estado de GameLoop antes de cada test
var _saved_encounter: CombatEncounterDefinition
var _saved_base_hp: float
var _saved_dirty: bool
var _saved_broken: bool
var _saved_turn_order: Array[String]
var _saved_participants: Array[String]


func _ready() -> void:
	print("\n" + "=".repeat(50))
	print("TEST — GameLoopSystem: moral de grupo con base dinámica")
	print("=".repeat(50))

	_test_ejemplo_1_500_400_refuerzo_100()
	_test_ejemplo_2_350_refuerzo_100()
	_test_base_no_cambia_sin_refuerzo()

	print("=".repeat(50))
	print("RESULTADO: %d/%d tests pasados" % [_passed, _passed + _failed])
	print("=".repeat(50))


# ============================================
# HELPERS
# ============================================

func _assert(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] %s" % description)
	else:
		_failed += 1
		print("  [FAIL] %s" % description)


func _save_gameloop_state() -> void:
	_saved_encounter = GameLoop._current_encounter
	_saved_base_hp = GameLoop._group_morale_base_hp
	_saved_dirty = GameLoop._group_morale_base_dirty
	_saved_broken = GameLoop._morale_broken
	_saved_turn_order = GameLoop.turn_order.duplicate()
	_saved_participants = GameLoop.participants.duplicate()


func _restore_gameloop_state() -> void:
	GameLoop._current_encounter = _saved_encounter
	GameLoop._group_morale_base_hp = _saved_base_hp
	GameLoop._group_morale_base_dirty = _saved_dirty
	GameLoop._morale_broken = _saved_broken
	GameLoop.turn_order = _saved_turn_order
	GameLoop.participants = _saved_participants


func _register_test_enemy(entity_id: String, max_hp: float, current_hp: float) -> void:
	Resources.register_entity(entity_id, ["health"])
	Resources.set_max_effective(entity_id, "health", max_hp)
	Resources.set_resource(entity_id, "health", current_hp)
	GameLoop.turn_order.append(entity_id)


func _unregister_test_enemy(entity_id: String) -> void:
	Resources.unregister_entity(entity_id)


func _make_encounter(threshold_pct: float) -> CombatEncounterDefinition:
	var e := CombatEncounterDefinition.new()
	e.morale_threshold_pct = threshold_pct
	return e


# ============================================
# TESTS
# ============================================

## Ejemplo 1 de la spec: 500 → 400 → refuerzo de 100 → base 500 → umbral 200.
func _test_ejemplo_1_500_400_refuerzo_100() -> void:
	print("\n-- Ejemplo 1: 500 -> 400 -> refuerzo 100 -> base 500, umbral 200 --")
	_save_gameloop_state()

	GameLoop._current_encounter = _make_encounter(40.0)
	GameLoop._group_morale_base_hp = 500.0  # como si start_combat() lo hubiera calculado
	GameLoop._group_morale_base_dirty = false
	GameLoop._morale_broken = false
	GameLoop.turn_order = []
	GameLoop.participants = []

	_register_test_enemy("test_survivor_1", 400.0, 400.0)  # supervivientes tras una muerte previa

	# Antes del refuerzo: 400/500=80% > 40% → no huye, base no cambia
	GameLoop._check_group_morale()
	_assert(not GameLoop._morale_broken, "80% de HP no dispara la huida")
	_assert(GameLoop._group_morale_base_hp == 500.0, "Base no cambia sin refuerzo")

	# Llega el refuerzo (100 HP, fresco)
	_register_test_enemy("test_reinforcement_1", 100.0, 100.0)
	GameLoop._group_morale_base_dirty = true  # esto es lo que hace _spawn_reinforcements()

	GameLoop._check_group_morale()
	_assert(GameLoop._group_morale_base_hp == 500.0, "Base recalculada: 400 supervivientes + 100 refuerzo = 500")
	_assert(not GameLoop._morale_broken, "500/500=100% > 40% -> sigue sin huir")

	# Bajar el HP total exactamente al umbral (40% de 500 = 200)
	var fled_ids: Array = []
	var handler := func(ids): fled_ids.append(ids)
	EventBus.enemy_group_fled.connect(handler)

	Resources.set_resource("test_survivor_1", "health", 100.0)  # total = 100+100 = 200
	GameLoop._check_group_morale()

	_assert(GameLoop._morale_broken, "200/500=40% <= umbral -> huyen")
	_assert(fled_ids.size() == 1 and fled_ids[0].size() == 2, "enemy_group_fled emitido con los 2 IDs")

	EventBus.enemy_group_fled.disconnect(handler)
	_unregister_test_enemy("test_survivor_1")
	_unregister_test_enemy("test_reinforcement_1")
	_restore_gameloop_state()


## Ejemplo 2 de la spec: 350 → refuerzo de 100 → base 450 → umbral 180.
func _test_ejemplo_2_350_refuerzo_100() -> void:
	print("\n-- Ejemplo 2: 350 -> refuerzo 100 -> base 450, umbral 180 --")
	_save_gameloop_state()

	GameLoop._current_encounter = _make_encounter(40.0)
	GameLoop._group_morale_base_hp = 500.0  # valor previo irrelevante, se sobreescribe
	GameLoop._group_morale_base_dirty = false
	GameLoop._morale_broken = false
	GameLoop.turn_order = []
	GameLoop.participants = []

	_register_test_enemy("test_survivor_2", 400.0, 350.0)  # herido, no al máximo
	_register_test_enemy("test_reinforcement_2", 100.0, 100.0)
	GameLoop._group_morale_base_dirty = true

	GameLoop._check_group_morale()
	_assert(GameLoop._group_morale_base_hp == 450.0, "Base recalculada: 350 supervivientes + 100 refuerzo = 450")
	_assert(not GameLoop._morale_broken, "450/450=100% > 40% -> no huye todavía")

	# Bajar exactamente al umbral (40% de 450 = 180)
	Resources.set_resource("test_survivor_2", "health", 80.0)  # total = 80+100 = 180
	GameLoop._check_group_morale()
	_assert(GameLoop._morale_broken, "180/450=40% <= umbral -> huyen")

	_unregister_test_enemy("test_survivor_2")
	_unregister_test_enemy("test_reinforcement_2")
	_restore_gameloop_state()


## Confirma que, sin refuerzo de por medio, la base nunca se toca aunque se
## evalúe la moral varias veces seguidas (no se recalcula golpe a golpe).
func _test_base_no_cambia_sin_refuerzo() -> void:
	print("\n-- La base no cambia entre evaluaciones sin refuerzo --")
	_save_gameloop_state()

	GameLoop._current_encounter = _make_encounter(40.0)
	GameLoop._group_morale_base_hp = 500.0
	GameLoop._group_morale_base_dirty = false
	GameLoop._morale_broken = false
	GameLoop.turn_order = []
	GameLoop.participants = []

	_register_test_enemy("test_survivor_3", 500.0, 500.0)

	GameLoop._check_group_morale()
	Resources.set_resource("test_survivor_3", "health", 450.0)
	GameLoop._check_group_morale()
	Resources.set_resource("test_survivor_3", "health", 401.0)
	GameLoop._check_group_morale()

	_assert(GameLoop._group_morale_base_hp == 500.0, "Tres evaluaciones seguidas sin refuerzo no tocan la base")
	_assert(not GameLoop._morale_broken, "401/500=80.2% > 40% -> no huye")

	_unregister_test_enemy("test_survivor_3")
	_restore_gameloop_state()
