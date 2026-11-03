# Spike 22 — Menú del jugador: rediseño del hub y navegación entre overlays

**Hito:** rediseño de interfaces · **Riesgo:** medio · **Depende de:** Spikes 18 (Inventario), 20 (Loadout) y 21 (Árbol de habilidades), todos cerrados. Usa lo aprendido en 19b (`UIResourceBar.set_values()`, pestañas) y 21 (`closed` conectado en el orquestador).
**Fuentes leídas en esta sesión:** paquete Fase 0 del menú (`player_menu_screen.gd`, `player_menu_screen.tscn`, `player_menu_viewmodel.gd`), extracto del orquestador (`open_inventory`, `open_party`, `open_skill_tree`, `open_player_menu`, `open_loadout`), informes 20 y 21, `estado_actual.md` y plan del hito.
**Aviso:** el paquete Fase 0 es **anterior** a los spikes 14-21. No he visto el manejo de teclas (`I`, `H`, `O`, `P`), el `NarrativeScenePanel` actual, el sistema de buffs, `menus.csv` ni `UIButton`/`UIResourceBar` tras los últimos spikes. Lo que dependa de ello va marcado **[sin verificar]** y se cierra en la Fase 0.

---

## 1. Qué es el Spike 22

El menú del jugador es el **hub** del personaje: muestra su estado (recursos, atributos derivados, buffs) y abre las subpantallas **Loadout**, **Inventario** y **Árbol de habilidades**. Es la última pantalla «de datos» del hito. Este spike hace dos cosas:

1. **Rediseña el propio menú** con el Design System (hoy son `Label` y `Button` sueltos en un `PanelContainer`, con rutas `$Root/...` de 7 niveles y un título «Player UI» de relleno).
2. **Arregla la navegación entre overlays**, que el orquestador de slot único (`_current_overlay`) hace frágil: `I` dentro del menú lo cierra entero, `I` con Party abierta la cierra, y hace falta doble `P` tras cerrar el menú.

## 2. Problema (lo leído en el paquete Fase 0)

### 2.1 View (`player_menu_screen.gd` / `.tscn`)
- **Rutas `$Root/Panel/MarginContainer/VBox/ContentHBox/StatusPanel/...`** de hasta 8 niveles para 11 nodos; el `.tscn` no usa nombres únicos.
- **`PanelContainer` propio a pantalla completa**, sin `UIPanel` ni marco; `Button` y `Label` raw; `HSeparator` por defecto; título con texto **«Player UI»** en la escena (relleno).
- **Recursos como texto** (`"Salud: 12 / 20"`) y no como barras: `UIResourceBar` ya existe y tiene `set_values()` (19b).
- **Atributos:** solo los **derivados** (`DISPLAYED_ATTRIBUTES`: `health_max`, `stamina_max`, `initiative`, `melee_damage`, `armor_rating`) con clave `ATTR_<ID>`; no se ven los atributos base (FUE, DES…) **[verificar qué ve hoy el jugador y si las claves existen]**. Las filas se crean con `Label.new()` y `_clear_container` usa `free()`.
- **Buffs:** muestra el **id crudo** (`buff.buff_id`) y `"(%.1fs)"` de `time_left`, que **no se actualiza en vivo** (solo se repinta cuando llega `buff_applied` / `temporary_state_removed`). La unidad (segundos/turnos) no está definida (ver pendiente del 21).
- **Navegación:** tres `Button` (Loadout, Inventario, Árbol). No hay botón de Party (se abre con su propia tecla) **[verificar]**, ni indicación de atajos de teclado.
- **Cabecera:** botón «X» raw; Esc cierra con `_input` + `set_input_as_handled()` (bien).
- **`_open_subscreen()`:** correcto y se conserva el contrato, pero su comentario y su **fallback a `tree_exiting`** están obsoletos (las tres subpantallas exponen `closed` desde los Spikes 17/20/21). Instancia la subpantalla como hijo, oculta el menú y, al cerrar, hace `queue_free()` + `visible = true` + `_vm.open(_character_id)` (refresco completo).
- **`print("[PlayerMenuScreen] Ready")`** y trazas de depuración.

