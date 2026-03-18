class_name LootEntry
extends Resource

## LootEntry - Una entrada en una tabla de loot
## Sub-resource embebido en LootTableDefinition

## ID del ítem a entregar (debe existir en ItemRegistry)
@export var item_id: String = ""

## Cantidad a entregar
@export var quantity: int = 1

## Probabilidad de aparición (0.0–1.0, donde 1.0 = siempre)
@export_range(0.0, 1.0) var chance: float = 1.0
