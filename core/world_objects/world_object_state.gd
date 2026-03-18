class_name WorldObjectState
extends RefCounted

## WorldObjectState - Estado mutable de una instancia de objeto del mundo
## Parte del WorldObjectSystem
##
## Representa EL ESTADO ACTUAL de un objeto concreto en la escena:
## qué flags están activas, si está agotado, etc.
##
## IMPORTANTE:
##   - Una definición (WorldObjectDefinition) puede tener N instancias con estados distintos.
##   - Este objeto NO contiene lógica — solo almacena y expone estado.
##   - El WorldObjectSystem es el único que modifica este estado.

# ============================================
# REFERENCIAS
# ============================================

## Definición inmutable de la que deriva este estado
var definition: WorldObjectDefinition


# ============================================
# IDENTIDAD DE INSTANCIA
# ============================================

## ID único de esta instancia en la escena (ej: "chest_01", "chest_room3_b")
## Puede ser igual al definition.id si solo hay una instancia del tipo
var instance_id: String = ""


# ============================================
# ESTADO PERSISTENTE
# ============================================

## Flags activas actualmente sobre este objeto
## Ejemplo inicial: ["locked"]
## Tras forzar con éxito: ["opened"]
var active_flags: Array[String] = []

## True cuando el objeto ya no tiene ninguna interacción útil disponible
## (todas sus interacciones tienen required_flags que ya no se cumplirán)
## El WorldObjectSystem lo marca; la UI puede usarlo para ocultar el prompt
var is_depleted: bool = false


# ============================================
# CONSTRUCTOR
# ============================================

func _init(obj_def: WorldObjectDefinition, inst_id: String) -> void:
	if obj_def == null:
		push_error("[WorldObjectState] definition cannot be null")
		return

	definition = obj_def
	instance_id = inst_id

	# Copiar flags iniciales desde la definición
	active_flags = obj_def.initial_flags.duplicate()

	print("[WorldObjectState] Created '%s' (def: '%s') flags: %s" % [
		instance_id, obj_def.id, str(active_flags)
	])


# ============================================
# CONSULTA DE FLAGS
# ============================================

## ¿Está activa esta flag?
func has_flag(flag: String) -> bool:
	return active_flags.has(flag)

## ¿Están activas TODAS estas flags?
func has_all_flags(flags: Array) -> bool:
	for flag in flags:
		if not active_flags.has(flag):
			return false
	return true

## ¿Está activa ALGUNA de estas flags?
## Usado por excluded_by_flags: si cualquiera está activa, la interacción se oculta
func has_any_flag(flags: Array) -> bool:
	for flag in flags:
		if active_flags.has(flag):
			return true
	return false


# ============================================
# MODIFICACIÓN DE FLAGS
## Solo el WorldObjectSystem debe llamar estos métodos.
# ============================================

## Añade una flag si no estaba ya presente
func add_flag(flag: String) -> void:
	if not active_flags.has(flag):
		active_flags.append(flag)

## Elimina una flag si estaba presente
func remove_flag(flag: String) -> void:
	active_flags.erase(flag)

## Aplica los cambios de flags de una interacción
## consumed se eliminan, produced se añaden
func apply_flag_changes(consumed: Array[String], produced: Array[String]) -> void:
	for flag in consumed:
		remove_flag(flag)
	for flag in produced:
		add_flag(flag)


# ============================================
# SAVE / LOAD
# ============================================

## Snapshot para SaveSystem
## Solo se persiste lo mutable: flags e is_depleted
func get_save_state() -> Dictionary:
	return {
		"instance_id":   instance_id,
		"definition_id": definition.id,
		"active_flags":  active_flags.duplicate(),
		"is_depleted":   is_depleted
	}

## Restaura estado desde snapshot
func load_save_state(data: Dictionary) -> void:
	if data.has("active_flags"):
		active_flags = data["active_flags"].duplicate()
	if data.has("is_depleted"):
		is_depleted = data["is_depleted"]


# ============================================
# DEBUG
# ============================================

func _to_string() -> String:
	return "WorldObjectState(id=%s, flags=%s, depleted=%s)" % [
		instance_id, str(active_flags), str(is_depleted)
	]