### 2.2 ViewModel (`player_menu_viewmodel.gd`)
- Bien estructurado y de solo lectura: `opened`, `attributes`, `buffs`, `resources`, `open_loadout/inventory/skill_tree`, `closed`. Se suscribe a `EventBus` (equipo, buffs, recursos) mientras está abierto y se desuscribe al cerrar.
- **`resources` se emite con cada cambio de recurso** (la estamina se regenera): la View repinta tres `Label`; con barras debe actualizarse en sitio y no reconstruir nada (lección de 19b: una vez por frame).
- **`BuffData` guarda `buff_id`, `time_left`, `duration` sin nombre localizado**; no hay clave por buff **[verificar el sistema de buffs y sus datos]**.
- `character_name = Characters.get_character_name(id)`: **[verificar si devuelve texto o clave]** (riesgo de doble `tr()`, ya ocurrió en el Loadout).
- El comentario de intenciones dice «SceneOrchestrator las ejecuta», pero es la **View** quien abre las subpantallas (comentario obsoleto).
- Acceso a `Characters`, `Resources`, `AttributeResolver` y `EventBus` desde el ViewModel (correcto).

### 2.3 Orquestador de slot único (`scene_orchestrator.gd`)
- Un solo `_current_overlay`. `open_inventory()`, `open_party()`, `open_skill_tree()`, `open_player_menu()` hacen *toggle*: **si hay cualquier overlay abierto, lo cierran** (`_hide_current_overlay()`), aunque sea otro distinto.
  - Con el **menú abierto**, pulsar `I` (o la tecla del árbol/Party) **cierra el menú entero** en vez de abrir esa pantalla o ignorarla.
  - Con **Party abierta**, `I` la cierra.
- **`open_player_menu()` no conecta `closed`** (a diferencia de inventario/party/árbol, Spikes 17 y 21): tras cerrar con X/Esc el menú sigue ocupando `_current_overlay` y hace falta **una segunda pulsación de `P`** (mismo fallo que tenía el árbol con `H`).
- **`open_loadout(character_id)`:** sin llamadores (decisión del Spike 20: dejarlo). Su comentario dice «llamado desde `PlayerMenuViewModel.request_open_loadout()`», lo cual **ya no es cierto**.
- Estados permitidos: `LIGHT_OVERLAY_ALLOWED_STATES`; en `NARRATIVE_SCENE` los `open_*` se **ignoran** a propósito: el `NarrativeScenePanel` gestiona sus propios sub-overlays (Inventory, Party, PlayerMenu) con `_open_sub_overlay`/`_close_sub_overlay`.
- **No he visto quién traduce las teclas** (`I`, `H`, `O`, `P`) a estas llamadas **[sin verificar: ¿`ExplorationController`, `ExplorationHUD`, `InputMap`?]**.

### 2.4 Contextos de uso (los tres a validar)
1. **Exploración:** `P` → `open_player_menu()` → `PlayerMenuScreen` como overlay del orquestador.
2. **Escena narrativa:** `NarrativeScenePanel` abre `PlayerMenuScreen` como **sub-overlay propio** (el `closed` lo escucha el panel).
3. **Anidado a tres niveles** (narrativa → menú → Inventario/Loadout/Árbol): cada capa debe cerrarse y devolver a la anterior con datos refrescados.

### 2.5 Localización
- Claves `MENU_*` (`menus.csv`, columnas `id,es,en`, **al revés que el resto**): `MENU_HEALTH`, `MENU_STAMINA`, `MENU_GOLD`, `MENU_NO_BUFFS`, `MENU_LOADOUT`, `MENU_INVENTORY`, `MENU_SKILL_TREE`, `ATTR_*` **[verificar cuáles existen y cuáles faltan]**. Títulos de sección (`ResourcesLabel`, `AttributesLabel`, `BuffsLabel`) sin texto en el `.tscn`: se rellenan o no **[verificar]**.
- Posible reutilización de `RESOURCE_*_NAME` frente a `MENU_HEALTH/STAMINA/GOLD` (duplicidad de claves de recursos).

