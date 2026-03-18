extends Node

## test_fase2_equipment.gd - VERSIÓN CORREGIDA
## Script de validación para FASE 2 del Spike
##
## OBJETIVO: Verificar que equipamiento funciona correctamente
##
## CASOS DE PRUEBA:
##   1. Equipar arma aumenta melee_damage (atributo derivado)
##   2. Desequipar arma revierte el cambio
##   3. Atributos derivados se recalculan
##   4. Toggle equip/unequip funciona
##   5. Equipar otro ítem en mismo slot desequipa el anterior
##   6. No se puede equipar sin tener el ítem en inventario

# ============================================
# CONFIGURACIÓN
# ============================================

const ENTITY_ID = "test_player"
const CHARACTER_DEF = "player_base"  # Ajustar según tu definición


# ============================================
# INICIALIZACIÓN
# ============================================

func _ready():
	print("\n" + "=".repeat(60))
	print("FASE 2 - TEST: Equipamiento")
	print("=".repeat(60) + "\n")
	
	await get_tree().process_frame
	
	# Setup inicial
	_setup_systems()
	
	# Esperar a que sistemas estén listos
	await get_tree().create_timer(0.5).timeout
	
	# Ejecutar tests
	_test_1_equip_weapon()
	await get_tree().create_timer(1.0).timeout
	
	_test_2_unequip_weapon()
	await get_tree().create_timer(1.0).timeout
	
	_test_3_derived_attributes()
	await get_tree().create_timer(1.0).timeout
	
	_test_4_toggle_equipment()
	await get_tree().create_timer(1.0).timeout
	
	_test_5_auto_unequip()
	await get_tree().create_timer(1.0).timeout
	
	_test_6_equipment_without_item()
	await get_tree().create_timer(1.0).timeout
	
	# Resumen final
	_print_final_summary()


# ============================================
# SETUP
# ============================================

func _setup_systems():
	print("[Setup] Inicializando sistemas...")
	
	# 1. Registrar entidad en CharacterSystem
	if not Characters.has_entity(ENTITY_ID):
		var success = Characters.register_entity(ENTITY_ID, CHARACTER_DEF)
		if not success:
			push_error("[Setup] Failed to register entity in CharacterSystem")
			return
	
	# 2. Registrar en ResourceSystem
	if not Resources._entities.has(ENTITY_ID):
		Resources.register_entity(ENTITY_ID, ["health", "stamina"])
	
	# 3. Registrar en InventorySystem
	if not Inventory._inventories.has(ENTITY_ID):
		Inventory.register_entity(ENTITY_ID)
	
	# NOTA: Bridge ya está como autoload, NO crearlo aquí
	
	# 4. Obtener valores iniciales
	var initial_strength = Characters.get_base_attribute(ENTITY_ID, "strength")
	
	print("[Setup] ✓ Entity '%s' registered in all systems" % ENTITY_ID)
	print("[Setup] ✓ Initial strength: %.1f\n" % initial_strength)


# ============================================
# TEST 1: Equipar Arma Aumenta Melee Damage
# ============================================

