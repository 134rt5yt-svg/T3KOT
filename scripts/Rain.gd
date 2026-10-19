extends Node3D
## Постоянный дождь: капли вокруг игрока, негромкий шум дождя.
## «Мокрый экран» (капли + искажение) рисует PS1-постобработка.

var _player: CharacterBody3D
var _particles: CPUParticles3D
var _snd: AudioStreamPlayer
var _ps1: Node

func _init(player: CharacterBody3D, ps1: Node = null) -> void:
	_player = player
	_ps1 = ps1

func _ready() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.014, 0.7, 0.014)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.72, 0.78, 0.85, 0.45)
	box.material = m

	_particles = CPUParticles3D.new()
	_particles.mesh = box
	_particles.amount = 480
	_particles.lifetime = 1.1
	_particles.emitting = true
	_particles.direction = Vector3(0.06, -1, 0.02)
	_particles.spread = 3.0
	_particles.gravity = Vector3(0, -26, 0)
	_particles.initial_velocity_min = 16.0
	_particles.initial_velocity_max = 22.0
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_particles.emission_box_extents = Vector3(14, 0.4, 14)
	add_child(_particles)
	_particles.global_position = _player.global_position + Vector3(0, 8, 0)

	_snd = AudioStreamPlayer.new()
	if ResourceLoader.exists("res://sounds/rain.wav"):
		var s: AudioStreamWAV = load("res://sounds/rain.wav")
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.data.size() / 2
		_snd.stream = s
	_snd.volume_db = -20.0
	add_child(_snd)
	_snd.play()

	if _ps1 != null and _ps1.has_method("set_wetness"):
		_ps1.call("set_wetness", 1.0)

func _process(_delta: float) -> void:
	if _player != null:
		_particles.global_position = _player.global_position + Vector3(0, 8, 0)

## Наклон дождя от ветра (0 — вертикально).
func set_tilt(wind: Vector3) -> void:
	_particles.direction = (wind * 0.09 + Vector3(0, -1, 0)).normalized()
