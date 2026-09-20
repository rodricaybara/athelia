extends Control

## Triángulo sólido de "turno actual", encima de la ficha activa.
## Helper interno de UICombatToken. Apex hacia abajo, apuntando a la
## ficha — base en la parte superior del propio Control.
##
## Visibilidad gestionada por UICombatToken (is_current_turn), no aquí.

const TRIANGLE_WIDTH: float = 16.0
const TRIANGLE_HEIGHT: float = 12.0


func _draw() -> void:
	var center_x: float = size.x / 2.0
	var apex: Vector2 = Vector2(center_x, size.y)
	var base_left: Vector2 = Vector2(center_x - TRIANGLE_WIDTH / 2.0, size.y - TRIANGLE_HEIGHT)
	var base_right: Vector2 = Vector2(center_x + TRIANGLE_WIDTH / 2.0, size.y - TRIANGLE_HEIGHT)
	draw_colored_polygon(PackedVector2Array([base_left, base_right, apex]), UITokens.COLOR_TURN_INDICATOR)
