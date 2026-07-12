# miniSaler 代码结构审计（2026-07-12）

## 结论

项目能够通过 Godot 4.7 脚本导入并启动主场景，但原 Phase 3 验收报告存在“接口/文件存在即视为功能完成”的误判。此次审计优先修复了会直接破坏核心交易循环、服务端权威性和跨局成长的数据链路，并增加可重复执行的集成测试。

## 已修复

1. **订单 ID 断链**：PlayerManager 与 OrderBook 原先各自生成订单 ID，成交回调无法找到玩家待成交订单。现在由经济层先校验并登记，撮合层沿用同一 ID。
2. **部分成交丢失**：OrderBook 的部分成交没有转发给 PlayerManager。现在完整转发并累计成交数量、加权成交价和资金变化。
3. **越权与无效订单**：新增数量、价格、方向、现金、持仓、保证金、重复卖出预占等服务端校验；市场拒单会回滚经济层待成交状态。
4. **Bot 绕过经济层**：Bot 原先直接向 MarketEngine 下单，资金和持仓不变化。现在统一走 GameSession 权威订单入口。
5. **做空资产重复计算**：卖空所得已进入现金，原持仓市值又计入卖空利润，导致资产虚增。现在短仓按回补负债计值，并支持 BUY 回补。
6. **被动技能只有 UI 提示**：被动技能现在进入统一 SkillEffect 链，由 GameSession 分发到 PlayerManager / ExtractionEngine；现金利息、手续费减免、爆仓保护、单股限制、做空收益与安全港窗口获得服务端落点。
7. **多人事件错误终局**：任意 Bot/其他玩家撤离或爆仓原先会结束全局游戏。现在只有所有真人玩家均已结算时才进入 Settlement。
8. **匹配/排行未接线**：Matchmaking 与 LeaderboardManager 原先仅被创建。现在注入 GameSession，补齐匹配 RPC、匹配结果与排行榜广播。
9. **成就奖励缺失**：补齐 `grant_reward()`、奖励信号和错误技能 ID；结算时更新交易数、连胜、时代撤离、爆仓、经验，并发放奖励及显示成就 Toast。
10. **UI 状态问题**：Loadout 重入会清空上局技能选择；SafeBoxScreen 正式注册；主题入口切换为 PixelTheme；修复 TradingScreen 锚点/尺寸冲突。

## 验证

- Godot 4.7 editor import：通过，零脚本解析错误。
- 主场景 headless smoke：通过，零 GDScript runtime error / warning。
- `tests/core_integration_test.gd`：通过，覆盖买入、越权卖出、合法卖出、做空、回补、现金利息和撤离窗口加成。

执行命令：

```bash
godot --headless --path . --script res://tests/core_integration_test.gd
godot --headless --path . --quit-after 120
```

macOS headless 模式仍会输出系统 CA 证书读取错误，这是沙箱/系统证书访问造成的引擎平台日志，不是项目脚本错误。

## 尚未完成的产品工作

以下属于 Phase 4 计划本身，当前源码尚未交付，不能计入本次“结构修复完成”：

- MainMenuScreen 与 skills / achievements / settings 三个导航屏幕尚不存在。
- KLineChart 仍是 Line2D 价格折线，不是 PRD 要求的 OHLC 像素蜡烛图。
- 多数既有屏幕仍使用桌面式绝对坐标或三栏布局，尚未完成 390×844 移动端像素布局适配。
- ClientNetwork 尚未被 Main 的运行模式入口实例化；虽然 RPC 协议文件存在，但独立 Client 进程端到端流程仍需专门联调验收。
- 若干复杂技能（自动止损、批量交易、谣言、AI 跟随、杠杆借款/债务）只有契约或局部钩子，不应宣称“22 技能完整实现”。

建议下一阶段先冻结一套真实的自动化验收：每个 CTO 任务必须至少对应一个可执行测试或可观察的端到端场景，再更新验收报告。
