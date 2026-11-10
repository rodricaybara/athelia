class_name OptionsViewModel
extends Node

## OptionsViewModel — Lógica y estado del panel de opciones (Spike 23).
##
## Único sitio que toca AudioServer, DisplayServer y TranslationServer
## (a través de GameSettings). La View no accede a ninguno.
##
## Razones de changed():
##   "opened"     → leer todo el estado y pintarlo
##   "fullscreen" → cambió pantalla completa
##   "language"   → cambió el idioma (los textos se retraducen solos por
##                  NOTIFICATION_TRANSLATION_CHANGED; aquí solo se refresca
##                  el selector)
##   "volume"     → cambió un volumen (hoy los sliders están ocultos)
##   "closed"     → el usuario pidió volver

signal changed(reason: String)

var fullscreen: bool = false
var language_code: String = "es"
var music_volume: float = 1.0
var sfx_volume: float = 1.0

## [{ "code": "es", "name": "Español" }, ...] — nombres sin traducir.
var languages: Array[Dictionary] = []


func _init() -> void:
	for entry in GameSettings.LANGUAGES:
		languages.append(entry as Dictionary)


# ============================================
# API PÚBLICA — llamada desde la View
# ============================================

## Lee el estado REAL del motor (no del fichero) y avisa a la View.
func open() -> void:
	fullscreen = GameSettings.is_fullscreen()
	language_code = GameSettings.get_current_language()
	music_volume = GameSettings.get_saved_volume(GameSettings.KEY_MUSIC)
	sfx_volume = GameSettings.get_saved_volume(GameSettings.KEY_SFX)
	changed.emit("opened")


func request_set_fullscreen(enabled: bool) -> void:
	if enabled == fullscreen:
		return
	fullscreen = enabled
	GameSettings.set_fullscreen(enabled)
	changed.emit("fullscreen")


func request_set_language(code: String) -> void:
	if code == language_code or not GameSettings.is_valid_language(code):
		return
	language_code = code
	GameSettings.set_language(code)
	changed.emit("language")


func request_set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	GameSettings.apply_volume(GameSettings.BUS_MUSIC, music_volume)
	changed.emit("volume")


func request_set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	GameSettings.apply_volume(GameSettings.BUS_SFX, sfx_volume)
	changed.emit("volume")


## Persiste los volúmenes (al soltar el slider, no en cada tick).
func request_commit_volumes() -> void:
	GameSettings.save_volumes(music_volume, sfx_volume)


func request_close() -> void:
	changed.emit("closed")
