# Spike 23 — Pantalla de inicio (informe de cierre)

*Cerrado: 2026-11-10. Validado por Fernando en partida (1152×648, 1680×1050, ES y EN).*

## Objetivo

Llevar la pantalla de inicio (`MainMenuScreen`, Main Scene) al Design System con identidad visual propia (fondo, título, marco), dejar las opciones correctas y persistentes, hacer la pantalla navegable con teclado y **dejar fondo y título como componente reutilizable para el Spike 24**, sin tocar el ciclo de vida de Main Scene, los flujos de sesión (Spike 14) ni el core.

## Decisiones (M1-M11)

| # | Decisión |
|---|---|
| M1 | Layout **A** (título centrado arriba, columna de botones centrada). Fernando prefería B; se elige A por robustez con arte provisional y por reutilizarlo en el 24. Cambiar de layout en el futuro es barato |
| M2 | Placeholder plano por tokens, con el componente preparado para recibir una textura. No hay arte propio del menú (solo fondos de la aventura de Los Telmori) |
| M3 | Opciones y Créditos como ventana con marco (0,5 del ancho, tope 620); Confirmar como modal pequeño (0,3 con mín. 380 y máx. 460). Se oculta la columna de botones bajo un velo |
| M4 | Idioma y pantalla completa como pares de `UIButton` segmentados (seleccionado `PRIMARY`, resto `SECONDARY`). Sin `OptionButton`, `CheckButton` ni tema local |
| M5 | **C**: persisten idioma y pantalla completa. Los sliders de volumen existen (rango 0-1) pero ocultos con `SHOW_VOLUME_SLIDERS = false`, a la espera del diseño del audio |
| M6 | «Cargar partida» fijo y bajo él una línea con la fecha localizada, o «Sin partida guardada». Sin tiempo jugado |
| M7 | Nueva partida `PRIMARY`; Cargar, Opciones y Créditos `SECONDARY`; Salir `GHOST`; en Confirmar, Sí `DANGER` y Cancelar `SECONDARY` |
| M8 | Foco inicial; Esc = Volver en Opciones, Créditos y Confirmar; Esc sin efecto en la principal |
| M9 | Créditos estáticos (el texto actual) |
| M10 | Título «ATHELIA» como texto en `COLOR_ACCENT` con `FONT_SIZE_DISPLAY`. Sin versión en el pie (no hay `config/version`) |
| M11 | Sin `SceneTreeTimer`: `load_blocked` solo refresca la línea de estado |
| Extra | **Opciones como componente propio** (`OptionsPanel` + `OptionsViewModel`), para reutilizarlo en un futuro menú de pausa y poder cambiar de idioma sin reiniciar la partida |
| Extra | `F9` en partida desestimado (decisión de Fernando); el código de quickload no se toca |

## Entregado

### Ficheros nuevos
- `ui/options/game_settings.gd` — `class_name GameSettings`, `RefCounted` con funciones estáticas. Lee, escribe y aplica `user://settings.cfg` (sección `[options]`: `language`, `fullscreen`, `music_volume`, `sfx_volume`). Sin fichero no toca nada: se conserva el arranque por defecto.
- `ui/options/options_viewmodel.gd` — único sitio que toca `AudioServer`, `DisplayServer` y `TranslationServer` (vía `GameSettings`). Razones de `changed`: `opened`, `fullscreen`, `language`, `volume`, `closed`.
- `ui/options/options_panel.gd` / `.tscn` — `class_name OptionsPanel extends UIPanel`; señal `closed`; no se libera a sí misma ni maneja Esc.
- `ui/design_system/components/title_backdrop/title_backdrop.gd` / `.tscn` — `class_name TitleBackdrop`: color base, `TextureRect` cover opcional, velo (solo con imagen) y título. Exports: `background_texture`, `title_text`, `show_title`, `title_top_fraction`.
- `localization/main_menu.csv` (`MAIN_MENU_*`, 13 claves) y `localization/options.csv` (`OPTIONS_*`, 8 claves), ambos `id,en,es`.

### Modificados
- `ui/main_menu/main_menu_screen.gd` / `.tscn` (uid conservado, sigue siendo Main Scene) y `main_menu_viewmodel.gd`.
- `ui/design_system/tokens/ui_tokens.gd` (aditivo): `FONT_SIZE_DISPLAY` (64), `COLOR_SCRIM`, `COLOR_MODAL_VEIL`.
- `localization/menus.csv`: salen las 17 claves `MENU_*` y `CREDITS_BODY` (quedan `LOADING_LABEL` y las `GAMEOVER_*`).

Sin cambios en el core (`GameLoop`, `SaveSystem`, `SceneOrchestrator`, `SessionReset`).

## Fase 0: lo que el código decía frente a la spec

