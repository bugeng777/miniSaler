## 时代数据结构定义
## 所有权: WS2 (游戏玩法组)
## EraConfig 作为 Resource 可序列化为 .tres 文件
class_name EraData
extends Resource


## 时代唯一标识
@export var era_id: StringName = &""
## 显示名称
@export var display_name: String = ""
## 历史年份
@export var year: int = 0
## 国家/地区代码
@export var country: String = ""
## 难度星级 1-5
@export_range(1, 5) var difficulty: int = 1
## 波动率倍率（乘在基础波动率上）
@export var volatility_multiplier: float = 1.0
## 收益倍率
@export var profit_multiplier: float = 1.0

## 股票池配置（每只股票的详细参数）
@export var stock_configs: Array[Dictionary] = []

## 撤离窗口配置
@export var extraction_config: ExtractionConfig = ExtractionConfig.new()

## 新闻模板 ID 列表（NewsSystem 根据此列表加载新闻）
@export var news_template_ids: Array[StringName] = []

## Boss 配置
@export var boss_config: BossConfig = BossConfig.new()

## 氛围关键词（用于 UI 主题切换）
@export var atmosphere_tags: Array[String] = []

## 特殊机制标识
@export var special_mechanics: Array[StringName] = []

func to_dict() -> Dictionary:
	return {
		"era_id": era_id,
		"display_name": display_name,
		"year": year,
		"country": country,
		"difficulty": difficulty,
		"volatility_multiplier": volatility_multiplier,
		"profit_multiplier": profit_multiplier,
		"stock_configs": stock_configs,
		"extraction_config": extraction_config.to_dict(),
		"news_template_ids": news_template_ids,
		"boss_config": boss_config.to_dict(),
		"atmosphere_tags": atmosphere_tags,
		"special_mechanics": special_mechanics,
	}


## 撤离窗口配置
class ExtractionConfig:
	## 撤离窗口类型: "timed" | "conditional" | "emergency"
	var window_type: String = "timed"
	## 定时窗口间隔（秒）
	var interval: float = 90.0
	## 窗口开放时长（秒）
	var duration: float = 15.0
	## 条件窗口触发阈值（如指数涨幅百分比）
	var condition_threshold: float = 0.05
	## 紧急窗口时长（秒）
	var emergency_duration: float = 5.0

	func to_dict() -> Dictionary:
		return {
			"window_type": window_type,
			"interval": interval,
			"duration": duration,
			"condition_threshold": condition_threshold,
			"emergency_duration": emergency_duration,
		}

	static func from_dict(data: Dictionary) -> ExtractionConfig:
		var cfg := ExtractionConfig.new()
		cfg.window_type = data.get("window_type", "timed")
		cfg.interval = data.get("interval", 90.0)
		cfg.duration = data.get("duration", 15.0)
		cfg.condition_threshold = data.get("condition_threshold", 0.05)
		cfg.emergency_duration = data.get("emergency_duration", 5.0)
		return cfg


## Boss 配置
class BossConfig:
	## Boss 名称
	var boss_name: String = ""
	## Boss 策略描述
	var strategy: String = ""
	## Boss 资金量
	var capital: float = 500_000.0
	## Boss 交易方向偏好（正=做多，负=做空）
	var direction_bias: float = -1.0
	## Boss 单笔交易量
	var trade_volume: int = 100
	## Boss 交易频率（秒）
	var trade_interval: float = 2.0

	func to_dict() -> Dictionary:
		return {
			"boss_name": boss_name,
			"strategy": strategy,
			"capital": capital,
			"direction_bias": direction_bias,
			"trade_volume": trade_volume,
			"trade_interval": trade_interval,
		}

	static func from_dict(data: Dictionary) -> BossConfig:
		var cfg := BossConfig.new()
		cfg.boss_name = data.get("boss_name", "")
		cfg.strategy = data.get("strategy", "")
		cfg.capital = data.get("capital", 500_000.0)
		cfg.direction_bias = data.get("direction_bias", -1.0)
		cfg.trade_volume = data.get("trade_volume", 100)
		cfg.trade_interval = data.get("trade_interval", 2.0)
		return cfg
