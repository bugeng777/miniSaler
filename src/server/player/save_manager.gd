## 存档管理器
## 所有权: WS3 (玩家经济组)
## 负责玩家持久化数据的读写，使用 JSON + 原子写入
## 存档路径: user://saves/
extends Node
class_name SaveManager

signal save_completed(success: bool)
signal load_completed(profile: PlayerTypes.PlayerProfile)


const SAVE_DIR := "user://saves/"
const PROFILE_FILE := "player_profile.json"
const SAFE_BOX_FILE := "safe_box.json"
const SKILL_PROGRESS_FILE := "skill_progress.json"
const LEADERBOARD_FILE := "leaderboard.json"
const BACKUP_SUFFIX := ".bak"
const MAX_BACKUPS := 2               ## 降低为 2（减少磁盘 I/O）
const BACKUP_INTERVAL: int = 5       ## 每 5 次保存才做一次备份轮转


## JSON 解析器缓存（复用，避免每次 load 创建新对象）
var _json_parser: JSON = null

## 脏标记系统：追踪哪些数据已修改需要写入
var _dirty_flags: Dictionary = {}    ## "profile"/"safe_box"/"skill_progress"/"leaderboard" -> bool

## 待写入数据缓存
var _pending_profile: PlayerTypes.PlayerProfile = null
var _pending_safe_box: Dictionary = {}
var _pending_skill_progress: Dictionary = {}
var _pending_leaderboard: Dictionary = {}

## 保存计数器（控制备份频率）
var _save_count: int = 0


func _ready() -> void:
	_json_parser = JSON.new()
	_dirty_flags = {
		"profile": false,
		"safe_box": false,
		"skill_progress": false,
		"leaderboard": false,
	}


## ─── 加载方法 ─────────────────────────────────────────────────────────────

## 加载玩家档案
func load_profile() -> PlayerTypes.PlayerProfile:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var path := SAVE_DIR + PROFILE_FILE
	if not FileAccess.file_exists(path):
		var profile := _create_default_profile()
		save_profile(profile)
		return profile
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return _create_default_profile()
	var json_text := file.get_as_text()
	file.close()
	if _json_parser.parse(json_text) != OK:
		push_warning("SaveManager: Failed to parse profile JSON")
		return _create_default_profile()
	return PlayerTypes.PlayerProfile.from_dict(_json_parser.data)


## 加载保险柜数据
func load_safe_box() -> Dictionary:
	var path := SAVE_DIR + SAFE_BOX_FILE
	if not FileAccess.file_exists(path):
		return {"slots": Constants.INITIAL_SAFE_BOX_SLOTS, "items": []}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {"slots": Constants.INITIAL_SAFE_BOX_SLOTS, "items": []}
	var json_text := file.get_as_text()
	file.close()
	if _json_parser.parse(json_text) != OK:
		push_warning("SaveManager: Failed to parse safe_box JSON")
		return {"slots": Constants.INITIAL_SAFE_BOX_SLOTS, "items": []}
	return _json_parser.data if _json_parser.data else {"slots": Constants.INITIAL_SAFE_BOX_SLOTS, "items": []}


## 加载技能进度
func load_skill_progress() -> Dictionary:
	var path := SAVE_DIR + SKILL_PROGRESS_FILE
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json_text := file.get_as_text()
	file.close()
	if _json_parser.parse(json_text) != OK:
		push_warning("SaveManager: Failed to parse skill_progress JSON")
		return {}
	return _json_parser.data if _json_parser.data else {}


## 加载排行榜数据
func load_leaderboard() -> Dictionary:
	var path := SAVE_DIR + LEADERBOARD_FILE
	if not FileAccess.file_exists(path):
		return {"global": [], "season": [], "season_id": ""}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {"global": [], "season": [], "season_id": ""}
	var json_text := file.get_as_text()
	file.close()
	if _json_parser.parse(json_text) != OK:
		push_warning("SaveManager: Failed to parse leaderboard JSON")
		return {"global": [], "season": [], "season_id": ""}
	return _json_parser.data if _json_parser.data else {"global": [], "season": [], "season_id": ""}


## ─── 保存方法（带脏标记）────────────────────────────────────────────────────

