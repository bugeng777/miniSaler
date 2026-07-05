# 代码评审报告 — 骨架代码 Phase 0-2

> **评审人**: CTO  
> **评审范围**: `src/` 目录下全部 42 个 GDScript 文件（5,235 行）  
> **评审日期**: 2026-07-04  

---

## CRITICAL（阻塞级，必须在 Phase 2 首次提交前修复）

### CR-01: `skill_types.gd` 变量声明被注释吞噬 → 运行时崩溃

**文件**: `src/shared/skill_types.gd` L23  
**归属**: WS2（游戏玩法组）

`restricted_era` 变量声明与 `##` 注释挤在同一行，GDScript 将整行视为注释，导致变量**从未声明**。`to_dict()` 和 `from_dict()` 中引用此变量会抛出运行时错误。

```gdscript
# 当前（错误）：
## 限定时代 ID（仅 era_restricted=true 时有效）	var restricted_era: StringName = &""

# 修复：
## 限定时代 ID（仅 era_restricted=true 时有效）
var restricted_era: StringName = &""
```

**验收**: SkillDef.from_dict() 能正确读取 restricted_era 字段，无报错。

---

### CR-02: ClientNetwork 所有 RPC 方法缺少 `@rpc` 注解 + 方法名不匹配

**文件**: `src/client/network/client_network.gd` L60-110  
**归属**: WS4（网络会话组）

**问题 A**: `send_submit_order`、`send_request_extraction` 等 5 个方法通过 `rpc_id()` 调用服务端，但自身缺少 `@rpc` 注解。多人模式下所有客户端请求静默失败。

**问题 B**: 服务端 `_broadcast()` 调用 `rpc_id(peer_id, "rpc_sync_data", msg)`，但客户端接收方法名为 `sync_data`（非 `rpc_sync_data`），方法名不匹配导致服务端广播无法到达客户端。

```gdscript
# 修复 A — 为每个发送方法添加注解：
@rpc("any_peer", "call_remote")
func send_submit_order(...) -> void:
    rpc_id(1, "rpc_submit_order", {...})

# 修复 B — 统一方法名：
@rpc("authority", "call_remote")
func rpc_sync_data(msg: Dictionary) -> void:
    # 接收服务器广播数据
```

**验收**: 启动 Host 模式 + 一个 Client 连接，客户端能收到 tick 数据。

---

## HIGH（严重，影响核心玩法，Phase 2 前两周内修复）

### HI-01: `main.gd` 将 StockSnapshot 对象误当 Dictionary → 顶栏/排行榜永远显示 $0

**文件**: `src/main.gd` L343-366  
**归属**: TL（架构师）

`_on_market_tick` 中从 `data.get("snapshots", [])` 取出的元素是 `MarketTypes.StockSnapshot` 实例，但代码用 `if s is Dictionary` 判断，永远为 false。导致 `prices` 字典为空，顶栏总资产 = 仅现金，排行榜所有玩家资产 = 仅现金。

```gdscript
# 修复：
for s in snaps:
    if s is MarketTypes.StockSnapshot:
        prices[s.symbol] = s.close
```

---

### HI-02: `PriceModel._build_snapshot()` 未填充 name 和 sector → 客户端股票列表无名称

**文件**: `src/server/market/price_model.gd` L171-182  
**归属**: WS1（市场引擎组）

`StockSnapshot` 声明了 `name` 和 `sector` 字段，但 `_build_snapshot()` 从未设置，客户端收到的股票名称和行业始终为空。

```gdscript
# 修复：在 StockPriceState 中缓存，在 _build_snapshot() 中填充
# StockPriceState 新增：
var stock_name: String = ""
var sector: String = ""

# initialize_stocks() 中：
state.stock_name = cfg.get("name", "")
state.sector = cfg.get("sector", "")

# _build_snapshot() 中：
snap.name = state.stock_name
snap.sector = state.sector
```

---

### HI-03: PlayerManager 无持仓验证 → 玩家可无限卖出/做空凭空获利

**文件**: `src/server/player/player_manager.gd` L88-96  
**归属**: WS3（玩家经济组）

`on_order_filled` 处理 SELL 订单时不检查玩家是否持有股票。玩家不持股也能卖出，`cash += (cost - fee)` 照样执行 → **凭空获利**。SHORT 同理无保证金检查。

