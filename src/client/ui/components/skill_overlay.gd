## 技能 UI 覆盖层（显示类技能的视觉表现）
## 所有权: WS5 (客户端 UI 组)
## 服务于 WS2 SkillEffect 中 effect_type == "ui_display" 类技能
extends CanvasLayer
class_name SkillOverlay

## 跟风大师: 其他玩家买卖方向箭头容器
var _herd_container: Control = null
## 风险预警: 全屏红色警告面板
var _crash_warning: ColorRect = null
var _crash_label: Label = null
## 追涨猎手: 连涨标记容器
var _momentum_markers: Dictionary = {}  ## symbol -> Label

## 跟风大师箭头池
var _herd_arrows: Array[Label] = []


func _ready() -> void:
	layer = 8  # 在 UI 之下, VFX 之下
	_build_overlay()


func _build_overlay() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# 跟风大师容器
	_herd_container = Control.new()
	_herd_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_herd_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_herd_container)

	# 风险预警面板（默认隐藏）
	_crash_warning = ColorRect.new()
	_crash_warning.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crash_warning.color = Color(0.9, 0.1, 0.1, 0.0)
	_crash_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crash_warning.visible = false
	root.add_child(_crash_warning)

	_crash_label = Label.new()
	_crash_label.text = "⚠ 风险预警: 市场即将崩盘! ⚠"
	_crash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crash_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crash_label.add_theme_font_size_override("font_size", 36)
	_crash_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	_crash_warning.add_child(_crash_label)


# ─── 趋势洞察: K 线 MA 交叉信号标记 ────────────────────────────────────────────

## 在 K 线图表上显示 MA 交叉信号（供 trading_screen 调用）
func show_ma_cross_signal(kline: Control, position: Vector2, is_golden: bool) -> void:
	var marker := Label.new()
	marker.text = "▲" if is_golden else "▼"
	marker.add_theme_font_size_override("font_size", 16)
	marker.add_theme_color_override("font_color",
		Color(0.2, 0.9, 0.3) if is_golden else Color(0.9, 0.2, 0.1))
	marker.position = position
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kline.add_child(marker)
	# 3 秒后淡出
	var tween := create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(marker, "modulate:a", 0.0, 0.5)
	tween.tween_callback(marker.queue_free)


# ─── 情绪感知: 增强恐贪指数显示 ────────────────────────────────────────────────

## 更新恐贪指数显示（增强版,带颜色渐变）
func update_sentiment_display(top_bar: Control, fgi: float) -> void:
	if top_bar.has_method("update_fear_greed"):
		top_bar.update_fear_greed(fgi)


# ─── 基本面扫描: 股票列表显示内在价值 ──────────────────────────────────────────

## 在股票按钮上显示内在价值 vs 现价
func show_intrinsic_value(stock_button: Button, current_price: float, intrinsic_value: float) -> void:
	var ratio := intrinsic_value / maxf(current_price, 0.01)
	var tag := ""
	var color := ""
	if ratio > 1.1:
		tag = " [低估]"
		color = "green"
	elif ratio < 0.9:
		tag = " [高估]"
		color = "red"
	else:
		tag = " [合理]"
		color = "yellow"
	# 追加到按钮文本
	var base_text := stock_button.text
	if not base_text.contains("["):
		stock_button.text = base_text + "\n[color=%s]%s[/color]" % [color, tag]


# ─── 风险预警: 崩盘前全屏红色警告 ──────────────────────────────────────────────

## 显示崩盘预警（持续 duration 秒后自动消失）
func play_crash_warning(duration: float = 5.0) -> void:
	_crash_warning.visible = true
	var tween := create_tween()
	# 红色渐入
	tween.tween_property(_crash_warning, "color:a", 0.3, 0.3)
	# 文字闪烁
	for i in range(3):
		tween.tween_property(_crash_label, "modulate:a", 0.3, 0.3)
		tween.tween_property(_crash_label, "modulate:a", 1.0, 0.3)
	# 保持显示
	tween.tween_interval(maxf(duration - 2.4, 0.5))
	# 渐出
	tween.tween_property(_crash_warning, "color:a", 0.0, 0.5)
	tween.tween_callback(func() -> void: _crash_warning.visible = false)


# ─── 跟风大师: 显示其他玩家买卖方向 ────────────────────────────────────────────

## 显示其他玩家的买卖方向箭头（持续 duration 秒）
func show_herd_directions(directions: Array[Dictionary], duration: float = 5.0) -> void:
	# 清除旧箭头
	_clear_herd_arrows()
	for dir_data in directions:
		var arrow := Label.new()
		var side: int = dir_data.get("side", 0)  # 0=buy, 1=sell
		var player_name: String = dir_data.get("player_name", "?")
		var pos_x: float = dir_data.get("x", randf_range(100.0, 600.0))
		var pos_y: float = dir_data.get("y", randf_range(200.0, 400.0))

		if side == 0:  # BUY
			arrow.text = "↑ %s 买入" % player_name
			arrow.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
		else:  # SELL/SHORT
			arrow.text = "↓ %s 卖出" % player_name
			arrow.add_theme_color_override("font_color", Color(0.9, 0.2, 0.1))

		arrow.add_theme_font_size_override("font_size", 14)
		arrow.position = Vector2(pos_x, pos_y)
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_herd_container.add_child(arrow)
		_herd_arrows.append(arrow)

	# duration 后自动清除
	var tween := create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(_clear_herd_arrows)


## 清除跟风大师箭头
func _clear_herd_arrows() -> void:
	for arrow in _herd_arrows:
		if is_instance_valid(arrow):
			arrow.queue_free()
	_herd_arrows.clear()
