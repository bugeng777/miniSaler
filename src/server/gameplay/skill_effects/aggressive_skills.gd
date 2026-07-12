## 激进类技能效果实现
## 所有权: WS2 (游戏玩法组)
## 4 个激进类技能：leverage_maniac / all_in / doom_gambler / reaper
class_name AggressiveSkills
extends RefCounted


## 杠杆狂人（被动）：可借入 base_value 倍资金
## WS3 在准备阶段计算最大可借金额 = 带入资金 × multiplier
static func apply_leverage_maniac(base_funds: float, base_value: float, level: int) -> Dictionary:
	var effective := base_value * (1.0 + (level - 1) * Constants.SKILL_LEVEL_BONUS)
	var max_borrow := base_funds * effective
	return {
		"effect_type": "fund_modifier",
		"action": "leverage_borrow",
		"max_borrow_amount": max_borrow,
		"leverage_ratio": effective,  ## 3.0x 基础
		"interest_rate": 0.002,       ## 借款利息 0.2%/tick
	}


## 全押（被动）：单一股票收益 ×2，但只能持有一只股票
## WS3 限制持仓数量为 1，结算时对唯一持仓乘以倍率
static func apply_all_in(current_positions: int, base_value: float, level: int) -> Dictionary:
	var effective := base_value * (1.0 + (level - 1) * Constants.SKILL_LEVEL_BONUS)
	return {
		"effect_type": "fund_modifier",
		"action": "single_stock_boost",
		"profit_multiplier": effective,  ## 2.0x 收益
		"max_positions": 1,              ## 只能持有 1 只股票
		"can_buy_new": current_positions < 1,  ## 有新仓位空间才可买
	}


## 末日赌徒（被动）：黑天鹅事件时所有收益 ×3
## WS2 NewsSystem 在黑天鹅触发时通知 SkillSystem，WS3 临时提升收益倍率
static func apply_doom_gambler(is_black_swan_active: bool, base_value: float, level: int) -> Dictionary:
	var effective := base_value * (1.0 + (level - 1) * Constants.SKILL_LEVEL_BONUS)
	return {
		"effect_type": "fund_modifier",
		"action": "black_swan_profit_boost",
		"boost_multiplier": effective if is_black_swan_active else 1.0,
		"condition_active": is_black_swan_active,  ## 仅黑天鹅期间生效
	}


## 收割者（被动）：对手爆仓时获得其本局利润的 base_value 比例
## WS2 ExtractionEngine 在 player_busted 信号触发时通知 SkillSystem
## WS3 将奖励金额加到收割者账户
static func apply_reaper(busted_player_profit: float, base_value: float, level: int) -> Dictionary:
	var effective := base_value * (1.0 + (level - 1) * Constants.SKILL_LEVEL_BONUS)
	var reward := busted_player_profit * effective
	return {
		"effect_type": "fund_modifier",
		"action": "harvest_bust_reward",
		"harvest_ratio": effective,   ## 0.1 = 10%
		"reward_amount": reward,      ## 实际奖励金额
		"requires_positive_profit": busted_player_profit > 0.0,  ## 对手需有正利润
	}
