extends Camera3D

@export var bob_amplitude := 0.05
@export var bob_frequency := 8.0
@export var sway := 0.025
@export var breath_amplitude := 0.012
@export var breath_frequency := 1.6
@export var land_dip_max := 0.22
@export var strafe_roll_deg := 3.0
@export var fall_fov_max := 6.0

var _time := 0.0
var _base_position: Vector3
var _base_fov: float
var _dip := 0.0
var _dip_velocity := 0.0
var _was_on_floor := true
var _prev_fall_speed := 0.0
var _roll := 0.0

func _ready() -> void:
	_base_position = position
	_base_fov = fov

func _process(delta: float) -> void:
	var body := get_parent() as CharacterBody3D
	if body == null:
		return
	var planar_speed := Vector2(body.velocity.x, body.velocity.z).length()

	if body.is_on_floor() and not _was_on_floor:
		_dip_velocity = -minf(_prev_fall_speed * 0.02, land_dip_max) * 8.0
	_was_on_floor = body.is_on_floor()
	if body.is_on_floor():
		_prev_fall_speed = 0.0
	else:
		_prev_fall_speed = maxf(_prev_fall_speed, -body.velocity.y)
	_dip_velocity += (-_dip * 90.0 - _dip_velocity * 12.0) * delta
	_dip += _dip_velocity * delta

	var target_y := _base_position.y + _dip
	var target_x := _base_position.x
	if body.is_on_floor() and planar_speed > 0.8:
		_time += delta * bob_frequency * clampf(planar_speed / 6.0, 0.6, 1.4)
		target_y += sin(_time * 2.0) * bob_amplitude
		target_x += cos(_time) * sway
	else:
		_time = 0.0
		target_y += sin(Time.get_ticks_msec() / 1000.0 * breath_frequency) * breath_amplitude

	var k := minf(12.0 * delta, 1.0)
	position.x = lerpf(position.x, target_x, k)
	position.y = lerpf(position.y, target_y, k)

	var input_x := Input.get_axis("move_left", "move_right")
	var target_roll := -input_x * deg_to_rad(strafe_roll_deg) * clampf(planar_speed / 6.0, 0.0, 1.0)
	_roll = lerpf(_roll, target_roll, minf(8.0 * delta, 1.0))
	rotation.z = _roll

	var fall := clampf(-body.velocity.y, 0.0, 25.0)
	fov = lerpf(fov, _base_fov + fall / 25.0 * fall_fov_max, minf(6.0 * delta, 1.0))
