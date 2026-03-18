class_name CharacterState
extends RefCounted

## CharacterState - Estado mutable de un personaje
## Parte del CharacterSystem
## Representa el ESTADO ACTUAL de una entidad viva en el mundo
##
## IMPORTANTE: Solo almacena estado PERSISTENTE
## - Atributos base actuales (pueden cambiar por level-up, curses)
## - Recursos actuales (NO mÃ¡ximos, se calculan dinÃ¡micamente)
## - Modificadores equipados (items, permanentes)
## - Estados temporales (buffs, debuffs) - NO SE PERSISTEN

# ============================================
# REFERENCIAS
# ============================================

## Referencia a la definiciÃ³n inmutable
var definition: CharacterDefinition


# ============================================
# ESTADO PERSISTENTE
# ============================================

## Atributos base ACTUALES
## Pueden cambiar por level-up, progresiÃ³n, maldiciones permanentes
## NO incluir atributos derivados (armor, hp_max, etc.)
var attributes: Dictionary = {}

## Recursos ACTUALES (NO mÃ¡ximos)
## Ejemplos: { "health": 28, "stamina": 15, "gold": 150 }
## Los mÃ¡ximos (health_max, stamina_max) se calculan dinÃ¡micamente
var resources: Dictionary = {}

## Modificadores equipados (items, efectos permanentes)
## Se aplican siempre mientras estÃ©n en el array
var equipped_modifiers: Array[ModifierDefinition] = []

## Valores de habilidades (% de Ã©xito 0-100)
## Formato: { skill_id: String -> value: int }
## Ejemplo: { "skill.attack.light": 35, "skill.magic.fireball": 20 }
## FASE C.1.5: Sistema de tiradas RuneQuest
var skill_values: Dictionary = {}


# ============================================
# ESTADO TEMPORAL (NO SE PERSISTE)
# ============================================

## Estados temporales activos (buffs, debuffs)
## Formato: [{ "id": String, "modifiers": Array[ModifierDefinition], "duration": float, "time_left": float }]
## NO se guardan en save, se reconstruyen en runtime si es necesario
var active_states: Array = []

## Modificadores pendientes de skill: se aplican en el próximo roll de esa skill y se consumen.
## Formato: { skill_id: String -> bonus: int }
## Ejemplo: { "skill.exploration.lockpick": 15 }
## NO se persiste en save — se reconstruye si el ítem se usa antes de guardar.
var pending_skill_modifiers: Dictionary = {}

# ============================================
# CONSTRUCTOR
# ============================================

## Constructor
func _init(def: CharacterDefinition):
	if def == null:
		push_error("[CharacterState] definition cannot be null")
		return
	
	if not def.validate():
		push_error("[CharacterState] definition validation failed for '%s'" % def.id)
		return
	
	definition = def
	
	# Copiar atributos base desde definiciÃ³n
	attributes = definition.base_attributes.duplicate()
	
	# Copiar recursos iniciales desde definiciÃ³n
	resources = definition.starting_resources.duplicate()
	
	# FASE C.1.5: Copiar skill values iniciales desde definiciÃ³n
	if definition.starting_skill_values:
		skill_values = definition.starting_skill_values.duplicate()
	else:
		skill_values = {}
	
	print("[CharacterState] Created for '%s'" % definition.id)


# ============================================
# ATRIBUTOS BASE
# ============================================

## Obtiene el valor ACTUAL de un atributo base (sin modificadores)
func get_base_attribute(attr_id: String) -> float:
	if not attributes.has(attr_id):
		push_warning("[CharacterState] Unknown attribute: %s" % attr_id)
		return 0.0
	
	return attributes[attr_id]


## Modifica un atributo base (level-up, maldiciÃ³n permanente, etc.)
## NO usar para buffs temporales (esos son modificadores)
func modify_base_attribute(attr_id: String, delta: float) -> void:
	if not attributes.has(attr_id):
		push_warning("[CharacterState] Unknown attribute: %s" % attr_id)
		return
	
	attributes[attr_id] += delta
	
	# Asegurar que no sea negativo (opcional segÃºn diseÃ±o)
	attributes[attr_id] = maxf(1.0, attributes[attr_id])


## Establece un atributo base a un valor especÃ­fico
func set_base_attribute(attr_id: String, value: float) -> void:
	if not attributes.has(attr_id):
		push_warning("[CharacterState] Unknown attribute: %s" % attr_id)
		return
	
	attributes[attr_id] = maxf(1.0, value)


# ============================================
# RECURSOS
# ============================================

## Obtiene el valor actual de un recurso
func get_resource(resource_id: String) -> float:
	return resources.get(resource_id, 0.0)


## Establece un recurso a un valor especÃ­fico
func set_resource(resource_id: String, value: float) -> void:
	resources[resource_id] = value


## Modifica un recurso (aÃ±adir/restar)
func modify_resource(resource_id: String, delta: float) -> void:
	if not resources.has(resource_id):
		resources[resource_id] = 0.0
	
	resources[resource_id] += delta


# ============================================
# MODIFICADORES
# ============================================

## AÃ±ade un modificador equipado
func add_equipped_modifier(modifier: ModifierDefinition) -> void:
	if modifier == null:
		push_warning("[CharacterState] Cannot add null modifier")
		return
	
	equipped_modifiers.append(modifier)


