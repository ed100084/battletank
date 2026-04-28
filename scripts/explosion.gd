extends Node2D
## 爆炸特效：在 _ready() 生成粒子，自動銷毀

func _ready() -> void:
	_add_particles(18, 0.8, 4.0, 8.0, 55.0, 145.0, Color(1.0, 0.48, 0.10))
	_add_particles(12, 0.5, 2.0, 3.5, 85.0, 210.0, Color(1.0, 0.90, 0.35))
	get_tree().create_timer(1.4).timeout.connect(queue_free)

func _add_particles(
		count: int, life: float,
		scale_min: float, scale_max: float,
		vel_min: float, vel_max: float,
		color: Color) -> void:
	var p := CPUParticles2D.new()
	p.emitting            = true
	p.amount              = count
	p.lifetime            = life
	p.one_shot            = true
	p.explosiveness       = 0.80
	p.randomness          = 0.50
	p.direction           = Vector2(0.0, 0.0)
	p.spread              = 180.0
	p.gravity             = Vector2(0.0, 220.0)
	p.initial_velocity_min = vel_min
	p.initial_velocity_max = vel_max
	p.scale_amount_min    = scale_min
	p.scale_amount_max    = scale_max
	p.color               = color
	add_child(p)
