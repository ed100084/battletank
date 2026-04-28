# 坦克大決戰 Battle Tank

> 經典坦克大戰復刻版 — Godot 4.6 / GDScript  
> 程序生成精靈圖、5 關卡系統、4 種敵人、ENet 雙人連線、音效道具計分全實裝

---

## 遊戲簡介

《坦克大決戰》是以 Godot 4.6 打造的 2D 俯視角坦克對戰遊戲，向 1980 年代經典街機《Battle City》致敬。全部精靈圖以 GDScript 程序生成（Polygon2D），無需外部美術資源，開箱即玩。

玩家駕駛黃色坦克保護中央老鷹基地，消滅全部敵軍坦克即可過關；老鷹基地被摧毀或玩家命數歸零則失敗。通關後自動進入下一關，共 5 個關卡。

---

## 功能列表

| 功能 | 狀態 | 說明 |
|------|------|------|
| 核心玩法 | ✅ 已實裝 | 坦克移動、開砲、碰撞、地圖生成 |
| 敵人系統 | ✅ 已實裝 | 4 種 AI 敵軍（基本兵 / 快速兵 / 重裝甲 / Boss） |
| 磚牆 / 鋼牆 | ✅ 已實裝 | 磚牆可摧毀；鋼牆吸收子彈 |
| 老鷹基地 | ✅ 已實裝 | 被摧毀即判定失敗 |
| 邊界防護 | ✅ 已實裝 | 隱形 StaticBody2D 防止坦克出界 |
| 關卡系統 | ✅ 已實裝 | 5 個 .tres 關卡資料、LevelManager、進度存檔 |
| 多人連線 | ✅ 已實裝 | ENet P2P，port 7000，最多 2 人同屏協作 |
| 大廳選單 | ✅ 已實裝 | Lobby 場景：單人 / 開房 / 加入房 / 選關 |
| 無敵閃爍 | ✅ 已實裝 | 出生後短暫無敵 + 閃爍提示 |
| Boss 散彈 | ✅ 已實裝 | Boss 坦克三向 ±15° 散彈、HP 5、體型 ×1.25 |
| 道具系統 | ✅ 已實裝 | 6 種道具拾取（星星/護盾/炸彈/時停/堡壘/加命） |
| 音效系統 | ✅ 已實裝 | AudioManager + 射擊 / 爆炸 / BGM / Boss警報 / 過關 |
| 爆炸特效 | ✅ 已實裝 | Explosion.tscn 爆炸動畫 |
| 計分系統 | ✅ 已實裝 | 擊殺積分、最高分記錄、過關分數顯示 |

---

## 操作說明

| 鍵位 | 動作 |
|------|------|
| ↑ ↓ ← → | 移動坦克 |
| `Space` | 開砲 |
| `Esc` | 暫停 / 繼續 |
| 任意鍵（過關 / 失敗畫面）| 下一關 / 重試 |

---

## 道具說明表

| 道具 | 效果 | 持續時間 |
|------|------|----------|
| 星星 | 子彈速度 x1.5，穿透鋼牆 | 10 秒 |
| 護盾 | 玩家無敵 | 8 秒 |
| 計時 | 凍結所有敵軍 | 6 秒 |
| 炸彈 | 消滅場上全部敵軍 | 即時 |
| 生命 | 增加 1 條命 | 即時 |
| 堡壘 | 老鷹基地周圍換成鋼牆 | 永久 |

---

## 敵人類型表

| 類型 | HP | 速度 | 特性 | 狀態 |
|------|----|------|------|------|
| 基本兵 | 1 | 慢 | 標準 AI 巡邏 | ✅ |
| 快速兵 | 1 | +50% | 橙色，高機動性 | ✅ |
| 重裝甲 | 2 | -30% | 灰色，多次命中 | ✅ |
| Boss | 5 | -15% | 紫色，三向散彈，體型放大 | ✅ |

---

## 技術架構

### 目錄結構

