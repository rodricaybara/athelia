class_name DefenseModule
extends RefCounted

## DefenseModule - Sistema de absorción temporal de daño
##
## Responsabilidades:
## - Activar/desactivar estado de defensa (1 turno)
## - Convertir daño recibido en consumo de stamina según ratio
## - Gestionar overflow de stamina → HP
## - Auto-expirar al inicio del turno del jugador
##
## NO gestiona:
## - Aplicación directa de daño a recursos (usa ResourceSystem)
## - Animaciones o feedback visual
## - Validación de estar en combate (responsabilidad de CombatSystem)

# ============================================
# CONSTANTES DE DISEÑO
# ============================================

## Ratio de conversión daño → stamina (0.7 = 70% a stamina, 30% a HP)
const CONVERSION_RATIO: float = 0.7

# ============================================
# SEÑALES
# ============================================

## Emitido cuando se activa la defensa
signal defense_activated()

## Emitido cuando la defensa intercepta daño
signal damage_absorbed(stamina_consumed: int, hp_taken: int, overflow: int)

## Emitido cuando la defensa expira
signal defense_expired()

# ============================================
# ESTADO INTERNO
# ============================================

## Indica si la defensa está activa
var is_defending: bool = false

## Referencia a ResourceSystem (inyectada desde CombatSystem)
var _resource_system: Node = null

# ============================================
# INICIALIZACIÓN
# ============================================

## Constructor - inyectar ResourceSystem
func _init(resource_system: Node = null) -> void:
	_resource_system = resource_system
	if not _resource_system:
		# Fallback: intentar obtener autoload
		_resource_system = Engine.get_main_loop().root.get_node_or_null("/root/Resources")
		if not _resource_system:
			push_error("[DefenseModule] ResourceSystem not found!")

# ============================================
# API PÚBLICA
# ============================================

## Activa el estado de defensa
## Solo puede activarse si no está ya activo
func activate_defense() -> bool:
	if is_defending:
		push_warning("[DefenseModule] Defense already active, ignoring")
		return false
	
	is_defending = true
	defense_activated.emit()
	
	print("[DefenseModule] 🛡️ Defense ACTIVATED (1 turn)")
	return true


## Procesa el daño entrante si la defensa está activa
## Retorna el daño final que debe aplicarse a HP
func process_incoming_damage(damage: int, entity_id: String) -> int:
	if not is_defending:
		# No hay defensa activa, retornar daño completo
		return damage
	
	if damage <= 0:
		# No hay daño que procesar
		return 0
	
	# Calcular división del daño
	var stamina_portion: int = int(damage * CONVERSION_RATIO)
	var hp_portion: int = damage - stamina_portion
	
	# Obtener stamina actual
	var current_stamina: int = _resource_system.get_resource_amount(entity_id, "stamina")
	
	# Consumir stamina
	_resource_system.add_resource(entity_id, "stamina", -stamina_portion)
	
	# Verificar overflow
	var new_stamina: int = _resource_system.get_resource_amount(entity_id, "stamina")
	var overflow: int = 0
	
	if new_stamina < 0:
		# Overflow: stamina no puede absorber todo el daño
		overflow = abs(new_stamina)
		hp_portion += overflow
		
		# Resetear stamina a 0 (ResourceSystem ya debería hacer esto, pero por seguridad)
		_resource_system.set_resource(entity_id, "stamina", 0)
		
		print("[DefenseModule] ⚠️ Stamina overflow: %d damage transferred to HP" % overflow)
	
	# Emitir evento con información del proceso
	damage_absorbed.emit(stamina_portion, hp_portion, overflow)
	
	print("[DefenseModule] 🛡️ Damage absorbed: %d total → %d stamina, %d HP (overflow: %d)" % [
		damage, stamina_portion, hp_portion, overflow
	])
	
	# Retornar el daño final que debe aplicarse a HP
	return hp_portion


## Expira la defensa al inicio del turno del jugador
## Debe llamarse desde CombatSystem._start_player_turn()
func on_player_turn_start() -> void:
	if not is_defending:
		return
	
	is_defending = false
	defense_expired.emit()
	
	print("[DefenseModule] 🛡️ Defense EXPIRED")


## Verifica si la defensa está activa
func is_active() -> bool:
	return is_defending


## Resetea el módulo (útil para testing o end_combat)
func reset() -> void:
	is_defending = false
	print("[DefenseModule] Module reset")

# ============================================
# DEBUG / TESTING
# ============================================

## Simula un escenario de defensa para testing
func debug_simulate_scenario(damage: int, entity_stamina: int, entity_hp: int) -> Dictionary:
	print("\n[DefenseModule] === DEBUG SIMULATION ===")
	print("  Initial state: %d HP, %d stamina" % [entity_hp, entity_stamina])
	print("  Incoming damage: %d" % damage)
	
	# Calcular sin aplicar
	var stamina_portion: int = int(damage * CONVERSION_RATIO)
	var hp_portion: int = damage - stamina_portion
	
	var final_stamina = entity_stamina - stamina_portion
	var overflow = 0
	
	if final_stamina < 0:
		overflow = abs(final_stamina)
		hp_portion += overflow
		final_stamina = 0
	
	var final_hp = entity_hp - hp_portion
	
	print("  Stamina consumed: %d" % stamina_portion)
	print("  HP damage: %d" % hp_portion)
	if overflow > 0:
		print("  ⚠️ Overflow: %d" % overflow)
	print("  Final state: %d HP, %d stamina" % [final_hp, final_stamina])
	print("=================================\n")
	
	return {
		"stamina_consumed": stamina_portion,
		"hp_damage": hp_portion,
		"overflow": overflow,
		"final_hp": final_hp,
		"final_stamina": final_stamina
	}
