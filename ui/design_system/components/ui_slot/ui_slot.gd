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
##   var slot: UISlot = preload("res://ui/design_system/components/ui_slot/ui_slot.tscn").instantiate()
##   slot.set_item(item_instance)
##   slot.slot_clicked.connect(_on_slot_clicked)
##
## Spike 18 (Fase 2) — primer consumidor real (inventario). Cambios:
##   - Rutas de nodos corregidas (nombres únicos %): antes apuntaban a una
##     jerarquía que la escena no tenía.
##   - Hover conectado (los métodos existían, las señales no).
##   - Cantidad, etiqueta de slot y marca de «equipado» van en Overlay y no
##     alteran el tamaño del slot (64×64 fijo).
##   - Banderas visuales independientes del estado: selected, equipped_mark,
##     hovered, overflow. set_state() se mantiene por compatibilidad.
##   - border_color_override: la View pasa el color (p. ej. por categoría).
##   - Ítem sin icono: silueta genérica (icon_item_placeholder.png) teñida.
##   - draggable / accept_drops / drop_source_filter: quién arrastra y qué acepta.
##   - slot_clicked se emite al SOLTAR el botón dentro del slot (no al pulsar):
##     así un arrastre nunca dispara la selección ni un repintado que destruya
##     el slot que se está arrastrando.
##   - Texto de la etiqueta: lo pone la View ya traducido (slot_label_text).
##   - set_definition(): para slots que solo conocen la ItemDefinition (equipo).
##
## Pendiente registrado: DISABLED usa modulate (atenúa también el contenido).


# ============================================================
# SEÑALES
# ============================================================

## Emitida al hacer click (pulsar y soltar dentro) en el slot, ocupado o vacío
signal slot_clicked(slot: UISlot)

## Emitida al soltar un drag sobre este slot
signal slot_drop_received(slot: UISlot, source_item_id: String)

## Spike 19: igual que slot_drop_received, pero con la entidad dueña del slot de
## origen (owner_id del slot arrastrado; "" si no lo declara). Se emite justo
## después de la anterior, que sigue existiendo para no cambiar el inventario.
signal slot_item_dropped(slot: UISlot, source_item_id: String, from_owner_id: String)


# ============================================================
# ESTADOS
# ============================================================

enum SlotState {
	EMPTY,       ## Sin item
	OCCUPIED,    ## Tiene item, no seleccionado
	SELECTED,    ## Seleccionado activamente (equivale a set_selected(true))
	EQUIPPED,    ## Colores de «equipado» (compatibilidad; la marca E es aparte)
	HIGHLIGHTED, ## Slot de comparación activo
	DISABLED,    ## No interactuable (requisito no cumplido, etc.)
}

const PLACEHOLDER_ICON_PATH: String = "res://ui/design_system/assets/icons/icon_item_placeholder.png"
const DASH_LENGTH: float = 5.0
const DASH_GAP: float = 4.0


# ============================================================
# CONFIGURACIÓN
# ============================================================

## Tamaño del slot — cambia el custom_minimum_size automáticamente
@export var slot_size: Vector2 = UITokens.SLOT_SIZE

## Si true, acepta drops de drag & drop
@export var accept_drops: bool = true

## Si true, el slot ocupado se puede arrastrar. Falso en slots de equipo
## (desequipar es un clic, no un arrastre).
@export var draggable: bool = true

## Si no está vacío, solo acepta drops cuyo `source` coincida. Los slots de
## equipo ponen "inventory": solo se equipa arrastrando desde la mochila.
@export var drop_source_filter: String = ""

## ID del slot de equipamiento (head, body, weapon...). Vacío en slots de inventario.
@export var equipment_slot_id: String = ""

## Spike 19: id opaco de la entidad dueña de este slot (la View lo pone; el
## componente nunca lo interpreta ni accede a sistemas). Viaja en el payload del
## arrastre para que quien reciba el drop sepa de dónde viene. Vacío = sin dueño.
@export var owner_id: String = ""

