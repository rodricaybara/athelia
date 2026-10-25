extends Control
## Prueba AISLADA de UISlot (Spike 18, Fase 2). Solo desarrollo; no entra en el juego.
##
## Ejecutar: abrir ui_slot_drag_test.tscn y pulsar F6 (Ejecutar escena actual).
## Necesita que existan los autoloads (siempre, al ser un proyecto Godot) y que
## el inventario de 'player' tenga ítems: si sale vacío, ejecútalo después de
## empezar una partida (o añade ítems al personaje inicial).
##
## Qué debe verse:
##   - Fila "Mochila": hasta 6 ítems reales. Se pueden ARRASTRAR; un clic los
##     selecciona (borde dorado). El último lleva borde discontinuo rojo
##     (desbordamiento) y el primero la marca E (equipado).
##   - Fila "Equipo": 3 slots (head, weapon, shield). NO se pueden arrastrar;
##     aceptan solo drops desde la mochila. Etiqueta bajo el icono.
##   - Un slot vacío al final de cada fila.
##   - Ítems sin icono (p. ej. enchanted_spear): silueta de bolsa grisácea.
##   - Registro en pantalla y en Output de cada clic y drop.

const SLOT_SCENE: PackedScene = preload("res://ui/design_system/components/ui_slot/ui_slot.tscn")
const ENTITY_ID: String = "player"
const EQUIP_IDS: Array[String] = ["head", "weapon", "shield"]
const FALLBACK_ITEM_IDS: Array[String] = ["iron_sword", "leather_armor", "health_potion", "enchanted_spear", "wooden_shield", "iron_helmet"]

## Instancias de prueba por id, para poder soltarlas en el equipo sin partida
var _fallback: Dictionary = {}

var _log_label: Label = null
var _bag_slots: Array[UISlot] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = UITokens.COLOR_BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_top = 24
	root.offset_right = -24
	root.offset_bottom = -24
	root.add_theme_constant_override("separation", UITokens.SPACE_LG)
	add_child(root)

	root.add_child(_make_title("Mochila (arrastrable; clic = seleccionar)"))
	var bag_row := HBoxContainer.new()
	bag_row.add_theme_constant_override("separation", UITokens.SPACE_SM)
	root.add_child(bag_row)

	root.add_child(_make_title("Equipo (no arrastrable; solo acepta drops de la mochila)"))
	var equip_row := HBoxContainer.new()
	equip_row.add_theme_constant_override("separation", UITokens.SPACE_SM)
	root.add_child(equip_row)

	_log_label = Label.new()
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_log_label)

	_build_bag(bag_row)
	_build_equipment(equip_row)


func _make_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UITokens.COLOR_ACCENT)
	return label


func _build_bag(row: HBoxContainer) -> void:
	var inventory: Dictionary = Inventory.get_inventory(ENTITY_ID)
	var instances: Array = inventory.values()
	if instances.is_empty():
		# F6 sin partida: se crean instancias de prueba (solo existen en esta escena)
		for item_id in FALLBACK_ITEM_IDS:
			var item_def: ItemDefinition = Items.get_item(item_id)
			if item_def != null:
				var created := ItemInstance.new(item_def, 2 if item_id == "health_potion" else 1)
				_fallback[item_id] = created
				instances.append(created)
		_report("Inventario de '%s' vacío: usando %d ítems de prueba." % [ENTITY_ID, instances.size()])

	var shown: int = mini(instances.size(), 6)
	for i in range(shown):
		var instance: ItemInstance = instances[i]
		var slot: UISlot = _new_bag_slot(row)
		slot.set_item(instance)
		slot.tooltip_text = instance.definition.id
		if i == 0:
			slot.set_equipped_mark(true)
		if i == shown - 1 and shown > 1:
			slot.set_overflow(true)
		# Borde de color como lo pasaría la View (aquí uno distinto por posición)
		slot.border_color_override = [UITokens.COLOR_WARNING, UITokens.COLOR_SUCCESS, UITokens.COLOR_ACCENT_SOFT][i % 3]

	var empty_slot: UISlot = _new_bag_slot(row)
	empty_slot.clear()


func _new_bag_slot(row: HBoxContainer) -> UISlot:
	var slot: UISlot = SLOT_SCENE.instantiate()
	slot.accept_drops = false
	row.add_child(slot)
	slot.slot_clicked.connect(_on_bag_clicked)
	_bag_slots.append(slot)
	return slot


func _build_equipment(row: HBoxContainer) -> void:
	for slot_id in EQUIP_IDS:
		var slot: UISlot = SLOT_SCENE.instantiate()
		slot.equipment_slot_id = slot_id
		slot.draggable = false
		slot.drop_source_filter = "inventory"
		slot.slot_label_text = slot_id.capitalize()
		row.add_child(slot)
		slot.clear()
		slot.slot_clicked.connect(func(s: UISlot) -> void:
			_report("Clic en slot de equipo '%s' (ocupado: %s)" % [s.equipment_slot_id, str(not s.is_empty())]))
		slot.slot_drop_received.connect(func(s: UISlot, item_id: String) -> void:
			_report("DROP de '%s' sobre el slot de equipo '%s'" % [item_id, s.equipment_slot_id])
			var instance: ItemInstance = Inventory.get_inventory(ENTITY_ID).get(item_id, _fallback.get(item_id))
			if instance != null:
				s.set_item(instance))


func _on_bag_clicked(slot: UISlot) -> void:
	for other in _bag_slots:
		other.set_selected(other == slot and not slot.is_empty())
	_report("Clic en mochila: '%s'" % (slot.get_item_id() if not slot.is_empty() else "(vacío)"))


func _report(message: String) -> void:
	print("[UISlotTest] ", message)
	if _log_label:
		_log_label.text = message + "\n" + _log_label.text
