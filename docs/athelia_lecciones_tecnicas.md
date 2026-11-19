# Athelia — Lecciones técnicas y convenciones

Lecciones de motor y de proceso reutilizables, agrupadas por tema. Cada una indica el spike de origen entre paréntesis (el relato completo está en `athelia_historial_spikes.md`).

**Lo que ya está en otros ficheros no se repite aquí:** los antipatrones de UI (autorreferencia por `class_name`, `SceneState`, `closed` frente a `tree_exiting`, razón de `changed()` sin consumidor, panel sin tamaño fijo, `TextureRect` con `expand_mode`, contorno sobre imagen, `PanelContainer` que apila hijos, validar antes de mover, `owner_id` en el arrastre, etc.) están en `athelia_ui_architecture.md`.

---

## Las 15 que más evitan errores

1. **Fase 0 antes de diseñar:** comprobar el código real con `Select-String` (con `-CaseSensitive` si hace falta); la documentación y las specs han descrito el código de forma incorrecta varias veces (S12, S15, S19).
2. **Una transición de `GameState` nueva se verifica contra `VALID_STATE_TRANSITIONS`:** una inválida solo hace `push_warning` y no pasa nada visible (G1, S13).
3. **`push_warning`/`push_error` salen en Depurador → Errores, no en el Output** (S13, S16).
4. **Un campo nuevo en una data class = declaración + `from_dict()` + registry que lo lea, todo en el mismo cambio.** Si falta una parte no hay error de compilación, falla en runtime o se ignora en silencio (S3D, G1).
5. **`Equipment` e `Inventory` son independientes:** quien mueve ítems entre entidades desequipa antes (S19).
6. **La carga sobrescribe, no borra, y un guard `has_entity` que no recrea hereda la entidad vieja:** una sesión nueva exige `SessionReset` antes (S14).
7. **Un flag puesto al DISPARAR una acción no demuestra que se haya GANADO:** las puertas de «lo conseguí» cuelgan de una escena que solo se alcanza al conseguirlo (S13).
8. **Un bloque perdido al parchear un método grande falla en silencio:** todo efecto de un outcome deja una línea de log, y se comprueba por log tras parchear (S10).
9. **Un `.csv` de localización nuevo necesita alta manual en Project Settings;** campos con comas entrecomillados; columnas `id,en,es` (excepto `menus.csv`: `id,es,en`) (S10, S15).
10. **Una clave `tr()` usada y no presente en el CSV sale cruda:** al terminar una View, comparar sus `tr("…")` con las filas del CSV (S19).
11. **Una `class_name` nueva no se resuelve hasta que su fichero existe:** el error sale en el consumidor, no en el fichero que falta. Los ficheros nuevos se entregan antes que los parches que los usan; si un script con `class_name` no compila, su nombre deja de resolverse en todo el proyecto («Identifier not declared» en decenas de ficheros) (G3A, S19).
12. **Antes de sustituir una escena de exploración, buscar quién busca `Player`/grupo `"player"` y qué hijos exige cada script compartido** (S12).
13. **Un comentario que documenta el caso vacío no es código que lo resuelva:** comprobar por separado que el fallback existe (S8).
14. **Dos caminos para construir el mismo evento divergen:** el segundo llama a la API pública del dueño del estado (S8).
15. **Una operación que cambia de dueño un dato valida todo antes y revierte si falla** (S19).
---

## GDScript y Godot

