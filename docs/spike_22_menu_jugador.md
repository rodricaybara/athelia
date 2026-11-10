# Spike 22 — Menú del jugador (informe de cierre)

*Cerrado: 2026-11-10. Entregado en tres fases (pantalla, orquestador y buffs con herramienta de depuración), todas validadas en partida por Fernando.*

## Objetivo

Llevar `PlayerMenuScreen` / `PlayerMenuViewModel` al Design System (UIPanel OVERLAY con marco, `UIButton`, `UIResourceBar`, solo tokens, nodos `%`, claves `PLAYER_MENU_*` localizadas), mantener su estado en vivo sin reconstruir nodos y hacer predecible la navegación entre overlays, **sin cambiar el menú de solo lectura, las subpantallas ni el core de sistemas**.

## Decisiones (P1-P10 y extras)

| # | Decisión |
|---|---|
| P1 | Layout **C**: cabecera, fila de tres botones y tres paneles (Recursos, Atributos, Efectos activos). «Luego si eso ya lo cambiaremos» |
| P2 | `UIResourceBar` de 14 px para vida y estamina con «actual / máx» como texto a la derecha (el valor interno del componente sale a 10 px: no se toca el componente); oro como número dorado |
| P3 | Derivados + atributos base abreviados (`ATTR_ABBR_*`). Los base muestran el **valor efectivo** (opción A, ver «Observado») |
| P4 | Nombre localizado por clave `PLAYER_MENU_BUFF_<ID>` con el id crudo como respaldo; tiempo **en vivo en segundos enteros**; un `Timer` de 0,5 s en el ViewModel |
| P5 | Tres botones `LG`; atajo leído de `InputMap` por el ViewModel (Inventario I, Habilidades H); Loadout sin atajo (no tiene acción); sin Party |
| P6 / P6b | Regla (a) en el orquestador + (c) en la View; con una subpantalla abierta se ignoran H, I, O y P |
| P7 | Aprobado: `closed` conectado en `open_player_menu()` y regla de toggle en los cuatro `open_*` |
| P8 | Retirado el fallback a `tree_exiting` |
| P9 | `UIButton` `PRIMARY` deshabilitado: no se toca (el menú no lo usa) |
| P10 | Título = nombre del personaje (texto libre, sin `tr()`), sin retrato |
| Extra 1 | Corregir el refresco de recursos al equipar o desequipar: aprobado |
| Extra 2 | Claves a `localization/player_menu.csv`: aprobado |
| Equipo | Los seis slots del equipo **fuera de este spike** (spike propio) |

## Entregado

### Pantalla (`ui/player_menu/`)
- `player_menu_screen.tscn` / `.gd` reescritos: `Backdrop` + `Frame` (`UIPanel` OVERLAY, variante 2, marco decorativo, fracción 0,9, tope 1400×820, `viewport.size_changed`). Contenido en `Root`: cabecera (título y X en `GHOST` de 32 px), fila de navegación con tres `UIButton` `SECONDARY` `LG`, y tres `UIPanel` con un único contenedor cada uno. Atributos y buffs van en `ScrollContainer`. Todos los nodos por `%`.
- `player_menu_row.gd` (**nuevo**, `class_name PlayerMenuRow`, solo script): fila nombre/valor con tres tipos (`TEXT`, `BUFF` con barra fina, `RESOURCE` con `UIResourceBar`). Construye sus nodos por dentro, así que la View no usa `Label.new()`. Todo se actualiza en sitio.
- `player_menu_viewmodel.gd` reescrito: entrega claves y datos listos (`AttrEntry`, `NavEntry`, `BuffData`).
- `localization/player_menu.csv` (**nuevo**, 14 claves, `id,en,es`; alta manual en Project Settings). Se eliminan 7 líneas `MENU_*` de `translations.csv`.

### Único cambio fuera de `ui/player_menu/`
`core/scene_orchestrator.gd` (seis parches, solo toggle y `closed`):
- `LIGHT_OVERLAY_SCENES` (inventario, party, árbol, menú, loadout).
- `_handle_overlay_toggle(scene_path)`: con un overlay abierto, el **propio se cierra** (toggle), **otro ligero se ignora** y cualquier otro se cierra como antes. Identifica el overlay por `_current_overlay.scene_file_path`.
- Los cuatro `open_*` llaman a ese helper en lugar de `_hide_current_overlay()`.
- `open_player_menu()` conecta `closed` con `_on_overlay_closed` (patrón de inventario, party y árbol).

