# ERS: Blackout

Especificación de Requisitos de Software, versión 0.3, 2026-11-08.

## 1. Introducción

### 1.1 Propósito
Este documento fija qué debe hacer la versión mínima jugable (MVP) del juego. Sirve de referencia para programar, probar y decidir qué queda fuera.

### 1.2 Alcance
Blackout es un juego cooperativo de terror para 1 a 4 jugadores, con vista desde arriba y arte pixel. Los jugadores recorren un hospital abandonado a oscuras para reactivar 3 generadores y escapar. Un monstruo los persigue y solo se mueve cuando ninguna luz lo ilumina.

### 1.3 Definiciones
| Término | Significado |
|---|---|
| Anfitrión | Jugador que crea la partida y actúa de servidor. |
| Cliente | Jugador que se une a la partida por IP. |
| Iluminado | El monstruo está dentro del cono de una linterna con línea de visión, o dentro de una zona de luz fija encendida. |
| Derribado | Estado de un jugador alcanzado por el monstruo. Puede ser reanimado durante 30 s. |
| MVP | Versión mínima jugable, objetivo de este documento. |

### 1.4 Referencias de estilo
Core Keeper y Soul Knight (vista y escala del pixel art), Lethal Company (tensión cooperativa). No se copia arte, nombres ni mecánicas concretas de estos juegos.

## 2. Descripción general

### 2.1 Bucle de partida
1. El anfitrión crea la sala. Los demás se unen con su IP.
2. Todos aparecen en la entrada de urgencias del hospital con la linterna cargada al 100%.
3. El grupo busca y repara 3 generadores. Cada reparación tarda 10 s manteniendo la tecla de interactuar y hace ruido.
4. Cada generador reparado enciende las luces fijas de su zona. El monstruo no entra en esa luz y, si se enciende con él dentro, sale de ella. Solo las linternas lo congelan.
5. Con los 3 generadores activos se abre la puerta de salida.
6. Se gana si al menos 1 jugador cruza la salida. Se pierde si todos mueren.

### 2.2 Usuarios
Grupos de 2 a 4 amigos que juegan desde su casa, hablando por Discord. También se permite jugar en solitario para probar.

### 2.3 Restricciones
- Motor: Godot 4.7.2, lenguaje GDScript.
- Plataforma: Windows 10 y 11 de 64 bits.
- Red: conexión directa por IP o red local con ENet, puerto UDP 7777. El anfitrión puede necesitar abrir ese puerto en su router.
- Arte: generado con Gemini y procesado por script, o dibujado a mano. Sin recursos con copyright de terceros.
- Sonido: bancos con licencia CC0 (freesound.org) o efectos creados con jsfxr.
- Control de versiones: Git con repositorio en GitHub.

### 2.4 Suposiciones
- Los jugadores usan teclado y ratón.
- La comunicación por voz se hace fuera del juego.

## 3. Requisitos funcionales

### 3.1 Menús y conexión
| ID | Requisito | Prioridad |
|---|---|---|
| RF-01 | El menú principal ofrece Crear partida, Unirse, Opciones y Salir. | Alta |
| RF-02 | Crear partida abre el servidor en el puerto 7777 y lleva a la sala de espera. | Alta |
| RF-03 | Unirse pide una IP y un nombre, y conecta en menos de 5 s o muestra un error. | Alta |
| RF-04 | La sala de espera lista a los jugadores conectados (máximo 4). Solo el anfitrión puede empezar. | Alta |
| RF-05 | Si el anfitrión se desconecta, los clientes vuelven al menú con un aviso. | Alta |
| RF-06 | Opciones permite cambiar volumen general, pantalla completa y nombre del jugador. | Media |
| RF-07 | La tecla Escape abre una pausa local con Volver y Abandonar. La partida no se detiene. | Media |

