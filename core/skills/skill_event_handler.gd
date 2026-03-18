extends Node

## SkillEventHandler - Puente entre NarrativeSystem y SkillSystem
## Singleton: /root/SkillEventHandler
##
## RESPONSABILIDAD ÚNICA:
##   Escuchar peticiones de efectos de juego emitidas por NarrativeEventDefinition
##   y traducirlas a llamadas concretas a SkillSystem / SkillProgressionService.
##
## CONTRATO DE ARQUITECTURA:
##   - Es el ÚNICO punto donde el flujo narrativo cruza hacia SkillSystem.
##   - NarrativeEventDefinition NUNCA llama directamente a Skills.unlock_skill().
##   - Este handler NO tiene lógica de negocio propia — solo delega y loggea.


func _ready() -> void:
	EventBus.skill_unlock_requested.connect(_on_skill_unlock_requested)
	EventBus.learning_session_requested.connect(_on_learning_session_requested)
	print("[SkillEventHandler] Ready — listening for skill_unlock_requested, learning_session_requested")


# ==============================================
# DESBLOQUEO DE SKILLS
# ==============================================

## Recibe la petición emitida por NarrativeEventDefinition._emit_game_effect()
## y delega en SkillSystem, que es quien valida prerequisites y emite skill_unlocked.
func _on_skill_unlock_requested(entity_id: String, skill_id: String) -> void:
	print("[SkillEventHandler] unlock_requested ← entity=%s, skill=%s" % [entity_id, skill_id])
	
	# Verificar que la entidad tiene la skill registrada
	if not Skills.has_skill(entity_id, skill_id):
		push_warning("[SkillEventHandler] Entity '%s' does not have skill '%s' registered" % [entity_id, skill_id])
		return
	
	# Delegar — SkillSystem comprobará prerequisites (Fase B) y emitirá skill_unlocked o skill_unlock_failed
	var success = Skills.unlock_skill(entity_id, skill_id)
	
	if not success:
		print("[SkillEventHandler] unlock FAILED for '%s' on '%s' (prerequisites not met)" % [skill_id, entity_id])
	else:
		print("[SkillEventHandler] unlock OK — '%s' for '%s'" % [skill_id, entity_id])


# ==============================================
# LEARNING SESSIONS (preparado para Fase C)
# ==============================================

## Recibe la petición emitida por NarrativeEventDefinition._emit_game_effect()
## y construye + ejecuta una LearningSession via SkillProgressionService.
func _on_learning_session_requested(
	entity_id: String,
	skill_id: String,
	source_level: int,
	source_type: String
) -> void:
	print("[SkillEventHandler] learning_session_requested ← entity=%s, skill=%s, level=%d, type=%s" % [
		entity_id, skill_id, source_level, source_type
	])

	var progression = get_node_or_null("/root/SkillProgression")
	if not progression:
		push_error("[SkillEventHandler] SkillProgressionService not found at /root/SkillProgression")
		return

	var session = LearningSession.create(entity_id, skill_id, source_level, source_type)
	var result: Dictionary = progression.execute_learning_session(session)

	match result.get("reason", ""):
		"skill_locked":
			print("[SkillEventHandler] Sesión cancelada: '%s' está bloqueada para '%s'" % [skill_id, entity_id])
		"no_progression":
			print("[SkillEventHandler] Sesión cancelada: '%s' no tiene sistema de progresión" % skill_id)
		"challenge_too_low":
			print("[SkillEventHandler] Sesión cancelada: source_level %d demasiado bajo para '%s'" % [source_level, skill_id])
		"improved":
			print("[SkillEventHandler] ✓ '%s' mejorada: %d → %d" % [skill_id, result["old_value"], result["new_value"]])
		"roll_failed":
			print("[SkillEventHandler] La sesión no produjo mejora (roll %d vs threshold %d)" % [result["roll"], result["threshold"]])