- **Enum anidado en otra clase** (`GameLoopSystem.GameState`): no usarlo como anotación de tipo de variable (falla con «Could not find type»); trabajar con `int` (G3A).
- **`match` sin rama `_:` y array indexado por enum no avisan si el enum crece:** revisar todos los consumidores al extender un enum (S2).
- **Una señal no admite parámetros opcionales,** y un dato que viaja fuera de la señal se lee de estado ambiente con degradación silenciosa si falta. Un punto de entrada nuevo debe pasar explícitamente todo lo que el camino antiguo obtenía por efecto lateral (S12).
- **Una señal con más argumentos en el emisor que en el callback:** GDScript descarta los de más si el callback acepta menos (S11).
- **El orden de conexión de dos nodos a la misma señal no está garantizado;** quien necesita el estado ya resuelto lo consulta directamente (S8).
- **Los setters de `@export` corren al cargar la escena, antes de `_ready()`:** protegerlos con `is_node_ready()` y dejar el estado inicial a `_ready()` (S15).
- **Un aviso dentro de `_draw()` se repite en cada redibujado:** resolver fuera de `_draw()` y una vez por proceso con `static var` (S15).
- **Los alias de constantes apuntan siempre hacia atrás** (el orden de declaración importa) (S15).
- **Nombres de variable que sombrean propiedades de la clase base** (`scale`, `size`, `position`): error con warnings-as-errors (S12).
- **`reload_current_scene()` no destruye nodos añadidos a `get_tree().root`:** `ExplorationScene` y los overlays viven como hermanos de `current_scene`; hay que liberarlos explícitamente (S7).
- **Sin `static` en funciones de autoload** (son instancias).
- **Un `Control` vacío sin `_draw()` no pinta nada,** por bien colocado que esté (G5).
- **Tras `queue_free()` + `await process_frame`, comprobar el estado al reanudar** (S14).
- **Tras `queue_free()` el hijo sigue en el árbol hasta el fin del frame:** para contar filas se usa la lista propia, y se hace `remove_child()` antes (S15, S16).
- **`user://` no es la carpeta del proyecto:** en Windows es `%APPDATA%\Godot\app_userdata\<proyecto>\` (S12).
- **`NOTIFICATION_TRANSLATION_CHANGED` llega a todos los nodos, también a los ocultos:** retraducir ahí (con `is_node_ready()` y el ViewModel ya creado) da cambio de idioma en caliente sin recargar escenas ni cerrar paneles (S23).
- **Un `const` declarado dos veces en un autoload lo deja sin compilar** y arrastra «Cannot infer the type» en todos los consumidores de `UITokens` (decenas de ficheros, y tests): ante ese aluvión, mirar el primer error, no los demás (S23).
- **Un `.tres` solo guarda las propiedades distintas del valor por defecto:** un `@export` nuevo que no aparece en el fichero vale 0 (o su defecto), aunque el inspector parezca mostrar otra cosa o el valor «se haya puesto». Hay que abrir el recurso, ponerlo y guardar (`combat_regen_per_round` en `stamina.tres`) (IA-0b).
- **Un `class_name` comentado en el fichero real y activo en su `_bak` hace que el nombre global resuelva al respaldo:** el código de producción usaba sin saberlo `defense_module_bak.gd` (con un fallo de desbordamiento). Antes de borrar un respaldo, buscar `class_name X` y `#class_name X` en todo el proyecto, activar la clase real y borrar el respaldo después; dos ficheros con el mismo `class_name` activo dan además errores de clase global duplicada (IA-0d).
- **`CharacterDefinition` y los `Resource` que se cargan como `.tres` no tienen `from_dict` ni registry:** un campo nuevo es `@export` + copia en `duplicate_definition()` (+ `validate()` si hace falta) (IA-0d).
- **`Dictionary.make_read_only()` y `Array.make_read_only()` son superficiales** (comprobado en 4.7.2): los contenedores anidados siguen siendo mutables, y un `deep_freeze` recursivo los congela (arrays tipados incluidos). Los `Resource` y los `Packed*Array` no se pueden congelar: un snapshot lleva solo tipos simples (IA-1a).
- **Mutar un contenedor congelado da un error rojo de runtime que aborta la función y no se puede atrapar:** una prueba comprueba `is_read_only()` de forma recursiva y nunca intenta mutar (IA-1a).
- **`duplicate()` de un contenedor congelado devuelve una copia mutable, pero superficial; `Resource.duplicate()` comparte los `Dictionary`/`Array` con el original:** quien entrega copias de un recurso con contenedores (un registry) usa `duplicate(true)`, que separa también los anidados (IA-1a).
- **El estado de un `RandomNumberGenerator` es de 64 bits y no sobrevive a JSON como número:** semilla y estado se exponen y se guardan como texto (`rng_state_string()`), y se reanuda asignando `state` (IA-1a).
- **Un `Array[String]` tipado comparado con un literal sin tipo da falso:** comparar con `",".join(...)` o elemento a elemento (IA-1a).
---

## Datos, registries y localización

- **No asumir que un catálogo escanea subcarpetas:** `SkillSystem`/`ItemRegistry` recursan; `ResourceSystem` no (lista hardcodeada `health`/`stamina`/`gold`); `DialogueRegistry` solo desde el Grupo 2; `InteractiveSceneDB` no. Comprobar el `_load_*` real (G3D, G2, S12).
- **Un registry que construye campo a campo ignora en silencio un campo nuevo del JSON** (`DialogueRegistry._load_option_from_dict()`) (G1).
- **Dos ficheros con el mismo nombre en carpetas distintas se pisan al copiar** (diálogo y escena narrativa del briefing); los diálogos llevan prefijo `dlg_` (S13).
- **`ItemDefinition.item_type` es enum cerrado** (`CONSUMABLE`/`EQUIPMENT`/`MISC`): el botín sin mecánica es `MISC` (G3D).
- **Los `.csv` de Godot resuelven claves duplicadas en silencio (gana la última).** Un borrado masivo de duplicados se hace con simulación previa, copia `.bak` y comprobando que cada fila es idéntica a su primera copia (si difiere, cambia el texto visible) (S15).
- **Textos de habilidades en `skills.csv`** (`SKILL_<ID>_NAME`/`_DESC`); una habilidad sin sus dos claves sale como `SKILL_X_NAME` (S15).
- **Datos específicos de una aventura** en su propia subcarpeta (`data/characters/telmori/`, `data/items/telmori/`), salvo ítems de arma con ranura (por tipo). Localización en un CSV propio por aventura (G3B).
- **Un fichero de iconos genéricos copia el arte;** nunca apunta a la carpeta de una aventura (G4).
- **El kit de skills de una entidad se lee siempre de su `CharacterDefinition`;** una copia paralela se desincroniza al editar el `.tres` (G3B). Los enemigos y refuerzos también (`_get_enemy_kit()`) (IA-0d).
- **`list_known_skills()` son las claves de `starting_skill_values`, no el kit `skills`:** una skill del kit sin valor de habilidad queda invisible para los selectores heredados que usan `list_known_skills()`; se usa a propósito para añadir skills a una IA que aún no debe verlas (las dos de Mira) (IA-0d).
- **Un recurso con máximo derivado no declara su máximo en `starting_resources`:** un dato inerte que parece mandar engaña a quien edita el `.tres`; se quita y se verifica por el log de registro (`Resources.register_entity()` sin lista da de alta todos los recursos) (IA-0d).
- **`reinforcement_definition_id` no admite tipos mixtos:** un refuerzo sale de una única `CharacterDefinition` (G3C).
- **`Inventory.add_item` devuelve `true` aunque pierda datos** (sobrescribe un no apilable ya presente, recorta al `max_stack`, descarta `custom_state`): quien transfiere pre-valida y comprueba la cantidad resultante (S19b).
- **La documentación decía «máximo 2 compañeros» y el código tiene `MAX_PARTY_SIZE = 3`:** una decisión de diseño que vive solo en un documento no es una regla (S19b).
- **Un id de ítem no tiene por qué coincidir con el nombre de su `.tres`:** `Items.get_item()` avisa y devuelve `null` (S19b).
- **`AttributeResolver.resolve()` solo sirve para derivados:** con un atributo base devuelve 0.0 con aviso; para los base se usa `Characters.get_all_base_attributes()` y `get_active_modifiers()` (S22).
- **Que un ítem declare un bono no garantiza que el motor lo aplique:** se comprueba contra los derivados antes de mostrarlo (el `+2 DES` de las botas no cambia la Iniciativa) (S22).
---

