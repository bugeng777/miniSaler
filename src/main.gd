## 主入口脚本
## 所有权: TL (架构师)
## 负责: 模式选择、子系统创建与注入、UI 构建、信号中转
extends Node
class_name Main


## 运行模式
enum RunMode {
	HOST,    ## 主机模式（服务器+客户端，无需网络）
	CLIENT,  ## 纯客户端模式（通过 ENet 连接远程服务器）
}

## ─── 子系统引用 ────────────────────────────────────────────────────────────
var _game_session: GameSession = null
var _market_engine: MarketEngine = null
var _era_manager: EraManager = null
var _extraction_engine: ExtractionEngine = null
var _news_system: NewsSystem = null
var _skill_system: SkillSystem = null
var _bot_manager: BotManager = null
var _player_manager: PlayerManager = null
var _safe_box_manager: SafeBoxManager = null
var _rank_system: RankSystem = null
var _achievement_system: AchievementSystem = null
var _save_manager: SaveManager = null

## 客户端
var _client_network: ClientNetwork = null
var _ui_manager: UIManager = null
var _sfx_manager: SfxManager = null

## 玩家档案（跨局持久化）
var _player_profile: PlayerTypes.PlayerProfile = null
## 本地 Host 玩家 ID（Host 模式下固定为 1）
const HOST_PLAYER_ID: int = 1

## 当前模式
var _run_mode: int = RunMode.HOST
## 准备阶段倒计时
var _loadout_countdown: float = 0.0
var _loadout_timer: Timer = null
## 玩家装备的技能 ID（供技能栏显示）
var _equipped_skill_ids: Array[StringName] = []


func _ready() -> void:
	_start_host_mode()


## ─── Host 模式启动 ──────────────────────────────────────────────────────────
func _start_host_mode() -> void:
	_run_mode = RunMode.HOST

	# 1. 加载存档
	_save_manager = SaveManager.new()
	_save_manager.name = "SaveManager"
	add_child(_save_manager)
	_player_profile = _save_manager.load_profile()

	# 2. 创建服务器子系统
	_create_server_subsystems()

	# 3. 创建 GameSession（Host 模式，不启动 ENet）
	_game_session = GameSession.new()
	_game_session.name = "GameSession"
	add_child(_game_session)
	_inject_subsystems()
	_game_session.connect_subsystem_signals()
	_game_session.start_host_mode()

	# 4. 创建客户端 UI + 音效
	_sfx_manager = SfxManager.new()
	_sfx_manager.name = "SfxManager"
	add_child(_sfx_manager)

	_build_game_ui()
	_connect_ui_signals()
	_populate_era_screen()

	# 准备阶段倒计时计时器
	_loadout_timer = Timer.new()
	_loadout_timer.wait_time = 1.0
	_loadout_timer.timeout.connect(_on_loadout_countdown_tick)
	add_child(_loadout_timer)

	DarkTheme.apply(get_tree())
	print("Main: Host mode started — 直接进入本地游戏")


## 创建服务器子系统（注入模式）
func _create_server_subsystems() -> void:
	_market_engine = MarketEngine.new()
	_market_engine.name = "MarketEngine"
	add_child(_market_engine)

	_era_manager = EraManager.new()
	_era_manager.name = "EraManager"
	add_child(_era_manager)

	_extraction_engine = ExtractionEngine.new()
	_extraction_engine.name = "ExtractionEngine"
	add_child(_extraction_engine)

	_news_system = NewsSystem.new()
	_news_system.name = "NewsSystem"
	add_child(_news_system)

	_skill_system = SkillSystem.new()
	_skill_system.name = "SkillSystem"
	add_child(_skill_system)

	_bot_manager = BotManager.new()
	_bot_manager.name = "BotManager"
	add_child(_bot_manager)

	_player_manager = PlayerManager.new()
	_player_manager.name = "PlayerManager"
	add_child(_player_manager)

	_safe_box_manager = SafeBoxManager.new()
	_safe_box_manager.name = "SafeBoxManager"
	add_child(_safe_box_manager)

	_rank_system = RankSystem.new()
	_rank_system.name = "RankSystem"
	add_child(_rank_system)

	_achievement_system = AchievementSystem.new()
	_achievement_system.name = "AchievementSystem"
	add_child(_achievement_system)

	# 初始化 Host 玩家保险柜
	if _player_profile:
		_safe_box_manager.initialize(HOST_PLAYER_ID, _player_profile.safe_box_items,
			_player_profile.safe_box_slots)


