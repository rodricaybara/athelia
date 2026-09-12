extends CanvasLayer
class_name NarrativeScenePanel

## NarrativeScenePanel — Spike 1: Motor Narrativo Base
##
## View del panel narrativo. Contrato estándar del proyecto:
## %UniqueNames sobre el .tscn, textos siempre vía tr(), cero acceso a
## sistemas core (Characters, Narrative, GameLoop...) — todo pasa por
## el ViewModel. Ver estructura de nodos recomendada en la entrega del spike.
##
## Todo botón de opción usa UIButton (Design System) — nunca Button "raw".

@onready var scene_image: TextureRect = %SceneImage
@onready var scene_text: Label = %SceneText
@onready var options_container: VBoxContainer = %OptionsContainer

const UI_BUTTON_SCENE := "res://ui/design_system/components/ui_button/ui_button.tscn"

var _vm: NarrativeSceneViewModel = null


func _ready() -> void:
	visible = false

	_vm = NarrativeSceneViewModel.new()
	_vm.name = "ViewModel"
	add_child(_vm)
	_vm.changed.connect(_on_vm_changed)


## API pública — llamada desde SceneOrchestrator.
func open(scene_id: String) -> void:
	visible = true
	_vm.open(scene_id)


func _on_vm_changed(reason: String) -> void:
	match reason:
		"opened", "node_changed":
			_render_node()
		"closed":
			visible = false
		_:
			push_warning("[NarrativeScenePanel] Razón desconocida: %s" % reason)


func _render_node() -> void:
	var node := _vm.current_node
	if not node:
		push_error("[NarrativeScenePanel] _render_node: current_node es null")
		return

	if not node.image_path.is_empty():
		scene_image.texture = load(node.image_path)
	else:
		scene_image.texture = null

	scene_text.text = tr(node.text_key)

	_render_options(node.options)


func _render_options(options: Array[NarrativeSceneOption]) -> void:
	_clear_options()
	for option in options:
		options_container.add_child(_instantiate_option_button(option))


func _clear_options() -> void:
	for child in options_container.get_children():
		child.queue_free()


func _instantiate_option_button(option: NarrativeSceneOption) -> Button:
	var button_scene: PackedScene = preload(UI_BUTTON_SCENE)
	var button: Button = button_scene.instantiate()
	button.text = tr(option.text_key)
	button.pressed.connect(func(): _vm.request_option(option.option_id))
	return button