### 3.2 Jugador
| ID | Requisito | Prioridad |
|---|---|---|
| RF-10 | El jugador se mueve con WASD a 60 px/s. | Alta |
| RF-11 | Con Mayús corre a 100 px/s gastando resistencia (4 s llena, recarga en 6 s). | Media |
| RF-12 | La linterna apunta hacia el ratón con un cono de 50° y 120 px de alcance. | Alta |
| RF-13 | La tecla F enciende y apaga la linterna. | Alta |
| RF-14 | La batería dura 90 s encendida. Por debajo del 20% la luz parpadea. | Alta |
| RF-15 | Las pilas del mapa recargan un 50% de batería al recogerlas con E. | Alta |
| RF-16 | Cada jugador tiene su propia cámara centrada en él. | Alta |
| RF-17 | Fuera de cualquier luz el escenario se ve casi negro. Los demás jugadores solo se ven si alguna luz los alcanza. | Alta |

### 3.3 Monstruo
| ID | Requisito | Prioridad |
|---|---|---|
| RF-20 | El monstruo se mueve solo cuando no está iluminado. | Alta |
| RF-21 | Iluminado, queda congelado al instante y emite un sonido de tensión. | Alta |
| RF-22 | A oscuras persigue al jugador más cercano por el mapa de navegación a 110 px/s. | Alta |
| RF-23 | El ruido de reparar un generador atrae al monstruo hacia ese punto. | Media |
| RF-24 | Al tocar a un jugador lo deja derribado y se aleja 3 s antes de volver a cazar. | Alta |
| RF-25 | Solo el anfitrión calcula si el monstruo está iluminado y lo mueve. Los clientes reciben su posición. | Alta |

### 3.4 Objetivos y estados
| ID | Requisito | Prioridad |
|---|---|---|
| RF-30 | El mapa contiene 3 generadores en zonas distintas. | Alta |
| RF-31 | Reparar exige mantener E durante 10 s. Soltar la tecla guarda el progreso. | Alta |
| RF-32 | Un generador reparado enciende las luces fijas de su zona de forma permanente. | Alta |
| RF-33 | Con 3 generadores activos se abre la salida y suena un aviso para todos. | Alta |
| RF-34 | Un jugador derribado puede ser reanimado por otro manteniendo E durante 4 s. | Alta |
| RF-35 | Un derribado no reanimado en 30 s muere y pasa a espectador de otro jugador. | Alta |
| RF-37 | Cada jugador aguanta 2 derribos por partida. El primer golpe lo derriba. El segundo golpe, tras ser reanimado, lo mata al instante. | Alta |
| RF-38 | Un jugador reanimado que ya gastó su primer derribo muestra una marca visible para todos (respiración agitada y cojera). | Media |
| RF-36 | La pantalla final muestra victoria o derrota, tiempo de partida y supervivientes. | Media |

## 4. Requisitos no funcionales
| ID | Requisito |
|---|---|
| RNF-01 | 60 FPS estables en una gráfica integrada (Intel UHD 620 o similar) con 4 jugadores. |
| RNF-02 | Resolución interna de 320x180 escalada por números enteros (x6 a 1920x1080) para mantener los píxeles nítidos. |
| RNF-03 | Casillas de 16x16 px. Personajes de 16x24 px. Paleta fija de 16 colores para todo el arte. |
| RNF-04 | El juego sigue siendo jugable con 150 ms de latencia entre anfitrión y cliente. |
| RNF-05 | El anfitrión es la única autoridad sobre monstruo, generadores, pilas y estados de los jugadores. |
| RNF-06 | Cada jugador controla su movimiento y el ángulo de su linterna. El anfitrión rechaza velocidades imposibles. |
| RNF-07 | Una partida dura entre 10 y 20 minutos. |
| RNF-08 | El ejecutable exportado ocupa menos de 150 MB. |

## 5. Contenido del MVP
| Elemento | Cantidad |
|---|---|
| Mapas | 1 hospital de unas 12 salas en planta baja y sótano, unidos por escaleras (ver 5.1) |
| Monstruos | 1 |
| Personajes | 1 modelo con 4 colores |
| Objetos | Pilas, generadores, puerta de salida |
| Sprites | Unos 25 (tiles, personaje con 4 direcciones, monstruo, objetos, interfaz) |
| Sonidos | Unos 15 (pasos, linterna, generador, monstruo, latido, interfaz) |
| Música | 1 ambiente de fondo en bucle |

