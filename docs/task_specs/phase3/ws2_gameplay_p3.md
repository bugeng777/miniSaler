# WS2 游戏玩法组 — Phase 3 任务规格书

> **组长**: WS2 Lead  
> **独占目录**: `src/server/gameplay/` + `src/shared/era_data.gd` + `src/shared/skill_types.gd`  
> **本阶段角色**: 技能系统核心 + Boss 系统核心（Phase 3 最关键的组）  
> **⚠️ 首日强制任务**: 任务 3.1 SkillEffect 契约必须 Week 1 第一天冻结，否则阻塞 WS1/WS3/WS5  

---

## 任务 3.1 【最高优先级】SkillEffect 契约定义

**文件**: `src/shared/skill_types.gd`  
**要求**: 定义每个技能的效果数据结构和触发方式，供其他组实现各自部分：

```gdscript
class SkillEffect:
    var skill_id: StringName
    var effect_type: StringName  # "market_data" | "fund_modifier" | "order_modifier" | "ui_display"
    var target: StringName       # 作用对象
    var value: float             # 效果数值
    var duration: float          # 持续时间
```

为 22 个技能各定义一个 SkillEffect 映射。**完成后立即通知 CTO 冻结，并广播给 WS1/WS3/WS5。**

**验收**: 22 个技能的 SkillEffect 定义完整，字段语义无歧义

## 任务 3.2 技能效果逻辑实现

**新增目录**: `src/server/gameplay/skill_effects/`  
按类别拆分文件（避免单文件过大）：
- `analysis_skills.gd` — 5 个分析类（调用 WS1 的 get_intrinsic_value 等）
- `execution_skills.gd` — 5 个执行类（批量交易/自动止损/闪电下单）
- `defense_skills.gd` — 5 个防御类（钢铁意志/风险预警/安全港）
- `social_skills.gd` — 4 个社交类（市场谣言/跟风大师）
- `aggressive_skills.gd` — 3 个激进类（杠杆狂人/全押/末日赌徒）

**验收**: 每个技能触发后产生预期效果（日志或信号可观测）

## 任务 3.3 Boss 击败判定与奖励

**文件**: `src/server/gameplay/bot_manager.gd`  
**要求**:
1. 完善 `settle_boss()` — Boss 亏损或爆仓时判定为"被击败"
2. 计算 Boss 对面玩家（反向持仓者）的额外奖励
3. emit `boss_defeated(boss_name, result)` 携带击败者列表和奖励
4. 每时代 Boss 独特行为（金融大鳄狂做空、风投之王拉高出货）

**验收**: Boss 亏损时触发击败，对面玩家获得奖励

## 任务 3.4 时代机制与技能联动

**文件**: `src/server/gameplay/era_manager.gd`  
**要求**: Phase 2 的 EraMechanicsHandler 与技能系统联动
- 香港"汇率战"触发时，"风险预警"技能提前警告
- 硅谷"IPO热潮"触发时，"Pre-IPO入场券"道具生效

**验收**: 时代机制与相关技能有可感知的联动

---

## 接口契约（Phase 3 新增，需 CTO 冻结）

```
# SkillSystem 新增信号
signal skill_effect_applied(player_id: int, skill_id: StringName, effect: SkillEffect)

# BotManager 已有信号（Phase 3 完善实现）
signal boss_defeated(boss_name: String, result: Dictionary)
# result 格式: {"defeated": bool, "winners": Array[int], "reward_per_winner": float}
```

**关键路径警告**: 任务 3.1 是整个 Phase 3 技能系统的地基。Phase 2 复盘显示 WS2 曾是瓶颈，本阶段请务必第一天交付契约。
