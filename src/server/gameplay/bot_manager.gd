## AI 对手管理器
## 所有权: WS2 (游戏玩法组)
## 管理 Bot 交易者的创建、策略执行和 Boss 行为
## 参考: modelDesign.md Ch.25 AI 智能体对手系统
extends Node
class_name BotManager


## ─── 信号（接口 B：BotManager -> GameSession）─────────────────────────────
signal bot_action_executed(bot_id: int, action: Dictionary)
signal boss_entered(boss_name: String, boss_data: Dictionary)
signal boss_action_executed(player_id: int, action: Dictionary)
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
	var price_history: Dictionary = {}  ## symbol -> Array[float] 最近 N tick 价格

## Boss 状态
class BossState:
	var boss_name: String = ""
	var config: EraData.BossConfig = null
	var is_active: bool = false
	var cash: float = 0.0
	var entry_time: float = 0.0
	var last_trade_time: float = 0.0
	var profit_loss: float = 0.0  ## Boss 当前盈亏
	var positions: Dictionary = {}  ## symbol -> {"qty": int, "avg_price": float, "side": int}
	var entry_prices: Dictionary = {}  ## symbol -> float 入场时价格
	var dump_triggered: bool = false  ## 风投之王是否已触发出货


var _bots: Array[BotState] = []
var _boss: BossState = null
var _elapsed_time: float = 0.0
var _boss_spawned: bool = false
var _current_era: EraData = null
var _symbols: Array[StringName] = []
var _base_prices: Dictionary = {}  ## symbol -> base_price（用于逆向投资者判断偏离度）
var _boss_phase: int = 0  ## Boss 阶段（0=吸筹 1=拉高 2=出货），风投之王专用
var _boss_phase_timer: float = 0.0

## 策略参数
const TREND_WINDOW: int = 6           ## 趋势跟踪者观察最近 N tick
const CONTRARIAN_DEVIATION: float = 0.08  ## 逆向投资者：偏离基准价 >8% 才操作
const NOISE_PAUSE_CHANCE: float = 0.35   ## 噪音交易者：暂停观望概率
const AGGRESSIVE_BOSS_FOLLOW_CHANCE: float = 0.7  ## 激进交易者：跟随 Boss 方向概率


## 初始化 Bot 池
func start(era_config: EraData, symbols: Array[StringName], bot_count: int = 7) -> void:
	_current_era = era_config
	_symbols = symbols
	_elapsed_time = 0.0
	_boss_spawned = false
	_boss_phase = 0
	_boss_phase_timer = 0.0
	_bots.clear()
	_boss = null
	# 记录基准价（用于逆向投资者判断偏离度）
	_base_prices.clear()
	for stock_cfg in era_config.stock_configs:
		var sym := StringName(stock_cfg.get("symbol", ""))
		_base_prices[sym] = stock_cfg.get("base_price", 100.0)

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

	# 更新价格历史
	for bot in _bots:
		for symbol in prices:
			if not bot.price_history.has(symbol):
				bot.price_history[symbol] = []
			var history: Array = bot.price_history[symbol]
			history.append(prices[symbol])
			# 保留最近 TREND_WINDOW * 2 条记录（策略行动间隔比 tick 慢）
			if history.size() > TREND_WINDOW * 2:
				history.remove_at(0)

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
			# 趋势跟踪者：检查最近 N tick 动量，持续上涨才买，持续下跌才卖
			action = _trend_follower_action(bot, target_symbol, current_price)

		GameEnums.BotStrategy.CONTRARIAN:
			# 逆向投资者：价格偏离基准价 >X% 才操作
			action = _contrarian_action(bot, target_symbol, current_price)

		GameEnums.BotStrategy.NOISE_TRADER:
			# 噪音交易者：随机买卖 + 暂停观望概率
			action = _noise_trader_action(bot, target_symbol, current_price)

		GameEnums.BotStrategy.AGGRESSIVE:
			# 激进交易者：大额交易 + Boss 入场时跟随 Boss 方向
			action = _aggressive_action(bot, target_symbol, current_price)

	if not action.is_empty():
		bot_action_executed.emit(bot.bot_id, action)


