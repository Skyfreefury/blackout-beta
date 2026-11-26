extends Node
## Música (audio/music/*.ogg, compuesta con Suno). Sigue sonando al cambiar de escena.
## play() cambia de pista con fundido cruzado; sting() suena una vez y baja la pista de fondo.

const TRACKS := {
	"menu": preload("res://audio/music/menu.ogg"),
	"explore": preload("res://audio/music/explore.ogg"),
	"chase": preload("res://audio/music/chase.ogg"),
	"win": preload("res://audio/music/win.ogg"),
	"death": preload("res://audio/music/death.ogg"),
}
## Volumen de cada pista de fondo en dB.
const LEVELS := {"menu": -6.0, "explore": -10.0, "chase": -6.0}
const SILENT := -60.0

var current := ""
var _players: Array[AudioStreamPlayer] = []
var _active := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = SILENT
		add_child(p)
		_players.append(p)
	for name in LEVELS:
		TRACKS[name].loop = true


## Pista de fondo en bucle. No hace nada si ya suena.
func play(track: String, fade := 1.5, volume_offset := 0.0) -> void:
	if track == current:
		return
	current = track
	var old := _players[_active]
	_active = 1 - _active
	var new := _players[_active]
	new.stream = TRACKS[track]
	new.volume_db = SILENT
	new.play()
	var tween := create_tween().set_parallel()
	tween.tween_property(new, "volume_db", LEVELS[track] + volume_offset, fade)
	tween.tween_property(old, "volume_db", SILENT, fade)
	tween.chain().tween_callback(old.stop)


func stop(fade := 1.0) -> void:
	current = ""
	for p in _players:
		create_tween().tween_property(p, "volume_db", SILENT, fade)


## Golpe musical corto (win, death). Para la pista de fondo.
func sting(track: String, volume_db := -2.0) -> void:
	stop(0.4)
	var p := AudioStreamPlayer.new()
	p.stream = TRACKS[track]
	p.volume_db = volume_db
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()
