class_name CombatArenaViewModel
extends Node

## CombatArenaViewModel — Estado de la arena de combate de producción
##
## Compone al CombatHudViewModel ya existente (menú de 8 acciones del
## jugador, sin cambios) con el estado nuevo: fichas de party/enemigos
## y log narrado. Mismo contrato MVVM de siempre — hijo de la View,
## signal changed(reason) única, sin lógica de combate propia (todo
## dato ya viene resuelto desde CombatSystem/EventBus).
##
## Razones de changed():
##   "tokens"       → refrescar fichas (HP/EN/turno/objetivo)
##   "log_entry"    → una línea nueva en log_entries (la View hace append)
##   "background"   → fondo del encuentro resuelto (Grupo 4)
##   "combat_ended" → limpiar arena

signal changed(reason: String)

const PLAYER_ID: String = "player"

## Skills que no pasan por SkillRoller — deciden su propia categoría de log.
## Calcado del criterio de SPECIAL_ACTIONS en player_combat_controller.gd,
## no duplicado con nombres propios.
const SPECIAL_SKILL_CATEGORY: Dictionary = {
	"skill.combat.dodge":  "DODGE",
	"skill.combat.defend": "DEFEND",
	"skill.combat.flee":   "FLEE",
}

var combat_tokens: Array[CombatTokenData] = []
var log_entries: Array[LogEntryData] = []

## Menú de 8 acciones del jugador — sin cambios respecto a la pantalla actual.
var action_menu: CombatHudViewModel = null

## Grupo 4 — fondo ilustrado del encuentro activo, o null si el encuentro no
## define background_path (o no hay encuentro). La View decide qué hacer con
## null (fondo sólido); el ViewModel solo resuelve el dato.
var background_texture: Texture2D = null

# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	action_menu = CombatHudViewModel.new()
	action_menu.name = "ActionMenu"
	add_child(action_menu)

	EventBus.combat_started.connect(_on_combat_started)
	EventBus.combat_ended.connect(_on_combat_ended)
	Resources.resource_changed.connect(_on_resource_changed)  # NO EventBus.resource_changed — ResourceSystem no lo reenvía (ver nota en _on_resource_changed)
	EventBus.character_died.connect(_on_character_died)

	EventBus.player_turn_started.connect(_on_player_turn_started)
	EventBus.enemy_turn_started.connect(_on_enemy_turn_started)
	EventBus.companion_turn_started.connect(_on_companion_turn_started)
	EventBus.target_changed.connect(_on_target_changed)

	# Refuerzos a mitad de combate (enemigos) y rescates narrativos
	# (companions) — la arena no se reconstruye entera, solo añade la
	# ficha nueva a lo que ya hay.
	EventBus.companion_joined.connect(_on_companion_joined)
	EventBus.reinforcement_spawned.connect(_on_reinforcement_spawned)

	# ATTACK — todo lo que pasa por SkillRoller llega aquí ya resuelto
	# (entity_id, skill_id, target_id, result), result siempre trae
	# "roll_result" porque dodge/staggered/disarmed nunca llegan a este
	# punto (early-return en combat_system.gd antes de emitirla).
	EventBus.combat_action_executed.connect(_on_combat_action_executed)

	# STAGGERED / DISARMED / DODGE — casos sin roll, solo por aquí.
	EventBus.combat_action_completed.connect(_on_combat_action_completed)

	# DEFEND — camino propio, nunca pasa por combat_action_*
	EventBus.defense_activated.connect(_on_defense_activated)
	EventBus.defense_expired.connect(_on_defense_expired)

	# FLEE — camino propio, resolución en el turno siguiente del jugador
	EventBus.escape_attempted.connect(_on_escape_attempted)
	EventBus.escape_succeeded.connect(_on_escape_succeeded)
	EventBus.escape_failed.connect(_on_escape_failed)

# ============================================
# CONSTRUCCIÓN DE FICHAS
# ============================================

