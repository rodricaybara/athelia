class_name SkillTreeViewModel
extends Node

## SkillTreeViewModel - ViewModel para SkillTreeScreen (Spike 21a)
## Patrón MVVM — ver athelia_ui_architecture.md
##
## RESPONSABILIDAD:
##   Construir y mantener el estado que SkillTreeScreen necesita para pintar el
##   árbol de habilidades: entidades, pestañas, filtros, tarjetas, detalle y
##   resultado del entrenamiento. Entrega CLAVES de localización; la View traduce.
##
## SISTEMAS QUE ACCEDE (solo este ViewModel, nunca la View):
##   - Skills           — snapshot y definiciones de skills
##   - SkillProgression — sesiones de aprendizaje (entrenar)
##   - Party            — companions activos
##   - Characters       — nombre (name_key) de cada companion
##
## SEÑAL ÚNICA hacia la View: changed(reason: String)
##
## Razones (cada una tiene su caso en SkillTreeScreen._on_vm_changed):
##   "opened"         → pintar todo desde cero
##   "entity_changed" → cambió el personaje mostrado (selector)
##   "tab"            → cambió la subcategoría activa
##   "selection"      → cambió la skill seleccionada
##   "filter_changed" → cambió el filtro activo
##   "mode_changed"   → cambió entre individual y comparativa, o la comparativa
##                      se refrescó por una mejora/desbloqueo externo
##   "training_done"  → datos refrescados. Si `train_result != null` es el
##                      resultado de un entrenamiento de esta pantalla; si es
##                      null, el refresco viene de fuera (mejora o desbloqueo
##                      por el EventBus)
##   "error"          → `error_message` trae la clave del rechazo
##   "closed"         → ocultar pantalla
##
## REGLAS NO CAMBIADAS: el core (Skills, SkillProgression, datos) no se toca.
## "Mejorable" = is_unlocked and has_progression and prereqs_met.


# ============================================
# CONSTANTES
# ============================================

const PLAYER_ID: String = "player"
const PLAYER_NAME_KEY: String = "SKILL_TREE_PLAYER_LABEL"
const COMPANION_FALLBACK_KEY: String = "SKILL_TREE_COMPANION_UNKNOWN"

## Origen de la sesión de aprendizaje y nivel mínimo de la fuente (el
## anti-grinding lo gestiona SkillProgression; 20 evita bloquear skills nuevas).
const TRAINING_SOURCE: String = "PRACTICE"
const MIN_SOURCE_LEVEL: int = 20

## Orden canónico de pestañas. "NONE" nunca se muestra (comportamiento previo).
const SUBCATEGORY_ORDER: Array[String] = ["MELEE", "RANGED", "EXPLORATION", "DIALOGUE", "NARRATIVE", "ENEMY"]
const HIDDEN_SUBCATEGORY: String = "NONE"

const REASON_PREREQS: String = "SKILL_TREE_REASON_PREREQS"
const REASON_TEACHER: String = "SKILL_TREE_REASON_TEACHER"
const REASON_NO_PROGRESSION: String = "SKILL_TREE_REASON_NO_PROGRESSION"


# ============================================
# ENUMS
# ============================================

enum PanelState { HIDDEN, SHOWING }

enum FilterMode {
	ALL,        ## Todas las skills
	TRAINABLE,  ## Mejorables ahora
	UNLOCKED,   ## Desbloqueadas
	LOCKED,     ## Bloqueadas
}


# ============================================
# DATOS PARA LA VIEW
# ============================================

class EntityData extends RefCounted:
	var entity_id: String = ""
	var name_key: String = ""


class CostData extends RefCounted:
	var resource_id: String = ""
	var amount: int = 0


class EffectData extends RefCounted:
	var type: String = ""
	var buff_type: String = ""
	var has_value: bool = false
	var value: float = 0.0
	var has_duration: bool = false
	var duration: float = 0.0
	var max_targets: int = 1


class PrereqData extends RefCounted:
	var name_key: String = ""
	var threshold: int = 0
	var current_value: int = 0
	var is_met: bool = false


