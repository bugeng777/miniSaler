## 市场引擎
## 所有权: WS1 (市场引擎组)
## 核心职责: 驱动 0.5s tick 循环、协调 PriceModel + OrderBook + CircuitBreaker
## 接口: 通过信号向 GameSession 输出数据，不直接引用其他子系统
extends Node
class_name MarketEngine


## ─── 信号（接口 A：MarketEngine -> GameSession）──────────────────────────
signal tick_complete(stock_snapshots: Array[MarketTypes.StockSnapshot], fear_greed_index: float)
signal circuit_breaker_triggered(symbol: StringName, duration: float)
signal market_phase_changed(phase: StringName)
## MD-04 修复：转发 OrderBook.order_filled，供 WS4 GameSession 连接（消除 OrderBook 直引）
signal order_filled_passthrough(order: MarketTypes.BookOrder, fill_price: float, fill_qty: int)

## ─── 内部组件 ──────────────────────────────────────────────────────────────
var _price_model: PriceModel = PriceModel.new()
var _order_book: OrderBook = OrderBook.new()
var _circuit_breaker: CircuitBreaker = CircuitBreaker.new()

## ─── 状态 ────────────────────────────────────────────────────────────────────
var _is_running: bool = false
var _tick_timer: Timer = null
var _tick_index: int = 0
var _elapsed_time: float = 0.0
var _current_era_config: EraData = null
var _pending_news_impacts: Dictionary = {}  ## symbol -> impact dict (由 NewsSystem 注入)
var _pending_boss_impacts: Dictionary = {}  ## symbol -> {direction, strength} (由 BotManager 注入)


func _ready() -> void:
	_tick_timer = Timer.new()
	_tick_timer.wait_time = Constants.TICK_INTERVAL
	_tick_timer.timeout.connect(_on_tick)
	add_child(_tick_timer)
	# 连接内部信号
	_circuit_breaker.breaker_triggered.connect(func(sym: StringName, dur: float) -> void:
		circuit_breaker_triggered.emit(sym, dur)
	)
	# MD-04：转发 OrderBook 成交信号，WS4 通过此信号获取成交数据
	_order_book.order_filled.connect(func(order: MarketTypes.BookOrder, fill_price: float, fill_qty: int) -> void:
		order_filled_passthrough.emit(order, fill_price, fill_qty)
	)


## 启动市场（由 GameSession 调用）
func start_market(era_config: EraData) -> void:
	_current_era_config = era_config
	_tick_index = 0
	_elapsed_time = 0.0
	_pending_news_impacts.clear()
	_pending_boss_impacts.clear()
	# 初始化子组件
	_price_model.initialize_stocks(era_config.stock_configs)
	_order_book.initialize(era_config.stock_configs)
	_circuit_breaker.initialize(era_config.stock_configs)
	# 任务 2.1: 根据时代波动特征配置 GARCH 参数
	_configure_garch_for_era(era_config)
	# 开始 tick
	_is_running = true
	_tick_timer.start()
	market_phase_changed.emit(&"trading")


## 停止市场
func stop_market() -> void:
	_is_running = false
	_tick_timer.stop()
	market_phase_changed.emit(&"closed")


## 注入新闻冲击（由 NewsSystem 通过 GameSession 中转调用）
func inject_news_impact(symbol: StringName, impact: Dictionary) -> void:
	_pending_news_impacts[symbol] = impact


## 提交订单（由 GameSession 转发玩家/Bot 的订单）
func submit_order(player_id: int, symbol: StringName, side: int,
		order_type: int, quantity: int, limit_price: float = 0.0) -> String:
	if not _is_running:
		return ""
	if _circuit_breaker.is_circuit_broken(symbol):
		return ""  # 熔断中不可交易
	return _order_book.submit_order(player_id, symbol, side, order_type, quantity, limit_price)


## 获取 OrderBook 引用（供 GameSession 读取深度等）
func get_order_book() -> OrderBook:
	return _order_book


## 获取当前所有股票快照
func get_current_snapshot() -> Dictionary:
	var prices := _price_model.get_all_prices()
	var result: Dictionary = {}
	for symbol in prices:
		result[symbol] = {
			"price": prices[symbol],
			"is_broken": _circuit_breaker.is_circuit_broken(symbol),
			"break_remaining": _circuit_breaker.get_remaining_time(symbol),
		}
	return result


## 获取价格历史
func get_price_history(symbol: StringName) -> Array[float]:
	return _price_model.get_price_history(symbol)


## ─── Phase 3 技能市场钩子（代理 PriceModel + OrderBook）──────────────

## 获取股票内在价值（供"基本面扫描"技能）
func get_intrinsic_value(symbol: StringName) -> float:
	return _price_model.get_intrinsic_value(symbol)


