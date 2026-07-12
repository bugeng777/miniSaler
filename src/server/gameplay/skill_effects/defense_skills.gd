## 防御类技能效果实现
## 所有权: WS2 (游戏玩法组)
## 5 个防御类技能：iron_will / risk_warning / safe_harbor / diversify / cash_is_king
## 依赖 WS3 PlayerManager（资金/持仓）和 ExtractionEngine（撤离窗口）
class_name DefenseSkills
extends RefCounted


## 钢铁意志（被动）：爆仓时保留 base_value 比例的资金
## WS3 在 trigger_bust 时检查此修改器，保留部分资金
static func apply_iron_will(current_cash: float, base_value: float, level: int) -> Dictionary:
	var effective := base_value * (1.0 + (level - 1) * Constants.SKILL_LEVEL_BONUS)
	var retained := current_cash * effective
	return {
		"effect_type": "fund_modifier",
		"action": "bust_retain_funds",
		"retain_ratio": effective,   ## 0.1 = 保留 10%
		"retained_amount": retained, ## 实际保留金额
	}


## 风险预警（被动）：崩盘前 N 秒发出警报
## WS2 EraMechanicsHandler / MarketEngine 在检测到崩盘风险时通知 SkillSystem
## WS5 收到 ui_display 后显示倒计时警告
static func apply_risk_warning(seconds_before: float, base_value: float, level: int) -> Dictionary:
	var effective := base_value * (1.0 + (level - 1) * Constants.SKILL_LEVEL_BONUS)
	return {
		"effect_type": "ui_display",
		"action": "crash_warning",
		"warning_advance": effective,  ## 提前 30 秒预警
		"severity": "high",
	}


## 安全港（被动）：撤离窗口延长 N 秒
## SkillSystem 将此信号传递给 ExtractionEngine.extend_window()
static func apply_safe_harbor(base_value: float, level: int) -> Dictionary:
	var effective := base_value * (1.0 + (level - 1) * Constants.SKILL_LEVEL_BONUS)
	return {
		"effect_type": "extraction",
		"action": "extend_window",
		"extra_seconds": effective,  ## 延长 10 秒
	}


## 分散投资（被动）：持仓超过 3 只股票时手续费减免
## WS3 在计算手续费时检查持仓数和此修改器
static func apply_diversify(position_count: int, base_value: float, level: int) -> Dictionary:
	var effective := base_value * (1.0 + (level - 1) * Constants.SKILL_LEVEL_BONUS)
	var is_active := position_count > 3
	return {
		"effect_type": "order_modifier",
		"action": "fee_reduction",
		"reduction_ratio": effective if is_active else 0.0,  ## 0.5 = 减半
		"condition_met": is_active,    ## 持仓 >3 才生效
		"position_count": position_count,
	}


## 现金为王（被动）：持有现金时按 base_value 比率获得利息
## WS3 每 tick 根据玩家现金余额计算利息并累加
static func apply_cash_is_king(current_cash: float, base_value: float, level: int) -> Dictionary:
	var effective := base_value * (1.0 + (level - 1) * Constants.SKILL_LEVEL_BONUS)
	## 每 tick 利息 = 现金 × 利率（base_value=0.001 即 0.1%/tick）
	var tick_interest := current_cash * effective
	return {
		"effect_type": "fund_modifier",
		"action": "cash_interest",
		"interest_rate": effective,  ## 每 tick 利率
		"tick_interest": tick_interest,
	}