## 注入子系统引用到 GameSession
func _inject_subsystems() -> void:
	_game_session.market_engine = _market_engine
	_game_session.era_manager = _era_manager
	_game_session.extraction_engine = _extraction_engine
	_game_session.news_system = _news_system
	_game_session.skill_system = _skill_system
	_game_session.bot_manager = _bot_manager
	_game_session.player_manager = _player_manager
	_game_session.safe_box_manager = _safe_box_manager
	_game_session.rank_system = _rank_system
	_game_session.achievement_system = _achievement_system
	_game_session.save_manager = _save_manager


## 构建游戏 UI（代码动态创建）
func _build_game_ui() -> void:
	_ui_manager = UIManager.new()
	_ui_manager.name = "UIManager"
	_ui_manager.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_ui_manager)

	_ui_manager.register_screen("era_select", EraSelectScreen.new())
	_ui_manager.register_screen("loadout", LoadoutScreen.new())
	_ui_manager.register_screen("trading", TradingScreen.new())
	_ui_manager.register_screen("settlement", SettlementScreen.new())
	_ui_manager.register_screen("profile", ProfileScreen.new())

	_ui_manager.show_screen("era_select")


## 填充时代选择屏幕数据
func _populate_era_screen() -> void:
	var era_screen := _find_screen("era_select")
	if era_screen is EraSelectScreen:
		var eras := _era_manager.get_all_eras()
		var unlocked: Array[StringName] = []
		if _player_profile:
			unlocked = _player_profile.unlocked_eras
		else:
			unlocked = [&"hk_1997", &"seoul_1988"]
		(era_screen as EraSelectScreen).load_eras(eras, unlocked)


## 连接所有 UI 信号
func _connect_ui_signals() -> void:
	# ── GameSession → UI（Host 模式直接连接）──
	_game_session.phase_changed.connect(_on_phase_changed)
	_game_session.data_received.connect(_on_data_received)

	# ── 时代选择屏幕 ──
	var era_screen := _find_screen("era_select")
	if era_screen is EraSelectScreen:
		(era_screen as EraSelectScreen).era_selected.connect(_on_era_selected)

	# ── 准备屏幕 ──
	var loadout_screen := _find_screen("loadout")
	if loadout_screen is LoadoutScreen:
		(loadout_screen as LoadoutScreen).loadout_confirmed.connect(_on_loadout_confirmed)

	# ── 交易屏幕：下单 ──
	var trading_screen := _find_screen("trading")
	if trading_screen is TradingScreen:
		var ts := trading_screen as TradingScreen
		var order_panel := ts.get_order_panel()
		if order_panel:
			order_panel.order_requested.connect(_on_order_requested)
		var ext_panel := ts.get_extraction_panel()
		if ext_panel:
			ext_panel.extraction_requested.connect(_on_extraction_requested)

	# ── 结算屏幕 ──
	var settlement_screen := _find_screen("settlement")
	if settlement_screen is SettlementScreen:
		(settlement_screen as SettlementScreen).play_again_pressed.connect(_on_play_again)


## ─── UI 事件处理 ─────────────────────────────────────────────────────────────

## 时代选择
func _on_era_selected(era_id: StringName) -> void:
	# Host 模式直接调用 GameSession（不走 RPC）
	_game_session.host_select_era(era_id)
	# 准备屏幕加载技能数据
	_populate_loadout_screen()


## 填充准备屏幕
func _populate_loadout_screen() -> void:
	var loadout_screen := _find_screen("loadout")
	if loadout_screen is LoadoutScreen:
		var ls := loadout_screen as LoadoutScreen
		# 加载玩家已解锁技能
		var available_skills: Array[Dictionary] = []
		var unlocked_ids: Array = _player_profile.unlocked_skills if _player_profile else []
		for raw in SkillTypes.ALL_SKILLS:
			var sid: String = raw.get("skill_id", "")
			if unlocked_ids.has(StringName(sid)):
				available_skills.append(raw)
		ls.load_skills(available_skills)


## 准备完成
func _on_loadout_confirmed(extra_funds: float, skill_ids: Array[StringName]) -> void:
	_loadout_timer.stop()  # 停止倒计时
	# Host 模式直接注册玩家
	var safe_cash := _safe_box_manager.get_total_cash(HOST_PLAYER_ID)
	var total_funds := safe_cash + extra_funds
	_player_manager.register_player(HOST_PLAYER_ID, "玩家", total_funds)
	# 装备技能
	_skill_system.equip_skills(HOST_PLAYER_ID, skill_ids)
	# 存储技能 ID 供技能栏使用
	_equipped_skill_ids = skill_ids
	# 通知 GameSession 进入下一阶段
	_game_session.host_start_game()


