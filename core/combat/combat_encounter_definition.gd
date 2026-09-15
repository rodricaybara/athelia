class_name CombatEncounterDefinition
extends Resource

## CombatEncounterDefinition — Spike 2, punto 6: moral y refuerzos cronometrados
## Spike 3, Grupo B: campo de sorpresa añadido (ver más abajo).
##
## Datos opcionales de un combate concreto — moral de grupo y refuerzos
## cronometrados. Genérico, no específico de ninguna aventura: los números
## y los enemy_ids concretos los pone quien arma el encuentro (hoy, a mano
## en código; en Spike 3, probablemente desde datos de la aventura).
##
## Se pasa como parámetro OPCIONAL a GameLoopSystem.start_combat(). Sin él
## (o con los valores por defecto), un combate se comporta exactamente
## igual que antes de Spike 2 — el grupo nunca huye, nunca llegan refuerzos,
## y desde Spike 3 tampoco hay sorpresa.
##
## Ninguno de los mecanismos vive hardcodeado en EnemyAI ni en
## CombatResolver — moral de grupo se resuelve entera en GameLoopSystem
## (saca entidades de participants/turn_order igual que una muerte, pero
## sin loot ni animación de muerte), refuerzos reutiliza el mismo camino
## de spawn que ya usa CombatTestScene para los enemigos iniciales, y
## sorpresa reutiliza el sistema de buffs ya existente en CombatSystem.
##
## NOTA (actualizada Spike 3, Grupo A): la base de moral YA NO es fija.
## Se recalcula cada vez que llega un refuerzo, sumando su HP máximo al HP
## actual de los supervivientes en ese momento — el umbral (%) configurado
## aquí se sigue aplicando siempre sobre la base vigente, que solo cambia
## al llegar un refuerzo, nunca golpe a golpe. Ver GameLoopSystem
## ._group_morale_base_hp / ._check_group_morale().

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

## Spike 3, Grupo B — sorpresa de combate.
## "" (default) = sin sorpresa, el combate empieza como siempre.
## "party"   = el grupo (jugador + companions) sorprende a los enemigos.
## "enemies" = los enemigos sorprenden al grupo.
##
## Implementado SIN tocar turn_order ni la máquina de TurnPhase (la
## estructura de fases ya obliga a jugador+companions a actuar antes que
## los enemigos cada ronda, así que reordenar iniciativa no tendría efecto
## real). En su lugar, el bando sorprendido recibe un buff "staggered" —
## el mismo que ya usa CombatSystem para aturdimiento — al montar el
## combate, y pierde su primer intento de acción en la ronda 1. A partir
## de ahí el combate sigue con las fases normales, sin más diferencia.
## Ver GameLoopSystem.start_combat().
var surprise_favors: String = ""

## 0.0 (default) = la sorpresa solo hace perder la primera acción, sin
## debuff adicional. >0.0 = además, el bando sorprendido recibe el buff
## "vulnerable" ya existente en CombatSystem con este valor durante la
## ronda de sorpresa — 100.0 = el doble de daño recibido, 200.0 = el
## triple. Reutiliza el pipeline de buffs numéricos de daño que ya aplica
## CombatSystem en cada golpe; no añade lógica de daño nueva. No combinar
## con un "damage_bonus" al atacante para el mismo efecto — se multiplican
## entre sí en vez de sumarse.
var surprise_vulnerable_pct: float = 0.0


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
	def.surprise_favors = data.get("surprise_favors", "")
	def.surprise_vulnerable_pct = data.get("surprise_vulnerable_pct", 0.0)
	return def
