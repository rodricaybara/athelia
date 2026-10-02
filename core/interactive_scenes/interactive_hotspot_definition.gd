class_name InteractiveHotspotDefinition
extends Resource

## InteractiveHotspotDefinition — Spike 12: motor de escenas interactivas
##
## Resource estático: un punto clicable sobre la imagen de una
## InteractiveSceneDefinition. NO contiene lógica — solo datos.
##
## Vocabulario de salida calcado de Interactable (interaction_type,
## target_id, enemy_ids_override, enemy_definitions) para que el
## ExplorationController lo enrute con el mismo `match` de siempre.
## Campos propios: posición normalizada, icono, etiqueta y visibilidad
## declarativa por flags (required_flags / blocked_flags).
##
## "item" queda fuera de los tipos válidos en v1: exige un WorldObject
## registrado en WorldObjectSystem y las escenas interactivas no tienen.

const VALID_INTERACTION_TYPES: Array[String] = ["dialogue", "shop", "combat", "narrative_scene"]

var hotspot_id: String = ""

## Posición NORMALIZADA (0.0–1.0) sobre el rectángulo de la imagen de fondo,
## no píxeles: el mapa escala con el viewport sin recalcular datos.
var map_position: Vector2 = Vector2(0.5, 0.5)

## Ruta res:// del icono. Vacío = solo texto.
var icon_path: String = ""

## Clave de localización de la etiqueta — NUNCA texto crudo.
var label_key: String = ""

var interaction_type: String = ""
var target_id: String = ""
var enemy_ids_override: Array[String] = []

## Mapeo enemy_id → definition_id (mismo formato que Interactable.enemy_definitions).
var enemy_definitions: Dictionary = {}

## El punto solo es visible si TODOS estos flags están puestos.
var required_flags: Array[String] = []

## El punto se oculta si CUALQUIERA de estos flags está puesto.
var blocked_flags: Array[String] = []


static func from_dict(data: Dictionary) -> InteractiveHotspotDefinition:
	var hotspot := new()
	hotspot.hotspot_id = data.get("hotspot_id", "")
	hotspot.icon_path = data.get("icon_path", "")
	hotspot.label_key = data.get("label_key", "")
	hotspot.interaction_type = data.get("interaction_type", "")
	hotspot.target_id = data.get("target_id", "")
	hotspot.enemy_ids_override = _to_string_array(data.get("enemy_ids_override", []))
	hotspot.required_flags = _to_string_array(data.get("required_flags", []))
	hotspot.blocked_flags = _to_string_array(data.get("blocked_flags", []))

	var raw_defs: Variant = data.get("enemy_definitions", {})
	if typeof(raw_defs) == TYPE_DICTIONARY:
		hotspot.enemy_definitions = (raw_defs as Dictionary).duplicate()

	var raw_pos: Variant = data.get("position", [0.5, 0.5])
	if typeof(raw_pos) == TYPE_ARRAY and (raw_pos as Array).size() >= 2:
		hotspot.map_position = Vector2(float(raw_pos[0]), float(raw_pos[1]))

	return hotspot


static func _to_string_array(raw: Variant) -> Array[String]:
	var result: Array[String] = []
	if typeof(raw) == TYPE_ARRAY:
		for item in raw:
			result.append(str(item))
	return result


## Mismo criterio que Interactable.interact(): combate con varios enemigos
## viaja como IDs unidos por comas en un único string.
func get_effective_target_id() -> String:
	if interaction_type == "combat" and not enemy_ids_override.is_empty():
		return ",".join(PackedStringArray(enemy_ids_override))
	return target_id


func validate(scene_id: String) -> bool:
	if hotspot_id.is_empty():
		push_error("[InteractiveHotspotDefinition] '%s': hotspot_id vacío" % scene_id)
		return false
	if not interaction_type in VALID_INTERACTION_TYPES:
		push_error("[InteractiveHotspotDefinition] '%s/%s': interaction_type '%s' no válido (válidos: %s)" % [
			scene_id, hotspot_id, interaction_type, str(VALID_INTERACTION_TYPES)])
		return false
	if label_key.is_empty():
		push_error("[InteractiveHotspotDefinition] '%s/%s': label_key vacío" % [scene_id, hotspot_id])
		return false
	if get_effective_target_id().is_empty():
		push_error("[InteractiveHotspotDefinition] '%s/%s': sin target_id (ni enemy_ids_override en combate)" % [
			scene_id, hotspot_id])
		return false

	# Warnings, no errores: el punto sigue siendo usable.
	if interaction_type != "combat" and not enemy_definitions.is_empty():
		push_warning("[InteractiveHotspotDefinition] '%s/%s': enemy_definitions ignorado fuera de combate" % [
			scene_id, hotspot_id])
	if map_position.x < 0.0 or map_position.x > 1.0 or map_position.y < 0.0 or map_position.y > 1.0:
		push_warning("[InteractiveHotspotDefinition] '%s/%s': position fuera de 0..1: %s" % [
			scene_id, hotspot_id, str(map_position)])
	if not icon_path.is_empty() and not ResourceLoader.exists(icon_path):
		push_warning("[InteractiveHotspotDefinition] '%s/%s': icon_path no existe: %s" % [
			scene_id, hotspot_id, icon_path])

	return true
