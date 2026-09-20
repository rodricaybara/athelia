class_name UIRadialGauge
extends Control

## UIRadialGauge — Anillo de progreso radial, parametrizable
##
## Componente del Design System. Dibuja UN único anillo (track + arco de
## progreso) mediante _draw(). No conoce PV/EN/party/enemigo — quien lo
## instancia decide color, grosor y tamaño (vía layout del nodo).
##
## Uso en una ficha de combate:
##   - Ficha de party: dos instancias (anillo PV exterior + anillo EN
##     interior, radios distintos por tamaño del Control).
##   - Ficha enemiga: una instancia (solo PV).
##
## Reactivo puro: cada setter llama a queue_redraw(). Sin _process().
##
## Nunca acceder a sistemas core (Characters, Resources...) desde aquí —
## el progreso y el color llegan siempre desde fuera, ya resueltos.

# ============================================
# PARÁMETROS EXPORTADOS
# ============================================

## Progreso actual, 0.0-1.0. Quien instancia el nodo calcula actual/max.
@export_range(0.0, 1.0, 0.01) var progress: float = 1.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()

## Color del arco de progreso.
@export var ring_color: Color = Color.WHITE:
	set(value):
		ring_color = value
		queue_redraw()

## Color del track de fondo (el anillo completo, por debajo del progreso).
## Default: reutiliza el border_color ya existente en UITokens — sin
## token nuevo para esto.
@export var track_color: Color = Color("#3D3830"):
	set(value):
		track_color = value
		queue_redraw()

## Grosor del anillo en píxeles.
@export var thickness: float = 4.0:
	set(value):
		thickness = maxf(0.0, value)
		queue_redraw()


# ============================================
# DIBUJADO
# ============================================

func _draw() -> void:
	var radius: float = _get_radius()
	if radius <= 0.0:
		return

	var center: Vector2 = size / 2.0
	var start_angle: float = -PI / 2.0  # arranca arriba (12 en punto)

	# Track completo — círculo de fondo
	draw_arc(center, radius, 0.0, TAU, 64, track_color, thickness, true)

	# Arco de progreso — sentido horario desde start_angle
	if progress > 0.0:
		var end_angle: float = start_angle + TAU * progress
		draw_arc(center, radius, start_angle, end_angle, 64, ring_color, thickness, true)


## Radio derivado del tamaño real del Control — nunca un número suelto
## que se pueda desincronizar del layout.
func _get_radius() -> float:
	return minf(size.x, size.y) / 2.0 - thickness / 2.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
