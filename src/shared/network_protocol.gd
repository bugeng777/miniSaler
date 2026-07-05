## 网络协议定义
## 所有权: WS4 (网络会话组)
## 所有 RPC 方法名常量和消息格式在此统一定义
class_name NetworkProtocol


# ─── Server -> Client 广播消息类型 ─────────────────────────────────────────────
const MSG_MARKET_TICK := &"sync_market_tick"
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
