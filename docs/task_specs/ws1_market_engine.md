# WS1 市场引擎组 — Phase 2 任务规格书

> **组长**: WS1 Lead  
> **独占目录**: `src/server/market/` + `src/shared/market_types.gd`  
> **禁止修改**: 其他任何目录的文件  

---

## 一、代码评审修复（优先级 CRITICAL → HIGH → MEDIUM）

### 任务 1.1 [HIGH] PriceModel 填充股票名称和行业 — HI-02

**文件**: `src/server/market/price_model.gd`  
**问题**: `_build_snapshot()` 未填充 `name` 和 `sector`，客户端股票列表无名称  
**要求**:
1. 在 `StockPriceState` 内部类新增 `stock_name: String` 和 `sector: String` 字段
2. `initialize_stocks()` 中从 cfg 读取并缓存
3. `_build_snapshot()` 中填充 `snap.name` 和 `snap.sector`

**验收**: 客户端交易屏幕股票按钮显示正确名称（如 "恒基地产" 而非空字符串）

### 任务 1.2 [MEDIUM] TradeRecord 序列化补全 — MD-03

**文件**: `src/shared/market_types.gd`  
**问题**: `TradeRecord.to_dict()` 缺失 `buy_order_id` 和 `sell_order_id`  
**要求**: 在 `to_dict()` 中添加这两个字段

**验收**: TradeRecord 序列化后可完整反序列化

---

## 二、Phase 2 新功能开发

### 任务 2.1 GARCH 参数可配置化

**文件**: `src/server/market/price_model.gd`  
**背景**: 当前 GARCH_OMEGA/ALPHA/BETA 是硬编码常量，但不同时代应有不同波动特征  
**要求**:
1. 将 GARCH 参数从 `const` 改为 `var`，默认值不变
2. 新增 `configure_garch(omega: float, alpha: float, beta: float)` 方法
3. MarketEngine.start_market() 时根据 EraData 配置 GARCH 参数

**验收**: 不同时代（如硅谷2000 vs 首尔1988）的价格波动特征明显不同

### 任务 2.2 订单簿限价单撮合优化

**文件**: `src/server/market/order_book.gd`  
**背景**: 当前限价单撮合正确，但市价单直接以"当前市价"成交，未考虑订单簿深度  
**要求**:
1. 市价单 BUY 时：从 ask 侧逐档吃单，直到数量满足
2. 市价单 SELL 时：从 bid 侧逐档吃单
3. 如果订单簿为空（无挂单），fallback 到当前市价成交

**验收**: 大额市价单会产生滑价效果（成交价略差于当前市价）

### 任务 2.3 熔断机制可视化数据

**文件**: `src/server/market/circuit_breaker.gd`  
**要求**:
1. 新增 `get_all_states() -> Dictionary` 返回所有股票的熔断状态
2. 返回格式: `{symbol: {"is_broken": bool, "remaining": float, "trigger_count": int}}`

**验收**: GameSession 可在每 tick 获取全市场熔断状态并广播

---

## 三、接口契约（冻结版）

WS1 对外暴露的信号（不可修改签名）：

```
# MarketEngine 信号
signal tick_complete(stock_snapshots: Array[MarketTypes.StockSnapshot], fear_greed_index: float)
signal circuit_breaker_triggered(symbol: StringName, duration: float)
signal market_phase_changed(phase: StringName)

# MarketEngine 公开方法
func start_market(era_config: EraData) -> void
func stop_market() -> void
func get_current_snapshot() -> Dictionary
func submit_order(player_id, symbol, side, order_type, quantity, limit_price) -> String
func inject_news_impact(symbol: StringName, impact: Dictionary) -> void
func get_order_book() -> OrderBook  # 仅供 WS4 GameSession 连接信号
func get_price_history(symbol: StringName) -> Array[float]
```

**注意 [架构约束]**: 此任务与 WS4-1.2 强耦合。WS1 必须:
1. 在 MarketEngine 中新增 `signal order_filled_passthrough(order: MarketTypes.BookOrder, fill_price: float, fill_qty: int)`
2. 在 MarketEngine._ready() 中连接 OrderBook.order_filled → emit order_filled_passthrough
3. 完成后通知 WS4 切换连接

**这是 CR 评审 MD-04 的修复方案，必须在 Week 1-2 完成。**
