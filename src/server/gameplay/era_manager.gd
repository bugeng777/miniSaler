## 时代管理器
## 所有权: WS2 (游戏玩法组)
## 负责加载、管理和提供时代配置数据
extends Node
class_name EraManager


## 已加载的时代配置缓存
var _era_configs: Dictionary = {}  ## era_id -> EraData
var _current_era: EraData = null
## 当前时代特殊机制处理器
var _mechanics_handler: EraMechanicsHandler = null


func _ready() -> void:
	_load_default_eras()


## 加载默认时代配置（代码生成，后续可改为 .tres 文件加载）
func _load_default_eras() -> void:
	# 香港 1997
	var hk := EraData.new()
	hk.era_id = &"hk_1997"
	hk.display_name = "香港 1997 — 东方之珠的风暴"
	hk.year = 1997
	hk.country = "HK"
	hk.difficulty = 3
	hk.volatility_multiplier = 1.5
	hk.profit_multiplier = 1.3
	hk.stock_configs = Constants.STOCK_POOL_HK_1997
	hk.extraction_config.window_type = "timed"
	hk.extraction_config.interval = 90.0
	hk.extraction_config.duration = 15.0
	hk.boss_config.boss_name = "金融大鳄"
	hk.boss_config.strategy = "大量做空，打爆港币"
	hk.boss_config.direction_bias = -1.0
	hk.atmosphere_tags = ["neon", "victoria_harbor", "cantonese"]
	hk.special_mechanics = [&"currency_war"]
	_era_configs[&"hk_1997"] = hk

	# 首尔 1988
	var seoul := EraData.new()
	seoul.era_id = &"seoul_1988"
	seoul.display_name = "首尔 1988 — 汉江奇迹"
	seoul.year = 1988
	seoul.country = "KR"
	seoul.difficulty = 2
	seoul.volatility_multiplier = 1.2
	seoul.profit_multiplier = 1.0
	seoul.stock_configs = Constants.STOCK_POOL_SEOUL_1988
	seoul.extraction_config.window_type = "conditional"
	seoul.extraction_config.interval = 60.0
	seoul.extraction_config.duration = 30.0
	seoul.boss_config.boss_name = "财阀掌门人"
	seoul.boss_config.strategy = "内幕交易，资金碾压"
	seoul.boss_config.direction_bias = 1.0
	seoul.atmosphere_tags = ["olympics", "hanbok", "construction"]
	seoul.special_mechanics = [&"chaebol_policy"]
	_era_configs[&"seoul_1988"] = seoul

	# 硅谷 2000
	var silicon := EraData.new()
	silicon.era_id = &"silicon_2000"
	silicon.display_name = "硅谷 2000 — 互联网淘金热"
	silicon.year = 2000
	silicon.country = "US"
	silicon.difficulty = 4
	silicon.volatility_multiplier = 2.0
	silicon.profit_multiplier = 1.8
	silicon.stock_configs = Constants.STOCK_POOL_SILICON_2000
	silicon.extraction_config.window_type = "conditional"
	silicon.extraction_config.condition_threshold = 0.05
	silicon.extraction_config.duration = 10.0
	silicon.boss_config.boss_name = "风投之王"
	silicon.boss_config.strategy = "拉高科技股后出货"
	silicon.boss_config.direction_bias = 1.0
	silicon.boss_config.capital = 800_000.0
	silicon.atmosphere_tags = ["garage", "nasdaq", "y2k"]
	silicon.special_mechanics = [&"ipo_frenzy"]
	_era_configs[&"silicon_2000"] = silicon

	# 东京 1989
	var tokyo := EraData.new()
	tokyo.era_id = &"tokyo_1989"
	tokyo.display_name = "东京 1989 — 泡沫之巅"
	tokyo.year = 1989
	tokyo.country = "JP"
	tokyo.difficulty = 3
	tokyo.volatility_multiplier = 1.3
	tokyo.profit_multiplier = 1.4
	tokyo.stock_configs = Constants.STOCK_POOL_TOKYO_1989
	tokyo.extraction_config.window_type = "conditional"
	tokyo.extraction_config.interval = 60.0
	tokyo.extraction_config.duration = 15.0
	tokyo.boss_config.boss_name = "日本银行总裁"
	tokyo.boss_config.strategy = "突然加息引发崩盘"
	tokyo.boss_config.direction_bias = -1.0
	tokyo.boss_config.capital = 1_000_000.0
	tokyo.atmosphere_tags = ["ginza", "bubble", "sushi"]
	tokyo.special_mechanics = [&"leverage_party"]
	_era_configs[&"tokyo_1989"] = tokyo

	# 上海 2007
	var shanghai := EraData.new()
	shanghai.era_id = &"shanghai_2007"
	shanghai.display_name = "上海 2007 — 六千点的疯狂"
	shanghai.year = 2007
	shanghai.country = "CN"
	shanghai.difficulty = 5
	shanghai.volatility_multiplier = 2.5
	shanghai.profit_multiplier = 2.0
	shanghai.stock_configs = Constants.STOCK_POOL_SHANGHAI_2007
	shanghai.extraction_config.window_type = "conditional"
	shanghai.extraction_config.duration = 10.0
	shanghai.boss_config.boss_name = "庄家联盟"
	shanghai.boss_config.strategy = "操纵ST股，拉高出货"
	shanghai.boss_config.direction_bias = 1.0
	shanghai.boss_config.capital = 600_000.0
	shanghai.atmosphere_tags = ["trading_hall", "red_kline", "newspaper"]
	shanghai.special_mechanics = [&"t_plus_1", &"price_limit"]
	_era_configs[&"shanghai_2007"] = shanghai


