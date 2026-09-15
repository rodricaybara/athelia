extends Node2D

## ExplorationTelmoriVillage — Escena raíz del pueblo de "Los Telmori"
##
## Igual que ExplorationTutorial: NO registra al jugador — Character
## Creation ya lo deja registrado en Characters/Resources/Skills/Equipment/
## Inventory antes de que GameLoop.enter_exploration() cargue esta escena.
##
## A diferencia del tutorial, casi todo el contenido de esta aventura vive
## encadenado dentro del panel narrativo (Grupo B: village_arrival →
## sheriff_briefing → equipment → hills_search → day2_approach → combate →
## post_ambush_tracking → guarida_door) — esta escena 2D solo hace dos
## cosas: 1) disparar la primera escena narrativa al entrar, una sola vez;
## 2) hacer aparecer el rastro de continuación cuando se gana la emboscada
## (Spike 3, Grupo B — plantilla validada, ver docs del spike).
##
## Sin WorldObjects (chests, etc.) todavía — se añade WorldObjectBridge/
## Panel cuando haga falta el primero; no tiene sentido instanciarlos vacíos.

@onready var player: PlayerExploration = $Player
@onready var exploration_controller: ExplorationController = $ExplorationController
@onready var exploration_hud: ExplorationHUD = $ExplorationHUD
@onready var trail_spawn_point: Marker2D = $WorldObjects/TrailSpawnPoint


func _ready() -> void:
	print("\n" + "=".repeat(50))
	print("TELMORI VILLAGE — INITIALIZING")
	print("=".repeat(50))

	_connect_interactables()
	_inject_hud()
	_register_telmori_ambush_continuation()

	# Companion desde el principio — más simple que ofrecerla como opción
	# narrativa. join_party() ya guarda contra unirse dos veces, así que
	# es seguro llamarlo en cada _ready() sin flag propio.
	var party: Node = get_node_or_null("/root/Party")
	if party:
		party.join_party("companion_mira")

	# Equipo inicial — jugador y companion, mismo kit para los dos.
	# equip_item() es seguro llamarlo repetido: si ya está equipado el
	# mismo ítem, se desequipa y reequipa sin duplicar modificadores.
	_equip_starter_gear("player")
	_equip_starter_gear("companion_mira")

	var game_loop: GameLoopSystem = get_node_or_null("/root/GameLoop")
	if game_loop:
		if game_loop.current_game_state != GameLoopSystem.GameState.EXPLORATION:
			game_loop.enter_exploration()
	else:
		push_error("[TelmoriVillage] GameLoop not found — inventory will be blocked")

	if exploration_hud:
		exploration_hud.refresh()

	# Arranque automático del gancho — una sola vez, guardado por flag.
	# No usa flag.telmori_mission_accepted (eso se marca más adelante en la
	# cadena, al aceptar en telmori_sheriff_briefing) porque este guard debe
	# cubrir desde el primer instante en que se entra a la escena, no desde
	# que se completa el primer tramo.
	if game_loop and not Narrative.has_flag("flag.telmori_village_visited"):
		Narrative.set_flag("flag.telmori_village_visited")
		print("[TelmoriVillage] First visit — entering telmori_village_arrival")
		game_loop.enter_narrative_scene("telmori_village_arrival")

	print("[TelmoriVillage] Ready")


func _connect_interactables() -> void:
	var interactables := _find_interactables(self)
	for interactable in interactables:
		interactable.player_in_range.connect(exploration_controller.register_interactable)
		interactable.player_out_of_range.connect(exploration_controller.unregister_interactable)
	print("[TelmoriVillage] Connected %d interactables" % interactables.size())


func _inject_hud() -> void:
	if exploration_controller and exploration_hud:
		exploration_controller.exploration_hud = exploration_hud
	else:
		push_warning("[TelmoriVillage] Cannot inject HUD — node missing")


func _find_interactables(node: Node) -> Array[Interactable]:
	var result: Array[Interactable] = []
	for child in node.get_children():
		if child is Interactable:
			result.append(child)
		result.append_array(_find_interactables(child))
	return result