class SkillData extends RefCounted:
	var skill_id: String = ""
	var name_key: String = ""
	var description_key: String = ""
	var subcategory: String = ""
	var mode: String = ""
	var tier: int = 1
	var current_value: int = 0
	var is_unlocked: bool = false
	var has_progression: bool = false
	var prereqs_met: bool = true
	var is_trainable: bool = false
	## Clave del motivo por el que no se puede entrenar ("" si se puede).
	## La clave del texto de ayuda es esta + "_HINT".
	var block_reason_key: String = ""
	var target_type: String = ""
	var range_type: String = ""
	var base_cooldown: float = 0.0
	var costs: Array[CostData] = []
	var effects: Array[EffectData] = []
	var attribute_ids: Array[String] = []
	var prereqs: Array[PrereqData] = []


class TierGroup extends RefCounted:
	var tier: int = 1
	var skills: Array[SkillData] = []


class TrainResult extends RefCounted:
	var improved: bool = false
	var old_value: int = 0
	var new_value: int = 0


## Celda de la comparativa: una skill vista desde una entidad.
class ComparisonCell extends RefCounted:
	var current_value: int = 0
	var is_unlocked: bool = false
	var is_trainable: bool = false


## Fila de la comparativa: una skill y su celda por entidad.
class ComparisonRow extends RefCounted:
	var skill_id: String = ""
	var name_key: String = ""
	var subcategory: String = ""
	var order: int = 0
	## { entity_id: ComparisonCell } — hay una celda por cada entidad de `entities`.
	var cells: Dictionary = {}


# ============================================
# SEÑAL
# ============================================

signal changed(reason: String)


# ============================================
# ESTADO PÚBLICO — leído por la View, nunca escrito desde fuera
# ============================================

var state: PanelState = PanelState.HIDDEN
var comparison_mode: bool = false

var selected_entity_id: String = ""
var selected_entity_name_key: String = PLAYER_NAME_KEY

## Jugador + companions activos (selector).
var entities: Array[EntityData] = []

var active_subcategory: String = ""
var available_subcategories: Array[String] = []
var active_filter: FilterMode = FilterMode.ALL

## Skills de la subcategoría activa, con el filtro aplicado, agrupadas por nivel.
var tier_groups: Array[TierGroup] = []

## Skill seleccionada (null si ninguna).
var selected_skill: SkillData = null

## Resultado del último entrenamiento hecho desde esta pantalla (null si el
## refresco no viene de un entrenamiento).
var train_result: TrainResult = null

## Clave del último rechazo (válida solo durante "error").
var error_message: String = ""

## Datos de la comparativa: una fila por skill desbloqueada en al menos una
## entidad, ordenadas por pestaña canónica y, dentro de ella, por aparición.
var comparison_data: Array[ComparisonRow] = []


# ============================================
# ESTADO INTERNO
# ============================================

## Snapshot raw por entidad: { entity_id: Array de Dictionary }
var _raw_snapshots: Dictionary = {}

## Skills de la entidad seleccionada, con tier y estado calculados.
var _all_skills: Array[SkillData] = []

## true mientras request_train_selected_skill() está ejecutando: el core emite
## skill_improved dentro, y ya refrescamos nosotros al terminar.
var _training_in_progress: bool = false


# ============================================
# INICIALIZACIÓN
# ============================================

func _ready() -> void:
	EventBus.skill_improved.connect(_on_skill_improved)
	EventBus.skill_unlocked.connect(_on_skill_unlocked)


# ============================================
# API PÚBLICA — llamada desde la View
# ============================================

func open(initial_entity_id: String = PLAYER_ID) -> void:
	_load_entities()
	comparison_mode = false
	_raw_snapshots.clear()
	var start_id: String = initial_entity_id
	if _find_entity(start_id) == null:
		start_id = PLAYER_ID
	_select_entity(start_id)
	state = PanelState.SHOWING
	changed.emit("opened")


func request_close() -> void:
	state = PanelState.HIDDEN
	selected_skill = null
	changed.emit("closed")


