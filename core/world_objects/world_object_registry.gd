## class_name eliminado — el autoload se llama "WorldObjects" (patrón igual que ItemRegistry → "Items")
extends Node

## WorldObjectRegistry - Registro global de WorldObjectDefinitions y LootTableDefinitions
## Autoload: /root/WorldObjects
##
## RESPONSABILIDAD:
##   - Cargar y cachear todos los .tres de res://data/world_objects/
##   - Proveer acceso por ID a definiciones de objetos y tablas de loot
##   - Validar que no existan IDs duplicados
##
## NO hace:
##   - Gestionar estado de instancias (eso es WorldObjectSystem)
##   - Ejecutar interacciones (eso es WorldObjectSystem)
##   - Modificar ningún otro sistema

# ============================================
# CATÁLOGOS
# ============================================

## Definiciones de objetos: { object_id: String -> WorldObjectDefinition }
var _objects: Dictionary = {}

## Tablas de loot: { loot_table_id: String -> LootTableDefinition }
var _loot_tables: Dictionary = {}


# ============================================
# INICIALIZACIÓN
# ============================================

func _ready() -> void:
	print("[WorldObjectRegistry] Initializing...")
	_load_from_directory("res://data/world_objects/")
	print("[WorldObjectRegistry] Loaded %d object types, %d loot tables" % [
		_objects.size(), _loot_tables.size()
	])
	_print_loaded()


# ============================================
# CARGA DE RECURSOS
# ============================================

## Carga todos los .tres del directorio dado
func _load_from_directory(path: String) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		push_warning("[WorldObjectRegistry] Directory not found: %s" % path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.ends_with(".tres"):
			_load_resource(path + file_name)
		file_name = dir.get_next()

	dir.list_dir_end()


## Carga un .tres e identifica su tipo para clasificarlo en el catálogo correcto
func _load_resource(file_path: String) -> void:
	var res = load(file_path)

	if res == null:
		push_error("[WorldObjectRegistry] Failed to load: %s" % file_path)
		return

	if res is WorldObjectDefinition:
		_register_object(res, file_path)
	elif res is LootTableDefinition:
		_register_loot_table(res, file_path)
	else:
		# Ignorar silenciosamente otros .tres del directorio (futuro: íconos, etc.)
		push_warning("[WorldObjectRegistry] Unrecognized resource type in %s — skipped" % file_path)


## Registra una WorldObjectDefinition validada
func _register_object(obj_def: WorldObjectDefinition, file_path: String) -> void:
	if not obj_def.validate():
		push_error("[WorldObjectRegistry] Validation failed: %s" % file_path)
		return

	if _objects.has(obj_def.id):
		push_warning("[WorldObjectRegistry] Duplicate object ID '%s' in %s — skipped" % [
			obj_def.id, file_path
		])
		return

	_objects[obj_def.id] = obj_def
	print("  [WorldObjectRegistry] ✓ object  → %s" % obj_def.id)


## Registra una LootTableDefinition validada
func _register_loot_table(loot_def: LootTableDefinition, file_path: String) -> void:
	if not loot_def.validate():
		push_error("[WorldObjectRegistry] Validation failed: %s" % file_path)
		return

	if _loot_tables.has(loot_def.id):
		push_warning("[WorldObjectRegistry] Duplicate loot table ID '%s' in %s — skipped" % [
			loot_def.id, file_path
		])
		return

	_loot_tables[loot_def.id] = loot_def
	print("  [WorldObjectRegistry] ✓ loot    → %s" % loot_def.id)


# ============================================
# API PÚBLICA — WorldObjectDefinition
# ============================================

## Obtiene la definición de un objeto por su ID
## Retorna null si no existe
func get_object(object_id: String) -> WorldObjectDefinition:
	if not _objects.has(object_id):
		push_warning("[WorldObjectRegistry] Object not found: %s" % object_id)
		return null
	return _objects[object_id]


## ¿Existe una definición para este ID?
func has_object(object_id: String) -> bool:
	return _objects.has(object_id)


## Lista todos los IDs de objetos registrados
func list_objects() -> Array:
	return _objects.keys()


# ============================================
# API PÚBLICA — LootTableDefinition
# ============================================

## Obtiene una tabla de loot por su ID
## Retorna null si no existe
func get_loot_table(loot_table_id: String) -> LootTableDefinition:
	if not _loot_tables.has(loot_table_id):
		push_warning("[WorldObjectRegistry] Loot table not found: %s" % loot_table_id)
		return null
	return _loot_tables[loot_table_id]


## ¿Existe una tabla de loot para este ID?
func has_loot_table(loot_table_id: String) -> bool:
	return _loot_tables.has(loot_table_id)


# ============================================
# DEBUG
# ============================================

func _print_loaded() -> void:
	if _objects.is_empty() and _loot_tables.is_empty():
		push_warning("  [WorldObjectRegistry] No resources loaded — check res://data/world_objects/")
		return

	print("  [WorldObjectRegistry] Objects:     %s" % str(_objects.keys()))
	print("  [WorldObjectRegistry] Loot tables: %s" % str(_loot_tables.keys()))
