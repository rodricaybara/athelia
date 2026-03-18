extends Node2D

## CombatTestScene - Escena de prueba para el sistema de combate
## 
## Responsabilidades:
## - Inicializar entidades (player, enemigos)
## - Registrar en sistemas (Resources, Characters, Skills)
## - Iniciar/terminar combate de prueba
## - Actualizar UI con estado actual

@onready var game_loop: GameLoopSystem = get_node("/root/GameLoop")

# ============================================
# REFERENCIAS A NODOS
# ============================================

@onready var player_node = $Player

# Escena base para instanciar enemigos dinámicamente
const ENEMY_COMBAT_NODE = preload("res://scenes/combat/enemy_combat_node.tscn")

# Posiciones de slot para hasta 5 enemigos, distribuidas verticalmente
const ENEMY_SLOT_POSITIONS = [
	Vector2(600, 300),
	Vector2(650, 220),
	Vector2(650, 380),
	Vector2(700, 260),
	Vector2(700, 340),
]

# UI Labels

@onready var combat_status_label = $UI/Panel/VBoxContainer/CombatStatus
@onready var target_label = $UI/Panel/VBoxContainer/TargetLabel
@onready var last_action_label = $UI/Panel/VBoxContainer/LastAction
@onready var escape_info_label = $UI/Panel/VBoxContainer/EscapeInfoLabel

# UI Bars (FASE B.3)
@onready var player_hp_bar = $UI/Panel/VBoxContainer/PlayerHPContainer/PlayerHPBar
@onready var player_stamina_bar = $UI/Panel/VBoxContainer/PlayerStaminaContainer/PlayerStaminaBar

# Barras de enemigos generadas dinámicamente en _build_enemy_bars()
# { enemy_id: { "container": HBoxContainer, "bar": ProgressBar, "label": Label } }
var _enemy_bars: Dictionary = {}

## Barras de los compañeros del player
var _companion_bars: Dictionary = {}

# Damage number label
@onready var damage_numbers_parent = $DamageNumbers

# ============================================
# INICIALIZACIÓN
# ============================================

func _ready():
	print("\n" + "=".repeat(60))
	print("COMBAT TEST SCENE - INITIALIZING")
	print("=".repeat(60))
	
	# Simular tiradas para verificar probabilidades
	SkillRoller.print_simulation(40, 1000)  # 1000 tiradas al 40%
	
		# 🔍 AUTO-DIAGNÓSTICO
	print("\n" + "=".repeat(60))
	print("AUTO-DIAGNOSTIC CHECK")
	print("=".repeat(60))
	
	# Check 1: Skills loaded
	var light_def = Skills.get_skill_definition("skill.attack.light")
	var heavy_def = Skills.get_skill_definition("skill.attack.heavy")
	var dodge_def = Skills.get_skill_definition("skill.combat.dodge")
	
	print("✓ Light Attack loaded: %s" % (light_def != null))
	print("✓ Heavy Attack loaded: %s" % (heavy_def != null))
	print("✓ Heavy Attack loaded: %s" % (dodge_def != null))
	
	# Check 2: Input actions
	print("✓ skill_1 configured: %s" % InputMap.has_action("skill_1"))
	print("✓ skill_2 configured: %s" % InputMap.has_action("skill_2"))
	print("✓ skill_3 configured: %s" % InputMap.has_action("skill_3"))
	print("✓ cycle_target configured: %s" % InputMap.has_action("cycle_target"))
	
	# Check 3: Player controller
	var controller = player_node.get_node_or_null("PlayerCombatController")
	print("✓ PlayerCombatController exists: %s" % (controller != null))
	
	print("=".repeat(60) + "\n")
	
	# Damage Labels
	Combat.damage_numbers_parent = damage_numbers_parent
	
	# Inicializar entidades usando los IDs reales de GameLoop
	_initialize_player()
	_initialize_enemies_from_gameloop()
	
	# Conectar a eventos de combate
	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.turn_phase_changed.connect(_on_turn_phase_changed)
	EventBus.player_turn_started.connect(_on_player_turn_started)
	EventBus.enemy_turn_started.connect(_on_enemy_turn_started)
	EventBus.combat_ended.connect(_on_combat_ended)
	EventBus.target_changed.connect(_on_target_changed)
	EventBus.combat_action_completed.connect(_on_combat_action_completed)
	
	# No llamar start_combat() aquí — cuando se llega desde exploración,
	# GameLoop.start_combat() ya fue llamado por ExplorationController.
	# Solo en modo standalone (sin ExplorationController) sería necesario.
	if game_loop.current_game_state != GameLoopSystem.GameState.COMBAT_ACTIVE:
		await get_tree().create_timer(0.5).timeout
		_start_combat()
	else:
		print("[CombatTest] Combat already started by GameLoop — skipping _start_combat()")
	
	print("\n[CombatTest] Scene ready - Press F5 to start combat")


