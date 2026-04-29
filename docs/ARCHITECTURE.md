# Architecture — 坦克大決戰

## 設計原則

1. **Resource-driven 關卡**：`.tres` 檔承載所有關卡資料；新關卡 = 新檔，不動程式
2. **Authority gating + RPC fan-out**：multiplayer 採 listen-server，host/單人 = authority；事件由 authority 廣播
3. **Autoload 限縮**：只放真正全域的 (網路、關卡、音效、共享狀態)
4. **MultiplayerSpawner + Synchronizer**：動態實體 (Tank/Bullet/Powerup/Explosion) 自動同步；靜態實體 (Wall/Eagle) 用 RPC

## 場景樹結構

```
Lobby.tscn (主場景)
└─ Panel
   ├─ Title / Subtitle
   ├─ Buttons (Single / Host / Join)
   ├─ JoinRow (IpInput + JoinConfirm)
   ├─ Stages (ItemList)
   ├─ Play
   ├─ Status
   └─ ResetProgress

Main.tscn (遊戲主場景)
├─ Background / ArenaFrame
├─ Arena (Node2D, position=(40,40))
│  ├─ Spawner (MultiplayerSpawner) ← 自動 replicate Tank/Bullet/Powerup/Explosion
│  ├─ Brick × N (建置時加入)
│  ├─ Steel × N
│  ├─ Eagle × 1
│  └─ <動態 spawn: Tank, Bullet, Powerup, Explosion>
├─ SpawnTimer (敵軍 spawn 節奏)
└─ UI (CanvasLayer)
   └─ Panel
      ├─ Title / Info / Help / Status
      └─ <動態 add: pause_overlay>
```

## Autoload 對應職責

| Autoload | 職責 | 備註 |
|---|---|---|
| `GameConst` | 全域常數 (TILE_SIZE, MAP_PX, PLAYER_SPEED, Dir enum) | 純常數，無狀態 |
| `GameManager` | 共享狀態 (score, high_score, kill_counts, is_paused) | 單一 source of truth；多人模式由 RPC sync |
| `LevelManager` | 掃 `res://levels/` 載入 .tres、追蹤 current_index、save.cfg 存進度 | |
| `NetworkManager` | ENet host/client，peer 事件，`rpc_start_match/return_to_lobby` | `process_mode = ALWAYS` (暫停中也能收 RPC) |
| `AudioManager` | SFX 播放器池、BGM；`play_synced()` 用 RPC 廣播 | SFX 檔放 `audio/sfx/`，缺檔 NOOP 不 crash |

## Multiplayer 同步策略

| 對象 | 機制 | 說明 |
|---|---|---|
| 玩家 Tank position/rotation | MultiplayerSynchronizer (mode=ALWAYS) | 每 frame 同步；client 端 `_physics_process` early return，純展示 |
| 玩家 Tank input | 各 peer 在自己的 tank 上跑 input | `multiplayer_authority` 設為 owner peer_id |
| 敵軍 Tank | host 跑 AI；MultiplayerSynchronizer 同步 position | host = authority |
| Tank 屬性 (color/type/hp/max_hp/move_speed/is_player/is_boss) | spawn-time replication | 一次性，spawn 時跟著 packet |
| Tank.is_shielded / is_frozen | replication_mode = on_change (2) | client 收到 → setter 自動建/移除 shield visual |
| Bullet | MultiplayerSpawner 自動 spawn/despawn；Sync 同步 position | host 移動，client 純顯示 |
| Wall (Brick/Steel) 破壞 | RPC: `Main.rpc_destroy_wall_at(gx, gy)` | 各 peer 在自己端 take_damage (含特效音效) |
| Eagle 破壞 | RPC: `Main.rpc_destroy_eagle()` | 同上 |
| Powerup spawn/pickup | Spawner 同步 spawn；authority-only 偵測 collision；queue_free 自動同步 despawn | 防雙端 race |
| Explosion VFX | Spawner whitelist；spawn-time position | 一次性 |
| UI (lives/score/enemies/kills) | RPC: `Main.rpc_sync_state(...)` | 每次 `_update_ui()` authority 廣播 |
| Status 文字 (clear/over) | RPC: `Main.rpc_show_status(text, color)` | |
| Audio 音效 | RPC: `AudioManager.rpc_play(name)` 透過 `play_synced()` | |
| Hit spark VFX | RPC: `Main.rpc_spawn_hit_spark(pos, dir)` | call_local + unreliable |
| 暫停 | RPC: `Main.rpc_pause(paused)` | host 才能觸發 |
| 場景切換 | RPC: `NetworkManager.rpc_start_match(idx, reset_score)` | reliable |

