extends CanvasLayer
## Существующее сенсорное управление: джойстик слева, прыжок справа,
## обзор отдельным пальцем в правой области. Не генерирует события мыши:
## камера получает дельту напрямую, поэтому джойстик не вращает обзор.

const STICK_RADIUS := 130.0
const STICK_DEAD := 0.15
const JUMP_RADIUS := 96.0
const LOOK_SENS := 0.0035 # радианы на пиксель, масштабируется с разрешением

var _stick_index := -1
var _look_index := -1
var _jump_index := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _jump_center := Vector2.ZERO
var _jump_pressed := false
var _hud: Control
var _player: CharacterBody3D
var _screen_size := Vector2.ZERO

func _ready() -> void:
	layer = 10
	_player = get_parent() as CharacterBody3D
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.draw.connect(_draw_hud)
	add_child(_hud)
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()

func _update_layout() -> void:
	_screen_size = get_viewport().get_visible_rect().size
	# Кнопка прыжка располагается с отступами в процентах от размера экрана.
	_jump_center = Vector2(_screen_size.x * 0.86, _screen_size.y * 0.80)
	_hud.queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			# Прыжок проверяем первым, чтобы он не был принят за джойстик
			# на телефонах с узким экраном.
			if touch.position.distance_to(_jump_center) <= JUMP_RADIUS * 1.25 and _jump_index == -1:
				_jump_index = touch.index
				_jump_pressed = true
				Input.action_press("jump")
				_hud.queue_redraw()
			elif touch.position.x < _screen_size.x * 0.48 and _stick_index == -1:
				_stick_index = touch.index
				_stick_origin = touch.position
				_stick_pos = touch.position
				_hud.queue_redraw()
			elif touch.position.x >= _screen_size.x * 0.48 and _look_index == -1:
				_look_index = touch.index
		else:
			if touch.index == _stick_index:
				_stick_index = -1
				_apply_move(Vector2.ZERO)
				_hud.queue_redraw()
			elif touch.index == _jump_index:
				_jump_index = -1
				_jump_pressed = false
				Input.action_release("jump")
				_hud.queue_redraw()
			elif touch.index == _look_index:
				_look_index = -1
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _stick_index:
			var offset: Vector2 = drag.position - _stick_origin
			if offset.length() > STICK_RADIUS:
				offset = offset.normalized() * STICK_RADIUS
			_stick_pos = _stick_origin + offset
			_apply_move(offset / STICK_RADIUS)
			_hud.queue_redraw()
		elif drag.index == _look_index and _player != null:
			# Только палец, захваченный в правой зоне, поворачивает камеру.
			_player.apply_touch_look(drag.relative)

func _apply_move(v: Vector2) -> void:
	for action in ["move_left", "move_right", "move_forward", "move_back"]:
		Input.action_release(action)
	if v.length() < STICK_DEAD:
		return
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