# ============================================
# INICIALIZACIÓN DE ENTIDADES
# ============================================

func _initialize_player():
	var player_id = "player"
	
	print("\n[CombatTest] Initializing Player...")
	
	# Cuando se llega desde exploración, player ya está registrado en
	# CharacterSystem y ResourceSystem. Solo registramos lo que falte.
	
	# 1. ResourceSystem — idempotente con guard explícito
	# ResourceSystem no expone has_entity — usamos get_resource_state como proxy
	if Resources.get_resource_state(player_id, "health") == null:
		Resources.register_entity(player_id, ["health", "stamina"])
		Resources.set_resource(player_id, "health", 100)
		Resources.set_resource(player_id, "stamina", 100)
		print("  ✓ Registered in ResourceSystem")
	else:
		print("  ↩ Player already in ResourceSystem — skipping")
	
	# 2. CharacterSystem — idempotente con guard explícito
	if not Characters.has_entity(player_id):
		if Characters.has_definition("player_base"):
			Characters.register_entity(player_id, "player_base")
			print("  ✓ Registered in CharacterSystem")
		else:
			print("  ⚠ Player definition not found")
	else:
		print("  ↩ Player already in CharacterSystem — skipping")
	
	# 3. Skills — siempre intentar (SkillSystem es idempotente)
	Skills.register_entity_skills(player_id, [
		"skill.attack.light",
		"skill.attack.heavy",
		"skill.combat.dodge"
		])
	print("  ✓ Player initialized")


## Instancia dinámicamente un EnemyCombatNode por cada enemigo en GameLoop.participants.
## Construye también las barras de HP en la UI para cada uno.
func _initialize_enemies_from_gameloop() -> void:
	var party: Node = get_node_or_null("/root/Party")
	var party_ids: Array = party.get_party_members() if party else []
 
	var enemy_ids: Array = game_loop.participants.filter(
		func(id: String) -> bool:
			return id != "player" and not party_ids.has(id)
	)

	print("\n[CombatTest] Spawning %d enemies dynamically..." % enemy_ids.size())

	# 1. Construir barras de UI antes del spawn (así están listas cuando _update_ui corre)
	_build_enemy_bars(enemy_ids)

	## Barras y nodos de los compañeros del player 
	_build_companion_bars()
	_spawn_companion_nodes()

	# 2. Instanciar un nodo visual por cada enemigo
	for i in range(enemy_ids.size()):
		var enemy_id: String = enemy_ids[i]
		var enemy_node: Node2D = ENEMY_COMBAT_NODE.instantiate()

		# Posición del slot: usar tabla o fallback calculado
		if i < ENEMY_SLOT_POSITIONS.size():
			enemy_node.position = ENEMY_SLOT_POSITIONS[i]
		else:
			enemy_node.position = Vector2(600 + i * 60, 300)

		# setup() ANTES de add_child(): asigna visual_node al AnimationController
		# antes de que _ready() se dispare en el árbol de escena.
		enemy_node.setup(enemy_id)
		$EnemyContainer.add_child(enemy_node)
		_initialize_enemy(enemy_id, enemy_node)

	print("[CombatTest] All enemies spawned")


