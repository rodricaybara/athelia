class_name ShopViewModel
extends Node

## ShopViewModel
## Gestiona el estado de la pantalla de tienda.
##
## Responsabilidades:
##   - Almacenar el snapshot actual de la tienda
##   - Gestionar el flag is_locked (acción en vuelo)
##   - Traducir códigos de error a claves de localización
##   - Emitir intenciones al EventBus (comprar, vender, cerrar)
##   - Escuchar resultados del sistema y notificar a la View
##
## NO hace:
##   - Calcular precios ni validar reglas
##   - Renderizar nada
##   - Instanciar nodos
##
## Spike 16: el mensaje de éxito distingue compra de venta y muestra el nombre
## visible del objeto (antes decía siempre "Comprado" y mostraba el id interno).
## Spike 16b: trade_type "loan" (objeto de préstamo tomado de la tienda) y
## código de error LOAN_ITEM (intento de vender un préstamo).


# ============================================
# ENUM
# ============================================

enum ShopState {
	HIDDEN,    ## Pantalla cerrada
	BROWSING,  ## Tienda abierta, sin acción pendiente
	WAITING,   ## Acción emitida, esperando respuesta del sistema
}


# ============================================
# SEÑAL HACIA LA VIEW
# ============================================

## Razones:
##   "opened"          → renderizar snapshot completo
##   "snapshot"        → re-renderizar (tras transacción o actualización)
##   "waiting"         → bloquear botones
##   "trade_success"   → desbloquear + mostrar feedback positivo
##   "trade_failed"    → desbloquear + mostrar feedback de error
##   "closed"          → ocultar pantalla
signal changed(reason: String)


# ============================================
# ESTADO PÚBLICO
# ============================================

var state: ShopState = ShopState.HIDDEN

var shop_id:    String = ""
var entity_id:  String = "player"

## Snapshot completo de la tienda — listo para renderizar
var snapshot: Dictionary = {}

## Feedback del último resultado
var feedback_message: String = ""
var feedback_is_error: bool = false


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	EventBus.shop_trade_success.connect(_on_trade_success)
	EventBus.shop_trade_failed.connect(_on_trade_failed)
	EventBus.shop_snapshot_updated.connect(_on_snapshot_updated)
	print("[ShopVM] Ready")


# ============================================
# APERTURA (llamada desde SceneOrchestrator vía la View)
# ============================================

func init_with_snapshot(p_shop_id: String, p_entity_id: String, p_snapshot: Dictionary) -> void:
	shop_id   = p_shop_id
	entity_id = p_entity_id
	snapshot  = p_snapshot
	state     = ShopState.BROWSING
	feedback_message  = ""
	feedback_is_error = false
	changed.emit("opened")


# ============================================
# INTENCIONES
# ============================================

func request_buy(item_id: String) -> void:
	if state != ShopState.BROWSING:
		return
	state = ShopState.WAITING
	changed.emit("waiting")
	EventBus.shop_buy_requested.emit(shop_id, item_id, 1)


func request_sell(item_id: String) -> void:
	if state != ShopState.BROWSING:
		return
	state = ShopState.WAITING
	changed.emit("waiting")
	EventBus.shop_sell_requested.emit(shop_id, item_id, 1)


func request_close() -> void:
	state = ShopState.HIDDEN
	changed.emit("closed")
	EventBus.shop_close_requested.emit(shop_id)


# ============================================
# CALLBACKS DEL SISTEMA
# ============================================

func _on_trade_success(
		trade_type: String,
		p_shop_id: String,
		item_id: String,
		quantity: int,
		new_snapshot: Dictionary) -> void:

	if p_shop_id != shop_id:
		return

	# El nombre visible se busca en el snapshot ANTERIOR: tras vender el último
	# ejemplar, el objeto ya no aparece en la lista del jugador.
	var item_name: String = _find_display_name(item_id)

	snapshot          = new_snapshot
	feedback_message  = tr(_success_message_key(trade_type)) % [item_name, quantity]
	feedback_is_error = false
	state             = ShopState.BROWSING
	changed.emit("trade_success")


func _on_trade_failed(p_shop_id: String, reason_code: String, _context: String) -> void:
	if p_shop_id != shop_id:
		return

	feedback_message  = _error_message(reason_code)
	feedback_is_error = true
	state             = ShopState.BROWSING
	changed.emit("trade_failed")


func _on_snapshot_updated(p_shop_id: String, new_snapshot: Dictionary) -> void:
	if p_shop_id != shop_id:
		return
	snapshot = new_snapshot
	changed.emit("snapshot")


# ============================================
# HELPERS
# ============================================

## Clave de localización del mensaje de éxito según el tipo de transacción.
func _success_message_key(trade_type: String) -> String:
	match trade_type:
		"buy":  return "SHOP_TRADE_SUCCESS"
		"loan": return "SHOP_TRADE_LOANED"
		_:      return "SHOP_TRADE_SOLD"


## Nombre visible de un objeto según el snapshot actual; el id si no aparece.
func _find_display_name(item_id: String) -> String:
	for list_key: String in ["items_for_sale", "player_items_sellable"]:
		var entries: Array = snapshot.get(list_key, [])
		for entry: Dictionary in entries:
			if entry.get("item_id", "") == item_id:
				return entry.get("display_name", item_id) as String
	return item_id


func _error_message(reason_code: String) -> String:
	match reason_code:
		"NO_MONEY":        return tr("SHOP_ERROR_NO_MONEY")
		"NO_STOCK":        return tr("SHOP_ERROR_NO_STOCK")
		"NO_SLOTS":        return tr("SHOP_ERROR_NO_SLOTS")
		"NO_BUDGET":       return tr("SHOP_ERROR_NO_BUDGET")
		"PLAYER_NO_ITEM":  return tr("SHOP_ERROR_PLAYER_NO_ITEM")
		"INVALID_ITEM":    return tr("SHOP_ERROR_INVALID_ITEM")
		"LOAN_ITEM":       return tr("SHOP_ERROR_LOAN_ITEM")
		_:                 return tr("SHOP_ERROR_GENERIC") % reason_code
