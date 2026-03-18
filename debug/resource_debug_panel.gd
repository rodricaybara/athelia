extends PanelContainer

## ResourceDebugPanel - UI temporal para testear ResourceSystem
## Solo para desarrollo, no incluir en build final

@export var entity_id: String = "player"
@export var resource_system_path: NodePath

var resource_system: ResourceSystem
var resource_bars: Dictionary = {}  # { resource_id -> { label, bar, value_label } }

@onready var resources_container = %ResourcesContainer
@onready var log_container = %LogContainer


func _ready():
	# Verificar que los nodos únicos existen
	if not resources_container:
		push_error("[ResourceDebugPanel] ResourcesContainer not found! Check unique names in scene.")
		return
	
	if not log_container:
		push_error("[ResourceDebugPanel] LogContainer not found! Check unique names in scene.")
		return
	# Buscar ResourceSystem
	if not resource_system_path.is_empty():
		resource_system = get_node(resource_system_path) as ResourceSystem
	
	if not resource_system:
		# Buscar en el root de la escena
		var root = get_tree().current_scene
		if root:
			resource_system = root.get_node_or_null("ResourceSystem") as ResourceSystem
	
	if not resource_system:
		push_error("[ResourceDebugPanel] ResourceSystem not found! Check 'resource_system_path' property.")
		return
	
	# Conectar a eventos
	resource_system.resource_changed.connect(_on_resource_changed)
	resource_system.resource_depleted.connect(_on_resource_depleted)
	resource_system.payment_failed.connect(_on_payment_failed)
	
	# IMPORTANTE: Esperar a que la entidad esté registrada
	await get_tree().process_frame
	await get_tree().process_frame  # Doble espera para asegurar
	
	_build_ui()
	_log("Debug panel initialized for entity: %s" % entity_id)


func _build_ui():
	print("[ResourceDebugPanel] Building UI for entity: ", entity_id)
	
	if not resource_system._entities.has(entity_id):
		_log("ERROR: Entity '%s' not registered!" % entity_id)
		print("[ResourceDebugPanel] Available entities: ", resource_system._entities.keys())
		return
	
	# Conectar botón de test bundle (si existe en la escena)
	var bundle_button = get_node_or_null("MarginContainer/VBoxContainer/TestButtons/BundleButton")
	if bundle_button:
		bundle_button.pressed.connect(_test_pay_bundle)
		print("[ResourceDebugPanel] Bundle button connected")
	
	# Crear barras para cada recurso
	var resources = resource_system._entities[entity_id]
	print("[ResourceDebugPanel] Creating bars for ", resources.size(), " resources")
	
	for res_id in resources.keys():
		_create_resource_bar(res_id, resources[res_id])
		print("[ResourceDebugPanel] Created bar for: ", res_id)


func _create_resource_bar(res_id: String, state: ResourceState):
	var container = VBoxContainer.new()
	container.name = "Resource_%s" % res_id
	
	# Header con nombre y valor
	var header = HBoxContainer.new()
	
	var name_label = Label.new()
	name_label.text = res_id.capitalize()
	name_label.custom_minimum_size.x = 100
	header.add_child(name_label)
	
	var value_label = Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size.x = 100
	_update_value_label(value_label, state)
	header.add_child(value_label)
	
	container.add_child(header)
	
	# Barra de progreso
	var progress_bar = ProgressBar.new()
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(200, 20)
	_update_progress_bar(progress_bar, state)
	container.add_child(progress_bar)
	
	# Botones de test
	var buttons = HBoxContainer.new()
	
	var btn_damage = Button.new()
	btn_damage.text = "-20"
	btn_damage.pressed.connect(func(): _test_subtract(res_id, 20.0))
	buttons.add_child(btn_damage)
	
	var btn_heal = Button.new()
	btn_heal.text = "+20"
	btn_heal.pressed.connect(func(): _test_add(res_id, 20.0))
	buttons.add_child(btn_heal)
	
	var btn_restore = Button.new()
	btn_restore.text = "Full"
	btn_restore.pressed.connect(func(): _test_restore(res_id))
	buttons.add_child(btn_restore)
	
	var btn_deplete = Button.new()
	btn_deplete.text = "Empty"
	btn_deplete.pressed.connect(func(): _test_deplete(res_id))
	buttons.add_child(btn_deplete)
	
	container.add_child(buttons)
	
	# Añadir separador
	var separator = HSeparator.new()
	container.add_child(separator)
	
	resources_container.add_child(container)
	
	# Guardar referencias
	resource_bars[res_id] = {
		"label": name_label,
		"bar": progress_bar,
		"value_label": value_label,
		"state": state
	}


func _update_value_label(label: Label, state: ResourceState):
	label.text = "%.0f / %.0f" % [state.current, state.max_effective]


func _update_progress_bar(bar: ProgressBar, state: ResourceState):
	bar.max_value = state.max_effective
	bar.value = state.current
	
	# Color según estado
	var percentage = state.get_percentage()
	if percentage > 0.6:
		bar.modulate = Color.GREEN
	elif percentage > 0.3:
		bar.modulate = Color.YELLOW
	else:
		bar.modulate = Color.RED


func _process(_delta: float):
	# Actualizar UI cada frame
	for res_id in resource_bars.keys():
		var data = resource_bars[res_id]
		var state = data.state as ResourceState
		
		_update_value_label(data.value_label, state)
		_update_progress_bar(data.bar, state)


## Test: Restar recurso
func _test_subtract(res_id: String, amount: float):
	resource_system.set_resource(entity_id, res_id, 
		resource_system.get_resource_amount(entity_id, res_id) - amount)
	_log("TEST: -%s %s" % [amount, res_id])


## Test: Añadir recurso
func _test_add(res_id: String, amount: float):
	resource_system.add_resource(entity_id, res_id, amount)
	_log("TEST: +%s %s" % [amount, res_id])


## Test: Restaurar recurso
func _test_restore(res_id: String):
	resource_system.restore_resource(entity_id, res_id)
	_log("TEST: Restored %s to full" % res_id)


## Test: Vaciar recurso
func _test_deplete(res_id: String):
	resource_system.set_resource(entity_id, res_id, 0.0)
	_log("TEST: Depleted %s" % res_id)


## Test: Pagar bundle
func _test_pay_bundle():
	var bundle = ResourceBundle.new()
	bundle.add_cost("stamina", 25.0)
	bundle.add_cost("gold", 10.0)
	
	var success = resource_system.apply_cost(entity_id, bundle)
	_log("TEST: Pay bundle - %s" % ("SUCCESS" if success else "FAILED"))


## Eventos
func _on_resource_changed(ent_id: String, res_id: String, current: float, max_val: float):
	if ent_id == entity_id:
		_log("[EVENT] %s: %.1f/%.1f" % [res_id, current, max_val])


func _on_resource_depleted(ent_id: String, res_id: String):
	if ent_id == entity_id:
		_log("[DEPLETED] %s is empty!" % res_id, Color.RED)


func _on_payment_failed(ent_id: String, bundle: ResourceBundle):
	if ent_id == entity_id:
		_log("[FAILED] Cannot pay: %s" % bundle, Color.ORANGE)


## Log de eventos
func _log(message: String, color: Color = Color.WHITE):
	var label = Label.new()
	label.text = "[%s] %s" % [Time.get_ticks_msec(), message]
	label.modulate = color
	log_container.add_child(label)
	
	# Limitar a 20 mensajes
	if log_container.get_child_count() > 20:
		log_container.get_child(0).queue_free()
