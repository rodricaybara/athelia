class_name NarrativeSceneOutcome
extends Resource

## NarrativeSceneOutcome — Spike 1: Motor Narrativo Base
##
## Data class ligera para el destino/consecuencias de una opción resuelta
## (fin de escena, siguiente nodo, flag, combate).
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


static func from_dict(data: Dictionary) -> NarrativeSceneOutcome:
	var outcome := new()
	outcome.next_scene_id = data.get("next_scene_id", "")
	outcome.flag_to_set = data.get("flag_to_set", "")

	var raw_enemies: Array = data.get("combat_enemy_ids", [])
	var enemies: Array[String] = []
	for enemy_id in raw_enemies:
		enemies.append(str(enemy_id))
	outcome.combat_enemy_ids = enemies

	return outcome
