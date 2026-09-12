class_name NarrativeSceneRegistry
extends Node

## NarrativeSceneRegistry — Spike 1: Motor Narrativo Base
## Singleton recomendado: /root/NarrativeSceneDB
##
## Responsabilidad única: cargar NarrativeSceneDefinition desde JSON y
## exponerlas por scene_id. Mismo patrón que DialogueRegistry (autoload
## DialogueDB) y SkillSystem._load_skill_definitions() (carga desde
## directorio, .from_dict() en vez de .tres).
##
## Deliberadamente SIN estado runtime — "en qué nodo estamos ahora" es
## responsabilidad del ViewModel (state, current_node), no de este registry.
## Ver discusión de diseño: esto es justo la distinción que separa este
## sistema de NarrativeSystem/CheckpointSystem (que sí llevan estado
## runtime propio de los hitos de historia).

const SCENES_DIR := "res://data/narrative_scenes/"

var _scenes: Dictionary = {}  # scene_id: String -> NarrativeSceneDefinition


func _ready() -> void:
	_load_scenes_from_directory(SCENES_DIR)
	print("[NarrativeSceneDB] Initialized with %d scenes" % _scenes.size())


# ============================================
# CARGA DE DEFINICIONES
# ============================================

func _load_scenes_from_directory(path: String) -> void:
	var dir := DirAccess.open(path)

	if not dir:
		push_warning("[NarrativeSceneDB] Directory not found: %s" % path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		if file_name.ends_with(".json"):
			_load_scene_from_file(path + file_name)

		file_name = dir.get_next()

	dir.list_dir_end()


func _load_scene_from_file(file_path: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)

	if not file:
		push_error("[NarrativeSceneDB] Failed to open: %s" % file_path)
		return

	var json_text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(json_text)

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[NarrativeSceneDB] Invalid JSON in: %s" % file_path)
		return

	var scene := NarrativeSceneDefinition.from_dict(parsed as Dictionary)

	if not scene.validate():
		push_error("[NarrativeSceneDB] Validation failed for: %s" % file_path)
		return

	if _scenes.has(scene.scene_id):
		push_warning(
			"[NarrativeSceneDB] Duplicate scene_id '%s' in %s (overwriting)"
			% [scene.scene_id, file_path]
		)

	_scenes[scene.scene_id] = scene

	var relative_path := file_path.replace(SCENES_DIR, "")
	print("[NarrativeSceneDB]   ✓ %s ← %s" % [scene.scene_id, relative_path])


# ============================================
# API PÚBLICA
# ============================================

## Obtiene una escena por id. Devuelve null si no existe — el llamador
## (ViewModel) es responsable de manejar el null, no este registry.
func get_scene(scene_id: String) -> NarrativeSceneDefinition:
	if not _scenes.has(scene_id):
		push_warning("[NarrativeSceneDB] Scene not found: %s" % scene_id)
		return null
	return _scenes[scene_id]


func has_scene(scene_id: String) -> bool:
	return _scenes.has(scene_id)


func list_scene_ids() -> Array:
	return _scenes.keys()
