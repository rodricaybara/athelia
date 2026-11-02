extends Control
class_name UIResourceBar
## UIResourceBar - Barra de recurso reactiva (HP, Stamina, Estrés, etc.)
##
## Dos formas de usarla:
##   - bind("player", "health"): se conecta a ResourceSystem y se actualiza sola.
##     (El componente accede al juego: no usarla desde una View MVVM.)
##   - set_values(current, max): la View pasa los valores que le da el ViewModel.
##
## Spike 19b-2 (aditivo, API sin cambios):
##   - El ancho del relleno se recalcula cuando la barra cambia de tamaño
##     (antes se calculaba con un ancho 0 si el primer valor llegaba antes del layout).
##   - Cada refresco cancela el tween anterior (antes se apilaban).
##   - El primer valor se pinta directamente, sin animar desde cero.
##   - Se pinta el último valor recibido al entrar en el árbol.


# ============================================================
# NODOS
# ============================================================

@onready var fill_rect:   ColorRect = $FillRect
@onready var bg_rect:     ColorRect = $BgRect
@onready var value_label: Label     = $ValueLabel  # opcional, puede ser null


# ============================================================
# CONFIGURACIÓN
# ============================================================

## Si true, muestra el valor numérico sobre la barra
@export var show_value: bool = false

## Si true, muestra "current / max" en lugar de solo "current"
@export var show_max: bool = false

## Tipo de recurso — determina los colores automáticamente
@export_enum("health", "stamina", "gold", "stress", "custom") var resource_type: String = "health"

## Colores custom (solo si resource_type == "custom")
@export var custom_fill_color: Color = UITokens.COLOR_ACCENT
@export var custom_bg_color:   Color = UITokens.COLOR_PANEL_ALT


# ============================================================
# ESTADO INTERNO
# ============================================================

var _entity_id:  String = ""
var _resource_id: String = ""
var _current: float = 0.0
var _max:     float = 100.0

var _pct: float = 0.0
var _tween: Tween = null
var _has_value: bool = false


# ============================================================
# INICIALIZACIÓN
# ============================================================

func _ready() -> void:
	custom_minimum_size.y = UITokens.RESOURCE_BAR_HEIGHT
	_apply_colors()

	if value_label:
		value_label.visible = show_value
		value_label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_XS)
		value_label.add_theme_color_override("font_color", UITokens.COLOR_TEXT)

	# El relleno sigue al tamaño de la barra (ventana redimensionada, columna que cambia)
	bg_rect.resized.connect(_on_bg_resized)

	# Si set_values() llegó antes de entrar en el árbol, se pinta ahora
	if _has_value:
		_refresh()


# ============================================================
# API PÚBLICA
# ============================================================

## Vincula la barra a un recurso de una entidad
## Después de llamar a bind(), la barra se actualiza automáticamente
func bind(entity_id: String, resource_id: String) -> void:
	_entity_id   = entity_id
	_resource_id = resource_id

	# Detectar tipo de recurso si no está fijado manualmente
	if resource_type != "custom":
		resource_type = resource_id

	_apply_colors()

	# Conectar a la señal del ResourceSystem (autoload: /root/Resources)
	var res_sys: Node = get_node_or_null("/root/Resources")
	if res_sys and not res_sys.resource_changed.is_connected(_on_resource_changed):
		res_sys.resource_changed.connect(_on_resource_changed)

	# Cargar valor inicial
	_load_initial_value()


## Actualiza manualmente (útil en contextos sin bind, como tooltips o Views MVVM)
func set_values(current: float, max_value: float) -> void:
	_current = current
	_max = max_value
	_refresh()


# ============================================================
# CALLBACKS
# ============================================================

func _on_resource_changed(entity_id: String, resource_id: String, current: float, max_value: float) -> void:
	if entity_id != _entity_id or resource_id != _resource_id:
		return
	_current = current
	_max = max_value
	_refresh()


## La barra cambió de tamaño: el relleno se ajusta sin animar
func _on_bg_resized() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	fill_rect.offset_right = bg_rect.size.x * _pct


# ============================================================
# VISUAL
# ============================================================

func _load_initial_value() -> void:
	var resources: Node = get_node_or_null("/root/Resources")
	if not resources:
		return
	var state = resources.get_resource_state(_entity_id, _resource_id)
	if state:
		_current = state.current
		_max     = state.max_effective
		_refresh()


func _refresh() -> void:
	# Fuera del árbol no hay nodos: _ready() repinta con el último valor
	_has_value = true
	if not is_inside_tree() or fill_rect == null or bg_rect == null:
		return

	_pct = clampf(_current / _max, 0.0, 1.0) if _max > 0 else 0.0
	var target_width: float = bg_rect.size.x * _pct

	if _tween != null and _tween.is_valid():
		_tween.kill()

	# Sin animar si la barra aún no tiene tamaño (primer layout pendiente);
	# en cuanto lo tenga, _on_bg_resized() ajusta el ancho
	if bg_rect.size.x <= 0.0:
		fill_rect.offset_right = target_width
	else:
		_tween = create_tween()
		_tween.tween_property(fill_rect, "offset_right",
			target_width,
			UITokens.ANIM_DURATION_NORMAL
		).set_ease(Tween.EASE_OUT)

	# Cambiar color según porcentaje (para HP)
	if resource_type == "health":
		fill_rect.color = _health_color(_pct)

	# Label
	if value_label and show_value:
		if show_max:
			value_label.text = "%d / %d" % [int(_current), int(_max)]
		else:
			value_label.text = str(int(_current))


func _apply_colors() -> void:
	if not is_inside_tree():
		await ready

	match resource_type:
		"health":
			bg_rect.color   = UITokens.COLOR_HEALTH_BG
			fill_rect.color = UITokens.COLOR_HEALTH
		"stamina":
			bg_rect.color   = UITokens.COLOR_STAMINA_BG
			fill_rect.color = UITokens.COLOR_STAMINA
		"gold":
			bg_rect.color   = UITokens.COLOR_GOLD_BG
			fill_rect.color = UITokens.COLOR_GOLD
		"stress":
			bg_rect.color   = UITokens.COLOR_STRESS_BG
			fill_rect.color = UITokens.COLOR_STRESS
		"custom":
			bg_rect.color   = custom_bg_color
			fill_rect.color = custom_fill_color
		_:
			bg_rect.color   = UITokens.COLOR_PANEL_ALT
			fill_rect.color = UITokens.COLOR_ACCENT


func _health_color(pct: float) -> Color:
	if pct > 0.5:
		return UITokens.COLOR_HEALTH
	elif pct > 0.25:
		return UITokens.COLOR_WARNING
	else:
		return UITokens.COLOR_DANGER_SOFT
