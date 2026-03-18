extends Node2D

## ExplorationTest — Escena raíz de exploración (spike)

@onready var player: PlayerExploration = $Player
@onready var exploration_controller: ExplorationController = $ExplorationController
@onready var exploration_hud: ExplorationHUD = $ExplorationHUD

## Mantiene referencias a LootBagWatcher vivos hasta que cada bolsa es recogida.
## Sin esto el RefCounted se destruye al salir del scope y el callable muere.
var _loot_watchers: Array = []

func _ready() -> void:
	print("\n" + "=".repeat(50))
	print("EXPLORATION SCENE — INITIALIZING")
	print("=".repeat(50))

	_register_player()
	_register_world_objects()   # conecta combat_loot_bag_spawned aquí
	_connect_interactables()
	_inject_hud()

	# Si hay loot pendiente de un combate anterior, spawnearlo ahora.
	var loot_spawner = get_node_or_null("/root/CombatLootSpawner")
	if loot_spawner and loot_spawner.has_pending_loot():
		loot_spawner.spawn_pending_loot()

	# Transicionar a EXPLORATION solo si no está ya en ese estado
	var game_loop: GameLoopSystem = get_node_or_null("/root/GameLoop")
	if game_loop:
		if game_loop.current_game_state != GameLoopSystem.GameState.EXPLORATION:
			game_loop.enter_exploration()
	else:
		push_error("[ExplorationTest] GameLoop not found — inventory will be blocked")

	if exploration_hud:
		exploration_hud.refresh()

	print("[ExplorationTest] Ready")


func _register_player() -> void:
	var chars: CharacterSystem = get_node_or_null("/root/Characters")
	var resources: ResourceSystem = get_node_or_null("/root/Resources")
	var equipment: EquipmentManager = get_node_or_null("/root/Equipment")
	
	if chars:
		if not chars.has_entity("player"):
			chars.register_entity("player", "player_base")
			print("[ExplorationTest] Player registered in CharacterSystem")
		else:
			print("[ExplorationTest] Player already in CharacterSystem — skipping")
	else:
		push_error("[ExplorationTest] CharacterSystem not found")

	var skills = get_node_or_null("/root/Skills")
	if skills:
		if not skills._entity_skills.has("player"):
			skills.register_entity_skills("player")
			print("[ExplorationTest] Player registered in SkillSystem")
		else:
			print("[ExplorationTest] Player already in SkillSystem — skipping")
	else:
		push_warning("[ExplorationTest] SkillSystem not found")
	
	if resources:
		resources.register_entity("player")
		print("[ExplorationTest] Player registered in ResourceSystem")
	else:
		push_error("[ExplorationTest] ResourceSystem not found")
	
	if equipment:
		equipment.register_entity("player")
		print("[ExplorationTest] Player registered in EquipmentManager")
	else:
		push_warning("[ExplorationTest] EquipmentManager not found at /root/Equipment — skipping")
	
	# Ítems de prueba para el spike (spike only — en producción vendrán del SaveSystem)
	var inventory: InventorySystem = get_node_or_null("/root/Inventory")
	if inventory:
		inventory.register_entity("player")
		inventory.add_item("player", "health_potion", 3)
		inventory.add_item("player", "stamina_potion_small", 2)
		inventory.add_item("player", "iron_sword", 1)
		inventory.add_item("player", "item.book.combat_basics", 1)
		print("[ExplorationTest] Test items added to player inventory")
	
	# Oro inicial de prueba (spike only)
	if resources:
		resources.set_resource("player", "gold", 500.0)  # set, no add — evita acumular sobre el max inicial
		print("[ExplorationTest] Added 500 gold for testing")

	_unlock_starting_skills()



func _unlock_starting_skills() -> void:
	## skill.attack.light comienza desbloqueada para el jugador.
	## skill.attack.heavy requiere unlock explícito (via NPC_Maestro).
	var skills = get_node_or_null("/root/Skills")
	if not skills:
		push_warning("[ExplorationTest] SkillSystem not found — cannot unlock starting skills")
		return

	# Iterar todas las entidades/skills registradas y ajustar is_unlocked directamente.
	# No usamos unlock_skill() porque ese método valida prerequisites y emite eventos —
	# aquí solo queremos establecer el estado inicial sin efectos secundarios.
	if not skills._entity_skills.has("player"):
		push_warning("[ExplorationTest] Player not registered in SkillSystem")
		return

	for skill_id in skills._entity_skills["player"].keys():
		var instance = skills._entity_skills["player"][skill_id]
		if skill_id == "skill.attack.heavy":
			instance.is_unlocked = false
			print("[ExplorationTest] %s → LOCKED (requiere NPC_Maestro)" % skill_id)
		else:
			instance.is_unlocked = true
			print("[ExplorationTest] %s → UNLOCKED (starter)" % skill_id)


