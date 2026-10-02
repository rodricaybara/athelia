class_name AdventureStarter
extends RefCounted

## AdventureStarter — Spike 13: arranque de partida data-driven.
##
## Sustituye a lo que hacía TelmoriVillage._ready(): unir companions y dar/equipar
## el kit inicial. Los datos viven en res://data/adventures/<id>.json.
##
## Llamar UNA sola vez, al confirmar el personaje. NO es idempotente a propósito:
## Inventory.add_item() suma, y repetirlo duplicaría el kit (el bug que tenía el
## pueblo al cargar partida).

const ADVENTURES_DIR: String = "res://data/adventures/"
const SUPPORTED_SCHEMA: int = 1


static func apply(adventure_id: String) -> bool:
	var path := "%s%s.json" % [ADVENTURES_DIR, adventure_id]
	if not FileAccess.file_exists(path):
		push_error("[AdventureStarter] No existe %s" % path)
		return false

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[AdventureStarter] JSON inválido: %s" % path)
		return false
	var data: Dictionary = parsed

	if int(data.get("schema_version", 0)) != SUPPORTED_SCHEMA:
		push_warning("[AdventureStarter] schema_version inesperada en %s" % path)

	var party: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/Party")
	if party:
		for companion_id in data.get("companions", []):
			party.join_party(str(companion_id))
	else:
		push_warning("[AdventureStarter] Party no encontrado")

	var gear: Dictionary = data.get("starting_gear", {})
	for entity_id in gear.keys():
		for item_id in gear[entity_id]:
			Inventory.add_item(str(entity_id), str(item_id), 1)
			Equipment.equip_item(str(entity_id), str(item_id))

	print("[AdventureStarter] Aventura '%s' aplicada" % adventure_id)
	return true
