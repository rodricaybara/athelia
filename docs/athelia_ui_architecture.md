# Athelia — Guía de Arquitectura UI
 
Estado vigente del patrón MVVM, el Design System y las pantallas. La historia de
cada spike vive en `athelia_historial_spikes.md` y en `docs/spike_N.md`.
 
## Índice
 
1. Filosofía general
2. Patrón MVVM simplificado
3. Estructura de archivos
4. Ciclo de vida
5. Contrato del ViewModel
6. Contrato de la View
7. Cómo crear un nuevo panel UI
8. Reglas que no se rompen
9. Antipatrones conocidos
10. Design System (`UIPanel`, `UIButton`, fila de lista, `UISlot`)
11. Contrato de pantalla y resolución de referencia
12. Contextos de apertura (inventario, Party)
13. Referencia de pantallas existentes
---
 
## Filosofía general
 
- **La View no decide nada.** Renderiza el estado del ViewModel y traduce input en llamadas al ViewModel.
- **El ViewModel no renderiza nada.** Gestiona estado, coordina sistemas y expone datos listos para pintar.
- **Los sistemas core son invisibles para la View.** `Inventory`, `Equipment`, `Characters`, `Resources`, `Dialogue`, `Party`… nunca se tocan desde el `.gd` de la View.
---
 
## Patrón MVVM simplificado
 
```
SISTEMAS CORE (Inventory, Equipment, Resources, Dialogue, Party...)
        │ EventBus signals
        ▼
VIEWMODEL (nombre_viewmodel.gd)
  - enum de estados, data classes (snapshots para la View)
  - escucha EventBus → actualiza estado
  - datos públicos (read-only para la View)
  - signal changed(reason: String)
  - intenciones: request_X(), select_X()
        │ changed(reason)
        ▼
VIEW (nombre_panel.gd / nombre_screen.gd)
  - @onready de nodos del .tscn
  - _on_vm_changed(reason) → match → _render_X()
  - input del jugador → _vm.request_X()
  - nunca accede a sistemas core
```
 
---
 
## Estructura de archivos
 
```
ui/nombre_pantalla/
├── nombre_viewmodel.gd     ← lógica y estado
├── nombre_panel.gd         ← renderizado y input
└── nombre_panel.tscn       ← estructura de nodos
```
 
| Tipo | Ejemplo |
|------|---------|
| ViewModel | `inventory_viewmodel.gd` (`class_name InventoryViewModel`) |
| View script / scene | `inventory_ui.gd` / `inventory_ui.tscn` |
 
---
 
## Ciclo de vida
 
```
SceneOrchestrator
  → instancia el .tscn y lo añade al árbol (_ready())
      → la View crea el ViewModel como hijo: add_child(_vm)
      → el ViewModel se conecta al EventBus en su _ready()
      → la View se conecta a _vm.changed
  → SceneOrchestrator llama open() o show_X_direct() en la View
      → la View delega a _vm.open() / _vm.init_with_snapshot()
          → el ViewModel emite changed("opened") → la View renderiza
 
Al cerrar:
  → la View llama _vm.request_close() → changed("closed") → visible = false
  → SceneOrchestrator (o quien la instanció) hace queue_free() al recibir `closed`
      → el ViewModel muere como hijo; señales desconectadas
```
 
**Regla crítica:** el ViewModel es siempre hijo de la View. Nunca autoload ni referencia externa.
 
### Caso especial: MainMenuScreen (Main Scene persistente)
 
No la instancia `SceneOrchestrator`; arranca directamente y nunca se destruye.
 
```
_ready() → crea MainMenuViewModel como hijo → conecta botones → _vm.open() → changed("main")
 
Nueva partida:  _vm.request_new_game() → changed("transitioning") → await process_frame
                → GameLoop.enter_character_creation()
Cargar partida: _vm.request_load_game() → SaveManager.load_game("quicksave")
                → GameLoop.enter_post_load_state(): escena narrativa guardada si la hay, si no EXPLORATION
Volver a MENU desde cualquier estado: EventBus.game_state_changed(MENU)
                → _on_game_state_changed() → open() → changed("main")
```
 
**Regla derivada:** el ViewModel de una View que es Main Scene persistente **debe** escuchar `EventBus.game_state_changed` en su `_ready()` y reaccionar al entrar y al salir de su estado. Puede volver a ese estado por un camino que no pasa por su código (sin el listener se quedaba para siempre en `TRANSITIONING`).
 
`DEFEAT` no transiciona directo a `CHARACTER_CREATION`. Desde el Spike 14, Game Over lleva al menú principal y `SessionReset` deja la sesión limpia (pasar por `MENU` por sí solo no limpia nada: lo hace `SceneOrchestrator._handle_main_menu()` + `SessionReset`).
 
---
 
## Contrato del ViewModel
 
### Estructura mínima
 
```gdscript
class_name MiPantallaViewModel
extends Node
 
# 1. Enum de estados. NUNCA "SceneState" (clase nativa del motor): usar PanelState u otro.
enum PanelState { HIDDEN, SHOWING }
 
# 2. Señal única hacia la View
## Razones: "opened" → todo · "datos" → sección · "closed" → ocultar
signal changed(reason: String)
 
# 3. Estado público: lo lee la View, nunca lo escribe
var state: PanelState = PanelState.HIDDEN
 
# 4. _ready(): conectar al EventBus
func _ready() -> void:
    EventBus.alguna_señal.connect(_on_alguna_señal)
 
# 5. Intenciones llamadas desde la View
func open() -> void: ...
func request_close() -> void: ...
 
# 6. Callbacks del EventBus: privados
func _on_alguna_señal(...) -> void: ...
```
 
**Regla derivada:** una razón nueva de `changed()` gana su caso en la View **en el mismo cambio**. Un ViewModel validado con fixtures aisladas no garantiza que la View lo consuma.
 
### `await` en el ViewModel
 
Única excepción permitida: `await get_tree().process_frame` antes de una transición de escena, para que la View procese `"transitioning"` y deshabilite botones. Nunca `await` en la View.
 
### Data classes
 
