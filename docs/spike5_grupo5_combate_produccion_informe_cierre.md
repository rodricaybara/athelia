# Mejoras del pivote narrativo — Grupo 5: Pantalla de combate de producción — INFORME DE CIERRE

*Athelia — Godot 4.7.2*

---

## Resumen

El grupo más grande de las cinco mejoras post-Spike 3. Sustituye la pantalla de
combate de test (`combat_test_scene.gd`/`combat_hud.tscn`) por una pantalla de
producción real, siguiendo un diseño visual ya cerrado de antemano en
conversación (arena de fichas circulares, party a la izquierda/enemigos a la
derecha, log narrado, menú de acciones fijo). Cero cambios a las reglas de
combate ya validadas en Spikes 2 y 3 — puramente presentación e integración.

**Validado jugando la aventura completa de "Los Telmori" de principio a fin**,
incluidos refuerzos reales a mitad de combate (ronda 4, guarida).

---

## Alcance cerrado

### Fase 5A — Componentes del Design System

- **`UIRadialGauge`** (`ui/design_system/components/ui_radial_gauge/`): anillo de
  progreso radial parametrizable (`progress`, `ring_color`, `track_color`,
  `thickness`). Primer componente del Design System con `_draw()`/arcos — todo
  lo anterior usaba `StyleBoxFlat`. Un único anillo por instancia; una ficha de
  party lo instancia dos veces (PV exterior + EN interior), una de enemigo una
  vez (solo PV). `thickness` final: 4.0 para ambos anillos, ajustado tras
  validación visual (5 resultaba grueso, 3 fino).
- **`UICombatToken`** (`ui/design_system/components/ui_combat_token/`): ficha de
  combate completa (party o enemigo). Compone dos `UIRadialGauge` + relleno
  central (iniciales de party o icono de tipo de enemigo) + triángulo de turno
  + retícula punteada de objetivo. Tres scripts helper internos, sin
  `class_name` a propósito (no son componentes reutilizables fuera de este
  contexto): `ui_combat_token_center_fill.gd`, `ui_combat_token_turn_triangle.gd`,
  `ui_combat_token_target_reticle.gd`.
- **`CharacterDefinition`** gana dos campos: `token_color: Color` (centinela
  `Color.BLACK` = sin asignar, fallback a `UITokens.COLOR_TOKEN_FILL_DEFAULT`)
  y `type_icon: Texture2D` (icono de tipo de enemigo, `null` = sin icono).
  Mismo criterio que retratos/nombres: dato en el `.tres`, no tabla de lookup
  aparte.
- **`ui_tokens.gd`** gana: `COLOR_GAUGE_HP_PARTY`/`COLOR_GAUGE_EN_PARTY`/
  `COLOR_GAUGE_HP_ENEMY` (deliberadamente distintos de `COLOR_HEALTH`/
  `COLOR_STAMINA` ya existentes — en la arena el color comunica bando además
  de recurso), `COLOR_TURN_INDICATOR`, `COLOR_TOKEN_FILL_DEFAULT`,
  `COLOR_LOG_FUMBLE`/`FAILURE`/`CRITICAL` (`SPECIAL` reutiliza
  `COLOR_TURN_INDICATOR`, `SUCCESS` reutiliza el `font_color` normal del tema).

### Fase 5B — MVVM

- **`CombatArenaViewModel`** (`ui/combat/`): nuevo ViewModel de la arena.
  **Compone** a `combat_hub_viewmodel.gd` existente como `action_menu` en vez
  de sustituirlo o fusionarlo — primer caso de composición de ViewModels del
  proyecto (documentado en `athelia_ui_architecture.md`).
