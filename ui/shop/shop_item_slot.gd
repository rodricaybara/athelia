extends PanelContainer
class_name ShopItemSlot

## ShopItemSlot - Representación visual de un item en la tienda
## Responsabilidades:
## - Mostrar información del item
## - Emitir señal cuando se clickea
## - Actualizar estado visual (affordable, disabled, etc.)
## NO hace:
## - Validar reglas
## - Calcular precios
## - Ejecutar transacciones

signal item_clicked(item_id: String, is_buy: bool)

## Datos del item
var item_id: String = ""
var display_name: String = ""
var quantity: int = 0
var price: int = 0
var is_buy_mode: bool = true  # true = comprar de tienda, false = vender a tienda

## Estado visual
var is_affordable: bool = true
var is_available: bool = true

## Referencias UI
@onready var name_label: Label = %NameLabel
@onready var price_label: Label = %PriceLabel
@onready var quantity_label: Label = %QuantityLabel
@onready var action_button: Button = %ActionButton
@onready var icon_rect: ColorRect = %IconRect


func _ready():
	if action_button:
		action_button.pressed.connect(_on_action_pressed)


## Configura el slot con datos del snapshot
func setup(item_data: Dictionary, buy_mode: bool):
	item_id = item_data.get("item_id", "")
	display_name = item_data.get("display_name", "???")
	quantity = item_data.get("quantity", 0)
	is_buy_mode = buy_mode
	
	if buy_mode:
		# Modo compra (tienda → jugador)
		price = item_data.get("unit_price", 0)
		is_affordable = item_data.get("is_affordable", false)
		is_available = quantity > 0
	else:
		# Modo venta (jugador → tienda)
		price = item_data.get("unit_price", 0)
		is_affordable = item_data.get("shop_can_afford", false)
		is_available = item_data.get("shop_has_slot", true)
	
	_update_display()


## Actualiza la visualización
func _update_display():
	if name_label:
		name_label.text = display_name
	
	if price_label:
		var prefix = "+" if not is_buy_mode else ""
		price_label.text = "%s%d gold" % [prefix, price]
		
		# Color según affordability
		if is_affordable:
			price_label.modulate = Color.WHITE
		else:
			price_label.modulate = Color.RED
	
	if quantity_label:
		quantity_label.text = "x%d" % quantity
		quantity_label.visible = quantity > 1
	
	if action_button:
		action_button.text = "BUY" if is_buy_mode else "SELL"
		action_button.disabled = not (is_affordable and is_available)
		
		# Tooltip si está disabled
		if not is_affordable:
			action_button.tooltip_text = "Not enough gold"
		elif not is_available:
			if is_buy_mode:
				action_button.tooltip_text = "Out of stock"
			else:
				action_button.tooltip_text = "Shop has no slots"
		else:
			action_button.tooltip_text = ""
	
	# Color del panel
	if not is_available:
		modulate = Color(0.5, 0.5, 0.5, 1.0)
	elif not is_affordable:
		modulate = Color(1.0, 0.8, 0.8, 1.0)
	else:
		modulate = Color.WHITE


func _on_action_pressed():
	if item_id.is_empty():
		return
	
	item_clicked.emit(item_id, is_buy_mode)
