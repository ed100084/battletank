extends Area2D
## 子彈：偵測坦克 / 牆 / 老鷹

var direction_vec: Vector2 = Vector2.UP
var speed: float = GameConst.BULLET_SPEED
var shooter: Node = null
var from_player: bool = true

func _is_local_authority() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true
	return is_multiplayer_authority()

func _ready() -> void:
	add_to_group("bullets")
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	# 移動由 authority 端做，再由 MultiplayerSynchronizer 同步 position 給 client
	if not _is_local_authority():
		return
	position += direction_vec * speed * delta
	if position.x < -8.0 or position.x > GameConst.MAP_PX_W + 8.0 \
			or position.y < -8.0 or position.y > GameConst.MAP_PX_H + 8.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	# 命中判定也只在 authority 端
	if not _is_local_authority():
		return
	if body == shooter:
		return
	# 友軍子彈不傷友軍 (player 子彈不傷 player；enemy 子彈不傷 enemy)
	if body.is_in_group("player") and from_player:
		return
	if body.is_in_group("enemy") and not from_player:
		return
	if body.has_method("take_damage"):
		body.take_damage()
	queue_free()
