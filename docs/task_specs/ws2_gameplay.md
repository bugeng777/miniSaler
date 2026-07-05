# WS2 游戏玩法组 — Phase 2 任务规格书

> **组长**: WS2 Lead  
> **独占目录**: `src/server/gameplay/` + `src/shared/era_data.gd` + `src/shared/skill_types.gd`  
> **禁止修改**: 其他任何目录的文件  

---

## 一、代码评审修复

### 任务 1.1 [CRITICAL] skill_types.gd 变量声明被注释吞噬 — CR-01

**文件**: `src/shared/skill_types.gd` L23  
**问题**: `restricted_era` 变量声明与 `##` 注释挤在同一行，变量从未声明  
**要求**: 将变量声明移到注释下一行  

**验收**: `SkillDef.from_dict()` 能正确读写 `restricted_era` 字段，运行无报错

---

## 二、Phase 2 新功能开发

### 任务 2.1 时代专属特殊机制实现

**文件**: `src/server/gameplay/era_manager.gd`  
**背景**: 每个时代在 `special_mechanics` 中声明了特殊机制标识（如 `currency_war`、`chaebol_policy`、`ipo_frenzy`、`leverage_party`、`t_plus_1`），但当前无实现  
**要求**:
1. 新增 `EraMechanicsHandler` 类（`RefCounted`），负责管理当前时代的特殊机制
2. 每个机制实现为一个方法：
   - `currency_war`（香港）：港币汇率波动影响所有股票
   - `chaebol_policy`（首尔）：政府政策新闻对财阀股影响 ×2
   - `ipo_frenzy`（硅谷）：每隔 N 秒注入一次"新公司 IPO"事件
   - `leverage_party`（东京）：所有玩家初始可借入额外资金
   - `t_plus_1`（上海）：买入当天不可卖出（T+1 限制）
3. EraManager 在 `set_current_era()` 时初始化对应机制

**验收**: 选择不同时代后，特殊机制效果可感知（通过日志或信号观察）

### 任务 2.2 新闻系统增强：信息延迟实现

**文件**: `src/server/gameplay/news_system.gd`  
**背景**: `NewsEvent` 已有 `info_delay` 字段，但当前生成后直接 emit，无延迟  
**要求**:
1. 新闻生成后不立即 emit，而是放入延迟队列
2. 每 tick（由 GameSession 调用的 `update(delta)`）检查队列，到期后 emit
3. 不同玩家有不同的延迟（通过 `skill_system` 的被动技能"新闻速读"可减少延迟）
4. 黑天鹅事件 `info_delay = 0`，立即 emit

**验收**: 普通新闻有 0-3 秒延迟，黑天鹅新闻无延迟

### 任务 2.3 技能系统：被动技能效果集成

**文件**: `src/server/gameplay/skill_system.gd`  
**背景**: 当前 `get_passive_modifiers()` 返回修改器字典，但没有子系统消费它  
**要求**:
1. 新增 `signal passive_effects_changed(player_id: int, modifiers: Dictionary)` 信号
2. 在 `equip_skills()` 完成后立即 emit 一次
3. 确保每个被动技能的 `base_value` 语义明确：
   - `news_reader`: 减少信息延迟秒数
   - `sentiment_sense`: 是否显示恐贪指数（bool 语义）
   - `short_expert`: 做空收益加成比例
   - `safe_harbor`: 撤离窗口延长秒数
   - `diversify`: 持仓 >3 时手续费减免比例

**验收**: GameSession 连接此信号后能获取玩家的被动效果，并传递给相关子系统

### 任务 2.4 Bot 策略多样化

**文件**: `src/server/gameplay/bot_manager.gd`  
**要求**:
1. **趋势跟踪者**: 增加动量判断——最近 N tick 价格持续上涨才买，持续下跌才卖
2. **逆向投资者**: 增加偏离度判断——价格偏离基准价 >X% 才操作
3. **噪音交易者**: 保持随机，但增加"暂停"概率（模拟散户观望）
4. **激进交易者**: 增加大额交易频率，并在 Boss 入场时跟随 Boss 方向

**验收**: 不同策略 Bot 的交易频率和方向分布有明显差异（可通过日志统计验证）

---

## 三、接口契约（冻结版）

```
# ExtractionEngine 信号
signal extraction_window_opened(duration: float)
signal extraction_window_closed()
signal player_extracted(player_id: int, profit: float)
signal player_busted(player_id: int)

# NewsSystem 信号
signal news_generated(news_event: Dictionary)
signal black_swan_triggered(event: Dictionary)

# SkillSystem 信号
signal skill_activated(player_id: int, skill_id: StringName, effect: Dictionary)
signal skill_cooldown_updated(player_id: int, skill_id: StringName, remaining: float)
signal passive_effects_changed(player_id: int, modifiers: Dictionary)  # 新增

# BotManager 信号
signal bot_action_executed(bot_id: int, action: Dictionary)
signal boss_entered(boss_name: String, boss_data: Dictionary)
signal boss_defeated(boss_name: String, result: Dictionary)
```
