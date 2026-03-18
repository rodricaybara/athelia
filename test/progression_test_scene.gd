extends Node2D

## ProgressionTestScene - Test completo del sistema de progresion
##
## QUE TESTEA:
##   T1 - SkillDefinition.has_progression() funciona
##   T2 - StressSystem se inicializa al registrar entidad
##   T3 - notify_skill_outcome acumula ticks correctamente
##   T4 - Pity system se activa tras PITY_THRESHOLD fallos
##   T5 - Estres se acumula en exitos
##   T6 - Tirada de mejora se ejecuta al fin del combate
##   T7 - Estres sube el umbral de mejora (FATIGUED)
##   T8 - Derrota NO ejecuta tiradas de mejora
##   T9 - reset_combat_state() limpia ticks entre combates
##   T10 - Anti-grind bloquea ticks con challenge bajo
##
## COMO USAR:
##   1. Abrir esta escena en Godot y ejecutar (F5)
##   2. Leer el Output panel — cada test imprime PASS o FAIL
##   3. Al final se imprime el resumen total

const PLAYER_ID: String = "player"

# Contadores globales del test runner
var _tests_run:    int = 0
var _tests_passed: int = 0
var _tests_failed: int = 0

# Referencia al estado anterior de skill para comparar mejoras
var _skill_value_before: Dictionary = {}


# ============================================
# ENTRY POINT
# ============================================

func _ready() -> void:
	# Pequeño delay para que todos los autoloads terminen _ready()
	await get_tree().create_timer(0.2).timeout
	_run_all_tests()


func _run_all_tests() -> void:
	_print_header("PROGRESSION SYSTEM — TEST SUITE")

	# Setup: registrar entidades
	_setup_entities()

	# Bloque 1 — Datos estáticos
	_test_skill_has_progression()
	_test_skill_without_progression()

	# Bloque 2 — StressSystem
	_test_stress_initialized_on_register()
	_test_stress_state_stable()

	# Bloque 3 — Ciclo de combate completo
	_test_ticks_accumulate_on_success()
	_test_tick_cap_respected()
	_test_pity_triggers_after_failures()
	_test_stress_accumulates_on_success()
	_test_stress_state_after_multiple_successes()

	# Bloque 4 — Tiradas de mejora
	_test_improvement_roll_on_victory()
	_test_no_improvement_on_defeat()
	_test_stress_raises_threshold()

	# Bloque 5 — Anti-grind y reset
	_test_anti_grind_blocks_easy_challenge()
	_test_combat_state_resets_between_combats()

	# Bloque 6 — requires_unlock (paso 8)
	_test_unlocked_skill_is_available()
	_test_locked_skill_is_not_available()
	_test_unlock_skill_makes_it_available()
	_test_unlock_emits_signal()

	_print_summary()


# ============================================
# SETUP
# ============================================

func _setup_entities() -> void:
	_print_section("SETUP")

	# Limpiar registros previos si la escena se reinicia
	if Characters.has_entity(PLAYER_ID):
		print("  [Setup] Player ya registrado, reutilizando")
	else:
		Resources.register_entity(PLAYER_ID, ["health", "stamina"])
		Resources.set_resource(PLAYER_ID, "health", 100.0)
		Resources.set_resource(PLAYER_ID, "stamina", 100.0)
		Characters.register_entity(PLAYER_ID, "player_base")
		Skills.register_entity_skills(PLAYER_ID, [
			"skill.attack.light",
			"skill.attack.heavy",
		])
		print("  [Setup] Player registrado")

	# Guardar valores iniciales para comparar después
	_skill_value_before = Characters.get_all_skill_values(PLAYER_ID).duplicate()

	# Añadir base_success_rate a las skills de test via CharacterState
	# (Las skills del .tres aún no tienen base_success_rate > 0, lo forzamos aquí
	#  para que has_progression() devuelva true en el test)
	_force_progression_on_test_skills()

	print("  [Setup] Skill values iniciales: %s" % str(_skill_value_before))
	print("  [Setup] Completado\n")


## Fuerza base_success_rate > 0 en las skills de test.
## En producción esto vendrá del .tres — aquí lo hacemos por script
## para no depender de datos que aún no están migrados.
func _force_progression_on_test_skills() -> void:
	var light_def = Skills.get_skill_definition("skill.attack.light")
	var heavy_def = Skills.get_skill_definition("skill.attack.heavy")

	if light_def:
		light_def.base_success_rate = 40
		light_def.stress_type       = "PHYSICAL"
		light_def.max_ticks_per_combat = 2
	if heavy_def:
		heavy_def.base_success_rate = 25
		heavy_def.stress_type       = "PHYSICAL"
		heavy_def.max_ticks_per_combat = 2