func _register_world_objects() -> void:
	var wo_system: Node = get_node_or_null("/root/WorldObjectSystem")
	if not wo_system:
		push_warning("[ExplorationTest] WorldObjectSystem not found — world objects will not work")
		return

	# ── Registrar instancias de WorldObject presentes en la escena ──────────
	wo_system.register_instance("chest_01", "chest_01")

	# ── Instanciar WorldObjectBridge (aplica loot + narrativa) ──────────────
	var bridge_script := load("res://core/world_objects/world_object_bridge.gd")
	if bridge_script:
		var bridge := Node.new()
		bridge.name = "WorldObjectBridge"
		bridge.set_script(bridge_script)
		add_child(bridge)
		print("[ExplorationTest] WorldObjectBridge instantiated")
	else:
		push_error("[ExplorationTest] world_object_bridge.gd not found")

	# ── Instanciar WorldObjectInteractionPanel (UI overlay) ─────────────────
	var panel_scene := load("res://ui/world_objects/world_object_interaction_panel.tscn")
	if panel_scene:
		var panel: CanvasLayer = panel_scene.instantiate() as CanvasLayer
		panel.name = "WorldObjectInteractionPanel"
		add_child(panel)
		print("[ExplorationTest] WorldObjectInteractionPanel instantiated")

		panel.visibility_changed.connect(func():
			if exploration_controller:
				exploration_controller.set_process_unhandled_input(not panel.visible)
		)
	else:
		push_error("[ExplorationTest] world_object_interaction_panel.tscn not found")

	# ── Escuchar loot bags de combate ────────────────────────────────────────
	EventBus.combat_loot_bag_spawned.connect(_on_combat_loot_bag_spawned)

	# Escuchar combat_ended para spawnar loot cuando la victoria se confirma.
	# NOTA: combat_ended llega DESPUÉS de game_state_changed(EXPLORATION),
	# por eso no podemos usar game_state_changed — el flag _pending_loot aún no está activo.
	EventBus.combat_ended.connect(_on_combat_ended_for_loot)

	# Escuchar retorno a exploración (desde combate) para spawnar loot pendiente
	EventBus.game_state_changed.connect(_on_game_state_changed)

	print("[ExplorationTest] WorldObjects registered")


## Instancia un nodo visual de bolsa de loot cuando un combate termina en victoria.
## La bolsa aparece en la posición donde estaba el enemigo derrotado.
func _on_combat_loot_bag_spawned(enemy_id: String, instance_id: String, _combat_position: Vector2) -> void:
	print("[ExplorationTest] Spawning loot bag: %s" % instance_id)

	# Ocultar el nodo del enemigo y desactivar su Interactable
	var enemy_scene_node: Node2D = $NPCs.get_node_or_null(enemy_id)
	if not enemy_scene_node:
		enemy_scene_node = $NPCs.get_node_or_null("Enemigo")
	if enemy_scene_node:
		enemy_scene_node.visible = false
		# Desactivar el Interactable y su colisión física
		var interactable: Interactable = enemy_scene_node.get_node_or_null("Interactable")
		if interactable:
			interactable.deactivate()
			interactable.monitoring = false
			interactable.monitorable = false
		print("[ExplorationTest] Enemy node hidden and deactivated: %s" % enemy_scene_node.name)
	else:
		push_warning("[ExplorationTest] Enemy scene node not found for: %s" % enemy_id)

	# Posición base del enemigo en la escena de exploración
	var spawn_position: Vector2 = Vector2.ZERO
	if enemy_scene_node:
		spawn_position = enemy_scene_node.global_position

	# Offset por índice para separar bolsas si hay varios enemigos apilados
	var bag_index := $NPCs.get_children().filter(
		func(n): return n.name.begins_with("loot_bag_")
	).size()
	spawn_position += Vector2(bag_index * 20, 0)

	# Nodo raíz de la bolsa
	var bag_node := Node2D.new()
	bag_node.name = instance_id
	bag_node.position = spawn_position

	# Sprite visual — chest.png como placeholder de bolsa
	var sprite := Sprite2D.new()
	var texture: Texture2D = load("res://data/items/chest.png")
	if texture:
		sprite.texture = texture
		sprite.scale = Vector2(0.15, 0.15)
	else:
		push_warning("[ExplorationTest] chest.png not found — loot bag will be invisible")
	bag_node.add_child(sprite)

	# Label identificativo (debug)
	var lbl := Label.new()
	lbl.text = "Loot"
	lbl.position = Vector2(-15, -30)
	bag_node.add_child(lbl)

	# Interactable — conecta la bolsa al pipeline WorldObject existente
	var interactable_script := load("res://scenes/exploration/interactable.gd")
	if interactable_script:
		var area := Area2D.new()
		area.set_script(interactable_script)
		area.set("interaction_type", "item")
		area.set("target_id", instance_id)
		area.set("prompt_key", "UI_LOOT_BAG_INTERACT")

		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 25.0
		shape.shape = circle
		area.add_child(shape)
		bag_node.add_child(area)

		area.player_in_range.connect(exploration_controller.register_interactable)
		area.player_out_of_range.connect(exploration_controller.unregister_interactable)
	else:
		push_error("[ExplorationTest] interactable.gd not found")

	$NPCs.add_child(bag_node)
	print("[ExplorationTest] Loot bag placed at: %s" % str(spawn_position))

	# Crear watcher y guardarlo en el array para evitar que el GC lo destruya.
	# LootBagWatcher es RefCounted — sin referencia fuerte se libera al salir del scope.
	var watcher := LootBagWatcher.new(instance_id, bag_node, _loot_watchers)
	_loot_watchers.append(watcher)
	EventBus.world_object_state_changed.connect(watcher.on_state_changed)


