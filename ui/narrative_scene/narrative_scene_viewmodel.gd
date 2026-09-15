class_name NarrativeSceneViewModel
extends Node

## NarrativeSceneViewModel — Spike 1: Motor Narrativo Base
## Spike 2: progresión de skill narrativa (punto 2), tiradas acumulativas
## con contador (punto 3), tiradas agregadas de grupo (punto 4)
##
## Sigue el contrato MVVM estándar del proyecto (docs/athelia_ui_architecture.md):
## enum de estados, señal única changed(reason), métodos de intención
## open()/request_option(). Siempre hijo de NarrativeScenePanel — muere con ella.
##
## Consume SkillRoller (tirada), Characters (valor de skill) y Party (miembros
## activos del grupo) sin tocar su lógica interna. Aplica consecuencias contra
## Narrative (flags) y GameLoop (combate) — todos ya existentes, sin sistemas
## nuevos inventados.
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
## challenge_level > 0) y solo en tiradas exitosas — ver _try_narrative_progression().
##
## Tiradas acumulativas (Spike 2, punto 3): el contador de racha de éxitos
## vive aquí (_success_streaks), nunca en NarrativeSceneDB (sigue siendo solo
## consulta síncrona sin estado — decisión de Spike 1) ni en NarrativeSceneOption
## (se recarga desde JSON en cada consulta, no es sitio para estado mutable de
## partida). Se reinicia solo al completar/perder la racha, o implícitamente al
## salir de la escena (el overlay se destruye e instancia de nuevo en cada
## apertura — no hace falta limpieza explícita). Ver _handle_accumulative_roll().
##
## Tiradas agregadas de grupo (Spike 2, punto 4): sin cambios en Party ni en
## Characters — _get_group_entity_ids() combina GameLoop.PLAYER_ID + Party.
## get_active_members() (los incapacitados no participan), y
## _get_effective_skill_value() reduce sus valores de skill a peor/mejor.
## No hay tirada opuesta real (segunda tirada de NPC / tabla de resistencia):
## la "oposición" se codifica en roll_modifier, decisión explícita por
## coste-beneficio. Si la opción también da progresión (challenge_level > 0),
## CADA miembro del grupo intenta su propia mejora de forma independiente —
## nunca un resultado de progresión compartido.

## NOTA: el enum de estados se llama PanelState, no SceneState — "SceneState"
## es una clase nativa del motor (usada por PackedScene) y el nombre colisiona
## si se reutiliza como class member. Sigue el nombre del ejemplo de contrato
## en athelia_ui_architecture.md.
enum PanelState { HIDDEN, SHOWING, WAITING_ROLL, TRANSITIONING }

## Razones:
##   "opened"          → render completo del nodo inicial
##   "node_changed"     → nuevo nodo tras resolver una opción, render completo
##                        (misma acción de render que "opened"; se distingue
##                        por si en el futuro la View quiere una transición
##                        distinta entre nodo inicial y nodo siguiente)
##   "streak_progress"  → tirada acumulativa procesada sin completar ni perder
##                        la racha definitivamente (éxito parcial, o fallo con
##                        retry_policy "immediate"). El nodo NO cambia — la
##                        View debe quedarse en el mismo render y, si quiere,
##                        mostrar streak_current/streak_required. No se aplica
##                        ningún NarrativeSceneOutcome en este caso.
##   "closed"           → ocultar panel (el nodo se destruye aparte, vía
##                        SceneOrchestrator, al volver a EXPLORATION o entrar
##                        en COMBAT_ACTIVE)
##
## NOTA: WAITING_ROLL existe en el enum pero no se emite en Spike 1 —
## SkillRoller.roll_skill() es síncrono, no hay ventana real de espera.
## Se reserva para una futura tirada animada/asíncrona (fuera de alcance
## de este spike).
signal changed(reason: String)

var state: PanelState = PanelState.HIDDEN
var current_node: NarrativeSceneDefinition = null

## Progreso de la racha de éxitos de la última tirada acumulativa procesada.
## Solo válido leerlo justo después de recibir changed("streak_progress").
var streak_option_id: String = ""
var streak_current: int = 0
var streak_required: int = 0

