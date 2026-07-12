## 玩家管理器
## 所有权: WS3 (玩家经济组)
## 管理所有玩家的资金、持仓、订单执行、爆仓判定
extends Node
class_name PlayerManager


## ─── 信号（接口 C：PlayerManager -> GameSession）──────────────────────────
signal order_submitted(player_id: int, order: PlayerTypes.Order)
signal order_filled(player_id: int, order: PlayerTypes.Order, fill_price: float)
signal player_balance_changed(player_id: int, cash: float, total_assets: float)
signal player_bust_detected(player_id: int)
signal order_rejected(player_id: int, reason: String)
signal level_up(player_id: int, new_level: int)


## 玩家状态表
var _players: Dictionary = {}  ## player_id -> PlayerStateData
## 当前市场价格引用（由 GameSession 每 tick 更新）
var _current_prices: Dictionary = {}
## 技能效果追踪
var _bust_protection: Dictionary = {}  ## player_id -> retain_ratio (0.0~1.0)
var _fund_modifiers: Dictionary = {}   ## player_id -> {skill_id: value}
var _order_modifiers: Dictionary = {}  ## player_id -> {skill_id: value}


## 注册玩家
func register_player(player_id: int, player_name: String, funds: float, is_bot: bool = false) -> void:
	var state := PlayerStateData.new()
	state.initialize(player_id, player_name, funds, is_bot)
	_players[player_id] = state


## 注销玩家
func unregister_player(player_id: int) -> void:
	_players.erase(player_id)


## 更新市场价格引用
func update_prices(prices: Dictionary) -> void:
	_current_prices = prices
	for pid in _players:
		var state: PlayerStateData = _players[pid]
		state.update_unrealized_pnl(prices)


## 提交订单
func submit_order(player_id: int, symbol: StringName, side: int,
		order_type: int, quantity: int, limit_price: float = 0.0) -> PlayerTypes.Order:
	if not _players.has(player_id):
		return null
	var state: PlayerStateData = _players[player_id]

	var order := PlayerTypes.Order.new()
	order.order_id = "p_%d_%d" % [player_id, Time.get_ticks_msec()]
	order.player_id = player_id
	order.symbol = symbol
	order.side = side
	order.order_type = order_type
	order.quantity = quantity
	order.limit_price = limit_price
	order.timestamp = Time.get_ticks_msec() / 1000.0

	var rejection := _validate_order(state, order)
	if not rejection.is_empty():
		order.status = GameEnums.OrderStatus.REJECTED
		order_rejected.emit(player_id, rejection)
		return order

	state.pending_orders.append(order)
	order_submitted.emit(player_id, order)
	return order


## 市场层拒单时回滚已经登记的待成交订单。
func reject_pending_order(player_id: int, order_id: String, reason: String) -> void:
	if not _players.has(player_id):
		return
	var state: PlayerStateData = _players[player_id]
	for i in range(state.pending_orders.size()):
		var order: PlayerTypes.Order = state.pending_orders[i]
		if order.order_id == order_id:
			order.status = GameEnums.OrderStatus.REJECTED
			state.pending_orders.remove_at(i)
			order_rejected.emit(player_id, reason)
			return


## 订单成交回调（由 MarketEngine 通过 GameSession 调用）
func on_order_filled(player_id: int, order_id: String, fill_price: float, fill_qty: int) -> void:
	if not _players.has(player_id):
		return
	var state: PlayerStateData = _players[player_id]

	for i in range(state.pending_orders.size()):
		var order: PlayerTypes.Order = state.pending_orders[i]
		if order.order_id == order_id:
			var previous_qty := order.filled_quantity
			var new_qty := previous_qty + fill_qty
			order.fill_price = (
				order.fill_price * previous_qty + fill_price * fill_qty
			) / maxf(float(new_qty), 1.0)
			order.filled_quantity = new_qty
			order.status = (GameEnums.OrderStatus.FILLED
				if new_qty >= order.quantity else GameEnums.OrderStatus.PARTIAL)

			# 更新资金和持仓
			var cost := fill_price * fill_qty
			var fee: float = cost * _get_fee_rate(state)

			if order.side == GameEnums.OrderSide.BUY:
				state.cash -= (cost + fee)
				var existing: PlayerTypes.Position = state.positions.get(order.symbol, null)
				if existing and existing.is_short:
					var short_profit := state.cover_short(order.symbol, fill_qty, fill_price)
					if short_profit > 0.0:
						state.cash += short_profit * _get_modifier(
							_fund_modifiers, player_id, &"short_expert")
				else:
					state.add_position(order.symbol, fill_qty, fill_price)
			elif order.side == GameEnums.OrderSide.SELL:
				state.cash += (cost - fee)
				state.reduce_position(order.symbol, fill_qty, fill_price)
			elif order.side == GameEnums.OrderSide.SHORT:
				state.cash += (cost - fee)
				state.add_position(order.symbol, fill_qty, fill_price, true)

			state.total_trades += 1
			if order.status == GameEnums.OrderStatus.FILLED:
				state.filled_orders.append(order)
				state.pending_orders.remove_at(i)

			order_filled.emit(player_id, order, fill_price)
			player_balance_changed.emit(player_id, state.cash,
				state.get_total_assets(_current_prices))
			break


