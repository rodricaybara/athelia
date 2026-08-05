extends Node

## test_character_persistence.gd
##
## Test aislado del roundtrip de guardado/carga para los datos de personaje
## (definition_id, character_name, attributes) — la conexión que hicimos hoy
## entre CharacterSystem y SaveSystem.
##
## Construye el personaje llamando directamente a _create_player_entity() del
## CharacterCreationViewModel (sin pasar por request_confirm_character(), que
## dispara GameLoop.enter_exploration() y cargaría una escena real — no
## queremos eso en un test aislado).
##
## Evita a propósito el hueco ya documentado de "registro en frío": aquí
## "player" está completamente registrado en todos los sistemas (Characters,
## Resources, Skills, Equipment, Inventory) ANTES de guardar y de cargar, así
## que no depende de la escena de exploración de producción pendiente.
##
## Uso: adjuntar a un Node raíz en una escena vacía guardada en disco (para
## que scene_file_path no esté vacío) y correr con F6.

const TEST_SLOT: String = "test_character_persistence"

var _passed: int = 0
var _failed: int = 0
var _dummy_player: Node2D = null


func _ready() -> void:
	print("\n" + "=".repeat(50))
	print("TEST — Persistencia de CharacterSystem (save/load)")
	print("=".repeat(50))

	# SaveSystem._collect_player_state() requiere un nodo "Player" en la
	# escena actual (usa su .position). En este test aislado no hay ninguno.
	_dummy_player = Node2D.new()
	_dummy_player.name = "Player"
	get_tree().current_scene.add_child(_dummy_player)

	await _test_roundtrip()

	_cleanup_test_save()
	if _dummy_player and is_instance_valid(_dummy_player):
		_dummy_player.queue_free()

	print("=".repeat(50))
	print("RESULTADO: %d/%d tests pasados" % [_passed, _passed + _failed])
	print("=".repeat(50))


func _assert(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] %s" % description)
	else:
		_failed += 1
		print("  [FAIL] %s" % description)


func _test_roundtrip() -> void:
	var chars: Node = get_node_or_null("/root/Characters")
	var save_manager: Node = get_node_or_null("/root/SaveManager")

	if not chars or not save_manager:
		_assert(false, "Characters y SaveManager deben estar disponibles como autoloads")
		return

	if chars.has_entity("player"):
		_assert(false, "'player' ya estaba registrado antes de empezar — correr esta escena en limpio")
		return

	# 1. Construir un personaje con valores conocidos
	var vm := CharacterCreationViewModel.new()
	add_child(vm)
	vm.open()
	vm.request_roll_attributes()
	for attr_id in CharacterCreationViewModel.PHYSICAL_ATTRIBUTES:
		vm.request_assign_value(vm.physical_pool[0], attr_id)
	for attr_id in CharacterCreationViewModel.RESILIENT_ATTRIBUTES:
		vm.request_assign_value(vm.resilient_pool[0], attr_id)
	vm.request_continue_to_naming()
	vm.set_character_name("Persistencia Test")
	vm.request_continue_to_summary()

	var original_attributes: Dictionary = vm.assigned_attributes.duplicate()
	var original_name: String = vm.character_name

	# Crear la entidad directamente — sin pasar por request_confirm_character(),
	# que dispararía GameLoop.enter_exploration() y cargaría una escena real.
	vm._create_player_entity()

	_assert(chars.has_entity("player"), "'player' registrado tras _create_player_entity()")
	_assert(chars.get_character_name("player") == original_name, "Nombre correcto tras crear")

	# 2. Guardar
	var save_ok: bool = save_manager.save_game(TEST_SLOT)
	_assert(save_ok, "save_game() retorna true")

	# 3. Mutar el estado en memoria — así probamos que el load() restaura de
	# verdad, no que los valores "ya estaban bien" por casualidad.
	chars.set_character_name("player", "NOMBRE_CORROMPIDO")
	for attr_id in original_attributes.keys():
		chars.set_base_attribute("player", attr_id, 1.0)

	_assert(chars.get_character_name("player") == "NOMBRE_CORROMPIDO", "Mutación de prueba aplicada")

	# 4. Cargar — debe restaurar los valores originales
	var load_ok: bool = save_manager.load_game(TEST_SLOT)
	_assert(load_ok, "load_game() retorna true")

	_assert(chars.get_character_name("player") == original_name,
		"Nombre restaurado correctamente: '%s'" % chars.get_character_name("player"))

	var restored_attributes: Dictionary = chars.get_all_base_attributes("player")
	var attributes_ok := true
	for attr_id in original_attributes.keys():
		var expected: float = float(original_attributes[attr_id])
		var actual: float = restored_attributes.get(attr_id, -1.0)
		if not is_equal_approx(expected, actual):
			attributes_ok = false
			print("    Mismatch en %s: esperado %.1f, obtenido %.1f" % [attr_id, expected, actual])
	_assert(attributes_ok, "Los 6 atributos restaurados coinciden con los originales")

	vm.queue_free()


func _cleanup_test_save() -> void:
	var save_path: String = "user://saves/%s.save" % TEST_SLOT
	var backup_path: String = "user://saves/%s.backup" % TEST_SLOT
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
		print("[Test] Save de test eliminado: %s" % save_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
