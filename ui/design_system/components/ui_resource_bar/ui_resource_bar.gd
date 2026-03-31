extends Control
class_name UIResourceBar
## UIResourceBar - Barra de recurso reactiva (HP, Stamina, Estrés, etc.)
##
## Se conecta a ResourceSystem vía EventBus.
## No accede directamente a ningún sistema — recibe actualizaciones pasivamente.
##
## Uso:
##   bar.bind("player", "health")
##
## La barra actualiza automáticamente cuando ResourceSystem emite resource_changed.


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


## Actualiza manualmente (útil en contextos sin bind, como tooltips)
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
	if not is_inside_tree():
		return

	var pct := clampf(_current / _max, 0.0, 1.0) if _max > 0 else 0.0

	# Animar el fill con tween para suavidad
	var tween := create_tween()
	tween.tween_property(fill_rect, "size:x",
		bg_rect.size.x * pct,
		UITokens.ANIM_DURATION_NORMAL
	).set_ease(Tween.EASE_OUT)

	# Cambiar color según porcentaje (para HP)
	if resource_type == "health":
		fill_rect.color = _health_color(pct)

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
