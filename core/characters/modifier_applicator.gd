class_name ModifierApplicator
extends Node

## ModifierApplicator - Orquestador de modificadores y atributos derivados
## Parte del CharacterSystem (Fase 4 del spike)
## Autoload: /root/ModifierApplicator
##
## Responsabilidades:
##   - Escuchar eventos de cambio (equipar items, buffs, level-up)
##   - Recalcular atributos derivados cuando sea necesario
##   - Actualizar ResourceSystem con máximos recalculados
##   - Gestionar expiración de estados temporales (buffs/debuffs)
##   - Emitir eventos de recalculo completado
##
## Flujo típico:
##   1. CharacterSystem emite base_attribute_changed o modifier_added
##   2. ModifierApplicator.recalculate_all(entity_id)
##   3. AttributeResolver calcula nuevos derivados (health_max, stamina_max, etc.)
##   4. ResourceSystem.set_max_effective() actualiza los máximos
##   5. derived_attributes_recalculated se emite para UI/otros sistemas
##
## Integración futura (post-spike):
##   - Conectar a EventBus.item_equipped / item_unequipped
##   - Conectar a eventos de status effects (poison, stun, etc.)


# ============================================
# SEÑALES
# ============================================

## Emitido tras recalcular TODOS los derivados de una entidad.
## Útil para que UI actualice tooltips, character sheets, etc.
signal derived_attributes_recalculated(entity_id: String)


# ============================================
# INICIALIZACIÓN
# ============================================

func _ready():
	# Conectar a eventos de CharacterSystem
	Characters.base_attribute_changed.connect(_on_base_attribute_changed)
	Characters.modifier_added.connect(_on_modifier_changed)
	Characters.modifier_removed.connect(_on_modifier_changed)
	
	# CRÍTICO: asegurar que _process siempre corre
	process_mode = Node.PROCESS_MODE_ALWAYS	
	
	# TODO (post-spike): conectar a ItemSystem
	# EventBus.item_equipped.connect(_on_item_equipped)
	# EventBus.item_unequipped.connect(_on_item_unequipped)
	
	print("[ModifierApplicator] Initialized")


# ============================================
# RECALCULO DE ATRIBUTOS DERIVADOS
# ============================================

## Recalcula TODOS los atributos derivados de una entidad.
## Llamado automáticamente cuando:
##   - Cambia un atributo base (level-up, curse, etc.)
##   - Se añade/remueve un modificador equipado
##   - Se añade/expira un estado temporal (buff/debuff)
##
## También puede llamarse manualmente desde otros sistemas si es necesario
## forzar un recalculo (ej: tras cargar save game).
func recalculate_all(entity_id: String) -> void:
	var state = Characters.get_character_state(entity_id)
	if not state:
		push_warning("[ModifierApplicator] Cannot recalculate for unknown entity: %s" % entity_id)
		return
	
	# Recalcular máximos de recursos (health_max, stamina_max)
	_recalculate_resource_maxes(entity_id)
	
	# Emitir evento para UI y otros sistemas
	derived_attributes_recalculated.emit(entity_id)
	
	print("[ModifierApplicator] Recalculated all for: %s" % entity_id)


## Recalcula los máximos efectivos de los recursos y actualiza ResourceSystem.
## Delega el cálculo a AttributeResolver, que aplica modificadores sobre
## las fórmulas base.
##
## Solo procesa recursos con máximo calculado (health, stamina).
## Recursos sin máximo (gold, focus) no se tocan.
func _recalculate_resource_maxes(entity_id: String) -> void:
	# Lista hardcoded en el spike — post-spike: cargar desde data
	var calculable_resources = ["health", "stamina"]
	
	for resource_id in calculable_resources:
		# Verificar que la entidad tenga este recurso registrado en ResourceSystem
		if not Resources.get_resource_state(entity_id, resource_id):
			continue
		
		# Calcular nuevo máximo
		var new_max = AttributeResolver.resolve_resource_max(entity_id, resource_id)
		
		# Actualizar en ResourceSystem
		Resources.set_max_effective(entity_id, resource_id, new_max)


# ============================================
# CALLBACKS DE EVENTOS
# ============================================

## Callback: cambió un atributo base (level-up, permanent curse, etc.)
func _on_base_attribute_changed(
	entity_id: String,
	attr_id: String,
	old_value: float,
	new_value: float
) -> void:
	print("[ModifierApplicator] Base attribute changed: %s.%s %.1f→%.1f" % [
		entity_id, attr_id, old_value, new_value
	])
	recalculate_all(entity_id)


## Callback: se añadió o removió un modificador equipado
func _on_modifier_changed(entity_id: String, modifier: ModifierDefinition) -> void:
	print("[ModifierApplicator] Modifier changed for: %s" % entity_id)
	recalculate_all(entity_id)


# ============================================
# APLICACIÓN DE ITEMS (integración con ItemSystem)
# ============================================

