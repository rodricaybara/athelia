class_name BagCapacity
extends RefCounted

## BagCapacity — único punto de cálculo de la capacidad de una mochila (Spike 19)
##
## Lo usan InventoryViewModel y PartyViewModel. Cada ViewModel resuelve la
## CharacterDefinition de su entidad y delega aquí SOLO la regla, así que este
## helper no depende de ningún autoload.
##
## Hoy la regla es CharacterDefinition.inventory_slots. Un mecanismo futuro de
## aumento de capacidad (premium, monedas, magia) se añade aquí, en un solo sitio.
##
## Sin definición no se conoce la capacidad: se devuelve used_count (nada se
## marca como desbordado) y se avisa.


## `definition`: definición del personaje (null si no se encuentra).
## `used_count`: pilas ocupadas, usado como valor de reserva.
## `entity_id`: solo para el mensaje de aviso.
static func compute(definition: CharacterDefinition, used_count: int, entity_id: String = "") -> int:
	if definition == null:
		push_warning("[BagCapacity] Sin definición para '%s': no se conoce la capacidad" % entity_id)
		return used_count
	return definition.inventory_slots
