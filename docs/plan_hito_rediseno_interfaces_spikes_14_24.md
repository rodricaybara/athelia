# Plan del hito de rediseño de interfaces — Spikes 14-24

**Fecha:** 2026-10-03 · **Última actualización:** 2026-10-20 (cierre del Spike 15)
**Alcance:** Rehacer y homogeneizar el estilo de 8 pantallas de Athelia (tienda,
inventario, party, Loadout, árbol de habilidades, menú del jugador, pantalla de
inicio y Game Over), más un spike previo de motor (reinicio de sesión) y uno de
cimientos del Design System. Es el resultado de la Fase 0 de comprobación de
código sobre las 8 pantallas, el Design System y el orquestador. **Los Spikes 14 y 15
están cerrados y validados en partida real** (informes en
`docs/spike_14_reinicio_sesion.md` y `docs/spike_15_cimientos_design_system.md`);
el resto está sin implementar.

---

## 1. Resumen: spikes en orden de ejecución

| # | Spike | Riesgo | Depende de |
|---|---|---|---|
| 14 | Reinicio de sesión y teardown (motor) — **cerrado** | Medio | — |
| 15 | Cimientos del Design System — **cerrado** | Medio | — |
| 16 | Tienda (piloto de adopción del DS) | Bajo | 15 |
| 17 | Inventario A: contrato MVVM, sin cambio visual | Alto | 15 |
| 18 | Inventario B: rediseño con `UISlot` | Medio | 17 |
| 19 | Party | Medio-alto | 18 |
| 20 | Loadout | Medio | 18 |
| 21 | Árbol de habilidades | Medio-alto | 15 |
| 22 | Menú del jugador | Medio | 18, 20, 21 |
| 23 | Pantalla de inicio | Bajo | 15 |
| 24 | Game Over: rediseño visual | Bajo | 14, 15, 23 |

- **14 y 15 están cerrados:** perder un combate lleva al menú principal con la
  sesión reiniciada, y el Design System está listo (tokens fusionados, `UIPanel`
  corregido, diálogo con rejilla de opciones). Lo que sigue empieza por el 16.
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

### Spike 16 — Tienda

**Objetivo:** primera adopción real del Design System; riesgo bajo.

**Alcance:** maqueta de 2-3 layouts; `UIPanel` con marco; `UIButton`; tokens;
sustituir `Color(...)` literales; localizar "Gold", "Shop", "Slots"; rediseñar
`ShopItemSlot` como fila del DS. Mantener `show_shop_direct()`, la señal de
cierre por `shop_closed` y los nombres `%`. Layout con anclas y fracciones
(`shop_ui.tscn` tiene 4 offsets fijos grandes); claves `SHOP_*`.

**Validación:** comprar, vender, oro insuficiente, tienda sin hueco, Esc, cierre
devuelve a exploración, herrería de Los Telmori. **Absorbe de la
recopilación (§6, Spike 13):** lanza equipada frente a lanza vendida
(comportamiento del préstamo `quest_loan`).

### Spike 17 — Inventario A: contrato MVVM

**Objetivo:** que la pantalla de inventario de producción cumpla el contrato
MVVM, sin cambio visual. Es el spike de más riesgo del hito.

**Fase 0:** decidir si se revive `InventoryViewModel`/`InventoryScreen` o se
reconstruye. Comprobar si el ViewModel cubre el arrastre para equipar y
desequipar, la comparación, y la diferencia entre `MAX_SLOTS = 20` y el grid
del `.tscn`.

**Alcance:** la View de producción pasa a MVVM; eliminar el código muerto que
no se reutilice; retirar `SceneOrchestrator.close_inventory()`; localizar los
textos sueltos; conservar `open_inventory()`, `closed` y los tres contextos de
apertura.

**Validación:** tres contextos (tecla en exploración con toggle, subpantalla de
PlayerMenu, sub-overlay narrativo); equipar y desequipar por botón y por
arrastre; usar consumible; fallo de uso; cierre correcto de la capa más profunda
en el anidado narrativa → PlayerMenu → Inventory.

### Spike 18 — Inventario B: rediseño