## 检查爆仓
func check_bust(player_id: int) -> bool:
	if not _players.has(player_id):
		return false
	var state: PlayerStateData = _players[player_id]
	var total_assets := state.get_total_assets(_current_prices)

	# 做空保证金检查
	var short_margin := 0.0
	for symbol in state.positions:
		var pos: PlayerTypes.Position = state.positions[symbol]
		if pos.is_short and _current_prices.has(symbol):
			short_margin += _current_prices[symbol] * pos.quantity * Constants.MARGIN_RATIO

	if total_assets < short_margin or total_assets <= 0.0:
		player_bust_detected.emit(player_id)
		return true
	return false


## 强制平仓（爆仓时调用）
func force_liquidate(player_id: int) -> void:
	if not _players.has(player_id):
		return
	var state: PlayerStateData = _players[player_id]
	for symbol in state.positions.keys():
		var pos: PlayerTypes.Position = state.positions[symbol]
		if _current_prices.has(symbol):
			if pos.is_short:
				state.cash -= _current_prices[symbol] * pos.quantity
			else:
				state.cash += _current_prices[symbol] * pos.quantity
	state.positions.clear()
	state.cash = maxf(state.cash, 0.0)
	# 爆仓保护：钢铁意志等技能保留部分资金
	var retained := apply_bust_protection(player_id)
	if retained > 0.0 and state.cash < retained:
		state.cash = retained


## 获取玩家状态
func get_player_state(player_id: int) -> PlayerStateData:
	return _players.get(player_id, null)


## 获取玩家快照
func get_player_snapshot(player_id: int) -> PlayerTypes.PlayerSnapshot:
	if _players.has(player_id):
		return _players[player_id].to_snapshot(_current_prices)
	return null


## 获取所有玩家快照
func get_all_snapshots() -> Array[PlayerTypes.PlayerSnapshot]:
	var snaps: Array[PlayerTypes.PlayerSnapshot] = []
	for pid in _players:
		snaps.append(_players[pid].to_snapshot(_current_prices))
	return snaps


## 清理所有玩家
func clear_all() -> void:
	_players.clear()
	_current_prices.clear()
	_bust_protection.clear()
	_fund_modifiers.clear()
	_order_modifiers.clear()


## ─── 破产保护机制 ─────────────────────────────────────────────────────────────

## 低保检查：总资金 < $5,000 且距上次低保 > 24h → 补充至 $10,000
func check_welfare(profile: PlayerTypes.PlayerProfile) -> float:
	if profile.total_funds >= Constants.WELFARE_TRIGGER:
		return 0.0
	if profile.last_welfare_time != "":
		var last_time: Dictionary = Time.get_datetime_dict_from_datetime_string(profile.last_welfare_time, false)
		var now := Time.get_datetime_dict_from_system()
		var hours_diff := _hours_between(last_time, now)
		if hours_diff < Constants.WELFARE_COOLDOWN_HOURS:
			return 0.0
	var refill := Constants.WELFARE_REFILL - profile.total_funds
	push_warning("PlayerManager: Welfare triggered — supplementing $%.2f" % refill)
	return refill