## Selecciona una entidad concreta.
func request_select_entity(entity_id: String) -> void:
	if entity_id == selected_entity_id or _find_entity(entity_id) == null:
		return
	_select_entity(entity_id)
	changed.emit("entity_changed")


## Avanza (+1) o retrocede (-1) por la lista de entidades, dando la vuelta.
func request_step_entity(step: int) -> void:
	if entities.size() < 2:
		return
	var index: int = 0
	for i in entities.size():
		if entities[i].entity_id == selected_entity_id:
			index = i
			break
	var next_index: int = posmod(index + step, entities.size())
	request_select_entity(entities[next_index].entity_id)


func request_select_subcategory(subcategory: String) -> void:
	if subcategory == active_subcategory:
		return
	active_subcategory = subcategory
	selected_skill = null
	train_result = null
	_rebuild_groups()
	changed.emit("tab")


## Selecciona una skill (también las bloqueadas: el detalle explica el motivo).
func request_select_skill(skill_id: String) -> void:
	var skill: SkillData = _find_skill(skill_id)
	if skill == null:
		return
	selected_skill = skill
	train_result = null
	changed.emit("selection")


func request_set_filter(filter: FilterMode) -> void:
	if filter == active_filter:
		return
	active_filter = filter
	_rebuild_groups()
	changed.emit("filter_changed")


func request_toggle_comparison_mode() -> void:
	comparison_mode = not comparison_mode
	if comparison_mode:
		_build_comparison_data()
	changed.emit("mode_changed")


## Entrena la skill seleccionada. Emite "training_done" (con train_result) o
## "error" (con error_message). No devuelve nada: la View solo reacciona a changed.
func request_train_selected_skill() -> void:
	if selected_skill == null:
		_fail("SKILL_TREE_ERROR_NO_SKILL_SELECTED")
		return
	if not selected_skill.is_trainable:
		_fail(_error_for_block_reason(selected_skill))
		return

	var skill_id: String = selected_skill.skill_id
	var source_level: int = maxi(selected_skill.current_value, MIN_SOURCE_LEVEL)
	var session: LearningSession = LearningSession.create(
		selected_entity_id, skill_id, source_level, TRAINING_SOURCE)

	_training_in_progress = true
	var result: Dictionary = SkillProgression.execute_learning_session(session)
	_training_in_progress = false

	var reason: String = result.get("reason", "") as String
	match reason:
		"improved", "roll_failed":
			var outcome := TrainResult.new()
			outcome.improved = reason == "improved"
			outcome.old_value = int(result.get("old_value", selected_skill.current_value))
			outcome.new_value = int(result.get("new_value", selected_skill.current_value))
			_refresh_selected_entity()
			selected_skill = _find_skill(skill_id)
			train_result = outcome
			changed.emit("training_done")
		"skill_locked":
			_fail("SKILL_TREE_ERROR_SKILL_LOCKED")
		"no_progression":
			_fail("SKILL_TREE_ERROR_NO_PROGRESSION")
		"challenge_too_low":
			_fail("SKILL_TREE_ERROR_CHALLENGE_TOO_LOW")
		_:
			_fail("SKILL_TREE_ERROR_UNKNOWN")


# ============================================
# LÓGICA INTERNA — entidades
# ============================================

func _load_entities() -> void:
	entities.clear()

	var player := EntityData.new()
	player.entity_id = PLAYER_ID
	player.name_key = PLAYER_NAME_KEY
	entities.append(player)

	for member in Party.get_active_members():
		var companion := EntityData.new()
		companion.entity_id = member as String
		companion.name_key = _companion_name_key(companion.entity_id)
		entities.append(companion)


func _companion_name_key(entity_id: String) -> String:
	var definition: Variant = Characters.get_character_definition(entity_id)
	if definition == null:
		return COMPANION_FALLBACK_KEY
	var name_key: String = definition.name_key as String
	return name_key if name_key != "" else COMPANION_FALLBACK_KEY


func _find_entity(entity_id: String) -> EntityData:
	for entity in entities:
		if entity.entity_id == entity_id:
			return entity
	return null


