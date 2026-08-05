class_name MainMenuViewModel
extends Node

## MainMenuViewModel — Lógica y estado del menú principal
##
## Razones de changed():
##   "main"          → mostrar panel principal, ocultar el resto
##   "options"       → mostrar panel de opciones
##   "credits"       → mostrar panel de créditos, iniciar scroll
##   "confirm_quit"  → mostrar diálogo de confirmación de salida
##   "transitioning" → deshabilitar botones (transición en curso)
##   "load_blocked"  → no hay partida guardada, feedback visual
##   "hidden"        → GameState salió de MENU — ocultar la pantalla entera

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

## ¿Existe una partida guardada? Determina si "Cargar Partida" está habilitado.
var has_save: bool = false

## Metadata del save (timestamp, playtime_seconds). Vacío si no hay save.
var save_info: Dictionary = {}

# ============================================
# REFERENCIAS
# ============================================

var _save_manager: SaveSystem = null

# ============================================
# INICIALIZACIÓN
# ============================================

func _ready() -> void:
	_save_manager = get_node_or_null("/root/SaveManager")
	if not _save_manager:
		push_warning("[MainMenuViewModel] SaveManager not found — load/save features disabled")

	if EventBus:
		EventBus.game_state_changed.connect(_on_game_state_changed)
	else:
		push_error("[MainMenuViewModel] EventBus not found — no podrá reaccionar a cambios de estado")

	print("[MainMenuViewModel] Initialized")


## Reacciona a cualquier cambio de GameState — incluidos los que NO originó
## este propio menú (ej: volver desde CharacterCreation, o salir hacia
## Exploration). Sin esto, el menú se queda "congelado" en TRANSITIONING
## para siempre tras la primera vez que se abandona MENU.
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
	print("[MainMenuViewModel] Opened → MAIN")


func request_new_game() -> void:
	if state == MenuState.TRANSITIONING:
		return
	print("[MainMenuViewModel] New game requested")
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
		print("[MainMenuViewModel] Load blocked — no save found")
		changed.emit("load_blocked")
		return
	print("[MainMenuViewModel] Loading game...")
	state = MenuState.TRANSITIONING
	changed.emit("transitioning")
	await get_tree().process_frame
	if _save_manager:
		var ok: bool = _save_manager.load_game("quicksave")
		if ok:
			var game_loop := get_node_or_null("/root/GameLoop") as GameLoopSystem
			if game_loop:
				game_loop.enter_exploration()
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
	print("[MainMenuViewModel] → OPTIONS")


func request_credits() -> void:
	if state == MenuState.TRANSITIONING:
		return
	state = MenuState.CREDITS
	changed.emit("credits")
	print("[MainMenuViewModel] → CREDITS")


func request_quit() -> void:
	if state == MenuState.TRANSITIONING:
		return
	state = MenuState.CONFIRM_QUIT
	changed.emit("confirm_quit")
	print("[MainMenuViewModel] → CONFIRM_QUIT")


func confirm_quit() -> void:
	print("[MainMenuViewModel] Quitting application")
	get_tree().quit()


## Vuelve al panel principal desde cualquier sub-panel
func request_back() -> void:
	if state == MenuState.TRANSITIONING:
		return
	state = MenuState.MAIN
	changed.emit("main")
	print("[MainMenuViewModel] → MAIN (back)")


# ============================================
# PRIVADO
# ============================================

func _refresh_save_state() -> void:
	if not _save_manager:
		has_save = false
		save_info = {}
		return
	has_save = _save_manager.has_save("quicksave")
	save_info = _save_manager.get_save_info("quicksave") if has_save else {}
	print("[MainMenuViewModel] Save state — has_save: %s" % has_save)
