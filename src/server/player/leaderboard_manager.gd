## 排行榜管理器
## 所有权: WS3 (玩家经济组)
## 管理全局排行和赛季排行，通过 SaveManager 持久化
extends Node
class_name LeaderboardManager

signal leaderboard_updated


## SaveManager 引用（由 main.gd 注入）
var _save_manager: SaveManager = null

## 全局排行数据
var _global_entries: Array[PlayerTypes.LeaderboardEntry] = []

## 赛季排行数据
var _season_entries: Array[PlayerTypes.LeaderboardEntry] = []

## 当前赛季标识（格式 "YYYY-MM"）
var _current_season_id: String = ""


## 初始化：注入 SaveManager 并加载持久化数据
func initialize(save_mgr: SaveManager) -> void:
	_save_manager = save_mgr
	_current_season_id = _get_current_season_id()
	_load_data()


## ─── 全局排行 ─────────────────────────────────────────────────────────────

## 获取全局排行榜（按指定字段排序）
## sort_by: "total_profit" | "win_rate" | "rank_points"
func get_global_ranking(sort_by: String = "total_profit") -> Array[PlayerTypes.LeaderboardEntry]:
	var sorted := _global_entries.duplicate()
	match sort_by:
		"total_profit":
			sorted.sort_custom(func(a: PlayerTypes.LeaderboardEntry, b: PlayerTypes.LeaderboardEntry) -> bool:
				return a.total_profit > b.total_profit)
		"win_rate":
			sorted.sort_custom(func(a: PlayerTypes.LeaderboardEntry, b: PlayerTypes.LeaderboardEntry) -> bool:
				return a.get_win_rate() > b.get_win_rate())
		"rank_points":
			sorted.sort_custom(func(a: PlayerTypes.LeaderboardEntry, b: PlayerTypes.LeaderboardEntry) -> bool:
				return a.rank_points > b.rank_points)
	return sorted


## ─── 赛季排行 ─────────────────────────────────────────────────────────────

## 获取赛季排行榜
func get_season_ranking(sort_by: String = "total_profit") -> Array[PlayerTypes.LeaderboardEntry]:
	var sorted := _season_entries.duplicate()
	match sort_by:
		"total_profit":
			sorted.sort_custom(func(a: PlayerTypes.LeaderboardEntry, b: PlayerTypes.LeaderboardEntry) -> bool:
				return a.total_profit > b.total_profit)
		"win_rate":
			sorted.sort_custom(func(a: PlayerTypes.LeaderboardEntry, b: PlayerTypes.LeaderboardEntry) -> bool:
				return a.get_win_rate() > b.get_win_rate())
		"rank_points":
			sorted.sort_custom(func(a: PlayerTypes.LeaderboardEntry, b: PlayerTypes.LeaderboardEntry) -> bool:
				return a.rank_points > b.rank_points)
	return sorted


## 获取当前赛季标识
func get_current_season_id() -> String:
	return _current_season_id


## ─── 更新条目 ─────────────────────────────────────────────────────────────

## 从 PlayerProfile 更新或插入排行条目
func update_from_profile(profile: PlayerTypes.PlayerProfile, player_name: String) -> void:
	_update_entry_in(_global_entries, profile, player_name, "")
	_update_entry_in(_season_entries, profile, player_name, _current_season_id)
	_save_data()
	leaderboard_updated.emit()


## ─── 赛季重置 ─────────────────────────────────────────────────────────────

## 每月重置赛季排行（保留全局排行）
func reset_season() -> void:
	var new_season := _get_current_season_id()
	if new_season != _current_season_id:
		_season_entries.clear()
		_current_season_id = new_season
		_save_data()
		leaderboard_updated.emit()


## ─── 内部方法 ─────────────────────────────────────────────────────────────

## 更新数组中的条目（按 player_name 匹配）
func _update_entry_in(entries: Array[PlayerTypes.LeaderboardEntry],
		profile: PlayerTypes.PlayerProfile, player_name: String, season_id: String) -> void:
	# 查找现有条目
	for i in range(entries.size()):
		if entries[i].player_name == player_name:
			entries[i].total_profit = profile.total_profit
			entries[i].total_games = profile.total_games
			entries[i].total_extractions = profile.total_extractions
			entries[i].rank_points = profile.rank_points
			entries[i].rank_tier = profile.rank_tier
			if season_id != "":
				entries[i].season_id = season_id
			return
	# 新增条目
	var entry := PlayerTypes.LeaderboardEntry.new()
	entry.player_name = player_name
	entry.total_profit = profile.total_profit
	entry.total_games = profile.total_games
	entry.total_extractions = profile.total_extractions
	entry.rank_points = profile.rank_points
	entry.rank_tier = profile.rank_tier
	entry.season_id = season_id
	entries.append(entry)


## 获取当前赛季 ID（YYYY-MM 格式）
func _get_current_season_id() -> String:
	var date := Time.get_date_dict_from_system()
	return "%04d-%02d" % [date["year"], date["month"]]


## 从 SaveManager 加载数据
func _load_data() -> void:
	if not _save_manager:
		return
	var data := _save_manager.load_leaderboard()
	_global_entries.clear()
	_season_entries.clear()
	for raw in data.get("global", []):
		if raw is Dictionary:
			_global_entries.append(PlayerTypes.LeaderboardEntry.from_dict(raw))
	for raw in data.get("season", []):
		if raw is Dictionary:
			_season_entries.append(PlayerTypes.LeaderboardEntry.from_dict(raw))
	var saved_season: String = data.get("season_id", "")
	if saved_season != "" and saved_season != _current_season_id:
		# 跨月了，清空赛季数据
		_season_entries.clear()


## 保存到 SaveManager
func _save_data() -> void:
	if not _save_manager:
		return
	var global_dicts: Array[Dictionary] = []
	for e in _global_entries:
		global_dicts.append(e.to_dict())
	var season_dicts: Array[Dictionary] = []
	for e in _season_entries:
		season_dicts.append(e.to_dict())
	_save_manager.save_leaderboard({
		"global": global_dicts,
		"season": season_dicts,
		"season_id": _current_season_id,
	})
