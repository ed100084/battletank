# 接蘋果 (Catch the Apple)

## 玩法

| 操作 | 鍵 |
|---|---|
| 籃子左移 | ← / A |
| 籃子右移 | → / D |
| 重新開始 (Game Over 後) | SPACE / Enter |

## 規則

- 蘋果隨機從畫面上方落下
- 接到 +1 分；漏掉 -1 命
- 分數越高，蘋果生成越快 (1.2s → 最快 0.4s)
- 命數歸零 → Game Over

## 程式架構

| 檔案 | 角色 | 關鍵職責 |
|---|---|---|
| `scenes/Main.tscn` + `scripts/main.gd` | 場景控制器 | 生成蘋果、計分、生命、Game Over |
| `scenes/Apple.tscn` + `scripts/apple.gd` | 蘋果 (Area2D) | 自由落體、被接到/漏掉發 signal |
| `Basket` (Main 內) + `scripts/basket.gd` | 玩家 (Area2D) | 接收輸入、限制邊界 |

## 設計重點 (給之後想擴充的你)

1. **訊號驅動 (Signal-driven)**：Apple 不知道分數系統存在，只會 `caught.emit()` / `missed.emit()`，由 Main 訂閱。低耦合。
2. **Area2D + Group**：碰撞偵測用 `area_entered` + `is_in_group("basket")`，比繼承樹耦合更乾淨。
3. **Scene as Prefab**：Apple 是獨立 .tscn，可以重用 / 換皮 / 加變體。

## 可以延伸的方向

- 加音效 (`AudioStreamPlayer` + `audio/sfx/`)
- 加金蘋果/炸彈 (Apple.tscn 改 export 變體)
- 高分存檔 (用 `user://highscore.cfg` ConfigFile)
- 換成 Tween 動畫讓蘋果搖晃
- 加暫停選單 (用 `GameManager.toggle_pause()`)