func _on_combat_started(_participants: Array) -> void:
	combat_tokens.clear()
	log_entries.clear()

	combat_tokens.append(_build_token(PLAYER_ID, true))

	# get_party_members() y no get_active_members() a propósito: un
	# companion incapacitado sigue en la arena (visible a 0 PV), igual
	# que un enemigo muerto — get_active_members() lo ocultaría del todo.
	var party_node: Node = get_node_or_null("/root/Party")
	if party_node:
		for companion_id in party_node.get_party_members():
			combat_tokens.append(_build_token(companion_id, true))

	for enemy_id in GameLoop.get_active_enemies():
		combat_tokens.append(_build_token(enemy_id, false))

	changed.emit("tokens")

	# Grupo 4 — diferido a propósito. combat_started no se emite desde
	# game_loop_system.gd y _current_encounter se asigna dentro de
	# start_combat(): sin garantía de orden entre ambos, leerlo aquí podría
	# ver null. start_combat() es síncrono, así que al final del frame el
	# encuentro ya está asignado.
	_resolve_background.call_deferred()


func _build_token(entity_id: String, is_party: bool) -> CombatTokenData:
	var data := CombatTokenData.new()
	data.entity_id = entity_id
	data.is_party = is_party
	data.is_current_turn = false
	data.is_targeted = false

	var hp_state: ResourceState = Resources.get_resource_state(entity_id, "health")
	data.hp_current = int(hp_state.current) if hp_state else 0
	data.hp_max = int(AttributeResolver.resolve(entity_id, "health_max"))

	if is_party:
		var en_state: ResourceState = Resources.get_resource_state(entity_id, "stamina")
		data.stamina_current = int(en_state.current) if en_state else 0
		data.stamina_max = int(AttributeResolver.resolve(entity_id, "stamina_max"))
		data.display_initials = _initials_for(entity_id)
	else:
		data.type_icon = _resolve_type_icon(entity_id)

	# Grupo 4 — antes solo se resolvía para party: las fichas enemigas se
	# quedaban con el Color.WHITE por defecto de CombatTokenData, y un icono
	# de tipo claro sobre un círculo blanco no se ve.
	data.fill_color = _resolve_fill_color(entity_id)

	return data


## Companion que se une a la party a mitad de combate (ej. rescate
## narrativo). No reconstruye combat_tokens entero — solo añade, si no
## estaba ya (join_party podría dispararse fuera de combate también,
## sin que este listener deba hacer nada raro si _find_token ya lo tiene).
func _on_companion_joined(companion_id: String) -> void:
	if combat_tokens.is_empty():
		return  # sin combate activo, nada que añadir a la arena
	if _find_token(companion_id):
		return  # ya está — evita duplicar si se llama dos veces
	combat_tokens.append(_build_token(companion_id, true))
	changed.emit("tokens")


## GameLoopSystem emite esta señal en _spawn_reinforcements(), pero el
## propio registro en Characters/Resources lo hace la escena en OTRO
## listener aparte (comentario explícito en game_loop_system.gd: "fuera
## de control de GameLoopSystem") — el orden entre ambos listeners no
## está garantizado. Un frame de margen evita construir la ficha antes
## de que el personaje exista de verdad.
func _on_reinforcement_spawned(enemy_id: String, _definition_id: String) -> void:
	if combat_tokens.is_empty():
		return
	if _find_token(enemy_id):
		return
	await get_tree().process_frame
	if _find_token(enemy_id):
		return  # por si se coló por otra vía durante ese frame
	combat_tokens.append(_build_token(enemy_id, false))
	changed.emit("tokens")


func _initials_for(entity_id: String) -> String:
	var state: CharacterState = Characters.get_character_state(entity_id)
	if not state or state.character_name.is_empty():
		return "??"
	var parts: PackedStringArray = state.character_name.split(" ", false)
	var initials: String = ""
	for part in parts:
		if not part.is_empty():
			initials += part[0]
		if initials.length() >= 3:
			break
	return initials.to_upper()


## Lee CharacterDefinition.token_color. Color.BLACK es el centinela de
## "sin asignar" (ver character_definition.gd) y cae al color neutro.
## Grupo 4: antes no se comprobaba el centinela — cualquier personaje sin
## token_color asignado salía con ficha negra en vez del color neutro.
func _resolve_fill_color(entity_id: String) -> Color:
	var state: CharacterState = Characters.get_character_state(entity_id)
	if state and state.definition:
		var custom_color = state.definition.get("token_color")
		if custom_color is Color and custom_color != Color.BLACK:
			return custom_color
	return UITokens.COLOR_TOKEN_FILL_DEFAULT


