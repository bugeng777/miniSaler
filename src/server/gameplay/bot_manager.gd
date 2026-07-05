## AI 对手管理器
## 所有权: WS2 (游戏玩法组)
## 管理 Bot 交易者的创建、策略执行和 Boss 行为
## 参考: modelDesign.md Ch.25 AI 智能体对手系统
extends Node
class_name BotManager


## ─── 信号（接口 B：BotManager -> GameSession）─────────────────────────────
signal bot_action_executed(bot_id: int, action: Dictionary)
signal boss_entered(boss_name: String, boss_data: Dictionary)
signal boss_defeated(boss_name: String, result: Dictionary)


## 单个 Bot 的运行时状态
class BotState:
	var bot_id: int = 0
	var bot_name: String = ""
	var strategy: int = GameEnums.BotStrategy.TREND_FOLLOWER
	var cash: float = 100_000.0
	var positions: Dictionary = {}  ## symbol -> quantity
	var last_action_time: float = 0.0
	var action_interval: float = 3.0  ## 每次行动的间隔（秒）
	var difficulty: float = 1.0       ## 难度系数

## Boss 状态
class BossState:
	var boss_name: String = ""
	var config: EraData.BossConfig = null
	var is_active: bool = false
	var cash: float = 0.0
	var entry_time: float = 0.0
	var last_trade_time: float = 0.0
	var profit_loss: float = 0.0  ## Boss 当前盈亏


var _bots: Array[BotState] = []
var _boss: BossState = null
var _elapsed_time: float = 0.0
var _boss_spawned: bool = false
var _current_era: EraData = null
var _symbols: Array[StringName] = []


## 初始化 Bot 池
func start(era_config: EraData, symbols: Array[StringName], bot_count: int = 7) -> void:
	_current_era = era_config
	_symbols = symbols
	_elapsed_time = 0.0
	_boss_spawned = false
	_bots.clear()
	_boss = null

	# 创建 Bot
	var strategies := [
		GameEnums.BotStrategy.TREND_FOLLOWER,
		GameEnums.BotStrategy.TREND_FOLLOWER,
		GameEnums.BotStrategy.TREND_FOLLOWER,
		GameEnums.BotStrategy.CONTRARIAN,
		GameEnums.BotStrategy.CONTRARIAN,
		GameEnums.BotStrategy.NOISE_TRADER,
		GameEnums.BotStrategy.AGGRESSIVE,
	]
	var bot_names := ["小明", "老王", "张三", "李四", "赵五", "陈六", "周七"]
	for i in range(mini(bot_count, strategies.size())):
		var bot := BotState.new()
		bot.bot_id = 100 + i
		bot.bot_name = bot_names[i] if i < bot_names.size() else "Bot_%d" % i
		bot.strategy = strategies[i]
		bot.action_interval = randf_range(2.0, 5.0)
		bot.difficulty = era_config.difficulty * 0.2
		_bots.append(bot)

	# 判定 Boss 是否出现
	if randf() < Constants.BOSS_SPAWN_PROBABILITY:
		_boss = BossState.new()
		_boss.boss_name = era_config.boss_config.boss_name
		_boss.config = era_config.boss_config
		_boss.cash = era_config.boss_config.capital
		_boss.entry_time = randf_range(
			Constants.BOSS_ENTRY_MINUTES_MIN * 60.0,
			Constants.BOSS_ENTRY_MINUTES_MAX * 60.0
		)


## 每 tick 更新（由 GameSession 调用）
func update(delta: float, prices: Dictionary) -> void:
	_elapsed_time += delta

	# Boss 入场检查
	if _boss and not _boss.is_active and _elapsed_time >= _boss.entry_time:
		_spawn_boss()

	# 更新 Bot 行为
	for bot in _bots:
		bot.last_action_time += delta
		if bot.last_action_time >= bot.action_interval:
			bot.last_action_time = 0.0
			_execute_bot_strategy(bot, prices)

	# 更新 Boss 行为
	if _boss and _boss.is_active:
		_boss.last_trade_time += delta
		if _boss.last_trade_time >= _boss.config.trade_interval:
			_boss.last_trade_time = 0.0
			_execute_boss_trade(prices)


