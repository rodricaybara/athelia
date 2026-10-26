extends Node

## DEBUG TEMPORAL — Spike 19 (solo para validar Party con 0 y 2 compañeros).
## NO entra en el entregable: borrar el fichero y quitar el autoload al terminar.
##
## Uso: Project Settings → Globals (Autoload) → añadir este script con el
## nombre "DebugPartyTool". Con Party CERRADA:
##   F10 → Mira abandona el grupo (caso 0 compañeros)
##   F11 → entra un segundo compañero de prueba (caso 2 compañeros)
##   F12 → sale el compañero de prueba
##
## AVISO: leave_party() da de baja a la entidad en todos los sistemas
## (inventario y equipo incluidos). Tras F10 hay que volver al menú y cargar el
## guardado de antes de la prueba. No guardes la partida con este estado.

const TEST_ID: String = "companion_debug_test"
## [inferido] La definición de Mira se llama "companion_mira" (el guardado usa
## companion_id como definition_id). Si no existe, join_party avisa por consola.
const TEST_DEFINITION_ID: String = "companion_mira"
const MIRA_ID: String = "companion_mira"


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_F10:
			var left: bool = Party.leave_party(MIRA_ID)
			print("[DebugPartyTool] F10 Mira abandona el grupo: %s" % str(left))
		KEY_F11:
			var joined: bool = Party.join_party(TEST_ID, TEST_DEFINITION_ID)
			print("[DebugPartyTool] F11 entra '%s': %s" % [TEST_ID, str(joined)])
		KEY_F12:
			var removed: bool = Party.leave_party(TEST_ID)
			print("[DebugPartyTool] F12 sale '%s': %s" % [TEST_ID, str(removed)])
