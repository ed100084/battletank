extends CharacterBody2D
class_name Tank

@export var bullet_scene: PackedScene
@export var is_player: bool = false
@export var move_speed: float = 100.0
@export var body_color: Color = Color(0.95, 0.85, 0.30)
@export var max_hp: int = 1
@export var is_boss: bool = false

signal died

var hp: int = 1
var direction: int = GameConst.Dir.UP
var has_active_bullet: bool = false
var ai_decide_timer: float = 0.0
var invincible: bool = false
var _blink_timer: float = 0.0
var active_bullets: int = 0  # boss 可同時 3 發

@onready var body_visual: Polygon2D = $Body
@onready var turret_visual: Polygon2D = $Turret
@onready var cannon_visual: Polygon2D = $Cannon

func _ready() -> void:
	hp = max_hp
	body_visual.color = body_color
	turret_visual.color = body_color.darkened(0.30)
	cannon_visual.color = body_color.darkened(0.55)
	if is_boss:
		scale = Vector2(1.25, 1.25)
	set_process(false)  # _process 只在無敵閃爍時啟用
	if is_player:
		add_to_group("player")
	else:
		add_to_group("enemy")
		direction = GameConst.Dir.DOWN
		ai_decide_timer = randf_range(0.5, 1.5)
	_update_facing()

func _is_local_authority() -> bool:
	# 沒有 multiplayer peer 時 = 單人，視為 authority
	if not multiplayer.has_multiplayer_peer():
		return true
	return is_multiplayer_authority()

func _physics_process(delta: float) -> void:
	if not _is_local_authority():
		# 遠端坦克：位置由 MultiplayerSynchronizer 同步，不跑邏輯
		return
	if is_player:
		_player_input()
	else:
		_ai_logic(delta)
	move_and_slide()

func _player_input() -> void:
	var new_dir: int = -1
	if Input.is_action_pressed("ui_up"):
		new_dir = GameConst.Dir.UP
	elif Input.is_action_pressed("ui_right"):
		new_dir = GameConst.Dir.RIGHT
	elif Input.is_action_pressed("ui_down"):
		new_dir = GameConst.Dir.DOWN
	elif Input.is_action_pressed("ui_left"):
		new_dir = GameConst.Dir.LEFT

	if new_dir != -1:
		if direction != new_dir:
			direction = new_dir
			_update_facing()
			_snap_to_grid_perp()
		velocity = GameConst.DIR_VEC[direction] * move_speed
	else:
		velocity = Vector2.ZERO

	if Input.is_action_just_pressed("shoot"):
		_shoot()

func _ai_logic(delta: float) -> void:
	ai_decide_timer -= delta
	var should_change: bool = false
	if get_slide_collision_count() > 0:
		should_change = true
	if ai_decide_timer <= 0.0:
		should_change = true

	if should_change:
		ai_decide_timer = randf_range(0.8, 2.2)
		direction = randi() % 4
		_update_facing()
		_snap_to_grid_perp()

	velocity = GameConst.DIR_VEC[direction] * move_speed

	if randf() < 0.018:
		_shoot()

func _snap_to_grid_perp() -> void:
	# 對齊到 cell center (ts/2 + n*ts) 而非 grid line (n*ts)
	# 避免坦克瞬移到牆內或邊界外
	var ts: float = float(GameConst.TILE_SIZE)
	var half: float = ts / 2.0
	if direction == GameConst.Dir.UP or direction == GameConst.Dir.DOWN:
		position.x = round((position.x - half) / ts) * ts + half
	else:
		position.y = round((position.y - half) / ts) * ts + half

func _update_facing() -> void:
	rotation = GameConst.DIR_ANGLE[direction]

func _shoot() -> void:
	var max_bullets: int = 3 if is_boss else 1
	if active_bullets >= max_bullets or bullet_scene == null:
		return
	var dir_vec: Vector2 = GameConst.DIR_VEC[direction]
	if is_boss:
		# Boss 三向散彈：主向 + 兩側 ±15°
		_spawn_bullet(dir_vec)
		_spawn_bullet(dir_vec.rotated(deg_to_rad(15)))
		_spawn_bullet(dir_vec.rotated(deg_to_rad(-15)))
	else:
		_spawn_bullet(dir_vec)
	has_active_bullet = active_bullets > 0  # 兼容舊欄位

func _spawn_bullet(dir_vec: Vector2) -> void:
	var b: Node2D = bullet_scene.instantiate()
	b.position = position + dir_vec * 22.0
	b.set("direction_vec", dir_vec)
	b.set("shooter", self)
	b.set("from_player", is_player)
	get_parent().add_child(b)
	active_bullets += 1
	b.tree_exited.connect(_on_bullet_freed)

func _on_bullet_freed() -> void:
	active_bullets = max(0, active_bullets - 1)
	has_active_bullet = active_bullets > 0

func take_damage() -> void:
	# 命中判定只在 authority 端做，避免雙方各扣一次
	if not _is_local_authority():
		return
	if invincible:
		return
	hp -= 1
	if hp > 0:
		# 受傷閃白 0.12 秒提示
		modulate = Color(2.0, 2.0, 2.0)
		await get_tree().create_timer(0.12).timeout
		modulate = Color.WHITE
		return
	died.emit()
	queue_free()

func grant_invincibility(seconds: float) -> void:
	invincible = true
	_blink_timer = seconds
	set_process(true)

func _process(delta: float) -> void:
	if _blink_timer > 0.0:
		_blink_timer -= delta
		# 每 0.1 秒切換 modulate 做閃爍
		modulate.a = 0.4 if int(_blink_timer * 10.0) % 2 == 0 else 1.0
		if _blink_timer <= 0.0:
			invincible = false
			modulate.a = 1.0
			set_process(false)
