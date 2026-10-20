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
##
## Spike 15 — opciones en rejilla y margen del texto proporcional:
##   · Opciones: una columna hasta 3 opciones; desde 4, dos columnas (L1) y la
##     franja de opciones reserva su altura natural, de modo que 6 opciones caben
##     sin scroll en 648 de alto. El ScrollContainer se queda como red de
##     seguridad. El orden de las opciones no cambia (se rellena por filas).
##   · Margen del texto (P2): el hueco que deja el retrato ya no es un 240 fijo,
##     se calcula desde el borde derecho real del retrato (que va por fracciones
##     de pantalla). A 1152x648 sigue siendo 240; en ventanas más anchas el texto
##     ya no queda debajo del retrato.


# ============================================
# CONSTANTES
# ============================================

## Opacidad del velo (Background) cuando hay imagen de fondo (BackgroundImage)
## detrás. Valor de partida, sin calibrar contra el arte real — misma
## lección que el velo 0.2 de los mapas de combate (Grupo 4): se ajusta
## mirando el resultado generado, no a priori.
const SCRIM_ALPHA_WITH_IMAGE := 0.55

## Desde este número de opciones se usan dos columnas.
const MULTI_COLUMN_THRESHOLD: int = 4
const OPTION_COLUMNS_MULTI: int = 2

## Separación entre el borde derecho del retrato y el inicio del texto.
## Calibrada para que a 1152x648 el margen resultante sea exactamente el 240
## fijo que había antes de P2.
const PORTRAIT_TEXT_GAP: int = 3


# ============================================
# EXPORTS
# ============================================

@export var option_button_scene: PackedScene


# ============================================
# NODOS
# ============================================

@onready var background:         ColorRect       = %Background
@onready var background_image:   TextureRect     = %BackgroundImage
@onready var panel:              UIPanel         = %Panel
@onready var portrait:           TextureRect     = %Portrait
@onready var text_margin:        MarginContainer = %MarginContainer
@onready var speaker_name_label: Label           = %SpeakerNameLabel
@onready var dialogue_text:      RichTextLabel   = %DialogueText
@onready var options_scroll:     ScrollContainer = %OptionsScroll
@onready var options_container:  GridContainer   = %OptionsContainer


# ============================================
# ESTADO INTERNO
# ============================================

var _vm: DialogueViewModel = null
var _option_buttons: Array[Button] = []


# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	visible = false

	# Fondo propio del panel (decisión 3 del spec): no puede depender de lo
	# que haya detrás — abierto desde exploración solo hay gris plano detrás.
	# Color desde tokens, no literal en el .tscn.
	background.color = UITokens.COLOR_BG

	# El margen del texto depende del tamaño real de panel y retrato.
	panel.resized.connect(_update_text_margin)
	portrait.resized.connect(_update_text_margin)

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
			call_deferred("_update_text_margin")
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
		var btn := option_button_scene.instantiate() as Button
		btn.text = tr(option.text_key)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# El foco de teclado se ve igual que el hover (en vez del reborde por
		# defecto, que se recortaba): el estilo "hover" del propio botón.
		btn.add_theme_stylebox_override("focus", btn.get_theme_stylebox("hover"))
		btn.pressed.connect(func(): _vm.select_option(option.id))
		options_container.add_child(btn)
		_option_buttons.append(btn)

	_apply_options_layout()


# ============================================
# LAYOUT DE OPCIONES (Spike 15, L1)
# ============================================

## Una columna hasta 3 opciones (sin cambios respecto a antes); desde 4, dos
## columnas y la franja reserva la altura natural de sus filas. Se cuenta con
## los botones ya añadidos: _clear_options() los saca del árbol al momento, así
## que los pendientes de queue_free() no cuentan como filas.
func _apply_options_layout() -> void:
	var count: int = _option_buttons.size()
	if count == 0:
		options_container.columns = 1
		options_scroll.custom_minimum_size.y = 0.0
		return

	var columns: int = OPTION_COLUMNS_MULTI if count >= MULTI_COLUMN_THRESHOLD else 1
	options_container.columns = columns

	# La franja reserva SIEMPRE la altura natural de sus filas (también con 1-3
	# opciones): sin eso, ScrollContainer y DialogueText se reparten el hueco
	# 50/50 y a 648 de alto se cortaba la tercera opción.
	var row_height: float = 0.0
	for btn in _option_buttons:
		row_height = maxf(row_height, btn.get_combined_minimum_size().y)

	var rows: int = ceili(float(count) / float(columns))
	var v_separation: int = options_container.get_theme_constant("v_separation")
	options_scroll.custom_minimum_size.y = rows * row_height + (rows - 1) * v_separation

	# Teclado: sin foco inicial las flechas/Enter no tienen a quién llegar.
	# El foco 2D de la rejilla (arriba/abajo/izquierda/derecha) lo resuelve Godot.
	call_deferred("_focus_first_option")


func _focus_first_option() -> void:
	if _option_buttons.is_empty():
		return
	var first: Button = _option_buttons[0]
	if is_instance_valid(first) and first.is_inside_tree() and first.is_visible_in_tree():
		first.grab_focus()


# ============================================
# UTILIDADES
# ============================================

func _clear_options() -> void:
	for btn in _option_buttons:
		if not is_instance_valid(btn):
			continue
		if btn.get_parent() == options_container:
			options_container.remove_child(btn)
		btn.queue_free()
	_option_buttons.clear()
	options_container.columns = 1
	options_scroll.custom_minimum_size.y = 0.0


## Sin retrato disponible, el panel de texto ocupa todo el ancho (decisión
## de la Fase 1 del spec) — el propio Panel no cambia de tamaño, es el
## MarginContainer/margin_left el que deja o no hueco para el retrato.
func _clear_portrait() -> void:
	portrait.texture = null
	portrait.hide()
	_update_text_margin()


func _assign_portrait(texture: Texture2D) -> void:
	portrait.texture = texture
	portrait.visible = true
	_update_text_margin()
	# Si el diálogo aún no tenía tamaño de layout, se recalcula al siguiente frame.
	call_deferred("_update_text_margin")


## Margen izquierdo del texto (P2): desde el borde derecho del retrato hasta el
## inicio del contenido del panel. Retrato y panel son hermanos bajo Root, así
## que sus posiciones están en el mismo espacio. Sin retrato visible, margen 0.
func _update_text_margin() -> void:
	var margin: int = 0
	if portrait.visible:
		var panel_style: StyleBox = panel.get_theme_stylebox("panel")
		var panel_padding: float = panel_style.get_margin(SIDE_LEFT) if panel_style else 0.0
		var portrait_right: float = portrait.position.x + portrait.size.x
		margin = maxi(0, roundi(portrait_right - (panel.position.x + panel_padding) + PORTRAIT_TEXT_GAP))
	text_margin.add_theme_constant_override("margin_left", margin)


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
