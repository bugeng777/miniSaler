## 新闻滚动条
## 所有权: WS5 (客户端 UI 组)
extends PanelContainer
class_name NewsTicker

var _label: Label = null
var _news_queue: Array[String] = []
var _current_index: int = 0


func _ready() -> void:
	_label = Label.new()
	_label.text = "等待新闻..."
	add_child(_label)


func add_news(text: String) -> void:
	_news_queue.append(text)
	if _news_queue.size() > 50:
		_news_queue.pop_front()
	_label.text = text