## Spike 2, punto 3 — contador de éxitos seguidos por opción. option_id → int.
var _success_streaks: Dictionary = {}


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

	if option.skill_id.is_empty():
		_apply_outcome(option.outcome_default)
		return

	var skill_value: int = _get_effective_skill_value(option)
	var roll: Dictionary = SkillRoller.roll_skill(skill_value + option.roll_modifier)
	SkillRoller.print_roll_result(roll, "NarrativeScene:%s" % option.skill_id)

	if option.required_successes > 0:
		_handle_accumulative_roll(option, roll)
	else:
		_try_narrative_progression(option, roll)
		_apply_outcome(option.get_outcome_for_grade(roll.result))


# ============================================
# INTERNO
# ============================================

## Spike 2, punto 4 — entidades que participan en una opción.
## Sin group_aggregate: solo el jugador (comportamiento idéntico a antes de
## este punto). Con group_aggregate ("worst"/"best"): jugador + companions
## activos (Party.get_active_members() ya excluye incapacitados). Se
## reutiliza tanto para el valor efectivo de la tirada como para la
## progresión de skill (punto 2).
func _get_group_entity_ids(option: NarrativeSceneOption) -> Array[String]:
	var ids: Array[String] = [GameLoop.PLAYER_ID]
	if not option.group_aggregate.is_empty():
		ids.append_array(Party.get_active_members())
	return ids


## Spike 2, punto 4 — valor de skill usado para la tirada. Sin
## group_aggregate, es el valor individual del jugador (igual que siempre).
## Con group_aggregate, es el peor o mejor valor de skill_id entre jugador +
## companions activos. Un group_aggregate no reconocido (avisado ya en
## validate()) se trata como "worst".
func _get_effective_skill_value(option: NarrativeSceneOption) -> int:
	if option.group_aggregate.is_empty():
		return Characters.get_skill_value(GameLoop.PLAYER_ID, option.skill_id)

	var values: Array[int] = []
	for entity_id in _get_group_entity_ids(option):
		values.append(Characters.get_skill_value(entity_id, option.skill_id))

	if option.group_aggregate == "best":
		return values.max()
	else:  # "worst" (default, incluye cualquier valor no reconocido)
		return values.min()


## Spike 2, punto 3 — resuelve una tirada de una opción con required_successes > 0.
## Reglas (confirmadas explícitamente, no son consecuencia directa del spec):
##   - PIFIA siempre transiciona (ignora retry_policy) — consecuencia dramática
##     propia, no un simple "vuelve a intentarlo".
##   - Progresión de skill (punto 2) solo se intenta al COMPLETAR la racha
##     entera, nunca en un éxito parcial — evita una vía de grinding que el
##     anti-grind de SkillProgressionService no está pensado para frenar
##     (limita el umbral de dificultad, no la frecuencia de intentos).
##   - "blocked": un fallo normal (no fumble) transiciona de verdad — es el
##     propio grafo narrativo el que impide el reintento infinito, sin
##     necesidad de un sistema de flags nuevo.
func _handle_accumulative_roll(option: NarrativeSceneOption, roll: Dictionary) -> void:
	var is_fumble: bool = (roll.result == SkillRoller.RollResult.FUMBLE)

	if is_fumble:
		_success_streaks.erase(option.option_id)
		_apply_outcome(option.get_outcome_for_grade(roll.result))
		return

	if roll.success:
		var current: int = _success_streaks.get(option.option_id, 0) + 1

		if current >= option.required_successes:
			_success_streaks.erase(option.option_id)
			_try_narrative_progression(option, roll)
			_apply_outcome(option.get_outcome_for_grade(roll.result))
		else:
			_success_streaks[option.option_id] = current
			_emit_streak_progress(option, current)
		return

	# Fallo normal (no fumble): el contador siempre se reinicia
	_success_streaks.erase(option.option_id)

	if option.retry_policy == "blocked":
		_apply_outcome(option.get_outcome_for_grade(roll.result))
	else:
		# "immediate" (o un valor no reconocido — ya avisado en validate()):
		# te quedas en el mismo nodo, reintento inmediato
		_emit_streak_progress(option, 0)


func _emit_streak_progress(option: NarrativeSceneOption, current: int) -> void:
	streak_option_id = option.option_id
	streak_current = current
	streak_required = option.required_successes
	changed.emit("streak_progress")


