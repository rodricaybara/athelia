class_name AttributeResolver
extends RefCounted

## AttributeResolver - Motor de cálculo de atributos derivados
## Parte del CharacterSystem
##
## ✅ PRODUCTION-READY: Data-Driven Formulas (Validated 2025-02-03)
##
## Sistema PURO sin estado persistente.
## Input:  atributos base (desde CharacterState) + modificadores activos + contexto
## Output: valor derivado calculado
##
## Contrato:
##   - NUNCA cachea resultados (solo cachea definiciones de fórmulas)
##   - SIEMPRE determinista: mismos inputs → mismo output
##   - NO emite eventos
##   - NO escribe estado en ningún otro sistema
##   - Todas las funciones son static
##
## Consumo externo:
##   - Characters.get_character_state(entity_id)   → leer atributos base
##   - Characters.get_active_modifiers(entity_id)  → leer modificadores (equipados + temporales)
##
## SPIKE COMPLETADO:
##   - Las fórmulas se definen en: res://data/formulas/derived_attributes.json
##   - Para añadir un nuevo atributo derivado, solo edita el JSON
##   - No requiere cambios en código GDScript
##
## Cómo añadir un nuevo atributo derivado:
##   1. Edita res://data/formulas/derived_attributes.json
##   2. Añade nueva entrada con formato linear_combination
##   3. Reinicia Godot para cargar la nueva fórmula
##   4. El atributo estará disponible vía AttributeResolver.resolve()
##
## Ejemplo de fórmula:
##   "my_new_attribute": {
##     "type": "linear_combination",
##     "base_constant": 5.0,           // Opcional, default 0.0
##     "description": "What this does", // Opcional, para documentación
##     "terms": [
##       { "attribute": "strength", "coefficient": 2.0 },
##       { "attribute": "dexterity", "coefficient": 1.5 }
##     ]
##   }
##   → Calcula: 5.0 + (strength × 2.0) + (dexterity × 1.5)
##
## ✅ PRODUCTION-READY: Data-driven formulas system validated
##
## Fórmulas cargadas desde: res://data/formulas/derived_attributes.json
## Validado: 2025-02-03 via character_spike_test.gd (5/5 tests passed)
##
## Para añadir nuevos atributos derivados:
##   - Solo edita el JSON, NO este archivo
##   - Formato: linear_combination con terms array
##   - Reinicia Godot para cargar cambios
##
## Extensibilidad futura:
##   - Nuevos tipos de fórmula: añadir case en _get_base_value() y su resolver
##   - Hot-reload: implementar FileSystemWatcher si se necesita
##   - Validación en editor: crear EditorPlugin para validar JSON
##
## Implementar lógica real en resolve_skill_cost (pendiente)


# ============================================
# DATA-DRIVEN FORMULAS (Phase 2 - VALIDATED)
# ============================================

## Cache de fórmulas parseadas desde JSON.
## Se carga una sola vez al primer uso.
## NO cachea valores calculados, solo las definiciones de fórmulas.
static var _formulas: Dictionary = {}
static var _formulas_loaded: bool = false

## Ruta al archivo de fórmulas
const FORMULAS_PATH = "res://data/formulas/derived_attributes.json"


## Asegura que las fórmulas estén cargadas.
## Llamado automáticamente por resolve() antes de calcular.
## Idempotente: si ya están cargadas, no hace nada.
static func _ensure_formulas_loaded() -> void:
	if _formulas_loaded:
		return
	
	print("[AttributeResolver] Loading formulas from %s..." % FORMULAS_PATH)
	
	# Abrir archivo JSON
	var file = FileAccess.open(FORMULAS_PATH, FileAccess.READ)
	if not file:
		push_error("[AttributeResolver] Failed to open formulas file: %s" % FORMULAS_PATH)
		push_error("[AttributeResolver] Formulas will not be available!")
		_formulas_loaded = true  # Evitar reintentos infinitos
		return
	
	# Leer contenido
	var json_text = file.get_as_text()
	file.close()
	
	# Parsear JSON
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		push_error("[AttributeResolver] JSON parse error at line %d: %s" % [
			json.get_error_line(),
			json.get_error_message()
		])
		_formulas_loaded = true
		return
	
	var data = json.data
	
	if typeof(data) != TYPE_DICTIONARY:
		push_error("[AttributeResolver] JSON root must be a dictionary")
		_formulas_loaded = true
		return
	
	# Extraer fórmulas (ignorar metadata que empieza con '_')
	var formula_count = 0
	for key in data.keys():
		if key.begins_with("_"):
			# Metadata field, skip
			continue
		
		var formula = data[key]
		if _validate_formula(key, formula):
			_formulas[key] = formula
			formula_count += 1
		else:
			push_warning("[AttributeResolver] Skipping invalid formula: %s" % key)
	
	_formulas_loaded = true
	print("[AttributeResolver] Loaded %d formulas successfully" % formula_count)


