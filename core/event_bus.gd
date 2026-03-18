extends Node

## EventBus - Sistema centralizado de eventos del juego
## Singleton: /root/EventBus
## Permite comunicación desacoplada entre sistemas

# ============================================
# EVENTOS DEL ITEM SYSTEM
# ============================================

## Inventario
signal item_added(entity_id: String, item_id: String, quantity: int)
signal item_removed(entity_id: String, item_id: String, quantity: int)
signal inventory_full(entity_id: String)

## Uso de ítems
signal item_use_requested(entity_id: String, item_id: String)
signal item_use_success(entity_id: String, item_id: String)
signal item_use_failed(entity_id: String, item_id: String, reason: String)

## Equipamiento (futuro)
signal item_equipped(entity_id: String, item_id: String, slot: String)
signal item_unequipped(entity_id: String, item_id: String, slot: String)

# ==============================================
# EVENTOS DE CHARACTER SYSTEM
# ==============================================

## Registro de personajes
signal character_registered(entity_id: String, definition_id: String)
signal character_unregistered(entity_id: String)

## Cambios de atributos base
signal base_attribute_changed(entity_id: String, attr_id: String, old_value: float, new_value: float)

## Modificadores
signal character_modifier_added(entity_id: String, modifier: ModifierDefinition)
signal character_modifier_removed(entity_id: String, modifier: ModifierDefinition)

## Estados temporales (buffs/debuffs)
signal temporary_state_added(entity_id: String, state_id: String, duration: float)
signal temporary_state_removed(entity_id: String, state_id: String)
signal temporary_state_expired(entity_id: String, state_id: String)

## Recalculo de atributos derivados
signal derived_attributes_recalculation_requested(entity_id: String)
signal derived_attributes_recalculated(entity_id: String)

## Level-up / Progression
signal character_level_up(entity_id: String, new_level: int)
signal character_attribute_increased(entity_id: String, attr_id: String, amount: float)

# ==============================================
# EVENTOS DE COMBATE DE PERSONAJES
# ==============================================

## Emitido cuando un personaje recibe daño
signal character_damaged(character_id: String, damage: float, current_hp: float)

## Emitido cuando un personaje muere
signal character_died(character_id: String)

## Emitido cuando se aplica un buff
signal buff_applied(character_id: String, buff_type: String, duration: float)

## Emitido cuando expira un buff
signal buff_expired(character_id: String, buff_type: String)

# ==============================================
# EVENTOS DE ECONOMÍA
# ==============================================

## Emitido cuando cambia el oro de una entidad
signal gold_changed(entity_id: String, old_amount: int, new_amount: int)

## Emitido cuando se completa una transacción económica
signal transaction_completed(transaction_type: String, amount: int, entity_id: String)

# ==============================================
# EVENTOS DE TIENDA
# ==============================================

## Solicitud de apertura de tienda
signal shop_open_requested(shop_id: String, entity_id: String)

## Tienda abierta con snapshot inicial
signal shop_opened(shop_id: String, snapshot: Dictionary)

## Solicitud de cierre de tienda
signal shop_close_requested(shop_id: String)

## Tienda cerrada
signal shop_closed(shop_id: String)

## Solicitud de compra (Tienda → Jugador)
signal shop_buy_requested(shop_id: String, item_id: String, quantity: int)

## Solicitud de venta (Jugador → Tienda)
signal shop_sell_requested(shop_id: String, item_instance_id: String, quantity: int)

## Transacción exitosa
signal shop_trade_success(
	trade_type: String,      # "buy" | "sell"
	shop_id: String,
	item_id: String,
	quantity: int,
	new_snapshot: Dictionary
)

## Transacción fallida
signal shop_trade_failed(
	shop_id: String,
	reason_code: String,     # "NO_MONEY", "NO_STOCK", etc.
	context: String
)

## Snapshot actualizado (sin transacción)
signal shop_snapshot_updated(shop_id: String, snapshot: Dictionary)

