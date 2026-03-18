class_name ItemRegistry
extends Node

## ItemRegistry - Registro global de ItemDefinitions
## Singleton: /root/Items
## Carga automáticamente todos los .tres de res://data/items/

## Catálogo de definiciones: { item_id: String -> ItemDefinition }
var _items: Dictionary = {}


func _ready():
	print("[ItemRegistry] Initializing...")
	_load_items_from_directory("res://data/items/")
	print("[ItemRegistry] Loaded %d item types" % _items.size())
	_print_loaded_items()


## Carga todos los .tres de un directorio y sus subdirectorios (recursivo)
func _load_items_from_directory(path: String):
	var dir = DirAccess.open(path)
	if not dir:
		push_warning("[ItemRegistry] Directory not found: %s" % path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir() and file_name != "." and file_name != "..":
			_load_items_from_directory(path + file_name + "/")
		elif file_name.ends_with(".tres"):
			_load_item_from_resource(path + file_name)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()


## Carga un ítem desde .tres
func _load_item_from_resource(file_path: String):
	var item_def = load(file_path) as ItemDefinition
	
	if not item_def:
		push_error("[ItemRegistry] Failed to load: %s" % file_path)
		return
	
	if not item_def.validate():
		push_error("[ItemRegistry] Validation failed: %s" % file_path)
		return
	
	if _items.has(item_def.id):
		push_warning("[ItemRegistry] Duplicate ID '%s' in %s" % [item_def.id, file_path])
		return
	
	_items[item_def.id] = item_def
	print("  [ItemRegistry] Loaded: %s" % item_def.id)


## Obtiene una definición por ID
func get_item(item_id: String) -> ItemDefinition:
	if not _items.has(item_id):
		push_warning("[ItemRegistry] Item not found: %s" % item_id)
		return null
	
	return _items[item_id]


## ¿Existe un ítem con este ID?
func has_item(item_id: String) -> bool:
	return _items.has(item_id)


## Lista todos los IDs registrados
func list_items() -> Array:
	return _items.keys()


## Obtiene todos los ítems con un tag específico
func get_items_by_tag(tag: String) -> Array[ItemDefinition]:
	var result: Array[ItemDefinition] = []
	for item_def in _items.values():
		if item_def.has_tag(tag):
			result.append(item_def)
	return result


## Debug: imprime todos los ítems cargados
func _print_loaded_items():
	if _items.is_empty():
		print("  [ItemRegistry] No items loaded")
		return
	
	print("  [ItemRegistry] Available items:")
	for item_id in _items.keys():
		var item_def = _items[item_id]
		print("    - %s (%.1fg, %dg)" % [item_id, item_def.weight, item_def.base_value])