## 获取指定时代配置
func get_era(era_id: StringName) -> EraData:
	return _era_configs.get(era_id, null)


## 获取所有可用时代列表
func get_all_eras() -> Array[EraData]:
	var eras: Array[EraData] = []
	for era_id in _era_configs:
		eras.append(_era_configs[era_id])
	return eras


## 获取已解锁时代列表
func get_unlocked_eras(profile: PlayerTypes.PlayerProfile) -> Array[EraData]:
	var unlocked: Array[EraData] = []
	for era_id in _era_configs:
		if _is_era_unlocked(era_id, profile):
			unlocked.append(_era_configs[era_id])
	return unlocked


## 设置当前时代
func set_current_era(era_id: StringName) -> EraData:
	_current_era = _era_configs.get(era_id, null)
	if _current_era:
		_mechanics_handler = EraMechanicsHandler.new(_current_era)
	return _current_era


## 获取当前时代
func get_current_era() -> EraData:
	return _current_era


## 获取当前时代的特殊机制处理器
func get_mechanics_handler() -> EraMechanicsHandler:
	return _mechanics_handler


## 检查时代是否解锁
func _is_era_unlocked(era_id: StringName, profile: PlayerTypes.PlayerProfile) -> bool:
	if not Constants.ERA_UNLOCK_CONDITIONS.has(era_id):
		return false
	var condition: Dictionary = Constants.ERA_UNLOCK_CONDITIONS[era_id]
	match condition.get("type", ""):
		"initial":
			return true
		"extractions":
			return profile.total_extractions >= condition.get("count", 0)
		"total_profit":
			return profile.total_profit >= condition.get("amount", 0)
		"era_clear":
			var required_eras: Array = condition.get("eras", [])
			var clear_count := 0
			for req_era in required_eras:
				if profile.unlocked_eras.has(StringName(req_era)):
					clear_count += 1
			return clear_count >= condition.get("count", 0)
	return false


