class_name SkillRoller
extends RefCounted

## SkillRoller - Sistema de tiradas D100 estilo RuneQuest
##
## Responsabilidades:
## - Tirar D100 vs skill_value
## - Determinar resultado (CrÃ­tico, Ã‰xito, Fallo, Pifia)
## - Calcular grado de Ã©xito
##
## NO ejecuta efectos, solo determina el resultado de la tirada

# ============================================
# ENUMS
# ============================================

enum RollResult {
	FUMBLE,    ## Pifia (â‰¥98)
	FAILURE,   ## Fallo (>skill_value)
	SUCCESS,   ## Ã‰xito (â‰¤skill_value, >2)
	CRITICAL   ## CrÃ­tico (â‰¤2)
}


# ============================================
# CONSTANTES (configurables)
# ============================================

## Rango de crÃ­tico (absoluto por ahora)
## TODO: Hacer dinÃ¡mico (skill_value / 5) en fase futura
const CRITICAL_THRESHOLD: int = 2

## Rango de pifia (absoluto por ahora)
## TODO: Hacer dinÃ¡mico segÃºn skill en fase futura
const FUMBLE_THRESHOLD: int = 98


# ============================================
# API PRINCIPAL
# ============================================

## Realiza una tirada de habilidad
## @param skill_value: Porcentaje de éxito (0-100)
## @param guaranteed: Si true, siempre resulta en SUCCESS (buff guaranteed_hit)
## @return Dictionary con resultado completo
static func roll_skill(skill_value: int, guaranteed: bool = false) -> Dictionary:
	# 🆕 FASE A.3: Guaranteed hit (buff de dodge)
	if guaranteed:
		return {
			"roll": 1,  # Valor simbólico
			"skill_value": skill_value,
			"result": RollResult.SUCCESS,
			"result_name": "GUARANTEED",
			"success": true,
			"margin": 99,
			"timestamp": Time.get_ticks_msec(),
			"guaranteed": true
		}
	
	# Validar skill_value
	var clamped_skill = clampi(skill_value, 0, 100)
	
	if skill_value != clamped_skill:
		push_warning("[SkillRoller] Skill value %d clamped to %d" % [skill_value, clamped_skill])
	
	# Tirar D100 (1-100)
	var roll = randi_range(1, 100)
	
	# Determinar resultado
	var result = _determine_result(roll, clamped_skill)
	
	# Calcular grado de Ã©xito (cuÃ¡nto sobrepasÃ³ o fallÃ³)
	var margin = _calculate_margin(roll, clamped_skill, result)
	
	return {
		"roll": roll,                    # Valor del dado (1-100)
		"skill_value": clamped_skill,   # % de habilidad usado
		"result": result,                # Enum RollResult
		"result_name": _result_to_string(result),  # String para debug
		"success": _is_success(result), # true si Ã©xito o crÃ­tico
		"margin": margin,                # Margen de Ã©xito/fallo
		"timestamp": Time.get_ticks_msec()
	}


# ============================================
# LÃ“GICA INTERNA
# ============================================

## Determina el resultado segÃºn la tirada
static func _determine_result(roll: int, skill_value: int) -> RollResult:
	# Pifia tiene prioridad (siempre â‰¥98, incluso si skill es 100%)
	if roll >= FUMBLE_THRESHOLD:
		return RollResult.FUMBLE
	
	# CrÃ­tico (â‰¤2)
	if roll <= CRITICAL_THRESHOLD:
		return RollResult.CRITICAL
	
	# Ã‰xito normal (â‰¤skill_value)
	if roll <= skill_value:
		return RollResult.SUCCESS
	
	# Fallo
	return RollResult.FAILURE


## Calcula el margen de Ã©xito/fallo
## Positivo = Ã©xito, negativo = fallo
## Ejemplo: roll=25, skill=40 â†’ margin=+15 (Ã©xito por 15)
## Ejemplo: roll=55, skill=40 â†’ margin=-15 (fallo por 15)
static func _calculate_margin(roll: int, skill_value: int, result: RollResult) -> int:
	match result:
		RollResult.CRITICAL:
			# CrÃ­tico: margen es la diferencia hasta el threshold
			return CRITICAL_THRESHOLD - roll + skill_value
		
		RollResult.SUCCESS:
			# Ã‰xito normal: margen positivo
			return skill_value - roll
		
		RollResult.FAILURE:
			# Fallo: margen negativo
			return skill_value - roll
		
		RollResult.FUMBLE:
			# Pifia: margen muy negativo
			return skill_value - roll
	
	return 0


## Verifica si el resultado es exitoso
static func _is_success(result: RollResult) -> bool:
	return result in [RollResult.SUCCESS, RollResult.CRITICAL]


