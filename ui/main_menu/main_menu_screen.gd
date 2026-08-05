class_name MainMenuScreen
extends CanvasLayer

## MainMenuScreen — View del menú principal
## Sigue el contrato MVVM: nunca accede a sistemas core directamente.
## Toda lógica pasa por MainMenuViewModel.

# ============================================
# NODOS — @onready desde el .tscn
# ============================================

@onready var main_panel: VBoxContainer   = %MainPanel
@onready var btn_new_game: Button        = %BtnNewGame
@onready var btn_load_game: Button       = %BtnLoadGame
@onready var btn_options: Button         = %BtnOptions
@onready var btn_credits: Button         = %BtnCredits
@onready var btn_quit: Button            = %BtnQuit

@onready var options_panel: PanelContainer  = %OptionsPanel
@onready var lbl_options_title: Label       = %LblOptionsTitle
@onready var lbl_music_vol: Label           = %LblMusicVol
@onready var slider_music_vol: HSlider      = %SliderMusicVol
@onready var lbl_sfx_vol: Label             = %LblSfxVol
@onready var slider_sfx_vol: HSlider        = %SliderSfxVol
@onready var lbl_fullscreen: Label          = %LblFullscreen
@onready var chk_fullscreen: CheckButton    = %ChkFullscreen
@onready var lbl_language: Label            = %LblLanguage
@onready var opt_language: OptionButton     = %OptLanguage
@onready var btn_options_back: Button       = %BtnOptionsBack

@onready var credits_panel: PanelContainer  = %CreditsPanel
@onready var lbl_credits_title: Label       = %LblCreditsTitle
@onready var credits_label: Label           = %CreditsLabel
@onready var btn_credits_back: Button       = %BtnCreditsBack

@onready var confirm_quit_panel: PanelContainer = %ConfirmQuitPanel
@onready var lbl_confirm_text: Label            = %LblConfirmText
@onready var btn_confirm_yes: Button            = %BtnConfirmYes
@onready var btn_confirm_no: Button             = %BtnConfirmNo

# ============================================
# VIEWMODEL
# ============================================

var _vm: MainMenuViewModel = null

# Timer para feedback temporal de "load_blocked"
var _feedback_timer: SceneTreeTimer = null

# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	# Crear ViewModel como hijo
	_vm = MainMenuViewModel.new()
	_vm.name = "ViewModel"
	add_child(_vm)
	_vm.changed.connect(_on_vm_changed)

	# Conectar botones del panel principal
	btn_new_game.pressed.connect(func(): _vm.request_new_game())
	btn_load_game.pressed.connect(func(): _vm.request_load_game())
	btn_options.pressed.connect(func(): _vm.request_options())
	btn_credits.pressed.connect(func(): _vm.request_credits())
	btn_quit.pressed.connect(func(): _vm.request_quit())

	# Conectar botones de sub-paneles
	btn_options_back.pressed.connect(func(): _vm.request_back())
	btn_credits_back.pressed.connect(func(): _vm.request_back())
	btn_confirm_yes.pressed.connect(func(): _vm.confirm_quit())
	btn_confirm_no.pressed.connect(func(): _vm.request_back())

	# Conectar opciones
	slider_music_vol.value_changed.connect(_on_music_vol_changed)
	slider_sfx_vol.value_changed.connect(_on_sfx_vol_changed)
	chk_fullscreen.toggled.connect(_on_fullscreen_toggled)
	opt_language.item_selected.connect(_on_language_selected)

	# Inicializar textos estáticos
	_setup_static_text()

	# Inicializar opciones con valores actuales del sistema
	_setup_options_initial_values()

	# Abrir el menú
	_vm.open()


# ============================================
# CALLBACK DEL VIEWMODEL
# ============================================

func _on_vm_changed(reason: String) -> void:
	match reason:
		"main":
			_render_main()
		"options":
			_render_options()
		"credits":
			_render_credits()
		"confirm_quit":
			_render_confirm_quit()
		"transitioning":
			_render_transitioning()
		"load_blocked":
			_render_load_blocked()
		"hidden":
			_render_hidden()
		_:
			push_warning("[MainMenuScreen] Razón desconocida: %s" % reason)


# ============================================
# RENDERS
# ============================================

func _render_main() -> void:
	visible = true
	main_panel.visible      = true
	options_panel.visible   = false
	credits_panel.visible   = false
	confirm_quit_panel.visible = false
	_set_main_buttons_enabled(true)

	# Habilitar/deshabilitar "Cargar Partida" según save existente
	btn_load_game.disabled = not _vm.has_save

	# Mostrar timestamp del save en el botón si existe
	if _vm.has_save and not _vm.save_info.is_empty():
		var timestamp: String = _vm.save_info.get("timestamp", "")
		btn_load_game.text = tr("MENU_LOAD_GAME") + "\n" + timestamp
	else:
		btn_load_game.text = tr("MENU_LOAD_GAME")


