**Characters Module Documentation**

Overview
- **Purpose:** concise descriptions for files in `core/characters` to serve as a Doxygen-like reference and a starting point for automated extraction.

Files

- **`attribute_resolver.gd`**: Resolves attribute values for characters, likely computing final attribute values from base stats, modifiers, and context-specific rules.
  - Functions (extracted):
    - `static func _ensure_formulas_loaded() -> void`
    - `static func _validate_formula(formula_id: String, formula: Variant) -> bool`
    - `static func resolve(entity_id: String, derived_attribute: String, context: Dictionary = {}) -> float`
    - `static func _get_base_value(state: CharacterState, derived_attr: String) -> float`
    - `static func _resolve_linear_combination(state: CharacterState, formula: Dictionary) -> float`
    - `static func _collect_modifiers(entity_id: String, derived_attr: String) -> Array[ModifierDefinition]`
    - `static func _modifier_applies_to(mod: ModifierDefinition, derived_attr: String) -> bool`
    - `static func _apply_modifiers(base_value: float, modifiers: Array[ModifierDefinition]) -> float`
    - `static func resolve_resource_max(entity_id: String, resource_id: String) -> float`
    - `static func resolve_skill_cost(entity_id: String, skill_id: String, base_cost: ResourceBundle) -> ResourceBundle`
    - `static func debug_resolve(entity_id: String, derived_attr: String) -> void`
  - Calls / external dependencies (extracted):
    - `Characters.get_character_state(entity_id)` — reads `CharacterState`
    - `Characters.get_active_modifiers(entity_id)` — obtains modifiers list
    - `FileAccess.open(...)`, `JSON.new()` — for loading formula definitions
    - Uses `ModifierDefinition` types and relies on `res://data/formulas/derived_attributes.json`

- **`character_definition.gd`**: Holds static definitions for a character type (templates, base attributes, starting equipment, growth tables).
  - Functions (extracted):
    - `func validate() -> bool`
    - `func get_base_attribute(attr_id: String) -> float`
    - `func get_starting_resource(resource_id: String) -> float`
    - `func has_skill(skill_id: String) -> bool`
    - `func has_equipment_slot(slot_name: String) -> bool`
    - `func duplicate_definition() -> CharacterDefinition`
    - `func _to_string() -> String`
  - Calls / external dependencies (extracted):
    - Uses Godot APIs: `push_error`, `push_warning`
    - Returns/produces `CharacterDefinition` and basic types only (no heavy external system calls)

- **`character_state.gd`**: Represents runtime character state (current HP, MP, attributes, active modifiers, inventory links, serialized checkpoint state).
  - Functions (extracted):
    - `func _init(def: CharacterDefinition)`
    - `func get_base_attribute(attr_id: String) -> float`
    - `func modify_base_attribute(attr_id: String, delta: float) -> void`
    - `func set_base_attribute(attr_id: String, value: float) -> void`
    - `func get_resource(resource_id: String) -> float`
    - `func set_resource(resource_id: String, value: float) -> void`
    - `func modify_resource(resource_id: String, delta: float) -> void`
    - `func add_equipped_modifier(modifier: ModifierDefinition) -> void`
    - `func remove_equipped_modifier(modifier: ModifierDefinition) -> bool`
    - `func get_equipped_modifiers() -> Array[ModifierDefinition]`
    - `func get_skill_value(skill_id: String) -> int`
    - `func set_skill_value(skill_id: String, value: int) -> void`
    - `func modify_skill_value(skill_id: String, delta: int) -> void`
    - `func has_skill(skill_id: String) -> bool`
    - `func list_known_skills() -> Array[String]`
    - `func add_temporary_state(state_data: Dictionary) -> void`
    - `func remove_temporary_state(state_id: String) -> bool`
    - `func get_temporary_modifiers() -> Array[ModifierDefinition]`
    - `func get_all_active_modifiers() -> Array[ModifierDefinition]`
    - `func print_state() -> void`
    - `func _to_string() -> String`
    - `func get_save_state() -> Dictionary`
    - `func load_save_state(save_data: Dictionary) -> void`
  - Calls / external dependencies (extracted):
    - Calls `CharacterDefinition.validate()` during initialization
    - Uses Godot API helpers: `push_error`, `push_warning`, `print`, `maxf`, `clampi`
    - Interacts with `ModifierDefinition` and serialization formats for save/load (TODO: serializer for modifiers)