## Spike 19b: si true, rechaza drops cuyo owner_id coincida con el suyo (no se
## puede soltar en la propia mochila). Apagado por defecto.
@export var drop_exclude_owner: bool = false

## Spike 19b: si true, durante un arrastre el slot resalta su borde cuando
## aceptaría el drop. Apagado por defecto.
@export var highlight_drop_targets: bool = false

## Color del borde en reposo (Color.TRANSPARENT = el del estado). Lo pasa la View.
@export var border_color_override: Color = Color.TRANSPARENT:
	set(value):
		border_color_override = value
		_apply_state_style()

## Texto de la etiqueta del slot, ya traducido. Vacío = sin etiqueta.
@export var slot_label_text: String = "":
	set(value):
		slot_label_text = value
		_refresh_slot_label()

## Texto de la marca de «equipado», ya traducido
@export var equipped_mark_text: String = "E":
	set(value):
		equipped_mark_text = value
		if is_node_ready():
			equipped_mark.text = value


# ============================================================
# REFERENCIAS A NODOS
# ============================================================

@onready var icon_rect:       TextureRect = %Icon
@onready var quantity_label:  Label       = %QuantityLabel
@onready var slot_label:      Label       = %SlotLabel
@onready var equipped_mark:   Label       = %EquippedMark
@onready var overlay:         Control     = %Overlay


# ============================================================
# ESTADO INTERNO
# ============================================================

var _state: SlotState = SlotState.EMPTY
var _item_instance: ItemInstance = null
var _item_id: String = ""

var _selected: bool = false
var _equipped_mark: bool = false
var _hovered: bool = false
var _overflow: bool = false
var _pressed: bool = false
var _drop_hint: bool = false

static var _placeholder_texture: Texture2D = null
static var _warned_missing_placeholder: bool = false


# ============================================================
# INICIALIZACIÓN
# ============================================================

func _ready() -> void:
	custom_minimum_size = slot_size

	mouse_entered.connect(_mouse_entered)
	mouse_exited.connect(_mouse_exited)

	quantity_label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_SM)
	quantity_label.add_theme_color_override("font_color", UITokens.COLOR_TEXT)
	quantity_label.add_theme_color_override("font_outline_color", UITokens.COLOR_TEXT_OUTLINE)
	quantity_label.add_theme_constant_override("outline_size", 3)

	slot_label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_XS)
	slot_label.add_theme_color_override("font_color", UITokens.COLOR_TEXT_MUTED)
	slot_label.add_theme_color_override("font_outline_color", UITokens.COLOR_TEXT_OUTLINE)
	slot_label.add_theme_constant_override("outline_size", 3)

	equipped_mark.text = equipped_mark_text
	equipped_mark.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_XS)
	equipped_mark.add_theme_color_override("font_color", UITokens.COLOR_TEXT)
	equipped_mark.add_theme_stylebox_override("normal", UITokens.make_stylebox(
		UITokens.COLOR_SLOT_EQUIPPED, UITokens.COLOR_SLOT_EQUIPPED_BORDER,
		UITokens.BORDER_WIDTH, UITokens.BORDER_RADIUS_SM, 0))
	equipped_mark.visible = _equipped_mark

	_refresh_slot_label()
	_apply_state_style()


# ============================================================
# API PÚBLICA
# ============================================================

## Asigna un ItemInstance al slot
func set_item(instance: ItemInstance) -> void:
	if instance == null or instance.definition == null:
		clear()
		return
	_item_instance = instance
	_show_definition(instance.definition, instance.quantity)


## Muestra una definición sin instancia (slots de equipo: la View solo conoce
## la ItemDefinition de lo equipado). get_item_instance() devuelve null.
func set_definition(definition: ItemDefinition, quantity: int = 1) -> void:
	if definition == null:
		clear()
		return
	_item_instance = null
	_show_definition(definition, quantity)