- **No hay audio ni buses.** [L] Un único bus `Master`, sin ficheros `.ogg/.wav/.mp3` ni `AudioStreamPlayer`. Los sliders de volumen no controlaban nada: `get_bus_index` devolvía -1.
- **Rango de los sliders:** 0-100 por defecto con semántica 0-1 (tirador al ~1 %, +40 dB en el máximo). Confirmado por lectura y por el Output.
- **Créditos no mostraba el texto:** el `ScrollContainer` colapsaba a altura 0.
- **Cambiar de idioma sacaba al jugador de Opciones** (`_render_main()` con el ViewModel aún en `OPTIONS`). No estaba en la spec.
- **Confirmar solapaba** con el panel principal (confirmado en captura).
- **El proyecto arranca en pantalla completa** (`window/size/mode=3`).
- **El contador `playtime_seconds`** de `SaveSystem` suma desde que arranca el proceso, también en el menú, y ni Nueva partida ni `SessionReset` lo ponen a 0: no es fiable para mostrarlo. Fuera de alcance (core).
- **El timestamp** del guardado es ISO local (`AAAA-MM-DDTHH:MM:SS`), formateable en el ViewModel sin tocar el core.
- **Ninguna otra pantalla** usa las claves `MENU_*` ni cambia volumen, idioma o ventana.
- **La spec citaba `FRAME_MAX_SIZE` como token:** no existe; el tope 1400×820 vive en cada pantalla.
- **`UIButton` como script suelto** funcionaba igual que instanciar la escena; se pasa a instanciar `ui_button.tscn` (patrón del resto de pantallas).
- **Contraste del `PRIMARY` deshabilitado** (conocido del 21): se evita usando `SECONDARY` en «Cargar partida», con el motivo en una línea aparte.

## Reglas de la pantalla (para quien la toque)

- **Ciclo de vida intacto:** el ViewModel escucha `game_state_changed`; `MENU` → `open()`; cualquier otro estado → `hidden`. Arranque en frío sin `MENU`.
- **Orden de arranque:** `GameSettings.apply_saved()` en el `_ready()` del ViewModel; luego `_vm.open()` en la View; la carga pendiente de quickload (diferida) corre después.
- **Razones de `changed`** (todas con caso en la View): `main`, `options`, `credits`, `confirm_quit`, `transitioning`, `load_blocked`, `hidden`.
- **Esc** en `_input` de la View: solo en los estados `OPTIONS`, `CREDITS` y `CONFIRM_QUIT` equivale a Volver y consume el evento. En la principal, `HIDDEN` y `TRANSITIONING` no hace nada ni consume.
- **Cambio de idioma en caliente:** `NOTIFICATION_TRANSLATION_CHANGED` en la View y en el panel de opciones retraduce todos los textos, también los de paneles ocultos.
- **Paneles centrados por contenido:** anclas al centro, `grow` a ambos lados y offsets a 0, con `custom_minimum_size.x` por fracción de la pantalla.
- **Foco:** vuelve al botón desde el que se abrió el subpanel; en Confirmar empieza en Cancelar (no en la acción destructiva).
- **`request_back()`** ignora `HIDDEN` y `TRANSITIONING`.
- **Fecha del guardado:** el ViewModel la trocea en `save_date` ({y, m, d, h, min}) y la View la formatea con `MAIN_MENU_SAVE_DATE` (el orden día/mes/año depende del idioma).

## Bugs corregidos (además del rediseño)
1. Cambiar el idioma sacaba de Opciones.
2. Créditos sin texto visible.
3. Confirmar solapaba con el panel principal.
4. Sliders con rango 0-100 y semántica 0-1.
5. Las opciones no se guardaban entre ejecuciones.
6. Sin foco inicial ni Esc.

## Cambios visibles
Textos con minúscula tras la primera palabra («Nueva partida»), título dorado en vez de blanco y sin espaciado de letras, fecha en formato local, jerarquía de botones, marco en Opciones, Créditos y Confirmar, Confirmar como modal sin solape, Esc = Volver.

## Validación en partida (1152×648 y 1680×1050, ES y EN)
Validado por Fernando:
- Arranque en frío: título, jerarquía de botones, foco y fecha localizada; Output y *Errores* limpios.
- Opciones: pantalla completa ↔ ventana, idioma ES ↔ EN en caliente sin salir del panel, y persistencia del idioma tras reiniciar (`settings.cfg` con `[options]`).
- Créditos: texto visible con scroll, centrado y sin pisar el título; Esc y «Volver».
- Confirmar: modal centrado y compacto; Esc cancela.
- «Cargar partida» sin guardado (apagado y «Sin partida guardada») y con guardado (carga y entra en el juego).
- Nueva partida → «Volver al menú» y derrota → menú.
- Auditoría de contrato: sin `AudioServer`, `DisplayServer`, `TranslationServer`, `SaveManager`, `GameLoop`, `Color(`, `Button.new`, `Label.new`, `modulate` ni `SceneTreeTimer` en la View, el ViewModel y el panel de opciones (solo dos comentarios con esos nombres).

