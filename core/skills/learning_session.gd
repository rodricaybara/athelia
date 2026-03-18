class_name LearningSession
extends RefCounted

## LearningSession - Value object que describe una sesión de aprendizaje fuera de combate
##
## RESPONSABILIDAD: Transportar los parámetros de una sesión de mejora
## entre quien la solicita (NPC entrenador, libro) y quien la ejecuta
## (SkillProgressionService.execute_learning_session).
##
## NO contiene lógica — es un contenedor de datos con validación mínima.
##
## FLUJOS QUE PRODUCEN UNA LearningSession:
##   - NPC entrenador → NarrativeEvent EVT_TRAINING_COMPLETE
##     → EventBus.learning_session_requested → SkillEventHandler → aquí
##   - Libro (consumible) → ItemCharacterBridge._apply_consumable
##     → learning_data en ItemDefinition → aquí

enum SourceType {
	TRAINER,  ## Entrenador NPC — nivel basado en su experiencia
	BOOK,     ## Libro — nivel basado en la dificultad del texto
	PRACTICE, ## Práctica libre — nivel más bajo, sin guía
}

## Entidad que aprende (normalmente "player")
var entity_id: String = ""

## Skill a mejorar
var skill_id: String = ""

## Nivel de la fuente — equivale al opposed_value en combate.
## Determina el anti-grinding: si source_level < 50% del valor actual, no hay mejora.
## Rango recomendado: 20–80.
var source_level: int = 30

## Tipo de fuente de aprendizaje
var source_type: SourceType = SourceType.TRAINER


## Constructor de conveniencia
static func create(
	p_entity_id: String,
	p_skill_id: String,
	p_source_level: int,
	p_source_type_str: String = "TRAINER"
) -> LearningSession:
	var session = LearningSession.new()
	session.entity_id   = p_entity_id
	session.skill_id    = p_skill_id
	session.source_level = p_source_level
	session.source_type  = _parse_source_type(p_source_type_str)
	return session


## Parsea el tipo desde String (para uso desde JSON/señales)
static func _parse_source_type(type_str: String) -> SourceType:
	match type_str.to_upper():
		"TRAINER":  return SourceType.TRAINER
		"BOOK":     return SourceType.BOOK
		"PRACTICE": return SourceType.PRACTICE
		_:
			push_warning("[LearningSession] Unknown source_type '%s', defaulting to TRAINER" % type_str)
			return SourceType.TRAINER


## Validación básica antes de ejecutar
func is_valid() -> bool:
	if entity_id.is_empty():
		push_error("[LearningSession] entity_id cannot be empty")
		return false
	if skill_id.is_empty():
		push_error("[LearningSession] skill_id cannot be empty")
		return false
	if source_level <= 0:
		push_error("[LearningSession] source_level must be > 0")
		return false
	return true


func _to_string() -> String:
	var type_names = ["TRAINER", "BOOK", "PRACTICE"]
	return "LearningSession(entity=%s, skill=%s, level=%d, source=%s)" % [
		entity_id, skill_id, source_level, type_names[source_type]
	]