## Genera las barras de HP de enemigos dinámicamente en la UI.
## Llamado desde _initialize_enemies_from_gameloop() antes del spawn visual.
func _build_enemy_bars(enemy_ids: Array) -> void:
	var vbox = $UI/Panel/VBoxContainer

	# Limpiar barras de un combate anterior (por restart con F5)
	for entry in _enemy_bars.values():
		entry["container"].queue_free()
	_enemy_bars.clear()

	# Insertar las nuevas barras antes de EscapeInfoLabel para mantener el orden visual
	var escape_label = $UI/Panel/VBoxContainer/EscapeInfoLabel

	for enemy_id in enemy_ids:
		var hbox := HBoxContainer.new()
		hbox.name = "%sHPContainer" % enemy_id

		var lbl := Label.new()
		lbl.custom_minimum_size = Vector2(100, 0)
		lbl.text = "%s HP:" % enemy_id

		var bar := ProgressBar.new()
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_theme_constant_override("outline_size", 1)
		bar.step = 0.1
		bar.value = 100.0

		hbox.add_child(lbl)
		hbox.add_child(bar)
		vbox.add_child(hbox)
		vbox.move_child(hbox, escape_label.get_index())

		_enemy_bars[enemy_id] = {"container": hbox, "bar": bar, "label": lbl}

	print("[CombatTest] Built %d enemy HP bars" % _enemy_bars.size())


func _initialize_enemy(enemy_id: String, enemy_node: Node2D):
	print("\n[CombatTest] Initializing Enemy: %s..." % enemy_id)
	
	# 1. ResourceSystem — ya registrado por ExplorationController antes de start_combat().
	# register_entity emitirá warning si ya existe, que es inofensivo.
	# Solo actualizamos el valor de HP si es necesario.
	if not Characters.has_entity(enemy_id):
		Resources.register_entity(enemy_id, ["health"])
	Resources.set_resource(enemy_id, "health", 50)
	print("  ✓ Registered in ResourceSystem")
	print("  ✓ Enemy initialized (HP: 50)")
	
	# 2. Registrar en CharacterSystem — guard idéntico al de ResourceSystem:
	# ExplorationController ya lo registró, solo actuar si falta.
	if not Characters.has_entity(enemy_id):
		if Characters.has_definition("enemy_base"):
			Characters.register_entity(enemy_id, "enemy_base")
			print("  ✓ Registered in CharacterSystem")
		else:
			push_warning("  ⚠ enemy_base definition not found")
	else:
		print("  ↩ %s already in CharacterSystem — skipping" % enemy_id)
	
	# 3. Registrar skills de enemigo
	Skills.register_entity_skills(enemy_id, ["skill.enemy.basic_attack"])
	print("  ✓ Enemy skills registered")
	
	# 4. ✅ AÑADIR EnemyAI dinámicamente
	var ai = Node.new()
	ai.set_script(preload("res://core/combat/enemy_ai.gd"))
	ai.name = "EnemyAI"
	enemy_node.add_child(ai)
	
	# Configurar propiedades
	ai.set("enemy_id", enemy_id)
	ai.set("attack_skill_id", "skill.enemy.basic_attack")
	
	print("  ✓ %s initialized with AI" % enemy_id)

# ============================================
# COMPANION
# ============================================

