class_name ResourceState
extends RefCounted

## ResourceState - Estado mutable de un recurso
## Parte del ResourceSystem
## Representa CUÁNTO tiene una entidad de un recurso

## Referencia a la definición inmutable
var definition: ResourceDefinition

## Valor actual del recurso
var current: float = 0.0

## Valor máximo efectivo (puede ser modificado por buffs/equipo)
var max_effective: float = 0.0

## ¿Está pausada la regeneración?
var regen_paused: bool = false

## Tiempo acumulado desde el último consumo (para regen_delay)
var time_since_last_use: float = 0.0


## Constructor
func _init(res_def: ResourceDefinition, initial_value: float = -1.0):
	if res_def == null:
		push_error("ResourceState: definition cannot be null")
		return
	
	definition = res_def
	max_effective = definition.max_base
	
	# Si initial_value es -1, empezamos con el máximo
	if initial_value < 0:
		current = max_effective
	else:
		current = clampf(initial_value, 0.0, max_effective)


## Establece el valor actual (con clamp)
func set_current(value: float) -> void:
	if definition.is_infinite:
		current = value  # Los recursos infinitos no tienen límite
		return
	
	if definition.allow_negative:
		current = minf(value, max_effective)
	else:
		current = clampf(value, 0.0, max_effective)


## Añade una cantidad al recurso
func add(amount: float) -> float:
	var old_value = current
	set_current(current + amount)
	return current - old_value  # Retorna cuánto realmente se añadió


## Resta una cantidad al recurso
func subtract(amount: float) -> float:
	var old_value = current
	set_current(current - amount)
	
	# Resetear timer de regeneración al consumir
	if amount > 0:
		time_since_last_use = 0.0
	
	return old_value - current  # Retorna cuánto realmente se restó


## ¿Puede pagar esta cantidad?
func can_pay(amount: float) -> bool:
	if definition.is_infinite:
		return true
	if definition.allow_negative:
		return true
	return current >= amount


## Intenta pagar un coste
func pay(amount: float) -> bool:
	if not can_pay(amount):
		return false
	
	subtract(amount)
	return true


## ¿Está lleno?
func is_full() -> bool:
	return current >= max_effective


## ¿Está vacío?
func is_empty() -> bool:
	return current <= 0.0


## Porcentaje actual (0.0 a 1.0)
func get_percentage() -> float:
	if definition.is_infinite or max_effective <= 0:
		return 1.0
	
	return current / max_effective


## Actualiza la regeneración (llamado por ResourceSystem cada frame)
func process_regeneration(delta: float) -> float:
	if definition.regen_rate <= 0:
		return 0.0
	
	if regen_paused:
		return 0.0
	
	if is_full():
		return 0.0
	
	# Esperar el delay antes de regenerar
	time_since_last_use += delta
	if time_since_last_use < definition.regen_delay:
		return 0.0
	
	# Regenerar
	var regen_amount = definition.regen_rate * delta
	return add(regen_amount)


## Restaura al máximo
func restore_full() -> void:
	set_current(max_effective)


## Actualiza el máximo efectivo (por buffs/equipo)
func set_max_effective(new_max: float) -> void:
	max_effective = new_max
	
	# Ajustar current si excede el nuevo máximo
	if current > max_effective and not definition.is_infinite:
		current = max_effective


## Debug
func _to_string() -> String:
	return "ResourceState(%s: %s/%s [%.0f%%])" % [
		definition.id,
		snappedf(current, 0.1),
		snappedf(max_effective, 0.1),
		get_percentage() * 100
	]
