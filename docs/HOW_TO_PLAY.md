# 野球拳 (Yakyuken) — 棒球主題猜拳

> 本作為**家庭友善版**：純棒球比分概念的猜拳對戰，不含任何成人內容。

## 玩法

- 與 CPU 對打猜拳，**先贏 3 局者勝**
- 平手不算勝負、不計分
- 勝負揭曉前會延遲 0.7 秒製造緊張感 (野・球・けん！)

| 操作 | 鍵 / 動作 |
|---|---|
| 出拳 | 點擊「石頭 / 剪刀 / 布」按鈕 |
| 重新開始 (結束後) | 點擊「再來一場」按鈕 或 SPACE / Enter |

## 規則

| 我方 | 對手 | 結果 |
|---|---|---|
| 石頭 | 剪刀 | WIN |
| 剪刀 | 布 | WIN |
| 布 | 石頭 | WIN |
| 同拳 | — | DRAW (不計分) |

## 程式架構

| 元素 | 路徑 | 職責 |
|---|---|---|
| 主場景 (UI Control) | `scenes/Main.tscn` | 整個 layout：Title / Score / Hands / Buttons |
| 主邏輯 | `scripts/main.gd` | 猜拳判定、計分、勝負、按鈕事件、await 延遲 |
| 字型 | `Main.tscn` 內 SubResource | SystemFont 串接 Microsoft JhengHei → YaHei → Noto CJK，CJK 字保證可顯示 |

## 設計重點

1. **enum + dict 對映**：`Hand { ROCK, SCISSORS, PAPER }` + `HAND_NAMES` 字典，新增手勢只要改兩個地方。
2. **await + Timer**：`await get_tree().create_timer(0.7).timeout` 製造揭曉延遲，比手動 Timer 節點省事。
3. **SystemFont 主題**：用 `theme = SubResource("Theme_main")` 一次套用到所有 Control 子節點，不必每個 Label 個別設字型。
4. **Best of N 條件**：用 `ROUNDS_TO_WIN` 常數，要改成 5 戰 3 勝、7 戰 4 勝只改一行。

## 可以延伸

- **AI 學習你的習慣**：偵測玩家連續 N 次出同一拳就反制
- **三盜一壘** 棒球計數：每勝多顯示一個壘包圖示
- **音效**：球棒揮擊 / 球進手套 / 觀眾歡呼 (`AudioStreamPlayer`)
- **連勝獎勵**：3 連勝額外加 1 分 (combo 系統)
- **難度選擇**：CPU 出拳機率分布調整 (Easy / Hard)