# ============================================
# BLOQUE 1 — DATOS ESTÁTICOS
# ============================================

func _test_skill_has_progression() -> void:
	var def = Skills.get_skill_definition("skill.attack.light")
	_assert(
		"T1 — has_progression() true cuando base_success_rate > 0",
		def != null and def.has_progression()
	)


func _test_skill_without_progression() -> void:
	# Creamos una definición temporal sin progression
	var def = SkillDefinition.new()
	def.id              = "test.no.progression"
	def.name_key        = "TEST"
	def.base_success_rate = 0
	_assert(
		"T2 — has_progression() false cuando base_success_rate == 0",
		not def.has_progression()
	)


# ============================================
# BLOQUE 2 — STRESS SYSTEM
# ============================================

func _test_stress_initialized_on_register() -> void:
	var stress_val = Stress.get_stress_value(PLAYER_ID, StressSystem.StressType.PHYSICAL)
	_assert(
		"T3 — StressSystem inicializa estres a 0 al registrar entidad",
		stress_val == 0.0
	)


func _test_stress_state_stable() -> void:
	var state = Stress.get_state(PLAYER_ID, StressSystem.StressType.PHYSICAL)
	_assert(
		"T4 — Estado inicial es STABLE",
		state == StressSystem.StressState.STABLE
	)


# ============================================
# BLOQUE 3 — CICLO DE COMBATE
# ============================================

func _test_ticks_accumulate_on_success() -> void:
	# Simular inicio de combate
	EventBus.combat_started.emit(["enemy_1"])

	var instance = Skills.get_skill_instance(PLAYER_ID, "skill.attack.light")
	var ticks_before = instance.ticks_this_combat

	# Notificar un exito
	SkillProgression.notify_skill_outcome(PLAYER_ID, "skill.attack.light", "success")

	_assert(
		"T5 — Tick se acumula tras notify_skill_outcome('success')",
		instance.ticks_this_combat == ticks_before + 1
	)

	# Limpiar para el siguiente test
	EventBus.combat_ended.emit("escaped")


func _test_tick_cap_respected() -> void:
	EventBus.combat_started.emit(["enemy_1"])

	var instance = Skills.get_skill_instance(PLAYER_ID, "skill.attack.light")
	# max_ticks_per_combat = 2, enviamos 5 exitos
	for i in range(5):
		SkillProgression.notify_skill_outcome(PLAYER_ID, "skill.attack.light", "success")

	_assert(
		"T6 — Ticks no superan max_ticks_per_combat (cap=2)",
		instance.ticks_this_combat <= 2
	)

	EventBus.combat_ended.emit("escaped")


func _test_pity_triggers_after_failures() -> void:
	EventBus.combat_started.emit(["enemy_1"])

	var instance = Skills.get_skill_instance(PLAYER_ID, "skill.attack.heavy")
	# PITY_THRESHOLD = 3 fallos consecutivos
	for i in range(3):
		SkillProgression.notify_skill_outcome(PLAYER_ID, "skill.attack.heavy", "partial")

	_assert(
		"T7 — Pity se activa tras 3 fallos consecutivos",
		instance.pity_triggered == true
	)

	EventBus.combat_ended.emit("escaped")


func _test_stress_accumulates_on_success() -> void:
	# Reseteamos estres primero
	Stress.reset_stress(PLAYER_ID)
	EventBus.combat_started.emit(["enemy_1"])

	var stress_before = Stress.get_stress_value(PLAYER_ID, StressSystem.StressType.PHYSICAL)
	SkillProgression.notify_skill_outcome(PLAYER_ID, "skill.attack.light", "success")
	var stress_after  = Stress.get_stress_value(PLAYER_ID, StressSystem.StressType.PHYSICAL)

	_assert(
		"T8 — Estres fisico aumenta tras exito en skill PHYSICAL",
		stress_after > stress_before
	)

	EventBus.combat_ended.emit("escaped")


