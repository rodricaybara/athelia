class_name ShopItemSlot
extends UIPanel

## ShopItemSlot — fila de la lista de la tienda (Spike 16, ampliada en la 16b)
##
## Representa un objeto (de la tienda o del inventario del jugador) como una
## fila del Design System:
##   [icono opcional] [nombre] [xN] [precio] [botón Comprar/Vender/Tomar]
##
## Responsabilidades:
##   - Mostrar los datos de una entrada del snapshot
##   - Emitir item_clicked al pulsar el botón
##   - Reflejar el estado (asequible, disponible, ocupado, préstamo) con tokens
## NO hace:
##   - Validar reglas
##   - Calcular precios
##   - Ejecutar transacciones
##
## Uso: añadir al árbol PRIMERO y llamar a setup() DESPUÉS (los @onready deben
## estar resueltos). No usar await en la View.
##
## Icono: %IconRect permanece oculto mientras la entrada del snapshot no traiga
## la clave "icon" (un Texture2D). Cuando EconomySystem la incluya, la fila lo
## muestra sin más cambios.
##
## Préstamo (16b): si la entrada trae "is_loan" = true, el precio se muestra
## como "Préstamo". En la tienda el botón dice "Tomar"; en el inventario del
## jugador el botón de vender queda deshabilitado con su tooltip.


# ============================================
# SEÑAL
# ============================================

signal item_clicked(item_id: String, is_buy: bool)


# ============================================
# CONSTANTES DE LAYOUT
# ============================================

const ROW_HEIGHT: int = 40
## Suelo de anchura: garantiza que el nombre sea legible aunque el contenedor
## no expanda la fila.
const ROW_MIN_WIDTH: int = 380
const QUANTITY_COLUMN_WIDTH: int = 32
const PRICE_COLUMN_WIDTH: int = 96
const ACTION_COLUMN_WIDTH: int = 84


# ============================================
# DATOS
# ============================================

var item_id: String = ""
var display_name: String = ""
var quantity: int = 0
var price: int = 0
var is_buy_mode: bool = true  # true = comprar de la tienda, false = vender a la tienda

var is_affordable: bool = true
var is_available: bool = true
var is_loan: bool = false


# ============================================
# ESTADO INTERNO
# ============================================

var _busy: bool = false
var _hovered: bool = false


# ============================================
# NODOS
# ============================================

@onready var row: HBoxContainer = %Row
@onready var icon_rect: TextureRect = %IconRect
@onready var name_label: Label = %NameLabel
@onready var quantity_label: Label = %QuantityLabel
@onready var price_label: Label = %PriceLabel
@onready var action_button: UIButton = %ActionButton


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	# Antes de super: UIPanel aplica el estilo en su _ready() con este padding.
	padding = UITokens.SPACE_XS
	super._ready()

	_apply_static_style()

	action_button.pressed.connect(_on_action_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _apply_static_style() -> void:
	custom_minimum_size = Vector2(ROW_MIN_WIDTH, ROW_HEIGHT)
	row.add_theme_constant_override("separation", UITokens.SPACE_SM)

	icon_rect.custom_minimum_size = UITokens.ICON_SIZE_SM
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.visible = false

	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	quantity_label.custom_minimum_size.x = QUANTITY_COLUMN_WIDTH
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_label.custom_minimum_size.x = PRICE_COLUMN_WIDTH
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var labels: Array[Label] = [name_label, quantity_label, price_label]
	for label: Label in labels:
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_MD)

	action_button.set_size_variant(UIButton.Size.SM)
	action_button.custom_minimum_size.x = ACTION_COLUMN_WIDTH
	action_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER


# ============================================
# API PÚBLICA
# ============================================

