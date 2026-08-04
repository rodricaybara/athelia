# Athelia — Informe de Cierre: Spike Menú Principal

**Fecha:** Agosto 2026  
**Estado:** ✅ Completado  
**Rama de trabajo:** `ui/main_menu`

---

## Objetivo

Implementar el flujo de inicio del juego: pantalla de menú principal, pantalla de carga, y stub de creación de personaje. Integrar todo con la arquitectura existente (GameLoop, SceneOrchestrator, SaveManager) sin romper el flujo de exploración y combate ya funcional.

---

## Decisiones de diseño tomadas

| Decisión | Opción elegida | Motivo |
|---|---|---|
| Arquitectura UI | MVVM completo | Consistencia con el resto del proyecto |
| Estructura de escena | Una sola escena con paneles internos | Simplicidad, fácil de evolucionar |
| Slot de guardado | Único (`quicksave`) | Diseño existente de SaveManager |
| Pantalla de carga | Implementada ahora | Los mapas crecerán — mejor tenerla desde el inicio |
| Créditos | Texto scrolling en panel interno | Sin assets, sin escena separada |
| Opciones | Volumen, pantalla completa, idioma | Scope mínimo viable |
| Guardar desde menú | Eliminado | Se guarda en checkpoints o F5 |
| Estética | Design System existente | Sin assets nuevos, placeholder de título |

---

## Archivos creados

### Nuevos
| Archivo | Ruta | Descripción |
|---|---|---|
| `main_menu_viewmodel.gd` | `ui/main_menu/` | ViewModel del menú principal |
| `main_menu_screen.gd` | `ui/main_menu/` | View del menú principal |
| `main_menu_screen.tscn` | `ui/main_menu/` | Escena del menú principal |
| `loading_screen.gd` | `ui/loading_screen/` | Pantalla de carga (sin ViewModel) |
| `loading_screen.tscn` | `ui/loading_screen/` | Escena de la pantalla de carga |
| `character_creation_screen.gd` | `scenes/character_creation/` | Stub — lógica pendiente |
| `character_creation_screen.tscn` | `scenes/character_creation/` | Escena stub |
| `menus.csv` | `localization/` | Claves de localización para menús |

### Modificados
| Archivo | Cambios |
|---|---|
| `game_loop_system.gd` | Añadido `CHARACTER_CREATION` al enum `GameState`, transiciones `MENU ↔ CHARACTER_CREATION`, métodos `enter_main_menu()` y `enter_character_creation()` |
| `scene_orchestrator.gd` | Añadidas constantes `SCENE_MAIN_MENU` y `SCENE_CHARACTER_CREATION`, ramas `MENU` y `CHARACTER_CREATION` en el match, handlers `_handle_main_menu()` y `_handle_character_creation()` |
| `combat_test_scene.gd` | Guard de doble registro en SkillSystem, `_input` → `_unhandled_input` |
| `player_combat_controller.gd` | Action names alineadas con InputMap (`combat_attack_1/2/3`, `combat_dodge`, `combat_defense`, `combat_scape`), `_input` → `_unhandled_input` |

---

## Arquitectura del menú principal

```
CanvasLayer (MainMenuScreen)
└── Control (full rect)
    ├── BackgroundRect          ← placeholder, futuro: ilustración
    ├── TitleLabel              ← "ATHELIA", futuro: logo
    ├── MainPanel (VBoxContainer)
    │   ├── BtnNewGame          → GameLoop.enter_character_creation()
    │   ├── BtnLoadGame         → SaveManager.load_game("quicksave") → enter_exploration()
    │   ├── BtnOptions          → panel interno
    │   ├── BtnCredits          → panel interno
    │   └── BtnQuit             → confirmación → get_tree().quit()
    ├── OptionsPanel            ← volumen música, volumen SFX, fullscreen, idioma
    ├── CreditsPanel            ← texto scrolling
    └── ConfirmQuitPanel        ← diálogo Sí/No
```

### Estados del ViewModel

```
HIDDEN → MAIN → OPTIONS → MAIN
              → CREDITS → MAIN
              → CONFIRM_QUIT → MAIN (cancelar) / quit (confirmar)
              → TRANSITIONING (nueva partida / cargar)
```

