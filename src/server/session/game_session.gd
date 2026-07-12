## 游戏会话管理器
## 所有权: WS4 (网络会话组)
## 核心中枢: 游戏阶段状态机、子系统信号中转与数据广播
## 所有子系统通过 GameSession 连接，禁止子系统之间直接引用
extends Node
class_name GameSession


## ─── 游戏阶段变更信号 ──────────────────────────────────────────────────────
signal phase_changed(phase: int, data: Dictionary)
## Host 模式下本地数据接收信号
signal data_received(msg: Dictionary)


## ─── 注入的子系统引用（由 main.gd 注入）────────────────────────────────────
var market_engine: MarketEngine = null
var era_manager: EraManager = null
var extraction_engine: ExtractionEngine = null
var news_system: NewsSystem = null
var skill_system: SkillSystem = null
var bot_manager: BotManager = null
var player_manager: PlayerManager = null
var safe_box_manager: SafeBoxManager = null
var rank_system: RankSystem = null
var achievement_system: AchievementSystem = null
var save_manager: SaveManager = null
var matchmaking: Matchmaking = null
var leaderboard_manager: LeaderboardManager = null

## ─── 状态 ────────────────────────────────────────────────────────────────────
var _current_phase: int = GameEnums.GamePhase.ERA_SELECT
var _current_era: EraData = null
var _trading_timer: Timer = null
var _trading_remaining: float = 0.0
var _loadout_timer: Timer = null
var _is_host: bool = false
var _has_enet: bool = false  ## 是否启动了 ENet 服务器
var _server_peer: ENetMultiplayerPeer = null

var _settlement_triggered: bool = false  ## 防止重复结算
var _tick_count: int = 0  ## 市场 tick 计数器
var _ready_players: Dictionary = {}
var _prev_snapshots: Dictionary = {}


func _ready() -> void:
	_trading_timer = Timer.new()
	_trading_timer.wait_time = 1.0
	_trading_timer.timeout.connect(_on_trading_tick)
	add_child(_trading_timer)
	_loadout_timer = Timer.new()
	_loadout_timer.one_shot = true
	_loadout_timer.timeout.connect(_on_loadout_timeout)
	add_child(_loadout_timer)


## ─── Host 模式启动（不启动 ENet，所有调用直连）─────────────────────────────
func start_host_mode() -> void:
	_is_host = true
	_has_enet = false
	print("GameSession: Host mode (local only, no ENet)")


## ─── ENet 服务器启动（多人模式用）───────────────────────────────────────────
func start_server(port: int = Constants.DEFAULT_PORT) -> bool:
	_server_peer = ENetMultiplayerPeer.new()
	var err := _server_peer.create_server(port, Constants.MAX_PLAYERS)
	if err != OK:
		push_error("GameSession: Failed to start server on port %d: %s" % [port, error_string(err)])
		return false
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.multiplayer_peer = _server_peer
	_is_host = true
	_has_enet = true
	print("GameSession: ENet server started on port %d" % port)
	return true


## 停止服务器
func stop_server() -> void:
	if _server_peer:
		_server_peer.close()
		_server_peer = null
	_has_enet = false


## ─── 阶段流转 ────────────────────────────────────────────────────────────────

func goto_era_select() -> void:
	_settlement_triggered = false
	_ready_players.clear()
	_prev_snapshots.clear()
	# 清理本局数据
	if player_manager:
		player_manager.clear_all()
	_set_phase(GameEnums.GamePhase.ERA_SELECT, {})


func goto_loadout(era_config: EraData) -> void:
	_current_era = era_config
	_set_phase(GameEnums.GamePhase.LOADOUT, {"era": era_config.to_dict()})
	_loadout_timer.wait_time = Constants.LOADOUT_DURATION
	_loadout_timer.start()


