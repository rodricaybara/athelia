# Spike 21 — Árbol de habilidades (informe de cierre)

*Cerrado: 2026-11-03. Entregado en dos partes (21a y 21b), ambas validadas en partida por Fernando.*

## Objetivo

Rediseñar `SkillTreeScreen` / `SkillTreeViewModel` sobre el Design System (UIPanel OVERLAY con marco, `UIButton`, tarjeta propia `SkillCard`, solo tokens, nodos `%`, claves `SKILL_TREE_*` localizadas), corregir los fallos de uso y completar la localización, **sin cambiar las reglas de progresión y sin tocar el core** (Skills, SkillProgression, datos de habilidades, combate).

## Decisión de diseño

Maqueta de 3 layouts + simulación con 20 habilidades. Elegido **B (lista por niveles con detalle a la derecha) + pie fijo de C** (motivo de «no entrenable» y botón Entrenar siempre visibles). El árbol visual con relaciones queda fuera de este spike (ver «Siguiente»).

## Entregado

### 21a — Pantalla
- `ui/skill_tree/skill_tree_screen.tscn` / `.gd` reescritos: `Backdrop` + `Frame` (`UIPanel` OVERLAY, variante 2, marco decorativo, tope 1400×820 como Inventario/Loadout), cabecera con selector de entidad (‹ nombre ›), botón Comparar/Individual y cierre; pestañas de subcategoría; filtros; rejilla de `SkillCard` por niveles (`HFlowContainer`); detalle con barra, descripción, costes (se omiten los ≤ 0), efectos, requisitos (✓/✗) y pie fijo.
- `ui/skill_tree/skill_card.gd` (**nuevo**, `class_name SkillCard`): nombre, porcentaje y barra fina (`UIResourceBar` custom, 6 px). Estados por stylebox con tokens (normal, mejorable = borde `COLOR_SUCCESS`, bloqueada, seleccionada, hover). Señal `pressed(card)` al soltar dentro de la ficha.
- `ui/skill_tree/skill_tree_viewmodel.gd` reescrito: datos listos para pintar (`SkillData`, `TierGroup`, `CostData`, `EffectData`, `PrereqData`, `TrainResult`…); el ViewModel entrega **claves** y la View traduce con `tr()`.
- `localization/skill_tree.csv` (**nuevo**, 37 claves, `id,en,es`; alta manual `skill_tree.en/es.translation`). Se eliminan 24 líneas `SKILL_TREE_*` de `translations.csv` (6 sin uso). `SKILL_FILTER_*`, `SKILL_SUBCATEGORY_*`, `SKILL_EFFECT_*`, `SKILL_META_*`, `SKILL_TARGET_*`, `SKILL_RANGE_*`, `SKILL_ATTR_ABBR_*` siguen en `translations.csv`.

### 21b — Comparación
- Modo Comparar: rejilla habilidades × entidades (jugador + compañeros) agrupada por subcategoría, con barra fina y % por celda (verde si esa entidad puede entrenarla, «—» si no la tiene). Datos tipados en el ViewModel (`ComparisonRow` / `ComparisonCell`), refresco también ante cambios externos.

### Único cambio fuera de `ui/skill_tree/`
`core/scene_orchestrator.gd`, `open_skill_tree()`: conectar `closed` (antes, la pantalla cerrada seguía ocupando `_current_overlay` y hacían falta **dos pulsaciones de H**):
```gdscript
if _current_overlay and _current_overlay.has_signal("closed"):
	_current_overlay.closed.connect(_on_overlay_closed.bind(_current_overlay))
```
Mismo patrón que `open_inventory()` / `open_party()` (Spike 17). No se tocó ningún sistema del core.

## Fase 0: lo que el código decía frente a la documentación
- `open_skill_tree()` está vivo (tecla H) y **no** conectaba `closed` (causa de la doble pulsación).
- El contexto `PlayerMenu` usa `_open_subscreen()` (ya correcto, `closed` conectada).
- `SkillTreeViewModel` guardaba `_ai_suggestions`, `training_cost`, `get_filtered_skills()` y accedía a `get_node_or_null("/root/…")`: todo retirado (sin consumidores reales; `SKILL_TREE_ERROR_SYSTEM` también, porque `SkillProgression` es autoload).
- Hipótesis descartadas al reproducir: «esquiva invisible» y «`challenge_too_low` bloquea el entrenamiento».

