class_name DialogueViewModel
extends Node

## DialogueViewModel
## Gestiona el estado de la pantalla de diálogo.
##
## Responsabilidades:
##   - Mantener estado explícito (enum DialogueState)
##   - Escuchar señales del EventBus y construir datos listos para renderizar
##   - Resolver path de portrait y verificar existencia
##   - Exponer opciones disponibles
##
## NO hace:
##   - Renderizar nada
##   - Instanciar nodos
##   - Llamar a Dialogue.select_option() directamente (eso es una intención)


# ============================================
# ENUM
# ============================================

enum DialogueState {
	HIDDEN,    ## Panel cerrado
	SHOWING,   ## Nodo de diálogo activo, sin opciones aún
	OPTIONS,   ## Opciones disponibles para el jugador
}


# ============================================
# SEÑAL HACIA LA VIEW
# ============================================

## Razones:
##   "opened"   → mostrar panel, renderizar nodo inicial
##   "node"     → nuevo nodo de diálogo (texto + portrait)
##   "options"  → opciones disponibles actualizadas
##   "closed"   → ocultar panel
signal changed(reason: String)


# ============================================
# ESTADO PÚBLICO
# ============================================

var state: DialogueState = DialogueState.HIDDEN

var dialogue_id:  String = ""
var node_id:      String = ""
var speaker_name: String = ""
var dialogue_text: String = ""

## Path de portrait listo para cargar, o "" si no existe
var portrait_path: String = ""

## Opciones disponibles (Array[DialogueOptionDefinition] o similares)
var options: Array = []


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_node_shown.connect(_on_dialogue_node_shown)
	EventBus.dialogue_options_updated.connect(_on_dialogue_options_updated)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)
	print("[DialogueVM] Ready")


# ============================================
# INTENCIONES
# ============================================

func select_option(option_id: String) -> void:
	if state != DialogueState.OPTIONS:
		return
	Dialogue.select_option(option_id)


# ============================================
# CALLBACKS DEL EVENTBUS
# ============================================

func _on_dialogue_started(p_dialogue_id: String) -> void:
	dialogue_id = p_dialogue_id
	options.clear()
	state = DialogueState.SHOWING
	changed.emit("opened")


func _on_dialogue_node_shown(
		p_node_id: String,
		speaker_id: String,
		text_key: String,
		portrait_id: String = "") -> void:

	node_id       = p_node_id
	dialogue_text = tr(text_key)
	speaker_name  = tr("SPEAKER_%s" % speaker_id.to_upper())
	portrait_path = _resolve_portrait(portrait_id if not portrait_id.is_empty() else speaker_id)
	options.clear()
	state = DialogueState.SHOWING
	changed.emit("node")


func _on_dialogue_options_updated(p_options: Array) -> void:
	options = p_options
	state   = DialogueState.OPTIONS
	changed.emit("options")


func _on_dialogue_ended(_p_dialogue_id: String) -> void:
	dialogue_id   = ""
	node_id       = ""
	speaker_name  = ""
	dialogue_text = ""
	portrait_path = ""
	options.clear()
	state = DialogueState.HIDDEN
	changed.emit("closed")


# ============================================
# HELPERS
# ============================================

func _resolve_portrait(speaker_id: String) -> String:
	var path := "res://data/characters/portrait/%s.png" % speaker_id
	if ResourceLoader.exists(path):
		return path
	return ""
