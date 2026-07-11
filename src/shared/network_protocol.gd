## 网络协议定义
## 所有权: WS4 (网络会话组)
## 所有 RPC 方法名常量和消息格式在此统一定义
class_name NetworkProtocol


# ─── Server -> Client 广播消息类型 ─────────────────────────────────────────────
const MSG_MARKET_TICK := &"sync_market_tick"
const MSG_MARKET_TICK_DELTA := &"sync_market_tick_delta"
const MSG_NEWS := &"sync_news"
const MSG_EXTRACTION_WINDOW := &"sync_extraction_window"
const MSG_PLAYER_STATE := &"sync_player_state"
const MSG_GAME_PHASE := &"sync_game_phase"
const MSG_SKILL_STATE := &"sync_skill_state"
const MSG_BOSS_EVENT := &"sync_boss_event"
const MSG_SETTLEMENT := &"sync_settlement"
const MSG_SAFE_BOX := &"sync_safe_box"
const MSG_RANK_UPDATE := &"sync_rank_update"
const MSG_ACHIEVEMENT := &"sync_achievement"
const MSG_CHAT := &"sync_chat"
const MSG_PLAYER_READY := &"sync_player_ready"
const MSG_STATE_SYNC := &"sync_state"
const MSG_LEADERBOARD_SYNC := &"sync_leaderboard"
const MSG_BOSS_DEFEATED := &"sync_boss_defeated"
const MSG_SKILL_EFFECT := &"sync_skill_effect"
const MSG_MATCH_FOUND := &"sync_match_found"

# ─── Client -> Server 请求消息类型 ─────────────────────────────────────────────
const MSG_SUBMIT_ORDER := &"submit_order"
const MSG_CANCEL_ORDER := &"cancel_order"
const MSG_REQUEST_EXTRACTION := &"request_extraction"
const MSG_ACTIVATE_SKILL := &"activate_skill"
const MSG_SELECT_ERA := &"select_era"
const MSG_CONFIGURE_LOADOUT := &"configure_loadout"
const MSG_READY := &"ready"

# ─── 消息构建辅助 ────────────────────────────────────────────────────────────────

## 构建市场 tick 广播数据
static func build_market_tick_msg(tick_data: MarketTypes.TickData) -> Dictionary:
	return {
		"msg_type": MSG_MARKET_TICK,
		"data": tick_data.to_dict(),
	}


static func build_market_tick_delta(prev_snapshots: Dictionary,
		current: MarketTypes.TickData) -> Dictionary:
	var changed: Array[Dictionary] = []
	for snap in current.snapshots:
		var prev: MarketTypes.StockSnapshot = prev_snapshots.get(snap.symbol, null)
		if prev == null or _snapshot_changed(prev, snap):
			changed.append(snap.to_dict())
	return {"msg_type": MSG_MARKET_TICK_DELTA, "tick_index": current.tick_index,
		"elapsed_time": current.elapsed_time,
		"fear_greed_index": current.fear_greed_index, "changed": changed}


static func _snapshot_changed(prev: MarketTypes.StockSnapshot,
		curr: MarketTypes.StockSnapshot) -> bool:
	if absf(prev.close - curr.close) > 0.001: return true
	if absf(prev.volume - curr.volume) > 0.001: return true
	if prev.is_circuit_broken != curr.is_circuit_broken: return true
	if absf(prev.high - curr.high) > 0.001: return true
	if absf(prev.low - curr.low) > 0.001: return true
	return false

## 构建新闻广播数据
static func build_news_msg(text: String, impact: int, magnitude: float,
		sentiment: int, symbol: StringName = &"") -> Dictionary:
	return {
		"msg_type": MSG_NEWS,
		"text": text,
		"impact": impact,
		"magnitude": magnitude,
		"sentiment": sentiment,
		"symbol": symbol,
	}

## 构建撤离窗口状态广播
static func build_extraction_window_msg(is_open: bool, remaining: float,
		window_type: String = "timed") -> Dictionary:
	return {
		"msg_type": MSG_EXTRACTION_WINDOW,
		"is_open": is_open,
		"remaining": remaining,
		"window_type": window_type,
	}

## 构建游戏阶段切换广播
static func build_game_phase_msg(phase: int, extra_data: Dictionary = {}) -> Dictionary:
	return {
		"msg_type": MSG_GAME_PHASE,
		"phase": phase,
		"data": extra_data,
	}

## 构建结算数据
static func build_settlement_msg(players: Array[Dictionary], winner_id: int,
		extraction_results: Dictionary) -> Dictionary:
	return {
		"msg_type": MSG_SETTLEMENT,
		"players": players,
		"winner_id": winner_id,
		"extraction_results": extraction_results,
	}


static func build_chat_msg(player_id: int, text: String) -> Dictionary:
	return {"msg_type": MSG_CHAT, "player_id": player_id, "text": text}


static func build_player_ready_msg(player_id: int, is_ready: bool) -> Dictionary:
	return {"msg_type": MSG_PLAYER_READY, "player_id": player_id, "is_ready": is_ready}


static func build_match_found_msg(room_id: String, players: Array) -> Dictionary:
	return {"msg_type": MSG_MATCH_FOUND, "room_id": room_id, "players": players}


static func build_boss_defeated_msg(boss_name: String, result: Dictionary) -> Dictionary:
	return {"msg_type": MSG_BOSS_DEFEATED, "boss_name": boss_name, "result": result}


static func build_skill_effect_msg(player_id: int, skill_id: StringName, effect: Dictionary) -> Dictionary:
	return {"msg_type": MSG_SKILL_EFFECT, "player_id": player_id, "skill_id": skill_id, "effect": effect}


static func build_leaderboard_msg(entries: Array) -> Dictionary:
	return {"msg_type": MSG_LEADERBOARD_SYNC, "entries": entries}
