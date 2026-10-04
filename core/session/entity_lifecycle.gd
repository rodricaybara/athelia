class_name EntityLifecycle
extends RefCounted

## EntityLifecycle — Baja completa de una entidad en todos los sistemas con
## registro por entidad (Spike 14).
##
## Ruta: res://core/session/entity_lifecycle.gd
##
## Orden fijo: el mismo que usaba PartyManager._unregister_from_systems()
##   Characters → Resources → Skills → Equipment → Inventory
##
## Contrato:
##   - Solo llama a APIs públicas de cada sistema (nunca a variables privadas).
##   - Idempotente: dar de baja una entidad que no existe no produce avisos.
##     Characters.unregister_entity() es el único que avisa si la entidad no
##     existe, por eso se protege con has_entity(). Los otros cuatro sistemas
##     hacen un erase silencioso.
##   - Characters va primero porque emite character_unregistered (Stress
##     escucha esa señal y borra su entrada).
##
## Mismo estilo que AdventureStarter: clase estática, sin estado, sin nodo.
## Los autoloads se acceden por su nombre global (ver project.godot).

static func unregister_everywhere(entity_id: String) -> void:
	if entity_id.is_empty():
		push_warning("[EntityLifecycle] unregister_everywhere() con entity_id vacío — ignorado")
		return

	if Characters.has_entity(entity_id):
		Characters.unregister_entity(entity_id)

	Resources.unregister_entity(entity_id)
	Skills.unregister_entity(entity_id)
	Equipment.unregister_entity(entity_id)
	Inventory.unregister_entity(entity_id)
