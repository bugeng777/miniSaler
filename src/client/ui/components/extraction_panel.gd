## 撤离面板（撤离按钮+倒计时+视觉反馈）
## 所有权: WS5 (客户端 UI 组)
extends PanelContainer
class_name ExtractionPanel

signal extraction_requested()

var _extract_btn: Button = null
var _countdown_label: Label = null
var _status_label: Label = null
var _is_window_open: bool = false
var _pulse_tween: Tween = null

const COLOR_OPEN := Color(0.2, 0.9, 0.3)
const COLOR_CLOSED := Color(0.4, 0.4, 0.4)
const COLOR_URGENT := Color(1.0, 0.2, 0.1)
const FONT_SIZE_NORMAL := 18
const FONT_SIZE_URGENT := 26

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)
	_status_label = Label.new()
	_status_label.text = "等待下次窗口"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", COLOR_CLOSED)
	vbox.add_child(_status_label)
	_countdown_label = Label.new()
	_countdown_label.text = ""
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override("font_size", FONT_SIZE_NORMAL)
	vbox.add_child(_countdown_label)
	_extract_btn = Button.new()
	_extract_btn.text = "撤离!"
	_extract_btn.custom_minimum_size = Vector2(150, 50)
	_extract_btn.disabled = true
	_extract_btn.pressed.connect(func() -> void: extraction_requested.emit())
	vbox.add_child(_extract_btn)
	_set_window_closed()

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
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(_extract_btn, "modulate:a", 0.6, 0.4)
	_pulse_tween.tween_property(_extract_btn, "modulate:a", 1.0, 0.4)

func _stop_pulse_animation() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null

func set_countdown(seconds: float) -> void:
	if seconds <= 0:
		_countdown_label.text = ""
		return
	_countdown_label.text = "%.0fs" % seconds
	if seconds < 5.0:
		_countdown_label.add_theme_color_override("font_color", COLOR_URGENT)
		_countdown_label.add_theme_font_size_override("font_size", FONT_SIZE_URGENT)
		_start_urgent_pulse()
	else:
		_countdown_label.add_theme_color_override("font_color", COLOR_OPEN)
		_countdown_label.add_theme_font_size_override("font_size", FONT_SIZE_NORMAL)

func _start_urgent_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		return
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(_countdown_label, "scale", Vector2(1.2, 1.2), 0.25).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_countdown_label, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_SINE)
