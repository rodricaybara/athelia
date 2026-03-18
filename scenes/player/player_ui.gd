extends CanvasLayer

## PlayerUI - Interfaz del jugador
## Muestra recursos (HP, Stamina) y estado de habilidades

## Referencias a nodos UI
@onready var hp_progress = %HPProgress
@onready var hp_value = %HPValue
@onready var stamina_progress = %StaminaProgress
@onready var stamina_value = %StaminaValue
@onready var dash_status = %DashStatus

## Referencias a sistemas
var resource_system: ResourceSystem
var skill_system: SkillSystem

## ID de la entidad a monitorizar
@export var entity_id: String = "player"


func _ready():
	# Buscar sistemas
	resource_system = get_node("/root/Resources")
	skill_system = get_node("/root/Skills")
	
	if not resource_system:
		push_error("[PlayerUI] ResourceSystem not found!")
		return
	
	if not skill_system:
		push_error("[PlayerUI] SkillSystem not found!")
		return
	
	# Conectar a eventos
	resource_system.resource_changed.connect(_on_resource_changed)
	skill_system.cooldown_started.connect(_on_cooldown_started)
	skill_system.cooldown_finished.connect(_on_cooldown_finished)
	
	# Inicializar UI
	_update_all_resources()
	_update_dash_status()


## Actualiza todos los recursos en la UI
func _update_all_resources():
	_update_resource_bar("health", hp_progress, hp_value)
	_update_resource_bar("stamina", stamina_progress, stamina_value)


## Actualiza una barra de recurso específica
func _update_resource_bar(resource_id: String, progress_bar: ProgressBar, value_label: Label):
	var current = resource_system.get_resource_amount(entity_id, resource_id)
	var state = resource_system.get_resource_state(entity_id, resource_id)
	
	if state:
		progress_bar.max_value = state.max_effective
		progress_bar.value = current
		value_label.text = "%d" % int(current)
		
		# Color según porcentaje
		var percentage = state.get_percentage()
		if percentage > 0.6:
			progress_bar.modulate = Color.WHITE
		elif percentage > 0.3:
			progress_bar.modulate = Color.YELLOW
		else:
			progress_bar.modulate = Color.RED


## Actualiza el estado del Dash
func _update_dash_status():
	var instance = skill_system.get_skill_instance(entity_id, "dash")
	if not instance:
		dash_status.text = "N/A"
		return
	
	if instance.is_on_cooldown():
		var remaining = instance.get_cooldown_remaining()
		dash_status.text = "%.1fs" % remaining
		dash_status.modulate = Color.RED
	else:
		dash_status.text = "Ready"
		dash_status.modulate = Color.GREEN


## Actualiza cada frame (para cooldown en tiempo real)
func _process(_delta: float):
	_update_dash_status()


## Callback: recurso cambió
func _on_resource_changed(ent_id: String, res_id: String, current: float, _max_val: float):
	if ent_id != entity_id:
		return
	
	if res_id == "health":
		_update_resource_bar("health", hp_progress, hp_value)
	elif res_id == "stamina":
		_update_resource_bar("stamina", stamina_progress, stamina_value)


## Callback: cooldown empezó
func _on_cooldown_started(ent_id: String, skill_id: String, _duration: float):
	if ent_id != entity_id:
		return
	
	if skill_id == "dash":
		_update_dash_status()


## Callback: cooldown terminó
func _on_cooldown_finished(ent_id: String, skill_id: String):
	if ent_id != entity_id:
		return
	
	if skill_id == "dash":
		_update_dash_status()