func _select_entity(entity_id: String) -> void:
	selected_entity_id = entity_id
	var entity: EntityData = _find_entity(entity_id)
	selected_entity_name_key = entity.name_key if entity != null else PLAYER_NAME_KEY
	selected_skill = null
	train_result = null
	_refresh_selected_entity()


# ============================================
# LÓGICA INTERNA — skills
# ============================================

func _refresh_snapshot(entity_id: String) -> void:
	_raw_snapshots[entity_id] = Skills.get_entity_skill_snapshot(entity_id)


## Recarga el snapshot de la entidad mostrada y reconstruye sus skills,
## pestañas y grupos. Mantiene la selección si la skill sigue existiendo.
func _refresh_selected_entity() -> void:
	_refresh_snapshot(selected_entity_id)
	var raw: Array = _raw_snapshots.get(selected_entity_id, []) as Array

	_all_skills.clear()
	for entry in raw:
		_all_skills.append(_build_skill_data(entry as Dictionary, raw))

	_update_available_subcategories()
	if not active_subcategory in available_subcategories:
		active_subcategory = available_subcategories[0] if not available_subcategories.is_empty() else ""
	_rebuild_groups()

	if selected_skill != null:
		selected_skill = _find_skill(selected_skill.skill_id)


func _build_skill_data(raw_skill: Dictionary, snapshot: Array) -> SkillData:
	var skill := SkillData.new()
	skill.skill_id = raw_skill.get("skill_id", "") as String
	skill.name_key = raw_skill.get("name_key", skill.skill_id) as String
	skill.description_key = raw_skill.get("description_key", "") as String
	skill.subcategory = raw_skill.get("subcategory", HIDDEN_SUBCATEGORY) as String
	skill.mode = raw_skill.get("mode", "") as String
	skill.tier = _compute_tier(raw_skill, snapshot)
	skill.current_value = int(raw_skill.get("current_value", 0))
	skill.is_unlocked = raw_skill.get("is_unlocked", false) as bool
	skill.has_progression = raw_skill.get("has_progression", false) as bool
	skill.prereqs_met = raw_skill.get("prereqs_met", true) as bool
	skill.target_type = raw_skill.get("target_type", "") as String
	skill.range_type = raw_skill.get("range_type", "") as String
	skill.base_cooldown = float(raw_skill.get("base_cooldown", 0.0))

	var costs: Dictionary = raw_skill.get("costs", {}) as Dictionary
	for key in costs.keys():
		var cost := CostData.new()
		cost.resource_id = key as String
		cost.amount = int(costs[key])
		skill.costs.append(cost)

	for raw_effect in raw_skill.get("effects", []) as Array:
		skill.effects.append(_build_effect_data(raw_effect as Dictionary))

	var weights: Dictionary = raw_skill.get("attribute_weights", {}) as Dictionary
	for key in weights.keys():
		skill.attribute_ids.append(key as String)

	var missing: Array = raw_skill.get("missing_prereqs", []) as Array
	var requirements: Dictionary = raw_skill.get("prerequisite_requirements", {}) as Dictionary
	for key in requirements.keys():
		var prereq_id: String = key as String
		var prereq := PrereqData.new()
		prereq.name_key = _skill_name_key(prereq_id)
		prereq.threshold = int(requirements[key])
		prereq.current_value = int(_find_in_snapshot(snapshot, prereq_id).get("current_value", 0))
		prereq.is_met = not prereq_id in missing
		skill.prereqs.append(prereq)

	_evaluate_trainability(skill)
	return skill


func _build_effect_data(raw_effect: Dictionary) -> EffectData:
	var effect := EffectData.new()
	effect.type = raw_effect.get("type", "") as String
	effect.buff_type = raw_effect.get("buff_type", "") as String
	effect.has_value = raw_effect.has("value")
	effect.value = float(raw_effect.get("value", 0.0))
	effect.has_duration = raw_effect.has("duration")
	effect.duration = float(raw_effect.get("duration", 0.0))
	effect.max_targets = int(raw_effect.get("max_targets", 1))
	return effect


