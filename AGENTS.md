# AGENTS.md — 迷你华尔街 (miniSaler)

## 项目概览

**迷你华尔街**是一款**金融版塔科夫**——提取循环(Extraction Loop)股票交易游戏。玩家穿越到不同历史金融市场（1997香港、1988首尔、2000硅谷、1989东京、2007上海），带入资金和技能卡进入市场交易，在撤离窗口提现利润——或者爆仓失去一切。保险柜保底，技能有限槽位，贪婪是敌人。

- **引擎**：Godot 4.7（Mobile 渲染器）
- **语言**：GDScript
- **主场景**：`res://src/main.tscn`
- **自动加载**：`Constants` → `res://src/shared/constants.gd`
- **设计文档**：
  - `PRD.md` — 产品需求文档（执行指南，说"做什么"）
  - `modelDesign.md` — 机制设计参考库（4938行44章，说"怎么做"）

### 核心循环

```
准备(Loadout) → 入局(Enter Market) → 交易+搜刮(Search & Trade) → 撤离/爆仓(Extract or Bust)
```

- **准备**: 选时代、配资金（保险柜+额外带入）、选技能卡（有限槽位）
- **入局**: 市场开始运转，新闻推送，AI/真人对手同时交易
- **交易**: 5-8分钟实时交易，贪婪分离线——"赚够了吗？还是再贪一点？"
- **撤离**: 撤离窗口开放时提现 = 利润永久入账；爆仓 = 本局收益全失（保险柜除外）

## 架构

### 客户端-服务器架构

