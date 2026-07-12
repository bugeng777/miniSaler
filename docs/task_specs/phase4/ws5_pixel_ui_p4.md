# WS5 客户端 UI 组 — Phase 4 任务规格书（像素风格改造）

> **组长**: WS5 Lead  
> **独占目录**: `src/client/ui/` + `src/client/audio/` + `assets/fonts/`  
> **本阶段角色**: 像素视觉全面改造（WS5 主导 Phase 4）  
> **周期**: 4-6 周  

---

## 里程碑 1：像素基础设施（Week 1-2）

### 任务 4.1 PixelTheme 系统（替代 DarkTheme）

**文件**: 新建 `src/client/ui/theme/pixel_theme.gd`（替代 `dark_theme.gd`）  
**要求**:
1. 定义 PRD §5.3 全部颜色常量（BG_DARKEST / BG_PANEL / BG_CARD / ACCENT_BLUE / ACCENT_GOLD / COLOR_UP / COLOR_DOWN / TEXT_PRIMARY / TEXT_SECONDARY / TEXT_DIM）
2. 实现 4 种像素边框工厂方法：`create_rpg_panel(color)` / `create_highlight_panel()` / `create_warning_panel()` / `create_simple_panel()`
3. 三层阶梯式边框：外层黑框 2px → 彩色主线 2px → 内阴影 2px
4. 四角 2×2 像素方块装饰（通过 `_draw()` 或额外 ColorRect 实现）
5. `apply_pixel_theme(tree: SceneTree)` 递归应用到所有 Control 节点

**验收**: 任意 PanelContainer 应用后显示三层像素边框，与 PRD §5.1 示意图一致

### 任务 4.2 像素字体集成

**新增目录**: `assets/fonts/`  
**要求**:
1. 下载 Zpix（中文像素字体）和 m5x7（英文像素字体）放入 `assets/fonts/`
2. 在 `pixel_theme.gd` 中定义字体常量
3. `project.godot` 中设置 `textures/canvas_textures/default_texture_filter=0`（Nearest）
4. 所有 Label/Button 默认使用像素字体
5. 标题字体加粗 + letter-spacing

**验收**: 中文/英文/数字均显示为像素风格，无模糊

### 任务 4.3 K 线重写（Line2D → 像素方块）

**文件**: 重写 `src/client/ui/components/kline_chart.gd`  
**当前实现**: Line2D 平滑曲线  
**要求**:
1. 废弃 Line2D，改用 `HBoxContainer` + `ColorRect` 数组
2. 每根 K 线 = 上影线(1px宽) + 实体(方块色块) + 下影线(1px宽)
3. 涨=绿(`#38b764`) 跌=红(`#e8434a`)
4. 实体带 inset 上亮下暗立体感
5. 网格用虚线（间隔 ColorRect）
6. 保留缩放功能（调整 CANDLE_WIDTH）

**验收**: K 线显示为像素方块风格，与 PRD §5.6 描述一致

### 任务 4.4 主菜单屏幕（新增）

**新增文件**: `src/client/ui/screens/main_menu_screen.gd`  
**PRD 参考**: §5.9 标题画面 ASCII 布局  
**要求**:
1. `class_name MainMenuScreen`，继承 `Control`
2. 像素 Logo（ASCII art 或 Label 组合）
3. 像素城市天际线装饰（ColorRect 组合）
4. 菜单项：开始交易（闪烁动画）/ 继续游戏 / 保险柜 / 设置
5. 底部显示版本号 + 玩家总资金
6. 所有元素使用 RPG 像素边框
7. 信号: `signal menu_item_selected(item: StringName)`

**验收**: 主菜单显示完整，像素风格，各按钮可点击并 emit 信号

---

## 里程碑 2：全屏幕像素化（Week 3-4）

### 任务 4.5 现有 8 屏幕像素边框改造

