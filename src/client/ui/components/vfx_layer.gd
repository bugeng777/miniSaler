## 视觉特效层（覆盖在交易屏幕之上）
## 所有权: WS5 (客户端 UI 组)
## 盈利/亏损/撤离/爆仓/Boss入场等关键事件的视觉反馈
extends CanvasLayer
class_name VfxLayer

## 特效层容器
var _overlay: Control = null
## 飘字容器
var _float_container: Control = null
## 全屏闪烁面板
var _flash_panel: ColorRect = null
## 屏幕震动相关
var _shake_target: Control = null
var _shake_tween: Tween = null
var _original_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	layer = 10  # 确保在 UI 之上
	_build_overlay()


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	# 飘字容器
	_float_container = Control.new()
	_float_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_float_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_float_container)

	# 全屏闪烁面板（默认隐藏）
	_flash_panel = ColorRect.new()
	_flash_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_panel.visible = false
	_overlay.add_child(_flash_panel)


## 设置屏幕震动目标（通常是交易主界面根节点）
func set_shake_target(target: Control) -> void:
	_shake_target = target
	if target:
		_original_position = target.position


## 盈利特效: 绿色数字飘升
func play_profit_effect(amount: float, position: Vector2) -> void:
	var label := _create_float_label("+$%.0f" % amount, Color(0.2, 0.9, 0.3))
	label.position = position
	_float_container.add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", position.y - 80, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.2).set_delay(0.3)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)


## 亏损特效: 红色数字飘落
func play_loss_effect(amount: float, position: Vector2) -> void:
	var label := _create_float_label("-$%.0f" % absf(amount), Color(0.9, 0.2, 0.1))
	label.position = position
	_float_container.add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", position.y + 60, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.2)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)


## 撤离成功: 全屏金色粒子 + 文字
func play_extraction_success() -> void:
	# 金色闪烁
	_flash_panel.color = Color(1.0, 0.85, 0.2, 0.4)
	_flash_panel.visible = true
	var flash_tween := create_tween()
	flash_tween.tween_property(_flash_panel, "color:a", 0.0, 0.8).set_trans(Tween.TRANS_CUBIC)
	flash_tween.tween_callback(func() -> void: _flash_panel.visible = false)

	# 大字提示
	var banner := _create_float_label("撤离成功!", Color(1.0, 0.85, 0.2))
	banner.add_theme_font_size_override("font_size", 48)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_preset(Control.PRESET_CENTER)
	_float_container.add_child(banner)
	var tween := create_tween()
	tween.tween_property(banner, "scale", Vector2(1.3, 1.3), 0.3).set_trans(Tween.TRANS_BACK)
	tween.tween_property(banner, "scale", Vector2(1.0, 1.0), 0.2)
	tween.tween_interval(1.5)
	tween.tween_property(banner, "modulate:a", 0.0, 0.5)
	tween.tween_callback(banner.queue_free)

	# 金色粒子（简单模拟）
	_spawn_gold_particles(20)


## 爆仓: 屏幕震动 + 红色闪烁
func play_bust_effect() -> void:
	# 红色闪烁
	_flash_panel.color = Color(0.9, 0.1, 0.1, 0.5)
	_flash_panel.visible = true
	var flash_tween := create_tween()
	for i in range(3):
		flash_tween.tween_property(_flash_panel, "color:a", 0.5, 0.1)
		flash_tween.tween_property(_flash_panel, "color:a", 0.0, 0.1)
	flash_tween.tween_callback(func() -> void: _flash_panel.visible = false)

	# 屏幕震动
	_play_screen_shake(0.5, 8.0)

	# 爆仓文字
	var banner := _create_float_label("爆仓!", Color(0.9, 0.2, 0.1))
	banner.add_theme_font_size_override("font_size", 56)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_preset(Control.PRESET_CENTER)
	_float_container.add_child(banner)
	var tween := create_tween()
	tween.tween_property(banner, "scale", Vector2(1.5, 1.5), 0.2).set_trans(Tween.TRANS_BACK)
	tween.tween_property(banner, "scale", Vector2(1.0, 1.0), 0.15)
	tween.tween_interval(2.0)
	tween.tween_property(banner, "modulate:a", 0.0, 0.5)
	tween.tween_callback(banner.queue_free)


## Boss 入场: 横幅 + 音效
func play_boss_entrance(boss_name: String) -> void:
	# 暗化背景
	_flash_panel.color = Color(0.0, 0.0, 0.0, 0.6)
	_flash_panel.visible = true
	var dim_tween := create_tween()
	dim_tween.tween_property(_flash_panel, "color:a", 0.6, 0.3)

	# Boss 横幅
	var banner_container := VBoxContainer.new()
	banner_container.set_anchors_preset(Control.PRESET_CENTER)
	banner_container.position -= Vector2(200, 40)
	banner_container.custom_minimum_size = Vector2(400, 80)
	_float_container.add_child(banner_container)

	var title_label := Label.new()
	title_label.text = "⚠ BOSS 入场 ⚠"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.1))
	banner_container.add_child(title_label)

	var name_label := Label.new()
	name_label.text = boss_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 36)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	banner_container.add_child(name_label)

	# 动画: 从左侧滑入
	banner_container.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(banner_container, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.5)
	# 淡出并恢复
	tween.tween_property(banner_container, "modulate:a", 0.0, 0.5)
	tween.tween_property(_flash_panel, "color:a", 0.0, 0.3)
	tween.tween_callback(func() -> void:
		_flash_panel.visible = false
		banner_container.queue_free()
	)


## 屏幕震动
func _play_screen_shake(duration: float, intensity: float) -> void:
	if not _shake_target:
		return
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	var steps := int(duration / 0.05)
	for i in range(steps):
		var offset := Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		_shake_tween.tween_property(_shake_target, "position", _original_position + offset, 0.05)
	_shake_tween.tween_property(_shake_target, "position", _original_position, 0.05)


## 创建飘字标签
func _create_float_label(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## 简单金色粒子模拟（使用 Label 节点）
func _spawn_gold_particles(count: int) -> void:
	for i in range(count):
		var particle := Label.new()
		particle.text = "✦"
		particle.add_theme_font_size_override("font_size", randi_range(16, 32))
		particle.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 0.8))
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var start_x := randf_range(100.0, 700.0)
		var start_y := randf_range(200.0, 500.0)
		particle.position = Vector2(start_x, start_y)
		_float_container.add_child(particle)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position:y", start_y - randf_range(60.0, 150.0), randf_range(0.8, 1.5)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "position:x", start_x + randf_range(-40.0, 40.0), randf_range(0.8, 1.5))
		tween.tween_property(particle, "modulate:a", 0.0, randf_range(0.8, 1.5)).set_delay(0.3)
		tween.set_parallel(false)
		tween.tween_callback(particle.queue_free)
