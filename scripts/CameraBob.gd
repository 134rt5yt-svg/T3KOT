extends Camera3D

@export var bob_amplitude := 0.06
@export var bob_frequency := 9.0
@export var sway := 0.03
@export var breath_amplitude := 0.012
@export var breath_frequency := 1.6
@export var land_dip_max := 0.22
@export var strafe_roll_deg := 3.5
@export var fall_fov_max := 7.0

@export var jump_kick_deg := 3.5      # клёв камеры вверх при прыжке
@export var land_pitch_deg := 4.0     # клёв вниз при приземлении
@export var jump_fov_kick := 4.0      # FOV-ручка при прыжке
@export var strafe_lag := 0.09        # боковой снос камеры при стрейфе
@export var strafe_lag_max := 0.12
@export var turn_sway_deg := 1.2      # небольшой наклон при повороте мыши
@export var step_bump := 0.02         # толчок вниз на каждый "шаг" боба

var pitch_offset := 0.0

var _time := 0.0
var _base_position: Vector3
var _base_fov: float
var _dip := 0.0
var _dip_velocity := 0.0
var _was_on_floor := true
var _was_on_floor_prev := true
var _prev_fall_speed := 0.0
var _roll := 0.0
var _pitch_kick := 0.0
var _pitch_kick_vel := 0.0
var _fov_kick := 0.0
var _lag_x := 0.0
var _prev_yaw := 0.0
var _yaw_vel := 0.0
var _last_step_sign := 1.0

func _ready() -> void:
	_base_position = position
	_base_fov = fov
	_prev_yaw = (get_parent() as Node3D).rotation.y

func _process(delta: float) -> void:
	var body := get_parent() as CharacterBody3D
	if body == null:
		return
	var planar_speed := Vector2(body.velocity.x, body.velocity.z).length()

	# --- приземление: вертикальный провал + клёв носом вниз ---
	if body.is_on_floor() and not _was_on_floor:
		var impact := minf(_prev_fall_speed * 0.02, land_dip_max)
		_dip_velocity = -impact * 8.0
		_pitch_kick_vel = -deg_to_rad(land_pitch_deg) * (impact / land_dip_max) * 8.0
	_was_on_floor = body.is_on_floor()
	if body.is_on_floor():
		_prev_fall_speed = 0.0
	else:
		_prev_fall_speed = maxf(_prev_fall_speed, -body.velocity.y)
	_dip_velocity += (-_dip * 90.0 - _dip_velocity * 12.0) * delta
	_dip += _dip_velocity * delta

	# --- прыжок: клёв вверх + FOV-кик ---
	if not body.is_on_floor() and _was_on_floor_prev and body.velocity.y > 1.0:
		_pitch_kick_vel = deg_to_rad(jump_kick_deg) * 8.0
		_fov_kick = jump_fov_kick
	_was_on_floor_prev = body.is_on_floor()
	_pitch_kick_vel += (-_pitch_kick * 90.0 - _pitch_kick_vel * 10.0) * delta
	_pitch_kick += _pitch_kick_vel * delta
	pitch_offset = _pitch_kick
	_fov_kick = lerpf(_fov_kick, 0.0, minf(5.0 * delta, 1.0))

	# --- боб ходьбы: вертикаль + горизонтальный снос + толчок на шаг ---
	var target_y := _base_position.y + _dip
	var target_x := _base_position.x
	if body.is_on_floor() and planar_speed > 0.8:
		_time += delta * bob_frequency * clampf(planar_speed / 6.0, 0.6, 1.4)
		target_y += sin(_time * 2.0) * bob_amplitude
		var sway_x := cos(_time)
		target_x += sway_x * sway
		# лёгкий удар ножки в момент переноса веса
		if signf(sway_x) != _last_step_sign and absf(sway_x) > 0.5:
			_last_step_sign = signf(sway_x)
			_dip_velocity -= step_bump * 20.0
	else:
		_time = 0.0
		target_y += sin(Time.get_ticks_msec() / 1000.0 * breath_frequency) * breath_amplitude

	# --- боковой снос камеры от стрейфа (инерция головы) ---
	var local_vel := (body.global_transform.basis.inverse() * body.velocity)
	_lag_x = lerpf(_lag_x, clampf(-local_vel.x / 6.0 * strafe_lag_max, -strafe_lag_max, strafe_lag_max), minf(10.0 * delta, 1.0))
	target_x += _lag_x

	var k := minf(12.0 * delta, 1.0)
	position.x = lerpf(position.x, target_x, k)
	position.y = lerpf(position.y, target_y, k)

	# --- наклон при стрейфе + лёгкий наклон от поворота мыши ---
	var yaw: float = (body as Node3D).rotation.y
	_yaw_vel = lerpf(_yaw_vel, angle_difference(_prev_yaw, yaw) / maxf(delta, 0.0001), minf(10.0 * delta, 1.0))
	_prev_yaw = yaw
	var input_x := Input.get_axis("move_left", "move_right")
	var target_roll := -input_x * deg_to_rad(strafe_roll_deg) * clampf(planar_speed / 6.0, 0.0, 1.0)
	target_roll += clampf(_yaw_vel * deg_to_rad(turn_sway_deg) / deg_to_rad(90.0), -deg_to_rad(turn_sway_deg), deg_to_rad(turn_sway_deg))
	_roll = lerpf(_roll, target_roll, minf(8.0 * delta, 1.0))
	rotation.z = _roll

	# --- FOV: разгон при падении + кик на прыжке ---
	var fall := clampf(-body.velocity.y, 0.0, 25.0)
	fov = lerpf(fov, _base_fov + fall / 25.0 * fall_fov_max + _fov_kick, minf(6.0 * delta, 1.0))
