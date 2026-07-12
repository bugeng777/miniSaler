## 撤离面板（撤离按钮+倒计时+视觉反馈）
## 所有权: WS5 (客户端 UI 组)
extends PanelContainer
class_name ExtractionPanel

signal extraction_requested()

var _extract_btn: Button = null
var _countdown_label: Label = null
var _status_label: Label = null
var _is_window_open: bool = false
var _blink_timer: Timer = null
var _blink_on: bool = true

# 颜色常量
const COLOR_OPEN := Color(0.2, 0.9, 0.3)     # 绿色 - 窗口开放
const COLOR_CLOSED := Color(0.4, 0.4, 0.4)    # 灰色 - 窗口关闭
const COLOR_URGENT := Color(1.0, 0.2, 0.1)    # 红色 - 倒计时紧迫
const FONT_SIZE_NORMAL := 18
const FONT_SIZE_URGENT := 26


func _ready() -> void:
	_build_ui()
	add_theme_stylebox_override("panel", PixelTheme.create_warning_panel())


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)

	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(header)
	var bolt_left := PixelIcon.new()
	bolt_left.icon_type = PixelIcon.Icon.LIGHTNING
	bolt_left.pixel_size = 1
	header.add_child(bolt_left)

	# 状态标签
	_status_label = Label.new()
	_status_label.text = "等待下次窗口"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", COLOR_CLOSED)
	header.add_child(_status_label)
	var bolt_right := PixelIcon.new()
	bolt_right.icon_type = PixelIcon.Icon.LIGHTNING
	bolt_right.pixel_size = 1
	header.add_child(bolt_right)

	# 倒计时标签
	_countdown_label = Label.new()
	_countdown_label.text = ""
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override("font_size", FONT_SIZE_NORMAL)
	vbox.add_child(_countdown_label)

	# 撤离按钮
	_extract_btn = Button.new()
	_extract_btn.text = "撤离!"
	_extract_btn.custom_minimum_size = Vector2(150, 50)
	_extract_btn.disabled = true
	_extract_btn.pressed.connect(func() -> void: extraction_requested.emit())
	vbox.add_child(_extract_btn)
	_blink_timer = Timer.new()
	_blink_timer.wait_time = 0.5
	_blink_timer.timeout.connect(_on_blink_tick)
	add_child(_blink_timer)

	# 初始状态: 窗口关闭
	_set_window_closed()


## 设置撤离窗口状态
func set_window_open(is_open: bool) -> void:
	_is_window_open = is_open
	if is_open:
		_set_window_open()
	else:
		_set_window_closed()


func _set_window_open() -> void:
	_extract_btn.disabled = false
	_extract_btn.modulate = COLOR_OPEN
	_status_label.text = "撤离窗口已开放!"
	_status_label.add_theme_color_override("font_color", COLOR_OPEN)
	# 背景闪烁动画
	_start_flash_animation()


func _set_window_closed() -> void:
	_extract_btn.disabled = true
	_extract_btn.modulate = COLOR_CLOSED
	_countdown_label.text = ""
	_status_label.text = "等待下次窗口"
	_status_label.add_theme_color_override("font_color", COLOR_CLOSED)
	_stop_pulse_animation()


func _start_flash_animation() -> void:
	_stop_pulse_animation()
	_blink_on = true
	_blink_timer.start()


func _stop_pulse_animation() -> void:
	if _blink_timer:
		_blink_timer.stop()
	_blink_on = true
	if _extract_btn:
		_extract_btn.visible = true
	if _countdown_label:
		_countdown_label.visible = true


## 更新倒计时显示
func set_countdown(seconds: float) -> void:
	if seconds <= 0:
		_countdown_label.text = ""
		return
	_countdown_label.text = "%.0fs" % seconds
	if seconds < 5.0:
		# 倒计时 < 5 秒: 红色 + 大字号 + 脉冲
		_countdown_label.add_theme_color_override("font_color", COLOR_URGENT)
		_countdown_label.add_theme_font_size_override("font_size", FONT_SIZE_URGENT)
		_start_urgent_pulse()
	else:
		_countdown_label.add_theme_color_override("font_color", COLOR_OPEN)
		_countdown_label.add_theme_font_size_override("font_size", FONT_SIZE_NORMAL)


## 紧迫脉冲动画
func _start_urgent_pulse() -> void:
	if _blink_timer.is_stopped():
		_blink_timer.start()


func _on_blink_tick() -> void:
	_blink_on = not _blink_on
	_extract_btn.visible = _blink_on
	if _countdown_label.text != "":
		_countdown_label.visible = _blink_on
