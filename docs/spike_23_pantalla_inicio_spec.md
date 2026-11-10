# Spike 23 — Pantalla de inicio: rediseño con el Design System, arte y opciones

**Hito:** rediseño de interfaces · **Riesgo:** bajo-medio · **Depende de:** Spike 15 (cerrado). No depende de ninguna otra pantalla. **El 24 (Game Over) depende de este** (hereda el estilo de arte, fondo y título).
**Fuentes leídas en esta sesión:** paquete Fase 0 de la pantalla de inicio (`main_menu_screen.gd`, `main_menu_screen.tscn`, `main_menu_viewmodel.gd`), informes de los Spikes 14 y 15, informe del Spike 22 (cierre del menú del jugador), extractos de `GameOverUI` (para el flujo de derrota) y plan del hito.
**Aviso:** el paquete Fase 0 es **anterior** a los spikes 14-22 (de hecho su comentario cita el Spike 7). No he visto `SaveSystem` (`has_save`, `get_save_info`, `consume_pending_quickload`), `project.godot`, el `audio_bus_layout`, `UIButton`/`UIPanel` tras los últimos spikes, los CSV del menú ni los assets. Lo que dependa de ello va marcado **[sin verificar]** y se cierra en la Fase 0.

---

## 1. Qué es el Spike 23

La pantalla de inicio es la **Main Scene** del juego: Nueva partida, Cargar partida, Opciones, Créditos y Salir (con confirmación). Es la más limpia de las ocho pantallas del hito (MVVM correcto, textos con `tr()`, `UIButton` y `UIPanel` ya enlazados) y la que menos cambia en estructura, pero **la primera que ve el jugador**: le faltan arte, título, marco y un diseño de las opciones. Este spike la lleva al Design System, le da identidad visual (que el 24 heredará) y arregla lo que la lectura del código deja dudoso (rango de los *sliders*, opciones que se pierden, solapes, foco), **sin cambiar el ciclo de vida de Main Scene ni los flujos de sesión** del Spike 14.

## 2. Problema (lo leído en el paquete Fase 0)

### 2.1 Escena (`main_menu_screen.tscn`)
- **Sin arte:** fondo = `ColorRect` con **`Color(0.10, 0.09, 0.09)` literal**; título = `Label` con texto fijo **«ATHELIA»** (sin `tr()`), `font_size = 55` suelto en la escena, anclado a pantalla completa (ocupa todo el rectángulo y solo se ve arriba por alineación).
- **`CanvasLayer` con `layer = 0`** y raíz `Control`; la estructura usa `%` en los nodos importantes (bien), pero hay contenedores sin nombre único (`HBoxContainer`…`HBoxContainer4`, `VBoxContainer`) y **orden de nodos incoherente** en Opciones (volumen de efectos antes que el título, música al final).
- **Posicionamiento por `offset` mínimo:** `MainPanel` y los tres sub-paneles se anclan al centro con offsets de ±20-70 px y **crecen según contenido**; sin tamaño mínimo ni fracción de pantalla. Sin marco decorativo.
- **`UIPanel` aplicado como script suelto** (`script = ui_panel.gd`) en `PanelContainer`, y **`UIButton` como script suelto** en `Button` (no instanciando `ui_button.tscn`, como hacen el resto de pantallas); variante y tamaño **por defecto** en los siete botones **[verificar que así se ven bien y que `_ready` de los componentes se ejecuta]**.
- **Controles sin Design System:** `HSlider`, `CheckButton`, `OptionButton` y `Label` sin tema (el tema global no está aplicado, ver README del DS): se ven con el estilo por defecto de Godot.
- **`HSlider` sin `min_value`/`max_value`/`step` en el `.tscn`:** valores por defecto 0-100 con paso 1, pero el código los trata como **0-1** (`db_to_linear`/`linear_to_db`). Consecuencia probable: el valor inicial se recorta a 1 (≈1 %), arrastrarlo hasta 100 da **+40 dB** y nunca llega a silencio. **[verificar en partida]**
- **Panel de confirmación de salida** centrado sobre el panel principal, que **sigue visible** (solo deshabilita sus botones): los dos paneles se solapan **[verificar con captura]**.

