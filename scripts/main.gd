extends Node2D
## 坦克大決戰 - 主場景

const POWERUP_SCENE := preload("res://scenes/Powerup.tscn")

const MAP: Array[String] = [
	".............",
	"..BBB...BBB..",
	"..B.B...B.B..",
	"..B.B.B.B.B..",
	"..BBB.B.BBB..",
	".....SSS.....",
	"......S......",
	".....SSS.....",
	"..BBB.B.BBB..",
	"..B.B.B.B.B..",
	"..B.B...B.B..",
	".....BBB.....",
	".....BEB.....",
]

const ENEMY_TOTAL: int = 5
const ENEMY_MAX_ON_FIELD: int = 3
const ENEMY_SPAWNS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(6, 0), Vector2i(12, 0)]
const PLAYER_SPAWN: Vector2i = Vector2i(4, 12)

## 敵軍種類權重表（重複出現＝機率較高）
const ENEMY_TYPE_POOL: Array[String] = [
	"basic", "basic", "basic",
	"fast",  "fast",
	"heavy",
	"boss",
]

@export var tank_scene:  PackedScene
@export var bullet_scene: PackedScene
@export var brick_scene:  PackedScene
@export var steel_scene:  PackedScene
@export var eagle_scene:  PackedScene

var enemies_remaining: int = ENEMY_TOTAL
var enemies_spawned:   int = 0
var enemies_alive:     int = 0
var player_lives:      int = 3
var is_game_over:      bool = false

@onready var arena:        Node2D = $Arena
@onready var spawn_timer:  Timer  = $SpawnTimer
@onready var info_label:   Label  = $UI/Panel/Info
@onready var status_label: Label  = $UI/Panel/Status

func _ready() -> void:
	GameManager.reset_session()
	randomize()
	status_label.visible = false
	_build_map()
	spawn_timer.timeout.connect(_try_spawn_enemy)
	spawn_timer.start()
	_spawn_player()
	_update_ui()
	AudioManager.play_bgm()

func _build_map() -> void:
	var ts: int = GameConst.TILE_SIZE
	for y in range(MAP.size()):
		var row: String = MAP[y]
		for x in range(row.length()):
			var c: String = row.substr(x, 1)
			var pos := Vector2(x * ts + ts / 2.0, y * ts + ts / 2.0)
			match c:
				"B":
					var w := brick_scene.instantiate()
					w.position = pos
					arena.add_child(w)
				"S":
					var w := steel_scene.instantiate()
					w.position = pos
					arena.add_child(w)
				"E":
					var e := eagle_scene.instantiate()
					e.position = pos
					e.destroyed.connect(_on_eagle_destroyed)
					arena.add_child(e)
	_add_boundary_walls()

func _add_boundary_walls() -> void:
	var w: float = float(GameConst.MAP_PX_W)
	var h: float = float(GameConst.MAP_PX_H)
	_add_invisible_wall(Vector2(w / 2.0, -16.0),    Vector2(w + 64.0, 32.0))
	_add_invisible_wall(Vector2(w / 2.0, h + 16.0), Vector2(w + 64.0, 32.0))
	_add_invisible_wall(Vector2(-16.0, h / 2.0),    Vector2(32.0, h + 64.0))
	_add_invisible_wall(Vector2(w + 16.0, h / 2.0), Vector2(32.0, h + 64.0))