# ==============================================
# EVENTOS DE NARRATIVE SYSTEM
# ==============================================

## Emitido cuando se activa un flag narrativo
signal narrative_flag_set(flag_id: String)

## Emitido cuando se desactiva un flag narrativo
signal narrative_flag_cleared(flag_id: String)

## Emitido cuando cambia una variable narrativa
signal narrative_variable_changed(var_id: String, value: Variant)

## Emitido cuando se completa un evento narrativo
signal narrative_event_triggered(event_id: String)

## Emitido cuando el estado narrativo completo cambia (útil para UI)
signal narrative_state_changed()

# ==============================================
# EVENTOS DE DIALOGUE SYSTEM
# ==============================================

## Emitido cuando inicia un diálogo
signal dialogue_started(dialogue_id: String)

## Emitido cuando se muestra un nodo de diálogo
signal dialogue_node_shown(node_id: String, speaker_id: String, text_key: String, portrait_id: String)

## Emitido cuando el jugador selecciona una opción
signal dialogue_option_selected(node_id: String, option_id: String)

## Emitido cuando termina un diálogo
signal dialogue_ended(dialogue_id: String)

## Emitido cuando las opciones disponibles cambian
signal dialogue_options_updated(options: Array)

# ==============================================
# EVENTOS DE GAMELOOP
# ==============================================

## Emitido cuando cambia el estado global del juego
signal game_state_changed(new_state: int)  # GameLoopSystem.GameState

## Emitido junto a game_state_changed cuando hay contexto adicional
## Ej: {dialogue_id: "dlg_guard"} o {shop_id: "blacksmith_01"}
signal game_state_context(new_state: int, context: Dictionary)

# ==============================================
# EVENTOS DE EXPLORACIÓN
# ==============================================

## Jugador solicita interactuar con un objeto/NPC del mundo
## interaction_type: "dialogue" | "shop" | "combat" | "item_pickup"
## target_id: ID del objetivo (dialogue_id, shop_id, enemy_id, item_id)
signal interaction_requested(interaction_type: String, target_id: String)

## Emitido cuando el SceneOrchestrator confirma que la escena destino está lista
signal scene_transition_completed(new_state: int)

## Emitido cuando el diálogo fuerza entrada en modo tienda (desde resultado de diálogo)
signal dialogue_state_entered(dialogue_id: String)

## Emitido cuando cambia la fase del turno
signal turn_phase_changed(new_phase: int)  # GameLoopSystem.TurnPhase

## Emitido cuando inicia el turno del jugador
signal player_turn_started()

## Emitido cuando termina el turno del jugador
signal player_turn_ended()

## Emitido cuando inicia el turno de un enemigo
signal enemy_turn_started(enemy_id: String)

## Emitido cuando inicia una nueva ronda
signal round_started(round_number: int)

## Emitido cuando termina un turno
signal turn_ended()

## Emitido cuando termina una ronda
signal round_ended(round_number: int)

# ==============================================
# EVENTOS DE COMBATE
# ==============================================

## Emitido cuando inicia un combate
## esta definida en habilidades progresivas
signal combat_started(participants: Array)

## Emitido cuando termina un combate
## result: "victory" o "defeat"
## esta definida en habilidades progresivas
signal combat_ended(result: String)

## Emitido cuando el jugador solicita una acción
signal player_action_requested(action_data: Dictionary)

## Emitido cuando GameLoop ordena ejecutar una acción de combate
signal execute_combat_action(action_data: Dictionary)

## Emitido cuando una acción de combate se completa
signal combat_action_completed(result: Dictionary)

## Emitido cuando el jugador completa su acción
signal player_action_completed(result: Dictionary)

## Emitido cuando falla una acción de combate
signal combat_action_failed(actor_id: String, reason: String)

## Emitido cuando se ejecuta una acción (legacy compatibility)
signal combat_action_executed(actor_id: String, skill_id: String, target_id: String, result: Dictionary)

## Emitido cuando un enemigo es derrotado
signal enemy_defeated(enemy_id: String)