## Reglas de la pantalla (para quien la toque)
- **«Mejorable»** tiene una sola definición, en el ViewModel: `is_unlocked and has_progression and prereqs_met`. La View no la recalcula.
- **Motivo de no entrenable** (prioridad): (1) requisitos pendientes → `SKILL_TREE_REASON_PREREQS`; (2) bloqueada con requisitos cumplidos → `_TEACHER`; (3) desbloqueada sin progresión → `_NO_PROGRESSION`. La pista es la clave + `_HINT`.
- **Entrenar** = `SkillProgression.execute_learning_session(LearningSession.create(entidad, skill, max(valor, 20), "PRACTICE"))`. La pantalla informa del **resultado real** (`improved` → «Mejoró: a % → b %», `roll_failed` → «No mejoró esta vez», o error traducido), no del éxito de la llamada. El flag `_training_in_progress` evita un doble repintado (el core emite `EventBus.skill_improved` dentro de la llamada).
- **Razones de `changed`** (todas con caso en la View): `opened`, `entity_changed`, `tab`, `selection`, `filter_changed`, `mode_changed`, `training_done` (`train_result != null` = entrenamiento de esta pantalla; `null` = refresco externo), `error`, `closed`.
- Repintado diferido (`call_deferred`) para pestañas y filtros (el clic nace en un nodo que el repintado destruye); la **selección** actualiza las fichas en sitio (sin repintar → no se pierde el scroll); tras entrenar se repinta conservando el scroll (`await get_tree().process_frame`).

## Bugs corregidos (además de la migración)
1. Doble pulsación de H / Esc no cerraba (orquestador sin `closed`; `ui_cancel` consumido en la pantalla).
2. Compañero mostrado con su id (`companion_mira`) en vez del nombre (`Characters.get_character_definition(id).name_key`).
3. Textos sin localizar (`T1` suelto → «Nivel %d»), claves sin definición, requisitos mostrados por id (ahora por nombre de habilidad).
4. Efectos mal formateados (Esquiva «×0.0» / «×100.0»): texto por tipo (`Daño físico ×1,2`, buff por `SKILL_BUFF_<TIPO>` o genérico, «Duración: %s s»; coma decimal si el idioma empieza por `es`).
5. Entrenar daba feedback de éxito aunque la tirada fallara.
6. En las capturas de la 21a: porcentaje de la ficha colapsado a 0 px (Label con elipsis junto a otro expansivo) → `OVERRUN_NO_TRIMMING`; «Coste: 0 Estamina» en Percepción → se omiten los costes ≤ 0; botón Entrenar deshabilitado ilegible → pasa a `SECONDARY` mientras está deshabilitado.
7. Barra fina de las celdas de comparación: se fijaba antes de que la barra entrara en el árbol y su `_ready()` la devolvía a 14 px → `bar.ready.connect(…, CONNECT_ONE_SHOT)`.

## Validación en partida
Validado por Fernando: apertura con H y cierre con Esc/H a la primera; filtros y pestañas; selección sin perder el scroll; entrenar (mejora y fallo) con feedback y refresco de barra; motivos de «no entrenable»; compañero con nombre; Comparar; localización ES. Capturas a 1152×648 de la 21a corregida: «Todo OK ahora».

## Sin confirmar / sin validar
- **Unidad de `duration` de los buffs:** asumida en segundos («Duración: %s s»). Si son turnos, cambiar solo `SKILL_TREE_EFFECT_DURATION` en `skill_tree.csv`.
- **Evasión 100** se muestra sin unidad (no sé si es % o puntos).
- `SKILL_ATTACK_LIGHT_DESC` («atack», espacios) y `RESOURCE_FOCUS_NAME` (falta): no tengo esas líneas; búsqueda: `Get-ChildItem -Recurse -Include *.csv | Select-String 'SKILL_ATTACK_LIGHT_DESC|RESOURCE_FOCUS_NAME'`.
- Sin validar explícitamente: detalle de Ataque Pesado, refresco ante una mejora externa (p. ej. narrativa) con la pantalla abierta, contexto PlayerMenu → SkillTree, capturas finales a 1680×1050, lista larga (el `player_new` tiene pocas habilidades; `player_base` tiene 15).

## Observado y no tocado
- Subcategoría de la esquiva: `EXPLORATION` en datos (la documentación dice `MELEE`).
- `NONE` y `ENEMY` se tratan al revés de lo que dice la documentación (la pantalla oculta `NONE`).
- El entrenamiento `PRACTICE` es ilimitado y gratuito (decisión de diseño pendiente; no es de esta pantalla).
- `SceneOrchestrator.close_skill_tree()` sin llamadores.
- `UIButton` `PRIMARY` deshabilitado es ilegible: se resolvió en la pantalla; arreglarlo en el componente es decisión de Fernando (cambia todas las pantallas).

## Lecciones nuevas (también en `athelia_lecciones_tecnicas.md`)
`UIResourceBar` fija 14 px en su `_ready()`; Label con elipsis junto a otro expansivo se colapsa; `PRIMARY` deshabilitado ilegible; selección en sitio frente a repintado; informar del resultado real del core; una sola definición de «mejorable».

## Siguiente
**Árbol visual con relaciones** (nodos y líneas de prerrequisitos, selector «Lista/Árbol» en la cabecera, sobre el mismo ViewModel). Acordado como spike posterior. Ojo: el plan del hito ya numera el **22** como «Menú del jugador», así que este trabajo necesita número propio (propuesta: 21c o un 25).