## Spike 2, punto 2 — intenta una mejora de skill fuera de combate.
## Opt-in explícito: solo si la opción define challenge_level > 0 (ver
## NarrativeSceneOption). Gateado en éxito (SUCCESS/SPECIAL/CRITICAL) —
## misma filosofía que combate, donde solo el éxito genera oportunidad de
## mejora (SkillProgressionService._handle_success vs _handle_failure).
## No usa notify_skill_outcome(): ese camino está hard-gated a
## _combat_active y aquí no estamos en combate.
##
## Spike 2, punto 4: en una opción de grupo, cada miembro (jugador +
## companions activos) intenta su propia LearningSession de forma
## independiente contra su propio valor de skill — nunca un resultado
## compartido. Para una opción normal (sin group_aggregate),
## _get_group_entity_ids() devuelve solo [player], así que el comportamiento
## es idéntico al del punto 2 antes de este punto.
func _try_narrative_progression(option: NarrativeSceneOption, roll: Dictionary) -> void:
	if option.challenge_level <= 0:
		return
	if not roll.success:
		return

	for entity_id in _get_group_entity_ids(option):
		var session := LearningSession.create(
			entity_id,
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

# PATCH — narrative_scene_viewmodel.gd
#
# Reemplaza el método _apply_outcome() completo por esta versión. Dos
# cambios: (1) otorgar ítem, independiente de si el outcome también
# encadena escena o dispara combate; (2) combat_encounter se pasa a
# start_combat() en vez de omitirse — null por defecto, mismo
# comportamiento que antes si el outcome no lo usa.

func _apply_outcome(outcome: NarrativeSceneOutcome) -> void:
	if not outcome:
		push_error("[NarrativeSceneViewModel] Outcome nulo — cerrando escena por seguridad")
		_close()
		return
 
	if not outcome.flag_to_set.is_empty():
		Narrative.set_flag(outcome.flag_to_set)
 
	# Spike 3, Grupo B — otorgar ítem: entrega puntual, independiente de si
	# el outcome además dispara combate o encadena a otra escena.
	if not outcome.grant_item_id.is_empty():
		Inventory.add_item(outcome.grant_item_target, outcome.grant_item_id, outcome.grant_item_quantity)
 
	if not outcome.combat_enemy_ids.is_empty():
		# GameLoop.start_combat() ya acepta NARRATIVE_SCENE como estado de
		# origen — no hace falta pasar por EXPLORATION antes.
		# _transition_game_state() a COMBAT_ACTIVE disparará game_state_changed,
		# y SceneOrchestrator._handle_combat() destruye este overlay igual que
		# hace con Shop/Dialogue.
		state = PanelState.TRANSITIONING
		changed.emit("closed")
 
		_register_combat_enemies(outcome.combat_enemy_ids, outcome.combat_enemy_definitions)
 
		var loot_spawner = get_node_or_null("/root/CombatLootSpawner")
		if loot_spawner:
			loot_spawner.register_combat_enemies(outcome.combat_enemy_definitions)
 
		# Spike 3, Grupo B — combat_encounter es opcional (null = comportamiento
		# idéntico a antes de este punto, sin moral/refuerzos/sorpresa).
		GameLoop.start_combat(outcome.combat_enemy_ids, outcome.combat_encounter)
		return
 
	if outcome.next_scene_id.is_empty():
		_close()
	else:
		_load_scene(outcome.next_scene_id, "node_changed")
 
 
## Réplica deliberada de ExplorationController._register_combat_enemies()
## — ver nota arriba. Registra cada enemigo en CharacterSystem (para que
## _calculate_initiative() lo encuentre) y en ResourceSystem con 50.0 HP
## fijo, igual que el camino de combate desde exploración.
func _register_combat_enemies(enemy_ids: Array[String], definitions: Dictionary) -> void:
	var chars: CharacterSystem = get_node_or_null("/root/Characters")
	var resources: ResourceSystem = get_node_or_null("/root/Resources")
 
	for enemy_id in enemy_ids:
		var def_id: String = definitions.get(enemy_id, "enemy_base")
 
		if chars and not chars.has_entity(enemy_id):
			if chars.has_definition(def_id):
				chars.register_entity(enemy_id, def_id)
			else:
				push_warning("[NarrativeSceneViewModel] definition '%s' not found for %s — falling back to enemy_base" % [def_id, enemy_id])
				if chars.has_definition("enemy_base"):
					chars.register_entity(enemy_id, "enemy_base")
 
		resources.register_entity(enemy_id)
		resources.set_resource(enemy_id, "health", 50.0)
 
		print("[NarrativeSceneViewModel] Pre-registered enemy: %s (def: %s)" % [enemy_id, def_id])

func _close() -> void:
	state = PanelState.HIDDEN
	var closing_scene_id: String = current_node.scene_id if current_node else ""
	current_node = null
	changed.emit("closed")
	EventBus.narrative_scene_closed.emit(closing_scene_id)