## Una sola definición de "mejorable" y el motivo, por orden de prioridad:
##   1. requisitos pendientes
##   2. bloqueada con requisitos cumplidos → hay que aprenderla de alguien
##   3. desbloqueada pero sin progresión
func _evaluate_trainability(skill: SkillData) -> void:
	skill.is_trainable = skill.is_unlocked and skill.has_progression and skill.prereqs_met
	skill.block_reason_key = ""
	if skill.is_trainable:
		return
	if not skill.prereqs_met:
		skill.block_reason_key = REASON_PREREQS
	elif not skill.is_unlocked:
		skill.block_reason_key = REASON_TEACHER
	else:
		skill.block_reason_key = REASON_NO_PROGRESSION


func _error_for_block_reason(skill: SkillData) -> String:
	if not skill.is_unlocked:
		return "SKILL_TREE_ERROR_SKILL_LOCKED"
	if not skill.has_progression:
		return "SKILL_TREE_ERROR_NO_PROGRESSION"
	return "SKILL_TREE_ERROR_SKILL_LOCKED"


func _skill_name_key(skill_id: String) -> String:
	var definition: Variant = Skills.get_skill_definition(skill_id)
	if definition == null:
		return skill_id
	var name_key: String = definition.name_key as String
	return name_key if name_key != "" else skill_id


func _update_available_subcategories() -> void:
	available_subcategories.clear()
	var present: Dictionary = {}
	for skill in _all_skills:
		present[skill.subcategory] = true

	for sub in SUBCATEGORY_ORDER:
		if present.has(sub):
			available_subcategories.append(sub)
	for sub in present.keys():
		var sub_id: String = sub as String
		if sub_id != HIDDEN_SUBCATEGORY and not sub_id in available_subcategories:
			available_subcategories.append(sub_id)


## Agrupa las skills de la subcategoría activa por nivel, aplicando el filtro.
func _rebuild_groups() -> void:
	tier_groups.clear()
	var by_tier: Dictionary = {}
	for skill in _all_skills:
		if skill.subcategory != active_subcategory or not _passes_filter(skill):
			continue
		if not by_tier.has(skill.tier):
			var group := TierGroup.new()
			group.tier = skill.tier
			by_tier[skill.tier] = group
		(by_tier[skill.tier] as TierGroup).skills.append(skill)

	var tiers: Array = by_tier.keys()
	tiers.sort()
	for tier in tiers:
		tier_groups.append(by_tier[tier] as TierGroup)


func _passes_filter(skill: SkillData) -> bool:
	match active_filter:
		FilterMode.TRAINABLE:
			return skill.is_trainable
		FilterMode.UNLOCKED:
			return skill.is_unlocked
		FilterMode.LOCKED:
			return not skill.is_unlocked
	return true


## Tier 1 = sin prerrequisitos. Tier N = max(tier de cada prerrequisito) + 1.
## Límite de recursión: 10 niveles (evita ciclos en datos corruptos).
func _compute_tier(skill_data: Dictionary, snapshot: Array, depth: int = 0) -> int:
	if depth > 10:
		push_warning("[SkillTreeViewModel] _compute_tier: max depth reached for '%s'" % skill_data.get("skill_id", "?"))
		return 1

	var prereq_ids: Array = (skill_data.get("prerequisite_requirements", {}) as Dictionary).keys()
	if prereq_ids.is_empty():
		return 1

	var max_prereq_tier: int = 0
	for prereq_id in prereq_ids:
		var prereq_data: Dictionary = _find_in_snapshot(snapshot, prereq_id as String)
		if prereq_data.is_empty():
			continue
		max_prereq_tier = maxi(max_prereq_tier, _compute_tier(prereq_data, snapshot, depth + 1))
	return max_prereq_tier + 1


func _find_skill(skill_id: String) -> SkillData:
	for skill in _all_skills:
		if skill.skill_id == skill_id:
			return skill
	return null


func _find_in_snapshot(snapshot: Array, skill_id: String) -> Dictionary:
	for entry in snapshot:
		var skill_data: Dictionary = entry as Dictionary
		if (skill_data.get("skill_id", "") as String) == skill_id:
			return skill_data
	return {}


