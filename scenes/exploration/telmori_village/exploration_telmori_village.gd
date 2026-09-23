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
	_register_telmori_ambush_trail_cleanup()
	_register_telmori_lair_combat_continuation()
	_register_telmori_lair_reward_continuation()

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

	# Mejoras post-Spike 3, Grupo 1 — antes comprobaba "!= EXPLORATION", lo
	# que asumía implícitamente que esta escena SOLO podía instanciarse
	# cuando GameState ya era (o debía pasar a ser) EXPLORATION. Desde que
	# SceneOrchestrator puede instanciar esta escena como sustrato de
	# NARRATIVE_SCENE (ver _ensure_exploration_scene_instantiated()), eso ya
	# no es cierto: si current_game_state es NARRATIVE_SCENE aquí, es
	# legítimo, no un estado a corregir. Solo hay que auto-inicializar
	# cuando de verdad no hay nada establecido todavía — MENU, el valor por
	# defecto de GameLoopSystem cuando esta escena se ejecuta suelta desde
	# el editor sin pasar por GameLoop/SceneOrchestrator. Con "!= EXPLORATION"
	# esto disparaba una transición NARRATIVE_SCENE → EXPLORATION reentrante
	# en mitad de _handle_narrative_scene(), cerrando el panel narrativo que
	# se estaba abriendo en el mismo instante.
	var game_loop: GameLoopSystem = get_node_or_null("/root/GameLoop")
	if game_loop:
		if game_loop.current_game_state == GameLoopSystem.GameState.MENU:
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


# ============================================
# SPIKE 3, GRUPO C — LIMPIEZA DEL RASTRO DE GRUPO B
# ============================================

## Toda la cadena de Grupo C (telmori_guarida_door → telmori_lair_approach →
## combate final) es 100% narrativa, sin ningún paso real por exploración
## 2D de por medio — el jugador nunca se mueve en el mundo mientras dura.
## Su posición en la escena sigue siendo la misma que dejó tras ganar la
## emboscada de Grupo B, justo donde vive "telmori_ambush_trail" — que
## sigue registrado y en rango durante toda la cadena de Grupo C. Al volver
## por fin a EXPLORATION tras el combate final de la guarida, ese
## interactuable obsoleto sigue ahí y puede volver a disparar
## telmori_post_ambush_tracking, una escena ya completada — dando la
## sensación de que el juego "retrocede" al claro de la emboscada.
##
## Se retira en cuanto deja de tener sentido: cuando el jugador COMPLETA
## con éxito la racha de rastreo (flag.telmori_tracked_to_lair, puesto por
## la rama outcome_success de telmori_post_ambush_tracking.json) — a partir
## de ahí la cadena sigue hacia telmori_guarida_door y la guarida, sin
## volver a necesitarlo.
##
## OJO — enganchado a EventBus.narrative_flag_set, NO a
## narrative_scene_closed: en el camino de éxito, telmori_post_ambush_tracking
## encadena internamente a telmori_guarida_door y luego a
## telmori_lair_approach SIN cerrar el panel (el ViewModel solo cambia de
## contenido, no pasa por EXPLORATION) — así que narrative_scene_closed con
## scene_id="telmori_post_ambush_tracking" nunca llega a emitirse en ese
## camino (solo en el de fallo, donde next_scene_id sí queda vacío y cierra
## de verdad). El flag es la única señal fiable de que la racha se completó.
func _register_telmori_ambush_trail_cleanup() -> void:
	if not EventBus.narrative_flag_set.is_connected(_on_narrative_flag_set_trail_cleanup):
		EventBus.narrative_flag_set.connect(_on_narrative_flag_set_trail_cleanup)


func _on_narrative_flag_set_trail_cleanup(flag_name: String) -> void:
	if flag_name != "flag.telmori_tracked_to_lair":
		return

	var trail_node: Node = get_node_or_null("WorldObjects/telmori_ambush_trail")
	if trail_node:
		print("[TelmoriVillage] Tracking succeeded — removing obsolete ambush trail")
		trail_node.queue_free()

	# El listener de combat_ended de la emboscada (flag.telmori_ambush_triggered
	# nunca se desactiva) se desconecta aquí: sin esto, CUALQUIER combate
	# posterior que termine en victoria — incluidos los de la guarida de
	# Grupo C — lo reactivaría, y como el nodo ya no existe (justo lo que
	# acabamos de borrar), su guardia contra duplicados deja de proteger y
	# lo vuelve a spawnear apuntando otra vez a telmori_post_ambush_tracking.
	# El arco de la emboscada ya está resuelto en este punto, no necesita
	# seguir escuchando.
	if EventBus.combat_ended.is_connected(_on_combat_ended_telmori_ambush):
		EventBus.combat_ended.disconnect(_on_combat_ended_telmori_ambush)


