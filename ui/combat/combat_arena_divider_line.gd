extends Control

## Línea vertical punteada entre PartyColumn y EnemyColumn.
## Helper interno de CombatArenaPanel — mismo criterio de dash que
## ui_combat_token_target_reticle.gd, pero en línea recta en vez de arco.

const DASH_LENGTH: float = 8.0
const GAP_LENGTH: float = 6.0
const LINE_COLOR: Color = Color("#3D3830")  # mismo border_color que el resto del Design System
const LINE_WIDTH: float = 2.0


func _draw() -> void:
	var x: float = size.x / 2.0
	var y: float = 0.0
	var step: float = DASH_LENGTH + GAP_LENGTH

	while y < size.y:
		var dash_end: float = minf(y + DASH_LENGTH, size.y)
		draw_line(Vector2(x, y), Vector2(x, dash_end), LINE_COLOR, LINE_WIDTH)
		y += step


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
