extends Node2D
## 接蘋果遊戲：主場景控制器

@export var apple_scene: PackedScene

@onready var spawn_timer: Timer = $SpawnTimer
@onready var score_label: Label = $UI/ScoreLabel
@onready var lives_label: Label = $UI/LivesLabel
@onready var game_over_label: Label = $UI/GameOverLabel

var score: int = 0
var lives: int = 3
var is_game_over: bool = false

func _ready() -> void:
	randomize()
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	_update_ui()
	game_over_label.visible = false

func _on_spawn_timer_timeout() -> void:
	if is_game_over or apple_scene == null:
		return
	var apple := apple_scene.instantiate()
	var screen_w: float = get_viewport_rect().size.x
	apple.position = Vector2(randf_range(40.0, screen_w - 40.0), -40.0)
	apple.fall_speed = randf_range(200.0, 340.0)
	apple.caught.connect(_on_apple_caught)
	apple.missed.connect(_on_apple_missed)
	add_child(apple)
	# 隨分數加快生成
	spawn_timer.wait_time = max(0.4, 1.2 - float(score) * 0.02)

func _on_apple_caught() -> void:
	score += 1
	_update_ui()

func _on_apple_missed() -> void:
	lives -= 1
	_update_ui()
	if lives <= 0:
		_trigger_game_over()

func _update_ui() -> void:
	score_label.text = "Score: %d" % score
	lives_label.text = "Lives: %d" % lives

func _trigger_game_over() -> void:
	is_game_over = true
	spawn_timer.stop()
	game_over_label.visible = true
	game_over_label.text = "GAME OVER\nFinal Score: %d\n按 SPACE 重新開始" % score
	for apple in get_tree().get_nodes_in_group("apples"):
		apple.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if is_game_over and event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()
