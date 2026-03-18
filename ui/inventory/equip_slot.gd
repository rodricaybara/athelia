class_name EquipSlot
extends PanelContainer

## EquipSlot - Slot de equipamiento en el panel de equipo
##
## Diferencias con ItemSlot:
## - Muestra el nombre del slot (cabeza, arma, etc.)
## - Click en slot ocupado → emite unequip_requested (no slot_clicked)
## - Acepta drop de drag & drop desde ItemSlot
## - Visual distinto: borde dorado cuando ocupado

signal unequip_requested(slot_id: String)
signal drop_accepted(slot_id: String, item_id: String)

## ID del slot: "head", "body", "weapon", etc.
@export var slot_id: String = ""
## Clave de localización para el label del slot
@export var slot_label_key: String = ""

@onready var icon_rect: TextureRect = $MarginContainer/VBoxContainer/IconRect
@onready var slot_label: Label = $MarginContainer/VBoxContainer/SlotLabel
@onready var button: Button = $Button

const COLOR_EMPTY    = Color(0.15, 0.15, 0.15, 0.9)
const COLOR_OCCUPIED = Color(0.25, 0.20, 0.05, 0.95)
const COLOR_HOVER    = Color(0.35, 0.30, 0.10, 1.0)
const BORDER_EMPTY    = Color(0.4, 0.4, 0.4, 1.0)
const BORDER_OCCUPIED = Color(0.8, 0.7, 0.2, 1.0)  # dorado

var _item_id: String = ""


func _ready() -> void:
	button.pressed.connect(_on_button_pressed)
	button.mouse_entered.connect(_on_mouse_entered)
	button.mouse_exited.connect(_on_mouse_exited)
	
	# Configurar label del slot
	if slot_label:
		slot_label.text = tr(slot_label_key) if not slot_label_key.is_empty() else slot_id.capitalize()
	
	_apply_style(COLOR_EMPTY, BORDER_EMPTY)


# ============================================
# API PÚBLICA
# ============================================

## Muestra el ítem equipado en este slot
func set_equipped(item_def: ItemDefinition) -> void:
	if not item_def:
		clear()
		return
	
	_item_id = item_def.id
	
	if item_def.icon:
		icon_rect.texture = item_def.icon
	else:
		icon_rect.texture = load("res://icon.svg")
		icon_rect.modulate = Color(0.9, 0.8, 0.3, 1.0)  # tinte dorado para placeholder
	
	button.disabled = false
	_apply_style(COLOR_OCCUPIED, BORDER_OCCUPIED)


## Vacía el slot
func clear() -> void:
	_item_id = ""
	icon_rect.texture = null
	icon_rect.modulate = Color.WHITE
	button.disabled = true
	_apply_style(COLOR_EMPTY, BORDER_EMPTY)


## Retorna el item_id equipado o "" si está vacío
func get_item_id() -> String:
	return _item_id


func is_occupied() -> bool:
	return not _item_id.is_empty()


# ============================================
# DRAG & DROP
# ============================================

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if not data.has("item_id") or not data.has("source") :
		return false
	# Solo acepta drops desde el inventario (no desde otro equip slot)
	return data.get("source") == "inventory"


func _drop_data(_pos: Vector2, data: Variant) -> void:
	var item_id: String = data.get("item_id", "")
	if not item_id.is_empty():
		emit_signal("drop_accepted", slot_id, item_id)


# ============================================
# CALLBACKS
# ============================================

func _on_button_pressed() -> void:
	if is_occupied():
		emit_signal("unequip_requested", slot_id)


func _on_mouse_entered() -> void:
	if is_occupied():
		_apply_style(COLOR_HOVER, BORDER_OCCUPIED)


func _on_mouse_exited() -> void:
	if is_occupied():
		_apply_style(COLOR_OCCUPIED, BORDER_OCCUPIED)
	else:
		_apply_style(COLOR_EMPTY, BORDER_EMPTY)


# ============================================
# HELPERS VISUALES
# ============================================

func _apply_style(bg: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = border
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	add_theme_stylebox_override("panel", style)