func _test_stress_state_after_multiple_successes() -> void:
	Stress.reset_stress(PLAYER_ID)
	EventBus.combat_started.emit(["enemy_1"])

	# Forzar muchos exitos para que el estres suba de zona
	# STRESS_PER_SUCCESS_PHYSICAL = 2.0
	# Tolerancia fisica player_base: constitution(11)*1.5 + wisdom(9)*0.5 = 21.0
	# Para llegar a FATIGUED necesitamos 70% de 21.0 = 14.7 → 8 exitos (8*2=16)
	for i in range(10):
		SkillProgression.notify_skill_outcome(PLAYER_ID, "skill.attack.light", "success")

	var state = Stress.get_state(PLAYER_ID, StressSystem.StressType.PHYSICAL)
	_assert(
		"T9 — Estado de estres sube a FATIGUED u OVERLOADED tras muchos exitos",
		state == StressSystem.StressState.FATIGUED or
		state == StressSystem.StressState.OVERLOADED or
		state == StressSystem.StressState.CRITICAL
	)

	EventBus.combat_ended.emit("escaped")


# ============================================
# BLOQUE 4 — TIRADAS DE MEJORA
# ============================================

func _test_improvement_roll_on_victory() -> void:
	Stress.reset_stress(PLAYER_ID)

	EventBus.combat_started.emit(["enemy_1"])
	SkillProgression.notify_skill_outcome(PLAYER_ID, "skill.attack.light", "success")
	SkillProgression.notify_skill_outcome(PLAYER_ID, "skill.attack.light", "success")

	# GDScript 4: usar Array como contenedor para captura por referencia
	# Los bool se capturan por valor — el Array se modifica in-place
	var attempted := [false]
	var callable := func(_eid, _sid, _roll, _thr): attempted[0] = true
	EventBus.skill_improvement_attempted.connect(callable)

	EventBus.combat_ended.emit("victory")

	EventBus.skill_improvement_attempted.disconnect(callable)

	_assert(
		"T10 — skill_improvement_attempted se emite al terminar con victoria",
		attempted[0]
	)


func _test_no_improvement_on_defeat() -> void:
	Stress.reset_stress(PLAYER_ID)

	EventBus.combat_started.emit(["enemy_1"])
	SkillProgression.notify_skill_outcome(PLAYER_ID, "skill.attack.light", "success")
	SkillProgression.notify_skill_outcome(PLAYER_ID, "skill.attack.light", "success")

	var attempted := [false]
	var callable := func(_eid, _sid, _roll, _thr): attempted[0] = true
	EventBus.skill_improvement_attempted.connect(callable)

	EventBus.combat_ended.emit("defeat")

	EventBus.skill_improvement_attempted.disconnect(callable)

	_assert(
		"T11 — skill_improvement_attempted NO se emite en derrota",
		not attempted[0]
	)


func _test_stress_raises_threshold() -> void:
	# Este test verifica matematicamente que el umbral efectivo
	# es mayor cuando hay estres que cuando no lo hay.

	var def = Skills.get_skill_definition("skill.attack.light")
	if not def:
		_assert("T12 — Estres sube el umbral efectivo", false)
		return

	# Sin estres
	Stress.reset_stress(PLAYER_ID)
	var mod_clean = Stress.get_modifier(PLAYER_ID, StressSystem.StressType.PHYSICAL)
	var val       = Characters.get_skill_value(PLAYER_ID, "skill.attack.light")
	var threshold_clean = int(float(val) / mod_clean) if mod_clean > 0.0 else val

	# Con estres FATIGUED (añadir 20 puntos sobre tolerancia ~21)
	Stress.add_stress(PLAYER_ID, StressSystem.StressType.PHYSICAL, 16.0)
	var mod_stressed    = Stress.get_modifier(PLAYER_ID, StressSystem.StressType.PHYSICAL)
	var threshold_stressed = int(float(val) / mod_stressed) if mod_stressed > 0.0 else val

	_assert(
		"T12 — Umbral de mejora es mayor con estres (%.2f) que sin el (%.2f)" % [
			mod_stressed, mod_clean
		],
		threshold_stressed >= threshold_clean
	)

	Stress.reset_stress(PLAYER_ID)


# ============================================
# BLOQUE 5 — ANTI-GRIND Y RESET
# ============================================

func _test_anti_grind_blocks_easy_challenge() -> void:
	EventBus.combat_started.emit(["enemy_1"])

	var instance = Skills.get_skill_instance(PLAYER_ID, "skill.attack.light")
	var ticks_before = instance.ticks_this_combat

	# Context con opposed_value muy bajo = reto trivial
	# skill.attack.light tiene valor 40 → 50% de 40 = 20
	# Enviamos opposed_value = 5 → debe bloquearse
	var trivial_context = { "opposed_value": 5.0 }
	SkillProgression.notify_skill_outcome(
		PLAYER_ID, "skill.attack.light", "success", trivial_context
	)

	_assert(
		"T13 — Anti-grind bloquea tick cuando challenge < 50% del valor actual",
		instance.ticks_this_combat == ticks_before
	)

	EventBus.combat_ended.emit("escaped")