func _build_companion_bars() -> void:
	var party := get_node_or_null("/root/Party")
	if not party or not party.has_companions():
		return
 
	# Limpiar barras anteriores
	for entry in _companion_bars.values():
		entry["container"].queue_free()
	_companion_bars.clear()
 
	var vbox := $UI/Panel/VBoxContainer
 
	for companion_id in party.get_party_members():
		var hbox := HBoxContainer.new()
		hbox.name = "%sHPContainer" % companion_id
 
		var lbl := Label.new()
		lbl.custom_minimum_size = Vector2(100, 0)
		lbl.text = "%s HP:" % companion_id.replace("companion_", "").capitalize()
		lbl.modulate = Color(0.4, 0.8, 1.0)  # azul para companions
 
		var bar := ProgressBar.new()
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.step = 0.1
		bar.value = 100.0
		bar.modulate = Color(0.4, 0.8, 1.0)
 
		hbox.add_child(lbl)
		hbox.add_child(bar)
 
		# Insertar antes de las barras de enemigos
		vbox.add_child(hbox)
		vbox.move_child(hbox, 2)  # Después de player HP y stamina
 
		_companion_bars[companion_id] = { "container": hbox, "bar": bar, "label": lbl }
 
	print("[CombatTestScene] Built %d companion HP bars" % _companion_bars.size())
 
 
func _spawn_companion_nodes() -> void:
	var party := get_node_or_null("/root/Party")
	if not party or not party.has_companions():
		return
 
	# Posiciones de companions: lado izquierdo del jugador en combate
	var companion_positions := [
		Vector2(200, 300),
		Vector2(200, 220),
	]
 
	var idx := 0
	for companion_id in party.get_party_members():
		# Crear nodo visual simple para combate
		var node := Node2D.new()
		node.name = companion_id
		node.add_to_group(companion_id)
		node.add_to_group("companion")
 
		var pos: Vector2 = companion_positions[min(idx, companion_positions.size() - 1)]
		node.position = pos
 
		# Label identificativo
		var lbl := Label.new()
		lbl.text = companion_id.replace("companion_", "").capitalize()
		lbl.position = Vector2(-20, -30)
		node.add_child(lbl)
 
		# Sprite
		var sprite := Sprite2D.new()
		sprite.name = "SpriteCompanion"
		var portrait_path := "res://data/characters/portrait/%s.png" % companion_id.replace("companion_", "")
		if ResourceLoader.exists(portrait_path):
			sprite.texture = load(portrait_path)
		else:
			sprite.texture = load("res://icon.svg")
			sprite.modulate = Color(0.4, 0.8, 1.0)
		sprite.scale = Vector2(0.3, 0.3)
		node.add_child(sprite)
 
		# AnimationController
		var anim := Node.new()
		anim.set_script(load("res://ui/entity_animation_controller.gd"))
		anim.name = "AnimationController"
		node.add_child(anim)
		# Asignar visual_node después de add_child para que _ready() lo encuentre
		anim.set("visual_node", sprite)
 
		# CompanionAI
		var ai := Node.new()
		ai.set_script(load("res://core/companions/companion_ai.gd"))
		ai.name = "CompanionAI"
		ai.set("companion_id", companion_id)
		ai.set("attack_skill_id", "skill.attack.light")
		node.add_child(ai)
 
		$EnemyContainer.add_child(node)  # Reutiliza el contenedor o crea CompanionContainer
		idx += 1
 
	print("[CombatTestScene] Spawned %d companion nodes" % idx)
 
 
func _update_companion_bar(companion_id: String, bar: ProgressBar, label: Label) -> void:
	var state := Resources.get_resource_state(companion_id, "health")
	if state == null:
		return
 
	var hp := Resources.get_resource_amount(companion_id, "health")
	var hp_max := state.max_effective
	var pct := (hp / hp_max) * 100.0 if hp_max > 0 else 0.0
 
	_update_bar_smooth(bar, pct)
 
	var party := get_node_or_null("/root/Party")
	if party and party.is_incapacitated(companion_id):
		bar.modulate = Color(0.5, 0.5, 0.5)
		label.text = "[INCAP] %s" % companion_id.replace("companion_", "").capitalize()
		label.modulate = Color(0.5, 0.5, 0.5)
	else:
		bar.modulate = Color(0.4, 0.8, 1.0)
		label.text = "%s HP:" % companion_id.replace("companion_", "").capitalize()
		label.modulate = Color(0.4, 0.8, 1.0)