```gdscript
# 修复方向：
# SELL 前检查：
if order.side == GameEnums.OrderSide.SELL:
    var pos := state.positions.get(order.symbol, null)
    if not pos or pos.quantity < fill_qty:
        return  # 拒绝：持仓不足

# SHORT 前检查保证金：
if order.side == GameEnums.OrderSide.SHORT:
    var required_margin := fill_price * fill_qty * Constants.MARGIN_RATIO
    if state.cash < required_margin:
        return  # 拒绝：保证金不足
```

---

### HI-04: 段位永远不会升段 → rank_tier 始终是 BRONZE

**文件**: `src/main.gd` L432-434  
**归属**: TL（架构师）+ WS3

`_persist_settlement()` 只更新 `rank_points`，但 `rank_tier` 从未重算。`RankSystem.apply_rank_change()` 存在但从未被调用。

```gdscript
# 修复：在 _persist_settlement 中调用 rank_system
if _rank_system:
    var result := _rank_system.apply_rank_change(
        HOST_PLAYER_ID, _player_profile.rank_points,
        _player_profile.rank_tier, rank_delta)
    _player_profile.rank_points = result.points
    _player_profile.rank_tier = result.tier
```

---

### HI-05: SaveManager 两个加载方法不检查 JSON 解析错误 → 损坏存档静默丢数据

**文件**: `src/server/player/save_manager.gd` L54-57, L74-77  
**归属**: WS3（玩家经济组）

`load_safe_box()` 和 `load_skill_progress()` 不检查 `json.parse()` 返回值（对比 `load_profile()` 正确检查了）。存档损坏时静默返回默认值，玩家保险柜和技能进度丢失无警告。

```gdscript
# 修复：
if json.parse(file.get_as_text()) != OK:
    push_warning("SaveManager: Failed to parse safe_box JSON")
    file.close()
    return {"slots": Constants.INITIAL_SAFE_BOX_SLOTS, "items": []}
```

---

## MEDIUM（建议修复，不影响核心流程但影响质量）

### MD-01: LoadoutScreen 重玩时技能选择不重置

**文件**: `src/client/ui/screens/loadout_screen.gd` L78  
**归属**: WS5（客户端 UI 组）

`load_skills()` 清除了 UI 子节点但未重置 `_selected_skills` 数组。再来一局时上局选择残留，可能超出槽位限制。

**修复**: 在 `load_skills()` 开头添加 `_selected_skills.clear()`

---

### MD-02: SkillBar 主动技能信号从未连接 → 点击主动技能无效果

**文件**: `src/main.gd` `_connect_ui_signals()`  
**归属**: TL（架构师）

`skill_bar.skill_activate_requested` 信号已声明并触发，但 `main.gd` 从未连接它。主动技能按钮点击无效。

**修复**: 在 `_connect_ui_signals()` 中连接 SkillBar 信号到 GameSession 的技能激活方法。

---

### MD-03: TradeRecord.to_dict() 缺失 buy_order_id 和 sell_order_id

**文件**: `src/shared/market_types.gd` L136-143  
**归属**: WS1（市场引擎组）

两个字段已声明但未包含在序列化输出中。

---

### MD-04: GameSession 通过 get_order_book() 直接访问 OrderBook → 违反架构约束

**文件**: `src/server/session/game_session.gd` L227-231  
**归属**: WS4（网络会话组）

GameSession 直接获取 MarketEngine 内部的 OrderBook 并连接其信号，违反了"子系统之间禁止直接引用"的架构规则。

**建议**: 让 MarketEngine 转发 `order_filled` 信号，GameSession 只连接 MarketEngine 的信号。

---

### MD-05: settlement_screen.gd 变量名 `name` 遮蔽 Node.name

**文件**: `src/client/ui/screens/settlement_screen.gd` L86  
**归属**: WS5（客户端 UI 组）

`var name: String` 遮蔽了 `Node.name` 内置属性。Godot 4.4+ 会给出警告。

**修复**: 改名为 `player_name`。

---

## 各组评审任务汇总

| 组 | CRITICAL | HIGH | MEDIUM | 总计 |
|---|---|---|---|---|
| **TL** | 0 | 2 (HI-01, HI-04) | 1 (MD-02) | 3 |
| **WS1** | 0 | 1 (HI-02) | 1 (MD-03) | 2 |
| **WS2** | 1 (CR-01) | 0 | 0 | 1 |
| **WS3** | 0 | 2 (HI-03, HI-05) | 0 | 2 |
| **WS4** | 1 (CR-02) | 0 | 1 (MD-04) | 2 |
| **WS5** | 0 | 0 | 2 (MD-01, MD-05) | 2 |
