# TL (WS0) 架构师 — Phase 3 任务规格书

> **角色**: Tech Lead / 架构师  
> **独占目录**: `src/main.gd`, `src/game_bootstrap.gd`, `src/shared/constants.gd`, `src/shared/enums.gd`  
> **本阶段角色**: 新子系统注入 + 跨组信号集成 + 契约冻结审批  

---

## 任务 3.1 契约冻结审批（Week 1，最高优先级）

Phase 3 有 3 个跨组契约需要 TL 审批冻结：

1. **SkillEffect 契约**（WS2 提交）→ TL 审核后广播给 WS1/WS3/WS5
2. **LeaderboardManager 接口**（WS3 提交）→ TL 审核后通知 WS4/WS5
3. **Matchmaking 接口**（WS4 提交）→ TL 审核

**TL 动作**: 收到各组契约提交后 24h 内审核，确保跨组一致性，冻结后各组才能开工。

## 任务 3.2 新子系统注入

**文件**: `src/main.gd`  
**要求**: 在 `_create_server_subsystems()` 中创建并注入新子系统：
1. `LeaderboardManager`（WS3 提供）→ 注入 GameSession
2. `Matchmaking`（WS4 提供）→ 注入 GameSession
3. 遵循 Phase 2 的注入模式（创建 → add_child → 注入引用）

**验收**: 新子系统正确挂载，GameSession 可访问

## 任务 3.3 技能效果集成

**前置**: 等 WS2 技能效果 + WS1 市场钩子 + WS3 资金效果就绪  
**文件**: `src/main.gd`  
**要求**: 在 main.gd 中连接技能效果链：
- `skill_system.skill_effect_applied` → 根据 effect_type 分发给对应子系统
- market_data → 调用 WS1 方法；fund_modifier → 调用 WS3 方法；ui_display → 转发 WS5

**验收**: 技能激活后完整效果链贯通（逻辑 + 资金 + UI）

## 任务 3.4 视觉特效集成

**前置**: 等 WS5 VfxLayer 就绪  
**文件**: `src/main.gd`  
**要求**: 在 main.gd 中创建 VfxLayer 并连接触发时机：
- 订单成交盈利 → play_profit_effect
- 撤离成功 → play_extraction_success
- 爆仓 → play_bust_effect
- Boss 入场 → play_boss_entrance

**验收**: 各事件触发对应特效

## 任务 3.5 新手引导集成

**前置**: 等 WS5 TutorialScreen 就绪  
**文件**: `src/main.gd`  
**要求**: 首次启动（profile.total_games == 0）时显示新手引导，连接 tutorial_completed 信号

**验收**: 新玩家首次进入触发引导

## 任务 3.6 新屏幕注册

**文件**: `src/main.gd`  
**要求**: 在 `_build_game_ui()` 中注册 WS5 新增屏幕：
- `leaderboard_screen`
- `tutorial_screen`
连接对应信号

**验收**: 新屏幕可通过 UIManager 切换

---

## 接口契约（TL 负责维护）

```
# main.gd 新增子系统引用
var _leaderboard_manager: LeaderboardManager = null
var _matchmaking: Matchmaking = null
var _vfx_layer: VfxLayer = null

# main.gd 技能效果分发方法
func _on_skill_effect_applied(player_id, skill_id, effect):
    match effect.effect_type:
        "market_data": _market_engine.xxx()
        "fund_modifier": _player_manager.xxx()
        "ui_display": (trading as TradingScreen).xxx()
```

**关键路径**: 任务 3.1 契约冻结是 Phase 3 全部开发的前提。Phase 2 复盘教训——首日必须冻结技能契约，TL 责任重大。
