extends CanvasLayer
class_name PartyUI

## PartyUI — View
##
## Renderiza el estado expuesto por PartyViewModel.
## No accede a Inventory, Equipment, Characters, Party ni Items directamente.
## Todo input del jugador se delega al ViewModel.


# ============================================
# SEÑALES
# ============================================

signal closed


# ============================================
# NODOS — columna jugador
# ============================================

@onready var player_equip_head:   EquipSlot     = %PlayerEquipHead
@onready var player_equip_body:   EquipSlot     = %PlayerEquipBody
@onready var player_equip_hands:  EquipSlot     = %PlayerEquipHands
@onready var player_equip_feet:   EquipSlot     = %PlayerEquipFeet
@onready var player_equip_weapon: EquipSlot     = %PlayerEquipWeapon
@onready var player_equip_shield: EquipSlot     = %PlayerEquipShield
@onready var player_grid:         GridContainer = %PlayerGrid


# ============================================
# NODOS — columna companion
# ============================================

@onready var companion_name_label:   Label        = %CompanionNameLabel
@onready var companion_prev_button:  Button       = %CompanionPrevButton
@onready var companion_next_button:  Button       = %CompanionNextButton
@onready var companion_equip_head:   EquipSlot    = %CompanionEquipHead
@onready var companion_equip_body:   EquipSlot    = %CompanionEquipBody
@onready var companion_equip_hands:  EquipSlot    = %CompanionEquipHands
@onready var companion_equip_feet:   EquipSlot    = %CompanionEquipFeet
@onready var companion_equip_weapon: EquipSlot    = %CompanionEquipWeapon
@onready var companion_equip_shield: EquipSlot    = %CompanionEquipShield
@onready var companion_grid:         GridContainer = %CompanionGrid
@onready var no_companions_label:    Label        = %NoCompanionsLabel
@onready var strategy_option:        OptionButton = %StrategyOption


# ============================================
# NODOS — comunes
# ============================================

@onready var close_button: Button = %CloseButton


# ============================================
# ESTADO INTERNO
# ============================================

var _vm: PartyViewModel = null

var _player_equip_nodes:    Dictionary = {}
var _companion_equip_nodes: Dictionary = {}
var _player_bag_slots:      Array      = []
var _companion_bag_slots:   Array      = []


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	visible = false

	# Crear ViewModel como hijo
	_vm = PartyViewModel.new()
	_vm.name = "ViewModel"
	add_child(_vm)
	_vm.changed.connect(_on_vm_changed)

	# Mapas de slots de equipo
	_player_equip_nodes = {
		"head":   player_equip_head,
		"body":   player_equip_body,
		"hands":  player_equip_hands,
		"feet":   player_equip_feet,
		"weapon": player_equip_weapon,
		"shield": player_equip_shield,
	}
	_companion_equip_nodes = {
		"head":   companion_equip_head,
		"body":   companion_equip_body,
		"hands":  companion_equip_hands,
		"feet":   companion_equip_feet,
		"weapon": companion_equip_weapon,
		"shield": companion_equip_shield,
	}

	# Cachear slots de mochila
	_player_bag_slots    = player_grid.get_children()
	_companion_bag_slots = companion_grid.get_children()

	# Conectar slots de equipo — jugador
	for slot_id in _player_equip_nodes:
		var equip_slot: EquipSlot = _player_equip_nodes[slot_id]
		equip_slot.unequip_requested.connect(
			func(sid: String): _vm.request_unequip(sid, PartyViewModel.PLAYER_ID)
		)
		equip_slot.drop_accepted.connect(
			func(sid: String, iid: String): _on_equip_drop(sid, iid, PartyViewModel.PLAYER_ID)
		)

	# Conectar slots de equipo — companion
	for slot_id in _companion_equip_nodes:
		var equip_slot: EquipSlot = _companion_equip_nodes[slot_id]
		equip_slot.unequip_requested.connect(
			func(sid: String): _vm.request_unequip(sid, _vm.companion_column.entity_id)
		)
		equip_slot.drop_accepted.connect(
			func(sid: String, iid: String): _on_equip_drop(sid, iid, _vm.companion_column.entity_id)
		)

	# Botones de navegación y cierre
	close_button.pressed.connect(func(): _vm.request_close())
	companion_prev_button.pressed.connect(func(): _vm.navigate_prev_companion())
	companion_next_button.pressed.connect(func(): _vm.navigate_next_companion())

	# Estrategia
	strategy_option.item_selected.connect(func(idx: int): _vm.request_set_strategy(idx))

	print("[PartyUI] Ready")


