## 玩家相关数据结构
## 所有权: WS3 (玩家经济组)
class_name PlayerTypes


## 订单（玩家提交的交易请求）
class Order:
	var order_id: String = ""
	var player_id: int = 0
	var symbol: StringName = &""
	var side: int = GameEnums.OrderSide.BUY
	var order_type: int = GameEnums.OrderType.MARKET
	var quantity: int = 0
	var limit_price: float = 0.0  ## 仅限价单
	var status: int = GameEnums.OrderStatus.PENDING
	var fill_price: float = 0.0
	var filled_quantity: int = 0
	var timestamp: float = 0.0

	func to_dict() -> Dictionary:
		return {
			"order_id": order_id,
			"player_id": player_id,
			"symbol": symbol,
			"side": side,
			"order_type": order_type,
			"quantity": quantity,
			"limit_price": limit_price,
			"status": status,
			"fill_price": fill_price,
			"filled_quantity": filled_quantity,
			"timestamp": timestamp,
		}

	static func from_dict(data: Dictionary) -> Order:
		var o := Order.new()
		o.order_id = data.get("order_id", "")
		o.player_id = data.get("player_id", 0)
		o.symbol = StringName(data.get("symbol", ""))
		o.side = data.get("side", GameEnums.OrderSide.BUY)
		o.order_type = data.get("order_type", GameEnums.OrderType.MARKET)
		o.quantity = data.get("quantity", 0)
		o.limit_price = data.get("limit_price", 0.0)
		o.status = data.get("status", GameEnums.OrderStatus.PENDING)
		o.fill_price = data.get("fill_price", 0.0)
		o.filled_quantity = data.get("filled_quantity", 0)
		o.timestamp = data.get("timestamp", 0.0)
		return o


## 持仓（单个股票的持仓信息）
class Position:
	var symbol: StringName = &""
	var quantity: int = 0
	var avg_price: float = 0.0
	var unrealized_pnl: float = 0.0  ## 未实现盈亏
	var realized_pnl: float = 0.0    ## 已实现盈亏
	var is_short: bool = false        ## 是否为做空持仓

	func get_market_value(current_price: float) -> float:
		if is_short:
			# 卖空成交所得已经计入现金；持仓市值必须表示回补负债，
			# 否则总资产会把卖空所得重复计算一次。
			return -current_price * quantity
		else:
			return current_price * quantity

	func update_unrealized_pnl(current_price: float) -> void:
		if is_short:
			unrealized_pnl = (avg_price - current_price) * quantity
		else:
			unrealized_pnl = (current_price - avg_price) * quantity

	func to_dict() -> Dictionary:
		return {
			"symbol": symbol,
			"quantity": quantity,
			"avg_price": avg_price,
			"unrealized_pnl": unrealized_pnl,
			"realized_pnl": realized_pnl,
			"is_short": is_short,
		}

	static func from_dict(data: Dictionary) -> Position:
		var p := Position.new()
		p.symbol = StringName(data.get("symbol", ""))
		p.quantity = data.get("quantity", 0)
		p.avg_price = data.get("avg_price", 0.0)
		p.unrealized_pnl = data.get("unrealized_pnl", 0.0)
		p.realized_pnl = data.get("realized_pnl", 0.0)
		p.is_short = data.get("is_short", false)
		return p