### 2.2 View (`main_menu_screen.gd`)
- **Textos asignados por código** en `_setup_static_text()`; al cambiar de idioma se vuelven a asignar todos (bien), pero la View toca a mano 22 nodos.
- **Acceso directo a singletons del motor** desde la View: `AudioServer` (buses `Music` y `SFX`), `DisplayServer` (modo de ventana) y `TranslationServer` (idioma). No son sistemas del juego, pero es **lógica de configuración en la View**, no en el ViewModel (contrato MVVM del hito).
- **Las opciones no se guardan:** volumen, pantalla completa e idioma se aplican en caliente y **se pierden al cerrar el juego** (la View los lee del motor al abrir) **[verificar si hay persistencia en otro sitio]**. Si los buses `Music`/`SFX` no existen (`get_bus_index < 0`), el *slider* no hace nada y el valor inicial es 1.0 **[verificar `audio_bus_layout.tres`]**.
- **Idiomas fijos en código:** `add_item("Español")`, `add_item("English")` y `match index: 0/1`.
- **Botón «Cargar partida» con la fecha concatenada** al texto (`tr(...) + "\n" + timestamp`), con el *timestamp* **tal cual** (sin formato localizado) y sin tiempo jugado, aunque `save_info` trae `playtime_seconds`.
- **Feedback de «sin partida» con `SceneTreeTimer`** (2 s) que además deja el botón `disabled = true`. `load_blocked` solo se alcanza por la carga pendiente del *quickload* (Spike 7): con el botón deshabilitado, el clic normal no llega a `request_load_game()` **[verificar]**.
- **Sin foco inicial** ni navegación por teclado/mando definida; **Esc no hace nada** (ni vuelve desde Opciones/Créditos/Confirmar) **[verificar]**.
- **Sin variante de botón por importancia:** los cinco botones se ven iguales.
- **`credits_label`:** `Label` con autowrap en un `ScrollContainer`; el ViewModel documenta «iniciar scroll» pero no hay ningún autoscroll.

### 2.3 ViewModel (`main_menu_viewmodel.gd`)
- **Bien estructurado:** `MenuState` (`HIDDEN`, `MAIN`, `OPTIONS`, `CREDITS`, `CONFIRM_QUIT`, `TRANSITIONING`); razones `main`, `options`, `credits`, `confirm_quit`, `transitioning`, `load_blocked`, `hidden`. Escucha `EventBus.game_state_changed`: `MENU` → `open()` (si no estaba en `MAIN`), cualquier otro estado → `HIDDEN`. **Ese ciclo de vida se conserva.**
- **Acceso a `SaveManager`** con `get_node_or_null("/root/SaveManager")` y al `GameLoop` con `get_node_or_null("/root/GameLoop")` (patrón antiguo; funciona).
- **Consume `consume_pending_quickload()` en `_ready()`** y dispara `request_load_game()` con `call_deferred` (Spike 7): el menú **carga solo** tras `F9`. Cualquier cambio de arranque debe respetarlo.
- **Trazas `print`** en todas las transiciones.
- `request_new_game()` y `request_load_game()` esperan un frame (`await process_frame`) antes de llamar a `GameLoop`; si `GameLoop` falla, vuelven a `MAIN`.
- **No expone** los datos de opciones (volumen, pantalla completa, idioma): la View los gestiona sola.
- **`confirm_quit()` → `get_tree().quit()`** sin comprobar que no haya nada pendiente de guardar (no aplica: el menú es previo a la partida).