func _fail(message_key: String) -> void:
	error_message = message_key
	changed.emit("error")


# ============================================
# COMPARATIVA
# ============================================

func _build_comparison_data() -> void:
	comparison_data.clear()
	for entity in entities:
		if not _raw_snapshots.has(entity.entity_id):
			_refresh_snapshot(entity.entity_id)

	# Una fila por skill vista en cualquier entidad; cada una con su celda.
	var rows: Dictionary = {}
	for entity in entities:
		for entry in _raw_snapshots.get(entity.entity_id, []) as Array:
			var raw_skill: Dictionary = entry as Dictionary
			var skill_id: String = raw_skill.get("skill_id", "") as String
			if skill_id.is_empty():
				continue
			var row: ComparisonRow = rows.get(skill_id) as ComparisonRow
			if row == null:
				row = ComparisonRow.new()
				row.skill_id = skill_id
				row.name_key = raw_skill.get("name_key", skill_id) as String
				row.subcategory = raw_skill.get("subcategory", HIDDEN_SUBCATEGORY) as String
				row.order = rows.size()
				rows[skill_id] = row
			row.cells[entity.entity_id] = _build_comparison_cell(raw_skill)

	for row_value in rows.values():
		var row: ComparisonRow = row_value as ComparisonRow
		if not _is_unlocked_by_anyone(row):
			continue
		for entity in entities:
			if not row.cells.has(entity.entity_id):
				row.cells[entity.entity_id] = ComparisonCell.new()
		comparison_data.append(row)

	comparison_data.sort_custom(func(a: ComparisonRow, b: ComparisonRow) -> bool:
		var rank_a: int = _subcategory_rank(a.subcategory)
		var rank_b: int = _subcategory_rank(b.subcategory)
		if rank_a != rank_b:
			return rank_a < rank_b
		return a.order < b.order)


func _build_comparison_cell(raw_skill: Dictionary) -> ComparisonCell:
	var cell := ComparisonCell.new()
	cell.is_unlocked = raw_skill.get("is_unlocked", false) as bool
	cell.current_value = int(raw_skill.get("current_value", 0))
	cell.is_trainable = cell.is_unlocked \
		and (raw_skill.get("has_progression", false) as bool) \
		and (raw_skill.get("prereqs_met", false) as bool)
	return cell


func _is_unlocked_by_anyone(row: ComparisonRow) -> bool:
	for cell_value in row.cells.values():
		if (cell_value as ComparisonCell).is_unlocked:
			return true
	return false


## Posición de la pestaña en el orden canónico; "NONE" y desconocidas al final.
func _subcategory_rank(subcategory: String) -> int:
	var index: int = SUBCATEGORY_ORDER.find(subcategory)
	if index >= 0:
		return index
	return SUBCATEGORY_ORDER.size() + (1 if subcategory == HIDDEN_SUBCATEGORY else 0)


# ============================================
# LISTENERS DEL EVENTBUS
# ============================================

func _on_skill_improved(entity_id: String, _skill_id: String, _old_value: int, _new_value: int) -> void:
	if state == PanelState.HIDDEN or _training_in_progress:
		return
	_refresh_after_external_change(entity_id)


func _on_skill_unlocked(entity_id: String, _skill_id: String) -> void:
	if state == PanelState.HIDDEN:
		return
	_refresh_after_external_change(entity_id)


## Mejora o desbloqueo que llega de fuera (no de esta pantalla). Solo se
## reconstruye lo de la entidad mostrada; el resto solo refresca su snapshot
## si la comparativa lo está usando.
func _refresh_after_external_change(entity_id: String) -> void:
	if entity_id == selected_entity_id:
		_refresh_selected_entity()
	elif _raw_snapshots.has(entity_id):
		_refresh_snapshot(entity_id)
	else:
		return

	if comparison_mode:
		_build_comparison_data()
		changed.emit("mode_changed")
	if entity_id == selected_entity_id:
		train_result = null
		changed.emit("training_done")