## Valida la estructura de una fórmula.
## Retorna true si es válida, false si debe descartarse.
static func _validate_formula(formula_id: String, formula: Variant) -> bool:
	# Debe ser un diccionario
	if typeof(formula) != TYPE_DICTIONARY:
		push_error("[AttributeResolver] Formula '%s' is not a dictionary" % formula_id)
		return false
	
	# Debe tener campo 'type'
	if not formula.has("type"):
		push_error("[AttributeResolver] Formula '%s' missing 'type' field" % formula_id)
		return false
	
	var formula_type = formula["type"]
	
	# Por ahora solo soportamos 'linear_combination'
	if formula_type != "linear_combination":
		push_error("[AttributeResolver] Formula '%s' has unsupported type: %s" % [
			formula_id, formula_type
		])
		return false
	
	# Debe tener array 'terms'
	if not formula.has("terms"):
		push_error("[AttributeResolver] Formula '%s' missing 'terms' field" % formula_id)
		return false
	
	var terms = formula["terms"]
	if typeof(terms) != TYPE_ARRAY:
		push_error("[AttributeResolver] Formula '%s' 'terms' must be an array" % formula_id)
		return false
	
	# Validar cada término
	for i in range(terms.size()):
		var term = terms[i]
		
		if typeof(term) != TYPE_DICTIONARY:
			push_error("[AttributeResolver] Formula '%s' term[%d] is not a dictionary" % [
				formula_id, i
			])
			return false
		
		# Cada término debe tener 'attribute' y 'coefficient'
		if not term.has("attribute") or not term.has("coefficient"):
			push_error("[AttributeResolver] Formula '%s' term[%d] missing required fields" % [
				formula_id, i
			])
			return false
		
		# coefficient debe ser numérico
		var coef = term["coefficient"]
		if typeof(coef) != TYPE_FLOAT and typeof(coef) != TYPE_INT:
			push_error("[AttributeResolver] Formula '%s' term[%d] coefficient is not numeric" % [
				formula_id, i
			])
			return false
	
	# base_constant es opcional, pero si existe debe ser numérico
	if formula.has("base_constant"):
		var base_const = formula["base_constant"]
		if typeof(base_const) != TYPE_FLOAT and typeof(base_const) != TYPE_INT:
			push_error("[AttributeResolver] Formula '%s' base_constant is not numeric" % formula_id)
			return false
	
	# Todo OK
	return true


# ============================================
# ORDEN DE APLICACIÓN DE MODIFICADORES
# ============================================
# Extensible vía config futuro (data/config/modifier_order.json)
# Orden actual confirmado en spike design doc:
#   1. BASE      → valor base calculado por fórmula
#   2. ADD       → suma todos los modificadores aditivos
#   3. MULTIPLY  → multiplica por todos los factores
#   4. OVERRIDE  → reemplaza el resultado (último gana)

enum ModifierOrder {
	BASE = 0,
	ADD = 1,
	MULTIPLY = 2,
	OVERRIDE = 3
}


# ============================================
# RESOLUCIÓN PRINCIPAL
# ============================================

