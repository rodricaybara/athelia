extends Node

## EventBus - Sistema centralizado de eventos del juego
## Singleton: /root/EventBus
## Permite comunicación desacoplada entre sistemas

# ============================================
# EVENTOS DEL ITEM SYSTEM
# ============================================

signal item_added(entity_id: String, item_id: String, quantity: int)
signal item_removed(entity_id: String, item_id: String, quantity: int)
signal inventory_full(entity_id: String)

signal item_use_requested(entity_id: String, item_id: String)
signal item_use_success(entity_id: String, item_id: String)
signal item_use_failed(entity_id: String, item_id: String, reason: String)

signal item_equipped(entity_id: String, item_id: String, slot: String)
signal item_unequipped(entity_id: String, item_id: String, slot: String)

# ==============================================
# EVENTOS DE CHARACTER SYSTEM
# ==============================================

signal character_registered(entity_id: String, definition_id: String)
signal character_unregistered(entity_id: String)

signal base_attribute_changed(entity_id: String, attr_id: String, old_value: float, new_value: float)

signal character_modifier_added(entity_id: String, modifier: ModifierDefinition)
signal character_modifier_removed(entity_id: String, modifier: ModifierDefinition)

signal temporary_state_added(entity_id: String, state_id: String, duration: float)
signal temporary_state_removed(entity_id: String, state_id: String)
signal temporary_state_expired(entity_id: String, state_id: String)

signal derived_attributes_recalculation_requested(entity_id: String)
signal derived_attributes_recalculated(entity_id: String)

signal character_level_up(entity_id: String, new_level: int)
signal character_attribute_increased(entity_id: String, attr_id: String, amount: float)

# ==============================================
# EVENTOS DE COMBATE DE PERSONAJES
# ==============================================

signal character_damaged(character_id: String, damage: float, current_hp: float)
signal character_died(character_id: String)
signal buff_applied(character_id: String, buff_type: String, duration: float)
signal buff_expired(character_id: String, buff_type: String)
signal player_incapacitated()
signal player_rescued_by_companions()
# ==============================================
# EVENTOS DE ECONOMÍA
# ==============================================

signal gold_changed(entity_id: String, old_amount: int, new_amount: int)
signal transaction_completed(transaction_type: String, amount: int, entity_id: String)

# ==============================================
# EVENTOS DE TIENDA
# ==============================================

signal shop_open_requested(shop_id: String, entity_id: String)
signal shop_opened(shop_id: String, snapshot: Dictionary)
signal shop_close_requested(shop_id: String)
signal shop_closed(shop_id: String)
signal shop_buy_requested(shop_id: String, item_id: String, quantity: int)
signal shop_sell_requested(shop_id: String, item_instance_id: String, quantity: int)

signal shop_trade_success(
	trade_type: String,
	shop_id: String,
	item_id: String,
	quantity: int,
	new_snapshot: Dictionary
)

signal shop_trade_failed(
	shop_id: String,
	reason_code: String,
	context: String
)

signal shop_snapshot_updated(shop_id: String, snapshot: Dictionary)

# ==============================================
# EVENTOS DE NARRATIVE SYSTEM
# ==============================================

signal narrative_flag_set(flag_id: String)
signal narrative_flag_cleared(flag_id: String)
signal narrative_variable_changed(var_id: String, value: Variant)
signal narrative_event_triggered(event_id: String)
signal narrative_state_changed()

# ==============================================
# EVENTOS DE DIALOGUE SYSTEM
# ==============================================

signal dialogue_started(dialogue_id: String)
signal dialogue_node_shown(node_id: String, speaker_id: String, text_key: String, portrait_id: String)
signal dialogue_option_selected(node_id: String, option_id: String)
signal dialogue_ended(dialogue_id: String)
signal dialogue_options_updated(options: Array)

# ==============================================
# EVENTOS DE GAMELOOP
# ==============================================

signal game_state_changed(new_state: int)
signal game_state_context(new_state: int, context: Dictionary)

# ==============================================
# EVENTOS DE EXPLORACIÓN
# ==============================================

signal interaction_requested(interaction_type: String, target_id: String)
signal scene_transition_completed(new_state: int)
signal dialogue_state_entered(dialogue_id: String)

signal turn_phase_changed(new_phase: int)
signal player_turn_started()
signal player_turn_ended()
signal enemy_turn_started(enemy_id: String)
signal round_started(round_number: int)
signal turn_ended()
signal round_ended(round_number: int)

# ==============================================
# EVENTOS DE COMBATE
# ==============================================