func goto_enter_market() -> void:
	_set_phase(GameEnums.GamePhase.ENTER_MARKET, {})
	if market_engine and _current_era:
		market_engine.start_market(_current_era)
	if news_system:
		news_system.start(_current_era.era_id)
	if extraction_engine:
		extraction_engine.start(_current_era.extraction_config)
	# 获取股票符号列表
	var symbols: Array[StringName] = []
	for cfg in _current_era.stock_configs:
		symbols.append(StringName(cfg.get("symbol", "")))
	if bot_manager:
		bot_manager.start(_current_era, symbols)
		# 注册 Bot 到 PlayerManager
		if player_manager:
			for bot_info in bot_manager.get_bot_info_list():
				player_manager.register_player(
					bot_info["bot_id"],
					bot_info["name"],
					bot_info.get("cash", 100_000.0),
					true)  # is_bot = true


func goto_trading() -> void:
	_trading_remaining = randf_range(Constants.TRADING_DURATION_MIN, Constants.TRADING_DURATION_MAX)
	_set_phase(GameEnums.GamePhase.TRADING, {"duration": _trading_remaining})
	_trading_timer.start()


func goto_extract(player_id: int, profit: float) -> void:
	_set_phase(GameEnums.GamePhase.EXTRACT, {"player_id": player_id, "profit": profit})


func goto_settlement() -> void:
	if _settlement_triggered:
		return
	_settlement_triggered = true
	if market_engine:
		market_engine.stop_market()
	if news_system:
		news_system.stop()
	_trading_timer.stop()
	var settlement_data := _build_settlement_data()
	_set_phase(GameEnums.GamePhase.SETTLEMENT, settlement_data)


## ─── Host 模式直连方法（由 main.gd 调用，不经过 RPC）─────────────────────

## Host 选择时代
func host_select_era(era_id: StringName) -> void:
	if era_manager:
		_current_era = era_manager.set_current_era(era_id)
		if _current_era:
			goto_loadout(_current_era)


## Host 准备完成，开始游戏
func host_start_game() -> void:
	_settlement_triggered = false
	_tick_count = 0
	_prev_snapshots.clear()
	_loadout_timer.stop()  # 取消自动超时
	goto_enter_market()
	# 短暂延迟后进入交易
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		goto_trading()
	)


## Host 提交订单
func host_submit_order(player_id: int, symbol: StringName, side: int,
		order_type: int, quantity: int, limit_price: float = 0.0) -> void:
	if not market_engine or not player_manager:
		return
	# 先在经济层做权威校验并登记订单，再把同一个 ID 交给撮合层。
	# 市价单会同步成交，因此顺序不能颠倒。
	var player_order := player_manager.submit_order(
		player_id, symbol, side, order_type, quantity, limit_price)
	if player_order == null or player_order.status == GameEnums.OrderStatus.REJECTED:
		return
	var market_order_id := market_engine.submit_order(
		player_id, symbol, side, order_type, quantity, limit_price,
		player_order.order_id)
	if market_order_id != player_order.order_id:
		player_manager.reject_pending_order(
			player_id, player_order.order_id, "Order rejected by market")
	# 订单成交后通过 market_engine.tick_complete → _on_market_tick 广播更新


## Host 请求撤离
func host_request_extraction(player_id: int) -> void:
	if extraction_engine and player_manager:
		var state := player_manager.get_player_state(player_id)
		if state:
			var prices: Dictionary = {}
			if market_engine:
				var snap := market_engine.get_current_snapshot()
				for sym in snap:
					prices[sym] = snap[sym].get("price", 0.0)
			extraction_engine.try_extract(
				player_id, state.get_total_assets(prices), state.brought_funds)


## ─── 交易中每秒更新 ────────────────────────────────────────────────────────
func _on_trading_tick() -> void:
	_trading_remaining -= 1.0
	if _trading_remaining <= 0.0:
		goto_settlement()
		return
	# 更新撤离引擎
	if extraction_engine:
		extraction_engine.update(1.0)
	# 更新技能冷却
	if skill_system:
		skill_system.update_cooldowns(1.0)
	if player_manager:
		player_manager.apply_tick_modifiers(1.0)
	# 更新 Bot
	if bot_manager and market_engine:
		var prices := market_engine.get_current_snapshot()
		var price_dict: Dictionary = {}
		for sym in prices:
			price_dict[sym] = prices[sym].get("price", 0.0)
		bot_manager.update(1.0, price_dict)


## 准备阶段超时（自动进入）
func _on_loadout_timeout() -> void:
	goto_enter_market()
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		goto_trading()
	)


