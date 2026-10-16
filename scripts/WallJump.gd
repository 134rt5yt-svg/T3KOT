extends Node

signal wall_state_changed(active: bool)

@export var push_force := 7.0
@export var up_velocity := 9.5
@export var slow_time_scale := 0.3

var player: CharacterBody3D
var active := false

var _jump_buffered := false

func _ready() -> void:
	player = get_parent() as CharacterBody3D

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		_jump_buffered = true

func _physics_process(_delta: float) -> void:
	if player == null or player.frozen:
		_set_active(false)
		return
	var on_wall := player.is_on_wall_only()
	_set_active(on_wall)
	if on_wall and _jump_buffered:
		_jump_buffered = false
		var wall_normal: Vector3 = player.get_wall_normal()
		player.velocity = wall_normal * push_force + Vector3.UP * up_velocity
		_set_active(false)
	elif not on_wall:
		_jump_buffered = false

func _set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	Engine.time_scale = slow_time_scale if active else 1.0
	wall_state_changed.emit(active)
