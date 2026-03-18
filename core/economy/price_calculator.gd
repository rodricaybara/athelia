class_name PriceCalculator
extends RefCounted

## PriceCalculator - Cálculo puro de precios sin estado
## Responsabilidades:
## - Calcular precio de compra (Tienda → Jugador)
## - Calcular precio de venta (Jugador → Tienda)
## - NO acceder a sistemas
## - Funciones puras (mismo input = mismo output)

## Calcula el precio de COMPRA (Tienda → Jugador)
## El jugador PAGA este precio
static func calculate_buy_price(base_value: int, shop_factor: float) -> int:
	if base_value <= 0:
		push_warning("[PriceCalculator] base_value <= 0: %d" % base_value)
		return 0
	
	var price = int(base_value * shop_factor)
	return max(1, price)  # Mínimo 1 oro


## Calcula el precio de VENTA (Jugador → Tienda)
## El jugador RECIBE este precio
static func calculate_sell_price(base_value: int, shop_factor: float) -> int:
	if base_value <= 0:
		push_warning("[PriceCalculator] base_value <= 0: %d" % base_value)
		return 0
	
	var price = int(base_value * shop_factor)
	return max(1, price)  # Mínimo 1 oro


## Calcula el precio total para una cantidad
static func calculate_total_price(unit_price: int, quantity: int) -> int:
	return unit_price * quantity


## Debug: imprime breakdown de precio
static func print_price_breakdown(base_value: int, factor: float, quantity: int, transaction_type: String):
	var unit_price = 0
	if transaction_type == "buy":
		unit_price = calculate_buy_price(base_value, factor)
	else:
		unit_price = calculate_sell_price(base_value, factor)
	
	var total = calculate_total_price(unit_price, quantity)
	
	print("\n[PriceCalculator] %s breakdown:" % transaction_type)
	print("  Base value: %d" % base_value)
	print("  Factor: %.2f" % factor)
	print("  Unit price: %d" % unit_price)
	print("  Quantity: %d" % quantity)
	print("  Total: %d gold" % total)
