## 像素主题系统（替代 DarkTheme）
## 所有权: WS5 (客户端 UI 组)
## 马里奥/勇者斗恶龙式三层阶梯像素边框 + 像素字体 + 全局主题应用
## 用法: PixelTheme.apply_pixel_theme(get_tree())
extends RefCounted
class_name PixelTheme


# ─── 配色方案 (PRD §5.3) ─────────────────────────────────────────────────────────
const BG_DARKEST := Color("#0a0b14")        ## 最暗底 / 外框色
const BG_PANEL := Color("#0f1020")          ## 面板底（简单框内部）
const BG_CARD := Color("#1a1c2c")           ## 卡片底（RPG框内部）
const ACCENT_BLUE := Color("#3b5dc9")       ## 主色蓝（RPG框线、主按钮）
const ACCENT_GOLD := Color("#f7b801")       ## 强调金（选中、标题、利润）
const COLOR_UP := Color("#38b764")          ## 涨色绿（盈利、撤离、成功）
const COLOR_DOWN := Color("#e8434a")        ## 跌色红（亏损、爆仓、危险）
const TEXT_PRIMARY := Color("#f4f4f4")      ## 主文字（正文、数值）
const TEXT_SECONDARY := Color("#94b0c2")    ## 次文字（标签、说明）
const TEXT_DIM := Color("#333c57")          ## 暗文字（边框、装饰、禁用）

# ─── 边框尺寸 ────────────────────────────────────────────────────────────────────
const BORDER_OUTER := 2   ## 外层黑框 px
const BORDER_MAIN := 2    ## 彩色主线 px
const BORDER_INNER := 2   ## 内阴影 px
const CORNER_SIZE := 2    ## 四角像素方块尺寸 px

# ─── 字体路径 ────────────────────────────────────────────────────────────────────
const FONT_CN_PATH := "res://assets/fonts/zpix.ttf"
const FONT_EN_PATH := "res://assets/fonts/m5x7.ttf"

static var _font_cn: Font = null
static var _font_en: Font = null


# ═══════════════════════════════════════════════════════════════════════════════════
#  4 种像素边框工厂方法
# ═══════════════════════════════════════════════════════════════════════════════════

## RPG 双层框 — 主对话框、重要面板
## 三层: 黑色外框 → 彩色主线(border) → 内阴影(shadow inset)
static func create_rpg_panel(color: Color = ACCENT_BLUE) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BG_CARD
	# 彩色主线边框
	style.border_width_left = BORDER_MAIN
	style.border_width_right = BORDER_MAIN
	style.border_width_top = BORDER_MAIN
	style.border_width_bottom = BORDER_MAIN
	style.border_color = color
	# 内阴影（模拟第三层暗色内框）
	style.shadow_size = BORDER_INNER
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_offset = Vector2.ZERO
	# 内容边距
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	# 像素风格: 零圆角
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	return style


## 选中高亮框 — 当前选中项
static func create_highlight_panel() -> StyleBoxFlat:
	var style := create_rpg_panel(ACCENT_GOLD)
	# 金色内发光效果: 更亮的内阴影
	style.shadow_color = Color(ACCENT_GOLD.r, ACCENT_GOLD.g, ACCENT_GOLD.b, 0.2)
	style.shadow_size = 3
	return style


## 警告框 — 撤离窗口、危机事件
static func create_warning_panel() -> StyleBoxFlat:
	var style := create_rpg_panel(COLOR_UP)
	# 红色外框模拟: 使用 expand_margin + border 组合
	style.border_color = COLOR_DOWN
	# 内阴影用绿色（红绿交替）
	style.shadow_color = Color(COLOR_UP.r, COLOR_UP.g, COLOR_UP.b, 0.25)
	style.shadow_size = 3
	return style


## 简单框 — 内容分组、次要面板（无外层黑框）
static func create_simple_panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BG_PANEL
	style.border_width_left = BORDER_MAIN
	style.border_width_right = BORDER_MAIN
	style.border_width_top = BORDER_MAIN
	style.border_width_bottom = BORDER_MAIN
	style.border_color = TEXT_DIM
	# 微弱内阴影
	style.shadow_size = 1
	style.shadow_color = Color(0, 0, 0, 0.2)
	style.shadow_offset = Vector2.ZERO
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	return style


# ═══════════════════════════════════════════════════════════════════════════════════
#  RPG 按钮风格
# ═══════════════════════════════════════════════════════════════════════════════════

## 创建像素风格按钮 StateBox（inset 上亮白 + 下暗黑 = RPG 凹凸感）
static func create_button_normal() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = ACCENT_BLUE
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = BG_DARKEST
	# inset 立体感: 上亮 + 下暗
	style.shadow_size = 2
	style.shadow_color = Color(1, 1, 1, 0.15)
	style.shadow_offset = Vector2(1, 1)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


static func create_button_hover() -> StyleBoxFlat:
	var style := create_button_normal()
	style.bg_color = Color(ACCENT_BLUE.r * 1.2, ACCENT_BLUE.g * 1.2, ACCENT_BLUE.b * 1.2)
	return style


