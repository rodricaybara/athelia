class_name InteractionDefinition
extends Resource

## InteractionDefinition - Define una interacción posible sobre un WorldObject
## Sub-resource embebido en WorldObjectDefinition
##
## Especifica QUÉ habilidad se requiere, QUÉ cuesta, QUÉ flags necesita/consume/produce
## y QUÉ outcome se aplica según el resultado de la tirada.
## NO contiene lógica de ejecución.

# ============================================
# IDENTIDAD
# ============================================

## ID único de la interacción dentro del objeto (ej: "force_lock", "inspect")
@export var id: String = ""

## Clave de localización para el botón/etiqueta en UI
@export var label_key: String = ""

## Clave de localización para la descripción en UI
@export var description_key: String = ""


# ============================================
# REQUISITOS DE HABILIDAD
# ============================================

## ID de la skill necesaria para intentar esta interacción
## Si el jugador no la tiene registrada, la interacción no aparece
@export var required_skill: String = ""

## Modificador de dificultad sobre la tirada base (1.0 = normal, 1.5 = difícil)
@export var difficulty: float = 1.0


# ============================================
# COSTE DE RECURSOS
# ============================================

## Coste en stamina para intentar la interacción (0 = gratis)
@export var stamina_cost: float = 0.0


# ============================================
# SISTEMA DE FLAGS
# ============================================

## Flags que deben estar ACTIVAS para que esta interacción esté disponible
## Si alguna no está presente en WorldObjectState, la interacción se oculta
@export var required_flags: Array[String] = []

## Flags que BLOQUEAN esta interacción si cualquiera de ellas está activa
## Uso típico: fases progresivas — la fase anterior se excluye cuando aparece
## la flag que activa la fase siguiente, aunque required_flags sigan cumpliéndose
@export var excluded_by_flags: Array[String] = []

## Flags que se ELIMINAN del WorldObjectState en éxito o crítico
@export var consumed_flags: Array[String] = []

## Flags que se AÑADEN al WorldObjectState en éxito o crítico
@export var produced_flags: Array[String] = []

## Flags que se ELIMINAN del WorldObjectState en fallo
## Vacío por defecto — la mayoría de interacciones no necesitan modificar estado en fallo
@export var failure_consumed_flags: Array[String] = []

## Flags que se AÑADEN al WorldObjectState en fallo
## Uso típico: degradación progresiva (ej: producir "lock_damaged" al fallar force_lock)
## Las pifias (fumble) NO aplican estas flags
@export var failure_produced_flags: Array[String] = []


# ============================================
# ÍTEM OPCIONAL
# ============================================

## ID del ítem que, si está en el inventario, se consume automáticamente al ejecutar
## y aplica un bonus a la tirada. Si no está presente, la interacción funciona igual sin bonus.
## Vacío = no se busca ningún ítem (comportamiento por defecto)
@export var optional_item: String = ""

## Bonus a la skill que aplica si optional_item está en el inventario
@export var optional_item_bonus: int = 0

## Skill a la que se aplica el bonus. Si vacío, usa required_skill
@export var optional_item_skill_target: String = ""


# ============================================
# OUTCOMES POR RESULTADO DE TIRADA
# ============================================

## Resultado en caso de crítico (tirada especialmente exitosa)
@export var outcome_critical: InteractionOutcome = null

## Resultado en caso de éxito normal
@export var outcome_success: InteractionOutcome = null

## Resultado en caso de fallo
@export var outcome_failure: InteractionOutcome = null

## Resultado en caso de pifia (fallo crítico)
## NINGUNA flag se modifica en fumble (ni success ni failure flags)
@export var outcome_fumble: InteractionOutcome = null


# ============================================
# UTILIDADES
# ============================================

## Devuelve el outcome correspondiente al resultado de tirada
## result: "critical" | "success" | "failure" | "fumble"
func get_outcome(result: String) -> InteractionOutcome:
	match result:
		"critical": return outcome_critical
		"success":  return outcome_success
		"failure":  return outcome_failure
		"fumble":   return outcome_fumble
	push_warning("[InteractionDefinition] Unknown result type: %s" % result)
	return null


## Valida que la definición sea coherente
func validate() -> bool:
	if id.is_empty():
		push_error("[InteractionDefinition] id cannot be empty")
		return false

	if required_skill.is_empty():
		push_error("[InteractionDefinition] required_skill cannot be empty (id: %s)" % id)
		return false

	if difficulty <= 0.0:
		push_error("[InteractionDefinition] difficulty must be > 0 (id: %s)" % id)
		return false

	if outcome_success == null:
		push_error("[InteractionDefinition] outcome_success is required (id: %s)" % id)
		return false

	return true
