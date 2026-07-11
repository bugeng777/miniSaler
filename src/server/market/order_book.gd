## 订单簿撮合引擎
## 所有权: WS1 (市场引擎组)
## 管理限价单/市价单的提交、撮合和成交
## 参考: modelDesign.md Ch.19 市场微观结构与委托簿系统
extends RefCounted
class_name OrderBook


signal order_filled(order: MarketTypes.BookOrder, fill_price: float, fill_qty: int)
signal order_partially_filled(order: MarketTypes.BookOrder, fill_price: float, fill_qty: int)
signal order_rejected(order_id: String, reason: String)


## 每只股票维护买卖两侧挂单
class BookSide:
	var bids: Array[MarketTypes.BookOrder] = []  ## 买单（价格从高到低排序）
	var asks: Array[MarketTypes.BookOrder] = []  ## 卖单（价格从低到高排序）

var _books: Dictionary = {}  ## symbol -> BookSide
var _order_counter: int = 0
var _current_prices: Dictionary = {}  ## symbol -> float (当前市价，用于市价单成交)


## 初始化
func initialize(stock_configs: Array[Dictionary]) -> void:
	_books.clear()
	_current_prices.clear()
	_order_counter = 0
	for cfg in stock_configs:
		var symbol := StringName(cfg.get("symbol", ""))
		_books[symbol] = BookSide.new()
		_current_prices[symbol] = cfg.get("base_price", 100.0)


## 更新当前市价（由 MarketEngine 每 tick 调用）
func update_prices(prices: Dictionary) -> void:
	for symbol in prices:
		_current_prices[symbol] = prices[symbol]


## 提交订单
func submit_order(player_id: int, symbol: StringName, side: int,
		order_type: int, quantity: int, limit_price: float = 0.0) -> String:
	if not _books.has(symbol):
		var reject_id := "invalid_symbol"
		order_rejected.emit(reject_id, "Unknown symbol: " + str(symbol))
		return reject_id

	_order_counter += 1
	var order_id := "ord_%d_%d" % [player_id, _order_counter]

	var order := MarketTypes.BookOrder.new()
	order.order_id = order_id
	order.player_id = player_id
	order.symbol = symbol
	order.side = side
	order.order_type = order_type
	order.quantity = quantity
	order.remaining = quantity
	order.price = limit_price
	order.timestamp = Time.get_ticks_msec() / 1000.0

	# 市价单立即撮合
	if order_type == GameEnums.OrderType.MARKET:
		_match_market_order(order)
	else:
		# 限价单：先尝试撮合，未成交部分挂单
		_match_limit_order(order)
		if order.remaining > 0:
			_add_to_book(order)

	return order_id


## 优先下单（供"闪电下单"技能）
## 与普通下单相同，但限价单挂入簿中时插到同价位最前面
func submit_order_priority(player_id: int, symbol: StringName, side: int,
		order_type: int, quantity: int, limit_price: float = 0.0) -> String:
	if not _books.has(symbol):
		var reject_id := "invalid_symbol"
		order_rejected.emit(reject_id, "Unknown symbol: " + str(symbol))
		return reject_id

	_order_counter += 1
	var order_id := "ord_%d_%d" % [player_id, _order_counter]

	var order := MarketTypes.BookOrder.new()
	order.order_id = order_id
	order.player_id = player_id
	order.symbol = symbol
	order.side = side
	order.order_type = order_type
	order.quantity = quantity
	order.remaining = quantity
	order.price = limit_price
	# 优先订单时间戳设为更早，确保排在同价位最前
	order.timestamp = Time.get_ticks_msec() / 1000.0 - 0.001

	# 市价单立即撮合（与普通相同）
	if order_type == GameEnums.OrderType.MARKET:
		_match_market_order(order)
	else:
		_match_limit_order(order)
		if order.remaining > 0:
			_add_to_book_priority(order)

	return order_id


## 市价单撮合（逐档吃单，支持滑价）
## BUY: 从 ask 侧逐档吃单；SELL: 从 bid 侧逐档吃单
## 如果订单簿为空则 fallback 到当前市价成交
func _match_market_order(order: MarketTypes.BookOrder) -> void:
	if not _books.has(order.symbol):
		order_rejected.emit(order.order_id, "Unknown symbol: " + str(order.symbol))
		return

	var book: BookSide = _books[order.symbol]
	var is_buy := order.side == GameEnums.OrderSide.BUY
	var opposite_side: Array[MarketTypes.BookOrder] = book.asks if is_buy else book.bids

	# 逐档撮合
	while order.remaining > 0 and opposite_side.size() > 0:
		var best: MarketTypes.BookOrder = opposite_side[0]
		var fill_qty := mini(order.remaining, best.remaining)
		best.remaining -= fill_qty
		order.remaining -= fill_qty
		if order.remaining > 0:
			order_partially_filled.emit(order, best.price, fill_qty)
		else:
			order_filled.emit(order, best.price, fill_qty)
		if best.remaining <= 0:
			opposite_side.pop_front()

	# 订单簿无挂单时 fallback 到当前市价成交
	if order.remaining > 0:
		if _current_prices.has(order.symbol):
			var fallback_price := _current_prices[order.symbol]
			var remaining_qty := order.remaining
			order.remaining = 0
			order_filled.emit(order, fallback_price, remaining_qty)
		else:
			order_rejected.emit(order.order_id, "No price available and order book empty")