## Calcula un atributo derivado para una entidad.
## Ejemplo: AttributeResolver.resolve("player", "health_max")
##
## Parámetros:
##   entity_id          → ID de la entidad registrada en CharacterSystem
##   derived_attribute  → nombre del atributo derivado (health_max, initiative, etc.)
##   context            → diccionario opcional para condiciones futuras
##
## Retorna 0.0 si la entidad no existe o el atributo no es conocido.
static func resolve(
	entity_id: String,
	derived_attribute: String,
	_context: Dictionary = {}
) -> float:
	var state = Characters.get_character_state(entity_id)
	if not state:
		push_error("[AttributeResolver] Entity not found: %s" % entity_id)
		return 0.0

	# 1. Valor base según fórmula
	var base_value = _get_base_value(state, derived_attribute)

	# 2. Filtrar modificadores que aplican a este atributo
	var modifiers = _collect_modifiers(entity_id, derived_attribute)

	# 3. Aplicar en orden BASE → ADD → MUL → OVERRIDE
	var final_value = _apply_modifiers(base_value, modifiers)

	return final_value


# ============================================
# FÓRMULAS BASE (Data-Driven desde Phase 2)
# ============================================
# Las fórmulas ahora se cargan desde res://data/formulas/derived_attributes.json
# Este método solo resuelve la fórmula, NO la define.

## Obtiene el valor base de un atributo derivado usando fórmulas data-driven.
## Las fórmulas se cargan desde res://data/formulas/derived_attributes.json
## y se cachean en memoria (NO se cachean valores calculados).
##
## Si la fórmula no existe o hay error, retorna 0.0 con warning.
static func _get_base_value(state: CharacterState, derived_attr: String) -> float:
	# Asegurar que las fórmulas estén cargadas
	_ensure_formulas_loaded()
	
	# Buscar fórmula para este atributo derivado
	if not _formulas.has(derived_attr):
		push_warning("[AttributeResolver] No formula defined for: %s" % derived_attr)
		return 0.0
	
	var formula = _formulas[derived_attr]
	var formula_type = formula.get("type", "")
	
	# Resolver según tipo de fórmula
	match formula_type:
		"linear_combination":
			return _resolve_linear_combination(state, formula)
		
		_:
			push_error("[AttributeResolver] Unknown formula type '%s' for %s" % [
				formula_type, derived_attr
			])
			return 0.0


## Resuelve una fórmula de tipo 'linear_combination'.
## Formato: result = base_constant + sum(attribute_value × coefficient)
##
## Ejemplo:
##   {
##     "base_constant": 10.0,
##     "terms": [
##       { "attribute": "dexterity", "coefficient": 1.0 }
##     ]
##   }
##   → result = 10.0 + (dexterity × 1.0)
static func _resolve_linear_combination(state: CharacterState, formula: Dictionary) -> float:
	# Valor base (constante opcional, defaults a 0.0)
	var result = formula.get("base_constant", 0.0)
	
	# Sumar cada término: attribute_value × coefficient
	var terms = formula.get("terms", [])
	for term in terms:
		var attr_id = term.get("attribute", "")
		var coefficient = term.get("coefficient", 0.0)
		
		# Leer valor del atributo base desde CharacterState
		var attr_value = state.get_base_attribute(attr_id)
		
		# Acumular: result += (attr_value × coefficient)
		result += attr_value * coefficient
	
	return result


# ============================================
# RECOLECCIÓN DE MODIFICADORES
# ============================================

## Obtiene todos los modificadores activos de la entidad y filtra
## los que aplican al atributo derivado solicitado.
## Delega la lista completa a Characters.get_active_modifiers(),
## que ya combina equipados + temporales.
static func _collect_modifiers(
	entity_id: String,
	derived_attr: String
) -> Array[ModifierDefinition]:
	var all_modifiers = Characters.get_active_modifiers(entity_id)
	var applicable: Array[ModifierDefinition] = []

	for mod in all_modifiers:
		if _modifier_applies_to(mod, derived_attr):
			applicable.append(mod)

	return applicable


