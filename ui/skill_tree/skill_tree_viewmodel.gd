class_name SkillTreeViewModel
extends Node

## SkillTreeViewModel - ViewModel para SkillTreeScreen
## Patrón MVVM — ver athelia_ui_architecture.md
##
## RESPONSABILIDAD:
##   Construir y mantener el estado que SkillTreeScreen necesita para renderizar
##   el árbol de habilidades en modo individual y modo comparativa de party.
##
## SISTEMAS QUE ACCEDE (solo este ViewModel, nunca la View):
##   - Skills  (SkillSystem)    — snapshot de skills por entidad
##   - Party   (PartyManager)   — lista de companions activos
##
## SEÑAL ÚNICA hacia la View: changed(reason: String)
##
## Razones posibles:
##   "opened"          → renderizar todo desde cero
##   "entity_changed"  → cambió el personaje seleccionado, re-renderizar árbol
##   "mode_changed"    → cambió entre individual y comparativa
##   "filter_changed"  → cambió el filtro activo, re-filtrar sin recargar datos
##   "training_done"   → entrenamiento ejecutado, refrescar valor del panel lateral
##   "closed"          → ocultar pantalla


# ============================================
# ENUMS
# ============================================

enum PanelState { HIDDEN, SHOWING }

enum FilterMode {
	ALL,          ## Todas las skills
	TRAINABLE,    ## Solo mejorables ahora (desbloqueadas + has_progression)
	UNLOCKED,     ## Solo desbloqueadas
	LOCKED,       ## Solo bloqueadas
}


# ============================================
# SEÑAL
# ============================================

signal changed(reason: String)


# ============================================
# ESTADO PÚBLICO — leído por la View, nunca escrito desde fuera
# ============================================

var state: PanelState = PanelState.HIDDEN
var comparison_mode: bool = false

## Entidad actualmente seleccionada en modo individual
var selected_entity_id: String = ""

## Lista de entidades disponibles para el selector (jugador + companions)
## Array de Dictionaries: [{ "entity_id": String, "display_name": String }]
var available_entities: Array = []

## Subcategoría activa en el árbol individual (tab seleccionada)
var active_subcategory: String = ""

## Lista de subcategorías disponibles para la entidad seleccionada
## (solo las que tienen al menos una skill)
var available_subcategories: Array[String] = []

## Filtro activo en modo individual
var active_filter: FilterMode = FilterMode.ALL

## Skills de la entidad seleccionada, agrupadas por subcategoría y tier.
## Estructura:
## {
##   "MELEE": {
##     1: [ skill_data, skill_data, ... ],   # tier 1 = sin prereqs
##     2: [ skill_data, ... ],               # tier 2 = prereqs en tier 1
##   },
##   "RANGED": { ... }
## }
var skills_by_subcategory: Dictionary = {}

## Skill seleccionada en el panel lateral (modo individual)
## Contiene el dict completo del snapshot, o {} si nada seleccionado
var selected_skill: Dictionary = {}

## Coste de entrenamiento de la skill seleccionada.
## Vacío hasta que se implemente el sistema de costes — la View lo oculta si está vacío.
var training_cost: Dictionary = {}

## Datos para el modo comparativa.
## Array de Dictionaries, uno por skill visible:
## {
##   "skill_id":    String,
##   "name_key":    String,
##   "subcategory": String,
##   "entities":    { entity_id: { "current_value": int, "is_unlocked": bool,
##                                 "prereqs_met": bool, "is_trainable": bool,
##                                 "has_ai_suggestion": bool } }
## }
## Solo incluye skills desbloqueadas por al menos una entidad.
var comparison_data: Array = []


# ============================================
# ESTADO INTERNO
# ============================================

## Snapshot raw por entidad: { entity_id: Array[Dictionary] }
var _raw_snapshots: Dictionary = {}

## Sugerencias IA pendientes: { entity_id: Array[String] }
## Preparado — vacío hasta que se implemente el sistema de sugerencias.
var _ai_suggestions: Dictionary = {}


# ============================================
# INICIALIZACIÓN
# ============================================

func _ready() -> void:
	# Escuchar mejoras de skills para refrescar el panel lateral si está abierto
	EventBus.skill_improved.connect(_on_skill_improved)
	EventBus.skill_unlocked.connect(_on_skill_unlocked)


# ============================================
# API PÚBLICA — llamada desde SceneOrchestrator o ExplorationHUD
# ============================================

func open(initial_entity_id: String = "player") -> void:
	_load_available_entities()
	_select_entity(initial_entity_id)
	state = PanelState.SHOWING
	changed.emit("opened")


