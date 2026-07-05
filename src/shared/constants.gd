## 全局常量（Autoload 单例）
## 所有权: TL (架构师)
## 通过 Constants 单例访问，不要硬编码数值
extends Node


# ─── 网络 ──────────────────────────────────────────────────────────────────────
const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 8

# ─── 游戏时间 ────────────────────────────────────────────────────────────────────
const LOADOUT_DURATION: float = 30.0          ## 准备阶段时长（秒）
const TRADING_DURATION_MIN: float = 300.0     ## 交易阶段最短时长（秒）
const TRADING_DURATION_MAX: float = 420.0     ## 交易阶段最长时长（秒）
const SETTLEMENT_DURATION: float = 15.0       ## 结算展示时长（秒）
const TICK_INTERVAL: float = 0.5              ## 市场价格 tick 间隔（秒）

# ─── 资金与经济 ──────────────────────────────────────────────────────────────────
const INITIAL_FUNDS: float = 100_000.0        ## 初始保险柜资金
const MAX_EXTRA_FUNDS: float = 200_000.0      ## 额外带入资金上限
const TRANSACTION_FEE_RATE: float = 0.001     ## 手续费率 0.1%
const MARGIN_RATIO: float = 0.5               ## 做空保证金比率 50%
const WELFARE_TRIGGER: float = 5_000.0        ## 低保触发线
const WELFARE_REFILL: float = 10_000.0        ## 低保补充金额
const WELFARE_COOLDOWN_HOURS: int = 24        ## 低保冷却时间（小时）
const NEWBIE_PROTECTION_GAMES: int = 10       ## 新手保护局数
const NEWBIE_PROTECTION_RATIO: float = 0.3    ## 新手爆仓保留比例

# ─── 市场参数 ────────────────────────────────────────────────────────────────────
const STOCKS_PER_GAME: int = 8                ## 每局股票数量
const STOCK_PRICE_MIN: float = 30.0           ## 股票基准价下限
const STOCK_PRICE_MAX: float = 200.0          ## 股票基准价上限
const VOLATILITY_MIN: float = 0.01            ## 每 tick 波动率下限
const VOLATILITY_MAX: float = 0.04            ## 每 tick 波动率上限
const CIRCUIT_BREAKER_THRESHOLD: float = 0.15 ## 熔断阈值 ±15%
const CIRCUIT_BREAKER_DURATION: float = 30.0  ## 熔断时长（秒）

# ─── 新闻系统 ────────────────────────────────────────────────────────────────────
const NEWS_INTERVAL_MIN: float = 8.0          ## 新闻间隔下限（秒）
const NEWS_INTERVAL_MAX: float = 15.0         ## 新闻间隔上限（秒）
const BLACK_SWAN_PROBABILITY: float = 0.05    ## 黑天鹅概率 5%
const INFO_DELAY_MIN: float = 0.0             ## 信息延迟下限（秒）
const INFO_DELAY_MAX: float = 3.0             ## 信息延迟上限（秒）

# ─── Boss 系统 ───────────────────────────────────────────────────────────────────
const BOSS_SPAWN_PROBABILITY: float = 0.5     ## Boss 出现概率 50%
const BOSS_ENTRY_MINUTES_MIN: float = 2.0     ## Boss 入场时间下限（分钟）
const BOSS_ENTRY_MINUTES_MAX: float = 3.0     ## Boss 入场时间上限（分钟）

# ─── 撤离窗口（因时代而异，此处为默认值）─────────────────────────────────────
const DEFAULT_EXTRACTION_INTERVAL: float = 90.0  ## 默认撤离窗口间隔（秒）
const DEFAULT_EXTRACTION_DURATION: float = 15.0  ## 默认撤离窗口时长（秒）
const EMERGENCY_EXTRACTION_DURATION: float = 5.0 ## 紧急撤离窗口时长（秒）

