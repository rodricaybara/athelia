class_name EscapeModule
extends RefCounted

## EscapeModule - Sistema de huida determinista
##
## Responsabilidades:
## - Activar estado ESCAPE_PENDING al solicitar huida
## - Calcular threshold dinámico según número de enemigos
## - Evaluar condición de escape al inicio del siguiente turno del jugador
## - Emitir señal de escape exitoso/fallido
##
## NO gestiona:
## - Terminar el combate (responsabilidad de CombatSystem)
## - Animaciones o transiciones
## - Validación de estar en combate (responsabilidad de CombatSystem)

# ============================================
# CONSTANTES DE DISEÑO
# ============================================

## Threshold base de stamina para escapar
const BASE_THRESHOLD: int = 20

## Stamina adicional requerida por cada enemigo extra
const PER_ENEMY: int = 10

# ============================================
# SEÑALES
# ============================================

## Emitido cuando el jugador solicita escapar
signal escape_attempted(threshold: int)

## Emitido cuando el escape es exitoso
signal escape_success()

## Emitido cuando el escape falla (stamina insuficiente)
signal escape_failed(stamina_current: int, stamina_required: int)

# ============================================
# ESTADO INTERNO
# ============================================

## Indica si hay un intento de escape pendiente de evaluar
var is_escape_pending: bool = false

## Threshold calculado para el escape actual
var escape_threshold: int = 0

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
			push_error("[EscapeModule] ResourceSystem not found!")

# ============================================
# API PÚBLICA
# ============================================

## Solicita escapar del combate
## Calcula el threshold y activa estado pendiente
## Parámetros:
##   enemy_count: Número de enemigos activos en combate
func attempt_escape(enemy_count: int) -> void:
	if is_escape_pending:
		push_warning("[EscapeModule] Escape already pending, ignoring")
		return
	
	# Calcular threshold dinámico
	escape_threshold = BASE_THRESHOLD + (enemy_count * PER_ENEMY)
	
	# Activar estado pendiente
	is_escape_pending = true
	
	escape_attempted.emit(escape_threshold)
	
	print("[EscapeModule] 🏃 Escape ATTEMPTED")
	print("  Enemies: %d" % enemy_count)
	print("  Required stamina: %d (base: %d + enemies: %d×%d)" % [
		escape_threshold, BASE_THRESHOLD, enemy_count, PER_ENEMY
	])
	print("  ⏳ Will resolve at start of next player turn")


## Evalúa si el escape es exitoso según stamina actual
## Debe llamarse desde CombatSystem._start_player_turn()
## Retorna true si el escape fue exitoso, false si falló
func resolve_escape(entity_id: String) -> bool:
	if not is_escape_pending:
		push_warning("[EscapeModule] No escape pending to resolve")
		return false
	
	# Obtener stamina actual
	var current_stamina: int = _resource_system.get_resource_amount(entity_id, "stamina")
	
	# Evaluar condición
	var success: bool = current_stamina >= escape_threshold
	
	if success:
		print("[EscapeModule] ✅ Escape SUCCESS!")
		print("  Stamina: %d / %d required" % [current_stamina, escape_threshold])
		escape_success.emit()
	else:
		print("[EscapeModule] ❌ Escape FAILED")
		print("  Stamina: %d / %d required (missing: %d)" % [
			current_stamina, escape_threshold, escape_threshold - current_stamina
		])
		escape_failed.emit(current_stamina, escape_threshold)
	
	# Resetear estado
	reset()
	
	return success


## Verifica si hay un escape pendiente
func is_pending() -> bool:
	return is_escape_pending


## Resetea el módulo
func reset() -> void:
	is_escape_pending = false
	escape_threshold = 0


## Obtiene el threshold actual (útil para UI)
func get_current_threshold() -> int:
	return escape_threshold

# ============================================
# INTERACCIÓN CON DefenseModule
# ============================================

## Cancela la defensa activa si se solicita escape
## Regla: Escape tiene prioridad sobre Defensa
## Parámetros:
##   defense_module: Referencia al DefenseModule activo
func cancel_defense_if_active(defense_module) -> void:
	if defense_module and defense_module.is_active():
		defense_module.is_defending = false
		print("[EscapeModule] ⚠️ Escape cancelled active defense")

# ============================================
# DEBUG / TESTING
# ============================================

## Calcula el threshold para un número de enemigos sin activar el escape
func debug_calculate_threshold(enemy_count: int) -> int:
	return BASE_THRESHOLD + (enemy_count * PER_ENEMY)


## Simula un escenario de escape para testing
func debug_simulate_scenario(enemy_count: int, entity_stamina: int) -> Dictionary:
	print("\n[EscapeModule] === DEBUG SIMULATION ===")
	print("  Enemies: %d" % enemy_count)
	print("  Player stamina: %d" % entity_stamina)
	
	var threshold = debug_calculate_threshold(enemy_count)
	var success = entity_stamina >= threshold
	var missing = max(0, threshold - entity_stamina)
	
	print("  Required threshold: %d" % threshold)
	print("  Result: %s" % ("SUCCESS ✅" if success else "FAILED ❌"))
	if not success:
		print("  Missing stamina: %d" % missing)
	print("=====================================\n")
	
	return {
		"threshold": threshold,
		"success": success,
		"missing_stamina": missing
	}


## Imprime tabla de thresholds para diferentes cantidades de enemigos
func debug_print_threshold_table() -> void:
	print("\n[EscapeModule] === ESCAPE THRESHOLD TABLE ===")
	print("  Enemies | Threshold")
	print("  --------|----------")
	for i in range(1, 6):
		var threshold = debug_calculate_threshold(i)
		print("  %d       | %d" % [i, threshold])
	print("==========================================\n")
