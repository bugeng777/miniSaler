## 客户端网络通信
## 所有权: WS4 (网络会话组)
## 管理 ENet 客户端连接、RPC 收发、断线重连
extends Node
class_name ClientNetwork


## ─── 信号（接口 D：ClientNetwork -> UI）───────────────────────────────────
signal connected_to_server()
signal disconnected_from_server()
signal reconnection_failed()
signal reconnected()
signal connection_timeout()
signal market_tick_received(data: Dictionary)
signal news_received(data: Dictionary)
signal extraction_window_received(is_open: bool, remaining: float)
signal player_state_received(data: Dictionary)
signal game_phase_received(phase: int, data: Dictionary)
signal skill_state_received(data: Dictionary)
signal boss_event_received(data: Dictionary)
signal settlement_received(data: Dictionary)
signal chat_received(player_id: int, text: String)
signal player_ready_received(player_id: int, is_ready: bool)
signal match_found_received(room_id: String, players: Array)
signal boss_defeated_received(boss_name: String, result: Dictionary)
signal skill_effect_received(player_id: int, skill_id: StringName, effect: Dictionary)
signal leaderboard_received(entries: Array)


## ─── 状态 ────────────────────────────────────────────────────────────────────
var _client_peer: ENetMultiplayerPeer = null
var _is_connected: bool = false
var _server_address: String = "127.0.0.1"
var _server_port: int = Constants.DEFAULT_PORT
var _reconnect_timer: Timer = null
var _reconnect_attempts: int = 0
const RECONNECT_INTERVAL: float = 3.0
const MAX_RECONNECT_ATTEMPTS: int = 5
var _is_reconnecting: bool = false
var _snapshot_cache: Dictionary = {}
const CONNECT_TIMEOUT: float = 10.0
var _connect_timeout_timer: Timer = null


## 连接到服务器
func connect_to_server(address: String = "127.0.0.1",
		port: int = Constants.DEFAULT_PORT) -> bool:
	_server_address = address
	_server_port = port
	# 防止重复连接信号（信号泄漏修复）
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.disconnect(_on_connected)
	_client_peer = ENetMultiplayerPeer.new()
	var err := _client_peer.create_client(address, port)
	if err != OK:
		push_error("ClientNetwork: Failed to connect to %s:%d" % [address, port])
		return false
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.multiplayer_peer = _client_peer
	# 启动连接超时计时器
	_start_connect_timeout()
	return true


## 断开连接
func disconnect_from_server() -> void:
	_stop_reconnect()
	_stop_connect_timeout()
	if _client_peer:
		_client_peer.close()
		_client_peer = null
	_is_connected = false


## 是否已连接
func is_network_connected() -> bool:
	return _is_connected


## ─── 发送到服务器的 RPC 方法 ──────────────────────────────────────────────

## 提交订单
@rpc("any_peer", "call_remote")
func send_submit_order(symbol: StringName, side: int, order_type: int,
		quantity: int, limit_price: float = 0.0) -> void:
	if _is_connected:
		rpc_id(1, "rpc_submit_order", {
			"symbol": symbol,
			"side": side,
			"order_type": order_type,
			"quantity": quantity,
			"limit_price": limit_price,
		})


## 请求撤离
@rpc("any_peer", "call_remote")
func send_request_extraction() -> void:
	if _is_connected:
		rpc_id(1, "rpc_request_extraction")


## 激活技能
@rpc("any_peer", "call_remote")
func send_activate_skill(skill_id: StringName) -> void:
	if _is_connected:
		rpc_id(1, "rpc_activate_skill", skill_id)


## 选择时代
@rpc("any_peer", "call_remote")
func send_select_era(era_id: StringName) -> void:
	if _is_connected:
		rpc_id(1, "rpc_select_era", era_id)


## 配置准备
@rpc("any_peer", "call_remote")
func send_configure_loadout(extra_funds: float, skill_ids: Array) -> void:
	if _is_connected:
		rpc_id(1, "rpc_configure_loadout", {
			"extra_funds": extra_funds,
			"skill_ids": skill_ids,
		})


