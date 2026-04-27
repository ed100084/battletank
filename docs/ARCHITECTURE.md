# Architecture Notes

## 設計原則

1. **Composition over Inheritance** — 用 component (Node) 組合，避免巨大繼承鏈
2. **Scene = Prefab** — 每個 .tscn 都是可重用單元
3. **Autoload 限縮** — 只放真正全域的東西 (存檔、事件 bus、設定)
4. **Resource 化資料** — 角色屬性、武器數值用 `.tres` Resource，方便策劃調整

## 推薦元件 (待實作)

| 元件 | 路徑 | 職責 |
|---|---|---|
| HealthComponent | scripts/components/health_component.gd | HP / 受傷 / 死亡訊號 |
| MovementComponent | scripts/components/movement_component.gd | 移動 / 跳躍 |
| HitboxComponent | scripts/components/hitbox_component.gd | 攻擊判定 |
| HurtboxComponent | scripts/components/hurtbox_component.gd | 受擊判定 |

## Signal 命名

`動詞_過去式` 或 `主詞_動作`，例如：`died`, `health_changed`, `level_completed`。

## 存檔策略

- 開發初期：`user://savegame.cfg` (ConfigFile)，純文字易 debug
- 正式版：JSON + 版本號，加 hash 防竄改 (非必要)
