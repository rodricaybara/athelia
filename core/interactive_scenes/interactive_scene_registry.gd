class_name InteractiveSceneRegistry
extends Node

## InteractiveSceneRegistry — Spike 12: motor de escenas interactivas
## Autoload recomendado: InteractiveSceneDB
##   (Project Settings → Globals → Autoload:
##    res://core/interactive_scenes/interactive_scene_registry.gd)
##
## Responsabilidad única: cargar InteractiveSceneDefinition desde JSON y
## exponerlas por scene_id. Mismo patrón que NarrativeSceneRegistry
## (autoload NarrativeSceneDB): sin estado runtime — "qué puntos se ven
## ahora" es responsabilidad del ViewModel.
##
## OJO: el directorio se escanea SIN recursión (un JSON por localización,
## todos directamente en SCENES_DIR).

const SCENES_DIR := "res://data/interactive_scenes/"

var _scenes: Dictionary = {}  # scene_id: String -> InteractiveSceneDefinition


func _ready() -> void:
	_load_scenes_from_directory(SCENES_DIR)
	print("[InteractiveSceneDB] Initialized with %d scenes" % _scenes.size())


func _load_scenes_from_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		push_warning("[InteractiveSceneDB] Directory not found: %s" % path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not file_name.begins_with(".") and file_name.ends_with(".json"):
			_load_scene_from_file(path + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_scene_from_file(file_path: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[InteractiveSceneDB] Failed to open: %s" % file_path)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[InteractiveSceneDB] Invalid JSON in: %s" % file_path)
		return

	var scene := InteractiveSceneDefinition.from_dict(parsed as Dictionary)
	if not scene.validate():
		push_error("[InteractiveSceneDB] Validation failed for: %s" % file_path)
		return

	if _scenes.has(scene.scene_id):
		push_warning("[InteractiveSceneDB] Duplicate scene_id '%s' in %s (overwriting)" % [scene.scene_id, file_path])

	_scenes[scene.scene_id] = scene
	print("[InteractiveSceneDB]   ✓ %s ← %s" % [scene.scene_id, file_path.replace(SCENES_DIR, "")])


## Devuelve null si no existe — el llamador (ViewModel) maneja el null.
func get_scene(scene_id: String) -> InteractiveSceneDefinition:
	if not _scenes.has(scene_id):
		push_warning("[InteractiveSceneDB] Scene not found: %s" % scene_id)
		return null
	return _scenes[scene_id]


func has_scene(scene_id: String) -> bool:
	return _scenes.has(scene_id)


func list_scene_ids() -> Array:
	return _scenes.keys()