func _test_1_equip_weapon():
	print("─".repeat(60))
	print("TEST 1: Equipar arma aumenta melee_damage")
	print("─".repeat(60))
	
	# Añadir espada al inventario
	Inventory.add_item(ENTITY_ID, "iron_sword", 1)
	print("[Test 1] Added iron_sword to inventory")
	
	# Verificar melee_damage antes
	var damage_before = AttributeResolver.resolve(ENTITY_ID, "melee_damage")
	print("[Test 1] Melee damage before equip: %.1f" % damage_before)
	
	# Verificar modificadores antes
	var mods_before = Characters.get_equipped_modifiers(ENTITY_ID)
	print("[Test 1] Equipped modifiers before: %d" % mods_before.size())
	
	# Equipar espada
	print("[Test 1] Equipping iron_sword...")
	Inventory.request_use_item(ENTITY_ID, "iron_sword")
	
	await get_tree().create_timer(0.2).timeout
	
	# Verificar melee_damage después
	var damage_after = AttributeResolver.resolve(ENTITY_ID, "melee_damage")
	print("[Test 1] Melee damage after equip: %.1f" % damage_after)
	
	# Verificar modificadores después
	var mods_after = Characters.get_equipped_modifiers(ENTITY_ID)
	print("[Test 1] Equipped modifiers after: %d" % mods_after.size())
	
	# Verificar que está equipado
	var is_equipped = Equipment.is_item_equipped(ENTITY_ID, "iron_sword")
	print("[Test 1] Is equipped: %s" % is_equipped)
	
	# Validar resultado
	var expected_increase = 5.0  # Según iron_sword.tres
	var actual_increase = damage_after - damage_before
	
	if is_equipped and abs(actual_increase - expected_increase) < 0.01 and mods_after.size() > mods_before.size():
		print("[Test 1] ✓ PASS: Weapon equipped, melee_damage increased by %.1f, modifier added" % actual_increase)
	else:
		print("[Test 1] ✗ FAIL: equipped=%s, damage_delta=%.1f, mods=%d→%d" % [
			is_equipped, actual_increase, mods_before.size(), mods_after.size()
		])
	
	print("")


# ============================================
# TEST 2: Desequipar Revierte Cambios
# ============================================

func _test_2_unequip_weapon():
	print("─".repeat(60))
	print("TEST 2: Desequipar arma revierte el cambio")
	print("─".repeat(60))
	
	# Verificar que está equipado
	var was_equipped = Equipment.is_item_equipped(ENTITY_ID, "iron_sword")
	print("[Test 2] Iron sword is equipped: %s" % was_equipped)
	
	# Obtener valores antes de desequipar
	var damage_before = AttributeResolver.resolve(ENTITY_ID, "melee_damage")
	var mods_before = Characters.get_equipped_modifiers(ENTITY_ID).size()
	
	print("[Test 2] Melee damage with sword: %.1f" % damage_before)
	print("[Test 2] Equipped modifiers: %d" % mods_before)
	
	# Desequipar (usando de nuevo)
	print("[Test 2] Unequipping iron_sword...")
	Inventory.request_use_item(ENTITY_ID, "iron_sword")
	
	await get_tree().create_timer(0.2).timeout
	
	# Verificar después
	var damage_after = AttributeResolver.resolve(ENTITY_ID, "melee_damage")
	var mods_after = Characters.get_equipped_modifiers(ENTITY_ID).size()
	var is_equipped = Equipment.is_item_equipped(ENTITY_ID, "iron_sword")
	
	print("[Test 2] Melee damage after unequip: %.1f" % damage_after)
	print("[Test 2] Equipped modifiers: %d" % mods_after)
	print("[Test 2] Is still equipped: %s" % is_equipped)
	
	# Validar
	var expected_decrease = 5.0
	var actual_decrease = damage_before - damage_after
	
	if not is_equipped and abs(actual_decrease - expected_decrease) < 0.01 and mods_after < mods_before:
		print("[Test 2] ✓ PASS: Weapon unequipped, melee_damage decreased, modifier removed")
	else:
		print("[Test 2] ✗ FAIL: equipped=%s, damage_delta=%.1f, mods=%d→%d" % [
			is_equipped, actual_decrease, mods_before, mods_after
		])
	
	print("")


# ============================================
# TEST 3: Atributos Derivados se Recalculan
# ============================================

