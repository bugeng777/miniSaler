## K 线图表渲染（折线 + 蜡烛图模式）
## 所有权: WS5 (客户端 UI 组)
extends Control
class_name KLineChart

enum ChartMode { LINE, CANDLE }

var _line: Line2D = null
var _price_data: Array[float] = []
var _ohlc_data: Array[Dictionary] = []
var _chart_mode: int = ChartMode.LINE
var _max_visible_points: int = 200
var _bg_color: Color = Color(0.08, 0.08, 0.12)
var _line_color: Color = Color(0.0, 0.8, 0.4)

const COLOR_BULL := Color(0.2, 0.9, 0.3)
const COLOR_BEAR := Color(0.9, 0.2, 0.1)
const COLOR_WICK := Color(0.6, 0.6, 0.6)

func _ready() -> void:
	_line = Line2D.new()
	_line.width = 2.0
	_line.default_color = _line_color
	add_child(_line)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _bg_color)
	if _chart_mode == ChartMode.CANDLE:
		_draw_candles()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_max_visible_points = maxi(_max_visible_points - 10, 20)
				queue_redraw()
				if _chart_mode == ChartMode.LINE:
					_rebuild_line()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_max_visible_points = mini(_max_visible_points + 10, 500)
				queue_redraw()
				if _chart_mode == ChartMode.LINE:
					_rebuild_line()

func set_chart_mode(mode: int) -> void:
	_chart_mode = mode
	_line.visible = (mode == ChartMode.LINE)
	queue_redraw()

func add_ohlc_point(ohlc: Dictionary) -> void:
	_ohlc_data.append(ohlc)
	if _ohlc_data.size() > _max_visible_points:
		_ohlc_data.pop_front()
	queue_redraw()

func set_ohlc_history(history: Array[Dictionary]) -> void:
	_ohlc_data = history.duplicate()
	if _ohlc_data.size() > _max_visible_points:
		_ohlc_data = _ohlc_data.slice(_ohlc_data.size() - _max_visible_points)
	queue_redraw()

func add_price_point(price: float) -> void:
	_price_data.append(price)
	if _price_data.size() > _max_visible_points:
		_price_data.pop_front()
	_rebuild_line()

func set_price_history(history: Array[float]) -> void:
	_price_data = history.duplicate()
	if _price_data.size() > _max_visible_points:
		_price_data = _price_data.slice(_price_data.size() - _max_visible_points)
	_rebuild_line()

func clear() -> void:
	_price_data.clear()
	_ohlc_data.clear()
	_line.clear_points()
	queue_redraw()

func _draw_candles() -> void:
	if _ohlc_data.size() == 0:
		return
	var min_price: float = _ohlc_data[0].get("low", 0.0)
	var max_price: float = _ohlc_data[0].get("high", 0.0)
	for ohlc in _ohlc_data:
		min_price = minf(min_price, ohlc.get("low", 0.0))
		max_price = maxf(max_price, ohlc.get("high", 0.0))
	var price_range := maxf(max_price - min_price, 0.01)
	var visible_count := mini(_ohlc_data.size(), _max_visible_points)
	var start_idx := _ohlc_data.size() - visible_count
	var candle_width := maxf(size.x / visible_count * 0.7, 2.0)
	var step_x := size.x / float(visible_count)
	var margin_y := size.y * 0.05
	var draw_height := size.y - margin_y * 2
	for i in range(visible_count):
		var ohlc: Dictionary = _ohlc_data[start_idx + i]
		var o: float = ohlc.get("open", 0.0)
		var h: float = ohlc.get("high", 0.0)
		var l: float = ohlc.get("low", 0.0)
		var c: float = ohlc.get("close", 0.0)
		var cx := i * step_x + step_x * 0.5
		var y_open := _price_to_y(o, min_price, price_range, margin_y, draw_height)
		var y_close := _price_to_y(c, min_price, price_range, margin_y, draw_height)
		var y_high := _price_to_y(h, min_price, price_range, margin_y, draw_height)
		var y_low := _price_to_y(l, min_price, price_range, margin_y, draw_height)
		var is_bull := c >= o
		var color := COLOR_BULL if is_bull else COLOR_BEAR
		draw_line(Vector2(cx, y_high), Vector2(cx, y_low), COLOR_WICK, 1.0)
		var body_top := minf(y_open, y_close)
		var body_height := maxf(absf(y_close - y_open), 1.0)
		var body_rect := Rect2(cx - candle_width * 0.5, body_top, candle_width, body_height)
		draw_rect(body_rect, color)

func _price_to_y(price: float, min_price: float, price_range: float, margin: float, draw_h: float) -> float:
	return margin + draw_h - ((price - min_price) / price_range) * draw_h

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
