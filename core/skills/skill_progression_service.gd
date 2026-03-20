class_name SkillProgressionService
extends Node

## SkillProgressionService - Orquestador del sistema de mejora de habilidades
## Singleton recomendado: /root/SkillProgression
##
## Responsabilidades:
## - Escuchar inicio/fin de combate para gestionar ciclo de progresion
## - Registrar resultados de tiradas (exitos, fallos, pity)
## - Ejecutar tiradas de mejora inversa al fin del combate
## - Aplicar modificador de estres al umbral de mejora
## - Acumular estres por uso exitoso de habilidades
## - Escribir el nuevo success_rate en CharacterSystem
## - Emitir eventos de resultado para UI y narrativa

# ============================================
# CONSTANTES
# ============================================

const MIN_IMPROVEMENT: int    = 1
const MAX_IMPROVEMENT: int    = 2
const PITY_THRESHOLD: int     = 3
const DEFAULT_MAX_TICKS: int  = 3
const PLAYER_ID: String       = "player"

## Estres generado por uso exitoso de una habilidad fisica
const STRESS_PER_SUCCESS_PHYSICAL: float = 2.0
## Estres generado por uso exitoso de una habilidad mental/magica
const STRESS_PER_SUCCESS_MENTAL: float   = 3.0

# ============================================
# REFERENCIAS
# ============================================

var _character_system: Node = null
var _skill_system: Node     = null
var _stress_system: Node    = null

# ============================================
# ESTADO INTERNO
# ============================================

var _combat_active: bool = false

# ============================================
# INICIALIZACION
# ============================================

func _ready() -> void:
	_character_system = get_node_or_null("/root/Characters")
	_skill_system     = get_node_or_null("/root/Skills")
	_stress_system    = get_node_or_null("/root/Stress")

	if not _character_system:
		push_error("[SkillProgressionService] CharacterSystem not found at /root/Characters")
		return
	if not _skill_system:
		push_error("[SkillProgressionService] SkillSystem not found at /root/Skills")
		return
	if not _stress_system:
		push_warning("[SkillProgressionService] StressSystem not found at /root/Stress — stress modifiers disabled")

	if EventBus:
		EventBus.combat_started.connect(_on_combat_started)
		EventBus.combat_ended.connect(_on_combat_ended)
		EventBus.skill_used.connect(_on_skill_used)

	print("[SkillProgressionService] Initialized")


# ============================================
# LISTENERS DEL EVENTBUS
# ============================================

func _on_combat_started(_participants) -> void:
	_combat_active = true
	_reset_all_combat_state(PLAYER_ID)
	print("[SkillProgressionService] Combat started - progression state reset")


func _on_combat_ended(result) -> void:
	_combat_active = false

	if str(result) == "defeat":
		print("[SkillProgressionService] Defeat - no improvement rolls")
		_reset_all_combat_state(PLAYER_ID)
		return

	print("[SkillProgressionService] Combat ended (%s) - processing improvement rolls" % str(result))
	_process_improvement_rolls(PLAYER_ID)
	var party: Node = get_node_or_null("/root/Party")
	if party:
		for companion_id in party.get_active_members():
			_process_improvement_rolls(companion_id)

func _on_skill_used(_entity_id: String, _skill_id: String) -> void:
	pass  # El outcome real llega por notify_skill_outcome()


# ============================================
# API PUBLICA
# ============================================

## Registra el resultado de una tirada de habilidad.
## Llamado por CombatSystem tras resolver cada accion.
func notify_skill_outcome(
	entity_id: String,
	skill_id: String,
	outcome: String,
	context: Dictionary = {}
) -> void:
	if not _combat_active:
		return
	# Aceptar jugador y companions — rechazar enemigos
	var party: Node = Engine.get_main_loop().root.get_node_or_null("/root/Party")
	var is_ally: bool = entity_id == PLAYER_ID or (party != null and party.is_in_party(entity_id))
	if not is_ally:
		return

	var instance = _get_skill_instance(entity_id, skill_id)
	if not instance or not instance.definition.has_progression():
		return

	if not _is_challenge_valid(instance, context):
		print("[SkillProgressionService] %s: challenge too low, no tick" % skill_id)
		return

	match outcome:
		"critical", "success":
			_handle_success(entity_id, skill_id, instance)
		"partial", "failure":
			_handle_failure(entity_id, skill_id, instance)