# ─── 技能系统 ────────────────────────────────────────────────────────────────────
const INITIAL_SKILL_SLOTS: int = 2            ## 初始技能槽位
const SKILL_SLOT_LV10: int = 3                ## Lv10 技能槽位
const SKILL_SLOT_LV20: int = 4                ## Lv20 技能槽位
const SKILL_SLOT_LV30: int = 5                ## Lv30 技能槽位
const SKILL_MAX_LEVEL: int = 3                ## 技能最高等级
const SKILL_LEVEL_BONUS: float = 0.3          ## 每级技能效果加成 30%

# ─── 保险柜 ───────────────────────────────────────────────────────────────────────
const INITIAL_SAFE_BOX_SLOTS: int = 2         ## 初始保险柜格数
const SAFE_BOX_SLOTS_LV1: int = 3             ## 升级后格数
const SAFE_BOX_SLOTS_LV2: int = 4             ## 升级后格数
const SAFE_BOX_SLOTS_LV3: int = 6             ## 最高格数

# ─── 段位积分阈值 ────────────────────────────────────────────────────────────────
var RANK_THRESHOLDS: Dictionary = {
	GameEnums.RankTier.BRONZE: 0,
	GameEnums.RankTier.SILVER: 500,
	GameEnums.RankTier.GOLD: 1200,
	GameEnums.RankTier.PLATINUM: 2500,
	GameEnums.RankTier.DIAMOND: 5000,
	GameEnums.RankTier.LEGEND: 10000,
}

# ─── 时代解锁条件 ────────────────────────────────────────────────────────────────
## era_id -> 解锁条件描述（具体逻辑在 EraManager 中判断）
const ERA_UNLOCK_CONDITIONS: Dictionary = {
	"hk_1997": {"type": "initial"},                              ## 初始解锁
	"seoul_1988": {"type": "initial"},                           ## 初始解锁
	"silicon_2000": {"type": "extractions", "count": 5},         ## 成功撤离 5 次
	"tokyo_1989": {"type": "total_profit", "amount": 1_000_000}, ## 累计利润 100 万
	"shanghai_2007": {"type": "era_clear", "eras": ["hk_1997", "seoul_1988", "silicon_2000"], "count": 3},
}

# ─── 股票池（各时代配置）────────────────────────────────────────────────────────
## 每个时代的股票列表，由 EraConfig 加载
## 此处仅定义基准股票池模板
const STOCK_POOL_HK_1997: Array[Dictionary] = [
	{"symbol": "HKRE", "name": "恒基地产", "sector": "realestate", "base_price": 95.0, "volatility": 0.025},
	{"symbol": "HKBK", "name": "汇丰银行", "sector": "finance", "base_price": 120.0, "volatility": 0.02},
	{"symbol": "HKTK", "name": "电讯盈科", "sector": "tech", "base_price": 80.0, "volatility": 0.03},
	{"symbol": "HKSP", "name": "太古航运", "sector": "shipping", "base_price": 65.0, "volatility": 0.022},
	{"symbol": "HKRE2", "name": "新鸿基", "sector": "realestate", "base_price": 110.0, "volatility": 0.028},
	{"symbol": "HKBK2", "name": "东亚银行", "sector": "finance", "base_price": 75.0, "volatility": 0.018},
	{"symbol": "HKTK2", "name": "和记黄埔", "sector": "tech", "base_price": 130.0, "volatility": 0.032},
	{"symbol": "HKSP2", "name": "中远海运", "sector": "shipping", "base_price": 55.0, "volatility": 0.026},
]

## 首尔 1988 — 汉江奇迹
const STOCK_POOL_SEOUL_1988: Array[Dictionary] = [
	{"symbol": "KRCV", "name": "三星电子", "sector": "chaebol", "base_price": 140.0, "volatility": 0.02},
	{"symbol": "KRHY", "name": "现代重工", "sector": "chaebol", "base_price": 95.0, "volatility": 0.022},
	{"symbol": "KRDW", "name": "大宇集团", "sector": "chaebol", "base_price": 70.0, "volatility": 0.035},
	{"symbol": "KRKT", "name": "韩国电力", "sector": "construction", "base_price": 55.0, "volatility": 0.015},
	{"symbol": "KRBL", "name": "浦项制铁", "sector": "construction", "base_price": 85.0, "volatility": 0.018},
	{"symbol": "KRLG", "name": "LG化学", "sector": "electronics", "base_price": 110.0, "volatility": 0.024},
	{"symbol": "KRSK", "name": "SK电信", "sector": "electronics", "base_price": 125.0, "volatility": 0.028},
	{"symbol": "KRFD", "name": "农心食品", "sector": "consumer", "base_price": 45.0, "volatility": 0.012},
]

