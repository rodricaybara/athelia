extends CharacterBody2D

## Player - Controlador del personaje jugador
## Día 2: Movimiento básico top-down sin consumo de recursos

## Configuración de movimiento
@export var speed: float = 200.0  ## Velocidad en píxeles/segundo
@export var acceleration: float = 1500.0  ## Aceleración
@export var friction: float = 1200.0  ## Fricción al soltar teclas

## Configuración de Dash
@export var dash_speed_multiplier: float = 2.0  ## Multiplicador de velocidad durante dash
@export var dash_duration: float = 0.3  ## Duración del dash en segundos

## Referencias
var resource_system: ResourceSystem
var skill_system: SkillSystem

## Estado
var input_direction: Vector2 = Vector2.ZERO
var is_dashing: bool = false  ## ⭐ NUEVO
var dash_time_remaining: float = 0.0  ## ⭐ NUEVO
var dash_direction: Vector2 = Vector2.ZERO  ## ⭐ NUEVO

func _ready():
	print("[Player] _ready START")
	# Buscar ResourceSystem
	resource_system = get_node("/root/Resources")
	
	if resource_system:
		resource_system.register_entity("player")
		print("[Player] Registered in ResourceSystem")
	else:
		push_warning("[Player] ResourceSystem not found!")
	
	# Buscar SkillSystem ⭐ NUEVO
	skill_system = get_node("/root/Skills")
	
	if skill_system:
		# Registrar habilidades del jugador
		skill_system.register_entity_skills("player", ["dash"])
		print("[Player] Registered in SkillSystem")
		
		# Conectar a eventos
		skill_system.skill_used.connect(_on_skill_used)
		skill_system.skill_failed.connect(_on_skill_failed)
	else:
		push_warning("[Player] SkillSystem not found!")
	
		# ⭐ NUEVO: Registrar en InventorySystem
	var inventory_system = get_node("/root/Inventory")
	if inventory_system:
		if inventory_system.has_method("register_entity"):
			inventory_system.register_entity("player")
			print("[Player] Registered in InventorySystem")
		else:
			push_warning("[Player] InventorySystem doesn't have register_entity method")
	else:
		push_warning("[Player] InventorySystem not found!")
	
	# Debug info
	print("[Player] Initialized - Speed: %s" % speed)
	# Conectar a eventos de ítems
	EventBus.item_use_requested.connect(_on_item_use_requested)
	print("[Player] Connected to ItemSystem events")
	print("[Player] _ready END")

func _physics_process(delta: float):
	# Procesar dash si está activo
	if is_dashing:
		_process_dash(delta)
		return  # Durante dash, ignorar input normal
	
	# Obtener input del jugador
	input_direction = get_input_direction()
	
	# Aplicar movimiento normal
	if input_direction.length() > 0:
		velocity = velocity.move_toward(
			input_direction * speed, 
			acceleration * delta
		)
	else:
		velocity = velocity.move_toward(
			Vector2.ZERO, 
			friction * delta
		)
	
	# Mover y colisionar
	move_and_slide()

## Procesa el movimiento durante el Dash
func _process_dash(delta: float):
	# Actualizar tiempo restante
	dash_time_remaining -= delta
	
	# Si terminó el dash
	if dash_time_remaining <= 0:
		is_dashing = false
		dash_time_remaining = 0.0
		print("[Player] Dash finished")
		return
	
	# Aplicar velocidad de dash
	velocity = dash_direction * speed * dash_speed_multiplier
	
	# Mover
	move_and_slide()

## Obtiene la dirección del input normalizada
func get_input_direction() -> Vector2:
	var direction = Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	
	return direction.normalized()

func _input(event):
	# Dash con Espacio
	if event.is_action_pressed("ui_accept"):
		_try_dash()
	
	# Guardar partida (F5) ⭐ NUEVO
	if event.is_action_pressed("quicksave"):
		_quicksave()
	
	# Cargar partida (F9) ⭐ NUEVO
	if event.is_action_pressed("quickload"):
		_quickload()
	
	# Debug: P para imprimir recursos y skills
	if event.is_action_pressed("ui_page_down"):
		print_resources()
		if skill_system:
			skill_system.print_entity_skills("player")

## Intenta ejecutar el Dash
func _try_dash():
	if not skill_system:
		return
	
	# Verificar si se puede usar
	if not skill_system.can_use("player", "dash"):
		# El evento skill_failed se encargará del feedback
		return
	
	# Solicitar uso de la habilidad
	if skill_system.request_use("player", "dash"):
		# El evento skill_used se encargará de aplicar el efecto
		pass

