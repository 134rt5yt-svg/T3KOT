extends Node3D

const KILL_DEPTH := -25.0

@onready var player: CharacterBody3D = $Player
@onready var wall_jump: Node = $Player/WallJump
@onready var ending: Node = $Ending
@onready var prompt_label: Label = $UI/Prompt

var prompt_override := ""
var prompt_override_until := -1.0

func _ready() -> void:
	$GoalPlatform/GoalTrigger.body_entered.connect(_on_goal_reached)
	_show_temp_prompt("Доберитесь до самой верхней платформы. Не падайте!", 7.0)
	# ================= ЗАГОТОВКА ДЛЯ ФОНОВОЙ МУЗЫКИ =================
	# 1. Положите файл музыки (track.ogg / track.mp3) в папку res://music/
	# 2. Раскомментируйте строки ниже и впишите имя своего файла:
	#
	# var stream: AudioStream = load("res://music/track.ogg")
	# if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
	#     stream.loop = true
	# $Music.stream = stream
	# $Music.play()
	# ================================================================

func _physics_process(_delta: float) -> void:
	_update_prompt()
	if not ending.started and player.global_position.y < KILL_DEPTH:
		player.respawn()

func _update_prompt() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if prompt_override_until > 0.0 and now < prompt_override_until:
		prompt_label.text = prompt_override
	elif wall_jump.active:
		prompt_label.text = "ПРОБЕЛ — прыжок от стены!"
	else:
		prompt_label.text = ""

func _show_temp_prompt(text: String, duration: float) -> void:
	prompt_override = text
	prompt_override_until = Time.get_ticks_msec() / 1000.0 + duration

func _on_goal_reached(body: Node) -> void:
	if body.is_in_group("player"):
		ending.start()