## 新手保护：前 10 局爆仓时保留 30% 损失
func apply_newbie_protection(profile: PlayerTypes.PlayerProfile, session_loss: float) -> float:
	if profile.total_games > Constants.NEWBIE_PROTECTION_GAMES:
		return 0.0
	if session_loss <= 0.0:
		return 0.0
	var protected_amount := session_loss * Constants.NEWBIE_PROTECTION_RATIO
	push_warning("PlayerManager: Newbie protection — saving $%.2f of $%.2f loss" % [protected_amount, session_loss])
	return protected_amount


## 辅助：计算两个时间字典之间的小时差
func _hours_between(from: Dictionary, to: Dictionary) -> float:
	var from_unix := Time.get_unix_time_from_datetime_dict(from)
	var to_unix := Time.get_unix_time_from_datetime_dict(to)
	return (to_unix - from_unix) / 3600.0


## 硬底线保护：确保保险柜永不被清零
## 在结算/爆仓后调用，保证至少有一笔现金在保险柜中
func ensure_safe_box_minimum(profile: PlayerTypes.PlayerProfile) -> void:
	var has_cash := false
	for item in profile.safe_box_items:
		if item.item_type == GameEnums.SafeBoxItemType.CASH and item.amount > 0.0:
			has_cash = true
			break
	if not has_cash:
		# 硬底线：向保险柜注入最低保底现金
		var min_item := PlayerTypes.SafeBoxItem.new()
		min_item.item_type = GameEnums.SafeBoxItemType.CASH
		min_item.item_id = &"cash"
		min_item.amount = 1000.0  ## 保底 $1,000
		if profile.safe_box_items.size() < profile.safe_box_slots:
			profile.safe_box_items.append(min_item)
		elif profile.safe_box_items.size() > 0:
			# 替换最后一个非现金物品或追加
			profile.safe_box_items.append(min_item)
		push_warning("PlayerManager: Safe box hard bottom activated — added $1000 minimum")


## ─── 经验值系统 ───────────────────────────────────────────────────────────────

## 计算本局经验值
static func calculate_session_exp(profit: float, extracted: bool, trades_count: int) -> int:
	var exp := 0
	exp += trades_count * 5
	if profit > 0.0:
		exp += int(profit / 100.0)
	if extracted:
		exp += 50
	return exp


## 应用经验值并处理升级
func apply_experience(player_id: int, profile: PlayerTypes.PlayerProfile, exp_gained: int) -> Dictionary:
	profile.player_exp += exp_gained
	var leveled_up := false
	var new_level := profile.player_level
	while profile.player_exp >= profile.player_level * 100:
		profile.player_exp -= profile.player_level * 100
		profile.player_level += 1
		new_level = profile.player_level
		leveled_up = true
		level_up.emit(player_id, new_level)
	return {"leveled_up": leveled_up, "new_level": new_level, "exp_gained": exp_gained}


## ─── 技能资金效果（供 WS2 SkillSystem 调用）──────────────────────────────────

## 现金利息："现金为王"技能每 tick 调用
## rate: 利率（如 0.001 = 每 tick 0.1%）
func apply_cash_interest(player_id: int, rate: float) -> float:
	if not _players.has(player_id):
		return 0.0
	var state: PlayerStateData = _players[player_id]
	if state.cash <= 0.0:
		return 0.0
	var interest := state.cash * rate
	state.cash += interest
	return interest


## 注册爆仓保护："钢铁意志"技能入局时调用
## retain_ratio: 爆仓时保留的资金比例（如 0.1 = 保留 10%）
func register_bust_protection(player_id: int, retain_ratio: float) -> void:
	_bust_protection[player_id] = retain_ratio


## 获取玩家爆仓保护比例
func get_bust_protection_ratio(player_id: int) -> float:
	return _bust_protection.get(player_id, 0.0)


## 应用爆仓保护：在 force_liquidate 前调用，返回保护后保留的金额
func apply_bust_protection(player_id: int) -> float:
	var ratio: float = _bust_protection.get(player_id, 0.0)
	if ratio <= 0.0:
		return 0.0
	if not _players.has(player_id):
		return 0.0
	var state: PlayerStateData = _players[player_id]
	var retained := state.brought_funds * ratio
	return retained


