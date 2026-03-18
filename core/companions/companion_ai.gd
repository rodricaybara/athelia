extends Node
## CompanionAI - IA de combate para companions del grupo
##
## Se instancia dinámicamente por CompanionCombatNode (análogo a EnemyAI).
## Escucha companion_turn_started y decide una acción automáticamente.
##
## ESTRATEGIA ACTUAL (v1):
##   1. Si hay un aliado incapacitado → intentar reanimar (futuro: skill de curación)
##   2. Si no → atacar al enemigo con menor HP actual
##
## El override manual del jugador se implementará en Fase 2.

@export var companion_id: String = "companion_mira"
@export var attack_skill_id: String = "skill.attack.light"
@export var decision_delay: float = 0.6

const PLAYER_ID: String = "player"


func _ready() -> void:
	if EventBus:
		EventBus.companion_turn_started.connect(_on_companion_turn_started)
	else:
		push_error("[CompanionAI] EventBus not found!")
	print("[CompanionAI] Initialized — %s" % companion_id)


func _on_companion_turn_started(acting_companion_id: String) -> void:
	if acting_companion_id != companion_id:
		return

	# Si el companion está incapacitado, no actúa
	if Party.is_incapacitated(companion_id):
		print("[CompanionAI] %s is incapacitated — skipping turn" % companion_id)
		_end_turn_empty()
		return

	print("[CompanionAI] %s deciding..." % companion_id)
	await get_tree().create_timer(decision_delay).timeout
	_decide_and_act()


func _decide_and_act() -> void:
	var target := _pick_best_target()

	if target.is_empty():
		print("[CompanionAI] %s: no valid target found" % companion_id)
		_end_turn_empty()
		return

	var action_data := {
		"actor":    companion_id,
		"skill_id": attack_skill_id,
		"target":   target
	}

	print("[CompanionAI] %s attacks %s with %s" % [companion_id, target, attack_skill_id])
	EventBus.emit_signal("player_action_requested", action_data)


## Selecciona el enemigo con menor HP — objetivo más vulnerable
func _pick_best_target() -> String:
	var game_loop := get_node_or_null("/root/GameLoop") as GameLoopSystem
	if not game_loop:
		return ""

	var enemies: Array[String] = game_loop.get_active_enemies()
	if enemies.is_empty():
		return ""

	var best_target := ""
	var lowest_hp := INF

	for enemy_id in enemies:
		var hp := Resources.get_resource_amount(enemy_id, "health")
		if hp > 0 and hp < lowest_hp:
			lowest_hp = hp
			best_target = enemy_id

	return best_target


## Emite un resultado vacío para que GameLoop continúe con el siguiente companion
func _end_turn_empty() -> void:
	EventBus.companion_action_completed.emit(companion_id, { "skipped": true })
