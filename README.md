# MyGodotGame

Godot 4.x (Standard / GDScript) 專案 scaffold。

## 環境資訊

| 項目 | 值 |
|---|---|
| Engine | Godot 4.x Standard |
| 主要語言 | GDScript |
| 目標平台 | Windows / Linux / Web (HTML5) |
| 渲染器 | GL Compatibility (預設，可在 `project.godot` 切換為 Forward+/Mobile) |
| 版本控制 | Git (local) |

## 資料夾結構

```
.
├─ assets/          # 美術資源
│  ├─ sprites/      # 2D 角色/物件圖
│  ├─ textures/     # 一般紋理 (含 3D)
│  └─ models/       # 3D 模型 (.glb/.gltf)
├─ scenes/          # .tscn 場景
│  ├─ levels/       # 關卡
│  ├─ ui/           # UI 場景
│  └─ player/       # 玩家相關場景
├─ scripts/         # GDScript
│  ├─ autoload/     # 全域單例 (見 GameManager)
│  ├─ components/   # 可重用元件 (Health, Movement, ...)
│  └─ utils/        # 工具函式
├─ audio/
│  ├─ sfx/          # 音效
│  └─ music/        # 背景音樂
├─ fonts/           # 字型
├─ addons/          # 第三方插件 (AssetLib)
├─ docs/            # 設計文件、需求、changelog
├─ .vscode/         # VS Code 推薦設定
├─ project.godot    # Godot 專案設定
├─ icon.svg         # 應用程式圖示
└─ scenes/Main.tscn # 預設啟動場景
```

## 開啟專案

1. 開啟 Godot 4.x → Project Manager → **Import** → 選 `D:\workspace\Godot\project.godot`
2. 第一次匯入會產生 `.godot/` 快取資料夾 (已被 `.gitignore` 排除)
3. 按 **F5** 即可執行 Main 場景

## 常用快捷鍵

| 動作 | 鍵 |
|---|---|
| 執行專案 | F5 |
| 執行當前場景 | F6 |
| Stop | F8 |
| 切換 Pause (執行期) | ESC (本專案 input map: `ui_pause`) |

## Autoload (全域)

| 名稱 | 路徑 | 用途 |
|---|---|---|
| `GameManager` | `scripts/autoload/game_manager.gd` | 全域狀態、暫停事件 |

## 架構建議

| 層 | 說明 |
|---|---|
| Scene 層 | 一個場景一個職責；用 `scenes/Main.tscn` 當 root，動態載入子場景 |
| Script 層 | 用 `scripts/components/` 寫可重用元件 (Composition over Inheritance) |
| Autoload 層 | 跨場景狀態 (存檔、設定、事件匯流) 才放這裡，避免濫用 |

## Roadmap

- 短期：把 Main.tscn 換成正式遊戲類型 (2D/3D)、補上 player scene
- 中期：建立基本 UI、存檔系統、設定選單
- 長期：匯出 preset (Windows/Web)、CI build、AssetLib 套件選用

## Git

```powershell
# 本地已 init
git log --oneline    # 檢視 commit
# 之後要推到遠端：
git remote add origin <your-repo-url>
git push -u origin main
```

## 安裝 Godot Editor

```powershell
winget install --id GodotEngine.GodotEngine --exact
```

(若改用 C#: `GodotEngine.GodotEngine.Mono`，並安裝 .NET 8 SDK)
