class_name ShopViewState
extends RefCounted

## ShopViewState - Snapshot del estado de una tienda para la UI
## Responsabilidades:
## - Contener TODO el estado necesario para renderizar la UI
## - NO contener lógica
## - Ser inmutable desde la UI

## Identificación de la tienda
var shop_id: String = ""
var shop_name: String = ""

## Estado económico
var player_gold: int = 0
var shop_gold: int = 0

## Capacidad
var shop_slots_used: int = 0
var shop_slots_max: int = 0

## Items disponibles para compra (Tienda → Jugador)
var items_for_sale: Array = []  # Array[ShopItemView]

## Items que el jugador puede vender (Jugador → Tienda)
var player_items_sellable: Array = []  # Array[PlayerItemView]

## Flags calculados
var flags: Dictionary = {
	"can_buy": true,
	"can_sell": true,
	"shop_has_money": true,
	"shop_has_slots": true
}


## Constructor vacío
func _init():
	pass


## Debug
func _to_string() -> String:
	return "ShopViewState(shop=%s, items=%d, player_gold=%d, shop_gold=%d)" % [
		shop_id,
		items_for_sale.size(),
		player_gold,
		shop_gold
	]