## 执行 Bot 策略
func _execute_bot_strategy(bot: BotState, prices: Dictionary) -> void:
	if _symbols.is_empty() or prices.is_empty():
		return
	var target_symbol: StringName = _symbols[randi() % _symbols.size()]
	if not prices.has(target_symbol):
		return

	var current_price: float = prices[target_symbol]
	var action := {}

	match bot.strategy:
		GameEnums.BotStrategy.TREND_FOLLOWER:
			# 追涨杀跌：价格涨就买，跌就卖
			var should_buy := randf() < 0.5 + bot.difficulty * 0.1
			action = _create_action(bot.bot_id, target_symbol,
				GameEnums.OrderSide.BUY if should_buy else GameEnums.OrderSide.SELL,
				randi_range(10, 50), current_price)

		GameEnums.BotStrategy.CONTRARIAN:
			# 逆向投资：跌多了买，涨多了卖
			var should_buy := randf() < 0.55
			action = _create_action(bot.bot_id, target_symbol,
				GameEnums.OrderSide.BUY if should_buy else GameEnums.OrderSide.SELL,
				randi_range(5, 30), current_price)

		GameEnums.BotStrategy.NOISE_TRADER:
			# 噪音交易：随机买卖
			var side := GameEnums.OrderSide.BUY if randf() < 0.5 else GameEnums.OrderSide.SELL
			action = _create_action(bot.bot_id, target_symbol, side,
				randi_range(1, 20), current_price)

		GameEnums.BotStrategy.AGGRESSIVE:
			# 激进交易：大额交易
			var side := GameEnums.OrderSide.BUY if randf() < 0.5 else GameEnums.OrderSide.SELL
			action = _create_action(bot.bot_id, target_symbol, side,
				randi_range(50, 200), current_price)

	if not action.is_empty():
		bot_action_executed.emit(bot.bot_id, action)


## Boss 交易
func _execute_boss_trade(prices: Dictionary) -> void:
	if not _boss or not _boss.is_active:
		return
	if _symbols.is_empty() or prices.is_empty():
		return
	var target: StringName = _symbols[randi() % _symbols.size()]
	if not prices.has(target):
		return
	var side := GameEnums.OrderSide.BUY if _boss.config.direction_bias > 0 else GameEnums.OrderSide.SELL
	var action := _create_action(999, target, side, _boss.config.trade_volume, prices[target])
	bot_action_executed.emit(999, action)


## Boss 入场
func _spawn_boss() -> void:
	if not _boss:
		return
	_boss.is_active = true
	_boss_spawned = true
	var data := {
		"boss_name": _boss.boss_name,
		"strategy": _boss.config.strategy,
		"capital": _boss.config.capital,
	}
	boss_entered.emit(_boss.boss_name, data)


## 结算 Boss 结果
func settle_boss(final_prices: Dictionary) -> void:
	if _boss and _boss.is_active:
		# 简化计算：假设 Boss 以均价买入/卖出
		var result := {"boss_name": _boss.boss_name, "profit": _boss.profit_loss, "defeated": _boss.profit_loss < 0}
		boss_defeated.emit(_boss.boss_name, result)


## 辅助：创建 action dict
func _create_action(bot_id: int, symbol: StringName, side: int, qty: int, price: float) -> Dictionary:
	return {
		"bot_id": bot_id,
		"symbol": symbol,
		"side": side,
		"quantity": qty,
		"price": price,
	}


## 获取 Bot 列表信息（含资金，供 PlayerManager 注册用）
func get_bot_info_list() -> Array[Dictionary]:
	var info: Array[Dictionary] = []
	for bot in _bots:
		info.append({"bot_id": bot.bot_id, "name": bot.bot_name,
			"strategy": bot.strategy, "cash": bot.cash})
	return info


## Boss 是否在场
func is_boss_active() -> bool:
	return _boss != null and _boss.is_active