## 趋势跟踪者：最近 N tick 价格持续上涨才买，持续下跌才卖
func _trend_follower_action(bot: BotState, symbol: StringName, price: float) -> Dictionary:
	if not bot.price_history.has(symbol):
		return {}
	var history: Array = bot.price_history[symbol]
	if history.size() < TREND_WINDOW:
		return {}  # 数据不足，观望

	# 检查最近 TREND_WINDOW 条价格是否单调递增/递减
	var recent: Array = history.slice(history.size() - TREND_WINDOW)
	var rising := true
	var falling := true
	for i in range(1, recent.size()):
		if recent[i] <= recent[i - 1]:
			rising = false
		if recent[i] >= recent[i - 1]:
			falling = false

	if rising:
		# 持续上涨 → 买入
		return _create_action(bot.bot_id, symbol, GameEnums.OrderSide.BUY,
			randi_range(10, 50), price)
	elif falling:
		# 持续下跌 → 卖出
		return _create_action(bot.bot_id, symbol, GameEnums.OrderSide.SELL,
			randi_range(10, 50), price)
	# 无明显趋势 → 不行动
	return {}


## 逆向投资者：价格偏离基准价 >X% 才操作
func _contrarian_action(bot: BotState, symbol: StringName, price: float) -> Dictionary:
	var base_price: float = _base_prices.get(symbol, price)
	if base_price <= 0.0:
		return {}
	var deviation := (price - base_price) / base_price

	if deviation < -CONTRARIAN_DEVIATION:
		# 价格低于基准价 >X% → 抄底买入
		var qty := int(5 + abs(deviation) * 200)  # 偏离越多买越多
		return _create_action(bot.bot_id, symbol, GameEnums.OrderSide.BUY,
			clampi(qty, 5, 40), price)
	elif deviation > CONTRARIAN_DEVIATION:
		# 价格高于基准价 >X% → 高位卖出
		var qty := int(5 + abs(deviation) * 200)
		return _create_action(bot.bot_id, symbol, GameEnums.OrderSide.SELL,
			clampi(qty, 5, 40), price)
	# 偏离不足 → 观望
	return {}


## 噪音交易者：随机买卖，但有暂停观望概率
func _noise_trader_action(bot: BotState, symbol: StringName, price: float) -> Dictionary:
	if randf() < NOISE_PAUSE_CHANCE:
		return {}  # 散户观望中
	var side := GameEnums.OrderSide.BUY if randf() < 0.5 else GameEnums.OrderSide.SELL
	return _create_action(bot.bot_id, symbol, side,
		randi_range(1, 20), price)


## 激进交易者：大额交易 + Boss 入场时跟随 Boss 方向
func _aggressive_action(bot: BotState, symbol: StringName, price: float) -> Dictionary:
	var side: int
	if _boss and _boss.is_active and randf() < AGGRESSIVE_BOSS_FOLLOW_CHANCE:
		# 跟随 Boss 方向
		side = GameEnums.OrderSide.BUY if _boss.config.direction_bias > 0 else GameEnums.OrderSide.SELL
	else:
		side = GameEnums.OrderSide.BUY if randf() < 0.5 else GameEnums.OrderSide.SELL
	return _create_action(bot.bot_id, symbol, side,
		randi_range(50, 200), price)


## Boss 交易（含时代专属行为）
func _execute_boss_trade(prices: Dictionary) -> void:
	if not _boss or not _boss.is_active:
		return
	if _symbols.is_empty() or prices.is_empty():
		return
	var era_id: StringName = _current_era.era_id if _current_era else &""
	match str(era_id):
		"hk_1997":
			_boss_trade_currency_war(prices)
		"seoul_1988":
			_boss_trade_chaebol(prices)
		"silicon_2000":
			_boss_trade_ipo_king(prices)
		"tokyo_1989":
			_boss_trade_boj(prices)
		"shanghai_2007":
			_boss_trade_manipulator(prices)
		_:
			_boss_trade_default(prices)


## 金融大鳄（香港1997）：大量做空，持续卖出施压
func _boss_trade_currency_war(prices: Dictionary) -> void:
	var target: StringName = _symbols[randi() % _symbols.size()]
	if not prices.has(target):
		return
	var qty := _boss.config.trade_volume
	if randf() < 0.3:  # 30%概率发动大额狙击
		qty = int(qty * 2.5)
	var action := _create_action(999, target, GameEnums.OrderSide.SELL, qty, prices[target])
	_update_boss_position(target, -qty, prices[target])
	boss_action_executed.emit(999, action)


