## 成就系统
## 所有权: WS3 (玩家经济组)
## 检测和解锁成就
extends Node
class_name AchievementSystem

signal achievement_unlocked(player_id: int, achievement_id: StringName)


## 成就定义
class AchievementDef:
	var id: StringName = &""
	var display_name: String = ""
	var description: String = ""
	var reward_type: String = ""  ## "skill" | "safe_box_upgrade" | "funds"
	var reward_value: String = ""

## 成就注册表
var _definitions: Dictionary = {}  ## id -> AchievementDef


func _ready() -> void:
	_register_achievements()


func _register_achievements() -> void:
	_register(&"first_extraction", "初次撤离", "成功完成第一次撤离", "funds", "5000")
	_register(&"millionaire", "百万富翁", "累计利润达到 100 万", "skill", "leverage_maniac")
	_register(&"streak_5", "连胜达人", "连续 5 次撤离成功", "funds", "10000")
	_register(&"era_hk", "港岛风云", "在香港 1997 成功撤离 3 次", "skill", "short_expert")
	_register(&"era_seoul", "汉江英雄", "在首尔 1988 成功撤离 3 次", "skill", "insider_network")
	_register(&"era_silicon", "硅谷传奇", "在硅谷 2000 成功撤离 3 次", "skill", "momentum_hunter")
	_register(&"black_swan_survivor", "黑天鹅幸存者", "在黑天鹅事件中成功撤离", "safe_box_upgrade", "1")
	_register(&"short_master", "做空大师", "单次做空获利超过 5 万", "skill", "short_expert")
	_register(&"all_eras", "时空旅人", "解锁所有 5 个时代", "funds", "50000")
	_register(&"iron_man", "钢铁意志", "爆仓 10 次仍未放弃", "skill", "iron_will")


func _register(id: StringName, name: String, desc: String, reward_type: String, reward_value: String) -> void:
	var def := AchievementDef.new()
	def.id = id
	def.display_name = name
	def.description = desc
	def.reward_type = reward_type
	def.reward_value = reward_value
	_definitions[id] = def


## 检测本局是否触发成就
func check_achievements(player_id: int, profile: PlayerTypes.PlayerProfile,
		session_result: Dictionary) -> Array[StringName]:
	var newly_unlocked: Array[StringName] = []

	# 初次撤离
	if not profile.achievements.has(&"first_extraction"):
		if session_result.get("extracted", false):
			newly_unlocked.append(&"first_extraction")

	# 百万富翁
	if not profile.achievements.has(&"millionaire"):
		if profile.total_profit + session_result.get("profit", 0.0) >= 1_000_000:
			newly_unlocked.append(&"millionaire")

	# 黑天鹅幸存者
	if not profile.achievements.has(&"black_swan_survivor"):
		if session_result.get("extracted", false) and session_result.get("had_black_swan", false):
			newly_unlocked.append(&"black_swan_survivor")

	for ach_id in newly_unlocked:
		achievement_unlocked.emit(player_id, ach_id)

	return newly_unlocked


## 获取成就定义
func get_definition(ach_id: StringName) -> AchievementDef:
	return _definitions.get(ach_id, null)


## 获取所有成就定义
func get_all_definitions() -> Dictionary:
	return _definitions
