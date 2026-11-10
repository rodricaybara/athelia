class_name GameSettings
extends RefCounted

## GameSettings — Persistencia y aplicación de las opciones del jugador (Spike 23).
##
## Guarda en user://settings.cfg: idioma, pantalla completa y volúmenes (0..1).
## Sin autoload y sin estado: solo funciones estáticas. Lo usan MainMenuViewModel
## (aplica lo guardado al arrancar) y OptionsViewModel (cambia y guarda).
##
## Sin fichero, NO se toca nada: el juego conserva su arranque por defecto
## (pantalla completa del proyecto, idioma del sistema).
##
## Volúmenes: solo se aplican si el bus existe. Hoy no hay buses "Music" ni
## "SFX" (no hay audio diseñado): el valor se guarda y queda a la espera.

const PATH: String = "user://settings.cfg"
const SECTION: String = "options"

const KEY_LANGUAGE: String = "language"
const KEY_FULLSCREEN: String = "fullscreen"
const KEY_MUSIC: String = "music_volume"
const KEY_SFX: String = "sfx_volume"

const BUS_MUSIC: String = "Music"
const BUS_SFX: String = "SFX"

## Nombres de idioma en su propio idioma (no se traducen).
const LANGUAGES: Array = [
	{"code": "es", "name": "Español"},
	{"code": "en", "name": "English"},
]


# ============================================
# LECTURA / ESCRITURA DEL FICHERO
# ============================================

static func _load() -> ConfigFile:
	var cfg := ConfigFile.new()
	var err: Error = cfg.load(PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("[GameSettings] No se pudo leer %s (error %d)" % [PATH, err])
	return cfg


static func _save(cfg: ConfigFile) -> void:
	var err: Error = cfg.save(PATH)
	if err != OK:
		push_warning("[GameSettings] No se pudo guardar %s (error %d)" % [PATH, err])


# ============================================
# ARRANQUE
# ============================================

## Aplica lo guardado. Solo las claves que existen en el fichero.
static func apply_saved() -> void:
	var cfg: ConfigFile = _load()

	if cfg.has_section_key(SECTION, KEY_LANGUAGE):
		var code: String = str(cfg.get_value(SECTION, KEY_LANGUAGE))
		if is_valid_language(code):
			TranslationServer.set_locale(code)

	if cfg.has_section_key(SECTION, KEY_FULLSCREEN):
		_apply_fullscreen(bool(cfg.get_value(SECTION, KEY_FULLSCREEN)))

	if cfg.has_section_key(SECTION, KEY_MUSIC):
		apply_volume(BUS_MUSIC, float(cfg.get_value(SECTION, KEY_MUSIC)))
	if cfg.has_section_key(SECTION, KEY_SFX):
		apply_volume(BUS_SFX, float(cfg.get_value(SECTION, KEY_SFX)))


# ============================================
# IDIOMA
# ============================================

static func is_valid_language(code: String) -> bool:
	for entry: Dictionary in LANGUAGES:
		if str(entry["code"]) == code:
			return true
	return false


static func get_current_language() -> String:
	return "en" if TranslationServer.get_locale().begins_with("en") else "es"


static func set_language(code: String) -> void:
	if not is_valid_language(code):
		return
	TranslationServer.set_locale(code)
	var cfg: ConfigFile = _load()
	cfg.set_value(SECTION, KEY_LANGUAGE, code)
	_save(cfg)


# ============================================
# PANTALLA COMPLETA
# ============================================

static func is_fullscreen() -> bool:
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


static func set_fullscreen(enabled: bool) -> void:
	_apply_fullscreen(enabled)
	var cfg: ConfigFile = _load()
	cfg.set_value(SECTION, KEY_FULLSCREEN, enabled)
	_save(cfg)


static func _apply_fullscreen(enabled: bool) -> void:
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


# ============================================
# VOLÚMENES (0..1)
# ============================================

## Valor guardado, o 1.0 si no hay ninguno.
static func get_saved_volume(key: String) -> float:
	var cfg: ConfigFile = _load()
	return clampf(float(cfg.get_value(SECTION, key, 1.0)), 0.0, 1.0)


## Aplica el volumen al bus si existe. Sin bus no hace nada.
static func apply_volume(bus_name: String, value: float) -> void:
	var bus: int = AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(value, 0.0001)))


## Guarda ambos volúmenes en una sola escritura.
static func save_volumes(music: float, sfx: float) -> void:
	var cfg: ConfigFile = _load()
	cfg.set_value(SECTION, KEY_MUSIC, clampf(music, 0.0, 1.0))
	cfg.set_value(SECTION, KEY_SFX, clampf(sfx, 0.0, 1.0))
	_save(cfg)
