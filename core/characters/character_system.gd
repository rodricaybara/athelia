class_name CharacterSystem
extends Node

## CharacterSystem - Gestor centralizado de personajes
## Singleton: /root/Characters
## Responsabilidades:
## - Registrar/desregistrar entidades
## - Almacenar CharacterState por entidad
## - Exponer API de consulta
## - Emitir eventos de cambios
## - Cargar definiciones desde archivos
##
## NO CALCULA atributos derivados (eso es AttributeResolver)
## NO EJECUTA lÃ³gica de combate/habilidades

# ============================================
# SEÃ‘ALES
# ============================================

## Emitido cuando se registra una nueva entidad
signal character_registered(entity_id: String, definition_id: String)

## Emitido cuando se desregistra una entidad
signal character_unregistered(entity_id: String)

## Emitido cuando cambia un atributo base
signal base_attribute_changed(entity_id: String, attr_id: String, old_value: float, new_value: float)

## Emitido cuando se aÃ±ade un modificador equipado
signal modifier_added(entity_id: String, modifier: ModifierDefinition)

## Emitido cuando se remueve un modificador equipado
signal modifier_removed(entity_id: String, modifier: ModifierDefinition)

## Emitido cuando se solicita recalcular derivados (para ModifierApplicator)
signal recalculation_requested(entity_id: String)


# ============================================
# ESTADO INTERNO
# ============================================

## Registry de estados por entidad: { entity_id: String -> CharacterState }
var _characters: Dictionary = {}

## CatÃ¡logo de definiciones cargadas: { definition_id: String -> CharacterDefinition }
var _definitions: Dictionary = {}


# ============================================
# INICIALIZACIÃ“N
# ============================================

func _ready():
	_load_character_definitions()
	print("[CharacterSystem] Initialized with %d character types" % _definitions.size())
	_print_available_definitions()


## Carga todas las definiciones desde data/characters/
func _load_character_definitions():
	_load_from_directory("res://data/characters/")
	
