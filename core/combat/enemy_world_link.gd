extends Node

## EnemyWorldLink — Spike 3, Grupo A
## Singleton: /root/EnemyWorldLink
##
## Hueco genérico para que cualquier sistema que haya dado a un enemigo de
## combate una representación en la capa de exploración/world objects pueda
## limpiarla cuando ese enemigo huye del grupo (EventBus.enemy_group_fled).
##
## GameLoopSystem no sabe que esto existe — emite enemy_group_fled con los
## IDs de quien huye y nada más. Este bridge tampoco sabe qué es "una
## representación de mundo": guarda un Callable por entity_id y lo invoca
## sin necesidad de conocer WorldObjectSystem, un nodo concreto, ni nada más.
## Si nadie registró nada para un entity_id, no pasa nada (no-op).
##
## Construido en Grupo A sin ningún caso de uso real todavía — lo ejercerá
## la emboscada/guarida concreta de Grupo B o C, que llamará a
## register_fled_cleanup() al dar de alta la representación del enemigo en
## la escena de exploración.

## entity_id: String -> Callable
var _cleanup_by_entity: Dictionary = {}


func _ready() -> void:
	if EventBus:
		EventBus.enemy_group_fled.connect(_on_enemy_group_fled)
	else:
		push_error("[EnemyWorldLink] EventBus autoload not found!")


## Registra cómo limpiar la representación de mundo de un enemigo si huye.
## Quien registra decide qué significa "limpiar" (queue_free, ocultar,
## desregistrar de WorldObjectSystem...) — este bridge no lo necesita saber.
## Una segunda llamada para el mismo entity_id sustituye el cleanup anterior.
func register_fled_cleanup(entity_id: String, cleanup: Callable) -> void:
	_cleanup_by_entity[entity_id] = cleanup


## Retira el registro sin invocar el cleanup — para el caso de que el
## enemigo muera en combate normal en vez de huir, y quien lo registró
## necesite desengancharlo sin esperar a un flee que no va a llegar.
func unregister(entity_id: String) -> void:
	_cleanup_by_entity.erase(entity_id)


func _on_enemy_group_fled(fled_enemy_ids: Array[String]) -> void:
	for entity_id in fled_enemy_ids:
		if _cleanup_by_entity.has(entity_id):
			_cleanup_by_entity[entity_id].call()
			_cleanup_by_entity.erase(entity_id)
