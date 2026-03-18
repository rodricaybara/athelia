class_name SkillInstance
extends RefCounted

## SkillInstance - Estado mutable de una habilidad para una entidad
## Parte del SkillSystem
## Representa el ESTADO actual de uso de una habilidad
##
## v2: Añadido bloque PROGRESSION con estado volatil de combate.
##     Todo compatible hacia atras — defaults seguros.

# ============================================
# BLOQUE ORIGINAL — sin cambios
# ============================================

var definition: SkillDefinition
var current_cooldown: float = 0.0
var total_uses: int = 0
var last_used_time: float = 0.0

func _init(skill_def: SkillDefinition):
	if skill_def == null:
		push_error("[SkillInstance] definition cannot be null")
		return
	definition = skill_def

func is_on_cooldown() -> bool:
	return current_cooldown > 0.0

func is_available() -> bool:
	return is_unlocked and not is_on_cooldown()

func get_cooldown_percentage() -> float:
	if definition.base_cooldown <= 0:
		return 0.0
	return clampf(current_cooldown / definition.base_cooldown, 0.0, 1.0)

func get_cooldown_remaining() -> float:
	return current_cooldown

func start_cooldown() -> void:
	current_cooldown = definition.base_cooldown
	total_uses += 1
	last_used_time = Time.get_ticks_msec() / 1000.0

func process_cooldown(delta: float) -> void:
	if current_cooldown > 0:
		current_cooldown = maxf(0.0, current_cooldown - delta)

func reset_cooldown() -> void:
	current_cooldown = 0.0


# ============================================
# BLOQUE PROGRESSION — nuevo en v2
# Estado VOLATIL: se resetea al inicio/fin de cada combate.
# NO se persiste en save. NO afecta al sistema de cooldowns.
# ============================================

## Ticks de exito acumulados en este combate.
## Un tick = uso exitoso valido para mejora.
var ticks_this_combat: int = 0

## Fallos consecutivos desde el ultimo exito.
## Usado por el pity system.
var consecutive_failures: int = 0

## True si el pity system se ha activado en este combate.
## Bloquea nuevos ticks hasta resetear.
var pity_triggered: bool = false

## True si hay suficientes ticks para intentar mejora al fin del combate.
var marked_for_improvement: bool = false

## True si la skill está disponible para usar.
## False si requiere desbloqueo narrativo previo.
var is_unlocked: bool = true

## Desbloquea la skill (llamado por narrativa/NPC/evento).
func unlock() -> void:
	is_unlocked = true

## Registra un exito. Devuelve true si el tick fue aceptado.
## Devuelve false si se ha alcanzado el cap o pity esta activo.
func register_success() -> bool:
	consecutive_failures = 0

	if pity_triggered:
		return false

	var max_ticks = _get_effective_max_ticks()
	if ticks_this_combat >= max_ticks:
		return false

	ticks_this_combat += 1
	marked_for_improvement = true
	return true


## Registra un fallo. Incrementa el contador para pity.
func register_failure() -> void:
	consecutive_failures += 1


## Activa el pity system. Invalida los ticks acumulados.
func trigger_pity() -> void:
	pity_triggered = true
	ticks_this_combat = 0
	marked_for_improvement = false


## Resetea todo el estado volatil de combate.
## Llamado por SkillProgressionService al inicio y fin de cada combate.
func reset_combat_state() -> void:
	ticks_this_combat     = 0
	consecutive_failures  = 0
	pity_triggered        = false
	marked_for_improvement = false


## True si hay ticks validos y no hay pity activo.
func can_attempt_improvement() -> bool:
	return marked_for_improvement and not pity_triggered and ticks_this_combat > 0


# ============================================
# HELPERS
# ============================================

func _get_effective_max_ticks() -> int:
	if definition.max_ticks_per_combat > 0:
		return definition.max_ticks_per_combat
	return 3  # fallback global — reemplazar por config cuando exista


# ============================================
# DEBUG
# ============================================

func _to_string() -> String:
	var progression_info: String = ""
	if definition.has_progression():
		progression_info = " | ticks=%d, fails=%d%s" % [
			ticks_this_combat,
			consecutive_failures,
			" [PITY]" if pity_triggered else ""
		]
	if is_on_cooldown():
		return "SkillInstance(%s: CD %.1fs%s)" % [definition.id, current_cooldown, progression_info]
	return "SkillInstance(%s: Ready, %d uses%s)" % [definition.id, total_uses, progression_info]