### 2.4 Localización
- Claves `MENU_*` (nuevo juego, cargar, opciones, créditos, salir, volumen, pantalla completa, idioma, volver, confirmar sí/no, «no hay partida»), `MENU_OPTIONS_TITLE`, `MENU_CREDITS_TITLE` y `CREDITS_BODY`. En el Spike 22 se vio que las claves de menú estaban en `translations.csv` y no en `menus.csv`; en el 14 se mencionó `menus.csv` (fila `MENU_CONFIRM_YES` con comas) **[verificar dónde está cada una, duplicados y orden de columnas]**.
- Título «ATHELIA» y nombres de idioma («Español», «English») **sin localizar** (los nombres de idioma suelen escribirse en su propio idioma; el título es marca).
- Posible choque de prefijo con las claves `MENU_*` ya retiradas por el Spike 22 (menú del jugador) **[verificar que no hay claves huérfanas ni colisiones]**.

### 2.5 Contextos de uso (a validar)
1. **Arranque en frío:** Main Scene; **no emite `MENU`**; el ViewModel hace `open()` en `_ready()`.
2. **Nueva partida → Character Creation → «Volver al menú»:** `GameLoop.enter_main_menu()` → `MENU` → `open()`.
3. **Derrota → Game Over → menú** (Spike 14): reinicio de sesión y `MENU`.
4. **Cargar partida:** `load_game("quicksave")` + `enter_post_load_state()`; la pantalla pasa a `HIDDEN`.
5. **Quickload en juego (`F9`):** recarga de escena y carga automática desde el menú recién arrancado.
6. **Cambio de resolución/pantalla completa** con el menú abierto (sin estiramiento: anclas y fracciones).

## 3. Objetivo

Que la pantalla de inicio tenga **identidad visual** (arte de fondo, título, marco), use el Design System (`UIPanel` con marco para Opciones/Créditos/Confirmar, `UIButton` `LG` con jerarquía de variantes, solo tokens, `%`, claves localizadas), tenga **opciones correctas y persistentes**, sea **navegable con teclado**, y deje **componentes de fondo y título reutilizables** para el Game Over (24), **sin tocar el ciclo de vida de Main Scene, los flujos de sesión ni el core**.

## 4. Decisiones ya tomadas (no reabrir)

1. **Ciclo de vida de Main Scene intacto:** la pantalla sigue siendo la escena principal; el ViewModel sigue escuchando `game_state_changed` (`MENU` → abrir; otro estado → `hidden`); arranque en frío sin `MENU`; `request_new_game()`/`request_load_game()` conservan su secuencia (transición, un frame, `GameLoop`) y el consumo del *quickload* pendiente.
2. **MVVM:** la View no accede a sistemas ni a singletons de configuración; la lógica de opciones pasa al ViewModel. ViewModel hijo de la View; razón nueva de `changed` ⇒ caso en la View **en el mismo cambio**; entrega claves y la View traduce.
3. **Sin cambios de core:** `GameLoop`, `SaveSystem`, `SceneOrchestrator`, `AdventureStarter` y el reinicio de sesión (Spike 14) no se tocan sin aprobación expresa.
4. **Design System:** `UIPanel` con marco (variante opaca/overlay) para Opciones, Créditos y Confirmar salida; `UIButton` `LG` (instanciados como en el resto de pantallas, no como script suelto); solo tokens; sin `Color(...)`, sin `modulate` para estados, sin tamaños de fuente sueltos.
5. **Layouts por anclas y fracciones** (referencia 1680×1050, mínimo 1152×648, sin estiramiento); funciona en ventana, en pantalla completa y al alternar.
6. **Nodos únicos `%`**, nunca rutas `$A/B/C`; contenido de cada panel en un único contenedor.
7. **Textos con `tr()`** y claves con prefijo de pantalla (`MAIN_MENU_*`) en un CSV propio (`id,en,es`); sin claves comunes.
8. **Maqueta antes de código:** 2-3 layouts a 1680×1050 y 1152×648 y espera de la elección.
9. **El arte que se cree es reutilizable por el Game Over (24):** fondo y título se implementan como componente(s) independientes de la pantalla (ver §7.A).
10. **No se sustituye la lógica de sesión** (nueva partida/cargar) ni se añaden pantallas nuevas (selector de ranuras de guardado, perfiles).

## 5. Fase 0 — comprobaciones antes de escribir código

Cada punto termina como «confirmado», «descartado» o «cambia el diseño». **Empieza por 5.A.**

