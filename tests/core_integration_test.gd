extends SceneTree


var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error("TEST FAILED: " + message)


func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	var market := MarketEngine.new()
	var players := PlayerManager.new()
	var eras := EraManager.new()
	var extraction := ExtractionEngine.new()
	var skills := SkillSystem.new()
	var achievements := AchievementSystem.new()
	var session := GameSession.new()
	for node in [market, players, eras, extraction, skills, achievements, session]:
		host.add_child(node)
	session.market_engine = market
	session.player_manager = players
	session.era_manager = eras
	session.extraction_engine = extraction
	session.skill_system = skills
	session.connect_subsystem_signals()
	session.start_host_mode()

	players.register_player(1, "Tester", 100_000.0)
	var era := eras.get_era(&"hk_1997")
	market.start_market(era)
	await create_timer(Constants.TICK_INTERVAL + 0.1).timeout
	var symbol := StringName(era.stock_configs[0].get("symbol", ""))
	var before_cash := players.get_player_state(1).cash

	# 同一订单 ID 必须贯穿 PlayerManager -> OrderBook -> 成交回调。
	session.host_submit_order(1, symbol, GameEnums.OrderSide.BUY,
		GameEnums.OrderType.MARKET, 10)
	var state := players.get_player_state(1)
	_check(state.positions.has(symbol), "market buy did not create a position")
	_check(state.pending_orders.is_empty(), "filled market buy remained pending")
	_check(state.cash < before_cash, "market buy did not debit cash")

	# 卖出不能超过可用持仓，且拒单不能进入订单簿。
	var filled_before := state.filled_orders.size()
	session.host_submit_order(1, symbol, GameEnums.OrderSide.SELL,
		GameEnums.OrderType.MARKET, 11)
	_check(state.filled_orders.size() == filled_before,
		"oversell was incorrectly filled")
	session.host_submit_order(1, symbol, GameEnums.OrderSide.SELL,
		GameEnums.OrderType.MARKET, 10)
	_check(not state.positions.has(symbol), "valid sell did not close the position")

	# 做空所得已在 cash 中，资产公式只能再计入回补负债。
	var equity_before_short := state.get_total_assets(players._current_prices)
	session.host_submit_order(1, symbol, GameEnums.OrderSide.SHORT,
		GameEnums.OrderType.MARKET, 5)
	var equity_after_short := state.get_total_assets(players._current_prices)
	_check(equity_after_short <= equity_before_short + 0.01,
		"short proceeds were counted twice in total assets")
	_check(state.positions[symbol].is_short, "short order did not create short position")
	session.host_submit_order(1, symbol, GameEnums.OrderSide.BUY,
		GameEnums.OrderType.MARKET, 5)
	_check(not state.positions.has(symbol), "buy did not cover short position")

	# 撮合必须同时结算主动单和订单簿中的被动单。
	players.register_player(2, "Maker", 100_000.0)
	session.host_submit_order(2, symbol, GameEnums.OrderSide.BUY,
		GameEnums.OrderType.MARKET, 10)
	var maker_state := players.get_player_state(2)
	var limit_price: float = players._current_prices[symbol] + 1.0
	session.host_submit_order(2, symbol, GameEnums.OrderSide.SELL,
		GameEnums.OrderType.LIMIT, 10, limit_price)
	_check(maker_state.pending_orders.size() == 1, "resting limit order was not queued")
	session.host_submit_order(1, symbol, GameEnums.OrderSide.BUY,
		GameEnums.OrderType.LIMIT, 10, limit_price)
	_check(not maker_state.positions.has(symbol),
		"resting side of matched limit order was not settled")
	_check(maker_state.pending_orders.is_empty(),
		"filled resting limit order remained pending")

	# 被动技能必须经 GameSession 落到服务端修改器，而非只显示 UI 提示。
	skills.equip_skills(1, [&"cash_is_king", &"safe_harbor"])
	var cash_before_interest := state.cash
	players.apply_tick_modifiers(1.0)
	_check(state.cash > cash_before_interest, "cash-is-king passive had no server effect")
	extraction.start(era.extraction_config)
	extraction.trigger_conditional_window()
	_check(extraction.get_window_remaining() >= era.extraction_config.duration + 10.0,
		"safe-harbor passive did not extend extraction window")

	var profile := PlayerTypes.PlayerProfile.new()
	var funds_before_reward := profile.total_funds
	_check(achievements.grant_reward(1, profile, &"first_extraction"),
		"achievement reward could not be granted")
	_check(profile.total_funds == funds_before_reward + 5000.0,
		"fund achievement reward did not update profile")

	market.stop_market()
	host.queue_free()
	if _failures.is_empty():
		print("CORE_INTEGRATION_TEST: PASS")
		quit(0)
	else:
		print("CORE_INTEGRATION_TEST: FAIL (%d)" % _failures.size())
		quit(1)
