## 像素新闻条：50ms 逐字硬切显示，无平滑滚动。
extends PanelContainer
class_name NewsTicker


var _label: Label = null
var _typing_timer: Timer = null
var _target_text: String = ""
var _visible_characters: int = 0
var _news_queue: Array[String] = []


func _ready() -> void:
	add_theme_stylebox_override("panel", PixelTheme.create_simple_panel())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	var icon := PixelIcon.new()
	icon.icon_type = PixelIcon.Icon.NEWS
	icon.pixel_size = 1
	row.add_child(icon)
	_label = Label.new()
	_label.text = "等待新闻_"
	_label.clip_text = true
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_label)
	_typing_timer = Timer.new()
	_typing_timer.wait_time = 0.05
	_typing_timer.timeout.connect(_type_next_character)
	add_child(_typing_timer)


func add_news(text: String) -> void:
	_news_queue.append(text)
	if _news_queue.size() > 50:
		_news_queue.pop_front()
	_target_text = text
	_visible_characters = 0
	_label.text = "_"
	_typing_timer.start()


func _type_next_character() -> void:
	_visible_characters += 1
	_label.text = _target_text.left(_visible_characters)
	if _visible_characters < _target_text.length():
		_label.text += "_"
	else:
		_typing_timer.stop()
