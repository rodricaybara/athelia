class_name NarrativeSceneOption
extends Resource

## NarrativeSceneOption — Spike 1: Motor Narrativo Base / Spike 2: grado SPECIAL
## y progresión de skill narrativa
##
## Una opción dentro de una NarrativeSceneDefinition. Puede resolver
## directo (outcome_default) o requerir una tirada de habilidad, en cuyo
## caso el destino depende del grado de resultado devuelto por SkillRoller.
## El destino/consecuencias en sí viven en NarrativeSceneOutcome (fichero
## propio — ver ese fichero para por qué no es clase interna).
##
## NOTA (Spike 2, punto 1): SkillRoller.RollResult tiene ahora 5 grados
## (FUMBLE, FAILURE, SUCCESS, SPECIAL, CRITICAL) — outcome_special añadido
## con el mismo patrón de fallback ya usado para fumble/critical en Spike 1.
##
## NOTA (Spike 2, punto 2): challenge_level habilita progresión de skill vía
## SkillProgression.execute_learning_session() (SourceType.NARRATIVE). Es
## opt-in explícito del autor de la escena: por defecto es 0, que significa
## "esta opción no ofrece progresión" — no toda tirada narrativa tiene por
## qué dar opción a mejorar la skill. Solo si es > 0, y solo en tiradas
## exitosas (SUCCESS/SPECIAL/CRITICAL), NarrativeSceneViewModel intenta la
## mejora — misma filosofía que combate, donde solo el éxito genera tick.
## El valor se pasa tal cual como LearningSession.source_level (el anti-
## grinding de SkillProgressionService exige que sea al menos el 50% del
## valor actual de la skill; rango recomendado 20–80, igual que el resto de
## LearningSession).
##
## NOTA: from_dict() usa new() en vez de NarrativeSceneOption.new() —
## autorreferenciar el propio class_name dentro del mismo script no se
## resuelve de forma fiable en GDScript. Ver narrative_scene_outcome.gd.

var option_id: String = ""
var text_key: String = ""

## Vacío = opción sin tirada, resuelve directo por outcome_default.
var skill_id: String = ""
var roll_modifier: int = 0

## Spike 2, punto 2 — ver nota de cabecera. 0 = sin progresión para esta
## opción (comportamiento por defecto, igual que antes de Spike 2).
var challenge_level: int = 0

## Usado solo si skill_id está vacío.
var outcome_default: NarrativeSceneOutcome = null

## Usados solo si skill_id no está vacío. success/failure son obligatorios
## en la práctica (validate() los exige); fumble/special/critical son
## opcionales — si vienen null, get_outcome_for_grade() hace fallback:
## fumble→failure, special→success, critical→success.
var outcome_fumble: NarrativeSceneOutcome = null
var outcome_failure: NarrativeSceneOutcome = null
var outcome_success: NarrativeSceneOutcome = null
var outcome_special: NarrativeSceneOutcome = null
var outcome_critical: NarrativeSceneOutcome = null


static func from_dict(data: Dictionary) -> NarrativeSceneOption:
	var option := new()
	option.option_id = data.get("option_id", "")
	option.text_key = data.get("text_key", "")
	option.skill_id = data.get("skill_id", "")
	option.roll_modifier = data.get("roll_modifier", 0)
	option.challenge_level = data.get("challenge_level", 0)

	if data.has("outcome_default"):
		option.outcome_default = NarrativeSceneOutcome.from_dict(data["outcome_default"])
	if data.has("outcome_fumble"):
		option.outcome_fumble = NarrativeSceneOutcome.from_dict(data["outcome_fumble"])
	if data.has("outcome_failure"):
		option.outcome_failure = NarrativeSceneOutcome.from_dict(data["outcome_failure"])
	if data.has("outcome_success"):
		option.outcome_success = NarrativeSceneOutcome.from_dict(data["outcome_success"])
	if data.has("outcome_special"):
		option.outcome_special = NarrativeSceneOutcome.from_dict(data["outcome_special"])
	if data.has("outcome_critical"):
		option.outcome_critical = NarrativeSceneOutcome.from_dict(data["outcome_critical"])

	return option


## Devuelve el outcome a aplicar para un grado de resultado dado.
## Fallback: FUMBLE sin definir → usa FAILURE. SPECIAL sin definir → usa
## SUCCESS. CRITICAL sin definir → usa SUCCESS. Mismo criterio en los tres
## casos: degradar hacia el tier "normal" más cercano (failure o success)
## en vez de inventar una regla nueva por grado.
func get_outcome_for_grade(grade: SkillRoller.RollResult) -> NarrativeSceneOutcome:
	match grade:
		SkillRoller.RollResult.FUMBLE:
			return outcome_fumble if outcome_fumble else outcome_failure
		SkillRoller.RollResult.FAILURE:
			return outcome_failure
		SkillRoller.RollResult.SUCCESS:
			return outcome_success
		SkillRoller.RollResult.SPECIAL:
			return outcome_special if outcome_special else outcome_success
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
		if challenge_level > 0:
			push_warning(
				"[NarrativeSceneOption] '%s.%s': challenge_level %d definido sin skill_id — no hay tirada, se ignora"
				% [owner_scene_id, option_id, challenge_level]
			)
	else:
		if not outcome_failure or not outcome_success:
			push_error(
				"[NarrativeSceneOption] '%s.%s': con skill_id necesita outcome_failure y outcome_success como mínimo"
				% [owner_scene_id, option_id]
			)
			return false

	return true
