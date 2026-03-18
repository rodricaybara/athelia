class_name SkillSystem
extends Node

## SkillSystem - Gestor central de habilidades del juego (MEJORADO v2)
## Responsabilidades:
## - Cargar SkillDefinitions desde archivos (RECURSIVAMENTE)
## - Validar uso de habilidades
## - Gestionar cooldowns
## - Emitir eventos de habilidades
##
## MEJORA FASE C.1: Carga recursiva de subdirectorios
## Soporta estructura:
##   res://data/skills/
##   ├── combat/
##   │   ├── melee/
##   │   │   ├── attack_light.tres
##   │   │   └── attack_heavy.tres
##   │   └── ranged/
##   │       └── fireball.tres
##   └── exploration/
##       └── sprint.tres

## Señales
signal skill_used(entity_id: String, skill_id: String)
signal skill_failed(entity_id: String, skill_id: String, reason: String)
signal cooldown_started(entity_id: String, skill_id: String, duration: float)
signal cooldown_finished(entity_id: String, skill_id: String)

## Catálogo de definiciones: { skill_id: String -> SkillDefinition }
var _skill_definitions: Dictionary = {}

## Habilidades por entidad: { entity_id: String -> { skill_id: String -> SkillInstance } }
var _entity_skills: Dictionary = {}

## Referencia al ResourceSystem
var resource_system: ResourceSystem


## Inicialización
func _ready():
	# Buscar ResourceSystem
	resource_system = get_node("/root/Resources")
	if not resource_system:
		push_error("[SkillSystem] ResourceSystem not found!")
		return
	
	# Cargar definiciones de habilidades (RECURSIVAMENTE)
	_load_skill_definitions()
	
	print("[SkillSystem] Initialized with %d skill types" % _skill_definitions.size())


# ============================================
# CARGA DE DEFINICIONES (MEJORADO - RECURSIVO)
# ============================================

## Carga las definiciones de habilidades desde archivos
## NUEVO: Busca recursivamente en subdirectorios
func _load_skill_definitions():
	var skill_dir = "res://data/skills/"
	
	print("[SkillSystem] Loading skills from: %s (recursive)" % skill_dir)
	
	_load_skills_from_directory(skill_dir, true)
	
	print("[SkillSystem] Total skills loaded: %d" % _skill_definitions.size())