func request_close() -> void:
	state = PanelState.HIDDEN
	selected_skill = {}
	changed.emit("closed")


## Cambia la entidad seleccionada en modo individual
func request_select_entity(entity_id: String) -> void:
	if entity_id == selected_entity_id:
		return
	_select_entity(entity_id)
	changed.emit("entity_changed")


## Cambia la subcategoría activa (tab)
func request_select_subcategory(subcategory: String) -> void:
	if subcategory == active_subcategory:
		return
	active_subcategory = subcategory
	selected_skill = {}
	changed.emit("entity_changed")


## Selecciona una skill para mostrar en el panel lateral
func request_select_skill(skill_id: String) -> void:
	var skill_data: Dictionary = _find_skill_in_snapshot(selected_entity_id, skill_id)
	if skill_data.is_empty():
		return
	selected_skill = skill_data
	training_cost = skill_data.get("training_cost", {})
	changed.emit("entity_changed")


## Cambia el filtro activo
func request_set_filter(filter: FilterMode) -> void:
	if filter == active_filter:
		return
	active_filter = filter
	changed.emit("filter_changed")


## Activa/desactiva el modo comparativa de party
func request_toggle_comparison_mode() -> void:
	comparison_mode = not comparison_mode
	if comparison_mode:
		_build_comparison_data()
	changed.emit("mode_changed")


## Ejecuta el entrenamiento de la skill seleccionada.
## Devuelve un String de error localizable, o "" si fue exitoso.
## La View muestra el error en el panel lateral si no está vacío.
func request_train_selected_skill() -> String:
	if selected_skill.is_empty():
		return "SKILL_TREE_ERROR_NO_SKILL_SELECTED"

	var skill_id: String = selected_skill.get("skill_id", "")
	if skill_id.is_empty():
		return "SKILL_TREE_ERROR_NO_SKILL_SELECTED"

	if not selected_skill.get("is_unlocked", false):
		return "SKILL_TREE_ERROR_SKILL_LOCKED"

	if not selected_skill.get("has_progression", false):
		return "SKILL_TREE_ERROR_NO_PROGRESSION"

	var progression: Node = get_node_or_null("/root/SkillProgression")
	if not progression:
		push_error("[SkillTreeViewModel] SkillProgressionService not found")
		return "SKILL_TREE_ERROR_SYSTEM"

	# Construir LearningSession con source_level = valor actual de la skill
	# (el anti-grinding lo gestiona SkillProgressionService)
	var current_value: int = selected_skill.get("current_value", 30)
	var source_level: int = maxi(current_value, 20)  # mínimo 20 para no bloquear skills nuevas

	var session: LearningSession = LearningSession.create(
		selected_entity_id,
		skill_id,
		source_level,
		"PRACTICE"
	)

	var result: Dictionary = progression.execute_learning_session(session)

	match result.get("reason", ""):
		"skill_locked":
			return "SKILL_TREE_ERROR_SKILL_LOCKED"
		"no_progression":
			return "SKILL_TREE_ERROR_NO_PROGRESSION"
		"challenge_too_low":
			return "SKILL_TREE_ERROR_CHALLENGE_TOO_LOW"
		"improved", "roll_failed":
			# Refrescar snapshot tras el intento (haya mejorado o no)
			_refresh_snapshot(selected_entity_id)
			# Actualizar selected_skill con el nuevo valor
			selected_skill = _find_skill_in_snapshot(selected_entity_id, skill_id)
			changed.emit("training_done")
			return ""
		_:
			return "SKILL_TREE_ERROR_UNKNOWN"


# ============================================
# QUERIES PARA LA VIEW
# ============================================

## Devuelve las skills de la subcategoría activa filtradas por active_filter.
## La View llama esto en cada _render_skills().
func get_filtered_skills() -> Array:
	var tier_map: Dictionary = skills_by_subcategory.get(active_subcategory, {})
	var all_skills: Array = []

	# Aplanar tiers en orden para aplicar filtro
	var tiers: Array = tier_map.keys()
	tiers.sort()
	for tier in tiers:
		all_skills.append_array(tier_map[tier])

	match active_filter:
		FilterMode.ALL:
			return all_skills
		FilterMode.TRAINABLE:
			return all_skills.filter(func(s): return s.get("is_unlocked", false) and s.get("has_progression", false))
		FilterMode.UNLOCKED:
			return all_skills.filter(func(s): return s.get("is_unlocked", false))
		FilterMode.LOCKED:
			return all_skills.filter(func(s): return not s.get("is_unlocked", false))

	return all_skills


