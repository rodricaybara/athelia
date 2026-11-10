class_name PlayerMenuScreen
extends CanvasLayer

## PlayerMenuScreen — View (Spike 22)
##
## Responsabilidades:
##   - Renderizar el estado del personaje (recursos, atributos, buffs)
##   - Gestionar subpantallas (Loadout, Inventario, SkillTree) como hijos propios
##   - Traducir input del jugador en llamadas al ViewModel
##   - NADA más
##
## Gestión de subpantallas:
##   - Las subpantallas se instancian como hijos de este nodo
##   - Al abrir una subpantalla, PlayerMenuScreen se oculta (visible=false)
##   - Al cerrar la subpantalla (señal `closed`), PlayerMenuScreen vuelve a mostrarse
##   - SceneOrchestrator no interviene en la navegación interna
##
## Teclas: con el menú visible, esta pantalla consume en _input() las acciones
## open_player_menu (cierra), open_inventory y open_skill_tree (abren la
## subpantalla) y ui_cancel (cierra). Con una subpantalla abierta solo
## consume open_player_menu, para que no cierre el menú entero por error.
## Funciona igual en exploración y en narrativa.


# ============================================
# SEÑALES
# ============================================

## Emitida en _close_all(), junto a visible = false. PlayerMenuScreen NUNCA se
## autolibera: quien la instancia (SceneOrchestrator o NarrativeScenePanel)
## hace queue_free() al recibir esta señal.
signal closed


# ============================================
# CONSTANTES
# ============================================

const SCENE_LOADOUT    := "res://ui/loadout/loadout_screen.tscn"
const SCENE_INVENTORY  := "res://ui/inventory/inventory_ui.tscn"
const SCENE_SKILL_TREE := "res://ui/skill_tree/skill_tree_screen.tscn"

## Marco centrado: fracción de la pantalla con tope (mismo criterio que
## Inventario, Party, Loadout y Árbol de habilidades).
const FRAME_FRACTION: float = 0.9
const FRAME_MAX_SIZE: Vector2 = Vector2(1400, 820)


# ============================================
# NODOS
# ============================================

@onready var backdrop:           ColorRect       = %Backdrop
@onready var frame:              Control         = %Frame
@onready var title_label:        Label           = %TitleLabel
@onready var close_button:       Button          = %CloseButton
@onready var loadout_button:     Button          = %LoadoutButton
@onready var inventory_button:   Button          = %InventoryButton
@onready var skill_tree_button:  Button          = %SkillTreeButton

@onready var resources_title:    Label           = %ResourcesTitle
@onready var resources_divider:  ColorRect       = %ResourcesDivider
@onready var resources_rows:     VBoxContainer   = %ResourcesRows

@onready var attributes_title:   Label           = %AttributesTitle
@onready var attributes_divider: ColorRect       = %AttributesDivider
@onready var derived_title:      Label           = %DerivedTitle
@onready var derived_rows:       VBoxContainer   = %DerivedRows
@onready var base_title:         Label           = %BaseTitle
@onready var base_rows:          VBoxContainer   = %BaseRows

@onready var buffs_title:        Label           = %BuffsTitle
@onready var buffs_divider:      ColorRect       = %BuffsDivider
@onready var empty_buffs_label:  Label           = %EmptyBuffsLabel
@onready var buffs_rows:         VBoxContainer   = %BuffsRows


# ============================================
# ESTADO INTERNO
# ============================================

var _vm: PlayerMenuViewModel = null
var _character_id: String = ""
var _subscreen: Node = null
var _is_open: bool = false

var _health_row: PlayerMenuRow = null
var _stamina_row: PlayerMenuRow = null
var _gold_row: PlayerMenuRow = null
var _derived_row_nodes: Array[PlayerMenuRow] = []
var _base_row_nodes: Array[PlayerMenuRow] = []
var _buff_row_nodes: Array[PlayerMenuRow] = []


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	visible = false

	_style_static()
	_build_resource_rows()

	_vm = PlayerMenuViewModel.new()
	_vm.name = "ViewModel"
	add_child(_vm)
	_vm.changed.connect(_on_vm_changed)

	close_button.pressed.connect(func(): _vm.request_close())
	loadout_button.pressed.connect(func(): _vm.request_open_loadout())
	inventory_button.pressed.connect(func(): _vm.request_open_inventory())
	skill_tree_button.pressed.connect(func(): _vm.request_open_skill_tree())

	get_viewport().size_changed.connect(_update_frame_rect)
	_update_frame_rect()


