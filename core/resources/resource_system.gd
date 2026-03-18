class_name ResourceSystem
extends Node

## ResourceSystem - Gestor central de recursos del juego
## Responsabilidades:
## - Gestionar recursos de todas las entidades (jugador, enemigos, NPCs)
## - Validar costes
## - Aplicar cambios
## - Regenerar recursos
## - Emitir eventos

## Señales
signal resource_changed(entity_id: String, resource_id: String, current: float, max_value: float)
signal resource_depleted(entity_id: String, resource_id: String)
signal payment_failed(entity_id: String, bundle: ResourceBundle)

## Registro: { entity_id: String -> { resource_id: String -> ResourceState } }
var _entities: Dictionary = {}

## Catálogo de definiciones disponibles
var _resource_definitions: Dictionary = {}


## Inicialización
func _ready():
	_load_resource_definitions()
	print("[ResourceSystem] Initialized with %d resource types" % _resource_definitions.size())


## Carga las definiciones de recursos disponibles
func _load_resource_definitions():
	# Cargar desde res://data/resources/
	var resource_files = ["health", "stamina", "gold"]
	
	for res_name in resource_files:
		var path = "res://data/resources/%s.tres" % res_name
		var res_def = load(path) as ResourceDefinition
		
		if res_def and res_def.validate():
			_resource_definitions[res_def.id] = res_def
			print("[ResourceSystem] Loaded definition: ", res_def.id)
		else:
			push_error("[ResourceSystem] Failed to load: %s" % path)


## Registra una nueva entidad con recursos
func register_entity(entity_id: String, resource_ids: Array = []) -> void:
	if _entities.has(entity_id):
		push_warning("[ResourceSystem] Entity already registered: %s" % entity_id)
		return
	
	_entities[entity_id] = {}
	
	# Si no se especifican recursos, usar todos los disponibles
	if resource_ids.is_empty():
		resource_ids = _resource_definitions.keys()
	
	# Crear ResourceState para cada recurso
	for res_id in resource_ids:
		if not _resource_definitions.has(res_id):
			push_error("[ResourceSystem] Unknown resource: %s" % res_id)
			continue
		
		var definition = _resource_definitions[res_id]
		var state = ResourceState.new(definition)
		_entities[entity_id][res_id] = state
	
	print("[ResourceSystem] Registered entity '%s' with %d resources" % [entity_id, resource_ids.size()])


## Desregistra una entidad
func unregister_entity(entity_id: String) -> void:
	if _entities.erase(entity_id):
		print("[ResourceSystem] Unregistered entity: %s" % entity_id)


## Obtiene el estado de un recurso de una entidad
func get_resource_state(entity_id: String, resource_id: String) -> ResourceState:
	if not _entities.has(entity_id):
		push_error("[ResourceSystem] Entity not found: %s" % entity_id)
		return null
	
	if not _entities[entity_id].has(resource_id):
		push_error("[ResourceSystem] Resource '%s' not found for entity '%s'" % [resource_id, entity_id])
		return null
	
	return _entities[entity_id][resource_id]


## Obtiene el valor actual de un recurso
func get_resource_amount(entity_id: String, resource_id: String) -> float:
	var state = get_resource_state(entity_id, resource_id)
	return state.current if state else 0.0


## Obtiene el porcentaje de un recurso (0.0 a 1.0)
func get_resource_percentage(entity_id: String, resource_id: String) -> float:
	var state = get_resource_state(entity_id, resource_id)
	return state.get_percentage() if state else 0.0


## ¿Puede pagar un bundle de recursos?
func can_pay(entity_id: String, bundle: ResourceBundle) -> bool:
	if not _entities.has(entity_id):
		return false
	
	# Verificar cada recurso del bundle
	for res_id in bundle.get_resource_ids():
		var cost = bundle.get_cost(res_id)
		var state = get_resource_state(entity_id, res_id)
		
		if state == null or not state.can_pay(cost):
			return false
	
	return true