## Lee el icono de tipo desde CharacterDefinition.type_icon (Grupo 5,
## enemigos). null hasta que el .tres del enemigo tenga uno asignado —
## la ficha se queda sin icono en el centro, no un placeholder genérico.
func _resolve_type_icon(entity_id: String) -> Texture2D:
	var state: CharacterState = Characters.get_character_state(entity_id)
	if state and state.definition:
		var icon = state.definition.get("type_icon")
		if icon is Texture2D:
			return icon
	return null

# ============================================
# FONDO DE LA ARENA (Grupo 4)
# ============================================

## Lee background_path del encuentro activo. Solo se resuelve al empezar el
## combate: configure_active_encounter() puede sustituir el encuentro a
## mitad de combate sin emitir ninguna señal, así que un fondo definido por
## esa vía no se mostraría (limitación conocida; ningún contenido lo usa hoy).
func _resolve_background() -> void:
	background_texture = null

	var encounter: CombatEncounterDefinition = GameLoop.get_current_encounter()
	if encounter and not encounter.background_path.is_empty():
		if ResourceLoader.exists(encounter.background_path):
			background_texture = load(encounter.background_path) as Texture2D
		else:
			push_warning("[CombatArenaViewModel] background_path no existe: %s" % encounter.background_path)

	changed.emit("background")

# ============================================
# TURNO Y OBJETIVO
# ============================================

func _on_player_turn_started() -> void:
	_set_current_turn(PLAYER_ID)


func _on_enemy_turn_started(enemy_id: String) -> void:
	_set_current_turn(enemy_id)


func _on_companion_turn_started(companion_id: String) -> void:
	_set_current_turn(companion_id)


func _set_current_turn(entity_id: String) -> void:
	for token in combat_tokens:
		token.is_current_turn = (token.entity_id == entity_id)
	changed.emit("tokens")


func _on_target_changed(target_id: String) -> void:
	for token in combat_tokens:
		if not token.is_party:
			token.is_targeted = (token.entity_id == target_id)
	changed.emit("tokens")

# ============================================
# RECURSOS Y MUERTE
# ============================================

## Firma real de Resources.resource_changed (ResourceSystem, NO EventBus —
## ver el bug documentado en _ready(): nada reenvía esta señal a EventBus,
## así que quien se conecte a EventBus.resource_changed nunca la recibe.
##
## Solo actualizamos current, no max: max_value viene de
## ResourceState.max_effective, que es el máximo base genérico de la
## definición de recurso (ej. 100 de health.tres), no el máximo derivado
## real del personaje — eso solo lo calcula AttributeResolver, fijado
## una vez en _build_token() y no reflejado de vuelta en ResourceState
## para estas entidades. Confirmado en pruebas reales: usar max_value
## aquí mostraba /100 para todo el mundo en vez de /55 y /40.
##
## Solo emitimos si el entero mostrado cambia de verdad — la
## regeneración de estamina dispara esta señal cada frame con
## variaciones de menos de 1 punto; sin este guard, changed("tokens")
## se dispara constantemente sin que se vea ningún cambio real.
func _on_resource_changed(entity_id: String, resource_id: String, current: float, _max_value: float) -> void:
	if resource_id != "health" and resource_id != "stamina":
		return

	var token: CombatTokenData = _find_token(entity_id)
	if not token:
		return

	var new_value: int = int(current)
	var did_change: bool = false

	match resource_id:
		"health":
			if token.hp_current != new_value:
				token.hp_current = new_value
				did_change = true
		"stamina":
			if token.is_party and token.stamina_current != new_value:
				token.stamina_current = new_value
				did_change = true

	if did_change:
		changed.emit("tokens")


## Decisión pendiente de UX, no de arquitectura: hoy la ficha se queda
## visible a 0 PV en vez de retirarse del array — evita reindexar la
## disposición de la arena a mitad de combate. Si prefieres que
## desaparezca, es un one-liner (combat_tokens.erase(token)) aquí mismo.
func _on_character_died(character_id: String) -> void:
	var token: CombatTokenData = _find_token(character_id)
	if token:
		token.hp_current = 0
		token.is_targeted = false
		changed.emit("tokens")


func _find_token(entity_id: String) -> CombatTokenData:
	for token in combat_tokens:
		if token.entity_id == entity_id:
			return token
	return null

# ============================================
# LOG — ATTACK (graduado por SkillRoller)
# ============================================

