extends CanvasLayer
## Пауза в стиле R.E.P.O.: большое 3D-меню физически распахивается из-за
## правого края экрана (почти на весь экран), камера наезжает и тянется
## за курсором. Сам лист — QuadMesh с текстурой SubViewport, поэтому кнопки
## на нём настоящие: клики пробрасываются лучом в под-вьюпорт.

const PANEL_W := 3.55
const PANEL_H := 2.05
const PANEL_Z := -1.85
const PIVOT_X := 1.93
const VP_SIZE := Vector2i(1520, 878)

# Палитра паузы — под платформы игры: тёплое дерево, текст белый.
const COL_ACC := Color("5c4229")     # фон карточки / ховер кнопок (дерево)
const COL_FG := Color(1, 1, 1, 1)    # основной текст — белый
const COL_HD := Color(1, 1, 1, 1)    # заголовок — белый
const COL_MUT := Color(1, 1, 1, 0.72)
const COL_BG := Color(1, 1, 1, 1)    # текст на кнопках — белый
const COL_CARD := Color("3d2c1d")    # заливка кнопок (тёмное дерево)
const COL_LINE := Color("2b1f14")    # рамки / плита-подложка
const NOTCH_U := 12          # размер пиксельного среза угла
const FONT_PATH := "res://resources/fonts/PixelifySans.ttf"

const SWING_FROM := deg_to_rad(84.0)
const SWING_TO := deg_to_rad(-6.0)
const ZOOM_FOV := 62.0
const DRIFT_YAW := deg_to_rad(7.0)
const DRIFT_PITCH := deg_to_rad(5.0)

var _player: CharacterBody3D
var _camera: Camera3D
var _sub_vp: SubViewport
var _quad: MeshInstance3D
var _pivot: Node3D
var _rig: Node3D
var _pause_btn: Button
var _game_ui: CanvasLayer

var _paused := false
var _settled := false
var _menu_touch_index := -1
var _base_fov := 80.0
var _base_cam_yaw := 0.0
var _base_cam_pitch := 0.0

# Аффинное отображение локальных координат квада в UV (считается из меша,
# чтобы не зависеть от порядка вершин QuadMesh).
var _uv_a := Vector2.ZERO
var _uv_b := Vector2.ZERO
var _uv_c := Vector2.ZERO

func _init(player: CharacterBody3D) -> void:
	_player = player

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_camera = _player.get_node_or_null("Camera3D") as Camera3D
	if _camera == null:
		push_error("PauseMenu: у игрока нет Camera3D")
		set_process(false)
		return

	_build_pause_button()
	_build_sub_viewport()
	_build_menu_rig()
	_game_ui = _player.get_node_or_null("../UI") as CanvasLayer

func _build_pause_button() -> void:
	_pause_btn = Button.new()
	_pause_btn.text = "❚❚"
	_pause_btn.flat = true
	_pause_btn.focus_mode = Control.FOCUS_NONE
	_pause_btn.add_theme_font_override("font", _pixel_font())
	_pause_btn.add_theme_font_size_override("font_size", 32)
	_pause_btn.add_theme_color_override("font_color", COL_FG)
	_pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_pause_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_pause_btn.offset_left = -64.0
	_pause_btn.offset_right = -10.0
	_pause_btn.offset_top = 8.0
	_pause_btn.offset_bottom = 52.0
	_pause_btn.pressed.connect(_open)
	add_child(_pause_btn)

func _build_sub_viewport() -> void:
	_sub_vp = SubViewport.new()
	_sub_vp.size = VP_SIZE
	_sub_vp.disable_3d = true
	_sub_vp.transparent_bg = true
	# Меню нужно только на паузе: не рендерим его каждый кадр игры.
	_sub_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_sub_vp)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sub_vp.add_child(root)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _notch_stylebox(
		Vector2i(320, 200), COL_ACC, COL_LINE, 6, Vector4(24, 24, 24, 24)))
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 22)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "ПАУЗА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", _pixel_font())
	title.add_theme_font_size_override("font_size", 112)
	title.add_theme_color_override("font_color", COL_HD)
	vbox.add_child(title)

	# Полоска-разделитель, как границы секций на сайте.
	var sep := ColorRect.new()
	sep.color = COL_LINE
	sep.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(sep)

	var buttons_box := VBoxContainer.new()
	buttons_box.add_theme_constant_override("separation", 18)
	vbox.add_child(buttons_box)
	buttons_box.add_child(_make_button("Продолжить", _resume))
	buttons_box.add_child(_make_button("Заново", _restart))
	buttons_box.add_child(_make_button("Выход", _quit))

	var hint := Label.new()
	hint.text = "Esc — продолжить"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", _pixel_font())
	hint.add_theme_font_size_override("font_size", 32)
	hint.add_theme_color_override("font_color", COL_MUT)
	vbox.add_child(hint)