```
.
├─ scenes/
│  ├─ Lobby.tscn           # 大廳選單（單人/開房/加入/選關）
│  ├─ Main.tscn            # 遊戲主場景
│  ├─ Tank.tscn            # 坦克（玩家 / 敵軍共用）
│  ├─ Bullet.tscn          # 子彈
│  ├─ Brick.tscn           # 磚牆（可破）
│  ├─ Steel.tscn           # 鋼牆（不可破）
│  └─ Eagle.tscn           # 老鷹基地
├─ scripts/
│  ├─ autoload/
│  │  └─ game_manager.gd   # 全域狀態、暫停
│  ├─ utils/
│  │  └─ constants.gd      # TILE_SIZE、速度、方向 Enum
│  ├─ level/
│  │  ├─ level_data.gd     # Resource：關卡資料（地圖、敵軍配置）
│  │  └─ level_manager.gd  # Autoload：載入 .tres、進度存檔
│  ├─ network/
│  │  └─ network_manager.gd # Autoload：ENet host/client/offline
│  ├─ main.gd              # 遊戲主邏輯
│  ├─ tank.gd              # 坦克邏輯（玩家 + AI + 多人 authority）
│  ├─ bullet.gd            # 子彈移動、碰撞
│  ├─ lobby.gd             # 大廳 UI 邏輯
│  ├─ wall.gd              # 磚牆 / 鋼牆受損
│  └─ eagle.gd             # 老鷹受損
├─ levels/
│  ├─ level_01.tres        # 入門關
│  ├─ level_02.tres ~ level_05.tres
├─ audio/
│  ├─ sfx/                 # 音效 .wav — 待加入
│  └─ music/               # BGM — 待加入
├─ docs/
│  ├─ ARCHITECTURE.md
│  └─ HOW_TO_PLAY.md
└─ project.godot
```

### Autoload 列表

| 名稱 | 路徑 | 用途 |
|------|------|------|
| `GameManager` | `scripts/autoload/game_manager.gd` | 全域狀態、暫停事件 |
| `GameConst` | `scripts/utils/constants.gd` | 地圖尺寸、速度、方向常數 |
| `LevelManager` | `scripts/level/level_manager.gd` | 關卡載入、通關進度存檔 |
| `NetworkManager` | `scripts/network/network_manager.gd` | ENet 多人連線管理 |

### 碰撞層設計

| Layer | 用途 |
|-------|------|
| 1 | 牆壁（Brick / Steel / Eagle / 邊界） |
| 2 | 坦克（Tank） |
| 4 | 子彈（Bullet） |

---

## 如何開啟

1. 安裝 **Godot 4.6**（或更新版本）
   ```powershell
   winget install --id GodotEngine.GodotEngine --exact
   ```
2. 開啟 Godot Project Manager → **Import** → 選取本目錄的 `project.godot`
3. 第一次匯入會產生 `.godot/` 快取資料夾（已由 `.gitignore` 排除）
4. 按 **F5** 執行遊戲（從大廳場景開始）

---

## 多人連線說明

採用 Godot 內建 **ENet** 協議進行 P2P 連線（listen-server 模式，主機同時也是玩家）：

1. **主機**：在大廳按「開房 (Host)」，系統顯示本機 LAN IP
2. **客戶端**：按「加入房 (Join)」輸入主機 IP → 「連線」
3. 主機按「▶ 開始遊戲」，雙方同步切換到遊戲場景

| 設定 | 值 |
|------|----|
| 通訊埠 | 7000 |
| 最多玩家 | 2 人 |
| 協議 | ENet UDP |
| 主機顏色 | 黃色坦克 |
| 客戶端顏色 | 藍色坦克 |

---

## Roadmap

- [x] 道具系統：6 種道具拾取機制（星星/護盾/炸彈/時停/堡壘/加命）
- [x] 音效系統：AudioManager singleton + 射擊 / 爆炸 / BGM / Boss警報
- [x] 爆炸特效：Explosion.tscn 坦克爆炸動畫
- [x] 計分系統：擊殺積分、最高分記錄、過關分數顯示
- [ ] 更多關卡：關卡 6 以後、Boss 關
- [ ] 匯出預設：Windows / Web (HTML5) 一鍵打包
- [ ] 行動裝置：虛擬搖桿支援

---

## 授權

MIT License — 自由使用、修改、散布。