## 获取庄家活动（供"庄家追踪"技能）
## 返回: {"direction": int, "volume": int}
## direction: 1=大单买入为主, -1=大单卖出为主, 0=无明显方向
func get_whale_activity(symbol: StringName) -> Dictionary:
	var depth := _order_book.get_book_depth(symbol, 10)
	var bid_vol := 0
	var ask_vol := 0
	# 统计买卖两侧前 10 档的挂单量
	for level in depth.get("bids", []):
		bid_vol += level.get("quantity", 0)
	for level in depth.get("asks", []):
		ask_vol += level.get("quantity", 0)
	# 大额订单阈值: 单侧总量超过 200 股视为大户活动
	var whale_threshold := 200
	var direction := 0
	if bid_vol > whale_threshold and bid_vol > ask_vol * 1.5:
		direction = 1   # 大户买入
	elif ask_vol > whale_threshold and ask_vol > bid_vol * 1.5:
		direction = -1  # 大户卖出
	return {"direction": direction, "volume": maxi(bid_vol, ask_vol)}


## 获取 MA 交叉信号（供"趋势洞察"技能）
func get_ma_cross_signal(symbol: StringName) -> int:
	return _price_model.get_ma_cross_signal(symbol)


## 快速下单（供"闪电下单"技能，优先撮合）
func submit_order_priority(player_id: int, symbol: StringName, side: int,
		order_type: int, quantity: int, limit_price: float = 0.0) -> String:
	if not _is_running:
		return ""
	if _circuit_breaker.is_circuit_broken(symbol):
		return ""
	return _order_book.submit_order_priority(player_id, symbol, side, order_type, quantity, limit_price)


## ─── Phase 3 Boss 价格操纵 ───────────────────────────────────────────────

## Boss 价格操纵接口（由 BotManager 在 Boss 交易时调用）
## direction: 正=做多压力, 负=做空压力; strength: 操纵强度(0.0~1.0)
## 每时代 Boss 操纵不同板块: 香港=汇率/金融股, 硅谷=科技股, 东京=银行/地产, 上海=ST股
func apply_boss_manipulation(symbol: StringName, direction: float, strength: float) -> void:
	_pending_boss_impacts[symbol] = {"direction": direction, "strength": clampf(strength, 0.0, 1.0)}


## 根据时代波动特征配置 GARCH 参数
## 高波动时代（如硅谷2000 vol_mult=1.8）→ 更高基础方差 + 更强冲击反应
## 低波动时代（如首尔1988 vol_mult=0.8）→ 更平稳的价格演化
func _configure_garch_for_era(era_config: EraData) -> void:
	var vol_mult := era_config.volatility_multiplier
	# 基础方差随波动倍率平方缩放
	var omega := 0.00001 * (vol_mult * vol_mult)
	# 冲击反应随波动倍率线性增强
	var alpha := 0.1 * vol_mult
	# 波动持续性随波动倍率略微降低（高波动市场记忆更短）
	var beta := clampf(0.85 / (1.0 + (vol_mult - 1.0) * 0.2), 0.6, 0.9)
	_price_model.configure_garch(omega, alpha, beta)


## ─── 内部 tick 处理 ──────────────────────────────────────────────────────────
func _on_tick() -> void:
	if not _is_running:
		return
	_tick_index += 1
	_elapsed_time += Constants.TICK_INTERVAL

	# 1. 价格模拟（含新闻冲击）
	var vol_multiplier := 1.0
	if _current_era_config:
		vol_multiplier = _current_era_config.volatility_multiplier
	var snapshots := _price_model.simulate_tick(vol_multiplier, _pending_news_impacts)
	_pending_news_impacts.clear()

	# 1.5. 应用 Boss 价格操纵
	for boss_symbol in _pending_boss_impacts:
		var impact: Dictionary = _pending_boss_impacts[boss_symbol]
		_price_model.apply_boss_pressure(boss_symbol, impact.get("direction", 0.0), impact.get("strength", 0.0))
	_pending_boss_impacts.clear()

	# 2. 更新订单簿价格
	var prices := _price_model.get_all_prices()
	_order_book.update_prices(prices)

	# 3. 熔断检查
	_circuit_breaker.check_and_update(prices, Constants.TICK_INTERVAL)

	# 4. 将熔断状态写入快照
	for snap in snapshots:
		snap.is_circuit_broken = _circuit_breaker.is_circuit_broken(snap.symbol)
		snap.circuit_break_remaining = _circuit_breaker.get_remaining_time(snap.symbol)

	# 5. 计算恐惧贪婪指数
	var fgi := _price_model.calculate_fear_greed_index()

	# 6. 广播
	tick_complete.emit(snapshots, fgi)
