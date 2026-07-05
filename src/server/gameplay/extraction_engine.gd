## 撤离引擎
## 所有权: WS2 (游戏玩法组)
## 管理撤离窗口的开放/关闭、撤离判定、贪婪分离线
## 参考: PRD §六 撤离机制详解
extends Node
class_name ExtractionEngine


## ─── 信号（接口 B：ExtractionEngine -> GameSession）──────────────────────
signal extraction_window_opened(duration: float)
signal extraction_window_closed()
signal player_extracted(player_id: int, profit: float)
signal player_busted(player_id: int)


## 当前时代撤离配置
var _config: EraData.ExtractionConfig = null
## 窗口状态
var _is_window_open: bool = false
var _window_remaining: float = 0.0
var _next_window_time: float = 0.0  ## 下一次窗口开放的游戏时间
## 交易阶段已过去时间
var _elapsed_time: float = 0.0
## 已撤离玩家集合
var _extracted_players: Dictionary = {}  ## player_id -> bool
## 已爆仓玩家集合
var _busted_players: Dictionary = {}  ## player_id -> bool


## 启动撤离引擎（每局开始时调用）
func start(extraction_config: EraData.ExtractionConfig) -> void:
	_config = extraction_config
	_is_window_open = false
	_window_remaining = 0.0
	_elapsed_time = 0.0
	_extracted_players.clear()
	_busted_players.clear()
	# 计算第一次窗口开放时间
	if _config.window_type == "timed":
		_next_window_time = _config.interval
	else:
		_next_window_time = _config.interval  # conditional 类型也用 interval 作为首次检查点


## 每 tick 更新（由 GameSession 调用）
func update(delta: float) -> void:
	_elapsed_time += delta

	if _is_window_open:
		_window_remaining -= delta
		if _window_remaining <= 0.0:
			_close_window()
	else:
		# 检查是否到达下次窗口时间
		if _config and _config.window_type == "timed":
			if _elapsed_time >= _next_window_time:
				_open_window(_config.duration)
				_next_window_time = _elapsed_time + _config.interval


## 条件窗口触发（由 GameSession 根据市场状态调用）
func trigger_conditional_window() -> void:
	if not _is_window_open and _config:
		_open_window(_config.duration)


## 紧急窗口（黑天鹅事件后触发）
func trigger_emergency_window() -> void:
	if not _is_window_open and _config:
		_open_window(_config.emergency_duration)


## 安全港技能延长窗口
func extend_window(extra_seconds: float) -> void:
	if _is_window_open:
		_window_remaining += extra_seconds


## 尝试撤离
func try_extract(player_id: int, total_assets: float, brought_funds: float) -> bool:
	if _extracted_players.has(player_id) or _busted_players.has(player_id):
		return false
	if not _is_window_open:
		return false
	# 执行撤离
	var profit := total_assets - brought_funds
	_extracted_players[player_id] = true
	player_extracted.emit(player_id, profit)
	return true


## 触发爆仓
func trigger_bust(player_id: int) -> void:
	if _extracted_players.has(player_id) or _busted_players.has(player_id):
		return
	_busted_players[player_id] = true
	player_busted.emit(player_id)


## 获取撤离状态
func is_window_open() -> bool:
	return _is_window_open


## 获取窗口剩余时间
func get_window_remaining() -> float:
	return _window_remaining


## 玩家是否已撤离
func is_extracted(player_id: int) -> bool:
	return _extracted_players.has(player_id)


## 玩家是否已爆仓
func is_busted(player_id: int) -> bool:
	return _busted_players.has(player_id)


## 获取撤离结果
func get_result(player_id: int) -> int:
	if _extracted_players.has(player_id):
		return GameEnums.ExtractionResult.SUCCESS
	if _busted_players.has(player_id):
		return GameEnums.ExtractionResult.BUSTED
	return GameEnums.ExtractionResult.NONE


## ─── 内部方法 ──────────────────────────────────────────────────────────────────
func _open_window(duration: float) -> void:
	_is_window_open = true
	_window_remaining = duration
	extraction_window_opened.emit(duration)


func _close_window() -> void:
	_is_window_open = false
	_window_remaining = 0.0
	extraction_window_closed.emit()
