# 坦克大決戰 (Battle City Clone)

> 玩法**參考**任天堂 Battle City，所有圖形為自繪 Polygon2D，無使用任何任天堂受著作權保護素材。

## 操作

| 按鍵 | 動作 |
|---|---|
| ↑ ↓ ← → | 移動坦克 |
| SPACE | 開砲 (一次只能有一發在場) |
| 任意鍵 | Game Over 後重新開始 |

## 規則

- 玩家初始 **3 條命**
- 場上隨時最多 **3 台**敵軍坦克，總共 **5 台**
- 殲滅 5 台敵軍 → **勝利**
- 玩家命數歸零 / 老鷹基地被打中 → **失敗**

## 地圖元素

| 符號 | 物件 | 行為 |
|---|---|---|
| `B` | 磚牆 (Brick) | 中彈即破，可作戰術掩體 |
| `S` | 鋼牆 (Steel) | 不可破，子彈被吸收 |
| `E` | 老鷹基地 | 被打到即遊戲失敗 |
| `.` | 空地 | 可通行 |

## 程式架構

```
Main (Node2D)             ← 主場景，地圖建構/spawn/勝負
 ├─ Background            ← ColorRect 全螢幕底色
 ├─ ArenaFrame            ← 戰場外框
 ├─ Arena (Node2D)        ← 所有遊戲物件 parent (座標 0..416)
 │   ├─ Brick × N
 │   ├─ Steel × N
 │   ├─ Eagle × 1
 │   ├─ Tank (Player)
 │   ├─ Tank (Enemy) × 3
 │   └─ Bullet × N
 ├─ SpawnTimer
 └─ UI (CanvasLayer)
     └─ Panel (Control + Theme)
         ├─ Title / Info / Help / Status
```

## 物件層級

| Scene | 父型別 | Group | Layer | 職責 |
|---|---|---|---|---|
| Tank.tscn | CharacterBody2D | `player` 或 `enemy` | 2 | 移動 + 開砲；玩家走 input、敵軍走 AI |
| Bullet.tscn | Area2D | `bullets` | 4 | 直線飛行、偵測碰撞、敵我識別 |
| Brick.tscn | StaticBody2D | `walls` | 1 | 中彈即毀 |
| Steel.tscn | StaticBody2D | `walls` | 1 | 不可破 |
| Eagle.tscn | StaticBody2D | `eagle` | 1 | 中彈即遊戲結束 |

## Collision Layer / Mask 設計

| 物件 | Layer | Mask | 為何 |
|---|---|---|---|
| Walls / Eagle | 1 | 0 | 靜態，自己不需偵測，被動被撞 |
| Tanks | 2 | 3 (1+2) | 撞牆、撞別坦克 |
| Bullets | 4 | 3 (1+2) | 偵測牆、偵測坦克；不偵測別子彈 |

## AI 行為

- 每 0.8 ~ 2.2 秒隨機改變方向
- 撞到任何東西立即改方向 (用 `get_slide_collision_count()` 偵測)
- 改方向時對齊網格 (避免卡角)
- 每 frame ~1.8% 機率開砲

## 設計亮點

1. **網格對齊轉向** — `_snap_to_grid_perp()` 讓坦克轉向時自動對齊網格，避免卡在牆角，這是 Battle City 流暢手感的關鍵。
2. **單發子彈限制** — `has_active_bullet` flag + `bullet.tree_exited` signal，子彈消失才能再開一發 (還原 NES 機制)。
3. **敵我識別** — Bullet 帶 `from_player` 旗標，避免自己誤傷友軍坦克。
4. **Composition over Inheritance** — Wall 用 `wall_type` enum 區分磚 / 鋼，不用繼承樹。

## 可以延伸

- **磚牆 4 子格分別破壞** (進階：把 Brick 拆 4 個小 ColorRect，依子彈位置只破其中一塊)
- **道具系統** (星星升級、炸彈、護盾、補命)
- **多關卡** (`MAP` 改成 `Array[Array[String]]` + 關卡編號)
- **二人本機合作** (新增 P2 InputMap WASD + Q 開砲)
- **敵軍類型** (一般 / 高速 / 重裝甲，用 `Tank.enemy_type` enum)
- **音效** (砲擊、中彈、爆炸、勝利音樂；放 `audio/sfx/`)
- **計分高分** (用 `user://highscore.cfg`)
