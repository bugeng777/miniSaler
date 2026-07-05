# Phase 2 跨组依赖分析与执行排序

> **文档类型**: CTO 技术管理文档  
> **用途**: 各组长按此排序执行，避免跨组阻塞  
> **更新频率**: 每周一 CTO 更新  

---

## 一、跨组依赖矩阵

以下标识了各组 Phase 2 任务之间的依赖关系。**无依赖的任务可立即并行开始。**

| 任务 | 所属组 | 依赖 | 被依赖 | 阻塞级别 |
|---|---|---|---|---|
| WS1-1.1 (PriceModel name/sector) | WS1 | 无 | WS5-2.1 (K线需sector数据) | 低 |
| WS1-2.1 (GARCH可配置) | WS1 | 无 | WS2-2.1 (时代机制需传参) | 中 |
| WS1-2.3 (熔断可视化) | WS1 | 无 | WS4-2.3 (增量广播需含熔断) | 低 |
| WS2-1.1 (CR-01 skill_types) | WS2 | 无 | 无 | **阻塞自身** |
| WS2-2.1 (时代特殊机制) | WS2 | WS1-2.1 (GARCH参数) | 无 | 中 |
| WS2-2.2 (新闻延迟) | WS2 | 无 | WS5-2.3 (撤离面板需配合) | 低 |
| WS2-2.3 (被动技能信号) | WS2 | 无 | WS4 (需转发) → WS5 (需显示) | **高** |
| WS3-1.1 (持仓验证) | WS3 | 无 | 无 | **阻塞自身** |
| WS3-2.1 (成就扩展) | WS3 | 无 | WS5 (成就弹窗) | 低 |
| WS3-2.2 (破产保护) | WS3 | 无 | 无 | 无 |
| WS3-2.3 (经验值) | WS3 | 无 | WS5 (升级UI) | 低 |
| WS4-1.1 (CR-02 RPC注解) | WS4 | 无 | 无 | **阻塞自身** |
| WS4-1.2 (消除OrderBook直引) | WS4 | **WS1 新增转发信号** | 无 | **高** |
| WS4-2.1 (断线重连) | WS4 | WS4-1.1 (RPC注解修好) | 无 | 中 |
| WS4-2.2 (多人RPC) | WS4 | WS4-1.1 | WS5 (聊天UI) | 中 |
| WS4-2.3 (增量广播) | WS4 | WS1-2.3 (熔断数据) | WS5 (需处理delta) | 中 |
| WS5-1.1/1.2 (CR修复) | WS5 | 无 | 无 | **阻塞自身** |
| WS5-2.1 (K线蜡烛图) | WS5 | WS1-1.1 (OHLC数据) | 无 | 中 |
| WS5-2.2 (订单面板增强) | WS5 | 无 | 无 | 无 |
| WS5-2.3 (撤离面板增强) | WS5 | 无 | 无 | 无 |
| WS5-2.4 (顶栏增强) | WS5 | 无 | 无 | 无 |
| WS5-2.5 (保险柜屏幕) | WS5 | WS3 (SafeBoxManager API) | 无 | 低 |
| WS5-2.6 (音效生成) | WS5 | 无 | 无 | 无 |

---

## 二、关键路径

