extends Area2D
## 玩家籃子：左右移動，接住蘋果

@export var speed: float = 650.0
@export var half_width: float = 60.0

func _process(delta: float) -> void:
	var direction: float = 0.0
	if Input.is_action_pressed("ui_right"):
		direction += 1.0
	if Input.is_action_pressed("ui_left"):
		direction -= 1.0
	position.x += direction * speed * delta
	var screen_w: float = get_viewport_rect().size.x
	position.x = clampf(position.x, half_width, screen_w - half_width)