## Configura la fila con una entrada del snapshot.
func setup(item_data: Dictionary, buy_mode: bool) -> void:
	item_id = item_data.get("item_id", "") as String
	display_name = item_data.get("display_name", "???") as String
	quantity = item_data.get("quantity", 0) as int
	price = item_data.get("unit_price", 0) as int
	is_loan = item_data.get("is_loan", false) as bool
	is_buy_mode = buy_mode

	if buy_mode:
		# Compra (tienda → jugador)
		is_affordable = item_data.get("is_affordable", false) as bool
		is_available = quantity > 0
	else:
		# Venta (jugador → tienda)
		is_affordable = item_data.get("shop_can_afford", false) as bool
		is_available = item_data.get("shop_has_slot", true) as bool

	var raw_icon: Variant = item_data.get("icon", null)
	if raw_icon is Texture2D:
		icon_rect.texture = raw_icon as Texture2D
		icon_rect.visible = true
	else:
		icon_rect.texture = null
		icon_rect.visible = false

	_refresh()


## Bloquea o desbloquea la acción mientras hay una transacción en vuelo.
## Se combina con el estado propio de la fila: nunca habilita lo que no se puede
## comprar o vender.
func set_busy(busy: bool) -> void:
	_busy = busy
	_refresh_button()


# ============================================
# RENDER
# ============================================

func _refresh() -> void:
	name_label.text = display_name
	tooltip_text = display_name

	quantity_label.text = (tr("SHOP_QUANTITY") % quantity) if quantity > 1 else ""

	if is_loan:
		price_label.text = tr("SHOP_PRICE_LOAN")
	else:
		var price_key: String = "SHOP_PRICE" if is_buy_mode else "SHOP_PRICE_SELL"
		price_label.text = tr(price_key) % price

	_apply_state_colors()
	_refresh_button()


func _apply_state_colors() -> void:
	var name_color: Color = UITokens.TEXT_PRIMARY
	var quantity_color: Color = UITokens.TEXT_SECONDARY
	var price_color: Color = UITokens.COLOR_INFO if is_loan else UITokens.COLOR_GOLD

	if not is_available:
		name_color = UITokens.TEXT_MUTED
		quantity_color = UITokens.TEXT_MUTED
		price_color = UITokens.TEXT_MUTED
	if not is_affordable:
		price_color = UITokens.COLOR_DANGER_SOFT

	name_label.add_theme_color_override("font_color", name_color)
	quantity_label.add_theme_color_override("font_color", quantity_color)
	price_label.add_theme_color_override("font_color", price_color)


func _refresh_button() -> void:
	# Un préstamo se puede tomar de la tienda, pero nunca vender.
	var is_locked_loan: bool = is_loan and not is_buy_mode
	var can_act: bool = is_affordable and is_available and not is_locked_loan

	if is_buy_mode:
		action_button.text = tr("SHOP_TAKE") if is_loan else tr("SHOP_BUY")
	else:
		action_button.text = tr("SHOP_SELL")
	action_button.disabled = _busy or not can_act

	if is_locked_loan:
		action_button.tooltip_text = tr("SHOP_TOOLTIP_LOAN")
	elif not is_affordable:
		action_button.tooltip_text = tr("SHOP_TOOLTIP_NO_GOLD") if is_buy_mode else tr("SHOP_TOOLTIP_NO_BUDGET")
	elif not is_available:
		action_button.tooltip_text = tr("SHOP_TOOLTIP_NO_STOCK") if is_buy_mode else tr("SHOP_TOOLTIP_NO_SLOTS")
	else:
		action_button.tooltip_text = ""


# ============================================
# HOVER
# ============================================

func _on_mouse_entered() -> void:
	_set_hover(true)


func _on_mouse_exited() -> void:
	# Al pasar sobre un hijo (el botón) Godot emite mouse_exited en la fila:
	# solo cuenta como salida si el ratón ya no está dentro de su rectángulo.
	if get_global_rect().has_point(get_global_mouse_position()):
		return
	_set_hover(false)


func _set_hover(on: bool) -> void:
	if _hovered == on:
		return
	_hovered = on
	if on:
		add_theme_stylebox_override("panel", UITokens.make_stylebox(
			UITokens.BG_RAISED,
			UITokens.BORDER_ACCENT,
			UITokens.BORDER_WIDTH,
			UITokens.BORDER_RADIUS_MD,
			_effective_padding()
		))
	else:
		_apply_style()


# ============================================
# INPUT
# ============================================

func _on_action_pressed() -> void:
	if item_id.is_empty():
		return
	item_clicked.emit(item_id, is_buy_mode)
