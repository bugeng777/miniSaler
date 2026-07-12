## 技能相关数据结构
## 所有权: WS2 (游戏玩法组)
class_name SkillTypes


## 技能定义（静态数据，不随玩家进度变化）
class SkillDef:
	var skill_id: StringName = &""
	var display_name: String = ""
	var description: String = ""
	var category: int = GameEnums.SkillCategory.ANALYSIS
	var trigger: int = GameEnums.SkillTrigger.PASSIVE
	## 冷却时间（秒），仅 ACTIVE 类型有效
	var cooldown: float = 0.0
	## 基础效果数值（各技能含义不同）
	var base_value: float = 0.0
	## 效果持续时长（秒），0 表示永久
	var duration: float = 0.0
	## 解锁等级要求
	var unlock_level: int = 0
	## 是否为时代专属技能
	var era_restricted: bool = false
	## 限定时代 ID（仅 era_restricted=true 时有效）
	var restricted_era: StringName = &""

	func to_dict() -> Dictionary:
		return {
			"skill_id": skill_id,
			"display_name": display_name,
			"description": description,
			"category": category,
			"trigger": trigger,
			"cooldown": cooldown,
			"base_value": base_value,
			"duration": duration,
			"unlock_level": unlock_level,
			"era_restricted": era_restricted,
			"restricted_era": restricted_era,
		}

	static func from_dict(data: Dictionary) -> SkillDef:
		var def := SkillDef.new()
		def.skill_id = StringName(data.get("skill_id", ""))
		def.display_name = data.get("display_name", "")
		def.description = data.get("description", "")
		def.category = data.get("category", GameEnums.SkillCategory.ANALYSIS)
		def.trigger = data.get("trigger", GameEnums.SkillTrigger.PASSIVE)
		def.cooldown = data.get("cooldown", 0.0)
		def.base_value = data.get("base_value", 0.0)
		def.duration = data.get("duration", 0.0)
		def.unlock_level = data.get("unlock_level", 0)
		def.era_restricted = data.get("era_restricted", false)
		def.restricted_era = StringName(data.get("restricted_era", ""))
		return def


## 玩家技能进度（动态数据，随使用升级）
class SkillProgress:
	var skill_id: StringName = &""
	var level: int = 1
	var exp: int = 0
	var exp_to_next: int = 50

	func get_effective_value(base_value: float) -> float:
		return base_value * (1.0 + (level - 1) * Constants.SKILL_LEVEL_BONUS)

	func to_dict() -> Dictionary:
		return {
			"skill_id": skill_id,
			"level": level,
			"exp": exp,
			"exp_to_next": exp_to_next,
		}

	static func from_dict(data: Dictionary) -> SkillProgress:
		var prog := SkillProgress.new()
		prog.skill_id = StringName(data.get("skill_id", ""))
		prog.level = data.get("level", 1)
		prog.exp = data.get("exp", 0)
		prog.exp_to_next = data.get("exp_to_next", 50)
		return prog


## 技能运行时状态（单局内，追踪冷却等）
class SkillRuntimeState:
	var skill_id: StringName = &""
	var is_active: bool = false
	var cooldown_remaining: float = 0.0
	var effect_remaining: float = 0.0  ## 效果剩余时间（0=永久）

	func to_dict() -> Dictionary:
		return {
			"skill_id": skill_id,
			"is_active": is_active,
			"cooldown_remaining": cooldown_remaining,
			"effect_remaining": effect_remaining,
		}


## ─── 技能效果契约（Phase 3 新增）──────────────────────────────────────────────
## 每个技能触发后产生的效果数据结构，供 WS1/WS3/WS5 消费
## effect_type 语义:
##   "market_data"     — 需要 WS1 MarketEngine 提供数据（内在价值/大户持仓/MA交叉）
##   "fund_modifier"   — 需要 WS3 PlayerManager 修改资金/持仓（利息/杠杆/爆仓保留）
##   "order_modifier"  — 需要 WS3 修改订单执行逻辑（速度/批量/止损）
##   "ui_display"      — 需要 WS5 在 UI 上显示（恐贪指数/信号/预警/他人方向）
##   "extraction"      — 影响 ExtractionEngine 撤离窗口
##   "social"          — 影响其他玩家（假消息/AI跟随）
class SkillEffect:
	var skill_id: StringName = &""
	var effect_type: StringName = &""   ## 见上方枚举说明
	var target: StringName = &""        ## 作用对象: "player" | "market" | "opponents" | "extraction" | "specific_stock"
	var value: float = 0.0              ## 效果数值（语义随技能不同）
	var duration: float = 0.0           ## 持续时间（秒），0 = 永久/瞬时

	func to_dict() -> Dictionary:
		return {
			"skill_id": skill_id,
			"effect_type": effect_type,
			"target": target,
			"value": value,
			"duration": duration,
		}

	static func from_dict(data: Dictionary) -> SkillEffect:
		var e := SkillEffect.new()
		e.skill_id = StringName(data.get("skill_id", ""))
		e.effect_type = StringName(data.get("effect_type", ""))
		e.target = StringName(data.get("target", ""))
		e.value = data.get("value", 0.0)
		e.duration = data.get("duration", 0.0)
		return e