```
┌─────────────────────────────────────────────────────┐
│                    main.gd (入口)                    │
│  ┌────────────────────────┐ ┌──────────────────────┐ │
│  │    服务器子系统         │ │    客户端逻辑         │ │
│  │   (仅 host 模式)        │ │   (所有模式)          │ │
│  │                        │ │                      │ │
│  │   MarketEngine         │ │   ClientNetwork      │ │
│  │   NewsGenerator        │ │   TradingLogic       │ │
│  │   PlayerManager        │ │   ExtractionUI       │ │
│  │   GameSession          │ │                      │ │
│  │   BotManager           │ │                      │ │
│  │   EraManager      [新] │ │                      │ │
│  │   SkillSystem     [新] │ │                      │ │
│  │   ExtractionEngine[新] │ │                      │ │
│  └────────────────────────┘ └──────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

- **Host 模式**：同时运行服务器 + 客户端
- **Client 模式**：仅客户端，通过 ENet RPC 通信
- **快速开始**：Host 模式 + AI Bot 填充

### 网络

- **协议**：ENet（`ENetMultiplayerPeer`）
- **端口**：7777（`Constants.DEFAULT_PORT`）
- **最大玩家**：8 人（`Constants.MAX_PLAYERS`）
- **通信**：服务器广播市场数据/新闻/撤离窗口状态，客户端 RPC 发送订单/撤离请求

### 游戏生命周期（新版）

```
时代选择 (ERA_SELECT) → 准备 (LOADOUT, 30s) → 入局 (ENTER_MARKET)
→ 交易中 (TRADING, 300-420s) → 撤离/爆仓 (EXTRACT/BUST) → 结算 (SETTLEMENT)
```

- **时代选择**: 选择进入哪个历史市场
- **准备**: 配置资金、技能卡、保险柜物品
- **交易中**: 实时行情（0.5s tick），随机新闻事件，撤离窗口间歇开放
- **撤离/爆仓**: 主动撤离成功 or 资金归零爆仓
- **结算**: 展示本局结果、经验获得、技能升级

## 项目结构

> **当前状态：Phase 2 进行中**。骨架代码已完成（42 文件 / 5,235 行），各组按 `docs/task_specs/` 下的任务规格书执行开发。

```
src/
├── main.gd / main.tscn           # 入口、子系统注入、信号中转（TL 维护）
├── game_bootstrap.gd             # 启动流程编排
├── server/
│   ├── market/                   # WS1 市场引擎组
│   │   ├── market_engine.gd      #   GARCH 价格模拟、tick 循环
│   │   ├── price_model.gd        #   GBM+均值回归+动量 价格形成算法
│   │   ├── order_book.gd         #   限价/市价单撮合引擎
│   │   └── circuit_breaker.gd    #   熔断机制
│   ├── gameplay/                 # WS2 游戏玩法组
│   │   ├── era_manager.gd        #   时代加载、配置、切换
│   │   ├── extraction_engine.gd  #   撤离窗口管理、撤离判定
│   │   ├── news_system.gd        #   新闻生成、信息延迟、黑天鹅
│   │   ├── skill_system.gd       #   技能执行、冷却、效果管理
│   │   └── bot_manager.gd        #   AI 对手策略、Boss 行为
│   ├── player/                   # WS3 玩家经济组
│   │   ├── player_manager.gd     #   玩家资金、持仓、订单执行
│   │   ├── player_state.gd       #   单个玩家运行时状态
│   │   ├── safe_box_manager.gd   #   保险柜：跨局资产保护
│   │   ├── rank_system.gd        #   段位计算与升降级
│   │   ├── achievement_system.gd #   成就检测与解锁
│   │   └── save_manager.gd       #   存档读写（user://saves/）
│   └── session/                  # WS4 网络会话组
│       └── game_session.gd       #   游戏阶段状态机、信号中枢、广播
├── client/
│   ├── network/                  # WS4 网络会话组
│   │   └── client_network.gd     #   ENet 客户端、RPC 收发
│   ├── ui/                       # WS5 客户端 UI 组
│   │   ├── ui_manager.gd         #   UI 栈管理、屏幕切换
│   │   ├── screens/              #   5 个屏幕（era_select, loadout, trading, settlement, profile）
│   │   ├── components/           #   8 个组件（kline, order, extraction, news, portfolio, leaderboard, topbar, skillbar）
│   │   └── theme/dark_theme.gd   #   暗色主题配置
│   └── audio/
│       └── sfx_manager.gd        #   音效管理
└── shared/                       # 共享数据类型（各组按所有权维护）
    ├── constants.gd              #   全局常量（Autoload, TL 维护）
    ├── enums.gd                  #   全局枚举（TL 维护）
    ├── market_types.gd           #   StockSnapshot, TickData, BookOrder（WS1）
    ├── era_data.gd               #   EraConfig Resource（WS2）
    ├── skill_types.gd            #   SkillDef, SkillProgress（WS2）
    ├── player_types.gd           #   Order, Position, PlayerSnapshot, SafeBoxItem, PlayerProfile（WS3）
    └── network_protocol.gd       #   RPC 消息常量、消息构建辅助（WS4）
