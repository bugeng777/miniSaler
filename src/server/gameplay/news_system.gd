## 新闻系统
## 所有权: WS2 (游戏玩法组)
## 生成宏观/行业/公司/黑天鹅 4 类新闻事件，影响价格波动
## 参考: modelDesign.md Ch.15 信息不对称与事件系统
extends Node
class_name NewsSystem


## ─── 信号（接口 B：NewsSystem -> GameSession）─────────────────────────────
signal news_generated(news_event: Dictionary)
signal black_swan_triggered(event: Dictionary)


## 新闻模板
class NewsTemplate:
	var id: StringName = &""
	var text_template: String = ""
	var impact: int = GameEnums.NewsImpact.PRICE_JUMP
	var magnitude: float = 0.05
	var sentiment: int = GameEnums.NewsSentiment.NEUTRAL
	var target_sector: String = ""  ## 空 = 宏观
	var target_symbol: StringName = &""  ## 空 = 不针对特定股票
	var is_black_swan: bool = false
	var era_id: StringName = &""  ## 空 = 所有时代通用


## 新闻生成计时器
var _news_timer: Timer = null
var _templates: Array[NewsTemplate] = []
var _current_era_id: StringName = &""

## 延迟队列：新闻生成后不立即 emit，而是放入队列等待到期
class _DelayedNews:
	var event_data: Dictionary = {}
	var remaining: float = 0.0
	var is_black_swan: bool = false

var _delay_queue: Array = []  ## Array[_DelayedNews]


func _ready() -> void:
	_news_timer = Timer.new()
	_news_timer.one_shot = true
	_news_timer.timeout.connect(_on_news_timer_timeout)
	add_child(_news_timer)
	_load_default_templates()


## 启动新闻系统
func start(era_id: StringName) -> void:
	_current_era_id = era_id
	_delay_queue.clear()
	_schedule_next_news()


## 停止
func stop() -> void:
	_news_timer.stop()
	_delay_queue.clear()


## 安排下一条新闻
func _schedule_next_news() -> void:
	var interval := randf_range(Constants.NEWS_INTERVAL_MIN, Constants.NEWS_INTERVAL_MAX)
	_news_timer.wait_time = interval
	_news_timer.start()


## 每 tick 更新（由 GameSession 调用），处理延迟队列
func update(delta: float) -> void:
	var i := _delay_queue.size() - 1
	while i >= 0:
		var entry: _DelayedNews = _delay_queue[i]
		entry.remaining -= delta
		if entry.remaining <= 0.0:
			_delay_queue.remove_at(i)
			news_generated.emit(entry.event_data)
		i -= 1


## 新闻计时器触发
func _on_news_timer_timeout() -> void:
	var event := _generate_news_event()
	if event.is_black_swan:
		# 黑天鹅事件无延迟，立即 emit
		black_swan_triggered.emit(event.to_dict())
		news_generated.emit(event.to_dict())
	elif event.info_delay <= 0.0:
		# 延迟为 0 的普通新闻也立即 emit
		news_generated.emit(event.to_dict())
	else:
		# 放入延迟队列，等待到期 emit
		var entry := _DelayedNews.new()
		entry.event_data = event.to_dict()
		entry.remaining = event.info_delay
		entry.is_black_swan = false
		_delay_queue.append(entry)
	_schedule_next_news()


## 生成一条新闻事件
func _generate_news_event() -> NewsEvent:
	# 判定是否为黑天鹅
	var is_black_swan := randf() < Constants.BLACK_SWAN_PROBABILITY

	if is_black_swan:
		return _generate_black_swan()

	# 从模板中随机（优先时代专属 + 通用）
	if _templates.is_empty():
		return _create_generic_event()

	# 筛选：当前时代专属 + 通用模板
	var eligible: Array[NewsTemplate] = []
	for t in _templates:
		if t.era_id == &"" or t.era_id == _current_era_id:
			eligible.append(t)
	if eligible.is_empty():
		eligible = _templates

	var template: NewsTemplate = eligible[randi() % eligible.size()]
	var event := NewsEvent.new()
	event.text = template.text_template
	event.impact = template.impact
	event.magnitude = template.magnitude * randf_range(0.5, 1.5)
	event.sentiment = template.sentiment
	event.symbol = template.target_symbol
	event.is_black_swan = false
	# 信息延迟
	event.info_delay = randf_range(Constants.INFO_DELAY_MIN, Constants.INFO_DELAY_MAX)
	return event