Clases internas ligeras para snapshots (`SlotData`, `ColumnData`…). Una data class en **fichero propio con `class_name`** nunca se autorreferencia por nombre en sus factory methods: usar `new()` a secas (GDScript no lo resuelve y rompe la resolución del tipo en otros ficheros). Las clases internas anidadas no tienen este problema.
 
```gdscript
static func from_dict(data: Dictionary) -> NarrativeSceneOutcome:
    var outcome := new()      # no NarrativeSceneOutcome.new()
```
 
Un campo nuevo en una data class necesita declaración + asignación en `from_dict()` + lectura en el registry/parser (que a veces construye campo a campo), todo en el mismo cambio.
 
### Composición de ViewModels
 
Cuando una pantalla necesita todo un ViewModel existente más estado propio, el nuevo **compone** al existente como hijo (no se duplica ni se fusiona). Ejemplo: `CombatArenaViewModel` compone `CombatHudViewModel` como `action_menu`. La View se conecta a **las dos** señales `changed` (`_vm.changed` y `_vm.action_menu.changed`); olvidar la segunda no da error, solo deja sin renderizar la parte compuesta.
 
### Tipado estricto
 
Nunca `:=` con `.get()` de diccionarios ni con nulos potenciales (infiere `Variant`; warnings = errores):
 
```gdscript
var used: int = snapshot.get("slots_used", 0)    # no: var used := snapshot.get(...)
```
 
---
 
## Contrato de la View
 
```gdscript
extends CanvasLayer          # o Control
class_name MiPantalla
 
@onready var mi_label: Label = %MiLabel       # nodos por nombre único
var _vm: MiPantallaViewModel = null
 
func _ready() -> void:
    visible = false
    _vm = MiPantallaViewModel.new()
    _vm.name = "ViewModel"
    add_child(_vm)
    _vm.changed.connect(_on_vm_changed)
 
func _on_vm_changed(reason: String) -> void:
    match reason:
        "opened": _render_todo()
        "closed": visible = false
        _: push_warning("[MiPantalla] Razón desconocida: %s" % reason)
 
func open() -> void:
    _vm.open()
```
 
- **Feedback temporal:** `SceneTreeTimer` con referencia (desconectar el anterior antes de crear otro) o un `Timer` hijo; nunca `await` en la View.
- **Textos:** siempre `tr("CLAVE")`, asignados por código (`_setup_static_text()`); labels y botones vacíos en el `.tscn`. Claves en el `.csv` de la pantalla, formato `PANTALLA_ELEMENTO`.
---
 
## Cómo crear un nuevo panel UI
 
1. **Carpeta** `ui/nombre_pantalla/`.
2. **Diseñar el ViewModel** antes de codificar: estados (enum), datos y data classes, señales del EventBus que escucha, intenciones `request_X()`, razones de `changed()` documentadas.
3. **Implementar el ViewModel** (`nombre_viewmodel.gd`) según el contrato.
4. **Crear el `.tscn`** con `%UniqueNames`; sin lógica en el inspector. Si puede mostrar texto largo real, anclar el contenedor raíz a un tamaño explícito desde el principio.
5. **Implementar la View** (`nombre_panel.gd`) según el contrato.
6. **Registrar en `SceneOrchestrator`** si es overlay (`const OVERLAY_X := "res://ui/..."` + handler o `open_X()`). Si necesita su propio `GameState`, el `id` de datos viaja por `_pending_context` (`GameLoop.request_state_change(state, {"id": ...})`) y se lee en `_on_game_state_changed()` igual que `dialogue_id`/`shop_id`.
7. **Claves de localización** en el `.csv` de la pantalla (alta manual en Project Settings → Localization → Translations).
---
 
## Reglas que no se rompen
 
| Regla | Motivo |
|-------|--------|
| La View nunca accede a sistemas core | Acoplamiento |
| El ViewModel nunca instancia nodos | Es lógica de presentación |
| `changed(reason)` es la única señal del VM hacia la View | Menos acoplamiento View↔VM |
| El ViewModel es siempre hijo de la View | Muere con ella; señales se desconectan solas |
| Sin `await` en la View; en el VM solo antes de cambiar escena | Bloquea el estado |
| Sin flags implícitos en la View | El estado es el enum del ViewModel |
| Tipado estricto | Warnings tratados como errores |
| Sin `static` en funciones de autoload | Son instancias |
| Variables que no colisionan con propiedades de Node (`btn_size`, no `size`; ni `scale`/`position` como locales en scripts de `Control`) | `SHADOWED_VARIABLE_BASE_CLASS` es error |
| El enum de estados nunca se llama `SceneState` | Colisiona con clase nativa |
| `class_name` en fichero propio sin autorreferencia en factories | Ver «Data classes» |
| Textos siempre vía `tr()`; labels vacíos en el `.tscn` | Localización |
| ViewModel de Main Scene persistente escucha `game_state_changed` | Puede volver a su estado por un camino externo |
| Contenedor raíz con texto largo real lleva tamaño/anclaje explícito | Sin él, el autowrap no tiene ancho |
| Razón nueva de `changed()` = caso nuevo en la View, mismo cambio | Si no, cae en `_:` sin error |
| Overlay/subpantalla anidable expone `closed`, nunca depende de `tree_exiting` | Ninguna pantalla se auto-libera |
| `_unhandled_input()` que dispara overlays comprueba `GameLoop.is_input_blocked()` | Si no, procesa el evento en cualquier `GameState` |
| Opción visual nueva de un componente compartido del DS entra apagada por defecto | Ninguna pantalla cambia de aspecto sin decisión explícita |
| Un overlay del orquestador que expone `closed` tiene su oyente en `SceneOrchestrator` | Con slot único, una pantalla oculta pero no liberada hace que la siguiente tecla la destruya en vez de abrir una nueva |
| Un payload de arrastre lleva el dueño del slot de origen (`owner_id`) | Con copias en varios inventarios, deducirlo toma el equivocado |
| Mover ítems entre inventarios comprueba antes que el destino admite la pila | `Inventory.add_item` devuelve `true` aunque sobrescriba o recorte |
| Un cálculo de presentación que comparten dos pantallas vive en un helper (`ItemDetailBuilder`), no en un ViewModel | Sin duplicar, y sin referencia circular entre ViewModels |
| Una operación compuesta valida todo antes de mover nada y revierte si falla | `Equipment` e `Inventory` son independientes |
| Una señal global de cierre se protege por el `GameState` de origen | Si algo abre esa pantalla como sub-overlay, la señal global destruiría el contexto anidado (p. ej. `_on_dialogue_ended()` solo actúa en `GameState.DIALOGUE`) |
 
