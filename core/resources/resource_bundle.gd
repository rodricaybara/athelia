class_name ResourceBundle
extends RefCounted

## ResourceBundle - Representa un coste o ganancia de múltiples recursos
## Ejemplo: { "stamina": 10, "mana": 5 }
## Usado por SkillSystem, ItemSystem, EconomySystem

## Diccionario { resource_id: String -> amount: float }
var costs: Dictionary = {}


## Constructor vacío o con diccionario inicial
func _init(initial_costs: Dictionary = {}):
	costs = initial_costs.duplicate()


## Añade un coste individual
func add_cost(resource_id: String, amount: float) -> void:
	if costs.has(resource_id):
		costs[resource_id] += amount
	else:
		costs[resource_id] = amount


## Obtiene el coste de un recurso específico
func get_cost(resource_id: String) -> float:
	return costs.get(resource_id, 0.0)


## ¿Tiene algún coste?
func is_empty() -> bool:
	return costs.is_empty()


## Obtiene todos los IDs de recursos
func get_resource_ids() -> Array:
	return costs.keys()


## Crea una copia
func duplicate_bundle() -> ResourceBundle:
	return ResourceBundle.new(costs.duplicate())


## Multiplica todos los costes por un factor
func scale(factor: float) -> ResourceBundle:
	var scaled = ResourceBundle.new()
	for res_id in costs.keys():
		scaled.add_cost(res_id, costs[res_id] * factor)
	return scaled


## Debug
func _to_string() -> String:
	if costs.is_empty():
		return "ResourceBundle(empty)"
	
	var parts = []
	for res_id in costs.keys():
		parts.append("%s: %s" % [res_id, snappedf(costs[res_id], 0.1)])
	
	return "ResourceBundle(%s)" % ", ".join(parts)
