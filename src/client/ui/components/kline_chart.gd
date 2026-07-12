## 像素 K 线图：整数网格绘制实体、影线和虚线网格，不使用 Line2D/抗锯齿。
extends Control
class_name KLineChart


const MIN_CANDLE_WIDTH := 3
const MAX_CANDLE_WIDTH := 10
const CANDLE_GAP := 2
const CHART_PADDING := 8.0

var _candles: Array[Dictionary] = []
var _candle_width: int = 5
var _max_visible_candles: int = 48


func _ready() -> void:
	custom_minimum_size = Vector2(160, 180)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PixelTheme.BG_PANEL)
	_draw_grid()
	if _candles.is_empty():
		_draw_empty_state()
		return
	var visible_count := mini(_candles.size(), _visible_capacity())
	var visible := _candles.slice(_candles.size() - visible_count)
	var bounds := _price_bounds(visible)
	var start_x := floori(size.x - CHART_PADDING - visible_count * (_candle_width + CANDLE_GAP))
	for i in range(visible.size()):
		_draw_candle(visible[i], start_x + i * (_candle_width + CANDLE_GAP), bounds)


func add_candle(candle: Dictionary) -> void:
	var close_price := float(candle.get("close", 0.0))
	if close_price <= 0.0:
		return
	var open_price := float(candle.get("open", close_price))
	var high_price := maxf(float(candle.get("high", close_price)), maxf(open_price, close_price))
	var low_price := minf(float(candle.get("low", close_price)), minf(open_price, close_price))
	_candles.append({"open": open_price, "high": high_price, "low": low_price, "close": close_price})
	if _candles.size() > _max_visible_candles:
		_candles.pop_front()
	queue_redraw()


## 兼容旧接口：仅有价格时用前一收盘价生成一根最小 OHLC。
func add_price_point(price: float) -> void:
	var previous := price
	if not _candles.is_empty():
		previous = float(_candles.back().get("close", price))
	add_candle({"open": previous, "high": maxf(previous, price),
		"low": minf(previous, price), "close": price})


func set_price_history(history: Array[float]) -> void:
	_candles.clear()
	for price in history:
		add_price_point(price)
	queue_redraw()


func clear() -> void:
	_candles.clear()
	queue_redraw()


func _draw_grid() -> void:
	for row in range(1, 5):
		var y := floorf(size.y * row / 5.0)
		for x in range(0, int(size.x), 8):
			draw_rect(Rect2(x, y, 4, 1), Color(PixelTheme.TEXT_DIM, 0.65))
	for column in range(1, 5):
		var x := floorf(size.x * column / 5.0)
		for y in range(0, int(size.y), 8):
			draw_rect(Rect2(x, y, 1, 4), Color(PixelTheme.TEXT_DIM, 0.35))


func _draw_empty_state() -> void:
	var center := (size * 0.5).floor()
	for i in range(5):
		var height := 8 + i * 5
		draw_rect(Rect2(center.x - 25 + i * 12, center.y - height * 0.5,
			6, height), Color(PixelTheme.TEXT_DIM, 0.55))


func _draw_candle(candle: Dictionary, x: int, bounds: Vector2) -> void:
	var open_y := _price_to_y(float(candle.open), bounds)
	var close_y := _price_to_y(float(candle.close), bounds)
	var high_y := _price_to_y(float(candle.high), bounds)
	var low_y := _price_to_y(float(candle.low), bounds)
	var is_up := float(candle.close) >= float(candle.open)
	var color := PixelTheme.COLOR_UP if is_up else PixelTheme.COLOR_DOWN
	var center_x := x + floori(_candle_width * 0.5)
	draw_rect(Rect2(center_x, high_y, 1, maxf(low_y - high_y + 1, 1)), color)
	var body_top := mini(open_y, close_y)
	var body_height := maxi(abs(close_y - open_y), 2)
	draw_rect(Rect2(x, body_top, _candle_width, body_height), color)
	# 1 px 高光/暗边让实体保持 RPG 方块立体感。
	draw_rect(Rect2(x, body_top, _candle_width, 1), color.lightened(0.28))
	draw_rect(Rect2(x, body_top + body_height - 1, _candle_width, 1), color.darkened(0.35))


func _price_bounds(candles: Array) -> Vector2:
	var min_price := INF
	var max_price := -INF
	for candle in candles:
		min_price = minf(min_price, float(candle.low))
		max_price = maxf(max_price, float(candle.high))
	var padding := maxf((max_price - min_price) * 0.08, 0.01)
	return Vector2(min_price - padding, max_price + padding)


func _price_to_y(price: float, bounds: Vector2) -> int:
	var usable_height := maxf(size.y - CHART_PADDING * 2.0, 1.0)
	var ratio := (price - bounds.x) / maxf(bounds.y - bounds.x, 0.01)
	return roundi(size.y - CHART_PADDING - ratio * usable_height)


func _visible_capacity() -> int:
	return maxi(int((size.x - CHART_PADDING * 2.0) / (_candle_width + CANDLE_GAP)), 1)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_candle_width = mini(_candle_width + 1, MAX_CANDLE_WIDTH)
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_candle_width = maxi(_candle_width - 1, MIN_CANDLE_WIDTH)
			queue_redraw()
