## 交易主界面（竖屏三栏布局）
## 所有权: WS5 (客户端 UI 组)
## 左栏: 股票列表 | 中栏: K线+交易面板 | 右栏: 持仓+排行
extends Control
class_name TradingScreen

var _top_bar: TopBar = null
var _stock_list: HBoxContainer = null
var _kline_chart: KLineChart = null
var _order_panel: OrderPanel = null
var _extraction_panel: ExtractionPanel = null
var _portfolio_view: PortfolioView = null
var _leaderboard_view: LeaderboardView = null
var _news_ticker: NewsTicker = null
var _skill_bar: SkillBar = null
var _selected_symbol: StringName = &""


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = PixelTheme.BG_DARKEST
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	# 顶栏
	var top_panel := PanelContainer.new()
	top_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_panel.custom_minimum_size = Vector2(0, 48)
	top_panel.add_theme_stylebox_override("panel", PixelTheme.create_simple_panel())
	add_child(top_panel)
	_top_bar = TopBar.new()
	_top_bar.custom_minimum_size = Vector2(0, 48)
	top_panel.add_child(_top_bar)

	# 390×844 竖屏单列布局：图表 → 股票横条 → 交易 → 技能 → 持仓/排行。
	var main_column := VBoxContainer.new()
	main_column.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_column.offset_top = 50.0
	main_column.offset_bottom = -34.0
	main_column.add_theme_constant_override("separation", 3)
	add_child(main_column)

	var chart_panel := PanelContainer.new()
	chart_panel.add_theme_stylebox_override("panel", PixelTheme.create_simple_panel())
	chart_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart_panel.size_flags_stretch_ratio = 2.5
	main_column.add_child(chart_panel)
	_kline_chart = KLineChart.new()
	_kline_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_kline_chart.custom_minimum_size = Vector2(0, 200)
	chart_panel.add_child(_kline_chart)

	var stock_panel := PanelContainer.new()
	stock_panel.add_theme_stylebox_override("panel", PixelTheme.create_simple_panel())
	stock_panel.custom_minimum_size = Vector2(0, 58)
	main_column.add_child(stock_panel)
	var stock_scroll := ScrollContainer.new()
	stock_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	stock_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stock_panel.add_child(stock_scroll)
	_stock_list = HBoxContainer.new()
	_stock_list.add_theme_constant_override("separation", 3)
	stock_scroll.add_child(_stock_list)

	_order_panel = OrderPanel.new()
	_order_panel.custom_minimum_size = Vector2(0, 120)
	main_column.add_child(_order_panel)
	_skill_bar = SkillBar.new()
	_skill_bar.custom_minimum_size = Vector2(0, 36)
	main_column.add_child(_skill_bar)

	var bottom_row := HBoxContainer.new()
	bottom_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_row.size_flags_stretch_ratio = 1.2
	bottom_row.add_theme_constant_override("separation", 3)
	main_column.add_child(bottom_row)
	var portfolio_panel := PanelContainer.new()
	portfolio_panel.add_theme_stylebox_override("panel", PixelTheme.create_simple_panel())
	portfolio_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(portfolio_panel)
	_portfolio_view = PortfolioView.new()
	_portfolio_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portfolio_panel.add_child(_portfolio_view)
	var leaderboard_panel := PanelContainer.new()
	leaderboard_panel.add_theme_stylebox_override("panel", PixelTheme.create_simple_panel())
	leaderboard_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(leaderboard_panel)
	_leaderboard_view = LeaderboardView.new()
	_leaderboard_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	leaderboard_panel.add_child(_leaderboard_view)

	# 底部新闻栏
	_news_ticker = NewsTicker.new()
	_news_ticker.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_news_ticker.custom_minimum_size = Vector2(0, 30)
	_news_ticker.position.y -= 30
	add_child(_news_ticker)

	# 撤离面板（浮动）
	_extraction_panel = ExtractionPanel.new()
	_extraction_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_extraction_panel.offset_left = -140
	_extraction_panel.offset_right = 140
	_extraction_panel.offset_top = -190
	_extraction_panel.offset_bottom = -42
	_extraction_panel.visible = false
	add_child(_extraction_panel)