## Equipo inicial de emergencia frente a la emboscada — casco, armadura,
## botas, escudo y espada. Va directo a Inventory + Equipment, sin pasar
## por ItemCharacterBridge (ese camino es para cuando el JUGADOR hace clic
## en "usar" un ítem desde la UI; aquí lo hacemos nosotros desde código,
## así que llamamos a los dos sistemas por separado tal como indica la
## NOTA 5 de equipment_manager.gd: "El Bridge valida ambas cosas antes de
## llamar a equip_item()" — Equipment.equip_item() en sí no exige que el
## ítem esté en el inventario, pero lo añadimos también para que quede
## coherente si el jugador lo desequipa más adelante.
func _equip_starter_gear(entity_id: String) -> void:
	var starter_gear: Array[String] = [
		"iron_helmet", "leather_armor", "leather_boots", "wooden_shield", "iron_sword"
	]
	for item_id in starter_gear:
		Inventory.add_item(entity_id, item_id, 1)
		Equipment.equip_item(entity_id, item_id)


# ============================================
# SPIKE 3, GRUPO B — RECONEXIÓN TRAS LA EMBOSCADA
# ============================================

## Llamado una vez desde _ready(). Requiere el patch ya aplicado de
## interactable.gd / exploration_controller.gd (interaction_type
## "narrative_scene").
func _register_telmori_ambush_continuation() -> void:
	if not EventBus.combat_ended.is_connected(_on_combat_ended_telmori_ambush):
		EventBus.combat_ended.connect(_on_combat_ended_telmori_ambush)


## Reacciona a cualquier combate terminado en victoria; solo actúa si el
## que acaba de terminar era la emboscada de Los Telmori (comprobado por
## el flag que telmori_day2_approach.json ya deja puesto al disparar el
## combate). Guard contra duplicados: si el rastro ya existe en el árbol,
## no crea otro — soporta volver a visitar la escena sin duplicar el
## objeto tras una derrota parcial en el rastreo posterior.
func _on_combat_ended_telmori_ambush(result: String) -> void:
	if result != "victory":
		return
	if not Narrative.has_flag("flag.telmori_ambush_triggered"):
		return
	if get_node_or_null("WorldObjects/telmori_ambush_trail"):
		return  # ya spawneado en una visita anterior

	print("[TelmoriVillage] Telmori ambush won — spawning trail continuation")

	var spawn_position: Vector2 = trail_spawn_point.global_position if trail_spawn_point else Vector2(400, 300)

	var trail_node := Node2D.new()
	trail_node.name = "telmori_ambush_trail"
	trail_node.position = spawn_position

	# Sprite placeholder — sustituir por arte real cuando exista
	var sprite := Sprite2D.new()
	var texture: Texture2D = load("res://icon.svg")
	if texture:
		sprite.texture = texture
		sprite.modulate = Color(0.6, 0.5, 0.3)
		sprite.scale = Vector2(0.2, 0.2)
	trail_node.add_child(sprite)

	var lbl := Label.new()
	lbl.text = "Rastro"
	lbl.position = Vector2(-20, -30)
	trail_node.add_child(lbl)

	# Interactable — abre telmori_post_ambush_tracking directamente, sin
	# pasar por WorldObjectSystem (no hace falta tirada de habilidad ni
	# loot table para esto, ya lo resuelve la propia escena narrativa)
	var interactable_script := load("res://scenes/exploration/interactable.gd")
	if interactable_script:
		var area := Area2D.new()
		area.set_script(interactable_script)
		area.set("interaction_type", "narrative_scene")
		area.set("target_id", "telmori_post_ambush_tracking")
		area.set("prompt_key", "UI_TELMORI_TRAIL_INTERACT")

		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 25.0
		shape.shape = circle
		area.add_child(shape)
		trail_node.add_child(area)

		area.player_in_range.connect(exploration_controller.register_interactable)
		area.player_out_of_range.connect(exploration_controller.unregister_interactable)
	else:
		push_error("[TelmoriVillage] interactable.gd not found")

	$WorldObjects.add_child(trail_node)
