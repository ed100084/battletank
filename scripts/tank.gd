extends CharacterBody2D
class_name Tank

const EXPLOSION_SCENE := preload("res://scenes/Explosion.tscn")

@export var bullet_scene: PackedScene
@export var is_player: bool = false
@export var move_speed: float = 100.0
@export var body_color: Color = Color(0.95, 0.85, 0.30)
@export var max_hp: int = 1
@export var is_boss: bool = false
@export var tank_type: String = "basic"

## death_position, tank_type
signal died(death_position: Vector2, death_type: String)

var hp: int = 1
var direction: int = GameConst.Dir.UP
var active_bullets: int = 0
var max_bullets: int = 1
var ai_decide_timer: float = 0.0
var invincible: bool = false
var _blink_timer: float = 0.0
var is_frozen: bool = false
var is_shielded: bool = false

var _shield_timer: float = 0.0
var _shield_blink: float = 0.0
var _shield_visual: Polygon2D = null

@onready var body_visual: Polygon2D   = $Body
@onready var turret_visual: Polygon2D = $Turret
@onready var cannon_visual: Polygon2D = $Cannon

func _ready() -> void:
	hp = max_hp
	body_visual.color   = body_color
	turret_visual.color = body_color.darkened(0.30)
	cannon_visual.color = body_color.darkened(0.55)
	if is_boss:
		scale = Vector2(1.25, 1.25)
	set_process(false)
	if is_player:
		add_to_group("player")
	else:
		add_to_group("enemy")
		direction = GameConst.Dir.DOWN
		ai_decide_timer = randf_range(0.5, 1.5)
	_update_facing()

func _is_local_authority() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true
	return is_multiplayer_authority()

func _physics_process(delta: float) -> void:
	if not _is_local_authority():
		return
	if is_frozen:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_player:
		_player_input()
	else:
		_ai_logic(delta)
	move_and_slide()

	if is_shielded:
		_shield_timer -= delta
		_shield_blink += delta
		if _shield_visual:
			_shield_visual.visible = fmod(_shield_blink, 0.4) < 0.2
		if _shield_timer <= 0.0:
			is_shielded = false
			if _shield_visual:
				_shield_visual.queue_free()
				_shield_visual = null

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
	var half: float = ts / 2.0
	if direction == GameConst.Dir.UP or direction == GameConst.Dir.DOWN:
		position.x = round((position.x - half) / ts) * ts + half
	else:
		position.y = round((position.y - half) / ts) * ts + half

func _update_facing() -> void:
	rotation = GameConst.DIR_ANGLE[direction]

func _shoot() -> void:
	var max_b: int = 3 if is_boss else max_bullets
	if active_bullets >= max_b or bullet_scene == null:
		return
	var dir_vec: Vector2 = GameConst.DIR_VEC[direction]
	if is_boss:
		# Boss 三向散彈：主向 + 兩側 ±15°
		_spawn_bullet(dir_vec)
		_spawn_bullet(dir_vec.rotated(deg_to_rad(15)))
		_spawn_bullet(dir_vec.rotated(deg_to_rad(-15)))
	else:
		_spawn_bullet(dir_vec)

func _spawn_bullet(dir_vec: Vector2) -> void:
	var b: Node2D = bullet_scene.instantiate()
	b.position = position + dir_vec * 22.0
	b.set("direction_vec", dir_vec)
	b.set("shooter", self)
	b.set("from_player", is_player)
	get_parent().add_child(b)
	active_bullets += 1
	b.tree_exited.connect(_on_bullet_freed)
	AudioManager.play("shoot")

func _on_bullet_freed() -> void:
	active_bullets = max(0, active_bullets - 1)

func take_damage() -> void:
	if not _is_local_authority():
		return
	if invincible or is_shielded:
		return
	hp -= 1
	if hp > 0:
		_flash_damage()
		return
	var expl := EXPLOSION_SCENE.instantiate()
	get_parent().add_child(expl)
	expl.global_position = global_position
	var sfx := "explosion_player" if is_player else "explosion_enemy"
	AudioManager.play(sfx)
	died.emit(global_position, tank_type)
	queue_free()

func _flash_damage() -> void:
	body_visual.color   = Color.WHITE
	turret_visual.color = Color.WHITE
	cannon_visual.color = Color.WHITE
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		body_visual.color   = body_color
		turret_visual.color = body_color.darkened(0.30)
		cannon_visual.color = body_color.darkened(0.55)

func grant_invincibility(seconds: float) -> void:
	invincible = true
	_blink_timer = seconds
	set_process(true)

func _process(delta: float) -> void:
	if _blink_timer > 0.0:
		_blink_timer -= delta
		modulate.a = 0.4 if int(_blink_timer * 10.0) % 2 == 0 else 1.0
		if _blink_timer <= 0.0:
			invincible = false
			modulate.a = 1.0
			set_process(false)

func apply_shield(duration: float) -> void:
	is_shielded   = true
	_shield_timer = duration
	_shield_blink = 0.0
	if _shield_visual == null:
		_shield_visual = Polygon2D.new()
		var pts := PackedVector2Array()
		for i in range(16):
			var a := i * TAU / 16.0
			pts.append(Vector2(cos(a) * 20.0, sin(a) * 20.0))
		_shield_visual.polygon = pts
		_shield_visual.color   = Color(0.30, 0.65, 1.0, 0.50)
		add_child(_shield_visual)

func freeze() -> void:
	is_frozen = true

func unfreeze() -> void:
	is_frozen = false