# ============================================
# GESTIÓN DE COMBATE
# ============================================

func _start_combat() -> void:
	if not game_loop:
		push_error("[CombatTest] GameLoop not found!")
		return
	print("\n[CombatTest] Starting combat (standalone)...")

	var standalone_ids: Array[String] = ["enemy_1", "enemy_2", "enemy_3"]

	# Registrar entidades manualmente — ExplorationController no actuó en standalone
	var chars: CharacterSystem = get_node_or_null("/root/Characters")
	var resources: ResourceSystem = get_node_or_null("/root/Resources")
	for enemy_id in standalone_ids:
		if chars and not chars.has_entity(enemy_id):
			chars.register_entity(enemy_id, "enemy_base")
		resources.register_entity(enemy_id)
		resources.set_resource(enemy_id, "health", 50.0)

	# Limpiar nodos de combate anteriores.
	# queue_free() es diferido — los nodos viejos coexistirán con los nuevos
	# durante este frame y desaparecerán al final. Aceptable para spike.
	for child in $EnemyContainer.get_children():
		child.queue_free()

	game_loop.start_combat(standalone_ids)

	# Re-spawnear nodos visuales — _ready() no vuelve a correr en restart
	_initialize_enemies_from_gameloop()

func _on_player_turn_started():
	print("[CombatTest] Player turn")
	combat_status_label.text = "Status: YOUR TURN - Select action"
	# NO usar attack_button (no existe en tu escena)

func _on_enemy_turn_started(enemy_id: String):
	print("[CombatTest] Enemy turn: %s" % enemy_id)
	combat_status_label.text = "Status: ENEMY TURN - %s" % enemy_id
	# NO usar attack_button (no existe en tu escena)

func _on_turn_phase_changed(new_phase: int):
	var phase_name = GameLoopSystem.TurnPhase.keys()[new_phase]
	print("[CombatTest] Phase: %s" % phase_name)
	# Actualizar UI según fase
	match new_phase:
		GameLoopSystem.TurnPhase.PLAYER_ACTION_SELECT:
			combat_status_label.text = "Status: YOUR TURN"
		GameLoopSystem.TurnPhase.ENEMY_ACTION_RESOLVE:
			combat_status_label.text = "Status: ENEMY TURN"

func _on_combat_ended(result: String):
	print("[CombatTest] Combat ended: %s" % result)
	if result == "victory":
		combat_status_label.text = "Status: VICTORY! (Press F5 to restart)"
	elif result == "defeat":
		combat_status_label.text = "Status: DEFEAT (Press F5 to restart)"

func _on_target_changed(new_target: String):
	# Actualizar indicador de target en UI
	target_label.text = "Target: %s" % new_target

func _on_combat_action_completed(result: Dictionary):
	if result.get("success", false):
		var damage = result.get("damage", 0)
		var crit = result.get("critical", false)
		var msg = "Damage: %.1f" % damage
		if crit:
			msg += " (CRITICAL!)"
		print("[CombatTest] Action result: %s" % msg)

# ============================================
# EVENTOS DE COMBATE
# ============================================

func _connect_combat_events():
	Combat.combat_started.connect(_on_combat_started)
	Combat.combat_ended.connect(_on_combat_ended)
	Combat.combat_action_executed.connect(_on_combat_action_executed)
	Combat.enemy_defeated.connect(_on_enemy_defeated)
	Combat.target_changed.connect(_on_target_changed)


func _on_combat_started(enemies: Array):
	print("\n[CombatTest] Combat started! Enemies: %s" % [str(enemies)])

func _on_combat_action_executed(actor_id: String, skill_id: String, target_id: String, result: Dictionary):
	var damage = result.get("damage", 0)
	
	last_action_label.text = "Last Action: %s -> %s (%.1f dmg)" % [
		actor_id, target_id, damage
	]
	
	print("[CombatTest] Action: %s used %s on %s → %.1f damage" % [
		actor_id, skill_id, target_id, damage
	])


