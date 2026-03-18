class_name SaveSystem
extends Node

## SaveSystem - Gestor central de guardado/carga
## Responsabilidades:
## - Serializar estado del juego
## - Guardar en disco (JSON)
## - Cargar desde disco
## - Validar integridad
## - Gestionar backups

## Señales
signal save_started(slot_id: String)
signal save_completed(slot_id: String)
signal save_failed(slot_id: String, reason: String)
signal load_started(slot_id: String)
signal load_completed(slot_id: String)
signal load_failed(slot_id: String, reason: String)

## Configuración
const SAVE_DIR: String         = "user://saves/"
const SAVE_EXTENSION: String   = ".save"
const BACKUP_EXTENSION: String = ".backup"

## Referencias a sistemas
var resource_system:   ResourceSystem = null
var skill_system:      SkillSystem    = null
var economy_system:    Node           = null
var equipment_manager: Node           = null  # ⭐ NUEVO v4

## Playtime tracking
var playtime_seconds: float = 0.0


## Inicialización
func _ready():
	_ensure_save_directory()

	resource_system   = get_node_or_null("/root/Resources")
	skill_system      = get_node_or_null("/root/Skills")
	economy_system    = get_node_or_null("/root/Economy")
	equipment_manager = get_node_or_null("/root/Equipment")  # ⭐ NUEVO v4

	if not resource_system:
		push_error("[SaveSystem] ResourceSystem not found!")
	if not skill_system:
		push_error("[SaveSystem] SkillSystem not found!")
	if not economy_system:
		push_warning("[SaveSystem] EconomySystem not found!")
	if not equipment_manager:
		push_warning("[SaveSystem] EquipmentManager not found — equipment won't be saved/loaded")

	print("[SaveSystem] Initialized")
	print("[SaveSystem] Save directory: %s" % SAVE_DIR)


## Actualiza playtime
func _process(delta: float):
	playtime_seconds += delta


## Asegura que existe el directorio de guardado
func _ensure_save_directory():
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")


## Obtiene la ruta completa del archivo de guardado
func _get_save_path(slot_id: String) -> String:
	return SAVE_DIR + slot_id + SAVE_EXTENSION


## Obtiene la ruta del backup
func _get_backup_path(slot_id: String) -> String:
	return SAVE_DIR + slot_id + BACKUP_EXTENSION


# ============================================
# GUARDAR
# ============================================

## Guarda el juego en un slot
func save_game(slot_id: String = "quicksave") -> bool:
	save_started.emit(slot_id)
	print("[SaveSystem] Saving game to slot: %s" % slot_id)

	var save_data = SaveData.new()
	save_data.save_id = slot_id

	save_data.metadata["timestamp"]        = Time.get_datetime_string_from_system()
	save_data.metadata["playtime_seconds"] = int(playtime_seconds)
	save_data.metadata["game_build"]       = "0.1.0-spike"
	save_data.metadata["save_id"]          = slot_id

	if not _collect_player_state(save_data):
		save_failed.emit(slot_id, "Failed to collect player state")
		return false

	_collect_world_state(save_data)

	if not _collect_economy_state(save_data):
		push_warning("[SaveSystem] Failed to collect economy state, continuing anyway")

	if not save_data.validate():
		save_failed.emit(slot_id, "Validation failed")
		return false

	var json_string = JSON.stringify(save_data.to_dict(), "\t")

	var save_path = _get_save_path(slot_id)
	if FileAccess.file_exists(save_path):
		_create_backup(slot_id)

	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		save_failed.emit(slot_id, "Cannot open file for writing")
		return false

	file.store_string(json_string)
	file.close()

	print("[SaveSystem] Game saved successfully (%d bytes)" % json_string.length())
	save_completed.emit(slot_id)
	return true


## Recopila el estado del jugador
func _collect_player_state(save_data: SaveData) -> bool:
	var player = _find_player()
	if not player:
		push_error("[SaveSystem] Player node not found")
		return false

	# Posición
	save_data.player_state["position"] = {
		"x": player.position.x,
		"y": player.position.y
	}

	# Recursos (HP, stamina, gold actuales)
	save_data.player_state["resources"] = resource_system.get_save_state("player")

	# Skills: cooldowns, total_uses, is_unlocked (v4 del SkillSystem)
	save_data.player_state["skills"] = skill_system.get_save_state("player")

	# Inventario
	save_data.player_state["inventory"] = Inventory.get_save_state("player")

	# ⭐ NUEVO v4: Skill values de progresión (viven en CharacterSystem)
	var character_system = get_node_or_null("/root/Characters")
	if character_system:
		save_data.player_state["skill_values"] = character_system.get_all_skill_values("player")
		print("[SaveSystem] Skill values collected: %d" % save_data.player_state["skill_values"].size())
	else:
		push_warning("[SaveSystem] CharacterSystem not found — skill_values won't be saved")
		save_data.player_state["skill_values"] = {}

	# ⭐ NUEVO v4: Equipamiento (vive en EquipmentManager)
	if equipment_manager:
		save_data.player_state["equipment"] = equipment_manager.get_save_state("player")
		print("[SaveSystem] Equipment collected: %d slots" % save_data.player_state["equipment"].size())
	else:
		save_data.player_state["equipment"] = {}

	# Estado narrativo (flags, variables, eventos, checkpoints)
	_collect_narrative_state(save_data)
	
	# Estado del grupo de compañeros del player
	_collect_party_state(save_data)

	return true