## ─── 信号连接（注入子系统后调用）────────────────────────────────────────────
func connect_subsystem_signals() -> void:
	if market_engine:
		market_engine.tick_complete.connect(_on_market_tick)
		market_engine.circuit_breaker_triggered.connect(_on_circuit_breaker)
		# MD-04: 改用 MarketEngine passthrough 信号
		if market_engine.has_signal("order_filled_passthrough") and player_manager:
			market_engine.connect("order_filled_passthrough", _on_order_filled_passthrough)
		if market_engine.has_signal("order_partially_filled_passthrough") and player_manager:
			market_engine.connect("order_partially_filled_passthrough", _on_order_filled_passthrough)
	if extraction_engine:
		extraction_engine.extraction_window_opened.connect(_on_extraction_window_opened)
		extraction_engine.extraction_window_closed.connect(_on_extraction_window_closed)
		extraction_engine.player_extracted.connect(_on_player_extracted)
		extraction_engine.player_busted.connect(_on_player_busted)
	if news_system:
		news_system.news_generated.connect(_on_news_generated)
		news_system.black_swan_triggered.connect(_on_black_swan)
	if skill_system:
		skill_system.skill_activated.connect(_on_skill_activated)
		skill_system.skill_cooldown_updated.connect(_on_skill_cooldown_updated)
		if skill_system.has_signal("skill_effect_applied"):
			skill_system.connect("skill_effect_applied", _on_skill_effect_applied)
	if bot_manager:
		bot_manager.boss_entered.connect(_on_boss_entered)
		bot_manager.bot_action_executed.connect(_on_bot_action)
		if bot_manager.has_signal("boss_defeated"):
			bot_manager.connect("boss_defeated", _on_boss_defeated)
	if player_manager:
		player_manager.player_bust_detected.connect(_on_bust_detected)
	if matchmaking:
		matchmaking.match_found.connect(_on_match_found)
	if leaderboard_manager:
		leaderboard_manager.leaderboard_updated.connect(_on_leaderboard_updated)


## ─── 子系统事件处理（广播到 UI）───────────────────────────────────────────

func _on_market_tick(snapshots: Array, fear_greed_index: float) -> void:
	# 更新玩家持仓盈亏
	if player_manager:
		var prices: Dictionary = {}
		for snap in snapshots:
			if snap is MarketTypes.StockSnapshot:
				prices[snap.symbol] = snap.close
		player_manager.update_prices(prices)
		# 检查每个玩家是否爆仓
		for snap in player_manager.get_all_snapshots():
			if snap.total_assets <= 0.0:
				if extraction_engine:
					extraction_engine.trigger_bust(snap.player_id)
	# 构建广播数据
	_tick_count += 1
	var tick_data := MarketTypes.TickData.new()
	tick_data.tick_index = _tick_count
	tick_data.elapsed_time = _tick_count * Constants.TICK_INTERVAL
	tick_data.snapshots.assign(snapshots)
	tick_data.fear_greed_index = fear_greed_index
	if _tick_count % 10 == 0 or _prev_snapshots.is_empty():
		_broadcast(NetworkProtocol.build_market_tick_msg(tick_data))
	else:
		_broadcast(NetworkProtocol.build_market_tick_delta(_prev_snapshots, tick_data))
	_prev_snapshots.clear()
	for snap in tick_data.snapshots:
		_prev_snapshots[snap.symbol] = snap


func _on_circuit_breaker(symbol: StringName, duration: float) -> void:
	_broadcast({"msg_type": &"circuit_breaker", "symbol": symbol, "duration": duration})


func _on_order_filled_passthrough(order: MarketTypes.BookOrder, fill_price: float, fill_qty: int) -> void:
	if player_manager:
		player_manager.on_order_filled(order.player_id, order.order_id, fill_price, fill_qty)


func _on_extraction_window_opened(duration: float) -> void:
	_broadcast(NetworkProtocol.build_extraction_window_msg(true, duration))


func _on_extraction_window_closed() -> void:
	_broadcast(NetworkProtocol.build_extraction_window_msg(false, 0.0))


