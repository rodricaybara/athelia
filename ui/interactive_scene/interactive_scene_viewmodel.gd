class_name InteractiveSceneViewModel
extends Node

## InteractiveSceneViewModel — Spike 12: motor de escenas interactivas
##
## Contrato MVVM habitual: la View escucha changed(reason) y lee las
## propiedades públicas; nunca await en la View.
##
## Responsabilidades:
##  - Cargar una InteractiveSceneDefinition desde InteractiveSceneDB.
##  - Calcular qué hotspots son visibles (required_flags / blocked_flags
##    contra el autoload Narrative). DECLARATIVO: se recalcula al cargar
##    la escena y cada vez que GameState vuelve a EXPLORATION. No hay
##    spawn/cleanup por evento (a diferencia de telmori_sheriff_reward).
##  - Validar y emitir hotspot_activated(). NO enruta: quien enruta es
##    ExplorationController.request_interaction() (contrato único de
##    routing del proyecto).

signal changed(reason: String)

## (interaction_type, target_id efectivo, enemy_definitions)
signal hotspot_activated(interaction_type: String, target_id: String, enemy_definitions: Dictionary)

const REASON_SCENE_LOADED := "scene_loaded"
const REASON_HOTSPOTS_REFRESHED := "hotspots_refreshed"

var scene_definition: InteractiveSceneDefinition = null
var background_path: String = ""
var visible_hotspots: Array[InteractiveHotspotDefinition] = []


func _ready() -> void:
	# Método con nombre (no lambda) — ver lecciones sobre "Lambda capture was freed".
	EventBus.game_state_changed.connect(_on_game_state_changed)


# ============================================
# API PÚBLICA
# ============================================

func load_scene(scene_id: String) -> bool:
	var registry := get_node_or_null("/root/InteractiveSceneDB") as InteractiveSceneRegistry
	if registry == null:
		push_error("[InteractiveSceneViewModel] InteractiveSceneDB autoload not found — ¿registrado en Project Settings?")
		return false

	var definition := registry.get_scene(scene_id)
	if definition == null:
		return false

	scene_definition = definition
	background_path = definition.image_path
	_warn_about_missing_narrative_targets()

	_recalculate_visible_hotspots()
	changed.emit(REASON_SCENE_LOADED)
	return true


func refresh() -> void:
	if scene_definition == null:
		return
	_recalculate_visible_hotspots()
	changed.emit(REASON_HOTSPOTS_REFRESHED)


## Llamado por la View al hacer clic. Valida primero, después emite.
## Devuelve true si la activación se emitió.
func activate_hotspot(hotspot_id: String) -> bool:
	# Segundo punto de entrada de input: necesita su propio guard de estado
	# (mismo motivo que ExplorationHUD._unhandled_input). Exigimos
	# EXPLORATION explícitamente — is_input_blocked() por sí solo dejaría
	# pasar PAUSE y MENU.
	var game_loop := get_node_or_null("/root/GameLoop") as GameLoopSystem
	if game_loop == null:
		push_error("[InteractiveSceneViewModel] GameLoop not found")
		return false
	if game_loop.current_game_state != GameLoopSystem.GameState.EXPLORATION:
		print("[InteractiveSceneViewModel] Click ignorado — estado: %s" % game_loop.get_state_name())
		return false

	var hotspot := _find_visible_hotspot(hotspot_id)
	if hotspot == null:
		push_warning("[InteractiveSceneViewModel] Hotspot no visible o inexistente: %s" % hotspot_id)
		return false

	print("[InteractiveSceneViewModel] Hotspot activado: %s (%s → %s)" % [
		hotspot.hotspot_id, hotspot.interaction_type, hotspot.get_effective_target_id()])
	hotspot_activated.emit(
		hotspot.interaction_type,
		hotspot.get_effective_target_id(),
		hotspot.enemy_definitions
	)
	return true

## Spike 13 — dispara la acción de primera visita, si la escena la define y aún
## no se hizo. Reutiliza hotspot_activated: el mapa ya reenvía eso a
## ExplorationController.request_interaction(). Solo actúa en EXPLORATION
## (mismo motivo que el guard de activate_hotspot: evita transiciones reentrantes
## si la escena se ejecuta suelta desde el editor o se carga en otro estado).
func request_first_visit() -> bool:
	if scene_definition == null or not scene_definition.has_first_visit():
		return false
	var narrative := get_node_or_null("/root/Narrative")
	var game_loop := get_node_or_null("/root/GameLoop") as GameLoopSystem
	if narrative == null or game_loop == null:
		return false
	if game_loop.current_game_state != GameLoopSystem.GameState.EXPLORATION:
		return false
	if narrative.has_flag(scene_definition.on_first_visit_flag):
		return false

	narrative.set_flag(scene_definition.on_first_visit_flag)
	print("[InteractiveSceneViewModel] Primera visita: %s → %s" % [
		scene_definition.on_first_visit_type, scene_definition.on_first_visit_target_id])
	hotspot_activated.emit(scene_definition.on_first_visit_type, scene_definition.on_first_visit_target_id, {})
	return true

# ============================================
# INTERNO
# ============================================

func _recalculate_visible_hotspots() -> void:
	visible_hotspots.clear()
	if scene_definition == null:
		return

	var narrative := get_node_or_null("/root/Narrative")
	for hotspot in scene_definition.hotspots:
		if _is_hotspot_visible(hotspot, narrative):
			visible_hotspots.append(hotspot)


func _is_hotspot_visible(hotspot: InteractiveHotspotDefinition, narrative: Node) -> bool:
	if narrative == null:
		# Sin Narrative no se puede evaluar ningún flag: solo se muestran
		# los puntos incondicionales.
		return hotspot.required_flags.is_empty() and hotspot.blocked_flags.is_empty()

	for flag_id in hotspot.required_flags:
		if not narrative.has_flag(flag_id):
			return false
	for flag_id in hotspot.blocked_flags:
		if narrative.has_flag(flag_id):
			return false
	return true


func _find_visible_hotspot(hotspot_id: String) -> InteractiveHotspotDefinition:
	for hotspot in visible_hotspots:
		if hotspot.hotspot_id == hotspot_id:
			return hotspot
	return null


## "Validar primero": un scene_id narrativo mal escrito en el JSON solo
## fallaría al hacer clic en partida. Se avisa al cargar.
func _warn_about_missing_narrative_targets() -> void:
	var narrative_db := get_node_or_null("/root/NarrativeSceneDB") as NarrativeSceneRegistry
	if narrative_db == null:
		return
	for hotspot in scene_definition.hotspots:
		if hotspot.interaction_type == "narrative_scene" and not narrative_db.has_scene(hotspot.target_id):
			push_warning("[InteractiveSceneViewModel] '%s/%s': escena narrativa inexistente: %s" % [
				scene_definition.scene_id, hotspot.hotspot_id, hotspot.target_id])

	if scene_definition.has_first_visit() and scene_definition.on_first_visit_type == "narrative_scene" \
			and not narrative_db.has_scene(scene_definition.on_first_visit_target_id):
		push_warning("[InteractiveSceneViewModel] '%s/on_first_visit': escena narrativa inexistente: %s" % [
			scene_definition.scene_id, scene_definition.on_first_visit_target_id])

func _on_game_state_changed(new_state: int) -> void:
	if new_state == GameLoopSystem.GameState.EXPLORATION:
		refresh()
