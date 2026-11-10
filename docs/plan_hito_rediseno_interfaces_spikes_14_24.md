# Plan del hito de rediseño de interfaces — Spikes 14-24

**Fecha:** 2026-10-03 · **Última actualización:** 2026-11-10 (cierre del Spike 23; spec del 24 preparada)
**Alcance:** Rehacer y homogeneizar el estilo de 8 pantallas de Athelia (tienda,
inventario, party, Loadout, árbol de habilidades, menú del jugador, pantalla de
inicio y Game Over), más un spike previo de motor (reinicio de sesión) y uno de
cimientos del Design System. Es el resultado de la Fase 0 de comprobación de
código sobre las 8 pantallas, el Design System y el orquestador. **Los Spikes 14, 15,
16 (A y B), 16c, 17, 18, 19a, 19b, 20, 21, 22 y 23 están cerrados y validados en partida real** (informes en
`docs/spike_14_reinicio_sesion.md`, `docs/spike_15_cimientos_design_system.md`,
`docs/spike_16_tienda.md`, `docs/spike_17_inventario_mvvm.md` y
`docs/spike_18_inventario_rediseno.md`, `docs/spike_19_party.md` y
`docs/spike_19b_party.md`); el resto está sin implementar. **La 16c (devolución del préstamo)
se resolvió dentro del 19b.** El estado vivo del hito está ahora en `estado_actual.md` del
proyecto; este fichero queda como plan de referencia. Los contextos PlayerMenu y
narrativa del inventario, pendientes tras el 17, se validaron en el 18.

---

## 1. Resumen: spikes en orden de ejecución

| # | Spike | Riesgo | Depende de |
|---|---|---|---|
| 14 | Reinicio de sesión y teardown (motor) — **cerrado** | Medio | — |
| 15 | Cimientos del Design System — **cerrado** | Medio | — |
| 16 | Tienda (piloto de adopción del DS) — **cerrado (A y B)**; la 16c se cerró en el 19b | Bajo | 15 |
| 16c | Devolución del préstamo `quest_loan` al sheriff — **cerrado en el 19b** | Bajo-medio | 16 |
| 17 | Inventario A: contrato MVVM, sin cambio visual — **cerrado** (17a; contextos validados en el 18) | Alto | 15 |
| 18 | Inventario B: rediseño con `UISlot` — **cerrado** | Medio | 17 |
| 19 | Party — **19a y 19b cerrados** | Medio-alto | 18 |
| 19b | Party: mochila a mochila, detalle con comparación, estado del compañero, regla de préstamo y 16c — **cerrado** (19b-1 y 19b-2) | Medio | 19a |
| 20 | Loadout — **cerrado** | Medio | 18 |
| 21 | Árbol de habilidades — **cerrado** (21a y 21b) | Medio-alto | 15 |
| 22 | Menú del jugador — **cerrado** | Medio | 18, 20, 21 |
| 23 | Pantalla de inicio — **cerrado** | Bajo | 15 |
| 24 | Game Over: rediseño visual | Bajo | 14, 15, 23 |

- **14 y 15 están cerrados:** perder un combate lleva al menú principal con la
  sesión reiniciada, y el Design System está listo (tokens fusionados, `UIPanel`
  corregido, diálogo con rejilla de opciones). **El 16 también:** la tienda ya usa el
  DS y el préstamo de la lanza funciona (la devolución, 16c, se cerró en el 19b). **El 17
  también (17a):** el inventario cumple el contrato MVVM. **El 18 también:** el inventario
  usa `UIPanel`, `UIButton`, `UISlot` y tokens, con categorías, capacidad/peso,
  comparación y bonos del equipo. **El 19a también:** Party usa el DS y `UISlot`, con
  capacidad real y contrato MVVM; `item_slot` y `equip_slot` están retirados. Lo que sigue
  empieza por el 20 (Loadout).
- **Orden flexible:** entre 16, 19, 20, 21 y 23 se puede reordenar siempre que
  se respeten las dependencias. 23 (pantalla de inicio) no depende de ninguna
  otra pantalla.
- **Equivalencia con los nombres usados durante la planificación:** 14 = "23A",
  15 = "14 Cimientos", 16 = "15 Tienda", 17 = "16", 18 = "17", 19 = "18",
  20 = "19", 21 = "20", 22 = "21", 23 = "22", 24 = "23B".

## 2. Reglas transversales a todos los spikes del hito

- Cada pantalla sigue el patrón ya usado en el panel narrativo y el diálogo:
  **Fase 0 (comprobación de código) → maqueta de 2-3 layouts → implementación →
  validación en partida real → informe de cierre.**
- La View no accede a sistemas core (`Inventory`, `Equipment`, `Characters`,
  `Resources`, `Party`...). Todo pasa por el ViewModel.
- Toda pantalla anidable expone su señal `closed`, y quien la instancia hace
  `queue_free()` al recibirla.
- Nodos referenciados por nombre único (`%`), nunca por rutas `$A/B/C/D...`.
  Nada debe depender del nombre del nodo raíz de una pantalla.
- Marco decorativo de `UIPanel`: opt-in por instancia.
- Sin `Color(...)` literales ni tamaños de fuente sueltos: tokens del vocabulario
  fusionado (Spike 15). **Regla de tokens:** código nuevo usa `BG_* / BORDER_* /
  TEXT_*` para superficies, bordes y texto, y `COLOR_*` para marca, semánticos,
  recursos y slots. Todo texto visible con `tr()` y clave en la localización,
  con formato `PANTALLA_ELEMENTO` (`SHOP_…`, `INVENTORY_…`). No hay claves
  comunes (cerrar, volver…): cada pantalla tiene las suyas.
- **Resolución de referencia (decidida en el Spike 15):** sin estiramiento, valores
  por defecto. Cada pantalla se diseña con **anclas y fracciones**, no con tamaños
  en píxeles fijos, para una ventana mínima de 1152×648 que también funcione a
  pantalla completa (probado a 1680×1050).
- `UIPanel` con marco: la esquinera 64×64 se aplica sola y el padding efectivo no
  baja de 16 px (`FRAME_MIN_PADDING`) salvo que se fije `padding` explícito.
  `UIPanel.Variant.OVERLAY` es **opaco** (no semitransparente).
- Se conservan los contratos públicos de cada pantalla (`open()`,
  `open_inventory()`, `show_shop_direct()`, `closed`...) salvo que el spike
  declare lo contrario.
- Cada spike cierra actualizando `athelia_ui_architecture.md`.

## 3. Hallazgos de la Fase 0

### 3.1 Game Over y reinicio de sesión (el más grave) — resuelto en el Spike 14

_Se conserva como registro del diagnóstico. Todo lo de este apartado quedó
resuelto; ver el informe de cierre del Spike 14._

- **El botón "Nueva partida" no funciona.** Confirmado por consola:
  `Invalid state transition: DEFEAT → CHARACTER_CREATION`.
  `VALID_STATE_TRANSITIONS` solo permite `DEFEAT → [MENU, EXPLORATION]`. El
  código llama a `enter_character_creation()` sin pasar por `MENU`, como sí
  documentaba el Spike 3/B. Antes de fallar, el botón ya había borrado
  narrativa, checkpoints y party.
- **Un parche provisional (pasar por `MENU` y luego a Character Creation) no
  lo resuelve:** deja el Game Over encima de Character Creation y la escena de
  exploración viva detrás (HUD con `HP: 0`). Se descarta; lo sustituye el
  spike 14.
- **`SceneOrchestrator._show_game_over()`** instancia `GameOverUI`, le pone
  nombre y lo cuelga de `root` sin guardar referencia, así que
  `_hide_current_overlay()` nunca lo libera.
- **`_handle_main_menu()` y `_handle_character_creation()`** solo llaman a
  `_hide_current_overlay()`. Nadie libera `ExplorationScene`, y ningún sistema
  de `core` reacciona a `GameState.MENU`. El documento de arquitectura afirma
  que pasar por `MENU` limpia al jugador anterior; en el código no lo hace
  nadie.
