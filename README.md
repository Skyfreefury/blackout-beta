# Blackout

Juego cooperativo de terror para 1 a 4 jugadores, con vista desde arriba y arte pixel, hecho en Godot 4.7.2.

Los jugadores recorren un hospital abandonado a oscuras para completar tareas y escapar. Cada nivel pide una tarea más (nivel 1: 2 tareas) sacada de un catálogo de 10: generadores, archivadores, ordenadores y válvulas. Además hay que entregar objetos de valor en el carro de la entrada hasta cubrir la cuota del nivel (100 € + 100 € por nivel). La mochila lleva 3 objetos y cada uno frena un 8%. Al caer, la mochila queda en el suelo. Tareas, objetos, pilas y el punto de aparición del monstruo cambian de sitio en cada partida. El Nonato los persigue y huye de las linternas. Con más jugadores sube la dificultad: 1 jugador, 1 Nonato normal; 2, uno mejorado; 3, dos normales; 4, dos mejorados. El mejorado es un 15% más rápido, se aturde menos y chilla al iluminarlo, lo que apaga 2 s las linternas cercanas (una vez cada 30 s).

Estado: beta en desarrollo. El menú tiene un botón "Cómo jugar" con el objetivo y los controles. Si todos los jugadores que quedan están derribados, la partida termina al momento.

## Documentación
- [ERS](docs/ERS.md): requisitos de la versión mínima jugable.
- [Ideas](docs/IDEAS.md): ideas anotadas para próximas versiones.

## Jugar en red
1. El anfitrión pulsa Crear partida. Su IP local se ve con `ipconfig` (IPv4).
2. Los demás escriben esa IP y pulsan Unirse.
3. Fuera de la red local, el anfitrión debe abrir el puerto UDP 7777 en su router.

Roles: en la sala de espera el botón Rol cambia entre enfermero/a, corredor/a, técnico/a y vigía. Cada uno tiene una ventaja y una desventaja.

Controles: WASD mover, ratón apuntar, Q o clic derecho linterna (F también vale), E coger pila u objeto de valor y entregar en el carro, mantener E para hacer tareas o reanimar, Espacio correr (Mayús también vale), Escape pausa, F11 pantalla completa, R siguiente nivel tras ganar o repetir tras perder (anfitrión).

## Pruebas automáticas
```bash
godot --headless --path . res://scenes/main.tscn -- --scenario=repair --nomonster --frames=700
```
Escenarios del hospital: `repair`, `door`, `revive`, `bleed` (con `--nomonster`) `lure`, `loot`, `drop` y `scream`. `--crowd=N` pone los Nonatos de una partida de N jugadores. `--seed=N` fija el reparto del mapa. Los escenarios usan el mapa fijo `maps/hospital.txt`; `--procgen` usa el hospital aleatorio de `scripts/hospital_gen.gd`. `godot --headless --path . --script res://tools/check_hospital_gen.gd -- 200` valida 200 semillas por tamaño. `--level=N` deja N + 1 tareas; sin él quedan las 10. `--role=N` elige el rol (0 enfermero/a, 1 corredor/a, 2 técnico/a, 3 vigía). Escenarios de luz con `--map=res://maps/test.txt`: `lit`, `dark`, `chase`, `lamp`. Todas las opciones en `scripts/debug_run.gd`.

## Ramas
- `main`: versiones estables y probadas.
- `develop`: trabajo en curso. Se fusiona en `main` al cerrar cada fase.