## Emitido cuando un loot bag aparece en el mundo tras victoria de combate.
## La escena de exploración escucha esto para instanciar el nodo visual.
## position: posición en el mundo donde estaba el enemigo derrotado
signal combat_loot_bag_spawned(enemy_id: String, instance_id: String, position: Vector2)

## Emitido cuando el jugador recoge completamente una bolsa de loot de combate
signal combat_loot_collected(entity_id: String, instance_id: String)

# ==============================================
# EVENTOS DE DEFENSA / HUIDA / ESQUIVA
# ==============================================

## Jugador solicita adoptar postura defensiva
signal defend_requested(entity_id: String)

## Jugador solicita intentar huir
signal flee_requested(entity_id: String)

## Defensa activada
signal defense_activated(entity_id: String)

## Defensa expiró al inicio del turno del jugador
signal defense_expired(entity_id: String)

## Daño interceptado por defensa (valores informativos para UI)
signal damage_absorbed(entity_id: String, stamina_consumed: int, hp_taken: int)

## Jugador intentó escapar (threshold calculado)
signal escape_attempted(entity_id: String, threshold: int)

## Escape exitoso
signal escape_succeeded(entity_id: String)

## Escape fallido por stamina insuficiente
signal escape_failed(entity_id: String, current_stamina: int, required_stamina: int)

## Ataque anulado por buff evasion
signal evasion_triggered(evader_id: String)

## Emitido cuando cambia el target actual
signal target_changed(new_target: String)

# ==============================================
# EVENTOS DE RECURSOS
# ==============================================

## Emitido cuando cambia un recurso (HP, Stamina, AP)
signal resource_changed(entity_id: String, resource_id: String, old_value: float, new_value: float)

## Emitido cuando un recurso llega a 0
signal resource_depleted(entity_id: String, resource_id: String)

## Emitido cuando un recurso se llena completamente
signal resource_maxed(entity_id: String, resource_id: String)

# ==============================================
# EVENTOS DE HABILIDADES
# ==============================================
# NOTA: SkillSystem emite skill_used y skill_failed directamente
# Estas señales son mirrors para observers externos

## Emitido cuando se usa una habilidad
signal skill_used(entity_id: String, skill_id: String)

## Emitido cuando falla una habilidad
signal skill_failed(entity_id: String, skill_id: String, reason: String)

## Emitido cuando una habilidad entra en cooldown
signal skill_cooldown_started(entity_id: String, skill_id: String, duration: float)

## Emitido cuando una habilidad sale de cooldown
signal skill_cooldown_ended(entity_id: String, skill_id: String)

# ==============================================
# EVENTOS DE CHECKPOINTS
# ==============================================

## Emitido cuando se alcanza un checkpoint
signal checkpoint_reached(checkpoint_id: String, state: Dictionary)

## Emitido cuando se aplica completamente un checkpoint
signal checkpoint_applied(checkpoint_id: String)

## Emitido cuando se consolidan vectores
signal values_consolidated(vectors: Dictionary)

# ==============================================
# EVENTOS DE PROGRESION DE HABILIDADES
# ==============================================
# Estos eventos son emitidos/consumidos por SkillProgressionService.
# NOTA: combat_started y combat_ended ya existen en el bloque EVENTOS DE COMBATE.
# Este bloque solo añade señales nuevas que no existian previamente.

## Emitido por SkillProgressionService cuando una tirada genera un tick de exito.
## La UI puede escucharlo para mostrar feedback visual.
signal skill_tick_generated(entity_id: String, skill_id: String, ticks_total: int)

## Emitido por SkillProgressionService cuando el pity system se activa.
## Indica que se forzo un exito automatico y los ticks se invalidaron.
signal skill_pity_triggered(entity_id: String, skill_id: String)

## Emitido por SkillProgressionService al intentar mejorar al fin del combate.
## Se emite independientemente de si la mejora tuvo exito o no.
signal skill_improvement_attempted(entity_id: String, skill_id: String, roll: int, threshold: int)

