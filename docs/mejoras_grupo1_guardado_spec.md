# Mejoras del pivote narrativo — Grupo 1: Guardado de partida

*Athelia — tras el cierre de Spike 3 y de los Grupos 2, 3 y 5*

---

## Contexto

El feedback post-Spike 3 señaló que jugar la partida entera de cabo a rabo
para probar un tramo avanzado (ej. confirmar que se entrega la recompensa
de 100 monedas) es un problema real. Al plantear los 5 grupos originales se
identificó que esto mezcla dos soluciones de coste muy distinto bajo el
mismo nombre:

- **Guardado real**: que la partida guardada recuerde el progreso
  narrativo, no solo personaje/recursos/skills/inventario/equipo.
- **Atajo de desarrollo**: poder saltar a un punto concreto sin jugar todo
  el camino, solo para probar — mucho más barato, resuelve el dolor
  inmediato sin tocar el sistema de guardado real.

Este grupo aborda las dos, por separado, porque comparten sistema pero no
comparten coste ni usuario final (una es para el jugador, la otra es
herramienta de desarrollo).

## Objetivo de este grupo

Que la partida guardada recuerde el progreso narrativo real y se pueda
reanudar exactamente donde se dejó, y tener un atajo de desarrollo barato
para probar tramos avanzados sin jugar la aventura entera.

---

## Alcance

### Incluye

1. **Comprobación de código, paso 1 obligado:** qué guarda hoy
   `SaveManager` exactamente — confirmar si incluye flags de
   `NarrativeSystem`, la posición actual del jugador (en qué escena
   narrativa y en qué nodo, si está dentro de una), o solo
   personaje/recursos/skills/inventario/equipo como sugiere la
   documentación existente.
2. **Comprobación de código, paso 2 obligado:** dónde viven hoy las teclas
   de quicksave/quickload (F5/F9) y si están condicionadas a
   `GameState == EXPLORATION` de la misma forma que lo estaban las teclas
   de inventory/party/player_menu antes de Grupo 3.
3. **Extender el schema de guardado** para incluir el progreso narrativo
   necesario para reanudar exactamente: flags de `NarrativeSystem`, y si el
   jugador está dentro de una escena narrativa, su identificador y el nodo
   actual dentro de ella.
4. **Decidir y aplicar las condiciones bajo las que se permite guardar**:
   ¿solo en `EXPLORATION` como hoy, o también en `NARRATIVE_SCENE` mientras
   no haya una racha de tiradas acumulativas en curso ni ningún sub-overlay
   (Inventory/Party/PlayerMenu/Diálogo) abierto? Guardar durante
   `COMBAT_ACTIVE` o `DIALOGUE` queda descartado explícitamente, no se
   diseña.
5. **Si se permite guardar desde `NARRATIVE_SCENE`**, extender el punto de
   entrada de F5/F9 al panel narrativo, con el mismo cuidado que Grupos 2 y
   3 aplicaron a sus propios puntos de entrada (guard de estado explícito,
   sin duplicar lógica entre `ExplorationController` y
   `NarrativeScenePanel`).
6. **Atajo de desarrollo**, sistema aparte del guardado real: un mecanismo
   barato para saltar a un flag narrativo concreto o fijar el valor de una
   skill, pensado solo para pruebas durante el desarrollo — decidir su
   forma (tecla de debug, comando, fichero de arranque) durante el grupo.

### No incluye (fuera de alcance de este grupo)

- Guardar durante combate o diálogo — descartado explícitamente.
- Múltiples slots de guardado — sigue siendo un único slot de quicksave;
  si en algún momento hace falta más de uno, es una extensión futura, no
  parte de este grupo.
- Cualquier contenido nuevo de "Los Telmori" — este grupo es de sistema.

---

## Diseño propuesto (a validar/discutir durante el grupo, no cerrado)

- Volcar el estado de flags de `NarrativeSystem` tal cual al schema de
  guardado (previsiblemente ya es una estructura serializable, a confirmar
  en la comprobación 1).
- Guardar el par "escena narrativa actual + nodo actual" solo cuando el
  jugador está dentro de una — al cargar, reabrir el panel narrativo
  directamente en ese nodo en vez de reconstruir el flujo desde el
  principio.
- **Prohibir explícitamente guardar con una racha de tiradas en curso o
  con cualquier sub-overlay abierto** — recomendación de empezar con las
  reglas más restrictivas posibles (nada de racha, nada de sub-overlay
  abierto) y relajarlas después solo si hace falta de verdad. Si el
  jugador lo intenta en un momento no permitido, debe verlo como un
  mensaje claro, no como un fallo silencioso.
- **Atajo de desarrollo**: diseñarlo desde el principio para que sea obvio
  que hay que retirarlo o que vive detrás de una comprobación de build de
  desarrollo (`OS.is_debug_build()` o similar) — mismo tipo de disciplina
  que habría evitado que la tecla F1 de Spike 1 se quedara viva hasta que
  Grupo A tuvo que retirarla explícitamente.

---

## Criterios de validación

- Guardar y cargar durante `EXPLORATION` sigue funcionando exactamente
  igual que hoy, sin regresión.
- Guardar durante `NARRATIVE_SCENE` (en un punto sin racha en curso ni
  sub-overlay abierto) y volver a cargar reproduce exactamente el mismo
  nodo narrativo, con los mismos flags aplicados.
- Intentar guardar con una racha en curso o un sub-overlay abierto se
  bloquea con un mensaje claro para el jugador, no en silencio.
- El atajo de desarrollo permite saltar a un flag/tramo concreto sin jugar
  la aventura completa, y queda claramente marcado como herramienta de
  desarrollo, no como funcionalidad de producción.
- Cero warnings, tipado estricto.

---

## Riesgos y decisiones abiertas

- El alcance real depende de qué guarda hoy `SaveManager` — puede ser tan
  simple como añadir un campo al schema existente, o exigir un rediseño
  más profundo, según lo que confirme la comprobación 1.
- Guardar "a mitad de una escena narrativa" es un concepto nuevo en el
  proyecto — cuantas más condiciones se permitan, más casos límite hay que
  cubrir. Empezar restrictivo.
- El atajo de desarrollo corre el riesgo de quedar olvidado en producción
  si no se diseña con cuidado desde el principio — ya ha pasado una vez en
  este proyecto con la tecla F1 de Spike 1.

---

## Prompt inicial para arrancar el grupo

```
Vamos a arrancar el Grupo 1 (Guardado de partida) de las mejoras post-Spike
3 en Athelia. Te adjunto el documento de especificaciones de este grupo.

Antes de proponer ningún diseño, resuelve las dos comprobaciones de código
que marca el documento como paso obligado:

1. Qué guarda hoy SaveManager exactamente — ¿incluye flags de
   NarrativeSystem o posición narrativa actual, o solo
   personaje/recursos/skills/inventario/equipo?
2. Dónde viven hoy las teclas de quicksave/quickload (F5/F9) y si están
   condicionadas a GameState == EXPLORATION.

Repórtame lo que encuentres antes de proponer nada más. Después, resuelve
explícitamente si se permite guardar desde NARRATIVE_SCENE y bajo qué
condiciones (recomendación de partida: nunca con una racha en curso ni un
sub-overlay abierto), y diseña el atajo de desarrollo por separado,
marcado desde el principio como herramienta de desarrollo y no como
funcionalidad de producción.

No implementes nada todavía — espera mi validación del diseño de cada
pieza antes de tocar código.
```