## Estado, flujo y señales

- **Un overlay/sub-pantalla anidable no depende de `tree_exiting`:** ver `athelia_ui_architecture.md`. Complemento: un orquestador con `_current_overlay` único debe conectar `closed` de cada overlay, o hay que pulsar la tecla dos veces (S17).
- **Con un orquestador de slot único, el overlay abierto se identifica por `scene_file_path` y se aplica una sola regla:** el propio se cierra, otro ligero se ignora, cualquier otro se cierra (S22).
- **Una pantalla anidada oculta debe seguir consumiendo en `_input` la tecla que cierra a su padre:** si no, el evento llega al orquestador y cierra todo (S22).
- **Si el core no emite señales de un estado, el ViewModel puede sondear con un `Timer` hijo solo mientras está abierto,** con razones distintas para «cambió la lista» (reconstruir) y «cambió el tiempo» (actualizar en sitio) (S22).
- **Un `_unhandled_input()` que dispara overlays comprueba `GameLoop.is_input_blocked()`** (G3).
- **Una señal global de cierre puede destruir un contexto anidado:** `SceneOrchestrator._on_dialogue_ended()` se gateó a `GameState.DIALOGUE` (G2).
- **Instanciar una escena tarde puede dejar huérfanos a listeners que dependen de existir ANTES de un evento:** una señal emitida sin oyente se pierde, sin cola ni replay. Factorizar `_ensure_exploration_scene_instantiated()` (G1).
- **Corregir un orden de instanciación puede exponer una trampa de reentrada:** un guard `if estado != X: transicionar_a(X)` escrito para «arrancar la escena sola» puede disparar una transición real en mitad de otra apertura; la condición correcta era `== MENU` (G1).
- **Un dato que debe sobrevivir a una señal síncrona no se guarda en el recurso que se limpia:** `_pending_victory_scene_id` en `GameLoop`, se consume durante `combat_ended` y se descarta justo después (S13).
- **Una escena narrativa con id inexistente abre un panel vacío sin salida:** validar el id antes de abrir y degradar a `EXPLORATION` (hecho en la ruta de victoria; guarda general pendiente) (S13).
- **Los mensajes `State: A → B` se imprimen después de los logs del handler:** `Handling state: MENU` aparece antes que `State: DEFEAT → MENU` (S14).
- **Reenviar una señal de un autoload a `EventBus` depende de cuántos consumidores reales tiene:** con uno basta reconectar; con varios, puente centralizado en el punto de emisión (S5).
- **Una API pública necesita su propio guard aunque el llamador ya lo tenga:** `request_interaction()` comprueba `is_input_blocked()` y el ViewModel exige además `GameState == EXPLORATION` (`is_input_blocked()` deja pasar `PAUSE` y `MENU`) (S12).
- **El orden de las validaciones define el comportamiento:** la regla que ya está en los datos (`quest_loan`) se consulta antes de la comprobación genérica (`base_value <= 0`) (S16).
- **Un valor nuevo en un `String` de contrato** (`trade_type = "loan"`) solo es seguro si se comprueba quién escucha la señal (S16).
- **Un solo punto de entrada y salida de un estado:** activar y desactivar algo ligado a `COMBAT_ACTIVE` en `_transition_game_state()` cubre victoria, derrota, huida y cualquier cambio directo; emparejar `start_combat()`/`end_combat()` deja fugas si el estado cambia por otro camino (IA-0b).
- **Mismo nombre, dos buses:** `SkillSystem.skill_used` (local) y `EventBus.skill_used` (sin emisor) conviven y el HUD escuchaba la segunda; igual que el puente de `resource_changed` (S5): al conectar una señal, comprobar quién la emite (IA-0b).
- **Un contador, una fuente:** el HUD llevaba sus cooldowns en rondas y `SkillSystem` los suyos en segundos, dos verdades que nunca se hablaban. El dato vive en el sistema y la UI solo lo lee (IA-0b).
- **Refrescar por señal propia, no por orden de conexión:** el sistema emite al terminar de actualizarse (`combat_cooldowns_ticked`) y el HUD se engancha a esa señal, no a `round_started` (IA-0b).
---

## Sesión, guardado y entidades