- **No existe reinicio de sesión.** Consecuencias confirmadas leyendo el
  código:
  - `CharacterCreationViewModel._create_player_entity()` tiene el guard
    `if chars.has_entity("player")` → "ya registrado — no se recrea", y la
    curación a máximos (`restore_resource`) está dentro del `else`. Con el
    jugador muerto aún registrado, la partida nueva arranca con `HP: 0` y los
    atributos y skills viejos.
  - `AdventureStarter.apply()` no es idempotente a propósito
    (`Inventory.add_item()` suma): el kit inicial se duplicaría.
  - `inventory.register_entity("player")` está fuera del guard: avisa y luego
    suma `STARTING_ITEMS` encima.
- **La carga de partida sobrescribe, no borra.** `SaveSystem._restore_state()`
  solo registra al jugador si falta ("arranque en frío") y aplica
  `load_save_state()` encima.
- **Lo que ya existe y se puede reutilizar:** `unregister_entity()` en
  `Characters`, `Resources`, `Skills`, `Equipment` e `Inventory` (en estos dos
  últimos es un simple `erase`); `Characters.get_registered_entities()`;
  `Narrative.clear_all()`, `Checkpoints.reset()`, `Dialogue.reset()`;
  `PartyManager.leave_party()`. `PartyManager._unregister_from_systems()` ya
  implementa la baja completa de una entidad (la usa con los companions).
- **Estado de sesión sin reset hoy:** `Economy` (stock y presupuesto de cada
  tienda; las `ShopInstance` se cargan de `res://data/shops/*.tres` al
  arrancar y se mutan al comprar/vender).
- **Estado que ya se limpia solo:** `GameLoop` (variables de combate,
  incluida `_pending_victory_scene_id`, en `end_combat()`), `CombatLootSpawner`
  (se reinicia al empezar y al terminar combate) y `Stress` (escucha
  `character_unregistered`).
- **Vestigial, sin reset necesario:** `EnemyWorldLink` (`_cleanup_by_entity`,
  se limpia por entidad) y `WorldObjectSystem` (`_instances`).
- **Por confirmar:** dónde vive `LoadoutState` (probablemente en
  `CharacterState`, y entonces se va con la baja de la entidad).

### 3.2 Resolución y estiramiento

- `project.godot` no tiene sección `[display]` ni claves `viewport_*` /
  `stretch/*`, y ningún script cambia `content_scale` ni el tamaño de ventana
  (el menú principal solo alterna pantalla completa). Se usan los valores por
  defecto: ventana de 1152×648 y estiramiento desactivado. Los layouts con
  fracciones (diálogo, narrativa, mapa interactivo) se adaptan al tamaño real
  de la ventana; los de píxeles fijos no.
- **Pantallas con offsets o tamaños fijos grandes en el `.tscn`:**
  character_creation (6), ui_combat_token (6), inventory_ui (6), party_ui (4),
  shop_ui (4), world_object_interaction_panel (4), game_over_ui (1),
  skill_tree_screen (1), shop_item_slot (1), damage_number (2).
- **Arte:** los fondos son de 1376×768 (10 ficheros). Con una base de 1280×720
  se muestran casi 1:1; a 1600×900 se amplían un 16 % y a 1920×1080 un 40 %.
  También hay 848×1264 (8, probablemente retratos; sin confirmar),
  128×128 (14) y 64×64 (17).
- **Diálogos:** solo `dlg_telmori_sheriff_briefing` llega a 6 opciones. Los
  siguientes tienen 3 (`tavern_keeper`, `sheriff_training`, `dlg_maestro_01`,
  `sheriff_reward`) y el resto 2 o menos. Se desconoce cuántas de esas 6
  aparecen a la vez (pueden depender de flags).
- **Escalado:** con estiramiento `canvas_items`, una base de 1280×720 escala a
  ×1,5 en 1080p, ×2 en 1440p y ×3 en 4K. La base actual da ×1,67 en 1080p
  (no entero).

### 3.3 Design System

- **`UIPanel.Variant.OVERLAY` es opaco:** `COLOR_BG.darkened(0.2)` mantiene alfa
  1,0, aunque la documentación dice "semitransparente".
- **Solo cuatro pantallas usan `UIPanel`** (CharacterCreation, Dialogue,
  Narrative y MainMenu, esta última solo con el script). Inventory, Shop,
  Party y PlayerMenu no, aunque el docstring dice que `DEFAULT` es para
  "inventario, shop, party".
- **`dialogue_panel.tscn` activa `decorative_frame = true` sin
  `corner_texture`** (el grep solo devuelve la línea 52; el panel narrativo sí
  la tiene). El diálogo dibuja solo los filetes, y el `push_warning` está
  dentro de `_draw()`, así que se repite en cada redibujado.
- `corner_texture` no tiene valor por defecto; el marco no compensa el padding
  (esquinera de 64 px frente a padding de 16 / 24); `resized.connect(queue_redraw)`
  solo se conecta en `_ready()`, así que activar el marco en runtime no
  redibuja.
- **Dos vocabularios paralelos de tokens en `UITokens`:** `COLOR_*` (usado por
  `UIPanel`, `UIButton`, `UISlot`, `UIResourceBar`) y `BG_* / TEXT_* /
  BORDER_* / ACCENT_* / RADIUS_*` (usado solo por el árbol de habilidades: 48
  referencias de las 82 que hace a `UITokens`).
  - Duplicados exactos: `COLOR_BG` = `BG_BASE` (`#1A1816`), `COLOR_PANEL` =
    `BG_PANEL` (`#2E2A26`), `COLOR_BORDER` = `BORDER_DEFAULT` (`#3D3830`),
    `COLOR_TEXT` = `TEXT_PRIMARY` (`#E0D8C3`).
  - Conflicto: `COLOR_TEXT_MUTED` `#7A756A` (contraste 3,10:1 sobre
    `COLOR_PANEL`) frente a `TEXT_MUTED` `#9A8E78` (4,42:1).
  - Casi iguales: `COLOR_PANEL_ALT` `#252220` y `BG_SURFACE` `#252118`. Los
    radios no coinciden (3/5/8 frente a 4/6).
- **Ninguna de las 5 pantallas originales usa `UISlot`, `UIResourceBar` ni
  `UITokens`** (0 usos), y tienen literales `Color(`: inventario 16, tienda 5,
  party 1, menú principal 1. `UISlot` no tiene ningún consumidor real y su
  docstring apunta a una ruta antigua (`components/slot/`).
- Hay tres implementaciones de slot: `ui_slot` (DS, sin uso), `item_slot`
  (inventario, con su `_create_stylebox` propio) y `shop_item_slot` (fila de
  lista de la tienda, de naturaleza distinta). `equip_slot` lo usan inventario
  y party.

### 3.4 Pantallas del hito

- **Inventario.** La View de producción es `inventory_ui.gd` (`extends
  CanvasLayer`, nodo raíz `InventoryUi`): sin ViewModel, con unas 22 líneas
  que acceden a `Inventory`, `Equipment`, `Characters`, `Resources`, `Items` y
  `EventBus`, rompiendo el contrato MVVM. `InventoryScreen` +
  `InventoryViewModel` (la versión MVVM) no están referenciados por ningún
  otro fichero. El detalle de ítem está duplicado en `inventory_screen.gd` y
  `item_detail_panel.gd`. Textos sin localizar: `HP/ST/G/STR/DEX/CON`,
  "Item not in inventory", "no encaja en", "usado", "Error:", y "INVENTARIO"
  fijo en el `.tscn`. El grid de slots viene predefinido en el `.tscn`.
  `SceneOrchestrator.close_inventory()` no la llama nadie (solo aparece su
  definición) y compara con `"InventoryUI"` mientras el nodo se llama
  `InventoryUi`. Tres contextos de apertura: overlay vía orquestador (toggle),
  subpantalla de PlayerMenu y sub-overlay de la narrativa.
- **Tienda.** MVVM correcto, sin `closed` (se abre solo con `show_shop_direct()`
  y se cierra por `EventBus.shop_closed`). `ShopItemSlot` es una fila de lista
  con icono `ColorRect`. 5 literales `Color(`. Textos "Gold", "Shop", "Slots"
  sin localizar.