## Convierte resultado a string legible
static func _result_to_string(result: RollResult) -> String:
	match result:
		RollResult.CRITICAL:
			return "CRITICAL"
		RollResult.SUCCESS:
			return "SUCCESS"
		RollResult.FAILURE:
			return "FAILURE"
		RollResult.FUMBLE:
			return "FUMBLE"
	
	return "UNKNOWN"


# ============================================
# UTILIDADES
# ============================================

## Simula mÃºltiples tiradas (para testing/estadÃ­sticas)
## @param skill_value: % de habilidad
## @param count: NÃºmero de tiradas
## @return Dictionary con estadÃ­sticas
static func simulate_rolls(skill_value: int, count: int = 100) -> Dictionary:
	var results = {
		"critical": 0,
		"success": 0,
		"failure": 0,
		"fumble": 0,
		"total": count
	}
	
	for i in range(count):
		var roll_result = roll_skill(skill_value)
		
		match roll_result.result:
			RollResult.CRITICAL:
				results.critical += 1
			RollResult.SUCCESS:
				results.success += 1
			RollResult.FAILURE:
				results.failure += 1
			RollResult.FUMBLE:
				results.fumble += 1
	
	# Calcular porcentajes
	results["critical_pct"] = (results.critical / float(count)) * 100
	results["success_pct"] = (results.success / float(count)) * 100
	results["failure_pct"] = (results.failure / float(count)) * 100
	results["fumble_pct"] = (results.fumble / float(count)) * 100
	results["total_success_pct"] = ((results.critical + results.success) / float(count)) * 100
	
	return results


## Imprime estadÃ­sticas de simulaciÃ³n
static func print_simulation(skill_value: int, rolls: int = 1000):
	print("\n[SkillRoller] Simulating %d rolls at %d%% skill..." % [rolls, skill_value])
	
	var stats = simulate_rolls(skill_value, rolls)
	
	print("  Results:")
	print("    Critical: %d (%.1f%%)" % [stats.critical, stats.critical_pct])
	print("    Success:  %d (%.1f%%)" % [stats.success, stats.success_pct])
	print("    Failure:  %d (%.1f%%)" % [stats.failure, stats.failure_pct])
	print("    Fumble:   %d (%.1f%%)" % [stats.fumble, stats.fumble_pct])
	print("  Total Success Rate: %.1f%%" % stats.total_success_pct)
	print("")


# ============================================
# DEBUG
# ============================================

## Imprime resultado de una tirada de forma legible
static func print_roll_result(result: Dictionary, context: String = ""):
	var prefix = "[SkillRoller]"
	if not context.is_empty():
		prefix += " [%s]" % context
	
	var success_icon = "âœ“" if result.success else "âœ—"
	var margin_text = ""
	
	if result.success:
		margin_text = " (margin: +%d)" % result.margin
	else:
		margin_text = " (margin: %d)" % result.margin
	
	print("%s %s D100=%d vs %d%% â†’ %s%s" % [
		prefix,
		success_icon,
		result.roll,
		result.skill_value,
		result.result_name,
		margin_text
	])

## Traduce un RollResult a outcome string para SkillProgressionService.
## Centraliza el mapeo aquí para evitar que CombatSystem lo haga inline.
## FAILURE y FUMBLE → "partial": en el diseño no se pierde turno,
## todo fallo es parcial desde el punto de vista de la progresión.
static func to_progression_outcome(result: RollResult) -> String:
	match result:
		RollResult.CRITICAL:
			return "critical"
		RollResult.SUCCESS:
			return "success"
		_:  # FAILURE y FUMBLE
			return "partial"

# ============================================
# NOTAS DE DISEÃ‘O
# ============================================

## NOTA 1: Â¿Por quÃ© absolutos (2/98)?
##
## En este spike usamos rangos absolutos para simplificar.
## En RuneQuest clÃ¡sico:
##   - CrÃ­tico: â‰¤ skill_value / 5
##   - Pifia: â‰¥96 (si skill<100%) o â‰¥100 (si skillâ‰¥100%)
##
## Migrar a dinÃ¡mico es trivial:
##   const CRITICAL_THRESHOLD â†’ func get_critical_threshold(skill: int)
##   const FUMBLE_THRESHOLD â†’ func get_fumble_threshold(skill: int)

## NOTA 2: Â¿Margen de Ã©xito?
##
## El margen indica "cuÃ¡n bien/mal" fue la tirada.
## Usos futuros:
##   - OposiciÃ³n: margen atacante vs margen defensor
##   - DaÃ±o escalado: +daÃ±o por margen alto
##   - Efectos variables: stun duration segÃºn margen

## NOTA 3: Extensibilidad
##
## Futuras mejoras sin refactor mayor:
##   - Contested rolls (attacker vs defender)
##   - Modificadores situacionales (+20% si flanquea)
##   - Rerolls (gastar luck points)
##   - Grados de Ã©xito (marginal, normal, critical)
