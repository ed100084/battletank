extends StaticBody2D
class_name Wall

enum WallType { BRICK, STEEL }

@export var wall_type: WallType = WallType.BRICK

func _ready() -> void:
	add_to_group("walls")

func take_damage() -> void:
	if wall_type == WallType.BRICK:
		_spawn_brick_debris()
		AudioManager.play("hit_brick")
		queue_free()
	else:
		AudioManager.play("hit_steel")
		# STEEL: 不可破，子彈會被吸收 (由 bullet.gd 處理 queue_free)

func _spawn_brick_debris() -> void:
	var p := CPUParticles2D.new()
	p.emitting             = true
	p.amount               = 8
	p.lifetime             = 0.40
	p.one_shot             = true
	p.explosiveness        = 0.80
	p.randomness           = 0.50
	p.direction            = Vector2(0.0, -1.0)
	p.spread               = 85.0
	p.gravity              = Vector2(0.0, 500.0)
	p.initial_velocity_min = 35.0
	p.initial_velocity_max = 95.0
	p.scale_amount_min     = 2.0
	p.scale_amount_max     = 4.0
	p.color                = Color(0.70, 0.40, 0.20)
	get_parent().add_child(p)
	p.global_position = global_position
	get_tree().create_timer(0.65).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free()
	)
