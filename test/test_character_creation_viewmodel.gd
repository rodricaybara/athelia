extends Node

## test_character_creation_viewmodel.gd
##
## Test aislado del ViewModel de Character Creation. No depende de la escena
## real ni del stub — instancia el ViewModel directamente como hijo de este
## nodo de test.
##
## Los tests que llaman a request_confirm_character() SÍ dependen de los
## autoloads (Characters, Skills, Resources, Equipment, Inventory, GameLoop)
## y de que exista "player_new" en CharacterDefinition — están señalados
## explícitamente y se pueden comentar si player_new.tres aún no existe.
##
## Uso: adjuntar este script a un Node en una escena vacía y correrla (F6).

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	print("\n" + "=".repeat(50))
	print("TEST — CharacterCreationViewModel")
	print("=".repeat(50))

	_test_estado_inicial()
	_test_roll_llena_pools()
	_test_asignacion_completa()
	_test_desasignar_devuelve_valor_al_pool()
	_test_continuar_incompleto_falla()
	_test_nombre_vacio_falla()
	_test_nombre_valido_pasa_a_summary()
	_test_reroll_una_sola_vez()

	# Descomentar solo cuando exista player_new.tres en data/characters/
	await _test_confirmar_personaje()

	print("=".repeat(50))
	print("RESULTADO: %d/%d tests pasados" % [_passed, _passed + _failed])
	print("=".repeat(50))


func _new_vm() -> CharacterCreationViewModel:
	var vm := CharacterCreationViewModel.new()
	add_child(vm)
	vm.open()
	return vm


func _assert(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] %s" % description)
	else:
		_failed += 1
		print("  [FAIL] %s" % description)


# ============================================
# TESTS
# ============================================

func _test_estado_inicial() -> void:
	print("\n-- Estado inicial --")
	var vm := _new_vm()
	_assert(vm.state == CharacterCreationViewModel.CreationState.ROLLING, "Estado inicial es ROLLING")
	_assert(vm.physical_pool.is_empty(), "physical_pool vacío antes de tirar")
	_assert(vm.resilient_pool.is_empty(), "resilient_pool vacío antes de tirar")
	_assert(vm.assigned_attributes.is_empty(), "assigned_attributes vacío antes de tirar")
	vm.queue_free()


func _test_roll_llena_pools() -> void:
	print("\n-- request_roll_attributes() --")
	var vm := _new_vm()
	vm.request_roll_attributes()

	_assert(vm.state == CharacterCreationViewModel.CreationState.ASSIGNING, "Estado pasa a ASSIGNING tras tirar")
	_assert(vm.physical_pool.size() == 3, "physical_pool tiene 3 valores (STR/DEX/CHA)")
	_assert(vm.resilient_pool.size() == 3, "resilient_pool tiene 3 valores (CON/INT/WIS)")

	var physical_ok := true
	for value in vm.physical_pool:
		if value < 3 or value > 18:
			physical_ok = false
	_assert(physical_ok, "Valores 3D6 en rango [3, 18]")

	var resilient_ok := true
	for value in vm.resilient_pool:
		if value < 8 or value > 18:
			resilient_ok = false
	_assert(resilient_ok, "Valores 2D6+6 en rango [8, 18] (suelo garantizado)")

	vm.queue_free()


func _test_asignacion_completa() -> void:
	print("\n-- Asignación completa de los 6 atributos --")
	var vm := _new_vm()
	vm.request_roll_attributes()

	for attr_id in CharacterCreationViewModel.PHYSICAL_ATTRIBUTES:
		vm.request_assign_value(vm.physical_pool[0], attr_id)
	for attr_id in CharacterCreationViewModel.RESILIENT_ATTRIBUTES:
		vm.request_assign_value(vm.resilient_pool[0], attr_id)

	_assert(vm.is_fully_assigned(), "is_fully_assigned() true tras asignar los 6")
	_assert(vm.physical_pool.is_empty(), "physical_pool vacío tras asignar")
	_assert(vm.resilient_pool.is_empty(), "resilient_pool vacío tras asignar")
	_assert(vm.assigned_attributes.size() == 6, "assigned_attributes tiene 6 entradas")

	vm.queue_free()


func _test_desasignar_devuelve_valor_al_pool() -> void:
	print("\n-- request_unassign_attribute() --")
	var vm := _new_vm()
	vm.request_roll_attributes()

	var value: int = vm.physical_pool[0]
	vm.request_assign_value(value, "strength")
	_assert(vm.assigned_attributes.has("strength"), "strength asignado")

	vm.request_unassign_attribute("strength")
	_assert(not vm.assigned_attributes.has("strength"), "strength desasignado")
	_assert(vm.physical_pool.has(value), "Valor vuelve al pool tras desasignar")

	vm.queue_free()


