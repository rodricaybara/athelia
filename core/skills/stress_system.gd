class_name StressSystem
extends Node

## StressSystem - Gestor de estres fisico y mental por entidad
## Singleton recomendado: /root/Stress
##
## Responsabilidades:
## - Acumular estres fisico y mental por entidad
## - Calcular tolerancia basada en atributos del personaje
## - Calcular tasa de recuperacion
## - Exponer estado (STABLE/FATIGUED/OVERLOADED/CRITICAL)
## - Exponer modificador de penalizacion para SkillProgressionService
##
## NO hace:
## - Aplicar penalizaciones directamente a skills (eso es SkillProgressionService)
## - Mostrar UI (eso es la capa de presentacion)
## - Persistir estado (el estres se resetea entre sesiones — diseno deliberado)

# ============================================
# ENUMS
# ============================================

enum StressState {
	STABLE,     ## < 70% tolerancia — sin penalizacion
	FATIGUED,   ## 70-100% tolerancia — penalizacion leve (-5%)
	OVERLOADED, ## 100-130% tolerancia — penalizacion media (-10%)
	CRITICAL    ## > 130% tolerancia — penalizacion maxima + riesgo de evento
}

enum StressType {
	PHYSICAL,
	MENTAL
}

# ============================================
# CONSTANTES — umbrales y penalizaciones
# Balanceables sin tocar logica
# ============================================

## Porcentaje de tolerancia a partir del cual se entra en FATIGUED
const THRESHOLD_FATIGUED: float    = 0.70
## Porcentaje de tolerancia a partir del cual se entra en OVERLOADED
const THRESHOLD_OVERLOADED: float  = 1.00
## Porcentaje de tolerancia a partir del cual se entra en CRITICAL
const THRESHOLD_CRITICAL: float    = 1.30

## Modificadores de penalizacion por estado (multiplicadores sobre success_rate)
## 1.0 = sin penalizacion, 0.95 = -5%, 0.90 = -10%
const MODIFIER_STABLE: float     = 1.00
const MODIFIER_FATIGUED: float   = 0.95
const MODIFIER_OVERLOADED: float = 0.90
const MODIFIER_CRITICAL: float   = 0.90  ## mismo cap que OVERLOADED — no permanente

## Coeficientes para calcular tolerancia desde atributos
## ToleranciaFisica = constitution * A + wisdom * B
## ToleranciaMental = intelligence * A + wisdom * B
const TOLERANCE_PRIMARY_COEF: float   = 1.5
const TOLERANCE_SECONDARY_COEF: float = 0.5

## Coeficientes para tasa de recuperacion base por tick de descanso
const RECOVERY_PRIMARY_COEF: float    = 0.8
const RECOVERY_SECONDARY_COEF: float  = 0.4

## Estres minimo — nunca baja de 0
const MIN_STRESS: float = 0.0

# ============================================
# ESTADO INTERNO
# { entity_id: { "physical": float, "mental": float } }
# ============================================

var _stress: Dictionary = {}

# ============================================
# REFERENCIAS
# ============================================

var _character_system: Node = null

# ============================================
# INICIALIZACION
# ============================================

func _ready() -> void:
	_character_system = get_node_or_null("/root/Characters")
	if not _character_system:
		push_error("[StressSystem] CharacterSystem not found at /root/Characters")
		return

	# Escuchar registro/baja de entidades para mantener estado limpio
	if EventBus:
		EventBus.character_registered.connect(_on_character_registered)
		EventBus.character_unregistered.connect(_on_character_unregistered)

	print("[StressSystem] Initialized")


# ============================================
# LISTENERS
# ============================================

func _on_character_registered(entity_id: String, _definition_id: String) -> void:
	_stress[entity_id] = { "physical": 0.0, "mental": 0.0 }
	print("[StressSystem] Tracking stress for: %s" % entity_id)


func _on_character_unregistered(entity_id: String) -> void:
	_stress.erase(entity_id)


# ============================================
# API PUBLICA
# ============================================

## Añade estres de un tipo a una entidad.
## Llamado por SkillProgressionService tras un uso exitoso con fatiga.
func add_stress(entity_id: String, stress_type: StressType, amount: float) -> void:
	_ensure_entry(entity_id)
	var key = _key(stress_type)
	_stress[entity_id][key] = maxf(MIN_STRESS, _stress[entity_id][key] + amount)


## Recuperacion gradual: reduce el estres de ambos tipos.
## Llamado al descansar o al final de una escena.
## recovery_multiplier > 1 en entornos favorables (cama, posada, etc.)
func recover(entity_id: String, recovery_multiplier: float = 1.0) -> void:
	_ensure_entry(entity_id)

	var phys_recovery = _compute_recovery_rate(entity_id, StressType.PHYSICAL) * recovery_multiplier
	var ment_recovery = _compute_recovery_rate(entity_id, StressType.MENTAL) * recovery_multiplier

	_stress[entity_id]["physical"] = maxf(MIN_STRESS, _stress[entity_id]["physical"] - phys_recovery)
	_stress[entity_id]["mental"]   = maxf(MIN_STRESS, _stress[entity_id]["mental"]   - ment_recovery)


