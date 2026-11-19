class_name CombatAIContext
extends RefCounted

## CombatAIContext — Lo que la IA comparte durante UN combate (IA-1a).
##
## Reúne el RNG de IA (independiente del RNG de combate de SkillRoller y del RNG global) y
## un CombatAIState por actor de IA (enemigos y companions; el protagonista no es de IA).
## Lo crea CombatProductionScene al empezar el combate y se suelta al acabar.
##
## El estado del RNG es un entero de 64 bits que NO sobrevive a JSON como número (se pierde
## precisión por encima de 2^53, comprobado en 4.7.2): para el log se exponen como texto.

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var seed_value: int = 0

var _states: Dictionary = {}   # entity_id -> CombatAIState


func _init() -> void:
	rng.randomize()
	seed_value = rng.seed


# ------------------------------------------------------------------- RNG

## Fija la semilla (reproducibilidad en pruebas y en modo sin interfaz).
func set_seed(new_seed: int) -> void:
	rng.seed = new_seed
	seed_value = new_seed


func rng_seed_string() -> String:
	return str(seed_value)


func rng_state_string() -> String:
	return str(rng.state)


## Reanuda el RNG en un estado guardado con rng_state_string(). false si el texto no es válido.
func restore_rng_state(state_text: String) -> bool:
	if not state_text.is_valid_int():
		return false
	rng.state = state_text.to_int()
	return true


func roll_int(min_value: int, max_value: int) -> int:
	return rng.randi_range(min_value, max_value)


## Elige uno por sorteo uniforme (desempates). Una sola opción no consume el RNG; vacío → null.
## Quien llama pasa las opciones en orden canónico para que el resultado sea reproducible.
func pick_one(items: Array) -> Variant:
	if items.is_empty():
		return null
	if items.size() == 1:
		return items[0]
	return items[rng.randi_range(0, items.size() - 1)]


# ---------------------------------------------------------------- estados

## Id de perfil de la definición del combatiente (&"" si no está registrado o no lo declara).
static func resolve_profile_id(entity_id: String) -> StringName:
	if not Characters.has_entity(entity_id):
		return &""
	var definition: CharacterDefinition = Characters.get_character_definition(entity_id)
	if definition == null:
		return &""
	return definition.behavior_profile_id


## Crea (o devuelve el existente) el estado de IA de un combatiente con un perfil explícito.
func register(entity_id: String, profile_id: StringName, warn_missing: bool = true) -> CombatAIState:
	if _states.has(entity_id):
		return _states[entity_id] as CombatAIState
	var state: CombatAIState = CombatAIState.create(entity_id, profile_id, warn_missing)
	_states[entity_id] = state
	return state


## Como register(), con el perfil que declara su CharacterDefinition.
func register_entity(entity_id: String, warn_missing: bool = true) -> CombatAIState:
	return register(entity_id, resolve_profile_id(entity_id), warn_missing)


func has_state(entity_id: String) -> bool:
	return _states.has(entity_id)


func get_state(entity_id: String) -> CombatAIState:
	return _states.get(entity_id, null) as CombatAIState


func get_state_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in _states.keys():
		ids.append(key)
	ids.sort()
	return ids


func size() -> int:
	return _states.size()


## Suelta todos los estados (fin de combate).
func release() -> void:
	_states.clear()