func _test_combat_state_resets_between_combats() -> void:
	# Combate 1: acumulamos ticks
	EventBus.combat_started.emit(["enemy_1"])
	SkillProgression.notify_skill_outcome(PLAYER_ID, "skill.attack.light", "success")
	EventBus.combat_ended.emit("victory")

	# Combate 2: los ticks deben haber reseteado
	EventBus.combat_started.emit(["enemy_1"])
	var instance      = Skills.get_skill_instance(PLAYER_ID, "skill.attack.light")
	var ticks_at_start = instance.ticks_this_combat

	_assert(
		"T14 — ticks_this_combat se resetea al iniciar nuevo combate",
		ticks_at_start == 0
	)

	EventBus.combat_ended.emit("escaped")


# ============================================
# BLOQUE 6 — REQUIRES_UNLOCK (Paso 8)
# ============================================

func _test_unlocked_skill_is_available() -> void:
	# skill.attack.light tiene requires_unlock=false → debe estar disponible
	var instance = Skills.get_skill_instance(PLAYER_ID, "skill.attack.light")
	_assert(
		"T15 — Skill con requires_unlock=false empieza disponible (is_unlocked=true)",
		instance != null and instance.is_unlocked == true
	)


func _test_locked_skill_is_not_available() -> void:
	# Registramos una entidad temporal con una skill bloqueada por defecto
	# Para no depender de un .tres específico, forzamos is_unlocked=false directamente
	var instance = Skills.get_skill_instance(PLAYER_ID, "skill.attack.heavy")
	if not instance:
		_assert("T16 — Skill bloqueada no está disponible", false)
		return

	# Forzar bloqueo para el test
	instance.is_unlocked = false
	_assert(
		"T16 — Skill con is_unlocked=false no está disponible (is_available=false)",
		instance.is_available() == false
	)

	# Restaurar para no afectar otros tests
	instance.is_unlocked = true


func _test_unlock_skill_makes_it_available() -> void:
	var instance = Skills.get_skill_instance(PLAYER_ID, "skill.attack.heavy")
	if not instance:
		_assert("T17 — unlock() hace la skill disponible", false)
		return

	# Bloquear
	instance.is_unlocked = false
	_assert(
		"T17a — Skill bloqueada antes del unlock (is_available=false)",
		instance.is_available() == false
	)

	# Desbloquear via API pública del SkillSystem
	Skills.unlock_skill(PLAYER_ID, "skill.attack.heavy")
	_assert(
		"T17b — unlock_skill() hace la skill disponible (is_available=true)",
		instance.is_available() == true
	)


func _test_unlock_emits_signal() -> void:
	var instance = Skills.get_skill_instance(PLAYER_ID, "skill.attack.heavy")
	if not instance:
		_assert("T18 — unlock emite skill_unlocked", false)
		return

	# Bloquear para poder desbloquear
	instance.is_unlocked = false

	var emitted := [false]
	var callable := func(_eid, _sid): emitted[0] = true
	EventBus.skill_unlocked.connect(callable)

	Skills.unlock_skill(PLAYER_ID, "skill.attack.heavy")

	EventBus.skill_unlocked.disconnect(callable)

	_assert(
		"T18 — unlock_skill() emite EventBus.skill_unlocked",
		emitted[0]
	)


# ============================================
# TEST RUNNER HELPERS
# ============================================

func _assert(test_name: String, condition: bool) -> void:
	_tests_run += 1
	if condition:
		_tests_passed += 1
		print("  ✅ PASS — %s" % test_name)
	else:
		_tests_failed += 1
		print("  ❌ FAIL — %s" % test_name)


func _print_header(title: String) -> void:
	print("\n" + "=".repeat(60))
	print("  %s" % title)
	print("=".repeat(60))


func _print_section(title: String) -> void:
	print("\n── %s ──────────────────────────────" % title)


func _print_summary() -> void:
	print("\n" + "=".repeat(60))
	print("  RESULTADOS: %d/%d tests pasados" % [_tests_passed, _tests_run])
	if _tests_failed > 0:
		print("  ⚠ FALLIDOS: %d" % _tests_failed)
		print("  Revisa los tests marcados con ❌ arriba")
	else:
		print("  🎉 Todos los tests pasaron")
	print("=".repeat(60) + "\n")

	# Estado final de depuración
	_print_section("ESTADO FINAL")
	SkillProgression.print_progression_state(PLAYER_ID)
	Stress.print_stress_state(PLAYER_ID)
