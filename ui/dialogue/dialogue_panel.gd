extends CanvasLayer

# Exported configuration properties
@export var background_texture: Texture2D
@export var portrait_frame_texture: Texture2D
@export var option_button_scene: PackedScene
@export var text_color: Color = Color.WHITE
@export var text_font_size: int = 24
@export var speaker_name_color: Color = Color.YELLOW
@export var speaker_name_font_size: int = 20

# Node references (will be set up in scene)
@onready var portrait_left: TextureRect = %PortraitLeft
@onready var portrait_right: TextureRect = %PortraitRight
@onready var portrait_left_frame: Panel = %PortraitLeftFrame
@onready var portrait_right_frame: Panel = %PortraitRightFrame
@onready var speaker_name_label: Label = %SpeakerNameLabel
@onready var dialogue_text: RichTextLabel = %DialogueText
@onready var options_container: VBoxContainer = %OptionsContainer

# Internal state
var current_dialogue_id: String = ""
var current_node_id: String = ""
var current_speaker_id: String = ""
var current_options: Array = []
var option_buttons: Array = []


func _ready() -> void:
	# Connect to EventBus signals
	if EventBus:
		EventBus.dialogue_started.connect(_on_dialogue_started)
		EventBus.dialogue_node_shown.connect(_on_dialogue_node_shown)
		EventBus.dialogue_options_updated.connect(_on_dialogue_options_updated)
		EventBus.dialogue_ended.connect(_on_dialogue_ended)
	
		# Initially hide the panel
	visible = false


func _on_dialogue_started(dialogue_id: String) -> void:
	current_dialogue_id = dialogue_id
	visible = true


func _on_dialogue_node_shown(node_id: String, speaker_id: String, text_key: String, portrait_id: String = "") -> void:
	current_node_id = node_id
	current_speaker_id = speaker_id
	
	# Get the localized text
	var text = tr(text_key)
	dialogue_text.text = text
	
	# Get speaker name from localization
	var speaker_name_key = "SPEAKER_%s" % speaker_id.to_upper()
	speaker_name_label.text = tr(speaker_name_key)
	
	# Load and display portrait using portrait_id
	var portrait_to_load = portrait_id if portrait_id else speaker_id
	_load_portrait(portrait_to_load)
	
	# Clear previous options
	_clear_options()


func _on_dialogue_options_updated(options: Array) -> void:
	current_options = options
	_populate_options(options)


func _on_dialogue_ended(dialogue_id: String) -> void:
	current_dialogue_id = ""
	current_node_id = ""
	current_speaker_id = ""
	_clear_options()
	_clear_portraits()
	visible = false


# Load portrait from data/characters/portrait directory
func _load_portrait(speaker_id: String) -> void:
	var portrait_path = "res://data/characters/portrait/%s.png" % speaker_id

	print_debug("[DialoguePanel] Looking for portrait: %s" % portrait_path)
	var exists = ResourceLoader.exists(portrait_path)
	print_debug("[DialoguePanel] Resource exists: %s" % exists)

	if exists:
		var portrait_texture = load(portrait_path)
		print_debug("[DialoguePanel] Loaded portrait resource: %s" % typeof(portrait_texture))

		# Defer assignment until after the current frame so layout has been calculated
		call_deferred("_assign_portrait", portrait_texture)
	else:
		# Fallback: hide portraits if not found
		print_debug("Portrait not found at: %s" % portrait_path)
		_clear_portraits()


func _populate_options(options: Array) -> void:
	_clear_options()
	
	if not option_button_scene:
		push_error("Option button scene not set in DialoguePanel!")
		return
	
	for option in options:
		var button_instance = option_button_scene.instantiate()
		
		# Set button text from localization
		var option_text = tr(option.text_key)
		button_instance.text = option_text
		
		# Connect button pressed signal with option ID
		button_instance.pressed.connect(_on_option_button_pressed.bindv([option.id]))
		
		options_container.add_child(button_instance)
		option_buttons.append(button_instance)


func _on_option_button_pressed(option_id: String) -> void:
	if Dialogue:
		Dialogue.select_option(option_id)


func _clear_options() -> void:
	for button in option_buttons:
		button.queue_free()
	option_buttons.clear()


func _clear_portraits() -> void:
	portrait_left.texture = null
	portrait_right.texture = null
	portrait_left.hide()
	portrait_right.hide()
	portrait_left_frame.hide()
	portrait_right_frame.hide()


func _assign_portrait(portrait_texture: Texture2D) -> void:
	# Assign texture and ensure visibility and expand/stretch
	portrait_left.texture = portrait_texture
	portrait_left.visible = true
	portrait_left.show()
	portrait_left_frame.visible = true
	portrait_left_frame.show()

	# Ensure the right portrait is hidden for single-speaker nodes
	portrait_right.visible = false
	portrait_right.hide()
	portrait_right_frame.visible = false
	portrait_right_frame.hide()

	# If the TextureRect has zero size, set a sensible minimum and log
	var rect_size = portrait_left.get_size()
	print_debug("[DialoguePanel] Deferred Portrait TextureRect size: %s" % rect_size)
	if rect_size.x <= 0 or rect_size.y <= 0:
		portrait_left.custom_minimum_size = Vector2(150, 200)
		portrait_left_frame.custom_minimum_size = Vector2(150, 200)
		print_debug("[DialoguePanel] Set custom minimum size for portrait TextureRect to (150,200)")
