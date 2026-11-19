class_name BehaviorProfile
extends Resource

## BehaviorProfile — Parámetros ESTÁTICOS de comportamiento de la IA de combate (IA-1a).
##
## Se carga de data/ai/profiles/*.tres a través de BehaviorProfileRegistry, que entrega
## siempre un duplicado profundo (Resource.duplicate() comparte los Dictionary/Array con
## el original: comprobado en 4.7.2). La moral ACTUAL nunca vive aquí: solo su configuración.
## Los pesos de consideración (`weights`) son de IA-2; en IA-1a pueden estar vacíos.
##
## Un .tres solo guarda lo distinto del valor por defecto: verificar los valores por el log
## de carga del registry, no por el inspector.

## Perfil que entrega el registry cuando el id pedido no existe o está vacío.
const SAFE_DEFAULT_ID: StringName = &"safe_default"

## Conjunto cerrado de preferencias de objetivo (spec 5.3).
const TARGET_PREFERENCES: Array[StringName] = [
	&"weakest", &"most_dangerous", &"last_attacker", &"random", &"none",
]

## Consideraciones conocidas (spec 5.2). `ally_in_danger` está reservada e inactiva en el MVP.
const CONSIDERATION_IDS: Array[StringName] = [
	&"expected_damage", &"resource_cost", &"action_utility",
	&"target_vulnerability", &"threat_level", &"self_risk", &"ally_in_danger",
]

## Claves permitidas de la configuración de moral (spec 9).
const MORALE_KEYS: Array[String] = [
	"base", "events", "big_hit_pct", "shaken_modifiers", "health_tiers", "conditions", "thresholds",
]
const MORALE_EVENT_KEYS: Array[String] = ["ally_died", "leader_died", "big_hit_taken"]
const MORALE_CONDITION_KEYS: Array[String] = ["outnumbered"]
const MORALE_MODIFIER_KEYS: Array[String] = ["offensive_mult", "defensive_mult", "flexibility_add"]
const MORALE_THRESHOLD_KEYS: Array[String] = ["shaken_enter", "shaken_exit", "broken"]

@export var id: StringName = &""
## consideración -> peso con signo (IA-2).
@export var weights: Dictionary = {}
## weakest | most_dangerous | last_attacker | random | none
@export var target_preference: StringName = &"none"
@export var target_bonus: float = 6.0
@export var decision_flexibility: float = 10.0
@export var survival_threshold: float = 0.3
@export var survival_bonus: float = 8.0
## 0 = usar reference_damage_default de ai_scales.json.
@export var reference_damage: float = 0.0
## Solo lo usan los aliados con orden (IA-3).
@export var obedience: float = 0.0
@export var can_flee: bool = true
## Configuración estática de moral (spec 9). Vacío = sin moral.
@export var morale: Dictionary = {}


## Perfil seguro: sin preferencia de objetivo, sin huida, sin moral, sin pesos. Siempre válido.
static func make_safe_default() -> BehaviorProfile:
	var profile: BehaviorProfile = new()
	profile.id = SAFE_DEFAULT_ID
	profile.target_preference = &"none"
	profile.can_flee = false
	return profile


## Copia independiente (profunda): weights y morale no se comparten con el original.
func duplicate_profile() -> BehaviorProfile:
	return duplicate(true) as BehaviorProfile


## Errores de datos con mensaje claro (vacío = válido).
func validate() -> Array[String]:
	var errors: Array[String] = []
	var label: String = String(id) if id != &"" else "(sin id)"

	if id == &"":
		errors.append("%s: id vacío" % label)
	if not TARGET_PREFERENCES.has(target_preference):
		errors.append("%s: target_preference '%s' fuera del conjunto cerrado %s" % [label, target_preference, str(TARGET_PREFERENCES)])

	_check_min(errors, label, "target_bonus", target_bonus, 0.0)
	_check_min(errors, label, "decision_flexibility", decision_flexibility, 0.0)
	_check_min(errors, label, "survival_bonus", survival_bonus, 0.0)
	_check_min(errors, label, "reference_damage", reference_damage, 0.0)
	_check_min(errors, label, "obedience", obedience, 0.0)
	if not is_finite(survival_threshold) or survival_threshold < 0.0 or survival_threshold > 1.0:
		errors.append("%s: survival_threshold %s debe estar entre 0 y 1" % [label, survival_threshold])

	for key in weights.keys():
		var key_type: int = typeof(key)
		if key_type != TYPE_STRING and key_type != TYPE_STRING_NAME:
			errors.append("%s: weights tiene una clave que no es texto (%s)" % [label, str(key)])
			continue
		if not CONSIDERATION_IDS.has(StringName(String(key))):
			errors.append("%s: weights contiene la consideración desconocida '%s'" % [label, String(key)])
		if not _is_number(weights[key]):
			errors.append("%s: el peso de '%s' no es un número finito" % [label, String(key)])

	if not morale.is_empty():
		_validate_morale(errors, label)
	return errors


