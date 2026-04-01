extends PanelContainer
class_name UISlot
## UISlot - Slot universal para inventario, equipamiento y loot
##
## Contrato:
##   - Nunca accede a sistemas core directamente
##   - Solo recibe datos, emite intenciones
##   - El padre (View / Screen) decide qué hacer con las señales
##
## Uso:
##   var slot = preload("res://ui/design_system/components/slot/ui_slot.tscn").instantiate()
##   slot.set_item(item_instance)
##   slot.slot_clicked.connect(_on_slot_clicked)


# ============================================================
# SEÑALES
# ============================================================

## Emitida al hacer click en el slot (ocupado o vacío)
signal slot_clicked(slot: UISlot)

## Emitida al soltar un drag sobre este slot
signal slot_drop_received(slot: UISlot, source_item_id: String)


# ============================================================
# ESTADOS
# ============================================================

enum SlotState {
	EMPTY,       ## Sin item
	OCCUPIED,    ## Tiene item, no seleccionado
	SELECTED,    ## Seleccionado activamente
	EQUIPPED,    ## Item equipado (para panel de equipamiento)
	HIGHLIGHTED, ## Slot de comparación activo
	DISABLED,    ## No interactuable (requisito no cumplido, etc.)
}


# ============================================================
# CONFIGURACIÓN
# ============================================================

## Tamaño del slot — cambia el custom_minimum_size automáticamente
@export var slot_size: Vector2 = UITokens.SLOT_SIZE

## Si true, acepta drops de drag & drop
@export var accept_drops: bool = true

## ID del slot de equipamiento (head, body, weapon...). Vacío en slots de inventario.
@export var equipment_slot_id: String = ""


# ============================================================
# REFERENCIAS A NODOS
# ============================================================

@onready var icon_rect:       TextureRect = $MarginContainer/Icon
@onready var quantity_label:  Label       = $MarginContainer/QuantityLabel
@onready var slot_label:      Label       = $SlotLabel   # label del tipo de slot (Head, Weapon...)
@onready var overlay:         Control     = $Overlay     # para highlight, estado, etc.


# ============================================================
# ESTADO INTERNO
# ============================================================

var _state: SlotState = SlotState.EMPTY
var _item_instance: ItemInstance = null
var _item_id: String = ""


# ============================================================
# INICIALIZACIÓN
# ============================================================

func _ready() -> void:
	custom_minimum_size = slot_size

	# Label del tipo de slot (solo en panel de equipamiento)
	if slot_label:
		slot_label.visible = not equipment_slot_id.is_empty()
		if not equipment_slot_id.is_empty():
			slot_label.text = equipment_slot_id.capitalize()
			slot_label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_XS)
			slot_label.add_theme_color_override("font_color", UITokens.COLOR_TEXT_MUTED)

	_apply_state_style()


# ============================================================
# API PÚBLICA
# ============================================================

## Asigna un ItemInstance al slot
func set_item(instance: ItemInstance) -> void:
	_item_instance = instance
	_item_id = instance.definition.id if instance and instance.definition else ""

	if instance and instance.definition:
		icon_rect.texture = instance.definition.icon
		icon_rect.visible = true

		# Cantidad solo si > 1 y stackable
		if instance.quantity > 1:
			quantity_label.text = str(instance.quantity)
			quantity_label.visible = true
		else:
			quantity_label.visible = false

		_set_state(SlotState.OCCUPIED)
	else:
		clear()


## Vacía el slot
func clear() -> void:
	_item_instance = null
	_item_id = ""
	icon_rect.texture = null
	icon_rect.visible = false
	quantity_label.visible = false
	_set_state(SlotState.EMPTY)


## Fuerza un estado visual sin cambiar el item
func set_state(new_state: SlotState) -> void:
	_set_state(new_state)


## Obtiene el item_id del item actual (vacío si no hay ninguno)
func get_item_id() -> String:
	return _item_id