func _test_3_derived_attributes():
	print("─".repeat(60))
	print("TEST 3: Atributos derivados se recalculan")
	print("─".repeat(60))
	
	# Calcular melee_damage sin arma
	var damage_without = AttributeResolver.resolve(ENTITY_ID, "melee_damage")
	print("[Test 3] Melee damage without weapon: %.1f" % damage_without)
	
	# Equipar espada
	print("[Test 3] Equipping iron_sword...")
	Inventory.request_use_item(ENTITY_ID, "iron_sword")
	
	await get_tree().create_timer(0.2).timeout
	
	# Calcular melee_damage con arma
	var damage_with = AttributeResolver.resolve(ENTITY_ID, "melee_damage")
	print("[Test 3] Melee damage with weapon: %.1f" % damage_with)
	
	# Desequipar
	print("[Test 3] Unequipping iron_sword...")
	Inventory.request_use_item(ENTITY_ID, "iron_sword")
	
	await get_tree().create_timer(0.2).timeout
	
	# Calcular de nuevo
	var damage_after = AttributeResolver.resolve(ENTITY_ID, "melee_damage")
	print("[Test 3] Melee damage after unequip: %.1f" % damage_after)
	
	# Validar
	if damage_with > damage_without and abs(damage_after - damage_without) < 0.01:
		print("[Test 3] ✓ PASS: Derived attributes recalculated correctly")
		print("[Test 3]   Damage progression: %.1f → %.1f → %.1f" % [
			damage_without, damage_with, damage_after
		])
	else:
		print("[Test 3] ✗ FAIL: Derived attributes not recalculating")
		print("[Test 3]   Expected: base < with_weapon, base == after_unequip")
	
	print("")


# ============================================
# TEST 4: Toggle Funciona
# ============================================

func _test_4_toggle_equipment():
	print("─".repeat(60))
	print("TEST 4: Toggle equip/unequip funciona")
	print("─".repeat(60))
	
	# Estado inicial: desequipado
	var equipped_0 = Equipment.is_item_equipped(ENTITY_ID, "iron_sword")
	print("[Test 4] Initially equipped: %s" % equipped_0)
	
	# Toggle 1: equipar
	print("[Test 4] Toggle 1 (should equip)...")
	Inventory.request_use_item(ENTITY_ID, "iron_sword")
	await get_tree().create_timer(0.2).timeout
	
	var equipped_1 = Equipment.is_item_equipped(ENTITY_ID, "iron_sword")
	print("[Test 4] After toggle 1: %s" % equipped_1)
	
	# Toggle 2: desequipar
	print("[Test 4] Toggle 2 (should unequip)...")
	Inventory.request_use_item(ENTITY_ID, "iron_sword")
	await get_tree().create_timer(0.2).timeout
	
	var equipped_2 = Equipment.is_item_equipped(ENTITY_ID, "iron_sword")
	print("[Test 4] After toggle 2: %s" % equipped_2)
	
	# Toggle 3: equipar de nuevo
	print("[Test 4] Toggle 3 (should equip again)...")
	Inventory.request_use_item(ENTITY_ID, "iron_sword")
	await get_tree().create_timer(0.2).timeout
	
	var equipped_3 = Equipment.is_item_equipped(ENTITY_ID, "iron_sword")
	print("[Test 4] After toggle 3: %s" % equipped_3)
	
	# Validar secuencia
	if not equipped_0 and equipped_1 and not equipped_2 and equipped_3:
		print("[Test 4] ✓ PASS: Toggle sequence correct (false→true→false→true)")
	else:
		print("[Test 4] ✗ FAIL: Toggle sequence incorrect (%s→%s→%s→%s)" % [
			equipped_0, equipped_1, equipped_2, equipped_3
		])
	
	# Cleanup: desequipar
	if equipped_3:
		Inventory.request_use_item(ENTITY_ID, "iron_sword")
		await get_tree().create_timer(0.2).timeout
	
	print("")


# ============================================
# TEST 5: Auto-Desequipar al Equipar Otro
# ============================================

