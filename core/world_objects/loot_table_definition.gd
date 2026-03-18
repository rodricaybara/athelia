class_name LootTableDefinition
extends Resource

## LootTableDefinition - Tabla de loot referenciada por InteractionOutcome
## Equivalente arquitectural a ShopDefinition o ItemDefinition.
##
## Define QUÉ ítems puede entregar una interacción exitosa.
## La resolución (tirar dados, filtrar por chance) la hace WorldObjectSystem.

## Identificador único de la tabla (ej: "chest_iron_normal", "chest_iron_rich")
@export var id: String = ""

## Entradas de la tabla
@export var entries: Array[LootEntry] = []


func validate() -> bool:
	if id.is_empty():
		push_error("[LootTableDefinition] id cannot be empty")
		return false

	for entry in entries:
		if entry.item_id.is_empty():
			push_error("[LootTableDefinition] entry with empty item_id in table '%s'" % id)
			return false
		if entry.quantity < 1:
			push_error("[LootTableDefinition] entry quantity must be >= 1 in table '%s'" % id)
			return false

	return true