func _on_player_extracted(player_id: int, profit: float) -> void:
	if _all_human_players_resolved():
		goto_settlement()


func _on_player_busted(player_id: int) -> void:
	if player_manager:
		player_manager.force_liquidate(player_id)
	if _all_human_players_resolved():
		goto_settlement()


func _all_human_players_resolved() -> bool:
	if not player_manager or not extraction_engine:
		return true
	var found_human := false
	for snapshot in player_manager.get_all_snapshots():
		var state := player_manager.get_player_state(snapshot.player_id)
		if state and not state.is_bot:
			found_human = true
			if extraction_engine.get_result(snapshot.player_id) == GameEnums.ExtractionResult.NONE:
				return false
	return found_human


func _on_news_generated(event: Dictionary) -> void:
	_broadcast(NetworkProtocol.build_news_msg(
		event.get("text", ""),
		event.get("impact", GameEnums.NewsImpact.PRICE_JUMP),
		event.get("magnitude", 0.0),
		event.get("sentiment", GameEnums.NewsSentiment.NEUTRAL),
		StringName(event.get("symbol", ""))
	))
	# 新闻冲击注入市场引擎
	if market_engine and event.get("symbol", "") != "":
		market_engine.inject_news_impact(StringName(event["symbol"]), event)


func _on_black_swan(event: Dictionary) -> void:
	if extraction_engine:
		extraction_engine.trigger_emergency_window()


func _on_skill_activated(player_id: int, skill_id: StringName, effect: Dictionary) -> void:
	_broadcast({"msg_type": NetworkProtocol.MSG_SKILL_STATE,
		"player_id": player_id, "skill_id": skill_id, "effect": effect,
		"event": "activated"})


func _on_skill_cooldown_updated(player_id: int, skill_id: StringName, remaining: float) -> void:
	_broadcast({"msg_type": NetworkProtocol.MSG_SKILL_STATE,
		"player_id": player_id, "skill_id": skill_id,
		"cooldown_remaining": remaining, "event": "cooldown"})


func _on_boss_entered(boss_name: String, boss_data: Dictionary) -> void:
	# 注册 Boss 到 PlayerManager
	const BOSS_ID := 999
	if player_manager:
		var capital: float = boss_data.get("capital", 500_000.0)
		player_manager.register_player(BOSS_ID, boss_name, capital, true)
	_broadcast({"msg_type": NetworkProtocol.MSG_BOSS_EVENT, "event": "enter",
		"boss_name": boss_name, "data": boss_data})


## Boss 击败广播（WS2 boss_defeated 信号）
func _on_boss_defeated(boss_name: String, result: Dictionary) -> void:
	_broadcast(NetworkProtocol.build_boss_defeated_msg(boss_name, result))


## 技能效果广播（WS2 skill_effect_applied 信号）
func _on_skill_effect_applied(player_id: int, skill_id: StringName, effect: Dictionary) -> void:
	var effect_type := StringName(effect.get("effect_type", ""))
	var target := StringName(effect.get("target", ""))
	var value: float = effect.get("value", 0.0)
	var duration: float = effect.get("duration", 0.0)
	match effect_type:
		&"fund_modifier":
			if player_manager:
				player_manager.apply_fund_modifier(
					player_id, skill_id, target, value, duration)
		&"order_modifier":
			if player_manager:
				player_manager.apply_order_modifier(
					player_id, skill_id, target, value, duration)
		&"extraction":
			if extraction_engine:
				extraction_engine.register_window_extension(player_id, value)
	_broadcast(NetworkProtocol.build_skill_effect_msg(player_id, skill_id, effect))


func _on_bust_detected(player_id: int) -> void:
	if extraction_engine:
		extraction_engine.trigger_bust(player_id)


## Bot 行为转发：Bot 下单 → MarketEngine
func _on_bot_action(bot_id: int, action: Dictionary) -> void:
	var symbol := StringName(action.get("symbol", ""))
	var side: int = action.get("side", GameEnums.OrderSide.BUY)
	var quantity: int = action.get("quantity", 10)
	host_submit_order(bot_id, symbol, side, GameEnums.OrderType.MARKET, quantity)


