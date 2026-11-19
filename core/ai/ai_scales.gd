class_name AIScales
extends RefCounted

## AIScales — Lector estático de data/ai/ai_scales.json (IA-0c)
##
## Escalas y tablas de la IA de combate: umbrales de `hp_state` y de amenaza, lista de
## condiciones visibles, tabla `effect_value`, regla de la etiqueta `costly` y factores
## de riesgo. Es DATOS: ningún valor vive en el código de `Combat`.
##
## Contrato:
##   - Carga perezosa, una sola vez; reload() fuerza una relectura (pruebas).
##   - get_value("a.b.c", fallback) lee por ruta con puntos. Ruta inexistente → fallback
##     (nunca error): quien necesite un dato obligatorio llama antes a validate().
##   - Solo lectura: devuelve duplicados de los diccionarios y arrays.

const PATH: String = "res://data/ai/ai_scales.json"

## Claves de primer nivel que el fichero debe tener.
const REQUIRED_KEYS: Array[String] = [
	"schema_version",
	"hp_state_thresholds",
	"threat_thresholds",
	"visible_conditions",
	"tag_rules",
	"effect_value",
	"self_risk_factor",
]

static var _data: Dictionary = {}
static var _loaded: bool = false


## Datos completos (carga la primera vez).
static func get_data() -> Dictionary:
	_ensure_loaded()
	return _data


## Lee un valor por ruta con puntos ("effect_value.restore.stamina").
## Devuelve `fallback` si cualquier tramo no existe.
static func get_value(path: String, fallback: Variant = null) -> Variant:
	_ensure_loaded()
	var node: Variant = _data
	for key in path.split("."):
		if node is Dictionary and node.has(key):
			node = node[key]
		else:
			return fallback
	if node is Dictionary or node is Array:
		return node.duplicate(true)
	return node


## Errores de forma del fichero (vacío = válido).
static func validate() -> Array[String]:
	_ensure_loaded()
	var errors: Array[String] = []
	if _data.is_empty():
		errors.append("ai_scales.json vacío o ilegible")
		return errors
	for key in REQUIRED_KEYS:
		if not _data.has(key):
			errors.append("falta la clave '%s'" % key)

	var hurt: float = float(get_value("hp_state_thresholds.hurt", -1.0))
	var badly: float = float(get_value("hp_state_thresholds.badly_hurt", -1.0))
	if not (0.0 <= badly and badly < hurt and hurt <= 1.0):
		errors.append("hp_state_thresholds debe cumplir 0 <= badly_hurt < hurt <= 1")

	var medium: float = float(get_value("threat_thresholds.medium", -1.0))
	var high: float = float(get_value("threat_thresholds.high", -1.0))
	if not (0.0 <= medium and medium < high):
		errors.append("threat_thresholds debe cumplir 0 <= medium < high")

	for unit_key in ["health", "stamina"]:
		if get_value("effect_value.restore.%s" % unit_key) == null:
			errors.append("effect_value.restore.%s sin declarar" % unit_key)
	return errors


## Descarta lo cargado y relee el fichero en el siguiente acceso.
static func reload() -> void:
	_data = {}
	_loaded = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true   # evita reintentos en bucle si el fichero está mal
	var file: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("[AIScales] No se pudo abrir %s" % PATH)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("[AIScales] JSON inválido en %s (línea %d): %s" % [PATH, json.get_error_line(), json.get_error_message()])
		return
	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("[AIScales] La raíz de %s debe ser un diccionario" % PATH)
		return
	_data = json.data