---
 
## Antipatrones conocidos
 
### ❌ Acceso a sistemas core o lógica de negocio en la View
 
```gdscript
# MAL
func _on_slot_clicked(item_id: String) -> void:
    if Items.get_item(item_id).item_type == "EQUIPMENT":
        Equipment.toggle_equipment("player", item_id)
 
# BIEN: la View solo comunica la intención
func _on_slot_clicked(item_id: String) -> void:
    _vm.request_slot_action(item_id)
```
 
### ❌ La View construye su propio payload de evento
 
`combat_arena_panel.gd` armaba a mano `player_action_requested` sin `"target"`, saltándose `PlayerCombatController`, único dueño del objetivo actual (error «No target specified»). Si un dato derivado ya tiene un dueño único, cualquier punto de entrada nuevo llama a su API pública (`controller.request_skill(skill_id)`); nunca reconstruye el estado por su cuenta.
 
Relacionado: el orden de conexión de dos nodos distintos a la misma señal no está garantizado. Quien necesita el estado ya resuelto de otro nodo en el mismo instante lo consulta directamente (`get_current_target()`), no se fía de recibir su señal derivada a tiempo.
 
### ❌ Transferir antes de validar, o mover sin poder deshacer
 
```gdscript
# MAL: el ítem ya cambió de dueño cuando se descubre que el slot no lo admite
func request_equip_drop(slot_id, item_id, target_entity):
    if not Inventory.has_item(target_entity, item_id):
        _transfer_item(_find_item_owner(item_id), target_entity, item_id)
    if not Equipment.can_equip_in_slot(target_entity, item_id, slot_id):
        return "PARTY_ERROR_WRONG_SLOT"
 
# BIEN: validar todo antes; si un paso falla, deshacer; un único mensaje al final
func request_equip_drop(slot_id, item_id, target_entity, from_entity):
    if not Equipment.can_equip_in_slot(target_entity, item_id, slot_id):
        _set_feedback(...); return                 # nada se movió
    var was_equipped := Equipment.is_item_equipped(from_entity, item_id)
    _suppress_feedback = true
    if was_equipped: Equipment.unequip_item(from_entity, item_id)
    if not _transfer_item(from_entity, target_entity, item_id):
        if was_equipped: Equipment.equip_item(from_entity, item_id)
        return
    if not Equipment.equip_item(target_entity, item_id):
        _transfer_item(target_entity, from_entity, item_id)   # revertir
        if was_equipped: Equipment.equip_item(from_entity, item_id)
        return
```
 
`EquipmentManager` no consulta el inventario y `InventorySystem` no toca el equipo: quien mueve ítems entre entidades es quien debe desequipar. Una operación compuesta emite varios eventos intermedios: se suprimen durante la operación y sale un solo mensaje al final.
 
### ❌ Dar por buena una escritura que devuelve `true`

`Inventory.add_item` devuelve `true` en tres casos que pierden datos: el destino ya tiene un ítem **no apilable** (sobrescribe la instancia), la pila supera `max_stack` (recorta) y el ítem lleva `custom_state` (el destino nace sin él). Como `_transfer_item` solo hace rollback si recibe `false`, nunca se dispara. La pre-validación va en el ViewModel antes de mover nada (`existing.can_stack_with(source)` y `existing.quantity + qty <= max_stack`), y tras mover se comprueba la cantidad resultante.

### ❌ Deducir el origen de un arrastre buscando el ítem en los inventarios
 
```gdscript
# MAL: con el mismo ítem en varias mochilas, siempre toma el del jugador
func _find_item_owner(item_id: String) -> String:
    if Inventory.has_item("player", item_id): return "player"
 
# BIEN: el slot declara su dueño (id opaco) y viaja en el payload
slot.owner_id = column.entity_id
# UISlot: { "item_id", "source", "owner_id" } → slot_item_dropped(slot, item_id, from_owner_id)
```
 
El componente del DS no interpreta `owner_id` ni accede a sistemas: lo transporta.
 
### ❌ Estado de selección en la View (y acciones destructivas escondidas)

La vista antigua del Loadout guardaba `_selected_slot_id`, lo limpiaba tras una asignación rechazada **sin repintar** (la pantalla seguía mostrando la selección vieja) y vaciaba un slot con un segundo clic sobre él, sin aviso. Correcto: `selected_slot_id` es estado público del ViewModel, solo cambia con `request_select_slot()` y se anuncia con `changed("selection")`; un error no limpia la selección; vaciar es un botón explícito («Vaciar slot»), y un clic en el slot seleccionado solo deselecciona.

Si el clic nace en un nodo que el repintado va a destruir (tarjetas de la lista), el repintado se **difiere** (`call_deferred`): liberar el nodo desde su propia señal de clic corrompe el procesado del evento.

### ❌ Flag implícito de estado
 
```gdscript
var _buttons_refreshed_by_state: bool = false     # MAL: ¿qué significa?
enum PanelState { HIDDEN, SHOWING, WAITING, SHOWING_RESULT }   # BIEN
```
 
### ❌ `await` en la View
 
Usar un `SceneTreeTimer` con referencia (o un `Timer` hijo), desconectando el anterior antes de crear el nuevo.
 
### ❌ ViewModel de Main Scene persistente sin listener de EventBus
 
Ver «Caso especial: MainMenuScreen». Solo aplica a Views que son Main Scene; en overlays instanciados por `SceneOrchestrator` el ciclo de vida ya lo resuelve.
 
### ❌ Panel sin tamaño fijo con texto largo
 
Sin ancho ni anclaje, el `Control` se dimensiona al contenido y el `autowrap_mode` del `Label` nunca tiene ancho contra el que envolver; con líneas cortas de prueba no se nota, con un párrafo real el panel se desborda. Anclar a tamaño explícito (anclas relativas u offsets).
 
