extends CharacterBody3D

const SPEED := 6.0
const ACCEL := 14.0
const GRAVITY := 18.0
const JUMP_VELOCITY := 10.5
const MOUSE_SENSITIVITY := 0.0025

const TouchControls := preload("res://scripts/TouchControls.gd")

const SND_LAND_LIGHT := preload("res://sounds/land_light.ogg")
const SND_LAND_MEDIUM := preload("res://sounds/land_medium.ogg")
const SND_LAND_HEAVY := preload("res://sounds/land_heavy.ogg")
const SND_JUMP := preload("res://sounds/jump.ogg")

@onready var camera: Camera3D = $Camera3D

var frozen := false
## Режим «посидеть»: камера под управлением паузы, ввод игнорируется.
var sit_mode := false
## Горизонтальный снос от ветра (заполняет Wind.gd, применяется в воздухе).
var wind_accel := Vector3.ZERO
var last_safe_position := Vector3.ZERO
var pitch := 0.0
var _was_on_floor := true
var _fall_speed := 0.0
var _sfx_land: AudioStreamPlayer
var _sfx_jump: AudioStreamPlayer

func _ready() -> void:
	add_to_group("player")
	last_safe_position = global_position
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
		# Иначе тач эмулирует мышь, и джойстик вращает камеру.
		Input.emulate_mouse_from_touch = false
		add_child(TouchControls.new())
	_sfx_land = AudioStreamPlayer.new()
	_sfx_land.bus = "Master"
	add_child(_sfx_land)
	_sfx_jump = AudioStreamPlayer.new()
	_sfx_jump.bus = "Master"
	add_child(_sfx_jump)

func _play_land() -> void:
	# Сила удара выбирает звук и его громкость.
	var impact := clampf(_fall_speed / 20.0, 0.0, 1.0)
	if impact < 0.001:
		return
	_sfx_land.stream = SND_LAND_LIGHT if impact < 0.35 \
		else (SND_LAND_MEDIUM if impact < 0.7 else SND_LAND_HEAVY)
	_sfx_land.volume_db = lerpf(-16.0, -2.0, impact)
	_sfx_land.pitch_scale = randf_range(0.94, 1.06)
	_sfx_land.play()

func _play_jump() -> void:
	_sfx_jump.stream = SND_JUMP
	_sfx_jump.volume_db = -10.0
	_sfx_jump.pitch_scale = randf_range(1.25, 1.4)
	_sfx_jump.play()

func apply_touch_look(relative: Vector2) -> void:
	# Прямой путь для сенсорного обзора; не создаём искусственные mouse events.
	var scale_factor := get_viewport().get_visible_rect().size.x / 1280.0
	var sens := MOUSE_SENSITIVITY * clampf(scale_factor, 0.65, 1.6) * 1.4
	rotate_y(-relative.x * sens)
	pitch = clampf(pitch - relative.y * sens, deg_to_rad(-85.0), deg_to_rad(85.0))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		pitch = clampf(pitch - event.relative.y * MOUSE_SENSITIVITY, deg_to_rad(-85.0), deg_to_rad(85.0))
	elif event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if not sit_mode:
		camera.rotation.x = pitch + camera.pitch_offset
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	var input_dir := Vector2.ZERO
	if not frozen:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction.length() > 0.5:
		velocity.x = move_toward(velocity.x, direction.x * SPEED, ACCEL * delta)
		velocity.z = move_toward(velocity.z, direction.z * SPEED, ACCEL * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, ACCEL * delta)
		velocity.z = move_toward(velocity.z, 0.0, ACCEL * delta)
	if not frozen and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		_play_jump()
	# Порыв ветра сносит только в воздухе.
	if not is_on_floor():
		velocity.x += wind_accel.x * delta
		velocity.z += wind_accel.z * delta
	move_and_slide()
	if is_on_floor():
		last_safe_position = global_position
		if not _was_on_floor:
			_play_land()
		_fall_speed = 0.0
	else:
		_fall_speed = maxf(_fall_speed, -velocity.y)
	_was_on_floor = is_on_floor()

func respawn() -> void:
	Engine.time_scale = 1.0
	global_position = last_safe_position + Vector3(0, 0.3, 0)
	velocity = Vector3.ZERO
