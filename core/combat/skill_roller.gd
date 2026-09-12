class_name SkillRoller
extends RefCounted

## SkillRoller - Sistema de tiradas D100 estilo RuneQuest
##
## Responsabilidades:
## - Tirar D100 vs skill_value
## - Determinar resultado (Crítico, Especial, Éxito, Fallo, Pifia)
## - Calcular grado de éxito
##
## NO ejecuta efectos, solo determina el resultado de la tirada
##
## Spike 2 — Reglas de RuneQuest: se añade el grado SPECIAL. A diferencia de
## CRITICAL/FUMBLE (constantes absolutas en Spike 1), CRITICAL y SPECIAL son
## ahora dinámicos (skill_value / 20 y skill_value / 5 respectivamente, fórmula
## RuneQuest clásica) — decisión tomada explícitamente para no necesitar un
## suelo/guard artificial entre bandas: al ser ambos proporcionales al mismo
## skill_value, CRITICAL ≤ SPECIAL ≤ skill_value se cumple siempre sin lógica
## adicional. FUMBLE se queda absoluto (fuera de alcance de este spike).

# ============================================
# ENUMS
# ============================================

enum RollResult {
	FUMBLE,    ## Pifia (≥98)
	FAILURE,   ## Fallo (>skill_value)
	SUCCESS,   ## Éxito (≤skill_value, >umbral especial)
	SPECIAL,   ## Especial (≤skill_value / 5)
	CRITICAL   ## Crítico (≤skill_value / 20)
}


# ============================================
# CONSTANTES (configurables)
# ============================================

## Rango de pifia (absoluto — fuera de alcance de Spike 2, sin decisión de
## hacerlo dinámico todavía)
const FUMBLE_THRESHOLD: int = 98

## Divisores RuneQuest clásicos para los umbrales dinámicos de crítico/especial
const CRITICAL_DIVISOR: int = 20
const SPECIAL_DIVISOR: int = 5


# ============================================
# API PRINCIPAL
# ============================================

## Realiza una tirada de habilidad
## @param skill_value: Porcentaje de éxito (0-100)
## @param guaranteed: Si true, siempre resulta en SUCCESS (buff guaranteed_hit)
## @return Dictionary con resultado completo
static func roll_skill(skill_value: int, guaranteed: bool = false, critical_bonus: int = 0) -> Dictionary:
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
	var result = _determine_result(roll, clamped_skill, critical_bonus)
	
	# Calcular grado de éxito (cuánto sobrepasó o falló)
	var margin = _calculate_margin(roll, clamped_skill, result, critical_bonus)
	
	return {
		"roll": roll,
		"skill_value": clamped_skill,
		"result": result,
		"result_name": _result_to_string(result),
		"success": _is_success(result),
		"margin": margin,
		"timestamp": Time.get_ticks_msec(),
		"critical_threshold": get_critical_threshold(clamped_skill, critical_bonus),
		"special_threshold": get_special_threshold(clamped_skill)
	}


# ============================================
# UMBRALES DINÁMICOS (Spike 2)
# ============================================

## Umbral de crítico para un skill_value dado (RuneQuest clásico: skill/20).
## Público porque CombatSystem lo usa también en un print de debug para
## mostrar el umbral efectivo cuando el buff critical_bonus está activo —
## evita duplicar la fórmula fuera de SkillRoller.
static func get_critical_threshold(skill_value: int, critical_bonus: int = 0) -> int:
	return (skill_value / CRITICAL_DIVISOR) + critical_bonus


## Umbral de especial para un skill_value dado (RuneQuest clásico: skill/5).
## No recibe critical_bonus — ese buff solo amplía el umbral de crítico.
static func get_special_threshold(skill_value: int) -> int:
	return skill_value / SPECIAL_DIVISOR


# ============================================
# LÓGICA INTERNA
# ============================================

## Determina el resultado según la tirada
static func _determine_result(roll: int, skill_value: int, critical_bonus: int = 0) -> RollResult:
	# Pifia tiene prioridad (siempre ≥98, incluso si skill es 100%)
	if roll >= FUMBLE_THRESHOLD:
		return RollResult.FUMBLE
	
	# Crítico — umbral dinámico (skill/20) + bonus del buff
	var effective_critical: int = get_critical_threshold(skill_value, critical_bonus)
	if roll <= effective_critical:
		return RollResult.CRITICAL
	
	# Especial — umbral dinámico (skill/5). Al ser proporcional al mismo
	# skill_value que crítico, effective_critical <= effective_special se
	# cumple siempre (20 > 5) — no hace falta ningún guard adicional aquí.
	var effective_special: int = get_special_threshold(skill_value)
	if roll <= effective_special:
		return RollResult.SPECIAL
	
	# Éxito normal (≤skill_value)
	if roll <= skill_value:
		return RollResult.SUCCESS
	
	# Fallo
	return RollResult.FAILURE

