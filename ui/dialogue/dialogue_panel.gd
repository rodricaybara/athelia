extends CanvasLayer
signal closed
## DialoguePanel — View
##
## Renderiza el estado expuesto por DialogueViewModel.
## No accede a DialogueSystem ni EventBus directamente.
##
## Spike 11 — rediseño (fondo propio, marco Spike 9, retrato único del NPC):
## base pasa de PanelContainer plano a UIPanel (decorative_frame = true).
## Único retrato (se descarta el layout de dos retratos original) que vive
## como hermano del panel, no como hijo — así puede sobresalir por encima
## del borde superior (layout C de la maqueta). Exports de configuración
## visual sin efecto real retirados: background_texture, portrait_frame_texture,
## text_color, text_font_size, speaker_name_color, speaker_name_font_size.


# ============================================
# EXPORTS
# ============================================

@export var option_button_scene: PackedScene

## Opacidad del velo (Background) cuando hay imagen de fondo (BackgroundImage)
## detrás. Valor de partida, sin calibrar contra el arte real — misma
## lección que el velo 0.2 de los mapas de combate (Grupo 4): se ajusta
## mirando el resultado generado, no a priori.
const SCRIM_ALPHA_WITH_IMAGE := 0.55


# ============================================
# NODOS
# ============================================

@onready var background:         ColorRect     = %Background
@onready var background_image:   TextureRect   = %BackgroundImage
@onready var panel:              UIPanel       = %Panel
@onready var portrait:           TextureRect   = %Portrait
@onready var speaker_name_label: Label         = %SpeakerNameLabel
@onready var dialogue_text:      RichTextLabel = %DialogueText
@onready var options_container:  VBoxContainer = %OptionsContainer


# ============================================
# ESTADO INTERNO
# ============================================

var _vm: DialogueViewModel = null
var _option_buttons: Array = []


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	visible = false

	# Fondo propio del panel (decisión 3 del spec): no puede depender de lo
	# que haya detrás — abierto desde exploración solo hay gris plano detrás.
	# Color desde tokens, no literal en el .tscn.
	background.color = UITokens.COLOR_BG

	_vm = DialogueViewModel.new()
	_vm.name = "ViewModel"
	add_child(_vm)
	_vm.changed.connect(_on_vm_changed)

	print("[DialoguePanel] Ready")


# ============================================
# CALLBACK ÚNICO DEL VIEWMODEL
# ============================================

func _on_vm_changed(reason: String) -> void:
	match reason:
		"opened":
			visible = true
		"node":
			_render_node()
		"background":
			_render_background()
		"options":
			_render_options()
		"closed":
			_clear_options()
			_clear_portrait()
			visible = false
			closed.emit()
		_:
			push_warning("[DialoguePanel] Razón desconocida: %s" % reason)


# ============================================
# RENDERS
# ============================================

## Fondo de ambiente del panel (Spike 11) — una imagen por aventura detrás
## de un velo, o color plano si no hay (ver DialogueViewModel._resolve_background).
func _render_background() -> void:
	if _vm.background_path.is_empty():
		_clear_background()
		return

	var texture := load(_vm.background_path) as Texture2D
	if texture:
		_assign_background(texture)
	else:
		_clear_background()


func _render_node() -> void:
	dialogue_text.text      = _vm.dialogue_text
	speaker_name_label.text = _vm.speaker_name
	_clear_options()

	if _vm.portrait_path.is_empty():
		_clear_portrait()
	else:
		var texture := load(_vm.portrait_path) as Texture2D
		if texture:
			_assign_portrait(texture)
		else:
			_clear_portrait()


func _render_options() -> void:
	_clear_options()

	if not option_button_scene:
		push_error("[DialoguePanel] option_button_scene no asignado")
		return

	for option in _vm.options:
		var btn := option_button_scene.instantiate()
		btn.text = tr(option.text_key)
		btn.pressed.connect(func(): _vm.select_option(option.id))
		options_container.add_child(btn)
		_option_buttons.append(btn)


# ============================================
# UTILIDADES
# ============================================

func _clear_options() -> void:
	for btn in _option_buttons:
		btn.queue_free()
	_option_buttons.clear()


## Sin retrato disponible, el panel de texto ocupa todo el ancho (decisión
## de la Fase 1 del spec) — el propio Panel no cambia de tamaño, es el
## MarginContainer/margin_left el que deja o no hueco para el retrato.
func _clear_portrait() -> void:
	portrait.texture = null
	portrait.hide()
	panel.get_node("MarginContainer").add_theme_constant_override("margin_left", 0)


func _assign_portrait(texture: Texture2D) -> void:
	portrait.texture = texture
	portrait.visible = true
	panel.get_node("MarginContainer").add_theme_constant_override("margin_left", 240)


## Sin imagen de ambiente, el panel se queda en el color plano opaco de
## siempre (decisión 3: no depende de lo que haya detrás).
func _clear_background() -> void:
	background_image.texture = null
	background_image.hide()
	background.color.a = 1.0


func _assign_background(texture: Texture2D) -> void:
	background_image.texture = texture
	background_image.visible = true
	# Velo semitransparente sobre la imagen para separar el panel del fondo,
	# no para dar legibilidad al texto — el propio Panel ya pinta su stylebox
	# opaco encima, independiente de lo que haya en Background/BackgroundImage.
	background.color.a = SCRIM_ALPHA_WITH_IMAGE
