class_name MainMenuScreen
extends CanvasLayer

## MainMenuScreen — View del menú principal (Spike 23)
## Contrato MVVM: nunca accede a sistemas core ni a singletons de configuración.
## Toda lógica pasa por MainMenuViewModel; las opciones, por OptionsPanel.
##
## Es la Main Scene: no se libera nunca; el ViewModel la oculta/muestra según
## GameState (razones "hidden" / "main").

const PANEL_WIDTH_FRACTION: float = 0.5
const PANEL_MAX_WIDTH: float = 620.0
const CONFIRM_MIN_WIDTH: float = 380.0
const CONFIRM_MAX_WIDTH: float = 460.0
const CREDITS_HEIGHT_FRACTION: float = 0.28
const CREDITS_MAX_HEIGHT: float = 360.0

# ============================================
# NODOS
# ============================================

@onready var button_column: VBoxContainer = %ButtonColumn
@onready var new_game_button: Button = %NewGameButton
@onready var load_game_button: Button = %LoadGameButton
@onready var load_info_label: Label = %LoadInfoLabel
@onready var options_button: Button = %OptionsButton
@onready var credits_button: Button = %CreditsButton
@onready var quit_button: Button = %QuitButton

@onready var modal_veil: ColorRect = %ModalVeil
@onready var options_panel: OptionsPanel = %OptionsPanel

@onready var credits_panel: PanelContainer = %CreditsPanel
@onready var credits_title: Label = %CreditsTitle
@onready var credits_divider: ColorRect = %CreditsDivider
@onready var credits_scroll: ScrollContainer = %CreditsScroll
@onready var credits_body: Label = %CreditsBody
@onready var credits_back_button: Button = %CreditsBackButton

@onready var confirm_panel: PanelContainer = %ConfirmPanel
@onready var confirm_text: Label = %ConfirmText
@onready var confirm_yes_button: Button = %ConfirmYesButton
@onready var confirm_no_button: Button = %ConfirmNoButton

# ============================================
# VIEWMODEL Y ESTADO DE VISTA
# ============================================

var _vm: MainMenuViewModel = null

## Botón al que vuelve el foco cuando se regresa al panel principal.
var _return_focus: Button = null

# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	_return_focus = new_game_button

	# ViewModel como hijo. Su _ready aplica lo guardado y puede encolar la carga
	# pendiente (Spike 7); el open() de más abajo se ejecuta ANTES de esa carga.
	_vm = MainMenuViewModel.new()
	_vm.name = "ViewModel"
	add_child(_vm)
	_vm.changed.connect(_on_vm_changed)

	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	options_button.pressed.connect(_on_options_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	credits_back_button.pressed.connect(func(): _vm.request_back())
	confirm_yes_button.pressed.connect(func(): _vm.confirm_quit())
	confirm_no_button.pressed.connect(func(): _vm.request_back())
	options_panel.closed.connect(func(): _vm.request_back())

	get_viewport().size_changed.connect(_layout)

	_apply_static_style()
	_render_texts()
	_layout()

	_vm.open()


func _notification(what: int) -> void:
	# Cambio de idioma en caliente: se retraducen TODOS los textos, también los
	# de los paneles ocultos.
	if what == NOTIFICATION_TRANSLATION_CHANGED and _vm != null:
		_render_texts()


## Esc = Volver, solo en los sub-paneles. En la principal, oculta o en
## transición no hace nada y no consume el evento.
func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	match _vm.state:
		MainMenuViewModel.MenuState.OPTIONS, \
		MainMenuViewModel.MenuState.CREDITS, \
		MainMenuViewModel.MenuState.CONFIRM_QUIT:
			_vm.request_back()
			get_viewport().set_input_as_handled()


# ============================================
# BOTONES DEL PANEL PRINCIPAL
# ============================================

func _on_new_game_pressed() -> void:
	_return_focus = new_game_button
	_vm.request_new_game()


func _on_load_game_pressed() -> void:
	_return_focus = load_game_button
	_vm.request_load_game()


func _on_options_pressed() -> void:
	_return_focus = options_button
	_vm.request_options()


func _on_credits_pressed() -> void:
	_return_focus = credits_button
	_vm.request_credits()


func _on_quit_pressed() -> void:
	_return_focus = quit_button
	_vm.request_quit()


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
	button_column.visible = true
	modal_veil.visible = false
	options_panel.visible = false
	credits_panel.visible = false
	confirm_panel.visible = false

	_set_main_buttons_enabled(true)
	_render_load_info()

	var target: Button = _return_focus
	if target == null or target.disabled:
		target = new_game_button
	target.call_deferred("grab_focus")


func _render_options() -> void:
	_enter_subscreen(options_panel)
	options_panel.open()
	options_panel.focus_first()


func _render_credits() -> void:
	_enter_subscreen(credits_panel)
	credits_back_button.grab_focus()


func _render_confirm_quit() -> void:
	_enter_subscreen(confirm_panel)
	# Foco en Cancelar, no en la acción destructiva.
	confirm_no_button.grab_focus()


func _render_transitioning() -> void:
	_set_main_buttons_enabled(false)


func _render_hidden() -> void:
	visible = false


func _render_load_blocked() -> void:
	load_game_button.disabled = true
	_render_load_info()


## Oculta la columna de botones (así no hay solape ni foco por detrás), pone el
## velo y muestra solo el panel indicado.
func _enter_subscreen(panel: Control) -> void:
	button_column.visible = false
	modal_veil.visible = true
	options_panel.visible = panel == options_panel
	credits_panel.visible = panel == credits_panel
	confirm_panel.visible = panel == confirm_panel
	_layout()


# ============================================
# TEXTOS Y ESTILO
# ============================================

func _render_texts() -> void:
	new_game_button.text = tr("MAIN_MENU_NEW_GAME")
	load_game_button.text = tr("MAIN_MENU_LOAD_GAME")
	options_button.text = tr("MAIN_MENU_OPTIONS")
	credits_button.text = tr("MAIN_MENU_CREDITS")
	quit_button.text = tr("MAIN_MENU_QUIT")
	_render_load_info()

	credits_title.text = tr("MAIN_MENU_CREDITS_TITLE")
	credits_body.text = tr("MAIN_MENU_CREDITS_BODY")
	credits_back_button.text = tr("MAIN_MENU_CREDITS_BACK")

	confirm_text.text = tr("MAIN_MENU_CONFIRM_TEXT")
	confirm_yes_button.text = tr("MAIN_MENU_CONFIRM_YES")
	confirm_no_button.text = tr("MAIN_MENU_CONFIRM_NO")


## Línea bajo "Cargar partida": fecha del guardado o el motivo del botón apagado.
func _render_load_info() -> void:
	if _vm != null and _vm.has_save and not _vm.save_date.is_empty():
		load_info_label.text = tr("MAIN_MENU_SAVE_DATE").format(_vm.save_date)
	elif _vm != null and _vm.has_save:
		load_info_label.text = ""
	else:
		load_info_label.text = tr("MAIN_MENU_NO_SAVE")


func _apply_static_style() -> void:
	modal_veil.color = UITokens.COLOR_MODAL_VEIL

	load_info_label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_SM)
	load_info_label.add_theme_color_override("font_color", UITokens.COLOR_TEXT_MUTED)

	credits_title.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_TITLE)
	credits_title.add_theme_color_override("font_color", UITokens.COLOR_TEXT)
	credits_divider.color = UITokens.BORDER_DEFAULT
	credits_body.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_LG)
	credits_body.add_theme_color_override("font_color", UITokens.COLOR_TEXT)

	confirm_text.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_XL)
	confirm_text.add_theme_color_override("font_color", UITokens.COLOR_TEXT)


# ============================================
# LAYOUT
# ============================================

## Anchos y altos por fracción de la pantalla (sin estiramiento). Los paneles
## se centran con su tamaño mínimo. Las Opciones se colocan solas.
func _layout() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size

	credits_panel.custom_minimum_size.x = minf(screen.x * PANEL_WIDTH_FRACTION, PANEL_MAX_WIDTH)
	credits_scroll.custom_minimum_size.y = minf(screen.y * CREDITS_HEIGHT_FRACTION, CREDITS_MAX_HEIGHT)
	confirm_panel.custom_minimum_size.x = clampf(screen.x * 0.3, CONFIRM_MIN_WIDTH, CONFIRM_MAX_WIDTH)

	for panel: PanelContainer in [credits_panel, confirm_panel]:
		_center_panel(panel)


## Centra un panel por su tamaño mínimo: anclas al centro, offsets a 0 y
## crecimiento hacia ambos lados. El tamaño sigue al contenido en cada cambio,
## sin congelar offsets calculados con un mínimo provisional.
func _center_panel(panel: Control) -> void:
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0


# ============================================
# HELPERS
# ============================================

func _set_main_buttons_enabled(enabled: bool) -> void:
	new_game_button.disabled = not enabled
	load_game_button.disabled = not enabled or not _vm.has_save
	options_button.disabled = not enabled
	credits_button.disabled = not enabled
	quit_button.disabled = not enabled