## Calcula el margen de éxito/fallo
## Positivo = éxito, negativo = fallo
## Ejemplo: roll=25, skill=40 → margin=+15 (éxito por 15)
## Ejemplo: roll=55, skill=40 → margin=-15 (fallo por 15)
static func _calculate_margin(roll: int, skill_value: int, result: RollResult, critical_bonus: int = 0) -> int:
	match result:
		RollResult.CRITICAL:
			# Crítico: margen es la diferencia hasta el umbral dinámico
			return get_critical_threshold(skill_value, critical_bonus) - roll + skill_value
		
		RollResult.SPECIAL:
			# Especial: margen es la diferencia hasta el umbral dinámico
			return get_special_threshold(skill_value) - roll + skill_value
		
		RollResult.SUCCESS:
			# Éxito normal: margen positivo
			return skill_value - roll
		
		RollResult.FAILURE:
			# Fallo: margen negativo
			return skill_value - roll
		
		RollResult.FUMBLE:
			# Pifia: margen muy negativo
			return skill_value - roll
	
	return 0


## Verifica si el resultado es exitoso
## SPECIAL cuenta como éxito — Spike 1 solo tenía SUCCESS/CRITICAL aquí;
## olvidar SPECIAL en esta lista sería el bug más grave posible al añadir
## el grado: CombatSystem trataría una tirada especial como fallo.
static func _is_success(result: RollResult) -> bool:
	return result in [RollResult.SUCCESS, RollResult.SPECIAL, RollResult.CRITICAL]


## Convierte resultado a string legible
static func _result_to_string(result: RollResult) -> String:
	match result:
		RollResult.CRITICAL:
			return "CRITICAL"
		RollResult.SPECIAL:
			return "SPECIAL"
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

## Simula múltiples tiradas (para testing/estadísticas)
## @param skill_value: % de habilidad
## @param count: Número de tiradas
## @return Dictionary con estadísticas
static func simulate_rolls(skill_value: int, count: int = 100) -> Dictionary:
	var results = {
		"critical": 0,
		"special": 0,
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
			RollResult.SPECIAL:
				results.special += 1
			RollResult.SUCCESS:
				results.success += 1
			RollResult.FAILURE:
				results.failure += 1
			RollResult.FUMBLE:
				results.fumble += 1
	
	# Calcular porcentajes
	results["critical_pct"] = (results.critical / float(count)) * 100
	results["special_pct"] = (results.special / float(count)) * 100
	results["success_pct"] = (results.success / float(count)) * 100
	results["failure_pct"] = (results.failure / float(count)) * 100
	results["fumble_pct"] = (results.fumble / float(count)) * 100
	results["total_success_pct"] = ((results.critical + results.special + results.success) / float(count)) * 100
	
	return results


## Imprime estadísticas de simulación
static func print_simulation(skill_value: int, rolls: int = 1000):
	print("\n[SkillRoller] Simulating %d rolls at %d%% skill..." % [rolls, skill_value])
	
	var stats = simulate_rolls(skill_value, rolls)
	
	print("  Results:")
	print("    Critical: %d (%.1f%%)" % [stats.critical, stats.critical_pct])
	print("    Special:  %d (%.1f%%)" % [stats.special, stats.special_pct])
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
	
	var success_icon = "✓" if result.success else "✗"
	var margin_text = ""
	
	if result.success:
		margin_text = " (margin: +%d)" % result.margin
	else:
		margin_text = " (margin: %d)" % result.margin
	
	print("%s %s D100=%d vs %d%% → %s%s" % [
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
## SPECIAL → "success" (decisión Spike 2): un especial es un resultado
## notable de la tirada, no un evento de aprendizaje distinto — no genera
## progresión más rápida ni un tick extra, cuenta igual que un éxito normal.
static func to_progression_outcome(result: RollResult) -> String:
	match result:
		RollResult.CRITICAL:
			return "critical"
		RollResult.SUCCESS, RollResult.SPECIAL:
			return "success"
		_:  # FAILURE y FUMBLE
			return "partial"

# ============================================
# NOTAS DE DISEÑO
# ============================================

## NOTA 1: ¿Por qué FUMBLE sigue siendo absoluto?
##
## CRITICAL y SPECIAL pasaron a ser dinámicos en Spike 2 (skill/20 y skill/5,
## fórmulas RuneQuest clásicas). FUMBLE (≥98) se queda como estaba a
## propósito — no formaba parte del alcance de Spike 2 y RuneQuest clásico
## ya lo trata como un caso especial en sí mismo (depende de si skill≥100%,
## no es un simple divisor). Hacerlo dinámico queda como posible trabajo
## futuro, igual que quedó documentado en Spike 1.

## NOTA 2: ¿Margen de éxito?
##
## El margen indica "cuán bien/mal" fue la tirada.
## Usos futuros:
##   - Oposición: margen atacante vs margen defensor
##   - Daño escalado: +daño por margen alto
##   - Efectos variables: stun duration según margen

## NOTA 3: Extensibilidad
##
## Futuras mejoras sin refactor mayor:
##   - Contested rolls (attacker vs defender)
##   - Modificadores situacionales (+20% si flanquea)
##   - Rerolls (gastar luck points)
