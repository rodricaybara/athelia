class_name SaveData
extends RefCounted

## SaveData - Modelo de datos para guardado/carga
## Estructura del archivo .save en formato JSON

## Versión del formato de guardado (para migraciones futuras)
const SAVE_VERSION: int = 4  # ⭐ Incrementado de 3 a 4 — añadidos skill_values, equipment

## Identificador del slot
var save_id: String = "quicksave"

## Metadata del guardado
var metadata: Dictionary = {}

## Estado del jugador
var player_state: Dictionary = {}

## Estado del mundo
var world_state: Dictionary = {}

## Estado del sistema económico
var economy_state: Dictionary = {}

## Estado narrativo y checkpoints
var narrative_state: Dictionary = {}


## Constructor
func _init():
	metadata = {
		"save_id":          save_id,
		"timestamp":        "",
		"playtime_seconds": 0,
		"game_build":       "0.1.0-spike"
	}

	player_state = {
		"position":     {"x": 0.0, "y": 0.0},
		"resources":    {},
		"skills":       {},
		"skill_values": {},  # ⭐ NUEVO v4: valores de progresión (viven en CharacterSystem)
		"equipment":    {},  # ⭐ NUEVO v4: slots equipados (viven en EquipmentManager)
	}

	world_state = {
		"current_scene": ""
	}

	economy_state = {
		"shops": {}
	}

	narrative_state = {
		"flags":            {},
		"variables":        {},
		"completed_events": [],
		"checkpoints": {
			"reached_checkpoints": [],
			"current_checkpoint":  ""
		}
	}


## Convierte a Dictionary para serialización JSON
func to_dict() -> Dictionary:
	return {
		"version":         SAVE_VERSION,
		"metadata":        metadata,
		"player_state":    player_state,
		"world_state":     world_state,
		"economy_state":   economy_state,
		"narrative_state": narrative_state
	}


## Crea SaveData desde Dictionary (carga)
static func from_dict(data: Dictionary) -> SaveData:
	var save_data = SaveData.new()

	if not data.has("version"):
		push_error("[SaveData] Missing version field")
		return null

	var version = data.get("version", 0)
	if version > SAVE_VERSION:
		push_warning("[SaveData] Save version %d is newer than current %d" % [version, SAVE_VERSION])

	if version < SAVE_VERSION:
		data = _migrate_from_version(data, version)

	save_data.metadata        = data.get("metadata",        {})
	save_data.player_state    = data.get("player_state",    {})
	save_data.world_state     = data.get("world_state",     {})
	save_data.economy_state   = data.get("economy_state",   {})
	save_data.narrative_state = data.get("narrative_state", {})
	save_data.save_id         = save_data.metadata.get("save_id", "quicksave")

	return save_data


## Migra datos de versiones antiguas al formato actual
static func _migrate_from_version(data: Dictionary, from_version: int) -> Dictionary:
	print("[SaveData] Migrating from version %d to %d" % [from_version, SAVE_VERSION])

	# v1/v2 → v3: añadir economy_state vacío
	if from_version < 3:
		if not data.has("economy_state"):
			data["economy_state"] = {"shops": {}}
			print("[SaveData] Migration: added empty economy_state")

	# v3 → v4: añadir skill_values y equipment en player_state
	# is_unlocked no necesita campo aquí: SkillSystem.load_save_state()
	# usa default true cuando la clave no existe en el entry del skill.
	if from_version < 4:
		var ps: Dictionary = data.get("player_state", {})
		if not ps.has("skill_values"):
			ps["skill_values"] = {}
			print("[SaveData] Migration: added empty skill_values")
		if not ps.has("equipment"):
			ps["equipment"] = {}
			print("[SaveData] Migration: added empty equipment")
		data["player_state"] = ps

	data["version"] = SAVE_VERSION
	return data


## Valida que los datos son coherentes
func validate() -> bool:
	if not metadata.has("timestamp"):
		push_error("[SaveData] Missing timestamp")
		return false

	if not player_state.has("position"):
		push_error("[SaveData] Missing player position")
		return false

	if not world_state.has("current_scene"):
		push_error("[SaveData] Missing current scene")
		return false

	if not narrative_state.has("checkpoints"):
		push_warning("[SaveData] Missing narrative checkpoints (old save?)")
		narrative_state["checkpoints"] = {
			"reached_checkpoints": [],
			"current_checkpoint":  ""
		}

	return true


## Debug
func _to_string() -> String:
	var shop_count = economy_state.get("shops", {}).size()
	return "SaveData(id=%s, scene=%s, shops=%d)" % [
		save_id,
		world_state.get("current_scene", "N/A"),
		shop_count
	]
