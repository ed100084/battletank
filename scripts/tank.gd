extends CharacterBody2D
class_name Tank

@export var bullet_scene: PackedScene
@export var is_player: bool = false
@export var move_speed: float = 100.0
@export var body_color: Color = Color(0.95, 0.85, 0.30)

signal died

var direction: int = GameConst.Dir.UP
var has_active_bullet: bool = false
var ai_decide_timer: float = 0.0

@onready var body_visual: Polygon2D = $Body
@onready var turret_visual: Polygon2D = $Turret
@onready var cannon_visual: Polygon2D = $Cannon

func _ready() -> void:
	body_visual.color = body_color
	turret_visual.color = body_color.darkened(0.30)
	cannon_visual.color = body_color.darkened(0.55)
	if is_player:
		add_to_group("player")
	else:
		add_to_group("enemy")
		direction = GameConst.Dir.DOWN
		ai_decide_timer = randf_range(0.5, 1.5)
	_update_facing()

func _physics_process(delta: float) -> void:
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
	var ts: float = float(GameConst.TILE_SIZE)
	if direction == GameConst.Dir.UP or direction == GameConst.Dir.DOWN:
		position.x = round(position.x / ts) * ts
	else:
		position.y = round(position.y / ts) * ts

func _update_facing() -> void:
	rotation = GameConst.DIR_ANGLE[direction]

func _shoot() -> void:
	if has_active_bullet or bullet_scene == null:
		return
	var b: Node2D = bullet_scene.instantiate()
	var dir_vec: Vector2 = GameConst.DIR_VEC[direction]
	b.position = position + dir_vec * 22.0
	b.set("direction_vec", dir_vec)
	b.set("shooter", self)
	b.set("from_player", is_player)
	get_parent().add_child(b)
	has_active_bullet = true
	b.tree_exited.connect(_on_bullet_freed)

func _on_bullet_freed() -> void:
	has_active_bullet = false

func take_damage() -> void:
	died.emit()
	queue_free()
