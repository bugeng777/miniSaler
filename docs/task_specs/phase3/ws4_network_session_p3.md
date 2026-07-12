# WS4 网络会话组 — Phase 3 任务规格书

> **组长**: WS4 Lead  
> **独占目录**: `src/server/session/` + `src/client/network/` + `src/shared/network_protocol.gd`  
> **本阶段角色**: 匹配系统 + 多人同步完善 + 排行榜/Boss/技能事件广播  

---

## 任务 3.1 匹配系统

**新增文件**: `src/server/session/matchmaking.gd`  
**要求**:
1. `class_name Matchmaking`，继承 `Node`
2. 快速匹配: `request_match(player_id, rank_tier)` — 匹配同段位玩家
3. Bot 填充: 匹配超时 10s 后用 Bot 填充空位到 8 人
4. 房间管理: `create_room()` / `join_room(room_id)` / `leave_room(player_id)`
5. 匹配成功后 emit `match_found(room_id, players)`

**前置**: 仅依赖 WS3 段位数据（Phase 2 已有），可独立开发  
**验收**: 玩家点击开始后 10s 内进入房间（真人或 Bot 填充）

## 任务 3.2 多人同步完善

**文件**: `src/server/session/game_session.gd` + `src/client/network/client_network.gd`  
**要求**:
1. **断线 Bot 接管**: 玩家断线后其 player_id 转为 Bot 控制（而非踢出）
2. **状态预测**: 客户端提交订单后乐观渲染，服务端确认后纠正
3. **快捷聊天**: 扩展 `rpc_chat_message` 支持预设消息 ID（"快撤离！"/"跟庄！"/"崩了"）

**验收**: 断线玩家由 Bot 接管，聊天快捷消息可用

## 任务 3.3 排行榜网络同步

**前置**: 等 WS3 完成 LeaderboardManager（Week 5）  
**文件**: `src/server/session/game_session.gd`  
**要求**:
1. 连接 `LeaderboardManager.leaderboard_updated` 信号
2. 新增广播消息 `MSG_LEADERBOARD_SYNC`
3. 客户端接收后转发给 WS5 的排行榜界面

**验收**: 排行榜数据能从服务端同步到客户端

## 任务 3.4 Boss/技能事件广播完善

**前置**: 等 WS2 完成 Boss 判定和技能效果（Week 3）  
**文件**: `src/server/session/game_session.gd`  
**要求**:
1. 连接 `bot_manager.boss_defeated` → 广播击败结果和奖励
2. 连接 `skill_system.skill_effect_applied` → 广播技能效果（供 WS5 显示特效）
3. 新增 `MSG_BOSS_DEFEATED` 和 `MSG_SKILL_EFFECT` 消息类型

**验收**: Boss 击败和技能触发能广播到所有客户端

---

## 接口契约（Phase 3 新增，需 CTO 冻结）

```
# NetworkProtocol 新增消息类型
const MSG_LEADERBOARD_SYNC := &"sync_leaderboard"
const MSG_BOSS_DEFEATED := &"sync_boss_defeated"
const MSG_SKILL_EFFECT := &"sync_skill_effect"
const MSG_MATCH_FOUND := &"sync_match_found"

# Matchmaking 信号
signal match_found(room_id: String, players: Array)

# ClientNetwork 新增 RPC
@rpc("any_peer") func rpc_request_match(rank_tier: int) -> void
@rpc("any_peer") func rpc_quick_chat(message_id: int) -> void
```

**依赖关系**: 3.1 独立可开工；3.3 依赖 WS3；3.4 依赖 WS2。建议 Week 5 先做 3.1/3.2。