- **`CombatTokenData`**/**`LogEntryData`** (`ui/combat/`): data classes ligeras,
  snapshots para la View.
- **Fichas dinámicas, no un roster fijo**: `combat_tokens` crece en respuesta a
  `EventBus.companion_joined` (rescate narrativo a mitad de combate) y
  `EventBus.reinforcement_spawned` (refuerzos cronometrados) — nunca se
  reconstruye entero. Fichas muertas se quedan visibles a 0 PV en vez de
  desaparecer, mismo criterio que companions incapacitados.
- **Menú de acciones real: 8 slots, no 6** — el spec original olvidó los 2
  slots de ítem. 3 ataque configurables/evolutivos + 3 defensivas fijas/
  inherentes + 2 ítems de turno, ya modelado tal cual por
  `ActionSlotData`/`LoadoutState` existente, sin cambio de arquitectura.
- **Log de combate: 4 categorías reales, no una tabla uniforme de grados**:
  - `ATTACK` — graduado por `SkillRoller` (5 claves: FUMBLE/FAILURE/SUCCESS/
    SPECIAL/CRITICAL), vía `combat_action_executed` (siempre trae
    `roll_result`).
  - `DODGE` — sin grado (no hace tirada, solo aplica un buff), vía
    `combat_action_completed`.
  - `DEFEND` — sin grado, vía señales propias de `DefenseModule`
    (`defense_activated`/`defense_expired`), camino de motor totalmente
    distinto al de `combat_action_completed`.
  - `FLEE` — sin grado, vía señales propias de `EscapeModule`
    (`escape_attempted`/`escape_succeeded`/`escape_failed`) — el intento y la
    resolución llegan en **turnos distintos**, no en el mismo evento.
  - `ITEM_USE` — reservado en el enum, sin claves de log: no existe consumo
    de ítem en combate hoy en el motor.
  - 13 claves totales en `localization/combat.csv` (nuevo).

### Punto 8 — Integración real en producción

- **`combat_production_scene.gd`/`.tscn`** (`scenes/combat/`, nuevo): pieza
  mínima sin UI que sustituye a `combat_test_scene.gd` como
  `SceneOrchestrator.SCENE_COMBAT`. Instancia `PlayerCombatController` +
  `EnemyAI`/`CompanionAI` (confirmados ambos `extends Node`, sin dependencia
  de nodo padre — pueden vivir sueltos) para el roster inicial y para
  refuerzos. Se auto-libera en `combat_ended`.
- **`SceneOrchestrator.OVERLAY_COMBAT_HUD`** → `combat_arena_panel.tscn`.
- **`combat_test.tscn`/`combat_hud.tscn` no se retiran** — dejan de ser
  producción, siguen como escena de test independiente con su propia UI de
  barras.
- **`EnemyCombatNode`** (visual 2D, sprite + `AnimationController`) confirmado
  prescindible en producción: ni `EnemyAI` ni `CompanionAI` dependen de él.
  `UICombatToken` cubre su único rol funcional real.

---

## Hallazgos de motor

### Corregidos en este grupo

1. **Payload de dodge sin `actor`** — `combat_system.gd._on_skill_used()`,
   rama de dodge, no incluía `"actor"` en `combat_action_completed`/
   `player_action_completed` (a diferencia de las ramas staggered/disarmed,
   que sí lo llevaban). Parche de una línea, puramente aditivo.
2. **Posición de damage number para fichas `Control`** —
   `_get_entity_damage_number_position()` asumía `Node2D` (conversión de
   transform de mundo a pantalla). Gana rama para `Control`, ya en espacio de
   pantalla, junto a la rama `Node2D` existente (retenida para
   `combat_test.tscn`).
3. **Skills nunca registrado para el roster inicial de enemigos en combate
   real** — `NarrativeSceneViewModel`/`ExplorationController` pre-registran
   `Characters`/`Resources` pero nunca `Skills`. Falso supuesto inicial de
   "ya está todo registrado" al diseñar `combat_production_scene.gd`;
   corregido con guard idempotente, aplicado a roster inicial y refuerzos por
   igual.

### Documentados, sin corregir (fuera de alcance de este grupo)

1. **`ResourceSystem.resource_changed` nunca se reenvía a
   `EventBus.resource_changed`** — nada en el proyecto hace ese puente.
   `combat_hub_viewmodel.gd` se conecta a la señal equivocada; el HP/EN del
   jugador probablemente no se actualiza en vivo en la pantalla de test.
   `CombatArenaViewModel` evita el bug conectándose directamente a
   `Resources.resource_changed`.
2. **Typo `combat_escape`/`combat_scape`** — `combat_hud.gd` mapea el slot
   `"escape"` a la action `"combat_escape"`, pero el InputMap real usa
   `"combat_scape"` (confirmado en `player_combat_controller.gd` y en la
   documentación de arquitectura). El botón de huir por teclado probablemente
   no respondía en la pantalla de test.
3. **Fuga de memoria en `SceneOrchestrator._handle_combat()`** — guarda
   referencia a la instancia de `OVERLAY_COMBAT_HUD` (liberada en
   `_on_combat_ended()`) pero nunca a la de `SCENE_COMBAT`, que no se libera
   jamás — se acumula una copia por combate. Preexistía con
   `combat_test_scene.gd`. `combat_production_scene.gd` se libera a sí misma
   como mitigación local; el problema de fondo en `SceneOrchestrator` sigue
   sin arreglar.
4. **`AttributeResolver`/`ResourceState.max_effective` desconectados** — el
   máximo derivado real del personaje (`AttributeResolver.resolve()`) y el
   máximo genérico de `ResourceState` (`ResourceDefinition.max_base`,
   típicamente 100) son dos números que no se sincronizan en ningún punto
   visible, al menos en el camino de `combat_test_scene.gd`. Origen histórico
   desconocido — Fernando no recuerda cómo quedó montado.
5. **`GameLoopSystem._transition_to_phase()`**: error real
   `Invalid transition: ROUND_END → TURN_END` reproducido en combate real —
   las rondas llegan a saltarse números y "Round N ended" se imprime dos
   veces seguidas. Bug de `GameLoopSystem`, no relacionado con este grupo.
6. **`combat_resolver.gd`** — sospecha fuerte de código muerto: duplica
   lógica de daño con nomenclatura de fases antiguas ("FASE A/B/C",
   pre-Spike), ningún fichero activo revisado lo referencia.

---

## Incidente durante las pruebas (resuelto)

Al validar contra combate real, el script y la estructura de nodos de
`combat_test.tscn` (la escena de producción, no una copia de test) se
sobrescribieron por error con el contenido de una escena de prueba mínima
construida durante la sesión — la escena real de producción quedó rota
temporalmente. Restaurada por completo a partir del historial de git del
proyecto (el `.tscn` llevaba 6 meses sin tocar). **Lección aplicada**: toda
escena de prueba nueva debe usar un nombre de fichero (`.gd` **y** `.tscn`)
que no coincida con ninguno usado por una escena de producción real.

---

## Pendientes reales (fuera de este cierre)

- **Arte real para `type_icon`** en las `CharacterDefinition` de enemigo
  (`enemy_base`, `telmori_warrior_base`, `telmori_wolf_base`, `wolf_gray`) —
  el campo y la tubería ya funcionan, probado con un icono placeholder.
- **Fondo configurable/por encuentro** — hoy `CombatArenaPanel` usa un
  `ColorRect` sólido fijo para tapar la escena de exploración (que sigue viva
  debajo por diseño de `SceneOrchestrator`). Pedido explícito de Fernando,
  no construido en este grupo.
- **Ficha de `companion_mira` muestra `??`** en vez de iniciales —
  `CharacterState.character_name` le llega vacío. Sin investigar.
- Los seis hallazgos de motor documentados-sin-corregir de la sección
  anterior.

---

## Validación

Jugada la aventura completa de "Los Telmori" de principio a fin contra la
integración real (`SceneOrchestrator` → `combat_production_scene.tscn` +
`combat_arena_panel.tscn`), incluida la emboscada inicial (6 enemigos +
companion, sorpresa desfavorable) y el combate final de la guarida con
refuerzos reales disparándose en la ronda 4 exactamente como estaba
diseñado desde Spike 3. Turno, objetivo, HP/EN, log narrado con los 4
colores de grado, menú de 8 acciones y números de daño flotantes, todo
confirmado funcionando en partida real, no solo en arneses de prueba
aislados.
