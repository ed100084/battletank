extends Resource
class_name LevelData
## 單一關卡資料 (Resource，可在編輯器拖拉、可序列化為 .tres)

## 地圖：每個字元一格
##   . = 空
##   B = 磚 (可破)
##   S = 鋼 (不可破)
##   E = 老鷹 (基地，被打中即敗)
@export var map_layout: PackedStringArray = PackedStringArray()

## 玩家出生格 (tile coord)；雙人模式下用 player_spawns 蓋過
@export var player_spawn: Vector2i = Vector2i(4, 12)
@export var player_spawns: Array[Vector2i] = []  # 多人時用

## 敵軍出生格 (tile coord)，會輪流隨機選
@export var enemy_spawns: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(6, 0), Vector2i(12, 0)
]

## 敵軍配置
@export var enemy_total: int = 5
@export var enemy_max_on_field: int = 3
@export var enemy_speed: float = 70.0
@export var spawn_interval: float = 2.5

## 敵軍類型權重 (key = type id, value = weight)
##   "basic"  = 基本型，HP 1
##   "fast"   = 速度 +50%
##   "heavy"  = HP 2，速度 -30%
##   "boss"   = HP 5，會射散彈
@export var enemy_type_weights: Dictionary = {"basic": 100}

## 顯示名稱與描述
@export var display_name: String = "Stage"
@export var hint: String = ""
