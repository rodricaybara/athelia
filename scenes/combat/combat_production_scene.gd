extends Node

## CombatProductionScene — pieza mínima de producción, sustituye el rol
## de combat_test_scene.gd como SceneOrchestrator.SCENE_COMBAT.
##
## A diferencia de combat_test_scene.gd (escena de TEST, standalone, que
## registra entidades porque no hay ExplorationController de por medio),
## esta pieza asume que el jugador/enemigos/companions YA están
## registrados en Characters/Resources — eso lo hace
## ExplorationController._on_interaction_requested() (o
## NarrativeSceneViewModel._apply_outcome()) ANTES de llamar a
## GameLoop.start_combat(). Skills NO llega registrado por ese camino
## (confirmado en combate real: NarrativeSceneViewModel pre-registra
## Characters/Resources pero nunca Skills) — _spawn_enemy_ai() lo
## registra aquí mismo, con guard idempotente, para el roster inicial
## y para refuerzos por igual. Esta pieza también instancia
## PlayerCombatController (antes colgado de $Player en combat_test.tscn)
## y la LÓGICA de IA (EnemyAI/CompanionAI) que antes colgaba de nodos
## visuales retirados (UICombatToken cubre su único rol funcional real).
## Sin UI: SceneOrchestrator carga CombatArenaPanel por separado, vía
## OVERLAY_COMBAT_HUD.
##
## Se limpia a sí misma en combat_ended — SceneOrchestrator._handle_combat()
## no guarda referencia a esta instancia ni la libera (hallazgo aparte,
## no arreglado aquí: la fuga ya existía con combat_test_scene.gd).

@onready var game_loop: GameLoopSystem = get_node("/root/GameLoop")


func _ready() -> void:
	_spawn_player_combat_controller()

	for enemy_id in game_loop.get_active_enemies():
		_spawn_enemy_ai(enemy_id)

	var party: Node = get_node_or_null("/root/Party")
	if party:
		for companion_id in party.get_party_members():
			_spawn_companion_ai(companion_id)

	EventBus.reinforcement_spawned.connect(_on_reinforcement_spawned)
	EventBus.combat_ended.connect(_on_combat_ended)


func _spawn_player_combat_controller() -> void:
	var controller := Node.new()
	controller.set_script(preload("res://scenes/player/player_combat_controller.gd"))
	controller.name = "PlayerCombatController"
	add_child(controller)


func _spawn_companion_ai(companion_id: String) -> void:
	var ai := Node.new()
	ai.set_script(preload("res://core/companions/companion_ai.gd"))
	ai.name = "CompanionAI_%s" % companion_id
	ai.set("companion_id", companion_id)
	add_child(ai)


func _spawn_enemy_ai(enemy_id: String) -> void:
	# NarrativeSceneViewModel (y probablemente ExplorationController)
	# pre-registran Characters/Resources para el roster inicial, pero
	# NUNCA Skills — falso supuesto mío al asumir "ya está todo
	# registrado". Mismo guard que ya uso para refuerzos, aplicado aquí
	# también.
	if not Skills._entity_skills.has(enemy_id):
		Skills.register_entity_skills(enemy_id, ["skill.enemy.basic_attack"])

	var ai := Node.new()
	ai.set_script(preload("res://core/combat/enemy_ai.gd"))
	ai.name = "EnemyAI_%s" % enemy_id
	# set() ANTES de add_child(): mismo criterio que UISlot.setup() y
	# el fix ya aplicado en combat_arena_test_scene.gd — evita que
	# EnemyAI._ready() vea el valor por defecto del script.
	ai.set("enemy_id", enemy_id)
	ai.set("attack_skill_id", "skill.enemy.basic_attack")
	add_child(ai)


## El registro en Characters/Resources de un refuerzo SÍ es
## responsabilidad de esta escena (a diferencia del roster inicial) —
## GameLoopSystem emite reinforcement_spawned pero no registra nada él
## mismo (comentario explícito en game_loop_system.gd: "fuera de
## control de GameLoopSystem"). Réplica de la lógica de registro de
## _initialize_enemy() en combat_test_scene.gd, sin la parte visual.
## Skills lo cubre _spawn_enemy_ai() para los dos casos (roster inicial
## y refuerzo), no lo dupliques aquí.
func _on_reinforcement_spawned(enemy_id: String, definition_id: String) -> void:
	if not Characters.has_entity(enemy_id):
		if Characters.has_definition(definition_id):
			Characters.register_entity(enemy_id, definition_id)
		else:
			push_warning("[CombatProductionScene] Definición no encontrada: %s" % definition_id)
		# Resources SIEMPRE después de Characters — Spike 6, Punto 1:
		# ResourceSystem.register_entity() necesita la entidad ya en
		# CharacterSystem para poder sincronizar max_effective.
		Resources.register_entity(enemy_id, ["health"])
 
	_spawn_enemy_ai(enemy_id)


func _on_combat_ended(_result: String) -> void:
	queue_free()
