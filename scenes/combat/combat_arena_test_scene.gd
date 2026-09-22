extends Node

## CombatArenaTestScene — escena mínima para probar CombatArenaViewModel
## sin nada del resto de combat_test_scene.tscn (barras de ProgressBar,
## companions, nodos visuales de enemigo, arte). Registra jugador + 2
## enemigos con Resources.set_resource() directo, igual que ya hace
## combat_test_scene.gd — sin pasar por AttributeResolver, a propósito,
## para tener control total sobre los números durante la prueba.
##
## Monta en el árbol junto a esta escena:
##   - Un Node llamado "PlayerCombatController" con player_combat_controller.gd
##   - Un Node llamado "ArenaDebugProbe" con combat_arena_debug_probe.gd
## (los dos sueltos, hijos directos de esta escena, sin jerarquía especial)

@onready var game_loop: GameLoopSystem = get_node("/root/GameLoop")

const PLAYER_ID: String = "player"
const ENEMY_IDS: Array[String] = ["enemy_1", "enemy_2"]


func _ready() -> void:
	_register_player()
	for enemy_id in ENEMY_IDS:
		_register_enemy(enemy_id)

	# Mismo motivo que combat_test_scene.gd: dar un frame para que todo
	# lo de arriba esté asentado antes de arrancar combate.
	await get_tree().create_timer(0.3).timeout

	var panel: Node = get_node_or_null("CombatArenaPanel")
	if panel and panel.has_method("open"):
		panel.open()

	game_loop.start_combat(ENEMY_IDS)
	print("[CombatArenaTestScene] Combate iniciado: %s" % [ENEMY_IDS])


func _register_player() -> void:
	if Resources.get_resource_state(PLAYER_ID, "health") == null:
		Resources.register_entity(PLAYER_ID, ["health", "stamina"])
	# Valores conocidos y coherentes entre sí — sin pasar por
	# AttributeResolver, para no repetir la confusión de escala de antes.
	Resources.set_resource(PLAYER_ID, "health", 55)
	Resources.set_resource(PLAYER_ID, "stamina", 40)

	if not Characters.has_entity(PLAYER_ID):
		Characters.register_entity(PLAYER_ID, "player_base")

	# Kit real de player_base.tres, no una lista hardcodeada — mismo
	# criterio que ya documenta el proyecto para CharacterCreationViewModel/
	# PartyManager: nunca duplicar la lista de skills iniciales.
	if not Skills._entity_skills.has(PLAYER_ID):
		var player_def: CharacterDefinition = Characters.get_definition("player_base")
		Skills.register_entity_skills(PLAYER_ID, player_def.skills)

	# LoadoutState.new() arranca vacío en todo CharacterState nuevo —
	# nada lo rellena automáticamente desde definition.skills. Sin esto,
	# CombatHudViewModel ve is_empty=true en los 6 slots de skill y los
	# botones del menú de acciones se quedan sin texto.
	var state: CharacterState = Characters.get_character_state(PLAYER_ID)
	state.loadout.assign_skill("attack_1", "skill.attack.light")
	state.loadout.assign_skill("attack_2", "skill.attack.heavy")
	state.loadout.assign_skill("attack_3", "skill.attack.stunning_blow")
	state.loadout.assign_skill("dodge", "skill.combat.dodge")
	state.loadout.assign_skill("defense", "skill.combat.defend")
	state.loadout.assign_skill("escape", "skill.combat.flee")

	# Consumibles: solo el loadout, sin Inventory.add_item() — InventorySystem
	# exige registrar la entidad primero (no tengo esa API confirmada) y ya
	# hemos fallado varias veces adivinando firmas esta sesión. Con el
	# item_id asignado en el loadout, el slot ya no es is_empty y muestra
	# nombre — saldrá is_available=false (cantidad 0) hasta que se registre
	# el inventario, estado de UI válido para esta prueba.
	state.loadout.assign_consumable("consumable_1", "health_potion")
	state.loadout.assign_consumable("consumable_2", "stamina_potion_small")

	print("[CombatArenaTestScene] Player registrado (HP 55, EN 40)")


func _register_enemy(enemy_id: String) -> void:
	if not Characters.has_entity(enemy_id):
		Resources.register_entity(enemy_id, ["health"])
	Resources.set_resource(enemy_id, "health", 40)

	if not Characters.has_entity(enemy_id):
		Characters.register_entity(enemy_id, "enemy_base")

	if not Skills._entity_skills.has(enemy_id):
		Skills.register_entity_skills(enemy_id, ["skill.enemy.basic_attack"])

	# set() ANTES de add_child(): igual que UISlot.setup(), para que
	# EnemyAI._ready() vea enemy_id/attack_skill_id ya asignados en vez
	# del valor por defecto del script.
	var ai := Node.new()
	ai.set_script(preload("res://core/combat/enemy_ai.gd"))
	ai.name = "EnemyAI_%s" % enemy_id
	ai.set("enemy_id", enemy_id)
	ai.set("attack_skill_id", "skill.enemy.basic_attack")
	add_child(ai)

	print("[CombatArenaTestScene] %s registrado (HP 40)" % enemy_id)
