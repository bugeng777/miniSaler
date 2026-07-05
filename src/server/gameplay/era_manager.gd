## 时代管理器
## 所有权: WS2 (游戏玩法组)
## 负责加载、管理和提供时代配置数据
extends Node
class_name EraManager


## 已加载的时代配置缓存
var _era_configs: Dictionary = {}  ## era_id -> EraData
var _current_era: EraData = null


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
	return _current_era


## 获取当前时代
func get_current_era() -> EraData:
	return _current_era


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