## 3. Objetivo

Que el menú del jugador sea **visualmente homogéneo** con el resto (marco `UIPanel`, `UIButton`, `UIResourceBar`, solo tokens, nodos `%`, textos y buffs localizados), que su **estado se actualice en vivo** sin reconstruir nodos, y que la **navegación entre overlays** sea predecible: ninguna tecla de otra pantalla debe cerrar el menú por error y cerrar el menú debe liberar el slot a la primera.

## 4. Decisiones ya tomadas (no reabrir)

1. **Contratos públicos intactos:** `PlayerMenuScreen.open(character_id)`, señal `closed` (la pantalla nunca se libera; quien instancia hace `queue_free()`), `_open_subscreen()` (gestión de subpantallas por el propio menú, `SceneOrchestrator` sin intervenir en esa navegación) y las tres subpantallas con su contrato (`s.open(id)`, `s.open_inventory()`, `closed`).
2. **MVVM:** la View no accede a sistemas ni a clases de core. ViewModel hijo de la View; `changed(reason)`; **cada razón nueva lleva su caso en la View en el mismo cambio**. El ViewModel entrega claves; la View traduce (criterio del Loadout/Árbol).
3. **El menú sigue siendo de solo lectura:** no escribe estado del personaje.
4. **Marco:** `UIPanel` OVERLAY con marco decorativo (padding 16, fracción 0,9, tope 1400×820, fondo opaco), como Inventario/Party/Loadout/Árbol. Referencia 1680×1050, mínimo 1152×648; anclas y fracciones.
5. **Componentes del DS:** `UIButton` (variantes y tamaños existentes), `UIResourceBar.set_values()` desde la View (no `bind()`). Cambios en componentes **aditivos** y con aprobación.
6. **Solo tokens** y `tr()` con claves del menú; sin `Color(...)`, sin `modulate` para estados, sin tamaños de fuente sueltos.
7. **Nodos únicos `%`**, nunca rutas `$A/B/C`; contenido de cada panel en **un único contenedor**.
8. **Maqueta antes de código:** 2-3 layouts a 1680×1050 y 1152×648 y espera de la elección.
9. **El slot único del orquestador no se sustituye por una pila general de overlays** salvo que lo decida el usuario (P6); el cambio mínimo es la prioridad.
10. **Absorbe** los pendientes de la sección de este spike en el plan y `estado_actual.md`: `I` dentro del menú cierra el menú entero; `I` con Party abierta la cierra; doble `P`.

## 5. Fase 0 — comprobaciones antes de escribir código

Cada punto termina como «confirmado», «descartado» o «cambia el diseño». **Empieza por 5.A.**

### 5.A Línea base y estado real

| # | Comprobación | Por qué |
|---|---|---|
| 0.1 | Capturas «antes» del menú a 1680×1050 y 1152×648, ES y EN, con y sin buffs. | Referencia y medidas reales. |
| 0.2 | Reproducir y anotar con el Output: (a) `P` abre, X/Esc cierra, `P` otra vez (¿doble pulsación?); (b) con el menú abierto, `I`, la tecla del árbol y la de Party; (c) con Party abierta, `I`; (d) con Inventario abierto desde el menú, `I`/`P`. | Hallazgos 2.3. |
| 0.3 | Comprobar que los ficheros del paquete **coinciden con el código actual** (`Get-FileHash` o `Select-String` de `class_name PlayerMenuScreen`, `signal closed`, `_open_subscreen`, `DISPLAYED_ATTRIBUTES`). | El paquete es anterior al hito. |
| 0.4 | Quién traduce las teclas a `open_inventory/open_party/open_skill_tree/open_player_menu` (búsqueda de `open_player_menu`, `open_inventory`, `ui_inventory`… en `core/` y `ui/`, y `[input]` de `project.godot`). Qué hace cada tecla en `NARRATIVE_SCENE`, `COMBAT` y `PAUSE`. | Sin esto no se puede diseñar la regla de P6. |
| 0.5 | Cómo abre el `NarrativeScenePanel` el `PlayerMenuScreen` (`_open_sub_overlay`), quién escucha `closed` y qué teclas llegan al panel o al orquestador mientras está abierto. | Segundo contexto y anidado de tres niveles. |
| 0.6 | Estado actual de `_current_overlay` en cada transición: abrir/cerrar menú, abrir subpantalla, cerrar subpantalla, cerrar menú desde la subpantalla (`I`). | Mapa real de la navegación. |