func _on_combat_action_executed(entity_id: String, _skill_id: String, target_id: String, result: Dictionary) -> void:
	if not result.has("roll_result"):
		return  # no debería pasar — combat_action_executed solo se emite tras un roll

	var grade: int = result.roll_result.result
	var grade_key: String = _grade_key(grade)
	var text_key: String = "LOG_ATTACK_%s" % grade_key

	# FUMBLE/FAILURE no muestran daño (no hay golpe) — sus plantillas del
	# .csv solo llevan 2 marcadores %s, no 3. Pasar un array de 3 contra
	# una plantilla de 2 hace que GDScript no sustituya nada y deje el
	# %s literal — confirmado en pruebas reales.
	var args: Array
	if grade == SkillRoller.RollResult.FUMBLE or grade == SkillRoller.RollResult.FAILURE:
		args = [_display_name(entity_id), _display_name(target_id)]
	else:
		var damage: int = int(result.get("damage", 0))
		args = [_display_name(entity_id), _display_name(target_id), damage]

	_append_log(text_key, args, grade)

# ============================================
# LOG — STAGGERED / DISARMED / DODGE (sin roll)
# ============================================

func _on_combat_action_completed(result: Dictionary) -> void:
	if result.get("staggered", false):
		_append_log("LOG_STAGGERED", [_display_name(result.get("actor", ""))], -1)
		return

	if result.get("disarmed", false):
		_append_log("LOG_DISARMED", [_display_name(result.get("actor", ""))], -1)
		return

	if result.get("action", "") == "dodge":
		# result["actor"] requiere el parche de combat_system.gd
		# (combat_system_dodge_patch.gd) aplicado. Fallback a PLAYER_ID
		# solo como red de seguridad si el parche no está aplicado todavía.
		var actor_id: String = result.get("actor", PLAYER_ID)
		_append_log("LOG_DODGE_ACTIVATED", [_display_name(actor_id)], -1)

# ============================================
# LOG — DEFEND (activación/expiración, sin roll)
# ============================================

func _on_defense_activated(entity_id: String) -> void:
	_append_log("LOG_DEFEND_ACTIVATED", [_display_name(entity_id)], -1)


func _on_defense_expired(entity_id: String) -> void:
	_append_log("LOG_DEFEND_EXPIRED", [_display_name(entity_id)], -1)

# ============================================
# LOG — FLEE (intento en un turno, resolución en el siguiente)
# ============================================

func _on_escape_attempted(entity_id: String, threshold: int) -> void:
	_append_log("LOG_FLEE_ATTEMPTED", [_display_name(entity_id), threshold], -1)


func _on_escape_succeeded(entity_id: String) -> void:
	_append_log("LOG_FLEE_SUCCEEDED", [_display_name(entity_id)], -1)


func _on_escape_failed(entity_id: String, current: int, required: int) -> void:
	_append_log("LOG_FLEE_FAILED", [_display_name(entity_id), current, required], -1)

# ============================================
# INTERNO
# ============================================

func _append_log(text_key: String, format_args: Array, grade: int) -> void:
	var entry := LogEntryData.new()
	entry.text_key = text_key
	entry.format_args = format_args
	entry.grade = grade
	log_entries.append(entry)
	changed.emit("log_entry")


func _display_name(entity_id: String) -> String:
	if entity_id.is_empty():
		return "?"
	var state: CharacterState = Characters.get_character_state(entity_id)
	if state and not state.character_name.is_empty():
		return state.character_name
	return entity_id


func _grade_key(grade: int) -> String:
	match grade:
		SkillRoller.RollResult.FUMBLE:
			return "FUMBLE"
		SkillRoller.RollResult.FAILURE:
			return "FAILURE"
		SkillRoller.RollResult.SUCCESS:
			return "SUCCESS"
		SkillRoller.RollResult.SPECIAL:
			return "SPECIAL"
		SkillRoller.RollResult.CRITICAL:
			return "CRITICAL"
		_:
			push_warning("[CombatArenaViewModel] Grado de roll desconocido: %d" % grade)
			return "FAILURE"

# ============================================
# CIERRE
# ============================================

func _on_combat_ended(_result: String) -> void:
	combat_tokens.clear()
	log_entries.clear()
	background_texture = null
	changed.emit("combat_ended")