`grow_vertical` por defecto es END (1); para que un desbordamiento ocasional crezca **hacia arriba** hay que escribir `grow_vertical = 0` (BEGIN), como en el panel narrativo (anclas `0.04 / 0.66 / 0.96 / 0.96`).
 
Pero si el contenido variable es la norma (número de opciones, longitud de una lista), mejor un `ScrollContainer` alrededor para que el panel conserve su tamaño anclado. Un `PanelContainer` no se encoge por debajo del mínimo de sus hijos. Además, `ScrollContainer` + `size_flags_vertical = 3` junto a otro hijo expansivo reparte el hueco a partes iguales: hay que reservar la altura natural con `custom_minimum_size` y dejar el scroll solo como red de seguridad (`DialoguePanel`).
 
### ❌ `TextureRect` de contenido con `expand_mode` por defecto
 
```
# MAL: EXPAND_KEEP_SIZE → el mínimo es el tamaño de la textura; una imagen real
# de 1376×768 empuja al contenedor fuera de pantalla (stretch_mode no lo evita)
# BIEN
expand_mode = 1        # IGNORE_SIZE
stretch_mode = 6       # KEEP_ASPECT_COVERED para fondos a pantalla completa
mouse_filter = 2       # IGNORE: un fondo no debe tragarse clics
```
 
### ❌ Texto claro sobre imagen sin contorno, o velo calibrado «a ojo»
 
El velo se calibra contra la luminosidad **real** de las imágenes (no contra el prompt con el que se generaron), desde tokens (`COMBAT_BACKGROUND_SCRIM_ALPHA`), y todo texto pintado directamente sobre una imagen lleva contorno (`TEXT_OUTLINE_SIZE`, `COLOR_TEXT_OUTLINE`).
 
### ❌ Razón de `changed()` nueva sin consumidor en la View
 
Cae en el `_:` por defecto: solo un `push_warning`, y la pantalla no se actualiza. Pasó con `"streak_progress"` (el test probaba el ViewModel con fixtures sin View real). También por despliegue parcial (ViewModel nuevo con View antigua): se diagnostica por el número de línea del rastreo.
 
### ❌ Overlay/subpantalla anidable sin señal `closed` propia
 
```gdscript
# MAL: asume que la subpantalla se libera sola
_subscreen.tree_exiting.connect(_on_subscreen_closed)
 
# BIEN: prioriza closed; tree_exiting solo como fallback con aviso
if _subscreen.has_signal("closed"):
    _subscreen.closed.connect(_on_subscreen_closed)
else:
    push_warning("%s no expone 'closed'" % scene_path.get_file())
    _subscreen.tree_exiting.connect(_on_subscreen_closed)
 
func _on_subscreen_closed() -> void:
    _subscreen.queue_free()      # nadie más lo hace
    _subscreen = null
    visible = true
```
 
Ninguna pantalla del proyecto se auto-libera en su cierre (solo `visible = false`): sin `closed`, anidar un segundo nivel deja las capas colgadas e invisibles, indistinguible de un crash. Toda pantalla anidable emite `closed` junto a su `visible = false`; quien la instancia hace `queue_free()`.
 
### ❌ Redimensionar un Control cuyo contenido usa offsets fijos
 
`UICombatToken` ancla sus hijos con desplazamientos absolutos calculados para 96×144 (`BASE_SIZE`). Forzar un `.size` menor descoloca el contenido. Correcto: un `Control` envoltorio que el `Container` redimensiona, y `.scale` sobre el componente, que nunca cambia de tamaño real.
 
### ❌ Nodo hijo colgado del padre equivocado en un `PanelContainer`
 
Un `PanelContainer` (y `UIPanel`) apila **todos** sus hijos en el mismo rectángulo: un nodo mal anidado no da error, se dibuja encima. El contenido de un panel va dentro de un único `VBoxContainer`/`HBoxContainer`, y al montar escenas a mano se verifica el padre de cada nodo.
 
---
 
## Design System
 
### `UIPanel` — variantes
 
| Variante | Qué es | Consumidores |
|---|---|---|
| `DEFAULT` | Fondo `COLOR_PANEL` con borde, padding 16 | Character Creation, Diálogo, Narrativa, sub-paneles del menú, cabeceras y filas de la tienda |
| `POPUP` | `COLOR_PANEL_ALT`, borde de foco, padding 8 | ninguno |
| `OVERLAY` | Fondo **opaco** (`COLOR_BG` oscurecido un 20 %, alfa 1,0), sin borde, padding 24 | Tienda, Inventario, Party, Loadout, Árbol de habilidades |
 
### `UIPanel` — marco decorativo (opt-in)
 
`decorative_frame` (false por defecto) dibuja doble filete + cuatro esquineras sobre el fondo.
 
| Propiedad | Por defecto | Descripción |
|---|---|---|
| `decorative_frame: bool` | `false` | Activa el marco; cualquier variante lo admite |
| `corner_texture: Texture2D` | `null` | Sin asignar usa `UITokens.FRAME_CORNER_TEXTURE_PATH` (64×64); solo si tampoco carga, se dibujan los filetes sin esquinas y avisa una vez por ejecución |
 
- Se dibuja con `_draw()` sobre el propio panel (un `StyleBoxFlat` solo admite un borde de un color): tres `draw_rect` concéntricos + cuatro `draw_texture` con `draw_set_transform(esquina, rotación)`.
- Con el marco activo el panel anula su borde y `corner_radius`.
- Con `padding = -1` y marco, el padding efectivo no baja de `FRAME_MIN_PADDING` (16). Un `padding` explícito (≥ 0) nunca se modifica.
- `decorative_frame` y `corner_texture` tienen setter y reaplican estilo y redibujan en runtime. Los setters de `@export` corren **antes de `_ready()`**: protegerlos con `is_node_ready()`.
- Para activarlo: inspector de la instancia, grupo «Marco decorativo (Spike 9)», marcar `Decorative Frame` y **guardar la escena**. Sin cambios de script. Si «no cambia nada», un `print` en `_ready()` distingue «el script no carga» de «el flag no está activo en esa instancia».
- Tokens: `COLOR_FRAME_OUTER/FILLET/INNER`, `FRAME_OUTER/FILLET/INNER_WIDTH`, `FRAME_GAP`, `FRAME_MIN_PADDING`, `FRAME_CORNER_TEXTURE_PATH`. Arte en `ui/design_system/assets/frames/`.
- Activado en: panel narrativo, diálogo, tienda, inventario, Party, Loadout y árbol de habilidades.
### `UIButton` — modo solo icono (opt-in)
 
