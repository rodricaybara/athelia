# Spike 5 — Arreglos rápidos de motor — Informe de cierre

**Estado:** Cerrado
**Fecha:** 2026-09-25
**Riesgo real:** Bajo, como se estimó — cinco puntos independientes, sin
dependencias cruzadas, cerrados en una sola sesión.

---

## Resumen

Los cinco puntos de alcance quedan resueltos y validados. Ningún hallazgo
no anticipado por la spec. La aventura completa de "Los Telmori" se jugó
de principio a fin tras los cinco cambios, sin errores ni warnings nuevos.

---

## Punto 1 — Typo `combat_scape` / `combat_escape`

**Arreglo aplicado:** `combat_hud.gd`, `SLOT_INPUT_ACTION["escape"]` pasa de
`"combat_escape"` a `"combat_scape"`, alineado con
`player_combat_controller.gd`, la tabla del InputMap
(`combat_scape` / R / `skill.combat.flee`) y la documentación de
arquitectura — consenso de dos consumidores + docs frente a un único
fichero discrepante.

**Validado:** sí, en partida real.

---

## Punto 2 — Puente `ResourceSystem.resource_changed` → `EventBus.resource_changed`

**Investigación previa (Find in Files vía PowerShell,
`Select-String -Pattern "EventBus\.resource_changed"`):** dos consumidores
reales confirmados, no uno:

- `combat_hub_viewmodel.gd`
- `player_menu_viewmodel.gd`

(`combat_arena_viewmodel.gd` queda fuera — ya se conecta directo a
`Resources.resource_changed`, que es la señal correcta.)

**Mecanismo elegido:** puente, no reconexión directa. Con más de un
consumidor real, reconectar uno solo habría dejado el otro sin arreglar;
el reenvío centralizado en el único punto de emisión de `ResourceSystem`
(`_emit_resource_changed()`) cubre a ambos consumidores actuales y a
cualquier consumidor futuro sin tocar cada ViewModel, respetando la regla
de comunicación por eventos del proyecto.

**Arreglo aplicado:** `resource_system.gd`, `_emit_resource_changed()`
añade `EventBus.resource_changed.emit(...)` con los mismos cuatro
argumentos que la señal propia. `combat_hub_viewmodel.gd` no requirió
cambios — su conexión ya era correcta.

**Hallazgo colateral corregido en la sesión (no en el alcance original):**
comentario desactualizado en `combat_arena_viewmodel.gd:266`
("quien se conecte a `EventBus.resource_changed` nunca la recibe") —
retirado por Fernando tras el arreglo.

**Validado:** sí, en partida real — HP/EN del HUD de acciones y del menú
de jugador se actualizan en vivo.

---

## Punto 3 — Doble extensión `telmori_lair_loot_obsidian.json.json`

**Investigación previa:** cero referencias a la ruta larga en `.gd`/`.json`
del proyecto.

**Arreglo aplicado:** fichero renombrado directamente sobre el proyecto.

**Validado:** sí, dentro de la partida completa de "Los Telmori".

---

## Punto 4 — `CharacterDefinition.duplicate_definition()` incompleto

**Arreglo aplicado:** `character_definition.gd`, `duplicate_definition()`
copia ahora `token_color`, `type_icon` (referencia compartida — no se
duplica la textura), `starting_skill_values` (`.duplicate()`, mismo
patrón que `base_attributes`/`starting_resources`) y `loot_table_id`.

**Validado:** sin camino real que lo ejercite todavía, como anticipaba la
spec — verificación puntual de que los cuatro campos llegan a la copia,
no playtest.

---

## Punto 5 — `combat_resolver.gd` — código muerto

**Investigación previa (repetida justo antes del borrado, Find in Files
vía PowerShell, `Select-String -Pattern "CombatResolver|combat_resolver"`):**
única mención fuera del propio fichero es un comentario en
`combat_encounter_definition.gd:20`, que además documenta que la moral de
grupo se resuelve en `GameLoopSystem`, no en `CombatResolver`. Ninguna
instanciación ni llamada real. Confirmado código muerto por segunda vez.

**Arreglo aplicado:** `combat_resolver.gd` eliminado del proyecto.

**Validado:** sí — proyecto compila sin errores ni warnings nuevos,
aventura completa jugada igual que antes.

---

## Hallazgo no anticipado por la spec (documentado, fuera de alcance)

Durante la validación final se detectó un desync entre el HP/EN mostrados
en `player_menu` y el estado real de `ResourceSystem` (ej. "Vida: 20/75"
mostrado cuando el valor real era 54; mismo patrón en Stamina). Coincide
con el bug "desync PV/EN" ya listado como fuera de alcance de este spike
en el documento original — se deja anotado para Spike 6/7, sin
investigar más a fondo aquí.

---

## Lección reutilizable

Cuando una señal tiene más de un consumidor real confirmado por Find in
Files, el arreglo de un bug de "señal equivocada" es el puente en el
punto de emisión, no la reconexión de un consumidor concreto — reconectar
uno solo dejaría a los demás sin cubrir. Confirmar el número de
consumidores reales antes de elegir el mecanismo, no asumirlo por el caso
que motivó el hallazgo.
