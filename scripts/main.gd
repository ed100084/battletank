extends Node2D
## Entry-point scene script.

func _ready() -> void:
	print("[Main] scene loaded")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause"):
		GameManager.toggle_pause()
