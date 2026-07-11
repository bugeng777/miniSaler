## 成就解锁 Toast 弹窗
## 所有权: WS5 (客户端 UI 组)
## 成就解锁时右上角弹出 Toast + 音效，3 秒后淡出
extends CanvasLayer
class_name AchievementToast

## Toast 队列（同时只显示一个）
var _toast_queue: Array[Dictionary] = []
var _is_showing: bool = false

## 当前 Toast 节点
var _current_toast: PanelContainer = null

## 音效引用（可选，由外部注入）
var _sfx_manager = null  ## SfxManager 引用


func _ready() -> void:
	layer = 12  # 在所有 UI 之上


## 设置音效管理器引用
func set_sfx_manager(manager) -> void:
	_sfx_manager = manager


## 显示成就 Toast
func show_achievement(title: String, description: String) -> void:
	_toast_queue.append({"title": title, "description": description})
	if not _is_showing:
		_show_next_toast()


## 显示队列中的下一个 Toast
func _show_next_toast() -> void:
	if _toast_queue.is_empty():
		_is_showing = false
		return

	_is_showing = true
	var data: Dictionary = _toast_queue.pop_front()

	# 创建 Toast 面板
	_current_toast = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.22, 0.95)
	style.border_color = Color(1.0, 0.85, 0.2, 0.8)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	_current_toast.add_theme_stylebox_override("panel", style)

	# 内容布局
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_current_toast.add_child(vbox)

	# 成就图标 + 标题行
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	var icon := Label.new()
	icon.text = "🏆"
	icon.add_theme_font_size_override("font_size", 24)
	header.add_child(icon)

	var title_label := Label.new()
	title_label.text = "成就解锁!"
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	header.add_child(title_label)

	# 成就名称
	var name_label := Label.new()
	name_label.text = data.get("title", "")
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	vbox.add_child(name_label)

	# 成就描述
	var desc_label := Label.new()
	desc_label.text = data.get("description", "")
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(desc_label)

	# 定位: 右上角
	add_child(_current_toast)
	_current_toast.position = Vector2(550, -100)  # 从屏幕外滑入

	# 播放音效
	_play_achievement_sound()

	# 动画: 滑入 → 停留 → 淡出
	var tween := create_tween()
	# 滑入
	tween.tween_property(_current_toast, "position:y", 20.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 停留 3 秒
	tween.tween_interval(3.0)
	# 淡出 + 上移
	tween.set_parallel(true)
	tween.tween_property(_current_toast, "modulate:a", 0.0, 0.5)
	tween.tween_property(_current_toast, "position:y", -20.0, 0.5)
	tween.set_parallel(false)
	tween.tween_callback(_on_toast_finished)


## Toast 显示完毕回调
func _on_toast_finished() -> void:
	if _current_toast and is_instance_valid(_current_toast):
		_current_toast.queue_free()
		_current_toast = null
	_show_next_toast()


## 播放成就音效
func _play_achievement_sound() -> void:
	if _sfx_manager and _sfx_manager.has_method("play_sfx"):
		# 使用 WINDOW_OPEN 音效作为成就音效（短促提示音）
		_sfx_manager.play_sfx(_sfx_manager.SfxType.WINDOW_OPEN)