- **Party.** MVVM correcto con `closed`. Reutiliza `item_slot.tscn` y
  `equip_slot.tscn` del inventario. `ColumnData` / `EquipSlotData` /
  `SlotData` duplican las del `InventoryViewModel` sin uso. "Sin companions"
  sin localizar.
- **Menú del jugador.** MVVM correcto, `tr()` en 8 puntos, `closed`. Abre
  Loadout, Inventory y SkillTree como subpantallas propias (`_open_subscreen`).
- **Loadout** (~320 líneas de View). MVVM correcto, 15 `tr()`, `closed`. Slots
  como `Button` estándar creados por código, 4 `Color(`, 0 tokens. Nodos por
  rutas `$Root/Panel/.../` de seis o siete niveles: cualquier reestructuración
  del `.tscn` rompe la View. También se abre desde el orquestador
  (`open_loadout()`, solo en EXPLORATION).
- **Árbol de habilidades** (~810 líneas de View). MVVM correcto, 47 `tr()`, usa
  `UIButton`. Construye tarjetas, cabeceras y comparación por código, y emula
  fondos y bordes a mano (`_apply_panel_styles`, `_add_bg_rect`,
  `_add_border_rect`). También se abre desde el orquestador
  (`open_skill_tree()`).
- **Pantalla de inicio.** La más limpia: MVVM, 21 `tr()`, `UIButton` ya
  adjunto, script de `UIPanel` en los tres sub-paneles (Opciones, Créditos,
  Confirmar salida). Es la Main Scene: su ViewModel escucha
  `game_state_changed` para volver a `"main"`. Faltan arte y marco.
- **Game Over.** Sin ViewModel. La View contiene lógica de juego (`Narrative`,
  `Checkpoints`, `Party`, `GameLoop`). Textos fijos en script y `.tscn`
  ("GAME OVER", "Nueva partida", el mensaje), fuentes 48/20/20 sueltas,
  `Color(0,0,0,0.85)` literal, `Button` estándar. El botón no pide foco.
- **Orquestador.** Un único `_current_overlay`: en `open_party()`,
  `open_player_menu()` y `open_inventory()`, si hay un overlay abierto, la
  tecla de otro overlay lo cierra en vez de abrir el nuevo.

---

## 4. Spikes

### Spike 14 — Reinicio de sesión y teardown (motor) — CERRADO

**Estado:** cerrado y validado en partida real el 2026-10-04. Informe completo en
`docs/spike_14_reinicio_sesion.md`. Lo que sigue es la spec original; cambios
respecto a ella: `Combat.clear_buffs()` entra en `SessionReset` (los buffs de
combate no se limpiaban nunca); el guard tras el `await` acepta `MENU` y
`CHARACTER_CREATION`; el botón se llama `ReturnToMenuButton`; en
`PartyManager` solo se sustituyó el `.has()` por `has_entity()`.

**Objetivo:** que perder un combate tenga salida y que tras llegar al menú
principal la sesión quede realmente cerrada. Sin cambio visual.

**Fase 0:**
- Confirmar dónde vive `LoadoutState`.
- Comprobar si hay tiendas registradas por código con `register_shop()`.
- Confirmar que `EnemyWorldLink` y `WorldObjectSystem` están vacíos en producción
  (se asume que no necesitan reset).
- Comprobar que la baja de `player` no provoca errores en el HUD (solo `Stress`
  y el log de `EventBus` escuchan `character_unregistered`).

**Alcance:**
1. `EntityLifecycle.unregister_everywhere(id)` (estático): Characters,
   Resources, Skills, Equipment, Inventory, en el mismo orden que
   `PartyManager._unregister_from_systems()`. `PartyManager` pasa a usarla (y
   deja de tocar `inventory._inventories`, acceso privado innecesario).
2. `SessionReset.apply()`: `leave_party()` de cada miembro; baja de todas las
   entidades de `Characters.get_registered_entities()`;
   `Narrative.clear_all()`, `Checkpoints.reset()`, `Dialogue.reset()`;
   `Economy.reset_session()`.
3. `Economy.reset_session()`: vuelve a cargar `_load_shop_definitions()`, que
   reemplaza cada `ShopInstance` por una nueva.
4. Orquestador: guardar `_game_over_ui` (como ya se hace con `_combat_hud`).
   `_handle_main_menu()` libera `GameOverUI`, `ExplorationScene` y los restos de
   `CombatScene` / `CombatHud`, y después ejecuta `SessionReset`, esperando un
   frame para que ningún HUD consulte una entidad ya borrada.
5. Game Over: botón único que lleva al menú principal (texto a decidir en la
   maqueta del spike 24; propuesta "Volver al menú principal"). ViewModel
   mínimo: la View deja de tocar `Narrative`, `Checkpoints`, `Party` y
   `GameLoop`. Sin "Cargar partida" ni más botones por ahora.
6. `CharacterCreationViewModel`: usar `skills.has_entity("player")`, que
   `SkillSystem` ya expone (lo usa `SaveSystem`), en vez de
   `skills._entity_skills`.
7. Descartar el parche provisional del Game Over.

**Por qué el diseño es sólido:** tras el reinicio, "Nueva partida" y "Cargar
partida" quedan como un primer arranque, que ya está validado. El guard
`has_entity("player")` ya no salta y la carga usa el "arranque en frío".

**Validación en partida real:**
1. Derrota → botón: menú visible, sin escena de exploración ni HUD detrás, sin
   errores en consola.
2. Nueva partida: vida completa, kit sin duplicar, un solo companion, la
   herrería con su stock original, y la primera visita al pueblo se dispara de
   nuevo.
3. Derrota → menú → Cargar partida: restaura el punto guardado.
4. Primer arranque normal sin regresiones.
5. "Volver al menú" desde Character Creation sigue funcionando.
6. Dos derrotas seguidas: no queda ninguna `ExplorationScene` duplicada en el
   árbol remoto.

**Efecto colateral:** "Cargar partida" tras una derrota en la misma sesión pasa
a ser alcanzable por primera vez.

### Spike 15 — Cimientos del Design System — CERRADO

**Estado:** cerrado y validado en partida real el 2026-10-20. Informe completo en
`docs/spike_15_cimientos_design_system.md`. Lo que sigue es la spec original;
resultado real: **resolución sin estiramiento** (el experimento con
1280×720 `canvas_items` ablandó el texto ≈15 %); tokens fusionados con alias y
dos cambios de valor (`COLOR_TEXT_MUTED` → `#9A8E78`, `COLOR_PANEL_ALT` →
`#252220`); `UIPanel` con esquinera por defecto, padding mínimo y setters; diálogo
con `GridContainer` (1 columna hasta 3 opciones, 2 desde 4), altura de opciones
reservada, margen del texto proporcional al retrato y foco de teclado; `skills.csv`
nuevo y duplicados de `translations.csv` eliminados. La Fase 0 corrigió la spec:
la fila mal formada era `DLG_SHERIFF_REWARD_01_GREET`, no `MENU_CONFIRM_YES`, y
había scroll también con ventanas altas.

**Objetivo:** resolver una sola vez lo que comparten las pantallas, antes de
tocar ninguna.

**Alcance:**
- **A. Resolución.** Experimento en una copia o rama: base 1280×720 con
  `canvas_items` y aspecto mantenido, y revisión de 4-5 pantallas existentes
  (inventario, party, tienda, combate, diálogo). Se decide con lo que se vea.
  Alternativa si el experimento sale mal: mantener los valores por defecto y
  diseñar para 1152×648.
- **B. Tokens.** Fusionar en un solo fichero con alias: los cuatro duplicados
  exactos se apuntan entre sí; `COLOR_TEXT_MUTED` pasa a `#9A8E78` (efecto
  visible: cambia ligeramente el texto en reposo de los botones `GHOST`);
  `COLOR_PANEL_ALT` y `BG_SURFACE` se unifican; los radios se resuelven con una
  tabla de equivalencias. Ningún consumidor se migra a la fuerza.
