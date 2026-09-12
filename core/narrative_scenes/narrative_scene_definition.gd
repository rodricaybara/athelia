class_name NarrativeSceneDefinition
extends Resource

## NarrativeSceneDefinition — Spike 1: Motor Narrativo Base
##
## Resource estático: una escena narrativa = imagen fija + texto + opciones.
## Se carga en memoria por NarrativeSceneDB a partir de JSON de autoría,
## igual que DialogueDefinition. NO contiene lógica — solo datos.
## La resolución (tiradas, ramificación, consecuencias) vive en
## NarrativeSceneViewModel, nunca aquí.
##
## NOTA: from_dict() usa new() en vez de NarrativeSceneDefinition.new() —
## autorreferenciar el propio class_name dentro del mismo script no se
## resuelve de forma fiable en GDScript. Ver narrative_scene_outcome.gd.

var scene_id: String = ""

## Ruta res:// a la imagen de la escena. Se carga con load() en la View,
## nunca preload aquí — evita cargar todas las imágenes del juego en
## memoria de golpe al arrancar el registry.
var image_path: String = ""

## Clave de localización del texto de la escena — NUNCA texto crudo.
## Ver localization/narrative_scenes.csv.
var text_key: String = ""

var options: Array[NarrativeSceneOption] = []


## Construye una NarrativeSceneDefinition desde un Dictionary parseado de JSON.
static func from_dict(data: Dictionary) -> NarrativeSceneDefinition:
	var scene := new()
	scene.scene_id = data.get("scene_id", "")
	scene.image_path = data.get("image_path", "")
	scene.text_key = data.get("text_key", "")

	var raw_options: Array = data.get("options", [])
	for raw_option in raw_options:
		if typeof(raw_option) == TYPE_DICTIONARY:
			scene.options.append(NarrativeSceneOption.from_dict(raw_option))

	return scene


## Validación mínima — usada por NarrativeSceneDB al cargar cada fichero.
## Tipado estricto, warnings-as-errors: cualquier campo obligatorio ausente
## se detecta aquí, no en producción con contenido real (Spike 3).
func validate() -> bool:
	if scene_id.is_empty():
		push_error("[NarrativeSceneDefinition] scene_id vacío")
		return false
	if text_key.is_empty():
		push_error("[NarrativeSceneDefinition] '%s': text_key vacío" % scene_id)
		return false
	if options.is_empty():
		push_error("[NarrativeSceneDefinition] '%s': sin opciones" % scene_id)
		return false

	for option in options:
		if not option.validate(scene_id):
			return false

	return true