No se tocó ningún sistema del core ni los sub-overlays de `NarrativeScenePanel`.

## Fase 0: lo que el código decía frente a la spec y la documentación
- Las claves del menú estaban en `translations.csv` (`id,en,es`), **no** en `menus.csv`. Los `ATTR_*` también.
- Las teclas se reparten en dos sitios: `ExplorationController` (`I`, `O`, `P`; no consume) y `ExplorationHUD` (`H`, `P`; sí consume). La `P` duplicada es inocua porque el HUD la consume primero.
- El «Player UI» del `.tscn` nunca se veía (la View lo sobrescribía) y las cabeceras de sección no existían.
- **Buffs:** no existe ningún productor en producción (nadie llama a `add_temporary_state`) y `ModifierApplicator` no emite `temporary_state_added/removed/expired`. El ViewModel escuchaba `buff_applied`, que es del combate. La lista de buffs **no se refrescaba nunca**. `time_left` está en segundos reales (decrementado con `delta`).
- `character_name` del jugador es texto libre de Character Creation: sin `tr()`.
- `AttributeResolver.resolve()` solo sirve para derivados; con un atributo base devuelve 0.0 con aviso.
- Acciones del InputMap con un solo `physical_keycode`; **Tab no está enlazada** (comentario «I / Tab» obsoleto) y `toggle_inventory` no la usa nadie.
- Mapa real de la navegación (capturado antes de tocar): cualquier `open_*` cerraba cualquier overlay abierto; con una subpantalla abierta cerraba menú y subpantalla juntos.

## Reglas de la pantalla (para quien la toque)
- **Teclas, en `_input` de la View:** con el menú visible consume `ui_cancel` y `open_player_menu` (cierran) y `open_inventory` / `open_skill_tree` (abren la subpantalla). Con una subpantalla abierta **solo consume `open_player_menu`**; Esc, I, H y O no se tocan.
- **Razones de `changed`** (todas con caso en la View): `opened`, `attributes`, `resources`, `buffs`, `buff_times`, `open_loadout`, `open_inventory`, `open_skill_tree`, `closed`.
- **Recursos:** `resource_changed` marca sucio y un único `call_deferred` por frame refresca y emite `resources`; la View solo llama a `set_values()` y cambia textos.
- **Buffs:** un `Timer` hijo del ViewModel relee `active_states` cada 0,5 s mientras el menú está abierto. Si cambian los ids, emite `buffs` (y refresca atributos y recursos); si no, `buff_times`.
- **Atributos base:** valor efectivo = base + suma de modificadores `add` activos con target `attribute.<id>` (`Characters.get_active_modifiers()`). No se aplican `mul` ni `override`. Verde si suma, rojo si resta, tooltip «Base X, modificadores +Y».
- Equipar o desequipar refresca atributos y recursos; `open()` desconecta antes de conectar (sin eventos duplicados).

## Bugs corregidos (además de la migración)
1. Doble `P` tras cerrar con X o Esc (el orquestador no conectaba `closed`).
2. `I`, `H` u `O` con el menú abierto lo cerraban entero; `I` con Party la cerraba; con una subpantalla abierta, `P`, `H`, `I` u `O` cerraban menú y subpantalla.
3. Los máximos de vida y estamina no se refrescaban al equipar.
4. La lista de buffs no se refrescaba nunca y el tiempo no avanzaba.
5. Buffs con el id crudo y sin respaldo localizado.
6. El menú se pintaba sin fondo ni marco sobre el mapa, pisando el HUD de exploración.
7. Rutas `$Root/...` de 10 niveles, `Label.new()` en la View, trazas `print` y comentarios obsoletos.

