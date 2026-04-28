extends Node2D
## 坦克大決戰 - 主場景
## 關卡資料來自 LevelManager (autoload)，不再硬編

@export var tank_scene: PackedScene
@export var bullet_scene: PackedScene
@export var brick_scene: PackedScene
@export var steel_scene: PackedScene
@export var eagle_scene: PackedScene

# --- 當前關卡狀態 ---
var current_level: LevelData
var enemies_remaining: int = 0
var enemies_spawned: int = 0
var enemies_alive: int = 0
var player_lives: int = 3
var is_game_over: bool = false
var is_stage_clear: bool = false

@onready var arena: Node2D = $Arena
@onready var spawn_timer: Timer = $SpawnTimer
@onready var info_label: Label = $UI/Panel/Info
@onready var status_label: Label = $UI/Panel/Status

func _ready() -> void:
	randomize()
	status_label.visible = false
	current_level = LevelManager.get_current()
	if current_level == null:
		push_error("[Main] no level loaded; falling back to empty.")
		return
	enemies_remaining = current_level.enemy_total
	spawn_timer.wait_time = current_level.spawn_interval
	_build_map()
	spawn_timer.timeout.connect(_try_spawn_enemy)
	# 只有 authority (host / 單人) 跑敵軍 spawn 與玩家生成
	if NetworkManager.is_authoritative():
		spawn_timer.start()
		_spawn_all_players()
	_update_ui()

func _spawn_all_players() -> void:
	# 單人 / host：依連線玩家數量 spawn
	var spawns: Array[Vector2i] = current_level.player_spawns.duplicate()
	if spawns.is_empty():
		spawns = [current_level.player_spawn]
	# host 自己 (id=1) 必先 spawn
	var assigned: int = 0
	if NetworkManager.is_offline():
		# 純單機
		_spawn_player(spawns[0], 0)
		return
	# host 模式：自己 + 已連線 client 各一台
	var ids: Array = [1]
	for pid in NetworkManager.players.keys():
		if pid != 1 and not ids.has(pid):
			ids.append(pid)
	for i in range(ids.size()):
		var sp: Vector2i = spawns[i % spawns.size()]
		_spawn_player(sp, ids[i])
		assigned += 1
		if assigned >= 2:
			break  # MVP 上限 2 人

# ---------- 地圖建立 ----------
func _build_map() -> void:
	var ts: int = GameConst.TILE_SIZE
	var rows: PackedStringArray = current_level.map_layout
	for y in range(rows.size()):
		var row: String = rows[y]
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

# ---------- 玩家 / 敵軍生成 ----------
func _spawn_player(spawn_tile: Vector2i, owner_peer_id: int = 0) -> void:
	var ts: int = GameConst.TILE_SIZE
	var t = tank_scene.instantiate()
	t.position = Vector2(spawn_tile.x * ts + ts / 2.0, spawn_tile.y * ts + ts / 2.0)
	t.is_player = true
	t.move_speed = GameConst.PLAYER_SPEED
	# 第二個玩家用藍色區分
	t.body_color = Color(0.95, 0.85, 0.30) if owner_peer_id <= 1 else Color(0.30, 0.70, 1.00)
	t.bullet_scene = bullet_scene
	t.died.connect(_on_player_died)
	# 命名以利 client 透過 NodePath 找到對應 tank
	t.name = "Player_%d" % owner_peer_id if owner_peer_id > 0 else "Player_solo"
	arena.add_child(t)
	# 設定 multiplayer authority (player 只能控制自己的 tank)
	if NetworkManager.is_authoritative() and owner_peer_id > 0:
		t.set_multiplayer_authority(owner_peer_id)
	t.grant_invincibility(1.5)

func _try_spawn_enemy() -> void:
	if is_game_over or is_stage_clear or current_level == null:
		return
	if enemies_alive >= current_level.enemy_max_on_field:
		return
	if enemies_spawned >= current_level.enemy_total:
		return
	var ts: int = GameConst.TILE_SIZE
	var available: Array[Vector2i] = []
	for sp in current_level.enemy_spawns:
		var p := Vector2(sp.x * ts + ts / 2.0, sp.y * ts + ts / 2.0)
		if not _is_spawn_blocked(p):
			available.append(sp)
	if available.is_empty():
		return
	var spawn: Vector2i = available.pick_random()
	var t = tank_scene.instantiate()
	t.position = Vector2(spawn.x * ts + ts / 2.0, spawn.y * ts + ts / 2.0)
	t.is_player = false
	# 依關卡類型權重抽選
	var enemy_type: StringName = _pick_enemy_type()
	_apply_enemy_type(t, enemy_type)
	t.bullet_scene = bullet_scene
	t.died.connect(_on_enemy_died)
	arena.add_child(t)
	enemies_spawned += 1
	enemies_alive += 1
	_update_ui()