## Emitido por SkillProgressionService cuando una habilidad sube de valor.
## old_value y new_value son el success_rate antes y despues.
signal skill_improved(entity_id: String, skill_id: String, old_value: int, new_value: int)

## Emitido por SkillProgressionService cuando la tirada de mejora falla.
signal skill_improvement_failed(entity_id: String, skill_id: String, roll: int, threshold: int)

## Emitido cuando una skill se desbloquea para una entidad
signal skill_unlocked(entity_id: String, skill_id: String)

## Emitido por NarrativeEventDefinition cuando un efecto de juego solicita desbloquear una skill.
## SkillEventHandler es el único listener autorizado — no llamar unlock_skill() directamente.
signal skill_unlock_requested(entity_id: String, skill_id: String)

## Emitido por SkillSystem cuando unlock_skill() falla por prerequisites no cumplidos.
signal skill_unlock_failed(entity_id: String, skill_id: String, missing_prerequisites: Array)

## Emitido por NarrativeEventDefinition cuando un efecto de juego solicita una sesión de aprendizaje.
## SkillEventHandler construirá y ejecutará la LearningSession correspondiente.
signal learning_session_requested(entity_id: String, skill_id: String, source_level: int, source_type: String)

# ==============================================
# EVENTOS DE WORLD OBJECTS
# ==============================================

## Jugador solicita ver las interacciones disponibles de un objeto del mundo
signal world_object_interaction_requested(entity_id: String, instance_id: String)

## Jugador elige una interacción concreta del panel
signal world_object_action_chosen(entity_id: String, instance_id: String, interaction_id: String)

## WorldObjectSystem resuelve la interacción y emite el resultado
signal world_object_interaction_resolved(instance_id: String, interaction_id: String, outcome: String, effect_data: Dictionary)

## WorldObjectSystem no pudo ejecutar la interacción
signal world_object_interaction_failed(entity_id: String, instance_id: String, reason: String)

## Las flags activas de un objeto cambiaron (la UI refresca los botones disponibles)
signal world_object_state_changed(instance_id: String, active_flags: Array)

## WorldObjectBridge ha procesado el outcome y la UI puede mostrar el resultado
signal world_object_feedback_ready(instance_id: String, interaction_id: String, outcome: String, feedback_key: String, revealed_info_key: String)

# ==============================================
# CONFIGURACIÓN
# ==============================================

## ¿Activar logging de eventos?
@export var enable_event_logging: bool = true

## Filtro de eventos a loggear (vacío = todos)
@export var logged_event_filter: Array[String] = []


func _ready():
	print("[EventBus] Initialized - ItemSystem events ready")
	print("[EventBus] Available signals:")
	print("  - item_added")
	print("  - item_removed")
	print("  - item_use_requested")
	print("  - item_use_success")
	print("  - item_use_failed")
	print("  - narrative_flag_set")
	print("  - narrative_flag_cleared")
	print("  - narrative_variable_changed")
	print("  - narrative_event_triggered")
	print("  - dialogue_started")
	print("  - dialogue_node_shown")
	print("  - dialogue_option_selected")
	print("  - dialogue_ended")
	print("  - dialogue_options_updated")
	print("  - checkpoint_reached")
	print("  - checkpoint_applied")
	print("  - values_consolidated")
	print("  - character_damaged")
	print("  - character_died")
	print("  - buff_applied")
	print("  - buff_expired")
	print("  - game_state_changed")
	print("  - turn_phase_changed")
	print("  - player_turn_started")
	print("  - enemy_turn_started")
	print("  - round_started")
	print("  - combat_started")
	print("  - combat_ended")
	print("  - execute_combat_action")
	print("  - combat_action_completed")
	print("  - target_changed")
	
	_connect_debug_listeners()


# ==============================================
# SISTEMA DE LOGGING
# ==============================================

