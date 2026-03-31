class_name InventoryScreen
extends CanvasLayer

## InventoryScreen — View
##
## Renderiza el estado expuesto por InventoryViewModel.
## No accede a Inventory, Equipment ni Characters directamente.
## Todo input del jugador se delega al ViewModel.


# ============================================
# NODOS — Layout principal
# ============================================

@onready var close_button: Button = %CloseButton

# Columna izquierda — equipamiento
@onready var equip_head:   PanelContainer = %EquipSlot_head
@onready var equip_body:   PanelContainer = %EquipSlot_body
@onready var equip_hands:  PanelContainer = %EquipSlot_hands
@onready var equip_feet:   PanelContainer = %EquipSlot_feet
@onready var equip_weapon: PanelContainer = %EquipSlot_weapon
@onready var equip_shield: PanelContainer = %EquipSlot_shield

@onready var stat_hp_label:    Label = %StatsHP
@onready var stat_stamina_label: Label = %StatsStamina
@onready var stat_gold_label:  Label = %StatsGold
@onready var stat_str_label:   Label = %StatsSTR
@onready var stat_dex_label:   Label = %StatsDEX
@onready var stat_con_label:   Label = %StatsCON

# Columna derecha — grid de mochila
@onready var slots_grid: GridContainer = %SlotsGrid

# Panel de detalle
@onready var detail_name_label: Label  = %ItemNameLabel
@onready var detail_desc_label: Label  = %ItemDescriptionLabel
@onready var detail_stats_label: Label = %ItemStatsLabel
@onready var detail_empty_msg: Label   = %EmptyMessage
@onready var use_button: Button        = %UseButton
@onready var equip_button: Button      = %EquipButton
@onready var feedback_popup            = %FeedbackPopup


# ============================================
# CONSTANTES
# ============================================

const SLOT_IDS: Array[String] = ["head", "body", "hands", "feet", "weapon", "shield"]


# ============================================
# ESTADO INTERNO DE LA VIEW
# ============================================

var _vm: InventoryViewModel = null

## Mapa slot_id → nodo EquipSlot para acceso genérico
var _equip_nodes: Dictionary = {}

## Lista de ItemSlot del grid, en orden
var _grid_slots: Array = []


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	visible = false

	# Crear ViewModel como hijo
	_vm = InventoryViewModel.new()
	_vm.name = "ViewModel"
	add_child(_vm)
	_vm.changed.connect(_on_vm_changed)

	# Mapa de slots de equipamiento
	_equip_nodes = {
		"head":   equip_head,
		"body":   equip_body,
		"hands":  equip_hands,
		"feet":   equip_feet,
		"weapon": equip_weapon,
		"shield": equip_shield,
	}

	# Conectar slots de mochila
	_grid_slots = slots_grid.get_children()
	for slot in _grid_slots:
		if slot is PanelContainer and slot.has_signal("slot_clicked"):
			slot.slot_clicked.connect(_on_inventory_slot_clicked)

	# Conectar slots de equipamiento
	for slot_id in _equip_nodes:
		var equip_slot = _equip_nodes[slot_id]
		if equip_slot.has_signal("unequip_requested"):
			equip_slot.unequip_requested.connect(_on_unequip_requested)
		if equip_slot.has_signal("drop_accepted"):
			equip_slot.drop_accepted.connect(_on_equip_drop_accepted)

	# Conectar botones de detalle
	close_button.pressed.connect(func(): _vm.request_close())
	use_button.pressed.connect(func(): _vm.request_use())
	equip_button.pressed.connect(func(): _vm.request_toggle_equip())

	print("[InventoryScreen] Ready")


# ============================================
# API PÚBLICA (llamada desde SceneOrchestrator)
# ============================================

func open_inventory(entity_id: String = "player") -> void:
	_vm.open(entity_id)


# ============================================
# CALLBACK ÚNICO DEL VIEWMODEL
# ============================================

func _on_vm_changed(reason: String) -> void:
	match reason:
		"opened":
			_render_all()
			visible = true
		"inventory":
			_render_inventory()
			_render_stats()
			_render_detail()
		"equipment":
			_render_equipment()
			_render_stats()
			_render_detail()
		"selection":
			_render_detail()
			_render_inventory()  # refrescar highlight del slot seleccionado
		"stats":
			_render_stats()
		"action_pending":
			_set_detail_buttons_enabled(false)
		"action_resolved":
			_set_detail_buttons_enabled(true)
			_render_feedback()
			_render_inventory()
			_render_detail()
		"closed":
			visible = false
		_:
			push_warning("[InventoryScreen] Razón desconocida: %s" % reason)


# ============================================
# RENDERS
# ============================================

func _render_all() -> void:
	_render_inventory()
	_render_equipment()
	_render_stats()
	_render_detail()


func _render_inventory() -> void:
	for i in range(_grid_slots.size()):
		var slot = _grid_slots[i]
		if not slot is PanelContainer:
			continue

		if i >= _vm.inventory_slots.size():
			if slot.has_method("clear"):
				slot.clear()
			continue

		var data: InventoryViewModel.SlotData = _vm.inventory_slots[i]

		if data.is_empty:
			if slot.has_method("clear"):
				slot.clear()
		else:
			# Construir ItemInstance mínimo para set_item (la View necesita la firma existente)
			var instance: ItemInstance = Inventory.get_inventory(_vm.entity_id).get(data.item_id)
			if instance and slot.has_method("set_item"):
				slot.set_item(instance)

		# Highlight del slot seleccionado
		if slot.has_method("set_selected"):
			slot.set_selected(data.item_id == _vm.selected_item_id and not data.is_empty)


