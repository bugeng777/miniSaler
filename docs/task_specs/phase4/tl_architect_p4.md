# TL (WS0) 架构师 — Phase 4 任务规格书

> **角色**: Tech Lead / 架构师  
> **独占目录**: `src/main.gd`, `src/game_bootstrap.gd`, `src/shared/constants.gd`, `src/shared/enums.gd`  
> **本阶段角色**: 导航流程改造（仅 2 个任务）  

---

## 任务 4.11 主菜单导航集成

**文件**: `src/main.gd`  
**前置**: 等 WS5 完成 MainMenuScreen（Week 1-2）  
**要求**:
1. 在 `_build_game_ui()` 中创建并注册 `MainMenuScreen`
2. 修改 `_ready()` 流程：首次进入显示 main_menu（而非 era_select）
3. 连接 `MainMenuScreen.menu_item_selected` 信号：
   - `&"start"` → `show_screen("era_select")`
   - `&"safe_box"` → `show_screen("safe_box")`
   - `&"skills"` → `show_screen("skills")`
   - `&"achievements"` → `show_screen("achievements")`
   - `&"settings"` → `show_screen("settings")`
   - `&"profile"` → `show_screen("profile")`
4. 注册 3 个 WS5 新增屏幕：skills / achievements / settings

**验收**: 启动游戏显示主菜单，各菜单项可导航到对应屏幕

## 任务 4.12 结算后返回主菜单

**文件**: `src/main.gd`  
**要求**: 修改结算后的导航：
- 当前：settlement → era_select
- PRD 要求：settlement → main_menu
- 在 `_on_play_again()` 和结算返回逻辑中改为 `show_screen("main_menu")`

**验收**: 完成一局后返回主菜单（而非直接进入时代选择）

---

## 附：project.godot 配置更新

**文件**: `project.godot`（TL 有权修改）  
**要求**:
1. 窗口分辨率改为竖屏：`viewport_width=390` / `viewport_height=844`
2. 纹理过滤改为 Nearest：`textures/canvas_textures/default_texture_filter=0`
3. stretch aspect 改为 `keep`

**验收**: 游戏窗口为竖屏像素风格