## Una línea con los valores cargados (para el log del registry).
func summary() -> String:
	return "%s (target_preference=%s, target_bonus=%.1f, flexibility=%.1f, survival=%.2f/%.1f, obedience=%.1f, can_flee=%s, morale=%s, weights=%d)" % [
		String(id), target_preference, target_bonus, decision_flexibility,
		survival_threshold, survival_bonus, obedience, str(can_flee),
		"sí" if not morale.is_empty() else "no", weights.size(),
	]


# ---------------------------------------------------------------- internos

static func _is_number(value: Variant) -> bool:
	var value_type: int = typeof(value)
	if value_type == TYPE_INT:
		return true
	return value_type == TYPE_FLOAT and is_finite(float(value))


static func _check_min(errors: Array[String], label: String, field: String, value: float, min_value: float) -> void:
	if not is_finite(value) or value < min_value:
		errors.append("%s: %s = %s debe ser un número finito >= %s" % [label, field, value, min_value])


func _validate_morale(errors: Array[String], label: String) -> void:
	for key in morale.keys():
		if not MORALE_KEYS.has(String(key)):
			errors.append("%s: morale contiene la clave desconocida '%s'" % [label, String(key)])

	var base_value: float = 100.0
	if morale.has("base"):
		if not _is_number(morale["base"]) or float(morale["base"]) <= 0.0:
			errors.append("%s: morale.base debe ser un número > 0" % label)
		else:
			base_value = float(morale["base"])

	var thresholds: Variant = morale.get("thresholds", null)
	if not (thresholds is Dictionary):
		errors.append("%s: morale.thresholds es obligatorio (shaken_enter, shaken_exit, broken)" % label)
	else:
		var th: Dictionary = thresholds
		var complete: bool = true
		for key in MORALE_THRESHOLD_KEYS:
			if not th.has(key) or not _is_number(th[key]):
				errors.append("%s: morale.thresholds.%s falta o no es un número" % [label, key])
				complete = false
		for key in th.keys():
			if not MORALE_THRESHOLD_KEYS.has(String(key)):
				errors.append("%s: morale.thresholds contiene la clave desconocida '%s'" % [label, String(key)])
		if complete:
			var broken: float = float(th["broken"])
			var shaken_enter: float = float(th["shaken_enter"])
			var shaken_exit: float = float(th["shaken_exit"])
			if not (broken >= 0.0 and broken < shaken_enter and shaken_enter < shaken_exit):
				errors.append("%s: umbrales de moral inválidos: debe cumplirse 0 <= broken < shaken_enter < shaken_exit (broken=%s, shaken_enter=%s, shaken_exit=%s)" % [label, broken, shaken_enter, shaken_exit])
			if shaken_exit > base_value:
				errors.append("%s: morale.thresholds.shaken_exit (%s) supera morale.base (%s)" % [label, shaken_exit, base_value])

	_validate_number_map(errors, label, "events", MORALE_EVENT_KEYS)
	_validate_number_map(errors, label, "conditions", MORALE_CONDITION_KEYS)
	_validate_number_map(errors, label, "shaken_modifiers", MORALE_MODIFIER_KEYS)

	if morale.has("big_hit_pct"):
		if not _is_number(morale["big_hit_pct"]) or float(morale["big_hit_pct"]) <= 0.0 or float(morale["big_hit_pct"]) > 100.0:
			errors.append("%s: morale.big_hit_pct debe estar entre 0 (excluido) y 100" % label)

	if morale.has("health_tiers"):
		var tiers: Variant = morale["health_tiers"]
		if not (tiers is Array):
			errors.append("%s: morale.health_tiers debe ser una lista" % label)
		else:
			var index: int = 0
			for tier in (tiers as Array):
				if not (tier is Dictionary) or not _is_number((tier as Dictionary).get("below")) \
						or not _is_number((tier as Dictionary).get("penalty")):
					errors.append("%s: morale.health_tiers[%d] necesita 'below' y 'penalty' numéricos" % [label, index])
				else:
					var below: float = float((tier as Dictionary)["below"])
					var penalty: float = float((tier as Dictionary)["penalty"])
					if below <= 0.0 or below > 1.0 or penalty < 0.0:
						errors.append("%s: morale.health_tiers[%d] fuera de rango (below en (0,1], penalty >= 0)" % [label, index])
				index += 1


func _validate_number_map(errors: Array[String], label: String, field: String, allowed: Array[String]) -> void:
	if not morale.has(field):
		return
	var value: Variant = morale[field]
	if not (value is Dictionary):
		errors.append("%s: morale.%s debe ser un diccionario" % [label, field])
		return
	var map: Dictionary = value
	for key in map.keys():
		if not allowed.has(String(key)):
			errors.append("%s: morale.%s contiene la clave desconocida '%s'" % [label, field, String(key)])
		elif not _is_number(map[key]) or float(map[key]) < 0.0:
			errors.append("%s: morale.%s.%s debe ser un número >= 0" % [label, field, String(key)])