## 限价单撮合
func _match_limit_order(order: MarketTypes.BookOrder) -> void:
	if not _books.has(order.symbol):
		return
	var book: BookSide = _books[order.symbol]

	if order.side == GameEnums.OrderSide.BUY:
		# 买单匹配卖单（asks）
		while order.remaining > 0 and book.asks.size() > 0:
			var best_ask: MarketTypes.BookOrder = book.asks[0]
			if order.price >= best_ask.price:
				var fill_qty := mini(order.remaining, best_ask.remaining)
				best_ask.remaining -= fill_qty
				order.remaining -= fill_qty
				order_filled.emit(order, best_ask.price, fill_qty)
				if best_ask.remaining <= 0:
					book.asks.pop_front()
			else:
				break
	else:
		# 卖单匹配买单（bids）
		while order.remaining > 0 and book.bids.size() > 0:
			var best_bid: MarketTypes.BookOrder = book.bids[0]
			if order.price <= best_bid.price:
				var fill_qty := mini(order.remaining, best_bid.remaining)
				best_bid.remaining -= fill_qty
				order.remaining -= fill_qty
				order_filled.emit(order, best_bid.price, fill_qty)
				if best_bid.remaining <= 0:
					book.bids.pop_front()
			else:
				break


## 将未成交的限价单挂入订单簿（普通：按价格排序）
func _add_to_book(order: MarketTypes.BookOrder) -> void:
	var book: BookSide = _books[order.symbol]
	if order.side == GameEnums.OrderSide.BUY:
		book.bids.append(order)
		book.bids.sort_custom(func(a: MarketTypes.BookOrder, b: MarketTypes.BookOrder) -> bool:
			return a.price > b.price
		)
	else:
		book.asks.append(order)
		book.asks.sort_custom(func(a: MarketTypes.BookOrder, b: MarketTypes.BookOrder) -> bool:
			return a.price < b.price
		)


## 将优先订单挂入簿中（插到同价位最前面）
func _add_to_book_priority(order: MarketTypes.BookOrder) -> void:
	var book: BookSide = _books[order.symbol]
	if order.side == GameEnums.OrderSide.BUY:
		# 找到第一个价格低于或等于本单的位置，插入其前
		var insert_idx := book.bids.size()
		for i in range(book.bids.size()):
			if book.bids[i].price < order.price:
				insert_idx = i
				break
			elif book.bids[i].price == order.price:
				insert_idx = i  # 同价位插到最前
				break
		book.bids.insert(insert_idx, order)
	else:
		var insert_idx := book.asks.size()
		for i in range(book.asks.size()):
			if book.asks[i].price > order.price:
				insert_idx = i
				break
			elif book.asks[i].price == order.price:
				insert_idx = i  # 同价位插到最前
				break
		book.asks.insert(insert_idx, order)


## 取消挂单
func cancel_order(order_id: String, symbol: StringName) -> bool:
	if not _books.has(symbol):
		return false
	var book: BookSide = _books[symbol]
	for i in range(book.bids.size()):
		if book.bids[i].order_id == order_id:
			book.bids.remove_at(i)
			return true
	for i in range(book.asks.size()):
		if book.asks[i].order_id == order_id:
			book.asks.remove_at(i)
			return true
	return false


## 获取某只股票的订单簿深度
func get_book_depth(symbol: StringName, levels: int = 5) -> Dictionary:
	if not _books.has(symbol):
		return {"bids": [], "asks": []}
	var book: BookSide = _books[symbol]
	var bid_dicts: Array[Dictionary] = []
	var ask_dicts: Array[Dictionary] = []
	for i in range(mini(levels, book.bids.size())):
		bid_dicts.append({"price": book.bids[i].price, "quantity": book.bids[i].remaining})
	for i in range(mini(levels, book.asks.size())):
		ask_dicts.append({"price": book.asks[i].price, "quantity": book.asks[i].remaining})
	return {"bids": bid_dicts, "asks": ask_dicts}


## 重置
func reset() -> void:
	_books.clear()
	_current_prices.clear()
	_order_counter = 0