### 5.B Código y datos

| # | Comprobación | Por qué |
|---|---|---|
| 0.7 | `_hide_current_overlay()`, `_on_overlay_closed()`, `_show_overlay()` y `LIGHT_OVERLAY_ALLOWED_STATES` en el orquestador actual; cómo conectan `closed` hoy `open_inventory`, `open_party` y `open_skill_tree`. | Reutilizar el mismo patrón en `open_player_menu`. |
| 0.8 | Sistema de buffs: origen de `active_states` de `CharacterState`, forma del diccionario (`id`, `time_left`, `duration`), claves de nombre/descripción localizables por id, si el tiempo es real (segundos) o por turnos, quién lo decrementa y si emite señal por tick. | Buffs localizados y en vivo (P4); la unidad está pendiente de diseño. |
| 0.9 | `Characters.get_character_name()`: ¿texto o clave? `AttributeResolver.resolve()` para los atributos mostrados y para los **atributos base**; claves `ATTR_*` existentes. | Doble `tr()` y P3. |
| 0.10 | `menus.csv`: claves existentes y faltantes (`MENU_*`, `ATTR_*`), orden real de columnas (`id,es,en`), duplicados con `Group-Object`; registro en Project Settings. Duplicidad con `RESOURCE_*_NAME`. | Localización completa. |
| 0.11 | `UIResourceBar` actual: `set_values()`, colores por token (¿variantes salud/estamina?), altura mínima (fija 14 px en `_ready()`, lección del 21). | Barras de HP/EN en el menú. |
| 0.12 | `UIButton`: tamaño `LG`, variante deshabilitada de `PRIMARY` (ilegible según el 21), `min_square`, icono. | Navegación y decisión P9. |
| 0.13 | `UIPanel`/patrón de cabecera de Inventario/Loadout/Árbol (título, cierre, esquina) para copiar el patrón exacto. | Homogeneidad. |
| 0.14 | Contrato: `Select-String -CaseSensitive 'Characters\.|Resources\.|AttributeResolver|Skills\.|Inventory\.|Color\(|Button\.new|Label\.new|\$Root|modulate'` en `player_menu_screen.gd`. | Línea base de la auditoría de cierre. |
| 0.15 | Quién más llama a `PlayerMenuScreen.open()` y con qué id (¿siempre `"player"`?). Y si algún flujo necesita el menú de un compañero. | Alcance del selector de personaje (fuera por defecto). |

## 6. Decisiones abiertas que resuelve el usuario al empezar

Preguntar **de una vez**, con lo que el código permite en cada una:

| # | Pregunta | Condicionante |
|---|---|---|
| P1 | **Layout.** (A) Conservar la estructura de dos columnas (estado | navegación) con el Design System; (B) cabecera con nombre y barras de HP/EN/oro arriba, atributos y buffs en una columna y navegación en tarjetas grandes en la otra; (C) navegación como fila de botones grandes bajo la cabecera y el estado debajo. | 0.1; maqueta decide. |
| P2 | **Recursos.** `UIResourceBar` para salud y estamina, oro como número con etiqueta/icono. ¿Se confirma? ¿Valor numérico dentro de la barra? | 0.11. |
| P3 | **Atributos.** (a) solo los derivados actuales; (b) derivados + atributos base del personaje; (c) agrupados con sección propia. ¿Se muestran bonos de equipo? | 0.9; las claves `ATTR_*`. |
| P4 | **Buffs.** (a) nombre localizado + tiempo restante estático como hoy; (b) nombre localizado + tiempo **en vivo**; (c) nombre localizado sin tiempo hasta definir la unidad. Si no hay clave por buff, ¿qué se muestra? | 0.8; la unidad (segundos/turnos) **está sin definir** (se decidirá en el spike de árbol y habilidades): el formato debe cambiarse en **una sola clave**. |
| P5 | **Navegación.** Los tres botones actuales (Loadout, Inventario, Árbol) en tamaño `LG` con **indicación del atajo**; ¿se añade Party? ¿Salir/guardar? (por defecto, no). | 0.4: de dónde se leen los atajos sin que la View toque `InputMap`. |
| P6 | **Regla de teclas con otro overlay abierto.** (a) Cada tecla solo cierra **su propio** overlay; si hay otro distinto abierto, **se ignora**; (b) cambia de overlay (cierra el actual y abre el pedido); (c) dentro del menú, `I`/tecla del árbol/etc. **abren la subpantalla** correspondiente (el menú es el hub); (d) pila real de overlays. | 0.2, 0.4, 0.6. Recomiendo (a) en el orquestador y (c) dentro del menú si 0.4 lo permite sin tocar más sistemas. |
| P7 | **`open_player_menu()` y `closed`.** Conectar `closed` con el patrón de inventario/party/árbol (arregla el doble `P`). ¿Se aprueba tocar `scene_orchestrator.gd` (solo esa conexión y la regla de P6)? | 0.7. Recomiendo sí. |
| P8 | **Fallback a `tree_exiting` en `_open_subscreen()`.** (a) retirarlo y su comentario (las tres subpantallas tienen `closed`); (b) conservarlo. | Código obsoleto. Recomiendo (a). |
| P9 | **`UIButton` `PRIMARY` deshabilitado ilegible** (hallazgo del 21): (a) arreglarlo en el componente en este spike con una pasada de capturas de todas las pantallas; (b) no tocarlo. | Cambia todas las pantallas. |
| P10 | **Título y retrato.** Título = nombre del personaje (hoy), sin retrato (fuera de alcance) o hueco reservado. | Retratos fuera del hito. |

**Recomendación a confirmar:** P1 (B) si la maqueta lo permite a 1152×648, P2 confirmada, P3 (b), P4 (c) mientras la unidad no esté definida (o (b) si el tiempo es real), P5 tres botones con atajo, sin Party, P6 (a)+(c), P7 sí, P8 (a), P9 (b) salvo que prefieras aprovechar el spike, P10 solo nombre.

## 7. Alcance

### 7.A Estructura y componentes
- Raíz `UIPanel` OVERLAY (marco, fondo opaco) sustituyendo a `Root`/`Panel`/`MarginContainer`/`VBox`; título con el nombre del personaje (se elimina «Player UI»); cierre `UIButton` visible, patrón del resto de pantallas.
- Secciones **Recursos**, **Atributos** y **Buffs** en contenedores propios con cabecera localizada y separador con token (sin `HSeparator` por defecto).
- Barras `UIResourceBar` con `set_values()`; oro como etiqueta/valor.
- Navegación con `UIButton` `LG` (variante `PRIMARY`/`SECONDARY` según P5/P9) y etiqueta de atajo.
- Todos los nodos con `%`; filas dinámicas reconstruidas con `remove_child()` + `queue_free()`.

### 7.B ViewModel
- Entrega claves de localización (atributos, buffs) y valores; nombre del personaje sin doble `tr()`.
- Razón `resources` sin reconstruir nodos: actualización **en sitio** desde la View (una vez por frame).
- Buffs según P4: si son en vivo, el ViewModel (o una señal del sistema de buffs) provoca la actualización; **la View no usa `_process`** para leer sistemas.
- Corregir comentarios obsoletos (intenciones, orquestador).

### 7.C Navegación entre overlays
- `open_player_menu()` conecta `closed` (P7).
- Regla de toggle del orquestador según P6 (cada `open_*` actúa solo sobre su propio overlay; con otro distinto abierto se ignora o cambia, según se decida) **sin tocar** los sub-overlays de `NarrativeScenePanel`.
- Dentro del menú, el comportamiento de `I`/atajos según P6 (c).
- `_open_subscreen()`: se retira el fallback si P8 (a); el contrato no cambia.