signal combat_started(participants: Array)
signal combat_ended(result: String)
signal player_action_requested(action_data: Dictionary)
signal execute_combat_action(action_data: Dictionary)
signal combat_action_completed(result: Dictionary)
signal player_action_completed(result: Dictionary)
signal combat_action_failed(actor_id: String, reason: String)
signal combat_action_executed(actor_id: String, skill_id: String, target_id: String, result: Dictionary)
signal enemy_defeated(enemy_id: String)
signal combat_loot_bag_spawned(enemy_id: String, instance_id: String, position: Vector2)
signal combat_loot_collected(entity_id: String, instance_id: String)

# ==============================================
# EVENTOS DE DEFENSA / HUIDA / ESQUIVA
# ==============================================

signal defend_requested(entity_id: String)
signal flee_requested(entity_id: String)
signal defense_activated(entity_id: String)
signal defense_expired(entity_id: String)
signal damage_absorbed(entity_id: String, stamina_consumed: int, hp_taken: int)
signal escape_attempted(entity_id: String, threshold: int)
signal escape_succeeded(entity_id: String)
signal escape_failed(entity_id: String, current_stamina: int, required_stamina: int)
signal evasion_triggered(evader_id: String)
signal target_changed(new_target: String)

# ==============================================
# EVENTOS DE RECURSOS
# ==============================================

signal resource_changed(entity_id: String, resource_id: String, old_value: float, new_value: float)
signal resource_depleted(entity_id: String, resource_id: String)
signal resource_maxed(entity_id: String, resource_id: String)

# ==============================================
# EVENTOS DE HABILIDADES
# ==============================================

signal skill_used(entity_id: String, skill_id: String)
signal skill_failed(entity_id: String, skill_id: String, reason: String)
signal skill_cooldown_started(entity_id: String, skill_id: String, duration: float)
signal skill_cooldown_ended(entity_id: String, skill_id: String)

# ==============================================
# EVENTOS DE CHECKPOINTS
# ==============================================

signal checkpoint_reached(checkpoint_id: String, state: Dictionary)
signal checkpoint_applied(checkpoint_id: String)
signal values_consolidated(vectors: Dictionary)

# ==============================================
# EVENTOS DE PROGRESION DE HABILIDADES
# ==============================================

signal skill_tick_generated(entity_id: String, skill_id: String, ticks_total: int)
signal skill_pity_triggered(entity_id: String, skill_id: String)
signal skill_improvement_attempted(entity_id: String, skill_id: String, roll: int, threshold: int)
signal skill_improved(entity_id: String, skill_id: String, old_value: int, new_value: int)
signal skill_improvement_failed(entity_id: String, skill_id: String, roll: int, threshold: int)
signal skill_unlocked(entity_id: String, skill_id: String)
signal skill_unlock_requested(entity_id: String, skill_id: String)
signal skill_unlock_failed(entity_id: String, skill_id: String, missing_prerequisites: Array)
signal learning_session_requested(entity_id: String, skill_id: String, source_level: int, source_type: String)

# ==============================================
# EVENTOS DE WORLD OBJECTS
# ==============================================

signal world_object_interaction_requested(entity_id: String, instance_id: String)
signal world_object_action_chosen(entity_id: String, instance_id: String, interaction_id: String)
signal world_object_interaction_resolved(instance_id: String, interaction_id: String, outcome: String, effect_data: Dictionary)
signal world_object_interaction_failed(entity_id: String, instance_id: String, reason: String)
signal world_object_state_changed(instance_id: String, active_flags: Array)
signal world_object_feedback_ready(instance_id: String, interaction_id: String, outcome: String, feedback_key: String, revealed_info_key: String)

# ==============================================
# EVENTOS DE COMPANIONS / PARTY
# ==============================================

## Emitido cuando un companion se une al grupo activo
signal companion_joined(companion_id: String)

## Emitido cuando un companion abandona el grupo (narrativa o muerte permanente)
signal companion_left(companion_id: String)

## Emitido cuando un companion llega a 0 HP — queda incapacitado, puede ser reanimado
signal companion_incapacitated(companion_id: String)

## Emitido cuando un companion es reanimado durante el combate
signal companion_revived(companion_id: String)

## Emitido cuando un companion muere permanentemente (evento narrativo explícito)
signal companion_died_permanently(companion_id: String)

## Emitido por GameLoop para que CompanionAI ejecute su turno
signal companion_turn_started(companion_id: String)

## Emitido cuando el companion termina su acción de combate
signal companion_action_completed(companion_id: String, result: Dictionary)

## Emitido por NarrativeEventDefinition para reclutar un companion
## PartyEventHandler es el único listener autorizado
signal join_party_requested(companion_id: String, definition_id: String)

# ==============================================
# CONFIGURACIÓN
# ==============================================

@export var enable_event_logging: bool = true
@export var logged_event_filter: Array[String] = []


func _ready():
	print("[EventBus] Initialized")
	_connect_debug_listeners()


# ==============================================
# SISTEMA DE LOGGING
# ==============================================