## Obtiene el ItemInstance actual (null si vacío)
func get_item_instance() -> ItemInstance:
	return _item_instance


## ¿Está vacío?
func is_empty() -> bool:
	return _state == SlotState.EMPTY or _item_instance == null


# ============================================================
# ESTILOS DE ESTADO
# ============================================================

func _set_state(new_state: SlotState) -> void:
	_state = new_state
	_apply_state_style()


func _apply_state_style() -> void:
	var bg_color: Color
	var border_color: Color
	var border_width: int = UITokens.BORDER_WIDTH

	match _state:
		SlotState.EMPTY:
			bg_color     = UITokens.COLOR_SLOT_EMPTY
			border_color = UITokens.COLOR_SLOT_EMPTY_BORDER

		SlotState.OCCUPIED:
			bg_color     = UITokens.COLOR_SLOT_OCCUPIED
			border_color = UITokens.COLOR_SLOT_OCCUPIED_BORDER

		SlotState.SELECTED:
			bg_color     = UITokens.COLOR_SLOT_SELECTED
			border_color = UITokens.COLOR_SLOT_SELECTED_BORDER
			border_width = UITokens.BORDER_WIDTH_FOCUS

		SlotState.EQUIPPED:
			bg_color     = UITokens.COLOR_SLOT_EQUIPPED
			border_color = UITokens.COLOR_SLOT_EQUIPPED_BORDER
			border_width = UITokens.BORDER_WIDTH_FOCUS

		SlotState.HIGHLIGHTED:
			bg_color     = UITokens.COLOR_SLOT_HOVER
			border_color = UITokens.COLOR_ACCENT_SOFT
			border_width = UITokens.BORDER_WIDTH_FOCUS

		SlotState.DISABLED:
			bg_color     = UITokens.COLOR_SLOT_EMPTY
			border_color = UITokens.COLOR_SLOT_EMPTY_BORDER
			modulate     = Color(1, 1, 1, UITokens.DISABLED_ALPHA)

	add_theme_stylebox_override("panel",
		UITokens.make_stylebox(bg_color, border_color, border_width, UITokens.BORDER_RADIUS_SM, UITokens.SPACE_XS)
	)

	# Restaurar opacidad si salimos de DISABLED
	if _state != SlotState.DISABLED:
		modulate = Color.WHITE


# ============================================================
# INPUT Y HOVER
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if _state == SlotState.DISABLED:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			slot_clicked.emit(self)
			accept_event()


func _mouse_entered() -> void:
	if _state == SlotState.DISABLED:
		return
	if _state == SlotState.OCCUPIED:
		_apply_hover_style()


func _mouse_exited() -> void:
	# Restaurar al estado previo (sin cambiar _state)
	_apply_state_style()


func _apply_hover_style() -> void:
	add_theme_stylebox_override("panel",
		UITokens.make_stylebox(
			UITokens.COLOR_SLOT_HOVER,
			UITokens.COLOR_SLOT_HOVER_BORDER,
			UITokens.BORDER_WIDTH,
			UITokens.BORDER_RADIUS_SM,
			UITokens.SPACE_XS
		)
	)


# ============================================================
# DRAG & DROP
# ============================================================

func _get_drag_data(_pos: Vector2) -> Variant:
	if _item_instance == null or _state == SlotState.DISABLED:
		return null

	# Preview visual del drag
	var preview := TextureRect.new()
	preview.texture = icon_rect.texture
	preview.custom_minimum_size = UITokens.ICON_SIZE_MD
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate = Color(1, 1, 1, 0.8)
	set_drag_preview(preview)

	return {
		"item_id": _item_id,
		"source_slot": self,
		"source": equipment_slot_id if not equipment_slot_id.is_empty() else "inventory"
	}


func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if not accept_drops:
		return false
	if not data is Dictionary:
		return false
	return data.has("item_id")


func _drop_data(_pos: Vector2, data: Variant) -> void:
	slot_drop_received.emit(self, data.get("item_id", ""))