## Devuelve las skills de la subcategoría activa agrupadas por tier (para renderizado con separadores).
## { tier_int: Array[skill_data] }
func get_skills_by_tier() -> Dictionary:
	var tier_map: Dictionary = skills_by_subcategory.get(active_subcategory, {})
	if active_filter == FilterMode.ALL:
		return tier_map

	# Aplicar filtro manteniendo estructura de tiers
	var filtered: Dictionary = {}
	for tier in tier_map.keys():
		var filtered_tier: Array = tier_map[tier].filter(_build_filter_func())
		if not filtered_tier.is_empty():
			filtered[tier] = filtered_tier
	return filtered


## ¿Tiene la skill seleccionada una sugerencia IA pendiente?
func selected_skill_has_ai_suggestion() -> bool:
	if selected_skill.is_empty():
		return false
	var suggestions: Array = _ai_suggestions.get(selected_entity_id, [])
	return selected_skill.get("skill_id", "") in suggestions


# ============================================
# LÓGICA INTERNA
# ============================================

func _load_available_entities() -> void:
	available_entities = []

	# Siempre incluir al jugador
	available_entities.append({ "entity_id": "player", "display_name": "SKILL_TREE_PLAYER_LABEL" })

	# Companions activos en la party
	var party: Node = get_node_or_null("/root/Party")
	if party:
		for companion_id in party.get_active_members():
			available_entities.append({
				"entity_id":    companion_id,
				"display_name": companion_id,  # la View localizará esto
			})


func _select_entity(entity_id: String) -> void:
	selected_entity_id = entity_id
	selected_skill = {}
	_refresh_snapshot(entity_id)
	_build_skills_by_subcategory(entity_id)
	_update_available_subcategories()

	# Seleccionar primera subcategoría disponible si la activa ya no existe
	if not active_subcategory in available_subcategories:
		active_subcategory = available_subcategories[0] if not available_subcategories.is_empty() else ""


func _refresh_snapshot(entity_id: String) -> void:
	var skills_node: Node = get_node_or_null("/root/Skills")
	if not skills_node:
		push_error("[SkillTreeViewModel] SkillSystem not found at /root/Skills")
		return
	_raw_snapshots[entity_id] = skills_node.get_entity_skill_snapshot(entity_id)


func _build_skills_by_subcategory(entity_id: String) -> void:
	skills_by_subcategory = {}
	var snapshot: Array = _raw_snapshots.get(entity_id, [])

	for skill_data in snapshot:
		var sub: String = skill_data.get("subcategory", "NONE")
		if not skills_by_subcategory.has(sub):
			skills_by_subcategory[sub] = {}

		var tier: int = _compute_tier(skill_data, snapshot)
		if not skills_by_subcategory[sub].has(tier):
			skills_by_subcategory[sub][tier] = []

		# Enriquecer con campos derivados que la View necesita
		var enriched: Dictionary = skill_data.duplicate()
		enriched["tier"] = tier
		enriched["is_trainable"] = skill_data.get("is_unlocked", false) \
			and skill_data.get("has_progression", false) \
			and skill_data.get("prereqs_met", true)
		enriched["has_ai_suggestion"] = skill_data.get("skill_id", "") in \
			_ai_suggestions.get(entity_id, [])

		skills_by_subcategory[sub][tier].append(enriched)


func _update_available_subcategories() -> void:
	available_subcategories.clear()
	# Orden canónico de tabs
	var canonical_order: Array[String] = ["MELEE", "RANGED", "EXPLORATION", "DIALOGUE", "NARRATIVE", "ENEMY"]
	for sub in canonical_order:
		if skills_by_subcategory.has(sub) and not skills_by_subcategory[sub].is_empty():
			available_subcategories.append(sub)
	# Subcategorías no canónicas al final
	for sub in skills_by_subcategory.keys():
		if sub not in available_subcategories and sub != "NONE":
			available_subcategories.append(sub)