## Recopila el estado del mundo
func _collect_world_state(save_data: SaveData):
	var current_scene = get_tree().current_scene
	if current_scene:
		save_data.world_state["current_scene"] = current_scene.scene_file_path


## Recopila el estado económico
func _collect_economy_state(save_data: SaveData) -> bool:
	if not economy_system:
		return true
	if not economy_system.has_method("get_save_state"):
		push_warning("[SaveSystem] EconomySystem has no get_save_state()")
		return false
	save_data.economy_state = economy_system.get_save_state()
	print("[SaveSystem] Economy collected: %d shops" % save_data.economy_state.get("shops", {}).size())
	return true


## Recopila el estado narrativo y checkpoints
func _collect_narrative_state(save_data: SaveData):
	save_data.narrative_state["flags"] = {}
	for flag in Narrative.get_active_flags():
		save_data.narrative_state["flags"][flag] = true

	save_data.narrative_state["variables"]        = Narrative.get_all_variables()
	save_data.narrative_state["completed_events"] = Narrative.get_completed_events()
	save_data.narrative_state["checkpoints"]      = Checkpoints.get_save_state()

	print("[SaveSystem] Narrative state collected:")
	print("  Flags: %d"       % save_data.narrative_state["flags"].size())
	print("  Variables: %d"   % save_data.narrative_state["variables"].size())
	print("  Events: %d"      % save_data.narrative_state["completed_events"].size())
	print("  Checkpoints: %d" % save_data.narrative_state["checkpoints"]["reached_checkpoints"].size())


# ============================================
# CARGAR
# ============================================

## Carga el juego desde un slot
func load_game(slot_id: String = "quicksave") -> bool:
	load_started.emit(slot_id)
	print("[SaveSystem] Loading game from slot: %s" % slot_id)

	var save_path = _get_save_path(slot_id)
	if not FileAccess.file_exists(save_path):
		load_failed.emit(slot_id, "Save file not found")
		return false

	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		load_failed.emit(slot_id, "Cannot open file for reading")
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) != OK:
		push_error("[SaveSystem] JSON parse error: %s (line %d)" % [
			json.get_error_message(), json.get_error_line()
		])
		load_failed.emit(slot_id, "JSON parse error")
		return false

	var save_data = SaveData.from_dict(json.data)
	if not save_data:
		load_failed.emit(slot_id, "Failed to parse save data")
		return false

	if not _restore_state(save_data):
		load_failed.emit(slot_id, "Failed to restore state")
		return false

	playtime_seconds = save_data.metadata.get("playtime_seconds", 0.0)

	print("[SaveSystem] Game loaded successfully")
	load_completed.emit(slot_id)
	return true


## Restaura el estado completo desde un SaveData
func _restore_state(save_data: SaveData) -> bool:
	print("[SaveSystem] Restoring state...")

	# 1. Recursos (fundamentales — van primero)
	var resources_data = save_data.player_state.get("resources", {})
	if not resources_data.is_empty():
		resource_system.load_save_state("player", resources_data)
		print("[SaveSystem] Resources restored")

	# 2. Skills: cooldowns, total_uses, is_unlocked
	var skills_data = save_data.player_state.get("skills", {})
	if not skills_data.is_empty():
		skill_system.load_save_state("player", skills_data)
		print("[SaveSystem] Skills restored (cooldowns reset)")

	# 3. ⭐ NUEVO v4: Skill values de progresión (CharacterSystem)
	var skill_values_data = save_data.player_state.get("skill_values", {})
	if not skill_values_data.is_empty():
		var character_system = get_node_or_null("/root/Characters")
		if character_system:
			for skill_id in skill_values_data.keys():
				character_system.set_skill_value("player", skill_id, skill_values_data[skill_id])
			print("[SaveSystem] Skill values restored: %d" % skill_values_data.size())
		else:
			push_warning("[SaveSystem] CharacterSystem not found — skill_values not restored")

	# 4. Estado narrativo
	_restore_narrative_state(save_data)

	# 5. Posición del jugador
	var player = _find_player()
	if player:
		var pos_data = save_data.player_state.get("position", {})
		player.position = Vector2(
			pos_data.get("x", 0.0),
			pos_data.get("y", 0.0)
		)
		print("[SaveSystem] Player position restored: %s" % player.position)

	# 6. Inventario
	var inventory_data = save_data.player_state.get("inventory", {})
	if not inventory_data.is_empty():
		Inventory.load_save_state("player", inventory_data)
		print("[SaveSystem] Inventory restored")

	# 7. ⭐ NUEVO v4: Equipamiento (EquipmentManager)
	var equipment_data = save_data.player_state.get("equipment", {})
	if not equipment_data.is_empty() and equipment_manager:
		equipment_manager.load_save_state("player", equipment_data)
		print("[SaveSystem] Equipment restored: %d slots" % equipment_data.size())

	# 8. Economía (tiendas)
	if economy_system and economy_system.has_method("load_save_state"):
		var economy_data = save_data.economy_state
		if not economy_data.is_empty():
			if economy_system.load_save_state(economy_data):
				print("[SaveSystem] Economy restored")
			else:
				push_warning("[SaveSystem] Economy restoration had errors")

	# 8.5 Grupo de compañeros del player
	_restore_party_state(save_data)
	# 9. Cambio de escena (futuro — descomenta cuando esté implementado)
	# var target_scene = save_data.world_state.get("current_scene", "")
	# if target_scene and target_scene != get_tree().current_scene.scene_file_path:
	#     get_tree().change_scene_to_file(target_scene)

	return true


