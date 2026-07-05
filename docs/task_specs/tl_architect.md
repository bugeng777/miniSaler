# TL (WS0) 架构师 — Phase 2 任务规格书

> **角色**: Tech Lead / 架构师  
> **独占目录**: `src/main.gd`, `src/game_bootstrap.gd`, `src/shared/constants.gd`, `src/shared/enums.gd`  
> **禁止修改**: `src/server/`, `src/client/` 下任何文件（归属各组）  
> **特殊权限**: 可审核 `src/shared/` 下各组的变更  

---

## 一、代码评审修复

### 任务 1.1 [HIGH] StockSnapshot 类型双模处理 — HI-01

**文件**: `src/main.gd` L344-360  
**问题**: `_on_market_tick` 中 `data.get("snapshots", [])` 的元素类型取决于运行模式：
- **Host 模式**: 元素是 `MarketTypes.StockSnapshot` 对象（信号直传，无序列化）
- **Client 模式**: 元素是 `Dictionary`（经过 ENet RPC 序列化）

当前代码用 `if s is Dictionary` 判断，Host 模式下永远为 false，导致 `prices` 字典为空 → 顶栏总资产和排行榜只显示现金部分。

**要求**:
```gdscript
# 修复：同时处理两种类型
for s in snaps:
    if s is MarketTypes.StockSnapshot:
        prices[s.symbol] = s.close
    elif s is Dictionary:
        prices[StringName(s.get("symbol", ""))] = s.get("close", 0.0)
```

需修复两处（L344-346 顶栏区域 + L358-360 排行榜区域）。

**验收**: Host 模式进入交易，顶栏"总资产" = 现金 + 持仓市值（非仅现金）

### 任务 1.2 [HIGH] 段位 rank_tier 永不升段 — HI-04

**文件**: `src/main.gd` L432-434  
**问题**: `_persist_settlement()` 只更新 `rank_points`，但 `rank_tier` 从未调用 `RankSystem.apply_rank_change()` 重算。玩家积分涨到 10000+ 仍然是 BRONZE。

**要求**:
```gdscript
# 修复：在 rank_points 更新后调用 rank_system
# 当前代码：
_player_profile.rank_points = maxi(0, _player_profile.rank_points + rank_delta)

# 改为：
if _rank_system:
    var result := _rank_system.apply_rank_change(
        HOST_PLAYER_ID,
        _player_profile.rank_points,
        _player_profile.rank_tier,
        rank_delta)
    _player_profile.rank_points = result.points
    _player_profile.rank_tier = result.tier
else:
    _player_profile.rank_points = maxi(0, _player_profile.rank_points + rank_delta)
```

**验收**: 累计积分到 500+ 完成一局后，`rank_tier` 从 BRONZE 变为 SILVER

### 任务 1.3 [MEDIUM] SkillBar 主动技能信号未连接 — MD-02

**文件**: `src/main.gd` `_connect_ui_signals()`  
**问题**: `SkillBar.skill_activate_requested` 信号已声明并在玩家点击时 emit，但 main.gd 从未连接它。主动技能按钮点击无效。

**要求**: 在 `_connect_ui_signals()` 的交易屏幕信号连接区域添加：
```gdscript
var trading_screen := _find_screen("trading")
if trading_screen is TradingScreen:
    var sb := (trading_screen as TradingScreen).get_skill_bar()
    if sb:
        sb.skill_activate_requested.connect(func(skill_id: StringName) -> void:
            _game_session.host_submit_skill(HOST_PLAYER_ID, skill_id)
        )
```

注意: `GameSession` 当前无 `host_submit_skill` 方法。TL 需在 main.gd 中直接调用：
```gdscript
if _skill_system:
    _skill_system.activate_skill(HOST_PLAYER_ID, skill_id)
```

**验收**: 装备主动技能（如"趋势洞察"），交易中点击技能按钮，技能效果触发

---

## 二、跨组接口集成（等各组交付后连接）

以下任务需等待其他组完成后才能在 main.gd 中集成。TL 负责跟踪进度并适时连接。

### 任务 2.1 等待 WS2: 被动技能信号连接

**前置**: WS2 完成 `skill_system.passive_effects_changed` 信号  
**TL 动作**: 在 `_connect_ui_signals()` 中连接此信号，更新 TradingScreen 上的被动技能指示器  
**预计时间**: Week 2

### 任务 2.2 等待 WS3: 订单拒绝信号连接

**前置**: WS3 完成 `player_manager.order_rejected` 信号  
**TL 动作**: 在 `_connect_ui_signals()` 中连接此信号，在 TradingScreen 上显示错误提示  
**预计时间**: Week 1-2

### 任务 2.3 等待 WS5: 新增屏幕注册

**前置**: WS5 完成 `SafeBoxScreen`  
**TL 动作**: 在 `_build_game_ui()` 中注册新屏幕，在 LoadoutScreen 中添加保险柜配置入口  
**预计时间**: Week 3+

---

## 三、main.gd 维护职责

### 3.1 信号连接完整性

TL 是 main.gd 的唯一维护者，负责确保：
- 所有 GameSession 信号 → UI 的映射正确
- 所有 UI 屏幕信号 → GameSession 的映射正确
- 新增信号时同步更新 `_connect_ui_signals()`

### 3.2 生命周期管理

TL 负责 main.gd 中的游戏生命周期流程：
```
ERA_SELECT → LOADOUT (30s countdown) → ENTER_MARKET (skill bar populate)
→ TRADING (tick updates, leaderboard, top bar) → SETTLEMENT (persist, leaderboard)
→ Play Again (reset screens)
```

### 3.3 shared/ 变更审核

当 WS1-WS5 需要修改 `src/shared/` 下的文件时，TL 负责：
1. 审核变更不影响其他组
2. 确保 `to_dict()`/`from_dict()` 一致性
3. 更新 `enums.gd` 或 `constants.gd` 如有需要

---

## 四、接口契约（main.gd 对外暴露/消费）

### main.gd 消费的子系统信号（在 _connect_ui_signals 中连接）

```
GameSession.phase_changed → _on_phase_changed
GameSession.data_received → _on_data_received
EraSelectScreen.era_selected → _on_era_selected
LoadoutScreen.loadout_confirmed → _on_loadout_confirmed
OrderPanel.order_requested → _on_order_requested
ExtractionPanel.extraction_requested → _on_extraction_requested
SettlementScreen.play_again_pressed → _on_play_again
SkillBar.skill_activate_requested → (待连接, 任务 1.3)
```

### main.gd 调用的子系统方法

```
_game_session.host_select_era(era_id)
_game_session.host_start_game()
_game_session.host_submit_order(player_id, symbol, side, type, qty, price)
_game_session.host_request_extraction(player_id)
_game_session.goto_era_select()
_player_manager.register_player(id, name, funds)
_player_manager.get_player_state(id)
_player_manager.get_all_snapshots()
_skill_system.equip_skills(id, skill_ids)
_skill_system.get_skill_def(skill_id)
_safe_box_manager.get_total_cash(id)
_safe_box_manager.initialize(id, items, slots)
_rank_system.apply_rank_change(id, points, tier, delta)  # 待连接 (任务 1.2)
_achievement_system.check_achievements(id, profile, result)
_save_manager.load_profile()
_save_manager.save_profile(profile)
```