## 财阀掌门人（首尔1988）：内幕交易，精准操作财阀股
func _boss_trade_chaebol(prices: Dictionary) -> void:
	var chaebol_symbols: Array[StringName] = []
	for sym in _symbols:
		if str(sym).begins_with("KRCV") or str(sym).begins_with("KRHY") or str(sym).begins_with("KRDW"):
			chaebol_symbols.append(sym)
	var target: StringName
	if chaebol_symbols.size() > 0 and randf() < 0.7:
		target = chaebol_symbols[randi() % chaebol_symbols.size()]
	else:
		target = _symbols[randi() % _symbols.size()]
	if not prices.has(target):
		return
	var side := GameEnums.OrderSide.BUY if randf() < 0.55 else GameEnums.OrderSide.SELL
	var qty := _boss.config.trade_volume
	if randf() < 0.2:  # 20%概率发动大额内幕交易
		qty = int(qty * 3.0)
	var action := _create_action(999, target, side, qty, prices[target])
	_update_boss_position(target, qty if side == GameEnums.OrderSide.BUY else -qty, prices[target])
	boss_action_executed.emit(999, action)


## 风投之王（硅谧2000）：先拉高科技股，然后出货
func _boss_trade_ipo_king(prices: Dictionary) -> void:
	_boss_phase_timer += _boss.config.trade_interval
	if _boss_phase_timer < 60.0:
		_boss_phase = 0  # 吸筹
	elif _boss_phase_timer < 120.0:
		_boss_phase = 1  # 拉高
	else:
		_boss_phase = 2  # 出货
	var tech_symbols: Array[StringName] = []
	for sym in _symbols:
		if str(sym).begins_with("USPE") or str(sym).begins_with("USWB") or str(sym).begins_with("USYA"):
			tech_symbols.append(sym)
	var target: StringName
	if tech_symbols.size() > 0:
		target = tech_symbols[randi() % tech_symbols.size()]
	else:
		target = _symbols[randi() % _symbols.size()]
	if not prices.has(target):
		return
	var side: int
	var qty: int = _boss.config.trade_volume
	if _boss_phase <= 1:
		side = GameEnums.OrderSide.BUY
		qty = int(qty * 1.5)
	else:
		side = GameEnums.OrderSide.SELL
		qty = int(qty * 2.0)
		if not _boss.dump_triggered:
			_boss.dump_triggered = true
			boss_entered.emit("风投之王出货", {"phase": "dump", "target": str(target)})
	var action := _create_action(999, target, side, qty, prices[target])
	_update_boss_position(target, qty if side == GameEnums.OrderSide.BUY else -qty, prices[target])
	boss_action_executed.emit(999, action)


## 日本银行总裁（东京1989）：稳步买入，突然加息时大量卖出
func _boss_trade_boj(prices: Dictionary) -> void:
	var target: StringName = _symbols[randi() % _symbols.size()]
	if not prices.has(target):
		return
	_boss_phase_timer += _boss.config.trade_interval
	var total_ticks := _boss.config.trade_interval * 50.0
	var time_ratio := _boss_phase_timer / total_ticks if total_ticks > 0 else 0.0
	if time_ratio < 0.8:
		var qty := int(_boss.config.trade_volume * 0.5)
		var action := _create_action(999, target, GameEnums.OrderSide.BUY, qty, prices[target])
		_update_boss_position(target, qty, prices[target])
		boss_action_executed.emit(999, action)
	else:
		var qty := int(_boss.config.trade_volume * 3.0)
		var action := _create_action(999, target, GameEnums.OrderSide.SELL, qty, prices[target])
		_update_boss_position(target, -qty, prices[target])
		boss_action_executed.emit(999, action)


