class_name CharacterDefinition
extends Resource

## CharacterDefinition - DefiniciÃ³n inmutable de un personaje
## Parte del CharacterSystem
## Representa QUÃ‰ PUEDE SER un personaje o mob
## NO contiene estado actual, solo datos base

# ============================================
# IDENTIDAD
# ============================================

## Identificador Ãºnico del personaje/mob
@export var id: String = ""

## Clave de localizaciÃ³n para el nombre
@export var name_key: String = ""

## Clave de localizaciÃ³n para la descripciÃ³n
@export var description_key: String = ""


# ============================================
# ATRIBUTOS BASE
# ============================================

## Atributos base iniciales
## Estos son valores INICIALES que pueden cambiar por progresiÃ³n
## NO incluir atributos derivados (hp_max, armor, etc.)
@export var base_attributes: Dictionary = {
	"strength": 10,
	"dexterity": 10,
	"constitution": 10,
	"intelligence": 10,
	"wisdom": 10,
	"charisma": 10
}


# ============================================
# RECURSOS INICIALES
# ============================================

## Recursos iniciales (valores actuales, NO mÃ¡ximos)
## Los mÃ¡ximos se calculan dinÃ¡micamente
@export var starting_resources: Dictionary = {
	"health": 30,
	"stamina": 20,
	"focus": 0,
	"gold": 0
}


# ============================================
# HABILIDADES Y EQUIPAMIENTO
# ============================================

## IDs de skills disponibles para este personaje
@export var skills: Array[String] = []

## Valores iniciales de habilidades (% de Ã©xito 0-100)
## Formato: { skill_id: String -> value: int }
## Ejemplo: { "skill.attack.light": 35, "skill.magic.fireball": 20 }
## FASE C.1.5: Sistema de tiradas RuneQuest
@export var starting_skill_values: Dictionary = {}

## NÃºmero de slots de inventario
@export var inventory_slots: int = 20

## ID de la loot table que suelta esta entidad al ser derrotada en combate.
## Vacio = sin loot. Referencia a LootTableDefinition en WorldObjectRegistry.
@export var loot_table_id: String = ""

## Slots de equipamiento disponibles
@export var equipment_slots: Array[String] = [
	"head",
	"body", 
	"hands",
	"feet",
	"weapon",
	"shield"
]


# ============================================
# VALIDACIÃ“N
# ============================================

## Valida que la definiciÃ³n sea coherente
func validate() -> bool:
	# ID obligatorio
	if id.is_empty():
		push_error("[CharacterDefinition] id cannot be empty")
		return false
	
	# Nombre obligatorio
	if name_key.is_empty():
		push_error("[CharacterDefinition] name_key cannot be empty")
		return false
	
	# Atributos base no pueden estar vacÃ­os
	if base_attributes.is_empty():
		push_error("[CharacterDefinition] base_attributes cannot be empty")
		return false
	
	# Validar que todos los atributos sean positivos
	for attr in base_attributes.keys():
		if base_attributes[attr] <= 0:
			push_error("[CharacterDefinition] attribute '%s' must be > 0 (got %s)" % [
				attr, base_attributes[attr]
			])
			return false
	
	# Validar recursos iniciales no negativos
	for res in starting_resources.keys():
		if starting_resources[res] < 0:
			push_error("[CharacterDefinition] resource '%s' cannot be negative (got %s)" % [
				res, starting_resources[res]
			])
			return false
	
	# Inventario debe tener al menos 1 slot
	if inventory_slots < 1:
		push_error("[CharacterDefinition] inventory_slots must be >= 1 (got %d)" % inventory_slots)
		return false
	
	return true


# ============================================
# UTILIDADES
# ============================================

## Obtiene el valor inicial de un atributo
func get_base_attribute(attr_id: String) -> float:
	return base_attributes.get(attr_id, 0.0)


## Obtiene el valor inicial de un recurso
func get_starting_resource(resource_id: String) -> float:
	return starting_resources.get(resource_id, 0.0)


## Â¿Tiene un skill especÃ­fico?
func has_skill(skill_id: String) -> bool:
	return skill_id in skills


## Â¿Tiene un slot de equipamiento especÃ­fico?
func has_equipment_slot(slot_name: String) -> bool:
	return slot_name in equipment_slots


## Crea una copia de esta definiciÃ³n (Ãºtil para modificadores)
func duplicate_definition() -> CharacterDefinition:
	var copy = CharacterDefinition.new()
	copy.id = id
	copy.name_key = name_key
	copy.description_key = description_key
	copy.base_attributes = base_attributes.duplicate()
	copy.starting_resources = starting_resources.duplicate()
	copy.skills = skills.duplicate()
	copy.inventory_slots = inventory_slots
	copy.equipment_slots = equipment_slots.duplicate()
	return copy


## Debug
func _to_string() -> String:
	return "CharacterDefinition(id=%s, STR=%d, DEX=%d, CON=%d)" % [
		id,
		base_attributes.get("strength", 0),
		base_attributes.get("dexterity", 0),
		base_attributes.get("constitution", 0)
	]