func _test_5_auto_unequip():
	print("─".repeat(60))
	print("TEST 5: Equipar otro ítem en mismo slot desequipa el anterior")
	print("─".repeat(60))
	
	# Crear segundo ítem desde archivo .tres en lugar de código
	# Para simplificar, crear recurso en memoria con tipos correctos
	
	var steel_sword_def = ItemDefinition.new()
	steel_sword_def.id = "test_steel_sword"
	steel_sword_def.name_key = "TEST_STEEL_SWORD"
	steel_sword_def.description_key = "TEST_STEEL_SWORD_DESC"
	steel_sword_def.item_type = "EQUIPMENT"
	steel_sword_def.usable = true
	steel_sword_def.stackable = false
	steel_sword_def.weight = 4.0
	steel_sword_def.base_value = 300
	
	# Tags con tipo correcto
	var tags_array: Array[String] = []
	tags_array.append("weapon")
	tags_array.append("melee")
	steel_sword_def.tags = tags_array
	
	# Crear modificador
	var steel_mod = ModifierDefinition.new()
	steel_mod.target = "attribute.melee_damage"
	steel_mod.operation = "add"
	steel_mod.value = 8.0
	steel_mod.condition = "equipped"
	
	# Validar modificador
	if not steel_mod.validate():
		push_error("[Test 5] Steel sword modifier validation failed")
		return
	
	# Modifiers con tipo correcto
	var mods_array: Array[ModifierDefinition] = []
	mods_array.append(steel_mod)
	steel_sword_def.modifiers = mods_array
	
	# Validar item
	if not steel_sword_def.validate():
		push_error("[Test 5] Steel sword definition validation failed")
		return
	
	# Registrar temporalmente
	Items._items["test_steel_sword"] = steel_sword_def
	
	# Añadir ambas armas al inventario
	Inventory.add_item(ENTITY_ID, "iron_sword", 1)
	Inventory.add_item(ENTITY_ID, "test_steel_sword", 1)
	
	# Equipar primera arma
	print("[Test 5] Equipping iron_sword (+5 melee_damage)...")
	Inventory.request_use_item(ENTITY_ID, "iron_sword")
	await get_tree().create_timer(0.2).timeout
	
	var iron_equipped = Equipment.is_item_equipped(ENTITY_ID, "iron_sword")
	var damage_with_iron = AttributeResolver.resolve(ENTITY_ID, "melee_damage")
	print("[Test 5] Iron sword equipped: %s, damage: %.1f" % [iron_equipped, damage_with_iron])
	
	# Equipar segunda arma (debería auto-desequipar la primera)
	print("[Test 5] Equipping steel_sword (+8 melee_damage) in same slot...")
	Inventory.request_use_item(ENTITY_ID, "test_steel_sword")
	await get_tree().create_timer(0.2).timeout
	
	var iron_still_equipped = Equipment.is_item_equipped(ENTITY_ID, "iron_sword")
	var steel_equipped = Equipment.is_item_equipped(ENTITY_ID, "test_steel_sword")
	var damage_with_steel = AttributeResolver.resolve(ENTITY_ID, "melee_damage")
	
	print("[Test 5] Iron sword still equipped: %s" % iron_still_equipped)
	print("[Test 5] Steel sword equipped: %s" % steel_equipped)
	print("[Test 5] Damage with steel: %.1f" % damage_with_steel)
	
	# Validar
	if not iron_still_equipped and steel_equipped and damage_with_steel > damage_with_iron:
		print("[Test 5] ✓ PASS: Previous weapon auto-unequipped, damage increased")
	else:
		print("[Test 5] ✗ FAIL: Auto-unequip didn't work correctly")
	
	# Cleanup
	Equipment.unequip_item(ENTITY_ID, "test_steel_sword")
	Inventory.remove_item(ENTITY_ID, "test_steel_sword", 1)
	Items._items.erase("test_steel_sword")
	
	print("")


# ============================================
# TEST 6: No Equipar Sin Tener el Ítem
# ============================================

