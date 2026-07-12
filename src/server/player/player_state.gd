## 单个玩家运行时状态
## 所有权: WS3 (玩家经济组)
## 封装一个玩家在单局内的所有运行时数据
extends RefCounted
class_name PlayerStateData


var player_id: int = 0
var player_name: String = ""
var is_bot: bool = false

## 本局资金
var cash: float = 0.0             ## 可用现金
var brought_funds: float = 0.0    ## 本局带入资金总额

## 持仓
var positions: Dictionary = {}    ## symbol -> PlayerTypes.Position

## 订单
var pending_orders: Array[PlayerTypes.Order] = []
var filled_orders: Array[PlayerTypes.Order] = []

## 本局统计
var total_trades: int = 0
var session_profit: float = 0.0

## 段位相关
var rank_points: int = 0
var rank_tier: int = GameEnums.RankTier.BRONZE


## 初始化新玩家状态
func initialize(id: int, pname: String, funds: float, is_ai: bool = false) -> void:
	player_id = id
	player_name = pname
	cash = funds
	brought_funds = funds
	is_bot = is_ai
	positions.clear()
	pending_orders.clear()
	filled_orders.clear()
	total_trades = 0
	session_profit = 0.0


## 计算总资产（现金 + 持仓市值）
func get_total_assets(prices: Dictionary) -> float:
	var assets := cash
	for symbol in positions:
		var pos: PlayerTypes.Position = positions[symbol]
		if prices.has(symbol):
			assets += pos.get_market_value(prices[symbol])
	return assets


## 更新所有持仓的未实现盈亏
func update_unrealized_pnl(prices: Dictionary) -> void:
	for symbol in positions:
		var pos: PlayerTypes.Position = positions[symbol]
		if prices.has(symbol):
			pos.update_unrealized_pnl(prices[symbol])


## 添加持仓（买入成交时调用）
func add_position(symbol: StringName, quantity: int, price: float, is_short: bool = false) -> void:
	if positions.has(symbol):
		var pos: PlayerTypes.Position = positions[symbol]
		var total_qty := pos.quantity + quantity
		if total_qty > 0:
			pos.avg_price = (pos.avg_price * pos.quantity + price * quantity) / total_qty
		pos.quantity = total_qty
	else:
		var pos := PlayerTypes.Position.new()
		pos.symbol = symbol
		pos.quantity = quantity
		pos.avg_price = price
		pos.is_short = is_short
		positions[symbol] = pos


## 减少持仓（卖出成交时调用）
func reduce_position(symbol: StringName, quantity: int, sell_price: float) -> float:
	if not positions.has(symbol):
		return 0.0
	var pos: PlayerTypes.Position = positions[symbol]
	var actual_qty := mini(quantity, pos.quantity)
	var pnl := (sell_price - pos.avg_price) * actual_qty
	pos.realized_pnl += pnl
	pos.quantity -= actual_qty
	if pos.quantity <= 0:
		positions.erase(symbol)
	return pnl


## 回补做空持仓（买入成交时调用）
func cover_short(symbol: StringName, quantity: int, cover_price: float) -> float:
	if not positions.has(symbol):
		return 0.0
	var pos: PlayerTypes.Position = positions[symbol]
	if not pos.is_short:
		return 0.0
	var actual_qty := mini(quantity, pos.quantity)
	var pnl := (pos.avg_price - cover_price) * actual_qty
	pos.realized_pnl += pnl
	pos.quantity -= actual_qty
	if pos.quantity <= 0:
		positions.erase(symbol)
	return pnl


## 生成快照
func to_snapshot(prices: Dictionary) -> PlayerTypes.PlayerSnapshot:
	var snap := PlayerTypes.PlayerSnapshot.new()
	snap.player_id = player_id
	snap.player_name = player_name
	snap.cash = cash
	snap.total_assets = get_total_assets(prices)
	snap.session_profit = snap.total_assets - brought_funds
	snap.rank_points = rank_points
	snap.rank_tier = rank_tier
	for symbol in positions:
		var pos: PlayerTypes.Position = positions[symbol]
		if prices.has(symbol):
			pos.update_unrealized_pnl(prices[symbol])
		snap.positions.append(pos)
	for order in pending_orders:
		snap.pending_orders.append(order)
	return snap