## Ejecuta una sesión de aprendizaje fuera de combate (entrenador, libro, práctica).
##
## Diferencias respecto al flujo de combate:
##   - No requiere _combat_active.
##   - No genera ticks — la mejora se intenta directamente.
##   - Usa session.source_level como opposed_value para el anti-grinding.
##   - El estrés acumulado sigue afectando el threshold si StressSystem está activo.
##
## Devuelve un Dictionary con el resultado para quien llame (SkillEventHandler,
## ItemCharacterBridge) pueda loggear o mostrar feedback:
##   { "improved": bool, "old_value": int, "new_value": int,
##     "roll": int, "threshold": int, "reason": String }
func execute_learning_session(session: LearningSession) -> Dictionary:
	var empty_result = { "improved": false, "old_value": 0, "new_value": 0,
						 "roll": 0, "threshold": 0, "reason": "" }

	if not session.is_valid():
		empty_result["reason"] = "invalid_session"
		return empty_result

	# Verificar que la skill está desbloqueada
	if not _skill_system.is_skill_unlocked(session.entity_id, session.skill_id):
		push_warning("[SkillProgressionService] LearningSession: '%s' is locked for '%s'" % [
			session.skill_id, session.entity_id
		])
		empty_result["reason"] = "skill_locked"
		return empty_result

	var instance = _get_skill_instance(session.entity_id, session.skill_id)
	if not instance or not instance.definition.has_progression():
		empty_result["reason"] = "no_progression"
		return empty_result

	# Anti-grinding: source_level actúa como opposed_value
	var anti_grind_context = { "opposed_value": float(session.source_level) }
	if not _is_challenge_valid(instance, anti_grind_context):
		push_warning("[SkillProgressionService] LearningSession: source_level %d too low for '%s'" % [
			session.source_level, session.skill_id
		])
		empty_result["reason"] = "challenge_too_low"
		return empty_result

	print("[SkillProgressionService] LearningSession: %s" % str(session))
	return _attempt_improvement(session.entity_id, session.skill_id, instance)


# ============================================
# LOGICA DE TICKS
# ============================================

func _handle_success(entity_id: String, skill_id: String, instance: SkillInstance) -> void:
	if instance.pity_triggered:
		return

	var tick_accepted = instance.register_success()

	# Acumular estres por el esfuerzo del uso exitoso
	_accumulate_stress(entity_id, instance)

	if tick_accepted:
		EventBus.skill_tick_generated.emit(entity_id, skill_id, instance.ticks_this_combat)
		print("[SkillProgressionService] %s: tick %d/%d" % [
			skill_id, instance.ticks_this_combat, _get_max_ticks(instance)
		])
	else:
		print("[SkillProgressionService] %s: tick cap reached (%d)" % [
			skill_id, instance.ticks_this_combat
		])


func _handle_failure(entity_id: String, skill_id: String, instance: SkillInstance) -> void:
	instance.register_failure()

	if instance.consecutive_failures >= PITY_THRESHOLD:
		instance.trigger_pity()
		EventBus.skill_pity_triggered.emit(entity_id, skill_id)
		print("[SkillProgressionService] %s: pity triggered after %d consecutive failures" % [
			skill_id, PITY_THRESHOLD
		])


# ============================================
# ACUMULACION DE ESTRES
# ============================================

## Acumula estres segun el tipo de la habilidad usada.
## Se llama solo en exitos — usar la habilidad tiene un coste de esfuerzo.
func _accumulate_stress(entity_id: String, instance: SkillInstance) -> void:
	if not _stress_system:
		return

	var stress_type_str: String = instance.definition.stress_type  # "PHYSICAL" o "MENTAL"
	var amount: float

	if stress_type_str == "PHYSICAL":
		amount = STRESS_PER_SUCCESS_PHYSICAL
		_stress_system.add_stress(entity_id, StressSystem.StressType.PHYSICAL, amount)
	else:
		amount = STRESS_PER_SUCCESS_MENTAL
		_stress_system.add_stress(entity_id, StressSystem.StressType.MENTAL, amount)


# ============================================
# TIRADAS DE MEJORA AL FIN DEL COMBATE
# ============================================

