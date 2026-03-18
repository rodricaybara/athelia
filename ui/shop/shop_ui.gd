extends CanvasLayer
class_name ShopUI

## ShopUI - Interfaz de tienda 100% pasiva
## Responsabilidades:
## - Renderizar snapshots recibidos
## - Emitir intenciones del jugador vía EventBus
## - Mostrar feedback visual
## NO hace:
## - Calcular precios
## - Validar reglas
## - Mutar estado del juego

## Referencias UI
@onready var shop_panel = %ShopPanel
@onready var shop_name_label = %ShopNameLabel
@onready var player_gold_label = %PlayerGoldLabel
@onready var shop_gold_label = %ShopGoldLabel
@onready var shop_slots_label = %ShopSlotsLabel

@onready var shop_items_container = %ShopItemsContainer
@onready var player_items_container = %PlayerItemsContainer

@onready var close_button = %CloseButton
@onready var feedback_label = %FeedbackLabel

## Estado
var current_shop_id: String = ""
var current_entity_id: String = "player"
var is_locked: bool = false

## Prefab para slots
var item_slot_scene = preload("res://ui/shop/shop_item_slot.tscn")


func _ready():
	# Ocultar inicialmente
	visible = false
	
	# Conectar botones
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# Conectar eventos del sistema
	EventBus.shop_opened.connect(_on_shop_opened)
	EventBus.shop_closed.connect(_on_shop_closed)
	EventBus.shop_trade_success.connect(_on_trade_success)
	EventBus.shop_trade_failed.connect(_on_trade_failed)
	EventBus.shop_snapshot_updated.connect(_on_snapshot_updated)
	
	print("[ShopUI] Initialized")


## ============================================
## APERTURA/CIERRE
## ============================================

## Solicita abrir una tienda
func open_shop(shop_id: String, entity_id: String = "player"):
	current_shop_id = shop_id
	current_entity_id = entity_id
	
	EventBus.shop_open_requested.emit(shop_id, entity_id)


## Solicita cerrar la tienda
func close_shop():
	if current_shop_id.is_empty():
		return
	
	EventBus.shop_close_requested.emit(current_shop_id)


## ============================================
## APERTURA DIRECTA (llamada desde SceneOrchestrator)
## ============================================

## Muestra la tienda con un snapshot ya calculado.
## Usado cuando el overlay se crea DESPUÉS de que EconomySystem
## ya procesó shop_open_requested — evita el problema de timing.
func show_shop_direct(shop_id: String, entity_id: String, snapshot: Dictionary) -> void:
	current_shop_id = shop_id
	current_entity_id = entity_id
	is_locked = false
	visible = true
	_render_snapshot(snapshot)
	print("[ShopUI] Shown via direct call for: %s" % shop_id)


## ============================================
## CALLBACKS DE EVENTOS
## ============================================

## Tienda abierta - renderizar snapshot
func _on_shop_opened(shop_id: String, snapshot: Dictionary):
	if shop_id != current_shop_id:
		return
	
	print("[ShopUI] Shop opened: %s" % shop_id)
	
	visible = true
	is_locked = false
	# ⭐ Deshabilitar input del player
	#_set_player_input_enabled(false)
	_render_snapshot(snapshot)


## Tienda cerrada - ocultar UI
func _on_shop_closed(shop_id: String):
	if shop_id != current_shop_id:
		return
	
	print("[ShopUI] Shop closed: %s" % shop_id)
	
	visible = false
	current_shop_id = ""
	_clear_items()


## Transacción exitosa - actualizar con nuevo snapshot
func _on_trade_success(_trade_type: String, shop_id: String, item_id: String, quantity: int, new_snapshot: Dictionary):
	if shop_id != current_shop_id:
		return
	
	print("[ShopUI] Trade success: %s x%d" % [item_id, quantity])
	
	is_locked = false
	_render_snapshot(new_snapshot)
	_show_feedback("✓ Transaction successful", Color.GREEN)


## Transacción fallida - mostrar error
func _on_trade_failed(shop_id: String, reason_code: String, context: String):
	if shop_id != current_shop_id:
		return
	
	print("[ShopUI] Trade failed: %s - %s" % [reason_code, context])
	
	is_locked = false
	
	var message = _get_error_message(reason_code)
	_show_feedback("✗ " + message, Color.RED)