## 应用资金类技能契约。这里只保存服务端权威修改器；结算与每 tick
## 逻辑统一从该表读取，避免 Main 依赖具体技能实现类。
func apply_fund_modifier(player_id: int, skill_id: StringName, _target: StringName,
		value: float, _duration: float = 0.0) -> void:
	if not _fund_modifiers.has(player_id):
		_fund_modifiers[player_id] = {}
	_fund_modifiers[player_id][skill_id] = value
	if skill_id == &"iron_will":
		register_bust_protection(player_id, value)


## 应用订单类技能契约（手续费减免等）。
func apply_order_modifier(player_id: int, skill_id: StringName, _target: StringName,
		value: float, _duration: float = 0.0) -> void:
	if not _order_modifiers.has(player_id):
		_order_modifiers[player_id] = {}
	_order_modifiers[player_id][skill_id] = value


## 每秒应用持续资金效果，由 GameSession 的权威计时器调用。
func apply_tick_modifiers(delta: float) -> void:
	for player_id in _players:
		var rate := _get_modifier(_fund_modifiers, player_id, &"cash_is_king")
		if rate > 0.0:
			apply_cash_interest(player_id, rate * delta)


func _validate_order(state: PlayerStateData, order: PlayerTypes.Order) -> String:
	if order.quantity <= 0:
		return "Order rejected: quantity must be positive"
	if order.side < GameEnums.OrderSide.BUY or order.side > GameEnums.OrderSide.SHORT:
		return "Order rejected: invalid side"
	if order.order_type < GameEnums.OrderType.MARKET or order.order_type > GameEnums.OrderType.LIMIT:
		return "Order rejected: invalid order type"
	if order.order_type == GameEnums.OrderType.LIMIT and order.limit_price <= 0.0:
		return "Order rejected: limit price must be positive"
	var estimated_price: float = (order.limit_price
		if order.order_type == GameEnums.OrderType.LIMIT
		else _current_prices.get(order.symbol, 0.0))
	if estimated_price <= 0.0:
		return "Order rejected: no market price for %s" % order.symbol
	var pos: PlayerTypes.Position = state.positions.get(order.symbol, null)
	if order.side == GameEnums.OrderSide.SELL:
		var available := 0 if pos == null or pos.is_short else pos.quantity
		available -= _get_pending_sell_qty(state, order.symbol)
		if available < order.quantity:
			return "SELL rejected: insufficient position in %s (available %d, need %d)" % [
				order.symbol, maxi(available, 0), order.quantity]
	if order.side == GameEnums.OrderSide.SHORT and pos != null and not pos.is_short:
		return "SHORT rejected: close the long position first"
	if order.side == GameEnums.OrderSide.BUY and pos != null and pos.is_short:
		if order.quantity > pos.quantity:
			return "BUY rejected: cover at most %d short shares first" % pos.quantity
	if order.side == GameEnums.OrderSide.BUY and (pos == null or not pos.is_short):
		var max_positions := 1 if _get_modifier(
			_fund_modifiers, state.player_id, &"all_in") > 0.0 else 0
		if max_positions > 0 and pos == null and state.positions.size() >= max_positions:
			return "BUY rejected: all-in skill limits positions to %d" % max_positions
		var cost := estimated_price * order.quantity
		if state.cash < cost * (1.0 + _get_fee_rate(state)):
			return "BUY rejected: insufficient cash"
	if order.side == GameEnums.OrderSide.SHORT:
		var required_margin := estimated_price * order.quantity * Constants.MARGIN_RATIO
		if state.get_total_assets(_current_prices) < required_margin:
			return "SHORT rejected: insufficient margin"
	return ""


func _get_pending_sell_qty(state: PlayerStateData, symbol: StringName) -> int:
	var total := 0
	for pending in state.pending_orders:
		if pending.symbol == symbol and pending.side == GameEnums.OrderSide.SELL:
			total += pending.quantity - pending.filled_quantity
	return total


func _get_fee_rate(state: PlayerStateData) -> float:
	var reduction := 0.0
	if state.positions.size() > 3:
		reduction = _get_modifier(_order_modifiers, state.player_id, &"diversify")
	return Constants.TRANSACTION_FEE_RATE * (1.0 - clampf(reduction, 0.0, 1.0))


func _get_modifier(store: Dictionary, player_id: int, skill_id: StringName) -> float:
	var player_modifiers: Dictionary = store.get(player_id, {})
	return float(player_modifiers.get(skill_id, 0.0))