### 7.D Localización
- Claves del menú completas en ES y EN (`menus.csv` o CSV propio, según 0.10), títulos de sección, buffs, atajos; sin claves crudas; revisión de duplicados con `Group-Object`.

### 7.E Limpieza
- Retirar `print("[PlayerMenuScreen] Ready")` y trazas innecesarias de esta pantalla (las del orquestador solo si se tocan).
- Anotar en `estado_actual.md` lo que se decida no tratar (selector de personaje, Party en el menú, pila de overlays general).

## 8. Cambio visual y funcional esperado

| Antes | Después |
|---|---|
| `PanelContainer` plano, título «Player UI» | `UIPanel` con marco, nombre del personaje |
| Recursos como texto | `UIResourceBar` (HP/EN) + oro |
| Buffs con id crudo y tiempo estático | Buffs localizados (y en vivo si P4 lo decide) |
| Botones raw sin atajo | `UIButton` `LG` con atajo |
| `I` dentro del menú lo cierra entero | Ignorado o abre Inventario (P6) |
| Doble `P` para cerrar y reabrir | `closed` conectado: a la primera |
| Rutas `$Root/...` de 8 niveles | `%` |

**No cambian:** contratos públicos, reglas del personaje, subpantallas, `NarrativeScenePanel`, el slot único del orquestador (salvo la regla de toggle de P6).

## 9. Fuera de alcance
- Pila general de overlays (P6 d) y rediseño del orquestador.
- Menú de compañeros / selector de personaje; botón de Party en el menú (salvo P5).
- Retratos, iconos definitivos de buffs, animaciones.
- Definir la unidad de la duración de los buffs (spike posterior sobre árbol y habilidades).
- Guardado y salida al menú (pantalla de pausa).
- Cambios en `Characters`, `Resources`, `AttributeResolver` o el sistema de buffs (solo se registran).
- El árbol visual de habilidades y el retiro de `DebugPartyTool` (cierre del hito, Spike 24).

## 10. Reglas a respetar
- MVVM y antipatrones de `athelia_ui_architecture.md`; ViewModel hijo de la View; `closed` nunca se libera a sí mismo.
- Componentes del DS sin acceso a sistemas; setters de `@export` con `is_node_ready()`; subclase de `UIPanel` llama a `super._ready()` y fija `padding` antes.
- Un `PanelContainer` apila todos sus hijos; `ScrollContainer` con `size_flags_vertical = 3` reparte a partes iguales; `Label` con elipsis junto a otro expansivo se colapsa (usar `OVERRUN_NO_TRIMMING` en los valores).
- `UIResourceBar` fija 14 px en su `_ready()`: configurar la altura tras entrar en el árbol (lección del 21).
- `remove_child()` antes de `queue_free()`; `Dictionary.get()` tipado con `as`; `tr()` no existe en funciones estáticas.
- Esc: `_input` + `set_input_as_handled()` (patrón de Loadout/Árbol); con una subpantalla abierta el menú está oculto y no debe consumir Esc.
- Auditar el contrato con `Select-String -CaseSensitive`. Teclas de depuración fuera de F5-F8.
- `.csv` con campos con comas entre comillas; claves únicas; `menus.csv` es `id,es,en` (al revés que el resto).
- Commit o copia de `ui/player_menu/`, `ui/design_system/` y `core/scene_orchestrator.gd` antes de empezar. Un ViewModel nuevo no se instala antes que su View.

## 11. Validación en partida real

