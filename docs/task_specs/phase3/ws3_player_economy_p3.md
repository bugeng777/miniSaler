# WS3 玩家经济组 — Phase 3 任务规格书

> **组长**: WS3 Lead  
> **独占目录**: `src/server/player/` + `src/shared/player_types.gd`  
> **本阶段角色**: 技能资金效果 + 成就完整化 + 排行榜数据  

---

## 任务 3.1 技能资金/持仓效果（服务于 WS2 技能系统）

**前置**: 等 WS2 冻结 SkillEffect 契约（Week 1）  
**文件**: `src/server/player/player_manager.gd` + `player_state.gd`

实现 `effect_type == "fund_modifier"` 类技能的资金修改：
1. `apply_leverage(player_id, multiplier)` — 杠杆狂人（借入 3 倍资金）
2. `apply_cash_interest(player_id, rate)` — 现金为王（每 tick 计息）
3. `apply_bust_protection(player_id, retain_ratio)` — 钢铁意志（爆仓保留 10%）
4. `apply_all_in_limit(player_id)` — 全押（限制只能持有一只股票）
5. `apply_short_bonus(player_id, bonus)` — 做空专家（做空收益 +20%）

**验收**: 装备对应技能后资金计算符合技能描述

## 任务 3.2 成就系统完整化

**文件**: `src/server/player/achievement_system.gd`  
**要求**:
1. 补全所有 10 个成就检测逻辑（Phase 2 已补部分）
2. 新增 10+ 个成就（参考 PRD §Ch.31）：
   - "首撤百万"、"连败翻身"、"满仓梭哈"、"BOSS猎人"、"时代通关"等
3. 成就奖励发放逻辑：`grant_reward(profile, achievement_def)`
   - reward_type: skill → 解锁技能；safe_box_upgrade → 保险柜+1格；funds → 加钱

**验收**: 20+ 成就可检测、可解锁、奖励可发放

## 任务 3.3 排行榜数据管理

**新增文件**: `src/server/player/leaderboard_manager.gd`  
**要求**:
1. `class_name LeaderboardManager`，继承 `Node`
2. 全局排行: `get_global_ranking(sort_by: StringName) -> Array`
   - 支持按 total_profit / win_rate / rank_points 排序
3. 赛季排行: `get_season_ranking() -> Array` + 每月重置逻辑
4. 数据持久化: 通过 SaveManager 存储历史排行

**验收**: 排行榜可按多维度排序，赛季数据可重置

## 任务 3.4 破产保护完善

**文件**: `src/server/player/player_manager.gd`  
**背景**: Phase 2 已实现 check_welfare / apply_newbie_protection  
**要求**: Phase 3 增加低保冷却时间检查（24h 最多一次）+ 硬底线（保险柜永不清零）

**验收**: 低保有冷却限制，保险柜资产任何情况不丢失

---

## 接口契约（Phase 3 新增，需 CTO 冻结）

```
# PlayerManager 新增方法（技能资金效果）
func apply_leverage(player_id: int, multiplier: float) -> void
func apply_cash_interest(player_id: int, rate: float) -> void
func apply_bust_protection(player_id: int, retain_ratio: float) -> void

# LeaderboardManager 新增（供 WS4 网络同步 + WS5 UI 显示）
signal leaderboard_updated(ranking: Array)
func get_global_ranking(sort_by: StringName) -> Array
func get_season_ranking() -> Array

# AchievementSystem 新增
signal reward_granted(player_id: int, reward_type: String, reward_value: String)
```

**依赖关系**: 3.1 依赖 WS2 契约；3.3 排行榜是 WS4/WS5 的前置。