- **Un guard `has_entity` que no recrea hace que una sesión nueva herede la entidad vieja** (jugador muerto con HP 0 y stats viejos): el guard protege del doble registro, no de la herencia entre sesiones (S14).
- **La carga sobrescribe, no borra:** todo lo que no está en el guardado sobrevive a una carga; el reinicio debe ocurrir antes (S14).
- **La lista de `get_save_state()` es la lista de control de un reinicio:** todo sistema que guarda estado hay que vaciarlo; añadir a mano los diccionarios runtime que no se guardan (`CombatSystem._active_buffs`) (S14).
- **Una baja idempotente necesita guard donde el sistema avisa:** `Characters.unregister_entity()` hace `push_warning` si no existe; los otros cuatro hacen `erase` silencioso (S14).
- **Pasar por `MENU` no limpia al jugador:** lo hace `SceneOrchestrator._handle_main_menu()` + `SessionReset` (S14).
- **Una skill aprendida en runtime se pierde al cargar si `load_save_state()` no puede recrearla** (S10).
- **Un sistema que solo mejora lo que ya existe no cubre «aprender lo nuevo»:** necesita su propio camino de alta (`learn_skill()`) con persistencia (S10).
- **Un consumible con efecto condicional no emite `item_use_success` incondicionalmente:** el consumo cuelga de esa señal (S10).
- **Mover objetos entre entidades invalida las acciones narrativas que asumen el inventario del jugador:** `take_item` falla en silencio (S16).
- **Un `CharacterState.character_name` vacío para toda entidad no-jugador** requiere fallback explícito a `tr(CharacterDefinition.name_key)` (S8).
- **`PartyManager.MAX_PARTY_SIZE` cuenta solo compañeros** (no al jugador): el máximo de 2 es decisión de diseño (S19).
- **Un helper estático (`GameSettings`) comparte la configuración entre ViewModels sin autoload ni core:** `apply_saved()` al arrancar y las intenciones del panel de opciones usan el mismo código, y sin fichero no cambia nada (S23).
- **`playtime_seconds` de `SaveSystem` suma también el tiempo de menú y no se reinicia en una partida nueva:** no se muestra hasta arreglarlo (S23).
- **Una intención que pide una transición a `GameLoop` compara `current_game_state` antes y después:** `enter_*` ignora el `bool` de `request_state_change()`, y si se rechaza nadie emite `game_state_changed`; el ViewModel debe volver por sí mismo a su estado (`MAIN` en el menú, `opened` en el Game Over) (S24).
---

## Combate y narrativa

- **Un listener de `combat_ended` sin desconectar resucita contenido:** cualquier combate posterior reactiva un guard que solo comprueba flag + «¿existe el nodo?». Desconectar al completar el arco (G3C). *(Con el ciclo actual de `combat_victory_scene_id` este patrón ya no se usa; la lección vale para cualquier listener global.)*
- **Un listener filtrado por `flag_name` no necesita desconectarse,** pero un interactuable de recompensa sin retirar permite repetir oro/ítems sin límite: siempre un segundo listener del flag de cierre del arco (G3D).
- **Limpiar un interactuable de reconexión se engancha a `narrative_flag_set`, no a `narrative_scene_closed`:** una escena que encadena a otra por `next_scene_id` no cierra el panel ni emite el cierre con su `scene_id` (G3C).
- **`NarrativeSceneViewModel` y `ExplorationController` pre-registran `Characters`/`Resources` para enemigos, nunca `Skills`:** no asumir que «la entidad ya está registrada» cubre los tres registros (G5).
- **Una escena de prueba nueva usa nombres de `.gd` y `.tscn` distintos a los de producción** (`combat_production_scene.gd`, no `combat_test_scene.gd`) (G5).
- **Todo lo que libere recursos al acabar un combate se difiere (`call_deferred`):** `character_died` → `GameLoop` → `end_combat()` puede dispararse a mitad de una acción y `Combat` sigue leyendo al objetivo y al atacante; dar de baja en el mismo momento dejó `Resources` y `Characters` sin la entidad (IA-0a).
- **Un `await` después de `combat_ended` no es fiable:** `SceneOrchestrator` hace `queue_free()` de `CombatScene` en esa misma emisión y la corrutina de un nodo liberado no continúa; una llamada diferida a una función estática no depende de la escena (IA-0a).
- **El flujo de una petición del jugador es síncrono** (petición → fase → ejecución → posible fallo → recuperación, todo dentro del `emit_signal`): el controlador apaga el input **antes** de emitir, porque la recuperación lo reactiva dentro de esa llamada (IA-0a).
- **Las señales que `Combat` reenvía se filtran por estado de juego:** `skill_failed` también salta con las skills de exploración (IA-0a).
- **Una guarda que sale si «ya está en el estado» no puede ser la que cambia ese estado:** `_incapacitate_player()` salía siempre porque el jugador ya estaba a 0 PV y sus señales no se emitían nunca; la guarda usa un indicador por combate (IA-0a).
- **Un reloj oculto puede sostener una regla de diseño.** La estamina se regeneraba en tiempo real (10/s): el resultado de una pulsación dependía del reloj y enmascaraba que con 0 de regeneración por ronda el jugador se quedaba sin aguante en 3-4 rondas y que un actor de IA sin estamina cuelga el turno. Al quitar un reloj, revisar los datos y los caminos de fallo que tapaba (IA-0a, IA-0b).
- **Dentro del combate, un cooldown se avanza solo por rondas:** `SkillSystem._process` tiene que salir en modo combate, o los segundos reales descuentan además del tick por ronda (valores fraccionarios, la skill libre antes de tiempo) (IA-0b).
- **El golpe que mata termina el combate dentro de `request_use`** (`skill_used` → `GameLoop.end_combat()`): el reseteo de cooldowns ocurre antes del `print` de esa línea y sale `(cooldown 0.0 s)` en la última acción. Es esperado y no es un fallo (IA-0b).
- **Un `Skill not found for entity` al terminar combate** significa que `register_entity_skills()` recibió una lista distinta a `list_known_skills()` (S3B).
- **Una cadena multi-escena cortada antes de tiempo se delata por el `scene_id` de `narrative_scene_closed` en el log** (G3D).
- **Dos sistemas narrativos distintos son fáciles de confundir:** `narrative_event_id` dispara `NarrativeSystem.apply_event()`, no `enter_narrative_scene()` (G3B).
- **Un modificador multiplicativo de combate y un mini-acertijo de objeto sobre objeto se descartaron explícitamente** por falta de un segundo caso real (G3C, G3D).
- **Un combatiente que sale sin morir (`FLED`) sale de todas las listas de objetivos con el mismo criterio:** `PlayerCombatController` seguía apuntando al lobo huido, `Combat` respondía `INVALID_TARGET` y el jugador repetía la misma petición. Se filtra con `Combat.is_fled()` y se escucha `enemy_fled`; releer la lista de `GameLoop` no basta, porque la retirada ocurre después de la señal (IA-0c).
- **Retirar a alguien de `turn_order` mientras se recorre se aplaza hasta cerrar la acción en curso y corrige el índice:** si no, el enemigo siguiente se salta (IA-0c).
- **Una rama genérica que reacciona a la señal de uso de cualquier skill comprueba que la acción en curso es esa skill** (`_pending_skill_context`); hasta IA-0c una skill `SELF` distinta de `dodge` colgaba el turno porque nadie la cerraba (IA-0c).
- **Un daño con una función no lineal (armadura `max(1, daño − armadura)`) se estima grado a grado con las probabilidades de `SkillRoller`, no con un daño medio:** y el camino real llama a las mismas funciones puras, para tener una sola fórmula (IA-0c).
- **Una rama especial se unifica con el constructor genérico declarando en los datos lo que antes deducía por su cuenta:** el buff de `dodge` pasó a `_build_buff()` con `expires_on: "use"` en su `.tres` (el constructor respeta el campo explícito y deduce de `duration` solo si falta), sin cambiar el resultado jugable (IA-0d).
- **Una skill multi-objetivo se resuelve respecto al bando del atacante** (`_get_hit_pool(attacker_id)`): con un conjunto fijo («los enemigos») un barrido enemigo golpearía a sus propios compañeros; el fallo es latente hasta que existe una skill así, y se prueba con una skill real leída de su definición, no con el tipo supuesto (`sweep` es `MULTI_ENEMY`, no `AREA`) (IA-0d).
- **Una prueba con entidades inventadas hereda las reglas de bando del sistema que prueba:** tras hacer `_get_hit_pool()` relativo al atacante, `ia0c_test` rompió porque su barrido lo lanzaba un aliado; se ajustó a un atacante no aliado y el caso de aliado lo cubre `ia0d_test` (IA-0d).
- **Un módulo de defensa debe calcular el desbordamiento antes de gastar el recurso:** si resta primero y `ResourceState` recorta a 0, el exceso nunca se detecta y la defensa absorbe gratis (IA-0d).
- **Un dato que la IA necesita y el sistema solo tiene privado se expone con un envoltorio público mínimo, no leyendo el miembro privado:** `Combat.get_side()` y `get_combatant_ids()` envuelven `_is_ally()` y la misma lógica de `_get_opponents()`; la lógica queda duplicada y se anota para unificarla. La prueba de contrato escanea `core/ai/` buscando `\b(Combat|GameLoop|Party|Resources|Characters|Skills)\._[A-Za-z]` (IA-1a).
- **Un estado que vive por combate y otro por combatiente son dos objetos:** el RNG de IA es por combate y el perfil por combatiente, así que un contexto por combate (`CombatAIContext`) reúne ambos; lo crea y libera la escena de combate, que ya spawnea cada IA (también los refuerzos) (IA-1a).
---

