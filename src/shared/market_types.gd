## 市场相关数据结构
## 所有权: WS1 (市场引擎组)
## 定义 MarketEngine 与其他模块之间传递的数据类型
class_name MarketTypes


## 单只股票的实时快照（每 tick 广播）
class StockSnapshot:
	var symbol: StringName = &""
	var name: String = ""
	var sector: String = ""
	var open: float = 0.0        ## 开盘价
	var high: float = 0.0        ## 最高价
	var low: float = 0.0         ## 最低价
	var close: float = 0.0       ## 当前价（收盘价）
	var volume: float = 0.0      ## 成交量
	var volatility: float = 0.0  ## 当前波动率
	var drift: float = 0.0       ## 当前漂移率
	var momentum: float = 0.0    ## 动量
	var is_circuit_broken: bool = false  ## 是否熔断中
	var circuit_break_remaining: float = 0.0  ## 熔断剩余时间

	func to_dict() -> Dictionary:
		return {
			"symbol": symbol,
			"name": name,
			"sector": sector,
			"open": open,
			"high": high,
			"low": low,
			"close": close,
			"volume": volume,
			"volatility": volatility,
			"drift": drift,
			"momentum": momentum,
			"is_circuit_broken": is_circuit_broken,
			"circuit_break_remaining": circuit_break_remaining,
		}

	static func from_dict(data: Dictionary) -> StockSnapshot:
		var snap := StockSnapshot.new()
		snap.symbol = StringName(data.get("symbol", ""))
		snap.name = data.get("name", "")
		snap.sector = data.get("sector", "")
		snap.open = data.get("open", 0.0)
		snap.high = data.get("high", 0.0)
		snap.low = data.get("low", 0.0)
		snap.close = data.get("close", 0.0)
		snap.volume = data.get("volume", 0.0)
		snap.volatility = data.get("volatility", 0.0)
		snap.drift = data.get("drift", 0.0)
		snap.momentum = data.get("momentum", 0.0)
		snap.is_circuit_broken = data.get("is_circuit_broken", false)
		snap.circuit_break_remaining = data.get("circuit_break_remaining", 0.0)
		return snap


## 一次 tick 的完整市场数据（用于网络广播）
class TickData:
	var tick_index: int = 0
	var elapsed_time: float = 0.0
	var fear_greed_index: float = 50.0  ## 恐惧贪婪指数 0-100
	var snapshots: Array[StockSnapshot] = []

	func to_dict() -> Dictionary:
		var snap_dicts: Array[Dictionary] = []
		for snap in snapshots:
			snap_dicts.append(snap.to_dict())
		return {
			"tick_index": tick_index,
			"elapsed_time": elapsed_time,
			"fear_greed_index": fear_greed_index,
			"snapshots": snap_dicts,
		}

	static func from_dict(data: Dictionary) -> TickData:
		var tick := TickData.new()
		tick.tick_index = data.get("tick_index", 0)
		tick.elapsed_time = data.get("elapsed_time", 0.0)
		tick.fear_greed_index = data.get("fear_greed_index", 50.0)
		var raw_snaps: Array = data.get("snapshots", [])
		for raw in raw_snaps:
			tick.snapshots.append(StockSnapshot.from_dict(raw))
		return tick


## 订单簿中单个挂单
class BookOrder:
	var order_id: String = ""
	var player_id: int = 0
	var symbol: StringName = &""
	var side: int = GameEnums.OrderSide.BUY   ## GameEnums.OrderSide
	var order_type: int = GameEnums.OrderType.LIMIT
	var price: float = 0.0       ## 限价单价格（市价单为 0）
	var quantity: int = 0
	var remaining: int = 0       ## 剩余数量
	var timestamp: float = 0.0   ## 提交时间

	func to_dict() -> Dictionary:
		return {
			"order_id": order_id,
			"player_id": player_id,
			"symbol": symbol,
			"side": side,
			"order_type": order_type,
			"price": price,
			"quantity": quantity,
			"remaining": remaining,
			"timestamp": timestamp,
		}

	static func from_dict(data: Dictionary) -> BookOrder:
		var order := BookOrder.new()
		order.order_id = data.get("order_id", "")
		order.player_id = data.get("player_id", 0)
		order.symbol = StringName(data.get("symbol", ""))
		order.side = data.get("side", GameEnums.OrderSide.BUY)
		order.order_type = data.get("order_type", GameEnums.OrderType.LIMIT)
		order.price = data.get("price", 0.0)
		order.quantity = data.get("quantity", 0)
		order.remaining = data.get("remaining", 0)
		order.timestamp = data.get("timestamp", 0.0)
		return order


## 成交记录
class TradeRecord:
	var trade_id: String = ""
	var symbol: StringName = &""
	var buy_order_id: String = ""
	var sell_order_id: String = ""
	var price: float = 0.0
	var quantity: int = 0
	var timestamp: float = 0.0

	func to_dict() -> Dictionary:
		return {
			"trade_id": trade_id,
			"symbol": symbol,
			"buy_order_id": buy_order_id,
			"sell_order_id": sell_order_id,
			"price": price,
			"quantity": quantity,
			"timestamp": timestamp,
		}

	static func from_dict(data: Dictionary) -> TradeRecord:
		var record := TradeRecord.new()
		record.trade_id = data.get("trade_id", "")
		record.symbol = StringName(data.get("symbol", ""))
		record.buy_order_id = data.get("buy_order_id", "")
		record.sell_order_id = data.get("sell_order_id", "")
		record.price = data.get("price", 0.0)
		record.quantity = data.get("quantity", 0)
		record.timestamp = data.get("timestamp", 0.0)
		return record
