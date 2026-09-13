class_name CombatEncounterDefinition
extends Resource

## CombatEncounterDefinition — Spike 2, punto 6: moral y refuerzos cronometrados
##
## Datos opcionales de un combate concreto — moral de grupo y refuerzos
## cronometrados. Genérico, no específico de ninguna aventura: los números
## y los enemy_ids concretos los pone quien arma el encuentro (hoy, a mano
## en código; en Spike 3, probablemente desde datos de la aventura).
##
## Se pasa como parámetro OPCIONAL a GameLoopSystem.start_combat(). Sin él
## (o con los valores por defecto), un combate se comporta exactamente
## igual que antes de Spike 2 — el grupo nunca huye, nunca llegan refuerzos.
##
## Ninguno de los dos mecanismos vive hardcodeado en EnemyAI ni en
## CombatResolver — moral de grupo se resuelve entera en GameLoopSystem
## (saca entidades de participants/turn_order igual que una muerte, pero
## sin loot ni animación de muerte), y refuerzos reutiliza el mismo camino
## de spawn que ya usa CombatTestScene para los enemigos iniciales.
##
## NOTA: la moral de grupo se calcula solo sobre el HP total del grupo
## ORIGINAL de enemigos, capturado una vez al iniciar combate — los
## refuerzos que lleguen no se suman a esa base. Es una simplificación
## explícita, no una limitación técnica: no hay un encuentro real todavía
## que diga si un refuerzo debería "diluir" la moral del grupo original o
## no. Revisar si Spike 3 lo necesita.

## 0 = el grupo nunca huye (comportamiento por defecto, igual que antes de
## Spike 2). >0 = cuando el HP total restante de los enemigos vivos cae a
## este % o menos del HP total inicial del grupo, todos los enemigos
## supervivientes huyen a la vez.
var morale_threshold_pct: float = 0.0

## Vacío (default) = el contador de refuerzos empieza a correr desde el
## inicio del combate. Con un nombre, no arranca hasta que algo llame a
## GameLoop.trigger_combat_event(ese nombre) — cualquier sistema puede
## dispararlo (una skill, un futuro outcome narrativo, un world object...)
## sin que este recurso sepa nada de quién lo hace.
var reinforcement_trigger: String = ""

## Asaltos (rondas completas) desde que se activa el contador hasta que
## llegan los refuerzos. 0 junto con reinforcement_enemy_ids vacío = sin
## refuerzos en este encuentro.
var reinforcement_delay_rounds: int = 0

## IDs de entidad de los refuerzos a spawnear — mismo formato que los
## enemy_ids que ya recibe start_combat().
var reinforcement_enemy_ids: Array[String] = []

## CharacterDefinition de la que sacan sus stats los refuerzos. Necesario
## porque _initialize_enemy() en CombatTestScene tenía "enemy_base"
## hardcodeado para todo enemigo — un refuerzo puede ser de un tipo
## distinto al resto del encuentro (ver nota en ese fichero).
var reinforcement_definition_id: String = "enemy_base"


## Constructor de conveniencia para pruebas / código — sin loader desde
## JSON todavía porque no hay ningún combate en el proyecto que se arme
## desde datos hoy (los enemy_ids se pasan a mano a start_combat()). Se
## deja from_dict() ya escrito para cuando Spike 3 sí lo necesite, siguiendo
## el mismo patrón que NarrativeSceneOption.from_dict().
static func from_dict(data: Dictionary) -> CombatEncounterDefinition:
	var def := new()
	def.morale_threshold_pct = data.get("morale_threshold_pct", 0.0)
	def.reinforcement_trigger = data.get("reinforcement_trigger", "")
	def.reinforcement_delay_rounds = data.get("reinforcement_delay_rounds", 0)
	var ids: Array = data.get("reinforcement_enemy_ids", [])
	def.reinforcement_enemy_ids.assign(ids)
	def.reinforcement_definition_id = data.get("reinforcement_definition_id", "enemy_base")
	return def