- **C. `UIPanel`.** Arreglar `OVERLAY` (opacidad o documentación); sacar el
  `push_warning` de `_draw()`; esquinera por defecto; compensación de padding
  cuando hay marco; conectar `resized` al activar el marco en runtime.
- **D. Diálogo.** Asignar `corner_texture` a `dialogue_panel.tscn`; opciones en
  dos columnas a partir de 3-4 opciones (estimación: ~216 px necesarios frente
  a 252 disponibles en ventana de 648; se confirma en la maqueta);
  `ScrollContainer` como red de seguridad.
- **E. `UISlot`.** Corregir la ruta del docstring.
- **F. Contrato de pantalla y documentación.** Fijar las reglas de §2 y
  corregir `athelia_ui_architecture.md`: la View de Inventory, el flujo del Game
  Over, el docstring de `UIPanel` y el nuevo vocabulario de tokens.
- **G. Localización.** Fijar la convención de claves compartidas para las
  pantallas del hito. Las claves del Game Over ya existen (`GAMEOVER_TITLE`,
  `GAMEOVER_MESSAGE`, `GAMEOVER_BUTTON_MENU` en `menus.csv`, columnas
  `id,es,en`). Revisar los `.csv`: la fila `MENU_CONFIRM_YES` de `menus.csv`
  tiene comas sin comillas, y hay que comprobar si el resto de ficheros tiene
  filas con el número de columnas incorrecto.

**Absorbe de la recopilación:** discrepancia de `UIPanel.Variant.OVERLAY` (§3).

**Validación:** las pantallas existentes no cambian de aspecto salvo lo
anunciado; el diálogo muestra esquineras y no escupe warnings; el diálogo del
sheriff cabe sin scroll en ventana de 648; el experimento de resolución queda
documentado con capturas.

### Spike 16 — Tienda — CERRADO (partes A y B; 16c pendiente)

**Informe de cierre:** `docs/spike_16_tienda.md`. Cerrado y validado en partida real
el 2026-10-21.

**Parte A — rediseño con el DS.** `UIPanel` `OVERLAY` con marco, `UIButton`, `UITokens`,
anclas y fracciones (panel al 90 % × 90 %), textos `SHOP_*` y `ShopItemSlot` como fila
(`extends UIPanel`). Dos columnas: inventario del jugador a la izquierda, tienda a la
derecha, oro en la cabecera de cada columna, cierre arriba a la derecha (sin pie). Se
conservan `show_shop_direct()`, `shop_closed` y los nombres `%`. `set_busy(bool)` sustituye
a `has_method("_update_display")`; `%IconRect` es ahora un `TextureRect` oculto (gancho
para iconos); `layer = 10`; el mensaje de éxito distingue compra/venta con el nombre
visible. 23 claves nuevas en `shops.csv` (`id,en,es`).

**Parte B (16b) — préstamo `quest_loan`.** La lanza encantada tenía `base_value = 0` y
daba `INVALID_ITEM`: bloqueaba la aventura. `EconomySystem` trata ahora el tag
`quest_loan`: se toma sin coste, no se vende, la fila muestra "Préstamo"/"Tomar".
`trade_type` gana el valor `"loan"`. Primer cambio del hito que toca el core.

**Lo que la Fase 0 corrigió de la spec:** los botones nunca quedaban deshabilitados
(`_render_snapshot` los reactivaba); snapshot no homogéneo (`shop_can_afford`,
`shop_has_slot`, `total_price` solo en `player_items_sellable`; sin icono); tooltip
equivocado en venta; `ShopUI` sin `layer`; rutas reales `core/economy/`.

**Sin confirmar en partida:** parte B puntos 4-7 (warning de `PriceCalculator`,
lanza equipada no vendible, derrota → partida nueva, compra/venta normales tras el
parche), tooltips `NO_BUDGET`/`NO_SLOTS`, tienda vacía y el camino `LOAN_ITEM`.

### Spike 16c — Devolución del préstamo — CERRADO en el 19b

**Problema (confirmado en partida):** `take_item` del sheriff
(`narrative_scene_viewmodel.gd:365-374`) solo actúa sobre `take_item_target`
(`"player"`). Si la lanza está en el inventario de un compañero (se interpreta, sin
confirmar, que con Mira), imprime "nada que quitar" y la aventura termina sin devolverla.

**Resolución (19b, decisión R8):** hipótesis **confirmada en partida** con la lanza equipada
en Mira. `take_item` de `narrative_scene_viewmodel.gd` delega ahora en
`_take_item_from_party()`: busca en toda la party, desequipa si hace falta y retira el
objeto (`Unequipped … for 'companion_mira'` y `Item taken: enchanted_spear x1 ← companion_mira`;
con la lanza en el jugador, `← player`). Además Party bloquea pasar un `quest_loan` del
jugador a un compañero (el camino inverso se permite).

### Spike 17 — Inventario A: contrato MVVM — CERRADO EN CÓDIGO (17a)

**Informe de cierre:** `docs/spike_17_inventario_mvvm.md` (2026-10-21).

**Decisión estructural:** se reconstruyó `InventoryViewModel` sobre el esqueleto muerto y
`inventory_ui.gd` quedó como única View (la opción de revivir `InventoryScreen` obligaba a
una escena nueva, es decir, cambio visual). Borrados `inventory_screen.gd` (+ `.uid`) y
`SceneOrchestrator.close_inventory()`.

**Resultado:** View pasiva (sin referencias a `Inventory`, `Equipment`, `Characters`,
`Resources`, `Items`, `Party`, `Skills` ni `EventBus`; búsqueda con `-CaseSensitive`
vacía); ViewModel hijo con `changed(reason)` (`opened`, `inventory`, `equipment`, `stats`,
`selection`, `feedback`, `closed`), refrescos agrupados con `_mark_dirty()` y feedback ya
traducido; `closed`, nodos `%`, `localization/inventory.csv` (`id,en,es`, 29 claves
`INVENTORY_*`, alta manual en Project Settings).

**Hallazgos de motor:** (1) `SceneOrchestrator` no escuchaba `closed` y la instancia oculta
seguía ocupando `_current_overlay`: había que pulsar dos veces para reabrir inventario y
Party; arreglado con `_on_overlay_closed(overlay)` conectado en `open_inventory()` y
`open_party()`. (2) Esc no cerraba el inventario (la spec lo daba por hecho): lo maneja la
View. (3) Cabecera y detalle obsoletos tras usar una poción y «HP: HP: 14» duplicado.
(4) Feedback: sin mensaje al desequipar, «usado» al equipar, popup que nunca se ocultaba.

**Cambios visibles acordados:** textos en el idioma activo, nombres de slot localizados y
capitalizados, mensajes al equipar/desequipar, popup que se oculta a los 2 s, Esc cierra.

**Validado en partida:** overlay con `I` (abre/cierra/reabre sin doble pulsación), Esc,
equipar/desequipar por botón, «no encaja en», poción (HUD y cabecera), mochila vacía,
Party y `O`, pestaña *Errors* limpia.

**Sin confirmar en partida (pendiente de validar, no de código):** contexto PlayerMenu
(subpantalla), contexto narrativa (sub-overlay), Esc anidado narrativa → PlayerMenu →
Inventory, mochila con más de 20 ítems y el arrastre «feliz» sobre un slot de equipo.

### Spike 18 — Inventario B: rediseño — CERRADO

**Informe de cierre:** `docs/spike_18_inventario_rediseno.md` (validado por Fernando el
2026-10-22 a 1152×648 y 1680×1050, en los tres contextos de apertura).

**Resultado:** `UIPanel` OVERLAY con marco decorativo, `UIButton`, `UISlot` (primer
consumidor real) y solo `UITokens`; contrato MVVM del 17 y contratos públicos intactos;
`SceneOrchestrator`, `item_slot`, `equip_slot`, `player_menu_*` y `narrative_scene_panel.gd`
sin tocar. `InventoryViewModel` gana `BagEntry`, `CategoryData`, `StatEntry`, `ModLine`,
`CompareLine`, la razón `categories` y `select_category()`; escucha `equip_failed`.

