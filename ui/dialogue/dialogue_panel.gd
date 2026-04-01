extends CanvasLayer

## DialoguePanel — View
##
## Renderiza el estado expuesto por DialogueViewModel.
## No accede a DialogueSystem ni EventBus directamente.


# ============================================
# EXPORTS (configuración visual — se mantienen)
# ============================================

@export var background_texture:      Texture2D
@export var portrait_frame_texture:  Texture2D
@export var option_button_scene:     PackedScene
@export var text_color:              Color = Color.WHITE
@export var text_font_size:          int   = 24
@export var speaker_name_color:      Color = Color.YELLOW
@export var speaker_name_font_size:  int   = 20


# ============================================
# NODOS
# ============================================

@onready var portrait_left:        TextureRect  = %PortraitLeft
@onready var portrait_right:       TextureRect  = %PortraitRight
@onready var portrait_left_frame:  Panel        = %PortraitLeftFrame
@onready var portrait_right_frame: Panel        = %PortraitRightFrame
@onready var speaker_name_label:   Label        = %SpeakerNameLabel
@onready var dialogue_text:        RichTextLabel = %DialogueText
@onready var options_container:    VBoxContainer = %OptionsContainer


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
		"options":
			_render_options()
		"closed":
			_clear_options()
			_clear_portraits()
			visible = false
		_:
			push_warning("[DialoguePanel] Razón desconocida: %s" % reason)


# ============================================
# RENDERS
# ============================================

func _render_node() -> void:
	dialogue_text.text    = _vm.dialogue_text
	speaker_name_label.text = _vm.speaker_name
	_clear_options()

	if _vm.portrait_path.is_empty():
		_clear_portraits()
	else:
		var texture := load(_vm.portrait_path) as Texture2D
		if texture:
			call_deferred("_assign_portrait", texture)
		else:
			_clear_portraits()


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


func _clear_portraits() -> void:
	portrait_left.texture  = null
	portrait_right.texture = null
	portrait_left.hide()
	portrait_right.hide()
	portrait_left_frame.hide()
	portrait_right_frame.hide()


func _assign_portrait(texture: Texture2D) -> void:
	portrait_left.texture  = texture
	portrait_left.visible  = true
	portrait_left_frame.visible = true

	portrait_right.visible = false
	portrait_right_frame.visible = false

	# Tamaño mínimo si el layout aún no ha calculado el rect
	if portrait_left.get_size().x <= 0:
		portrait_left.custom_minimum_size       = Vector2(150, 200)
		portrait_left_frame.custom_minimum_size = Vector2(150, 200)
