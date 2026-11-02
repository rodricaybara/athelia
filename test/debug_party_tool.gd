extends Node

## DEBUG TEMPORAL — Spike 19 / 19b (solo para validar Party y la integridad de datos).
## NO entra en el entregable: borrar el fichero y quitar el autoload al terminar.
##
## Autoload: Project Settings → Globals → "DebugPartyTool" → res://test/debug_party_tool.gd
## Con Party CERRADA (exploración):
##   F5  → llena la mochila de Mira hasta 15 pilas distintas
##   F6  → PROBE no apilable que el destino ya tiene   (esperado PERDIDA=1)
##   F7  → PROBE tope de pila (9+3 > 10)               (esperado PERDIDA=2)
##   F8  → PROBE control, cabe en la pila              (esperado PERDIDA=0)
##   F10 → Mira abandona el grupo (caso 0 compañeros)
##   F11 → entra un segundo compañero de prueba (caso 2 compañeros)
##   F12 → sale el compañero de prueba
##
## AVISO: estas teclas DESTRUYEN estado (inventarios, party). No guardes la
## partida con ellas; tras probar, vuelve al menú y carga el guardado anterior.

const TEST_ID: String = "companion_debug_test"
## [inferido] La definición de Mira se llama "companion_mira".
const TEST_DEFINITION_ID: String = "companion_mira"
const MIRA_ID: String = "companion_mira"
const PROBE_PLAYER: String = "player"
const PROBE_COMPANION: String = "companion_mira"
const FILL_TARGET: int = 15

## [inferido] ids tomados de los nombres de fichero de data/items; los que no
## existan en el registro se saltan.
const FILL_ITEMS: Array[String] = [
	"steel_sword", "shortbow", "ring_health", "ring_stamina", "amulet_strength",
	"book_combat_basic", "book_tanning", "lockpick_quality", "stamina_potion_small",
	"health_potion", "silver_arrow", "obsidian_spearhead", "telmori_magic_bag",
	"wolf_tail_trophy", "enchanted_spear",
]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event
	if not key_event.pressed or key_event.echo:
		return

	match key_event.keycode:
		KEY_F5:
			_fill_companion_bag()
		KEY_F6:
			_probe_transfer("steel_sword", 1, 1, 1)
		KEY_F7:
			_probe_transfer("stamina_potion_small", 3, 5, 9)
		KEY_INSERT:
			_probe_transfer("stamina_potion_small", 3, 5, 2)
		KEY_HOME:
			_give_spear_to_companion()
		KEY_F10:
			var left: bool = Party.leave_party(MIRA_ID)
			print("[DebugPartyTool] F10 Mira abandona el grupo: %s" % str(left))
		KEY_F11:
			var joined: bool = Party.join_party(TEST_ID, TEST_DEFINITION_ID)
			print("[DebugPartyTool] F11 entra '%s': %s" % [TEST_ID, str(joined)])
		KEY_F12:
			var removed: bool = Party.leave_party(TEST_ID)
			print("[DebugPartyTool] F12 sale '%s': %s" % [TEST_ID, str(removed)])


func _fill_companion_bag() -> void:
	for item_id in FILL_ITEMS:
		if Inventory.get_inventory(PROBE_COMPANION).size() >= FILL_TARGET:
			break
		if Items.get_item(item_id) == null:
			print("[DebugPartyTool] F5 id inexistente, se salta: %s" % item_id)
			continue
		if not Inventory.has_item(PROBE_COMPANION, item_id):
			Inventory.add_item(PROBE_COMPANION, item_id, 1)
	print("[DebugPartyTool] F5 mochila de Mira: %d pilas" % Inventory.get_inventory(PROBE_COMPANION).size())


func _set_qty(entity_id: String, item_id: String, amount: int) -> void:
	var current: int = Inventory.get_item_quantity(entity_id, item_id)
	if current > 0:
		Inventory.remove_item(entity_id, item_id, current)
	if amount > 0:
		Inventory.add_item(entity_id, item_id, amount)


## Replica la secuencia de PartyViewModel._transfer_item (quitar y luego añadir)
func _probe_transfer(item_id: String, qty: int, seed_from: int, seed_to: int) -> void:
	_set_qty(PROBE_PLAYER, item_id, seed_from)
	_set_qty(PROBE_COMPANION, item_id, seed_to)
	var before: int = Inventory.get_item_quantity(PROBE_PLAYER, item_id) + Inventory.get_item_quantity(PROBE_COMPANION, item_id)
	var removed: bool = Inventory.remove_item(PROBE_PLAYER, item_id, qty)
	var added: bool = Inventory.add_item(PROBE_COMPANION, item_id, qty)
	var after: int = Inventory.get_item_quantity(PROBE_PLAYER, item_id) + Inventory.get_item_quantity(PROBE_COMPANION, item_id)
	print("[DebugPartyTool] PROBE %s x%d (origen %d, destino %d): remove=%s add=%s total antes=%d despues=%d PERDIDA=%d" % [
		item_id, qty, seed_from, seed_to, str(removed), str(added), before, after, before - after])

## Pone la lanza prestada en Mira, equipada (salta el bloqueo de Party a propósito)
func _give_spear_to_companion() -> void:
	if Inventory.has_item(PROBE_PLAYER, "enchanted_spear"):
		Equipment.unequip_item(PROBE_PLAYER, "enchanted_spear")
		Inventory.remove_item(PROBE_PLAYER, "enchanted_spear", 1)
	Inventory.add_item(PROBE_COMPANION, "enchanted_spear", 1)
	Equipment.equip_item(PROBE_COMPANION, "enchanted_spear")
	print("[DebugPartyTool] Inicio: lanza equipada en Mira")