## Objeto auxiliar que monitoriza el estado de UNA bolsa de loot concreta.
## Instancia separada por bolsa = callable único = sin colisión en connect().
## Se almacena en _loot_watchers para sobrevivir al scope de la función que lo crea.
class LootBagWatcher:
	var instance_id: String
	var bag_node: Node2D
	var watchers_array: Array  # referencia al array padre para auto-limpieza

	func _init(id: String, node: Node2D, arr: Array) -> void:
		instance_id = id
		bag_node = node
		watchers_array = arr

	func on_state_changed(changed_id: String, _flags: Array) -> void:
		if changed_id != instance_id:
			return
		if not is_instance_valid(bag_node):
			watchers_array.erase(self)
			return

		var wo: Node = bag_node.get_node_or_null("/root/WorldObjectSystem")
		if not wo or not wo.is_depleted(instance_id):
			return

		var eb: Node = bag_node.get_node_or_null("/root/EventBus")

		# Desconectar antes de destruir
		if eb and eb.world_object_state_changed.is_connected(on_state_changed):
			eb.world_object_state_changed.disconnect(on_state_changed)

		# Desactivar interactable y su colisión inmediatamente
		# queue_free() es diferido — el Area2D seguiría detectando colisiones ese frame
		var interactable: Node = bag_node.get_node_or_null("Interactable")
		if interactable:
			if interactable.has_method("deactivate"):
				interactable.deactivate()
			# Deshabilitar el Area2D para que no emita señales de colisión
			if interactable is Area2D:
				interactable.monitoring = false
				interactable.monitorable = false

		bag_node.queue_free()

		if eb:
			eb.combat_loot_collected.emit("player", instance_id)

		# Eliminar del array para liberar la referencia
		watchers_array.erase(self)
		print("[LootBagWatcher] Bag collected and removed: %s" % instance_id)


func _connect_interactables() -> void:
	var interactables := _find_interactables(self)
	for interactable in interactables:
		interactable.player_in_range.connect(exploration_controller.register_interactable)
		interactable.player_out_of_range.connect(exploration_controller.unregister_interactable)
	print("[ExplorationTest] Connected %d interactables" % interactables.size())


func _inject_hud() -> void:
	if exploration_controller and exploration_hud:
		exploration_controller.exploration_hud = exploration_hud
	else:
		push_warning("[ExplorationTest] Cannot inject HUD — node missing")


## Llamado cuando termina el combate. En este punto _pending_loot ya es true
## y ya estamos de vuelta en la escena de exploración (es aditiva, siempre viva).
func _on_combat_ended_for_loot(result: String) -> void:
	if result != "victory":
		return
	var loot_spawner = get_node_or_null("/root/CombatLootSpawner")
	if loot_spawner and loot_spawner.has_pending_loot():
		loot_spawner.spawn_pending_loot()


## Fallback: si por alguna razón el loot no se spawneó al volver a exploración
func _on_game_state_changed(new_state: int) -> void:
	if new_state != GameLoopSystem.GameState.EXPLORATION:
		return
	var loot_spawner = get_node_or_null("/root/CombatLootSpawner")
	if loot_spawner and loot_spawner.has_pending_loot():
		loot_spawner.spawn_pending_loot()


func _find_interactables(node: Node) -> Array[Interactable]:
	var result: Array[Interactable] = []
	for child in node.get_children():
		if child is Interactable:
			result.append(child)
		result.append_array(_find_interactables(child))
	return result
