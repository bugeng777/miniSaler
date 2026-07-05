# WS4 网络会话组 — Phase 2 任务规格书

> **组长**: WS4 Lead  
> **独占目录**: `src/server/session/` + `src/client/network/` + `src/shared/network_protocol.gd`  
> **禁止修改**: 其他任何目录的文件（含 `src/main.gd`，main.gd 由 TL 维护）  

---

## 一、代码评审修复

### 任务 1.1 [CRITICAL] ClientNetwork RPC 注解 + 方法名统一 — CR-02

**文件**: `src/client/network/client_network.gd`  
**问题 A**: 5 个 `send_*` 方法通过 `rpc_id()` 调用服务端但缺少 `@rpc` 注解  
**问题 B**: 服务端 `_broadcast()` 调用 `rpc_sync_data` 但客户端接收方法名为 `sync_data`

**要求**:
1. 为所有 `send_*` 方法添加 `@rpc("any_peer", "call_remote")` 注解
2. 将 `sync_data` 重命名为 `rpc_sync_data`，并添加 `@rpc("authority", "call_remote")` 注解
3. 确保 `ClientNetwork` 的 RPC 方法签名与 `GameSession` 的对应方法匹配

**验收**: Host 模式 + Client 连接后，双方能双向通信

### 任务 1.2 [MEDIUM] GameSession 消除 OrderBook 直接引用 — MD-04

**文件**: `src/server/session/game_session.gd` L227-231  
**问题**: `connect_subsystem_signals()` 中通过 `market_engine.get_order_book()` 直接访问 OrderBook 内部组件并连接其信号，违反"子系统间禁止直接引用"的架构规则  
**要求**:
1. 删除 `market_engine.get_order_book()` 调用
2. 改为连接 MarketEngine 自身转发的信号（WS1 会在 MarketEngine 中新增 `order_filled_passthrough` 信号）
3. 如果 WS1 尚未就绪，可先在 GameSession 中声明一个临时内部信号做桥接

**验收**: GameSession 不再直接引用 OrderBook 对象

---

## 二、Phase 2 新功能开发

### 任务 2.1 断线重连机制

**文件**: `src/client/network/client_network.gd`  
**要求**:
1. 检测断线: 连接 `multiplayer.server_disconnected` 信号
2. 自动重连: 断线后每 3 秒尝试重连，最多重试 5 次
3. 重连成功后: 向服务端请求当前状态快照（新增 `rpc_request_state_sync`）
4. 重连失败后: emit `signal reconnection_failed()`，UI 显示提示

**验收**: 模拟断线后客户端自动重连并恢复游戏状态

### 任务 2.2 多人模式 RPC 完善

**文件**: `src/server/session/game_session.gd`  
**背景**: 当前 RPC 方法仅处理基本请求，缺少多人场景下的状态同步  
**要求**:
1. 新增 `rpc_player_ready(player_id: int)`: 多人模式下标记玩家准备完成
2. 新增 `rpc_chat_message(player_id: int, text: String)`: 简单聊天功能
3. 所有 RPC 方法增加 `player_id` 合法性校验（防止伪造 ID）

**验收**: 两个 Client 连接 Host，双方能看到对方的订单和状态变化

### 任务 2.3 广播优化：增量快照

**文件**: `src/server/session/game_session.gd` + `src/shared/network_protocol.gd`  
**背景**: 当前每 tick 广播完整市场快照（8 只股票全量数据），约 2KB/包  
**要求**:
1. 新增 `build_market_tick_delta(prev, current)` 方法，只发送变化的股票数据
2. 每 10 tick 发送一次全量快照（防漂移），其余发送增量
3. 在 `NetworkProtocol` 中新增 `MSG_MARKET_TICK_DELTA` 消息类型

**验收**: 增量包大小 < 500B（对比全量 2KB）

---

## 三、接口契约（冻结版）

### GameSession 对子系统的连接方式（仅通过信号）

```
MarketEngine.tick_complete → _on_market_tick → _broadcast(tick_data)
ExtractionEngine.* → _on_extraction_* → _broadcast / goto_*
NewsSystem.* → _on_news_* → _broadcast
SkillSystem.* → _on_skill_* → _broadcast
BotManager.* → _on_bot_action / _on_boss_entered → MarketEngine.submit_order / _broadcast
PlayerManager.* → 由 GameSession 直接调用（PlayerManager 是纯数据层）
```

### ClientNetwork RPC 方法清单

```
# Client → Server（客户端调用）
rpc_submit_order(data: Dictionary)
rpc_request_extraction()
rpc_activate_skill(skill_id: StringName)
rpc_select_era(era_id: StringName)
rpc_configure_loadout(data: Dictionary)
rpc_player_ready()  # 新增
rpc_chat_message(text: String)  # 新增
rpc_request_state_sync()  # 新增（断线重连后）

# Server → Client（服务端广播）
rpc_sync_data(msg: Dictionary)  # 统一广播通道
```
