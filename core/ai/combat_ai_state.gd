class_name CombatAIState
extends RefCounted

## CombatAIState — Estado de IA de UN combatiente durante UN combate (IA-1a).
##
## Vive lo que dura el combate y no entra en el guardado. En IA-1a solo el perfil está en
## uso; la orden activa (IA-3) y la moral (IA-4) están reservadas para no cambiar el
## contrato después. El último atacante NO vive aquí: lo registra Combat.

const MORALE_STEADY: StringName = &"STEADY"
const MORALE_SHAKEN: StringName = &"SHAKEN"
const MORALE_BROKEN: StringName = &"BROKEN"

var entity_id: String = ""
## Id que se pidió (puede ser &"" o inexistente); `profile.id` es el que se aplicó.
var requested_profile_id: StringName = &""
## Duplicado independiente: modificarlo no toca el registry ni a otros combatientes.
var profile: BehaviorProfile = null
var used_fallback: bool = false

## Reservado para IA-3: id de la orden activa de un aliado.
var active_order: StringName = &""
## Reservado para IA-4: "<tipo>:<id_origen>" -> true.
var processed_morale_events: Dictionary = {}
## Reservado para IA-4.
var morale_state: StringName = MORALE_STEADY


static func create(p_entity_id: String, p_profile_id: StringName, warn_missing: bool = true) -> CombatAIState:
	var state: CombatAIState = new()
	state.entity_id = p_entity_id
	state.requested_profile_id = p_profile_id
	state.profile = BehaviorProfileRegistry.get_profile(p_profile_id, warn_missing)
	state.used_fallback = state.profile.id != p_profile_id
	return state


## Una línea para el log de registro del combate.
func describe() -> String:
	var origin: String = "perfil %s" % String(profile.id)
	if used_fallback:
		origin += " [seguro: se pidió '%s']" % String(requested_profile_id)
	return "%s → %s, %s" % [entity_id, origin, profile.summary()]