## Devuelve el estado actual de estres de un tipo para una entidad.
func get_state(entity_id: String, stress_type: StressType) -> StressState:
	_ensure_entry(entity_id)
	var ratio = _stress_ratio(entity_id, stress_type)

	if ratio >= THRESHOLD_CRITICAL:
		return StressState.CRITICAL
	elif ratio >= THRESHOLD_OVERLOADED:
		return StressState.OVERLOADED
	elif ratio >= THRESHOLD_FATIGUED:
		return StressState.FATIGUED
	else:
		return StressState.STABLE


## Devuelve el modificador de penalizacion (0.90 - 1.00) para aplicar al success_rate.
## Usado por SkillProgressionService antes de ejecutar tiradas.
func get_modifier(entity_id: String, stress_type: StressType) -> float:
	match get_state(entity_id, stress_type):
		StressState.STABLE:
			return MODIFIER_STABLE
		StressState.FATIGUED:
			return MODIFIER_FATIGUED
		StressState.OVERLOADED, StressState.CRITICAL:
			return MODIFIER_CRITICAL
	return MODIFIER_STABLE


## Devuelve el valor actual de estres (para debug o UI avanzada interna).
func get_stress_value(entity_id: String, stress_type: StressType) -> float:
	_ensure_entry(entity_id)
	return _stress[entity_id][_key(stress_type)]


## Devuelve la tolerancia calculada para una entidad y tipo.
func get_tolerance(entity_id: String, stress_type: StressType) -> float:
	return _compute_tolerance(entity_id, stress_type)


## Resetea el estres de una entidad a 0 (usar solo en eventos narrativos especiales).
func reset_stress(entity_id: String) -> void:
	if _stress.has(entity_id):
		_stress[entity_id] = { "physical": 0.0, "mental": 0.0 }


# ============================================
# CALCULO INTERNO
# ============================================

## Tolerancia fisica  = constitution * 1.5 + wisdom * 0.5
## Tolerancia mental  = intelligence * 1.5 + wisdom * 0.5
func _compute_tolerance(entity_id: String, stress_type: StressType) -> float:
	if not _character_system:
		return 10.0  # fallback seguro

	var primary: float
	var secondary: float

	match stress_type:
		StressType.PHYSICAL:
			primary   = _character_system.get_base_attribute(entity_id, "constitution")
			secondary = _character_system.get_base_attribute(entity_id, "wisdom")
		StressType.MENTAL:
			primary   = _character_system.get_base_attribute(entity_id, "intelligence")
			secondary = _character_system.get_base_attribute(entity_id, "wisdom")

	return maxf(1.0, primary * TOLERANCE_PRIMARY_COEF + secondary * TOLERANCE_SECONDARY_COEF)


## Tasa de recuperacion por tick de descanso.
## Fisica: constitution * 0.8 + wisdom * 0.4
## Mental:  intelligence * 0.8 + wisdom * 0.4
func _compute_recovery_rate(entity_id: String, stress_type: StressType) -> float:
	if not _character_system:
		return 1.0

	var primary: float
	var secondary: float

	match stress_type:
		StressType.PHYSICAL:
			primary   = _character_system.get_base_attribute(entity_id, "constitution")
			secondary = _character_system.get_base_attribute(entity_id, "wisdom")
		StressType.MENTAL:
			primary   = _character_system.get_base_attribute(entity_id, "intelligence")
			secondary = _character_system.get_base_attribute(entity_id, "wisdom")

	return maxf(0.1, primary * RECOVERY_PRIMARY_COEF + secondary * RECOVERY_SECONDARY_COEF)


## Ratio estres / tolerancia (0.0 = sin estres, 1.0 = en el limite, >1.0 = sobrecarga)
func _stress_ratio(entity_id: String, stress_type: StressType) -> float:
	var tolerance = _compute_tolerance(entity_id, stress_type)
	if tolerance <= 0.0:
		return 0.0
	return _stress[entity_id][_key(stress_type)] / tolerance


func _key(stress_type: StressType) -> String:
	return "physical" if stress_type == StressType.PHYSICAL else "mental"


func _ensure_entry(entity_id: String) -> void:
	if not _stress.has(entity_id):
		_stress[entity_id] = { "physical": 0.0, "mental": 0.0 }


# ============================================
# DEBUG
# ============================================

func print_stress_state(entity_id: String) -> void:
	_ensure_entry(entity_id)

	var phys_val  = _stress[entity_id]["physical"]
	var ment_val  = _stress[entity_id]["mental"]
	var phys_tol  = _compute_tolerance(entity_id, StressType.PHYSICAL)
	var ment_tol  = _compute_tolerance(entity_id, StressType.MENTAL)
	var phys_state = StressState.keys()[get_state(entity_id, StressType.PHYSICAL)]
	var ment_state = StressState.keys()[get_state(entity_id, StressType.MENTAL)]

	print("\n[StressSystem] === %s ===" % entity_id)
	print("  Physical: %.1f / %.1f  (%s)  mod=%.2f" % [
		phys_val, phys_tol, phys_state,
		get_modifier(entity_id, StressType.PHYSICAL)
	])
	print("  Mental:   %.1f / %.1f  (%s)  mod=%.2f" % [
		ment_val, ment_tol, ment_state,
		get_modifier(entity_id, StressType.MENTAL)
	])
