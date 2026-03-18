extends PanelContainer

## ItemSlot - Slot individual de ítem en el inventario
## Componente reutilizable y pasivo
## ACTUALIZACIÓN: añadido soporte drag & drop

signal slot_clicked(item_id: String)

var item_instance: ItemInstance = null

@onready var icon_rect: TextureRect = $MarginContainer/VBoxContainer/IconRect
@onready var quantity_label: Label = $MarginContainer/VBoxContainer/QuantityLabel
@onready var button: Button = $Button

const NORMAL_COLOR   = Color(0.2, 0.2, 0.2, 0.8)
const SELECTED_COLOR = Color(0.4, 0.4, 0.6, 1.0)
const HOVER_COLOR    = Color(0.3, 0.3, 0.4, 0.9)


func _ready() -> void:
	button.pressed.connect(_on_button_pressed)
	button.mouse_entered.connect(_on_mouse_entered)
	button.mouse_exited.connect(_on_mouse_exited)
	clear()


## Configura el slot con un ítem
func set_item(instance: ItemInstance) -> void:
	if not instance or not instance.definition:
		clear()
		return
	
	item_instance = instance
	
	if instance.definition.icon:
		icon_rect.texture = instance.definition.icon
	else:
		var placeholder = load("res://icon.svg") as Texture2D
		icon_rect.texture = placeholder
		icon_rect.modulate = Color(0.5, 0.8, 0.5, 1.0)
	
	if instance.quantity > 1:
		quantity_label.text = "x%d" % instance.quantity
		quantity_label.visible = true
	else:
		quantity_label.visible = false
	
	button.disabled = false
	modulate = Color.WHITE


## Limpia el slot
func clear() -> void:
	item_instance = null
	icon_rect.texture = null
	quantity_label.visible = false
	button.disabled = true
	modulate = Color(1, 1, 1, 0.3)
	set_selected(false)


## Resalta el slot como seleccionado
func set_selected(selected: bool) -> void:
	if selected:
		add_theme_stylebox_override("panel", _create_stylebox(SELECTED_COLOR))
	else:
		add_theme_stylebox_override("panel", _create_stylebox(NORMAL_COLOR))


# ============================================
# DRAG & DROP
# ============================================

func _get_drag_data(_pos: Vector2) -> Variant:
	if not item_instance:
		return null
	
	# Crear preview visual del drag
	var preview := TextureRect.new()
	preview.texture = icon_rect.texture
	preview.custom_minimum_size = Vector2(48, 48)
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	
	return {
		"item_id": item_instance.definition.id,
		"source": "inventory"
	}


# ============================================
# CALLBACKS
# ============================================

func _on_button_pressed() -> void:
	if item_instance:
		slot_clicked.emit(item_instance.definition.id)


func _on_mouse_entered() -> void:
	if item_instance and not button.disabled:
		add_theme_stylebox_override("panel", _create_stylebox(HOVER_COLOR))


func _on_mouse_exited() -> void:
	if item_instance:
		set_selected(false)


func _create_stylebox(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.5, 0.5, 1.0)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style
