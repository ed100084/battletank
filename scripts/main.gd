extends Node2D
## 坦克大決戰 - 主場景

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

@export var tank_scene: PackedScene
@export var bullet_scene: PackedScene
@export var brick_scene: PackedScene
@export var steel_scene: PackedScene
@export var eagle_scene: PackedScene

var enemies_remaining: int = ENEMY_TOTAL
var enemies_spawned: int = 0
var enemies_alive: int = 0
var player_lives: int = 3
var is_game_over: bool = false

@onready var arena: Node2D = $Arena
@onready var spawn_timer: Timer = $SpawnTimer
@onready var info_label: Label = $UI/Panel/Info
@onready var status_label: Label = $UI/Panel/Status

func _ready() -> void:
	randomize()
	status_label.visible = false
	_build_map()
	spawn_timer.timeout.connect(_try_spawn_enemy)
	spawn_timer.start()
	_spawn_player()
	_update_ui()

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
	# 上 / 下 / 左 / 右 邊界 (隱形 StaticBody2D)
	_add_invisible_wall(Vector2(w / 2.0, -16.0),  Vector2(w + 64.0, 32.0))
	_add_invisible_wall(Vector2(w / 2.0, h + 16.0), Vector2(w + 64.0, 32.0))
	_add_invisible_wall(Vector2(-16.0, h / 2.0),  Vector2(32.0, h + 64.0))
	_add_invisible_wall(Vector2(w + 16.0, h / 2.0), Vector2(32.0, h + 64.0))

func _add_invisible_wall(pos: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = pos
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	wall.add_child(cs)
	arena.add_child(wall)

func _spawn_player() -> void:
	var ts: int = GameConst.TILE_SIZE
	var t = tank_scene.instantiate()
	t.position = Vector2(PLAYER_SPAWN.x * ts + ts / 2.0, PLAYER_SPAWN.y * ts + ts / 2.0)
	t.is_player = true
	t.move_speed = GameConst.PLAYER_SPEED
	t.body_color = Color(0.95, 0.85, 0.30)
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
	var ts: int = GameConst.TILE_SIZE
	var spawn: Vector2i = ENEMY_SPAWNS.pick_random()
	var t = tank_scene.instantiate()
	t.position = Vector2(spawn.x * ts + ts / 2.0, spawn.y * ts + ts / 2.0)
	t.is_player = false
	t.move_speed = GameConst.ENEMY_SPEED
	t.body_color = Color(0.75, 0.40, 0.40)
	t.bullet_scene = bullet_scene
	t.died.connect(_on_enemy_died)
	arena.add_child(t)
	enemies_spawned += 1
	enemies_alive += 1
	_update_ui()

func _on_player_died() -> void:
	player_lives -= 1
	_update_ui()
	if player_lives <= 0:
		_game_over(false, "PLAYER 全滅")
		return
	await get_tree().create_timer(1.0).timeout
	if not is_game_over:
		_spawn_player()

func _on_enemy_died() -> void:
	enemies_alive -= 1
	enemies_remaining -= 1
	_update_ui()
	if enemies_remaining <= 0:
		_game_over(true, "")

func _on_eagle_destroyed() -> void:
	_game_over(false, "老鷹基地被摧毀")

func _update_ui() -> void:
	info_label.text = "玩家命數：%d\n剩餘敵軍：%d\n場上敵軍：%d" % [player_lives, enemies_remaining, enemies_alive]

func _game_over(victory: bool, reason: String) -> void:
	if is_game_over:
		return
	is_game_over = true
	spawn_timer.stop()
	status_label.visible = true
	if victory:
		status_label.text = "🏆 VICTORY!\n殲滅全部敵軍\n\n按任意鍵重新開始"
		status_label.modulate = Color(0.4, 1.0, 0.5, 1)
	else:
		status_label.text = "💀 GAME OVER\n%s\n\n按任意鍵重新開始" % reason
		status_label.modulate = Color(1.0, 0.4, 0.4, 1)

func _unhandled_input(event: InputEvent) -> void:
	if is_game_over and event is InputEventKey and event.pressed:
		get_tree().reload_current_scene()