## 下单请求
func _on_order_requested(symbol: StringName, side: int, order_type: int,
		quantity: int, limit_price: float) -> void:
	# Host 模式：通过 GameSession 直接提交（不走 RPC）
	# symbol 可能为空（需要选中股票），如果为空则忽略
	if symbol == &"":
		# 尝试从交易屏幕获取当前选中股票
		var trading := _find_screen("trading")
		if trading is TradingScreen:
			symbol = (trading as TradingScreen).get_selected_symbol()
	if symbol != &"":
		_game_session.host_submit_order(HOST_PLAYER_ID, symbol, side,
			order_type, quantity, limit_price)


## 撤离请求
func _on_extraction_requested() -> void:
	_game_session.host_request_extraction(HOST_PLAYER_ID)


## 再来一局
func _on_play_again() -> void:
	# 重置交易屏幕状态
	var trading := _find_screen("trading")
	if trading is TradingScreen:
		(trading as TradingScreen).reset_screen()
	_game_session.goto_era_select()
	_populate_era_screen()


## ─── GameSession 数据分发给 UI ──────────────────────────────────────────────

func _on_phase_changed(phase: int, data: Dictionary) -> void:
	match phase:
		GameEnums.GamePhase.ERA_SELECT:
			_loadout_timer.stop()
			_ui_manager.show_screen("era_select")
			_update_profile_screen()
		GameEnums.GamePhase.LOADOUT:
			_ui_manager.show_screen("loadout")
			# 启动准备阶段倒计时
			_loadout_countdown = Constants.LOADOUT_DURATION
			_loadout_timer.start()
			_update_loadout_countdown()
		GameEnums.GamePhase.ENTER_MARKET:
			_loadout_timer.stop()
			_ui_manager.show_screen("trading")
			_populate_skill_bar()
		GameEnums.GamePhase.TRADING:
			_ui_manager.show_screen("trading")
		GameEnums.GamePhase.SETTLEMENT:
			_loadout_timer.stop()
			_ui_manager.show_screen("settlement")
			_persist_settlement(data)
			var settlement := _find_screen("settlement")
			if settlement is SettlementScreen:
				(settlement as SettlementScreen).show_result(data)


func _on_data_received(msg: Dictionary) -> void:
	var msg_type: StringName = msg.get("msg_type", &"")
	match msg_type:
		NetworkProtocol.MSG_MARKET_TICK:
			_on_market_tick(msg.get("data", {}))
		NetworkProtocol.MSG_NEWS:
			_on_news_received(msg)
		NetworkProtocol.MSG_EXTRACTION_WINDOW:
			_on_extraction_window(msg.get("is_open", false), msg.get("remaining", 0.0))
		NetworkProtocol.MSG_GAME_PHASE:
			pass  # phase_changed 信号已处理
		NetworkProtocol.MSG_SKILL_STATE:
			_on_skill_state(msg)
		NetworkProtocol.MSG_BOSS_EVENT:
			_on_boss_event(msg)


func _on_market_tick(data: Dictionary) -> void:
	var trading := _find_screen("trading")
	if trading is TradingScreen and trading.visible:
		(trading as TradingScreen).update_market_tick(data)
		# 更新顶栏现金/总资产
		if _player_manager:
			var state := _player_manager.get_player_state(HOST_PLAYER_ID)
			if state:
				var top := (trading as TradingScreen).get_top_bar()
				if top:
					var prices: Dictionary = {}
					var snaps: Array = data.get("snapshots", [])
					for s in snaps:
						if s is Dictionary:
							prices[StringName(s.get("symbol", ""))] = s.get("close", 0.0)
					top.update_cash(state.cash)
					top.update_assets(state.get_total_assets(prices))
					top.update_timer(data.get("elapsed_time", 0.0))
			# 更新排行榜
			if _player_manager:
				var lb := (trading as TradingScreen).get_leaderboard()
				if lb:
					var snapshots := _player_manager.get_all_snapshots()
					var lb_data: Array[Dictionary] = []
					var prices: Dictionary = {}
					var snaps: Array = data.get("snapshots", [])
					for s in snaps:
						if s is Dictionary:
							prices[StringName(s.get("symbol", ""))] = s.get("close", 0.0)
					for snap in snapshots:
						lb_data.append({
							"player_name": snap.player_name,
							"total_assets": snap.get_total_assets(prices),
						})
					lb.update_leaderboard(lb_data)
			

func _on_news_received(data: Dictionary) -> void:
	var trading := _find_screen("trading")
	if trading is TradingScreen and trading.visible:
		(trading as TradingScreen).add_news(data.get("text", ""))
	# 音效
	if _sfx_manager:
		_sfx_manager.play_sfx(SfxManager.SfxType.NEWS_ALERT)