## ─── 时代特殊机制处理器 ─────────────────────────────────────────────────────
## 管理当前时代的特殊机制效果
## 由 EraManager.set_current_era() 初始化，GameSession 每 tick 调用 update()
class EraMechanicsHandler:
	extends RefCounted

	## 机制效果信号（供 GameSession 连接后转发）
	signal mechanic_event_triggered(mechanic_id: StringName, data: Dictionary)

	var _active_mechanics: Array[StringName] = []
	var _elapsed_time: float = 0.0
	var _era_config: EraData = null

	## IPO 狂潮参数
	const IPO_INTERVAL: float = 45.0  ## 每 45 秒注入一次 IPO 事件
	var _next_ipo_time: float = IPO_INTERVAL

	## 汇率战参数
	const CURRENCY_WAR_INTERVAL: float = 30.0  ## 每 30 秒触发汇率波动
	var _next_currency_war_time: float = CURRENCY_WAR_INTERVAL
	var _currency_pressure: float = 0.0  ## 当前汇率压力值

	## T+1 参数
	var _today_bought: Dictionary = {}  ## player_id -> Array[StringName] 当天买入的股票

	## 杠杆狂欢参数
	const LEVERAGE_BONUS_RATIO: float = 0.5  ## 额外可借入资金比例

	func _init(era: EraData) -> void:
		_era_config = era
		_active_mechanics = era.special_mechanics.duplicate()
		_next_ipo_time = IPO_INTERVAL
		_next_currency_war_time = CURRENCY_WAR_INTERVAL
		_currency_pressure = 0.0
		_today_bought.clear()

	## 每 tick 更新（由 GameSession 调用）
	func update(delta: float) -> void:
		_elapsed_time += delta
		for mechanic in _active_mechanics:
			match mechanic:
				&"currency_war":
					_update_currency_war(delta)
				&"ipo_frenzy":
					_update_ipo_frenzy(delta)

	## 获取当前激活的特殊机制列表
	func get_active_mechanics() -> Array[StringName]:
		return _active_mechanics

	## 检查某个机制是否激活
	func has_mechanic(mechanic_id: StringName) -> bool:
		return _active_mechanics.has(mechanic_id)

	## ─── currency_war（香港 1997）：港币汇率波动影响所有股票 ────────
	func _update_currency_war(delta: float) -> void:
		if _elapsed_time >= _next_currency_war_time:
			_next_currency_war_time = _elapsed_time + CURRENCY_WAR_INTERVAL
			# 随机汇率压力变化
			_currency_pressure += randf_range(-0.05, 0.08)
			_currency_pressure = clampf(_currency_pressure, -0.3, 0.5)
			var data := {
				"mechanic": "currency_war",
				"pressure": _currency_pressure,
				"volatility_boost": abs(_currency_pressure) * 0.5,
			}
			mechanic_event_triggered.emit(&"currency_war", data)

	## 获取当前汇率压力值（供 MarketEngine 读取，影响全局波动率）
	func get_currency_pressure() -> float:
		return _currency_pressure

	## ─── chaebol_policy（首尔 1988）：政府政策新闻对财阀股影响 ×2 ────────
	## 由 NewsSystem 的新闻事件触发，GameSession 调用此方法获取倍率
	func get_chaebol_news_multiplier() -> float:
		if has_mechanic(&"chaebol_policy"):
			return 2.0
		return 1.0

	## ─── ipo_frenzy（硅谷 2000）：每隔 N 秒注入一次“新公司 IPO”事件 ────────
	func _update_ipo_frenzy(delta: float) -> void:
		if _elapsed_time >= _next_ipo_time:
			_next_ipo_time = _elapsed_time + IPO_INTERVAL
			var ipo_companies := [
				{"name": "eToys", "sector": "internet", "base_price": 25.0},
				{"name": "TheGlobe.com", "sector": "internet", "base_price": 15.0},
				{"name": "VA Linux", "sector": "internet", "base_price": 30.0},
				{"name": "Priceline", "sector": "internet", "base_price": 40.0},
			]
			var pick: Dictionary = ipo_companies[randi() % ipo_companies.size()]
			var data := {
				"mechanic": "ipo_frenzy",
				"company_name": pick.get("name", "NewCo"),
				"sector": pick.get("sector", "internet"),
				"base_price": pick.get("base_price", 20.0),
				"hype_multiplier": randf_range(2.0, 5.0),
			}
			mechanic_event_triggered.emit(&"ipo_frenzy", data)

	## ─── leverage_party（东京 1989）：所有玩家初始可借入额外资金 ────────
	## GameSession 在准备阶段调用，获取每个玩家的额外借款额度
	func get_leverage_bonus(base_funds: float) -> float:
		if has_mechanic(&"leverage_party"):
			return base_funds * LEVERAGE_BONUS_RATIO
		return 0.0

	## ─── t_plus_1（上海 2007）：买入当天不可卖出 ────────
	## 记录玩家当天买入的股票
	func record_buy(player_id: int, symbol: StringName) -> void:
		if not has_mechanic(&"t_plus_1"):
			return
		if not _today_bought.has(player_id):
			_today_bought[player_id] = []
		_today_bought[player_id].append(symbol)

	## 检查某只股票是否可以卖出（T+1 限制）
	func can_sell(player_id: int, symbol: StringName) -> bool:
		if not has_mechanic(&"t_plus_1"):
			return true
		if not _today_bought.has(player_id):
			return true
		return not _today_bought[player_id].has(symbol)

	## 新的一天（每局开始时调用，清除 T+1 记录）
	func reset_daily() -> void:
		_today_bought.clear()