# ============================================
# SPIKE 3, GRUPO C — RECONEXIÓN TRAS EL COMBATE FINAL DE LA GUARIDA
# ============================================

## Mismo problema que resolvió Grupo B para la emboscada, aplicado ahora al
## combate final de telmori_lair_alerted/telmori_lair_stealth: un combate
## disparado desde una escena narrativa vuelve a EXPLORATION al ganar, pero
## no existe ningún camino de motor que reabra una escena narrativa por sí
## solo — el único mecanismo validado en el proyecto es spawnear un
## Interactable y esperar a que el jugador lo use. Sin esto, ganar el
## combate de la guarida deja al jugador en EXPLORATION sin más, sin llegar
## nunca a telmori_lair_victory (bug reportado tras la primera partida real
## de Grupo C).
##
## Un único flag (flag.telmori_lair_combat_won) cubre las dos ramas —
## alertados y sigilosa ponen el mismo flag al disparar su combate, así
## que este listener no necesita distinguir cuál de las dos ganó; ambas
## llevan al mismo telmori_lair_victory.
func _register_telmori_lair_combat_continuation() -> void:
	if not EventBus.combat_ended.is_connected(_on_combat_ended_telmori_lair):
		EventBus.combat_ended.connect(_on_combat_ended_telmori_lair)
	if not EventBus.narrative_flag_set.is_connected(_on_narrative_flag_set_lair_aftermath_cleanup):
		EventBus.narrative_flag_set.connect(_on_narrative_flag_set_lair_aftermath_cleanup)


func _on_combat_ended_telmori_lair(result: String) -> void:
	if result != "victory":
		return
	if not Narrative.has_flag("flag.telmori_lair_combat_won"):
		return
	if get_node_or_null("WorldObjects/telmori_lair_aftermath"):
		return  # ya spawneado

	print("[TelmoriVillage] Telmori lair combat won — spawning victory continuation")

	var spawn_position: Vector2 = (trail_spawn_point.global_position + Vector2(120, 0)) if trail_spawn_point else Vector2(520, 300)

	var aftermath_node := Node2D.new()
	aftermath_node.name = "telmori_lair_aftermath"
	aftermath_node.position = spawn_position

	var sprite := Sprite2D.new()
	var texture: Texture2D = load("res://icon.svg")
	if texture:
		sprite.texture = texture
		sprite.modulate = Color(0.3, 0.5, 0.6)
		sprite.scale = Vector2(0.2, 0.2)
	aftermath_node.add_child(sprite)

	var lbl := Label.new()
	lbl.text = "Guarida despejada"
	lbl.position = Vector2(-40, -30)
	aftermath_node.add_child(lbl)

	var interactable_script := load("res://scenes/exploration/interactable.gd")
	if interactable_script:
		var area := Area2D.new()
		area.set_script(interactable_script)
		area.set("interaction_type", "narrative_scene")
		area.set("target_id", "telmori_lair_victory")
		area.set("prompt_key", "UI_TELMORI_LAIR_AFTERMATH_INTERACT")

		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 25.0
		shape.shape = circle
		area.add_child(shape)
		aftermath_node.add_child(area)

		area.player_in_range.connect(exploration_controller.register_interactable)
		area.player_out_of_range.connect(exploration_controller.unregister_interactable)
	else:
		push_error("[TelmoriVillage] interactable.gd not found")

	$WorldObjects.add_child(aftermath_node)


## telmori_lair_victory es una única rama sin reintento posible — a
## diferencia del rastro de Grupo B, no hace falta condicionar la limpieza
## a ningún flag de "éxito parcial". Enganchado a flag.telmori_lair_cleared
## (puesto por el propio outcome_default de telmori_lair_victory.json) en
## vez de a narrative_scene_closed, por consistencia con la solución de
## _on_narrative_flag_set_trail_cleanup — misma familia de problema, mismo
## mecanismo fiable, aunque aquí el cierre por scene_id debería funcionar
## bien (next_scene_id vacío, cierre real).
func _on_narrative_flag_set_lair_aftermath_cleanup(flag_name: String) -> void:
	if flag_name != "flag.telmori_lair_cleared":
		return

	var aftermath_node: Node = get_node_or_null("WorldObjects/telmori_lair_aftermath")
	if aftermath_node:
		aftermath_node.queue_free()

	# Mismo motivo que en _on_narrative_flag_set_trail_cleanup: sin
	# desconectar, cualquier combate futuro de Grupo D que termine en
	# victoria reactivaría este listener y resucitaría el nodo ya borrado.
	if EventBus.combat_ended.is_connected(_on_combat_ended_telmori_lair):
		EventBus.combat_ended.disconnect(_on_combat_ended_telmori_lair)