## Validación en partida (1152×648 y 1680×1050, ES y EN)
Validado por Fernando:
- Fase 1: apertura, marco, barras, atributos, X y Esc, `I`/`H`/`P` dentro del menú, `P` con subpantalla abierta, atributos tras equipar y desequipar, valor efectivo de DES con las botas (12 en verde, tooltip), auditoría de contrato vacía, barras a ancho correcto tras ajustar los stretch ratio (1,3 en Recursos).
- Fase 2: `P` a la primera tras X o Esc, y las teclas con otro overlay abierto (menú, subpantalla, Party, Inventario) según la regla acordada.
- Fase 3: F10 («Vigor (prueba)», 20 s, barra fina) y F11 (seis buffs con respaldo de id crudo, sin desbordar a 648), regeneración de estamina con F12 (el menú la sigue, sin parpadeos).
- Contexto narrativo y anidado de tres niveles, menú no abre en combate, reinicio de sesión sin eventos duplicados, regresión de Inventario, Party, Árbol y Loadout, pestaña *Errores* limpia.

## Sin confirmar / sin validar
- Scroll de la lista de buffs con más de seis (a 648 caben seis sin desbordar).
- Captura en inglés a 1680×1050.
- Buffs con modificadores reales sobre atributos (los de depuración llevan lista vacía).
- Que `scene_file_path` coincida con las constantes `OVERLAY_*` en todos los casos: lo validan indirectamente las pruebas de Party, Inventario y menú, no una traza directa.

## Observado y no tocado
- **Los modificadores `attribute.<base>` no afectan a los derivados.** `_resolve_linear_combination` lee `state.get_base_attribute()`: el `+2 DES` de las botas no cambia la Iniciativa (16 con DES 10 y con DES efectiva 12) ni ningún otro derivado. El menú muestra el bono declarado por el ítem (opción A, decidida por Fernando); arreglarlo es un cambio de motor con spike propio.
- `ModifierApplicator` no emite señales al aplicar o expirar estados temporales y nadie los aplica en producción.
- La unidad de la duración de los buffs de **habilidades** (`SKILL_BUFF_*`, segundos o turnos) sigue sin definir; los estados temporales del personaje son segundos reales.
- Tab no enlazada a `open_inventory`: comentario obsoleto «Tecla I / Tab» en `ExplorationController`; acción `toggle_inventory` sin uso.
- `open_loadout()` sin llamadores y con comentario obsoleto («llamado desde `PlayerMenuViewModel.request_open_loadout()`»).
- Trazas de depuración ajenas: `[DBG] tecla:` en `ExplorationController` y `[DIAG]` en `narrative_scene_panel.gd`.
- Loadout no tiene atajo de teclado (exigiría una acción nueva del InputMap).

## Lecciones nuevas (también en `athelia_lecciones_tecnicas.md`)
1. Con un orquestador de slot único, identificar el overlay abierto por `scene_file_path` y decidir con una sola regla («propio se cierra, otro ligero se ignora»).
2. Una pantalla anidada oculta debe seguir consumiendo en `_input` la tecla que cierra a su padre, o el evento llega al orquestador y cierra todo.
3. Si el core no emite señales de un estado, el ViewModel puede sondear con un `Timer` solo mientras está abierto y emitir razones distintas para «cambió la lista» y «cambió el tiempo».
4. `AttributeResolver.resolve()` no sirve para atributos base; usar `Characters.get_all_base_attributes()` y `get_active_modifiers()`.
5. Un componente de pantalla de solo script (fila) evita `Label.new()` en la View y permite actualizar en sitio.
6. Las acciones con `physical_keycode` se muestran con `DisplayServer.keyboard_get_keycode_from_physical()` para que la letra sea correcta en cualquier teclado.
7. `UIResourceBar` pinta su valor a 10 px: para un texto legible, ponerlo en una etiqueta aparte.
8. Mostrar un bono declarado por un ítem no garantiza que el motor lo aplique: comprobarlo contra los derivados antes de prometerlo.

## Limpieza al cerrar (hecha por Fernando)
- `debug_buff_tool.gd` y su autoload `DebugBuffTool` fuera.
- Clave `PLAYER_MENU_BUFF_DEBUG_VIGOR` fuera de `player_menu.csv`.

## Siguiente
**Spike 23 — Pantalla de inicio**, que no depende de ninguna otra pantalla.
