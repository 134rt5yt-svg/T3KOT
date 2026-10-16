extends Node

@export var player_path: NodePath = ^"../Player"
@export var subtitle_label_path: NodePath = ^"../UI/Subtitles"
@export var end_label_path: NodePath = ^"../UI/EndLabel"
@export var flash_rect_path: NodePath = ^"../UI/Flash"

@export var flash_time := 10.0

var started := false

@onready var _player: CharacterBody3D = get_node(player_path)
@onready var _subtitle: Label = get_node(subtitle_label_path)
@onready var _end: Label = get_node(end_label_path)
@onready var _flash: ColorRect = get_node(flash_rect_path)

func start() -> void:
	if started:
		return
	started = true
	_player.frozen = true
	Engine.time_scale = 1.0

	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.92, flash_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await get_tree().create_timer(1.5).timeout
	var lines := [
		["Сиди чиль чилируй тут", 3.2],
		["Ты прошёл это чтото нечто", 3.2],
		["ЧИИИИИЛЛ", 3.0],
		["Спасибо за игру", 3.0],
	]
	for line in lines:
		_subtitle.text = line[0]
		await get_tree().create_timer(line[1]).timeout
	_subtitle.text = ""
	_end.text = "ох биля"
	_end.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
