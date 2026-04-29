extends Node2D
## 坦克大決戰 - 主場景
## 關卡資料來自 LevelManager (autoload)，不再硬編

const POWERUP_SCENE := preload("res://scenes/Powerup.tscn")

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

# --- 當前關卡狀態 ---
var current_level: LevelData
var enemies_remaining: int = 0
var enemies_spawned: int = 0
var enemies_alive: int = 0
var player_lives: int = 3
var is_game_over: bool = false
var is_stage_clear: bool = false

# 各玩家原始 spawn (peer_id → tile) 用於死亡重生時回到自己原位
var player_spawns_by_id: Dictionary = {}

@onready var arena:        Node2D = $Arena
@onready var spawn_timer:  Timer  = $SpawnTimer
@onready var info_label:   Label  = $UI/Panel/Info
@onready var status_label: Label  = $UI/Panel/Status

var pause_overlay: ColorRect

func _ready() -> void:
	# 注意：不要在這裡 reset_session()，否則跨關 score 會歸零
	# 由 Lobby._on_play 在開新遊戲時才 reset
	randomize()
	status_label.visible = false
	_setup_pause_overlay()
	# 進新場景一律重置 pause (避免跨關殘留)
	GameManager.is_paused = false
	get_tree().paused = false
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
	AudioManager.play_bgm()

func _spawn_all_players() -> void:
	# 單人 / host：依連線玩家數量 spawn
	var spawns: Array[Vector2i] = current_level.player_spawns.duplicate()
	if spawns.is_empty():
		spawns = [current_level.player_spawn]
	var assigned: int = 0
	if NetworkManager.is_offline():
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

# ---------- 玩家 / 敵軍生成 ----------
func _spawn_player(spawn_tile: Vector2i, owner_peer_id: int = 0) -> void:
	var ts: int = GameConst.TILE_SIZE
	# 記錄原始 spawn，死亡重生回原位
	player_spawns_by_id[owner_peer_id] = spawn_tile
	var t = tank_scene.instantiate()
	t.position = Vector2(spawn_tile.x * ts + ts / 2.0, spawn_tile.y * ts + ts / 2.0)
	t.is_player = true
	t.move_speed = GameConst.PLAYER_SPEED
	# 第二個玩家用藍色區分
	t.body_color = Color(0.95, 0.85, 0.30) if owner_peer_id <= 1 else Color(0.30, 0.70, 1.00)
	t.set("tank_type", "player")
	t.bullet_scene = bullet_scene
	# 把 owner_peer_id 綁進 callable，重生時可知道是哪個玩家
	t.died.connect(_on_player_died.bind(owner_peer_id))
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
	var enemy_type: StringName = _pick_enemy_type()
	_apply_enemy_type(t, enemy_type)
	t.bullet_scene = bullet_scene
	t.died.connect(_on_enemy_died)
	arena.add_child(t)
	enemies_spawned += 1
	enemies_alive   += 1
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
	t.set("tank_type", String(type_id))
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
			AudioManager.play_synced("boss_warning")
		&"mega":
			t.move_speed = base_speed * 0.6
			t.body_color = Color(0.55, 0.05, 0.10)  # 暗紅
			t.set("max_hp", 10)
			t.set("is_boss", true)  # 享 boss 三向散彈 + 大型
			AudioManager.play_synced("boss_warning")
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

# ---------- Multiplayer 同步 RPC ----------
## 由 authority 端 (bullet 命中後) 呼叫，所有 peer 在自己端摧毀對應 wall
@rpc("authority", "call_local", "reliable")
func rpc_destroy_wall_at(grid_x: int, grid_y: int) -> void:
	var w: Node = _find_wall_at(grid_x, grid_y)
	if w and w.has_method("take_damage"):
		w.take_damage()  # wall.gd 自己處理 brick queue_free / steel 吸彈 + 音效特效

@rpc("authority", "call_local", "reliable")
func rpc_destroy_eagle() -> void:
	for e in get_tree().get_nodes_in_group("eagle"):
		if e.has_method("take_damage"):
			e.take_damage()
			break

func _find_wall_at(grid_x: int, grid_y: int) -> Node:
	var ts: int = GameConst.TILE_SIZE
	var target := Vector2(grid_x * ts + ts / 2.0, grid_y * ts + ts / 2.0)
	for w in get_tree().get_nodes_in_group("walls"):
		if w is Node2D and (w as Node2D).position.distance_to(target) < 4.0:
			return w
	return null