func _input(event: InputEvent) -> void:
	if not _is_open:
		return

	# Con una subpantalla abierta el menú está oculto. Solo se consume P:
	# si llegara al orquestador, cerraría menú y subpantalla juntos.
	# Esc, I, H y O no se tocan (las gestiona la subpantalla o se ignoran).
	if _subscreen != null and is_instance_valid(_subscreen):
		if event.is_action_pressed("open_player_menu"):
			get_viewport().set_input_as_handled()
		return

	if not visible:
		return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_player_menu"):
		_vm.request_close()
	elif event.is_action_pressed("open_inventory"):
		_vm.request_open_inventory()
	elif event.is_action_pressed("open_skill_tree"):
		_vm.request_open_skill_tree()
	else:
		return
	get_viewport().set_input_as_handled()


# ============================================
# API PÚBLICA — llamada desde SceneOrchestrator / NarrativeScenePanel
# ============================================

func open(character_id: String) -> void:
	_character_id = character_id
	_vm.open(character_id)


# ============================================
# CALLBACK ÚNICO DEL VIEWMODEL
# ============================================

func _on_vm_changed(reason: String) -> void:
	match reason:
		"opened":
			_is_open = true
			_render_all()
		"attributes":
			_render_attributes()
		"resources":
			_render_resources()
		"buffs":
			_render_buffs()
		"buff_times":
			_render_buff_times()
		"open_loadout":
			_open_subscreen(SCENE_LOADOUT, func(s): s.open(_character_id))
		"open_inventory":
			_open_subscreen(SCENE_INVENTORY, func(s): s.open_inventory())
		"open_skill_tree":
			_open_subscreen(SCENE_SKILL_TREE, func(s): s.open(_character_id))
		"closed":
			_close_all()
		_:
			push_warning("[PlayerMenuScreen] Razón desconocida: %s" % reason)


# ============================================
# ESTILO Y CONSTRUCCIÓN ÚNICA
# ============================================

func _style_static() -> void:
	backdrop.color = UITokens.BG_VOID

	title_label.add_theme_font_size_override("font_size", UITokens.FONT_SIZE_TITLE)
	title_label.add_theme_color_override("font_color", UITokens.TEXT_PRIMARY)

	for label in [resources_title, attributes_title, buffs_title]:
		(label as Label).add_theme_font_size_override("font_size", UITokens.FONT_SIZE_LG)
		(label as Label).add_theme_color_override("font_color", UITokens.TEXT_SECONDARY)

	for label in [derived_title, base_title, empty_buffs_label]:
		(label as Label).add_theme_font_size_override("font_size", UITokens.FONT_SIZE_MD)
		(label as Label).add_theme_color_override("font_color", UITokens.TEXT_MUTED)

	for divider in [resources_divider, attributes_divider, buffs_divider]:
		(divider as ColorRect).color = UITokens.BORDER_DEFAULT


func _build_resource_rows() -> void:
	_health_row = PlayerMenuRow.create(PlayerMenuRow.Kind.RESOURCE, "health")
	_stamina_row = PlayerMenuRow.create(PlayerMenuRow.Kind.RESOURCE, "stamina")
	_gold_row = PlayerMenuRow.create(PlayerMenuRow.Kind.TEXT)
	_gold_row.set_value_color(UITokens.COLOR_GOLD)
	resources_rows.add_child(_health_row)
	resources_rows.add_child(_stamina_row)
	resources_rows.add_child(_gold_row)


## Marco centrado: FRAME_FRACTION de la pantalla, con tope FRAME_MAX_SIZE.
func _update_frame_rect() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var target := Vector2(
		minf(screen.x * FRAME_FRACTION, FRAME_MAX_SIZE.x),
		minf(screen.y * FRAME_FRACTION, FRAME_MAX_SIZE.y))
	frame.offset_left = -target.x / 2.0
	frame.offset_right = target.x / 2.0
	frame.offset_top = -target.y / 2.0
	frame.offset_bottom = target.y / 2.0


# ============================================
# RENDERS
# ============================================

func _render_all() -> void:
	title_label.text = _vm.character_name

	resources_title.text = tr("PLAYER_MENU_SECTION_RESOURCES")
	attributes_title.text = tr("PLAYER_MENU_SECTION_ATTRIBUTES")
	derived_title.text = tr("PLAYER_MENU_ATTR_DERIVED")
	base_title.text = tr("PLAYER_MENU_ATTR_BASE")
	buffs_title.text = tr("PLAYER_MENU_SECTION_BUFFS")
	empty_buffs_label.text = tr("PLAYER_MENU_NO_BUFFS")

	_render_navigation()
	_render_resources()
	_render_attributes()
	_render_buffs()
	_update_frame_rect()
	visible = true


func _render_navigation() -> void:
	var buttons: Array[Button] = [loadout_button, inventory_button, skill_tree_button]
	for i in mini(buttons.size(), _vm.nav_entries.size()):
		var entry: PlayerMenuViewModel.NavEntry = _vm.nav_entries[i]
		var label: String = tr(entry.label_key)
		buttons[i].text = label if entry.key_text.is_empty() else "%s (%s)" % [label, entry.key_text]