func _pixel_font() -> Font:
	if ResourceLoader.exists(FONT_PATH):
		var f: FontFile = load(FONT_PATH)
		# Пиксельный шрифт только без сглаживания, иначе мыло.
		f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		f.hinting = TextServer.HINTING_NONE
		f.generate_mipmaps = false
		return f
	return load("res://resources/pixel_font.tres")

## Прямоугольник с пиксельно срезанными углами (аналог clip-path --notch
## на сайте): рамка + заливка, срезанные квадраты по углам.
func _notch_texture(size: Vector2i, fill: Color, border: Color, border_w: int) -> ImageTexture:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	# Без рамки вся площадь — заливка, иначе кнопки остались бы невидимыми.
	img.fill(fill if border_w == 0 else border)
	if border_w > 0:
		img.fill_rect(Rect2i(border_w, border_w,
			size.x - border_w * 2, size.y - border_w * 2), fill)
	var u := NOTCH_U
	img.fill_rect(Rect2i(0, 0, u, u), Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(size.x - u, 0, u, u), Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(0, size.y - u, u, u), Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(size.x - u, size.y - u, u, u), Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

## StyleBoxTexture с девятипатчевой растяжкой: углы с панелькой не плывут.
func _notch_stylebox(tex_size: Vector2i, fill: Color, border: Color,
		border_w: int, content_margins: Vector4) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = _notch_texture(tex_size, fill, border, border_w)
	var m := NOTCH_U + border_w
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
	sb.content_margin_left = content_margins.x
	sb.content_margin_top = content_margins.y
	sb.content_margin_right = content_margins.z
	sb.content_margin_bottom = content_margins.w
	return sb

func _make_button(text: String, handler: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(640, 96)
	b.add_theme_font_override("font", _pixel_font())
	b.add_theme_font_size_override("font_size", 48)
	# Кнопка как .btn на сайте: акцентная заливка, тёмный текст,
	# срезанные пиксельные углы; ховер — жёлтый (--hd).
	b.add_theme_color_override("font_color", COL_BG)
	b.add_theme_color_override("font_hover_color", COL_BG)
	b.add_theme_color_override("font_pressed_color", COL_BG)

	b.add_theme_stylebox_override("normal", _notch_stylebox(
		Vector2i(96, 48), COL_CARD, Color(0, 0, 0, 0), 0, Vector4(12, 10, 12, 10)))
	var hover := _notch_stylebox(
		Vector2i(96, 48), COL_ACC, Color(0, 0, 0, 0), 0, Vector4(12, 10, 12, 10))
	b.add_theme_stylebox_override("hover", hover)
	var pressed := _notch_stylebox(
		Vector2i(96, 48), COL_ACC.darkened(0.15), Color(0, 0, 0, 0), 0,
		Vector4(12, 14, 12, 6))
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(handler)
	return b

func _build_menu_rig() -> void:
	# Лист живёт прямо в мире как ребёнок камеры: мир за ним уходит
	# в параллакс, когда камера плывёт за курсором.
	_rig = Node3D.new()
	_rig.visible = false
	_camera.add_child(_rig)

	_pivot = Node3D.new()
	_pivot.position = Vector3(PIVOT_X, 0.02, PANEL_Z)
	_rig.add_child(_pivot)

	# Подложка-плита в цвете границ сайта: рамка вокруг карточки меню.
	var slab := MeshInstance3D.new()
	var slab_mesh := BoxMesh.new()
	slab_mesh.size = Vector3(PANEL_W + 0.06, PANEL_H + 0.06, 0.05)
	slab.mesh = slab_mesh
	var slab_mat := StandardMaterial3D.new()
	slab_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	slab_mat.albedo_color = COL_LINE
	slab.material_override = slab_mat
	slab.position = Vector3(-PANEL_W * 0.5 - 0.03, 0.0, 0.0)
	_pivot.add_child(slab)

	_quad = MeshInstance3D.new()
	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2(PANEL_W, PANEL_H)
	_quad.mesh = quad_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	# Текстуру берём напрямую у вьюпорта: ViewportTexture, собранный
	# вручную по пути узла, надёжно не подключается (даёт magenta-заглушку).
	mat.albedo_texture = _sub_vp.get_texture()
	_quad.material_override = mat
	_quad.position = Vector3(-PANEL_W * 0.5, 0.0, 0.028)
	_pivot.add_child(_quad)

	_build_uv_map(quad_mesh)

func _build_uv_map(mesh: QuadMesh) -> void:
	var arrays: Array = mesh.surface_get_arrays(0)
	if arrays.is_empty():
		return
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var n := verts.size()
	for i in n:
		for j in range(i + 1, n):
			for k in range(j + 1, n):
				var x0 := verts[i].x
				var y0 := verts[i].y
				var d := (verts[j].x - x0) * (verts[k].y - y0) \
					- (verts[k].x - x0) * (verts[j].y - y0)
				if absf(d) < 0.0001:
					continue
				_uv_a = Vector2(
					((uvs[j].x - uvs[i].x) * (verts[k].y - y0) - (uvs[k].x - uvs[i].x) * (verts[j].y - y0)) / d,
					((uvs[j].y - uvs[i].y) * (verts[k].y - y0) - (uvs[k].y - uvs[i].y) * (verts[j].y - y0)) / d)
				_uv_b = Vector2(
					((uvs[k].x - uvs[i].x) * (verts[j].x - x0) - (uvs[j].x - uvs[i].x) * (verts[k].x - x0)) / d,
					((uvs[k].y - uvs[i].y) * (verts[j].x - x0) - (uvs[j].y - uvs[i].y) * (verts[k].x - x0)) / d)
				_uv_c = Vector2(
					uvs[i].x - _uv_a.x * x0 - _uv_b.x * y0,
					uvs[i].y - _uv_a.y * x0 - _uv_b.y * y0)
				return

func _input(event: InputEvent) -> void:
	if _camera == null:
		return
	if not _paused:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_open()
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_resume()
		return
	if event is InputEventScreenTouch:
		# Тач-нажатие -> клик мышью внутри меню (эмуляция мыши из тача
		# выключена ради джойстика, поэтому конвертируем вручную).
		var t := event as InputEventScreenTouch
		if t.index != _menu_touch_index and _menu_touch_index != -1:
			return  # этот палец не мы — например, джойстик
		var btn := InputEventMouseButton.new()
		btn.button_index = MOUSE_BUTTON_LEFT
		btn.pressed = t.pressed
		btn.position = t.position
		btn.global_position = t.position
		if t.pressed and _menu_pos(t.position).x >= 0.0:
			_menu_touch_index = t.index
		elif not t.pressed:
			_menu_touch_index = -1
		_forward_to_menu(btn)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if _menu_touch_index != -1 and d.index != _menu_touch_index:
			return
		var motion := InputEventMouseMotion.new()
		motion.position = d.position
		motion.global_position = d.position
		motion.relative = d.relative
		_forward_to_menu(motion)
	elif event is InputEventMouseMotion or event is InputEventMouseButton:
		_forward_to_menu(event)

func _forward_to_menu(event: InputEvent) -> void:
	var mouse_ev := event as InputEventMouse
	if mouse_ev == null:
		return
	var pos := _menu_pos(mouse_ev.position)
	var ev := mouse_ev.duplicate() as InputEventMouse
	ev.position = pos
	ev.global_position = pos
	_sub_vp.push_input(ev)

func _menu_pos(mouse: Vector2) -> Vector2:
	var origin := _camera.project_ray_origin(mouse)
	var dir := _camera.project_ray_normal(mouse)
	var xf := _quad.global_transform
	var plane := Plane(xf.basis.z, xf.origin)
	var hit = plane.intersects_ray(origin, dir)
	if hit == null:
		return Vector2(-10000.0, -10000.0)
	var local: Vector3 = xf.affine_inverse() * (hit as Vector3)
	var uv := Vector2(
		_uv_a.x * local.x + _uv_b.x * local.y + _uv_c.x,
		_uv_a.y * local.x + _uv_b.y * local.y + _uv_c.y)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return Vector2(-10000.0, -10000.0)
	return Vector2(uv.x * _sub_vp.size.x, uv.y * _sub_vp.size.y)

func _open() -> void:
	if _paused or _player.frozen:
		return
	_paused = true
	_settled = false
	Engine.time_scale = 1.0
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_sub_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_base_fov = _camera.fov
	_base_cam_yaw = _camera.rotation.y
	_base_cam_pitch = _camera.rotation.x
	_pause_btn.visible = false
	if _game_ui != null:
		_game_ui.visible = false

	var fov_tw := create_tween()
	fov_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fov_tw.tween_property(_camera, "fov", ZOOM_FOV, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Лист распахивается из-за правого края, как дверь на пружине.
	_rig.visible = true
	_pivot.rotation = Vector3(0.0, SWING_FROM, 0.09)
	_pivot.position = Vector3(PIVOT_X, 0.02, PANEL_Z)
	var swing := create_tween()
	swing.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	swing.set_parallel(true)
	swing.tween_property(_pivot, "rotation:y", SWING_TO, 0.65) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	swing.tween_property(_pivot, "rotation:z", 0.0, 0.65) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	swing.chain().tween_callback(func() -> void:
		_settled = true
		_debug_dump())

func _resume() -> void:
	if not _paused:
		return
	_paused = false
	_settled = false
	_menu_touch_index = -1
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_pause_btn.visible = true
	if _game_ui != null:
		_game_ui.visible = true

	var fov_tw := create_tween()
	fov_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fov_tw.tween_property(_camera, "fov", _base_fov, 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var yaw_tw := create_tween()
	yaw_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	yaw_tw.tween_property(_camera, "rotation:y", _base_cam_yaw, 0.3)

	var swing := create_tween()
	swing.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	swing.tween_property(_pivot, "rotation:y", SWING_FROM, 0.45) \
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	swing.tween_callback(func() -> void:
		_rig.visible = false
		_sub_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED)

func _restart() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()

func _quit() -> void:
	get_tree().paused = false
	get_tree().quit()

func _process(delta: float) -> void:
	if not _paused or _camera == null:
		return
	var vp_size := get_viewport().get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return
	var mouse := get_viewport().get_mouse_position()
	var nx := clampf(mouse.x / vp_size.x, 0.0, 1.0) - 0.5
	var ny := clampf(mouse.y / vp_size.y, 0.0, 1.0) - 0.5
	var k := minf(6.0 * delta, 1.0)

	# Камера плывёт за курсором — мир за листом уходит в параллакс.
	_camera.rotation.y = lerpf(_camera.rotation.y, _base_cam_yaw - nx * 2.0 * DRIFT_YAW, k)
	_camera.rotation.x = lerpf(_camera.rotation.x, _base_cam_pitch - ny * 2.0 * DRIFT_PITCH, k)

	if _settled:
		# Лист чуть противоходит курсору и тихо парит.
		_pivot.rotation.y = lerpf(_pivot.rotation.y, SWING_TO + nx * 0.12, k)
		_pivot.position.y = 0.02 + sin(Time.get_ticks_msec() / 1000.0 * 1.3) * 0.012

func _debug_dump() -> void:
	# Диагностика только в отладочных сборках: картинка сабвьюпорта
	# и прямоугольники всех контролов — в консоль редактора.
	if not OS.is_debug_build() or DisplayServer.get_name() == "headless":
		return  # headless: рендерера нет, дампить нечего
	var tex := _sub_vp.get_texture()
	if tex == null or tex.get_image() == null:
		return
	var img := tex.get_image()
	img.save_png("user://pause_debug.png")
	print("PauseMenu: sub-viewport ", _sub_vp.size,
		" -> user://pause_debug.png")
	var stack: Array = [_sub_vp]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Control:
			var c: Control = n
			print("  ", c.name, " [", c.get_class(), "] rect=", c.get_global_rect(),
				" visible=", c.is_visible_in_tree())
		for ch in n.get_children():
			stack.push_back(ch)
