extends Node
## Молнии при дожде: вспышка на весь экран, сцена и туман на миг
## светлеют, лужи блестят, затем — запаздывающий раскат грома.

const FIRST_MIN := 8.0
const FIRST_MAX := 20.0
const NEXT_MIN := 18.0
const NEXT_MAX := 50.0

var _player: CharacterBody3D
var _env: Environment
var _sun: DirectionalLight3D
var _puddles_mat: StandardMaterial3D
var _flash: ColorRect
var _thunder: AudioStreamPlayer
var _timer := 12.0

func _init(player: CharacterBody3D) -> void:
	_player = player

func _ready() -> void:
	_env = (get_parent().get_node("WorldEnvironment") as WorldEnvironment).environment
	_sun = get_parent().get_node("Sun") as DirectionalLight3D
	for sibling in get_parent().get_children():
		var s: Script = sibling.get_script()
		if s != null and String(s.resource_path).ends_with("Puddles.gd"):
			_puddles_mat = sibling.call("get_material")
	_timer = randf_range(FIRST_MIN, FIRST_MAX)

	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	_flash = ColorRect.new()
	_flash.color = Color(0.92, 0.94, 1.0, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash)

	_thunder = AudioStreamPlayer.new()
	if ResourceLoader.exists("res://sounds/thunder.wav"):
		_thunder.stream = load("res://sounds/thunder.wav")
	add_child(_thunder)

func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(NEXT_MIN, NEXT_MAX)
		_strike()

func _strike() -> void:
	# Вспышка: два пика, как у настоящей молнии.
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.85, 0.04)
	tw.tween_property(_flash, "color:a", 0.2, 0.1)
	tw.tween_property(_flash, "color:a", 0.65, 0.05)
	tw.tween_property(_flash, "color:a", 0.0, 0.45)

	# Сцена светлеет и туман на мгновение редеет.
	var amb := _env.ambient_light_energy
	var dens := _env.fog_density
	var sun := _sun.light_energy
	var ev := create_tween()
	ev.set_parallel(true)
	ev.tween_property(_env, "ambient_light_energy", amb + 1.9, 0.05)
	ev.tween_property(_env, "fog_density", dens * 0.4, 0.08)
	ev.tween_property(_sun, "light_energy", 3.2, 0.05)
	if _puddles_mat != null:
		ev.tween_property(_puddles_mat, "emission_energy_multiplier", 2.6, 0.05)
	ev.chain().set_parallel(true)
	ev.tween_property(_env, "ambient_light_energy", amb, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ev.tween_property(_env, "fog_density", dens, 1.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ev.tween_property(_sun, "light_energy", sun, 0.6)
	if _puddles_mat != null:
		ev.tween_property(_puddles_mat, "emission_energy_multiplier", 0.18, 1.0)

	# Гром доходит с задержкой — чем выше игрок, тем «ближе» удар.
	var height := clampf(_player.global_position.y / 42.0, 0.0, 1.0)
	_play_thunder.call_deferred(randf_range(0.35, 1.5) * (1.2 - height))

func _play_thunder(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if _thunder.stream != null:
		_thunder.pitch_scale = randf_range(0.85, 1.15)
		_thunder.volume_db = lerpf(-16.0, -5.0,
			clampf(1.1 - delay / 1.6, 0.0, 1.0))
		_thunder.play()