func _add_invisible_wall(pos: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask  = 0
	wall.position = pos
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape  = rect
	wall.add_child(cs)
	arena.add_child(wall)

func _spawn_player() -> void:
	var ts: int = GameConst.TILE_SIZE
	var t := tank_scene.instantiate() as Tank
	t.position    = Vector2(PLAYER_SPAWN.x * ts + ts / 2.0, PLAYER_SPAWN.y * ts + ts / 2.0)
	t.is_player   = true
	t.move_speed  = GameConst.PLAYER_SPEED
	t.body_color  = Color(0.95, 0.85, 0.30)
	t.tank_type   = "player"
	t.bullet_scene = bullet_scene
	t.died.connect(_on_player_died)
	arena.add_child(t)

func _try_spawn_enemy() -> void:
	if is_game_over:
		return
	if enemies_alive >= ENEMY_MAX_ON_FIELD:
		return
	if enemies_spawned >= ENEMY_TOTAL:
		return

	var ts: int    = GameConst.TILE_SIZE
	var spawn: Vector2i = ENEMY_SPAWNS.pick_random()
	var tank_type: String = ENEMY_TYPE_POOL.pick_random()

	var t := tank_scene.instantiate() as Tank
	t.position   = Vector2(spawn.x * ts + ts / 2.0, spawn.y * ts + ts / 2.0)
	t.is_player  = false
	t.tank_type  = tank_type
	t.bullet_scene = bullet_scene

	match tank_type:
		"fast":
			t.move_speed = GameConst.ENEMY_SPEED * 1.8
			t.body_color = Color(0.90, 0.60, 0.25)
			t.hp = 1
		"heavy":
			t.move_speed = GameConst.ENEMY_SPEED * 0.60
			t.body_color = Color(0.45, 0.20, 0.20)
			t.hp = 4
		"boss":
			t.move_speed = GameConst.ENEMY_SPEED
			t.body_color = Color(0.92, 0.92, 0.92)
			t.hp = 2
			AudioManager.play("boss_warning")
		_:  # basic
			t.move_speed = GameConst.ENEMY_SPEED
			t.body_color = Color(0.75, 0.40, 0.40)
			t.hp = 1

	t.died.connect(_on_enemy_died)
	arena.add_child(t)
	enemies_spawned += 1
	enemies_alive   += 1
	_update_ui()

# ── 事件處理 ─────────────────────────────────────────

func _on_player_died() -> void:
	player_lives -= 1
	_update_ui()
	if player_lives <= 0:
		_game_over(false, "PLAYER 全滅")
		return
	await get_tree().create_timer(1.0).timeout
	if not is_game_over:
		_spawn_player()

func _on_enemy_died(pos: Vector2, tank_type: String) -> void:
	enemies_alive     -= 1
	enemies_remaining -= 1
	GameManager.add_kill(tank_type)
	if not is_game_over:
		_maybe_spawn_powerup(pos, tank_type)
	_update_ui()
	if enemies_remaining <= 0 and not is_game_over:
		_game_over(true, "")

func _on_eagle_destroyed() -> void:
	_game_over(false, "老鷹基地被摧毀")

# ── 道具系統 ──────────────────────────────────────────

func _maybe_spawn_powerup(pos: Vector2, tank_type: String) -> void:
	var should_drop := (tank_type == "boss") or (randf() < 0.20)
	if not should_drop:
		return
	var pu := POWERUP_SCENE.instantiate() as Powerup
	if pu == null:
		return
	pu.position     = pos
	pu.powerup_type = randi() % (Powerup.Type.EXTRA_LIFE + 1)
	pu.collected.connect(_on_powerup_collected)
	arena.add_child(pu)

func _on_powerup_collected(pu_type: int) -> void:
	AudioManager.play("powerup")
	var player := _get_player()
	match pu_type:
		Powerup.Type.STAR:
			if player:
				player.max_bullets = 2
		Powerup.Type.SHIELD:
			if player:
				player.apply_shield(10.0)
		Powerup.Type.BOMB:
			_apply_bomb()
		Powerup.Type.CLOCK:
			_apply_clock(5.0)
		Powerup.Type.SHOVEL:
			_apply_shovel(15.0)
		Powerup.Type.EXTRA_LIFE:
			player_lives += 1
			_update_ui()

func _get_player() -> Tank:
	var nodes := get_tree().get_nodes_in_group("player")
	if nodes.is_empty():
		return null
	return nodes[0] as Tank

func _apply_bomb() -> void:
	var enemies := get_tree().get_nodes_in_group("enemy").duplicate()
	for node in enemies:
		if is_instance_valid(node):
			var t := node as Tank
			if t:
				t.hp = 1
				t.take_damage()

func _apply_clock(duration: float) -> void:
	for node in get_tree().get_nodes_in_group("enemy"):
		if node.has_method("freeze"):
			node.freeze()
	await get_tree().create_timer(duration).timeout
	for node in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(node) and node.has_method("unfreeze"):
			node.unfreeze()

func _apply_shovel(duration: float) -> void:
	var eagles := get_tree().get_nodes_in_group("eagle")
	if eagles.is_empty():
		return
	var eagle_pos: Vector2 = (eagles[0] as Node2D).position
	var ts := float(GameConst.TILE_SIZE)
	var offsets := [
		Vector2(-ts, -ts), Vector2(0, -ts), Vector2(ts, -ts),
		Vector2(-ts,  0),                   Vector2(ts,  0),
		Vector2(-ts,  ts), Vector2(0,  ts), Vector2(ts,  ts),
	]
	var temp_steels: Array[Node] = []
	for off in offsets:
		var s := steel_scene.instantiate()
		s.position = eagle_pos + off
		s.add_to_group("shovel_temp")
		arena.add_child(s)
		temp_steels.append(s)
	await get_tree().create_timer(duration).timeout
	for s in temp_steels:
		if is_instance_valid(s):
			s.queue_free()

# ── UI ───────────────────────────────────────────────

func _update_ui() -> void:
	info_label.text = (
		"分數：%d\n最高：%d\n\n玩家命數：%d\n剩餘敵軍：%d\n場上敵軍：%d"
		% [GameManager.score, GameManager.high_score,
		   player_lives, enemies_remaining, enemies_alive]
	)

func _game_over(victory: bool, reason: String) -> void:
	if is_game_over:
		return
	is_game_over = true
	spawn_timer.stop()
	AudioManager.stop_bgm()

	var kc  := GameManager.kill_counts
	var stats := (
		"基本×%d  快速×%d\n重型×%d  Boss×%d"
		% [kc["basic"], kc["fast"], kc["heavy"], kc["boss"]]
	)
	status_label.visible = true
	if victory:
		AudioManager.play("stage_clear")
		status_label.text = (
			"🏆 VICTORY!\n殲滅全部敵軍！\n\n%s\n分數 %d  最高 %d\n\n按任意鍵重新開始"
			% [stats, GameManager.score, GameManager.high_score]
		)
		status_label.modulate = Color(0.4, 1.0, 0.5, 1)
	else:
		AudioManager.play("game_over")
		status_label.text = (
			"💀 GAME OVER\n%s\n\n%s\n分數 %d  最高 %d\n\n按任意鍵重新開始"
			% [reason, stats, GameManager.score, GameManager.high_score]
		)
		status_label.modulate = Color(1.0, 0.4, 0.4, 1)

func _unhandled_input(event: InputEvent) -> void:
	if is_game_over and event is InputEventKey and event.pressed:
		get_tree().reload_current_scene()