### Razones de `changed()`

| Razón | Efecto en la View |
|---|---|
| `"main"` | Muestra MainPanel, oculta el resto |
| `"options"` | Muestra OptionsPanel |
| `"credits"` | Muestra CreditsPanel |
| `"confirm_quit"` | Muestra ConfirmQuitPanel |
| `"transitioning"` | Deshabilita todos los botones |
| `"load_blocked"` | Feedback temporal en BtnLoadGame (2 segundos) |

---

## Flujo de estados del juego

```
(arranque del ejecutable)
    → GameLoop: estado inicial MENU
    → SceneOrchestrator: _handle_main_menu() — sin acción (escena ya es el menú)
    → MainMenuScreen._ready() → _vm.open() → changed("main")

Nueva partida:
    MENU → CHARACTER_CREATION
    → SceneOrchestrator._handle_character_creation()
    → instancia character_creation_screen.tscn → open()

Cargar partida:
    SaveManager.load_game("quicksave")
    → MENU → EXPLORATION
    → SceneOrchestrator._handle_exploration()
```

---

## Claves de localización añadidas (`menus.csv`)

```
MENU_NEW_GAME, MENU_LOAD_GAME, MENU_OPTIONS, MENU_CREDITS, MENU_QUIT
MENU_BACK, MENU_CONFIRM_YES, MENU_CONFIRM_NO
MENU_NO_SAVE_FOUND, MENU_CONFIRM_QUIT_TEXT
MENU_OPTIONS_TITLE, MENU_MUSIC_VOL, MENU_SFX_VOL, MENU_FULLSCREEN, MENU_LANGUAGE
MENU_CREDITS_TITLE, CREDITS_BODY
LOADING_LABEL
```

---

## Bugs corregidos durante el spike

### Doble registro en SkillSystem al entrar en combate
**Causa:** `combat_test_scene._initialize_player()` llamaba `Skills.register_entity_skills()` sin comprobar si el player ya estaba registrado desde la escena de exploración.  
**Fix:** Guard `if not Skills._entity_skills.has(player_id)` — mismo patrón que ya usaba `CharacterSystem`.

### Teclas de combate no funcionaban tras actualización a Godot 4.7
**Causa 1:** `skill_hotkeys` en `PlayerCombatController` referenciaba actions inexistentes (`skill_1`, `skill_2`, `skill_3`, `defend`, `flee`) en lugar de las definidas en el InputMap (`combat_attack_1/2/3`, `combat_dodge`, `combat_defense`, `combat_scape`).  
**Causa 2:** En Godot 4.7, `_input` en nodos del árbol principal tiene prioridad sobre `_unhandled_input` en nodos hijo de escenas aditivas, bloqueando los eventos antes de que llegaran al controller.  
**Fix:** Actualizar action names en `skill_hotkeys` + cambiar `_input` → `_unhandled_input` en `PlayerCombatController` y `combat_test_scene`.

---

## Pendiente / próximos pasos

- [ ] **Character Creation Screen** — implementar lógica real (nombre, atributos, habilidades iniciales). Requiere spike propio con decisiones de diseño previas.
- [ ] **LoadingScreen integrada en SceneOrchestrator** — actualmente está implementada pero no conectada. Integrar cuando las escenas de exploración crezcan en tamaño.
- [ ] **Estética del menú** — placeholder funcional. Evolucionar con ilustración de fondo y logo cuando haya assets.
- [ ] **Opciones persistentes** — volumen e idioma se pierden al cerrar. Guardar en `SaveManager` o en un fichero de configuración separado.
- [ ] **Sliders de opciones** — ajustar tamaño con `size_flags_horizontal = Expand` y `custom_minimum_size`.
- [ ] **Main Scene** confirmada como `res://ui/main_menu/main_menu_screen.tscn` en Project Settings.

---

## Resultado

Flujo completo funcional:

```
Menú Principal → Nueva Partida → Character Creation (stub)
              → Cargar Partida → Exploración (si existe save)
              → Opciones ✅
              → Créditos ✅
              → Salir ✅
Exploración → Combate ✅ (flujo preexistente, bugs corregidos)
```