```

### 设计文档

| 文档 | 定位 |
|------|------|
| `PRD.md` | 产品需求文档（做什么、为什么做） |
| `modelDesign.md` | 机制设计参考库（4938行44章，怎么做） |
| `AGENTS.md` | 本文件，项目上下文（AI协作入口） |
| `docs/task_specs/code_review_report.md` | 代码评审报告（12项问题，按组分配） |
| `docs/task_specs/ws1_market_engine.md` | WS1 市场引擎组 Phase 2 任务规格书 |
| `docs/task_specs/ws2_gameplay.md` | WS2 游戏玩法组 Phase 2 任务规格书 |
| `docs/task_specs/ws3_player_economy.md` | WS3 玩家经济组 Phase 2 任务规格书 |
| `docs/task_specs/ws4_network_session.md` | WS4 网络会话组 Phase 2 任务规格书 |
| `docs/task_specs/ws5_client_ui.md` | WS5 客户端UI组 Phase 2 任务规格书 |
| `docs/task_specs/cross_team_dependencies.md` | 跨组依赖分析与执行排序 |
| `docs/task_specs/phase2_acceptance_criteria.md` | Phase 2 集成验收标准 |

### 工作流制开发架构

项目采用 6 个工作流（Work Stream）组织开发，各组目录所有权严格隔离：

| 组 | 代号 | 独占目录 | 职责 |
|---|---|---|---|
| **TL** | 架构师 | `src/main.gd`, `src/shared/constants.gd`, `src/shared/enums.gd` | 入口、子系统注入、shared 审核 |
| **WS1** | 市场引擎组 | `src/server/market/`, `src/shared/market_types.gd` | 价格模拟、订单撮合、熔断 |
| **WS2** | 游戏玩法组 | `src/server/gameplay/`, `src/shared/era_data.gd`, `src/shared/skill_types.gd` | 时代、撤离、新闻、技能、Bot |
| **WS3** | 玩家经济组 | `src/server/player/`, `src/shared/player_types.gd` | 玩家管理、保险柜、段位、成就、存档 |
| **WS4** | 网络会话组 | `src/server/session/`, `src/client/network/`, `src/shared/network_protocol.gd` | GameSession、ENet、RPC |
| **WS5** | 客户端UI组 | `src/client/ui/`, `src/client/audio/` | 全部UI、音效、主题 |

**核心规则**：
1. 任何人不得修改非本组目录下的 `.gd` 文件
2. `shared/` 变更需提交 TL 审核
3. 子系统间只通过 signal 通信，禁止直接引用
4. 接口签名变更需 CTO 审批

## 已安装的插件

### Godot AI MCP (dlight) — v2.8.2

| 项 | 值 |
|---|---|
| **路径** | `addons/godot_ai/` |
| **来源** | https://github.com/hi-godot/godot-ai |
| **许可** | MIT |
| **MCP 工具数** | 120+ |
| **MCP Server** | `http://127.0.0.1:8000/mcp` |
| **Python 依赖** | `uv`（已安装 v0.11.25） |

**架构**：MCP 客户端 → HTTP :8000 → Python Server → WebSocket :9500 → Godot 编辑器插件 → EditorInterface + SceneTree API

## 开发环境依赖

| 依赖 | 版本 | 用途 |
|---|---|---|
| Godot | 4.7 | 游戏引擎（Mobile 渲染器） |
| uv | 0.11.25 | Python 包管理（MCP Server 运行所需） |

## AI 开发约定

1. **场景编辑优先用 MCP**：通过 Godot AI MCP 工具操作场景树和节点，不要直接编辑 `.tscn` 文件
2. **GDScript 规范**：遵循 Godot 4.x 官方风格指南，使用类型标注（`var x: float`、`-> void`）
3. **Autoload 使用**：全局常量通过 `Constants` 单例访问，`OrderTypes` 和 `StockData` 通过 `class_name` 全局引用
4. **架构分层**：客户端/服务端/共享代码严格分离在 `src/client/`、`src/server/`、`src/shared/` 下
5. **子系统注入**：新增服务器子系统需在 `main.gd` 中创建并注入到 `GameSession`，不要在子系统内部直接引用其他子系统
6. **UI 构建模式**：所有 UI 通过代码动态创建（`Node.new()` + `add_child()`），不使用 `.tscn` 场景文件
7. **信号驱动**：子系统间通过 signal 通信
8. **序列化约定**：网络传输使用 `to_dict()` / `from_dict()` 模式
9. **设计参考**：新增游戏机制前，先查阅 `modelDesign.md` 对应章节和 `PRD.md` 确认产品边界
# AGENTS.md — 迷你商贩 (miniSaler)

## 项目概览

**迷你商贩**（又名"迷你华尔街"）是一款**多人实时股票交易模拟游戏**。玩家在大厅匹配后进入一局游戏，经历盘前新闻预览、实时交易、收盘结算三个阶段。通过市价/限价单买卖 8 支虚拟股票，根据盈亏排名竞争段位提升。支持多人联机（最多 8 人）和单人 + AI 机器人两种模式。

- **引擎**：Godot 4.7（Mobile 渲染器）
- **语言**：GDScript
- **主场景**：`res://src/main.tscn`
- **自动加载**：`Constants` → `res://src/shared/constants.gd`
- **设计参考**：`modelDesign.md`（4900+ 行游戏机制设计文档，涵盖经济系统、价格模型、行为金融学、AI 对手等 44 个章节）

