# Ideas para próximas versiones

Ideas anotadas el 2026-11-08. Implementado: roles, hospital generado al azar, tareas, tamaño del mapa y Nonatos por nivel. Del modo extracción ya está la cuota de botín por nivel. Gastar el botín entre niveles: hecho con la tienda de la pantalla final.

## Mapas que cambian en cada partida
| Opción | Qué cambia | Trabajo |
|---|---|---|
| Colocación aleatoria | Generadores, pilas, aparición del monstruo y luces salen de una lista de sitios candidatos | Bajo |
| Salas intercambiables | El plano se mantiene; cada hueco recibe una sala de un catálogo (quirófano, morgue, farmacia...) | Medio |
| Generación completa | Salas y pasillos nuevos cada vez | Alto |

Generación completa implementada el 2026-11-09 en `scripts/hospital_gen.gd`. Mantiene tres franjas (urgencias y alas, salas del medio, sótano) y sortea anchos de sala, puertas, escalera, muebles y sitios candidatos. Cada plano se valida como en `tools/gen_hospital_map.py`; si falla se genera otro, y tras 40 intentos se usa `maps/hospital.txt`. Tamaño: 48x34 en el nivel 1, 60x39 en los niveles 2 y 3, 74x45 desde el 4.

Antes: colocación aleatoria. El hospital marca 3 sitios por generador, 3 para el monstruo y 14 para pilas.
`scripts/level.gd` se queda con 1 de cada y 8 pilas. El anfitrión elige una semilla nueva en cada partida y la envía al resto, así todos ven el mismo mapa.
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

- Implementado: catálogo de 10 en el hospital (3 generadores, 2 archivadores de 6 s, 2 ordenadores de 8 s, 3 válvulas de 5 s). Cada nivel deja nivel + 1 tareas. Ganar pasa al nivel siguiente y perder lo repite.
- Implementado: mapas más grandes por nivel y Nonatos por nivel (+1 desde el nivel 3 y otro cada 2 niveles, sumados a los de jugadores, tope 4).
- Pendiente: la llave y el ascensor necesitan inventario.
- Necesitaba: tareas como objetos con el mismo sistema de "mantener E" que los generadores, y monstruos que no se estorben entre sí.

## Modo extracción con botín (extraction looter)
- Encaja con el bucle actual. La salida ya es una extracción y las pilas ya son botín.
- Cambios: objetos de valor repartidos por el hospital, inventario con peso o huecos limitados, varias salidas que se abren en momentos distintos.
- Implementado: 4 objetos de valor (muestras 20 a 40 €, instrumental 40 a 70 €, reloj 80 a 120 €, microscopio 120 a 180 €), mochila de 3 huecos, carro de entrega y cuota de 100 € + 100 € por nivel para abrir la salida. El botín de los niveles superados se suma.
- Lo que no se saca se pierde al morir. Lo extraído se gasta entre partidas en mejoras: linternas, más batería, botiquines.
- Implementado el 2026-11-09 en `scripts/shop.gd`: tienda en la pantalla final con el banco común. Pila +25% (120 €, 2 veces), zapatillas +10% velocidad y +20% aguante (150 €, 2), mochila +1 hueco (200 €, 2), botiquín que levanta solo en 6 s (180 €, 1 uso) y dardo tranquilizante que duerme al Nonato 5 s (160 €, hasta 2, clic izquierdo o G). Cada compra repetida cuesta el doble, el triple... El anfitrión valida cada compra. Las mejoras duran la racha y se pierden al volver al nivel 1; no se guardan en disco.
- Riesgo: necesita progreso guardado entre partidas y equilibrar la economía. Es el cambio más grande de esta lista.

## Dificultad por número de jugadores (implementado)
| Jugadores | Nonatos |
|---|---|
| 1 | 1 normal |
| 2 | 1 mejorado |
| 3 | 2 normales |
| 4 | 2 mejorados |

El mejorado corre un 15% más, se aturde 0,3 s en vez de 0,5 s y chilla al recibir luz: apaga 2 s las linternas a 150 px, con recarga de 30 s. Dos Nonatos se reparten las presas: un jugador ya perseguido le parece al otro un 50% más lejos.

## Roles en cooperativo (implementado)
Hecho en `scripts/roles.gd`. El botón "Rol" de la sala de espera cambia de rol.
Valores actuales: enfermero/a reanima x1,5 con 72 de batería; corredor/a corre a 120 y aguanta 5 s, y el Nonato le ve a un 60% de su distancia; técnico/a repara x1,4 y se mueve a 54 y 90; vigía tiene un cono de 65° y gasta x3 al alumbrar al Nonato.

Cada jugador elige un rol en la sala de espera. Una ventaja y una desventaja por rol para que ninguno sea siempre el mejor.

| Rol | Ventaja | Desventaja |
|---|---|---|
| Enfermero/a | Reanima un 50% más rápido | Linterna con un 20% menos de batería |
| Corredor/a | Corre un 20% más rápido y con más resistencia | Hace más ruido: el monstruo le prefiere |
| Técnico/a | Hace las tareas un 40% más rápido | Anda un 10% más lento |
| Vigía | Cono de linterna un 30% más ancho | Su linterna se gasta más rápido al apuntar al monstruo |

Los porcentajes son de partida y se ajustan jugando.

## Segundo escenario desde el nivel 4 (anotado el 2026-11-09)
Niveles 1 a 3 en el hospital. Desde el nivel 4, otro mapa con su ambientación y monstruos nuevos.
Ideas de partida, sin decidir:

| Escenario | Plano | Monstruo nuevo |
|---|---|---|
| Psiquiátrico | Celdas en pasillos largos, patio y sala de terapia | Acechador: solo se mueve cuando nadie le mira |
| Orfanato | Dormitorios, capilla, sótano con túneles | Niña de la cuna: imita la voz de un compañero para atraer |
| Morgue municipal | Cámaras frigoríficas, incinerador, túneles | Cadáver que se levanta al pisar cerca de una camilla |

Cambios necesarios: generador de planos con catálogo de salas por escenario (hoy `scripts/hospital_gen.gd`), hoja de casillas por escenario, sonidos y una escena de monstruo por tipo con su propia IA.
