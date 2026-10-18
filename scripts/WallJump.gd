extends Node

signal wall_state_changed(active: bool)

const SND_WALL_JUMP := preload("res://sounds/wall_jump.ogg")
const SND_WALL_JUMP_2 := preload("res://sounds/wall_jump_2.ogg")

@export var push_force := 7.0
@export var up_velocity := 9.5
@export var slow_time_scale := 0.3

var player: CharacterBody3D
var camera: Camera3D
var active := false

var _jump_buffered := false
var _buffer_time := 0.0

@export var buffer_window := 0.12

func _ready() -> void:
	player = get_parent() as CharacterBody3D
	camera = player.get_node_or_null("Camera3D") as Camera3D

func _physics_process(delta: float) -> void:
	if player == null or player.frozen:
		_set_active(false)
		return
	# Тач-кнопка прыжка не создаёт InputEvent (только Input.action_press),
	# поэтому проверяем экшен прямо в физике — работает и с клавиатурой.
	if Input.is_action_just_pressed("jump"):
		_jump_buffered = true
		_buffer_time = buffer_window
	if _buffer_time > 0.0:
		_buffer_time -= delta
	else:
		_jump_buffered = false
	var on_wall := player.is_on_wall_only()
	_set_active(on_wall)
	if on_wall and _jump_buffered:
		_jump_buffered = false
		var wall_normal: Vector3 = player.get_wall_normal()
		player.velocity = wall_normal * push_force + Vector3.UP * up_velocity
		_play_bounce(wall_normal)
		_set_active(false)

func _play_bounce(wall_normal: Vector3) -> void:
	# Кик камеры в сторону от стены + деревянный удар.
	if camera != null and camera.has_method("wall_kick"):
		var local_n: Vector3 = player.global_transform.basis.inverse() * wall_normal
		camera.wall_kick(signf(local_n.x))
	var p := AudioStreamPlayer.new()
	p.stream = SND_WALL_JUMP if randf() < 0.5 else SND_WALL_JUMP_2
	p.volume_db = -4.0
	p.pitch_scale = randf_range(0.95, 1.1)
	p.finished.connect(p.queue_free)
	player.add_child(p)
	p.play()

func _set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	Engine.time_scale = slow_time_scale if active else 1.0
	wall_state_changed.emit(active)
