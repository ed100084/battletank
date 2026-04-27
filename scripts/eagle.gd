extends StaticBody2D
class_name Eagle

signal destroyed

func _ready() -> void:
	add_to_group("eagle")

func take_damage() -> void:
	destroyed.emit()
	queue_free()
