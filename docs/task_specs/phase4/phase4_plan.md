# Phase 4 — 像素华尔街视觉改造计划

> **文档类型**: CTO 计划  
> **触发**: PRD v2.0 新增 §5 视觉风格规范  
> **目标**: 从当前暗色扁平 UI 改为像素 RPG 风格  
> **周期**: 4-6 周（3 个里程碑）  

---

## 一、影响评估

### 变更范围

| 维度 | 当前 | PRD 要求 | 影响程度 |
|---|---|---|---|
| 主题 | dark_theme.gd（扁平暗色） | 三层阶梯像素边框 + 四角装饰 | 🔴 重写 |
| K 线 | Line2D（平滑曲线） | 像素方块色块 + 影线 | 🔴 重写 |
| 进度条 | Tween 平滑 | 方块色块数组 | 🟡 改造 |
| 动画 | Tween 渐变 | step-end 硬切 | 🟡 改造 |
| 字体 | Godot 默认 | Zpix/m5x7 像素字体 | 🟡 集成 |
| 导航 | _ready → era_select | main_menu → era_select | 🟡 改造 |
| 屏幕数量 | 8 个屏幕 | 11 个屏幕（+3 新屏幕） | 🟡 新增 |

### 各组影响

| 组 | 任务数 | 影响 |
|---|---|---|
| **TL** | 2 | 导航流程改造（main_menu 入口） |
| **WS1** | 0 | 无影响（市场引擎纯逻辑） |
| **WS2** | 0 | 无影响（游戏玩法纯逻辑） |
| **WS3** | 0 | 无影响（玩家经济纯逻辑） |
| **WS4** | 0 | 无影响（网络层纯逻辑） |
| **WS5** | 10 | 全部 UI 像素化改造 + 3 新屏幕 |

**结论**: Phase 4 是 **WS5 主导的视觉专项**，WS1-WS4 可在此期间做质量优化或休息。

---

## 二、新增资产需求

### 字体文件（需添加到项目）

| 文件 | 用途 | 来源 |
|---|---|---|
| `assets/fonts/zpix.ttf` | 中文像素字体 | https://github.com/SolidZORO/zpix-pixel-font |
| `assets/fonts/m5x7.ttf` | 英文/数字像素字体 | https://managore.itch.io/m5x7 |

### Godot 项目配置

```ini
# project.godot 新增
[display]
window/size/viewport_width=390
window/size/viewport_height=844
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[rendering]
textures/canvas_textures/default_texture_filter=0  # Nearest（像素不模糊）
```

---

## 三、里程碑

| 周次 | 里程碑 | 交付物 |
|---|---|---|
| **Week 1-2** | 像素基础设施 | PixelTheme 系统 + 像素字体 + K 线重写 + main_menu |
| **Week 3-4** | 全屏幕像素化 | 8 个现有屏幕像素边框改造 + 3 个新屏幕 |
| **Week 5-6** | 动画打磨 | 像素动画 + 进度条 + 音效适配 |

---

## 四、PixelTheme 规范（WS5 核心交付）

### 颜色常量（替代 DarkTheme）

```gdscript
# pixel_theme.gd
class_name PixelTheme

# 背景层
const BG_DARKEST := Color("#0a0b14")   # 屏幕背景/外框
const BG_PANEL := Color("#0f1020")     # 简单框内部
const BG_CARD := Color("#1a1c2c")      # RPG框内部

# 强调色
const ACCENT_BLUE := Color("#3b5dc9")  # RPG框线、主按钮
const ACCENT_GOLD := Color("#f7b801")  # 选中、标题、利润
const COLOR_UP := Color("#38b764")     # 盈利、撤离、成功
const COLOR_DOWN := Color("#e8434a")   # 亏损、爆仓、危险

# 文字色
const TEXT_PRIMARY := Color("#f4f4f4")
const TEXT_SECONDARY := Color("#94b0c2")
const TEXT_DIM := Color("#333c57")
```

### 像素边框工厂

```gdscript
# PixelBorder — 三层阶梯式边框
static func create_rpg_panel(color: Color = ACCENT_BLUE) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = BG_CARD
    style.border_width_left = 2
    style.border_width_right = 2
    style.border_width_top = 2
    style.border_width_bottom = 2
    style.border_color = color
    style.shadow_color = BG_DARKEST
    style.shadow_size = 2
    style.shadow_offset = Vector2(2, 2)
    # 内阴影通过 inset ContentMargin 实现
    style.content_margin_left = 4
    style.content_margin_right = 4
    style.content_margin_top = 4
    style.content_margin_bottom = 4
    return style
```

### 四种框体类型

| 类型 | 方法名 | 用途 |
|---|---|---|
| RPG双层框 | `create_rpg_panel(ACCENT_BLUE)` | 对话框、重要面板 |
| 选中高亮框 | `create_rpg_panel(ACCENT_GOLD)` | 当前选中项 |
| 警告框 | `create_warning_panel()` | 撤离窗口、危机 |
| 简单框 | `create_simple_panel()` | 内容分组 |

---

## 五、导航流程变更

### 当前流程（Phase 3）
```
_ready() → tutorial/era_select → loadout → trading → settlement → era_select
```

### PRD 要求流程（Phase 4）
```
_ready() → main_menu
    ├── [开始交易] → era_select → loadout → trading → settlement → main_menu
    ├── [保险柜] → safe_box → main_menu
    ├── [技能库] → skills → main_menu
    ├── [成就墙] → achievements → main_menu
    ├── [设置] → settings → main_menu
    └── [个人主页] → profile → main_menu
```

**TL 任务**: main.gd 中添加 `MainMenuScreen` 作为首屏，修改结算后返回 main_menu 而非 era_select。

---

## 六、K 线重写规范

### 当前实现（需废弃）
- `Line2D` 平滑曲线
- `_draw()` 直接绘制顶点

### PRD 要求（像素 K 线）
- `HBoxContainer` + `ColorRect` 数组
- 每根 K 线 = 上影线(1px) + 实体(方块色块) + 下影线(1px)
- 涨=绿(`#38b764`) 跌=红(`#e8434a`)
- 实体带 `inset` 上亮下暗立体感
- 网格用虚线（`repeating` ColorRect 间隔）

```gdscript
# kline_chart.gd 重写方向
func _rebuild_candles(ohlc_data: Array) -> void:
    for child in _candle_container.get_children():
        child.queue_free()
    for candle in ohlc_data:
        var is_up := candle.close >= candle.open
        var color := PixelTheme.COLOR_UP if is_up else PixelTheme.COLOR_DOWN
        # 上影线
        var upper_wick := ColorRect.new()
        upper_wick.custom_minimum_size = Vector2(1, _price_to_pixel(candle.high) - _price_to_pixel(maxf(candle.open, candle.close)))
        upper_wick.color = color
        # 实体
        var body := ColorRect.new()
        body.custom_minimum_size = Vector2(CANDLE_WIDTH, absf(_price_to_pixel(candle.close) - _price_to_pixel(candle.open)))
        body.color = color
        # 下影线
        var lower_wick := ColorRect.new()
        # ...
        _candle_container.add_child(upper_wick)
        _candle_container.add_child(body)
        _candle_container.add_child(lower_wick)
```