| Opción | Efecto |
|---|---|
| `min_square: int = 0` | `> 0` = botón de solo icono, cuadrado de ese lado en px y relleno mínimo (`SPACE_XS`). `0` = comportamiento normal |
| `icon_backdrop: bool = false` | Solo con `min_square > 0`: disco oscuro semitransparente con borde de foco; hover/pressed lo hacen más opaco |
 
- `variant`, `btn_size`, `min_square` e `icon_backdrop` se fijan **antes de `add_child()`**: `UIButton` los lee en `_ready()` y fuerza `custom_minimum_size.y`.
- Para solo icono: vaciar `text` y pasar el nombre a `tooltip_text`. Sin `icon_path` válido sigue siendo un botón de texto (fallback sin código extra).
- Un icono claro sobre fondo claro no destaca solo: el disco oscuro lo resuelve; en arte nuevo, interior más oscuro.
- `UICombatToken` está acoplado al combate y no sirve como icono de mapa.
### Fila de lista: `ShopItemSlot`
 
Patrón reutilizable: `[icono opcional] [nombre] [xN] [precio] [botón]`.
 
- Raíz `PanelContainer` con script que `extends UIPanel` (`DEFAULT`); fija `padding = SPACE_XS` **antes** de `super._ready()`. Alto 40 px, suelo de anchura 380 px (un `Label` con elipsis tiene anchura mínima 0).
- Contrato: `setup(item_data, buy_mode)` **después** de `add_child()`; señal `item_clicked(item_id, is_buy)`; `set_busy(bool)` bloquea la acción durante una transacción y nunca habilita lo que la fila no permite. No se comprueban métodos por nombre.
- Estados con tokens, sin `modulate`: no asequible (precio `COLOR_DANGER_SOFT`, botón deshabilitado, tooltip), no disponible (`TEXT_MUTED`).
- Préstamo: la clave `"is_loan"` cambia el precio por «Préstamo» (`COLOR_INFO`) y el botón por «Tomar»; en venta queda bloqueado.
- `%IconRect` oculto hasta que la entrada traiga `"icon"` (`Texture2D`).
- Hover: `BG_RAISED` + `BORDER_ACCENT`; `mouse_exited` llega también al entrar en un hijo, así que solo es salida si el ratón ya no está dentro de `get_global_rect()`.
- Listas: `VBoxContainer` en `ScrollContainer` (`horizontal_scroll_mode = DISABLED`); al reconstruir, `remove_child()` antes de `queue_free()`; mensajes con altura reservada: vaciar el texto en lugar de ocultar el `Label`.
### `UIResourceBar` — uso desde una View MVVM (19b)

- La View llama a `set_values(current, max)` con lo que le da el ViewModel. `bind()` se conecta a `Resources` por sí misma: accede al juego y no se usa desde una View MVVM.
- El relleno va anclado a izquierda y alto, y su ancho se ajusta con `offset_right` (un control con anclas opuestas distintas ignora `size`). Se recalcula al cambiar de tamaño la barra; el primer valor se pinta sin animar y cada refresco cancela el tween anterior.
- Alto `RESOURCE_BAR_HEIGHT` (14 px); dos barras con 4 px de separación caben en una cabecera de 36 px. Para el recurso que se regenera (estamina) el ViewModel emite una razón propia (`resources`) agrupada por frame, no repinta la pantalla entera.
- Barra fina (21): `UIResourceBar` fija `custom_minimum_size.y = 14` en su `_ready()`; una barra de 6 px se rebaja **después** de ese `_ready` (en el `_ready()` del padre, o con `bar.ready.connect(…, CONNECT_ONE_SHOT)` si la barra entra al árbol más tarde). Con `resource_type = "custom"` se asignan `custom_fill_color`/`custom_bg_color` antes de añadirla al árbol.

### `UISlot` y overlay a pantalla completa
 
- **API:** `set_item(ItemInstance)`, `set_definition(definition, quantity = 1)`, `clear()`, `get_item_id()`, `is_empty()`; flags `set_selected()`, `set_equipped_mark()`, `set_overflow()` (borde discontinuo de peligro); `border_color_override`; arrastre con `draggable`, `accept_drops`, `drop_source_filter`, `equipment_slot_id`; `owner_id` (id opaco del dueño, viaja en el payload). Sin icono: placeholder teñido con `COLOR_TEXT_MUTED`.
- **Señales:** `slot_clicked(slot)` (se emite **al soltar** el botón dentro del slot, no al pulsar, para que un arrastre no dispare una selección), `slot_drop_received(slot, item_id)` y `slot_item_dropped(slot, item_id, from_owner_id)` (justo después de la anterior).
- **No conoce el juego:** no equipa ni mueve nada; avisa por señal y la View lo traduce en una intención del ViewModel.
- **Drops entre mochilas (19b):** `drop_exclude_owner` (apagado por defecto) rechaza drops cuyo `owner_id` coincide con el del slot; `highlight_drop_targets` (apagado por defecto) resalta el borde de los slots que aceptarían el arrastre en curso (`NOTIFICATION_DRAG_BEGIN/END`, `gui_get_drag_data()`). Un slot de equipo no lo activa: aceptaría y resaltaría cualquier ítem aunque no encaje.
- **Overlay a pantalla completa:** `Backdrop` (`ColorRect` opaco, `mouse_filter = STOP`) + `Frame` (`UIPanel` OVERLAY con marco, padding 16) con fracción 0,9 y **tamaño máximo 1400×820**, centrado, recalculado en `get_viewport().size_changed` y al abrir. Sin tope, a 1680×1050 el panel queda vacío.
- **Rejilla variable:** pool de `UISlot` reutilizados (los sobrantes se ocultan); columnas con el ancho real del `ScrollContainer` más una reserva para la barra de scroll. Lo que excede la capacidad se muestra con borde discontinuo, no se descarta.
- **Categorías en datos:** `data/ui/inventory_categories.json` (primera coincidencia por prioridad); el ViewModel las traduce a pestañas.
- **Columna de equipo:** 6 `UISlot` de 64 px en vertical con la etiqueta dentro del slot (no cabe debajo con 6 slots en 648 de alto). No arrastrables; aceptan solo drops con `source == "inventory"`.
- **Bloques informativos** (estadísticas, bonos): `UIPanel` `DEFAULT` con un único contenedor de layout dentro. Los bonos suman solo modificadores `add`.
- Una subclase de `UIPanel` (`ItemDetailPanel`, `ShopItemSlot`) llama a `super._ready()`; si no, el estilo no se aplica.
- Una clase interna de la View (`ColumnView`) evita duplicar el pintado de columnas idénticas (Party).
- **`BagCapacity`** (`ui/inventory/bag_capacity.gd`, `RefCounted`): `compute(definition, used_count, entity_id = "")` devuelve `definition.inventory_slots` (o `used_count` con aviso si no hay definición). Único punto de cálculo de la capacidad de una mochila.
- Limitación conocida: el estado `DISABLED` de `UISlot` usa `modulate` (atenúa también el contenido).
---
 
