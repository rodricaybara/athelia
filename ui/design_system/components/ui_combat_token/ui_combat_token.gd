class_name UICombatToken
extends Control

## UICombatToken — Ficha de combate (party o enemigo)
##
## Componente del Design System. Compone dos UIRadialGauge (PV/EN),
## un relleno central (iniciales o icono de tipo), triángulo de turno
## y retícula de objetivo — todos como hijos ya presentes en el .tscn,
## nunca instanciados por código.
##
## Cero lógica de combate aquí: solo traduce datos ya resueltos
## (CombatTokenData, desde el ViewModel) a estado visual. Quien lo usa
## llama a set_hp()/set_stamina() y fija los demás exports/propiedades
## en cada refresco de la View — mismo contrato MVVM de siempre.

# ============================================
# REFERENCIAS A NODOS (fijas en el .tscn)
# ============================================

@onready var _hp_gauge: UIRadialGauge = %HpGauge
@onready var _en_gauge: UIRadialGauge = %EnGauge
@onready var _center_fill: Control = %CenterFill          # script: ui_combat_token_center_fill.gd
@onready var _initials_label: Label = %InitialsLabel
@onready var _type_icon: TextureRect = %TypeIcon
@onready var _hp_value_label: Label = %HpValueLabel
@onready var _en_value_label: Label = %EnValueLabel
@onready var _turn_triangle: Control = %TurnTriangle       # script: ui_combat_token_turn_triangle.gd
@onready var _target_reticle: Control = %TargetReticle     # script: ui_combat_token_target_reticle.gd

# ============================================
# PARÁMETROS EXPORTADOS — se fijan una vez al construir la ficha
# ============================================

## true = ficha de party (muestra EN, iniciales). false = enemigo (solo PV, icono de tipo).
@export var is_party: bool = true:
	set(value):
		is_party = value
		if is_node_ready():
			_update_party_dependent_visuals()

## Iniciales mostradas en el centro (solo party). 2-3 letras.
@export var display_initials: String = "":
	set(value):
		display_initials = value
		if is_node_ready():
			_initials_label.text = display_initials

## Icono de tipo mostrado en el centro (solo enemigos).
@export var type_icon: Texture2D = null:
	set(value):
		type_icon = value
		if is_node_ready():
			_type_icon.texture = type_icon

## Color de relleno del círculo central.
@export var fill_color: Color = Color.WHITE:
	set(value):
		fill_color = value
		if is_node_ready():
			_center_fill.fill_color = fill_color

# ============================================
# ESTADO — actualizado en cada refresco de la View
# ============================================

var hp_current: int = 0
var hp_max: int = 1
var stamina_current: int = 0
var stamina_max: int = 1

## Triángulo de turno encima de la ficha.
var is_current_turn: bool = false:
	set(value):
		is_current_turn = value
		if is_node_ready():
			_turn_triangle.visible = is_current_turn

## Retícula punteada de objetivo alrededor de la ficha.
var is_targeted: bool = false:
	set(value):
		is_targeted = value
		if is_node_ready():
			_target_reticle.visible = is_targeted

# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	_apply_text_outline()
	_update_party_dependent_visuals()
	_center_fill.fill_color = fill_color
	_turn_triangle.visible = is_current_turn
	_target_reticle.visible = is_targeted
	if is_party:
		_initials_label.text = display_initials
	else:
		_type_icon.texture = type_icon

# ============================================
# API PÚBLICA — recursos
# ============================================

## PV y máximo casi siempre llegan juntos (un solo resource_changed) —
## un método agrupado evita dos actualizaciones visuales separadas.
func set_hp(current: int, max_value: int) -> void:
	hp_current = current
	hp_max = maxi(1, max_value)  # evita división por cero en el gauge
	_hp_gauge.progress = float(hp_current) / float(hp_max)
	_hp_value_label.text = "%d/%d" % [hp_current, hp_max]

## No-op silencioso si is_party == false — los enemigos no exponen EN.
func set_stamina(current: int, max_value: int) -> void:
	if not is_party:
		return
	stamina_current = current
	stamina_max = maxi(1, max_value)
	_en_gauge.progress = float(stamina_current) / float(stamina_max)
	_en_value_label.text = "%d/%d" % [stamina_current, stamina_max]

# ============================================
# INTERNO
# ============================================

## Grupo 4 — contorno oscuro en todo el texto de la ficha. Con fondos de
## combate claros (mapas sobre pergamino) el texto claro sin contorno se
## pierde. Desde el script y no desde el .tscn: los valores vienen de
## UITokens, nunca fijados en la escena.
func _apply_text_outline() -> void:
	for label: Label in [_initials_label, _hp_value_label, _en_value_label]:
		label.add_theme_constant_override("outline_size", UITokens.TEXT_OUTLINE_SIZE)
		label.add_theme_color_override("font_outline_color", UITokens.COLOR_TEXT_OUTLINE)


func _update_party_dependent_visuals() -> void:
	_en_gauge.visible = is_party
	_en_value_label.visible = is_party
	_initials_label.visible = is_party
	_type_icon.visible = not is_party

	if is_party:
		_hp_gauge.ring_color = UITokens.COLOR_GAUGE_HP_PARTY
		_en_gauge.ring_color = UITokens.COLOR_GAUGE_EN_PARTY
	else:
		_hp_gauge.ring_color = UITokens.COLOR_GAUGE_HP_ENEMY