## Incidencias de la entrega (para no repetirlas)
1. **Parche de tokens duplicado:** el parche del ancla y el bloque «al final» eran dos caminos para lo mismo; la constante `FONT_SIZE_DISPLAY` quedó declarada dos veces y el autoload `UITokens` no compilaba, con errores en cascada en `ui_button.gd`, `party_ui.gd` y un test. Se dejó una sola declaración de cada constante.
2. **Paneles descentrados y Confirmar estirado:** `set_anchors_and_offsets_preset(..., PRESET_MODE_MINSIZE)` congela los offsets con el tamaño mínimo provisional del momento. Se sustituyó por anclas al centro + `grow` a ambos lados + offsets a 0.
3. **Autowrap en `ConfirmText`:** medido con poco ancho daba un mínimo enorme (el «estiramiento vertical» intermitente). Se quitó el autowrap (la frase cabe en una línea).
4. **Créditos pisaba el título a 648 de alto:** altura del scroll a 0,28 de la pantalla (tope 360).

## Lecciones nuevas (también en `athelia_lecciones_tecnicas.md`)
1. Para centrar un panel que sigue a su contenido, usar anclas al centro + `grow_horizontal/vertical = BOTH` + offsets a 0. `set_anchors_and_offsets_preset(..., MINSIZE)` calcula offsets con el mínimo del momento y no los actualiza si el contenido cambia después.
2. Un `Label` con autowrap dentro de un panel sin ancho fijo puede dar un mínimo desproporcionado si se mide antes de recibir su ancho: evitar autowrap en textos cortos de modales.
3. Un `const` duplicado en un autoload impide compilarlo y arrastra errores de tipo «Cannot infer the type» en todos los consumidores de `UITokens`. Cuando un fichero se parchea, dar **un único** camino (ancla o bloque final, nunca ambos).
4. `NOTIFICATION_TRANSLATION_CHANGED` llega a todos los nodos, también ocultos: basta con retraducir ahí (guardando `is_node_ready()` y la existencia del ViewModel) para cambiar de idioma en caliente sin recargar escenas.
5. El editor ejecuta el juego **incrustado** en la pestaña Game, que solo admite modo ventana («Embedded window only supports Windowed mode»): probar la pantalla completa con el juego en ventana propia o exportado.
6. Mover la lógica de configuración a un helper estático (`GameSettings`) permite que la lean y apliquen tanto el ViewModel del menú como el de Opciones sin autoloads ni dependencias del core.
7. Un panel de opciones extraído como componente con señal `closed` y sin autoliberación puede alojarse en el menú principal hoy y en un menú de pausa mañana.

## Pendientes (sin spike asignado salvo indicación)
- **Audio:** diseñar el audio, crear los buses `Music` y `SFX`, dar estilo a los sliders y poner `SHOW_VOLUME_SLIDERS = true` (hoy `false`, a petición de Fernando). La persistencia de volúmenes ya está preparada.
- **Menú de pausa / acceso a Opciones desde la partida:** reutiliza `OptionsPanel`. Exige orquestador y `GameLoop` (spike propio); cada pantalla debe retraducir al cambiar el idioma.
- **`fullscreen` guardado sin aplicarse:** con la ventana incrustada del editor el botón «Activada» guarda `fullscreen=true` aunque el modo no cambie. Mejora opcional: guardar el valor real tras aplicarlo.
- **Tiempo jugado del guardado:** el contador de `SaveSystem` incluye el tiempo de menú y no se reinicia (core).
- **Limpieza de quickload:** `consume_pending_quickload()` (ViewModel) y `_quickload()` (`ExplorationController`) siguen, aunque F9 está desestimado.
- **`TRANSITIONING` atascado:** si `enter_post_load_state()` o `enter_character_creation()` rechazan la transición, el menú no se recupera (mismo patrón que el 14 arregló en Game Over).
- **Versión en el pie:** requiere añadir `config/version` al proyecto.
- **Créditos:** sustituir los «Por definir» cuando haya contenido; el texto es el de `MAIN_MENU_CREDITS_BODY`.
- **Arte del menú:** asignar `background_texture` en la instancia de `TitleBackdrop` cuando exista; comprobar legibilidad con el velo.
- **Character Creation** (pantalla gris sin estilo, tamaños fijos): fuera del hito, en el barrido de §8 del plan.
- **Archivos de ayuda:** borrar `localization/menus.csv.bak`.

## Siguiente
**Spike 24 — Game Over: rediseño visual.** Hereda `TitleBackdrop` (fondo y título) y el estilo de arte de este spike.
