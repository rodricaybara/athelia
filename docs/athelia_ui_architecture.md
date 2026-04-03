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

Estructura de nodos con `%UniqueNames` para todos los nodos que la View referenciará. No añadir lógica en el inspector — solo estructura y propiedades visuales.

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

Toda cadena visible en la UI debe tener su clave en `localization/translations.csv`:

```csv
MI_PANTALLA_TITULO,My Panel Title,Título de mi panel
MI_PANTALLA_ERROR_X,Error message,Mensaje de error
```

---

## Reglas que no se rompen

| Regla | Motivo |
|-------|--------|
| La View nunca accede a sistemas core | Acoplamiento — rompe la separación de responsabilidades |
| El ViewModel nunca instancia nodos | Es lógica de presentación, no de View |
| `changed(reason)` es la única señal del VM hacia la View | Más señales = más acoplamiento View↔VM |
| El ViewModel es siempre hijo de la View | Garantiza que muere con ella y las señales se desconectan solas |
| Sin `await` en la View | Bloquea el estado; usar `SceneTreeTimer` con referencia |
| Sin flags implícitos en la View | Usar el enum del ViewModel; el estado es siempre explícito |
| Tipado estricto en GDScript | Godot 4 trata warnings como errores en este proyecto |
| Sin `static` en funciones de autoload | Los autoloads son instancias, no clases estáticas |
| Nombres de variables no colisionan con propiedades de Node | Ej: usar `btn_size` en lugar de `size` en Button |
| Zona dinámica separada de nodos fijos en pantallas complejas | Evita referencias colgantes al limpiar contenido generado por código |
| `free()` inmediato (no `queue_free()`) para limpiar zonas dinámicas dentro del mismo frame | `queue_free()` deja el nodo vivo hasta fin de frame — si se accede a él en ese mismo frame da "previously freed" |

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

### ❌ Mezclar nodos fijos y dinámicos en el mismo contenedor

```gdscript
# MAL — _clear_dynamic() hace queue_free() en algunos hijos
# pero luego accede a _train_btn que es hermano de los eliminados.
# En el mismo frame, Godot puede lanzar "previously freed".
func _clear_dynamic() -> void:
    var keep = ["TrainBtn", "FeedbackLabel"]
    for child in _panel.get_children():
        if child.name not in keep:
            child.queue_free()  # ← el nodo sigue "vivo" hasta fin de frame

func _render() -> void:
    _clear_dynamic()
    _panel.add_child(new_content)
    _panel.move_child(_train_btn, -1)  # ← puede fallar si queue_free aún no ejecutó
```

```gdscript
# BIEN — zona dinámica en un VBoxContainer hijo dedicado.
# Los nodos fijos (_train_btn, _feedback_label) nunca se tocan.
# free() inmediato garantiza que no hay referencias colgantes.

# En el .tscn:
# Panel (VBoxContainer)
# ├── HeaderFijo (Label)       ← fijo
# ├── PctFijo (Label)          ← fijo
# ├── DynamicContent (VBoxContainer) ← única zona que se vacía
# ├── FeedbackLabel (Label)    ← fijo
# └── TrainBtn (Button)        ← fijo

func _clear_dynamic() -> void:
    for child in _dynamic_content.get_children():
        child.free()  # inmediato — sin referencias colgantes

func _render() -> void:
    _clear_dynamic()
    _dynamic_content.add_child(new_content)
    _train_btn.disabled = not can_train  # nodo fijo — siempre accesible
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

## Referencia de pantallas existentes

| Pantalla | ViewModel | View | Descripción |
|----------|-----------|------|-------------|
| WorldObject | `world_object_panel_viewmodel.gd` | `world_object_interaction_panel.gd` | Panel piloto del patrón. El más simple. Buen punto de partida para entender el flujo. |
| Inventory | `inventory_viewmodel.gd` | `inventory_screen.gd` | Pantalla con dos columnas (equipo + mochila), detalle de ítem y acciones. |
| Party | `party_viewmodel.gd` | `party_ui.gd` | Gestión de party con dos columnas simétricas. Incluye transferencia de ítems entre entidades. |
| Shop | `shop_viewmodel.gd` | `shop_ui.gd` | Tienda con snapshot inmutable. Abierta desde `SceneOrchestrator` via `show_shop_direct()`. |
| Dialogue | `dialogue_viewmodel.gd` | `dialogue_panel.gd` | Panel de diálogo con portrait, texto y opciones. El más reactivo — sin intenciones complejas. |
| SkillTree | `skill_tree_viewmodel.gd` | `skill_tree_screen.gd` | Árbol de habilidades con modo individual y modo comparativa de party. El más complejo — zona dinámica en `DetailContent`, tier inferido de prerequisitos, query centralizada en `SkillSystem`. Primera pantalla que cumple el Design System al 100% (`UIButton`, `UITokens`). |

---

*Última actualización: spike SkillTreeScreen — zona dinámica separada, antipatrón free() vs queue_free(), SkillTree añadido a referencia de pantallas.*
