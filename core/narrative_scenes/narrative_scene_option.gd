class_name NarrativeSceneOption
extends Resource

## NarrativeSceneOption — Spike 1: Motor Narrativo Base
##
## Una opción dentro de una NarrativeSceneDefinition. Puede resolver
## directo (outcome_default) o requerir una tirada de habilidad, en cuyo
## caso el destino depende del grado de resultado devuelto por SkillRoller.
## El destino/consecuencias en sí viven en NarrativeSceneOutcome (fichero
## propio — ver ese fichero para por qué no es clase interna).
##
## NOTA (decisión de spike, ver docs/spike_1_narrativa_informe_cierre.md):
## SkillRoller.RollResult solo tiene 4 grados en Spike 1
## (FUMBLE, FAILURE, SUCCESS, CRITICAL). Un quinto grado "especial" se
## discutió durante el diseño y se difiere explícitamente a Spike 2 —
## no existe en SkillRoller hoy, por eso no hay outcome_special aquí.
##
## Progresión de skill narrativa (enganche vía SkillProgression.
## execute_learning_session / LearningSession) también se discutió y se
## difiere a Spike 2 — por eso no hay campo challenge_level en esta versión.
##
## NOTA: from_dict() usa new() en vez de NarrativeSceneOption.new() —
## autorreferenciar el propio class_name dentro del mismo script no se
## resuelve de forma fiable en GDScript. Ver narrative_scene_outcome.gd.

var option_id: String = ""
var text_key: String = ""

## Vacío = opción sin tirada, resuelve directo por outcome_default.
var skill_id: String = ""
var roll_modifier: int = 0

## Usado solo si skill_id está vacío.
var outcome_default: NarrativeSceneOutcome = null

## Usados solo si skill_id no está vacío. success/failure son obligatorios
## en la práctica (validate() los exige); fumble/critical son opcionales —
## si vienen null, get_outcome_for_grade() hace fallback a failure/success.
var outcome_fumble: NarrativeSceneOutcome = null
var outcome_failure: NarrativeSceneOutcome = null
var outcome_success: NarrativeSceneOutcome = null
var outcome_critical: NarrativeSceneOutcome = null


static func from_dict(data: Dictionary) -> NarrativeSceneOption:
	var option := new()
	option.option_id = data.get("option_id", "")
	option.text_key = data.get("text_key", "")
	option.skill_id = data.get("skill_id", "")
	option.roll_modifier = data.get("roll_modifier", 0)

	if data.has("outcome_default"):
		option.outcome_default = NarrativeSceneOutcome.from_dict(data["outcome_default"])
	if data.has("outcome_fumble"):
		option.outcome_fumble = NarrativeSceneOutcome.from_dict(data["outcome_fumble"])
	if data.has("outcome_failure"):
		option.outcome_failure = NarrativeSceneOutcome.from_dict(data["outcome_failure"])
	if data.has("outcome_success"):
		option.outcome_success = NarrativeSceneOutcome.from_dict(data["outcome_success"])
	if data.has("outcome_critical"):
		option.outcome_critical = NarrativeSceneOutcome.from_dict(data["outcome_critical"])

	return option


## Devuelve el outcome a aplicar para un grado de resultado dado.
## Fallback: FUMBLE sin definir → usa FAILURE. CRITICAL sin definir → usa SUCCESS.
func get_outcome_for_grade(grade: SkillRoller.RollResult) -> NarrativeSceneOutcome:
	match grade:
		SkillRoller.RollResult.FUMBLE:
			return outcome_fumble if outcome_fumble else outcome_failure
		SkillRoller.RollResult.FAILURE:
			return outcome_failure
		SkillRoller.RollResult.SUCCESS:
			return outcome_success
		SkillRoller.RollResult.CRITICAL:
			return outcome_critical if outcome_critical else outcome_success

	push_error("[NarrativeSceneOption] Grado de resultado desconocido: %s" % grade)
	return outcome_failure


## Validación mínima — llamada desde NarrativeSceneDefinition.validate().
func validate(owner_scene_id: String) -> bool:
	if option_id.is_empty():
		push_error("[NarrativeSceneOption] '%s': option_id vacío" % owner_scene_id)
		return false
	if text_key.is_empty():
		push_error("[NarrativeSceneOption] '%s.%s': text_key vacío" % [owner_scene_id, option_id])
		return false

	if skill_id.is_empty():
		if not outcome_default:
			push_error(
				"[NarrativeSceneOption] '%s.%s': sin skill_id necesita outcome_default"
				% [owner_scene_id, option_id]
			)
			return false
	else:
		if not outcome_failure or not outcome_success:
			push_error(
				"[NarrativeSceneOption] '%s.%s': con skill_id necesita outcome_failure y outcome_success como mínimo"
				% [owner_scene_id, option_id]
			)
			return false

	return true