**Decisiones de diseño:** categorías como pestañas definidas en datos
(`data/ui/inventory_categories.json`, primera coincidencia por prioridad); capacidad desde
`inventory_slots` de `CharacterDefinition` (20 por defecto, Mira 15) con un único punto,
`_compute_capacity()`; los ítems que desbordan se muestran con borde discontinuo (antes se
perdían); marca «E» de equipado; comparación de modificadores frente al equipado; bloque de
estadísticas base; **bloque «Bonos del equipo»** (suma de modificadores `add`, añadido con
OK explícito al ver espacio libre a pantalla completa); marco con tope 1400×820 centrado y
fondo opaco; feedback sobre la parte baja de la columna de la mochila. `localization/
inventory.csv`: 58 claves.

**`UISlot`:** `set_item`, `set_definition`, `clear`, estados `set_selected`,
`set_equipped_mark`, `set_overflow`; señales `slot_clicked` (se emite **al soltar**),
`slot_drop_received`; arrastre y drop; placeholder de icono. Limitación: `DISABLED` por
`modulate`.

**Pendientes del propio spike:** estadísticas efectivas frente a base (verificar con
`AttributeResolver`); claves `INVENTORY_BAG_HEADER`/`INVENTORY_STATS_HEADER` sin uso,
`INVENTORY_STAT_FOCUS` oculta; los bonos solo suman `add` (no `mul`/`override`); la pestaña
«Misión» pasa a segunda fila a 1152×648 (aceptado); comentarios «UISlot.setup()» obsoletos
en escenas de combate; redimensionado en caliente no probado (cubierto por inspección).

### Spike 19 — Party — 19a CERRADO (19b pendiente)

**Informe de cierre:** `docs/spike_19_party.md` (validado por Fernando el 2026-10-26 a
1680×1050 y 1152×648; spec en `spike_19_party_spec.md`). El spike se partió: este es el **19a**.

**Resultado:** `UIPanel` OVERLAY con marco (fracción 0,9, tope 1400×820, fondo opaco),
`UIButton`, `UISlot` y solo tokens; layout **L3** (equipo en columna vertical de 6 `UISlot` de
64 px a la izquierda de cada mochila). Contratos públicos y `SceneOrchestrator` intactos; dos
contextos (overlay `O` y sub-overlay narrativo). Referencia de diseño decidida: **1680×1050**,
mínimo 1152×648. `item_slot` y `equip_slot` **retirados** (sin consumidores).

**ViewModel:** `PartyViewModel` con data classes propias (`BagEntry`, `EquipEntry`,
`ColumnData`, `StrategyOption`, `CompanionTab`); la View ya no toca `Inventory`. Razones de
`changed`: `opened`, `player_column`, `companion_column`, `companion_changed`, `party_changed`
(nueva), `feedback` (nueva), `closed`. Refresco agrupado con `_mark_dirty()`. Feedback con el
`FeedbackPopup` del inventario; los motivos de fallo del core (texto libre en inglés) solo van
a consola y el jugador ve un mensaje genérico localizado.

**`request_equip_drop` corregido:** valida el slot antes de mover nada; si el destino ya tiene
copia, equipa la suya sin transferir (Q2); si no, usa el `owner_id` del payload como origen,
desequipa en el origen (Q1), transfiere con rollback y equipa en el destino (revierte y
reequipa en el origen si falla). Un único mensaje al final.

**Nuevo/modificado:** `BagCapacity` (helper estático `ui/inventory/bag_capacity.gd`, punto único
de capacidad, usado por Inventario y Party); `UISlot` gana `owner_id`, `"owner_id"` en el
payload y la señal `slot_item_dropped` (aditivos; `slot_drop_received` se mantiene);
`localization/party.csv` (27 claves `PARTY_*`, `id,en,es`; las 3 `PARTY_ERROR_*` salen de
`translations.csv`). Estrategias localizadas (Agresiva, Defensiva, Ataque en área, Berserker;
id interno `AREA_FOCUS`). Capacidad «huecos usados/capacidad» por columna, sin peso.
Máximo 2 compañeros por decisión de diseño (el core permite 3); con 2 o más, pestañas.

**Confirmado en partida (antes de tocar código):** límite de 8 ítems, ítem transferido pese a
drop rechazado, origen que conservaba el ítem equipado (la lanza quedaba equipada en jugador y
Mira a la vez) y `quest_loan` transferible a Mira (`Transferido: enchanted_spear × 1 player →
companion_mira`). Esto es **coherente con la hipótesis de la 16c, aún no probada hablando con
el sheriff**.

**Sin confirmar (no reportado):** inventario, Party y tienda sin errores tras el borrado de los
slots antiguos (la búsqueda de consumidores salió limpia); idioma inglés de la pantalla;
transferencias con ítem que ambos tienen y origen del arrastre con copia en ambas mochilas
(Output); Mira con mochila llena (15) junto al jugador a 20 huecos a 1152×648; retirada del
script y autoload de depuración `DebugPartyTool`.

**19b CERRADO (2026-11-01)** — informe `docs/spike_19b_party.md`; spec `spike_19b_party_spec.md`.
Partido en 19b-1 (bloques A y D, 16c y limpieza) y 19b-2 (bloques B y C). Decisiones: gesto de
arrastre entre mochilas (1 unidad, Mayús para la pila entera); mochila destino llena bloquea
con mensaje si ocupa pila nueva; el **clic selecciona** y usar/equipar/desequipar van en los
botones del detalle (cambio de comportamiento del 19a, aprobado); comparación contra el equipo
del dueño; HP y estamina con `UIResourceBar.set_values()` y atributos base en tooltip; regla de
préstamo solo por tag `quest_loan` (jugador→compañero bloqueado, el inverso permitido, y
bloqueo también al equipar con clic); cálculo de detalle y comparación extraído a helper
compartido (`ItemDetailBuilder` + `ItemDetailData`); pre-validación en el ViewModel sin tocar
el core. Razón nueva de `changed`: `resources`. Retirado `DebugPartyTool`.

**Hallazgos que corrigieron la spec:** `Inventory.add_item` **pierde datos sin avisar** y
devuelve `true` (sobrescribe un ítem no apilable ya existente; recorta al tope de pila; no
conserva `custom_state`), de modo que el rollback de `_transfer_item` nunca se dispara; Party lo
evita con pre-validación. `PartyManager.MAX_PARTY_SIZE = 3` (no 2). `UIResourceBar` no era
usable tal cual (arreglada de forma aditiva; `bind()` rompe MVVM, las Views usan
`set_values()`). `UISlot` no filtraba por dueño (`drop_exclude_owner`).

**Pendientes del 19b:** `Inventory.add_item` (motor, sin tocar); decidir el máximo de
compañeros (3 en el core frente a 2 de diseño; a 1152×648 con 2 compañeros el margen vertical
es ≈2 px); `InventorySystem.load_save_state()` desconecta/reconecta `item_use_success`; el
cajetín de Party no muestra «Categoría» a pantalla completa; el modificador sale repetido en
detalle y comparación a pantalla completa (igual que el inventario); barra de scroll mínima en
la mochila del jugador con selección a 1152×648. **Sin validar:** Party con 2 compañeros **y**
un ítem seleccionado a 1152×648, y un tercer compañero.

### Spike 20 — Loadout — CERRADO (2026-11-02)

**Alcance:** migrar `$Root/...` a nombres únicos `%`; botones por código a
`UIButton`/`UISlot`; tokens; maqueta.

**Absorbe de la recopilación:** pista visual del primer clic (§4) y claves
`LOADOUT_TITLE`, `LOADOUT_SLOT_EMPTY`, `LOADOUT_SKILLS_AVAILABLE` (§5), que
siguen sin traducir tras el Spike 15.

**Validación:** asignar skill y consumible, limpiar slot, slot incompatible,
cierre; dos contextos (subpantalla de PlayerMenu y `open_loadout()`).