## Conecta listeners de debug si está habilitado
func _connect_debug_listeners():
	# Economy events
	gold_changed.connect(_on_gold_changed_debug)
	transaction_completed.connect(_on_transaction_completed_debug)
	
	# Shop events
	shop_open_requested.connect(_on_shop_open_requested_debug)
	shop_opened.connect(_on_shop_opened_debug)
	shop_close_requested.connect(_on_shop_close_requested_debug)
	shop_closed.connect(_on_shop_closed_debug)
	shop_buy_requested.connect(_on_shop_buy_requested_debug)
	shop_sell_requested.connect(_on_shop_sell_requested_debug)
	shop_trade_success.connect(_on_shop_trade_success_debug)
	shop_trade_failed.connect(_on_shop_trade_failed_debug)
	shop_snapshot_updated.connect(_on_shop_snapshot_updated_debug)
	
	# Narrative events
	narrative_flag_set.connect(_on_narrative_flag_set_debug)
	narrative_flag_cleared.connect(_on_narrative_flag_cleared_debug)
	narrative_variable_changed.connect(_on_narrative_variable_changed_debug)
	narrative_event_triggered.connect(_on_narrative_event_triggered_debug)
	narrative_state_changed.connect(_on_narrative_state_changed_debug)
	
	# Dialogue events
	dialogue_started.connect(_on_dialogue_started_debug)
	dialogue_node_shown.connect(_on_dialogue_node_shown_debug)
	dialogue_option_selected.connect(_on_dialogue_option_selected_debug)
	dialogue_ended.connect(_on_dialogue_ended_debug)
	dialogue_options_updated.connect(_on_dialogue_options_updated_debug)
	
	# Checkpoint events
	checkpoint_reached.connect(_on_checkpoint_reached_debug)
	checkpoint_applied.connect(_on_checkpoint_applied_debug)
	values_consolidated.connect(_on_values_consolidated_debug)
	
	# Skill unlock / learning events (Fase A/B)
	skill_unlock_requested.connect(_on_skill_unlock_requested_debug)
	skill_unlock_failed.connect(_on_skill_unlock_failed_debug)
	learning_session_requested.connect(_on_learning_session_requested_debug)


## Debug listeners (solo si enable_event_logging = true)
func _on_gold_changed_debug(entity_id: String, old_amount: int, new_amount: int):
	if _should_log("gold_changed"):
		print("[EventBus] gold_changed ← entity=%s, %d→%d" % [entity_id, old_amount, new_amount])


func _on_transaction_completed_debug(transaction_type: String, amount: int, entity_id: String):
	if _should_log("transaction_completed"):
		print("[EventBus] transaction_completed ← type=%s, amount=%d, entity=%s" % [transaction_type, amount, entity_id])


func _on_shop_open_requested_debug(shop_id: String, entity_id: String):
	if _should_log("shop_open_requested"):
		print("[EventBus] shop_open_requested ← shop=%s, entity=%s" % [shop_id, entity_id])


func _on_shop_opened_debug(shop_id: String, snapshot: Dictionary):
	if _should_log("shop_opened"):
		print("[EventBus] shop_opened ← shop=%s, budget=%s" % [shop_id, snapshot.get("budget", "N/A")])


func _on_shop_close_requested_debug(shop_id: String):
	if _should_log("shop_close_requested"):
		print("[EventBus] shop_close_requested ← shop=%s" % shop_id)


func _on_shop_closed_debug(shop_id: String):
	if _should_log("shop_closed"):
		print("[EventBus] shop_closed ← shop=%s" % shop_id)


func _on_shop_buy_requested_debug(shop_id: String, item_id: String, quantity: int):
	if _should_log("shop_buy_requested"):
		print("[EventBus] shop_buy_requested ← shop=%s, item=%s, qty=%d" % [shop_id, item_id, quantity])


func _on_shop_sell_requested_debug(shop_id: String, item_instance_id: String, quantity: int):
	if _should_log("shop_sell_requested"):
		print("[EventBus] shop_sell_requested ← shop=%s, item=%s, qty=%d" % [shop_id, item_instance_id, quantity])