func _load_from_directory(path: String):
	var dir = DirAccess.open(path)
	if not dir:
		push_warning("[CharacterSystem] Directory not found: %s" % path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			# Entrar en subdirectorio recursivamente
			_load_from_directory(path + file_name + "/")
		elif file_name.ends_with(".tres"):
			_load_character_from_resource(path + file_name)
		file_name = dir.get_next()
	
	dir.list_dir_end()


## Carga una definiciÃ³n desde un archivo .tres
func _load_character_from_resource(file_path: String):
	var char_def = load(file_path) as CharacterDefinition
	
	if not char_def:
		push_error("[CharacterSystem] Failed to load: %s" % file_path)
		return
	
	# Validar
	if not char_def.validate():
		push_error("[CharacterSystem] Validation failed for: %s" % file_path)
		return
	
	# Verificar duplicados
	if _definitions.has(char_def.id):
		push_warning("[CharacterSystem] Duplicate definition ID '%s' (overwriting)" % char_def.id)
	
	# Registrar
	_definitions[char_def.id] = char_def
	print("[CharacterSystem] Loaded: %s" % char_def.id)


## Debug: imprime definiciones disponibles
func _print_available_definitions():
	if _definitions.is_empty():
		print("[CharacterSystem] No character definitions loaded")
		return
	
	print("[CharacterSystem] Available character types:")
	for def_id in _definitions.keys():
		var def = _definitions[def_id]
		print("  - %s (STR=%d, DEX=%d, CON=%d)" % [
			def_id,
			def.get_base_attribute("strength"),
			def.get_base_attribute("dexterity"),
			def.get_base_attribute("constitution")
		])


# ============================================
# GESTIÃ“N DE ENTIDADES
# ============================================

## Registra una nueva entidad con su CharacterState
## Retorna true si se registrÃ³ correctamente
func register_entity(entity_id: String, definition_id: String) -> bool:
	# Verificar que no exista ya
	if _characters.has(entity_id):
		push_warning("[CharacterSystem] Entity already registered: %s" % entity_id)
		return false
	
	# Verificar que la definiciÃ³n exista
	if not _definitions.has(definition_id):
		push_error("[CharacterSystem] Unknown character definition: %s" % definition_id)
		push_error("[CharacterSystem] Available definitions: %s" % _definitions.keys())
		return false
	
	# Crear CharacterState
	var definition = _definitions[definition_id]
	var state = CharacterState.new(definition)
	
	if not state:
		push_error("[CharacterSystem] Failed to create CharacterState for '%s'" % entity_id)
		return false
	
	# Registrar
	_characters[entity_id] = state
	
	# Emitir evento
	character_registered.emit(entity_id, definition_id)
	
	print("[CharacterSystem] Registered '%s' as '%s'" % [entity_id, definition_id])
	
	return true


## Desregistra una entidad
## Retorna true si se desregistrÃ³ correctamente
func unregister_entity(entity_id: String) -> bool:
	if not _characters.has(entity_id):
		push_warning("[CharacterSystem] Cannot unregister unknown entity: %s" % entity_id)
		return false
	
	_characters.erase(entity_id)
	
	# Emitir evento
	character_unregistered.emit(entity_id)
	
	print("[CharacterSystem] Unregistered: %s" % entity_id)
	
	return true


## Verifica si una entidad estÃ¡ registrada
func has_entity(entity_id: String) -> bool:
	return _characters.has(entity_id)


## Obtiene lista de todas las entidades registradas
func get_registered_entities() -> Array[String]:
	var result: Array[String] = []
	result.assign(_characters.keys())
	return result


# ============================================
# ACCESO A ESTADOS
# ============================================

## Obtiene el CharacterState de una entidad
## Retorna null si no existe
func get_character_state(entity_id: String) -> CharacterState:
	if not _characters.has(entity_id):
		push_warning("[CharacterSystem] Entity not found: %s" % entity_id)
		return null
	
	return _characters[entity_id]


## Obtiene la definiciÃ³n de una entidad
func get_character_definition(entity_id: String) -> CharacterDefinition:
	var state = get_character_state(entity_id)
	return state.definition if state else null


# ============================================
# ATRIBUTOS BASE
# ============================================

## Obtiene el valor actual de un atributo base (sin modificadores)
func get_base_attribute(entity_id: String, attr_id: String) -> float:
	var state = get_character_state(entity_id)
	return state.get_base_attribute(attr_id) if state else 0.0


## Modifica un atributo base (level-up, permanent curse, etc.)
## NO usar para buffs temporales (esos son modificadores)
func modify_base_attribute(entity_id: String, attr_id: String, delta: float) -> void:
	var state = get_character_state(entity_id)
	if not state:
		return
	
	# Obtener valor anterior
	var old_value = state.get_base_attribute(attr_id)
	
	# Modificar
	state.modify_base_attribute(attr_id, delta)
	
	# Obtener nuevo valor
	var new_value = state.get_base_attribute(attr_id)
	
	# Emitir evento solo si cambiÃ³ realmente
	if abs(new_value - old_value) > 0.001:
		base_attribute_changed.emit(entity_id, attr_id, old_value, new_value)
		print("[CharacterSystem] %s.%s: %.1f â†’ %.1f (%+.1f)" % [
			entity_id, attr_id, old_value, new_value, delta
		])


## Establece un atributo base a un valor especÃ­fico
func set_base_attribute(entity_id: String, attr_id: String, value: float) -> void:
	var state = get_character_state(entity_id)
	if not state:
		return
	
	var old_value = state.get_base_attribute(attr_id)
	state.set_base_attribute(attr_id, value)
	var new_value = state.get_base_attribute(attr_id)
	
	if abs(new_value - old_value) > 0.001:
		base_attribute_changed.emit(entity_id, attr_id, old_value, new_value)


## Obtiene todos los atributos base de una entidad
func get_all_base_attributes(entity_id: String) -> Dictionary:
	var state = get_character_state(entity_id)
	return state.attributes.duplicate() if state else {}


# ============================================
# RECURSOS
# ============================================

## Obtiene el valor actual de un recurso
func get_resource(entity_id: String, resource_id: String) -> float:
	var state = get_character_state(entity_id)
	return state.get_resource(resource_id) if state else 0.0


## Establece un recurso a un valor especÃ­fico
func set_resource(entity_id: String, resource_id: String, value: float) -> void:
	var state = get_character_state(entity_id)
	if state:
		state.set_resource(resource_id, value)


## Modifica un recurso (aÃ±adir/restar)
func modify_resource(entity_id: String, resource_id: String, delta: float) -> void:
	var state = get_character_state(entity_id)
	if state:
		state.modify_resource(resource_id, delta)


## Obtiene todos los recursos de una entidad
func get_all_resources(entity_id: String) -> Dictionary:
	var state = get_character_state(entity_id)
	return state.resources.duplicate() if state else {}


# ============================================
# SKILL VALUES (FASE C.1.5)
# ============================================

## Obtiene el valor de una habilidad (% de éxito)
func get_skill_value(entity_id: String, skill_id: String) -> int:
	var state = get_character_state(entity_id)
	return state.get_skill_value(skill_id) if state else 0


## Establece el valor de una habilidad
func set_skill_value(entity_id: String, skill_id: String, value: int) -> void:
	var state = get_character_state(entity_id)
	if state:
		state.set_skill_value(skill_id, value)


## Modifica el valor de una habilidad (incremento/decremento)
func modify_skill_value(entity_id: String, skill_id: String, delta: int) -> void:
	var state = get_character_state(entity_id)
	if state:
		state.modify_skill_value(skill_id, delta)


## Lista todas las habilidades conocidas de una entidad
func list_known_skills(entity_id: String) -> Array[String]:
	var state = get_character_state(entity_id)
	return state.list_known_skills() if state else []


## Obtiene todos los skill values de una entidad
func get_all_skill_values(entity_id: String) -> Dictionary:
	var state = get_character_state(entity_id)
	return state.skill_values.duplicate() if state else {}


# ============================================
# MODIFICADORES
# ============================================

## AÃ±ade un modificador equipado (item, permanente)
func add_equipped_modifier(entity_id: String, modifier: ModifierDefinition) -> void:
	var state = get_character_state(entity_id)
	if not state:
		return
	
	if modifier == null:
		push_warning("[CharacterSystem] Cannot add null modifier to '%s'" % entity_id)
		return
	
	state.add_equipped_modifier(modifier)
	
	# Emitir evento
	modifier_added.emit(entity_id, modifier)
	
	print("[CharacterSystem] Added modifier to '%s': %s" % [entity_id, modifier])
	
	# Solicitar recalculo de derivados
	recalculation_requested.emit(entity_id)


## Remueve un modificador equipado
func remove_equipped_modifier(entity_id: String, modifier: ModifierDefinition) -> bool:
	var state = get_character_state(entity_id)
	if not state:
		return false
	
	var success = state.remove_equipped_modifier(modifier)
	
	if success:
		# Emitir evento
		modifier_removed.emit(entity_id, modifier)
		
		print("[CharacterSystem] Removed modifier from '%s': %s" % [entity_id, modifier])
		
		# Solicitar recalculo de derivados
		recalculation_requested.emit(entity_id)
	
	return success


## Obtiene TODOS los modificadores activos (equipados + temporales)
func get_active_modifiers(entity_id: String) -> Array[ModifierDefinition]:
	var state = get_character_state(entity_id)
	if not state:
		return []
	
	return state.get_all_active_modifiers()


## Obtiene solo los modificadores equipados
func get_equipped_modifiers(entity_id: String) -> Array[ModifierDefinition]:
	var state = get_character_state(entity_id)
	if not state:
		return []
	
	return state.get_equipped_modifiers()

## Añade un bonus temporal de skill que se consumirá en el próximo roll.
## Llamado por ItemCharacterBridge cuando se usa un ítem con duration_type="next_skill_roll".
func add_pending_skill_modifier(entity_id: String, skill_id: String, bonus: int) -> void:
	var state := get_character_state(entity_id)
	if not state:
		push_warning("[CharacterSystem] add_pending_skill_modifier: entity '%s' not found" % entity_id)
		return
	state.add_pending_skill_modifier(skill_id, bonus)
	print("[CharacterSystem] Pending +%d to '%s' for '%s'" % [bonus, skill_id, entity_id])

## Consume y retorna el bonus pendiente para una skill. Retorna 0 si no había ninguno.
## Llamado por WorldObjectSystem/CombatSystem justo antes del roll.
func consume_pending_skill_modifier(entity_id: String, skill_id: String) -> int:
	var state := get_character_state(entity_id)
	if not state:
		return 0
	var bonus := state.consume_pending_skill_modifier(skill_id)
	if bonus != 0:
		print("[CharacterSystem] Consumed pending +%d for '%s' on '%s'" % [bonus, skill_id, entity_id])
	return bonus

# ============================================
# ESTADOS TEMPORALES
# ============================================

## AÃ±ade un estado temporal (buff/debuff)
## Nota: Esta funciÃ³n es principalmente para ModifierApplicator
func add_temporary_state(entity_id: String, state_data: Dictionary) -> void:
	var state = get_character_state(entity_id)
	if state:
		state.add_temporary_state(state_data)
		recalculation_requested.emit(entity_id)


## Remueve un estado temporal por ID
func remove_temporary_state(entity_id: String, state_id: String) -> bool:
	var state = get_character_state(entity_id)
	if not state:
		return false
	
	var success = state.remove_temporary_state(state_id)
	if success:
		recalculation_requested.emit(entity_id)
	
	return success


## Obtiene todos los estados temporales activos
func get_active_states(entity_id: String) -> Array:
	var state = get_character_state(entity_id)
	return state.active_states.duplicate() if state else []


# ============================================
# DEFINICIONES
# ============================================

## Obtiene una definiciÃ³n por ID
func get_definition(definition_id: String) -> CharacterDefinition:
	return _definitions.get(definition_id, null)


## Verifica si existe una definiciÃ³n
func has_definition(definition_id: String) -> bool:
	return _definitions.has(definition_id)


## Lista todas las definiciones disponibles
func list_definitions() -> Array[String]:
	var result: Array[String] = []
	result.assign(_definitions.keys())
	return result


# ============================================
# DEBUG
# ============================================

## Imprime el estado completo de una entidad
func print_character(entity_id: String):
	if not _characters.has(entity_id):
		print("[CharacterSystem] Entity not found: %s" % entity_id)
		return
	
	var state = _characters[entity_id]
	
	print("\n" + "=".repeat(50))
	print("CHARACTER: %s" % entity_id)
	print("\n" + "=".repeat(50))
	print("Definition: %s" % state.definition.id)
	
	print("\nBase Attributes:")
	for attr in state.attributes.keys():
		print("  %s: %.1f" % [attr, state.attributes[attr]])
	
	print("\nResources (current):")
	for res in state.resources.keys():
		print("  %s: %.1f" % [res, state.resources[res]])
	
	print("\nEquipped Modifiers: %d" % state.equipped_modifiers.size())
	for mod in state.equipped_modifiers:
		print("  - %s %s %.1f on %s" % [mod.operation, mod.value, mod.target])
	
	print("\nActive States: %d" % state.active_states.size())
	for temp_state in state.active_states:
		print("  - %s (%.1fs left)" % [
			temp_state.get("id", "?"),
			temp_state.get("time_left", 0)
		])
	
	print("\n" + "=".repeat(50))


## Imprime todas las entidades registradas
func print_all_entities():
	if _characters.is_empty():
		print("[CharacterSystem] No entities registered")
		return
	
	print("\n[CharacterSystem] Registered Entities:")
	for entity_id in _characters.keys():
		var state = _characters[entity_id]
		print("  - %s (%s)" % [entity_id, state.definition.id])


# ============================================
# SAVE/LOAD (PreparaciÃ³n futura)
# ============================================

## Obtiene snapshot de una entidad para guardar
func get_save_state(entity_id: String) -> Dictionary:
	var state = get_character_state(entity_id)
	if not state:
		return {}
	
	return state.get_save_state()


## Carga snapshot de una entidad
func load_save_state(entity_id: String, save_data: Dictionary) -> bool:
	# Si la entidad no existe, crearla
	if not _characters.has(entity_id):
		var definition_id = save_data.get("definition_id", "")
		if not register_entity(entity_id, definition_id):
			return false
	
	var state = get_character_state(entity_id)
	if state:
		state.load_save_state(save_data)
		return true
	
	return false


## Obtiene snapshot de TODAS las entidades
func get_save_state_all() -> Dictionary:
	var save_data = {}
	
	for entity_id in _characters.keys():
		save_data[entity_id] = get_save_state(entity_id)
	
	return save_data


## Carga snapshot de TODAS las entidades
func load_save_state_all(save_data: Dictionary) -> void:
	for entity_id in save_data.keys():
		load_save_state(entity_id, save_data[entity_id])
