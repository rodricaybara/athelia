extends CanvasLayer
class_name ShopUI

## ShopUI — View (Spike 16: rediseño con el Design System)
##
## Renderiza el estado expuesto por ShopViewModel en dos columnas:
##   izquierda = inventario del jugador, derecha = tienda.
## No accede a EconomySystem ni EventBus directamente.
## Todo input del jugador se delega al ViewModel.
##
## Contrato público (sin cambios): show_shop_direct(shop_id, entity_id, snapshot).
## El cierre lo gestiona EventBus.shop_closed → SceneOrchestrator.


# ============================================
# NODOS
# ============================================

@onready var shop_name_label: Label = %ShopNameLabel
@onready var close_button: UIButton = %CloseButton

@onready var player_title_label: Label = %PlayerTitleLabel
@onready var player_gold_label: Label = %PlayerGoldLabel
@onready var player_empty_label: Label = %PlayerEmptyLabel
@onready var player_items_scroll: ScrollContainer = %PlayerItemsScroll
@onready var player_items_container: Control = %PlayerItemsContainer

@onready var shop_title_label: Label = %ShopTitleLabel
@onready var shop_gold_label: Label = %ShopGoldLabel
@onready var shop_slots_label: Label = %ShopSlotsLabel
@onready var shop_empty_label: Label = %ShopEmptyLabel
@onready var shop_items_scroll: ScrollContainer = %ShopItemsScroll
@onready var shop_items_container: Control = %ShopItemsContainer

@onready var feedback_label: Label = %FeedbackLabel


# ============================================
# CONSTANTES
# ============================================

const ITEM_SLOT_SCENE := preload("res://ui/shop/shop_item_slot.tscn")

## Misma capa que el resto de overlays del SceneOrchestrator (por encima del HUD).
const OVERLAY_LAYER: int = 10
const FEEDBACK_DURATION: float = 3.0
## Altura reservada para el mensaje: el layout no salta al aparecer o desaparecer.
const FEEDBACK_MIN_HEIGHT: int = 28


# ============================================
# ESTADO INTERNO
# ============================================

var _vm: ShopViewModel = null
var _feedback_timer: SceneTreeTimer = null


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	layer = OVERLAY_LAYER
	visible = false

	_vm = ShopViewModel.new()
	_vm.name = "ViewModel"
	add_child(_vm)
	_vm.changed.connect(_on_vm_changed)

	_setup_static_text()
	_apply_style()

	close_button.pressed.connect(_on_close_pressed)

	feedback_label.text = ""
	print("[ShopUI] Ready")


func _setup_static_text() -> void:
	player_title_label.text = tr("SHOP_PLAYER_INVENTORY")
	shop_title_label.text = tr("SHOP_STOCK_TITLE")
	player_empty_label.text = tr("SHOP_EMPTY_INVENTORY")
	shop_empty_label.text = tr("SHOP_EMPTY_STOCK")
	close_button.text = tr("SHOP_CLOSE")


func _apply_style() -> void:
	shop_name_label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_TITLE)
	shop_name_label.add_theme_color_override("font_color", UITokens.TEXT_PRIMARY)
	shop_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var titles: Array[Label] = [player_title_label, shop_title_label]
	for label: Label in titles:
		label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_LG)
		label.add_theme_color_override("font_color", UITokens.TEXT_PRIMARY)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var gold_labels: Array[Label] = [player_gold_label, shop_gold_label]
	for label: Label in gold_labels:
		label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_MD)
		label.add_theme_color_override("font_color", UITokens.COLOR_GOLD)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	shop_slots_label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_MD)
	shop_slots_label.add_theme_color_override("font_color", UITokens.TEXT_SECONDARY)
	shop_slots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shop_slots_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var empty_labels: Array[Label] = [player_empty_label, shop_empty_label]
	for label: Label in empty_labels:
		label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_MD)
		label.add_theme_color_override("font_color", UITokens.TEXT_MUTED)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.visible = false

	feedback_label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_LG)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback_label.custom_minimum_size.y = FEEDBACK_MIN_HEIGHT

	close_button.set_variant(UIButton.Variant.SECONDARY)
	close_button.set_size_variant(UIButton.Size.SM)

	var scrolls: Array[ScrollContainer] = [player_items_scroll, shop_items_scroll]
	for scroll: ScrollContainer in scrolls:
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	player_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL


# ============================================
# API PÚBLICA (llamada desde SceneOrchestrator)
# ============================================

