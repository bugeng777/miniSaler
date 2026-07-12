## 分析类技能效果实现
## 所有权: WS2 (游戏玩法组)
## 5 个分析类技能：news_reader / trend_insight / sentiment_sense / fundamental_scan / whale_tracker
## 依赖 WS1 MarketEngine 提供市场数据
class_name AnalysisSkills
extends RefCounted


## 新闻速读：减少信息延迟秒数
## 由 SkillSystem 的 passive_effects_changed 信号传递给 NewsSystem
## NewsSystem 读取 modifiers["news_reader"] 减少 info_delay
static func apply_news_reader(base_value: float, level: int) -> Dictionary:
	var effective := base_value * (1.0 + (level - 1) * Constants.SKILL_LEVEL_BONUS)
	return {
		"effect_type": "market_data",
		"action": "reduce_info_delay",
		"delay_reduction": effective,  ## 减少的秒数
	}


## 趋势洞察（主动）：计算并返回短期 MA 交叉信号
## 需要 WS1 提供 price_history，WS5 显示交叉标记
static func apply_trend_insight(price_history: Array, base_value: float, level: int) -> Dictionary:
	if price_history.size() < 10:
		return {"effect_type": "market_data", "action": "trend_signal", "signal": "insufficient_data"}
	# 短期 MA (5) vs 长期 MA (10)
	var short_window := mini(5, price_history.size())
	var long_window := mini(10, price_history.size())
	var short_ma := 0.0
	var long_ma := 0.0
	for i in range(price_history.size() - short_window, price_history.size()):
		short_ma += price_history[i]
	short_ma /= short_window
	for i in range(price_history.size() - long_window, price_history.size()):
		long_ma += price_history[i]
	long_ma /= long_window
	var signal_str := "neutral"
	if short_ma > long_ma * 1.001:
		signal_str = "golden_cross"  ## 金叉：短期上穿长期
	elif short_ma < long_ma * 0.999:
		signal_str = "death_cross"   ## 死叉：短期下穿长期
	return {
		"effect_type": "market_data",
		"action": "trend_signal",
		"signal": signal_str,
		"short_ma": short_ma,
		"long_ma": long_ma,
	}


## 情绪感知：返回当前恐贪指数显示权限
## 由 passive_effects_changed 传递，WS5 据此显示/隐藏恐贪指数 UI
static func apply_sentiment_sense(base_value: float) -> Dictionary:
	return {
		"effect_type": "ui_display",
		"action": "show_sentiment_index",
		"visible": base_value >= 1.0,
	}


## 基本面扫描：请求内在价值估算数据
## 需要 WS1 MarketEngine 提供 intrinsic_value 字段
static func apply_fundamental_scan(symbol: StringName, current_price: float,
		intrinsic_value: float) -> Dictionary:
	var deviation := 0.0
	if intrinsic_value > 0.0:
		deviation = (current_price - intrinsic_value) / intrinsic_value
	var assessment := "fair"
	if deviation > 0.15:
		assessment = "overvalued"
	elif deviation < -0.15:
		assessment = "undervalued"
	return {
		"effect_type": "market_data",
		"action": "fundamental_data",
		"symbol": symbol,
		"current_price": current_price,
		"intrinsic_value": intrinsic_value,
		"deviation": deviation,
		"assessment": assessment,
	}


## 庄家追踪（主动）：请求大户持仓变动数据
## 需要 WS1 提供大户持仓变化，WS5 显示变动热力图
static func apply_whale_tracker(whale_data: Array, base_value: float, level: int) -> Dictionary:
	var effective := base_value * (1.0 + (level - 1) * Constants.SKILL_LEVEL_BONUS)
	return {
		"effect_type": "market_data",
		"action": "whale_movements",
		"top_n": int(effective),  ## 显示前 N 个大户变动
		"data": whale_data,       ## WS1 填充的数据
	}