## 物件層級

| Scene | 父型別 | Group | Layer | Mask |
|---|---|---|---|---|
| Tank.tscn | CharacterBody2D | `player` 或 `enemy` | 2 | 3 (1+2) |
| Bullet.tscn | Area2D | `bullets` | 4 | 3 (1+2) |
| Brick.tscn | StaticBody2D | `walls` | 1 | 0 |
| Steel.tscn | StaticBody2D | `walls` | 1 | 0 |
| Eagle.tscn | StaticBody2D | `eagle` | 1 | 0 |
| Powerup.tscn | Area2D | `powerups` | 8 | 2 |
| Explosion.tscn | Node2D (純 VFX) | — | — | — |
| 隱形邊界牆 | StaticBody2D (動態建立) | — | 1 | 0 |

## 關卡資料 (LevelData Resource)

```gdscript
@export var map_layout: PackedStringArray   # 13×13 字元地圖
@export var player_spawn: Vector2i          # 單人出生
@export var player_spawns: Array[Vector2i]  # 多人時用
@export var enemy_spawns: Array[Vector2i]
@export var enemy_total: int
@export var enemy_max_on_field: int
@export var enemy_speed: float
@export var spawn_interval: float
@export var enemy_type_weights: Dictionary  # {"basic":40,"fast":30,"heavy":20,"boss":10}
@export var display_name: String
@export var hint: String
```

地圖字元：`.` 空地 / `B` 磚牆 / `S` 鋼牆 / `E` 老鷹基地

## 關鍵設計亮點

1. **網格對齊轉向** — `Tank._snap_to_grid_perp()` 對齊到 cell center (`ts/2 + n*ts`)，非格線；避免坦克瞬移到牆內或邊界外
2. **Authority gating** — Tank/Bullet 物理與命中判定全在 authority，client 純展示；防雙端各算一次
3. **MultiplayerSpawner whitelist** — `Tank/Bullet/Powerup/Explosion` 自動同步生成銷毀，無需手寫 RPC
4. **混合策略** — 動態實體用 Spawner，靜態實體 (Wall/Eagle) 用 RPC by grid coord，避免每場數百個 wall 都掛 Synchronizer
5. **Replication Config 分層** — `replication_mode`: 0=spawn-only / 1=每 frame / 2=on_change，依屬性更新頻率調整
6. **`process_mode = ALWAYS` on NetworkManager** — 暫停中 RPC 仍可送達 (恢復暫停的訊號)
7. **單一 RPC `rpc_start_match(idx, reset_score)`** — 同一通道處理「新場 / 進下一關 / Game Over 重來」，差異在 `reset_score` 旗標

## 存檔策略

- `user://save.cfg` (ConfigFile)
  - `[progress] highest_unlocked = N`
- 純文字方便 debug；正式版可加版本號 / hash

## 已知限制

| 限制 | 影響 | 計畫 |
|---|---|---|
| 無 NAT 穿透 | 公網需手動 port forward | 加 UPnP (中期) |
| 無 reconnect | 斷線 = 回 Lobby | 中期 |
| 無 anti-cheat | P2P 模式 host 可改值 | 公網對戰前評估，可改 server-authoritative dedicated |
| 道具效果 client 視覺 | STAR 加多發子彈在 client 看不到視覺反饋 (但實際生效) | 加 RPC 廣播效果動畫 |
| 觀察者模式 | 三個以上 peer 連線 = client 被踢 (MAX_PLAYERS=2) | 設計考量，2 人協作為主 |