func _test_continuar_incompleto_falla() -> void:
	print("\n-- request_continue_to_naming() con asignación incompleta --")
	var vm := _new_vm()
	vm.request_roll_attributes()
	vm.request_assign_value(vm.physical_pool[0], "strength")  # solo 1 de 6

	var error_recibido: Array[bool] = [false]  # Array = tipo por referencia, capturable en lambda
	vm.changed.connect(func(reason): 
		if reason == "error_incomplete_assignment":
			error_recibido[0] = true
	)
	vm.request_continue_to_naming()

	_assert(error_recibido[0], "Emite error_incomplete_assignment")
	_assert(vm.state == CharacterCreationViewModel.CreationState.ASSIGNING, "Estado se mantiene en ASSIGNING")

	vm.queue_free()


func _test_nombre_vacio_falla() -> void:
	print("\n-- request_continue_to_summary() con nombre vacío --")
	var vm := _new_vm()
	_fill_all_attributes(vm)
	vm.request_continue_to_naming()
	vm.set_character_name("   ")  # solo espacios

	var error_recibido: Array[bool] = [false]  # Array = tipo por referencia, capturable en lambda
	vm.changed.connect(func(reason):
		if reason == "error_empty_name":
			error_recibido[0] = true
	)
	vm.request_continue_to_summary()

	_assert(error_recibido[0], "Emite error_empty_name con nombre en blanco")
	_assert(vm.state == CharacterCreationViewModel.CreationState.NAMING, "Estado se mantiene en NAMING")

	vm.queue_free()


func _test_nombre_valido_pasa_a_summary() -> void:
	print("\n-- request_continue_to_summary() con nombre válido --")
	var vm := _new_vm()
	_fill_all_attributes(vm)
	vm.request_continue_to_naming()
	vm.set_character_name("Aldric")
	vm.request_continue_to_summary()

	_assert(vm.state == CharacterCreationViewModel.CreationState.SUMMARY, "Estado pasa a SUMMARY")
	_assert(vm.character_name == "Aldric", "character_name guardado correctamente")

	vm.queue_free()


func _test_reroll_una_sola_vez() -> void:
	print("\n-- request_reroll() límite de 1 uso --")
	var vm := _new_vm()
	vm.request_roll_attributes()

	vm.request_reroll()
	_assert(vm.reroll_used, "reroll_used pasa a true tras el primer reroll")
	_assert(vm.assigned_attributes.is_empty(), "assigned_attributes se limpia tras reroll")

	# Segundo intento — no debe volver a tirar (comprobamos que no crashea y sigue bloqueado)
	var pool_tras_primer_reroll: Array[int] = vm.physical_pool.duplicate()
	vm.request_reroll()
	_assert(vm.physical_pool == pool_tras_primer_reroll, "Segundo reroll no tiene efecto (ya usado)")

	vm.queue_free()


## Descomentar en test_ready() cuando exista player_new.tres.
## Requiere que los autoloads Characters/Skills/Resources/Equipment/Inventory/GameLoop
## estén presentes (correr esto como escena principal o con autoloads cargados).
func _test_confirmar_personaje() -> void:
	print("\n-- request_confirm_character() [requiere player_new.tres + autoloads] --")
	var vm := _new_vm()
	_fill_all_attributes(vm)
	vm.request_continue_to_naming()
	vm.set_character_name("TestHero")
	vm.request_continue_to_summary()

	vm.request_confirm_character()
	await get_tree().create_timer(0.2).timeout  # dar tiempo al await interno del VM

	var chars: Node = get_node_or_null("/root/Characters")
	_assert(chars != null and chars.has_entity("player"), "Entidad 'player' registrada en CharacterSystem")

	var resources: Node = get_node_or_null("/root/Resources")
	if resources:
		print("  Recursos del player tras confirmar:")
		resources.print_entity_resources("player")

		var health: float = resources.get_resource_amount("player", "health")
		var health_max: float = resources.get_resource_state("player", "health").max_effective
		_assert(is_equal_approx(health, health_max), "health curada a su máximo tras crear personaje")

		var stamina: float = resources.get_resource_amount("player", "stamina")
		var stamina_max: float = resources.get_resource_state("player", "stamina").max_effective
		_assert(is_equal_approx(stamina, stamina_max), "stamina curada a su máximo tras crear personaje")

		var gold: float = resources.get_resource_amount("player", "gold")
		_assert(is_equal_approx(gold, 50.0), "Oro inicial = 50")

	var skills_node: Node = get_node_or_null("/root/Skills")
	if skills_node:
		var entity_skills: Dictionary = skills_node._entity_skills.get("player", {})
		_assert(entity_skills.size() == 3, "Solo las 3 skills del kit fijo registradas (no las 17 del catálogo)")

	vm.queue_free()


func _fill_all_attributes(vm: CharacterCreationViewModel) -> void:
	vm.request_roll_attributes()
	for attr_id in CharacterCreationViewModel.PHYSICAL_ATTRIBUTES:
		vm.request_assign_value(vm.physical_pool[0], attr_id)
	for attr_id in CharacterCreationViewModel.RESILIENT_ATTRIBUTES:
		vm.request_assign_value(vm.resilient_pool[0], attr_id)