## ─── RPC 接收客户端请求（多人模式）──────────────────────────────────────────

func _validate_peer(peer_id: int) -> bool:
	if not _has_enet: return true
	if peer_id <= 0: return false
	return peer_id in multiplayer.get_peers()


@rpc("any_peer", "call_local")
func rpc_submit_order(data: Dictionary) -> void:
	var pid := multiplayer.get_remote_sender_id()
	if not _validate_peer(pid): return
	host_submit_order(pid,
		StringName(data.get("symbol", "")),
		data.get("side", GameEnums.OrderSide.BUY),
		data.get("order_type", GameEnums.OrderType.MARKET),
		data.get("quantity", 0),
		data.get("limit_price", 0.0))


@rpc("any_peer", "call_local")
func rpc_request_extraction() -> void:
	var pid := multiplayer.get_remote_sender_id()
	if not _validate_peer(pid): return
	host_request_extraction(pid)


@rpc("any_peer", "call_local")
func rpc_activate_skill(skill_id: StringName) -> void:
	var pid := multiplayer.get_remote_sender_id()
	if not _validate_peer(pid): return
	if skill_system:
		skill_system.activate_skill(pid, skill_id)


@rpc("any_peer", "call_local")
func rpc_select_era(era_id: StringName) -> void:
	var pid := multiplayer.get_remote_sender_id()
	if not _validate_peer(pid): return
	host_select_era(era_id)


@rpc("any_peer", "call_local")
func rpc_configure_loadout(data: Dictionary) -> void:
	var pid := multiplayer.get_remote_sender_id()
	if not _validate_peer(pid): return
	var extra_funds: float = data.get("extra_funds", 0.0)
	var skill_ids: Array = data.get("skill_ids", [])
	if player_manager:
		var safe_cash := safe_box_manager.get_total_cash(pid) if safe_box_manager else 0.0
		player_manager.register_player(pid, "Player_%d" % pid, safe_cash + extra_funds)
	if skill_system:
		if extraction_engine:
			extraction_engine.clear_window_extension(pid)
		var typed_ids: Array[StringName] = []
		for s in skill_ids:
			typed_ids.append(StringName(s))
		skill_system.equip_skills(pid, typed_ids)


@rpc("any_peer", "call_local")
func rpc_player_ready() -> void:
	var pid := multiplayer.get_remote_sender_id()
	if not _validate_peer(pid): return
	_ready_players[pid] = true
	_broadcast(NetworkProtocol.build_player_ready_msg(pid, true))
	_check_all_ready()


@rpc("any_peer", "call_local")
func rpc_chat_message(text: String) -> void:
	var pid := multiplayer.get_remote_sender_id()
	if not _validate_peer(pid): return
	_broadcast(NetworkProtocol.build_chat_msg(pid, text.substr(0, 200)))


## 快捷聊天: message_id 对应预设消息
const QUICK_CHAT_MESSAGES: Dictionary = {
	0: "快撤离！", 1: "跟庄！", 2: "崩了！",
	3: "稳住", 4: "做空！", 5: "加仓！",
	6: "GG", 7: "好运",
}

@rpc("any_peer", "call_local")
func rpc_quick_chat(message_id: int) -> void:
	var pid := multiplayer.get_remote_sender_id()
	if not _validate_peer(pid): return
	var text: String = QUICK_CHAT_MESSAGES.get(message_id, "")
	if text != "":
		_broadcast(NetworkProtocol.build_chat_msg(pid, text))


@rpc("any_peer", "call_local")
func rpc_request_match(rank_tier: int) -> void:
	var pid := multiplayer.get_remote_sender_id()
	if not _validate_peer(pid):
		return
	if matchmaking:
		matchmaking.request_match(pid, rank_tier)


func _on_match_found(room_id: String, players: Array) -> void:
	_broadcast(NetworkProtocol.build_match_found_msg(room_id, players))


func _on_leaderboard_updated() -> void:
	if not leaderboard_manager:
		return
	var entries: Array = []
	for entry in leaderboard_manager.get_global_ranking("rank_points"):
		entries.append(entry.to_dict())
	_broadcast(NetworkProtocol.build_leaderboard_msg(entries))


