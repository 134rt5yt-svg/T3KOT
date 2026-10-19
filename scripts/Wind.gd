extends Node
## Порывы ветра: в воздухе игрока заметно сносит в сторону, дождь
## наклоняется, нарастает рёв. Чем выше по башне — тем сильнее ветер.

const CALM_MIN := 9.0
const CALM_MAX := 22.0
const GUST_MIN := 3.5
const GUST_MAX := 6.5
const RAMP_UP := 1.2
const RAMP_DOWN := 1.6
const BASE_STRENGTH := 1.1   # м/с^2 в разгоне воздушного сноса

var _player: CharacterBody3D
var _rain: Node
var _snd: AudioStreamPlayer

var _calm := true
var _timer := 6.0
var _phase := 0.0           # время внутри порыва
var _duration := 5.0
var _dir := Vector3.ZERO
var _peak := 1.5

func _init(player: CharacterBody3D, rain: Node) -> void:
	_player = player
	_rain = rain

func _ready() -> void:
	_snd = AudioStreamPlayer.new()
	if ResourceLoader.exists("res://sounds/wind.wav"):
		var s: AudioStreamWAV = load("res://sounds/wind.wav")
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.data.size() / 2
		_snd.stream = s
	_snd.volume_db = -60.0
	add_child(_snd)
	_snd.play()
	_timer = randf_range(5.0, 12.0)

func _physics_process(delta: float) -> void:
	_timer -= delta
	if _calm:
		if _timer <= 0.0:
			_start_gust()
		return

	_phase += delta
	if _phase >= _duration + RAMP_DOWN:
		_end_gust()
		return

	# Огибающая порыва: разгон — удержание — спад.
	var env := 1.0
	if _phase < RAMP_UP:
		env = _phase / RAMP_UP
	elif _phase > _duration:
		env = 1.0 - (_phase - _duration) / RAMP_DOWN
	env = clampf(env, 0.0, 1.0)

	# С высотой ветер злее: у земли x1, на вершине x1.8.
	var height := clampf(_player.global_position.y / 42.0, 0.0, 1.0)
	var scale := 1.0 + height * 0.8

	_player.wind_accel = _dir * _peak * env * scale
	_rain.call_deferred("set_tilt", _dir * env * scale)

	var vol := lerpf(-60.0, -16.0, env * (0.55 + 0.45 * height))
	_snd.volume_db = vol
	_snd.pitch_scale = 0.9 + 0.25 * env

func _start_gust() -> void:
	_calm = false
	_phase = 0.0
	_duration = randf_range(GUST_MIN, GUST_MAX)
	_peak = BASE_STRENGTH * randf_range(0.8, 1.6)
	var ang := randf() * TAU
	_dir = Vector3(cos(ang), 0, sin(ang)).normalized()
	if _snd.stream != null:
		_snd.pitch_scale = randf_range(0.9, 1.15)

func _end_gust() -> void:
	_calm = true
	_player.wind_accel = Vector3.ZERO
	_rain.call_deferred("set_tilt", Vector3.ZERO)
	_snd.volume_db = -60.0
	_timer = randf_range(CALM_MIN, CALM_MAX)