func _on_enemy_defeated(enemy_id: String):
	print("[CombatTest] Enemy defeated: %s" % enemy_id)

	var enemy_node = get_tree().get_first_node_in_group(enemy_id)
	if enemy_node:
		# Reproducir animación de muerte
		var anim_controller = enemy_node.get_node_or_null("AnimationController")
		if anim_controller:
			anim_controller.play_death()
		else:
			enemy_node.modulate = Color(0.5, 0.5, 0.5, 0.5)

func _on_game_state_changed(new_state: int):
	var state_name = GameLoopSystem.GameState.keys()[new_state]
	print("[CombatTest] State: %s" % state_name)
	match new_state:
		GameLoopSystem.GameState.MENU:
			combat_status_label.text = "Status: MENU"
		GameLoopSystem.GameState.COMBAT_ACTIVE:
			combat_status_label.text = "Status: IN COMBAT"
		GameLoopSystem.GameState.VICTORY:
			combat_status_label.text = "Status: VICTORY! 🎉"
		GameLoopSystem.GameState.DEFEAT:
			combat_status_label.text = "Status: DEFEAT 💀"

# ============================================
# ACTUALIZACIÓN DE UI
# ============================================

func _process(_delta):
	_update_ui()

func _update_ui():
	# Combat status
	if game_loop:
		var state_name = GameLoopSystem.GameState.keys()[game_loop.current_game_state]
		combat_status_label.text = "Status: %s" % state_name
	
	# Player stats - HP
	var player_hp = Resources.get_resource_amount("player", "health")
	var player_hp_max = Resources.get_resource_state("player", "health").max_effective
	var player_hp_pct = (player_hp / player_hp_max) * 100.0 if player_hp_max > 0 else 0.0
	
	#player_hp_bar.value = player_hp_pct
	_update_bar_smooth(player_hp_bar, player_hp_pct)
	_set_bar_color(player_hp_bar, player_hp_pct / 100.0)
	
	# Player stats - Stamina
	var player_stamina = Resources.get_resource_amount("player", "stamina")
	var player_stamina_max = Resources.get_resource_state("player", "stamina").max_effective
	var player_stamina_pct = (player_stamina / player_stamina_max) * 100.0 if player_stamina_max > 0 else 0.0
	
	player_stamina_bar.value = player_stamina_pct
	# Stamina siempre azul
	player_stamina_bar.modulate = Color(0.3, 0.7, 1.0)
	
	# Enemy stats — barras generadas dinámicamente en _build_enemy_bars()
	for enemy_id in _enemy_bars.keys():
		var entry = _enemy_bars[enemy_id]
		_update_enemy_bar(enemy_id, entry["bar"], entry["label"])

	## Barras de los compañeros del player generadas dinamicamente
	for companion_id in _companion_bars.keys():
		var entry = _companion_bars[companion_id]
		_update_companion_bar(companion_id, entry["bar"], entry["label"])
	
		# ✨ FASE A.5: Escape Info
	_update_escape_info(player_stamina)

func _update_enemy_bar(enemy_id: String, bar: ProgressBar, label: Label):
	var state = Resources.get_resource_state(enemy_id, "health")
	if state == null:
		return  # Entidad aún no registrada — skip silencioso
	var enemy_hp = Resources.get_resource_amount(enemy_id, "health")
	var enemy_hp_max = state.max_effective
	var hp_pct = (enemy_hp / enemy_hp_max) * 100.0 if enemy_hp_max > 0 else 0.0
	
	_update_bar_smooth(bar, hp_pct)
	# ✅ CORRECTO - Ahora PlayerCombatController tiene get_current_target()
	var player_controller = player_node.get_node_or_null("PlayerCombatController")
	if player_controller and player_controller.has_method("get_current_target"):
		var current_target = player_controller.get_current_target()
		if current_target == enemy_id:
			bar.modulate = Color.YELLOW
			label.text = ">>> %s" % enemy_id
			label.modulate = Color.YELLOW
		else:
			_set_bar_color(bar, hp_pct)
			label.text = "    %s" % enemy_id
			label.modulate = Color.WHITE
	else:
		# Fallback si no hay controller
		_set_bar_color(bar, hp_pct)
		label.text = "    %s" % enemy_id
		label.modulate = Color.WHITE

