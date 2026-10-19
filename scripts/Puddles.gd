extends Node
## Лужи на платформах: тёмные пятна с отблеском неба. Один общий
## материал, и молния вспышкой заставляет все лужи блеснуть.

const CHANCE := 0.5

var _mat: StandardMaterial3D

func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mat.albedo_texture = _make_puddle_texture()
	_mat.emission_enabled = true
	_mat.emission = Color(0.55, 0.6, 0.68)
	_mat.emission_energy_multiplier = 0.18

	var rng := RandomNumberGenerator.new()
	rng.seed = 20261019
	for child in get_parent().get_children():
		var deck_top := 0.25
		if child.name == "StartPlatform":
			deck_top = 0.5
		elif not child.name.begins_with("Platform"):
			continue
		if rng.randf() > CHANCE:
			continue
		var size := rng.randf_range(0.8, 1.5)
		var quad := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(size, size * rng.randf_range(0.6, 0.9))
		mesh.material = _mat
		quad.mesh = mesh
		quad.position = Vector3(
			rng.randf_range(-1.0, 1.0), deck_top + 0.012, rng.randf_range(-1.0, 1.0))
		quad.rotation = Vector3(-PI / 2 + rng.randf_range(-0.04, 0.04), 0.0,
			rng.randf_range(0.0, TAU))
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		child.add_child(quad)

func get_material() -> StandardMaterial3D:
	return _mat

func _make_puddle_texture() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 64:
		for x in 64:
			var d := Vector2(x - 32, y - 32) / Vector2(26.0, 16.0)
			var dist := d.length()
			if dist < 1.0:
				# тёмная вода с чуть более светлым краем
				var t := clampf((dist - 0.75) / 0.25, 0.0, 1.0)
				var edge := t * t * (3.0 - 2.0 * t)
				var a := 0.62 - edge * 0.2
				# диагональный отблеск неба
				var glint := clampf(1.0 - abs((x + y) - 74) / 10.0, 0.0, 1.0)
				glint = glint * 0.22 if dist < 0.85 else 0.0
				var c := Color(0.16 + glint, 0.19 + glint, 0.24 + glint * 1.2, a)
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
