# Athelia — Pendientes tras el pivote narrativo

*Recopilación para arrancar nuevos spikes. Estado a fecha de cierre del
Grupo 4 de mejoras post-Spike 3 — "Los Telmori" jugable de principio a fin,
con arte real, guardado real y pantalla de combate de producción.*

---

## 1. Contenido incompleto

- **Grupo 2 (diálogo con NPCs) parcial**: solo `sheriff_briefing` está
  convertido a `DialogueSystem`. Quedan por convertir la recompensa y el
  entrenamiento del sheriff, siguiendo el mismo patrón ya validado
  (sub-overlay de diálogo desde `NarrativeScenePanel`, `resume_after_dialogue()`).
  `telmori_sheriff_pelts` (venta de pieles) **no se puede convertir**:
  necesita una tirada real contra `skill.exploration.tanning`, que
  `DialogueOptionDefinition` no soporta — se queda como escena narrativa
  para siempre, no es una tarea pendiente.

---

## 2. Bugs de motor de combate (encontrados en Grupo 5, sin tratar)

1. **`ResourceSystem.resource_changed` no se reenvía a `EventBus.resource_changed`.**
   `combat_hub_viewmodel.gd` (menú de acciones, compuesto dentro de la
   pantalla de combate de producción) se conecta a la señal de `EventBus`
   — probablemente el HP/EN mostrado ahí no se actualiza en vivo. La arena
   de combate (`CombatArenaViewModel`) ya evita esto conectándose directo a
   `Resources.resource_changed`, así que el impacto real podría estar
   limitado a esa sub-parte. **Arreglo probablemente trivial** (puentear la
   señal o cambiar el punto de conexión).
2. **Typo `combat_scape`/`combat_escape`.** `combat_hud.gd` (el HUD viejo,
   compuesto dentro de la arena) mapea el slot `"escape"` a la acción
   `"combat_escape"`, pero el InputMap real usa `"combat_scape"` — el botón
   de huir por teclado probablemente no responde. **Arreglo trivial** (una
   línea).
3. **Desync `AttributeResolver` / `ResourceState.max_effective`.** El
   máximo de PV/EN derivado del personaje y el máximo genérico de
   `ResourceDefinition` (típicamente 100) no se sincronizan en ningún punto
   visible — nada llama a `Resources.set_max_effective()`. Se ha visto como
   desajustes tipo `50/60` o `50/45` (actual por encima del máximo),
   confirmado y más visible tras Grupo 4. Fernando no recuerda cómo quedó
   montado originalmente. **Necesita investigación** antes de decidir el
   arreglo — no está claro si Character Creation sí sincroniza esto en
   algún flujo y el gap es solo de un camino concreto, o si es un problema
   general.
4. **`GameLoopSystem._transition_to_phase()`: `Invalid transition: ROUND_END → TURN_END`.**
   Reproducido en combate real — las rondas se saltan número y "Round N
   ended" se imprime dos veces seguidas. No se ha confirmado si afecta al
   contador real que usan los refuerzos cronometrados (la validación de
   Grupo 5 sugiere que no, el refuerzo llegó en la ronda esperada) o si es
   puramente cosmético en el log. **Necesita investigación.**
5. **Fuga de memoria en `SceneOrchestrator._handle_combat()`.** Nunca
   guarda ni libera la instancia de `SCENE_COMBAT` — se acumula una copia
   por combate. Ya mitigada en la práctica: `combat_production_scene.gd`
   se autolibera en `combat_ended`. El problema de fondo en
   `SceneOrchestrator` sigue sin arreglar, pero no sangra hoy. **Sin
   urgencia.**
6. **`combat_resolver.gd` (`class_name CombatResolver`) parece código
   muerto.** Duplica lógica de daño con nomenclatura de fases antiguas
   ("FASE A/B/C", pre-Spike). Confirmado sin ningún fichero activo que lo
   referencie. **Limpieza, no bug.**

---

## 3. Pendientes menores de UI/UX (Grupos 4 y 5)

- Ficha de `companion_mira` muestra `??` en vez de sus iniciales —
  `CharacterState.character_name` le llega vacío. Sin investigar.
- Los 8 botones del menú de acciones de combate no muestran nombre —
  según Fernando, nunca lo han mostrado. Sospechas sin confirmar: timing
  de señales `"slots"`/`"opened"` de `CombatHudViewModel`, o `UIButton`
  gestionando el texto por su cuenta.
- La columna de enemigos se desborda por arriba con 6-8 enemigos —
  `CombatArenaPanel` no limita la altura del `GridContainer`.
- El log de combate muestra IDs internos (`telmori_warrior_3`,
  `companion_mira`) en vez de nombres localizados — incumple la regla de
  localización del proyecto.
- `telmori_lair_loot_obsidian.json.json` — doble extensión en el fichero
  real del proyecto. Carga igual (termina en `.json`), pendiente de
  renombrar.
- `CharacterDefinition.duplicate_definition()` no copia `token_color`,
  `type_icon`, `starting_skill_values` ni `loot_table_id` — confirmado sin
  ninguna llamada real a ese método en el proyecto hoy, así que sin efecto
  observable, pero latente si algo empieza a usarlo.

---

## 4. Otros bugs sueltos

- **F9 (quickload) en una sesión ya activa en `EXPLORATION` provoca
  bloqueo total de input.** Causa raíz sin confirmar. Referenciado también
  en el informe de un spike anterior (producción post-character-creation),
  así que no es nuevo de esta ronda.

---

## 5. Limpieza de schema

- `SaveData.player_state["position"]` (x, y) queda vestigial desde el
  pivote a RPG narrativo por eventos/flags — se sigue guardando/
  restaurando sin ningún efecto observable en el juego. Candidato a
  limpieza futura del schema de guardado, sin fecha decidida.

---

## 6. Spike aparcado: marco decorativo de ventanas (Design System)

Surgido al ver el panel narrativo con fondo real por primera vez (Grupo 4).
Fernando quiere un marco decorativo para las ventanas del juego, empezando
por el panel narrativo pero reutilizable en cualquier pantalla.

- **Variante ya elegida** (de tres maquetadas): doble filete (borde oscuro
  exterior + filete bronce + línea interior tenue) con esquineras
  ornamentales — una única imagen pequeña de esquina reutilizada en las 4,
  sin estirarse. Descartadas: solo doble filete (sin esquineras), y marco
  ilustrado completo estilo 9-slice.
- Va en el Design System, como opción activable dentro de `UIPanel` — no
  específico de `NarrativeScenePanel`.
- Para empezarlo hacen falta tocar `ui_panel.gd`, `ui_panel.tscn` y
  `make_stylebox()` de `ui_tokens.gd`.
- Es contenido de diseño visual ya cerrado — la sesión que lo aborde puede
  ir directa a implementación sin necesidad de maquetar de nuevo, salvo
  para el propio recurso de la esquinera (arte, no decisión).

---

## Nota de proceso

Todo lo anterior salió de comprobar código real y jugar partidas
completas, no de teoría — varios de estos bugs (sobre todo los de
motor de combate) llevaban preexistiendo desde antes del pivote narrativo
y solo se hicieron visibles al ejercitar caminos reales por primera vez.
Para cualquiera de estos puntos, sigue aplicando lo que ha funcionado en
todo este pivote: comprobación de código como paso obligado antes de
diseñar, y dividir en spikes/grupos separados cuando el alcance mezcla
piezas de riesgo distinto (aquí, al menos, "arreglo trivial" vs. "necesita
investigación" es una división natural).
