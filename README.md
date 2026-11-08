# Blackout

Juego cooperativo de terror para 1 a 4 jugadores, con vista desde arriba y arte pixel, hecho en Godot 4.7.2.

Los jugadores recorren un hospital abandonado a oscuras para reactivar 3 generadores y escapar. El Nonato los persigue y solo se mueve cuando ninguna luz lo ilumina.

## Documentación
- [ERS](docs/ERS.md): requisitos de la versión mínima jugable.
- [Ideas](docs/IDEAS.md): ideas anotadas para próximas versiones.

## Jugar en red
1. El anfitrión pulsa Crear partida. Su IP local se ve con `ipconfig` (IPv4).
2. Los demás escriben esa IP y pulsan Unirse.
3. Fuera de la red local, el anfitrión debe abrir el puerto UDP 7777 en su router.

Controles: WASD mover, ratón apuntar, Q o clic derecho linterna (F también vale), E coger pila, mantener E para reparar generadores o reanimar, Espacio correr (Mayús también vale), Escape pausa, F11 pantalla completa, R otra partida (anfitrión, al terminar).

## Pruebas automáticas
```bash
godot --headless --path . res://scenes/main.tscn -- --scenario=repair --nomonster --frames=700
```
Escenarios del hospital: `repair`, `door`, `revive`, `bleed` (con `--nomonster`). Escenarios de luz con `--map=res://maps/test.txt`: `lit`, `dark`, `chase`, `lamp`. Todas las opciones en `scripts/debug_run.gd`.

## Ramas
- `main`: versiones estables y probadas.
- `develop`: trabajo en curso. Se fusiona en `main` al cerrar cada fase.
