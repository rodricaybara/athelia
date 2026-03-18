class_name ItemDefinition
extends Resource

## ItemDefinition - Definición inmutable de un ítem (v2)
## Incluye peso, durabilidad, valor base y modificadores
##
## IMPORTANTE: Esta clase NO ejecuta lógica de juego
## Solo describe QUÉ ES un ítem

# ============================================
# IDENTIDAD
# ============================================

## Identificador único del ítem
@export var id: String = ""

## Clave de localización para el nombre
@export var name_key: String = ""

## Clave de localización para la descripción
@export var description_key: String = ""

## Icono del ítem
@export var icon: Texture2D


# ============================================
# PROPIEDADES FÍSICAS/ECONÓMICAS (v2)
# ============================================

## Peso en kg (mínimo 0.1)
@export var weight: float = 0.1

## Durabilidad máxima (mínimo 1)
## Para consumibles de un uso: durability_max = 1
@export var durability_max: int = 100000

## Valor base en oro (mínimo 0)
@export var base_value: int = 0


# ============================================
# CLASIFICACIÓN
# ============================================

## Tipo de ítem
@export_enum("CONSUMABLE", "EQUIPMENT", "MISC") var item_type: String = "MISC"

## ¿Puede apilarse?
@export var stackable: bool = true

## Cantidad máxima por stack (solo si stackable = true)
@export var max_stack: int = 99

## ¿Se puede usar directamente?
@export var usable: bool = false

## Acción al usar (genérico por ahora)
## Ejemplos: "apply_modifiers", "equip", "read"
@export var use_action: String = "apply_modifiers"


# ============================================
# SEMÁNTICA
# ============================================

## Tags para clasificación y búsqueda
## Ejemplos: "consumable", "potion", "stamina", "magical"
@export var tags: Array[String] = []


# ============================================
# MODIFICADORES (v2)
# ============================================

## Modificadores declarativos
## Define QUÉ efectos tiene el ítem, NO cómo se aplican
@export var modifiers: Array[ModifierDefinition] = []

## Datos de sesión de aprendizaje para ítems de tipo libro/pergamino.
## Si no está vacío, al usar el ítem se ejecuta una LearningSession
## en lugar de (o además de) aplicar modificadores estándar.
## Formato: { "skill_id": String, "source_level": int, "source_type": String }
## Ejemplo: { "skill_id": "skill.attack.light", "source_level": 35, "source_type": "BOOK" }
@export var learning_data: Dictionary = {}


# ============================================
# VALIDACIÓN
# ============================================

## Valida que la definición sea coherente
func validate() -> bool:
	# ID obligatorio
	if id.is_empty():
		push_error("[ItemDefinition] id cannot be empty")
		return false
	
	# Clave de nombre obligatoria
	if name_key.is_empty():
		push_error("[ItemDefinition] name_key cannot be empty")
		return false
	
	# Peso mínimo 0.1 kg
	if weight < 0.1:
		push_error("[ItemDefinition] weight must be >= 0.1 (got %.2f)" % weight)
		return false
	
	# Durabilidad mínima 1
	if durability_max < 1:
		push_error("[ItemDefinition] durability_max must be >= 1 (got %d)" % durability_max)
		return false
	
	# Valor no negativo
	if base_value < 0:
		push_error("[ItemDefinition] base_value must be >= 0 (got %d)" % base_value)
		return false
	
	# Si es stackable, max_stack debe ser >= 1
	if stackable and max_stack < 1:
		push_error("[ItemDefinition] max_stack must be >= 1 for stackable items (got %d)" % max_stack)
		return false
	
	# Validar todos los modificadores
	for i in range(modifiers.size()):
		var mod = modifiers[i]
		if mod == null:
			push_error("[ItemDefinition] modifier[%d] is null" % i)
			return false
		
		if not mod.validate():
			push_error("[ItemDefinition] modifier[%d] validation failed" % i)
			return false
	
	return true


# ============================================
# UTILIDADES
# ============================================

## Calcula el peso total para una cantidad dada
func get_total_weight(quantity: int = 1) -> float:
	return weight * quantity


## ¿Tiene modificadores?
func has_modifiers() -> bool:
	return not modifiers.is_empty()


## Obtiene modificadores que se aplican en cierta condición
func get_modifiers_for_condition(condition: String) -> Array[ModifierDefinition]:
	var result: Array[ModifierDefinition] = []
	for mod in modifiers:
		if mod.condition == condition:
			result.append(mod)
	return result


## ¿Tiene un tag específico?
func has_tag(tag: String) -> bool:
	return tag in tags


## Debug
func _to_string() -> String:
	return "ItemDef(%s, %.1fg, %d gold, %d mods)" % [
		id, 
		weight, 
		base_value,
		modifiers.size()
	]
