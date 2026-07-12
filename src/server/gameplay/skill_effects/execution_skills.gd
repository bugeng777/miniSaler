## 执行类技能效果实现
## 所有权: WS2 (游戏玩法组)
## 5 个执行类技能：lightning_order / auto_stop_loss / batch_trade / momentum_hunter / short_expert
## 依赖 WS3 PlayerManager 修改订单执行逻辑
class_name ExecutionSkills
extends RefCounted


## 闪电下单（主动，CD 45s，持续 3s）：交易执行速度翻倍
## WS3 收到 order_modifier 后在持续期内跳过排队/延迟
static func apply_lightning_order(base_value: float, level: int) -> Dictionary:
	var effective := base_value * (1.0 + (level - 1) * Constants.SKILL_LEVEL_BONUS)
	return {
		"effect_type": "order_modifier",
		"action": "speed_multiplier",
		"multiplier": effective,  ## 2.0x 基础速度
		"duration": 3.0,          ## 持续 3 秒
	}


## 自动止损（主动，CD 90s）：对当前选中持仓设置 -5% 止损线
## WS3 收到后在持仓上挂止损单，触发时自动市价卖出
static func apply_auto_stop_loss(symbol: StringName, entry_price: float,
		base_value: float, level: int) -> Dictionary:
	var effective := base_value * (1.0 + (level - 1) * Constants.SKILL_LEVEL_BONUS)
	var stop_price := entry_price * (1.0 - effective)
	return {
		"effect_type": "order_modifier",
		"action": "set_stop_loss",
		"symbol": symbol,
		"stop_price": stop_price,
		"trigger_pct": effective,  ## 0.05 = -5%
	}


## 批量交易（主动，CD 60s）：允许同时提交多笔订单
## WS3 收到后在单次请求中处理多笔订单而非逐笔
static func apply_batch_trade(orders: Array, base_value: float) -> Dictionary:
	return {
		"effect_type": "order_modifier",
		"action": "batch_submit",
		"orders": orders,          ## Array[Dictionary] — 多笔订单数据
		"max_orders": 5,           ## 单次最多 5 笔
	}


## 追涨猎手（主动，CD 30s）：标记最近连续上涨的股票
## WS5 收到后在 K 线上显示上涨标记
static func apply_momentum_hunter(price_histories: Dictionary, base_value: float,
		level: int) -> Dictionary:
	var effective := int(base_value * (1.0 + (level - 1) * Constants.SKILL_LEVEL_BONUS))
	var rising_stocks: Array[StringName] = []
	for symbol in price_histories:
		var history: Array = price_histories[symbol]
		if history.size() < effective:
			continue
		var recent: Array = history.slice(history.size() - effective)
		var is_rising := true
		for i in range(1, recent.size()):
			if recent[i] <= recent[i - 1]:
				is_rising = false
				break
		if is_rising:
			rising_stocks.append(StringName(symbol))
	return {
		"effect_type": "ui_display",
		"action": "mark_momentum_stocks",
		"rising_stocks": rising_stocks,
		"streak_required": effective,  ## 连涨 N tick 才算
	}


## 做空专家（被动）：做空收益 +20%
## WS3 在结算做空盈亏时乘以额外倍率
static func apply_short_expert(base_value: float, level: int) -> Dictionary:
	var effective := base_value * (1.0 + (level - 1) * Constants.SKILL_LEVEL_BONUS)
	return {
		"effect_type": "fund_modifier",
		"action": "short_profit_bonus",
		"bonus_ratio": effective,  ## 0.2 = +20% 做空收益
	}