### 5.A Línea base y estado real

| # | Comprobación | Por qué |
|---|---|---|
| 0.1 | Capturas «antes» a 1152×648, 1680×1050 y pantalla completa, ES y EN: principal, Opciones, Créditos y Confirmar salida (¿se solapan los paneles?), con y sin partida guardada. | Referencia y hallazgos 2.1. |
| 0.2 | Comprobar que los ficheros del paquete **coinciden con el código actual** (`Get-FileHash` o `Select-String` de `class_name MainMenuScreen`, `consume_pending_quickload`, `confirm_quit`). | El paquete es anterior al hito. |
| 0.3 | Reproducir los *sliders* de volumen: valor inicial, arrastre hasta el máximo y hasta el mínimo, ¿suena distinto?, ¿existen los buses `Music` y `SFX` en `audio_bus_layout.tres`? | Hallazgo del rango 0-100. |
| 0.4 | ¿Se guardan las opciones en algún sitio (`user://`, `ProjectSettings`, `ConfigFile`)? Reiniciar el juego tras cambiar idioma/volumen/pantalla completa. ¿Quién fija el idioma por defecto (`internationalization/locale/test`, `fallback`)? | Persistencia (M5). |
| 0.5 | Mapa de flujos actuales con el Output: arranque en frío, Nueva partida → «Volver al menú» desde Character Creation, derrota → menú, `F9`, Cargar con y sin guardado. | Contextos 2.5 y que no hay regresión del Spike 14/7. |

### 5.B Código y datos

