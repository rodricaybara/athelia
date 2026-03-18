class_name CombatResolver
extends RefCounted

## CombatResolver - Motor de cálculos de combate
## Clase estática sin estado
##
## Responsabilidades:
## - Calcular daño de habilidades
## - Procesar efectos de SkillDefinition
## - Calcular hit chance (futuro)
## - Calcular críticos (futuro)
## - FASE A.3: Procesar buffs (guaranteed_hit, evasion)
##
## Integración con SkillDefinition existente:
## - Usa el campo 'effects' Array de SkillDefinition
## - Busca efectos de tipo "DAMAGE" para calcular daño base
## - Busca efectos de tipo "BUFF" para aplicar buffs temporales

# ============================================
# CÁLCULO DE DAÑO
# ============================================

## Calcula el daño de una habilidad de combate
##
## FASE C.1.5: Añadido soporte para críticos
## FASE C.2: ✅ COMPLETADA - Usa AttributeResolver para base_damage
##
## Parámetros:
##   attacker_id: ID del atacante (necesario para AttributeResolver)
##   skill_def: Definición de la habilidad (SkillDefinition existente)
##   is_critical: Si es un golpe crítico (daño x2)
##
## Retorna: Daño final calculado (mínimo 1.0)
static func calculate_skill_damage(
	attacker_id: String,
	skill_def: SkillDefinition,
	is_critical: bool = false
) -> float:
	
	if not skill_def:
		push_error("[CombatResolver] Skill definition is null")
		return 0.0
	
	# Buscar efecto de DAMAGE en el array effects
	var damage_effect = _find_effect_by_type(skill_def.effects, "DAMAGE")
	
	if damage_effect == null:
		push_warning("[CombatResolver] Skill '%s' has no DAMAGE effect" % skill_def.id)
		return 0.0
	
	# 🎯 FASE C.2: Calcular base_damage dinámicamente con AttributeResolver
	# Fórmula definida en: res://data/formulas/derived_attributes.json
	# base_damage = 5.0 + (strength × 0.8) + (dexterity × 0.2)
	var base_damage = AttributeResolver.resolve(attacker_id, "base_damage")
	
	if base_damage <= 0:
		push_warning("[CombatResolver] base_damage resolved to 0 for '%s', using fallback" % attacker_id)
		base_damage = 5.0  # Fallback mínimo
	
	# Debug: Mostrar cálculo de base_damage
	print("[CombatResolver]   Base damage: %.1f (from attributes)" % base_damage)
	
	# Obtener multiplicador del efecto
	var effect_value = damage_effect.get("value", 1.0)
	
	# Determinar si es multiplicador o valor absoluto
	var damage: float
	if effect_value < 10:
		damage = base_damage * effect_value
	else:
		damage = effect_value
	
	# 🎲 FASE C.1.5: Críticos hacen x2
	if is_critical:
		damage *= 2.0
		print("[CombatResolver]   💥 CRITICAL HIT! Damage x2")
	
	# Variación aleatoria ±10%
	var variance = randf_range(0.9, 1.1)
	damage *= variance
	
	# Asegurar daño mínimo de 1
	return max(1.0, damage)


## Busca un efecto por tipo en el array effects
static func _find_effect_by_type(effects: Array, effect_type: String) -> Variant:
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		
		if effect.get("type", "") == effect_type:
			return effect
	
	return null