## 保存玩家档案（标记脏 + 缓存，flush_all 时实际写入）
func save_profile(profile: PlayerTypes.PlayerProfile) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	_pending_profile = profile
	_dirty_flags["profile"] = true
	return _flush_single("profile")


## 保存保险柜数据
func save_safe_box(data: Dictionary) -> bool:
	_pending_safe_box = data
	_dirty_flags["safe_box"] = true
	return _flush_single("safe_box")


## 保存技能进度
func save_skill_progress(data: Dictionary) -> bool:
	_pending_skill_progress = data
	_dirty_flags["skill_progress"] = true
	return _flush_single("skill_progress")


## 保存排行榜数据
func save_leaderboard(data: Dictionary) -> bool:
	_pending_leaderboard = data
	_dirty_flags["leaderboard"] = true
	return _flush_single("leaderboard")


## 标记数据为脏（供外部调用，延迟写入）
func mark_dirty(data_type: StringName) -> void:
	_dirty_flags[data_type] = true


## 批量保存所有脏数据（一次性写入，减少 I/O）
func flush_all() -> bool:
	var all_ok := true
	for key in _dirty_flags:
		if _dirty_flags[key]:
			if not _flush_single(key):
				all_ok = false
			_dirty_flags[key] = false
	return all_ok


## ─── 内部写入方法 ─────────────────────────────────────────────────────────

## 写入单个数据类型
func _flush_single(data_type: String) -> bool:
	var content: String = ""
	var filename: String = ""
	match data_type:
		"profile":
			if _pending_profile == null:
				return true
			content = JSON.stringify(_pending_profile.to_dict())
			filename = PROFILE_FILE
		"safe_box":
			content = JSON.stringify(_pending_safe_box)
			filename = SAFE_BOX_FILE
		"skill_progress":
			content = JSON.stringify(_pending_skill_progress)
			filename = SKILL_PROGRESS_FILE
		"leaderboard":
			content = JSON.stringify(_pending_leaderboard)
			filename = LEADERBOARD_FILE
		_:
			return false
	_dirty_flags[data_type] = false
	return _atomic_write(SAVE_DIR + filename, content)


## 原子写入：先写临时文件，再 rename
func _atomic_write(path: String, content: String) -> bool:
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: Cannot write to " + tmp_path)
		save_completed.emit(false)
		return false
	file.store_string(content)
	file.close()
	# 降低备份频率：每 BACKUP_INTERVAL 次保存才轮转一次
	_save_count += 1
	if _save_count % BACKUP_INTERVAL == 0:
		_backup_rotate(path)
	# 原子 rename
	var err := DirAccess.rename_absolute(tmp_path, path)
	if err != OK:
		push_error("SaveManager: Rename failed: " + str(err))
		save_completed.emit(false)
		return false
	save_completed.emit(true)
	return true


## 备份轮转
func _backup_rotate(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	# 删除最旧的备份
	var oldest := path + BACKUP_SUFFIX + str(MAX_BACKUPS)
	if FileAccess.file_exists(oldest):
		DirAccess.remove_absolute(oldest)
	# 轮转
	for i in range(MAX_BACKUPS - 1, 0, -1):
		var src := path + BACKUP_SUFFIX + str(i)
		var dst := path + BACKUP_SUFFIX + str(i + 1)
		if FileAccess.file_exists(src):
			DirAccess.rename_absolute(src, dst)
	# 当前文件 -> .bak1
	DirAccess.copy_absolute(path, path + BACKUP_SUFFIX + "1")


## 创建默认档案
func _create_default_profile() -> PlayerTypes.PlayerProfile:
	var profile := PlayerTypes.PlayerProfile.new()
	profile.total_funds = Constants.INITIAL_FUNDS
	profile.safe_box_slots = Constants.INITIAL_SAFE_BOX_SLOTS
	# 初始保险柜放一笔现金
	var cash_item := PlayerTypes.SafeBoxItem.new()
	cash_item.item_type = GameEnums.SafeBoxItemType.CASH
	cash_item.item_id = &"cash"
	cash_item.amount = 50_000.0
	profile.safe_box_items.append(cash_item)
	# 初始解锁时代和技能
	profile.unlocked_eras = [&"hk_1997", &"seoul_1988"]
	profile.unlocked_skills = [&"news_reader", &"sentiment_sense", &"safe_harbor"]
	profile.created_at = Time.get_datetime_string_from_system()
	return profile