## Aplica un coste (resta recursos)
func apply_cost(entity_id: String, bundle: ResourceBundle) -> bool:
	if not can_pay(entity_id, bundle):
		payment_failed.emit(entity_id, bundle)
		return false
	
	# Aplicar todos los costes
	for res_id in bundle.get_resource_ids():
		var cost = bundle.get_cost(res_id)
		var state = get_resource_state(entity_id, res_id)
		
		if state:
			state.subtract(cost)
			_emit_resource_changed(entity_id, res_id, state)
	
	return true


## Añade recursos (curación, recompensa, etc.)
func add_resource(entity_id: String, resource_id: String, amount: float) -> float:
	var state = get_resource_state(entity_id, resource_id)
	if not state:
		return 0.0
	
	var added = state.add(amount)
	_emit_resource_changed(entity_id, resource_id, state)
	return added


## Establece un recurso a un valor específico
func set_resource(entity_id: String, resource_id: String, value: float) -> void:
	var state = get_resource_state(entity_id, resource_id)
	if not state:
		return
	
	state.set_current(value)
	_emit_resource_changed(entity_id, resource_id, state)


## Restaura un recurso al máximo
func restore_resource(entity_id: String, resource_id: String) -> void:
	var state = get_resource_state(entity_id, resource_id)
	if not state:
		return
	
	state.restore_full()
	_emit_resource_changed(entity_id, resource_id, state)


## Actualiza el máximo efectivo de un recurso (buffs, equipo)
func set_max_effective(entity_id: String, resource_id: String, new_max: float) -> void:
	var state = get_resource_state(entity_id, resource_id)
	if not state:
		return
	
	state.set_max_effective(new_max)
	_emit_resource_changed(entity_id, resource_id, state)


## Pausa/reanuda la regeneración de un recurso
func set_regen_paused(entity_id: String, resource_id: String, paused: bool) -> void:
	var state = get_resource_state(entity_id, resource_id)
	if state:
		state.regen_paused = paused


## Proceso de regeneración (llamado cada frame)
func _process(delta: float):
	for entity_id in _entities.keys():
		for res_id in _entities[entity_id].keys():
			var state = _entities[entity_id][res_id] as ResourceState
			
			var regen_amount = state.process_regeneration(delta)
			
			# Emitir evento solo si hubo regeneración real
			if regen_amount > 0:
				_emit_resource_changed(entity_id, res_id, state)


## Emite señal de cambio de recurso
func _emit_resource_changed(entity_id: String, resource_id: String, state: ResourceState):
	resource_changed.emit(entity_id, resource_id, state.current, state.max_effective)
	
	# Emitir evento de agotamiento si llegó a 0
	if state.is_empty() and not state.definition.is_infinite:
		resource_depleted.emit(entity_id, resource_id)


## Debug: imprime el estado de una entidad
func print_entity_resources(entity_id: String):
	if not _entities.has(entity_id):
		print("[ResourceSystem] Entity not found: %s" % entity_id)
		return
	
	print("\n[ResourceSystem] Entity: %s" % entity_id)
	for res_id in _entities[entity_id].keys():
		var state = _entities[entity_id][res_id]
		print("  - %s" % state)


## Obtiene snapshot para SaveSystem (futuro)
func get_save_state(entity_id: String) -> Dictionary:
	if not _entities.has(entity_id):
		return {}
	
	var save_data = {}
	for res_id in _entities[entity_id].keys():
		var state = _entities[entity_id][res_id] as ResourceState
		save_data[res_id] = {
			"current": state.current,
			"max_effective": state.max_effective
		}
	
	return save_data


## Carga snapshot desde SaveSystem (futuro)
func load_save_state(entity_id: String, save_data: Dictionary):
	if not _entities.has(entity_id):
		return
	
	for res_id in save_data.keys():
		var state = get_resource_state(entity_id, res_id)
		if state:
			state.current = save_data[res_id].get("current", state.max_effective)
			state.max_effective = save_data[res_id].get("max_effective", state.definition.max_base)