## 庄家联盟（上海2007）：操纵 ST 股，拉高出货
func _boss_trade_manipulator(prices: Dictionary) -> void:
	var st_symbols: Array[StringName] = []
	for sym in _symbols:
		if str(sym).begins_with("CNST") or str(sym).begins_with("CNSJ"):
			st_symbols.append(sym)
	var target: StringName
	if st_symbols.size() > 0 and randf() < 0.8:
		target = st_symbols[randi() % st_symbols.size()]
	else:
		target = _symbols[randi() % _symbols.size()]
	if not prices.has(target):
		return
	_boss_phase_timer += _boss.config.trade_interval
	var side: int
	var qty: int = _boss.config.trade_volume
	if _boss_phase_timer < 80.0:
		side = GameEnums.OrderSide.BUY
		qty = int(qty * 1.2)
	else:
		side = GameEnums.OrderSide.SELL
		qty = int(qty * 2.5)
	var action := _create_action(999, target, side, qty, prices[target])
	_update_boss_position(target, qty if side == GameEnums.OrderSide.BUY else -qty, prices[target])
	boss_action_executed.emit(999, action)


## 默认 Boss 交易
func _boss_trade_default(prices: Dictionary) -> void:
	var target: StringName = _symbols[randi() % _symbols.size()]
	if not prices.has(target):
		return
	var side := GameEnums.OrderSide.BUY if _boss.config.direction_bias > 0 else GameEnums.OrderSide.SELL
	var action := _create_action(999, target, side, _boss.config.trade_volume, prices[target])
	_update_boss_position(target, _boss.config.trade_volume if side == GameEnums.OrderSide.BUY else -_boss.config.trade_volume, prices[target])
	boss_action_executed.emit(999, action)


## 更新 Boss 持仓记录
func _update_boss_position(symbol: StringName, qty_change: int, price: float) -> void:
	if not _boss:
		return
	if not _boss.positions.has(symbol):
		_boss.positions[symbol] = {"qty": 0, "avg_price": price, "side": 0}
	var pos: Dictionary = _boss.positions[symbol]
	var old_qty: int = pos["qty"]
	pos["qty"] = old_qty + qty_change
	if old_qty == 0 or (old_qty > 0 and qty_change > 0) or (old_qty < 0 and qty_change < 0):
		var total_cost: float = pos["avg_price"] * abs(old_qty) + price * abs(qty_change)
		pos["avg_price"] = total_cost / abs(pos["qty"]) if pos["qty"] != 0 else price
	pos["side"] = 1 if pos["qty"] > 0 else (-1 if pos["qty"] < 0 else 0)


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


## 结算 Boss 结果：判定击败、计算对面玩家奖励
## player_positions: Dictionary — player_id -> {symbol -> {"qty": int, "side": int}}
func settle_boss(final_prices: Dictionary, player_positions: Dictionary = {}) -> void:
	if not _boss or not _boss.is_active:
		return
	# 计算 Boss 最终盈亏
	_boss.profit_loss = 0.0
	for symbol in _boss.positions:
		var pos: Dictionary = _boss.positions[symbol]
		var final_price: float = final_prices.get(symbol, pos["avg_price"])
		var pnl: float = (final_price - pos["avg_price"]) * pos["qty"]
		_boss.profit_loss += pnl
	var is_defeated: bool = _boss.profit_loss < 0.0
	# 找出 Boss 对面的玩家（Boss做空时做多、Boss做多时做空的玩家）
	var winners: Array[int] = []
	var total_reward: float = 0.0
	if is_defeated:
		var boss_net_direction: int = 0
		for symbol in _boss.positions:
			boss_net_direction += sign(_boss.positions[symbol]["qty"])
		# boss_net_direction > 0 表示 Boss 总体做多，对面玩家是做空者
		# boss_net_direction < 0 表示 Boss 总体做空，对面玩家是做多者
		for pid in player_positions:
			var p_positions: Dictionary = player_positions[pid]
			var is_opposite := false
			for sym in p_positions:
				var p_side: int = sign(p_positions[sym].get("qty", 0))
				if boss_net_direction < 0 and p_side > 0:
					is_opposite = true  # Boss做空，玩家做多
				elif boss_net_direction > 0 and p_side < 0:
					is_opposite = true  # Boss做多，玩家做空
			if is_opposite:
				winners.append(pid)
		# 奖励 = Boss亏损总额的 50% 分配给对面玩家
		total_reward = abs(_boss.profit_loss) * 0.5
	var reward_per_winner: float = total_reward / winners.size() if winners.size() > 0 else 0.0
	var result := {
		"boss_name": _boss.boss_name,
		"profit": _boss.profit_loss,
		"defeated": is_defeated,
		"winners": winners,
		"reward_per_winner": reward_per_winner,
		"total_reward_pool": total_reward,
	}
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