**Cierre:** informe `docs/spike_20_loadout.md`; spec `spike_20_loadout_spec.md`. Pantalla
rehecha con `UIPanel` OVERLAY con marco, `UIButton`/`UISlot`, tokens, nodos `%` y `loadout.csv`
(41 claves). Habilidades como tarjetas (`LoadoutCard`, nuevo), consumibles como `UISlot`; el
estado de selección pasó al ViewModel (razón `selection`). Decisiones: L1 (c), L2 clic+clic
(arrastre más adelante), L3 todos los costes, L4 el segundo clic solo deselecciona y vaciar es
un botón, L5 solo jugador, L6/L7 sin duplicados y lista filtrada por compatibilidad, L8
`open_loadout()` intacto, D1(a) etiquetas de tecla desde `CombatHudViewModel.SLOT_KEYBIND_LABEL`,
D2 el slot sigue seleccionado tras asignar, D4 errores en línea fija, O1 `escape` es un slot
fijo no asignable. Sin cambios en el core.

**Hallazgos de la Fase 0:** `open_loadout()` no tiene llamadores (código muerto, solo
validable por inspección) y Esc no estaba implementado; `defend`/`flee` sin `.tres` (ids
hardcodeados en el controlador de combate); `fireball` no cabe en ningún slot; el combate solo
lee el loadout del jugador.

**Pendientes del 20:** Huida (la tarjeta promete una acción que el HUD no muestra) y
Defensa/Esquiva/Huida sin datos → spike futuro de combate; una skill con requisitos no
cumplidos se puede asignar y sale atenuada en el HUD; sin slot para magia; eliminar
`open_loadout()`; doble `P` tras cerrar el menú del jugador (→ Spike 22); falta
`RESOURCE_FOCUS_NAME`; teclas F y G sin acción en el InputMap; mover `SLOT_KEYBIND_LABEL` a un
sitio compartido (toca combate); loadouts de compañeros; arrastre para asignar; retirar
`DebugPartyTool` (aún en `project.godot`, línea 56) y la traza `[DBG] tecla:` antes de cerrar
el hito; etiqueta de tecla del `UISlot` solapada con el icono (cosmético); textos de
`SKILL_ATTACK_LIGHT_DESC` y de la poción de vida (→ Spike 21 / datos).

### Spike 21 — Árbol de habilidades — CERRADO (2026-11-03)

**Fase 0:** decidir si se parte en dos (~810 líneas, construye la UI por código).

**Alcance:** sustituir `_apply_panel_styles()`, `_add_bg_rect()` y
`_add_border_rect()` por `UIPanel`; alinear con el vocabulario fusionado de
tokens; maqueta.

**Ya resuelto en el Spike 15:** las claves `SKILL_*_NAME` / `_DESC` de las
habilidades (ahora en `localization/skills.csv`, columnas `id,en,es`) y los
alias de tokens (`BG_*`/`TEXT_*` apuntan a `COLOR_*`), por lo que la migración
de tokens es mínima.

**Absorbe del Spike 15:** la pestaña `companion_mira` muestra el id en vez de un
nombre localizado; un `T1` suelto sin localizar; revisar si se muestran al
jugador `SKILL_META_COST_`, `SKILL_NOT_FOUND`, `SKILL_NOT_LEARNED`,
`SKILL_SLOTS`, `SKILL_A`, `SKILL_B`, `SKILL_CATEGORY` (sin definición en los
CSV); revisar los textos nuevos de `skills.csv` (borrador) y
`SKILL_ATTACK_LIGHT_DESC` (espacios y «atack»).

**Validación:** entrenar skill, filtros, modo comparación con companions,
cierre; dos contextos (subpantalla de PlayerMenu y `open_skill_tree()`).

**Cierre:** informe `docs/spike_21_arbol_habilidades.md`; spec `spike_21_arbol_habilidades_spec.md`. Entregado en dos partes. **21a:** `UIPanel` OVERLAY con marco, cabecera con selector de entidad, pestañas, filtros, rejilla de `SkillCard` por niveles (nuevo componente de pantalla), detalle con costes, efectos y requisitos, pie fijo con el motivo de «no entrenable»; `skill_tree.csv` (37 claves). **21b:** modo Comparar (habilidades × entidades). Layout elegido: B (lista por niveles con detalle a la derecha) + pie fijo de C. El ViewModel se reescribió con datos listos para pintar y entrega claves; «mejorable» tiene una sola definición, en el ViewModel. La pantalla informa del **resultado real** del entrenamiento (mejoró / no mejoró).

**Cambio fuera de `ui/skill_tree/`:** `SceneOrchestrator.open_skill_tree()` conecta ahora `closed` (patrón de inventario/party); antes la pantalla cerrada seguía ocupando `_current_overlay` y hacían falta dos pulsaciones de H. Ningún cambio en el core de sistemas.

**Hallazgos de la Fase 0:** `open_skill_tree()` está vivo (tecla H), a diferencia de `open_loadout()`; se retiró la infraestructura sin consumidores (`_ai_suggestions`, `training_cost`, `get_filtered_skills()`, accesos por `get_node_or_null("/root/...")`).

**Pendientes del 21 (sin spike asignado salvo indicación):**
- **Árbol visual con relaciones** (nodos y líneas de prerrequisitos, selector Lista/Árbol sobre el mismo ViewModel): **pendiente para un spike posterior, fuera del hito 14-24** y sin número asignado (decisión de Fernando, 2026-11-03).
- **Unidad de `duration` de los buffs:** se supone que son **turnos**, pero no está definido; se decidirá en el futuro spike sobre el árbol y las habilidades (hoy la pantalla dice «Duración: %s s»; basta cambiar `SKILL_TREE_EFFECT_DURATION`). Pendiente también la unidad de la evasión.
- `SKILL_ATTACK_LIGHT_DESC` («atack», espacios) y `RESOURCE_FOCUS_NAME` siguen sin comprobar/arreglar.
- `UIButton` `PRIMARY` deshabilitado es ilegible (se resolvió solo en esta pantalla): decidir si se arregla en el componente (afecta a todas las pantallas).
- Subcategoría de la esquiva (`EXPLORATION` en datos frente a `MELEE` en la documentación) y tratamiento de `NONE`/`ENEMY` contrario al documentado.
- El entrenamiento `PRACTICE` es ilimitado y gratuito (decisión de diseño).
- `SceneOrchestrator.close_skill_tree()` sin llamadores.
- **Sin validar:** detalle de Ataque Pesado, refresco ante una mejora externa con la pantalla abierta, contexto PlayerMenu → SkillTree, capturas finales a 1680×1050, lista larga (15 habilidades de `player_base`).

### Spike 22 — Menú del jugador — CERRADO (2026-11-10)

**Alcance:** es el hub: integra las tres subpantallas ya rediseñadas; maqueta;
`closed` y `_open_subscreen()` ya son correctos y se conservan.

**Validación:** anidado de tres niveles con cierre correcto de cada capa;
Loadout, Inventory y SkillTree desde el menú; HP y energía actualizándose en
vivo.

**Cierre:** informe `docs/spike_22_menu_jugador.md`; spec `spike_22_menu_jugador_spec.md`. Entregado en tres fases (pantalla, orquestador, buffs). Layout C (cabecera, fila de tres botones `LG` y tres paneles: Recursos, Atributos, Efectos activos); `UIResourceBar` con «actual / máx» como texto aparte; atributos derivados + base (valor efectivo); buffs localizados por clave `PLAYER_MENU_BUFF_<ID>` con id crudo de respaldo y tiempo en vivo (un `Timer` de 0,5 s en el ViewModel); `PlayerMenuRow` (componente de pantalla, solo script); `player_menu.csv` (14 claves). Atajos leídos de `InputMap` por el ViewModel. Fuera de este spike: los seis slots del equipo (spike propio).

**Cambio fuera de `ui/player_menu/`:** `core/scene_orchestrator.gd` (seis parches): `LIGHT_OVERLAY_SCENES` y `_handle_overlay_toggle()` (el propio overlay se cierra, otro ligero se ignora, cualquier otro se cierra como antes; se identifica por `scene_file_path`) en los cuatro `open_*`, y `closed` conectado en `open_player_menu()` (fin del doble `P`). Dentro del menú, `I`/`H` abren la subpantalla y con una subpantalla abierta solo se consume `open_player_menu`. Ningún sistema del core ni los sub-overlays de `NarrativeScenePanel` tocados.