## Contrato de pantalla y resolución de referencia
 
Reglas de toda pantalla nueva o rediseñada del hito:
 
1. **MVVM.** La View no accede a sistemas core; todo pasa por el ViewModel (`changed(reason)`, `request_X()`). El ViewModel es hijo de la View.
2. **`closed`.** Toda pantalla anidable la expone, junto a su `visible = false`; quien la instancia hace `queue_free()`.
3. **Nombres únicos `%`.** Nunca rutas `$A/B/C/D` ni `get_node("X")`. Nada depende del nombre del nodo raíz (el orquestador puede renombrarlo).
4. **Marco decorativo** opt-in por pantalla.
5. **Tokens.** Sin `Color(...)` literales ni tamaños de fuente sueltos. Superficies/bordes/texto → `BG_*`/`BORDER_*`/`TEXT_*`; marca, semánticos, recursos y slots → `COLOR_*`. Nada se migra a la fuerza; un mismo valor en las dos familias es un **alias** apuntando hacia atrás (el orden de declaración importa en GDScript).
6. **Texto.** `tr()` con clave `PANTALLA_ELEMENTO` en el CSV de la pantalla. Textos de habilidades (`SKILL_<ID>_NAME`/`_DESC`) en `skills.csv`; textos de pantalla (`SKILL_TREE_*`…) en su CSV o `translations.csv`. Alta manual de cada `.csv` nuevo.
7. **Layout.** Anclas y fracciones, no píxeles fijos. Si una medida depende de otro nodo (el hueco de un retrato), se calcula desde el borde real de ese nodo y se recalcula en `resized`.
8. **Contenido variable.** Si el número de hijos varía entre aperturas, reservar su altura natural con `custom_minimum_size` más un `ScrollContainer` como red de seguridad.
9. **Teclado.** Si hay opciones seleccionables, un control toma el foco al abrirse (`grab_focus`, diferido) y el foco se ve: el estilo `focus` por defecto de un `Button` puede recortarse; usar el estilo `hover` (`add_theme_stylebox_override("focus", btn.get_theme_stylebox("hover"))`).
10. **Contratos públicos** (`open()`, `open_inventory()`, `show_shop_direct()`, `closed`…) se conservan salvo que el spike declare lo contrario.
**Resolución de referencia:** sin estiramiento, valores por defecto (ventana 1152×648, sin `stretch/mode`). `canvas_items` con base 1280×720 ablandaba el texto (≈15 % en la medición) y se descartó. Mínimo que no debe romperse: 1152×648; referencia de diseño: 1680×1050 a pantalla completa (así se juega). Las pantallas de píxeles fijos se corrigen en el spike de cada una.
 
---
 
## Contextos de apertura
 
### Inventario
 
| Contexto | Quién instancia | `closed` | Quién libera |
|---|---|---|---|
| Overlay en exploración (tecla `I`) | `SceneOrchestrator.open_inventory()` (toggle) | conectada por el orquestador | `_on_overlay_closed()` |
| Subpantalla de PlayerMenu | `PlayerMenuScreen._open_subscreen()` | conectada | PlayerMenu |
| Sub-overlay de narrativa | `NarrativeScenePanel._open_sub_overlay()` (nunca vía orquestador) | conectada | el panel |
 
### Party
 
| Contexto | Quién instancia | `closed` | Quién libera |
|---|---|---|---|
| Overlay en exploración (tecla `O`) | `SceneOrchestrator.open_party()` (toggle) | conectada por el orquestador | `_on_overlay_closed()` |
| Sub-overlay de narrativa | `NarrativeScenePanel._open_sub_overlay()` (llama a `open()`) | conectada | el panel |
 
Reglas comunes:
- `SceneOrchestrator` tiene un único `_current_overlay` (no una pila). Si no conecta `closed`, la pantalla cerrada (solo oculta) sigue ocupando el slot y la siguiente pulsación la destruye en vez de abrirla (dos pulsaciones). `open_inventory()` y `open_party()` conectan `closed`.
- `ui_cancel`: la pantalla lo consume con `set_input_as_handled()` y cierra; el input no manejado se propaga de hijo a padre, así que en anidado cierra solo la capa más profunda. Una pantalla con `closed` nunca se libera a sí misma.
- Limitación conocida del orquestador (→ Spike 22): con Party abierta, `I` la cierra en vez de abrir el inventario; `I` dentro de PlayerMenu cierra el menú entero. `PlayerMenu` no abre Party (solo Loadout, Inventory y SkillTree).
- Party en narrativa: cerrar solo vuelve a mostrar el panel; no avanza nodo ni racha.
- SkillTree: overlay en exploración (tecla `H`, `SceneOrchestrator.open_skill_tree()`, `closed` conectada por el orquestador) y subpantalla de PlayerMenu (`_open_subscreen()`).
- Loadout: solo como subpantalla de PlayerMenu (`_open_subscreen()`, `closed` conectada, la libera PlayerMenu). `SceneOrchestrator.open_loadout()` existe pero no tiene llamadores ni acción de input (código muerto).
---
 
## Referencia de pantallas existentes
 