## Aplica los modificadores de un item usado (consumible).
## Los modificadores "on_use" que afectan recursos (resource.X)
## se aplican directamente al valor actual, NO al máximo.
##
## Ejemplo: poción de stamina con mod { target: "resource.stamina", op: "add", value: 50 }
##          → añade 50 stamina actual (el máximo no cambia)
##
## Los modificadores "equipped" no se procesan aquí, esos van a
## CharacterSystem.add_equipped_modifier() cuando se equipa el item.
func apply_item_modifiers(entity_id: String, item_def: ItemDefinition) -> void:
	var modifiers = item_def.get_modifiers_for_condition("on_use")
	
	for mod in modifiers:
		if mod.targets_resource():
			# Aplicar al recurso actual
			var resource_id = mod.get_resource_id()
			
			match mod.operation:
				"add":
					Resources.add_resource(entity_id, resource_id, mod.value)
					print("[ModifierApplicator] Applied +%.1f to %s.%s" % [
						mod.value, entity_id, resource_id
					])
				
				"override":
					Resources.set_resource(entity_id, resource_id, mod.value)
					print("[ModifierApplicator] Set %s.%s to %.1f" % [
						entity_id, resource_id, mod.value
					])
				
				"mul":
					# MUL sobre recurso actual: leer, multiplicar, escribir
					var current = Resources.get_resource_amount(entity_id, resource_id)
					var new_value = current * mod.value
					Resources.set_resource(entity_id, resource_id, new_value)
					print("[ModifierApplicator] Multiplied %s.%s by %.2f" % [
						entity_id, resource_id, mod.value
					])


# ============================================
# ESTADOS TEMPORALES (buffs/debuffs)
# ============================================

## Añade un estado temporal (buff/debuff) a una entidad.
## El estado se almacena en CharacterState.active_states y expirará
## automáticamente tras 'duration' segundos.
##
## Los modificadores del estado afectan a atributos derivados mientras
## el estado esté activo. AttributeResolver.resolve() los verá vía
## Characters.get_active_modifiers().
##
## Ejemplo: buff de vigor que aumenta health_max un 20% por 10 segundos.
func add_temporary_state(
	entity_id: String,
	state_id: String,
	modifiers: Array[ModifierDefinition],
	duration: float
) -> void:
	var state = Characters.get_character_state(entity_id)
	if not state:
		push_warning("[ModifierApplicator] Cannot add temp state to unknown entity: %s" % entity_id)
		return
	
	# Crear estructura de estado temporal
	var temp_state = {
		"id": state_id,
		"modifiers": modifiers,
		"duration": duration,
		"time_left": duration
	}
	
	# Añadir a CharacterState
	state.active_states.append(temp_state)
	
	# Recalcular porque los modificadores temporales ahora están activos
	recalculate_all(entity_id)
	
	print("[ModifierApplicator] Added temp state: %s on %s (%.1fs)" % [
		state_id, entity_id, duration
	])


# ============================================
# EXPIRACIÓN DE ESTADOS TEMPORALES
# ============================================

## Procesa estados temporales cada frame.
## Decrementa time_left y elimina los que llegaron a 0.
## Cuando un estado expira, recalcula derivados para reflejar
## la pérdida de los modificadores.
func _process(delta: float):
	# Iterar sobre todas las entidades registradas
	var entity_ids = Characters.get_registered_entities()
	
	for entity_id in entity_ids:
		var state = Characters.get_character_state(entity_id)
		if not state:
			continue
		
		# Si no hay estados temporales, skip
		if state.active_states.is_empty():
			continue
		
		# Recolectar índices de estados expirados
		var expired_indices: Array[int] = []
		
		for i in range(state.active_states.size()):
			var temp_state = state.active_states[i]
			temp_state["time_left"] -= delta
			
			if temp_state["time_left"] <= 0:
				expired_indices.append(i)
		
		# Eliminar en orden inverso para no desincronizar índices
		if not expired_indices.is_empty():
			expired_indices.reverse()
			
			for idx in expired_indices:
				var expired = state.active_states[idx]
				state.active_states.remove_at(idx)
				
				print("[ModifierApplicator] Expired state: %s on %s" % [
					expired.get("id", "?"), entity_id
				])
			
			# Recalcular una sola vez tras remover todos los expirados
			recalculate_all(entity_id)


# ============================================
# DEBUG
# ============================================

## Imprime todos los estados temporales activos de una entidad.
## Útil durante desarrollo para ver qué buffs/debuffs tiene un personaje.
func debug_print_active_states(entity_id: String) -> void:
	var state = Characters.get_character_state(entity_id)
	if not state:
		print("[ModifierApplicator] Entity not found: %s" % entity_id)
		return
	
	if state.active_states.is_empty():
		print("[ModifierApplicator] %s has no active temporary states" % entity_id)
		return
	
	print("\n[ModifierApplicator] Active states for %s:" % entity_id)
	for temp_state in state.active_states:
		print("  - %s: %.1fs left (%d modifiers)" % [
			temp_state.get("id", "?"),
			temp_state.get("time_left", 0),
			temp_state.get("modifiers", []).size()
		])