## Restaura el estado narrativo y checkpoints
func _restore_narrative_state(save_data: SaveData):
	print("[SaveSystem] Restoring narrative state...")

	var narrative_data = save_data.narrative_state

	Narrative.clear_all()

	var flags_data = narrative_data.get("flags", {})
	for flag in flags_data.keys():
		if flags_data[flag]:
			Narrative.set_flag(flag)
	print("  Flags restored: %d" % flags_data.size())

	var vars_data = narrative_data.get("variables", {})
	for var_name in vars_data.keys():
		Narrative.set_variable(var_name, vars_data[var_name])
	print("  Variables restored: %d" % vars_data.size())

	var events_data = narrative_data.get("completed_events", [])
	for event_id in events_data:
		Narrative.register_event(event_id)
	print("  Events restored: %d" % events_data.size())

	var checkpoints_data = narrative_data.get("checkpoints", {})
	if not checkpoints_data.is_empty():
		Checkpoints.load_save_state(checkpoints_data)

	print("[SaveSystem] Narrative state restored successfully")

func _collect_party_state(save_data: SaveData) -> void:
	var party := get_node_or_null("/root/Party")
	if not party:
		return
	save_data.player_state["party"] = party.get_save_state()
	print("[SaveSystem] Party collected: %d companions" % party.get_party_members().size())
 
func _restore_party_state(save_data: SaveData) -> void:
	var party := get_node_or_null("/root/Party")
	if not party:
		return
	var party_data: Dictionary = save_data.player_state.get("party", {})
	if not party_data.is_empty():
		party.load_save_state(party_data)
		print("[SaveSystem] Party restored: %d companions" % party.get_party_members().size())
		
# ============================================
# UTILIDADES
# ============================================

## Crea un backup del save actual
func _create_backup(slot_id: String):
	var save_path   = _get_save_path(slot_id)
	var backup_path = _get_backup_path(slot_id)
	var dir = DirAccess.open(SAVE_DIR)
	if dir.file_exists(slot_id + SAVE_EXTENSION):
		dir.copy(save_path, backup_path)
		print("[SaveSystem] Backup created: %s" % backup_path)


## Busca el nodo Player en la escena actual
func _find_player() -> Node:
	var current_scene = get_tree().current_scene
	if not current_scene:
		return null
	var player = current_scene.get_node_or_null("Player")
	if player:
		return player
	return _find_node_by_name(current_scene, "Player")


## Busca un nodo por nombre recursivamente
func _find_node_by_name(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var found = _find_node_by_name(child, node_name)
		if found:
			return found
	return null


## Verifica si existe un save en un slot
func has_save(slot_id: String = "quicksave") -> bool:
	return FileAccess.file_exists(_get_save_path(slot_id))


## Obtiene información de un save sin cargarlo completo
func get_save_info(slot_id: String = "quicksave") -> Dictionary:
	if not has_save(slot_id):
		return {}
	var file = FileAccess.open(_get_save_path(slot_id), FileAccess.READ)
	if not file:
		return {}
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return {}
	file.close()
	return json.data.get("metadata", {})


## Debug: imprime información del save
func print_save_info(slot_id: String = "quicksave"):
	var info = get_save_info(slot_id)
	if info.is_empty():
		print("[SaveSystem] No save found in slot: %s" % slot_id)
		return
	print("\n[SaveSystem] Save info for '%s':" % slot_id)
	print("  Timestamp: %s"    % info.get("timestamp",        "N/A"))
	print("  Playtime:  %d s"  % info.get("playtime_seconds", 0))
	print("  Build:     %s"    % info.get("game_build",       "N/A"))
