## 段位系统
## 所有权: WS3 (玩家经济组)
## 管理段位积分的计算与升降级
extends Node
class_name RankSystem

signal rank_changed(player_id: int, old_tier: int, new_tier: int)

## 段位积分变动规则
const WIN_POINTS: int = 50        ## 撤离成功获得积分
const LOSS_POINTS: int = -20      ## 爆仓扣除积分
const PROFIT_BONUS_RATIO: float = 0.01  ## 每 $100 利润额外 +1 积分


## 根据本局结果计算积分变动
func calculate_rank_change(profit: float, extracted: bool) -> int:
	var points := 0
	if extracted:
		points = WIN_POINTS
		points += int(maxf(0.0, profit) * PROFIT_BONUS_RATIO)
	else:
		points = LOSS_POINTS
	return points


## 应用积分变动，返回新的段位
func apply_rank_change(player_id: int, current_points: int, current_tier: int,
		delta_points: int) -> Dictionary:
	var new_points := maxi(0, current_points + delta_points)
	var new_tier := _calculate_tier(new_points)
	if new_tier != current_tier:
		rank_changed.emit(player_id, current_tier, new_tier)
	return {"points": new_points, "tier": new_tier, "changed": new_tier != current_tier}


## 根据积分计算段位
func _calculate_tier(points: int) -> int:
	var tier := GameEnums.RankTier.BRONZE
	for t in Constants.RANK_THRESHOLDS:
		if points >= Constants.RANK_THRESHOLDS[t]:
			tier = t
	return tier


## 获取距离下一段位还差多少积分
func get_points_to_next_tier(current_points: int) -> int:
	var current_tier := _calculate_tier(current_points)
	var next_tier := current_tier + 1
	if next_tier > GameEnums.RankTier.LEGEND:
		return 0
	if Constants.RANK_THRESHOLDS.has(next_tier):
		return Constants.RANK_THRESHOLDS[next_tier] - current_points
	return 0