```
Week 1 (阻塞修复 + 无依赖任务):
  WS1: 1.1 (name/sector) ─── 可立即开始
  WS2: 1.1 (CR-01) ─── 必须第一天修，否则后续全阻塞
  WS3: 1.1 (持仓验证) + 1.2 (存档检查) ─── 可立即开始
  WS4: 1.1 (CR-02) ─── 必须第一天修，否则多人功能全阻塞
  WS5: 1.1/1.2 (CR修复) ─── 可立即开始

Week 2 (高依赖任务 + 独立新功能):
  WS1: 2.1 (GARCH配置) ─── 无依赖，可开始
  WS2: 2.3 (被动技能信号) ─── 新增信号需提前通知 WS4
  WS3: 2.1 (成就扩展) ─── 无依赖
  WS4: 1.2 (消除OrderBook) ─── 等 WS1 转发信号就绪
  WS5: 2.2/2.3/2.4 (独立UI增强) ─── 无依赖

Week 3+ (有依赖的新功能):
  WS1: 2.2 (订单簿优化) + 2.3 (熔断数据)
  WS2: 2.1 (时代机制) ─── 等 WS1-2.1 GARCH配置完成
  WS3: 2.2 (破产保护) + 2.3 (经验值)
  WS4: 2.1 (断线重连) + 2.2 (多人RPC) + 2.3 (增量广播)
  WS5: 2.1 (K线蜡烛图) ─── 等 WS1-1.1 OHLC数据就绪
         2.5 (保险柜) ─── 等 WS3 SafeBox API 确认
         2.6 (音效生成) ─── 无依赖
```

---

## 三、需 CTO 协调的接口变更

以下变更涉及跨组接口修改，**必须由 CTO 审批后才能提交**：

### 变更 1: MarketEngine 新增信号（WS1 → WS4）

```
# WS1 在 MarketEngine 中新增：
signal order_filled_passthrough(order: MarketTypes.BookOrder, fill_price: float, fill_qty: int)

# WS4 将 GameSession 从直接连接 OrderBook 改为连接此信号
```

**协调动作**: WS1 先提交信号声明 → WS4 切换连接 → CTO 验证两边一致

### 变更 2: SkillSystem 新增信号（WS2 → WS4 → WS5）

```
# WS2 在 SkillSystem 中新增：
signal passive_effects_changed(player_id: int, modifiers: Dictionary)

# WS4 在 GameSession 中新增广播：
func _on_passive_effects_changed(player_id, modifiers):
    _broadcast({"msg_type": "passive_effects", ...})

# WS5 在 TradingScreen 中新增显示被动效果图标
```

**协调动作**: WS2 定义信号签名 → CTO 冻结 → WS4 转发 → WS5 消费

### 变更 3: PlayerManager 新增信号（WS3 → WS4 → WS5）

```
# WS3 在 PlayerManager 中新增：
signal order_rejected(player_id: int, reason: String)

# WS4 在 GameSession 中新增广播
# WS5 在 TradingScreen 中新增错误提示 Toast
```

**协调动作**: WS3 先提交 → WS4 转发 → WS5 UI 提示

### 变更 4: TickData 格式扩展（WS1 → WS4）

```
# WS1 在 MarketTypes.TickData 中新增可选字段：
var circuit_break_states: Dictionary = {}  # symbol -> {is_broken, remaining}

# WS4 在 NetworkProtocol 中新增 MSG_MARKET_TICK_DELTA 消息类型
```

**协调动作**: WS1 扩展 TickData → WS4 适配序列化 → WS5 解析新字段

---

## 四、各组并行无冲突保证

| 组 | 独占文件 | 独占 class_name | 可安全并行 |
|---|---|---|---|
| WS1 | `server/market/*.gd` + `shared/market_types.gd` | PriceModel, OrderBook, CircuitBreaker, MarketEngine, MarketTypes | 是 |
| WS2 | `server/gameplay/*.gd` + `shared/era_data.gd` + `shared/skill_types.gd` | EraManager, ExtractionEngine, NewsSystem, SkillSystem, BotManager, EraData, SkillTypes | 是 |
| WS3 | `server/player/*.gd` + `shared/player_types.gd` | PlayerManager, PlayerStateData, SafeBoxManager, RankSystem, AchievementSystem, SaveManager, PlayerTypes | 是 |
| WS4 | `server/session/*.gd` + `client/network/*.gd` + `shared/network_protocol.gd` | GameSession, ClientNetwork, NetworkProtocol | 是（除跨组信号变更） |
| WS5 | `client/ui/**/*.gd` + `client/audio/*.gd` | UIManager, 各Screen, 各Component, DarkTheme, SfxManager | 是 |

**规则**: 任何跨组文件修改（如 WS4 改 main.gd）必须先提交 CTO 审批。
