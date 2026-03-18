class_name InventorySystem
extends Node

## InventorySystem - Gestor centralizado de inventarios
## Singleton: /root/Inventory
## Responsabilidad: Gestionar colecciones de ItemInstance por entidad

## Inventarios por entidad: { entity_id: String -> { item_id: String -> ItemInstance } }
var _inventories: Dictionary = {}


func _ready():
	# Conectar a eventos de uso exitoso para consumir ítems
	EventBus.item_use_success.connect(_on_item_use_success)
	print("[InventorySystem] Initialized")


## Registra una nueva entidad con inventario vacío
func register_entity(entity_id: String):
	if _inventories.has(entity_id):
		push_warning("[InventorySystem] Entity already registered: %s" % entity_id)
		return
	
	_inventories[entity_id] = {}
	print("[InventorySystem] Registered entity: %s" % entity_id)


## Desregistra una entidad y elimina su inventario
func unregister_entity(entity_id: String):
	if _inventories.erase(entity_id):
		print("[InventorySystem] Unregistered entity: %s" % entity_id)


## Añade un ítem al inventario
## Retorna true si se añadió correctamente
func add_item(entity_id: String, item_id: String, quantity: int = 1) -> bool:
	if not _inventories.has(entity_id):
		push_error("[InventorySystem] Entity not registered: %s" % entity_id)
		return false
	
	var item_def = Items.get_item(item_id)
	if not item_def:
		push_error("[InventorySystem] Item not found: %s" % item_id)
		return false
	
	var inventory = _inventories[entity_id]
	
	# Si ya existe y es stackable
	if inventory.has(item_id):
		var existing = inventory[item_id] as ItemInstance
		
		# Verificar si se puede stackear
		var temp_instance = ItemInstance.new(item_def, quantity)
		if existing.can_stack_with(temp_instance):
			var added = existing.add_quantity(quantity)
			if added > 0:
				EventBus.item_added.emit(entity_id, item_id, added)
			return true
	
	# Crear nueva instancia
	var instance = ItemInstance.new(item_def, quantity)
	inventory[item_id] = instance
	EventBus.item_added.emit(entity_id, item_id, quantity)
	return true


## Remueve un ítem del inventario
## Retorna true si se removió correctamente
func remove_item(entity_id: String, item_id: String, quantity: int = 1) -> bool:
	if not _inventories.has(entity_id):
		return false
	
	var inventory = _inventories[entity_id]
	if not inventory.has(item_id):
		return false
	
	var instance = inventory[item_id] as ItemInstance
	var removed = instance.remove_quantity(quantity)
	
	# Eliminar si quantity <= 0
	if instance.is_empty():
		inventory.erase(item_id)
	
	if removed > 0:
		EventBus.item_removed.emit(entity_id, item_id, removed)
	
	return removed > 0


## Obtiene la cantidad de un ítem
func get_item_quantity(entity_id: String, item_id: String) -> int:
	if not _inventories.has(entity_id):
		return 0
	
	var inventory = _inventories[entity_id]
	if not inventory.has(item_id):
		return 0
	
	return inventory[item_id].quantity


## ¿Tiene al menos cierta cantidad de un ítem?
func has_item(entity_id: String, item_id: String, min_quantity: int = 1) -> bool:
	return get_item_quantity(entity_id, item_id) >= min_quantity


## Obtiene todo el inventario de una entidad
func get_inventory(entity_id: String) -> Dictionary:
	return _inventories.get(entity_id, {})


## Solicita usar un ítem (emite evento)
func request_use_item(entity_id: String, item_id: String):
	var instance = _get_item_instance(entity_id, item_id)
	if not instance:
		EventBus.item_use_failed.emit(entity_id, item_id, "Item not found")
		return
	
	if not instance.definition.usable:
		EventBus.item_use_failed.emit(entity_id, item_id, "Item not usable")
		return
	
	# Emitir request para que otros sistemas procesen
	EventBus.item_use_requested.emit(entity_id, item_id)


## Obtiene una instancia específica
func _get_item_instance(entity_id: String, item_id: String) -> ItemInstance:
	if not _inventories.has(entity_id):
		return null
	
	var inventory = _inventories[entity_id]
	return inventory.get(item_id, null)


## Callback: consumir ítem tras uso exitoso
func _on_item_use_success(entity_id: String, item_id: String):
	var instance = _get_item_instance(entity_id, item_id)
	if instance and instance.definition.item_type == "CONSUMABLE":
		remove_item(entity_id, item_id, 1)


## Debug: imprime inventario de una entidad
func print_inventory(entity_id: String):
	if not _inventories.has(entity_id):
		print("[InventorySystem] Entity not found: %s" % entity_id)
		return
	
	var inventory = _inventories[entity_id]
	if inventory.is_empty():
		print("[InventorySystem] Inventory for '%s' is empty" % entity_id)
		return
	
	print("\n[InventorySystem] Inventory for '%s':" % entity_id)
	for item_id in inventory.keys():
		var instance = inventory[item_id]
		print("  - %s x%d (%.1fg, %dg total)" % [
			item_id,
			instance.quantity,
			instance.get_total_weight(),
			instance.get_total_value()
		])

# ============================================
# SAVE/LOAD INTEGRATION - DÍA 7
# ============================================

## Obtiene snapshot del inventario de una entidad para guardar
func get_save_state(entity_id: String) -> Dictionary:
	if not _inventories.has(entity_id):
		return {}
	
	var save_data = {}
	var inventory = _inventories[entity_id]
	
	for item_id in inventory.keys():
		var instance = inventory[item_id] as ItemInstance
		save_data[item_id] = {
			"quantity": instance.quantity,
			"custom_state": instance.custom_state.duplicate()
		}
	
	return save_data

## Restaura inventario desde snapshot
func load_save_state(entity_id: String, save_data: Dictionary):
	if not _inventories.has(entity_id):
		push_warning("[InventorySystem] Entity not registered for load: %s" % entity_id)
		register_entity(entity_id)
	
	# ⭐ CRÍTICO: Desconectar eventos temporalmente
	var was_connected = EventBus.item_added.is_connected(_on_item_use_success)
	if was_connected:
		EventBus.item_use_success.disconnect(_on_item_use_success)
	
	# Limpiar inventario actual
	_inventories[entity_id].clear()
	
	# Restaurar cada ítem (sin emitir eventos individuales)
	for item_id in save_data.keys():
		var item_def = Items.get_item(item_id)
		if not item_def:
			push_warning("[InventorySystem] Item not found in registry: %s (skipped)" % item_id)
			continue
		
		var item_data = save_data[item_id]
		var quantity = item_data.get("quantity", 1)
		var custom_state = item_data.get("custom_state", {})
		
		# Crear instancia SIN emitir eventos
		var instance = ItemInstance.new(item_def, quantity, custom_state)
		_inventories[entity_id][item_id] = instance
	
	# ⭐ NUEVO: Emitir UN SOLO evento de "inventario cargado"
	# (en lugar de N eventos item_added)
	EventBus.item_added.emit(entity_id, "", 0)  # Señal genérica de "refresh"
	
	# Reconectar eventos
	if was_connected:
		EventBus.item_use_success.connect(_on_item_use_success)
	
	print("[InventorySystem] Loaded %d items for '%s'" % [save_data.size(), entity_id])