func _connect_debug_listeners():
	gold_changed.connect(_on_gold_changed_debug)
	transaction_completed.connect(_on_transaction_completed_debug)

	shop_open_requested.connect(_on_shop_open_requested_debug)
	shop_opened.connect(_on_shop_opened_debug)
	shop_close_requested.connect(_on_shop_close_requested_debug)
	shop_closed.connect(_on_shop_closed_debug)
	shop_buy_requested.connect(_on_shop_buy_requested_debug)
	shop_sell_requested.connect(_on_shop_sell_requested_debug)
	shop_trade_success.connect(_on_shop_trade_success_debug)
	shop_trade_failed.connect(_on_shop_trade_failed_debug)
	shop_snapshot_updated.connect(_on_shop_snapshot_updated_debug)

	narrative_flag_set.connect(_on_narrative_flag_set_debug)
	narrative_flag_cleared.connect(_on_narrative_flag_cleared_debug)
	narrative_variable_changed.connect(_on_narrative_variable_changed_debug)
	narrative_event_triggered.connect(_on_narrative_event_triggered_debug)
	narrative_state_changed.connect(_on_narrative_state_changed_debug)

	dialogue_started.connect(_on_dialogue_started_debug)
	dialogue_node_shown.connect(_on_dialogue_node_shown_debug)
	dialogue_option_selected.connect(_on_dialogue_option_selected_debug)
	dialogue_ended.connect(_on_dialogue_ended_debug)
	dialogue_options_updated.connect(_on_dialogue_options_updated_debug)

	checkpoint_reached.connect(_on_checkpoint_reached_debug)
	checkpoint_applied.connect(_on_checkpoint_applied_debug)
	values_consolidated.connect(_on_values_consolidated_debug)

	skill_unlock_requested.connect(_on_skill_unlock_requested_debug)
	skill_unlock_failed.connect(_on_skill_unlock_failed_debug)
	learning_session_requested.connect(_on_learning_session_requested_debug)

	# Companions
	companion_joined.connect(_on_companion_joined_debug)
	companion_left.connect(_on_companion_left_debug)
	companion_incapacitated.connect(_on_companion_incapacitated_debug)
	companion_revived.connect(_on_companion_revived_debug)
	companion_died_permanently.connect(_on_companion_died_permanently_debug)


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

func _on_skill_unlock_requested_debug(entity_id: String, skill_id: String):
	if _should_log("skill_unlock_requested"):
		print("[EventBus] skill_unlock_requested ← entity=%s, skill=%s" % [entity_id, skill_id])

func _on_skill_unlock_failed_debug(entity_id: String, skill_id: String, missing: Array):
	if _should_log("skill_unlock_failed"):
		print("[EventBus] skill_unlock_failed ← entity=%s, skill=%s, missing=%s" % [entity_id, skill_id, str(missing)])

func _on_learning_session_requested_debug(entity_id: String, skill_id: String, source_level: int, source_type: String):
	if _should_log("learning_session_requested"):
		print("[EventBus] learning_session_requested ← entity=%s, skill=%s, level=%d, type=%s" % [entity_id, skill_id, source_level, source_type])

# --- Companions debug ---

func _on_companion_joined_debug(companion_id: String):
	if _should_log("companion_joined"):
		print("[EventBus] companion_joined ← %s" % companion_id)

func _on_companion_left_debug(companion_id: String):
	if _should_log("companion_left"):
		print("[EventBus] companion_left ← %s" % companion_id)

func _on_companion_incapacitated_debug(companion_id: String):
	if _should_log("companion_incapacitated"):
		print("[EventBus] companion_incapacitated ← %s" % companion_id)

func _on_companion_revived_debug(companion_id: String):
	if _should_log("companion_revived"):
		print("[EventBus] companion_revived ← %s" % companion_id)

func _on_companion_died_permanently_debug(companion_id: String):
	if _should_log("companion_died_permanently"):
		print("[EventBus] companion_died_permanently ← %s" % companion_id)

# ==============================================
# UTILIDADES
# ==============================================

func _should_log(event_name: String) -> bool:
	if not enable_event_logging:
		return false
	if logged_event_filter.is_empty():
		return true
	return event_name in logged_event_filter

func get_listeners_count(signal_name: String) -> int:
	if not has_signal(signal_name):
		return 0
	return get_signal_connection_list(signal_name).size()

func print_available_signals():
	print("\n[EventBus] Available signals:")
	for sig in get_signal_list():
		var name = sig["name"]
		var count = get_listeners_count(name)
		print("  - %s (%d listeners)" % [name, count])

func set_logging_enabled(enabled: bool):
	enable_event_logging = enabled

func set_event_filter(filter: Array[String]):
	logged_event_filter = filter

# ==============================================
# DEBUG LISTENERS — CHARACTER SYSTEM
# ==============================================

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
