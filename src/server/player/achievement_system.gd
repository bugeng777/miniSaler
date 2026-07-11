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
	_register(&"streak_10", "十连胜", "连续 10 次撤离成功", "funds", "20000")
	_register(&"era_tokyo", "泡沫猎手", "在东京 1989 成功撤离 3 次", "skill", "risk_warning")
	_register(&"era_shanghai", "六千点勇士", "在上海 2007 成功撤离 3 次", "skill", "dispersion")
	_register(&"trades_100", "百次操盘", "累计交易 100 次", "funds", "5000")
	_register(&"trades_500", "交易狂人", "累计交易 500 次", "funds", "15000")
	_register(&"profit_500k", "半百万富翁", "累计利润达到 50 万", "funds", "25000")
	_register(&"big_loss", "惨痛教训", "单局亏损超过 5 万", "funds", "3000")
	_register(&"level_10", "初露锋芒", "玩家等级达到 10", "skill", "cash_king")
	_register(&"level_20", "资深交易员", "玩家等级达到 20", "safe_box_upgrade", "1")
	_register(&"games_50", "老玩家", "累计 50 局", "funds", "10000")


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

	# 连胜达人：连续 5 次撤离成功
	if not profile.achievements.has(&"streak_5"):
		if profile.current_streak >= 5:
			newly_unlocked.append(&"streak_5")

	# 港岛风云：香港 1997 成功撤离 3 次
	if not profile.achievements.has(&"era_hk"):
		if profile.era_extractions.get("hk_1997", 0) >= 3:
			newly_unlocked.append(&"era_hk")

	# 汉江英雄：首尔 1988 成功撤离 3 次
	if not profile.achievements.has(&"era_seoul"):
		if profile.era_extractions.get("seoul_1988", 0) >= 3:
			newly_unlocked.append(&"era_seoul")

	# 硅谷传奇：硅谷 2000 成功撤离 3 次
	if not profile.achievements.has(&"era_silicon"):
		if profile.era_extractions.get("silicon_2000", 0) >= 3:
			newly_unlocked.append(&"era_silicon")

	# 做空大师：单次做空获利超过 5 万
	if not profile.achievements.has(&"short_master"):
		if session_result.get("max_short_profit", 0.0) > 50_000:
			newly_unlocked.append(&"short_master")

	# 时空旅人：解锁所有 5 个时代
	if not profile.achievements.has(&"all_eras"):
		if profile.unlocked_eras.size() >= 5:
			newly_unlocked.append(&"all_eras")

	# 钢铁意志：爆仓 10 次仍未放弃
	if not profile.achievements.has(&"iron_man"):
		if profile.total_busts >= 10:
			newly_unlocked.append(&"iron_man")

	# 十连胜
	if not profile.achievements.has(&"streak_10"):
		if profile.current_streak >= 10:
			newly_unlocked.append(&"streak_10")

	# 泡沫猎手：东京 1989 撤离 3 次
	if not profile.achievements.has(&"era_tokyo"):
		if profile.era_extractions.get("tokyo_1989", 0) >= 3:
			newly_unlocked.append(&"era_tokyo")

	# 六千点勇士：上海 2007 撤离 3 次
	if not profile.achievements.has(&"era_shanghai"):
		if profile.era_extractions.get("shanghai_2007", 0) >= 3:
			newly_unlocked.append(&"era_shanghai")

	# 百次操盘
	if not profile.achievements.has(&"trades_100"):
		if profile.total_trades >= 100:
			newly_unlocked.append(&"trades_100")

	# 交易狂人
	if not profile.achievements.has(&"trades_500"):
		if profile.total_trades >= 500:
			newly_unlocked.append(&"trades_500")

	# 半百万富翁
	if not profile.achievements.has(&"profit_500k"):
		if profile.total_profit >= 500_000:
			newly_unlocked.append(&"profit_500k")

	# 惨痛教训：单局亏损超 5 万
	if not profile.achievements.has(&"big_loss"):
		var session_loss: float = absf(session_result.get("profit", 0.0)) if session_result.get("profit", 0.0) < 0.0 else 0.0
		if session_loss > 50_000 or profile.highest_single_loss > 50_000:
			newly_unlocked.append(&"big_loss")

	# 初露锋芒：等级达到 10
	if not profile.achievements.has(&"level_10"):
		if profile.player_level >= 10:
			newly_unlocked.append(&"level_10")

	# 资深交易员：等级达到 20
	if not profile.achievements.has(&"level_20"):
		if profile.player_level >= 20:
			newly_unlocked.append(&"level_20")

	# 老玩家：累计 50 局
	if not profile.achievements.has(&"games_50"):
		if profile.total_games >= 50:
			newly_unlocked.append(&"games_50")

	for ach_id in newly_unlocked:
		achievement_unlocked.emit(player_id, ach_id)

	return newly_unlocked


## 获取成就定义
func get_definition(ach_id: StringName) -> AchievementDef:
	return _definitions.get(ach_id, null)


## 获取所有成就定义
func get_all_definitions() -> Dictionary:
	return _definitions
