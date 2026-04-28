extends Node
## Global singleton (autoload) for game-wide state.
## Access from anywhere via: GameManager.<member>

signal game_paused(is_paused: bool)
signal score_changed(new_score: int)

const SCORE_TABLE := {
	"basic": 100,
	"fast":  200,
	"heavy": 300,
	"boss":  500,
}

var current_level: String = ""
var is_paused: bool = false
var score: int = 0
var high_score: int = 0
var kill_counts: Dictionary = {"basic": 0, "fast": 0, "heavy": 0, "boss": 0}

func _ready() -> void:
	print("[GameManager] ready, version: %s" % ProjectSettings.get_setting("application/config/version"))

func toggle_pause() -> void:
	is_paused = not is_paused
	get_tree().paused = is_paused
	emit_signal("game_paused", is_paused)

func add_kill(tank_type: String) -> void:
	var pts: int = SCORE_TABLE.get(tank_type, 100)
	score += pts
	if tank_type in kill_counts:
		kill_counts[tank_type] += 1
	if score > high_score:
		high_score = score
	score_changed.emit(score)

func reset_session() -> void:
	score = 0
	kill_counts = {"basic": 0, "fast": 0, "heavy": 0, "boss": 0}