## Comprueba si un modificador aplica al atributo derivado dado.
## Convención de target: "attribute.<nombre_derivado>"
##   Ejemplo: mod.target == "attribute.health_max" aplica a derived_attr "health_max"
##   Nota: los mods con target "resource.X" son para ModifierApplicator, no para aquí.
static func _modifier_applies_to(mod: ModifierDefinition, derived_attr: String) -> bool:
	var expected_target = "attribute." + derived_attr
	return mod.target == expected_target


# ============================================
# APLICACIÓN DE MODIFICADORES (orden estricto)
# ============================================

## Aplica los modificadores sobre un valor base siguiendo el orden
## definido en ModifierOrder: ADD → MULTIPLY → OVERRIDE.
##
## - ADD:      todos los modificadores aditivos se suman al base.
## - MULTIPLY: todos los factores se aplican secuencialmente sobre el resultado de ADD.
## - OVERRIDE: si existe al menos uno, reemplaza todo el resultado. Si hay varios, gana el último.
static func _apply_modifiers(
	base_value: float,
	modifiers: Array[ModifierDefinition]
) -> float:
	# Agrupar por operación
	var adds: Array[ModifierDefinition] = []
	var muls: Array[ModifierDefinition] = []
	var overrides: Array[ModifierDefinition] = []

	for mod in modifiers:
		match mod.operation:
			"add":
				adds.append(mod)
			"mul":
				muls.append(mod)
			"override":
				overrides.append(mod)

	# 1. BASE
	var result = base_value

	# 2. ADD — sumar todos
	for mod in adds:
		result += mod.value

	# 3. MULTIPLY — aplicar secuencialmente
	for mod in muls:
		result *= mod.value

	# 4. OVERRIDE — el último reemplaza todo
	if not overrides.is_empty():
		result = overrides[-1].value

	return result


# ============================================
# RESOLUCIÓN DE MÁXIMOS DE RECURSOS
# ============================================

## Calcula el máximo efectivo de un recurso delegando al atributo
## derivado correspondiente.
## Usado por ModifierApplicator (Phase 4) para actualizar ResourceSystem.
##
## Recursos sin máximo calculado (ej: gold) retornan un valor
## prácticamente infinito para no interferir con la lógica de ResourceState.
static func resolve_resource_max(entity_id: String, resource_id: String) -> float:
	match resource_id:
		"health":
			return resolve(entity_id, "health_max")
		"stamina":
			return resolve(entity_id, "stamina_max")
		_:
			# Recursos sin fórmula de máximo (gold, focus, etc.)
			return 999999.0


# ============================================
# RESOLUCIÓN DE COSTES DE HABILIDADES
# ============================================

## Calcula el coste modificado de una habilidad.
## Phase 3 stub: retorna el coste base sin modificaciones.
##
## Post-spike: aplicar modificadores "skill_cost_reduction",
## bonificaciones por atributos, etc.
static func resolve_skill_cost(
	_entity_id: String,
	_skill_id: String,
	base_cost: ResourceBundle
) -> ResourceBundle:
	# TODO (post-spike): filtrar modificadores con target "skill_cost.*"
	# y aplicar reducciones/aumentos sobre base_cost
	return base_cost


# ============================================
# DEBUG
# ============================================

## Imprime el cálculo paso a paso para un atributo derivado.
## Útil durante desarrollo y para tooltips de UI futuros.
##
## Ejemplo de output:
##   === Resolving health_max for player ===
##   Base value: 55.00
##   Modifiers found: 2
##     - attribute.health_max add 15.00
##     - attribute.health_max mul 1.20
##   Final value: 84.00
static func debug_resolve(entity_id: String, derived_attr: String) -> void:
	print("\n=== Resolving %s for %s ===" % [derived_attr, entity_id])

	var state = Characters.get_character_state(entity_id)
	if not state:
		print("  ERROR: Entity not found")
		return

	var base = _get_base_value(state, derived_attr)
	print("  Base value: %.2f" % base)

	var mods = _collect_modifiers(entity_id, derived_attr)
	print("  Modifiers found: %d" % mods.size())

	for mod in mods:
		print("    - %s %s %.2f" % [mod.target, mod.operation, mod.value])

	var final_value = _apply_modifiers(base, mods)
	print("  Final value: %.2f" % final_value)
