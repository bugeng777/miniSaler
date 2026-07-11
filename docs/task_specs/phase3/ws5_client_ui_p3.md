# WS5 客户端 UI 组 — Phase 3 任务规格书

> **组长**: WS5 Lead  
> **独占目录**: `src/client/ui/` + `src/client/audio/`  
> **本阶段角色**: 技能 UI + 视觉特效 + 时代氛围 + 新手引导（工作量最大的组）  

---

## 任务 3.1 技能 UI 显示（服务于 WS2 技能系统）

**前置**: 等 WS2 冻结 SkillEffect 契约（Week 1）  
**文件**: `src/client/ui/components/skill_bar.gd` + 新增技能显示组件

实现 `effect_type == "ui_display"` 类技能的 UI 表现：
1. 趋势洞察: K 线上显示 MA 交叉信号标记
2. 情绪感知: 顶栏显示恐贪指数（Phase 2 已有，Phase 3 优化）
3. 基本面扫描: 股票列表显示内在价值 vs 现价
4. 风险预警: 崩盘前 30 秒全屏红色警告
5. 跟风大师: 显示其他玩家买卖方向箭头

**验收**: 5 个显示类技能激活后有对应 UI 表现

## 任务 3.2 视觉反馈系统

**新增文件**: `src/client/ui/components/vfx_layer.gd`  
**要求**:
1. `class_name VfxLayer`，覆盖在交易屏幕之上
2. 盈利动画: 买入获利时绿色数字飘升
3. 亏损动画: 亏损时红色数字飘落
4. 撤离成功: 全屏金色粒子 + 音效
5. 爆仓: 屏幕震动 + 红色闪烁
6. Boss 入场: 专属过场动画（横幅 + 音效）

**验收**: 各关键事件有明确视觉反馈

## 任务 3.3 时代氛围差异化

**文件**: `src/client/ui/theme/dark_theme.gd`（扩展）  
**要求**:
1. 每个时代独特配色方案（香港=霓虹紫、硅谷=科技蓝、上海=中国红）
2. `apply_era_theme(era_id)` 方法切换配色
3. 时代专属背景音乐（WS5 audio 目录新增）

**验收**: 切换时代后 UI 配色和 BGM 明显不同

## 任务 3.4 新手引导

**新增文件**: `src/client/ui/screens/tutorial_screen.gd`  
**要求**:
1. `class_name TutorialScreen`，继承 `Control`
2. 首次进入触发（读取存档 total_games == 0）
3. 分步高亮引导: 选股 → 买入 → 看新闻 → 撤离
4. 可跳过，可在设置中重新触发

**验收**: 新玩家首次进入有引导，老玩家不触发

## 任务 3.5 排行榜界面

**前置**: 等 WS3 LeaderboardManager + WS4 网络同步（Week 5-6）  
**新增文件**: `src/client/ui/screens/leaderboard_screen.gd`  
**要求**: 显示全局/赛季排行，支持按利润/胜率/段位切换排序

**验收**: 排行榜界面可显示并切换排序维度

## 任务 3.6 成就弹窗

**前置**: 等 WS3 成就系统（Week 3-4）  
**新增文件**: `src/client/ui/components/achievement_toast.gd`  
**要求**: 成就解锁时右上角弹出 Toast + 音效，3 秒后淡出

**验收**: 成就解锁时有弹窗提示

---

## 接口契约（Phase 3 新增）

```
# VfxLayer 公开方法（供 main.gd 调用）
func play_profit_effect(amount: float, position: Vector2) -> void
func play_loss_effect(amount: float, position: Vector2) -> void
func play_extraction_success() -> void
func play_bust_effect() -> void
func play_boss_entrance(boss_name: String) -> void

# TutorialScreen 信号
signal tutorial_completed()
signal tutorial_skipped()

# DarkTheme 新增
func apply_era_theme(era_id: StringName) -> void

# AchievementToast 公开方法
func show_achievement(title: String, description: String) -> void
```

**依赖关系**: 3.1 依赖 WS2；3.5 依赖 WS3+WS4；3.6 依赖 WS3。3.2/3.3/3.4 完全独立可先做。
