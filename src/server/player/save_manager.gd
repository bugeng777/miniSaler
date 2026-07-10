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
const BACKUP_SUFFIX := ".bak"
const MAX_BACKUPS := 3


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
	var json := JSON.new()
	if json.parse(json_text) != OK:
		push_warning("SaveManager: Failed to parse profile JSON")
		return _create_default_profile()
	return PlayerTypes.PlayerProfile.from_dict(json.data)


## 保存玩家档案（原子写入）
func save_profile(profile: PlayerTypes.PlayerProfile) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	return _atomic_write(SAVE_DIR + PROFILE_FILE, JSON.stringify(profile.to_dict(), "\t"))


## 加载保险柜数据
func load_safe_box() -> Dictionary:
	var path := SAVE_DIR + SAFE_BOX_FILE
	if not FileAccess.file_exists(path):
		return {"slots": Constants.INITIAL_SAFE_BOX_SLOTS, "items": []}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {"slots": Constants.INITIAL_SAFE_BOX_SLOTS, "items": []}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("SaveManager: Failed to parse safe_box JSON")
		file.close()
		return {"slots": Constants.INITIAL_SAFE_BOX_SLOTS, "items": []}
	file.close()
	return json.data if json.data else {"slots": Constants.INITIAL_SAFE_BOX_SLOTS, "items": []}


## 保存保险柜数据
func save_safe_box(data: Dictionary) -> bool:
	return _atomic_write(SAVE_DIR + SAFE_BOX_FILE, JSON.stringify(data, "\t"))


## 加载技能进度
func load_skill_progress() -> Dictionary:
	var path := SAVE_DIR + SKILL_PROGRESS_FILE
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("SaveManager: Failed to parse skill_progress JSON")
		file.close()
		return {}
	file.close()
	return json.data if json.data else {}


## 保存技能进度
func save_skill_progress(data: Dictionary) -> bool:
	return _atomic_write(SAVE_DIR + SKILL_PROGRESS_FILE, JSON.stringify(data, "\t"))


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
	# 备份旧文件
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