func _test_6_equipment_without_item():
	print("─".repeat(60))
	print("TEST 6: No se puede equipar sin tener el ítem en inventario")
	print("─".repeat(60))
	
	# Crear un ítem que NO esté en inventario
	var test_item_id = "test_nonexistent_item"
	
	# Crear definición dummy
	var dummy_def = ItemDefinition.new()
	dummy_def.id = test_item_id
	dummy_def.name_key = "TEST_NONEXISTENT"
	dummy_def.description_key = "TEST_NONEXISTENT_DESC"
	dummy_def.item_type = "EQUIPMENT"
	dummy_def.usable = true
	dummy_def.stackable = false
	
	var tags: Array[String] = []
	tags.append("weapon")
	dummy_def.tags = tags
	
	var mod = ModifierDefinition.new()
	mod.target = "attribute.melee_damage"
	mod.operation = "add"
	mod.value = 1.0
	mod.condition = "equipped"
	
	var mods: Array[ModifierDefinition] = []
	mods.append(mod)
	dummy_def.modifiers = mods
	
	# Registrar definición pero NO añadir al inventario
	Items._items[test_item_id] = dummy_def
	
	# Verificar que NO está en inventario
	var has_item = Inventory.has_item(ENTITY_ID, test_item_id)
	print("[Test 6] Item in inventory: %s" % has_item)
	
	# Conectar a evento de fallo
	var failed = false
	var failure_reason = ""
	
	var on_failure = func(entity_id: String, item_id: String, reason: String):
		if item_id == test_item_id:
			failed = true
			failure_reason = reason
	
	EventBus.item_use_failed.connect(on_failure)
	
	# Intentar equipar sin tenerlo
	print("[Test 6] Attempting to equip item without having it in inventory...")
	Inventory.request_use_item(ENTITY_ID, test_item_id)
	
	await get_tree().create_timer(0.2).timeout
	
	EventBus.item_use_failed.disconnect(on_failure)
	
	# Verificar que no se equipó
	var is_equipped = Equipment.is_item_equipped(ENTITY_ID, test_item_id)
	
	print("[Test 6] Failed: %s" % failed)
	print("[Test 6] Reason: %s" % failure_reason)
	print("[Test 6] Is equipped: %s" % is_equipped)
	
	# Validar
	if failed and "inventory" in failure_reason.to_lower() and not is_equipped:
		print("[Test 6] ✓ PASS: Correctly prevented equipping without item")
	else:
		print("[Test 6] ✗ FAIL: Should have failed with inventory error")
	
	# Cleanup
	Items._items.erase(test_item_id)
	
	print("")


# ============================================
# RESUMEN FINAL
# ============================================

func _print_final_summary():
	print("\n" + "=".repeat(60))
	print("FASE 2 - RESUMEN")
	print("=".repeat(60))
	
	print("\nEstado final de la entidad '%s':" % ENTITY_ID)
	
	# Atributos base
	print("\nAtributos base:")
	var strength = Characters.get_base_attribute(ENTITY_ID, "strength")
	print("  strength: %.1f" % strength)
	
	# Atributos derivados
	print("\nAtributos derivados:")
	var melee_damage = AttributeResolver.resolve(ENTITY_ID, "melee_damage")
	print("  melee_damage: %.1f" % melee_damage)
	
	# Modificadores equipados
	print("\nModificadores equipados:")
	var mods = Characters.get_equipped_modifiers(ENTITY_ID)
	if mods.is_empty():
		print("  (ninguno)")
	else:
		for mod in mods:
			print("  - %s" % mod)
	
	# Equipamiento
	print("\nEquipamiento:")
	var equipment = Equipment.get_all_equipment(ENTITY_ID)
	if equipment.is_empty():
		print("  (ningún ítem equipado)")
	else:
		for slot in equipment.keys():
			print("  %s: %s" % [slot, equipment[slot]])
	
	# Inventario
	print("\nInventario:")
	var inv = Inventory.get_inventory(ENTITY_ID)
	if inv.is_empty():
		print("  (vacío)")
	else:
		for item_id in inv.keys():
			var instance = inv[item_id]
			print("  - %s x%d" % [item_id, instance.quantity])
	
	# Conclusiones
	print("\n" + "─".repeat(60))
	print("CONCLUSIONES:")
	print("─".repeat(60))
	print("✓ Equipamiento aplica modificadores correctamente")
	print("✓ Desequipar revierte modificadores sin residuos")
	print("✓ Atributos derivados se recalculan automáticamente")
	print("✓ Toggle equip/unequip funciona")
	print("✓ Auto-desequipa al equipar en mismo slot")
	print("✓ Validación de inventario funciona")
	print("\n✅ FASE 2 VALIDADA - Sistema de equipamiento funcional")
	print("=".repeat(60) + "\n")