func _render_options() -> void:
	main_panel.visible         = false
	options_panel.visible      = true
	credits_panel.visible      = false
	confirm_quit_panel.visible = false


func _render_credits() -> void:
	main_panel.visible         = false
	options_panel.visible      = false
	credits_panel.visible      = true
	confirm_quit_panel.visible = false


func _render_confirm_quit() -> void:
	options_panel.visible      = false
	credits_panel.visible      = false
	confirm_quit_panel.visible = true
	_set_main_buttons_enabled(false)


func _render_transitioning() -> void:
	_set_main_buttons_enabled(false)


func _render_hidden() -> void:
	visible = false


func _render_load_blocked() -> void:
	btn_load_game.disabled = true
	btn_load_game.text = tr("MENU_NO_SAVE_FOUND")

	if _feedback_timer and is_instance_valid(_feedback_timer):
		_feedback_timer.timeout.disconnect(_restore_load_button)

	_feedback_timer = get_tree().create_timer(2.0)
	_feedback_timer.timeout.connect(_restore_load_button)


func _restore_load_button() -> void:
	btn_load_game.disabled = true
	btn_load_game.text = tr("MENU_LOAD_GAME")


# ============================================
# SETUP INICIAL
# ============================================

func _setup_static_text() -> void:
	# Panel principal
	btn_new_game.text  = tr("MENU_NEW_GAME")
	btn_load_game.text = tr("MENU_LOAD_GAME")
	btn_options.text   = tr("MENU_OPTIONS")
	btn_credits.text   = tr("MENU_CREDITS")
	btn_quit.text      = tr("MENU_QUIT")

	# Panel opciones
	lbl_options_title.text = tr("MENU_OPTIONS_TITLE")
	lbl_music_vol.text     = tr("MENU_MUSIC_VOL")
	lbl_sfx_vol.text       = tr("MENU_SFX_VOL")
	lbl_fullscreen.text    = tr("MENU_FULLSCREEN")
	lbl_language.text      = tr("MENU_LANGUAGE")
	btn_options_back.text  = tr("MENU_BACK")

	# Panel créditos
	lbl_credits_title.text = tr("MENU_CREDITS_TITLE")
	credits_label.text     = tr("CREDITS_BODY")
	btn_credits_back.text  = tr("MENU_BACK")

	# Panel confirmación salida
	lbl_confirm_text.text  = tr("MENU_CONFIRM_QUIT_TEXT")
	btn_confirm_yes.text   = tr("MENU_CONFIRM_YES")
	btn_confirm_no.text    = tr("MENU_CONFIRM_NO")


func _setup_options_initial_values() -> void:
	# Volumen música
	var music_bus: int = AudioServer.get_bus_index("Music")
	if music_bus >= 0:
		slider_music_vol.value = db_to_linear(AudioServer.get_bus_volume_db(music_bus))
	else:
		slider_music_vol.value = 1.0

	# Volumen efectos
	var sfx_bus: int = AudioServer.get_bus_index("SFX")
	if sfx_bus >= 0:
		slider_sfx_vol.value = db_to_linear(AudioServer.get_bus_volume_db(sfx_bus))
	else:
		slider_sfx_vol.value = 1.0

	# Pantalla completa
	chk_fullscreen.button_pressed = \
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

	# Idioma
	opt_language.clear()
	opt_language.add_item("Español", 0)
	opt_language.add_item("English", 1)
	var locale: String = TranslationServer.get_locale()
	opt_language.selected = 1 if locale.begins_with("en") else 0


# ============================================
# CALLBACKS DE OPCIONES
# ============================================

func _on_music_vol_changed(value: float) -> void:
	var music_bus: int = AudioServer.get_bus_index("Music")
	if music_bus >= 0:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(value))


func _on_sfx_vol_changed(value: float) -> void:
	var sfx_bus: int = AudioServer.get_bus_index("SFX")
	if sfx_bus >= 0:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(value))


func _on_fullscreen_toggled(pressed: bool) -> void:
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_language_selected(index: int) -> void:
	match index:
		0: TranslationServer.set_locale("es")
		1: TranslationServer.set_locale("en")
	# Refrescar todos los textos al cambiar idioma
	_setup_static_text()
	_render_main()


# ============================================
# HELPERS
# ============================================

func _set_main_buttons_enabled(enabled: bool) -> void:
	btn_new_game.disabled  = not enabled
	btn_load_game.disabled = not enabled or not _vm.has_save
	btn_options.disabled   = not enabled
	btn_credits.disabled   = not enabled
	btn_quit.disabled      = not enabled
