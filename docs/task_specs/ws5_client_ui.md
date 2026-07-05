# WS5 客户端 UI 组 — Phase 2 任务规格书

> **组长**: WS5 Lead  
> **独占目录**: `src/client/ui/` + `src/client/audio/`  
> **禁止修改**: 其他任何目录的文件（含 `src/main.gd`，UI 信号连接由 TL 在 main.gd 中维护）  

---

## 一、代码评审修复

### 任务 1.1 [MEDIUM] LoadoutScreen 技能选择不重置 — MD-01

**文件**: `src/client/ui/screens/loadout_screen.gd` L78  
**问题**: `load_skills()` 清除 UI 子节点但未重置 `_selected_skills` 数组，再来一局时残留  
**要求**: 在 `load_skills()` 开头添加 `_selected_skills.clear()`  
**验收**: 连续两局游戏，第二局技能选择为空

### 任务 1.2 [MEDIUM] settlement_screen.gd 变量名遮蔽 — MD-05

**文件**: `src/client/ui/screens/settlement_screen.gd` L86  
**问题**: `var name: String` 遮蔽 `Node.name` 内置属性  
**要求**: 改名为 `var player_name: String`  
**验收**: Godot 4.4+ 无变量遮蔽警告

---

## 二、Phase 2 新功能开发

### 任务 2.1 K 线图表增强：蜡烛图模式

**文件**: `src/client/ui/components/kline_chart.gd`  
**背景**: 当前 K 线使用 Line2D 绘制折线，但股票游戏应使用蜡烛图（OHLC）  
**要求**:
1. 新增绘制模式枚举: `enum ChartMode { LINE, CANDLE }`
2. 蜡烛模式下:
   - 阳线（收盘 > 开盘）: 绿色实心矩形
   - 阴线（收盘 < 开盘）: 红色实心矩形
   - 上下影线: 细线段
3. 支持缩放: `_gui_input()` 中检测鼠标滚轮，调整 `_max_visible_points`
4. 数据源改为 `Array[Dictionary]`（每个 dict 包含 open/high/low/close），而非 `Array[float]`

**验收**: K 线图显示标准蜡烛图，支持缩放

### 任务 2.2 交易面板增强：持仓联动

**文件**: `src/client/ui/components/order_panel.gd`  
**要求**:
1. 新增 `set_position_info(quantity: int, avg_price: float, unrealized_pnl: float)` 方法
2. 在面板上显示当前选中股票的持仓信息
3. 买入数量输入框增加快捷按钮: "10" "50" "100" "MAX"
4. 新增 `signal order_requested_with_context(symbol, side, type, qty, price, is_short)` 替代旧信号

**验收**: 选中股票后，订单面板显示持仓信息，快捷按钮可点击

### 任务 2.3 撤离面板增强：视觉反馈

**文件**: `src/client/ui/components/extraction_panel.gd`  
**要求**:
1. 窗口开放时: 按钮高亮（绿色），背景闪烁动画
2. 窗口关闭时: 按钮灰色禁用，显示"等待下次窗口"
3. 倒计时 < 5 秒时: 数字变红，字号放大
4. 新增倒计时动画: 使用 `Tween` 做脉冲效果

**验收**: 撤离窗口开放/关闭有明确视觉区分，倒计时有紧迫感

### 任务 2.4 顶栏增强：交易阶段指示

**文件**: `src/client/ui/components/top_bar.gd`  
**要求**:
1. 新增 `update_phase(phase_name: String, color: Color)` 方法
2. 不同阶段显示不同颜色:
   - ERA_SELECT: 蓝色
   - LOADOUT: 黄色
   - TRADING: 绿色
   - SETTLEMENT: 灰色
3. 新增 `update_extraction_status(is_window_open: bool, remaining: float)`:
   - 窗口开放时: 顶栏底部显示绿色进度条
   - 窗口关闭时: 隐藏

**验收**: 顶栏颜色随阶段变化，撤离窗口有进度条提示

### 任务 2.5 新增 UI 屏幕：保险柜管理

**文件**: 新建 `src/client/ui/screens/safe_box_screen.gd`  
**要求**:
1. `class_name SafeBoxScreen`，继承 `Control`
2. 显示保险柜格子（GridContainer），每格显示物品图标 + 名称
3. 支持拖放操作: 从"可用物品"列表拖入保险柜格子
4. 新增信号: `signal safe_box_configured(items: Array[PlayerTypes.SafeBoxItem])`

**验收**: 保险柜屏幕可显示和配置物品

### 任务 2.6 音效管理器：占位音效生成

**文件**: `src/client/audio/sfx_manager.gd`  
**背景**: 当前所有 `play_*` 方法为空（无音频文件），需要生成占位音效  
**要求**:
1. 使用 `AudioStreamGenerator` 生成简单占位音效（正弦波/方波）:
   - BUY: 短促上升音（440Hz → 880Hz, 0.1s）
   - SELL: 短促下降音（880Hz → 440Hz, 0.1s）
   - EXTRACTION_SUCCESS: 欢快和弦（C-E-G, 0.5s）
   - BUST: 低沉下降音（220Hz → 55Hz, 0.5s）
   - NEWS_ALERT: 提示音（660Hz, 0.05s）
   - BOSS_ENTER: 紧张鼓点（低频脉冲 x3, 0.3s）
2. 在 `_ready()` 中预生成所有音效到 `_streams: Dictionary`
3. 播放时从字典加载对应 stream

**验收**: 各事件触发时有可感知的音效反馈（即使是简单波形）

---

## 三、接口契约（冻结版）

### UI 组件信号清单（供 TL 在 main.gd 中连接）

```
# EraSelectScreen
signal era_selected(era_id: StringName)

# LoadoutScreen
signal loadout_confirmed(extra_funds: float, skill_ids: Array[StringName])

# TradingScreen 内部组件信号（通过 get_* 方法获取引用）
OrderPanel.order_requested(symbol, side, type, qty, price)
ExtractionPanel.extraction_requested()
SkillBar.skill_activate_requested(skill_id: StringName)

# SettlementScreen
signal play_again_pressed()

# SafeBoxScreen（新增）
signal safe_box_configured(items: Array[PlayerTypes.SafeBoxItem])
```

### UI 组件公开方法清单（供 main.gd 调用）

```
# TradingScreen
func update_market_tick(data: Dictionary) -> void
func add_news(text: String) -> void
func set_extraction_window(is_open: bool, remaining: float) -> void
func get_selected_symbol() -> StringName
func get_top_bar() -> TopBar
func get_skill_bar() -> SkillBar
func get_leaderboard() -> LeaderboardView
func get_order_panel() -> OrderPanel
func get_extraction_panel() -> ExtractionPanel
func reset_screen() -> void

# SettlementScreen
func show_result(data: Dictionary) -> void

# ProfileScreen
func load_profile(profile: PlayerTypes.PlayerProfile) -> void

# LoadoutScreen
func load_skills(available_skills: Array[Dictionary]) -> void
func set_countdown(seconds: float) -> void

# EraSelectScreen
func load_eras(eras: Array[EraData], unlocked_ids: Array[StringName]) -> void
```