**Hallazgos de la Fase 0:** no hay productor de buffs en producción y `ModifierApplicator` no emite señales de estados temporales; las claves del menú estaban en `translations.csv`, no en `menus.csv`; las teclas se reparten entre `ExplorationController` (`I`, `O`, `P`) y `ExplorationHUD` (`H`, `P`).

**Pendientes del 22 (sin spike asignado salvo indicación):**
- **Los modificadores `attribute.<base>` no afectan a los derivados** (`_resolve_linear_combination` lee el atributo base): el `+2 DES` de las botas no cambia la Iniciativa. El menú muestra el bono declarado por el ítem (opción A); arreglarlo es un cambio de motor con spike propio.
- **Seis slots del equipo en el menú:** spike propio.
- `ModifierApplicator` no emite señales al aplicar o expirar estados temporales y nadie los aplica en producción.
- La unidad de la duración de los buffs de **habilidades** sigue sin definir (los estados temporales del personaje son segundos reales).
- Tab no enlazada a `open_inventory` (comentario obsoleto «I / Tab» en `ExplorationController`; acción `toggle_inventory` sin uso); Loadout sin atajo (exigiría una acción nueva del InputMap).
- Trazas de depuración ajenas: `[DBG] tecla:` en `ExplorationController` y `[DIAG]` en `narrative_scene_panel.gd` (retirar antes de cerrar el hito, junto con `DebugPartyTool`).
- `open_loadout()` del orquestador sin llamadores y con comentario obsoleto.
- **Sin validar:** scroll de buffs con más de seis, captura en inglés a 1680×1050, buffs con modificadores reales sobre atributos, y que `scene_file_path` coincida con las constantes `OVERLAY_*` en todos los casos (validado de forma indirecta).

### Spike 23 — Pantalla de inicio — CERRADO (2026-11-10)

**Alcance:** arte de fondo y título; `UIButton` `LG` en los botones; marco en
Opciones, Créditos y Confirmar salida; mantener el ciclo de vida de Main Scene
(el ViewModel escucha `game_state_changed`).

**Validación:** Nueva partida, Cargar (con y sin guardado), Opciones (volumen,
pantalla completa, idioma), Créditos, salir con confirmación, volver al menú
desde Character Creation y tras una derrota.

**Cierre:** informe `docs/spike_23_pantalla_inicio.md`; spec `spike_23_pantalla_inicio_spec.md`. Layout A (título centrado arriba, columna de botones centrada) con fondo placeholder por tokens (no hay arte propio del menú); jerarquía de botones (Nueva partida `PRIMARY`, resto `SECONDARY`, Salir `GHOST`; Confirmar: Sí `DANGER` / Cancelar `SECONDARY`); Opciones y Créditos como ventana con marco y Confirmar como modal pequeño bajo un velo; idioma y pantalla completa como pares de `UIButton` segmentados; foco inicial y Esc = Volver; «Cargar partida» fijo con la fecha localizada en una línea aparte. Ciclo de vida de Main Scene, flujos de sesión y core sin cambios.

**Componentes nuevos reutilizables:** `TitleBackdrop` (fondo y título; hereda el Spike 24), `OptionsPanel` + `OptionsViewModel` (extraído para un futuro menú de pausa) y `GameSettings` (helper estático que lee, escribe y aplica `user://settings.cfg`: idioma, pantalla completa y volúmenes). Tokens nuevos (aditivos): `FONT_SIZE_DISPLAY`, `COLOR_SCRIM`, `COLOR_MODAL_VEIL`. CSV nuevos: `main_menu.csv` (13 claves) y `options.csv` (8 claves); salen de `menus.csv` las 17 claves `MENU_*` y `CREDITS_BODY`.

**Hallazgos de la Fase 0:** no hay audio ni buses (los sliders no controlaban nada y tenían rango 0-100 con semántica 0-1); Créditos no mostraba el texto; cambiar de idioma sacaba al jugador de Opciones; Confirmar solapaba con el panel principal; el contador `playtime_seconds` de `SaveSystem` no es fiable.

**Pendientes del 23 (sin spike asignado salvo indicación):**
- **Audio:** diseñar el audio, crear los buses `Music` y `SFX`, dar estilo a los sliders y poner `SHOW_VOLUME_SLIDERS = true` (hoy `false`). La persistencia de volúmenes ya está preparada.
- **Menú de pausa / Opciones desde la partida:** reutiliza `OptionsPanel`; exige orquestador y `GameLoop` (spike propio).
- `fullscreen` guardado sin aplicarse en la ventana incrustada del editor (mejora opcional: guardar el valor real tras aplicarlo).
- Tiempo jugado del guardado: el contador de `SaveSystem` incluye el tiempo de menú y no se reinicia (core).
- Limpieza de quickload: `consume_pending_quickload()` y `_quickload()` siguen, aunque F9 está desestimado.
- **`TRANSITIONING` atascado:** si `enter_post_load_state()` o `enter_character_creation()` rechazan la transición, el menú no se recupera (mismo patrón que el 14 arregló en Game Over).
- Versión en el pie (requiere `config/version`); créditos «Por definir»; asignar `background_texture` cuando exista arte y comprobar la legibilidad con el velo.
- **Character Creation** (pantalla gris sin estilo, tamaños fijos): fuera del hito, para el barrido de §8.
- Borrar `localization/menus.csv.bak`.

### Spike 24 — Game Over: rediseño visual

**Alcance:** `UIPanel` + tokens + arte del estilo decidido en el spike 23;
textos localizados (ya existen desde el spike 14); foco inicial en el botón.
La lógica ya está movida en el spike 14. El botón único (`ReturnToMenuButton`)
se ensancha porque "Volver al menú principal" es más largo que el texto
anterior: resolverlo en la maqueta. La View ya delega en `GameOverViewModel`.

**Validación:** derrota → pantalla → menú; el flujo funcional del spike 14 no
cambia.

**Spec y prompt:** `spike_24_game_over_spec.md`, `prompt_spike_24.md` (preparados tras el 23). Además del rediseño, incluye la **limpieza de cierre del hito**: `DebugPartyTool` (aún en `project.godot`), trazas `[DBG]`/`[DIAG]`, `menus.csv.bak`, comentarios obsoletos y, según decida Fernando, la etiqueta de depuración del HUD de exploración y el atasco de `TRANSITIONING` del menú principal; auditoría global de contrato de `ui/` y documentación final. Decisiones abiertas G1-G9. El código actual del Game Over no se ha visto (el paquete es anterior al Spike 14).

---

## 5. Pendientes de la recopilación que absorbe el hito

| Pendiente (recopilación) | Spike |
|---|---|
| `UIPanel.Variant.OVERLAY` opaco (§3) | 15 — **resuelto** (documentado como opaco) |
| Pantalla de Loadout: pista visual del primer clic (§4) | 20 (resuelto) |
| Claves `LOADOUT_*` sin traducir (§5) | 20 (resuelto) |
| Claves `SKILL_*_NAME` sin traducir (§5) | 15 — **resuelto** (`skills.csv`); revisión de textos en 21 |
| Lanza equipada frente a lanza vendida (§6) | 16 — **resuelto en parte**: el préstamo no se vende (16b); vender un objeto equipado queda sin probar; devolución → 16c |
| Hito de rediseño de interfaces (§8) | todo el documento |

## 6. Pendientes nuevos detectados en esta ronda

**Resueltos en el Spike 14:** bug del Game Over ("Nueva partida"), reinicio de
sesión, `GameOverUI` sin referencia y accesos privados de `PartyManager`
(`inventory._inventories`) y `CharacterCreationViewModel`
(`skills._entity_skills`).

**Abiertos del hito:**
- **Documentación:** `athelia_ui_architecture.md` describe una View de
  Inventory que no es la de producción → 15 y 17. (El flujo del Game Over ya
  está corregido por el spike 14.)
- **Marcador:** al cargar la exploración sale `telmori_village/exit_final:
  escena narrativa inexistente: telmori_village_departure`. Es el marcador de
  la salida del pueblo (§7 de la recopilación: decidir qué ocurre al salir);
  ajeno al hito.