## 硅谷 2000 — 互联网泡沫
const STOCK_POOL_SILICON_2000: Array[Dictionary] = [
	{"symbol": "USPE", "name": "Pets.com", "sector": "internet", "base_price": 30.0, "volatility": 0.04},
	{"symbol": "USWB", "name": "Webvan", "sector": "internet", "base_price": 45.0, "volatility": 0.038},
	{"symbol": "USAM", "name": "Amazon", "sector": "internet", "base_price": 150.0, "volatility": 0.03},
	{"symbol": "USQH", "name": "Qualcomm", "sector": "software", "base_price": 180.0, "volatility": 0.032},
	{"symbol": "USYA", "name": "Yahoo!", "sector": "internet", "base_price": 200.0, "volatility": 0.035},
	{"symbol": "USMS", "name": "Microsoft", "sector": "software", "base_price": 120.0, "volatility": 0.018},
	{"symbol": "USGL", "name": "GlobalCrossing", "sector": "telecom", "base_price": 60.0, "volatility": 0.04},
	{"symbol": "USGE", "name": "GeneralElectric", "sector": "traditional", "base_price": 90.0, "volatility": 0.01},
]

## 东京 1989 — 泡沫之巅
const STOCK_POOL_TOKYO_1989: Array[Dictionary] = [
	{"symbol": "JPNK", "name": "日本兴业银行", "sector": "bank", "base_price": 160.0, "volatility": 0.02},
	{"symbol": "JPMF", "name": "三菱银行", "sector": "bank", "base_price": 130.0, "volatility": 0.018},
	{"symbol": "JPMI", "name": "三井不动产", "sector": "realestate", "base_price": 200.0, "volatility": 0.025},
	{"symbol": "JPSM", "name": "住友不动产", "sector": "realestate", "base_price": 175.0, "volatility": 0.028},
	{"symbol": "JPSE", "name": "索尼", "sector": "electronics", "base_price": 150.0, "volatility": 0.022},
	{"symbol": "JPTA", "name": "东芝", "sector": "electronics", "base_price": 85.0, "volatility": 0.02},
	{"symbol": "JPTY", "name": "丰田汽车", "sector": "automotive", "base_price": 110.0, "volatility": 0.015},
	{"symbol": "JPHN", "name": "本田", "sector": "automotive", "base_price": 95.0, "volatility": 0.016},
]

## 上海 2007 — 六千点的疯狂
const STOCK_POOL_SHANGHAI_2007: Array[Dictionary] = [
	{"symbol": "CNIC", "name": "工商银行", "sector": "bank", "base_price": 8.0, "volatility": 0.02},
	{"symbol": "CNCC", "name": "招商银行", "sector": "bank", "base_price": 35.0, "volatility": 0.025},
	{"symbol": "CNVK", "name": "万科A", "sector": "realestate", "base_price": 28.0, "volatility": 0.03},
	{"symbol": "CNPL", "name": "保利地产", "sector": "realestate", "base_price": 50.0, "volatility": 0.035},
	{"symbol": "CNZJ", "name": "紫金矿业", "sector": "metals", "base_price": 18.0, "volatility": 0.04},
	{"symbol": "CNLY", "name": "洛阳钼业", "sector": "metals", "base_price": 12.0, "volatility": 0.042},
	{"symbol": "CNST", "name": "ST长控", "sector": "st", "base_price": 5.0, "volatility": 0.045},
	{"symbol": "CNSJ", "name": "ST金泰", "sector": "st", "base_price": 3.5, "volatility": 0.048},
]