| Pantalla | ViewModel / View | Estado vigente |
|----------|------------------|----------------|
| MainMenu | `main_menu_viewmodel.gd` / `main_menu_screen.gd` | Main Scene. Pantalla única con sub-paneles (opciones, créditos, confirmar salida). No la instancia `SceneOrchestrator`. Ver «Caso especial». |
| WorldObject | `world_object_panel_viewmodel.gd` / `world_object_interaction_panel.gd` | Panel piloto del patrón; el más simple. Vestigial en el camino jugable. |
| Inventory | `inventory_viewmodel.gd` / `inventory_ui.gd` | `Backdrop` + `Frame` (`UIPanel` OVERLAY con marco, tope 1400×820). Tres columnas: equipo (6 `UISlot`), mochila (pestañas `UIButton` SM + rejilla de `UISlot` con pool, marca «E», desbordamiento con borde discontinuo) y detalle (`ItemDetailPanel` con modificadores y comparación) + bonos del equipo + estadísticas (valores base). Cabecera con oro, peso y huecos (`_compute_capacity()` → `BagCapacity`). Razones de `changed`: `opened/inventory/equipment/stats/selection/feedback/categories/closed`. Feedback decidido por el ViewModel en `FeedbackPopup` (se oculta solo). Esc cierra. Textos `INVENTORY_*` (`inventory.csv`). |
| Party | `party_viewmodel.gd` / `party_ui.gd` | Mismo patrón de overlay que el inventario. Layout L3: por columna, equipo en 6 `UISlot`, mochila (pool según capacidad), cajetín de detalle (`ItemDetailPanel`, compacto bajo 700 px de marco) y cabecera con nombre, barras HP/estamina y huecos. View pasiva: el ViewModel entrega `ColumnData` (`BagEntry`/`EquipEntry`, recursos, atributos para el tooltip, selección y `ItemDetailData`), `StrategyOption` y `CompanionTab` ya traducidos. Clic en la mochila = seleccionar (selección por columna, se limpia al cambiar de pestaña). Arrastre: al slot de equipo (`request_equip_drop`) o mochila a mochila (`request_transfer`: 1 unidad, Mayús = pila; valida préstamo, apilado y hueco antes de mover). Un `quest_loan` solo puede estar en el jugador. Razones: `opened`, `player_column`, `companion_column`, `companion_changed`, `party_changed`, `resources`, `feedback`, `closed`. Pestañas solo con 2 o más compañeros. Textos `PARTY_*` (`party.csv`); el cajetín usa claves `INVENTORY_*`. |
| Shop | `shop_viewmodel.gd` / `shop_ui.gd` | `UIPanel` OVERLAY con marco (anclas 0.05–0.95), `layer = 10`; dos columnas (inventario del jugador, tienda) con cabeceras `UIPanel` (título + oro), `ScrollContainer` de filas `ShopItemSlot`, botón Cerrar arriba a la derecha y tira de mensaje de altura reservada. Snapshot inmutable abierto vía `show_shop_direct()`; cierre por `EventBus.shop_closed`. `trade_type` admite `"loan"` (tag `quest_loan`: sin coste, no vendible). Textos `SHOP_*` (`shops.csv`). |
| Dialogue | `dialogue_viewmodel.gd` / `dialogue_panel.gd` | Base `UIPanel` con marco. Franja inferior (anclas `0.04/0.57/0.96/0.96`) con un único retrato como **hermano** del panel (sobresale por el marco), fondo de ambiente (`BackgroundImage` + `Background` como velo, razón `"background"`) y opciones en `GridContainer` (1 columna hasta 3, 2 desde 4) con altura natural reservada y `ScrollContainer` de seguridad. Margen del texto calculado desde el borde real del retrato. Foco inicial en la primera opción. Retrato resuelto por cascada `<portrait_id>_<mood>.png` → `<portrait_id>.png` → ninguno. `dialogue_node_shown` lleva 7 argumentos. Como sub-overlay de narrativa expone `closed` y `resume_after_dialogue()`. |
| CharacterCreation | `character_creation_viewmodel.gd` / `character_creation_screen.gd` | Roll-and-assign de atributos (2 pools, 1 reroll), nombre, resumen `RichTextLabel`+BBCode. Interacción por clic. Kit de skills leído de `player_new.tres`; `AdventureStarter.apply()` da companions y kit al confirmar. |
| PlayerMenu | `player_menu_viewmodel.gd` / `player_menu_screen.gd` | Recursos, atributos derivados, buffs, nombre. Gestiona Loadout/Inventory/SkillTree como subpantallas hijas propias (`_open_subscreen`); `SceneOrchestrator` no interviene en esa navegación. HP/EN desde el estado vivo de `Resources`. |
| NarrativeScene | `narrative_scene_viewmodel.gd` / `narrative_scene_panel.gd` | Fondo `SceneImage` a pantalla completa (`IGNORE_SIZE` + `KEEP_ASPECT_COVERED`) y `UIPanel` con marco en el tercio inferior (`grow_vertical = BEGIN`). Opciones con tirada opcional (`SkillRoller`, 5 grados), tiradas acumulativas (`"streak_progress"`), progresión narrativa y agregación de grupo. Razones además: `open_inventory`/`open_party`/`open_player_menu`. Sub-overlays (Inventory, Party, PlayerMenu, Diálogo) gestionados por el propio panel (`_open_sub_overlay`/`_close_sub_overlay`, nunca vía `SceneOrchestrator`, cuyo `_current_overlay` apunta al panel narrativo); solo el de Diálogo reengancha (`_sub_overlay_is_dialogue` → `resume_after_dialogue()`). `_apply_outcome()` resuelve en orden: flag → otorgar ítem → quitar ítem → otorgar recurso → `dialogue_id` (retorno temprano) → combate (registra enemigos antes de `start_combat`) → `next_scene_id`. Cierre desacoplado por `EventBus.narrative_scene_closed`. |
| CombatArena | `combat_arena_viewmodel.gd` (+ `combat_hub_viewmodel.gd` como `action_menu`) / `combat_arena_panel.gd` | Pantalla de combate de producción (`OVERLAY_COMBAT_HUD`). Fichas dinámicas (`combat_tokens`), log narrado (`log_entries`, 4 categorías con fuente de señal propia) y menú de 8 acciones. Se conecta a `Resources.resource_changed` directamente. Fondo por encuentro (`background_path`, razón `"background"`). Nombres resueltos con fallback a `tr(CharacterDefinition.name_key)`. Columna enemiga con envoltorio + `.scale` (ver antipatrón). Acciones delegadas en `PlayerCombatController.request_skill()`. |
| InteractiveScene | `interactive_scene_viewmodel.gd` / `interactive_scene_view.gd` | Vista **permanente** del mapa de puntos de interés. Ver siguiente sección. |
| Loadout | `loadout_viewmodel.gd` / `loadout_screen.gd` (+ `loadout_card.gd`, `LoadoutCard`) | `Backdrop` + `Frame` (`UIPanel` OVERLAY con marco, tope 1400×820). Izquierda: slots agrupados en Ataque / Defensa / Consumibles (habilidades como `LoadoutCard` de dos líneas, etiqueta del slot + tecla arriba y nombre debajo; consumibles como `UISlot` de 64 px con la tecla en la etiqueta). Derecha: lista de candidatos del slot seleccionado (compatibles por tag, no asignados en otro slot; «asignada aquí» si ya está en este), cajetín de detalle (costes, requisito o «sirve para», cantidad; «Vaciar slot» solo si muestra el contenido del slot seleccionado) y línea de feedback fija (token `COLOR_DANGER_SOFT`, `Timer` de 2,5 s). El slot `escape` es fijo (`FIXED_SLOTS`): tarjeta «Acción de combate», no seleccionable. Clic para seleccionar y clic para asignar (arrastre previsto). Estado en el ViewModel (`selected_slot_id`, `groups`, `slots`, `candidates`); entrega **claves** de localización y la View traduce. Razones: `opened/selection/slots/error/closed`. Teclas leídas de `CombatHudViewModel.SLOT_KEYBIND_LABEL`. Esc cierra (`ui_cancel`), `closed` sin auto-liberarse. Textos `LOADOUT_*` (`loadout.csv`, 41 claves). |
| SkillTree | `skill_tree_viewmodel.gd` / `skill_tree_screen.gd` (+ `skill_card.gd`, `SkillCard`) | `Backdrop` + `Frame` (`UIPanel` OVERLAY con marco, tope 1400×820). Cabecera con selector de entidad (‹ nombre ›, vuelta circular), Comparar/Individual y cierre; pestañas de subcategoría y filtros (`UIButton`); lista por niveles de `SkillCard` (`HFlowContainer`, 260 px; cabecera de nivel solo si hay más de uno) y detalle (barra, subtítulo, descripción, costes >0, efectos, requisitos ✓/✗) con **pie fijo** (motivo de «no entrenable» + botón Entrenar, `SECONDARY` cuando está deshabilitado). Modo Comparar: rejilla habilidades × entidades por subcategoría. El ViewModel decide todo: «mejorable» = `is_unlocked and has_progression and prereqs_met`; motivo por prioridad (requisitos → profesor → sin progresión); entrena con `SkillProgression.execute_learning_session(…"PRACTICE")` y entrega `TrainResult`; entrega **claves** y la View traduce. Razones: `opened/entity_changed/tab/selection/filter_changed/mode_changed/training_done/error/closed`. Selección en sitio (sin repintar); pestañas/filtros con repintado diferido; tras entrenar se conserva el scroll. Esc cierra (`ui_cancel`), `closed` sin auto-liberarse. Textos `SKILL_TREE_*` (`skill_tree.csv`, 37 claves) + `SKILL_FILTER_*`/`SKILL_SUBCATEGORY_*`/`SKILL_EFFECT_*`… en `translations.csv`. |
 