## 架构

### 客户端-服务器架构

```
┌─────────────────────────────────────────┐
│              main.gd (入口)              │
│  ┌───────────────────┐ ┌──────────────┐ │
│  │   服务器子系统     │ │  客户端逻辑   │ │
│  │  (仅 host 模式)    │ │  (所有模式)   │ │
│  │                   │ │              │ │
│  │  MarketEngine     │ │ ClientNetwork│ │
│  │  NewsGenerator    │ │ TradingLogic │ │
│  │  PlayerManager    │ │              │ │
│  │  GameSession      │ │              │ │
│  │  BotManager       │ │              │ │
│  └───────────────────┘ └──────────────┘ │
└─────────────────────────────────────────┘
```

- **Host 模式**：同时运行服务器子系统 + 客户端逻辑，主机既是服务端也是玩家
- **Client 模式**：仅运行客户端逻辑，通过 ENet RPC 与服务器通信
- **快速开始**：Host 模式 + 4 个 AI 机器人（BotManager）

### 网络

- **协议**：ENet（`ENetMultiplayerPeer`）
- **端口**：7777（`Constants.DEFAULT_PORT`）
- **最大玩家**：8 人（`Constants.MAX_PLAYERS`）
- **通信方式**：服务器通过 `GameSession` 广播市场数据/新闻/排行榜，客户端通过 RPC 发送订单

### 游戏生命周期

```
大厅 (LOBBY, 15s) → 盘前预览 (PRE_MARKET, 30s) → 交易中 (TRADING, 360s) → 收盘中 (CLOSEOUT, 30s) → 结算 (SETTLEMENT)
```

- **大厅**：等待玩家加入
- **盘前预览**：展示新闻，玩家观察但不能交易
- **交易中**：实时行情 tick（0.5s 间隔），玩家可下单
- **收盘中**：停止交易，计算排名
- **结算**：展示排行榜和盈亏，可"再来一局"

### UI 架构

**所有 UI 均为代码动态构建**（`main.gd` 中 `_build_game_ui()` 等方法），不使用 `.tscn` 场景文件。布局为三栏式：
- 左栏：股票列表（按钮选择）
- 中栏：行情图（Line2D 绘制）+ 交易面板（市价/限价单）
- 右栏：持仓 + 排行榜
- 底部：新闻滚动条
- 顶栏：阶段/计时器/现金/总资产/恐惧贪婪指数

暗色主题在 `_apply_dark_theme()` 中统一配置。

## 项目结构

```
src/
├── main.gd / main.tscn              # 主入口：模式选择 + UI 构建 + 信号中转
├── client/
│   └── scripts/
│       ├── client_network.gd        # ENet 客户端，RPC 接收服务器数据
│       └── trading_logic.gd         # 客户端交易逻辑，维护本地行情/持仓状态
├── server/
│   ├── market_engine.gd             # 市场引擎：价格模拟（GBM+均值回归）、订单簿撮合、恐惧贪婪指数
│   ├── news_generator.gd            # 新闻系统：宏观/行业/公司/黑天鹅 4 类事件，影响价格波动
│   ├── player_manager.gd            # 玩家管理：资金/持仓/订单执行/段位/成就/排行榜
│   ├── game_session.gd              # 会话管理：游戏阶段流转、ENet 服务器、数据广播
│   └── bot_manager.gd               # AI 机器人：4 种策略（random/trend/contrarian/aggressive）
└── shared/
    ├── constants.gd                  # 全局常量（Autoload）：市场参数/股票池/阶段时长/段位
    ├── order_types.gd                # 数据类型：Order（订单）、Position（持仓）、PlayerSnapshot
    └── stock_data.gd                 # 数据类型：StockData（股票 OHLCV + 波动率/漂移/动量）
```

### 核心数据类型

