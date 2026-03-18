class_name EnemyAI
extends RefCounted

## EnemyAI - Sistema de IA básica para enemigos
## FASE A.4: Turnos automáticos
##
## Responsabilidades:
## - Decidir qué acción toma un enemigo
## - Seleccionar target (siempre player por ahora)
## - Elegir skill a usar
##
## NO hace:
## - Ejecutar la acción (eso es CombatSystem)
## - Validar recursos (eso es SkillSystem)

# ============================================
# CONSTANTES DE COMPORTAMIENTO
# ============================================

## Probabilidad de atacar vs esperar
const ATTACK_CHANCE: float = 0.8  # 80% ataca, 20% espera

## Skills disponibles para enemigos básicos
const BASIC_ENEMY_SKILLS: Array[String] = [
	"skill.enemy.basic_attack"
]


# ============================================
# DECISIÓN DE ACCIÓN
# ============================================

## Decide qué acción toma un enemigo en su turno
## @param enemy_id: ID del enemigo que decide
## @return Dictionary con la acción a ejecutar
static func decide_action(enemy_id: String) -> Dictionary:
	# Por ahora: comportamiento simple
	# TODO FASE B: Comportamientos por tipo de enemigo
	
	# Decidir si ataca o espera
	var roll = randf()
	
	if roll < ATTACK_CHANCE:
		# Atacar al jugador
		return {
			"type": "attack",
			"target": "player",
			"skill": BASIC_ENEMY_SKILLS[0]
		}
	else:
		# Esperar (no hace nada este turno)
		return {
			"type": "wait"
		}


## Selecciona el mejor skill a usar (futuro - por ahora siempre basic_attack)
## @param enemy_id: ID del enemigo
## @param target_id: ID del target
## @return Skill ID a usar
static func select_skill(enemy_id: String, target_id: String) -> String:
	# FASE A.4: Siempre usa basic_attack
	return BASIC_ENEMY_SKILLS[0]
	
	# TODO FASE B: Selección inteligente
	# - Verificar recursos disponibles
	# - Seleccionar skill según HP del target
	# - Usar skills especiales según condiciones


## Evalúa la prioridad de un target (futuro - múltiples jugadores)
## @param enemy_id: ID del enemigo
## @param target_id: ID del target potencial
## @return Puntuación de prioridad (mayor = más prioritario)
static func evaluate_target_priority(enemy_id: String, target_id: String) -> float:
	# FASE A.4: Solo hay un jugador, siempre prioridad 1.0
	return 1.0
	
	# TODO FASE B: Prioridad por HP, amenaza, etc.


# ============================================
# COMPORTAMIENTOS AVANZADOS (Futuro)
# ============================================

## Decide si el enemigo debe huir
static func should_flee(enemy_id: String) -> bool:
	# TODO FASE B: Huir si HP < 20%
	return false


## Decide si el enemigo debe usar item
static func should_use_item(enemy_id: String) -> Dictionary:
	# TODO FASE B: Usar poción si HP < 30%
	return {"use_item": false}


## Decide si el enemigo debe cambiar de target
static func should_switch_target(enemy_id: String, current_target: String) -> bool:
	# TODO FASE B: Cambiar si hay mejor target
	return false


# ============================================
# DEBUG
# ============================================

## Imprime la decisión tomada
static func debug_print_decision(enemy_id: String, decision: Dictionary) -> void:
	match decision.type:
		"attack":
			print("[EnemyAI] %s decides to attack %s with %s" % [
				enemy_id,
				decision.get("target", "?"),
				decision.get("skill", "?")
			])
		
		"wait":
			print("[EnemyAI] %s decides to wait" % enemy_id)
		
		_:
			print("[EnemyAI] %s has unknown decision: %s" % [enemy_id, decision])


## Imprime estadísticas de decisiones (para balanceo)
static func debug_simulate_decisions(enemy_id: String, iterations: int = 100) -> void:
	var stats = {
		"attack": 0,
		"wait": 0
	}
	
	for i in range(iterations):
		var decision = decide_action(enemy_id)
		stats[decision.type] += 1
	
	print("\n[EnemyAI] Decision Statistics for %s (%d iterations):" % [enemy_id, iterations])
	print("  Attack: %d (%.1f%%)" % [stats.attack, (stats.attack / float(iterations)) * 100])
	print("  Wait: %d (%.1f%%)" % [stats.wait, (stats.wait / float(iterations)) * 100])
