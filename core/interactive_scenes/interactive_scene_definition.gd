class_name InteractiveSceneDefinition
extends Resource

## InteractiveSceneDefinition — Spike 12: motor de escenas interactivas
##
## Resource estático: imagen de fondo + lista de puntos clicables.
## Se carga por InteractiveSceneDB desde JSON de autoría. NO contiene
## lógica: la visibilidad por flags y el disparo de acciones viven en
## InteractiveSceneViewModel.
##
## Naming genérico a propósito: el mismo primitivo (fondo + hotspots +
## visibilidad por flags) sirve para el mapa del pueblo y, en el futuro,
## para escenas de "buscar algo en la imagen".

var scene_id: String = ""

## Ruta res:// a la imagen de fondo. Vacío = fondo liso de placeholder.
## Se carga con load() en la View, nunca preload aquí.
var image_path: String = ""

var hotspots: Array[InteractiveHotspotDefinition] = []

## Spike 13 — acción de una sola vez al entrar por primera vez en la escena.
## Mismo vocabulario que un hotspot. once_flag se marca ANTES de ejecutarla y
## persiste en el save. Vacío = ninguna.
var on_first_visit_type: String = ""
var on_first_visit_target_id: String = ""
var on_first_visit_flag: String = ""

func has_first_visit() -> bool:
	return not on_first_visit_type.is_empty()

static func from_dict(data: Dictionary) -> InteractiveSceneDefinition:
	var scene := new()
	scene.scene_id = data.get("scene_id", "")
	scene.image_path = data.get("image_path", "")

	var raw_hotspots: Array = data.get("hotspots", [])
	for raw_hotspot in raw_hotspots:
		if typeof(raw_hotspot) == TYPE_DICTIONARY:
			scene.hotspots.append(InteractiveHotspotDefinition.from_dict(raw_hotspot))

	var raw_first: Dictionary = data.get("on_first_visit", {})
	scene.on_first_visit_type = raw_first.get("interaction_type", "")
	scene.on_first_visit_target_id = raw_first.get("target_id", "")
	scene.on_first_visit_flag = raw_first.get("once_flag", "")

	return scene


func validate() -> bool:
	if scene_id.is_empty():
		push_error("[InteractiveSceneDefinition] scene_id vacío")
		return false
	if hotspots.is_empty():
		push_error("[InteractiveSceneDefinition] '%s': sin hotspots" % scene_id)
		return false

	if not image_path.is_empty() and not ResourceLoader.exists(image_path):
		push_warning("[InteractiveSceneDefinition] '%s': image_path no existe: %s" % [scene_id, image_path])

	var seen_ids: Dictionary = {}
	for hotspot in hotspots:
		if not hotspot.validate(scene_id):
			return false
		if seen_ids.has(hotspot.hotspot_id):
			push_error("[InteractiveSceneDefinition] '%s': hotspot_id duplicado '%s'" % [scene_id, hotspot.hotspot_id])
			return false
		seen_ids[hotspot.hotspot_id] = true

	return true