## Calcula el tier de una skill a partir de su cadena de prerequisitos.
## Tier 1 = sin prereqs.
## Tier N = max(tier de cada prereq directo) + 1.
## Límite de recursión: 10 niveles (evita ciclos en datos corruptos).
func _compute_tier(skill_data: Dictionary, snapshot: Array, _depth: int = 0) -> int:
	if _depth > 10:
		push_warning("[SkillTreeViewModel] _compute_tier: max depth reached for '%s'" % skill_data.get("skill_id", "?"))
		return 1

	var prereq_ids: Array = skill_data.get("prerequisite_requirements", {}).keys()
	if prereq_ids.is_empty():
		return 1

	var max_prereq_tier: int = 0
	for prereq_id in prereq_ids:
		var prereq_data: Dictionary = _find_in_snapshot(snapshot, prereq_id)
		if prereq_data.is_empty():
			continue
		var prereq_tier: int = _compute_tier(prereq_data, snapshot, _depth + 1)
		max_prereq_tier = maxi(max_prereq_tier, prereq_tier)

	return max_prereq_tier + 1


func _build_comparison_data() -> void:
	comparison_data = []

	# Recopilar snapshots de todas las entidades
	var all_entity_ids: Array = []
	for entry in available_entities:
		var eid: String = entry.get("entity_id", "")
		if eid.is_empty():
			continue
		all_entity_ids.append(eid)
		if not _raw_snapshots.has(eid):
			_refresh_snapshot(eid)

	# Recopilar todas las skills desbloqueadas en al menos una entidad
	var skill_ids_seen: Dictionary = {}
	for eid in all_entity_ids:
		for skill_data in _raw_snapshots.get(eid, []):
			if skill_data.get("is_unlocked", false):
				skill_ids_seen[skill_data.get("skill_id", "")] = true

	# Construir filas de comparativa
	for skill_id in skill_ids_seen.keys():
		if skill_id.is_empty():
			continue

		var row: Dictionary = {
			"skill_id":    skill_id,
			"name_key":    "",
			"subcategory": "",
			"entities":    {},
		}

		for eid in all_entity_ids:
			var skill_data: Dictionary = _find_skill_in_snapshot(eid, skill_id)
			if skill_data.is_empty():
				# La entidad no tiene esta skill registrada
				row["entities"][eid] = {
					"current_value":    0,
					"is_unlocked":      false,
					"prereqs_met":      false,
					"is_trainable":     false,
					"has_ai_suggestion": false,
				}
			else:
				if row["name_key"].is_empty():
					row["name_key"] = skill_data.get("name_key", skill_id)
					row["subcategory"] = skill_data.get("subcategory", "")

				row["entities"][eid] = {
					"current_value":     skill_data.get("current_value", 0),
					"is_unlocked":       skill_data.get("is_unlocked", false),
					"prereqs_met":       skill_data.get("prereqs_met", false),
					"is_trainable":      skill_data.get("is_unlocked", false) and skill_data.get("has_progression", false),
					"has_ai_suggestion": skill_id in _ai_suggestions.get(eid, []),
				}

		comparison_data.append(row)

	# Ordenar por subcategoría para que la tabla quede agrupada
	comparison_data.sort_custom(func(a, b): return a["subcategory"] < b["subcategory"])


# ============================================
# HELPERS
# ============================================

func _find_skill_in_snapshot(entity_id: String, skill_id: String) -> Dictionary:
	var snapshot: Array = _raw_snapshots.get(entity_id, [])
	return _find_in_snapshot(snapshot, skill_id)


func _find_in_snapshot(snapshot: Array, skill_id: String) -> Dictionary:
	for skill_data in snapshot:
		if skill_data.get("skill_id", "") == skill_id:
			return skill_data
	return {}


func _build_filter_func() -> Callable:
	match active_filter:
		FilterMode.TRAINABLE:
			return func(s): return s.get("is_unlocked", false) and s.get("has_progression", false)
		FilterMode.UNLOCKED:
			return func(s): return s.get("is_unlocked", false)
		FilterMode.LOCKED:
			return func(s): return not s.get("is_unlocked", false)
		_:
			return func(_s): return true


# ============================================
# LISTENERS DEL EVENTBUS
# ============================================

func _on_skill_improved(entity_id: String, _skill_id: String, _old_val: int, _new_val: int) -> void:
	if state == PanelState.HIDDEN:
		return
	# Refrescar solo la entidad afectada
	_refresh_snapshot(entity_id)
	_build_skills_by_subcategory(entity_id)
	if comparison_mode:
		_build_comparison_data()
	# training_done ya fue emitido por request_train_selected_skill;
	# este listener cubre mejoras que lleguen por combate mientras la pantalla está abierta.
	changed.emit("entity_changed")


func _on_skill_unlocked(entity_id: String, _skill_id: String) -> void:
	if state == PanelState.HIDDEN:
		return
	_refresh_snapshot(entity_id)
	_build_skills_by_subcategory(entity_id)
	if comparison_mode:
		_build_comparison_data()
	changed.emit("entity_changed")
