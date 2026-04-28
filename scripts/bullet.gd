extends Area2D
## 子彈：偵測坦克 / 牆 / 老鷹

var direction_vec: Vector2 = Vector2.UP
var speed: float = GameConst.BULLET_SPEED
var shooter: Node = null
var from_player: bool = true

func _ready() -> void:
	add_to_group("bullets")
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += direction_vec * speed * delta
	if position.x < -8.0 or position.x > GameConst.MAP_PX_W + 8.0 \
			or position.y < -8.0 or position.y > GameConst.MAP_PX_H + 8.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body == shooter:
		return
	if body.is_in_group("player") and from_player:
		return
	if body.is_in_group("enemy") and not from_player:
		return
	_spawn_hit_spark()
	if body.has_method("take_damage"):
		body.take_damage()
	queue_free()

func _spawn_hit_spark() -> void:
	var p := CPUParticles2D.new()
	p.emitting             = true
	p.amount               = 6
	p.lifetime             = 0.25
	p.one_shot             = true
	p.explosiveness        = 0.90
	p.randomness           = 0.30
	p.direction            = -direction_vec
	p.spread               = 65.0
	p.gravity              = Vector2(0.0, 280.0)
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 80.0
	p.scale_amount_min     = 2.0
	p.scale_amount_max     = 3.0
	p.color                = Color(1.0, 0.85, 0.30)
	get_parent().add_child(p)
	p.global_position = global_position
	get_tree().create_timer(0.45).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free()
	)