func _render_equipment() -> void:
	for equip_data in _vm.equipment_slots:
		var slot = _equip_nodes.get(equip_data.slot_id)
		if not slot:
			continue

		if equip_data.is_empty:
			if slot.has_method("clear"):
				slot.clear()
		else:
			if slot.has_method("set_equipped"):
				slot.set_equipped(equip_data.item_def)


func _render_stats() -> void:
	if stat_hp_label:
		stat_hp_label.text = "HP:  %d/%d" % [int(_vm.stat_hp), int(_vm.stat_hp_max)]
	if stat_stamina_label:
		stat_stamina_label.text = "ST:  %d/%d" % [int(_vm.stat_stamina), int(_vm.stat_stamina_max)]
	if stat_gold_label:
		stat_gold_label.text = "G:   %d" % int(_vm.stat_gold)
	if stat_str_label:
		stat_str_label.text = "STR: %d" % int(_vm.stat_strength)
	if stat_dex_label:
		stat_dex_label.text = "DEX: %d" % int(_vm.stat_dexterity)
	if stat_con_label:
		stat_con_label.text = "CON: %d" % int(_vm.stat_constitution)


func _render_detail() -> void:
	var d: InventoryViewModel.DetailData = _vm.detail

	if d == null:
		_show_detail_empty()
		return

	# Nombre y descripción
	detail_name_label.text = tr(d.item_def.name_key)
	detail_name_label.visible = true
	detail_desc_label.text = tr(d.item_def.description_key)
	detail_desc_label.visible = true
	detail_empty_msg.visible = false

	# Stats
	var stats := "Peso: %.1f kg\nValor: %d oro\nCantidad: %d" % [
		d.item_def.weight, d.item_def.base_value, d.quantity
	]

	# Modificadores del ítem equipado
	var mods := d.item_def.get_modifiers_for_condition("equipped")
	if not mods.is_empty():
		stats += "\n─────────"
		for mod in mods:
			var sign_str := "+" if mod.value >= 0 else ""
			stats += "\n%s %s%.0f" % [
				mod.target.split(".")[-1].capitalize(),
				sign_str, mod.value
			]

	# Comparación con ítem equipado actualmente
	if d.competing_item_def:
		stats += "\n\n↕ Equipado: %s" % tr(d.competing_item_def.name_key)

	detail_stats_label.text = stats
	detail_stats_label.visible = true

	# Botones de acción
	use_button.visible = d.can_use
	use_button.disabled = false

	equip_button.visible = d.can_equip or d.can_unequip
	equip_button.disabled = false
	if d.can_unequip:
		equip_button.text = "DESEQUIPAR"
		equip_button.modulate = Color(1.0, 0.6, 0.4)
	else:
		equip_button.text = "EQUIPAR"
		equip_button.modulate = Color.WHITE


func _show_detail_empty() -> void:
	detail_name_label.visible = false
	detail_desc_label.visible = false
	detail_stats_label.visible = false
	use_button.visible = false
	equip_button.visible = false
	detail_empty_msg.visible = true


func _render_feedback() -> void:
	if _vm.feedback_message.is_empty():
		return
	if feedback_popup and feedback_popup.has_method("show_success"):
		if _vm.feedback_is_error:
			feedback_popup.show_error(_vm.feedback_message)
		else:
			feedback_popup.show_success(_vm.feedback_message)
	_vm.feedback_message = ""


func _set_detail_buttons_enabled(enabled: bool) -> void:
	use_button.disabled = not enabled
	equip_button.disabled = not enabled


# ============================================
# INPUT DE LA VIEW → VIEWMODEL
# ============================================

func _on_inventory_slot_clicked(item_id: String) -> void:
	_vm.select_item(item_id)


func _on_unequip_requested(slot_id: String) -> void:
	## Desequipar directamente — no pasa por el ViewModel de selección
	## porque el jugador no necesita seleccionar para desequipar desde el panel de equipo
	Equipment.unequip_slot(_vm.entity_id, slot_id)


func _on_equip_drop_accepted(slot_id: String, item_id: String) -> void:
	if not Inventory.has_item(_vm.entity_id, item_id):
		if feedback_popup and feedback_popup.has_method("show_error"):
			feedback_popup.show_error("Item no disponible")
		return

	if not Equipment.can_equip_in_slot(_vm.entity_id, item_id, slot_id):
		var item_def: ItemDefinition = Items.get_item(item_id)
		var name_str := tr(item_def.name_key) if item_def else item_id
		if feedback_popup and feedback_popup.has_method("show_error"):
			feedback_popup.show_error("%s no encaja en %s" % [name_str, slot_id])
		return

	Equipment.equip_item(_vm.entity_id, item_id)


# ============================================
# INPUT DE TECLADO
# ============================================

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_inventory"):
		_vm.request_close()
		get_viewport().set_input_as_handled()
