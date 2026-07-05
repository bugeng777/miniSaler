## 价格形成模型
## 所有权: WS1 (市场引擎组)
## 实现 GARCH + 均值回归 + 动量 + 漂移的价格模拟算法
## 参考: modelDesign.md Ch.11 价格形成机制
extends RefCounted
class_name PriceModel


## 单只股票的价格状态
class StockPriceState:
	var symbol: StringName = &""
	var current_price: float = 0.0
	var open_price: float = 0.0
	var high_price: float = 0.0
	var low_price: float = 0.0
	var volume: float = 0.0
	var base_volatility: float = 0.02
	var current_volatility: float = 0.02  ## GARCH 动态波动率
	var drift: float = 0.0                ## 漂移率（趋势方向）
	var momentum: float = 0.0             ## 动量（短期趋势惯性）
	var mean_reversion_target: float = 0.0  ## 均值回归目标价
	var price_history: Array[float] = []    ## 价格历史（用于MA计算）
	var garch_variance: float = 0.0004      ## GARCH 条件方差

	func reset(base_price: float, base_vol: float) -> void:
		current_price = base_price
		open_price = base_price
		high_price = base_price
		low_price = base_price
		volume = 0.0
		base_volatility = base_vol
		current_volatility = base_vol
		drift = randf_range(-0.001, 0.001)
		momentum = 0.0
		mean_reversion_target = base_price
		price_history.clear()
		price_history.append(base_price)
		garch_variance = base_vol * base_vol


## GARCH(1,1) 参数
const GARCH_OMEGA: float = 0.00001   ## 常数项
const GARCH_ALPHA: float = 0.1       ## ARCH 项系数（冲击反应）
const GARCH_BETA: float = 0.85       ## GARCH 项系数（波动持续性）

## 均值回归参数
const MEAN_REVERSION_SPEED: float = 0.005  ## 回归速度
const MEAN_REVERSION_THRESHOLD: float = 0.20  ## 偏离基准价 20% 时触发

## 动量参数
const MOMENTUM_DECAY: float = 0.95  ## 动量衰减系数
const MOMENTUM_IMPACT: float = 0.3  ## 动量对价格的影响权重

## 股票状态表
var _states: Dictionary = {}  ## symbol -> StockPriceState


## 初始化股票池
func initialize_stocks(stock_configs: Array[Dictionary]) -> void:
	_states.clear()
	for cfg in stock_configs:
		var state := StockPriceState.new()
		state.symbol = StringName(cfg.get("symbol", ""))
		state.reset(
			cfg.get("base_price", 100.0),
			cfg.get("volatility", 0.02)
		)
		_states[state.symbol] = state


## 执行一次 tick 的价格模拟
## 返回所有股票的快照数组
func simulate_tick(volatility_multiplier: float = 1.0,
		news_impacts: Dictionary = {}) -> Array[MarketTypes.StockSnapshot]:
	var snapshots: Array[MarketTypes.StockSnapshot] = []
	for symbol in _states:
		var state: StockPriceState = _states[symbol]
		# 应用新闻冲击
		if news_impacts.has(symbol):
			_apply_news_impact(state, news_impacts[symbol])
		# GARCH 波动率更新
		_update_garch(state, volatility_multiplier)
		# 均值回归
		_apply_mean_reversion(state)
		# 动量更新
		_update_momentum(state)
		# 价格演化（GBM + 漂移 + 动量）
		_evolve_price(state)
		# 构建快照
		snapshots.append(_build_snapshot(state))
	return snapshots


## GARCH(1,1) 波动率更新
func _update_garch(state: StockPriceState, vol_multiplier: float) -> void:
	var returns := 0.0
	if state.price_history.size() >= 2:
		var prev := state.price_history[state.price_history.size() - 2]
		if prev > 0.0:
			returns = (state.current_price - prev) / prev
	# GARCH(1,1): sigma^2_t = omega + alpha * r^2_{t-1} + beta * sigma^2_{t-1}
	state.garch_variance = GARCH_OMEGA + GARCH_ALPHA * returns * returns + GARCH_BETA * state.garch_variance
	state.current_volatility = sqrt(state.garch_variance) * vol_multiplier
	# 限制波动率范围
	state.current_volatility = clampf(state.current_volatility, 0.001, 0.1)


## 均值回归力
func _apply_mean_reversion(state: StockPriceState) -> void:
	var deviation := (state.current_price - state.mean_reversion_target) / state.mean_reversion_target
	if absf(deviation) > MEAN_REVERSION_THRESHOLD:
		# 偏离过大，施加回归力
		var reversion_force := -deviation * MEAN_REVERSION_SPEED
		state.drift += reversion_force


