extends CanvasLayer
## Сенсорное управление для телефонов: плавающий джойстик слева,
## кнопка прыжка справа снизу, обзор — перетаскиванием по правой половине экрана.
## Создаётся целиком из кода и подаёт нажатия через Input.action_press,
## так что Player.gd работает без изменений.

const STICK_RADIUS := 130.0   # радиус базы джойстика
const STICK_DEAD := 0.15
const JUMP_RADIUS := 96.0
const LOOK_SENS := 1.6        # множитель чувствительности обзора относительно мыши

var _stick_index := -1        # палец, который ведёт джойстик
var _look_index := -1         # палец, который ведёт обзор
var _jump_index := -1         # палец на кнопке прыжка
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _jump_center := Vector2.ZERO
var _jump_pressed := false
var _hud: Control

func _ready() -> void:
	layer = 10
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.draw.connect(_draw_hud)
	add_child(_hud)
	get_viewport().size_changed.connect(_update_jump_center)
	_update_jump_center()

func _update_jump_center() -> void:
	var size := _hud.get_viewport_rect().size
	_jump_center = Vector2(size.x - JUMP_RADIUS - 60.0, size.y - JUMP_RADIUS - 80.0)
	_hud.queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < _hud.get_viewport_rect().size.x * 0.5 and _stick_index == -1:
				_stick_index = event.index
				_stick_origin = event.position
				_stick_pos = event.position
				_hud.queue_redraw()
			elif event.position.distance_to(_jump_center) < JUMP_RADIUS * 1.3:
				_jump_index = event.index
				_jump_pressed = true
				Input.action_press("jump")
				_hud.queue_redraw()
			elif _look_index == -1:
				_look_index = event.index
		else:
			if event.index == _stick_index:
				_stick_index = -1
				_apply_move(Vector2.ZERO)
				_hud.queue_redraw()
			elif event.index == _jump_index:
				_jump_index = -1
				_jump_pressed = false
				Input.action_release("jump")
				_hud.queue_redraw()
			elif event.index == _look_index:
				_look_index = -1
	elif event is InputEventScreenDrag and event.index == _stick_index:
		var drag := event as InputEventScreenDrag
		var offset := drag.position - _stick_origin
		if offset.length() > STICK_RADIUS:
			# база подтягивается за пальцем, как в современных шутерах
			_stick_origin = event.position - offset.normalized() * STICK_RADIUS
			offset = offset.normalized() * STICK_RADIUS
		_stick_pos = _stick_origin + offset
		_apply_move(offset / STICK_RADIUS)
		_hud.queue_redraw()
	elif event is InputEventScreenDrag and event.index == _look_index:
		var motion := InputEventMouseMotion.new()
		motion.relative = (event as InputEventScreenDrag).relative * LOOK_SENS
		Input.parse_input_event(motion)

func _apply_move(v: Vector2) -> void:
	for action in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(action)
	if v.length() < STICK_DEAD:
		return
	# оси как у Player.gd: x — влево/вправо, y — вперёд/назад
	var strength := clampf(v.length(), 0.0, 1.0)
	var dir := v.normalized()
	if dir.x < -0.2:
		Input.action_press("move_left", strength * -dir.x)
	if dir.x > 0.2:
		Input.action_press("move_right", strength * dir.x)
	if dir.y < -0.2:
		Input.action_press("move_forward", strength * -dir.y)
	if dir.y > 0.2:
		Input.action_press("move_back", strength * dir.y)

func _draw_hud() -> void:
	if _stick_index != -1:
		_hud.draw_circle(_stick_origin, STICK_RADIUS, Color(1, 1, 1, 0.08))
		_hud.draw_arc(_stick_origin, STICK_RADIUS, 0, TAU, 40, Color(1, 1, 1, 0.35), 2.0)
		_hud.draw_circle(_stick_pos, 48.0, Color(1, 1, 1, 0.25))
		_hud.draw_arc(_stick_pos, 48.0, 0, TAU, 32, Color(1, 1, 1, 0.6), 2.0)
	var jump_col := Color(1, 1, 1, 0.5) if _jump_pressed else Color(1, 1, 1, 0.22)
	_hud.draw_circle(_jump_center, JUMP_RADIUS, Color(1, 1, 1, 0.10))
	_hud.draw_arc(_jump_center, JUMP_RADIUS, 0, TAU, 48, jump_col, 3.0)
	_hud.draw_circle(_jump_center, 26.0, jump_col)
