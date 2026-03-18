extends PanelContainer

## ItemDetailPanel - Panel de información del ítem seleccionado
## ACTUALIZACIÓN: añadido botón EQUIPAR / DESEQUIPAR

@onready var item_name_label: Label        = %ItemNameLabel
@onready var item_description_label: Label = %ItemDescriptionLabel
@onready var item_stats_label: Label       = %ItemStatsLabel
@onready var use_button: Button            = %UseButton
@onready var equip_button: Button          = %EquipButton
@onready var empty_message: Label          = %EmptyMessage

var current_item_id: String = ""
var _is_equipped: bool = false

signal use_pressed(item_id: String)
signal equip_pressed(item_id: String)
signal unequip_pressed(item_id: String)


func _ready() -> void:
	use_button.pressed.connect(_on_use_button_pressed)
	equip_button.pressed.connect(_on_equip_button_pressed)
	clear()


## Muestra información de un ítem
## is_equipped: si ya está equipado, el botón mostrará "DESEQUIPAR"
func show_item(item_def: ItemDefinition, quantity: int, is_equipped: bool = false) -> void:
	if not item_def:
		clear()
		return
	
	current_item_id = item_def.id
	_is_equipped = is_equipped
	
	item_name_label.text = tr(item_def.name_key)
	item_description_label.text = tr(item_def.description_key)
	
	var stats_text := ""
	stats_text += "Peso: %.1f kg\n" % item_def.weight
	stats_text += "Valor: %d oro\n" % item_def.base_value
	stats_text += "Cantidad: %d" % quantity
	
	# Mostrar modificadores si los tiene
	var mods := item_def.get_modifiers_for_condition("equipped")
	if not mods.is_empty():
		stats_text += "\n─────────"
		for mod in mods:
			var sign_str := "+" if mod.value >= 0 else ""
			stats_text += "\n%s %s%.0f" % [mod.target.split(".")[-1].capitalize(), sign_str, mod.value]
	
	item_stats_label.text = stats_text
	
	# Botón USAR: solo para consumibles
	use_button.visible = item_def.usable and item_def.item_type == "CONSUMABLE"
	use_button.disabled = false
	
	# Botón EQUIPAR/DESEQUIPAR: solo para equipment
	equip_button.visible = item_def.item_type == "EQUIPMENT"
	equip_button.disabled = false
	if is_equipped:
		equip_button.text = "DESEQUIPAR"
		equip_button.modulate = Color(1.0, 0.6, 0.4, 1.0)  # tinte anaranjado
	else:
		equip_button.text = "EQUIPAR"
		equip_button.modulate = Color.WHITE
	
	empty_message.visible = false
	item_name_label.visible = true
	item_description_label.visible = true
	item_stats_label.visible = true


## Limpia el panel
func clear() -> void:
	current_item_id = ""
	_is_equipped = false
	item_name_label.visible = false
	item_description_label.visible = false
	item_stats_label.visible = false
	use_button.visible = false
	equip_button.visible = false
	empty_message.visible = true


func _on_use_button_pressed() -> void:
	if not current_item_id.is_empty():
		emit_signal("use_pressed", current_item_id)


func _on_equip_button_pressed() -> void:
	if current_item_id.is_empty():
		return
	if _is_equipped:
		emit_signal("unequip_pressed", current_item_id)
	else:
		emit_signal("equip_pressed", current_item_id)