## Callback cuando se usa una habilidad
func _on_skill_used(entity_id: String, skill_id: String):
	if entity_id != "player":
		return
	
	if skill_id == "dash":
		_apply_dash_effect()


## Callback cuando falla el uso de una habilidad
func _on_skill_failed(entity_id: String, skill_id: String, reason: String):
	if entity_id != "player":
		return
	
	print("[Player] Skill '%s' failed: %s" % [skill_id, reason])
	# TODO: Feedback visual/audio

## Aplica el efecto del Dash
func _apply_dash_effect():
	# Guardar dirección actual (o última dirección si está quieto)
	if input_direction.length() > 0:
		dash_direction = input_direction
	elif velocity.length() > 0:
		dash_direction = velocity.normalized()
	else:
		dash_direction = Vector2.RIGHT  # Default si está completamente quieto
	
	# Activar estado de dash
	is_dashing = true
	dash_time_remaining = dash_duration
	# Activar partículas si existen
	if has_node("DashParticles"):
		var particles = $DashParticles as CPUParticles2D
		particles.emitting = true	
	print("[Player] Dash activated! Direction: %s" % dash_direction)

## Debug: imprime info de movimiento
func _debug_movement():
	var speed_current = velocity.length()
	print("[Player] Pos: %s | Speed: %.0f | Dir: %s" % [
		position.round(), 
		speed_current,
		input_direction
	])


## Obtiene el porcentaje de un recurso (para Día 3)
func get_resource_percentage(resource_id: String) -> float:
	if resource_system:
		return resource_system.get_resource_percentage("player", resource_id)
	return 0.0


## Debug: imprime recursos actuales
func print_resources():
	if resource_system:
		resource_system.print_entity_resources("player")

## ============================================
## SAVE/LOAD INTEGRATION (Día 4)
## ============================================

## Guarda la partida rápidamente
func _quicksave():
	var save_manager = get_node("/root/SaveManager")
	if save_manager:
		save_manager.save_game("quicksave")
	else:
		push_warning("[Player] SaveManager not found!")


## Carga la partida rápidamente
func _quickload():
	var save_manager = get_node("/root/SaveManager")
	if save_manager:
		save_manager.load_game("quicksave")
	else:
		push_warning("[Player] SaveManager not found!")
		
# ============================================
# INTEGRACIÓN ITEMSYSTEM - DÍA 5
# ============================================

## Procesa solicitud de uso de ítem
func _on_item_use_requested(entity_id: String, item_id: String):
	if entity_id != "player":
		return  # Solo procesar ítems del jugador
	
	var item_def = Items.get_item(item_id)
	if not item_def:
		EventBus.item_use_failed.emit(entity_id, item_id, "Item definition not found")
		return
	
	# Aplicar modificadores del ítem
	var success = _apply_item_modifiers(entity_id, item_def)
	
	if success:
		EventBus.item_use_success.emit(entity_id, item_id)
		print("[Player] Used item: %s" % item_id)
	else:
		EventBus.item_use_failed.emit(entity_id, item_id, "No effect applied")


## Aplica los modificadores declarativos de un ítem
func _apply_item_modifiers(entity_id: String, item_def: ItemDefinition) -> bool:
	var any_applied = false
	
	# Obtener solo modificadores que se aplican "on_use"
	var on_use_modifiers = item_def.get_modifiers_for_condition("on_use")
	
	if on_use_modifiers.is_empty():
		push_warning("[Player] Item has no on_use modifiers: %s" % item_def.id)
		return false
	
	for modifier in on_use_modifiers:
		# Solo procesar modificadores de recursos
		if not modifier.targets_resource():
			continue
		
		var resource_id = modifier.get_resource_id()
		
		match modifier.operation:
			"add":
				var added = resource_system.add_resource(entity_id, resource_id, modifier.value)
				if added > 0:
					any_applied = true
					print("[Player] Applied modifier: +%.0f %s" % [added, resource_id])
			
			"mul":
				# Futuro: multiplicadores
				push_warning("[Player] Multiply operation not yet implemented")
			
			"override":
				resource_system.set_resource(entity_id, resource_id, modifier.value)
				any_applied = true
				print("[Player] Applied modifier: set %s to %.0f" % [resource_id, modifier.value])
	
	return any_applied