| 类型 | 文件 | 说明 |
|---|---|---|
| `OrderTypes.Order` | `order_types.gd` | 订单（id/方向/类型/数量/限价/成交状态） |
| `OrderTypes.Position` | `order_types.gd` | 持仓（symbol/数量/均价/未实现盈亏/已实现盈亏） |
| `OrderTypes.PlayerSnapshot` | `order_types.gd` | 玩家快照（资金/总资产/持仓/段位积分/胜率） |
| `StockData` | `stock_data.gd` | 股票数据（OHLCV + 波动率/漂移/动量 + 价格历史） |
| `Constants.Rank` | `constants.gd` | 段位枚举：BRONZE → SILVER → GOLD → PLATINUM → DIAMOND → LEGEND |

### 股票池

| 代码 | 名称 | 板块 | 基准价 |
|---|---|---|---|
| MNTK | 迷你科技 | tech | $120 |
| GOLX | 黄金矿业 | finance | $85 |
| ENEW | 新能源 | energy | $95 |
| BIOZ | 生物科技 | bio | $110 |
| CRYP | 加密核心 | tech | $150 |
| FOOD | 食品连锁 | consumer | $70 |
| META | 元宇宙 | tech | $130 |
| AUTO | 自动驾驶 | tech | $105 |

### 服务器子系统注入模式

`GameSession` 不直接创建子系统，而是由 `main.gd` 创建后注入引用：
```gdscript
server_game_session.market_engine = server_market_engine
server_game_session.news_generator = server_news_generator
server_game_session.player_manager = server_player_manager
```
`BotManager` 同样通过 `initialize(engine_ref, pm_ref)` 注入依赖。新增子系统需遵循此模式。

## 已安装的插件与工具

### Godot AI MCP (dlight) — v2.8.2

| 项 | 值 |
|---|---|
| **类型** | MCP Bridge（编辑器 ↔ AI 客户端） |
| **路径** | `addons/godot_ai/` |
| **来源** | https://github.com/hi-godot/godot-ai |
| **许可** | MIT |
| **MCP 工具数** | 120+（场景/节点/脚本/动画/材质/粒子/音频/UI 等） |
| **MCP Server 地址** | `http://127.0.0.1:8000/mcp` |
| **Python 依赖** | `uv`（已安装 v0.11.25） |
| **启用方式** | Godot → Project Settings → Plugins → 启用 Godot AI |

**架构**：MCP 客户端 → HTTP :8000 → Python Server (FastMCP) → WebSocket :9500 → Godot 编辑器插件 → EditorInterface + SceneTree API

**支持的 MCP 客户端**：Qoder、Claude Code、Claude Desktop、Cursor、Windsurf、VS Code、Codex、Antigravity、Zed、Cline 等 16+。

**使用注意**：
- 启动 Godot 编辑器后插件自动启动 MCP Server，无需手动启动
- 遥测可通过 `GODOT_AI_DISABLE_TELEMETRY=true` 关闭

## 开发环境依赖

| 依赖 | 版本 | 用途 |
|---|---|---|
| Godot | 4.7 | 游戏引擎（Mobile 渲染器） |
| uv | 0.11.25 | Python 包管理（MCP Server 运行所需） |

## AI 开发约定

1. **场景编辑优先用 MCP**：通过 Godot AI MCP 工具操作场景树和节点，不要直接编辑 `.tscn` 文件
2. **GDScript 规范**：遵循 Godot 4.x 官方风格指南，使用类型标注（`var x: float`、`-> void`）
3. **Autoload 使用**：全局常量通过 `Constants` 单例访问，`OrderTypes` 和 `StockData` 通过 `class_name` 全局引用，不要重复定义
4. **架构分层**：客户端/服务端/共享代码严格分离在 `src/client/`、`src/server/`、`src/shared/` 下
5. **子系统注入**：新增服务器子系统需在 `main.gd` 的 `_start_server()` 中创建并注入到 `GameSession`，不要在子系统内部直接引用其他子系统
6. **UI 构建模式**：所有 UI 通过代码动态创建（`Node.new()` + `add_child()`），不使用 `.tscn` 场景文件。新增 UI 组件应遵循 `main.gd` 中现有的 `_build_xxx_ui()` 方法模式
7. **信号驱动**：子系统间通过 signal 通信，不要在回调中直接调用其他子系统的方法（如 `market_engine.tick_complete` → `game_session.broadcast`）
8. **序列化约定**：网络传输使用 `to_dict()` / `from_dict()` 模式，所有共享数据类型需实现此接口
9. **新闻事件格式**：`{text, impact, magnitude, sentiment, symbol?}`，impact 类型为 `price_jump` 或 `volatility_spike`
10. **设计参考**：新增游戏机制前，先查阅 `modelDesign.md` 对应章节获取设计方法论参考
# AGENTS.md — 迷你商贩 (miniSaler)

