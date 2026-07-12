## 匹配系统
## 所有权: WS4 (网络会话组)
## 管理快速匹配、房间创建、Bot 填充
extends Node
class_name Matchmaking


## ─── 信号 ────────────────────────────────────────────────────────────────────
signal match_found(room_id: String, players: Array)
signal match_cancelled(player_id: int)


## ─── 常量 ────────────────────────────────────────────────────────────────────
const MATCH_TIMEOUT: float = 10.0  ## 匹配超时（秒），超时后 Bot 填充
const MAX_PLAYERS: int = 8         ## 每房间最大人数
const BOT_ID_BASE: int = 1000      ## Bot ID 起始值


## ─── 房间数据 ────────────────────────────────────────────────────────────────
class Room:
	var room_id: String = ""
	var players: Array = []         ## player_id 列表
	var rank_tier: int = 0          ## 房间段位基准
	var is_started: bool = false
	var created_at: float = 0.0


## ─── 状态 ────────────────────────────────────────────────────────────────────
var _rooms: Dictionary = {}        ## room_id -> Room
var _match_queue: Array = []       ## [{player_id, rank_tier, queued_at}]
var _match_timer: Timer = null
var _room_counter: int = 0
var _bot_counter: int = 0


func _ready() -> void:
	_match_timer = Timer.new()
	_match_timer.wait_time = 1.0
	_match_timer.timeout.connect(_on_match_tick)
	add_child(_match_timer)
	_match_timer.start()


## ─── 公开接口 ────────────────────────────────────────────────────────────────

## 请求快速匹配
func request_match(player_id: int, rank_tier: int = 0) -> void:
	# 防止重复入队
	for entry in _match_queue:
		if entry["player_id"] == player_id:
			return
	_match_queue.append({
		"player_id": player_id,
		"rank_tier": rank_tier,
		"queued_at": Time.get_ticks_msec() / 1000.0,
	})


## 取消匹配
func cancel_match(player_id: int) -> void:
	for i in range(_match_queue.size() - 1, -1, -1):
		if _match_queue[i]["player_id"] == player_id:
			_match_queue.remove_at(i)
			match_cancelled.emit(player_id)
			return


## 创建房间
func create_room(rank_tier: int = 0) -> String:
	_room_counter += 1
	var room_id := "room_%d" % _room_counter
	var room := Room.new()
	room.room_id = room_id
	room.rank_tier = rank_tier
	room.created_at = Time.get_ticks_msec() / 1000.0
	_rooms[room_id] = room
	return room_id


## 加入房间
func join_room(room_id: String, player_id: int) -> bool:
	var room: Room = _rooms.get(room_id, null)
	if room == null or room.is_started:
		return false
	if room.players.size() >= MAX_PLAYERS:
		return false
	if player_id in room.players:
		return false
	room.players.append(player_id)
	return true


## 离开房间
func leave_room(player_id: int) -> void:
	for room_id in _rooms:
		var room: Room = _rooms[room_id]
		room.players.erase(player_id)
		# 空房间自动清理
		if room.players.is_empty() and not room.is_started:
			_rooms.erase(room_id)


## 获取房间信息
func get_room(room_id: String) -> Room:
	return _rooms.get(room_id, null)


## ─── 匹配逻辑（每秒 tick）────────────────────────────────────────────────────

func _on_match_tick() -> void:
	if _match_queue.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	# 按段位分组尝试匹配
	var grouped: Dictionary = {}  ## rank_tier -> [entries]
	for entry in _match_queue:
		var tier: int = entry["rank_tier"]
		if not grouped.has(tier):
			grouped[tier] = []
		grouped[tier].append(entry)
	# 尝试每个段位的匹配
	for tier in grouped:
		var entries: Array = grouped[tier]
		# 检查是否有超时玩家
		var has_timeout := false
		for entry in entries:
			if now - entry["queued_at"] >= MATCH_TIMEOUT:
				has_timeout = true
				break
		# 够人数或超时 → 创建房间
		if entries.size() >= MAX_PLAYERS or has_timeout:
			_create_matched_room(entries, tier)
	# 清理已入队的玩家
	_cleanup_queue()


func _create_matched_room(entries: Array, rank_tier: int) -> void:
	var room_id := create_room(rank_tier)
	var room: Room = _rooms[room_id]
	var player_ids: Array = []
	# 加入真人玩家
	for entry in entries:
		if player_ids.size() < MAX_PLAYERS:
			join_room(room_id, entry["player_id"])
			player_ids.append(entry["player_id"])
	# Bot 填充到 MAX_PLAYERS
	while player_ids.size() < MAX_PLAYERS:
		_bot_counter += 1
		var bot_id := BOT_ID_BASE + _bot_counter
		join_room(room_id, bot_id)
		player_ids.append(bot_id)
	# 标记房间已开始
	room.is_started = true
	# 从队列移除已匹配的玩家
	for entry in entries:
		for i in range(_match_queue.size() - 1, -1, -1):
			if _match_queue[i]["player_id"] == entry["player_id"]:
				_match_queue.remove_at(i)
				break
	match_found.emit(room_id, player_ids)


func _cleanup_queue() -> void:
	# 移除已在房间中的玩家
	for room_id in _rooms:
		var room: Room = _rooms[room_id]
		for i in range(_match_queue.size() - 1, -1, -1):
			if _match_queue[i]["player_id"] in room.players:
				_match_queue.remove_at(i)
