extends Control
## 野球拳 (Yakyuken) - 棒球主題猜拳
## 先贏 ROUNDS_TO_WIN 局者勝

enum Hand { ROCK, SCISSORS, PAPER }

const HAND_NAMES := {
	Hand.ROCK: "石頭",
	Hand.SCISSORS: "剪刀",
	Hand.PAPER: "布",
}

const ROUNDS_TO_WIN: int = 3
const REVEAL_DELAY: float = 0.7

@onready var player_hand_label: Label = $Layout/Hands/PlayerCol/PlayerHand
@onready var cpu_hand_label: Label = $Layout/Hands/CpuCol/CpuHand
@onready var score_label: Label = $Layout/ScoreLabel
@onready var round_label: Label = $Layout/RoundLabel
@onready var result_label: Label = $Layout/ResultLabel
@onready var status_label: Label = $Layout/StatusLabel
@onready var rock_btn: Button = $Layout/Buttons/RockBtn
@onready var scissors_btn: Button = $Layout/Buttons/ScissorsBtn
@onready var paper_btn: Button = $Layout/Buttons/PaperBtn
@onready var restart_btn: Button = $Layout/RestartBtn

var player_score: int = 0
var cpu_score: int = 0
var round_num: int = 1
var is_finished: bool = false
var is_revealing: bool = false

func _ready() -> void:
	randomize()
	rock_btn.pressed.connect(_on_rock)
	scissors_btn.pressed.connect(_on_scissors)
	paper_btn.pressed.connect(_on_paper)
	restart_btn.pressed.connect(_restart)
	restart_btn.visible = false
	result_label.text = ""
	status_label.text = "選擇你的拳！"
	_update_ui()

func _on_rock() -> void: _play(Hand.ROCK)
func _on_scissors() -> void: _play(Hand.SCISSORS)
func _on_paper() -> void: _play(Hand.PAPER)

func _play(player_hand: int) -> void:
	if is_finished or is_revealing:
		return
	is_revealing = true
	_set_buttons_disabled(true)

	player_hand_label.text = "？"
	cpu_hand_label.text = "？"
	result_label.text = ""
	status_label.text = "野・球・けん！"

	await get_tree().create_timer(REVEAL_DELAY).timeout

	var cpu_hand: int = randi() % 3
	player_hand_label.text = HAND_NAMES[player_hand]
	cpu_hand_label.text = HAND_NAMES[cpu_hand]

	var outcome: int = _judge(player_hand, cpu_hand)
	match outcome:
		1:
			player_score += 1
			result_label.text = "WIN  ⚾"
			result_label.modulate = Color(0.4, 1.0, 0.5, 1)
		-1:
			cpu_score += 1
			result_label.text = "LOSE  ✕"
			result_label.modulate = Color(1.0, 0.4, 0.4, 1)
		0:
			result_label.text = "DRAW  ─"
			result_label.modulate = Color(1.0, 0.95, 0.4, 1)

	if outcome != 0:
		round_num += 1

	_update_ui()

	if player_score >= ROUNDS_TO_WIN or cpu_score >= ROUNDS_TO_WIN:
		_finish()
	else:
		status_label.text = "選擇你的拳！"
		_set_buttons_disabled(false)

	is_revealing = false

func _judge(p: int, c: int) -> int:
	if p == c:
		return 0
	if (p == Hand.ROCK and c == Hand.SCISSORS) \
			or (p == Hand.SCISSORS and c == Hand.PAPER) \
			or (p == Hand.PAPER and c == Hand.ROCK):
		return 1
	return -1

func _update_ui() -> void:
	score_label.text = "%d   :   %d" % [player_score, cpu_score]
	round_label.text = "Round %d   (先贏 %d 局)" % [round_num, ROUNDS_TO_WIN]

func _set_buttons_disabled(d: bool) -> void:
	rock_btn.disabled = d
	scissors_btn.disabled = d
	paper_btn.disabled = d

func _finish() -> void:
	is_finished = true
	_set_buttons_disabled(true)
	restart_btn.visible = true
	if player_score > cpu_score:
		status_label.text = "🏆 全壘打！PLAYER 勝利！"
		status_label.modulate = Color(0.4, 1.0, 0.5, 1)
	else:
		status_label.text = "💀 三振出局… CPU 勝利"
		status_label.modulate = Color(1.0, 0.4, 0.4, 1)

func _restart() -> void:
	get_tree().reload_current_scene()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and is_finished:
		_restart()