| # | Comprobación | Por qué |
|---|---|---|
| 0.6 | `project.godot`: `run/main_scene`, `display/window/size` (mínimo), `stretch/mode`, `window/size/mode`, ¿`audio/buses/default_bus_layout`?; autoloads. | Ciclo de vida de Main Scene y comportamiento al cambiar de ventana. |
| 0.7 | `SaveSystem`: `has_save()`, `get_save_info()` (campos reales: `timestamp`, `playtime_seconds`; **formato** del timestamp), `consume_pending_quickload()`; ranura única `"quicksave"`. | Mostrar fecha/tiempo jugado localizados sin tocar el core. |
| 0.8 | Cómo muestra/oculta el menú el orquestador (`_handle_main_menu()`, `_free_session_scenes()`), `layer` del `CanvasLayer` frente a overlays (`layer = 10`), y quién instancia `MainMenuScreen` si no es Main Scene directa. | No romper el Spike 14. |
| 0.9 | `UIButton`: variantes (`PRIMARY`, `SECONDARY`, `GHOST`, `DANGER`), tamaños (`LG`), estilo **deshabilitado** (el `PRIMARY` deshabilitado era ilegible, lección del 21), **estilo de foco**, `min_square`; diferencia entre instanciar `ui_button.tscn` y adjuntar el script a un `Button`. | Jerarquía de botones y accesibilidad. |
| 0.10 | `UIPanel`: variantes y marco (`Backdrop` + `Frame`, fracción 0,9, tope 1400×820, `FRAME_MAX_SIZE`), cómo se hace un **modal** pequeño centrado (Confirmar) frente a una ventana grande (Opciones/Créditos). | Tres sub-paneles de tamaños distintos. |
| 0.11 | `ui_tokens.gd`: ¿hay token de fuente de título/*display*? ¿tamaños `FONT_SIZE_*` hasta cuánto? ¿colores de velo/overlay para texto sobre imagen? | Título y legibilidad sobre arte. |
| 0.12 | Assets: ¿qué arte existe en `assets/` o `art/` (fondos, logo, fuentes)? ¿Cómo cargan otras pantallas imágenes de fondo (Diálogo: `BackgroundImage`; narrativa: `SceneImage`)? | Decide M2 y el componente reutilizable. |
| 0.13 | CSV: dónde están `MENU_NEW_GAME`, `MENU_LOAD_GAME`, `MENU_OPTIONS`, `MENU_CREDITS`, `MENU_QUIT`, `MENU_OPTIONS_TITLE`, `MENU_MUSIC_VOL`, `MENU_SFX_VOL`, `MENU_FULLSCREEN`, `MENU_LANGUAGE`, `MENU_BACK`, `MENU_CREDITS_TITLE`, `CREDITS_BODY`, `MENU_CONFIRM_*`, `MENU_NO_SAVE_FOUND`; duplicados con `Group-Object`; filas con comas sin comillas; registro en Project Settings. | Localización completa y sin huérfanas. |
| 0.14 | Contrato: `Select-String -CaseSensitive 'AudioServer|DisplayServer|TranslationServer|SaveManager|GameLoop|Color\(|StyleBoxFlat|Button\.new|Label\.new|modulate|SceneTreeTimer|\$'` en `main_menu_screen.gd`, y `get_node_or_null\("/root` en el ViewModel. | Línea base de la auditoría de cierre. |
| 0.15 | `ExplorationController`/`GameLoop`: qué hace `Esc` en estado `MENU`; si `ui_cancel` llega a la pantalla. | Navegación por teclado (M8). |
| 0.16 | Qué ocurre con las opciones en otras pantallas: ¿hay otro punto donde se cambien volumen/idioma (pausa, partida)? | Duplicación de lógica de opciones. |

## 6. Decisiones abiertas que resuelve el usuario al empezar

Preguntar **de una vez**, con lo que el código permite en cada una:

| # | Pregunta | Condicionante |
|---|---|---|
| M1 | **Layout.** (A) Título centrado arriba y columna de botones centrada sobre el arte; (B) título arriba a la izquierda y botones en columna a la izquierda sobre el arte (clásico de RPG); (C) botones dentro de un `UIPanel` con marco central sobre el arte. | 0.1, 0.12; maqueta decide. |
| M2 | **Arte.** ¿Qué hay? (fondo a pantalla completa, logotipo del título, ambas, ninguna). Placeholder si no existe: degradado/velo por token y título en texto con tamaño de token. ¿Música fuera? ¿Se reutiliza en Game Over? | 0.12. Si hay imagen, se carga como el Diálogo (cover) con velo para legibilidad. |
| M3 | **Subpantallas.** Opciones y Créditos como ventanas con `UIPanel` y marco (ocultando los botones principales) y Confirmar salida como modal pequeño sobre un velo (sin solapar los botones). ¿Se confirma? | 0.10; solape actual (2.1). |
| M4 | **Controles de Opciones** (sliders, casilla, desplegable): (a) restilar por tokens con un tema local al panel de opciones; (b) crear componentes del DS (`UISlider`, `UIToggle`, `UIDropdown`) en este spike; (c) dejar el estilo por defecto. | No existen en el DS; (b) amplía el alcance. Recomiendo (a). |
| M5 | **Opciones.** (a) solo arreglar el rango de los *sliders* y mover la lógica al ViewModel; (b) además **persistirlas** (p. ej. `user://settings.cfg`) y aplicarlas al arrancar; ¿dónde vive esa persistencia sin tocar el core? | 0.3, 0.4. Recomiendo (b) con la persistencia dentro del ViewModel (Main Scene corre siempre al arrancar). |
| M6 | **Cargar partida.** Texto del botón fijo y datos de la partida (fecha, tiempo jugado) en una línea secundaria o *tooltip*, **localizados**; estado deshabilitado legible («Sin partida guardada»). | 0.7, 0.9. |
| M7 | **Jerarquía de botones.** Nueva partida `PRIMARY`; Cargar, Opciones y Créditos `SECONDARY`; Salir `GHOST`; en Confirmar, Sí `DANGER` / No `SECONDARY`. ¿Se confirma? ¿Y el `PRIMARY` deshabilitado ilegible (¿se arregla el componente ahora?) | 0.9; si «Cargar» no es `PRIMARY` el problema no aparece. |
| M8 | **Teclado/mando.** Foco inicial en el primer botón habilitado, navegación arriba/abajo, Esc = Atrás en Opciones/Créditos/Confirmar (y nada en la principal). ¿Se confirma? ¿Esc en la principal abre Confirmar salida? | 0.15. |
| M9 | **Créditos.** Texto estático con scroll manual (hoy) o autoscroll (el ViewModel lo menciona); ¿contenido nuevo (versión del juego, motor, créditos de arte)? | `CREDITS_BODY`. Recomiendo estático. |
| M10 | **Título y versión.** «ATHELIA» como texto con token (no localizable) o imagen; ¿se muestra la versión (`application/config/version`) en el pie? ¿Nombre del idioma en su propio idioma? | 0.11. |
| M11 | **Feedback de carga.** ¿Se mantiene `load_blocked` (solo alcanzable por el *quickload* pendiente) como línea de feedback fija con token y `Timer`, o se simplifica? | 2.2. |

**Recomendación a confirmar:** M1 (A) o (C) según el arte, M2 con placeholder si no hay arte y componente reutilizable, M3 confirmado, M4 (a), M5 (b), M6 confirmado, M7 confirmado (sin tocar `PRIMARY` deshabilitado), M8 confirmado, M9 estático, M10 título como texto/arte y versión en el pie, M11 simplificar a una línea fija.

## 7. Alcance

### 7.A Estructura, arte y componentes
- Raíz `Control` a pantalla completa: **fondo** (imagen con cover + velo por token, o degradado placeholder), **título** y **contenido** (columna de botones o panel, según M1).
- Fondo y título como **componente(s) reutilizables** (p. ej. un nodo `MenuBackdrop` + título; ubicación según 0.12/convención de carpetas) para el Game Over (24); la pantalla de inicio es el primer consumidor.
- `UIButton` `LG` **instanciados desde `ui_button.tscn`** con la jerarquía de M7; ancho mínimo fraccional; foco visible.
- Opciones, Créditos y Confirmar salida con `UIPanel` + marco (tamaños acordes a M3); Opciones con filas ordenadas (título, música, efectos, pantalla completa, idioma, volver) en un único contenedor; controles según M4.
- Todos los nodos con `%`; eliminar `HBoxContainer`… sin nombre; sin `Color(...)` ni `font_size` en la escena.

### 7.B ViewModel
- **Opciones en el ViewModel:** estado público (`music_volume`, `sfx_volume`, `fullscreen`, `language`, lista de idiomas con nombre), intenciones (`request_set_music_volume()`, `request_set_sfx_volume()`, `request_set_fullscreen()`, `request_set_language()`), y razón `options_changed` (con caso en la View). Aplica en `AudioServer`/`DisplayServer`/`TranslationServer` **desde el ViewModel** y, si M5 (b), carga/guarda la configuración y la aplica en `_ready()`.
- Datos de la partida para «Cargar» (fecha y tiempo jugado formateados o claves + valores), sin acceso de la View a `SaveSystem`.
- Se conservan `MenuState`, las razones actuales, `game_state_changed`, el consumo del *quickload* y las secuencias de `request_new_game()`/`request_load_game()`.
- Retirar trazas `print` innecesarias; actualizar comentarios obsoletos («iniciar scroll»).

### 7.C Teclado y foco
- Foco inicial, navegación y Esc según M8, con `ui_cancel` consumido solo por esta pantalla y solo cuando está visible (`hidden` no debe consumir entrada de otras pantallas).

### 7.D Localización
- CSV propio `main_menu.csv` (`id,en,es`, claves `MAIN_MENU_*`; alta manual en Project Settings → Localization) que absorbe las claves del menú principal y elimina las líneas retiradas de `translations.csv`/`menus.csv`; claves nuevas (sin partida, fecha, tiempo jugado, versión, títulos de sección, nombres de idioma si procede); revisión de duplicados con `Group-Object`.

### 7.E Limpieza
- Retirar `SceneTreeTimer` de la View; sin `modulate`; sin `Label.new()`/`Button.new()`.
- Anotar en `estado_actual.md` lo que se decida no tratar (selector de ranuras, perfiles, música, componentes `UISlider`/`UIToggle` si M4 ≠ (b)).

## 8. Cambio visual y funcional esperado

| Antes | Después |
|---|---|
| Fondo `ColorRect` con color literal; «ATHELIA» a 55 px suelto | Arte (o placeholder por token) y título con token |
| Cinco botones iguales, tamaño por defecto | `UIButton` `LG` con jerarquía de variantes |
| Sub-paneles centrados y mínimos, sin marco; Confirmar solapa | `UIPanel` con marco; Confirmar modal sobre velo |
| Controles de opciones con el estilo por defecto | Controles con tokens (M4) |
| *Sliders* 0-100 tratados como 0-1; opciones que se pierden | Rango correcto; opciones persistentes (M5) |
| Fecha en bruto pegada al botón de cargar | Fecha y tiempo jugado localizados en línea secundaria |
| Sin foco ni Esc | Foco inicial, navegación y Esc = Atrás |
| Lógica de opciones en la View | Opciones en el ViewModel |

**No cambian:** ciclo de vida de Main Scene, flujos de sesión (Spike 14), carga automática tras `F9` (Spike 7), `GameLoop`, `SaveSystem`, `SceneOrchestrator`.

## 9. Fuera de alcance
- Selector de ranuras de guardado, perfiles, «continuar última partida» y borrado de partidas.
- Música y efectos de sonido del menú; ajuste de volumen maestro; opciones de gráficos más allá de pantalla completa; remapeo de teclas.
- Componentes `UISlider`, `UIToggle`, `UIDropdown` en el DS (salvo M4 (b)).
- Rediseño del Game Over (Spike 24: solo se deja el componente de fondo/título reutilizable).
- Cambios en `GameLoop`, `SaveSystem`, `SceneOrchestrator`, reinicio de sesión.
- Retirar `DebugPartyTool` y las trazas `[DBG]`/`[DIAG]` (cierre del hito).
- Localización de contenidos de créditos más allá de `CREDITS_BODY`.

## 10. Reglas a respetar
- MVVM y antipatrones de `athelia_ui_architecture.md`; ViewModel hijo de la View; la pantalla no se libera a sí misma (es Main Scene).
- Componentes del DS sin acceso a sistemas; setters de `@export` con `is_node_ready()`; subclase de `UIPanel` llama a `super._ready()` y fija `padding` antes.
- Un `PanelContainer` apila todos sus hijos; `ScrollContainer` con `size_flags_vertical = 3` reparte a partes iguales; `Label` con elipsis junto a otro expansivo se colapsa.
- `UIButton`: instanciar `ui_button.tscn`; el `PRIMARY` deshabilitado es ilegible (si hay botones que se deshabilitan, usar `SECONDARY`).
- `remove_child()` antes de `queue_free()`; `Dictionary.get()` tipado con `as`; `tr()` no existe en funciones estáticas.
- Al cambiar el idioma en caliente, **todos** los textos (incluidos los de paneles ocultos) se vuelven a traducir.
- Auditar el contrato con `Select-String -CaseSensitive`. Teclas de depuración fuera de F5-F8.
- `.csv` con campos con comas entre comillas; claves únicas; alta manual del CSV nuevo; `PowerShell 5.1` con scripts sin acentos.
- Commit o copia de `ui/main_menu/` y `ui/design_system/` antes de empezar. ViewModel y View se entregan juntos.

## 11. Validación en partida real

A 1152×648, 1680×1050 y pantalla completa, ES y EN, con capturas antes/después:
1. **Línea base (0.1-0.5):** capturas y mapa de flujos con el Output.
2. **Arranque en frío:** menú principal con arte y título; foco en el primer botón habilitado; sin avisos en el Output.
3. **Nueva partida** → Character Creation → **«Volver al menú»**: el menú reaparece con los botones habilitados y sin quedarse en transición.
4. **Cargar partida**, con y sin guardado: botón deshabilitado legible y con el motivo; con guardado, fecha y tiempo jugado localizados; la carga entra en el juego.
5. **`F9` en partida:** recarga y carga automática (Spike 7) sin pasar por pantalla intermedia visible.
6. **Derrota → Game Over → menú** (Spike 14): menú operativo, nueva partida limpia.
7. **Opciones:** música y efectos (rango completo, silencio real, sin +40 dB), pantalla completa (alternar sin romper el layout), idioma ES↔EN (se traducen **todos** los textos, también Cargar y los paneles ocultos); **cerrar el juego, reabrir y comprobar que se conservan** (M5).
8. **Créditos:** texto completo con scroll, Volver y Esc.
9. **Salir:** Confirmar sobre velo (sin solapar), «No» vuelve y «Sí» cierra.
10. **Teclado:** foco visible, flechas, Intro, Esc según M8; ratón sin regresiones.
11. **Cambio de resolución** con el menú abierto (arrastrar la ventana al mínimo 1152×648): sin recortes ni solapes.
12. **Reinicios de sesión** repetidos (derrota → menú → partida nueva → derrota): una sola instancia del menú, sin señales duplicadas.
13. **Localización:** sin claves crudas en ES ni EN; sin huérfanas ni duplicados.
14. **Contrato:** `Select-String -CaseSensitive` de la View sin `AudioServer`, `DisplayServer`, `TranslationServer`, `SaveManager`, `GameLoop`, `Color(`, `Button.new`, `modulate`, `SceneTreeTimer`.
15. Pestaña *Errors* del Depurador sin avisos nuevos.

## 12. Riesgos conocidos
- **Main Scene:** cualquier cambio en el arranque puede romper el reinicio de sesión (Spike 14) o la carga automática tras `F9` (Spike 7). El ViewModel y sus razones se conservan.
- **Persistencia de opciones** sin tocar el core: dónde se guarda y cuándo se aplica (`_ready()` del ViewModel), y no pisar el idioma de prueba del proyecto.
- **Sliders en 0-100 con semántica 0-1:** posible volumen +40 dB en producción hoy.
- **Controles sin DS** (sliders, casilla, desplegable): el restilado por tema local puede no cubrir todos los estados (foco, hover, deshabilitado).
- **Sobre un arte real, la legibilidad del texto** depende del velo; el arte final puede no existir.
- **Cambio de idioma en caliente:** textos de paneles ocultos o del botón Cargar sin refrescar.
- **Foco y `ui_cancel`:** una pantalla oculta que sigue consumiendo Esc rompería las demás (lección del Spike 22).
- **Componente de fondo/título compartido con el 24:** acoplarlo a esta pantalla en vez de hacerlo independiente.
- **Paquete Fase 0 obsoleto:** puede no coincidir con el código actual (0.2).

## 13. Entregables

**Código (completo):** `main_menu_screen.gd`, `main_menu_viewmodel.gd` (entregados juntos) y los scripts nuevos del fondo/título reutilizable. **Escenas:** `main_menu_screen.tscn` (completa o como árbol de nodos legible, con el padre de cada nodo verificado; conserva el uid, es Main Scene) y las nuevas del componente de fondo/título. **Parches:** `ui_tokens.gd` si falta algún token (título, velo), componentes del DS (aditivos, con aprobación). **Datos:** `main_menu.csv` (ES y EN, orden real de columnas) y limpieza de `translations.csv`/`menus.csv`; alta manual en Project Settings → Localization.

**Documentación:**
- `docs/spike_23_pantalla_inicio.md` (informe de cierre: respuestas M1-M11, cambios en View/ViewModel, qué se descubrió de los *sliders* y de la persistencia, validación, lecciones y pendientes).
- `athelia_ui_architecture.md` (fila de MainMenu, editada en su sitio), `athelia_referencia_sistemas.md` (si hay persistencia de opciones), `athelia_historial_spikes.md` (un párrafo con enlace), `athelia_estructura_carpetas.md`, README del Design System si cambia algún componente.
- `athelia_lecciones_tecnicas.md`: solo lecciones nuevas.
- `estado_actual.md`: tabla y pendientes (23 cerrado; 24 es el siguiente y hereda el arte).
- Plan del hito: cerrar el 23 y anotar pendientes nuevos.
