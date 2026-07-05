## K 线图表渲染
## 所有权: WS5 (客户端 UI 组)
## 使用 Line2D 绘制价格走势
extends Control
class_name KLineChart

var _line: Line2D = null
var _price_data: Array[float] = []
var _max_visible_points: int = 200
var _bg_color: Color = Color(0.08, 0.08, 0.12)
var _line_color: Color = Color(0.0, 0.8, 0.4)


func _ready() -> void:
	_line = Line2D.new()
	_line.width = 2.0
	_line.default_color = _line_color
	add_child(_line)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _bg_color)


## 添加价格点
func add_price_point(price: float) -> void:
	_price_data.append(price)
	if _price_data.size() > _max_visible_points:
		_price_data.pop_front()
	_rebuild_line()


## 批量设置价格历史
func set_price_history(history: Array[float]) -> void:
	_price_data = history.duplicate()
	if _price_data.size() > _max_visible_points:
		_price_data = _price_data.slice(_price_data.size() - _max_visible_points)
	_rebuild_line()


## 清空数据
func clear() -> void:
	_price_data.clear()
	_line.clear_points()


## 重建 Line2D 顶点
func _rebuild_line() -> void:
	_line.clear_points()
	if _price_data.size() < 2:
		return
	var min_price := _price_data[0]
	var max_price := _price_data[0]
	for p in _price_data:
		min_price = minf(min_price, p)
		max_price = maxf(max_price, p)
	var price_range := maxf(max_price - min_price, 0.01)
	var step_x := size.x / maxf(_price_data.size() - 1, 1)
	for i in range(_price_data.size()):
		var x := i * step_x
		var y := size.y - ((_price_data[i] - min_price) / price_range) * size.y * 0.8 - size.y * 0.1
		_line.add_point(Vector2(x, y))
