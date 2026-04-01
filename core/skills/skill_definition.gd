class_name SkillDefinition
extends Resource

## SkillDefinition - Definición inmutable de una habilidad
## Parte del SkillSystem
## Representa QUÉ ES una habilidad (datos estáticos)
##
## v3: Añadidos subcategory y prerequisite_requirements.
##     Eliminado prerequisites: Array[String] — reemplazado por prerequisite_requirements.
##     Todos los .tres existentes sin estos campos usan defaults seguros.

# ============================================
# BLOQUE ORIGINAL — sin cambios
# ============================================

@export var id: String = ""
@export var name_key: String = ""
@export var description_key: String = ""

@export_enum("COMBAT", "EXPLORATION", "DIALOGUE", "NARRATIVE") var mode: String = "EXPLORATION"
@export_enum("PHYSICAL", "MENTAL", "MAGIC", "UTILITY") var category: String = "PHYSICAL"

## Subcategoría para agrupación en UI (árbol de habilidades, filtros).
## Independiente de mode — permite granularidad mayor.
## Ej: mode=COMBAT puede tener subcategory=MELEE o subcategory=RANGED.
@export_enum("MELEE", "RANGED", "EXPLORATION", "DIALOGUE", "NARRATIVE", "ENEMY", "NONE") var subcategory: String = "NONE"

@export var costs: Dictionary = {}
@export var base_cooldown: float = 0.0

@export_enum("SELF", "SINGLE_ENEMY", "MULTI_ENEMY", "AREA") var target_type: String = "SELF"
@export_enum("MELEE", "SHORT", "MEDIUM", "LONG") var range_type: String = "MELEE"

@export var effects: Array = []
@export var tags: Array[String] = []


# ============================================
# BLOQUE PROGRESSION — v2, sin cambios salvo prerequisites
# ============================================

@export var base_success_rate: int = 0
@export_enum("PHYSICAL", "MENTAL") var stress_type: String = "PHYSICAL"
@export var attribute_weights: Dictionary = {}

## Requisitos para desbloquear esta habilidad.
## Formato: { "skill_id": umbral_int }
## Ejemplo: { "espada": 50 } — requiere Espada con al menos 50% para desbloquear esta skill.
## Vacío = sin requisitos, disponible desde el inicio (si requires_unlock=false).
##
## REEMPLAZA al antiguo prerequisites: Array[String].
## Para obtener solo los IDs: prerequisite_requirements.keys()
## Para obtener el umbral de un prereq: prerequisite_requirements.get("skill_id", 0)
@export var prerequisite_requirements: Dictionary = {}

@export var difficulty: float = 1.0
@export var max_ticks_per_combat: int = 0
@export var difficulty_scaling: Dictionary = {}

## Si true, la skill empieza bloqueada y requiere desbloqueo narrativo adicional
## por encima de cumplir los prerequisite_requirements.
## Si false (default), se desbloquea automáticamente en cuanto se cumplen los requisitos.
@export var requires_unlock: bool = false


# ============================================
# VALIDACIÓN ORIGINAL — actualizada para prerequisite_requirements
# ============================================

func validate() -> bool:
	if id.is_empty():
		push_error("[SkillDefinition] id cannot be empty")
		return false

	if name_key.is_empty():
		push_error("[SkillDefinition] name_key cannot be empty")
		return false

	if base_cooldown < 0.0:
		push_error("[SkillDefinition] base_cooldown cannot be negative")
		return false

	for resource_id in costs.keys():
		if costs[resource_id] < 0:
			push_error("[SkillDefinition] cost for '%s' cannot be negative" % resource_id)
			return false

	for prereq_id in prerequisite_requirements.keys():
		var threshold: int = prerequisite_requirements[prereq_id]
		if threshold < 0 or threshold > 100:
			push_error("[SkillDefinition] prerequisite threshold for '%s' out of range [0,100]: %s" % [prereq_id, id])
			return false

	return true


# ============================================
# VALIDACIÓN DE PROGRESIÓN — v2, sin cambios
# ============================================

func validate_progression() -> bool:
	if base_success_rate == 0:
		return true

	if base_success_rate < 0 or base_success_rate > 100:
		push_error("[SkillDefinition] base_success_rate out of range [0,100]: %s" % id)
		return false

	if difficulty <= 0.0:
		push_error("[SkillDefinition] difficulty must be > 0: %s" % id)
		return false

	if not attribute_weights.is_empty():
		var total_weight: float = 0.0
		for w in attribute_weights.values():
			total_weight += float(w)
		if total_weight <= 0.0:
			push_error("[SkillDefinition] attribute_weights must sum > 0: %s" % id)
			return false

	return true


# ============================================
# HELPERS
# ============================================

func has_progression() -> bool:
	return base_success_rate > 0

func has_cost() -> bool:
	return not costs.is_empty()

func has_prerequisites() -> bool:
	return not prerequisite_requirements.is_empty()

## IDs de las skills requeridas (sin umbrales).
## Equivalente al antiguo prerequisites: Array[String].
func get_prerequisite_ids() -> Array:
	return prerequisite_requirements.keys()

## Umbral mínimo requerido para una skill prereq concreta.
## Devuelve 0 si el prereq no existe (sin umbral = solo necesita estar desbloqueada).
func get_prerequisite_threshold(prereq_skill_id: String) -> int:
	return prerequisite_requirements.get(prereq_skill_id, 0)

func get_cost(resource_id: String) -> float:
	return costs.get(resource_id, 0.0)

func get_cost_bundle() -> ResourceBundle:
	var bundle := ResourceBundle.new()
	for res_id in costs.keys():
		bundle.add_cost(res_id, costs[res_id])
	return bundle

func get_difficulty_penalty(current_value: int) -> int:
	var penalty: int = 0
	for threshold_key in difficulty_scaling.keys():
		if current_value >= int(threshold_key):
			penalty = int(difficulty_scaling[threshold_key])
	return penalty

func duplicate_definition() -> SkillDefinition:
	var copy := SkillDefinition.new()
	copy.id = id
	copy.name_key = name_key
	copy.description_key = description_key
	copy.mode = mode
	copy.category = category
	copy.subcategory = subcategory
	copy.costs = costs.duplicate()
	copy.base_cooldown = base_cooldown
	copy.target_type = target_type
	copy.range_type = range_type
	copy.effects = effects.duplicate()
	copy.tags = tags.duplicate()
	copy.base_success_rate = base_success_rate
	copy.stress_type = stress_type
	copy.attribute_weights = attribute_weights.duplicate()
	copy.prerequisite_requirements = prerequisite_requirements.duplicate()
	copy.difficulty = difficulty
	copy.max_ticks_per_combat = max_ticks_per_combat
	copy.difficulty_scaling = difficulty_scaling.duplicate()
	copy.requires_unlock = requires_unlock
	return copy

func _to_string() -> String:
	var prereq_str: String = ""
	if has_prerequisites():
		prereq_str = " | prereqs=%s" % str(prerequisite_requirements)
	if has_progression():
		return "SkillDefinition(id=%s, sr=%d%%, sub=%s%s)" % [id, base_success_rate, subcategory, prereq_str]
	return "SkillDefinition(id=%s, sub=%s%s)" % [id, subcategory, prereq_str]
