# Athelia — Guía de Arquitectura UI

## Índice

1. [Filosofía general](#filosofía-general)
2. [Patrón MVVM simplificado](#patrón-mvvm-simplificado)
3. [Estructura de archivos](#estructura-de-archivos)
4. [Ciclo de vida](#ciclo-de-vida)
5. [Contrato del ViewModel](#contrato-del-viewmodel)
6. [Contrato de la View](#contrato-de-la-view)
7. [Cómo crear un nuevo panel UI](#cómo-crear-un-nuevo-panel-ui)
8. [Reglas que no se rompen](#reglas-que-no-rompen)
9. [Antipatrones conocidos](#antipatrones-conocidos)
10. [Referencia de pantallas existentes](#referencia-de-pantallas-existentes)

---

## Filosofía general

Toda pantalla de UI en Athelia sigue tres principios:

- **La View no decide nada.** Solo renderiza el estado que le da el ViewModel y traduce input del jugador en llamadas al ViewModel.
- **El ViewModel no renderiza nada.** Solo gestiona estado, coordina sistemas y expone datos listos para pintar.
- **Los sistemas core son invisibles para la View.** `Inventory`, `Equipment`, `Characters`, `Resources`, `Dialogue`... ninguno de ellos es accesible desde el `.gd` de la View. Todo pasa por el ViewModel.

---

## Patrón MVVM simplificado

```
┌─────────────────────────────────────────────────────────┐
│  SISTEMAS CORE                                          │
│  (Inventory, Equipment, Resources, Dialogue, Party...)  │
└────────────────────────┬────────────────────────────────┘
                         │ EventBus signals
                         ▼
┌─────────────────────────────────────────────────────────┐
│  VIEWMODEL  (nombre_viewmodel.gd)                       │
│                                                         │
│  - Enum de estados                                      │
│  - Data classes (snapshots para la View)                │
│  - Escucha EventBus → actualiza estado                  │
│  - Expone datos públicos (read-only para la View)       │
│  - Emite: signal changed(reason: String)                │
│  - Métodos de intención: request_X(), select_X()        │
└────────────────────────┬────────────────────────────────┘
                         │ signal changed(reason)
                         ▼
┌─────────────────────────────────────────────────────────┐
│  VIEW  (nombre_panel.gd / nombre_screen.gd)             │
│                                                         │
│  - @onready de nodos del .tscn                          │
│  - _on_vm_changed(reason) → match → _render_X()         │
│  - Input del jugador → _vm.request_X()                  │
│  - Nunca accede a sistemas core                         │
└─────────────────────────────────────────────────────────┘
```

---

## Estructura de archivos

Cada pantalla UI vive en su propia carpeta dentro de `ui/`:

```
ui/
└── nombre_pantalla/
    ├── nombre_viewmodel.gd     ← lógica y estado
    ├── nombre_panel.gd         ← renderizado y input
    └── nombre_panel.tscn       ← estructura de nodos
```

### Convenciones de nombre

| Tipo | Ejemplo |
|------|---------|
| ViewModel | `inventory_viewmodel.gd` |
| View script | `inventory_screen.gd` |
| View scene | `inventory_ui.tscn` |
| ViewModel class | `class_name InventoryViewModel` |
| View class | `class_name InventoryScreen` |

---

## Ciclo de vida

```
SceneOrchestrator
  → instancia el .tscn
  → añade al árbol (_ready() se dispara)
      → View crea el ViewModel como hijo: add_child(_vm)
      → ViewModel se conecta al EventBus en su propio _ready()
      → View se conecta a _vm.changed
  → SceneOrchestrator llama open() o show_X_direct() en la View
      → View delega a _vm.open() o _vm.init_with_snapshot()
          → ViewModel emite changed("opened")
              → View renderiza

Al cerrar:
  → View llama _vm.request_close()
      → ViewModel emite changed("closed")
          → View se oculta (visible = false)
  → SceneOrchestrator llama queue_free() sobre el overlay
      → El ViewModel muere como hijo → señales desconectadas automáticamente
```

**Regla crítica:** El ViewModel es siempre hijo de la View. Nunca se crea como autoload ni se pasa por referencia externa. Su ciclo de vida está ligado al de la pantalla.

### Caso especial: MainMenuScreen

El menú principal es la **Main Scene del proyecto** — no es instanciado por `SceneOrchestrator` sino que arranca directamente. Su ciclo de vida es:

```
(arranque del ejecutable)
  → MainMenuScreen._ready()
      → crea MainMenuViewModel como hijo
      → conecta señales de botones
      → llama _vm.open() → changed("main") → _render_main()

Al iniciar partida nueva:
  → _vm.request_new_game()
      → changed("transitioning") → botones deshabilitados
      → await process_frame
      → GameLoop.enter_character_creation()
          → SceneOrchestrator._handle_character_creation()
              → instancia CharacterCreationScreen

Al cargar partida:
  → _vm.request_load_game()
      → SaveManager.load_game("quicksave")
      → GameLoop.enter_exploration()

Al volver a MENU desde cualquier otro estado (ej: CharacterCreation → "Volver al menú"):
  → EventBus.game_state_changed(MENU) se emite
      → MainMenuViewModel._on_game_state_changed() lo captura → open() → changed("main")
```

**Lección aprendida (spike Character Creation):** `MainMenuViewModel` originalmente solo llamaba a `open()` una vez, desde `_ready()` de la View. Tras la primera transición fuera de `MENU` (`request_new_game()` → `TRANSITIONING`), se quedaba ahí **para siempre** — nada le decía que volviera a `"main"`. Como `MainMenuScreen` es la Main Scene, nunca se destruye ni se recrea, así que el bug persistía indefinidamente tras el primer uso.

**Regla derivada:** cualquier ViewModel cuya View sea una Main Scene persistente (no instanciada/destruida por `SceneOrchestrator`) **debe** escuchar `EventBus.game_state_changed` en su propio `_ready()` y reaccionar tanto al entrar como al salir de su estado — no puede depender solo de que algo la invoque explícitamente, porque puede volver a ese estado por un camino que no pasa por su propio código (`GameLoop.enter_main_menu()` llamado desde otra pantalla, por ejemplo).

---

## Contrato del ViewModel

### Estructura mínima obligatoria

```gdscript
class_name MiPantallaViewModel
extends Node

# 1. Enum de estados — siempre
enum PanelState { HIDDEN, SHOWING, ... }

# 2. Señal única hacia la View — siempre
signal changed(reason: String)

# 3. Estado público — leído por la View, nunca escrito
var state: PanelState = PanelState.HIDDEN
var mi_dato: String = ""
# ... más datos que necesite la View

# 4. _ready() — conectar al EventBus
func _ready() -> void:
    EventBus.alguna_señal.connect(_on_alguna_señal)

# 5. Métodos de intención — llamados desde la View
func open() -> void: ...
func request_close() -> void: ...
func request_accion() -> void: ...

# 6. Callbacks del EventBus — privados
func _on_alguna_señal(...) -> void: ...
```

### Razones de `changed(reason)`

Las razones son strings cortos que permiten refreshes parciales en la View. Deben documentarse en el propio ViewModel:

```gdscript
## Razones posibles:
##   "opened"   → renderizar todo
##   "datos"    → solo refrescar sección de datos
##   "waiting"  → bloquear botones
##   "closed"   → ocultar panel
signal changed(reason: String)
```

### `await` en el ViewModel — única excepción permitida

El ViewModel **puede** usar `await get_tree().process_frame` antes de una transición de escena, para dar tiempo a la View a procesar `"transitioning"` y deshabilitar botones antes de que la escena cambie. Esta es la única excepción justificada — nunca `await` en la View.

```gdscript
# ✅ CORRECTO — await en el ViewModel, antes de cambiar escena
func request_new_game() -> void:
    state = MenuState.TRANSITIONING
    changed.emit("transitioning")
    await get_tree().process_frame   # ← View procesa el disable de botones
    GameLoop.enter_character_creation()
```

### Data classes

Para datos complejos que la View necesita renderizar, usar clases internas ligeras:

```gdscript
class SlotData:
    var item_id: String = ""
    var is_empty: bool = true

    static func empty() -> SlotData:
        return SlotData.new()

    static func from_instance(instance: ItemInstance) -> SlotData:
        var d := SlotData.new()
        d.item_id = instance.definition.id
        d.is_empty = false
        return d
```

### Tipado estricto

Nunca usar `:=` con `.get()` de diccionarios ni con nulos potenciales:

```gdscript
# ❌ MAL — infiere Variant
var used := snapshot.get("slots_used", 0)

# ✅ BIEN — tipado explícito
var used: int = snapshot.get("slots_used", 0)
```

---

## Contrato de la View

### Estructura mínima obligatoria

```gdscript
extends CanvasLayer  # o Control según el caso
class_name MiPantalla

# 1. @onready de nodos del .tscn
@onready var mi_label: Label = %MiLabel
@onready var mi_boton: Button = %MiBoton

# 2. ViewModel como variable interna
var _vm: MiPantallaViewModel = null

func _ready() -> void:
    visible = false

    # Crear ViewModel como hijo
    _vm = MiPantallaViewModel.new()
    _vm.name = "ViewModel"
    add_child(_vm)
    _vm.changed.connect(_on_vm_changed)

    # Conectar input directo
    mi_boton.pressed.connect(func(): _vm.request_accion())

# 3. Callback único del ViewModel
func _on_vm_changed(reason: String) -> void:
    match reason:
        "opened":  _render_todo()
        "datos":   _render_datos()
        "waiting": _set_botones_enabled(false)
        "closed":  visible = false
        _: push_warning("[MiPantalla] Razón desconocida: %s" % reason)

# 4. Renders — uno por sección lógica
func _render_todo() -> void: ...
func _render_datos() -> void: ...

# 5. API pública — llamada desde SceneOrchestrator
func open() -> void:
    _vm.open()
```

### Feedback temporal

Para mensajes que desaparecen solos, usar `SceneTreeTimer` con referencia — nunca `await` en la View:

```gdscript
var _feedback_timer: SceneTreeTimer = null

func _show_feedback(mensaje: String, es_error: bool) -> void:
    feedback_label.text    = mensaje
    feedback_label.visible = true

    if _feedback_timer and is_instance_valid(_feedback_timer):
        _feedback_timer.timeout.disconnect(_hide_feedback)

    _feedback_timer = get_tree().create_timer(3.0)
    _feedback_timer.timeout.connect(_hide_feedback)

func _hide_feedback() -> void:
    if feedback_label:
        feedback_label.visible = false
```

### Textos localizados

Todos los textos visibles se asignan por código vía `tr()` — nunca hardcodeados en el `.tscn` ni en el script:

```gdscript
# ✅ CORRECTO
btn_new_game.text = tr("MENU_NEW_GAME")

# ❌ MAL — hardcodeado
btn_new_game.text = "Nueva Partida"
```

Las claves de localización van en el `.csv` correspondiente de `localization/`. El menú principal usa `menus.csv`; Character Creation usa `character_creation.csv`; otras pantallas pueden usar `translations.csv` o un fichero propio si el volumen lo justifica.

---

## Cómo crear un nuevo panel UI

### Paso 1 — Crear la carpeta

```
ui/nombre_pantalla/
```

### Paso 2 — Diseñar el ViewModel

Antes de escribir código, responder:

- ¿Qué estados tiene esta pantalla? → definir enum
- ¿Qué datos necesita renderizar la View? → definir variables públicas y data classes
- ¿Qué señales del EventBus escucha? → conectar en `_ready()`
- ¿Qué intenciones puede recibir del jugador? → definir `request_X()`
- ¿Qué razones emite `changed()`? → documentarlas en el signal

### Paso 3 — Implementar el ViewModel

Archivo: `nombre_viewmodel.gd`

Seguir la estructura de [Contrato del ViewModel](#contrato-del-viewmodel).

### Paso 4 — Crear el .tscn

Estructura de nodos con `%UniqueNames` para todos los nodos que la View referenciará. No añadir lógica en el inspector — solo estructura y propiedades visuales. Los textos de labels y botones se dejan vacíos; se asignan por código en `_setup_static_text()`.

### Paso 5 — Implementar la View

Archivo: `nombre_panel.gd` o `nombre_screen.gd`

Seguir la estructura de [Contrato de la View](#contrato-de-la-view).

### Paso 6 — Registrar en SceneOrchestrator

Si la pantalla es un overlay gestionado por `SceneOrchestrator`:

```gdscript
# En scene_orchestrator.gd
const OVERLAY_MI_PANTALLA := "res://ui/nombre_pantalla/nombre_panel.tscn"
```

Y añadir el handler correspondiente en `_on_game_state_changed()` o como método público (`open_X()`).

### Paso 7 — Añadir claves de localización

Toda cadena visible en la UI debe tener su clave en el `.csv` de localización correspondiente:

```csv
MI_PANTALLA_TITULO,My Panel Title,Título de mi panel
MI_PANTALLA_ERROR_X,Error message,Mensaje de error
```

Godot genera los `.translation` automáticamente al recargar el proyecto cuando el `.csv` está registrado en Project Settings → Localization → Translations.

---

## Reglas que no se rompen

| Regla | Motivo |
|-------|--------|
| La View nunca accede a sistemas core | Acoplamiento — rompe la separación de responsabilidades |
| El ViewModel nunca instancia nodos | Es lógica de presentación, no de View |
| `changed(reason)` es la única señal del VM hacia la View | Más señales = más acoplamiento View↔VM |
| El ViewModel es siempre hijo de la View | Garantiza que muere con ella y las señales se desconectan solas |
| Sin `await` en la View | Bloquea el estado; usar `SceneTreeTimer` con referencia |
| `await` en el ViewModel solo antes de cambiar escena | Única excepción: dar un frame para que la View procese `"transitioning"` |
| Sin flags implícitos en la View | Usar el enum del ViewModel; el estado es siempre explícito |
| Tipado estricto en GDScript | Godot 4 trata warnings como errores en este proyecto |
| Sin `static` en funciones de autoload | Los autoloads son instancias, no clases estáticas |
| Nombres de variables no colisionan con propiedades de Node | Ej: usar `btn_size` en lugar de `size` en Button |
| Textos siempre via `tr()`, nunca hardcodeados | Consistencia con el sistema de localización |
| Labels y botones vacíos en el .tscn | Los textos se asignan por código en `_setup_static_text()` |
| ViewModel de una Main Scene persistente escucha `EventBus.game_state_changed` | Puede volver a su estado por un camino externo — no solo por su propio código |

---

## Antipatrones conocidos

### ❌ Flag implícito de estado

```gdscript
# MAL — ¿qué significa _buttons_refreshed_by_state?
var _buttons_refreshed_by_state: bool = false
```

```gdscript
# BIEN — el estado es explícito y legible
enum PanelState { HIDDEN, SHOWING, WAITING, SHOWING_RESULT }
var state: PanelState = PanelState.HIDDEN
```

---

### ❌ await en la View

```gdscript
# MAL — bloquea el hilo de la View
func _show_feedback(msg: String) -> void:
    feedback_label.text = msg
    await get_tree().create_timer(3.0).timeout
    feedback_label.visible = false
```

```gdscript
# BIEN — timer con referencia, sin await
var _feedback_timer: SceneTreeTimer = null

func _show_feedback(msg: String) -> void:
    feedback_label.text    = msg
    feedback_label.visible = true
    if _feedback_timer and is_instance_valid(_feedback_timer):
        _feedback_timer.timeout.disconnect(_hide_feedback)
    _feedback_timer = get_tree().create_timer(3.0)
    _feedback_timer.timeout.connect(_hide_feedback)
```

---

### ❌ Acceso a sistemas core desde la View

```gdscript
# MAL — la View sabe demasiado
func _on_slot_clicked(item_id: String) -> void:
    var item_def = Items.get_item(item_id)
    if item_def.item_type == "EQUIPMENT":
        Equipment.toggle_equipment("player", item_id)
```

```gdscript
# BIEN — la View solo comunica la intención
func _on_slot_clicked(item_id: String) -> void:
    _vm.request_slot_action(item_id)
```

---

### ❌ Lógica de negocio en la View

```gdscript
# MAL — la View decide si transferir
func _on_drop_accepted(slot_id: String, item_id: String, entity_id: String) -> void:
    if not Inventory.has_item(entity_id, item_id):
        var source = _find_item_owner(item_id)
        _transfer_item(source, entity_id, item_id)
    Equipment.equip_item(entity_id, item_id)
```

```gdscript
# BIEN — el ViewModel valida y ejecuta, devuelve resultado
func _on_drop_accepted(slot_id: String, item_id: String, entity_id: String) -> void:
    var error := _vm.request_equip_drop(slot_id, item_id, entity_id)
    if not error.is_empty():
        _show_feedback(tr(error), true)
```

---

### ❌ Inferencia de Variant con Dictionary.get()

```gdscript
# MAL — Godot 4 trata esto como error con warnings-as-errors
var used := snapshot.get("slots_used", 0)
```

```gdscript
# BIEN — tipo explícito
var used: int = snapshot.get("slots_used", 0)
```

---

### ❌ Texto hardcodeado en el .tscn o en el script

```gdscript
# MAL — no localizable, difícil de mantener
btn_new_game.text = "Nueva Partida"
```

```gdscript
# BIEN — localizable, clave en menus.csv
btn_new_game.text = tr("MENU_NEW_GAME")
```

---

### ❌ ViewModel de una Main Scene persistente sin listener de EventBus

```gdscript
# MAL — solo se abre una vez, en _ready() de la View. Si el GameState
# vuelve a este estado por un camino externo (otra pantalla llamando a
# GameLoop.enter_main_menu()), el ViewModel se queda congelado en el
# último estado en el que estaba (ej: TRANSITIONING, botones deshabilitados)
func _ready() -> void:
    EventBus.alguna_señal.connect(_on_alguna_señal)
    # sin listener de game_state_changed
```

```gdscript
# BIEN — reacciona a cualquier cambio de GameState, lo haya originado
# esta pantalla o no
func _ready() -> void:
    EventBus.game_state_changed.connect(_on_game_state_changed)

func _on_game_state_changed(new_state: int) -> void:
    if new_state == GameLoopSystem.GameState.MENU:
        if state != MenuState.MAIN:
            open()
    else:
        if state != MenuState.HIDDEN:
            state = MenuState.HIDDEN
            changed.emit("hidden")
```

Este antipatrón solo aplica a pantallas cuya View es una Main Scene persistente (ej. `MainMenuScreen`) — para overlays normales instanciados/destruidos por `SceneOrchestrator` en cada apertura, el ciclo de vida ya resuelve esto (el ViewModel muere con la View).

---

## Referencia de pantallas existentes

| Pantalla | ViewModel | View | Descripción |
|----------|-----------|------|-------------|
| MainMenu | `main_menu_viewmodel.gd` | `main_menu_screen.gd` | Menú principal del juego. Main Scene del proyecto. Pantalla única con sub-paneles internos (opciones, créditos, confirmación de salida). No instanciada por SceneOrchestrator — arranca directamente. |
| WorldObject | `world_object_panel_viewmodel.gd` | `world_object_interaction_panel.gd` | Panel piloto del patrón. El más simple. Buen punto de partida para entender el flujo. |
| Inventory | `inventory_viewmodel.gd` | `inventory_screen.gd` | Pantalla con dos columnas (equipo + mochila), detalle de ítem y acciones. |
| Party | `party_viewmodel.gd` | `party_ui.gd` | Gestión de party con dos columnas simétricas. Incluye transferencia de ítems entre entidades. |
| Shop | `shop_viewmodel.gd` | `shop_ui.gd` | Tienda con snapshot inmutable. Abierta desde `SceneOrchestrator` via `show_shop_direct()`. |
| Dialogue | `dialogue_viewmodel.gd` | `dialogue_panel.gd` | Panel de diálogo con portrait, texto y opciones. El más reactivo — sin intenciones complejas. |
| CharacterCreation | `character_creation_viewmodel.gd` | `character_creation_screen.gd` | Roll-and-assign de atributos (2 pools separados, 1 reroll), nombre, resumen con `RichTextLabel`+BBCode. Interacción por click (no drag&drop) — chip seleccionado + slot destino. |

### Pantallas sin ViewModel (casos especiales)

| Pantalla | Script | Descripción |
|----------|--------|-------------|
| LoadingScreen | `loading_screen.gd` | Pantalla de carga pasiva. Sin ViewModel por ausencia de estado complejo. Usa `ResourceLoader.load_threaded_request()` y emite `loading_finished(packed_scene)`. Actualmente implementada pero no conectada a `SceneOrchestrator`. |

---

*Última actualización: Spike Character Creation — CharacterCreationScreen implementada (ya no es stub), nuevo antipatrón de ViewModel persistente sin listener de EventBus (detectado en MainMenuViewModel). Godot 4.7.1.*