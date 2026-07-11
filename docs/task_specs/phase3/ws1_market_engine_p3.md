# WS1 市场引擎组 — Phase 3 任务规格书

> **组长**: WS1 Lead  
> **独占目录**: `src/server/market/` + `src/shared/market_types.gd`  
> **本阶段角色**: 技能系统的市场数据提供方 + Boss 价格操纵行为  

---

## 任务 3.1 技能市场钩子（服务于 WS2 技能系统）

**前置**: 等 WS2 冻结 SkillEffect 契约（Week 1）  
**文件**: `src/server/market/market_engine.gd` + `price_model.gd`

分析类技能需要 WS1 提供市场数据。新增以下方法：

1. `get_intrinsic_value(symbol: StringName) -> float`（供"基本面扫描"）
   - 基于均值回归目标价 + 随机偏移计算内在价值
2. `get_whale_activity(symbol: StringName) -> Dictionary`（供"庄家追踪"）
   - 返回该股票最近大额订单方向和量（从 OrderBook 大单统计）
3. `get_ma_cross_signal(symbol: StringName) -> int`（供"趋势洞察"）
   - 返回 -1/0/1（死叉/无/金叉），基于短期/长期 MA

**验收**: WS2 技能系统能通过这些方法获取数据，返回值合理

## 任务 3.2 快速下单钩子（服务于"闪电下单"技能）

**文件**: `src/server/market/order_book.gd`  
**要求**: 新增 `submit_order_priority(...)` 方法，优先撮合（跳过队列）  
**验收**: 带"闪电下单"buff 的订单成交速度快于普通订单

## 任务 3.3 Boss 价格操纵行为

**前置**: 等 WS2 Boss 击败判定契约（Week 3）  
**文件**: `src/server/market/market_engine.gd`  
**要求**:
1. 新增 `apply_boss_manipulation(symbol, direction, strength)` 方法
2. Boss 交易时对目标股票施加额外价格压力（区别于普通订单）
3. 每时代 Boss 操纵不同板块（香港=汇率相关、硅谷=科技股）

**验收**: Boss 入场后目标板块出现明显异动

## 任务 3.4 时代 GARCH 参数微调

**文件**: `src/server/gameplay/era_manager.gd`（配合 WS2）→ WS1 提供接口  
**要求**: 确保 `configure_garch()` 已被各时代正确调用（Phase 2 已实现基础，Phase 3 做数值平衡）  
**验收**: 5 个时代波动特征符合 PRD 设定（硅谷2000极端、首尔1988中高）

---

## 接口契约（Phase 3 新增，需 CTO 冻结）

```
# MarketEngine 新增方法
func get_intrinsic_value(symbol: StringName) -> float
func get_whale_activity(symbol: StringName) -> Dictionary
func get_ma_cross_signal(symbol: StringName) -> int
func apply_boss_manipulation(symbol: StringName, direction: float, strength: float) -> void

# OrderBook 新增方法
func submit_order_priority(player_id, symbol, side, order_type, quantity, limit_price) -> String
```

**依赖关系**: 本组 3.1/3.2 是 WS2 技能系统的前置依赖，必须在 Week 1-2 优先交付。
