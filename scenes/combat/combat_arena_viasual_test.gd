extends Node

## CombatArenaVisualTest — SOLO PARA PROBAR EL LAYOUT, borrar cuando ya
## no haga falta.
##
## Instancia CombatArenaPanel y le inyecta CombatTokenData/LogEntryData
## construidos a mano, escribiendo directo en _vm.combat_tokens/
## log_entries y emitiendo _vm.changed() nosotros mismos. Cero contacto
## con GameLoop/CombatSystem/SceneOrchestrator — no dispara start_combat()
## en ningún momento, así que no puede volver a chocar con la escena de
## combate real de producción.
##
## No valida reglas de combate ni el menú de acciones (action_menu se
## queda vacío, sin Characters/Loadout reales detrás) — solo el layout
## visual de fichas + log.

const PANEL_SCENE := "res://ui/combat/combat_arena_panel.tscn"


func _ready() -> void:
	var panel: CombatArenaPanel = load(PANEL_SCENE).instantiate()
	add_child(panel)
	panel.open()

	_inject_tokens(panel)
	_inject_log(panel)


func _inject_tokens(panel: CombatArenaPanel) -> void:
	var player := CombatTokenData.new()
	player.entity_id = "player"
	player.is_party = true
	player.display_initials = "FE"
	player.fill_color = Color("#5A544A")
	player.hp_current = 40
	player.hp_max = 55
	player.stamina_current = 25
	player.stamina_max = 40
	player.is_current_turn = true

	var enemy1 := CombatTokenData.new()
	enemy1.entity_id = "enemy_1"
	enemy1.is_party = false
	enemy1.hp_current = 12
	enemy1.hp_max = 40
	enemy1.is_targeted = true

	var enemy2 := CombatTokenData.new()
	enemy2.entity_id = "enemy_2"
	enemy2.is_party = false
	enemy2.hp_current = 40
	enemy2.hp_max = 40

	panel._vm.combat_tokens = [player, enemy1, enemy2]
	panel._vm.changed.emit("tokens")


func _inject_log(panel: CombatArenaPanel) -> void:
	var entries: Array = [
		["LOG_ATTACK_CRITICAL", ["player", "enemy_1", 20], SkillRoller.RollResult.CRITICAL],
		["LOG_ATTACK_FAILURE", ["enemy_1", "player"], SkillRoller.RollResult.FAILURE],
		["LOG_DODGE_ACTIVATED", ["player"], -1],
		["LOG_ATTACK_SPECIAL", ["enemy_2", "player", 4], SkillRoller.RollResult.SPECIAL],
	]
	for row in entries:
		var entry := LogEntryData.new()
		entry.text_key = row[0]
		entry.format_args = row[1]
		entry.grade = row[2]
		panel._vm.log_entries.append(entry)
		panel._vm.changed.emit("log_entry")