func _show_definition(definition: ItemDefinition, quantity: int) -> void:
	_item_id = definition.id

	var icon: Texture2D = definition.icon
	if icon != null:
		icon_rect.texture = icon
		icon_rect.modulate = Color.WHITE
	else:
		# Sin icono: silueta genérica teñida en el icono, no en el contenedor
		icon_rect.texture = _get_placeholder()
		icon_rect.modulate = UITokens.COLOR_TEXT_MUTED
	icon_rect.visible = icon_rect.texture != null

	# Cantidad solo si > 1
	if quantity > 1:
		quantity_label.text = str(quantity)
		quantity_label.visible = true
	else:
		quantity_label.visible = false

	_set_state(SlotState.OCCUPIED)


## Vacía el slot (también apaga marca de equipado y desbordamiento)
func clear() -> void:
	_item_instance = null
	_item_id = ""
	icon_rect.texture = null
	icon_rect.modulate = Color.WHITE
	icon_rect.visible = false
	quantity_label.visible = false
	_selected = false
	set_equipped_mark(false)
	set_overflow(false)
	_set_state(SlotState.EMPTY)


## Fuerza un estado visual sin cambiar el item (compatibilidad)
func set_state(new_state: SlotState) -> void:
	_set_state(new_state)


## Resalta el slot como seleccionado (independiente del estado)
func set_selected(value: bool) -> void:
	if _selected == value:
		return
	_selected = value
	_apply_state_style()


## Muestra la marca de «equipado» en la esquina (el ítem está en un slot de equipo)
func set_equipped_mark(value: bool) -> void:
	_equipped_mark = value
	if is_node_ready():
		equipped_mark.visible = value


## Marca el slot como «por encima de la capacidad»: borde discontinuo de peligro
func set_overflow(value: bool) -> void:
	if _overflow == value:
		return
	_overflow = value
	queue_redraw()


## Obtiene el item_id del item actual (vacío si no hay ninguno)
func get_item_id() -> String:
	return _item_id


## Obtiene el ItemInstance actual (null si vacío)
func get_item_instance() -> ItemInstance:
	return _item_instance


## ¿Está vacío?
func is_empty() -> bool:
	return _item_id.is_empty()


func is_selected() -> bool:
	return _selected


# ============================================================
# ESTILOS
# ============================================================

func _set_state(new_state: SlotState) -> void:
	_state = new_state
	_apply_state_style()


func _refresh_slot_label() -> void:
	if not is_node_ready():
		return
	slot_label.text = slot_label_text
	slot_label.visible = not slot_label_text.is_empty()


func _apply_state_style() -> void:
	if not is_node_ready():
		return

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
			if border_color_override.a > 0.0:
				border_color = border_color_override

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

	# Las banderas pesan más que el estado base: seleccionado > hover
	if _selected:
		bg_color     = UITokens.COLOR_SLOT_SELECTED
		border_color = UITokens.COLOR_SLOT_SELECTED_BORDER
		border_width = UITokens.BORDER_WIDTH_FOCUS
	elif _hovered and _state != SlotState.EMPTY and _state != SlotState.DISABLED:
		bg_color     = UITokens.COLOR_SLOT_HOVER
		border_color = UITokens.COLOR_SLOT_HOVER_BORDER

	# Spike 19b: destino válido de un arrastre en curso
	if _drop_hint and not _selected:
		border_color = UITokens.COLOR_ACCENT
		border_width = UITokens.BORDER_WIDTH_FOCUS

	# Padding 0: el margen interior lo da el nodo Content, y Overlay debe
	# cubrir el slot entero para colocar cantidad, etiqueta y marca.
	add_theme_stylebox_override("panel",
		UITokens.make_stylebox(bg_color, border_color, border_width, UITokens.BORDER_RADIUS_SM, 0)
	)

	modulate = Color(1, 1, 1, UITokens.DISABLED_ALPHA) if _state == SlotState.DISABLED else Color.WHITE