func _process_improvement_rolls(entity_id: String) -> void:
	var known_skills = _character_system.list_known_skills(entity_id)

	for skill_id in known_skills:
		var instance = _get_skill_instance(entity_id, skill_id)
		if not instance or not instance.definition.has_progression():
			continue
		if not instance.can_attempt_improvement():
			continue
		_attempt_improvement(entity_id, skill_id, instance)

	_reset_all_combat_state(entity_id)


## Ejecuta la tirada de mejora para una skill.
## Usado tanto por el flujo de combate (_process_improvement_rolls)
## como por el aprendizaje fuera de combate (execute_learning_session).
## Devuelve el resultado como Dictionary para consumo externo.
func _attempt_improvement(entity_id: String, skill_id: String, instance: SkillInstance) -> Dictionary:
	var current_value: int = _character_system.get_skill_value(entity_id, skill_id)

	# Valor efectivo: incorpora attribute_weights si están definidos en la skill.
	# Si no hay pesos, devuelve current_value sin cambios (comportamiento v1).
	var effective_value: int = _get_effective_value(entity_id, skill_id, instance, current_value)

	# Aplicar modificador de estres al valor efectivo usado en la tirada.
	# Estres alto sube el umbral efectivo → mas dificil mejorar cuando estas agotado.
	if _stress_system:
		var stress_type_str: String = instance.definition.stress_type
		var stress_enum = (
			StressSystem.StressType.PHYSICAL
			if stress_type_str == "PHYSICAL"
			else StressSystem.StressType.MENTAL
		)
		var stress_mod: float = _stress_system.get_modifier(entity_id, stress_enum)
		# Invertimos el modificador: stress_mod < 1.0 significa fatiga.
		# Fatiga sube el umbral (mas dificil mejorar), no lo baja.
		# Ejemplo: valor=50, stress_mod=0.90 → effective_value = 50 / 0.90 ≈ 55
		if stress_mod > 0.0:
			effective_value = int(float(effective_value) / stress_mod)

	# Penalizacion adicional por soft caps definidos en la skill
	var penalty: int        = instance.definition.get_difficulty_penalty(current_value)
	var threshold: int      = effective_value + penalty
	var improvement_roll: int = randi_range(1, 100)

	EventBus.skill_improvement_attempted.emit(entity_id, skill_id, improvement_roll, threshold)

	if improvement_roll > threshold:
		var improvement: int  = randi_range(MIN_IMPROVEMENT, MAX_IMPROVEMENT)
		var old_value: int    = current_value
		_character_system.modify_skill_value(entity_id, skill_id, improvement)
		var new_value: int    = _character_system.get_skill_value(entity_id, skill_id)

		EventBus.skill_improved.emit(entity_id, skill_id, old_value, new_value)
		print("[SkillProgressionService] [%s] %s IMPROVED: %d → %d (roll %d vs threshold %d)" % [
			entity_id, skill_id, old_value, new_value, improvement_roll, threshold
		])
		return { "improved": true,  "old_value": old_value, "new_value": new_value,
				 "roll": improvement_roll, "threshold": threshold, "reason": "improved" }
	else:
		EventBus.skill_improvement_failed.emit(entity_id, skill_id, improvement_roll, threshold)
		print("[SkillProgressionService] [%s] %s: no improvement (roll %d vs threshold %d)" % [
			entity_id, skill_id, improvement_roll, threshold
		])
		return { "improved": false, "old_value": current_value, "new_value": current_value,
				 "roll": improvement_roll, "threshold": threshold, "reason": "roll_failed" }


# ============================================
# ANTI-GRINDING
# ============================================

func _is_challenge_valid(instance: SkillInstance, context: Dictionary) -> bool:
	if context.is_empty():
		return true

	var opposed_value: float = context.get("opposed_value", context.get("difficulty_rating", 0.0))
	if opposed_value <= 0.0:
		return true

	# El reto debe superar el 50% del valor actual de la skill
	var current = float(_character_system.get_skill_value(PLAYER_ID, instance.definition.id))
	if current > 0.0 and opposed_value < current * 0.5:
		return false

	return true


# ============================================
# HELPERS
# ============================================