## UI y Design System (solo lo no cubierto en ui_architecture)

- **Un componente del DS lee sus propiedades en `_ready()`:** fijar `variant`, `btn_size`, `min_square`, `icon_backdrop` antes de `add_child()`; un `custom_minimum_size` previo se pisa en parte (S13).
- **Una raíz que `extends UIPanel` fija `padding` antes de `super._ready()` y siempre llama a `super._ready()`** (S16, S18).
- **Tipar un `@onready` con la clase del componente delata una instancia equivocada:** falla en `@implicit_ready` con «Trying to assign value of type 'Button'…» (S16).
- **Un `Label` con elipsis tiene anchura mínima 0:** poner un suelo de anchura o expandir el contenedor (S16).
- **Estado visual por fila con tokens y `disabled`, no con `modulate` del contenedor** (S16).
- **No comprobar métodos por nombre** (`has_method("_update_display")`): método público explícito (S16).
- **Mensajes con altura reservada:** vaciar el texto en lugar de ocultar el `Label` (S16).
- **`mouse_exited` llega al padre al entrar en un hijo:** comprobar `get_global_rect()` antes de apagar el hover (S16).
- **`ScrollContainer` + `size_flags_vertical = 3` reparte el hueco a partes iguales:** reservar la altura natural con `custom_minimum_size` (S15).
- **Un margen en píxeles atado a un hermano proporcional se rompe al cambiar de tamaño:** calcular desde el borde real del hermano y recalcular en `resized` (S15).
- **Sin foco inicial, el teclado no tiene a quién llegar:** `grab_focus()` diferido; el estilo `focus` por defecto puede recortarse, usar el `hover` del propio botón (S15).
- **`stretch/mode = canvas_items` ablanda el texto (≈15 %):** descartado. Verificar que la configuración se guardó (`Select-String` sobre `project.godot`) antes de medir un experimento (S15).
- **Un icono claro sobre fondo claro no destaca por sí solo:** disco oscuro o interior más oscuro en el arte (S13).
- **Un panel proporcional sin tamaño máximo se ve vacío a pantalla completa:** tope + centrado + fondo opaco con `mouse_filter = STOP` (S18).
- **Una etiqueta bajo cada slot de equipo no cabe en 648 de alto con seis slots:** va dentro del slot (S18).
- **Una rejilla con columnas variables usa el ancho real del `ScrollContainer` menos una reserva para la barra de scroll** y un pool de slots (S18).
- **Lo que no cabe en la capacidad se muestra con borde de desbordamiento, no se descarta** (S18).
- **Los bonos de equipo suman solo `add`;** `mul` y `override` no se pueden sumar sin ambigüedad. Las estadísticas mostradas son valores **base** (S18).
- **Un `.tscn` creado a mano sin UID:** Godot lo regenera y avisa; es inofensivo (S18). Lo mismo un `.tres` de skill sin `uid` en la cabecera (IA-0d).
- **Una clase interna de la View (`ColumnView`) evita duplicar el pintado de dos columnas idénticas** (S19).
- **Una View puede pintar sin `ItemInstance`:** `UISlot.set_definition(definition, quantity)` basta (S19).
- **Un widget con ocultado automático lleva su propio `Timer` hijo:** un mensaje nuevo reinicia la cuenta (S17).
- **`ui_cancel` se consume con `set_input_as_handled()` en la propia pantalla;** el input no manejado se propaga de hijo a padre, y en anidado cierra la capa más profunda (S17).
- **El puente de ítems emite `item_use_success` también al equipar:** el mensaje de «equipado» sale del evento de equipo (S17).
- **Un snapshot de mochila no asume que el equipo sale del inventario:** un ítem equipado aparece también en la mochila (S17).
- **Un ViewModel nuevo no se instala antes que su View** si la View antigua usa su API (el proyecto dejaría de compilar): se entregan juntos; lo que se puede validar antes (un `.csv`) se instala aparte (S19).
- **Al reconstruir un ViewModel muerto, comprobar qué cubre frente a lo que hace la pantalla real** (S17).
- **Dos compañeros de prueba con la misma definición se llaman igual:** para probar pestañas, nombres distintos (S19).
- **Un componente compartido gana una señal nueva y mantiene la antigua** (`slot_item_dropped` tras `slot_drop_received`) (S19).
- **Un control con anclas opuestas distintas ignora `size`** y avisa en cada cambio: se mueve `offset_right` (o `offset_bottom`); la animación también apunta a la propiedad `offset_*`, no a `size:x` (S19b).
- **Un componente sin consumidores previos esconde defectos en su `.tscn`** (raíz `visible = false`, relleno de 40 px fijos, ancho calculado antes del layout): al adoptarlo se revisa la escena además del script (S19b).
- **`tr()` no existe en funciones estáticas:** un helper que traduce es una instancia `RefCounted` (S19b).
- **Extraer un cálculo compartido entre dos ViewModels obliga a mover sus clases de datos a un fichero propio:** si siguen siendo internas de uno, el helper y el ViewModel se referencian en círculo (S19b).
- **Un recurso que se regenera (estamina) emite sin parar:** va con razón propia agrupada por frame, no repinta la pantalla entera (S19b).
- **Resaltar los destinos de un arrastre** se hace desde `NOTIFICATION_DRAG_BEGIN/END` con `gui_get_drag_data()`, y es opt-in: un slot que acepta cualquier cosa resaltaría siempre (S19b).
- **Un `Label` ignora el ratón:** para un tooltip, `mouse_filter = STOP` (S19b).
- **El estado de selección vive en el ViewModel y un error de asignación no lo limpia:** si lo hace la View, cambia el estado sin repintar y la pantalla miente (S20).
- **Una acción destructiva no se esconde en un segundo clic:** botón explícito; el clic sobre lo ya seleccionado solo deselecciona (S20).
- **Filtrar los candidatos por compatibilidad en vez de listar todo y rechazar** vuelve inalcanzables los errores de asignación; se conservan como salvaguarda del ViewModel, y no se pueden validar desde la interfaz (S20).
- **Un clic que nace en un nodo que el repintado destruye** exige repintado diferido (`call_deferred`) (S20).
- **Una View que muestra costes de recursos traduce `RESOURCE_<ID>_NAME` con fallback a `id.capitalize()`:** un recurso sin clave (`focus`) no sale crudo, pero conviene darla de alta (S20).
- **Dos líneas (etiqueta + nombre) caben donde una sola línea con todo no:** para tarjetas anchas con dos datos, apilarlos (S20).
- **`UIResourceBar` fija su alto mínimo en 14 px en su `_ready()`:** una barra fina se rebaja después de ese `_ready` (en el `_ready()` del padre; si la barra se añade más tarde, `bar.ready.connect(…, CONNECT_ONE_SHOT)`) (S21).
- **Un `Label` con elipsis junto a otro `Label` expansivo se queda sin sitio (ancho mínimo 0):** los valores cortos (porcentajes, cantidades) llevan `OVERRUN_NO_TRIMMING`; el elástico es el nombre (S21).
- **Un `UIButton` `PRIMARY` deshabilitado es ilegible:** la View cambia a `SECONDARY` mientras esté deshabilitado (el arreglo de raíz está en el componente y afecta a todas las pantallas) (S21).
- **Seleccionar no repinta:** cambiar la selección actualiza el estilo de las fichas existentes; repintar la lista pierde el scroll. Cuando hay que repintar, se guarda el scroll y se restaura tras `await get_tree().process_frame` (S21).
- **Informar del resultado real del core, no de que la llamada no falló:** `execute_learning_session` devuelve `improved`/`roll_failed`/…; mostrar «Mejoró» tras una tirada fallida miente (S21).
- **Una definición única de «puede hacerse» en el ViewModel** (`is_trainable`) y un motivo con prioridad; la View ni la recalcula ni la reordena (S21).
- **Un coste ≤ 0 no se muestra** («Coste: 0 Estamina» en una habilidad pasiva) (S21).
- **Un componente de pantalla de solo script (`PlayerMenuRow`) evita `Label.new()` en la View** y permite actualizar en sitio sin crear nodos (S22).
- **Las acciones con `physical_keycode` se muestran con `DisplayServer.keyboard_get_keycode_from_physical()`:** si no, la letra mostrada depende de la disposición del teclado (S22).
- **`UIResourceBar` pinta su valor a 10 px:** para un texto legible, «actual / máx» va en una etiqueta aparte (S22).
- **Centrar un panel que sigue a su contenido:** anclas al centro + `grow_horizontal/vertical = BOTH` + offsets a 0. `set_anchors_and_offsets_preset(…, MINSIZE)` congela los offsets con el mínimo provisional del momento (paneles descentrados, un modal que se estira en vertical) (S23).
- **Un `Label` con `autowrap` en un modal corto puede dar un mínimo enorme si se mide antes de recibir su ancho:** sin autowrap en textos cortos de modales (S23).
- **Una View con subpaneles oculta la columna de botones mientras hay un subpanel** (velo + foco): si solo se apaga con un velo, los botones de detrás siguen enfocables por teclado y se ven al fondo (S23).
- **Un panel anidable con señal `closed` y sin autoliberación sirve para varios huéspedes:** `OptionsPanel` vive hoy en el menú principal y mañana puede vivir en un menú de pausa sin cambios (S23).
- **Al volver al panel principal, el foco vuelve al botón que abrió el subpanel,** y en un modal destructivo empieza en la acción segura (Cancelar) (S23).
- **Un control de opciones sin sistema detrás no se enseña:** los sliders de volumen no controlaban nada porque no hay buses ni audio. se dejan en la escena, ocultos tras una constante, y se anota el pendiente (S23).
- **Un `Control` con `mouse_filter = IGNORE` (`TitleBackdrop` y sus hijos) deja pasar los clics:** la pantalla que debe bloquearlos pone `STOP` en su instancia, sin tocar el componente compartido (S24).
- **Un valor de escena que el script sobrescribe en `_ready()` es un literal muerto** (el color del `Backdrop` de inventario y Party): ensucia la auditoría de `Color(` y se quita del `.tscn` (S24).
- **Un botón con ancho por fracción de pantalla (`custom_minimum_size.x` desde la View, recalculado en `size_changed`) y `SHRINK_CENTER` no depende del idioma ni del texto** (S24).
- **Una pantalla que arranca oculta y la muestra el orquestador se previsualiza con una escena temporal en `test/`** (con una constante de idioma); la retira el propio spike (S24).
---

