## 客户端网络通信
## 所有权: WS4 (网络会话组)
## 管理 ENet 客户端连接、RPC 收发、断线重连
extends Node
class_name ClientNetwork


## ─── 信号（接口 D：ClientNetwork -> UI）───────────────────────────────────
signal connected_to_server()
signal disconnected_from_server()
signal market_tick_received(data: Dictionary)
signal news_received(data: Dictionary)
signal extraction_window_received(is_open: bool, remaining: float)
signal player_state_received(data: Dictionary)
signal game_phase_received(phase: int, data: Dictionary)
signal skill_state_received(data: Dictionary)
signal boss_event_received(data: Dictionary)
signal settlement_received(data: Dictionary)


## ─── 状态 ────────────────────────────────────────────────────────────────────
var _client_peer: ENetMultiplayerPeer = null
var _is_connected: bool = false
var _server_address: String = "127.0.0.1"
var _server_port: int = Constants.DEFAULT_PORT


## 连接到服务器
func connect_to_server(address: String = "127.0.0.1",
		port: int = Constants.DEFAULT_PORT) -> bool:
	_server_address = address
	_server_port = port
	_client_peer = ENetMultiplayerPeer.new()
	var err := _client_peer.create_client(address, port)
	if err != OK:
		push_error("ClientNetwork: Failed to connect to %s:%d" % [address, port])
		return false
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.multiplayer_peer = _client_peer
	return true


## 断开连接
func disconnect_from_server() -> void:
	if _client_peer:
		_client_peer.close()
		_client_peer = null
	_is_connected = false


## 是否已连接
func is_connected() -> bool:
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


## ─── 接收服务器广播 ──────────────────────────────────────────────────────────

## 统一广播通道（方法名与 GameSession.rpc_sync_data 一致）
@rpc("authority", "call_remote")
func rpc_sync_data(msg: Dictionary) -> void:
	var msg_type: StringName = msg.get("msg_type", &"")
	match msg_type:
		NetworkProtocol.MSG_MARKET_TICK:
			market_tick_received.emit(msg.get("data", {}))
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


## ─── 网络事件回调 ──────────────────────────────────────────────────────────

func _on_connected() -> void:
	_is_connected = true
	connected_to_server.emit()
	print("ClientNetwork: Connected to server %s:%d" % [_server_address, _server_port])


func _on_server_disconnected() -> void:
	_is_connected = false
	disconnected_from_server.emit()
	print("ClientNetwork: Disconnected from server")