## 玩家快照（用于网络广播和结算）
class PlayerSnapshot:
	var player_id: int = 0
	var player_name: String = ""
	var cash: float = 0.0              ## 当前现金
	var total_assets: float = 0.0      ## 总资产（现金 + 持仓市值）
	var positions: Array[Position] = []
	var pending_orders: Array[Order] = []
	var rank_points: int = 0
	var rank_tier: int = GameEnums.RankTier.BRONZE
	var extraction_result: int = GameEnums.ExtractionResult.NONE
	var session_profit: float = 0.0    ## 本局净利润

	func to_dict() -> Dictionary:
		var pos_dicts: Array[Dictionary] = []
		for p in positions:
			pos_dicts.append(p.to_dict())
		return {
			"player_id": player_id,
			"player_name": player_name,
			"cash": cash,
			"total_assets": total_assets,
			"positions": pos_dicts,
			"rank_points": rank_points,
			"rank_tier": rank_tier,
			"extraction_result": extraction_result,
			"session_profit": session_profit,
		}

	static func from_dict(data: Dictionary) -> PlayerSnapshot:
		var snap := PlayerSnapshot.new()
		snap.player_id = data.get("player_id", 0)
		snap.player_name = data.get("player_name", "")
		snap.cash = data.get("cash", 0.0)
		snap.total_assets = data.get("total_assets", 0.0)
		var raw_pos: Array = data.get("positions", [])
		for rp in raw_pos:
			snap.positions.append(Position.from_dict(rp))
		snap.rank_points = data.get("rank_points", 0)
		snap.rank_tier = data.get("rank_tier", GameEnums.RankTier.BRONZE)
		snap.extraction_result = data.get("extraction_result", GameEnums.ExtractionResult.NONE)
		snap.session_profit = data.get("session_profit", 0.0)
		return snap


## 保险柜物品
class SafeBoxItem:
	var item_type: int = GameEnums.SafeBoxItemType.CASH
	var item_id: StringName = &""  ## cash 时为 &"cash"，技能卡时为 skill_id
	var amount: float = 0.0        ## cash 时为金额
	var level: int = 0             ## 技能卡时为等级

	func to_dict() -> Dictionary:
		return {
			"item_type": item_type,
			"item_id": item_id,
			"amount": amount,
			"level": level,
		}

	static func from_dict(data: Dictionary) -> SafeBoxItem:
		var item := SafeBoxItem.new()
		item.item_type = data.get("item_type", GameEnums.SafeBoxItemType.CASH)
		item.item_id = StringName(data.get("item_id", ""))
		item.amount = data.get("amount", 0.0)
		item.level = data.get("level", 0)
		return item