## 22 个技能的 SkillEffect 静态映射表（Phase 3 契约，CTO 冻结后不可变更）
## 各组实现时需严格按此表的 effect_type / target / value 语义执行
const ALL_SKILL_EFFECTS: Array[Dictionary] = [
	# ─── 分析类（5）─────────────────────────────────────────
	{"skill_id": "news_reader",      "effect_type": "market_data",    "target": "player",     "value": 2.0,  "duration": 0.0},
	{"skill_id": "trend_insight",    "effect_type": "market_data",    "target": "market",     "value": 1.0,  "duration": 5.0},
	{"skill_id": "sentiment_sense",  "effect_type": "ui_display",     "target": "player",     "value": 1.0,  "duration": 0.0},
	{"skill_id": "fundamental_scan", "effect_type": "market_data",    "target": "market",     "value": 1.0,  "duration": 0.0},
	{"skill_id": "whale_tracker",    "effect_type": "market_data",    "target": "market",     "value": 5.0,  "duration": 5.0},
	# ─── 执行类（5）─────────────────────────────────────────
	{"skill_id": "lightning_order",  "effect_type": "order_modifier", "target": "player",     "value": 2.0,  "duration": 3.0},
	{"skill_id": "auto_stop_loss",   "effect_type": "order_modifier", "target": "specific_stock", "value": 0.05, "duration": 0.0},
	{"skill_id": "batch_trade",      "effect_type": "order_modifier", "target": "player",     "value": 1.0,  "duration": 0.0},
	{"skill_id": "momentum_hunter",  "effect_type": "ui_display",     "target": "market",     "value": 3.0,  "duration": 0.0},
	{"skill_id": "short_expert",     "effect_type": "fund_modifier",  "target": "player",     "value": 0.2,  "duration": 0.0},
	# ─── 防御类（5）─────────────────────────────────────────
	{"skill_id": "iron_will",        "effect_type": "fund_modifier",  "target": "player",     "value": 0.1,  "duration": 0.0},
	{"skill_id": "risk_warning",     "effect_type": "ui_display",     "target": "player",     "value": 30.0, "duration": 0.0},
	{"skill_id": "safe_harbor",      "effect_type": "extraction",     "target": "extraction", "value": 10.0, "duration": 0.0},
	{"skill_id": "diversify",        "effect_type": "order_modifier", "target": "player",     "value": 0.5,  "duration": 0.0},
	{"skill_id": "cash_is_king",     "effect_type": "fund_modifier",  "target": "player",     "value": 0.001, "duration": 0.0},
	# ─── 社交类（4）─────────────────────────────────────────
	{"skill_id": "market_rumor",     "effect_type": "social",         "target": "opponents",  "value": 1.0,  "duration": 0.0},
	{"skill_id": "herd_master",      "effect_type": "ui_display",     "target": "opponents",  "value": 5.0,  "duration": 5.0},
	{"skill_id": "opinion_leader",   "effect_type": "social",         "target": "market",     "value": 1.0,  "duration": 0.0},
	{"skill_id": "insider_network",  "effect_type": "market_data",    "target": "player",     "value": 1.0,  "duration": 0.0},
	# ─── 激进类（3+1）───────────────────────────────────────
	{"skill_id": "leverage_maniac",  "effect_type": "fund_modifier",  "target": "player",     "value": 3.0,  "duration": 0.0},
	{"skill_id": "all_in",           "effect_type": "fund_modifier",  "target": "specific_stock", "value": 2.0, "duration": 0.0},
	{"skill_id": "doom_gambler",     "effect_type": "fund_modifier",  "target": "player",     "value": 3.0,  "duration": 0.0},
	{"skill_id": "reaper",           "effect_type": "fund_modifier",  "target": "player",     "value": 0.1,  "duration": 0.0},
]