## Snapshot actualizado (sin transacción)
func _on_snapshot_updated(shop_id: String, snapshot: Dictionary):
	if shop_id != current_shop_id:
		return
	
	_render_snapshot(snapshot)


## ============================================
## RENDERIZADO
## ============================================

## Renderiza un snapshot completo
func _render_snapshot(snapshot: Dictionary):
	# Header
	if shop_name_label:
		shop_name_label.text = snapshot.get("shop_name", "Shop")
	
	if player_gold_label:
		player_gold_label.text = "Gold: %d" % snapshot.get("player_gold", 0)
	
	if shop_gold_label:
		shop_gold_label.text = "Shop: %d gold" % snapshot.get("shop_gold", 0)
	
	if shop_slots_label:
		var used = snapshot.get("shop_slots_used", 0)
		var max_slots = snapshot.get("shop_slots_max", 0)
		shop_slots_label.text = "Slots: %d/%d" % [used, max_slots]
	
	# Items en venta
	_render_shop_items(snapshot.get("items_for_sale", []))
	
	# Items vendibles del jugador
	_render_player_items(snapshot.get("player_items_sellable", []))


## Renderiza items de la tienda
func _render_shop_items(items: Array):
	_clear_container(shop_items_container)
	
	for item_data in items:
		var slot = item_slot_scene.instantiate()
		shop_items_container.add_child(slot)
		
		slot.setup(item_data, true)  # true = modo compra
		slot.item_clicked.connect(_on_shop_item_clicked)


## Renderiza items del jugador
func _render_player_items(items: Array):
	print("[ShopUI] Rendering player items: ", items.size())
	print("[ShopUI] Container visible:", player_items_container.visible)
	print("[ShopUI] Container min size:", player_items_container.custom_minimum_size)
	
	_clear_container(player_items_container)
	
	for item_data in items:
		var slot = item_slot_scene.instantiate()
		player_items_container.add_child(slot)
		print("  Slot instance:", slot)
		print("  Slot min size:", slot.custom_minimum_size)
		slot.setup(item_data, false)  # false = modo venta
		slot.item_clicked.connect(_on_player_item_clicked)


## ============================================
## INTERACCIÓN
## ============================================

## Click en item de la tienda (comprar)
func _on_shop_item_clicked(item_id: String, _is_buy: bool):
	if is_locked:
		return
	
	print("[ShopUI] Buy requested: %s" % item_id)
	
	is_locked = true
	EventBus.shop_buy_requested.emit(current_shop_id, item_id, 1)


## Click en item del jugador (vender)
func _on_player_item_clicked(item_id: String, _is_buy: bool):
	if is_locked:
		return
	
	print("[ShopUI] Sell requested: %s" % item_id)
	
	is_locked = true
	EventBus.shop_sell_requested.emit(current_shop_id, item_id, 1)


## Click en cerrar
func _on_close_pressed():
	close_shop()


## ============================================
## UTILIDADES
## ============================================

## Limpia un contenedor de items
func _clear_container(container: Node):
	if not container:
		return
	
	for child in container.get_children():
		child.queue_free()


## Limpia todos los items
func _clear_items():
	_clear_container(shop_items_container)
	_clear_container(player_items_container)


## Muestra mensaje de feedback temporal
func _show_feedback(message: String, color: Color):
	if not feedback_label:
		return
	
	feedback_label.text = message
	feedback_label.modulate = color
	feedback_label.visible = true
	
	# Ocultar después de 3 segundos
	await get_tree().create_timer(3.0).timeout
	
	if feedback_label:
		feedback_label.visible = false


## Traduce código de error a mensaje legible
func _get_error_message(reason_code: String) -> String:
	match reason_code:
		"NO_MONEY":
			return "Not enough gold"
		"NO_STOCK":
			return "Item out of stock"
		"NO_SLOTS":
			return "Shop inventory full"
		"NO_BUDGET":
			return "Shop cannot afford this"
		"PLAYER_NO_ITEM":
			return "You don't have this item"
		"INVALID_ITEM":
			return "Invalid item"
		"TRANSACTION_FAILED":
			return "Transaction failed"
		_:
			return "Error: " + reason_code


## ⭐ NUEVO: Manejar ESC para cerrar tienda
func _unhandled_input(event):
	if not visible:
		return
	
	if event.is_action_pressed("ui_cancel"):
		close_shop()
		get_viewport().set_input_as_handled()
