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

## Path del fondo de ambiente del panel (Spike 11), o "" si no hay para
## esta aventura — el panel cae entonces al color plano (decisión 3).
var background_path: String = ""

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
		portrait_id: String = "",
		mood: String = "neutral",
		portrait_folder: String = "",
		background_id: String = "") -> void:

	node_id       = p_node_id
	dialogue_text = tr(text_key)
	speaker_name  = tr("SPEAKER_%s" % speaker_id.to_upper())
	portrait_path = _resolve_portrait(portrait_id if not portrait_id.is_empty() else speaker_id, mood, portrait_folder)

	# El fondo de ambiente es por aventura, no por nodo — solo se emite un
	# "background" cuando cambia, para no recargar la textura en cada línea.
	var new_background_path := _resolve_background(portrait_folder, background_id)
	if new_background_path != background_path:
		background_path = new_background_path
		changed.emit("background")

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
	background_path = ""
	options.clear()
	state = DialogueState.HIDDEN
	changed.emit("closed")


# ============================================
# HELPERS
# ============================================

## Resuelve el retrato para (speaker_id, mood) con respaldo a neutral:
##   1) "<speaker_id>_<mood>.png"        (mood != "" y != "neutral")
##   2) "<speaker_id>.png"               (neutral, o respaldo de 1)
## Si ninguna existe, avisa con push_warning (antes fallaba en silencio)
## y el panel se queda sin retrato para ese nodo.
func _resolve_portrait(speaker_id: String, mood: String = "neutral", portrait_folder: String = "") -> String:
	var folder := (portrait_folder + "/") if not portrait_folder.is_empty() else ""

	if not mood.is_empty() and mood != "neutral":
		var mood_path := "res://data/characters/portrait/%s%s_%s.png" % [folder, speaker_id, mood]
		if ResourceLoader.exists(mood_path):
			return mood_path
		push_warning("[DialogueViewModel] Falta retrato '%s' para mood '%s' — usando neutral" % [speaker_id, mood])

	var neutral_path := "res://data/characters/portrait/%s%s.png" % [folder, speaker_id]
	if ResourceLoader.exists(neutral_path):
		return neutral_path

	push_warning("[DialogueViewModel] Falta retrato neutral para '%s' — sin retrato" % speaker_id)
	return ""


## Resuelve el fondo de ambiente del panel para esta aventura (Spike 11).
## Una imagen por portrait_folder, no por diálogo ni por nodo. Sin
## portrait_folder o sin archivo, respaldo silencioso salvo warning — el
## panel cae al color plano (decisión 3: no depende de lo que haya detrás).
func _resolve_background(portrait_folder: String, background_id: String = "") -> String:
	if portrait_folder.is_empty():
		return ""

	if not background_id.is_empty():
		var scene_path := "res://data/dialogue/backgrounds/%s/%s.png" % [portrait_folder, background_id]
		if ResourceLoader.exists(scene_path):
			return scene_path
		push_warning("[DialogueViewModel] Falta fondo '%s' para escena '%s' — usando el de aventura" % [portrait_folder, background_id])

	var path := "res://data/dialogue/backgrounds/%s.png" % portrait_folder
	if ResourceLoader.exists(path):
		return path

	push_warning("[DialogueViewModel] Falta fondo de ambiente para '%s' — panel en color plano" % portrait_folder)
	return ""
