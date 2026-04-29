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
	# 命中判定只在 authority 端
	if not _is_local_authority():
		return
	if body == shooter:
		return
	if body.is_in_group("player") and from_player:
		return
	if body.is_in_group("enemy") and not from_player:
		return
	var main := _get_main()
	# 命中特效 RPC 廣播 (所有 peer 同時顯示)
	if main:
		main.rpc_spawn_hit_spark.rpc(global_position, direction_vec)
	# 對 wall / eagle 走 RPC (因它們不是 MultiplayerSpawner 管理)；
	# 對 tank 直接 take_damage (Tank 已透過 Spawner+Synchronizer 同步)
	if body.is_in_group("walls"):
		if main:
			var ts: int = GameConst.TILE_SIZE
			var gx: int = int(((body as Node2D).position.x - ts / 2.0) / ts)
			var gy: int = int(((body as Node2D).position.y - ts / 2.0) / ts)
			main.rpc_destroy_wall_at.rpc(gx, gy)
	elif body.is_in_group("eagle"):
		if main:
			main.rpc_destroy_eagle.rpc()
	elif body.has_method("take_damage"):
		body.take_damage()
	queue_free()

func _get_main() -> Node:
	# bullet 加在 Arena 下；Arena.parent = Main
	var p := get_parent()
	if p:
		return p.get_parent()
	return null