## Calcula el valor efectivo de una skill combinando su valor base con los
## atributos del personaje ponderados por attribute_weights.
##
## FÓRMULA:
##   Si attribute_weights está vacío  → devuelve current_value sin cambios (compatibilidad v1).
##   Si tiene pesos                   → bonus = Σ(attr_value × weight) / Σ(weights)
##                                      effective = current_value + int(bonus * ATTRIBUTE_WEIGHT_SCALE)
##
## El bonus se suma al valor base, no lo reemplaza. Esto significa que los atributos
## aceleran la mejora pero no la garantizan — un personaje fuerte mejora más rápido
## su ataque pesado, pero no puede saltarse el umbral de 100%.
##
## ATTRIBUTE_WEIGHT_SCALE = 0.5: un personaje con atributo 14 y peso 1.0
## contribuye con +7 al threshold efectivo, lo cual es un efecto notable pero no dominante.
const ATTRIBUTE_WEIGHT_SCALE: float = 0.5

func _get_effective_value(
	entity_id: String,
	skill_id: String,
	instance: SkillInstance,
	current_value: int
) -> int:
	var weights: Dictionary = instance.definition.attribute_weights

	# Sin pesos declarados: comportamiento idéntico a v1
	if weights.is_empty():
		return current_value

	# Calcular promedio ponderado de atributos
	var weighted_sum: float = 0.0
	var total_weight: float = 0.0

	for attr_id in weights.keys():
		var weight: float = float(weights[attr_id])
		var attr_value: float = _character_system.get_base_attribute(entity_id, attr_id)

		if attr_value <= 0.0:
			push_warning("[SkillProgressionService] attribute_weights: attr '%s' is 0 for entity '%s'" % [
				attr_id, entity_id
			])
			continue

		weighted_sum  += attr_value * weight
		total_weight  += weight

	if total_weight <= 0.0:
		push_warning("[SkillProgressionService] attribute_weights: total_weight is 0 for '%s'" % skill_id)
		return current_value

	var attr_average: float = weighted_sum / total_weight
	var bonus: int = int(attr_average * ATTRIBUTE_WEIGHT_SCALE)
	var effective: int = current_value + bonus

	print("[SkillProgressionService] %s effective_value: %d + %d (attrs) = %d" % [
		skill_id, current_value, bonus, effective
	])

	return effective

func _get_skill_instance(entity_id: String, skill_id: String) -> SkillInstance:
	if not _skill_system:
		return null
	return _skill_system.get_skill_instance(entity_id, skill_id)


func _get_max_ticks(instance: SkillInstance) -> int:
	if instance.definition.max_ticks_per_combat > 0:
		return instance.definition.max_ticks_per_combat
	return DEFAULT_MAX_TICKS


func _reset_all_combat_state(entity_id: String) -> void:
	if not _skill_system or not _character_system:
		return
	var known_skills: Array[String] = _character_system.list_known_skills(entity_id)
	for skill_id in known_skills:
		var instance: SkillInstance = _get_skill_instance(entity_id, skill_id)
		if instance:
			instance.reset_combat_state()


# ============================================
# DEBUG
# ============================================

func print_progression_state(entity_id: String = PLAYER_ID) -> void:
	print("\n[SkillProgressionService] === PROGRESSION STATE: %s ===" % entity_id)

	var known_skills = _character_system.list_known_skills(entity_id)
	if known_skills.is_empty():
		print("  (no known skills)")
		return

	for skill_id in known_skills:
		var current_value = _character_system.get_skill_value(entity_id, skill_id)
		var instance      = _get_skill_instance(entity_id, skill_id)

		var progression_info: String = ""
		if instance and instance.definition.has_progression():
			var stress_info: String = ""
			if _stress_system:
				var stress_type_str = instance.definition.stress_type
				var stress_enum = (
					StressSystem.StressType.PHYSICAL
					if stress_type_str == "PHYSICAL"
					else StressSystem.StressType.MENTAL
				)
				var mod = _stress_system.get_modifier(entity_id, stress_enum)
				stress_info = " stress_mod=%.2f" % mod
			progression_info = " | ticks=%d, fails=%d%s%s" % [
				instance.ticks_this_combat,
				instance.consecutive_failures,
				" [PITY]" if instance.pity_triggered else "",
				stress_info
			]

		print("  %s: %d%%%s" % [skill_id, current_value, progression_info])

	print("")