- **Limpieza:** duplicado `damage_number.tscn` (`ui\` y `ui\combat\`) y
  etiqueta de depuración visible en el HUD de exploración (`estado | paused=`)
  → barrido final.

**Detectados en el Spike 14, de motor, sin spike asignado (para la
recopilación de pendientes):**
- `CombatSystem._active_buffs` no se limpia al terminar un combate;
  `clear_buffs()` no tenía llamador. `SessionReset` solo cubre las entidades
  registradas, no los buffs de enemigos de un combate anterior con el mismo id.
- `CombatLootSpawner.spawn_pending_loot()` no tiene llamador: el botín de combate
  no se materializa en producción.
- `ItemCharacterIntegration` es código muerto (no es autoload ni se instancia;
  el autoload `Bridge` es `item_character_bridge.gd`).
- `PartyManager._register_in_systems()` conserva un acceso privado
  (`skills_node._entity_skills.get(...).keys()`): hace falta un listador público
  en `SkillSystem`.
- Una entidad registrada solo en `Skills` o `Resources`, pero no en `Characters`,
  no la vería el reinicio (no hay listador público fuera de `Characters`).
  `CombatProductionScene` registra en `Skills` antes que en `Characters`.
- Validaciones del Spike 14 no hechas en partida: un combate lanzado desde una
  escena narrativa, y el rescate o la muerte permanente de un companion (no
  tienen camino jugable en la aventura actual).

**Detectados en el Spike 15 (fuera del hito, sin spike asignado):**
- `main_theme.tres` no está aplicado al proyecto; sin decidir fuentes ni tema.
- `interactive_scene_view.gd:15`: comentario erróneo sobre `main_theme.tres`.
- Pantallas de píxeles fijos (§3.2): se rehacen con anclas en el spike de cada
  una; las de fuera del hito (CharacterCreation, combate) siguen fijas.
- `world_objects.csv`: se eliminó la segunda `WORLD_OBJECT_DEPLETED`; el texto
  visible es ahora «Nothing more to do here».

**Resueltos en el Spike 15:** `dialogue_panel.tscn` sin esquinera y warning en
`_draw()`; fila mal formada de `.csv` (era `DLG_SHERIFF_REWARD_01_GREET`; el
aviso sobre `MENU_CONFIRM_YES` era falso); 29 claves duplicadas de
`translations.csv`; clave `SPEAKER_INNKEEPER`.

**Decisión cerrada:** la carga con F9 en partida queda desestimada de forma
definitiva (recopilación §2); no se vuelve a tratar.

## 7. Comprobaciones abiertas

_(Las de `LoadoutState` y tiendas registradas por código quedaron resueltas en
el Spike 14: `LoadoutState` es un campo de `CharacterState` y no hay llamadas de
producción a `register_shop()`.)_

_(Las del Spike 15 quedaron resueltas: el `sheriff_briefing` con 6 opciones cabe en
2 columnas × 3 filas a 1152×648 y hubo scroll también con ventanas altas;
resolución decidida sin estiramiento.)_

_(La cobertura del `InventoryViewModel` muerto quedó resuelta en el Spike 17: no cubría
la pantalla y se reconstruyó.)_
_(Lo pendiente de validar tras el 17 —contextos PlayerMenu y narrativa, Esc anidado, más
de 20 ítems, arrastre a slot de equipo— quedó validado en el Spike 18.)_
- **Spike 18 (registrado, no corregido):** `equip_item` no recibe el slot de destino (un
  arrastre a un slot concreto equipa donde decida el sistema); motivos de `equip_failed` en
  texto libre (hace falta código de motivo en el core); mecanismo de aumento de capacidad
  (premium, monedas, magia) vía `_compute_capacity()`; `base_damage` frente a
  `melee_damage` (`steel_sword`/`iron_sword`) incoherentes y `amulet_strength` sin tag de
  slot; `narrative_scene_panel.gd` conserva un `print` `[DIAG]` en `_input`.
- **Spike 19 (registrado, no corregido):** una poción se consume aunque no tenga efecto (Mira
  con salud máxima; lógica del puente de ítems); `Inventory.add_item` no valida capacidad y
  sobrescribe la instancia si `can_stack_with` falla; descripciones de estrategia inexistentes
  en datos; comentarios «UISlot.setup()» obsoletos en `combat_arena_test_scene.gd` y
  `combat_production_scene.gd`; `InventoryUI` sin selector de compañero (la mochila de Mira ya
  se ve en Party); el mensaje «Equipado en Jugador: …» usa un nombre genérico del jugador;
  el cursor de prohibido al soltar mochila a mochila no da feedback (resuelto en el 19b).
- **La tecla `I` dentro de PlayerMenu cierra el menú entero** y **`I` con Party abierta la
  cierra** (pila del orquestador de slot único). → 22.
- Cerrar con la tecla (toggle del orquestador) libera la instancia sin pasar por
  `request_close()`: no se imprime `[InventoryUI] Closed`. Inocuo.
- Resolución del arte 848×1264: ¿retratos? → spike de la pantalla que los use.
- Saludo del sheriff de 3 líneas con las 6 opciones a 648 de alto: previsto un
  recorte de ~4 px, no observado. → revisar en partida.
- **Spike 16 (sin confirmar en partida):** parte B puntos 4-7; tooltips
  `NO_BUDGET`/`NO_SLOTS`; tienda vacía; camino `LOAN_ITEM` de `sell_item`.
- **Vender un objeto equipado** (inferido): `equip_item` no saca el objeto del inventario
  y `sell_item` solo comprueba `has_item`; podría quedar un slot de equipo apuntando a un
  objeto vendido. Confirmado en el 17/18: `equip_item` no saca el objeto del inventario (el
  18 ya marca «E» en la mochila); vender un equipado sigue sin resolverse (decisión de
  alcance, registrado).
- **Comprar con inventario lleno:** `buy_item` omite la validación de espacio
  (`InventorySystem` no tiene `can_add_item`).
- **`accepted_tags`** sin aplicar en `ShopInstance.can_buy_from_player` (hay un `TODO`) e
  **`INSUFFICIENT_STOCK`** sin traducir en `ShopViewModel._error_message`.
- Limpieza de la tienda: doble `create_shop_snapshot` al abrir y `print` de depuración
  en `_get_player_items_sellable`.
- **Contraste de botones deshabilitados** (`COLOR_TEXT_DISABLED` sobre bronce oscuro):
  es de `UIButton`/DS, decisión aplazada.
- **Poción de vida:** `ITEM_HEALTH_POTION_DESC` (`items.csv`, línea 5) con espacio inicial
  en ES y efecto inconsistente (EN "10", ES "50", `health_potion.tres` `value = 10.0`).
- **Iconos y descripción en el snapshot de la tienda:** `ItemDefinition.icon` y
  `description_key` existen pero `EconomySystem` no los transporta; la fila ya muestra
  `icon` si llega. → 18.
- Retrato del posadero: es un placeholder (muestra el del sheriff); se diseñará uno propio más adelante. No entra en el Spike 16 (la tienda no usa retratos).
- Idioma inglés de lo tocado en el Spike 15 y comando de columnas de los `.csv`
  tras los cambios: sin confirmar.

## 8. Fuera del hito (barrido opcional tras el spike 24)

CharacterCreation (usa `UIPanel`, 6 offsets fijos, y es el paso entre la
pantalla de inicio y el juego), HUD de exploración, combate (`UICombatToken`
con tamaños fijos), narrativa, `world_object_interaction_panel` (vestigial) y
los duplicados de `damage_number`.

---

## Cómo usar este documento

Cada spike es independiente salvo por las dependencias de la tabla del §1. Antes
de empezar uno, repetir su Fase 0 sobre los ficheros que ese spike toca (el
código puede haber cambiado desde esta fecha) y escribir su spec propia con la
maqueta de 2-3 layouts. El orden recomendado es 16 → 17 → 18 (el 14 y el 15 ya están cerrados), y
después el resto según dependencias. El documento de estructura vigente es
`athelia_estructura_carpetas.md`.
