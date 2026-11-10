class_name OptionsPanel
extends UIPanel

## OptionsPanel — Ventana de opciones reutilizable (Spike 23).
##
## Idioma y pantalla completa (persistentes). Los sliders de volumen existen en
## la escena pero están ocultos: ver SHOW_VOLUME_SLIDERS.
##
## No se libera a sí misma ni maneja Esc: emite `closed` y quien la instancia
## decide (hoy MainMenuScreen; mañana, un menú de pausa). Cambiar de idioma
## retraduce todo sin cerrar el panel.
##
## Contrato: el ViewModel es hijo; la View nunca toca AudioServer, DisplayServer
## ni TranslationServer.

signal closed

## PENDIENTE (audio): no hay audio diseñado ni buses "Music"/"SFX", así que los
## sliders no controlarían nada. Poner a true cuando exista el audio y darles
## estilo (hoy tendrían el aspecto por defecto de Godot).
const SHOW_VOLUME_SLIDERS: bool = false

const WIDTH_FRACTION: float = 0.5
const MAX_WIDTH: float = 620.0

@onready var title_label: Label = %TitleLabel
@onready var divider: ColorRect = %Divider
@onready var fullscreen_label: Label = %FullscreenLabel
@onready var fullscreen_on_button: UIButton = %FullscreenOnButton
@onready var fullscreen_off_button: UIButton = %FullscreenOffButton
@onready var language_label: Label = %LanguageLabel
@onready var language_button_0: UIButton = %LanguageButton0
@onready var language_button_1: UIButton = %LanguageButton1
@onready var volume_box: VBoxContainer = %VolumeBox
@onready var music_label: Label = %MusicLabel
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_label: Label = %SfxLabel
@onready var sfx_slider: HSlider = %SfxSlider
@onready var back_button: UIButton = %BackButton

var _vm: OptionsViewModel = null
var _language_buttons: Array[UIButton] = []


func _ready() -> void:
	super._ready()

	_vm = OptionsViewModel.new()
	_vm.name = "ViewModel"
	add_child(_vm)
	_vm.changed.connect(_on_vm_changed)

	_language_buttons = [language_button_0, language_button_1]

	fullscreen_on_button.pressed.connect(func(): _vm.request_set_fullscreen(true))
	fullscreen_off_button.pressed.connect(func(): _vm.request_set_fullscreen(false))
	language_button_0.pressed.connect(_on_language_pressed.bind(0))
	language_button_1.pressed.connect(_on_language_pressed.bind(1))
	back_button.pressed.connect(func(): _vm.request_close())

	music_slider.value_changed.connect(func(v: float): _vm.request_set_music_volume(v))
	sfx_slider.value_changed.connect(func(v: float): _vm.request_set_sfx_volume(v))
	for slider: HSlider in [music_slider, sfx_slider]:
		slider.drag_ended.connect(func(_changed: bool): _vm.request_commit_volumes())
		slider.focus_exited.connect(func(): _vm.request_commit_volumes())

	_apply_static_style()
	volume_box.visible = SHOW_VOLUME_SLIDERS

	get_viewport().size_changed.connect(_update_rect)
	_render_texts()
	_update_rect()


func _notification(what: int) -> void:
	# Al cambiar el idioma se retraducen todos los textos, también con el
	# panel oculto.
	if what == NOTIFICATION_TRANSLATION_CHANGED and _vm != null:
		_render_texts()


# ============================================
# API PÚBLICA
# ============================================

## Lee el estado real y se prepara para mostrarse. El que la instancia pone
## visible = true.
func open() -> void:
	_vm.open()
	_update_rect()


## Foco inicial: el botón de pantalla completa que corresponde al estado actual.
func focus_first() -> void:
	var target: UIButton = fullscreen_on_button if _vm.fullscreen else fullscreen_off_button
	target.grab_focus()


# ============================================
# CALLBACK DEL VIEWMODEL
# ============================================

func _on_vm_changed(reason: String) -> void:
	match reason:
		"opened":
			_render_texts()
			_render_fullscreen()
			_render_language()
			_render_volume()
		"fullscreen":
			_render_fullscreen()
		"language":
			_render_language()
		"volume":
			_render_volume()
		"closed":
			closed.emit()
		_:
			push_warning("[OptionsPanel] Razón desconocida: %s" % reason)


func _on_language_pressed(index: int) -> void:
	if index < _vm.languages.size():
		_vm.request_set_language(str(_vm.languages[index]["code"]))


# ============================================
# RENDERS
# ============================================

func _render_texts() -> void:
	title_label.text = tr("OPTIONS_TITLE")
	fullscreen_label.text = tr("OPTIONS_FULLSCREEN")
	fullscreen_on_button.text = tr("OPTIONS_FULLSCREEN_ON")
	fullscreen_off_button.text = tr("OPTIONS_FULLSCREEN_OFF")
	language_label.text = tr("OPTIONS_LANGUAGE")
	music_label.text = tr("OPTIONS_MUSIC_VOLUME")
	sfx_label.text = tr("OPTIONS_SFX_VOLUME")
	back_button.text = tr("OPTIONS_BACK")
	for i in _language_buttons.size():
		if i < _vm.languages.size():
			_language_buttons[i].text = str(_vm.languages[i]["name"])


func _render_fullscreen() -> void:
	_set_selected(fullscreen_on_button, _vm.fullscreen)
	_set_selected(fullscreen_off_button, not _vm.fullscreen)


func _render_language() -> void:
	for i in _language_buttons.size():
		var is_current: bool = i < _vm.languages.size() \
			and str(_vm.languages[i]["code"]) == _vm.language_code
		_set_selected(_language_buttons[i], is_current)


func _render_volume() -> void:
	music_slider.set_value_no_signal(_vm.music_volume)
	sfx_slider.set_value_no_signal(_vm.sfx_volume)


## Botón segmentado: el seleccionado es PRIMARY, el resto SECONDARY.
func _set_selected(button: UIButton, selected: bool) -> void:
	button.set_variant(UIButton.Variant.PRIMARY if selected else UIButton.Variant.SECONDARY)


# ============================================
# ESTILO Y LAYOUT
# ============================================

func _apply_static_style() -> void:
	title_label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_TITLE)
	title_label.add_theme_color_override("font_color", UITokens.COLOR_TEXT)
	divider.color = UITokens.BORDER_DEFAULT
	for label: Label in [fullscreen_label, language_label, music_label, sfx_label]:
		label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_LG)
		label.add_theme_color_override("font_color", UITokens.COLOR_TEXT)


## Centrada, ancho = fracción de la pantalla con tope; el alto lo da el contenido.
func _update_rect() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	custom_minimum_size.x = minf(screen.x * WIDTH_FRACTION, MAX_WIDTH)
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
