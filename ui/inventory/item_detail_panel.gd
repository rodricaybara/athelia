class_name ItemDetailPanel
extends UIPanel

## ItemDetailPanel - Panel de información del ítem seleccionado
##
## Pasivo: recibe datos de la View que lo contiene y emite intenciones.
## Spike 18: es un UIPanel (DEFAULT); botones UIButton; categoría, modificadores
## y comparación con lo equipado vienen YA calculados en
## InventoryViewModel.DetailData (este panel solo los pinta).
##
## Compatibilidad: show_item(item_def, quantity, is_equipped) se mantiene
## (sin categoría, modificadores ni comparación).

signal use_pressed(item_id: String)
signal equip_pressed(item_id: String)
signal unequip_pressed(item_id: String)

@onready var empty_message: Label           = %EmptyMessage
@onready var body: Control                  = %Body
@onready var item_name_label: Label         = %ItemNameLabel
@onready var category_label: Label          = %CategoryLabel
@onready var item_description_label: Label  = %ItemDescriptionLabel
@onready var item_stats_label: Label        = %ItemStatsLabel
@onready var modifiers_box: VBoxContainer   = %ModifiersBox
@onready var compare_box: VBoxContainer     = %CompareBox
@onready var use_button: UIButton           = %UseButton
@onready var equip_button: UIButton         = %EquipButton

var current_item_id: String = ""
var _is_equipped: bool = false


func _ready() -> void:
	super._ready()

	use_button.pressed.connect(_on_use_button_pressed)
	equip_button.pressed.connect(_on_equip_button_pressed)

	item_name_label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_XL)
	item_name_label.add_theme_color_override("font_color", UITokens.COLOR_ACCENT)
	category_label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_SM)
	category_label.add_theme_color_override("font_color", UITokens.COLOR_TEXT_MUTED)
	item_description_label.add_theme_color_override("font_color", UITokens.COLOR_TEXT)
	item_stats_label.add_theme_color_override("font_color", UITokens.COLOR_TEXT_MUTED)
	empty_message.add_theme_color_override("font_color", UITokens.COLOR_TEXT_MUTED)

	use_button.text = tr("INVENTORY_BUTTON_USE")
	empty_message.text = tr("INVENTORY_DETAIL_EMPTY")
	clear()


## Muestra el detalle completo calculado por el ViewModel
func show_detail(data: InventoryViewModel.DetailData) -> void:
	if data == null or data.item_def == null:
		clear()
		return

	_show_common(data.item_def, data.quantity, data.is_equipped)

	category_label.text = tr("INVENTORY_DETAIL_CATEGORY") % data.category_name if not data.category_name.is_empty() else ""
	category_label.visible = not data.category_name.is_empty()

	_clear_children(modifiers_box)
	for line in data.modifier_lines:
		_add_row(modifiers_box, line.label, line.text, UITokens.COLOR_TEXT)

	_clear_children(compare_box)
	if data.has_comparison:
		var header: String
		if data.compare_slot_free:
			header = tr("INVENTORY_COMPARE_SLOT_FREE") % _slot_text(data.compare_slot_id)
		else:
			header = tr("INVENTORY_COMPARE_HEADER") % data.compare_against_name
		var header_label := Label.new()
		header_label.text = header
		header_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		header_label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_SM)
		header_label.add_theme_color_override("font_color", UITokens.COLOR_TEXT_MUTED)
		compare_box.add_child(header_label)

		if data.compare_lines.is_empty():
			var none_label := Label.new()
			none_label.text = tr("INVENTORY_COMPARE_NO_DIFF")
			none_label.add_theme_color_override("font_color", UITokens.COLOR_TEXT_MUTED)
			compare_box.add_child(none_label)
		for line in data.compare_lines:
			var color: Color = UITokens.COLOR_SUCCESS_SOFT if line.delta > 0.0 else UITokens.COLOR_DANGER_SOFT
			_add_row(compare_box, line.label, line.text, color)
	compare_box.visible = data.has_comparison
	modifiers_box.visible = not data.modifier_lines.is_empty()


## Compatibilidad con el contrato del Spike 17
func show_item(item_def: ItemDefinition, quantity: int, is_equipped: bool = false) -> void:
	if item_def == null:
		clear()
		return
	_show_common(item_def, quantity, is_equipped)
	category_label.visible = false
	_clear_children(modifiers_box)
	_clear_children(compare_box)
	modifiers_box.visible = false
	compare_box.visible = false


func clear() -> void:
	current_item_id = ""
	_is_equipped = false
	body.visible = false
	empty_message.visible = true


func _show_common(item_def: ItemDefinition, quantity: int, is_equipped: bool) -> void:
	current_item_id = item_def.id
	_is_equipped = is_equipped

	item_name_label.text = tr(item_def.name_key)
	item_description_label.text = tr(item_def.description_key)

	var stats_text: String = tr("INVENTORY_DETAIL_WEIGHT") % item_def.weight + "\n"
	stats_text += tr("INVENTORY_DETAIL_VALUE") % item_def.base_value + "\n"
	stats_text += tr("INVENTORY_DETAIL_QUANTITY") % quantity
	item_stats_label.text = stats_text

	# Botón USAR: solo para consumibles
	use_button.visible = item_def.usable and item_def.item_type == "CONSUMABLE"

	# Botón EQUIPAR/DESEQUIPAR: solo para equipment
	equip_button.visible = item_def.item_type == "EQUIPMENT"
	if is_equipped:
		equip_button.text = tr("INVENTORY_BUTTON_UNEQUIP")
		equip_button.set_variant(UIButton.Variant.SECONDARY)
	else:
		equip_button.text = tr("INVENTORY_BUTTON_EQUIP")
		equip_button.set_variant(UIButton.Variant.PRIMARY)

	empty_message.visible = false
	body.visible = true


func _slot_text(slot_id: String) -> String:
	var key: String = "INVENTORY_SLOT_" + slot_id.to_upper()
	var text: String = tr(key)
	return text if text != key else slot_id.capitalize()


func _add_row(container: VBoxContainer, left_text: String, right_text: String, right_color: Color) -> void:
	var row := HBoxContainer.new()
	var left := Label.new()
	left.text = left_text
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_color_override("font_color", UITokens.COLOR_TEXT)
	var right := Label.new()
	right.text = right_text
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_theme_color_override("font_color", right_color)
	row.add_child(left)
	row.add_child(right)
	container.add_child(row)


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _on_use_button_pressed() -> void:
	if not current_item_id.is_empty():
		use_pressed.emit(current_item_id)


func _on_equip_button_pressed() -> void:
	if current_item_id.is_empty():
		return
	if _is_equipped:
		unequip_pressed.emit(current_item_id)
	else:
		equip_pressed.emit(current_item_id)