func _on_shop_trade_success_debug(trade_type: String, shop_id: String, item_id: String, quantity: int, _new_snapshot: Dictionary):
	if _should_log("shop_trade_success"):
		print("[EventBus] shop_trade_success ← type=%s, shop=%s, item=%s, qty=%d" % [trade_type, shop_id, item_id, quantity])


func _on_shop_trade_failed_debug(shop_id: String, reason_code: String, context: String):
	if _should_log("shop_trade_failed"):
		print("[EventBus] shop_trade_failed ← shop=%s, reason=%s, context=%s" % [shop_id, reason_code, context])


func _on_shop_snapshot_updated_debug(shop_id: String, _snapshot: Dictionary):
	if _should_log("shop_snapshot_updated"):
		print("[EventBus] shop_snapshot_updated ← shop=%s" % shop_id)


func _on_narrative_flag_set_debug(flag_id: String):
	if _should_log("narrative_flag_set"):
		print("[EventBus] narrative_flag_set ← %s" % flag_id)


func _on_narrative_flag_cleared_debug(flag_id: String):
	if _should_log("narrative_flag_cleared"):
		print("[EventBus] narrative_flag_cleared ← %s" % flag_id)


func _on_narrative_variable_changed_debug(var_id: String, value: Variant):
	if _should_log("narrative_variable_changed"):
		print("[EventBus] narrative_variable_changed ← %s = %s" % [var_id, value])


func _on_narrative_event_triggered_debug(event_id: String):
	if _should_log("narrative_event_triggered"):
		print("[EventBus] narrative_event_triggered ← %s" % event_id)


func _on_narrative_state_changed_debug():
	if _should_log("narrative_state_changed"):
		print("[EventBus] narrative_state_changed")


func _on_dialogue_started_debug(dialogue_id: String):
	if _should_log("dialogue_started"):
		print("[EventBus] dialogue_started ← %s" % dialogue_id)


func _on_dialogue_node_shown_debug(node_id: String, speaker_id: String, text_key: String, portrait_id: String = ""):
	if _should_log("dialogue_node_shown"):
		print("[EventBus] dialogue_node_shown ← node=%s, speaker=%s, text=%s, portrait=%s" % [node_id, speaker_id, text_key, portrait_id])


func _on_dialogue_option_selected_debug(node_id: String, option_id: String):
	if _should_log("dialogue_option_selected"):
		print("[EventBus] dialogue_option_selected ← node=%s, option=%s" % [node_id, option_id])


func _on_dialogue_ended_debug(dialogue_id: String):
	if _should_log("dialogue_ended"):
		print("[EventBus] dialogue_ended ← %s" % dialogue_id)


func _on_dialogue_options_updated_debug(options: Array):
	if _should_log("dialogue_options_updated"):
		print("[EventBus] dialogue_options_updated ← %d options available" % options.size())

func _on_checkpoint_reached_debug(checkpoint_id: String, _state: Dictionary):
	if _should_log("checkpoint_reached"):
		print("[EventBus] checkpoint_reached ← %s" % checkpoint_id)


func _on_checkpoint_applied_debug(checkpoint_id: String):
	if _should_log("checkpoint_applied"):
		print("[EventBus] checkpoint_applied ← %s" % checkpoint_id)


func _on_values_consolidated_debug(vectors: Dictionary):
	if _should_log("values_consolidated"):
		print("[EventBus] values_consolidated ← %d vectors" % vectors.size())

## Verifica si un evento debe loggearse según el filtro
func _should_log(event_name: String) -> bool:
	if not enable_event_logging:
		return false
	
	if logged_event_filter.is_empty():
		return true
	
	return event_name in logged_event_filter


# ==============================================
# UTILIDADES
# ==============================================

## Obtiene lista de eventos actualmente conectados a un signal
func get_listeners_count(signal_name: String) -> int:
	if not has_signal(signal_name):
		return 0
	
	return get_signal_connection_list(signal_name).size()


