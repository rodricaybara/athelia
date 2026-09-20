extends Control

## Círculo relleno central de UICombatToken.
## Helper interno del componente — no es un componente del Design
## System por sí mismo, no lleva class_name ni vive fuera de
## ui_combat_token/.

@export var fill_color: Color = Color.WHITE:
	set(value):
		fill_color = value
		queue_redraw()


func _draw() -> void:
	var radius: float = minf(size.x, size.y) / 2.0
	draw_circle(size / 2.0, radius, fill_color)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