A 1680×1050 y 1152×648, ES y EN, con capturas antes/después:
1. **Línea base (0.1-0.6):** capturas y mapa real de las teclas con el Output.
2. **Exploración:** `P` abre; X y Esc cierran; **`P` vuelve a abrir a la primera**; sin traza de overlay colgado.
3. **Estado en vivo:** HP y estamina cambian con el menú abierto (regeneración) sin parpadeos ni reconstrucción; oro correcto tras comprar y volver; atributos cambian al equipar en Inventario y volver.
4. **Buffs:** sin buffs («Sin efectos»), con uno y con varios; nombre localizado; actualización según P4.
5. **Loadout, Inventario y Árbol desde el menú:** abrir, trabajar (asignar, equipar, entrenar), cerrar con X y con Esc; el menú reaparece con datos refrescados y sin duplicar nodos.
6. **Teclas con otro overlay abierto:** `I`, atajo del árbol y de Party con el menú abierto, con una subpantalla abierta y con Party abierta; resultado según P6, sin cerrar el menú por error.
7. **Escena narrativa:** menú abierto desde el panel narrativo; subpantalla desde ahí; cerrar cada capa devuelve a la anterior.
8. **Anidado de tres niveles** (narrativa → menú → Inventario → cierre → cierre → cierre) sin pantallas colgadas ni `_current_overlay` huérfano.
9. **Estados no permitidos:** en combate y en pausa el menú no abre (y no rompe nada).
10. **Localización:** sin claves crudas en ES ni EN; sin doble `tr()` en el nombre; sin «Player UI».
11. **Regresión:** Inventario, Loadout, Árbol, Party y tienda abiertos por sus teclas sin el menú, intactos.
12. **Reabrir** varias veces y tras **reinicio de sesión** (derrota → menú → partida nueva): sin eventos duplicados (`item_equipped` se procesa una vez).
13. **Contrato:** `Select-String -CaseSensitive` de sistemas core en `player_menu_screen.gd` vacío; sin `Color(`, `Button.new`, `Label.new`, `$Root`, `modulate`.
14. Pestaña *Errors* del Depurador sin avisos nuevos.

## 12. Riesgos conocidos
- **Tocar el orquestador:** cualquier cambio en el toggle afecta a Inventario, Party y Árbol; hay que validar los cuatro y el contexto narrativo.
- **Dos contextos de apertura** (orquestador y `NarrativeScenePanel`) con `closed` distinto: un cierre que no libere el slot o no devuelva a la capa anterior.
- **Paquete Fase 0 obsoleto** y teclas sin ver (0.4): la regla de P6 puede no ser implementable solo en el orquestador.
- **Buffs:** la unidad del tiempo está sin definir; datos sin nombre localizable por id.
- **Actualización de barras con alta frecuencia** (regeneración de estamina): coste de repintado y parpadeo.
- **Doble `tr()`** del nombre del personaje.
- **Altura a 1152×648** con barras, atributos, buffs y tres botones `LG`.
- **`PRIMARY` deshabilitado ilegible** si se usa en el menú (P9).
- **Eventos duplicados** si `open()` se llama sin desuscribir (ya se desconecta antes de conectar; comprobarlo tras el refresco de `_on_subscreen_closed`).

## 13. Entregables

**Código (completo):** `player_menu_screen.gd`, `player_menu_viewmodel.gd` (entregados juntos). **Escenas:** `player_menu_screen.tscn` (completa o como árbol de nodos legible con el padre de cada nodo verificado; conserva uid). **Parches:** `scene_orchestrator.gd` (solo `open_player_menu` y la regla de toggle, con aprobación), componentes del DS (aditivos, con aprobación) y `ui_tokens.gd` si falta algún token. **Datos:** `menus.csv` ampliado (ES y EN, orden real de columnas) y registro en Project Settings si es un CSV nuevo.

**Documentación:**
- `docs/spike_22_menu_jugador.md` (informe de cierre: respuestas P1-P10, cambios en View/ViewModel/orquestador, validación, lecciones y pendientes).
- `athelia_ui_architecture.md` (fila de PlayerMenu y regla de navegación entre overlays, editadas en su sitio), `athelia_referencia_sistemas.md` (SceneOrchestrator), `athelia_historial_spikes.md` (un párrafo con enlace), `athelia_estructura_carpetas.md`, README del Design System si cambia algún componente.
- `athelia_lecciones_tecnicas.md`: solo lecciones nuevas.
- `estado_actual.md`: tabla y pendientes (22 cerrado; 23 es el siguiente; marcar resueltos `I` en el menú, `I` con Party y doble `P`).
- Plan del hito: cerrar el 22 y anotar pendientes nuevos.
