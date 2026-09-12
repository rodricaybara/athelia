class_name NarrativeSceneViewModel
extends Node

## NarrativeSceneViewModel — Spike 1: Motor Narrativo Base / Spike 2, punto 2:
## progresión de skill narrativa
##
## Sigue el contrato MVVM estándar del proyecto (docs/athelia_ui_architecture.md):
## enum de estados, señal única changed(reason), métodos de intención
## open()/request_option(). Siempre hijo de NarrativeScenePanel — muere con ella.
##
## Consume SkillRoller (tirada) y Characters (valor de skill) sin tocar su
## lógica interna. Aplica consecuencias contra Narrative (flags) y GameLoop
## (combate) — ambos ya existentes, sin sistemas nuevos inventados.
##
## Cierre: emite EventBus.narrative_scene_closed en vez de llamar a GameLoop
## directamente — mismo patrón desacoplado que DialogueViewModel (dialogue_ended)
## y EconomySystem (shop_closed). SceneOrchestrator escucha y decide volver a
## EXPLORATION; este ViewModel no conoce GameLoop para cerrar, solo para
## disparar combate (ver _apply_outcome).
##
## Progresión de skill narrativa (Spike 2, punto 2): enganchada vía
## SkillProgression.execute_learning_session() (SourceType.NARRATIVE), NO
## notify_skill_outcome() — ese está hard-gated a _combat_active y esto pasa
## en EXPLORATION/NARRATIVE_SCENE. Opt-in por opción (NarrativeSceneOption.
## challenge_level > 0) y solo en tiradas exitosas — ver request_option().

## NOTA: el enum de estados se llama PanelState, no SceneState — "SceneState"
## es una clase nativa del motor (usada por PackedScene) y el nombre colisiona
## si se reutiliza como class member. Sigue el nombre del ejemplo de contrato
## en athelia_ui_architecture.md.
enum PanelState { HIDDEN, SHOWING, WAITING_ROLL, TRANSITIONING }

## Razones:
##   "opened"       → render completo del nodo inicial
##   "node_changed" → nuevo nodo tras resolver una opción, render completo
##                     (misma acción de render que "opened"; se distingue
##                     por si en el futuro la View quiere una transición
##                     distinta entre nodo inicial y nodo siguiente)
##   "closed"       → ocultar panel (el nodo se destruye aparte, vía
##                     SceneOrchestrator, al volver a EXPLORATION o entrar
##                     en COMBAT_ACTIVE)
##
## NOTA: WAITING_ROLL existe en el enum pero no se emite en Spike 1 —
## SkillRoller.roll_skill() es síncrono, no hay ventana real de espera.
## Se reserva para una futura tirada animada/asíncrona (fuera de alcance
## de este spike).
signal changed(reason: String)

var state: PanelState = PanelState.HIDDEN
var current_node: NarrativeSceneDefinition = null


func open(scene_id: String) -> void:
	_load_scene(scene_id, "opened")


func request_option(option_id: String) -> void:
	if state != PanelState.SHOWING:
		push_warning("[NarrativeSceneViewModel] request_option ignorado: estado %s" % state)
		return

	var option := _find_option(option_id)
	if not option:
		push_error("[NarrativeSceneViewModel] Opción no encontrada: %s" % option_id)
		return

	var outcome: NarrativeSceneOutcome

	if option.skill_id.is_empty():
		outcome = option.outcome_default
	else:
		var skill_value: int = Characters.get_skill_value(GameLoop.PLAYER_ID, option.skill_id)
		var roll: Dictionary = SkillRoller.roll_skill(skill_value + option.roll_modifier)
		outcome = option.get_outcome_for_grade(roll.result)
		SkillRoller.print_roll_result(roll, "NarrativeScene:%s" % option.skill_id)

		_try_narrative_progression(option, roll)

	_apply_outcome(outcome)


# ============================================
# INTERNO
# ============================================

## Spike 2, punto 2 — intenta una mejora de skill fuera de combate.
## Opt-in explícito: solo si la opción define challenge_level > 0 (ver
## NarrativeSceneOption). Gateado en éxito (SUCCESS/SPECIAL/CRITICAL) —
## misma filosofía que combate, donde solo el éxito genera oportunidad de
## mejora (SkillProgressionService._handle_success vs _handle_failure).
## No usa notify_skill_outcome(): ese camino está hard-gated a
## _combat_active y aquí no estamos en combate.
func _try_narrative_progression(option: NarrativeSceneOption, roll: Dictionary) -> void:
	if option.challenge_level <= 0:
		return
	if not roll.success:
		return

	var session := LearningSession.create(
		GameLoop.PLAYER_ID,
		option.skill_id,
		option.challenge_level,
		"NARRATIVE"
	)
	SkillProgression.execute_learning_session(session)


func _load_scene(scene_id: String, reason: String) -> void:
	var scene := NarrativeSceneDB.get_scene(scene_id)
	if not scene:
		push_error("[NarrativeSceneViewModel] No se pudo cargar escena: %s" % scene_id)
		return

	current_node = scene
	state = PanelState.SHOWING
	changed.emit(reason)


func _find_option(option_id: String) -> NarrativeSceneOption:
	if not current_node:
		return null
	for option in current_node.options:
		if option.option_id == option_id:
			return option
	return null


func _apply_outcome(outcome: NarrativeSceneOutcome) -> void:
	if not outcome:
		push_error("[NarrativeSceneViewModel] Outcome nulo — cerrando escena por seguridad")
		_close()
		return

	if not outcome.flag_to_set.is_empty():
		Narrative.set_flag(outcome.flag_to_set)

	if not outcome.combat_enemy_ids.is_empty():
		# GameLoop.start_combat() ya acepta NARRATIVE_SCENE como estado de
		# origen (ver patch_game_loop_system.md) — no hace falta pasar por
		# EXPLORATION antes. _transition_game_state() a COMBAT_ACTIVE disparará
		# game_state_changed, y SceneOrchestrator._handle_combat() destruye
		# este overlay igual que hace con Shop/Dialogue.
		state = PanelState.TRANSITIONING
		changed.emit("closed")
		GameLoop.start_combat(outcome.combat_enemy_ids)
		return

	if outcome.next_scene_id.is_empty():
		_close()
	else:
		_load_scene(outcome.next_scene_id, "node_changed")


func _close() -> void:
	state = PanelState.HIDDEN
	var closing_scene_id: String = current_node.scene_id if current_node else ""
	current_node = null
	changed.emit("closed")
	EventBus.narrative_scene_closed.emit(closing_scene_id)
