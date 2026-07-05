## 全局枚举定义
## 所有权: TL (架构师)
## 修改需 Tech Lead 审核
class_name GameEnums


## 游戏阶段
enum GamePhase {
	ERA_SELECT,    ## 时代选择
	LOADOUT,       ## 准备阶段（配资金/选技能）
	ENTER_MARKET,  ## 入局（市场初始化）
	TRADING,       ## 交易中（核心玩法）
	EXTRACT,       ## 撤离成功
	BUST,          ## 爆仓
	SETTLEMENT,    ## 结算
}

## 订单方向
enum OrderSide {
	BUY,   ## 买入
	SELL,  ## 卖出
	SHORT, ## 做空
}

## 订单类型
enum OrderType {
	MARKET, ## 市价单
	LIMIT,  ## 限价单
}

## 订单状态
enum OrderStatus {
	PENDING,    ## 待成交
	FILLED,     ## 已成交
	PARTIAL,    ## 部分成交
	CANCELLED,  ## 已取消
	REJECTED,   ## 已拒绝
}

## 市场阶段（子状态）
enum MarketPhase {
	PRE_MARKET,  ## 盘前（只观察不可交易）
	TRADING,     ## 交易中
	CLOSED,      ## 已收盘
}

## 段位
enum RankTier {
	BRONZE,    ## 青铜
	SILVER,    ## 白银
	GOLD,      ## 黄金
	PLATINUM,  ## 铂金
	DIAMOND,   ## 钻石
	LEGEND,    ## 传奇
}

## 新闻影响类型
enum NewsImpact {
	PRICE_JUMP,       ## 价格跳变
	VOLATILITY_SPIKE, ## 波动率飙升
}

## 新闻情感
enum NewsSentiment {
	POSITIVE,  ## 利好
	NEGATIVE,  ## 利空
	NEUTRAL,   ## 中性
}

## 技能类型
enum SkillCategory {
	ANALYSIS,   ## 分析类
	EXECUTION,  ## 执行类
	DEFENSE,    ## 防御类
	SOCIAL,     ## 社交类
	AGGRESSIVE, ## 激进类
}

## 技能触发方式
enum SkillTrigger {
	PASSIVE,  ## 被动（入局自动生效）
	ACTIVE,   ## 主动（需玩家触发，有冷却）
}

## 保险柜物品类型
enum SafeBoxItemType {
	CASH,       ## 现金
	SKILL_CARD, ## 技能卡
	INTEL,      ## 情报
	LEGENDARY,  ## 传说道具
}

## Bot 策略类型
enum BotStrategy {
	TREND_FOLLOWER,  ## 趋势跟踪
	CONTRARIAN,      ## 逆向投资
	NOISE_TRADER,    ## 噪音交易
	AGGRESSIVE,      ## 激进交易
}

## 撤离结果
enum ExtractionResult {
	NONE,      ## 未撤离
	SUCCESS,   ## 撤离成功
	BUSTED,    ## 爆仓
	TIMEOUT,   ## 时间到未撤离
}
