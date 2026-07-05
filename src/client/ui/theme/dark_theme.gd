## 暗色主题统一配置
## 所有权: WS5 (客户端 UI 组)
## 在 main.gd 中调用 DarkTheme.apply(get_tree()) 全局应用
extends RefCounted
class_name DarkTheme


const BG_COLOR := Color(0.08, 0.08, 0.12)
const PANEL_COLOR := Color(0.12, 0.12, 0.18)
const TEXT_COLOR := Color(0.9, 0.9, 0.9)
const ACCENT_COLOR := Color(0.0, 0.7, 0.5)
const DANGER_COLOR := Color(0.9, 0.2, 0.2)
const SUCCESS_COLOR := Color(0.2, 0.8, 0.3)


## 应用暗色主题到整个场景树
static func apply(tree: SceneTree) -> void:
	var root := tree.root
	_apply_to_node(root)


## 递归设置所有 Control 节点的主题覆盖
static func _apply_to_node(node: Node) -> void:
	if node is Control:
		var ctrl: Control = node as Control
		# 设置默认字体颜色
		ctrl.add_theme_color_override("font_color", TEXT_COLOR)
		# 按钮样式
		if node is Button:
			var btn: Button = node as Button
			btn.add_theme_color_override("font_color", TEXT_COLOR)
			btn.add_theme_color_override("font_hover_color", ACCENT_COLOR)
		# 面板背景
		if node is PanelContainer:
			var panel: PanelContainer = node as PanelContainer
			var style := StyleBoxFlat.new()
			style.bg_color = PANEL_COLOR
			style.corner_radius_top_left = 4
			style.corner_radius_top_right = 4
			style.corner_radius_bottom_left = 4
			style.corner_radius_bottom_right = 4
			panel.add_theme_stylebox_override("panel", style)
	for child in node.get_children():
		_apply_to_node(child)