## Procesa todos los efectos de una habilidad
## Retorna un diccionario con los resultados de cada efecto
## FASE A.3: Añadido soporte para BUFF effects
static func process_skill_effects(
	attacker_id: String,
	skill_def: SkillDefinition,
	is_critical: bool = false
) -> Dictionary:
	
	var results = {
		"damage": 0.0,
		"status_applied": [],
		"knockback": 0.0,
		"buffs_applied": []  # ← NUEVO A.3: Lista de buffs aplicados
	}
	
	for effect in skill_def.effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		
		var effect_type = effect.get("type", "")
		
		match effect_type:
			"DAMAGE":
				results.damage = calculate_skill_damage(attacker_id, skill_def, is_critical)
			
			"BUFF":
				# FASE A.3: Procesar buffs
				var buff_data = {
					"buff_type": effect.get("buff_type", "unknown"),
					"value": effect.get("value", 0.0),
					"duration": effect.get("duration", 0.0),
					"description": effect.get("description", ""),
					"applied_at": Time.get_ticks_msec() / 1000.0
				}
				results.buffs_applied.append(buff_data)
				print("[CombatResolver] Buff queued: %s (%.1fs)" % [buff_data.buff_type, buff_data.duration])
			
			"STATUS_APPLY":
				pass
			
			"KNOCKBACK":
				pass
			
			_:
				push_warning("[CombatResolver] Unknown effect type: %s" % effect_type)
	
	return results


# ============================================
# HIT CHANCE (Futuro - Fase 2)
# ============================================

## Calcula probabilidad de acierto
##
## FASE 1: Siempre retorna 1.0 (100% acierto)
## FASE 2: Fórmula basada en accuracy vs evasion
static func calculate_hit_chance(
	attacker_id: String,
	skill_def: SkillDefinition,
	target_id: String
) -> float:
	
	# FASE 1: Siempre acierta
	return 1.0


## Determina si un ataque es crítico
##
## FASE 1: Siempre retorna false
## FASE 2: Basado en luck/critical_chance
static func is_critical_hit(attacker_id: String, skill_def: SkillDefinition) -> bool:
	return false


## Calcula multiplicador de crítico
##
## FASE 1: Retorna 1.0 (sin multiplicador)
## FASE 2: Basado en atributos
static func get_critical_multiplier(attacker_id: String) -> float:
	return 1.0


# ============================================
# VALIDACIONES
# ============================================

## Verifica si una habilidad puede usarse en combate
static func is_valid_combat_skill(skill_def: SkillDefinition) -> bool:
	if not skill_def:
		return false
	
	if skill_def.mode != "COMBAT":
		return false
	
	if skill_def.effects.is_empty():
		push_warning("[CombatResolver] Skill '%s' has no effects" % skill_def.id)
		return false
	
	return true


# ============================================
# DEBUG
# ============================================

## Simula un cálculo de daño con valores de prueba
static func debug_simulate_damage(skill_def: SkillDefinition, attacker_strength: float = 10.0) -> void:
	if not skill_def:
		print("[CombatResolver] Cannot simulate: skill_def is null")
		return
	
	print("\n[CombatResolver] Simulating damage for skill: %s" % skill_def.id)
	print("  Attacker strength: %.1f" % attacker_strength)
	
	var damage_effect = _find_effect_by_type(skill_def.effects, "DAMAGE")
	
	if damage_effect:
		var effect_value = damage_effect.get("value", 0.0)
		print("  Effect value: %.1f" % effect_value)
		
		var base_damage = 10.0
		var final_damage = base_damage * effect_value if effect_value < 10 else effect_value
		var variance = randf_range(0.9, 1.1)
		final_damage *= variance
		
		print("  Base damage: %.1f" % base_damage)
		print("  Variance: %.2f" % variance)
		print("  Final damage: %.1f" % final_damage)
	else:
		print("  No DAMAGE effect found")


## Imprime información de efectos de una habilidad
static func debug_print_skill_effects(skill_def: SkillDefinition) -> void:
	if not skill_def:
		print("[CombatResolver] Skill is null")
		return
	
	print("\n[CombatResolver] Skill Effects: %s" % skill_def.id)
	print("  Mode: %s" % skill_def.mode)
	print("  Category: %s" % skill_def.category)
	print("  Effects count: %d" % skill_def.effects.size())
	
	for i in range(skill_def.effects.size()):
		var effect = skill_def.effects[i]
		if typeof(effect) == TYPE_DICTIONARY:
			print("  Effect[%d]:" % i)
			print("    Type: %s" % effect.get("type", "unknown"))
			print("    Value: %s" % effect.get("value", "N/A"))
			print("    Duration: %s" % effect.get("duration", "N/A"))
		else:
			print("  Effect[%d]: Invalid format" % i)
