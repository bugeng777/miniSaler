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

	# 买入检查：现金是否足够
	if side == GameEnums.OrderSide.BUY and order_type == GameEnums.OrderType.MARKET:
		var cost := _current_prices.get(symbol, 0.0) * quantity
		var fee := cost * Constants.TRANSACTION_FEE_RATE
		if state.cash < cost + fee:
			order.status = GameEnums.OrderStatus.REJECTED
			return order

	state.pending_orders.append(order)
	order_submitted.emit(player_id, order)
	return order


## 订单成交回调（由 MarketEngine 通过 GameSession 调用）
func on_order_filled(player_id: int, order_id: String, fill_price: float, fill_qty: int) -> void:
	if not _players.has(player_id):
		return
	var state: PlayerStateData = _players[player_id]

	for i in range(state.pending_orders.size()):
		var order: PlayerTypes.Order = state.pending_orders[i]
		if order.order_id == order_id:
			order.fill_price = fill_price
			order.filled_quantity = fill_qty
			order.status = GameEnums.OrderStatus.FILLED

			# 更新资金和持仓
			var cost := fill_price * fill_qty
			var fee := cost * Constants.TRANSACTION_FEE_RATE

			if order.side == GameEnums.OrderSide.BUY:
				state.cash -= (cost + fee)
				state.add_position(order.symbol, fill_qty, fill_price)
			elif order.side == GameEnums.OrderSide.SELL:
				# 持仓验证
				var pos: PlayerTypes.Position = state.positions.get(order.symbol, null)
				if not pos or pos.quantity < fill_qty:
					var reason := "SELL rejected: insufficient position in %s (have %d, need %d)" % [
						order.symbol, pos.quantity if pos else 0, fill_qty]
					push_warning("PlayerManager: " + reason)
					order.status = GameEnums.OrderStatus.REJECTED
					state.pending_orders.remove_at(i)
					order_rejected.emit(player_id, reason)
					break
				state.cash += (cost - fee)
				state.reduce_position(order.symbol, fill_qty, fill_price)
			elif order.side == GameEnums.OrderSide.SHORT:
				# 保证金验证
				var required_margin := fill_price * fill_qty * Constants.MARGIN_RATIO
				if state.cash < required_margin:
					var reason := "SHORT rejected: insufficient margin (cash $%.2f, need $%.2f)" % [
						state.cash, required_margin]
					push_warning("PlayerManager: " + reason)
					order.status = GameEnums.OrderStatus.REJECTED
					state.pending_orders.remove_at(i)
					order_rejected.emit(player_id, reason)
					break
				state.cash += (cost - fee)
				state.add_position(order.symbol, fill_qty, fill_price, true)

			state.total_trades += 1
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

	if state.cash < short_margin or total_assets <= 0.0:
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
				state.cash += pos.avg_price * pos.quantity - _current_prices[symbol] * pos.quantity
			else:
				state.cash += _current_prices[symbol] * pos.quantity
	state.positions.clear()
	state.cash = maxf(state.cash, 0.0)


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


## ─── 破产保护机制 ─────────────────────────────────────────────────────────────

## 低保检查：总资金 < $5,000 且距上次低保 > 24h → 补充至 $10,000
func check_welfare(profile: PlayerTypes.PlayerProfile) -> float:
	if profile.total_funds >= Constants.WELFARE_TRIGGER:
		return 0.0
	if profile.last_welfare_time != "":
		var last_time := Time.get_datetime_dict_from_datetime_string(profile.last_welfare_time)
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