## Remueve un modificador equipado
func remove_equipped_modifier(modifier: ModifierDefinition) -> bool:
	var idx = equipped_modifiers.find(modifier)
	if idx >= 0:
		equipped_modifiers.remove_at(idx)
		return true
	return false


## Obtiene todos los modificadores equipados
func get_equipped_modifiers() -> Array[ModifierDefinition]:
	return equipped_modifiers.duplicate()


# ============================================
# SKILL VALUES (FASE C.1.5)
# ============================================

## Obtiene el valor de una habilidad (% de éxito)
## Retorna 0 si la habilidad no está en el diccionario
func get_skill_value(skill_id: String) -> int:
	return skill_values.get(skill_id, 0)


## Establece el valor de una habilidad
## Clampea entre 0 y 100
func set_skill_value(skill_id: String, value: int) -> void:
	skill_values[skill_id] = clampi(value, 0, 100)


## Modifica el valor de una habilidad (incremento/decremento)
## Útil para progresión: increase_skill_value("skill.attack.light", 5)
func modify_skill_value(skill_id: String, delta: int) -> void:
	var current = get_skill_value(skill_id)
	set_skill_value(skill_id, current + delta)


## ¿Tiene esta habilidad registrada?
func has_skill(skill_id: String) -> bool:
	return skill_values.has(skill_id)


## Lista todas las habilidades conocidas
func list_known_skills() -> Array[String]:
	var result: Array[String] = []
	result.assign(skill_values.keys())
	return result

## Añade un bonus pendiente para una skill. Se acumula si ya había uno.
func add_pending_skill_modifier(skill_id: String, bonus: int) -> void:
	pending_skill_modifiers[skill_id] = pending_skill_modifiers.get(skill_id, 0) + bonus

## Consume y devuelve el bonus pendiente para una skill. Retorna 0 si no había ninguno.
## Llamar justo antes de calcular el roll — el bonus desaparece al consumirse.
func consume_pending_skill_modifier(skill_id: String) -> int:
	if not pending_skill_modifiers.has(skill_id):
		return 0
	var bonus: int = pending_skill_modifiers[skill_id]
	pending_skill_modifiers.erase(skill_id)
	return bonus

# ============================================
# ESTADOS TEMPORALES
# ============================================

## AÃ±ade un estado temporal (buff/debuff)
## Nota: Esta funciÃ³n es llamada por ModifierApplicator
func add_temporary_state(state_data: Dictionary) -> void:
	active_states.append(state_data)


## Remueve un estado temporal por ID
func remove_temporary_state(state_id: String) -> bool:
	for i in range(active_states.size()):
		if active_states[i].get("id") == state_id:
			active_states.remove_at(i)
			return true
	return false


## Obtiene todos los modificadores de estados temporales
func get_temporary_modifiers() -> Array[ModifierDefinition]:
	var result: Array[ModifierDefinition] = []
	
	for state in active_states:
		if state.has("modifiers"):
			result.append_array(state["modifiers"])
	
	return result


# ============================================
# UTILIDADES
# ============================================

## Obtiene TODOS los modificadores activos (equipados + temporales)
func get_all_active_modifiers() -> Array[ModifierDefinition]:
	var result: Array[ModifierDefinition] = []
	result.append_array(equipped_modifiers)
	result.append_array(get_temporary_modifiers())
	return result


## Debug: imprime el estado completo
func print_state() -> void:
	print("\n=== CharacterState: %s ===" % definition.id)
	
	print("Attributes:")
	for attr in attributes.keys():
		print("  %s: %.1f" % [attr, attributes[attr]])
	
	print("Resources:")
	for res in resources.keys():
		print("  %s: %.1f" % [res, resources[res]])
	
	print("Equipped modifiers: %d" % equipped_modifiers.size())
	for mod in equipped_modifiers:
		print("  - %s" % mod)
	
	print("Active states: %d" % active_states.size())
	for state in active_states:
		print("  - %s (%.1fs left)" % [state.get("id", "?"), state.get("time_left", 0)])


## Debug: representaciÃ³n string
func _to_string() -> String:
	return "CharacterState(%s, STR=%.0f, HP=%.0f, %d mods)" % [
		definition.id,
		get_base_attribute("strength"),
		get_resource("health"),
		equipped_modifiers.size() + active_states.size()
	]


# ============================================
# SAVE/LOAD (PreparaciÃ³n futura)
# ============================================

## Obtiene snapshot para guardar
func get_save_state() -> Dictionary:
	var save_data = {
		"definition_id": definition.id,
		"attributes": attributes.duplicate(),
		"resources": resources.duplicate(),
		"equipped_modifiers": []  # TODO: Serializar modificadores
	}
	
	# Nota: active_states NO se persisten, se reconstruyen en runtime
	
	return save_data


## Carga snapshot
func load_save_state(save_data: Dictionary) -> void:
	if save_data.has("attributes"):
		attributes = save_data["attributes"].duplicate()
	
	if save_data.has("resources"):
		resources = save_data["resources"].duplicate()
	
	# TODO: Deserializar equipped_modifiers si es necesario
