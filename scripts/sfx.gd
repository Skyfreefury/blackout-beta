extends Node
## Efectos de sonido. Los WAV salen de tools/gen_sounds.py.
## Los sonidos posicionales se oyen según la distancia a la cámara activa.

const STREAMS := {
	"step": preload("res://audio/step.wav"),
	"flashlight": preload("res://audio/flashlight.wav"),
	"battery": preload("res://audio/battery.wav"),
	"generator_loop": preload("res://audio/generator_loop.wav"),
	"generator_on": preload("res://audio/generator_on.wav"),
	"door_open": preload("res://audio/door_open.wav"),
	"monster_loop": preload("res://audio/monster_loop.wav"),
	"monster_freeze": preload("res://audio/monster_freeze.wav"),
	"heartbeat_loop": preload("res://audio/heartbeat_loop.wav"),
	"down": preload("res://audio/down.wav"),
	"revive": preload("res://audio/revive.wav"),
	"death": preload("res://audio/death.wav"),
	"ui_click": preload("res://audio/ui_click.wav"),
	"ambient_loop": preload("res://audio/ambient_loop.wav"),
}
## Distancia en píxeles a la que un sonido deja de oírse.
const HEARING := 260.0


## Sonido único en una posición del mundo. Se borra al terminar.
func play_at(sound: String, pos: Vector2, volume_db := 0.0) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var p := AudioStreamPlayer2D.new()
	p.stream = STREAMS[sound]
	p.volume_db = volume_db
	p.max_distance = HEARING
	p.global_position = pos
	p.finished.connect(p.queue_free)
	scene.add_child(p)
	p.play()


## Sonido de interfaz, sin posición.
func play_ui(sound: String, volume_db := 0.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = STREAMS[sound]
	p.volume_db = volume_db
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()


## Reproductor en bucle colgado de un nodo. Se controla con play() y stop().
## El bucle viene de la importación: los *_loop.wav.import usan edit/loop_mode=2.
func make_loop_2d(owner_node: Node2D, sound: String, volume_db := 0.0, distance := HEARING) -> AudioStreamPlayer2D:
	var p := AudioStreamPlayer2D.new()
	p.stream = STREAMS[sound]
	p.volume_db = volume_db
	p.max_distance = distance
	owner_node.add_child(p)
	return p


func make_loop(owner_node: Node, sound: String, volume_db := 0.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = STREAMS[sound]
	p.volume_db = volume_db
	owner_node.add_child(p)
	return p