### 5.1 Mapa: hospital abandonado
| Zona | Salas | Contenido |
|---|---|---|
| Entrada | Urgencias, recepción, sala de espera | Punto de aparición, puerta de salida bloqueada |
| Ala A | Maternidad, sala de incubadoras, control de enfermería | Generador 1 |
| Ala B | Quirófano, farmacia, rayos X | Generador 2 |
| Sótano | Morgue, laboratorio secreto, sala de calderas | Generador 3, punto donde aparece el monstruo |
| Pasillos | Conexión entre zonas | Pilas repartidas, camillas y sillas de ruedas como obstáculos |

Ambiente visual: azulejos sucios, cortinas rotas, carteles médicos sin texto legible y luces de emergencia rojas apagadas hasta reparar cada generador.

Los pasillos y puertas miden al menos 3 casillas (48 px) de ancho para que el monstruo quepa.

### 5.2 Monstruo: El Nonato (nombre provisional)
| Aspecto | Descripción |
|---|---|
| Origen | Experimento fallido del laboratorio secreto del sótano, ligado a la maternidad del Ala A. |
| Forma | Feto gigante, pálido y translúcido, con la cabeza hinchada y desproporcionada. Se arrastra con brazos largos y arrastra el cordón umbilical. |
| Tamaño | Sprite de 40x40 px, unas 2,5 veces la altura de un jugador (16x24 px). Caja de colisión de 32x24 px. |
| Animaciones | Arrastrarse en 4 direcciones, temblar congelado bajo la luz, atacar. |
| Sonido | Latido grave cuando está cerca, gorgoteo al moverse, llanto distorsionado al quedar congelado. |
| Pista visual | El cordón deja un rastro húmedo en el suelo durante 20 s, visible solo con luz. |

## 6. Fuera del MVP
Estas funciones quedan para ampliaciones posteriores:
- Más monstruos con reglas propias, por ejemplo uno que solo ataca a quien hace ruido.
- Más mapas y salas generadas al azar.
- Objetos extra: bengalas, trampas de luz, llaves.
- Mando, chat de voz por proximidad, partidas por Steam sin abrir puertos.
- Progresión entre partidas.

## 7. Plan de fases
| Fase | Contenido | Duración estimada |
|---|---|---|
| 1 | Prototipo en solitario: movimiento, linterna, oscuridad, monstruo | 2 semanas |
| 2 | Red: sala de espera, sincronización de jugadores, monstruo y objetos | 4 a 6 semanas |
| 3 | Bucle completo: generadores, derribo, salida, pantallas | 2 semanas |
| 4 | Arte final, sonido y pruebas con amigos | 2 semanas |

## 8. Estado
| Fase | Estado | Pendiente |
|---|---|---|
| 1 | Hecha. Pruebas automáticas: luz, oscuridad, lámpara y persecución. | Prueba manual del control. |
| 2 | Hecha. Pruebas con 2 instancias en el mismo PC: movimiento, pila y derribo sincronizados. RF-06 opciones (volumen, pantalla completa con F11, nombre guardado). RNF-06: el anfitrión devuelve a su sitio a quien se mueve más rápido de lo posible. | Prueba entre 2 PCs reales. |
| 4 | Hecha en parte. Sprites animados (jugador 4x3 fotogramas en 4 colores, monstruo 4 fotogramas), paredes con cara iluminada, 14 sonidos sintetizados (tools/gen_sounds.py), latido según distancia al monstruo, herramienta tools/pixelize.py para convertir dibujos a la paleta. | Gemini no genera imágenes en la cuenta gratuita (cuota 0). Arte dibujado a mano o con IA de pago, fuente pixel, opciones de volumen (RF-06) y pruebas con amigos. |
| 3 | Hecha. Mapa del hospital (tools/gen_hospital_map.py), generadores, luces de zona, salida, reanimación, 2 derribos, muerte por desangrado, espectador, pausa (RF-07) y pantalla final. Pruebas: reparar, escapar, reanimar, segundo golpe y desangrado. | Prueba manual con 2 a 4 jugadores. El sótano está en el mismo plano que la planta baja, unido por casillas de escalera. |

## 9. Decisiones abiertas
- Nombre definitivo del monstruo.