**文件**: 所有 `src/client/ui/screens/*.gd`  
**要求**: 将每个屏幕的 PanelContainer 替换为 PixelTheme 像素边框
- `era_select_screen.gd` — 选中项=金色高亮框，未选中=简单框，未解锁=暗色框+LOCKED
- `loadout_screen.gd` — 资金配置/技能/保险柜各用 RPG 框包裹
- `trading_screen.gd` — K线区/股票列表/持仓/新闻各用简单框，撤离窗口用警告框
- `settlement_screen.gd` — 成功=RPG金色框，爆仓=红色警告框+碎屏效果
- `profile_screen.gd` — RPG 框包裹
- `leaderboard_screen.gd` — 简单框包裹
- `tutorial_screen.gd` — RPG 框包裹
- `safe_box_screen.gd` — RPG 框包裹

**验收**: 每个屏幕都有像素边框，无残留扁平风格

### 任务 4.6 新增 3 个屏幕

**新增文件**:
- `src/client/ui/screens/skills_screen.gd` — 技能库管理（已解锁/未解锁/装备中分类显示）
- `src/client/ui/screens/achievements_screen.gd` — 成就墙（像素奖杯图标 + 进度条）
- `src/client/ui/screens/settings_screen.gd` — 设置（音量/画质/语言）

**PRD 参考**: §5.8 屏幕导航架构  
**验收**: 3 个新屏幕可从主菜单进入并返回

### 任务 4.7 组件像素化

**文件**: 所有 `src/client/ui/components/*.gd`  
**要求**:
- `top_bar.gd` — 像素进度条（方块色块数组替代 Tween）
- `extraction_panel.gd` — 警告框 + 文字闪烁（step-end 0.5s）
- `order_panel.gd` — RPG 按钮凹凸感（inset 上亮白+下暗黑）
- `news_ticker.gd` — 打字机效果（Timer 逐字追加 Label.text，每 50ms 一字）
- `portfolio_view.gd` — 简单框包裹
- `leaderboard_view.gd` — 简单框包裹
- `skill_bar.gd` — RPG 按钮风格
- `achievement_toast.gd` — RPG 框 + 弹出动画（硬切，非渐变）

**验收**: 所有组件使用像素风格

---

## 里程碑 3：动画打磨（Week 5-6）

### 任务 4.8 像素动画系统

**要求**:
1. 闪烁光标: `step-end` 切换 visible（硬切，非渐变）
2. 按钮立体感: inset 上亮白 + 下暗黑
3. 撤离警报: 红框闪烁 + 文字闪烁（step-end 0.5s）
4. 数字跳动: Tween 逐帧更新（结算时的数字滚动效果）
5. 碎屏效果: 爆仓时 ColorRect 碎片散落

**验收**: 各动画均为像素风格（无平滑渐变）

### 任务 4.9 VFX 像素化

**文件**: `src/client/ui/components/vfx_layer.gd`  
**要求**: 所有特效改为像素风格
- 盈利/亏损: 像素数字飘升/飘落（方块数字）
- 撤离成功: 像素金色粒子（ColorRect 方块）
- 爆仓: 屏幕震动 + 红色像素闪烁
- Boss 入场: 像素横幅 + 像素字体

**验收**: VFX 全部像素化

### 任务 4.10 音效像素化适配

**文件**: `src/client/audio/sfx_manager.gd`  
**要求**: 当前占位波形已可工作，Phase 4 保持兼容即可。如替换为专业音效文件，需确保 8-bit 风格。

**验收**: 音效与像素视觉风格统一

---

## 接口契约（Phase 4 新增）

```
# MainMenuScreen 信号
signal menu_item_selected(item: StringName)
# item 值: &"start" / &"continue" / &"safe_box" / &"skills" / &"achievements" / &"settings" / &"profile"

# PixelTheme 公开方法
static func create_rpg_panel(color: Color = ACCENT_BLUE) -> StyleBoxFlat
static func create_highlight_panel() -> StyleBoxFlat
static func create_warning_panel() -> StyleBoxFlat
static func create_simple_panel() -> StyleBoxFlat
static func apply_pixel_theme(tree: SceneTree) -> void
static func get_pixel_font_cn() -> Font
static func get_pixel_font_en() -> Font
```