func _draw() -> void:
	if not _overflow:
		return
	# Borde discontinuo (StyleBoxFlat no sabe dibujarlos)
	var rect := Rect2(Vector2.ONE, size - Vector2(2, 2))
	var color: Color = UITokens.COLOR_DANGER_SOFT
	var width: float = float(UITokens.BORDER_WIDTH_FOCUS)
	_dashed_line(rect.position, Vector2(rect.end.x, rect.position.y), color, width)
	_dashed_line(Vector2(rect.end.x, rect.position.y), rect.end, color, width)
	_dashed_line(rect.end, Vector2(rect.position.x, rect.end.y), color, width)
	_dashed_line(Vector2(rect.position.x, rect.end.y), rect.position, color, width)


func _dashed_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var total: float = from.distance_to(to)
	if total <= 0.0:
		return
	var direction: Vector2 = (to - from) / total
	var distance: float = 0.0
	while distance < total:
		var segment_end: float = minf(distance + DASH_LENGTH, total)
		draw_line(from + direction * distance, from + direction * segment_end, color, width)
		distance += DASH_LENGTH + DASH_GAP


static func _get_placeholder() -> Texture2D:
	if _placeholder_texture == null and ResourceLoader.exists(PLACEHOLDER_ICON_PATH):
		_placeholder_texture = load(PLACEHOLDER_ICON_PATH) as Texture2D
	if _placeholder_texture == null and not _warned_missing_placeholder:
		_warned_missing_placeholder = true
		push_warning("UISlot: falta el icono genérico '%s' — los ítems sin icono se verán vacíos." % PLACEHOLDER_ICON_PATH)
	return _placeholder_texture


# ============================================================
# INPUT Y HOVER
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if _state == SlotState.DISABLED:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
			accept_event()
		else:
			# Click = pulsar y soltar dentro. Si hubo arrastre, el botón se suelta
			# sobre otro control y aquí no llega (o llega con _pressed = false).
			var was_pressed: bool = _pressed
			_pressed = false
			if was_pressed and Rect2(Vector2.ZERO, size).has_point(event.position):
				slot_clicked.emit(self)
			accept_event()


func _mouse_entered() -> void:
	_hovered = true
	_apply_state_style()


func _mouse_exited() -> void:
	_hovered = false
	_apply_state_style()


## Spike 19b: resalta los destinos válidos mientras dura un arrastre
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		if highlight_drop_targets and is_visible_in_tree():
			var data: Variant = get_viewport().gui_get_drag_data()
			_drop_hint = data != null and _can_drop_data(Vector2.ZERO, data)
			_apply_state_style()
	elif what == NOTIFICATION_DRAG_END:
		if _drop_hint:
			_drop_hint = false
			_apply_state_style()


# ============================================================
# DRAG & DROP
# ============================================================

func _get_drag_data(_pos: Vector2) -> Variant:
	if not draggable or _item_id.is_empty() or _state == SlotState.DISABLED:
		return null

	_pressed = false

	# Preview visual del drag
	var preview := TextureRect.new()
	preview.texture = icon_rect.texture
	preview.custom_minimum_size = UITokens.ICON_SIZE_MD
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate = Color(icon_rect.modulate.r, icon_rect.modulate.g, icon_rect.modulate.b, 0.8)
	set_drag_preview(preview)

	return {
		"item_id": _item_id,
		"source_slot": self,
		"source": equipment_slot_id if not equipment_slot_id.is_empty() else "inventory",
		"owner_id": owner_id
	}


func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if not accept_drops:
		return false
	if not data is Dictionary:
		return false
	var payload: Dictionary = data
	if not payload.has("item_id"):
		return false
	if not drop_source_filter.is_empty() and str(payload.get("source", "")) != drop_source_filter:
		return false
	if drop_exclude_owner and not owner_id.is_empty() and str(payload.get("owner_id", "")) == owner_id:
		return false
	return true


func _drop_data(_pos: Vector2, data: Variant) -> void:
	var payload: Dictionary = data
	var dropped_item_id: String = str(payload.get("item_id", ""))
	slot_drop_received.emit(self, dropped_item_id)
	slot_item_dropped.emit(self, dropped_item_id, str(payload.get("owner_id", "")))