## Carga skills de un directorio (con opción recursiva)
## @param path: Directorio a escanear
## @param recursive: Si true, busca en subdirectorios
func _load_skills_from_directory(path: String, recursive: bool = false):
	var dir = DirAccess.open(path)
	
	if not dir:
		push_warning("[SkillSystem] Directory not found: %s" % path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		# Ignorar archivos/directorios ocultos
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		
		var full_path = path + file_name
		
		# Si es directorio y modo recursivo está activado
		if dir.current_is_dir() and recursive:
			# Añadir "/" al final si no lo tiene
			var subdir_path = full_path + "/" if not full_path.ends_with("/") else full_path
			
			print("[SkillSystem]   Scanning subdirectory: %s" % file_name)
			_load_skills_from_directory(subdir_path, true)
		
		# Si es archivo .tres
		elif file_name.ends_with(".tres"):
			_load_skill_from_resource(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()


## Carga una habilidad desde un archivo .tres
func _load_skill_from_resource(file_path: String):
	var skill_def = load(file_path) as SkillDefinition
	
	if not skill_def:
		push_error("[SkillSystem] Failed to load skill: %s" % file_path)
		return
	
	# Validar
	if not skill_def.validate():
		push_error("[SkillSystem] Validation failed for: %s" % file_path)
		return
	
	# Verificar duplicados
	if _skill_definitions.has(skill_def.id):
		push_warning("[SkillSystem] Duplicate skill ID '%s' found in %s (overwriting)" % [
			skill_def.id, file_path
		])
	
	# Registrar
	_skill_definitions[skill_def.id] = skill_def
	
	# Log con path relativo para claridad
	var relative_path = file_path.replace("res://data/skills/", "")
	print("[SkillSystem]     ✓ %s → %s" % [skill_def.id, relative_path])


# ============================================
# API PÚBLICA (Sin cambios)
# ============================================

## Obtiene una definición de habilidad
func get_skill_definition(skill_id: String) -> SkillDefinition:
	if not _skill_definitions.has(skill_id):
		push_warning("[SkillSystem] Skill not found: %s" % skill_id)
		return null
	
	return _skill_definitions[skill_id]


## Lista todas las habilidades disponibles
func list_skills() -> Array:
	return _skill_definitions.keys()

## Registra habilidades para una entidad
func register_entity_skills(entity_id: String, skill_ids: Array = []):
	if _entity_skills.has(entity_id):
		push_warning("[SkillSystem] Entity already registered: %s" % entity_id)
		return

	_entity_skills[entity_id] = {}

	if skill_ids.is_empty():
		skill_ids = _skill_definitions.keys()

	var unlocked_count: int = 0
	var locked_count: int = 0

	for skill_id in skill_ids:
		var definition = get_skill_definition(skill_id)
		if not definition:
			continue

		var instance = SkillInstance.new(definition)

		# Skills con requires_unlock=true empiezan bloqueadas.
		# Se desbloquean más tarde via unlock_skill().
		# Skills sin el campo (requires_unlock=false) se registran disponibles.
		if definition.requires_unlock:
			instance.is_unlocked = false
			locked_count += 1
		else:
			instance.is_unlocked = true
			unlocked_count += 1

		_entity_skills[entity_id][skill_id] = instance

	print("[SkillSystem] Registered '%s': %d unlocked, %d locked" % [
		entity_id, unlocked_count, locked_count
	])

## Desregistra una entidad
func unregister_entity(entity_id: String):
	if _entity_skills.erase(entity_id):
		print("[SkillSystem] Unregistered entity: %s" % entity_id)


## Obtiene la instancia de una habilidad de una entidad
func get_skill_instance(entity_id: String, skill_id: String) -> SkillInstance:
	if not _entity_skills.has(entity_id):
		push_warning("[SkillSystem] Entity not found: %s" % entity_id)
		return null
	
	if not _entity_skills[entity_id].has(skill_id):
		push_warning("[SkillSystem] Skill '%s' not found for entity '%s'" % [skill_id, entity_id])
		return null
	
	return _entity_skills[entity_id][skill_id]


## ¿Puede usar esta habilidad?
func can_use(entity_id: String, skill_id: String) -> bool:
	var instance = get_skill_instance(entity_id, skill_id)
	if not instance:
		return false
	
	# Verificar cooldown
	if instance.is_on_cooldown():
		return false
	
	# Verificar recursos
	var cost_bundle = instance.definition.get_cost_bundle()
	if not cost_bundle.is_empty():
		if not resource_system.can_pay(entity_id, cost_bundle):
			return false
	
	return true


## Intenta usar una habilidad
func request_use(entity_id: String, skill_id: String) -> bool:
	var instance = get_skill_instance(entity_id, skill_id)
	if not instance:
		skill_failed.emit(entity_id, skill_id, "Skill not found")
		return false
	
	# Verificar cooldown
	if instance.is_on_cooldown():
		skill_failed.emit(entity_id, skill_id, "On cooldown")
		return false
	
	# Aplicar coste
	var cost_bundle = instance.definition.get_cost_bundle()
	if not cost_bundle.is_empty():
		if not resource_system.apply_cost(entity_id, cost_bundle):
			skill_failed.emit(entity_id, skill_id, "Insufficient resources")
			return false
	
	# Iniciar cooldown
	instance.start_cooldown()
	
	# Emitir eventos
	skill_used.emit(entity_id, skill_id)
	cooldown_started.emit(entity_id, skill_id, instance.definition.base_cooldown)
	
	print("[SkillSystem] %s used %s" % [entity_id, skill_id])
	
	return true


## Obtiene el cooldown restante de una habilidad
func get_cooldown_remaining(entity_id: String, skill_id: String) -> float:
	var instance = get_skill_instance(entity_id, skill_id)
	if instance:
		return instance.get_cooldown_remaining()
	return 0.0


## Obtiene el porcentaje de cooldown (0-1)
func get_cooldown_percentage(entity_id: String, skill_id: String) -> float:
	var instance = get_skill_instance(entity_id, skill_id)
	if instance:
		return instance.get_cooldown_percentage()
	return 0.0


## Proceso de cooldowns (cada frame)
func _process(delta: float):
	for entity_id in _entity_skills.keys():
		for skill_id in _entity_skills[entity_id].keys():
			var instance = _entity_skills[entity_id][skill_id] as SkillInstance
			
			var was_on_cooldown = instance.is_on_cooldown()
			instance.process_cooldown(delta)
			
			# Emitir evento si el cooldown terminó
			if was_on_cooldown and not instance.is_on_cooldown():
				cooldown_finished.emit(entity_id, skill_id)


## Debug: imprime habilidades de una entidad
func print_entity_skills(entity_id: String):
	if not _entity_skills.has(entity_id):
		print("[SkillSystem] Entity not found: %s" % entity_id)
		return
	
	print("\n[SkillSystem] Entity: %s" % entity_id)
	for skill_id in _entity_skills[entity_id].keys():
		var instance = _entity_skills[entity_id][skill_id]
		print("  - %s" % instance)

## ¿Tiene esta entidad la skill registrada?
func has_skill(entity_id: String, skill_id: String) -> bool:
	if not _entity_skills.has(entity_id):
		return false
	return _entity_skills[entity_id].has(skill_id)


## Desbloquea una skill para una entidad.
## Llamado por SkillEventHandler (vía narrativa) o directamente por código de juego.
##
## FASE B — Valida prerequisites antes de desbloquear:
##   Si alguna skill del array prerequisites no está desbloqueada,
##   emite skill_unlock_failed y devuelve false.
func unlock_skill(entity_id: String, skill_id: String) -> bool:
	var instance = get_skill_instance(entity_id, skill_id)
	if not instance:
		return false

	# Comprobar prerequisites
	var missing: Array[String] = []
	for prereq_id in instance.definition.prerequisites:
		if not is_skill_unlocked(entity_id, prereq_id):
			missing.append(prereq_id)

	if not missing.is_empty():
		push_warning("[SkillSystem] Cannot unlock '%s' for '%s' — missing prerequisites: %s" % [
			skill_id, entity_id, str(missing)
		])
		EventBus.skill_unlock_failed.emit(entity_id, skill_id, missing)
		return false

	instance.unlock()
	print("[SkillSystem] Unlocked '%s' for '%s'" % [skill_id, entity_id])
	EventBus.skill_unlocked.emit(entity_id, skill_id)
	return true


## ¿Está desbloqueada esta skill?
func is_skill_unlocked(entity_id: String, skill_id: String) -> bool:
	var instance = get_skill_instance(entity_id, skill_id)
	return instance.is_unlocked if instance else false

## Snapshot para SaveSystem
## ⭐ v4: incluye is_unlocked además de current_cooldown y total_uses
func get_save_state(entity_id: String) -> Dictionary:
	if not _entity_skills.has(entity_id):
		return {}

	var save_data = {}
	for skill_id in _entity_skills[entity_id].keys():
		var instance = _entity_skills[entity_id][skill_id] as SkillInstance
		save_data[skill_id] = {
			"current_cooldown": instance.current_cooldown,
			"total_uses":       instance.total_uses,
			"is_unlocked":      instance.is_unlocked,  # ⭐ NUEVO v4
		}

	return save_data

## Carga snapshot desde SaveSystem
## ⭐ v4: restaura is_unlocked con default true (backward-compatible)
func load_save_state(entity_id: String, save_data: Dictionary):
	if not _entity_skills.has(entity_id):
		return

	for skill_id in save_data.keys():
		var instance = get_skill_instance(entity_id, skill_id)
		if instance:
			instance.current_cooldown = save_data[skill_id].get("current_cooldown", 0.0)
			instance.total_uses       = save_data[skill_id].get("total_uses",       0)
			instance.is_unlocked      = save_data[skill_id].get("is_unlocked",      true)  # ⭐ NUEVO v4

# ============================================
# UTILIDADES DE DEBUG (NUEVAS)
# ============================================

## Lista todas las skills cargadas por categoría
func print_all_skills_by_category():
	print("\n[SkillSystem] ========== ALL LOADED SKILLS ==========")
	
	# Agrupar por mode
	var by_mode: Dictionary = {}
	
	for skill_id in _skill_definitions.keys():
		var skill_def = _skill_definitions[skill_id]
		var mode = skill_def.mode
		
		if not by_mode.has(mode):
			by_mode[mode] = []
		
		by_mode[mode].append(skill_def)
	
	# Imprimir por categoría
	for mode in by_mode.keys():
		print("\n  [%s] (%d skills)" % [mode, by_mode[mode].size()])
		for skill_def in by_mode[mode]:
			var cost_text = ""
			if skill_def.has_cost():
				cost_text = " | Cost: %s" % skill_def.costs
			
			print("    - %s%s" % [skill_def.id, cost_text])
	
	print("\n[SkillSystem] =============================================\n")
