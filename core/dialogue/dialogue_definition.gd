class_name DialogueDefinition
extends Resource

## DialogueDefinition - Definición completa de un diálogo
##
## Contiene todos los nodos que componen un diálogo

## Identificador único del diálogo
@export var id: String = ""

## Nodos del diálogo
var nodes: Array[DialogueNodeDefinition] = []


## Valida que la definición sea coherente
func validate() -> bool:
	if id.is_empty():
		push_error("[DialogueDefinition] id cannot be empty")
		return false
	
	if nodes.is_empty():
		push_error("[DialogueDefinition] Dialogue must have at least one node")
		return false
	
	# Validar todos los nodos
	for node in nodes:
		if not node.validate():
			push_error("[DialogueDefinition] Invalid node in dialogue %s" % id)
			return false
	
	return true


## Obtiene un nodo por ID
func get_node(node_id: String) -> DialogueNodeDefinition:
	for node in nodes:
		if node.id == node_id:
			return node
	
	return null


## Obtiene el primer nodo (nodo inicial)
func get_first_node() -> DialogueNodeDefinition:
	if nodes.is_empty():
		return null
	
	return nodes[0]


## ¿Tiene un nodo con este ID?
func has_node(node_id: String) -> bool:
	return get_node(node_id) != null


## Debug
func _to_string() -> String:
	return "Dialogue(id=%s, nodes=%d)" % [id, nodes.size()]