## 命中特效；由 authority 廣播給所有 peer 同步顯示
@rpc("authority", "call_local", "unreliable")
func rpc_spawn_hit_spark(pos: Vector2, dir: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.emitting             = true
	p.amount               = 6
	p.lifetime             = 0.25
	p.one_shot             = true
	p.explosiveness        = 0.90
	p.randomness           = 0.30
	p.direction            = -dir
	p.spread               = 65.0
	p.gravity              = Vector2(0.0, 280.0)
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 80.0
	p.scale_amount_min     = 2.0
	p.scale_amount_max     = 3.0
	p.color                = Color(1.0, 0.85, 0.30)
	arena.add_child(p)
	p.global_position = pos
	get_tree().create_timer(0.45).timeout.connect(func():
		if is_instance_valid(p):
			p.queue_free()
	)

# ---------- 事件 ----------
func _on_player_died(_death_pos: Vector2, _death_type: String, owner_peer_id: int) -> void:
	player_lives -= 1
	_update_ui()
	if player_lives <= 0:
		_game_over(false, "PLAYER 全滅")
		return
	await get_tree().create_timer(1.0).timeout
	if not is_game_over and not is_stage_clear:
		var spawn_tile: Vector2i = player_spawns_by_id.get(owner_peer_id, current_level.player_spawn)
		_spawn_player(spawn_tile, owner_peer_id)

func _on_enemy_died(pos: Vector2, tank_type: String) -> void:
	enemies_alive     -= 1
	enemies_remaining -= 1
	GameManager.add_kill(tank_type)
	if not is_game_over:
		_maybe_spawn_powerup(pos, tank_type)
	_update_ui()
	if enemies_remaining <= 0:
		_stage_clear()

func _on_eagle_destroyed() -> void:
	_game_over(false, "老鷹基地被摧毀")

# ---------- 道具系統 ----------
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

func _on_powerup_collected(pu_type: int, picker: Node) -> void:
	AudioManager.play_synced("powerup")
	var picker_tank := picker as Tank
	match pu_type:
		Powerup.Type.STAR:
			if picker_tank:
				picker_tank.max_bullets = 2
		Powerup.Type.SHIELD:
			if picker_tank:
				picker_tank.apply_shield(10.0)
		Powerup.Type.BOMB:
			_apply_bomb()
		Powerup.Type.CLOCK:
			_apply_clock(5.0)
		Powerup.Type.SHOVEL:
			_apply_shovel(15.0)
		Powerup.Type.EXTRA_LIFE:
			player_lives += 1
			_update_ui()

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

# ---------- UI / 狀態切換 ----------
func _update_ui() -> void:
	var stage_name: String = current_level.display_name if current_level else "?"
	info_label.text = "%s\n分數：%d  最高：%d\n玩家命數：%d\n剩餘敵軍：%d\n場上敵軍：%d" % [
		stage_name, GameManager.score, GameManager.high_score,
		player_lives, enemies_remaining, enemies_alive
	]
	# 多人模式下，authority 把狀態廣播給 client
	if not NetworkManager.is_offline() and NetworkManager.is_authoritative():
		rpc_sync_state.rpc(
			enemies_remaining, enemies_alive, player_lives,
			GameManager.score, GameManager.high_score, GameManager.kill_counts
		)

@rpc("authority", "call_remote", "reliable")
func rpc_sync_state(rem: int, alive: int, lives: int, score: int, high: int, kills: Dictionary) -> void:
	enemies_remaining = rem
	enemies_alive     = alive
	player_lives      = lives
	GameManager.score       = score
	GameManager.high_score  = high
	GameManager.kill_counts = kills
	# call _update_ui on client without re-broadcasting
	var stage_name: String = current_level.display_name if current_level else "?"
	info_label.text = "%s\n分數：%d  最高：%d\n玩家命數：%d\n剩餘敵軍：%d\n場上敵軍：%d" % [
		stage_name, score, high, lives, rem, alive
	]

## 廣播 status (stage clear / game over) 文字給 client
@rpc("authority", "call_remote", "reliable")
func rpc_show_status(text: String, r: float, g: float, b: float, a: float) -> void:
	status_label.visible = true
	status_label.text = text
	status_label.modulate = Color(r, g, b, a)

func _broadcast_status(text: String, c: Color) -> void:
	if not NetworkManager.is_offline() and NetworkManager.is_authoritative():
		rpc_show_status.rpc(text, c.r, c.g, c.b, c.a)

func _stage_clear() -> void:
	if is_stage_clear or is_game_over:
		return
	is_stage_clear = true
	spawn_timer.stop()
	LevelManager.mark_cleared()
	AudioManager.play_synced("stage_clear")
	status_label.visible = true
	var has_next: bool = LevelManager.current_index + 1 < LevelManager.levels.size()
	if has_next:
		var msg := "🏆 STAGE CLEAR!\n%s\n\n3 秒後進入下一關 (按任意鍵立刻)" % current_level.display_name
		var col := Color(0.4, 1.0, 0.5, 1)
		status_label.text = msg
		status_label.modulate = col
		_broadcast_status(msg, col)
		await get_tree().create_timer(3.0).timeout
		if is_stage_clear:  # 玩家未中斷
			_advance_stage()
	else:
		var kc  := GameManager.kill_counts
		var stats := "基本×%d  快速×%d  重型×%d\nBoss×%d  Mega×%d" % [
			kc["basic"], kc["fast"], kc["heavy"], kc["boss"], kc["mega"]
		]
		var msg := "🎖 ALL CLEAR!\n全關卡攻略完成\n\n%s\n分數 %d  最高 %d\n\n按任意鍵回首頁" % [
			stats, GameManager.score, GameManager.high_score
		]
		var col := Color(1.0, 0.85, 0.3, 1)
		status_label.text = msg
		status_label.modulate = col
		_broadcast_status(msg, col)

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
	AudioManager.stop_bgm()

	var kc  := GameManager.kill_counts
	var stats := (
		"基本×%d  快速×%d  重型×%d\nBoss×%d  Mega×%d"
		% [kc["basic"], kc["fast"], kc["heavy"], kc["boss"], kc["mega"]]
	)
	status_label.visible = true
	var msg: String
	var col: Color
	if victory:
		AudioManager.play_synced("stage_clear")
		msg = (
			"🏆 VICTORY!\n殲滅全部敵軍！\n\n%s\n分數 %d  最高 %d\n\n按任意鍵重新開始"
			% [stats, GameManager.score, GameManager.high_score]
		)
		col = Color(0.4, 1.0, 0.5, 1)
	else:
		AudioManager.play_synced("game_over")
		msg = (
			"💀 GAME OVER\n%s\n\n%s\n分數 %d  最高 %d\n\n按任意鍵重新開始"
			% [reason, stats, GameManager.score, GameManager.high_score]
		)
		col = Color(1.0, 0.4, 0.4, 1)
	status_label.text = msg
	status_label.modulate = col
	_broadcast_status(msg, col)

func _setup_pause_overlay() -> void:
	pause_overlay = ColorRect.new()
	pause_overlay.color = Color(0, 0, 0, 0.55)
	pause_overlay.anchor_right = 1.0
	pause_overlay.anchor_bottom = 1.0
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	pause_overlay.visible = false
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := Label.new()
	label.text = "⏸  已暫停\n\nESC 繼續"
	label.add_theme_font_size_override("font_size", 48)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	pause_overlay.add_child(label)

	$UI.add_child(pause_overlay)

func _toggle_pause() -> void:
	if not NetworkManager.is_authoritative():
		return  # client 不能主動 pause
	var new_paused: bool = not GameManager.is_paused
	if NetworkManager.is_offline():
		_apply_pause(new_paused)
	else:
		rpc_pause.rpc(new_paused)

@rpc("authority", "call_local", "reliable")
func rpc_pause(paused: bool) -> void:
	_apply_pause(paused)

func _apply_pause(p: bool) -> void:
	GameManager.is_paused = p
	get_tree().paused = p
	if pause_overlay:
		pause_overlay.visible = p

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return

	# 暫停：host / 單人才能觸發；遊戲結束/通關階段不能 pause
	if event.is_action_pressed("ui_pause") \
			and NetworkManager.is_authoritative() \
			and not is_game_over and not is_stage_clear:
		_toggle_pause()
		get_viewport().set_input_as_handled()
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
		# Game Over 重來：重置 score (與 Lobby 開新場一致)
		if NetworkManager.is_offline():
			GameManager.reset_session()
			LevelManager.start_level(LevelManager.current_index)
			get_tree().reload_current_scene()
		else:
			NetworkManager.rpc_start_match.rpc(LevelManager.current_index, true)
