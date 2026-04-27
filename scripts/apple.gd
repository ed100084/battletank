extends Area2D
## 掉落的蘋果

signal caught
signal missed

var fall_speed: float = 250.0

func _ready() -> void:
	add_to_group("apples")
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	position.y += fall_speed * delta
	if position.y > get_viewport_rect().size.y + 40.0:
		missed.emit()
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("basket"):
		caught.emit()
		queue_free()