@rpc("any_peer", "call_local")
func rpc_request_state_sync() -> void:
	var pid := multiplayer.get_remote_sender_id()
	if not _validate_peer(pid): return
	rpc_id(pid, "rpc_sync_data", NetworkProtocol.build_game_phase_msg(_current_phase, {}))
	if _current_phase == GameEnums.GamePhase.TRADING and market_engine:
		var snap := market_engine.get_current_snapshot()
		var td := MarketTypes.TickData.new()
		td.tick_index = _tick_count
		td.elapsed_time = _tick_count * Constants.TICK_INTERVAL
		for sym in snap:
			var s := MarketTypes.StockSnapshot.new()
			s.symbol = StringName(sym)
			s.close = snap[sym].get("price", 0.0)
			td.snapshots.append(s)
		rpc_id(pid, "rpc_sync_data", NetworkProtocol.build_market_tick_msg(td))
	if player_manager:
		var ps := player_manager.get_player_snapshot(pid)
		if ps:
			rpc_id(pid, "rpc_sync_data", {"msg_type": NetworkProtocol.MSG_PLAYER_STATE, "data": ps.to_dict()})


func _check_all_ready() -> void:
	if not _has_enet: return
	var peers := multiplayer.get_peers()
	if peers.is_empty(): return
	for peer_id in peers:
		if not _ready_players.get(peer_id, false): return
	_settlement_triggered = false
	_tick_count = 0
	_prev_snapshots.clear()
	_ready_players.clear()
	goto_enter_market()
	get_tree().create_timer(1.5).timeout.connect(func(): goto_trading())


## ─── 网络事件 ────────────────────────────────────────────────────────────────
func _on_peer_connected(peer_id: int) -> void:
	print("GameSession: Peer connected: %d" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	print("GameSession: Peer disconnected: %d" % peer_id)
	_ready_players.erase(peer_id)
	# 断线 Bot 接管: 将断线玩家转为 Bot 控制
	if player_manager and bot_manager:
		var state := player_manager.get_player_state(peer_id)
		if state and not state.is_bot:
			state.is_bot = true
			print("GameSession: Player %d transferred to bot control" % peer_id)


## ─── 广播 ────────────────────────────────────────────────────────────────────
func _broadcast(msg: Dictionary) -> void:
	if not _is_host:
		return
	# ENet 模式下向远程客户端广播
	if _has_enet:
		for peer_id in multiplayer.get_peers():
			rpc_id(peer_id, "rpc_sync_data", msg)
	# 本地 Host 通过信号接收
	data_received.emit(msg)


## RPC 方法：服务器向客户端发送数据
@rpc("authority", "call_remote")
func rpc_sync_data(msg: Dictionary) -> void:
	data_received.emit(msg)


## ─── 辅助 ────────────────────────────────────────────────────────────────────
func _set_phase(phase: int, data: Dictionary) -> void:
	_current_phase = phase
	phase_changed.emit(phase, data)
	# 阶段变更也通过广播发送
	if phase != GameEnums.GamePhase.ERA_SELECT:
		_broadcast(NetworkProtocol.build_game_phase_msg(phase, data))


func _build_settlement_data() -> Dictionary:
	var snapshots: Array[Dictionary] = []
	var player_extracted := false
	var player_profit := 0.0
	var player_rank_points := 0
	if player_manager:
		for snap in player_manager.get_all_snapshots():
			var d := snap.to_dict()
			var result := extraction_engine.get_result(snap.player_id) if extraction_engine else GameEnums.ExtractionResult.NONE
			d["extraction_result"] = result
			snapshots.append(d)
			# 找到玩家（非 Bot）的数据
			if snap.player_id == 1:
				player_extracted = (result == GameEnums.ExtractionResult.SUCCESS)
				player_profit = snap.session_profit
				player_rank_points = snap.rank_points
	# 计算段位变化
	var rank_delta := 0
	if rank_system:
		rank_delta = rank_system.calculate_rank_change(player_profit, player_extracted)
	return {
		"players": snapshots,
		"extracted": player_extracted,
		"profit": player_profit,
		"rank_points": player_rank_points + rank_delta,
		"rank_delta": rank_delta,
	}
