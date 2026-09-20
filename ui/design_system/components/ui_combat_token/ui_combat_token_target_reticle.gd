extends Control

## Retícula punteada de "objetivo seleccionado", alrededor de la ficha.
## Helper interno de UICombatToken. Godot no tiene un círculo punteado
## nativo — se simula con varios draw_arc() cortos separados por huecos.
##
## Visibilidad gestionada por UICombatToken (is_targeted), no aquí.
## Forma y color deliberadamente distintos del triángulo de turno
## (círculo punteado vs triángulo sólido) aunque compartan color —
## para no confundirse si algún día coinciden sobre la misma ficha.

const DASH_COUNT: int = 16
const DASH_ARC_RATIO: float = 0.6  # fracción de cada segmento que se dibuja; el resto es hueco
const RETICLE_THICKNESS: float = 2.0


func _draw() -> void:
	var radius: float = minf(size.x, size.y) / 2.0 - RETICLE_THICKNESS / 2.0
	if radius <= 0.0:
		return

	var center: Vector2 = size / 2.0
	var segment: float = TAU / DASH_COUNT
	var dash_length: float = segment * DASH_ARC_RATIO

	for i in range(DASH_COUNT):
		var start_angle: float = i * segment
		var end_angle: float = start_angle + dash_length
		draw_arc(center, radius, start_angle, end_angle, 8, UITokens.COLOR_TURN_INDICATOR, RETICLE_THICKNESS, true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
