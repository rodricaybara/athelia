class_name CombatSnapshot
extends RefCounted

## CombatSnapshot — Lo que la IA puede conocer al decidir (IA-1a, spec 7).
##
## Es un Dictionary CONGELADO EN PROFUNDIDAD, construido solo con la API pública de Combat y
## de Resources (nunca miembros privados). El evaluador no consulta Combat mientras puntúa:
## por eso las candidatas viajan dentro del snapshot.
##
## Observabilidad (D1): de sí mismo, valores exactos; de los demás, lo aparente (estado de
## salud, amenaza, condiciones visibles). Excepción de la spec: el último atacante del
## protagonista, que `protect` necesita.
##
## Solo lleva tipos simples (bool, int, float, String, StringName, Dictionary, Array): un
## Resource o un PackedArray no se pueden congelar. make_read_only() es SUPERFICIAL
## (comprobado en 4.7.2), de ahí deep_freeze(). Modificar un contenedor congelado da un error
## de ejecución, así que las pruebas comprueban is_deep_frozen() en vez de intentarlo.
##
## Forma:
##   { schema_version, actor_id, side,
##     self:      { id, hp_ratio, hp_state, resources{health,stamina}, conditions[], last_attacker_id },
##     player:    { id, hp_state, conditions[], last_attacker_id },
##     allies:    [ { id, hp_state, threat, conditions[], targetable } ]   # sin el propio actor
##     opponents: [ { id, hp_state, threat, conditions[], targetable } ],
##     candidates:[ candidata de Combat.get_candidates() ] }

const SCHEMA_VERSION: int = 1
const PLAYER_ID: String = "player"
const SELF_RESOURCES: Array[String] = ["health", "stamina"]


static func build(actor_id: String) -> Dictionary:
	var side: StringName = Combat.get_side(actor_id)
	var other_side: StringName = CombatTags.SIDE_ENEMY if side == CombatTags.SIDE_ALLY else CombatTags.SIDE_ALLY
	var snapshot: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"actor_id": actor_id,
		"side": side,
		"self": _build_self(actor_id),
		"player": _build_player(),
		"allies": _build_entries(side, side, actor_id),
		"opponents": _build_entries(other_side, side, actor_id),
		"candidates": Combat.get_candidates(actor_id).duplicate(true),
	}
	deep_freeze(snapshot)
	return snapshot


## Congela un valor y todo lo que contiene. Devuelve el mismo valor.
static func deep_freeze(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary: Dictionary = value
		for key in dictionary.keys():
			deep_freeze(dictionary[key])
		dictionary.make_read_only()
	elif value is Array:
		var array: Array = value
		for item in array:
			deep_freeze(item)
		array.make_read_only()
	return value


static func is_deep_frozen(value: Variant) -> bool:
	if value is Dictionary:
		var dictionary: Dictionary = value
		if not dictionary.is_read_only():
			return false
		for key in dictionary.keys():
			if not is_deep_frozen(dictionary[key]):
				return false
	elif value is Array:
		var array: Array = value
		if not array.is_read_only():
			return false
		for item in array:
			if not is_deep_frozen(item):
				return false
	return true


## ¿Solo tipos simples? Un Object dentro del snapshot no se podría congelar.
static func is_plain_data(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
			return true
		TYPE_DICTIONARY:
			var dictionary: Dictionary = value
			for key in dictionary.keys():
				if not is_plain_data(key) or not is_plain_data(dictionary[key]):
					return false
			return true
		TYPE_ARRAY:
			var array: Array = value
			for item in array:
				if not is_plain_data(item):
					return false
			return true
	return false


# ---------------------------------------------------------------- internos

static func _build_self(actor_id: String) -> Dictionary:
	var resources: Dictionary = {}
	if Resources.has_entity(actor_id):
		for resource_id in SELF_RESOURCES:
			if Resources.has_resource(actor_id, resource_id):
				resources[resource_id] = Resources.get_resource_amount(actor_id, resource_id)
	return {
		"id": actor_id,
		"hp_ratio": Combat.get_hp_ratio(actor_id),
		"hp_state": Combat.get_hp_state(actor_id),
		"resources": resources,
		"conditions": Combat.get_visible_conditions(actor_id).duplicate(),
		"last_attacker_id": Combat.get_last_attacker(actor_id),
	}


static func _build_player() -> Dictionary:
	return {
		"id": PLAYER_ID,
		"hp_state": Combat.get_hp_state(PLAYER_ID),
		"conditions": Combat.get_visible_conditions(PLAYER_ID).duplicate(),
		"last_attacker_id": Combat.get_last_attacker(PLAYER_ID),
	}


## Entradas aparentes de un bando (ordenadas por id, sin el propio actor). Incluye a los
## caídos con `targetable = false`: `protect` y las órdenes necesitan saber que existen.
static func _build_entries(side: StringName, observer_side: StringName, actor_id: String) -> Array:
	var ids: Array[String] = Combat.get_combatant_ids(side)
	ids.sort()
	var entries: Array = []
	for entity_id in ids:
		if entity_id == actor_id:
			continue
		var conditions: Array[StringName] = Combat.get_visible_conditions(entity_id)
		entries.append({
			"id": entity_id,
			"hp_state": Combat.get_hp_state(entity_id),
			"threat": Combat.estimate_threat(observer_side, entity_id),
			"conditions": conditions,
			"targetable": not (conditions.has(CombatTags.CONDITION_INCAPACITATED) or conditions.has(CombatTags.CONDITION_FLED)),
		})
	return entries
