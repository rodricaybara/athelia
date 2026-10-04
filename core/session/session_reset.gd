class_name SessionReset
extends RefCounted

## SessionReset — Reinicio de sesión (Spike 14).
##
## Ruta: res://core/session/session_reset.gd
##
## Deja los sistemas globales como en un arranque en frío, para que "Nueva
## partida" y "Cargar partida" no hereden nada de la partida anterior.
## Lo invoca SceneOrchestrator al entrar en MENU, tras el teardown de escenas.
##
## Coordinador explícito con ORDEN FIJO (no es un evento: varios pasos
## dependen del anterior). Solo usa APIs públicas de cada sistema:
##
##   1. Dialogue.reset()          — cierra un diálogo activo mientras las
##                                  entidades todavía existen.
##   2. Combat.clear_buffs(id)    — por cada entidad registrada. Los buffs de
##                                  CombatSystem nunca se limpian al terminar
##                                  un combate, y los ids de companion son
##                                  fijos (companion_mira), así que la
##                                  partida nueva los heredaría.
##   3. Party.leave_party(id)     — por cada miembro (emite companion_left y
##                                  da de baja al companion vía
##                                  EntityLifecycle).
##   4. EntityLifecycle           — todo lo que siga en Characters: jugador y
##                                  enemigos sueltos de un combate perdido.
##   5. Narrative.clear_all()     — flags, variables y eventos.
##   6. Checkpoints.reset()
##   7. Economy.reset_session()   — stock y presupuesto de las tiendas.
##
## Idempotente: con el almacén vacío (arranque en frío, o CHARACTER_CREATION →
## MENU) no produce avisos ni errores; los contadores salen a 0.
##
## Límites conocidos (anotados para la recopilación del hito):
##   - Solo ve las entidades registradas en Characters. Una entidad que
##     estuviera solo en Skills o Resources no se vería (no hay listador
##     público en esos sistemas).
##   - Los buffs de entidades que ya NO están registradas (p.ej. enemigos de
##     un combate anterior ya limpiado) tampoco se tocan.

static func apply() -> void:
	print("[SessionReset] === Reiniciando sesión ===")

	# 1. Diálogo activo (si lo hubiera)
	Dialogue.reset()

	# 2. Buffs de combate de todas las entidades registradas
	var registered: Array[String] = Characters.get_registered_entities()
	for entity_id: String in registered:
		Combat.clear_buffs(entity_id)

	# 3. Party: dar de baja a cada miembro
	var members: Array = Party.get_party_members().duplicate()
	var companions_left: int = 0
	for companion_id: String in members:
		if Party.leave_party(companion_id):
			companions_left += 1

	# 4. Resto de entidades (jugador + enemigos sueltos).
	#    Se vuelve a leer la lista: la baja de companions ya la ha reducido.
	var remaining: Array[String] = Characters.get_registered_entities()
	var unregistered: int = remaining.size()
	for entity_id: String in remaining:
		EntityLifecycle.unregister_everywhere(entity_id)

	# 5-7. Estado global de narrativa y economía
	Narrative.clear_all()
	Checkpoints.reset()
	Economy.reset_session()

	print("[SessionReset] === Sesión reiniciada — buff_entities=%d, companions_left=%d, entities_unregistered=%d, remaining_in_characters=%d ===" % [
		registered.size(),
		companions_left,
		unregistered,
		Characters.get_registered_entities().size(),
	])
