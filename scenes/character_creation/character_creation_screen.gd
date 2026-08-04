class_name CharacterCreationScreen
extends CanvasLayer

## CharacterCreationScreen — STUB
## Pantalla de creación de personaje. Lógica pendiente de implementar.
##
## API mínima para que SceneOrchestrator pueda cargarlo sin errores:
##   open() → muestra la pantalla
##
## TODO: Implementar lógica de creación de personaje:
##   - Selección de nombre
##   - Distribución de atributos base
##   - Selección de habilidades iniciales
##   - Confirmación → GameLoop.enter_exploration()

func _ready() -> void:
	visible = false
	print("[CharacterCreationScreen] Stub loaded — WIP")


func open() -> void:
	visible = true
	print("[CharacterCreationScreen] open() called — awaiting implementation")
