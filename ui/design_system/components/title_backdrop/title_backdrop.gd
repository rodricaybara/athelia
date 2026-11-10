class_name TitleBackdrop
extends Control

## TitleBackdrop — Fondo y título de pantalla completa (Spike 23).
##
## Componente reutilizable del Design System. Lo usa la pantalla de inicio y lo
## usará el Game Over (Spike 24). No conoce ninguna pantalla ni sistema.
##
## Capas: color base (UITokens.BG_BASE) → imagen cover (opcional) → velo
## (solo con imagen, para la legibilidad) → título.
##
## Sin background_texture (placeholder actual) se ve el color base plano.
## Cuando haya arte, basta con asignarla en el inspector.

@export var background_texture: Texture2D:
	set(value):
		background_texture = value
		if is_node_ready():
			_apply()

@export var title_text: String = "ATHELIA":
	set(value):
		title_text = value
		if is_node_ready():
			_apply()

@export var show_title: bool = true:
	set(value):
		show_title = value
		if is_node_ready():
			_apply()

## Posición vertical del título como fracción de la altura.
@export_range(0.0, 0.5, 0.01) var title_top_fraction: float = 0.12:
	set(value):
		title_top_fraction = value
		if is_node_ready():
			_update_title_position()

@onready var base_rect: ColorRect = %BaseRect
@onready var background_image: TextureRect = %BackgroundImage
@onready var scrim: ColorRect = %Scrim
@onready var title_label: Label = %TitleLabel


func _ready() -> void:
	base_rect.color = UITokens.BG_BASE
	scrim.color = UITokens.COLOR_SCRIM

	title_label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_DISPLAY)
	title_label.add_theme_color_override("font_color", UITokens.COLOR_ACCENT)
	title_label.add_theme_color_override("font_outline_color", UITokens.COLOR_TEXT_OUTLINE)
	title_label.add_theme_constant_override("outline_size", UITokens.TEXT_OUTLINE_SIZE)

	resized.connect(_update_title_position)
	_apply()


func _apply() -> void:
	background_image.texture = background_texture
	background_image.visible = background_texture != null
	scrim.visible = background_texture != null

	title_label.text = title_text
	title_label.visible = show_title
	_update_title_position()


func _update_title_position() -> void:
	title_label.offset_top = size.y * title_top_fraction
	title_label.offset_bottom = title_label.offset_top + title_label.get_minimum_size().y
