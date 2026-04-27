extends StaticBody2D
class_name Wall

enum WallType { BRICK, STEEL }

@export var wall_type: WallType = WallType.BRICK

func _ready() -> void:
	add_to_group("walls")

func take_damage() -> void:
	if wall_type == WallType.BRICK:
		queue_free()
	# STEEL: 不可破，子彈會被吸收 (由 bullet.gd 處理 queue_free)