static func create_button_pressed() -> StyleBoxFlat:
	var style := create_button_normal()
	style.bg_color = Color(ACCENT_BLUE.r * 0.7, ACCENT_BLUE.g * 0.7, ACCENT_BLUE.b * 0.7)
	# 按下时反转 inset: 上暗 + 下亮（凹陷感）
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_offset = Vector2(-1, -1)
	return style


# ═══════════════════════════════════════════════════════════════════════════════════
#  全局主题应用
# ═══════════════════════════════════════════════════════════════════════════════════

## 递归应用像素主题到整个场景树
static func apply_pixel_theme(tree: SceneTree) -> void:
	var root := tree.root
	_apply_to_node(root)


## 递归设置所有 Control 节点的像素主题
static func _apply_to_node(node: Node) -> void:
	if node is Control:
		var ctrl: Control = node as Control
		# 默认字体颜色
		ctrl.add_theme_color_override("font_color", TEXT_PRIMARY)
		# 应用像素字体（如果有）
		_apply_pixel_font(ctrl)

		if node is Button:
			var btn: Button = node as Button
			btn.add_theme_color_override("font_color", TEXT_PRIMARY)
			btn.add_theme_color_override("font_hover_color", ACCENT_GOLD)
			btn.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
			btn.add_theme_stylebox_override("normal", create_button_normal())
			btn.add_theme_stylebox_override("hover", create_button_hover())
			btn.add_theme_stylebox_override("pressed", create_button_pressed())

		if node is PanelContainer:
			var panel: PanelContainer = node as PanelContainer
			# 默认用 RPG 框
			# 保留组件主动设置的 highlight/warning/simple 样式，避免全局主题覆盖语义色。
			if not panel.has_theme_stylebox_override("panel"):
				panel.add_theme_stylebox_override("panel", create_rpg_panel())

	# 递归子节点
	for child in node.get_children():
		_apply_to_node(child)


## 为 Control 节点应用像素字体
static func _apply_pixel_font(ctrl: Control) -> void:
	# Zpix 同时覆盖中文、英文和数字。此前强制使用 m5x7 会让中文全部变成空白。
	var font := get_pixel_font_cn()
	if font:
		ctrl.add_theme_font_override("font", font)


# ═══════════════════════════════════════════════════════════════════════════════════
#  字体管理
# ═══════════════════════════════════════════════════════════════════════════════════

## 获取中文像素字体
static func get_pixel_font_cn() -> Font:
	if not _font_cn:
		if ResourceLoader.exists(FONT_CN_PATH):
			_font_cn = load(FONT_CN_PATH)
	return _font_cn


## 获取英文像素字体
static func get_pixel_font_en() -> Font:
	if not _font_en:
		if ResourceLoader.exists(FONT_EN_PATH):
			_font_en = load(FONT_EN_PATH)
	return _font_en


# ═══════════════════════════════════════════════════════════════════════════════════
#  工具方法
# ═══════════════════════════════════════════════════════════════════════════════════

## 为 PanelContainer 添加外层黑框（模拟三层阶梯的第一层）
## 通过在 PanelContainer 外围套一个黑色 MarginContainer 实现
static func wrap_with_outer_frame(panel: PanelContainer, color: Color = BG_DARKEST) -> MarginContainer:
	var wrapper := MarginContainer.new()
	wrapper.add_theme_constant_override("margin_left", BORDER_OUTER)
	wrapper.add_theme_constant_override("margin_right", BORDER_OUTER)
	wrapper.add_theme_constant_override("margin_top", BORDER_OUTER)
	wrapper.add_theme_constant_override("margin_bottom", BORDER_OUTER)
	# 外框背景色
	var outer_style := StyleBoxFlat.new()
	outer_style.bg_color = color
	outer_style.corner_radius_top_left = 0
	outer_style.corner_radius_top_right = 0
	outer_style.corner_radius_bottom_left = 0
	outer_style.corner_radius_bottom_right = 0
	wrapper.add_theme_stylebox_override("panel", outer_style)
	# 重新挂载
	if panel.get_parent():
		var idx := panel.get_index()
		var parent := panel.get_parent()
		parent.remove_child(panel)
		wrapper.add_child(panel)
		parent.add_child(wrapper)
		parent.move_child(wrapper, idx)
	return wrapper


## 为 PanelContainer 添加四角像素方块装饰
static func add_corner_decorations(panel: PanelContainer, color: Color = ACCENT_BLUE) -> void:
	var presets := [
		Control.PRESET_TOP_LEFT,
		Control.PRESET_TOP_RIGHT,
		Control.PRESET_BOTTOM_LEFT,
		Control.PRESET_BOTTOM_RIGHT,
	]
	for preset in presets:
		var corner := ColorRect.new()
		corner.color = color
		corner.custom_minimum_size = Vector2(CORNER_SIZE, CORNER_SIZE)
		corner.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
		corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		corner.z_index = 10
		panel.add_child(corner)


## 创建像素进度条（方块色块数组，替代 Tween 渐变）
static func create_pixel_progress_bar(filled: int, total: int, fill_color: Color, empty_color: Color = TEXT_DIM) -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 2)
	for i in range(total):
		var block := ColorRect.new()
		block.custom_minimum_size = Vector2(8, 12)
		if i < filled:
			block.color = fill_color
		else:
			block.color = Color(empty_color.r, empty_color.g, empty_color.b, 0.3)
		bar.add_child(block)
	return bar