**Alcance:** maqueta de 2-3 layouts; `UISlot` (primer consumidor real, pueden
aparecer huecos: arrastre, `equipment_slot_id`, estados); `UIPanel` con marco;
rediseño de `item_detail_panel` y `feedback_popup`; tamaño del panel con anclas
y fracciones para ventana mínima de 1152×648 (hoy 860×600 fijos; con marco y
padding mínimo de 16 px el margen vertical es escaso). `item_slot` y `equip_slot` antiguos se quedan hasta el
spike 19.

**Validación:** la misma batería del spike 17, más arrastrar y soltar con los
nuevos slots.

### Spike 19 — Party

**Alcance:** adoptar los componentes de ítem del spike 18; retirar `item_slot` y
`equip_slot` antiguos; resolver la duplicación de `ColumnData` /
`EquipSlotData` / `SlotData`; localizar "Sin companions"; maqueta.

**Validación:** transferir ítems jugador ↔ companion en ambos sentidos, equipar
en companion, cambiar estrategia, navegar entre companions, caso sin companions;
dos contextos (overlay y sub-overlay narrativo).

### Spike 20 — Loadout

**Alcance:** migrar `$Root/...` a nombres únicos `%`; botones por código a
`UIButton`/`UISlot`; tokens; maqueta.

**Absorbe de la recopilación:** pista visual del primer clic (§4) y claves
`LOADOUT_TITLE`, `LOADOUT_SLOT_EMPTY`, `LOADOUT_SKILLS_AVAILABLE` (§5), que
siguen sin traducir tras el Spike 15.

**Validación:** asignar skill y consumible, limpiar slot, slot incompatible,
cierre; dos contextos (subpantalla de PlayerMenu y `open_loadout()`).

### Spike 21 — Árbol de habilidades

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

### Spike 22 — Menú del jugador

**Alcance:** es el hub: integra las tres subpantallas ya rediseñadas; maqueta;
`closed` y `_open_subscreen()` ya son correctos y se conservan.

**Validación:** anidado de tres niveles con cierre correcto de cada capa;
Loadout, Inventory y SkillTree desde el menú; HP y energía actualizándose en
vivo.

### Spike 23 — Pantalla de inicio

**Alcance:** arte de fondo y título; `UIButton` `LG` en los botones; marco en
Opciones, Créditos y Confirmar salida; mantener el ciclo de vida de Main Scene
(el ViewModel escucha `game_state_changed`).

**Validación:** Nueva partida, Cargar (con y sin guardado), Opciones (volumen,
pantalla completa, idioma), Créditos, salir con confirmación, volver al menú
desde Character Creation y tras una derrota.

### Spike 24 — Game Over: rediseño visual

**Alcance:** `UIPanel` + tokens + arte del estilo decidido en el spike 23;
textos localizados (ya existen desde el spike 14); foco inicial en el botón.
La lógica ya está movida en el spike 14. El botón único (`ReturnToMenuButton`)
se ensancha porque "Volver al menú principal" es más largo que el texto
anterior: resolverlo en la maqueta. La View ya delega en `GameOverViewModel`.

**Validación:** derrota → pantalla → menú; el flujo funcional del spike 14 no
cambia.

---

## 5. Pendientes de la recopilación que absorbe el hito

| Pendiente (recopilación) | Spike |
|---|---|
| `UIPanel.Variant.OVERLAY` opaco (§3) | 15 — **resuelto** (documentado como opaco) |
| Pantalla de Loadout: pista visual del primer clic (§4) | 20 |
| Claves `LOADOUT_*` sin traducir (§5) | 20 |
| Claves `SKILL_*_NAME` sin traducir (§5) | 15 — **resuelto** (`skills.csv`); revisión de textos en 21 |
| Lanza equipada frente a lanza vendida (§6) | 16 |
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

- Cobertura del `InventoryViewModel` muerto (arrastre, comparación). → 17.
- Resolución del arte 848×1264: ¿retratos? → spike de la pantalla que los use.
- Saludo del sheriff de 3 líneas con las 6 opciones a 648 de alto: previsto un
  recorte de ~4 px, no observado. → revisar en partida.
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
