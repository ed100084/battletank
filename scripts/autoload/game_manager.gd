extends Node
## Global singleton (autoload) for game-wide state.
## Access from anywhere via: GameManager.<member>
## 注意：暫停由 main.gd 管理 (含 RPC 同步)，此處只放共享狀態。

const SCORE_TABLE := {
	"basic": 100,
	"fast":  200,
	"heavy": 300,
	"boss":  500,
	"mega":  1000,
}

var is_paused: bool = false
var score: int = 0
var high_score: int = 0
var kill_counts: Dictionary = {"basic": 0, "fast": 0, "heavy": 0, "boss": 0, "mega": 0}

func _ready() -> void:
	print("[GameManager] ready, version: %s" % ProjectSettings.get_setting("application/config/version"))

func add_kill(tank_type: String) -> void:
	var pts: int = SCORE_TABLE.get(tank_type, 100)
	score += pts
	if tank_type in kill_counts:
		kill_counts[tank_type] += 1
	if score > high_score:
		high_score = score

func reset_session() -> void:
	score = 0
	kill_counts = {"basic": 0, "fast": 0, "heavy": 0, "boss": 0, "mega": 0}
