class_name BehaviorProfileRegistry
extends RefCounted

## BehaviorProfileRegistry — Carga, valida y entrega perfiles de comportamiento (IA-1a).
##
## Contrato:
##   - Carga perezosa y una sola vez de data/ai/profiles/ CON recursión (un catálogo que no
##     recursa ignora en silencio las subcarpetas). reload() fuerza una relectura.
##   - Un perfil inválido se RECHAZA con push_error y no entra en la caché. El id debe
##     coincidir con el nombre del fichero y ser único.
##   - get_profile(id) entrega un DUPLICADO PROFUNDO; si el id está vacío, no existe o fue
##     rechazado, entrega el perfil seguro con un push_warning una sola vez por id.
##   - Ningún acceso a miembros privados de otro sistema.

const PROFILES_DIR: String = "res://data/ai/profiles"

static var _cache: Dictionary = {}     # StringName -> BehaviorProfile (originales, no se entregan)
static var _sources: Dictionary = {}   # StringName -> ruta de origen
static var _warned: Dictionary = {}    # ids ya avisados
static var _loaded: bool = false


## Duplicado independiente del perfil `profile_id`, o el perfil seguro si no existe.
## `warn = false` silencia el aviso (pruebas).
static func get_profile(profile_id: StringName, warn: bool = true) -> BehaviorProfile:
	_ensure_loaded()
	if _cache.has(profile_id):
		return (_cache[profile_id] as BehaviorProfile).duplicate_profile()
	if warn:
		_warn_once(profile_id)
	return BehaviorProfile.make_safe_default()


static func has_profile(profile_id: StringName) -> bool:
	_ensure_loaded()
	return _cache.has(profile_id)


## Ids cargados, ordenados.
static func get_profile_ids() -> Array[StringName]:
	_ensure_loaded()
	var ids: Array[StringName] = []
	for key in _cache.keys():
		ids.append(key)
	ids.sort()
	return ids


## Valida y registra un perfil. Devuelve los errores (vacío = registrado). Si `source_path`
## no está vacío, exige que el id coincida con el nombre del fichero.
static func try_register(profile: BehaviorProfile, source_path: String = "") -> Array[String]:
	var errors: Array[String] = profile.validate()
	if not source_path.is_empty():
		var stem: String = source_path.get_file().get_basename()
		if String(profile.id) != stem:
			errors.append("%s: el id '%s' no coincide con el nombre del fichero '%s'" % [source_path, String(profile.id), stem])
	if errors.is_empty() and _cache.has(profile.id):
		errors.append("%s: id duplicado '%s' (ya cargado desde %s)" % [source_path, String(profile.id), String(_sources.get(profile.id, "memoria"))])
	if errors.is_empty():
		_cache[profile.id] = profile
		_sources[profile.id] = source_path if not source_path.is_empty() else "memoria"
	return errors


## Carga todos los .tres de `dir_path` y sus subcarpetas. Devuelve
## { "loaded": Array de ids, "rejected": { ruta: Array de errores } }.
## `report_errors = false` evita push_error (pruebas).
static func load_directory(dir_path: String, report_errors: bool = true) -> Dictionary:
	var loaded: Array[StringName] = []
	var rejected: Dictionary = {}
	var files: Array[String] = []
	_collect_files(dir_path, files)
	files.sort()

	for path in files:
		var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		var profile: BehaviorProfile = resource as BehaviorProfile
		var errors: Array[String] = []
		if profile == null:
			errors.append("%s: no es un BehaviorProfile" % path)
		else:
			errors = try_register(profile, path)
		if errors.is_empty():
			loaded.append(profile.id)
			print("[BehaviorProfileRegistry] Loaded profile: %s" % profile.summary())
		else:
			rejected[path] = errors
			if report_errors:
				for message in errors:
					push_error("[BehaviorProfileRegistry] Perfil rechazado — %s" % message)
	return {"loaded": loaded, "rejected": rejected}


## Descarta lo cargado; el siguiente acceso relee data/ai/profiles/.
static func reload() -> void:
	_cache.clear()
	_sources.clear()
	_warned.clear()
	_loaded = false


# ---------------------------------------------------------------- internos

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true   # evita bucles si la carpeta está mal
	if not DirAccess.dir_exists_absolute(PROFILES_DIR):
		push_error("[BehaviorProfileRegistry] No existe la carpeta %s" % PROFILES_DIR)
		return
	var report: Dictionary = load_directory(PROFILES_DIR, true)
	print("[BehaviorProfileRegistry] %d perfiles cargados, %d rechazados" % [
		(report["loaded"] as Array).size(), (report["rejected"] as Dictionary).size()])


static func _collect_files(dir_path: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub_dir in dir.get_directories():
		_collect_files(dir_path.path_join(sub_dir), out)
	for file_name in dir.get_files():
		var clean_name: String = file_name
		if clean_name.ends_with(".remap"):   # exportado: los recursos llegan como .tres.remap
			clean_name = clean_name.trim_suffix(".remap")
		if clean_name.ends_with(".tres"):
			out.append(dir_path.path_join(clean_name))


static func _warn_once(profile_id: StringName) -> void:
	if _warned.has(profile_id):
		return
	_warned[profile_id] = true
	if profile_id == &"":
		push_warning("[BehaviorProfileRegistry] Combatiente sin behavior_profile_id: se usa el perfil seguro '%s'" % String(BehaviorProfile.SAFE_DEFAULT_ID))
	else:
		push_warning("[BehaviorProfileRegistry] Perfil '%s' inexistente o rechazado: se usa el perfil seguro '%s'" % [String(profile_id), String(BehaviorProfile.SAFE_DEFAULT_ID)])
