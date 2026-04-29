extends Node
## 全域關卡管理 (autoload: LevelManager)
## 負責：載入關卡列表、追蹤當前進度、存讀檔

const SAVE_PATH := "user://save.cfg"
const LEVEL_DIR := "res://levels"

var levels: Array[LevelData] = []
var current_index: int = 0
var highest_unlocked: int = 0  # 最高解鎖關卡 index (0-based)

func _ready() -> void:
	_load_levels()
	_load_save()
	print("[LevelManager] %d levels loaded, highest_unlocked=%d" % [levels.size(), highest_unlocked])

func _load_levels() -> void:
	# 自動掃 res://levels/ 下所有 .tres，依檔名排序
	var dir := DirAccess.open(LEVEL_DIR)
	if dir == null:
		push_error("[LevelManager] cannot open %s" % LEVEL_DIR)
		return
	var files: Array[String] = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			files.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	files.sort()
	for f in files:
		var path := "%s/%s" % [LEVEL_DIR, f]
		var res := load(path)
		if res is LevelData:
			levels.append(res)
		else:
			push_warning("[LevelManager] %s is not LevelData" % path)

func get_current() -> LevelData:
	if levels.is_empty():
		return null
	return levels[clampi(current_index, 0, levels.size() - 1)]

func start_level(index: int) -> void:
	if index < 0 or index >= levels.size():
		push_error("[LevelManager] invalid level index %d" % index)
		return
	current_index = index

func mark_cleared() -> void:
	if current_index > highest_unlocked:
		highest_unlocked = current_index
	if current_index + 1 < levels.size():
		highest_unlocked = max(highest_unlocked, current_index + 1)
	_save()

func advance_to_next() -> bool:
	if current_index + 1 >= levels.size():
		return false
	start_level(current_index + 1)
	return true

# ---------- save / load ----------
func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "highest_unlocked", highest_unlocked)
	cfg.save(SAVE_PATH)

func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		highest_unlocked = 0
		return
	highest_unlocked = cfg.get_value("progress", "highest_unlocked", 0)

func reset_progress() -> void:
	highest_unlocked = 0
	current_index = 0
	_save()
