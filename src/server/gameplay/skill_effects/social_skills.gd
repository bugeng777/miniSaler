## 社交类技能效果实现
## 所有权: WS2 (游戏玩法组)
## 4 个社交类技能：market_rumor / herd_master / opinion_leader / insider_network
class_name SocialSkills
extends RefCounted


## 市场谣言（主动，CD 120s）：发布假消息影响对手判断
## WS4 将假消息广播给其他玩家，WS5 显示为普通新闻样式
static func apply_market_rumor(player_id: int, rumor_text: String,
		base_value: float, level: int) -> Dictionary:
	var effective := base_value * (1.0 + (level - 1) * Constants.SKILL_LEVEL_BONUS)
	return {
		"effect_type": "social",
		"action": "inject_fake_news",
		"source_player": player_id,
		"rumor_text": rumor_text,
		"credibility": clampf(effective * 0.5, 0.3, 0.9),  ## 可信度 30%-90%
		"magnitude": 0.03 * effective,  ## 对价格的影响幅度
	}


## 跟风大师（主动，CD 60s，持续 5s）：显示其他玩家的买卖方向
## WS4 收集其他玩家最近交易方向，WS5 显示方向箭头
static func apply_herd_master(other_players_actions: Array,
		base_value: float, level: int) -> Dictionary:
	var effective := int(base_value * (1.0 + (level - 1) * Constants.SKILL_LEVEL_BONUS))
	# 返回最近 N 条其他玩家交易方向
	var visible_actions: Array = []
	var count := mini(effective, other_players_actions.size())
	for i in range(count):
		visible_actions.append(other_players_actions[i])
	return {
		"effect_type": "ui_display",
		"action": "show_others_direction",
		"visible_actions": visible_actions,
		"max_visible": effective,  ## 最多显示 N 条
		"duration": 5.0,           ## 持续 5 秒
	}


## 意见领袖（被动）：你的交易会被 1 个 AI 跟随
## WS2 BotManager 创建 1 个跟随 Bot，复制玩家交易方向
static func apply_opinion_leader(player_id: int, base_value: float, level: int) -> Dictionary:
	var effective := int(base_value * (1.0 + (level - 1) * Constants.SKILL_LEVEL_BONUS))
	return {
		"effect_type": "social",
		"action": "create_follower_bot",
		"leader_player": player_id,
		"follower_count": effective,  ## 1 个 AI 跟随
		"copy_ratio": 0.5,            ## 跟随者以 50% 量级复制
	}


## 内幕网络（被动）：每局获得 1 条独家新闻（提前看到）
## WS2 NewsSystem 在生成新闻时，给该玩家减少全部延迟
static func apply_insider_network(base_value: float, level: int) -> Dictionary:
	var effective := int(base_value * (1.0 + (level - 1) * Constants.SKILL_LEVEL_BONUS))
	return {
		"effect_type": "market_data",
		"action": "exclusive_news_access",
		"news_count": effective,    ## 每局 N 条独家新闻
		"delay_override": 0.0,     ## 独家新闻无延迟
	}