## 项目概览

- **项目名称**：迷你商贩
- **引擎**：Godot 4.7（Mobile 渲染器）
- **语言**：GDScript
- **主场景**：`res://src/main.tscn`
- **自动加载**：`Constants` → `res://src/shared/constants.gd`

## 项目结构

```
src/
├── client/
│   └── scripts/
│       ├── client_network.gd    # 客户端网络通信
│       └── trading_logic.gd     # 交易逻辑
├── server/
│   ├── bot_manager.gd           # 机器人管理
│   ├── game_session.gd          # 游戏会话
│   ├── market_engine.gd         # 市场引擎
│   ├── news_generator.gd        # 新闻生成器
│   └── player_manager.gd        # 玩家管理
├── shared/
│   ├── constants.gd             # 全局常量（Autoload）
│   ├── order_types.gd           # 订单类型定义
│   └── stock_data.gd            # 股票数据
└── main.gd / main.tscn          # 主入口
```

## 已安装的插件与工具

### Godot AI MCP (dlight) — v2.8.2

| 项 | 值 |
|---|---|
| **类型** | MCP Bridge（编辑器 ↔ AI 客户端） |
| **路径** | `addons/godot_ai/` |
| **来源** | https://github.com/hi-godot/godot-ai |
| **许可** | MIT |
| **MCP 工具数** | 120+（场景/节点/脚本/动画/材质/粒子/音频/UI 等） |
| **MCP Server 地址** | `http://127.0.0.1:8000/mcp` |
| **Python 依赖** | `uv`（已安装 v0.11.25） |
| **启用方式** | Godot → Project Settings → Plugins → 启用 Godot AI |

**架构**：
```
MCP 客户端 (Qoder/Claude Code/Cursor/...)
    ↓ HTTP /mcp (端口 8000)
Python Server (FastMCP)
    ↓ WebSocket (端口 9500)
Godot 编辑器插件
    ↓ EditorInterface + SceneTree API
Godot 编辑器
```

**支持的 MCP 客户端**：Qoder、Claude Code、Claude Desktop、Cursor、Windsurf、VS Code、Codex、Antigravity、Zed、Cline、Kilo Code、Roo Code、Kiro、Trae 等 16+。

**使用注意**：
- 启动 Godot 编辑器后插件自动启动 MCP Server
- 无需手动启动 Python Server
- 遥测可通过 `GODOT_AI_DISABLE_TELEMETRY=true` 关闭

## 开发环境依赖

| 依赖 | 版本 | 用途 |
|---|---|---|
| Godot | 4.7 | 游戏引擎 |
| uv | 0.11.25 | Python 包管理（MCP Server 运行所需） |

## AI 开发约定

1. **场景编辑优先用 MCP**：通过 Godot AI MCP 工具操作场景树和节点，不要直接编辑 `.tscn` 文件
2. **GDScript 规范**：遵循 Godot 4.x GDScript 官方风格指南
3. **Autoload 使用**：全局常量通过 `Constants` 单例访问，不要重复定义
4. **架构分层**：客户端/服务端/共享代码严格分离在 `src/client/`、`src/server/`、`src/shared/` 下
5. **信号连接**：优先在代码中连接信号，避免在编辑器中隐式连接
