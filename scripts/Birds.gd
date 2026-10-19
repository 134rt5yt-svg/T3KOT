extends Node3D
## Стайки птиц, изредка пролетающие по небу над башней: тёмные силуэты
## клином, машут крыльями, иногда издают далёкий крик.

const SPAWN_MIN := 18.0
const SPAWN_MAX := 45.0
const FLOCK_SPEED := 9.0
const DESPAWN_DIST := 130.0

var _player: CharacterBody3D
var _timer := 9.0
var _flocks: Array[Node3D] = []
var _snd: AudioStreamPlayer

func _init(player: CharacterBody3D) -> void:
	_player = player

func _ready() -> void:
	_snd = AudioStreamPlayer.new()
	if ResourceLoader.exists("res://sounds/caw.wav"):
		_snd.stream = load("res://sounds/caw.wav")
	_snd.volume_db = -24.0
	add_child(_snd)

func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(SPAWN_MIN, SPAWN_MAX)
		_spawn_flock()

	var now := Time.get_ticks_msec() / 1000.0
	for flock in _flocks.duplicate():
		var vel: Vector3 = flock.get_meta("vel")
		var phase: float = flock.get_meta("phase")
		flock.global_position += vel * delta
		flock.global_position.y += sin(now * 0.7 + phase) * 0.4 * delta
		# Взмахи крыльев.
		var flap := 0.55 + 0.65 * sin(now * 9.0 + phase)
		for bird in flock.get_children():
			var p: float = bird.get_meta("phase")
			var f := 0.55 + 0.65 * sin(now * 9.0 + p)
			bird.get_node("WingL").rotation.z = f
			bird.get_node("WingR").rotation.z = -f
		# Далёкий крик — изредка.
		if _snd.stream != null and randf() < 0.10 * delta * 10.0:
			_snd.pitch_scale = randf_range(0.85, 1.2)
			_snd.play()
		if flock.global_position.distance_to(_player.global_position) > DESPAWN_DIST:
			_flocks.erase(flock)
			flock.queue_free()

func _spawn_flock() -> void:
	var count := randi_range(5, 9)
	var ang := randf() * TAU
	var start := _player.global_position + Vector3(cos(ang), 0, sin(ang)) * 60.0
	start.y = _player.global_position.y + randf_range(14.0, 24.0)
	# Летит насквозь: направление чуть мимо игрока.
	var to_player := (_player.global_position - start).normalized()
	var side := to_player.cross(Vector3.UP)
	var dir := (to_player + side * randf_range(-0.5, 0.5)).normalized()

	var flock := Node3D.new()
	var phase := randf() * TAU
	flock.set_meta("vel", dir * FLOCK_SPEED * randf_range(0.85, 1.15))
	flock.set_meta("phase", phase)
	add_child(flock)
	flock.global_position = start
	flock.look_at(start + dir, Vector3.UP)
	var wing_mesh := QuadMesh.new()
	wing_mesh.size = Vector2(0.6, 0.2)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 0.19, 0.18)
	wing_mesh.material = mat

	for i in count:
		var row := (i + 1) / 2
		var side_i := 1.0 if i % 2 == 0 else -1.0
		var bird := Node3D.new()
		bird.position = Vector3(side_i * row * 1.4 + randf_range(-0.3, 0.3),
			randf_range(-0.4, 0.4), -row * 1.1 + randf_range(-0.3, 0.3))
		bird.set_meta("phase", phase + randf() * TAU)
		flock.add_child(bird)

		var wing_l := MeshInstance3D.new()
		wing_l.mesh = wing_mesh
		wing_l.position = Vector3(-0.28, 0, 0)
		wing_l.rotation = Vector3(-PI / 2, 0, 0.4)
		wing_l.name = "WingL"
		bird.add_child(wing_l)

		var wing_r := MeshInstance3D.new()
		wing_r.mesh = wing_mesh
		wing_r.position = Vector3(0.28, 0, 0)
		wing_r.rotation = Vector3(-PI / 2, 0, -0.4)
		wing_r.scale.x = -1.0
		wing_r.name = "WingR"
		bird.add_child(wing_r)

	_flocks.append(flock)