## Proceso y herramientas

- **Cuando una spec da una hipótesis como causa, reproducir antes de arreglar** (16c) (S19). Las cifras de una spec se comprueban contra el árbol de nodos real (S15).
- **Una línea que falta en el Output delata un bug:** comparar el Output con la secuencia esperada, no solo buscar errores (S19). En IA-0b la ausencia de `🔋` y de `disponible de nuevo` en el log reveló el campo sin guardar y el parche omitido.
- **Los parches «buscar → sustituir» usan anclas de una sola línea:** las de varias líneas fallan con tabuladores y finales de línea de Windows, y un ancla mal aplicada puede borrar otra línea sin aviso (IA-0a).
- **Para renombrar una señal, buscar `emit_signal("x"`, `x.emit(` y `x.connect(` por separado:** el HUD de combate emitía con `.emit({` y la primera búsqueda no lo vio (IA-0a).
- **Los parches «buscar → sustituir» comprueban que el ancla aparece exactamente una vez y no asumen la sangría;** en funciones largas, vigilar las comas al añadir claves a un diccionario. Mismo criterio para parchear documentación (S18, S19, S16).
- **Un script de PowerShell 5.1 sin BOM corrompe los acentos literales:** escribirlos con `[char]0xE9` o mantener el script en ASCII; los CSV se leen y escriben como UTF-8 conservando BOM y saltos de línea (S15).
- **Las rutas relativas de .NET (`[IO.File]::…`) se resuelven contra `C:\Windows\system32`, no contra `Get-Location`:** un script de PowerShell las construye con `Join-Path (Get-Location) …`. Y un bloque de GDScript pegado en la consola pierde las tabulaciones: el código va al editor, no a un here-string (IA-0d).
- **`Select-String` no distingue mayúsculas por defecto:** `Items\.` casa con `bag_items.`; para auditar el contrato MVVM usar `-CaseSensitive` (S17). Un patrón también casa con líneas preexistentes parecidas: contar bien el número esperado de coincidencias antes de dar un parche por mal aplicado (IA-0d).
- **`Get-ChildItem data\characters\*.tres` no entra en subcarpetas:** para localizar un recurso usar `-Recurse` (`companion_mira.tres` está en `companions/`) (IA-0d).
- **Una prueba aislada de un componente con ítems de respaldo** evita depender del estado del juego (`ui_slot_drag_test`) (S18).
- **Un script de depuración temporal (autoload con teclas) permite probar casos que el juego no produce** (0 y 2 compañeros), pero sus acciones destruyen estado: no se guarda con él activo, se restaura el guardado después y se retira (con su autoload) antes de cerrar el spike (S19).
- **Un dato de prueba de un spike anterior altera la siguiente validación** (`inventory_slots` reducido, `Huecos 6/7`): devolverlo a su valor real (S19).
- **Un spec puede dar por hecho un comportamiento que nadie implementó** (Esc en el inventario): comprobar con `Select-String 'ui_cancel'` antes de validar (S17, S20: Esc en el Loadout).
- **Un contexto de apertura sin llamadores ni acción de input no se puede validar en partida:** se verifica por inspección y se registra como código muerto (`open_loadout()`) (S20).
- **Un conteo de claves o de campos en una spec se comprueba contra el código** (6 `LOADOUT_ERROR_*` en la spec, 7 en el código) (S20).
- **Una prueba con un id mal escrito se hace a propósito** para validar el fallback (S13).
- **Un script de reinicio con simulación previa y copia `.bak`** antes de cualquier borrado masivo (S15).
- **Las teclas F5-F8 son atajos del editor** (F8 detiene la ejecución, F5 la lanza): las herramientas de depuración usan otras (Insert, Inicio) (S19b).
- **Una hipótesis de la spec se prueba con un caso que de verdad la ejerza:** la primera prueba de la 16c tenía la lanza en el jugador y funcionaba; el fallo solo aparece con ella en un compañero (S19b).
- **Seis parches en un mismo fichero se entregan como fichero completo:** un parche mal colocado da un error de compilación en un sitio que no es el del cambio (S19b).
- **Una herramienta de depuración que mete el juego en estados imposibles** (lanza prestada en un compañero tras bloquearlo en la interfaz) es la única forma de probar una corrección de compatibilidad con partidas antiguas (S19b).
- **Un parche de un fichero lleva un único camino:** dos instrucciones solapadas (un parche con ancla y un bloque «pégalo al final») dejan constantes duplicadas. Si una ancla no coincide, se comprueba primero qué hay (`Select-String`) antes de pegar nada (S23).
- **El editor ejecuta el juego incrustado en la pestaña Game, que solo admite modo ventana** («Embedded window only supports Windowed mode»): la pantalla completa se prueba con el juego en ventana propia o exportado (S23).
- **Una comprobación del paquete Fase 0 con `Select-String` sobre las líneas clave (`_feedback_timer`, `consume_pending_quickload`) confirma si el paquete adjunto coincide con el código actual** antes de fiarse de él (S23).
- **Quitar un nodo de depuración referenciado por `$Nombre`:** primero el script (`@onready` y usos), después los `.tscn`; al revés da error al cargar (S24).
- **Tras aplicar un parche, comprobar con `Select-String` que su identificador nuevo está en el fichero antes de probar:** una prueba «ok» no demuestra que el cambio estuviera aplicado (el `_recover_if_transition_rejected()` del menú, S24; el `if _combat_mode: return` de `SkillSystem._process`, IA-0b, que se delató porque el número de línea de `process_cooldown` no coincidía con el esperado).
- **Un setter temporal con `print_stack()` sobre el campo sospechoso** (`current_cooldown`) dice quién lo cambia sin leer todo el código; se retira al cerrar el spike (IA-0b).
- **Los cambios temporales de validación llevan una marca fija (`TEMPORAL IA-0c`, `TEMPORAL IA-0d`) y su retirada se comprueba con `Select-String` sobre la marca y sobre `seed(`** antes de cerrar el spike (IA-0c, IA-0d).
- **Una comparación de cifras con semilla solo vale con el mismo estado inicial completo:** si cada ejecución crea un personaje distinto, no es comparable; la prueba automática con ids de definición fijos sí (IA-0c).
- **Una prueba de Monte Carlo silencia el Output (`Engine.print_to_stdout = false`) y lo restaura al terminar;** usa ids de definición reales (`companion_mira`, `telmori_wolf_base`; el jugador no tiene `.tres`) (IA-0c).
- **Una prueba automática lee los datos reales en lugar de suponerlos** (tipo de objetivo de `sweep`, kit de cada enemigo): una prueba que asume el dato falla por la suposición y esconde si el código está bien (IA-0d).
- **`Resources.get_resource_state` da error si el recurso no existe:** una comprobación silenciosa (costes de las candidatas) usa `has_resource` (IA-0c).
- **Un `print` al cargar un recurso con el valor leído** (`Loaded definition: stamina (combat_regen_per_round=…)`) separa «dato no guardado» de «código equivocado»; es inocuo y se queda (IA-0b).
- **Un patrón de auditoría amplio (`Label.new`) da falsos positivos en listas dinámicas:** el que cuenta es `Color\(|modulate`; los ficheros `*_test*` y `*_bak*` se filtran por nombre, no solo por carpeta (S24).
- **Un informe puede listar como pendiente algo que ya no existe** (`DebugPartyTool`): comprobar antes de planificar su retirada (S24).
- **Una sonda `EditorScript` (Ctrl+Shift+X) con líneas `[PASS]/[FAIL]/[INFO]` contrasta hipótesis de motor** (congelado, `duplicate`, RNG) antes de diseñar sobre ellas; es temporal, marcada `TEMPORAL IA-<x>`, y se borra al cerrar. En una sonda no se pueden usar métodos de comprobación por nombre sobre tipos nativos (`PackedStringArray.has_method` da error) (IA-1a).
- **Un registry de recursos exige que el id coincida con el nombre del fichero:** así copiar un `.tres` no crea duplicados silenciosos, y la prueba de carga usa un directorio temporal en `user://` con casos buenos y rechazados (IA-1a).
- **En una prueba, una línea `[SKIP]` no es un fallo de código:** significa que no se pudo preparar el escenario (por ejemplo, no hay protagonista); se informa y se pregunta, no se da por buena (IA-1a).
---

## Convenciones de ficheros

- `*_bak.gd`/`*_bak.tscn` son backups; `.gd.uid` es metadato de Godot. `_definition.gd` = Resource estático; `_state.gd` = Resource runtime; `_system.gd` = sistema lógico (autoload o manager). `test/` y `debug/` no se usan en producción.
- Main Scene del proyecto: `res://ui/main_menu/main_menu_screen.tscn`.
- La localización cubre ES y EN: CSV compilados a `.translation`.
