class_name InteractiveSceneView
extends Control

## InteractiveSceneView — Spike 12: motor de escenas interactivas
##
## Vista pasiva: pinta el fondo y un Button por hotspot visible. No conoce
## GameLoop, EventBus ni flags — todo lo decide el ViewModel.
##
## Árbol esperado (ver guía de montaje):
##   InteractiveSceneView (Control, este script, anclaje full rect)
##   ├── Fallback (ColorRect, full rect, mouse_filter = Ignore)
##   ├── Background (TextureRect, full rect, mouse_filter = Ignore)
##   └── HotspotLayer (Control, full rect, mouse_filter = Ignore)
##
## Los hotspots usan Button estándar de momento (hereda main_theme.tres).
## Sustituir por UIButton/UISlot cuando se haga el pase de arte de UI.

const HOTSPOT_MIN_SIZE := Vector2(140, 44)
## Lado (px) de los hotspots con icono.
const ICON_HOTSPOT_SIZE: int = 88

var _view_model: InteractiveSceneViewModel = null

@onready var _background: TextureRect = $Background
@onready var _hotspot_layer: Control = $HotspotLayer


func _ready() -> void:
	# Fijados en código además de en el editor: un TextureRect con
	# expand_mode por defecto impone el tamaño de su textura como mínimo.
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	resized.connect(_layout_hotspots)


## Debe llamarse DESPUÉS de que este nodo esté en el árbol (@onready listos).
func bind(view_model: InteractiveSceneViewModel) -> void:
	if _view_model != null and _view_model.changed.is_connected(_on_view_model_changed):
		_view_model.changed.disconnect(_on_view_model_changed)

	_view_model = view_model
	_view_model.changed.connect(_on_view_model_changed)
	_rebuild()


func _on_view_model_changed(_reason: String) -> void:
	_rebuild()


func _rebuild() -> void:
	if _view_model == null:
		return

	_apply_background()

	for child in _hotspot_layer.get_children():
		_hotspot_layer.remove_child(child)
		child.queue_free()

	for hotspot in _view_model.visible_hotspots:
		_hotspot_layer.add_child(_create_hotspot_button(hotspot))

	_layout_hotspots()


func _apply_background() -> void:
	var path := _view_model.background_path
	if path.is_empty() or not ResourceLoader.exists(path):
		_background.texture = null
	else:
		_background.texture = load(path) as Texture2D


func _create_hotspot_button(hotspot: InteractiveHotspotDefinition) -> Button:
	var has_icon: bool = not hotspot.icon_path.is_empty() and ResourceLoader.exists(hotspot.icon_path)

	# variant/btn_size/min_square se fijan ANTES del add_child (UIButton los lee en _ready).
	var button := UIButton.new()
	button.set_meta("map_position", hotspot.map_position)

	if has_icon:
		button.variant = UIButton.Variant.GHOST
		button.min_square = ICON_HOTSPOT_SIZE
		button.icon_backdrop = true
		button.icon = load(hotspot.icon_path) as Texture2D
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.tooltip_text = tr(hotspot.label_key)   # el nombre pasa a tooltip
	else:
		button.variant = UIButton.Variant.SECONDARY
		button.btn_size = UIButton.Size.MD
		button.text = tr(hotspot.label_key)
		button.custom_minimum_size = HOTSPOT_MIN_SIZE

	button.pressed.connect(_on_hotspot_pressed.bind(hotspot.hotspot_id))
	return button


func _on_hotspot_pressed(hotspot_id: String) -> void:
	if _view_model:
		_view_model.activate_hotspot(hotspot_id)


## Rectángulo que ocupa realmente la imagen dentro de la vista
## (STRETCH_KEEP_ASPECT_CENTERED deja franjas si las proporciones difieren).
## Sin textura, usa toda la vista. Las posiciones normalizadas se aplican
## sobre este rectángulo, no sobre el control completo.
func _get_image_rect() -> Rect2:
	var full_rect := Rect2(Vector2.ZERO, size)
	var texture := _background.texture
	if texture == null:
		return full_rect

	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return full_rect

	var fit := minf(size.x / texture_size.x, size.y / texture_size.y)
	var image_size := texture_size * fit
	return Rect2((size - image_size) * 0.5, image_size)


func _layout_hotspots() -> void:
	var image_rect := _get_image_rect()
	for child in _hotspot_layer.get_children():
		var button := child as Control
		if button == null:
			continue
		var map_pos: Vector2 = button.get_meta("map_position", Vector2(0.5, 0.5))
		var button_size := button.get_combined_minimum_size()
		button.size = button_size
		button.position = image_rect.position + map_pos * image_rect.size - button_size * 0.5