func show_shop_direct(shop_id: String, entity_id: String, snapshot: Dictionary) -> void:
	_vm.init_with_snapshot(shop_id, entity_id, snapshot)


# ============================================
# CALLBACK ÚNICO DEL VIEWMODEL
# ============================================

func _on_vm_changed(reason: String) -> void:
	match reason:
		"opened":
			_render_snapshot()
			visible = true
		"snapshot":
			_render_snapshot()
		"waiting":
			_set_all_busy(true)
		"trade_success":
			_render_snapshot()
			_show_feedback(_vm.feedback_message, false)
		"trade_failed":
			_set_all_busy(false)
			_show_feedback(_vm.feedback_message, true)
		"closed":
			_clear_containers()
			visible = false
		_:
			push_warning("[ShopUI] Razón desconocida: %s" % reason)


# ============================================
# RENDERS
# ============================================

func _render_snapshot() -> void:
	var s: Dictionary = _vm.snapshot

	var shop_name: String = s.get("shop_name", "")
	shop_name_label.text = shop_name if not shop_name.is_empty() else tr("SHOP_STOCK_TITLE")

	var player_gold: int = s.get("player_gold", 0)
	var shop_gold: int = s.get("shop_gold", 0)
	player_gold_label.text = tr("SHOP_PLAYER_GOLD") % player_gold
	shop_gold_label.text = tr("SHOP_SHOP_GOLD") % shop_gold

	var used: int = s.get("shop_slots_used", 0)
	var max_slots: int = s.get("shop_slots_max", 0)
	shop_slots_label.text = tr("SHOP_SLOTS") % [used, max_slots]

	_render_items(shop_items_container, shop_empty_label, s.get("items_for_sale", []), true)
	_render_items(player_items_container, player_empty_label, s.get("player_items_sellable", []), false)


func _render_items(container: Control, empty_label: Label, items: Array, buy_mode: bool) -> void:
	_clear_container(container)
	empty_label.visible = items.is_empty()

	for item_data: Dictionary in items:
		var slot: ShopItemSlot = ITEM_SLOT_SCENE.instantiate() as ShopItemSlot
		container.add_child(slot)
		slot.setup(item_data, buy_mode)
		if buy_mode:
			slot.item_clicked.connect(_on_shop_item_clicked)
		else:
			slot.item_clicked.connect(_on_player_item_clicked)


# ============================================
# INPUT DE LA VIEW → VIEWMODEL
# ============================================

func _on_shop_item_clicked(item_id: String, _is_buy: bool) -> void:
	_vm.request_buy(item_id)


func _on_player_item_clicked(item_id: String, _is_buy: bool) -> void:
	_vm.request_sell(item_id)


func _on_close_pressed() -> void:
	_vm.request_close()


# ============================================
# FEEDBACK TEMPORAL
# ============================================

func _show_feedback(message: String, is_error: bool) -> void:
	feedback_label.text = message
	var color: Color = UITokens.COLOR_DANGER_SOFT if is_error else UITokens.COLOR_SUCCESS_SOFT
	feedback_label.add_theme_color_override("font_color", color)

	# Cancelar timer anterior si existía
	if _feedback_timer and is_instance_valid(_feedback_timer):
		_feedback_timer.timeout.disconnect(_hide_feedback)

	_feedback_timer = get_tree().create_timer(FEEDBACK_DURATION)
	_feedback_timer.timeout.connect(_hide_feedback)


## Vacía el texto en lugar de ocultar el Label: su altura sigue reservada.
func _hide_feedback() -> void:
	if is_instance_valid(feedback_label):
		feedback_label.text = ""


# ============================================
# UTILIDADES
# ============================================

## Bloquea o desbloquea la acción de todas las filas mientras hay una
## transacción en vuelo. Cada fila combina esto con su propio estado.
func _set_all_busy(busy: bool) -> void:
	for container: Control in [shop_items_container, player_items_container]:
		for child: Node in container.get_children():
			if child is ShopItemSlot:
				(child as ShopItemSlot).set_busy(busy)


## remove_child antes de queue_free: la fila deja de ocupar sitio en el layout
## al instante, no al final del frame.
func _clear_container(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _clear_containers() -> void:
	_clear_container(shop_items_container)
	_clear_container(player_items_container)


# ============================================
# INPUT DE TECLADO
# ============================================

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_vm.request_close()
		get_viewport().set_input_as_handled()
