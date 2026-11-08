# Ideas para próximas versiones

Ideas anotadas el 2026-11-08. Ninguna está implementada.

## Mapas que cambian en cada partida
| Opción | Qué cambia | Trabajo |
|---|---|---|
| Colocación aleatoria | Generadores, pilas, aparición del monstruo y luces salen de una lista de sitios candidatos | Bajo |
| Salas intercambiables | El plano se mantiene; cada hueco recibe una sala de un catálogo (quirófano, morgue, farmacia...) | Medio |
| Generación completa | Salas y pasillos nuevos cada vez | Alto |

El anfitrión elige una semilla y la envía al resto, así todos generan el mismo mapa.
`tools/gen_hospital_map.py` ya comprueba pasos y alcance del monstruo; serviría para validar cada mapa generado.

## Tareas por mapa y niveles
- Cada mapa tiene un catálogo de tareas, por ejemplo 10: reparar generadores, encontrar una llave, recoger historiales, activar un ascensor.
- Cada partida elige unas pocas al azar del catálogo.
- La dificultad sube por nivel:

| Nivel | Tareas | Tamaño del mapa | Monstruos |
|---|---|---|---|
| 1 | 2 | Pequeño | 1 |
| 2 | 3 | Mediano | 1 |
| 3 | 4 | Mediano | 2 |
| 4 en adelante | +1 por nivel | Grande | +1 cada 2 niveles |

- Necesita: tareas como objetos con el mismo sistema de "mantener E" que los generadores, y monstruos que no se estorben entre sí.

## Modo extracción con botín (extraction looter)
- Encaja con el bucle actual. La salida ya es una extracción y las pilas ya son botín.
- Cambios: objetos de valor repartidos por el hospital, inventario con peso o huecos limitados, varias salidas que se abren en momentos distintos.
- Lo que no se saca se pierde al morir. Lo extraído se gasta entre partidas en mejoras: linternas, más batería, botiquines.
- Riesgo: necesita progreso guardado entre partidas y equilibrar la economía. Es el cambio más grande de esta lista.

## Roles en cooperativo
Cada jugador elige un rol en la sala de espera. Una ventaja y una desventaja por rol para que ninguno sea siempre el mejor.

| Rol | Ventaja | Desventaja |
|---|---|---|
| Enfermero/a | Reanima un 50% más rápido | Linterna con un 20% menos de batería |
| Corredor/a | Corre un 20% más rápido y con más resistencia | Hace más ruido: el monstruo le prefiere |
| Técnico/a | Repara generadores un 40% más rápido | Anda un 10% más lento |
| Vigía | Cono de linterna un 30% más ancho | Su linterna se gasta más rápido al apuntar al monstruo |

Los porcentajes son de partida y se ajustan jugando.
