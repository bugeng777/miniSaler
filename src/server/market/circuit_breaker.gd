## 熔断机制
## 所有权: WS1 (市场引擎组)
## 当股票价格偏离开盘价超过阈值时，暂停该股票交易
## 参考: PRD §9.5 熔断阈值 ±15%, 熔断时长 30s
extends RefCounted
class_name CircuitBreaker


## 熔断状态
class BreakerState:
	var symbol: StringName = &""
	var open_price: float = 0.0
	var is_broken: bool = false
	var remaining_time: float = 0.0
	var trigger_count: int = 0  ## 本局触发次数

signal breaker_triggered(symbol: StringName, duration: float)
signal breaker_cleared(symbol: StringName)

var _states: Dictionary = {}  ## symbol -> BreakerState


## 初始化
func initialize(stock_configs: Array[Dictionary]) -> void:
	_states.clear()
	for cfg in stock_configs:
		var state := BreakerState.new()
		state.symbol = StringName(cfg.get("symbol", ""))
		state.open_price = cfg.get("base_price", 100.0)
		_states[state.symbol] = state


## 每 tick 检查是否需要熔断
func check_and_update(current_prices: Dictionary, delta: float) -> void:
	for symbol in _states:
		var state: BreakerState = _states[symbol]
		if state.is_broken:
			# 倒计时
			state.remaining_time -= delta
			if state.remaining_time <= 0.0:
				state.is_broken = false
				state.remaining_time = 0.0
				breaker_cleared.emit(symbol)
		else:
			if current_prices.has(symbol) and state.open_price > 0.0:
				var deviation := absf(current_prices[symbol] - state.open_price) / state.open_price
				if deviation >= Constants.CIRCUIT_BREAKER_THRESHOLD:
					state.is_broken = true
					state.remaining_time = Constants.CIRCUIT_BREAKER_DURATION
					state.trigger_count += 1
					breaker_triggered.emit(symbol, Constants.CIRCUIT_BREAKER_DURATION)


## 检查股票是否处于熔断状态
func is_circuit_broken(symbol: StringName) -> bool:
	if _states.has(symbol):
		var state: BreakerState = _states[symbol]
		return state.is_broken
	return false


## 获取熔断剩余时间
func get_remaining_time(symbol: StringName) -> float:
	if _states.has(symbol):
		var state: BreakerState = _states[symbol]
		return state.remaining_time
	return 0.0


## 获取所有股票的熔断状态（供 GameSession 每 tick 广播）
## 返回格式: {symbol: {"is_broken": bool, "remaining": float, "trigger_count": int}}
func get_all_states() -> Dictionary:
	var result: Dictionary = {}
	for symbol in _states:
		var state: BreakerState = _states[symbol]
		result[symbol] = {
			"is_broken": state.is_broken,
			"remaining": state.remaining_time,
			"trigger_count": state.trigger_count,
		}
	return result


## 重置（新一局）
func reset() -> void:
	_states.clear()