## 生成黑天鹅事件
func _generate_black_swan() -> NewsEvent:
	var templates := [
		{"text": "突发：全球金融市场剧烈震荡！", "magnitude": 0.15, "sentiment": GameEnums.NewsSentiment.NEGATIVE},
		{"text": "央行紧急宣布意外政策调整", "magnitude": 0.12, "sentiment": GameEnums.NewsSentiment.NEGATIVE},
		{"text": "重大地缘政治事件冲击市场信心", "magnitude": 0.10, "sentiment": GameEnums.NewsSentiment.NEGATIVE},
		{"text": "罕见利好：大规模经济刺激计划出台！", "magnitude": 0.12, "sentiment": GameEnums.NewsSentiment.POSITIVE},
	]
	var t: Dictionary = templates[randi() % templates.size()]
	var event := NewsEvent.new()
	event.text = t.get("text", "黑天鹅事件")
	event.impact = GameEnums.NewsImpact.VOLATILITY_SPIKE
	event.magnitude = t.get("magnitude", 0.1)
	event.sentiment = t.get("sentiment", GameEnums.NewsSentiment.NEGATIVE)
	event.is_black_swan = true
	event.info_delay = 0.0  # 黑天鹅无延迟
	return event


## 通用事件（无模板时）
func _create_generic_event() -> NewsEvent:
	var event := NewsEvent.new()
	event.text = "市场传来不确定的消息"
	event.impact = GameEnums.NewsImpact.PRICE_JUMP
	event.magnitude = 0.03
	event.sentiment = GameEnums.NewsSentiment.NEUTRAL
	event.info_delay = 1.0
	return event