## 所有基础技能定义（静态注册表）
## SkillSystem 在初始化时加载此表
const ALL_SKILLS: Array[Dictionary] = [
	# ─── 分析类 ─────────────────────────────────────────────
	{"skill_id": "news_reader", "display_name": "新闻速读", "description": "新闻延迟减少2秒",
	 "category": 0, "trigger": 0, "cooldown": 0.0, "base_value": 2.0, "unlock_level": 0},
	{"skill_id": "trend_insight", "display_name": "趋势洞察", "description": "显示短期MA交叉信号",
	 "category": 0, "trigger": 1, "cooldown": 30.0, "base_value": 1.0, "unlock_level": 5},
	{"skill_id": "sentiment_sense", "display_name": "情绪感知", "description": "显示当前市场恐贪指数",
	 "category": 0, "trigger": 0, "cooldown": 0.0, "base_value": 1.0, "unlock_level": 0},
	{"skill_id": "fundamental_scan", "display_name": "基本面扫描", "description": "显示股票内在价值估算",
	 "category": 0, "trigger": 0, "cooldown": 0.0, "base_value": 1.0, "unlock_level": 10},
	{"skill_id": "whale_tracker", "display_name": "庄家追踪", "description": "短暂显示大户持仓变动",
	 "category": 0, "trigger": 1, "cooldown": 60.0, "base_value": 5.0, "unlock_level": 15},
	# ─── 执行类 ─────────────────────────────────────────────
	{"skill_id": "lightning_order", "display_name": "闪电下单", "description": "交易执行速度翻倍",
	 "category": 1, "trigger": 1, "cooldown": 45.0, "base_value": 2.0, "duration": 3.0, "unlock_level": 5},
	{"skill_id": "auto_stop_loss", "display_name": "自动止损", "description": "自动设置-5%止损线",
	 "category": 1, "trigger": 1, "cooldown": 90.0, "base_value": 0.05, "unlock_level": 10},
	{"skill_id": "batch_trade", "display_name": "批量交易", "description": "同时买卖多只股票",
	 "category": 1, "trigger": 1, "cooldown": 60.0, "base_value": 1.0, "unlock_level": 15},
	{"skill_id": "momentum_hunter", "display_name": "追涨猎手", "description": "连涨3天股票自动标记",
	 "category": 1, "trigger": 1, "cooldown": 30.0, "base_value": 3.0, "unlock_level": 5},
	{"skill_id": "short_expert", "display_name": "做空专家", "description": "做空收益+20%",
	 "category": 1, "trigger": 0, "cooldown": 0.0, "base_value": 0.2, "unlock_level": 10},
	# ─── 防御类 ─────────────────────────────────────────────
	{"skill_id": "iron_will", "display_name": "钢铁意志", "description": "爆仓时保留10%资金",
	 "category": 2, "trigger": 0, "cooldown": 0.0, "base_value": 0.1, "unlock_level": 10},
	{"skill_id": "risk_warning", "display_name": "风险预警", "description": "崩盘前30秒收到警报",
	 "category": 2, "trigger": 0, "cooldown": 0.0, "base_value": 30.0, "unlock_level": 5},
	{"skill_id": "safe_harbor", "display_name": "安全港", "description": "撤离窗口延长10秒",
	 "category": 2, "trigger": 0, "cooldown": 0.0, "base_value": 10.0, "unlock_level": 0},
	{"skill_id": "diversify", "display_name": "分散投资", "description": "持仓超过3只股票时手续费减半",
	 "category": 2, "trigger": 0, "cooldown": 0.0, "base_value": 0.5, "unlock_level": 10},
	{"skill_id": "cash_is_king", "display_name": "现金为王", "description": "持有现金时获得利息",
	 "category": 2, "trigger": 0, "cooldown": 0.0, "base_value": 0.001, "unlock_level": 15},
	# ─── 社交类 ─────────────────────────────────────────────
	{"skill_id": "market_rumor", "display_name": "市场谣言", "description": "发布假消息影响对手",
	 "category": 3, "trigger": 1, "cooldown": 120.0, "base_value": 1.0, "unlock_level": 15},
	{"skill_id": "herd_master", "display_name": "跟风大师", "description": "显示其他玩家的买卖方向",
	 "category": 3, "trigger": 1, "cooldown": 60.0, "base_value": 5.0, "unlock_level": 10},
	{"skill_id": "opinion_leader", "display_name": "意见领袖", "description": "你的交易会被1个AI跟随",
	 "category": 3, "trigger": 0, "cooldown": 0.0, "base_value": 1.0, "unlock_level": 20},
	{"skill_id": "insider_network", "display_name": "内幕网络", "description": "每局获得1条独家新闻",
	 "category": 3, "trigger": 0, "cooldown": 0.0, "base_value": 1.0, "unlock_level": 15},
	# ─── 激进类 ─────────────────────────────────────────────
	{"skill_id": "leverage_maniac", "display_name": "杠杆狂人", "description": "可借入3倍资金",
	 "category": 4, "trigger": 0, "cooldown": 0.0, "base_value": 3.0, "unlock_level": 10},
	{"skill_id": "all_in", "display_name": "全押", "description": "单一股票收益x2，但只能买一只",
	 "category": 4, "trigger": 0, "cooldown": 0.0, "base_value": 2.0, "unlock_level": 15},
	{"skill_id": "doom_gambler", "display_name": "末日赌徒", "description": "黑天鹅事件时收益x3",
	 "category": 4, "trigger": 0, "cooldown": 0.0, "base_value": 3.0, "unlock_level": 20},
	{"skill_id": "reaper", "display_name": "收割者", "description": "对手爆仓时你获得其10%利润",
	 "category": 4, "trigger": 0, "cooldown": 0.0, "base_value": 0.1, "unlock_level": 20},
]
