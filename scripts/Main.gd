extends Node3D

const KILL_DEPTH := -25.0

@onready var player: CharacterBody3D = $Player
@onready var wall_jump: Node = $Player/WallJump
@onready var ending: Node = $Ending
@onready var prompt_label: Label = $UI/Prompt
@onready var hint_label: Label = $UI/Hint

var prompt_override := ""
var prompt_override_until := -1.0
var _hint_hidden := false

const PauseMenu := preload("res://scripts/PauseMenu.gd")
const PS1FX := preload("res://scripts/PS1.gd")
const RainFX := preload("res://scripts/Rain.gd")
const RainScreenFX := preload("res://scripts/RainScreen.gd")
const PuddlesFX := preload("res://scripts/Puddles.gd")
const LightningFX := preload("res://scripts/Lightning.gd")
const WindFX := preload("res://scripts/Wind.gd")
const BirdsFX := preload("res://scripts/Birds.gd")

func _ready() -> void:
	$GoalPlatform/GoalTrigger.body_entered.connect(_on_goal_reached)
	_show_temp_prompt("Доберитесь до самой верхней платформы. Не падайте!", 7.0)
	_apply_ps1_font()
	add_child(PauseMenu.new($Player))
	add_child(PS1FX.new())
	add_child(RainScreenFX.new())
	var rain := RainFX.new($Player)
	add_child(rain)
	add_child(PuddlesFX.new())
	add_child(LightningFX.new($Player))
	add_child(WindFX.new($Player, rain))
	add_child(BirdsFX.new($Player))

## Весь игровой текст — пиксельный шрифт без сглаживания.
func _apply_ps1_font() -> void:
	if not ResourceLoader.exists("res://resources/fonts/PixelifySans.ttf"):
		return
	var font: FontFile = load("res://resources/fonts/PixelifySans.ttf")
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.hinting = TextServer.HINTING_NONE
	font.generate_mipmaps = false
	var theme := Theme.new()
	theme.default_font = font
	for child in $UI.get_children():
		if child is Control:
			(child as Control).theme = theme
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
	_hide_hint_when_left_start()
	if not ending.started and player.global_position.y < KILL_DEPTH:
		player.respawn()

## Подсказка управления тает, как только игрок ушёл со стартовой платформы.
func _hide_hint_when_left_start() -> void:
	if _hint_hidden or hint_label == null:
		return
	var d := Vector2(player.global_position.x, player.global_position.z).length()
	if d > 4.6:
		_hint_hidden = true
		var tw := create_tween()
		tw.tween_property(hint_label, "modulate:a", 0.0, 1.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void: hint_label.visible = false)

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
