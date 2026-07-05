# WS3 玩家经济组 — Phase 2 任务规格书

> **组长**: WS3 Lead  
> **独占目录**: `src/server/player/` + `src/shared/player_types.gd`  
> **禁止修改**: 其他任何目录的文件  

---

## 一、代码评审修复

### 任务 1.1 [HIGH] PlayerManager 持仓验证 — HI-03

**文件**: `src/server/player/player_manager.gd` L88-96  
**问题**: `on_order_filled` 处理 SELL/SHORT 不检查持仓，玩家可凭空卖出获利  
**要求**:
1. SELL 订单成交前验证: `state.positions.has(symbol) && state.positions[symbol].quantity >= fill_qty`
2. SHORT 订单成交前验证: `state.cash >= fill_price * fill_qty * Constants.MARGIN_RATIO`
3. 验证失败时: 不更新资金，日志警告，emit `order_rejected` 信号

**验收**: 无持仓时 SELL 被拒绝，保证金不足时 SHORT 被拒绝

### 任务 1.2 [HIGH] SaveManager JSON 解析错误检查 — HI-05

**文件**: `src/server/player/save_manager.gd` L54-57, L74-77  
**问题**: `load_safe_box()` 和 `load_skill_progress()` 不检查 `json.parse()` 返回值  
**要求**: 与 `load_profile()` 保持一致，解析失败时 `push_warning` 并返回默认值

**验收**: 故意损坏存档文件后，加载不崩溃且有警告日志

---

## 二、Phase 2 新功能开发

### 任务 2.1 成就系统扩展：完整成就列表

**文件**: `src/server/player/achievement_system.gd`  
**背景**: 当前只有 3 个成就检测逻辑，但注册了 10 个成就  
**要求**: 补全所有成就的检测逻辑：
- `streak_5`: 连续 5 次撤离成功 → 需在 PlayerProfile 新增 `current_streak: int`
- `era_hk` / `era_seoul` / `era_silicon`: 各时代撤离 3 次 → 需按时代统计
- `short_master`: 单次做空获利 >5 万 → 从 session 数据判断
- `all_eras`: 解锁所有 5 时代 → 检查 unlocked_eras 数组
- `iron_man`: 爆仓 10 次 → 需新增 `total_busts: int`

**验收**: 每个成就在满足条件后正确解锁并 emit 信号

### 任务 2.2 破产保护机制

**文件**: `src/server/player/player_manager.gd`  
**背景**: PRD §7.2 定义了新手保护和低保系统，当前未实现  
**要求**:
1. 新增 `check_welfare(profile: PlayerTypes.PlayerProfile) -> float`:
   - 总资金 < $5,000 且距上次低保 > 24h → 补充至 $10,000
2. 新增 `apply_newbie_protection(profile, session_loss: float) -> float`:
   - 前 10 局爆仓时保留 30% 损失

**验收**: 低资金玩家触发低保，新手爆仓保留部分资金

### 任务 2.3 玩家经验值系统

**文件**: `src/server/player/player_state.gd` + `src/shared/player_types.gd`  
**要求**:
1. PlayerProfile 新增 `player_level: int` 和 `player_exp: int`（已声明但未使用）
2. 新增 `calculate_session_exp(profit, extracted, trades_count) -> int` 经验计算
3. 升级阈值: `exp_to_next = level * 100`
4. 升级时 emit `signal level_up(player_id: int, new_level: int)`

**验收**: 每局结算后经验增长，满值后升级

---

## 三、接口契约（冻结版）

```
# PlayerManager 信号
signal order_submitted(player_id: int, order: PlayerTypes.Order)
signal order_filled(player_id: int, order: PlayerTypes.Order, fill_price: float)
signal player_balance_changed(player_id: int, cash: float, total_assets: float)
signal player_bust_detected(player_id: int)
signal order_rejected(player_id: int, reason: String)  # 新增

# SafeBoxManager 信号
signal safe_box_updated(player_id: int, contents: Array)

# RankSystem 信号
signal rank_changed(player_id: int, old_tier: int, new_tier: int)

# AchievementSystem 信号
signal achievement_unlocked(player_id: int, achievement_id: StringName)
```