func _render_resources() -> void:
	_health_row.set_name_text(tr("PLAYER_MENU_HEALTH"))
	_health_row.set_resource(_vm.health_current, _vm.health_max)
	_stamina_row.set_name_text(tr("PLAYER_MENU_STAMINA"))
	_stamina_row.set_resource(_vm.stamina_current, _vm.stamina_max)
	_gold_row.set_name_text(tr("PLAYER_MENU_GOLD"))
	_gold_row.set_value_text(str(_vm.gold))


func _render_attributes() -> void:
	_sync_attribute_rows(derived_rows, _derived_row_nodes, _vm.derived_attributes)
	_sync_attribute_rows(base_rows, _base_row_nodes, _vm.base_attributes)
	base_title.visible = not _vm.base_attributes.is_empty()


func _sync_attribute_rows(container: Container, rows: Array[PlayerMenuRow], entries: Array[PlayerMenuViewModel.AttrEntry]) -> void:
	while rows.size() < entries.size():
		var row := PlayerMenuRow.create(PlayerMenuRow.Kind.TEXT)
		container.add_child(row)
		rows.append(row)
	while rows.size() > entries.size():
		var extra: PlayerMenuRow = rows.pop_back()
		container.remove_child(extra)
		extra.queue_free()
	for i in entries.size():
		var entry: PlayerMenuViewModel.AttrEntry = entries[i]
		rows[i].set_name_text(tr(entry.label_key))
		rows[i].set_value_text(str(entry.value))
		rows[i].set_value_color(_attribute_color(entry.bonus))
		var tip: String = ""
		if entry.bonus != 0:
			tip = tr("PLAYER_MENU_ATTR_BONUS_TOOLTIP") % [entry.base_value, entry.bonus]
		rows[i].set_tooltip(tip)


## Verde si el equipo o un efecto suma, rojo si resta, normal si no hay bono.
func _attribute_color(bonus: int) -> Color:
	if bonus > 0:
		return UITokens.COLOR_SUCCESS_SOFT
	if bonus < 0:
		return UITokens.COLOR_DANGER_SOFT
	return UITokens.COLOR_TEXT


func _render_buffs() -> void:
	var count: int = _vm.active_buffs.size()
	empty_buffs_label.visible = count == 0

	while _buff_row_nodes.size() < count:
		var row := PlayerMenuRow.create(PlayerMenuRow.Kind.BUFF)
		buffs_rows.add_child(row)
		_buff_row_nodes.append(row)
	while _buff_row_nodes.size() > count:
		var extra: PlayerMenuRow = _buff_row_nodes.pop_back()
		buffs_rows.remove_child(extra)
		extra.queue_free()

	for i in count:
		_buff_row_nodes[i].set_name_text(_buff_display_name(_vm.active_buffs[i]))
	_render_buff_times()


func _render_buff_times() -> void:
	var count: int = mini(_buff_row_nodes.size(), _vm.active_buffs.size())
	for i in count:
		var buff: PlayerMenuViewModel.BuffData = _vm.active_buffs[i]
		_buff_row_nodes[i].set_value_text(tr("PLAYER_MENU_BUFF_TIME") % ceili(buff.time_left))
		_buff_row_nodes[i].set_bar(buff.time_left, buff.duration)


## Nombre localizado del buff; si no hay clave definida, el id crudo.
func _buff_display_name(buff: PlayerMenuViewModel.BuffData) -> String:
	var translated: String = tr(buff.name_key)
	return buff.buff_id if translated == buff.name_key else translated


# ============================================
# GESTIÓN DE SUBPANTALLAS
#
# Las tres subpantallas (InventoryUI, LoadoutScreen, SkillTreeScreen)
# exponen la señal `closed` y nunca se autoliberan: este menú, que las
# instancia, hace queue_free() al recibirla.
# ============================================

func _open_subscreen(scene_path: String, init_callback: Callable) -> void:
	_close_subscreen()

	var packed := load(scene_path) as PackedScene
	if not packed:
		push_error("[PlayerMenuScreen] No se puede cargar: %s" % scene_path)
		return

	var screen: Node = packed.instantiate()
	if not screen.has_signal("closed"):
		push_error("[PlayerMenuScreen] %s no expone la señal 'closed'" % scene_path.get_file())
		screen.free()
		return

	_subscreen = screen
	add_child(_subscreen)
	_subscreen.connect("closed", _on_subscreen_closed)
	init_callback.call(_subscreen)

	visible = false


func _on_subscreen_closed() -> void:
	_close_subscreen()
	visible = true
	_vm.open(_character_id)


func _close_subscreen() -> void:
	if _subscreen and is_instance_valid(_subscreen):
		if _subscreen.is_connected("closed", _on_subscreen_closed):
			_subscreen.disconnect("closed", _on_subscreen_closed)
		_subscreen.queue_free()
	_subscreen = null


func _close_all() -> void:
	_is_open = false
	_close_subscreen()
	visible = false
	closed.emit()
