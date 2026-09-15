class_name NarrativeSceneOutcome
extends Resource

## NarrativeSceneOutcome — Spike 1: Motor Narrativo Base
## Spike 3, Grupo B: campos de otorgar-ítem y combat_encounter añadidos
## (ver más abajo). Resolución pendiente en el ViewModel — estos campos son
## inertes hasta que se cablee su aplicación ahí.
##
## Data class ligera para el destino/consecuencias de una opción resuelta
## (fin de escena, siguiente nodo, flag, ítem, combate).
##
## Extraída a fichero propio en vez de clase interna de NarrativeSceneOption
## (primer intento de fix). La causa real, confirmada en depuración: un
## script GDScript no resuelve de forma fiable su propio class_name
## referenciado dentro de sí mismo (aquí, en from_dict()). Fix real: usar
## new() a secas en vez de NarrativeSceneOutcome.new() — instancia el script
## actual sin pasar por la tabla global de clases. Ver depuración de Spike 1.

## Vacío = fin de la escena, cierra el panel.
var next_scene_id: String = ""

## Vacío = ninguno. Convención "flag." confirmada en uso real
## (game_loop_system.gd: Narrative.set_flag("flag.player_downed")).
var flag_to_set: String = ""

## Vacío = no dispara combate. Si no está vacío, GameLoop.start_combat()
## toma el control — el panel narrativo se cierra antes de llamarlo.
var combat_enemy_ids: Array[String] = []

## Spike 3, Grupo B — mapeo enemy_id → definition_id, mismo formato que
## Interactable.enemy_definitions. Necesario porque, a diferencia del
## combate disparado desde ExplorationController (que lee este mapeo del
## Interactable que lo dispara), un combate disparado desde una escena
## narrativa no tiene ningún Interactable de por medio — sin este campo,
## los enemigos nunca se registran en CharacterSystem/ResourceSystem antes
## de start_combat() y _calculate_initiative() no los encuentra. Vacío o
## sin entrada para un enemy_id concreto = fallback a "enemy_base", igual
## que en ExplorationController._register_combat_enemies().
var combat_enemy_definitions: Dictionary = {}

## Spike 3, Grupo B — null = combate sin encuentro configurado (moral,
## refuerzos y sorpresa en reposo, igual que antes de Spike 2/3). Si
## combat_enemy_ids no está vacío y este campo tiene un valor, se pasa
## directamente como segundo argumento de GameLoop.start_combat() —
## sustituye a tener que llamar aparte a configure_active_encounter().
var combat_encounter: CombatEncounterDefinition = null

## Spike 3, Grupo B — "otorgar ítem": entrega puntual de un solo ítem,
## reutilizando la API de Inventory ya existente. Vacío = no otorga nada.
## Deliberadamente mínimo: no es una tabla de botín, no admite condiciones
## ni probabilidad — si una escena necesita algo más rico, es una escena
## nueva con dos opciones, no una extensión de estos campos.
var grant_item_id: String = ""
var grant_item_quantity: int = 1

## entity_id destino de la entrega. "player" por defecto — decidible por
## el autor de la escena en JSON (p. ej. para dar un ítem a un companion
## en vez de al jugador).
var grant_item_target: String = "player"


static func from_dict(data: Dictionary) -> NarrativeSceneOutcome:
	var outcome := new()
	outcome.next_scene_id = data.get("next_scene_id", "")
	outcome.flag_to_set = data.get("flag_to_set", "")

	var raw_enemies: Array = data.get("combat_enemy_ids", [])
	var enemies: Array[String] = []
	for enemy_id in raw_enemies:
		enemies.append(str(enemy_id))
	outcome.combat_enemy_ids = enemies

	outcome.combat_enemy_definitions = data.get("combat_enemy_definitions", {})

	if data.has("combat_encounter"):
		outcome.combat_encounter = CombatEncounterDefinition.from_dict(data["combat_encounter"])

	outcome.grant_item_id = data.get("grant_item_id", "")
	outcome.grant_item_quantity = data.get("grant_item_quantity", 1)
	outcome.grant_item_target = data.get("grant_item_target", "player")

	return outcome
