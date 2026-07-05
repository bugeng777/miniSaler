## 交易主界面（竖屏三栏布局）
## 所有权: WS5 (客户端 UI 组)
## 左栏: 股票列表 | 中栏: K线+交易面板 | 右栏: 持仓+排行
extends Control
class_name TradingScreen

var _top_bar: TopBar = null
var _stock_list: VBoxContainer = null
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
	# 顶栏
	_top_bar = TopBar.new()
	_top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top_bar.custom_minimum_size = Vector2(0, 50)
	add_child(_top_bar)

	# 三栏布局
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.position.y = 50
	hbox.size.y -= 80  # 底部留空间给新闻栏
	add_child(hbox)

	# 左栏：股票列表
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(150, 0)
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 0.15
	hbox.add_child(left_panel)
	_stock_list = VBoxContainer.new()
	left_panel.add_child(_stock_list)

	# 中栏：K线 + 交易面板
	var center_panel := VBoxContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_stretch_ratio = 0.55
	hbox.add_child(center_panel)
	_kline_chart = KLineChart.new()
	_kline_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_kline_chart.custom_minimum_size = Vector2(0, 300)
	center_panel.add_child(_kline_chart)
	_order_panel = OrderPanel.new()
	_order_panel.custom_minimum_size = Vector2(0, 150)
	center_panel.add_child(_order_panel)
	_skill_bar = SkillBar.new()
	_skill_bar.custom_minimum_size = Vector2(0, 40)
	center_panel.add_child(_skill_bar)

	# 右栏：持仓 + 排行
	var right_panel := VBoxContainer.new()
	right_panel.custom_minimum_size = Vector2(180, 0)
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 0.3
	hbox.add_child(right_panel)
	_portfolio_view = PortfolioView.new()
	_portfolio_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(_portfolio_view)
	_leaderboard_view = LeaderboardView.new()
	_leaderboard_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(_leaderboard_view)

	# 底部新闻栏
	_news_ticker = NewsTicker.new()
	_news_ticker.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_news_ticker.custom_minimum_size = Vector2(0, 30)
	_news_ticker.position.y -= 30
	add_child(_news_ticker)

	# 撤离面板（浮动）
	_extraction_panel = ExtractionPanel.new()
	_extraction_panel.position = Vector2(500, 500)
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
				_kline_chart.add_price_point(snap.get("close", 0.0))
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
			btn.custom_minimum_size = Vector2(140, 50)
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