## 动量更新
func _update_momentum(state: StockPriceState) -> void:
	# 基于最近 N 个 tick 的价格变化计算动量
	if state.price_history.size() >= 5:
		var recent_start := state.price_history[maxi(0, state.price_history.size() - 5)]
		var recent_end := state.current_price
		if recent_start > 0.0:
			var short_return := (recent_end - recent_start) / recent_start
			state.momentum = state.momentum * MOMENTUM_DECAY + short_return * (1.0 - MOMENTUM_DECAY)
	else:
		state.momentum *= MOMENTUM_DECAY


## GBM 价格演化
func _evolve_price(state: StockPriceState) -> void:
	var random_shock := randfn(0.0, state.current_volatility)
	var momentum_effect := state.momentum * MOMENTUM_IMPACT
	var price_change := state.drift + momentum_effect + random_shock
	var new_price := state.current_price * (1.0 + price_change)
	# 价格不能为负
	new_price = maxf(new_price, 0.01)
	# 更新状态
	state.price_history.append(new_price)
	# 限制历史长度（保留最近 500 个 tick）
	if state.price_history.size() > 500:
		state.price_history.pop_front()
	state.current_price = new_price
	state.high_price = maxf(state.high_price, new_price)
	state.low_price = minf(state.low_price, new_price)
	state.volume += randf_range(50.0, 500.0)  # 模拟成交量
	# 漂移缓慢随机游走
	state.drift += randfn(0.0, 0.0005)
	state.drift = clampf(state.drift, -0.01, 0.01)


## 应用新闻冲击
func _apply_news_impact(state: StockPriceState, impact: Dictionary) -> void:
	var impact_type: int = impact.get("type", GameEnums.NewsImpact.PRICE_JUMP)
	var magnitude: float = impact.get("magnitude", 0.0)
	var sentiment: int = impact.get("sentiment", GameEnums.NewsSentiment.NEUTRAL)
	var direction := 1.0 if sentiment == GameEnums.NewsSentiment.POSITIVE else -1.0

	match impact_type:
		GameEnums.NewsImpact.PRICE_JUMP:
			# 价格跳变：直接偏移价格
			state.current_price *= (1.0 + direction * magnitude)
			state.drift += direction * magnitude * 0.1
		GameEnums.NewsImpact.VOLATILITY_SPIKE:
			# 波动率飙升：临时提高波动率
			state.current_volatility *= (1.0 + magnitude)
			state.garch_variance *= (1.0 + magnitude * 2.0)


## 构建快照
func _build_snapshot(state: StockPriceState) -> MarketTypes.StockSnapshot:
	var snap := MarketTypes.StockSnapshot.new()
	snap.symbol = state.symbol
	snap.open = state.open_price
	snap.high = state.high_price
	snap.low = state.low_price
	snap.close = state.current_price
	snap.volume = state.volume
	snap.volatility = state.current_volatility
	snap.drift = state.drift
	snap.momentum = state.momentum
	return snap


## 获取单只股票当前价格
func get_price(symbol: StringName) -> float:
	if _states.has(symbol):
		var state: StockPriceState = _states[symbol]
		return state.current_price
	return 0.0


## 获取所有股票当前价格
func get_all_prices() -> Dictionary:
	var prices: Dictionary = {}
	for symbol in _states:
		var state: StockPriceState = _states[symbol]
		prices[symbol] = state.current_price
	return prices


## 获取股票价格历史（用于 K 线绘制）
func get_price_history(symbol: StringName) -> Array[float]:
	if _states.has(symbol):
		var state: StockPriceState = _states[symbol]
		return state.price_history
	return []


## 计算恐惧贪婪指数 (0-100, 50=中性)
func calculate_fear_greed_index() -> float:
	var total_momentum := 0.0
	var total_vol_change := 0.0
	var count := 0
	for symbol in _states:
		var state: StockPriceState = _states[symbol]
		total_momentum += state.momentum
		if state.base_volatility > 0.0:
			total_vol_change += (state.current_volatility - state.base_volatility) / state.base_volatility
		count += 1
	if count == 0:
		return 50.0
	# 动量正值=贪婪，负值=恐惧
	var momentum_score := clampf(total_momentum / count * 500.0, -25.0, 25.0)
	# 波动率上升=恐惧
	var vol_score := clampf(-total_vol_change / count * 25.0, -25.0, 25.0)
	return clampf(50.0 + momentum_score + vol_score, 0.0, 100.0)
