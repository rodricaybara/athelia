extends CanvasLayer
class_name ShopUI

## ShopUI — View
##
## Renderiza el estado expuesto por ShopViewModel.
## No accede a EconomySystem ni EventBus directamente.
## Todo input del jugador se delega al ViewModel.


# ============================================
# NODOS
# ============================================

@onready var shop_name_label:       Label         = %ShopNameLabel
@onready var player_gold_label:     Label         = %PlayerGoldLabel
@onready var shop_gold_label:       Label         = %ShopGoldLabel
@onready var shop_slots_label:      Label         = %ShopSlotsLabel
@onready var shop_items_container:  Control = %ShopItemsContainer
@onready var player_items_container: Control = %PlayerItemsContainer
@onready var close_button:          Button        = %CloseButton
@onready var feedback_label:        Label         = %FeedbackLabel


# ============================================
# CONSTANTES
# ============================================

const ITEM_SLOT_SCENE := preload("res://ui/shop/shop_item_slot.tscn")

const COLOR_FEEDBACK_OK  := Color(0.3, 0.9, 0.3)
const COLOR_FEEDBACK_ERR := Color(0.9, 0.3, 0.3)
const FEEDBACK_DURATION  := 3.0


# ============================================
# ESTADO INTERNO
# ============================================

var _vm: ShopViewModel = null
var _feedback_timer: SceneTreeTimer = null


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	visible = false

	_vm = ShopViewModel.new()
	_vm.name = "ViewModel"
	add_child(_vm)
	_vm.changed.connect(_on_vm_changed)

	close_button.pressed.connect(func(): _vm.request_close())

	feedback_label.visible = false
	print("[ShopUI] Ready")


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
			_set_all_buttons_enabled(false)
		"trade_success":
			_render_snapshot()
			_show_feedback(_vm.feedback_message, false)
		"trade_failed":
			_set_all_buttons_enabled(true)
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

	shop_name_label.text    = s.get("shop_name", "Shop")
	player_gold_label.text  = "Gold: %d" % s.get("player_gold", 0)
	shop_gold_label.text    = "Shop: %d gold" % s.get("shop_gold", 0)

	var used:      int = s.get("shop_slots_used", 0)
	var max_slots: int = s.get("shop_slots_max", 0)
	shop_slots_label.text = "Slots: %d/%d" % [used, max_slots]

	_render_items(shop_items_container,   s.get("items_for_sale", []),        true)
	_render_items(player_items_container, s.get("player_items_sellable", []), false)

	_set_all_buttons_enabled(true)


func _render_items(container: Node, items: Array, buy_mode: bool) -> void:
	_clear_container(container)
	for item_data in items:
		var slot: ShopItemSlot = ITEM_SLOT_SCENE.instantiate()
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


# ============================================
# FEEDBACK TEMPORAL
# ============================================

func _show_feedback(message: String, is_error: bool) -> void:
	feedback_label.text     = message
	feedback_label.modulate = COLOR_FEEDBACK_ERR if is_error else COLOR_FEEDBACK_OK
	feedback_label.visible  = true

	# Cancelar timer anterior si existía
	if _feedback_timer and is_instance_valid(_feedback_timer):
		_feedback_timer.timeout.disconnect(_hide_feedback)

	_feedback_timer = get_tree().create_timer(FEEDBACK_DURATION)
	_feedback_timer.timeout.connect(_hide_feedback)


func _hide_feedback() -> void:
	if feedback_label:
		feedback_label.visible = false


# ============================================
# UTILIDADES
# ============================================

func _set_all_buttons_enabled(enabled: bool) -> void:
	for container in [shop_items_container, player_items_container]:
		for slot in container.get_children():
			if slot.has_method("_update_display"):
				var btn = slot.get_node_or_null("%ActionButton")
				if btn:
					btn.disabled = not enabled


func _clear_container(container: Node) -> void:
	for child in container.get_children():
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
