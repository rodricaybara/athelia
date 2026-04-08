class_name LoadoutState
extends RefCounted

## LoadoutState - Configuración de slots de combate de un personaje
## Parte del CharacterSystem
##
## Almacena qué skill o ítem está asignado a cada slot de combate.
## Es estado PERSISTENTE — vive en CharacterState y se serializa en SaveData.
##
## Slots de skill:   attack_1/2/3, dodge, defense, escape
## Slots de consumible: consumable_1, consumable_2
##
## Restricciones por slot (se validan en LoadoutViewModel, no aquí):
##   attack_1/2/3  → SkillDefinition con tag "attack"
##   dodge         → SkillDefinition con tag "dodge"
##   defense       → SkillDefinition con tag "defensive"
##   escape        → SkillDefinition con tag "escape"
##   consumable_*  → ItemDefinition de tipo CONSUMABLE
##
## Compatible con cualquier CharacterState (jugador y companions).


# ============================================
# CONSTANTES
# ============================================

const SKILL_SLOTS: Array[String] = [
	"attack_1",
	"attack_2",
	"attack_3",
	"dodge",
	"defense",
	"escape"
]

const CONSUMABLE_SLOTS: Array[String] = [
	"consumable_1",
	"consumable_2"
]

## Tags requeridos por slot de skill
const SLOT_REQUIRED_TAG: Dictionary = {
	"attack_1":  "attack",
	"attack_2":  "attack",
	"attack_3":  "attack",
	"dodge":     "dodge",
	"defense":   "defensive",
	"escape":    "escape"
}


# ============================================
# ESTADO
# ============================================

## Skills asignadas por slot. Valor "" significa slot vacío.
## Formato: { slot_id: String -> skill_id: String }
var skill_slots: Dictionary = {}

## Consumibles asignados por slot. Valor "" significa slot vacío.
## Formato: { slot_id: String -> item_id: String }
var consumable_slots: Dictionary = {}


# ============================================
# CONSTRUCTOR
# ============================================

func _init() -> void:
	for slot_id in SKILL_SLOTS:
		skill_slots[slot_id] = ""
	for slot_id in CONSUMABLE_SLOTS:
		consumable_slots[slot_id] = ""


# ============================================
# LECTURA
# ============================================

## Devuelve la skill asignada a un slot. "" si vacío o slot inválido.
func get_skill(slot_id: String) -> String:
	return skill_slots.get(slot_id, "")


## Devuelve el ítem asignado a un slot de consumible. "" si vacío o slot inválido.
func get_consumable(slot_id: String) -> String:
	return consumable_slots.get(slot_id, "")


## ¿El slot de skill está ocupado?
func is_skill_slot_filled(slot_id: String) -> bool:
	return skill_slots.get(slot_id, "") != ""


## ¿El slot de consumible está ocupado?
func is_consumable_slot_filled(slot_id: String) -> bool:
	return consumable_slots.get(slot_id, "") != ""


## Devuelve el tag requerido para un slot de skill.
## Devuelve "" si el slot no existe o no es de skill.
func get_required_tag(slot_id: String) -> String:
	return SLOT_REQUIRED_TAG.get(slot_id, "")


# ============================================
# ESCRITURA
# ============================================

## Asigna una skill a un slot.
## No valida restricciones de tag — eso es responsabilidad del LoadoutViewModel.
func assign_skill(slot_id: String, skill_id: String) -> void:
	if not skill_slots.has(slot_id):
		push_warning("[LoadoutState] Slot de skill inválido: %s" % slot_id)
		return
	skill_slots[slot_id] = skill_id


## Asigna un consumible a un slot.
func assign_consumable(slot_id: String, item_id: String) -> void:
	if not consumable_slots.has(slot_id):
		push_warning("[LoadoutState] Slot de consumible inválido: %s" % slot_id)
		return
	consumable_slots[slot_id] = item_id


## Vacía un slot (skill o consumible).
func clear_slot(slot_id: String) -> void:
	if skill_slots.has(slot_id):
		skill_slots[slot_id] = ""
	elif consumable_slots.has(slot_id):
		consumable_slots[slot_id] = ""
	else:
		push_warning("[LoadoutState] Slot inválido: %s" % slot_id)


# ============================================
# SNAPSHOT PARA COMBATE
# ============================================

## Devuelve una copia inmutable del loadout para pasar a CombatSystem.
## CombatSystem nunca recibe una referencia viva — solo este snapshot.
## Formato: { slot_id: skill_id_o_item_id }
func get_combat_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for slot_id in skill_slots:
		snapshot[slot_id] = skill_slots[slot_id]
	for slot_id in consumable_slots:
		snapshot[slot_id] = consumable_slots[slot_id]
	return snapshot


# ============================================
# SAVE / LOAD
# ============================================

## Serializa el loadout para guardar en SaveData.
func get_save_state() -> Dictionary:
	return {
		"skill_slots":      skill_slots.duplicate(),
		"consumable_slots": consumable_slots.duplicate()
	}


## Restaura el loadout desde un snapshot de SaveData.
func load_save_state(data: Dictionary) -> void:
	if data.has("skill_slots"):
		for slot_id in SKILL_SLOTS:
			skill_slots[slot_id] = data["skill_slots"].get(slot_id, "")
	if data.has("consumable_slots"):
		for slot_id in CONSUMABLE_SLOTS:
			consumable_slots[slot_id] = data["consumable_slots"].get(slot_id, "")


# ============================================
# DEBUG
# ============================================

func print_state() -> void:
	print("\n=== LoadoutState ===")
	print("Skills:")
	for slot_id in skill_slots:
		var val: String = skill_slots[slot_id]
		print("  %s: %s" % [slot_id, val if val != "" else "(vacío)"])
	print("Consumibles:")
	for slot_id in consumable_slots:
		var val: String = consumable_slots[slot_id]
		print("  %s: %s" % [slot_id, val if val != "" else "(vacío)"])


func _to_string() -> String:
	var filled: int = 0
	for slot_id in skill_slots:
		if skill_slots[slot_id] != "":
			filled += 1
	for slot_id in consumable_slots:
		if consumable_slots[slot_id] != "":
			filled += 1
	return "LoadoutState(%d/%d slots ocupados)" % [filled, SKILL_SLOTS.size() + CONSUMABLE_SLOTS.size()]