func _pick_enemy_type() -> StringName:
	var weights: Dictionary = current_level.enemy_type_weights
	var total: int = 0
	for k in weights:
		total += int(weights[k])
	if total <= 0:
		return &"basic"
	var r: int = randi() % total
	var acc: int = 0
	for k in weights:
		acc += int(weights[k])
		if r < acc:
			return StringName(k)
	return &"basic"

func _apply_enemy_type(t: Node, type_id: StringName) -> void:
	var base_speed: float = current_level.enemy_speed
	match type_id:
		&"fast":
			t.move_speed = base_speed * 1.5
			t.body_color = Color(0.95, 0.55, 0.20)
			t.set("max_hp", 1)
		&"heavy":
			t.move_speed = base_speed * 0.7
			t.body_color = Color(0.45, 0.45, 0.55)
			t.set("max_hp", 2)
		&"boss":
			t.move_speed = base_speed * 0.85
			t.body_color = Color(0.85, 0.20, 0.85)
			t.set("max_hp", 5)
			t.set("is_boss", true)
		_:
			t.move_speed = base_speed
			t.body_color = Color(0.75, 0.40, 0.40)
			t.set("max_hp", 1)

func _is_spawn_blocked(p: Vector2, radius: float = 16.0) -> bool:
	for group_name in ["player", "enemy"]:
		for n in get_tree().get_nodes_in_group(group_name):
			if n is Node2D and n.global_position.distance_to(p + arena.global_position) < radius * 1.5:
				return true
	return false

# ---------- 事件 ----------
func _on_player_died() -> void:
	player_lives -= 1
	_update_ui()
	if player_lives <= 0:
		_game_over(false, "PLAYER 全滅")
		return
	await get_tree().create_timer(1.0).timeout
	if not is_game_over and not is_stage_clear:
		_spawn_player(current_level.player_spawn)

func _on_enemy_died() -> void:
	enemies_alive -= 1
	enemies_remaining -= 1
	_update_ui()
	if enemies_remaining <= 0:
		_stage_clear()

func _on_eagle_destroyed() -> void:
	_game_over(false, "老鷹基地被摧毀")

# ---------- UI / 狀態切換 ----------
func _update_ui() -> void:
	var stage_name: String = current_level.display_name if current_level else "?"
	info_label.text = "%s\n玩家命數：%d\n剩餘敵軍：%d\n場上敵軍：%d" % [
		stage_name, player_lives, enemies_remaining, enemies_alive
	]

func _stage_clear() -> void:
	if is_stage_clear or is_game_over:
		return
	is_stage_clear = true
	spawn_timer.stop()
	LevelManager.mark_cleared()
	status_label.visible = true
	var has_next: bool = LevelManager.current_index + 1 < LevelManager.levels.size()
	if has_next:
		status_label.text = "🏆 STAGE CLEAR!\n%s\n\n3 秒後進入下一關 (按任意鍵立刻)" % current_level.display_name
		status_label.modulate = Color(0.4, 1.0, 0.5, 1)
		await get_tree().create_timer(3.0).timeout
		if is_stage_clear:  # 玩家未中斷
			_advance_stage()
	else:
		status_label.text = "🎖 ALL CLEAR!\n全關卡攻略完成\n\n按任意鍵回首頁"
		status_label.modulate = Color(1.0, 0.85, 0.3, 1)

func _advance_stage() -> void:
	if not NetworkManager.is_authoritative():
		return  # 只有 host 能切
	if LevelManager.current_index + 1 >= LevelManager.levels.size():
		return
	var next_idx: int = LevelManager.current_index + 1
	if NetworkManager.is_offline():
		LevelManager.start_level(next_idx)
		get_tree().reload_current_scene()
	else:
		NetworkManager.rpc_start_match.rpc(next_idx)

func _game_over(victory: bool, reason: String) -> void:
	if is_game_over:
		return
	is_game_over = true
	spawn_timer.stop()
	status_label.visible = true
	if victory:
		# 走到這裡通常代表 stage_clear 路徑，保留兼容
		status_label.text = "🏆 VICTORY!\n按任意鍵重新開始"
		status_label.modulate = Color(0.4, 1.0, 0.5, 1)
	else:
		status_label.text = "💀 GAME OVER\n%s\n\n按任意鍵重新開始" % reason
		status_label.modulate = Color(1.0, 0.4, 0.4, 1)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	# 多人模式下，只有 host 可下一步；client 按鍵忽略
	if not NetworkManager.is_authoritative():
		return
	if is_stage_clear:
		var has_next: bool = LevelManager.current_index + 1 < LevelManager.levels.size()
		if has_next:
			_advance_stage()
		else:
			# 全破回 Lobby
			if NetworkManager.is_offline():
				LevelManager.start_level(0)
				get_tree().change_scene_to_file("res://scenes/Lobby.tscn")
			else:
				NetworkManager.rpc_return_to_lobby.rpc()
	elif is_game_over:
		# 從當前關重來
		if NetworkManager.is_offline():
			LevelManager.start_level(LevelManager.current_index)
			get_tree().reload_current_scene()
		else:
			NetworkManager.rpc_start_match.rpc(LevelManager.current_index)
