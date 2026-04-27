extends Node
## Global singleton (autoload) for game-wide state.
## Access from anywhere via: GameManager.<member>

signal game_paused(is_paused: bool)

var current_level: String = ""
var is_paused: bool = false

func _ready() -> void:
	print("[GameManager] ready, version: %s" % ProjectSettings.get_setting("application/config/version"))

func toggle_pause() -> void:
	is_paused = not is_paused
	get_tree().paused = is_paused
	emit_signal("game_paused", is_paused)
