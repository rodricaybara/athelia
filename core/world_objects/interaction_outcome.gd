class_name InteractionOutcome
extends Resource

## InteractionOutcome - Resultado de una interacción según tirada
## Sub-resource embebido en InteractionDefinition
##
## Define QUÉ ocurre para un resultado concreto (critical/success/failure/fumble).
## NO contiene lógica — solo datos declarativos.

## Clave de localización del mensaje de feedback al jugador
@export var feedback_key: String = ""

## ID de la loot table a aplicar (si vacío, no hay loot)
@export var loot_table_id: String = ""

## Clave de información que se revela (pergaminos, inscripciones, etc.)
@export var revealed_info_key: String = ""

## ID de evento narrativo a disparar (si vacío, no dispara nada)
@export var narrative_event_id: String = ""

## ¿Este outcome marca el objeto como agotado (depleted)?
## Si true, el WorldObjectSystem no mostrará más interacciones.
@export var depletes_object: bool = false
