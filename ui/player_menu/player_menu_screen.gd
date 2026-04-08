class_name PlayerMenuScreen
extends CanvasLayer

## PlayerMenuScreen — View
##
## Responsabilidades:
##   - Renderizar el estado del personaje (recursos, atributos derivados, buffs)
##   - Ofrecer navegación a subpantallas (Loadout, Inventario, Árbol de Skills)
##   - Traducir input del jugador en llamadas al ViewModel
##   - NADA más
##
## Nunca accede a Characters, Resources, AttributeResolver ni sistemas core.
## Todo pasa por PlayerMenuViewModel.
##
## Estructura esperada del .tscn:
##
## CanvasLayer                            ← este script
## └── Panel (PanelContainer)
##     └── MarginContainer
##         └── VBox (VBoxContainer)
##             ├── Header (HBoxContainer)
##             │   ├── TitleLabel (Label)
##             │   └── CloseButton (Button)
##             ├── ContentHBox (HBoxContainer)
##             │   ├── StatusPanel (PanelContainer)     ← columna izquierda
##             │   │   └── MarginContainer
##             │   │       └── StatusVBox (VBoxContainer)
##             │   │           ├── ResourcesSection (VBoxContainer)
##             │   │           │   ├── ResourcesLabel (Label)
##             │   │           │   ├── HealthLabel (Label)
##             │   │           │   ├── StaminaLabel (Label)
##             │   │           │   └── GoldLabel (Label)
##             │   │           ├── HSeparator
##             │   │           ├── AttributesSection (VBoxContainer)
##             │   │           │   ├── AttributesLabel (Label)
##             │   │           │   └── AttributesVBox (VBoxContainer)
##             │   │           ├── HSeparator
##             │   │           └── BuffsSection (VBoxContainer)
##             │   │               ├── BuffsLabel (Label)
##             │   │               └── BuffsVBox (VBoxContainer)
##             │   └── NavigationPanel (PanelContainer)  ← columna derecha
##             │       └── MarginContainer
##             │           └── NavigationVBox (VBoxContainer)
##             │               ├── LoadoutButton (Button)
##             │               ├── InventoryButton (Button)
##             │               └── SkillTreeButton (Button)


# ============================================
# NODOS
# ============================================

@onready var title_label:       Label         = $Panel/MarginContainer/VBox/Header/TitleLabel
@onready var close_button:      Button        = $Panel/MarginContainer/VBox/Header/CloseButton
@onready var health_label:      Label         = $Panel/MarginContainer/VBox/ContentHBox/StatusPanel/MarginContainer/StatusVBox/ResourcesSection/HealthLabel
@onready var stamina_label:     Label         = $Panel/MarginContainer/VBox/ContentHBox/StatusPanel/MarginContainer/StatusVBox/ResourcesSection/StaminaLabel
@onready var gold_label:        Label         = $Panel/MarginContainer/VBox/ContentHBox/StatusPanel/MarginContainer/StatusVBox/ResourcesSection/GoldLabel
@onready var attributes_vbox:   VBoxContainer = $Panel/MarginContainer/VBox/ContentHBox/StatusPanel/MarginContainer/StatusVBox/AttributesSection/AttributesVBox
@onready var buffs_vbox:        VBoxContainer = $Panel/MarginContainer/VBox/ContentHBox/StatusPanel/MarginContainer/StatusVBox/BuffsSection/BuffsVBox
@onready var loadout_button:    Button        = $Panel/MarginContainer/VBox/ContentHBox/NavigationPanel/MarginContainer/NavigationVBox/LoadoutButton
@onready var inventory_button:  Button        = $Panel/MarginContainer/VBox/ContentHBox/NavigationPanel/MarginContainer/NavigationVBox/InventoryButton
@onready var skill_tree_button: Button        = $Panel/MarginContainer/VBox/ContentHBox/NavigationPanel/MarginContainer/NavigationVBox/SkillTreeButton


# ============================================
# ESTADO INTERNO
# ============================================

var _vm: PlayerMenuViewModel = null


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	visible = false

	_vm = PlayerMenuViewModel.new()
	_vm.name = "ViewModel"
	add_child(_vm)

	_vm.changed.connect(_on_vm_changed)

	close_button.pressed.connect(func(): _vm.request_close())
	loadout_button.pressed.connect(func(): _vm.request_open_loadout())
	inventory_button.pressed.connect(func(): _vm.request_open_inventory())
	skill_tree_button.pressed.connect(func(): _vm.request_open_skill_tree())

	print("[PlayerMenuScreen] Ready")


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_vm.request_close()
		get_viewport().set_input_as_handled()


# ============================================
# API PÚBLICA — llamada desde SceneOrchestrator
# ============================================

func open(character_id: String) -> void:
	_vm.open(character_id)


# ============================================
# CALLBACK ÚNICO DEL VIEWMODEL
# ============================================

func _on_vm_changed(reason: String) -> void:
	match reason:
		"opened":
			_render_all()
		"attributes":
			_render_attributes()
		"buffs":
			_render_buffs()
		"resources":
			_render_resources()
		"closed":
			visible = false
		_:
			push_warning("[PlayerMenuScreen] Razón desconocida: %s" % reason)


# ============================================
# RENDERS
# ============================================

func _render_all() -> void:
	title_label.text = _vm.character_name
	_render_resources()
	_render_attributes()
	_render_buffs()
	_render_navigation()
	visible = true


func _render_resources() -> void:
	health_label.text  = "%s: %d / %d" % [tr("MENU_HEALTH"),  _vm.health_current,  _vm.health_max]
	stamina_label.text = "%s: %d / %d" % [tr("MENU_STAMINA"), _vm.stamina_current, _vm.stamina_max]
	gold_label.text    = "%s: %d"      % [tr("MENU_GOLD"),     _vm.gold]


func _render_attributes() -> void:
	_clear_container(attributes_vbox)

	for attr_id in _vm.attributes.keys():
		var value: float = _vm.attributes[attr_id]
		var row := Label.new()
		row.text = "%s: %d" % [tr("ATTR_" + attr_id.to_upper()), int(value)]
		attributes_vbox.add_child(row)


func _render_buffs() -> void:
	_clear_container(buffs_vbox)

	if _vm.active_buffs.is_empty():
		var empty_label := Label.new()
		empty_label.text = tr("MENU_NO_BUFFS")
		buffs_vbox.add_child(empty_label)
		return

	for buff in _vm.active_buffs:
		var row := Label.new()
		row.text = "%s (%.1fs)" % [buff.buff_id, buff.time_left]
		buffs_vbox.add_child(row)


func _render_navigation() -> void:
	loadout_button.text    = tr("MENU_LOADOUT")
	inventory_button.text  = tr("MENU_INVENTORY")
	skill_tree_button.text = tr("MENU_SKILL_TREE")


# ============================================
# UTILIDADES
# ============================================

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.free()