# ============================================
# UI HELPERS (FASE B.3)
# ============================================

## Establece el color de una barra según porcentaje de HP
func _set_bar_color(bar: ProgressBar, percentage: float):
	if percentage > 0.6:
		# Verde: > 60%
		bar.modulate = Color(0.3, 1.0, 0.3)
	elif percentage > 0.3:
		# Amarillo: 30-60%
		bar.modulate = Color(1.0, 0.9, 0.2)
	else:
		# Rojo: < 30%
		bar.modulate = Color(1.0, 0.3, 0.3)

## Actualiza una barra con transición suave (Tween)
func _update_bar_smooth(bar: ProgressBar, new_value: float):
	if bar.value == new_value:
		return
	
	var tween = create_tween()
	tween.tween_property(bar, "value", new_value, 0.3).set_ease(Tween.EASE_OUT)
	
# ============================================
# DEBUG INPUT
# ============================================

func _input(event):
	if not event is InputEventKey or not event.pressed:
		return
	
	if event.keycode == KEY_F5:
		# Reiniciar recursos del player
		Resources.set_resource("player", "health", 100)
		Resources.set_resource("player", "stamina", 100)
		# Reiniciar recursos de todos los enemigos activos
		for enemy_id in _enemy_bars.keys():
			Resources.set_resource(enemy_id, "health", 50)
		_start_combat()
		get_viewport().set_input_as_handled()

	if event.keycode == KEY_F6:
		if game_loop:
			game_loop.end_combat("victory")  # ✅
		get_viewport().set_input_as_handled()
	
	# F7: Print debug info
	if event.keycode == KEY_F7:
		_print_debug_info()
		get_viewport().set_input_as_handled()
	
	# Tab: Cycle target
	if event.keycode == KEY_TAB:
		var controller = player_node.get_node_or_null("PlayerCombatController")
		if controller and controller.has_method("cycle_target"):
			controller.cycle_target()
		get_viewport().set_input_as_handled()
	

func _print_debug_info():
	print("\n" + "=".repeat(60))
	print("DEBUG INFO")
	print("=".repeat(60))
	
	Combat.print_combat_state()
	Resources.print_entity_resources("player")
	Resources.print_entity_resources("enemy_1")
	Skills.print_entity_skills("player")
	
	print("=".repeat(60) + "\n")

# ============================================
# ESCAPE UI (FASE A.5)
# ============================================
# Copiar esta sección completa al final de combat_test_scene.gd

## Actualiza el label de información de escape
func _update_escape_info(current_stamina: float):
	# Verificar si estamos en combate
	if not game_loop or not game_loop.is_in_combat():
		escape_info_label.text = ""
		escape_info_label.visible = false
		return
	
	# Calcular threshold basado en número de enemigos
	var enemies = game_loop.get_active_enemies()
	var enemy_count = enemies.size()
	var threshold = 20 + (enemy_count * 10)  # BASE_THRESHOLD + (enemigos × PER_ENEMY)
	
	# ⚠️ NOTA: is_escape_pending() y is_defending() ya no existen en Combat refactorizado
	# Si tienes sistema de escape/defensa, necesitas implementarlo en GameLoopSystem
	# Por ahora, simplificamos:
	
	if current_stamina >= threshold:
		escape_info_label.text = "Press [F] to escape (%d stamina)" % threshold
		escape_info_label.modulate = Color.CYAN
	else:
		var missing = threshold - current_stamina
		escape_info_label.text = "Escape: %d stamina (need %d more)" % [threshold, missing]
		escape_info_label.modulate = Color.GRAY
	
	escape_info_label.visible = true