func send_player_ready() -> void:
	if _is_connected:
		rpc_id(1, "rpc_player_ready")


func send_chat_message(text: String) -> void:
	if _is_connected:
		rpc_id(1, "rpc_chat_message", text)


func send_request_match(rank_tier: int) -> void:
	if _is_connected:
		rpc_id(1, "rpc_request_match", rank_tier)


func send_quick_chat(message_id: int) -> void:
	if _is_connected:
		rpc_id(1, "rpc_quick_chat", message_id)


## ─── 接收服务器广播 ──────────────────────────────────────────────────────────

## 统一广播通道（方法名与 GameSession.rpc_sync_data 一致）
@rpc("authority", "call_remote")
func rpc_sync_data(msg: Dictionary) -> void:
	if not msg is Dictionary:
		return
	var msg_type: StringName = msg.get("msg_type", &"")
	if msg_type == &"":
		return
	match msg_type:
		NetworkProtocol.MSG_MARKET_TICK:
			_update_snapshot_cache(msg.get("data", {}))
			market_tick_received.emit(msg.get("data", {}))
		NetworkProtocol.MSG_MARKET_TICK_DELTA:
			_apply_delta(msg)
		NetworkProtocol.MSG_NEWS:
			news_received.emit(msg)
		NetworkProtocol.MSG_EXTRACTION_WINDOW:
			extraction_window_received.emit(
				msg.get("is_open", false),
				msg.get("remaining", 0.0))
		NetworkProtocol.MSG_PLAYER_STATE:
			player_state_received.emit(msg.get("data", {}))
		NetworkProtocol.MSG_GAME_PHASE:
			game_phase_received.emit(
				msg.get("phase", GameEnums.GamePhase.ERA_SELECT),
				msg.get("data", {}))
		NetworkProtocol.MSG_SKILL_STATE:
			skill_state_received.emit(msg)
		NetworkProtocol.MSG_BOSS_EVENT:
			boss_event_received.emit(msg)
		NetworkProtocol.MSG_SETTLEMENT:
			settlement_received.emit(msg)
		NetworkProtocol.MSG_CHAT:
			chat_received.emit(msg.get("player_id", 0), msg.get("text", ""))
		NetworkProtocol.MSG_PLAYER_READY:
			player_ready_received.emit(msg.get("player_id", 0), msg.get("is_ready", false))
		NetworkProtocol.MSG_MATCH_FOUND:
			match_found_received.emit(msg.get("room_id", ""), msg.get("players", []))
		NetworkProtocol.MSG_BOSS_DEFEATED:
			boss_defeated_received.emit(msg.get("boss_name", ""), msg.get("result", {}))
		NetworkProtocol.MSG_SKILL_EFFECT:
			skill_effect_received.emit(msg.get("player_id", 0), StringName(msg.get("skill_id", "")), msg.get("effect", {}))
		NetworkProtocol.MSG_LEADERBOARD_SYNC:
			leaderboard_received.emit(msg.get("entries", []))


## ─── 网络事件回调 ──────────────────────────────────────────────────────────

func _on_connected() -> void:
	_is_connected = true
	_stop_connect_timeout()
	if _is_reconnecting:
		_stop_reconnect()
		_snapshot_cache.clear()
		rpc_id(1, "rpc_request_state_sync")
		reconnected.emit()
	else:
		print("ClientNetwork: Connected to %s:%d" % [_server_address, _server_port])
	connected_to_server.emit()


func _on_server_disconnected() -> void:
	_is_connected = false
	disconnected_from_server.emit()
	print("ClientNetwork: Disconnected from server")
	_start_reconnect()


func _update_snapshot_cache(data: Dictionary) -> void:
	for snap in data.get("snapshots", []):
		var sym: StringName = StringName(snap.get("symbol", ""))
		if sym != &"": _snapshot_cache[sym] = snap


