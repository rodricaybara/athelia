class_name GameOverViewModel
extends Node

## GameOverViewModel — Estado y única intención de la pantalla de Game Over
## (Spike 14).
##
## Ruta: res://ui/gameover/game_over_viewmodel.gd
## Hijo de GameOverUI (la View lo crea en su _ready()).
##
## Una sola intención: request_return_to_menu(). Lleva a GameLoop a MENU; el
## reinicio de sesión y el teardown de escenas (incluida esta misma pantalla)
## los hace SceneOrchestrator al entrar en MENU. Por eso este ViewModel NO
## escucha EventBus: su vida la gestiona el orquestador, no una señal.
##
## Razones posibles de changed():
##   "opened"        → mostrar la pantalla y habilitar el botón
##   "transitioning" → deshabilitar el botón (ya se está volviendo al menú)

enum PanelState { HIDDEN, SHOWING, TRANSITIONING }

signal changed(reason: String)

## Estado público: la View lo lee, nunca lo escribe.
var state: PanelState = PanelState.HIDDEN


## Llamado por la View cuando el orquestador muestra el Game Over.
func open() -> void:
	state = PanelState.SHOWING
	changed.emit("opened")


## Única intención. Ignora pulsaciones repetidas mientras transiciona.
func request_return_to_menu() -> void:
	if state != PanelState.SHOWING:
		return

	state = PanelState.TRANSITIONING
	changed.emit("transitioning")

	# Único await permitido en un ViewModel: da un frame a la View para que
	# procese "transitioning" y deshabilite el botón antes de cambiar de
	# estado (ver contrato del ViewModel en athelia_ui_architecture.md).
	await get_tree().process_frame

	print("[GameOverViewModel] Return to menu requested")
	GameLoop.enter_main_menu()

	# Si la transición se rechazara, GameLoop se queda donde estaba y el botón
	# se quedaría bloqueado para siempre. En el caso normal, el orquestador ya
	# habrá encolado la liberación de esta pantalla; este nodo sigue vivo hasta
	# el final del frame, así que la comprobación es segura.
	var current_state: int = GameLoop.current_game_state
	if current_state != GameLoopSystem.GameState.MENU:
		push_error("[GameOverViewModel] No se pudo volver a MENU — reabriendo el botón")
		state = PanelState.SHOWING
		changed.emit("opened")