## 玩家永久档案（跨局持久化）
class PlayerProfile:
	var total_funds: float = 0.0
	var rank_points: int = 0
	var rank_tier: int = GameEnums.RankTier.BRONZE
	var total_extractions: int = 0     ## 累计成功撤离次数
	var total_games: int = 0           ## 累计总局数
	var total_profit: float = 0.0      ## 累计净利润
	var highest_session_profit: float = 0.0  ## 单局最高利润
	var achievements: Array[StringName] = []
	var unlocked_eras: Array[StringName] = []
	var unlocked_skills: Array[StringName] = []
	var safe_box_slots: int = Constants.INITIAL_SAFE_BOX_SLOTS
	var safe_box_items: Array[SafeBoxItem] = []
	var skill_progress: Dictionary = {}  ## skill_id -> SkillProgress.to_dict()
	var player_level: int = 1
	var player_exp: int = 0
	var current_streak: int = 0         ## 当前连续撤离成功次数
	var total_busts: int = 0             ## 累计爆仓次数
	var era_extractions: Dictionary = {} ## era_id -> 该时代撤离成功次数
	var last_welfare_time: String = ""   ## 上次低保时间（ISO 8601）
	var total_trades: int = 0              ## 累计交易次数
	var highest_single_loss: float = 0.0   ## 单局最大亏损（正数表示）
	var total_short_profit: float = 0.0    ## 累计做空利润
	var max_streak: int = 0                ## 历史最高连胜
	var created_at: String = ""

	func get_win_rate() -> float:
		if total_games == 0:
			return 0.0
		return float(total_extractions) / float(total_games)

	func to_dict() -> Dictionary:
		var sb_dicts: Array[Dictionary] = []
		for item in safe_box_items:
			sb_dicts.append(item.to_dict())
		return {
			"total_funds": total_funds,
			"rank_points": rank_points,
			"rank_tier": rank_tier,
			"total_extractions": total_extractions,
			"total_games": total_games,
			"total_profit": total_profit,
			"highest_session_profit": highest_session_profit,
			"achievements": achievements,
			"unlocked_eras": unlocked_eras,
			"unlocked_skills": unlocked_skills,
			"safe_box_slots": safe_box_slots,
			"safe_box_items": sb_dicts,
			"skill_progress": skill_progress,
			"player_level": player_level,
			"player_exp": player_exp,
			"current_streak": current_streak,
			"total_busts": total_busts,
			"era_extractions": era_extractions,
			"last_welfare_time": last_welfare_time,
			"total_trades": total_trades,
			"highest_single_loss": highest_single_loss,
			"total_short_profit": total_short_profit,
			"max_streak": max_streak,
			"created_at": created_at,
		}

	static func from_dict(data: Dictionary) -> PlayerProfile:
		var prof := PlayerProfile.new()
		prof.total_funds = data.get("total_funds", 0.0)
		prof.rank_points = data.get("rank_points", 0)
		prof.rank_tier = data.get("rank_tier", GameEnums.RankTier.BRONZE)
		prof.total_extractions = data.get("total_extractions", 0)
		prof.total_games = data.get("total_games", 0)
		prof.total_profit = data.get("total_profit", 0.0)
		prof.highest_session_profit = data.get("highest_session_profit", 0.0)
		prof.achievements.assign(data.get("achievements", []))
		prof.unlocked_eras.assign(data.get("unlocked_eras", []))
		prof.unlocked_skills.assign(data.get("unlocked_skills", []))
		prof.safe_box_slots = data.get("safe_box_slots", Constants.INITIAL_SAFE_BOX_SLOTS)
		var raw_sb: Array = data.get("safe_box_items", [])
		for rs in raw_sb:
			prof.safe_box_items.append(SafeBoxItem.from_dict(rs))
		prof.skill_progress = data.get("skill_progress", {})
		prof.player_level = data.get("player_level", 1)
		prof.player_exp = data.get("player_exp", 0)
		prof.current_streak = data.get("current_streak", 0)
		prof.total_busts = data.get("total_busts", 0)
		prof.era_extractions = data.get("era_extractions", {})
		prof.last_welfare_time = data.get("last_welfare_time", "")
		prof.total_trades = data.get("total_trades", 0)
		prof.highest_single_loss = data.get("highest_single_loss", 0.0)
		prof.total_short_profit = data.get("total_short_profit", 0.0)
		prof.max_streak = data.get("max_streak", 0)
		prof.created_at = data.get("created_at", "")
		return prof

## 排行榜条目
class LeaderboardEntry:
	var player_name: String = ""
	var total_profit: float = 0.0
	var total_games: int = 0
	var total_extractions: int = 0
	var rank_points: int = 0
	var rank_tier: int = GameEnums.RankTier.BRONZE
	var season_id: String = ""  ## 赛季标识（如 "2026-07"）

	func get_win_rate() -> float:
		if total_games == 0:
			return 0.0
		return float(total_extractions) / float(total_games)

	func to_dict() -> Dictionary:
		return {
			"player_name": player_name,
			"total_profit": total_profit,
			"total_games": total_games,
			"total_extractions": total_extractions,
			"rank_points": rank_points,
			"rank_tier": rank_tier,
			"season_id": season_id,
		}

	static func from_dict(data: Dictionary) -> LeaderboardEntry:
		var e := LeaderboardEntry.new()
		e.player_name = data.get("player_name", "")
		e.total_profit = data.get("total_profit", 0.0)
		e.total_games = data.get("total_games", 0)
		e.total_extractions = data.get("total_extractions", 0)
		e.rank_points = data.get("rank_points", 0)
		e.rank_tier = data.get("rank_tier", GameEnums.RankTier.BRONZE)
		e.season_id = data.get("season_id", "")
		return e