### Pantallas sin ViewModel
 
| Pantalla | Descripción |
|----------|-------------|
| LoadingScreen (`loading_screen.gd`) | Carga asíncrona con `ResourceLoader.load_threaded_request()`; emite `loading_finished(packed_scene)`. Implementada pero no conectada a `SceneOrchestrator`. |
 
(Game Over ya tiene `GameOverViewModel` desde el Spike 14: una intención, `request_return_to_menu()`, y una View sin acceso a `core`.)
 
### Vista permanente sin overlay: `InteractiveSceneView`
 
Vive **dentro de la escena de exploración** (`ExplorationScene`, bajo `get_tree().root`) en un `CanvasLayer` de capa -1, no como overlay del orquestador.
 
- La escena raíz crea el ViewModel (`new()` + `add_child`) y llama a `map_view.bind(view_model)` **después** de que la vista esté en el árbol (sus `@onready` ya resueltos).
- `changed(reason)` con dos razones: `"scene_loaded"` y `"hotspots_refreshed"`; la View reconstruye todos los botones en ambas (`remove_child` + `queue_free`, sin fijar `name`).
- Señal de intención `hotspot_activated(interaction_type, target_id, enemy_definitions)` que la escena raíz reenvía a `ExplorationController.request_interaction()`. No pasa por `EventBus` porque `enemy_definitions` no cabe en `interaction_requested(type, target_id)`.
- `activate_hotspot()` exige `GameState == EXPLORATION` (`is_input_blocked()` por sí solo deja pasar `PAUSE` y `MENU`).
- Visibilidad: `required_flags`/`blocked_flags` contra `Narrative`, recalculada al cargar y en cada `game_state_changed → EXPLORATION`. La View no conoce flags ni `GameLoop`.
- Layout pasivo: posiciones normalizadas (0–1) sobre el rectángulo **real** de la imagen (`STRETCH_KEEP_ASPECT_CENTERED` deja franjas), recolocadas en `resized`.
- La escena raíz oculta el `MapLayer` en `COMBAT_ACTIVE`/`VICTORY`/`DEFEAT`.
- Hotspots como `UIButton`: con `icon_path` válido, solo icono (`GHOST` + `min_square` + `icon_backdrop`, nombre en tooltip); sin él, botón de texto (`SECONDARY`, `MD`).
- `request_first_visit()`: acción de una sola vez al entrar; solo en `EXPLORATION`, marca su flag antes de actuar, y la escena raíz la llama con `call_deferred` desde su `_ready()`.