## Debug: imprime todos los signals disponibles
func print_available_signals():
	print("\n[EventBus] Available signals:")
	for sig in get_signal_list():
		var name = sig["name"]
		var count = get_listeners_count(name)
		print("  - %s (%d listeners)" % [name, count])
	print("")


## Activa/desactiva logging
func set_logging_enabled(enabled: bool):
	enable_event_logging = enabled


## Establece filtro de eventos a loggear
func set_event_filter(filter: Array[String]):
	logged_event_filter = filter

# ==============================================
# DEBUG LISTENERS PARA CHARACTER SYSTEM
# ==============================================
# NOTA: Añadir estas conexiones en _connect_debug_listeners()

func _connect_character_debug_listeners():
	character_registered.connect(_on_character_registered_debug)
	character_unregistered.connect(_on_character_unregistered_debug)
	base_attribute_changed.connect(_on_base_attribute_changed_debug)
	character_modifier_added.connect(_on_character_modifier_added_debug)
	character_modifier_removed.connect(_on_character_modifier_removed_debug)
	temporary_state_added.connect(_on_temporary_state_added_debug)
	temporary_state_expired.connect(_on_temporary_state_expired_debug)
	derived_attributes_recalculated.connect(_on_derived_attributes_recalculated_debug)

func _on_character_registered_debug(entity_id: String, definition_id: String):
	if _should_log("character_registered"):
		print("[EventBus] character_registered ← entity=%s, def=%s" % [entity_id, definition_id])

func _on_character_unregistered_debug(entity_id: String):
	if _should_log("character_unregistered"):
		print("[EventBus] character_unregistered ← entity=%s" % entity_id)

func _on_base_attribute_changed_debug(entity_id: String, attr_id: String, old_value: float, new_value: float):
	if _should_log("base_attribute_changed"):
		print("[EventBus] base_attribute_changed ← %s.%s: %.1f→%.1f" % [entity_id, attr_id, old_value, new_value])

func _on_character_modifier_added_debug(entity_id: String, modifier: ModifierDefinition):
	if _should_log("character_modifier_added"):
		print("[EventBus] character_modifier_added ← %s: %s" % [entity_id, modifier])

func _on_character_modifier_removed_debug(entity_id: String, modifier: ModifierDefinition):
	if _should_log("character_modifier_removed"):
		print("[EventBus] character_modifier_removed ← %s: %s" % [entity_id, modifier])

func _on_temporary_state_added_debug(entity_id: String, state_id: String, duration: float):
	if _should_log("temporary_state_added"):
		print("[EventBus] temporary_state_added ← %s: %s (%.1fs)" % [entity_id, state_id, duration])

func _on_temporary_state_expired_debug(entity_id: String, state_id: String):
	if _should_log("temporary_state_expired"):
		print("[EventBus] temporary_state_expired ← %s: %s" % [entity_id, state_id])

func _on_derived_attributes_recalculated_debug(entity_id: String):
	if _should_log("derived_attributes_recalculated"):
		print("[EventBus] derived_attributes_recalculated ← %s" % entity_id)


# ==============================================
# DEBUG LISTENERS — SKILL UNLOCK / LEARNING (Fase A/B)
# ==============================================

func _on_skill_unlock_requested_debug(entity_id: String, skill_id: String):
	if _should_log("skill_unlock_requested"):
		print("[EventBus] skill_unlock_requested ← entity=%s, skill=%s" % [entity_id, skill_id])

func _on_skill_unlock_failed_debug(entity_id: String, skill_id: String, missing: Array):
	if _should_log("skill_unlock_failed"):
		print("[EventBus] skill_unlock_failed ← entity=%s, skill=%s, missing=%s" % [entity_id, skill_id, str(missing)])

func _on_learning_session_requested_debug(entity_id: String, skill_id: String, source_level: int, source_type: String):
	if _should_log("learning_session_requested"):
		print("[EventBus] learning_session_requested ← entity=%s, skill=%s, level=%d, type=%s" % [entity_id, skill_id, source_level, source_type])
