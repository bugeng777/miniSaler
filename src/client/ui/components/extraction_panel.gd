## 撤离面板（撤离按钮+倒计时）
## 所有权: WS5 (客户端 UI 组)
extends PanelContainer
class_name ExtractionPanel

signal extraction_requested()

var _extract_btn: Button = null
var _countdown_label: Label = null


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	add_child(vbox)
	_countdown_label = Label.new()
	_countdown_label.text = "撤离窗口: 15s"
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_countdown_label)
	_extract_btn = Button.new()
	_extract_btn.text = "撤离!"
	_extract_btn.custom_minimum_size = Vector2(150, 50)
	_extract_btn.pressed.connect(func() -> void: extraction_requested.emit())
	vbox.add_child(_extract_btn)


func set_countdown(seconds: float) -> void:
	_countdown_label.text = "撤离窗口: %.0fs" % seconds