# ============================================
# API PÚBLICA
# ============================================

func open() -> void:
	_vm.open()


func close() -> void:
	_vm.request_close()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


# ============================================
# CALLBACK ÚNICO DEL VIEWMODEL
# ============================================

func _on_vm_changed(reason: String) -> void:
	match reason:
		"opened":
			_render_all()
			visible = true
		"player_column":
			_render_column(_player_equip_nodes, _player_bag_slots, _vm.player_column)
		"companion_column":
			_render_column(_companion_equip_nodes, _companion_bag_slots, _vm.companion_column)
		"companion_changed":
			_render_companion_header()
			_render_column(_companion_equip_nodes, _companion_bag_slots, _vm.companion_column)
		"closed":
			visible = false
			closed.emit()
		_:
			push_warning("[PartyUI] Razón desconocida: %s" % reason)


# ============================================
# RENDERS
# ============================================

func _render_all() -> void:
	_render_strategy_options()
	_render_column(_player_equip_nodes, _player_bag_slots, _vm.player_column)
	_render_companion_header()
	_render_column(_companion_equip_nodes, _companion_bag_slots, _vm.companion_column)


func _render_companion_header() -> void:
	var has := _vm.companion_count > 0
	var has_nav := _vm.companion_count > 1

	no_companions_label.visible    = not has
	companion_prev_button.visible  = has_nav
	companion_next_button.visible  = has_nav
	strategy_option.disabled       = not has

	if not has:
		companion_name_label.text = "Sin companions"
		return

	companion_name_label.text = _vm.companion_column.display_name

	if _vm.companion_column.active_strategy >= 0:
		strategy_option.select(_vm.companion_column.active_strategy)


func _render_strategy_options() -> void:
	strategy_option.clear()
	for strategy_name in _vm.strategy_names:
		strategy_option.add_item(strategy_name)


func _render_column(
		equip_nodes: Dictionary,
		bag_slots: Array,
		data: PartyViewModel.ColumnData) -> void:

	# Slots de equipo
	for equip_data in data.equip_slots:
		var slot = equip_nodes.get(equip_data.slot_id)
		if not slot:
			continue
		if equip_data.is_empty:
			slot.clear()
		else:
			slot.set_equipped(equip_data.item_def)

	# Mochila
	for i in range(bag_slots.size()):
		var slot = bag_slots[i]
		if not slot.has_method("set_item"):
			continue

		if i >= data.bag_slots.size() or data.bag_slots[i].is_empty:
			slot.clear()
			continue

		var slot_data: PartyViewModel.SlotData = data.bag_slots[i]
		var instance: ItemInstance = Inventory.get_inventory(data.entity_id).get(slot_data.item_id)
		if instance:
			slot.set_item(instance)
			# Conectar click vinculado a la entidad correcta
			if slot.slot_clicked.is_connected(_on_bag_slot_clicked):
				slot.slot_clicked.disconnect(_on_bag_slot_clicked)
			slot.slot_clicked.connect(_on_bag_slot_clicked.bind(data.entity_id))
		else:
			slot.clear()


# ============================================
# INPUT DE LA VIEW → VIEWMODEL
# ============================================

func _on_bag_slot_clicked(item_id: String, entity_id: String) -> void:
	_vm.request_slot_action(item_id, entity_id)


func _on_equip_drop(slot_id: String, item_id: String, entity_id: String) -> void:
	var error := _vm.request_equip_drop(slot_id, item_id, entity_id)
	if not error.is_empty():
		print("[PartyUI] Drop rechazado: %s" % tr(error))


# ============================================
# INPUT DE TECLADO
# ============================================

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("open_party") or event.is_action_pressed("ui_cancel"):
		_vm.request_close()
		get_viewport().set_input_as_handled()
