## 暗色主题统一配置 + 时代氛围差异化
## 所有权: WS5 (客户端 UI 组)
## 在 main.gd 中调用 DarkTheme.apply(get_tree()) 全局应用
## 切换时代后调用 DarkTheme.apply_era_theme(era_id, get_tree()) 切换配色
extends RefCounted
class_name DarkTheme


# ─── 基础暗色主题 ─────────────────────────────────────────────────────────────────
const BG_COLOR := Color(0.08, 0.08, 0.12)
const PANEL_COLOR := Color(0.12, 0.12, 0.18)
const TEXT_COLOR := Color(0.9, 0.9, 0.9)
const ACCENT_COLOR := Color(0.0, 0.7, 0.5)
const DANGER_COLOR := Color(0.9, 0.2, 0.2)
const SUCCESS_COLOR := Color(0.2, 0.8, 0.3)

# ─── 时代配色方案 ─────────────────────────────────────────────────────────────────
## 每个时代独特的主色调，用于 accent / panel 背景 / 高亮
const ERA_THEMES: Dictionary = {
	"hk_1997": {
		"accent": Color(0.85, 0.3, 0.9),       ## 霓虹紫
		"panel": Color(0.15, 0.08, 0.18),       ## 深紫面板
		"highlight": Color(1.0, 0.4, 0.95),     ## 亮粉
		"bg_tint": Color(0.1, 0.06, 0.12),      ## 紫色背景
		"bull": Color(0.2, 0.9, 0.3),           ## 阳线绿
		"bear": Color(0.9, 0.2, 0.1),           ## 阴线红
	},
	"seoul_1988": {
		"accent": Color(0.95, 0.75, 0.2),       ## 奥运金
		"panel": Color(0.15, 0.12, 0.08),       ## 深金面板
		"highlight": Color(1.0, 0.85, 0.3),     ## 亮金
		"bg_tint": Color(0.1, 0.09, 0.06),      ## 金色背景
		"bull": Color(0.2, 0.85, 0.3),
		"bear": Color(0.9, 0.2, 0.15),
	},
	"silicon_2000": {
		"accent": Color(0.2, 0.6, 1.0),         ## 科技蓝
		"panel": Color(0.08, 0.1, 0.18),        ## 深蓝面板
		"highlight": Color(0.4, 0.8, 1.0),      ## 亮蓝
		"bg_tint": Color(0.06, 0.08, 0.14),     ## 蓝色背景
		"bull": Color(0.2, 0.9, 0.4),
		"bear": Color(0.95, 0.25, 0.15),
	},
	"tokyo_1989": {
		"accent": Color(1.0, 0.55, 0.7),        ## 泡沫粉
		"panel": Color(0.16, 0.1, 0.12),        ## 深粉面板
		"highlight": Color(1.0, 0.7, 0.8),      ## 亮粉
		"bg_tint": Color(0.12, 0.08, 0.1),      ## 粉色背景
		"bull": Color(0.15, 0.85, 0.35),
		"bear": Color(0.85, 0.15, 0.1),
	},
	"shanghai_2007": {
		"accent": Color(0.9, 0.15, 0.15),       ## 中国红
		"panel": Color(0.16, 0.08, 0.08),       ## 深红面板
		"highlight": Color(1.0, 0.3, 0.2),      ## 亮红
		"bg_tint": Color(0.12, 0.06, 0.06),     ## 红色背景
		"bull": Color(0.9, 0.2, 0.15),          ## 中国股市阳线=红
		"bear": Color(0.15, 0.8, 0.25),         ## 阴线=绿（中国特色）
	},
}

## 当前激活的时代主题（运行时状态）
static var _current_era: StringName = &""
static var _current_theme: Dictionary = {}


## 应用暗色主题到整个场景树
static func apply(tree: SceneTree) -> void:
	var root := tree.root
	_apply_to_node(root, ACCENT_COLOR, PANEL_COLOR)


## 切换时代配色方案
static func apply_era_theme(era_id: StringName, tree: SceneTree) -> void:
	_current_era = era_id
	if ERA_THEMES.has(str(era_id)):
		_current_theme = ERA_THEMES[str(era_id)]
	else:
		_current_theme = {}
	_apply_to_node(tree.root, _get_accent(), _get_panel())


## 获取当前时代主题颜色（供其他组件查询）
static func get_era_color(key: String) -> Color:
	if _current_theme.has(key):
		return _current_theme[key]
	match key:
		"accent": return ACCENT_COLOR
		"panel": return PANEL_COLOR
		"highlight": return ACCENT_COLOR
		"bg_tint": return BG_COLOR
		"bull": return SUCCESS_COLOR
		"bear": return DANGER_COLOR
		_: return TEXT_COLOR


## 获取当前时代 ID
static func get_current_era() -> StringName:
	return _current_era


## 内部: 获取当前 accent 颜色
static func _get_accent() -> Color:
	if _current_theme.has("accent"):
		return _current_theme["accent"]
	return ACCENT_COLOR


## 内部: 获取当前 panel 颜色
static func _get_panel() -> Color:
	if _current_theme.has("panel"):
		return _current_theme["panel"]
	return PANEL_COLOR


## 递归设置所有 Control 节点的主题覆盖
static func _apply_to_node(node: Node, accent: Color, panel_bg: Color) -> void:
	if node is Control:
		var ctrl: Control = node as Control
		ctrl.add_theme_color_override("font_color", TEXT_COLOR)
		if node is Button:
			var btn: Button = node as Button
			btn.add_theme_color_override("font_color", TEXT_COLOR)
			btn.add_theme_color_override("font_hover_color", accent)
		if node is PanelContainer:
			var p: PanelContainer = node as PanelContainer
			var style := StyleBoxFlat.new()
			style.bg_color = panel_bg
			style.corner_radius_top_left = 4
			style.corner_radius_top_right = 4
			style.corner_radius_bottom_left = 4
			style.corner_radius_bottom_right = 4
			p.add_theme_stylebox_override("panel", style)
	for child in node.get_children():
		_apply_to_node(child, accent, panel_bg)