func _on_extraction_window(is_open: bool, remaining: float) -> void:
	var trading := _find_screen("trading")
	if trading is TradingScreen:
		(trading as TradingScreen).set_extraction_window(is_open, remaining)
	if is_open and _sfx_manager:
		_sfx_manager.play_sfx(SfxManager.SfxType.WINDOW_OPEN)


func _on_skill_state(data: Dictionary) -> void:
	var trading := _find_screen("trading")
	if trading is TradingScreen and trading.visible:
		var skill_bar := (trading as TradingScreen).get_skill_bar()
		if skill_bar:
			var skill_id := StringName(data.get("skill_id", ""))
			var event: String = data.get("event", "")
			if event == "cooldown":
				var remaining: float = data.get("cooldown_remaining", 0.0)
				skill_bar.update_cooldown(skill_id, remaining)
			elif event == "activated":
				# 技能激活时显示完整冷却时间
				var effect: Dictionary = data.get("effect", {})
				skill_bar.update_cooldown(skill_id, effect.get("duration", 0.0))


func _on_boss_event(data: Dictionary) -> void:
	var trading := _find_screen("trading")
	if trading is TradingScreen:
		var boss_name: String = data.get("boss_name", "")
		(trading as TradingScreen).add_news("[BOSS] %s 入场！" % boss_name)
	if _sfx_manager:
		_sfx_manager.play_sfx(SfxManager.SfxType.BOSS_ENTER)


## 辅助：查找已注册屏幕
func _find_screen(screen_name: String) -> Control:
	if _ui_manager:
		return _ui_manager.get_screen(screen_name)
	return null


## 结算后持久化存档
func _persist_settlement(data: Dictionary) -> void:
	if not _player_profile or not _save_manager:
		return
	# 更新玩家档案
	_player_profile.total_games += 1
	var extracted: bool = data.get("extracted", false)
	var profit: float = data.get("profit", 0.0)
	if extracted:
		_player_profile.total_extractions += 1
		_player_profile.total_funds += profit
		_player_profile.total_profit += profit
		if profit > _player_profile.highest_session_profit:
			_player_profile.highest_session_profit = profit
	# 更新段位
	var rank_delta: int = data.get("rank_delta", 0)
	if _rank_system:
		var result := _rank_system.apply_rank_change(
			HOST_PLAYER_ID,
			_player_profile.rank_points,
			_player_profile.rank_tier,
			rank_delta)
		_player_profile.rank_points = result.points
		_player_profile.rank_tier = result.tier
	else:
		_player_profile.rank_points = maxi(0, _player_profile.rank_points + rank_delta)
	# 检查成就解锁
	if _achievement_system:
		var session_result := {"extracted": extracted, "profit": profit}
		var new_achievements := _achievement_system.check_achievements(
			HOST_PLAYER_ID, _player_profile, session_result)
		for ach_id in new_achievements:
			_player_profile.achievements.append(ach_id)
	# 保存
	_save_manager.save_profile(_player_profile)
	print("Main: Profile saved — games: %d, extractions: %d, funds: $%d" % [
		_player_profile.total_games, _player_profile.total_extractions,
		int(_player_profile.total_funds)])


## ─── 准备阶段倒计时 ────────────────────────────────────────────────────────

func _on_loadout_countdown_tick() -> void:
	_loadout_countdown -= 1.0
	_update_loadout_countdown()
	if _loadout_countdown <= 0.0:
		_loadout_timer.stop()
		# 自动提交默认配置
		_on_loadout_confirmed(0.0, [])


func _update_loadout_countdown() -> void:
	var loadout := _find_screen("loadout")
	if loadout is LoadoutScreen:
		(loadout as LoadoutScreen).set_countdown(maxf(0.0, _loadout_countdown))


## ─── 技能栏填充 ─────────────────────────────────────────────────────────────

func _populate_skill_bar() -> void:
	var trading := _find_screen("trading")
	if not trading is TradingScreen:
		return
	var skill_bar := (trading as TradingScreen).get_skill_bar()
	if not skill_bar:
		return
	skill_bar.clear_skills()
	for sid in _equipped_skill_ids:
		var def := _skill_system.get_skill_def(sid)
		if def:
			var is_active := (def.trigger == GameEnums.SkillTrigger.ACTIVE)
			skill_bar.add_skill(sid, def.display_name, is_active)


## ─── 个人资料屏幕 ─────────────────────────────────────────────────────────────

func _update_profile_screen() -> void:
	if not _player_profile:
		return
	var profile := _find_screen("profile")
	if profile is ProfileScreen:
		(profile as ProfileScreen).load_profile(_player_profile)