- **`character_system.gd`**: Manages creation, lookup, persistence and lifecycle of characters in the game (factory, registries, event hooks).
  - Functions (extracted):
    - `func _ready()`
    - `func _load_character_definitions()`
    - `func _load_character_from_resource(file_path: String)`
    - `func _print_available_definitions()`
    - `func register_entity(entity_id: String, definition_id: String) -> bool`
    - `func unregister_entity(entity_id: String) -> bool`
    - `func has_entity(entity_id: String) -> bool`
    - `func get_registered_entities() -> Array[String]`
    - `func get_character_state(entity_id: String) -> CharacterState`
    - `func get_character_definition(entity_id: String) -> CharacterDefinition`
    - `func get_base_attribute(entity_id: String, attr_id: String) -> float`
    - `func modify_base_attribute(entity_id: String, attr_id: String, delta: float) -> void`
    - `func set_base_attribute(entity_id: String, attr_id: String, value: float) -> void`
    - `func get_all_base_attributes(entity_id: String) -> Dictionary`
    - `func get_resource(entity_id: String, resource_id: String) -> float`
    - `func set_resource(entity_id: String, resource_id: String, value: float) -> void`
    - `func modify_resource(entity_id: String, resource_id: String, delta: float) -> void`
    - `func get_all_resources(entity_id: String) -> Dictionary`
    - `func get_skill_value(entity_id: String, skill_id: String) -> int`
    - `func set_skill_value(entity_id: String, skill_id: String, value: int) -> void`
    - `func modify_skill_value(entity_id: String, skill_id: String, delta: int) -> void`
    - `func list_known_skills(entity_id: String) -> Array[String]`
    - `func get_all_skill_values(entity_id: String) -> Dictionary`
    - `func add_equipped_modifier(entity_id: String, modifier: ModifierDefinition) -> void`
    - `func remove_equipped_modifier(entity_id: String, modifier: ModifierDefinition) -> bool`
    - `func get_active_modifiers(entity_id: String) -> Array[ModifierDefinition]`
    - `func get_equipped_modifiers(entity_id: String) -> Array[ModifierDefinition]`
    - `func add_temporary_state(entity_id: String, state_data: Dictionary) -> void`
    - `func remove_temporary_state(entity_id: String, state_id: String) -> bool`
    - `func get_active_states(entity_id: String) -> Array`
    - `func get_definition(definition_id: String) -> CharacterDefinition`
    - `func has_definition(definition_id: String) -> bool`
    - `func list_definitions() -> Array[String]`
    - `func print_character(entity_id: String)`
    - `func print_all_entities()`
    - `func get_save_state(entity_id: String) -> Dictionary`
    - `func load_save_state(entity_id: String, save_data: Dictionary) -> bool`
    - `func get_save_state_all() -> Dictionary`
    - `func load_save_state_all(save_data: Dictionary) -> void`
  - Calls / external dependencies (extracted):
    - `DirAccess.open(...)`, `load(file_path)` — loads `CharacterDefinition` resources
    - `CharacterState.new(definition)` — constructs runtime state
    - Emits signals: `character_registered`, `character_unregistered`, `base_attribute_changed`, `modifier_added`, `modifier_removed`, `recalculation_requested`
    - Uses `push_warning` / `push_error`, and internal `CharacterState` APIs

- **`modifier_applicator.gd`**: Applies and removes modifiers to character state, resolves stacking rules and duration handling.
  - Functions (extracted):
    - `func _ready()`
    - `func recalculate_all(entity_id: String) -> void`
    - `func _recalculate_resource_maxes(entity_id: String) -> void`
    - `func _on_base_attribute_changed(entity_id: String, attr_id: String, old_value: float, new_value: float) -> void`
    - `func _on_modifier_changed(entity_id: String, modifier: ModifierDefinition) -> void`
    - `func apply_item_modifiers(entity_id: String, item_def: ItemDefinition) -> void`
    - `func add_temporary_state(entity_id: String, state_id: String, modifiers: Array[ModifierDefinition], duration: float) -> void`
    - `func _process(delta: float)`
    - `func debug_print_active_states(entity_id: String) -> void`
  - Calls / external dependencies (extracted):
    - Connects to `Characters` signals: `base_attribute_changed`, `modifier_added`, `modifier_removed`
    - Calls `Characters.get_character_state`, `Characters.get_registered_entities`
    - Calls `AttributeResolver.resolve_resource_max(entity_id, resource_id)` to compute maxima
    - Calls `Resources.get_resource_state`, `Resources.set_max_effective`, `Resources.add_resource`, `Resources.set_resource`, `Resources.get_resource_amount`
    - Interacts with `ItemDefinition` and `ModifierDefinition` APIs (e.g. `get_modifiers_for_condition`, `targets_resource`, `get_resource_id`)


How to auto-populate the TODOs (function & call extraction)
- Quick PowerShell (Windows) snippet to list exported function names from `.gd` files in `core/characters`:

```powershell
Get-ChildItem -Path core\characters -Filter *.gd | ForEach-Object {
  $path = $_.FullName
  "# File: $($_.Name)"
  Select-String -Path $path -Pattern 'func\s+\w+' | ForEach-Object { $_.Line.Trim() }
  ""
}
```

- A slightly more advanced extraction (shows function signatures and called methods roughly):

```powershell
Get-ChildItem core\characters -Filter *.gd | ForEach-Object {
  $file = $_.FullName
  Write-Output "# $($_.Name)"
  Select-String -Path $file -Pattern '^\s*func\s+.*' | % { $_.Line.Trim() }
  Select-String -Path $file -Pattern '\w+\s*\(' | % { $_.Matches } | % { $_.Value } | Sort-Object -Unique
  ""
}
```

- If you prefer I can run the extraction and fill the TODOs for you — tell me if you want real signatures inserted.

Doxygen-style tags (suggested)
- Use these tags in header comments in `.gd` files to aid tools that parse docs:
  - `@file` — file description
  - `@class` — class/purpose
  - `@param` — function parameters
  - `@return` — return value
  - `@see` — related files

Next steps
- I can: fill the TODOs by reading each `.gd` and inserting actual function signatures and cross-calls, or generate a JSON or Markdown report extracted automatically. Which would you like?