## 缩写 key -> 完整 key 映射
const _DELTA_KEY_MAP := {"p": "close", "v": "volume", "h": "high",
	"l": "low", "cb": "is_circuit_broken", "cr": "circuit_break_remaining"}

func _apply_delta(msg: Dictionary) -> void:
	for entry in msg.get("c", []):
		# 兼容缩写 key "s" 和完整 key "symbol"
		var sym: StringName = StringName(entry.get("s", entry.get("symbol", "")))
		if sym == &"": continue
		if entry.has("name"):
			# 完整快照（首次出现的股票）
			_snapshot_cache[sym] = entry
		else:
			# 字段级 delta：合并到缓存
			if not _snapshot_cache.has(sym):
				_snapshot_cache[sym] = {"symbol": sym}
			var cached: Dictionary = _snapshot_cache[sym]
			for short_key in _DELTA_KEY_MAP:
				if entry.has(short_key):
					cached[_DELTA_KEY_MAP[short_key]] = entry[short_key]
	# 兼容缩写 key "t/e/f" 和完整 key
	market_tick_received.emit({"tick_index": msg.get("t", msg.get("tick_index", 0)),
		"elapsed_time": msg.get("e", msg.get("elapsed_time", 0.0)),
		"fear_greed_index": msg.get("f", msg.get("fear_greed_index", 50.0)),
		"snapshots": _snapshot_cache.values()})


func _start_reconnect() -> void:
	if _is_reconnecting: return
	_is_reconnecting = true
	_reconnect_attempts = 0
	_reconnect_timer = Timer.new()
	_reconnect_timer.wait_time = RECONNECT_INTERVAL
	_reconnect_timer.one_shot = true
	_reconnect_timer.timeout.connect(_try_reconnect)
	add_child(_reconnect_timer)
	_reconnect_timer.start()


func _stop_reconnect() -> void:
	_is_reconnecting = false
	_reconnect_attempts = 0
	if _reconnect_timer:
		_reconnect_timer.stop()
		_reconnect_timer.queue_free()
		_reconnect_timer = null


func _try_reconnect() -> void:
	_reconnect_attempts += 1
	if _client_peer:
		_client_peer.close()
		_client_peer = null
	_client_peer = ENetMultiplayerPeer.new()
	var err := _client_peer.create_client(_server_address, _server_port)
	if err != OK:
		_handle_reconnect_failed()
		return
	# 重新连接信号（关键修复：新 peer 需要重新绑定信号）
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.disconnect(_on_connected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.multiplayer_peer = _client_peer
	if _reconnect_timer:
		_reconnect_timer.wait_time = RECONNECT_INTERVAL
		_reconnect_timer.start()


func _handle_reconnect_failed() -> void:
	if _reconnect_attempts >= MAX_RECONNECT_ATTEMPTS:
		_stop_reconnect()
		reconnection_failed.emit()
	else:
		if _reconnect_timer:
			_reconnect_timer.wait_time = RECONNECT_INTERVAL
			_reconnect_timer.start()


## ─── 连接超时 ──────────────────────────────────────────────────────────────

func _start_connect_timeout() -> void:
	if _connect_timeout_timer:
		_connect_timeout_timer.queue_free()
	_connect_timeout_timer = Timer.new()
	_connect_timeout_timer.wait_time = CONNECT_TIMEOUT
	_connect_timeout_timer.one_shot = true
	_connect_timeout_timer.timeout.connect(_on_connect_timeout)
	add_child(_connect_timeout_timer)
	_connect_timeout_timer.start()


func _stop_connect_timeout() -> void:
	if _connect_timeout_timer:
		_connect_timeout_timer.stop()
		_connect_timeout_timer.queue_free()
		_connect_timeout_timer = null


func _on_connect_timeout() -> void:
	if not _is_connected:
		push_warning("ClientNetwork: Connection timeout after %ds" % CONNECT_TIMEOUT)
		disconnect_from_server()
		connection_timeout.emit()
