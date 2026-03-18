class_name DialogueSystem
extends Node

## DialogueSystem - Gestor de ejecución de diálogos
## Singleton: /root/Dialogue
##
## Responsabilidad: Ejecutar diálogos, mostrar nodos, procesar opciones
## - Mantiene estado del diálogo activo
## - Evalúa condiciones narrativas
## - Dispara eventos narrativos
## - Emite señales para UI

## Estado del diálogo actual
var _current_dialogue: DialogueDefinition = null
var _current_node: DialogueNodeDefinition = null
var _is_active: bool = false


func _ready():
	print("[DialogueSystem] Initialized - Passive dialogue executor ready")


# ==============================================
# CONTROL DE DIÁLOGO
# ==============================================

## Inicia un diálogo
func start_dialogue(dialogue_id: String) -> bool:
	# Verificar que existe el diálogo
	var dialogue = DialogueDB.get_dialogue(dialogue_id)
	if not dialogue:
		push_error("[DialogueSystem] Dialogue not found: %s" % dialogue_id)
		return false
	
	# Verificar que no hay diálogo activo
	if _is_active:
		push_warning("[DialogueSystem] Dialogue already active, ending it first")
		end_dialogue()
	
	# Iniciar diálogo
	_current_dialogue = dialogue
	_current_node = dialogue.get_first_node()
	_is_active = true
	
	# Emitir evento
	EventBus.dialogue_started.emit(dialogue_id)
	print("[DialogueSystem] Started dialogue: %s" % dialogue_id)
	
	# Mostrar primer nodo
	_show_current_node()
	
	return true


## Termina el diálogo actual
func end_dialogue() -> void:
	if not _is_active:
		return
	
	var dialogue_id = _current_dialogue.id if _current_dialogue else "UNKNOWN"
	
	# Limpiar estado
	_current_dialogue = null
	_current_node = null
	_is_active = false
	
	# Emitir evento
	EventBus.dialogue_ended.emit(dialogue_id)
	print("[DialogueSystem] Ended dialogue: %s" % dialogue_id)


## ¿Hay un diálogo activo?
func is_active() -> bool:
	return _is_active


## Obtiene el ID del diálogo actual
func get_current_dialogue_id() -> String:
	if _current_dialogue:
		return _current_dialogue.id
	return ""


## Obtiene el ID del nodo actual
func get_current_node_id() -> String:
	if _current_node:
		return _current_node.id
	return ""


# ==============================================
# NAVEGACIÓN DE NODOS
# ==============================================

## Muestra el nodo actual
func _show_current_node() -> void:
	if not _current_node:
		push_error("[DialogueSystem] No current node to show")
		return
	
	# Emitir evento de nodo mostrado
	EventBus.dialogue_node_shown.emit(
		_current_node.id,
		_current_node.speaker_id,
		_current_node.text_key,
		_current_node.portrait_id
	)
	
	print("[DialogueSystem] Showing node: %s (speaker: %s)" % [
		_current_node.id,
		_current_node.speaker_id
	])
	
	# Obtener opciones disponibles
	var available_options = _current_node.get_available_options()
	
	# Emitir evento de opciones actualizadas
	var options_data = []
	for option in available_options:
		options_data.append({
			"id": option.id,
			"text_key": option.text_key,
			"ends_dialogue": option.ends_dialogue()
		})
	
	EventBus.dialogue_options_updated.emit(options_data)
	print("[DialogueSystem] Available options: %d" % available_options.size())


## Navega a un nodo específico
func go_to_node(node_id: String) -> bool:
	if not _is_active:
		push_error("[DialogueSystem] No active dialogue")
		return false
	
	if not _current_dialogue:
		push_error("[DialogueSystem] No current dialogue")
		return false
	
	var node = _current_dialogue.get_node(node_id)
	if not node:
		push_error("[DialogueSystem] Node not found: %s" % node_id)
		return false
	
	_current_node = node
	_show_current_node()
	
	return true


# ==============================================
# SELECCIÓN DE OPCIONES
# ==============================================

## Selecciona una opción
func select_option(option_id: String) -> bool:
	if not _is_active:
		push_error("[DialogueSystem] No active dialogue")
		return false
	
	if not _current_node:
		push_error("[DialogueSystem] No current node")
		return false
	
	# Obtener la opción
	var option = _current_node.get_option(option_id)
	if not option:
		push_error("[DialogueSystem] Option not found: %s" % option_id)
		return false
	
	# Verificar disponibilidad
	if not option.is_available():
		push_warning("[DialogueSystem] Option not available: %s" % option_id)
		return false
	
	# Emitir evento de selección
	EventBus.dialogue_option_selected.emit(_current_node.id, option_id)
	print("[DialogueSystem] Selected option: %s" % option_id)
	
	# Disparar eventos narrativos
	_trigger_narrative_events(option.narrative_events)
	
	# Navegar al siguiente nodo o terminar
	if option.ends_dialogue():
		end_dialogue()
		return true
	
	return go_to_node(option.next_node_id)


## Dispara eventos narrativos de una opción
func _trigger_narrative_events(event_ids: Array[String]) -> void:
	if event_ids.is_empty():
		return
	
	print("[DialogueSystem] Triggering %d narrative events" % event_ids.size())
	
	for event_id in event_ids:
		Narrative.apply_event(event_id)


# ==============================================
# CONSULTAS DE ESTADO
# ==============================================

## Obtiene las opciones disponibles del nodo actual
func get_available_options() -> Array[DialogueOptionDefinition]:
	if not _current_node:
		return []
	
	return _current_node.get_available_options()


## Obtiene información del nodo actual
func get_current_node_info() -> Dictionary:
	if not _current_node:
		return {}
	
	return {
		"id": _current_node.id,
		"speaker_id": _current_node.speaker_id,
		"text_key": _current_node.text_key,
		"portrait_id": _current_node.portrait_id,
		"options_count": _current_node.options.size()
	}


## Obtiene el speaker del nodo actual
func get_current_speaker() -> String:
	if _current_node:
		return _current_node.speaker_id
	return ""


## Obtiene el text_key del nodo actual
func get_current_text_key() -> String:
	if _current_node:
		return _current_node.text_key
	return ""

## Obtiene el portrait del nodo actual
func get_current_portrait_id() -> String:
	if _current_node:
		return _current_node.portrait_id
	return ""

# ==============================================
# DEBUG
# ==============================================

## Imprime el estado actual del diálogo
func print_state() -> void:
	print("\n[DialogueSystem] Current State:")
	print("  Active: %s" % _is_active)
	
	if _is_active:
		print("  Dialogue: %s" % get_current_dialogue_id())
		print("  Node: %s" % get_current_node_id())
		print("  Speaker: %s" % get_current_speaker())
		print("  Available options: %d" % get_available_options().size())
	
	print("")


## Reinicia el sistema (debug)
func reset() -> void:
	if _is_active:
		end_dialogue()
	
	_current_dialogue = null
	_current_node = null
	_is_active = false
	
	print("[DialogueSystem] Reset complete")