## 加载默认新闻模板
func _load_default_templates() -> void:
	_templates.clear()
	# 宏观新闻（所有时代通用）
	_add_template(&"macro_rate", "央行宣布调整基准利率", GameEnums.NewsImpact.PRICE_JUMP, 0.05, GameEnums.NewsSentiment.NEGATIVE, "")
	_add_template(&"macro_gdp", "GDP 数据超预期增长", GameEnums.NewsImpact.PRICE_JUMP, 0.03, GameEnums.NewsSentiment.POSITIVE, "")
	_add_template(&"macro_inflation", "通胀数据高于预期", GameEnums.NewsImpact.VOLATILITY_SPIKE, 0.04, GameEnums.NewsSentiment.NEGATIVE, "")
	_add_template(&"macro_trade", "国际贸易谈判取得突破", GameEnums.NewsImpact.PRICE_JUMP, 0.04, GameEnums.NewsSentiment.POSITIVE, "")
	# 行业新闻
	_add_template(&"sector_tech", "科技行业迎来重大技术突破", GameEnums.NewsImpact.PRICE_JUMP, 0.06, GameEnums.NewsSentiment.POSITIVE, "tech")
	_add_template(&"sector_finance", "金融监管政策收紧", GameEnums.NewsImpact.VOLATILITY_SPIKE, 0.05, GameEnums.NewsSentiment.NEGATIVE, "finance")
	_add_template(&"sector_energy", "新能源政策补贴加码", GameEnums.NewsImpact.PRICE_JUMP, 0.05, GameEnums.NewsSentiment.POSITIVE, "energy")
	# 公司新闻
	_add_template(&"company_earnings", "某公司发布超预期财报", GameEnums.NewsImpact.PRICE_JUMP, 0.08, GameEnums.NewsSentiment.POSITIVE, "")
	_add_template(&"company_scandal", "某公司爆出财务丑闻", GameEnums.NewsImpact.PRICE_JUMP, 0.10, GameEnums.NewsSentiment.NEGATIVE, "")
	# 香港 1997 专属
	_add_template(&"hk_soros", "索罗斯旗下基金大量做空港币", GameEnums.NewsImpact.PRICE_JUMP, 0.08, GameEnums.NewsSentiment.NEGATIVE, "finance", &"hk_1997")
	_add_template(&"hk_hkgov", "香港金管局宣布干预汇市", GameEnums.NewsImpact.PRICE_JUMP, 0.06, GameEnums.NewsSentiment.POSITIVE, "finance", &"hk_1997")
	_add_template(&"hk_property", "地产价格暴跌，多家公司破产", GameEnums.NewsImpact.VOLATILITY_SPIKE, 0.07, GameEnums.NewsSentiment.NEGATIVE, "realestate", &"hk_1997")
	# 首尔 1988 专属
	_add_template(&"kr_chaebol", "政府宣布扶持重点财阀企业", GameEnums.NewsImpact.PRICE_JUMP, 0.05, GameEnums.NewsSentiment.POSITIVE, "chaebol", &"seoul_1988")
	_add_template(&"kr_olympics", "奥运经济带动基建投资热潮", GameEnums.NewsImpact.PRICE_JUMP, 0.04, GameEnums.NewsSentiment.POSITIVE, "construction", &"seoul_1988")
	_add_template(&"kr_daewoo", "大宇集团爆出巨额债务危机", GameEnums.NewsImpact.PRICE_JUMP, 0.12, GameEnums.NewsSentiment.NEGATIVE, "chaebol", &"seoul_1988")
	# 硅谷 2000 专属
	_add_template(&"us_ipo", "又一家互联网公司成功IPO，首日暴涨", GameEnums.NewsImpact.PRICE_JUMP, 0.10, GameEnums.NewsSentiment.POSITIVE, "internet", &"silicon_2000")
	_add_template(&"us_fed", "美联储暗示加息，科技股承压", GameEnums.NewsImpact.VOLATILITY_SPIKE, 0.06, GameEnums.NewsSentiment.NEGATIVE, "internet", &"silicon_2000")
	_add_template(&"us_dotcom", "多家 .com 公司宣布盈利不达预期", GameEnums.NewsImpact.PRICE_JUMP, 0.08, GameEnums.NewsSentiment.NEGATIVE, "internet", &"silicon_2000")
	# 东京 1989 专属
	_add_template(&"jp_boj", "日本央行暗示加息，市场紧张", GameEnums.NewsImpact.VOLATILITY_SPIKE, 0.07, GameEnums.NewsSentiment.NEGATIVE, "bank", &"tokyo_1989")
	_add_template(&"jp_land", "地价持续上涨，地产股大涨", GameEnums.NewsImpact.PRICE_JUMP, 0.06, GameEnums.NewsSentiment.POSITIVE, "realestate", &"tokyo_1989")
	_add_template(&"jp_plaza", "广场协议后续影响，日元升值压力", GameEnums.NewsImpact.PRICE_JUMP, 0.05, GameEnums.NewsSentiment.NEGATIVE, "", &"tokyo_1989")
	# 上海 2007 专属
	_add_template(&"cn_policy", "证监会发布新规抑制投机炒作", GameEnums.NewsImpact.VOLATILITY_SPIKE, 0.06, GameEnums.NewsSentiment.NEGATIVE, "", &"shanghai_2007")
	_add_template(&"cn_reform", "股权分置改革深入推进，市场信心倍增", GameEnums.NewsImpact.PRICE_JUMP, 0.05, GameEnums.NewsSentiment.POSITIVE, "", &"shanghai_2007")
	_add_template(&"cn_st", "ST股连续涨停，散户疯狂追捧", GameEnums.NewsImpact.PRICE_JUMP, 0.10, GameEnums.NewsSentiment.POSITIVE, "st", &"shanghai_2007")
	_add_template(&"cn_rate", "央行上调存款准备金率", GameEnums.NewsImpact.PRICE_JUMP, 0.04, GameEnums.NewsSentiment.NEGATIVE, "bank", &"shanghai_2007")


func _add_template(id: StringName, text: String, impact: int, magnitude: float,
		sentiment: int, sector: String, era: StringName = &"") -> void:
	var t := NewsTemplate.new()
	t.id = id
	t.text_template = text
	t.impact = impact
	t.magnitude = magnitude
	t.sentiment = sentiment
	t.target_sector = sector
	t.era_id = era
	_templates.append(t)


## ─── 新闻事件数据 ────────────────────────────────────────────────────────────
class NewsEvent:
	var text: String = ""
	var impact: int = GameEnums.NewsImpact.PRICE_JUMP
	var magnitude: float = 0.0
	var sentiment: int = GameEnums.NewsSentiment.NEUTRAL
	var symbol: StringName = &""
	var is_black_swan: bool = false
	var info_delay: float = 0.0

	func to_dict() -> Dictionary:
		return {
			"text": text,
			"impact": impact,
			"magnitude": magnitude,
			"sentiment": sentiment,
			"symbol": symbol,
			"is_black_swan": is_black_swan,
			"info_delay": info_delay,
		}