var _stock_buttons: Dictionary = {}  ## symbol -> Button
var _first_tick: bool = true


## 更新市场数据
func update_market_tick(data: Dictionary) -> void:
	if _top_bar:
		_top_bar.update_fear_greed(data.get("fear_greed_index", 50.0))
	var snapshots: Array = data.get("snapshots", [])
	_update_stock_list(snapshots)
	# 更新选中股票的 K 线
	if _selected_symbol != &"":
		for snap in snapshots:
			if snap is Dictionary and snap.get("symbol", "") == str(_selected_symbol):
				_kline_chart.add_candle(snap)
				break


## 更新股票列表
func _update_stock_list(snapshots: Array) -> void:
	if _first_tick:
		_first_tick = false
		# 首次: 创建按钮并自动选中第一只股票
		for child in _stock_list.get_children():
			child.queue_free()
		_stock_buttons.clear()
		for i in range(snapshots.size()):
			var snap: Dictionary = snapshots[i]
			var btn := Button.new()
			var sym: String = snap.get("symbol", "")
			var price: float = snap.get("close", 0.0)
			btn.text = "%s\n$%.2f" % [sym, price]
			btn.custom_minimum_size = Vector2(76, 44)
			var sn := StringName(sym)
			btn.pressed.connect(func() -> void:
				_selected_symbol = sn
				_kline_chart.clear()
			)
			_stock_list.add_child(btn)
			_stock_buttons[sn] = btn
		# 自动选中第一只
		if snapshots.size() > 0 and _selected_symbol == &"":
			_selected_symbol = StringName(snapshots[0].get("symbol", ""))
	else:
		# 后续: 只更新价格文本
		for snap in snapshots:
			if snap is Dictionary:
				var sn := StringName(snap.get("symbol", ""))
				if _stock_buttons.has(sn):
					var btn: Button = _stock_buttons[sn]
					var price: float = snap.get("close", 0.0)
					btn.text = "%s\n$%.2f" % [str(sn), price]
					btn.disabled = snap.get("is_circuit_broken", false)


## 设置新闻
func add_news(text: String) -> void:
	if _news_ticker:
		_news_ticker.add_news(text)


## 显示/隐藏撤离窗口
func set_extraction_window(is_open: bool, remaining: float) -> void:
	_extraction_panel.visible = is_open
	if is_open:
		_extraction_panel.set_countdown(remaining)


## 更新持仓
func update_portfolio(positions: Array) -> void:
	if _portfolio_view:
		_portfolio_view.update_positions(positions)


## 获取 K 线图表引用
func get_kline_chart() -> KLineChart:
	return _kline_chart


## 获取订单面板引用
func get_order_panel() -> OrderPanel:
	return _order_panel


## 获取撤离面板引用
func get_extraction_panel() -> ExtractionPanel:
	return _extraction_panel


## 获取顶栏引用
func get_top_bar() -> TopBar:
	return _top_bar


## 获取技能栏引用
func get_skill_bar() -> SkillBar:
	return _skill_bar


## 获取排行榜引用
func get_leaderboard() -> LeaderboardView:
	return _leaderboard_view


## 获取当前选中的股票符号
func get_selected_symbol() -> StringName:
	return _selected_symbol


## 设置选中的股票（供外部调用）
func select_symbol(symbol: StringName) -> void:
	_selected_symbol = symbol
	# 清空 K 线并重新加载该股票历史
	if _kline_chart:
		_kline_chart.clear()


## 重置屏幕状态（重玩时调用）
func reset_screen() -> void:
	_selected_symbol = &""
	_stock_buttons.clear()
	_first_tick = true
	if _kline_chart:
		_kline_chart.clear()
	if _extraction_panel:
		_extraction_panel.visible = false
	# 清除股票列表
	for child in _stock_list.get_children():
		child.queue_free()
