class_name MainMenuViewModel
extends Node

## MainMenuViewModel — Lógica y estado del menú principal
##
## Razones de changed():
##   "main"          → mostrar panel principal, ocultar el resto
##   "options"       → mostrar el panel de opciones
##   "credits"       → mostrar el panel de créditos
##   "confirm_quit"  → mostrar la confirmación de salida
##   "transitioning" → deshabilitar botones (transición en curso)
##   "load_blocked"  → no hay partida guardada: refrescar la línea de estado
##   "hidden"        → GameState salió de MENU — ocultar la pantalla entera
##
## Spike 23: las opciones (idioma, pantalla completa, volúmenes) viven en
## OptionsViewModel; aquí solo se aplica lo guardado al arrancar.

signal changed(reason: String)

# ============================================
# ESTADOS
# ============================================

enum MenuState {
	HIDDEN,
	MAIN,
	OPTIONS,
	CREDITS,
	CONFIRM_QUIT,
	TRANSITIONING,
}

# ============================================
# ESTADO PÚBLICO — leído por la View, nunca escrito desde fuera
# ============================================

var state: MenuState = MenuState.HIDDEN

## ¿Existe una partida guardada? Determina si "Cargar partida" está habilitado.
var has_save: bool = false

## Metadata del save (timestamp, playtime_seconds). Vacío si no hay save.
var save_info: Dictionary = {}

## Fecha del save troceada en textos ya con ceros: { y, m, d, h, min }.
## Vacío si no hay save o el timestamp no se entiende. La View la formatea con
## una clave localizada (el orden día/mes/año depende del idioma).
var save_date: Dictionary = {}

# ============================================
# REFERENCIAS
# ============================================

var _save_manager: SaveSystem = null

# ============================================
# INICIALIZACIÓN
# ============================================

func _ready() -> void:
	# Spike 23: lo guardado en user://settings.cfg se aplica al arrancar.
	# Sin fichero no cambia nada.
	GameSettings.apply_saved()

	_save_manager = get_node_or_null("/root/SaveManager")
	if not _save_manager:
		push_warning("[MainMenuViewModel] SaveManager not found — load/save features disabled")

	if EventBus:
		EventBus.game_state_changed.connect(_on_game_state_changed)
	else:
		push_error("[MainMenuViewModel] EventBus not found — no podrá reaccionar a cambios de estado")

	# Spike 7: marca de quickload pendiente. F9 en partida está desestimado, pero
	# la llamada se conserva sin cambios (inocua; limpieza pendiente).
	if _save_manager and _save_manager.consume_pending_quickload():
		call_deferred("request_load_game")


## Reacciona a cualquier cambio de GameState — incluidos los que NO originó
## este propio menú (volver desde CharacterCreation, derrota, salir a
## Exploration). Sin esto, el menú se queda "congelado" en TRANSITIONING.
func _on_game_state_changed(new_state: int) -> void:
	if new_state == GameLoopSystem.GameState.MENU:
		if state != MenuState.MAIN:
			open()
	else:
		if state != MenuState.HIDDEN:
			state = MenuState.HIDDEN
			changed.emit("hidden")


# ============================================
# API PÚBLICA — llamada desde la View
# ============================================

func open() -> void:
	_refresh_save_state()
	state = MenuState.MAIN
	changed.emit("main")


func request_new_game() -> void:
	if state == MenuState.TRANSITIONING:
		return
	state = MenuState.TRANSITIONING
	changed.emit("transitioning")
	# Dar un frame para que la View deshabilite botones antes de cambiar escena
	await get_tree().process_frame
	var game_loop := get_node_or_null("/root/GameLoop") as GameLoopSystem
	if game_loop:
		game_loop.enter_character_creation()
	else:
		push_error("[MainMenuViewModel] GameLoop not found")
		state = MenuState.MAIN
		changed.emit("main")


func request_load_game() -> void:
	if state == MenuState.TRANSITIONING:
		return
	if not has_save:
		changed.emit("load_blocked")
		return
	state = MenuState.TRANSITIONING
	changed.emit("transitioning")
	await get_tree().process_frame
	if _save_manager:
		var ok: bool = _save_manager.load_game("quicksave")
		if ok:
			var game_loop := get_node_or_null("/root/GameLoop") as GameLoopSystem
			if game_loop:
				# Decide entre volver a la escena narrativa pendiente o a EXPLORATION.
				game_loop.enter_post_load_state(_save_manager)
			else:
				push_error("[MainMenuViewModel] GameLoop not found")
				state = MenuState.MAIN
				changed.emit("main")
		else:
			push_error("[MainMenuViewModel] load_game() failed")
			state = MenuState.MAIN
			changed.emit("main")
	else:
		push_error("[MainMenuViewModel] SaveManager not found")
		state = MenuState.MAIN
		changed.emit("main")


func request_options() -> void:
	if state == MenuState.TRANSITIONING:
		return
	state = MenuState.OPTIONS
	changed.emit("options")


func request_credits() -> void:
	if state == MenuState.TRANSITIONING:
		return
	state = MenuState.CREDITS
	changed.emit("credits")


func request_quit() -> void:
	if state == MenuState.TRANSITIONING:
		return
	state = MenuState.CONFIRM_QUIT
	changed.emit("confirm_quit")


func confirm_quit() -> void:
	get_tree().quit()


## Vuelve al panel principal desde cualquier sub-panel
func request_back() -> void:
	if state == MenuState.TRANSITIONING or state == MenuState.HIDDEN:
		return
	state = MenuState.MAIN
	changed.emit("main")


# ============================================
# PRIVADO
# ============================================

func _refresh_save_state() -> void:
	if not _save_manager:
		has_save = false
		save_info = {}
		save_date = {}
		return
	has_save = _save_manager.has_save("quicksave")
	save_info = _save_manager.get_save_info("quicksave") if has_save else {}
	save_date = _parse_save_date(str(save_info.get("timestamp", "")))


## "2026-11-01T22:30:54" → { y: "2026", m: "11", d: "01", h: "22", min: "30" }.
## Devuelve {} si el formato no es el esperado.
func _parse_save_date(timestamp: String) -> Dictionary:
	var halves: PackedStringArray = timestamp.split("T")
	if halves.size() != 2:
		return {}
	var date_parts: PackedStringArray = halves[0].split("-")
	var time_parts: PackedStringArray = halves[1].split(":")
	if date_parts.size() != 3 or time_parts.size() < 2:
		return {}
	return {
		"y": date_parts[0],
		"m": date_parts[1],
		"d": date_parts[2],
		"h": time_parts[0],
		"min": time_parts[1],
	}