# ============================================
# SPIKE 3, GRUPO D — RECOMPENSA DEL SHERIFF Y SU LIMPIEZA
# ============================================

## Disparador distinto a los dos anteriores: no hay combate de por medio.
## flag.telmori_lair_cleared se marca al final de la cadena de botín
## (telmori_lair_victory → telmori_lair_loot_obsidian), así que basta con
## escuchar narrative_flag_set — no hace falta EventBus.combat_ended aquí.
func _register_telmori_lair_reward_continuation() -> void:
	if not EventBus.narrative_flag_set.is_connected(_on_narrative_flag_set_reward_spawn):
		EventBus.narrative_flag_set.connect(_on_narrative_flag_set_reward_spawn)
	if not EventBus.narrative_flag_set.is_connected(_on_narrative_flag_set_reward_cleanup):
		EventBus.narrative_flag_set.connect(_on_narrative_flag_set_reward_cleanup)


## Filtra por flag_name, igual que los cleanups de Grupo C — no necesita
## desconectarse a sí mismo: flag.telmori_lair_cleared se pone una sola vez
## en toda la partida, a diferencia de EventBus.combat_ended, que es
## genérico y se dispara con cualquier combate no relacionado (la lección
## de Grupo C aplica a listeners de combat_ended, no a estos).
func _on_narrative_flag_set_reward_spawn(flag_name: String) -> void:
	if flag_name != "flag.telmori_lair_cleared":
		return
	if get_node_or_null("WorldObjects/telmori_sheriff_reward"):
		return  # ya spawneado

	print("[TelmoriVillage] Lair loot collected — spawning sheriff reward point")

	var spawn_position: Vector2 = (trail_spawn_point.global_position + Vector2(240, 0)) if trail_spawn_point else Vector2(640, 300)

	var reward_node := Node2D.new()
	reward_node.name = "telmori_sheriff_reward"
	reward_node.position = spawn_position

	var sprite := Sprite2D.new()
	var texture: Texture2D = load("res://icon.svg")
	if texture:
		sprite.texture = texture
		sprite.modulate = Color(0.8, 0.7, 0.2)
		sprite.scale = Vector2(0.2, 0.2)
	reward_node.add_child(sprite)

	var lbl := Label.new()
	lbl.text = "Sheriff"
	lbl.position = Vector2(-30, -30)
	reward_node.add_child(lbl)

	var interactable_script := load("res://scenes/exploration/interactable.gd")
	if interactable_script:
		var area := Area2D.new()
		area.set_script(interactable_script)
		area.set("interaction_type", "narrative_scene")
		area.set("target_id", "telmori_sheriff_reward_intro")
		area.set("prompt_key", "UI_TELMORI_SHERIFF_REWARD_INTERACT")

		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 25.0
		shape.shape = circle
		area.add_child(shape)
		reward_node.add_child(area)

		area.player_in_range.connect(exploration_controller.register_interactable)
		area.player_out_of_range.connect(exploration_controller.unregister_interactable)
	else:
		push_error("[TelmoriVillage] interactable.gd not found")

	$WorldObjects.add_child(reward_node)


## Retira el interactuable de recompensa en cuanto el jugador termina la
## cadena completa (flag.telmori_adventure_completed, puesto por
## telmori_epilogue_hook) — sin esto, el jugador podría reentrar en
## telmori_sheriff_reward_intro → telmori_sheriff_pelts indefinidamente y
## acumular oro/ítems sin límite. Riesgo distinto al de Grupo C (ahí era
## "resucita contenido ya visto", aquí es "economía explotable"), pero
## misma solución: escuchar el flag correcto, no el cierre del panel.
func _on_narrative_flag_set_reward_cleanup(flag_name: String) -> void:
	if flag_name != "flag.telmori_adventure_completed":
		return

	var reward_node: Node = get_node_or_null("WorldObjects/telmori_sheriff_reward")
	if reward_node:
		print("[TelmoriVillage] Adventure completed — removing sheriff reward point")
		reward_node.queue_free()
