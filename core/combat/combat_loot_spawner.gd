extends Node
## CombatLootSpawner - Gestiona el loot de combate al terminar con victoria
## Singleton: /root/CombatLootSpawner
##
## Fuentes de verdad:
##   _enemy_definitions  → todos los participantes del encuentro (de ExplorationController)
##   _defeated_enemies   → solo los que realmente murieron (de EventBus.enemy_defeated)

const PLAYER_ID := "player"

var _enemy_definitions: Dictionary = {}
var _defeated_enemies: Array[String] = []
var _pending_loot: bool = false


func _ready() -> void:
	if EventBus:
		EventBus.combat_ended.connect(_on_combat_ended)
		EventBus.enemy_defeated.connect(_on_enemy_defeated)
	print("[CombatLootSpawner] Initialized")


func register_combat_enemies(enemy_definitions: Dictionary) -> void:
	_enemy_definitions = enemy_definitions.duplicate()
	_defeated_enemies.clear()
	_pending_loot = false
	print("[CombatLootSpawner] Registered %d enemy definitions" % _enemy_definitions.size())


func has_pending_loot() -> bool:
	return _pending_loot


func spawn_pending_loot() -> void:
	if not _pending_loot:
		return

	print("[CombatLootSpawner] Spawning %d loot bags" % _defeated_enemies.size())

	for enemy_id in _defeated_enemies:
		var def_id: String = _enemy_definitions.get(enemy_id, "enemy_base")
		_evaluate_enemy_loot(enemy_id, def_id)

	_clear()


func _on_enemy_defeated(enemy_id: String) -> void:
	if not _enemy_definitions.has(enemy_id):
		return
	if enemy_id not in _defeated_enemies:
		_defeated_enemies.append(enemy_id)
	print("[CombatLootSpawner] Defeat registered: %s (total: %d)" % [enemy_id, _defeated_enemies.size()])


func _on_combat_ended(result: String) -> void:
	if result == "victory":
		_pending_loot = true
		print("[CombatLootSpawner] Victory recorded — %d enemies defeated, loot pending" % _defeated_enemies.size())
	else:
		_clear()


func _evaluate_enemy_loot(enemy_id: String, def_id: String) -> void:
	var chars: CharacterSystem = get_node_or_null("/root/Characters")
	if not chars:
		push_error("[CombatLootSpawner] CharacterSystem not found")
		return

	var char_def: CharacterDefinition = chars.get_definition(def_id)
	if not char_def:
		push_warning("[CombatLootSpawner] No CharacterDefinition for: %s" % def_id)
		return

	if char_def.loot_table_id.is_empty():
		print("[CombatLootSpawner]   %s: no loot_table_id — skip" % enemy_id)
		return

	var instance_id := "loot_bag_%s" % enemy_id
	_register_loot_bag_instance(instance_id, char_def.loot_table_id)

	EventBus.combat_loot_bag_spawned.emit(enemy_id, instance_id, Vector2.ZERO)
	print("[CombatLootSpawner]   ✓ emitted: %s (loot: %s)" % [instance_id, char_def.loot_table_id])


func _register_loot_bag_instance(instance_id: String, loot_table_id: String) -> void:
	var wo_system: Node = get_node_or_null("/root/WorldObjectSystem")
	if not wo_system:
		push_error("[CombatLootSpawner] WorldObjectSystem not found")
		return

	if wo_system.has_instance(instance_id):
		wo_system.unregister_instance(instance_id)

	wo_system.register_instance(instance_id, "loot_bag_01")

	var state = wo_system.get_state(instance_id)
	if state and state.definition:
		var interaction = state.definition.get_interaction("collect")
		if interaction and interaction.outcome_success:
			interaction.outcome_success.loot_table_id = loot_table_id
			if interaction.outcome_critical:
				interaction.outcome_critical.loot_table_id = loot_table_id
			print("[CombatLootSpawner]   loot_table injected: %s → %s" % [instance_id, loot_table_id])
		else:
			push_warning("[CombatLootSpawner]   'collect' interaction not found on loot_bag_01")


func _clear() -> void:
	_enemy_definitions.clear()
	_defeated_enemies.clear()
	_pending_loot = false
