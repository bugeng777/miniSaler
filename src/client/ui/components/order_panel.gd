## 买卖交易面板
## 所有权: WS5 (客户端 UI 组)
extends PanelContainer
class_name OrderPanel

signal order_requested(symbol: StringName, side, order_type, quantity, limit_price)
signal order_requested_with_context(symbol, side, order_type, quantity, limit_price, is_short)

var _buy_btn: Button = null
var _sell_btn: Button = null
var _short_btn: Button = null
var _qty_spinbox: SpinBox = null
var _price_spinbox: SpinBox = null
var _limit_check: CheckBox = null
var _position_label: RichTextLabel = null
var _quick_btn_container: HBoxContainer = null
var _current_symbol: StringName = &""
var _current_max_qty: int = 10000

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var main_vbox := VBoxContainer.new()
	add_child(main_vbox)
	_position_label = RichTextLabel.new()
	_position_label.bbcode_enabled = true
	_position_label.fit_content = true
	_position_label.scroll_active = false
	_position_label.text = "持仓: --"
	_position_label.add_theme_font_size_override("normal_font_size", 13)
	_position_label.custom_minimum_size = Vector2(0, 25)
	main_vbox.add_child(_position_label)
	var qty_row := HBoxContainer.new()
	main_vbox.add_child(qty_row)
	var qty_label := Label.new()
	qty_label.text = "数量:"
	qty_row.add_child(qty_label)
	_qty_spinbox = SpinBox.new()
	_qty_spinbox.min_value = 1
	_qty_spinbox.max_value = 10000
	_qty_spinbox.value = 10
	_qty_spinbox.custom_minimum_size = Vector2(100, 30)
	qty_row.add_child(_qty_spinbox)
	_quick_btn_container = HBoxContainer.new()
	qty_row.add_child(_quick_btn_container)
	for preset in [10, 50, 100]:
		var btn := Button.new()
		btn.text = str(preset)
		btn.custom_minimum_size = Vector2(45, 28)
		var val: int = preset
		btn.pressed.connect(func() -> void: _qty_spinbox.value = val)
		_quick_btn_container.add_child(btn)
	var max_btn := Button.new()
	max_btn.text = "MAX"
	max_btn.custom_minimum_size = Vector2(50, 28)
	max_btn.pressed.connect(func() -> void: _qty_spinbox.value = _current_max_qty)
	_quick_btn_container.add_child(max_btn)
	var limit_row := HBoxContainer.new()
	main_vbox.add_child(limit_row)
	_limit_check = CheckBox.new()
	_limit_check.text = "限价"
	limit_row.add_child(_limit_check)
	_price_spinbox = SpinBox.new()
	_price_spinbox.min_value = 0.01
	_price_spinbox.max_value = 9999.0
	_price_spinbox.value = 100.0
	_price_spinbox.custom_minimum_size = Vector2(100, 30)
	limit_row.add_child(_price_spinbox)
	var action_row := HBoxContainer.new()
	main_vbox.add_child(action_row)
	_buy_btn = Button.new()
	_buy_btn.text = "买入"
	_buy_btn.custom_minimum_size = Vector2(80, 30)
	_buy_btn.pressed.connect(func() -> void: _emit_order(GameEnums.OrderSide.BUY))
	action_row.add_child(_buy_btn)
	_sell_btn = Button.new()
	_sell_btn.text = "卖出"
	_sell_btn.custom_minimum_size = Vector2(80, 30)
	_sell_btn.pressed.connect(func() -> void: _emit_order(GameEnums.OrderSide.SELL))
	action_row.add_child(_sell_btn)
	_short_btn = Button.new()
	_short_btn.text = "做空"
	_short_btn.custom_minimum_size = Vector2(80, 30)
	_short_btn.pressed.connect(func() -> void: _emit_order(GameEnums.OrderSide.SHORT))
	action_row.add_child(_short_btn)

func set_position_info(quantity: int, avg_price: float, unrealized_pnl: float) -> void:
	if quantity == 0:
		_position_label.text = "持仓: 无"
	else:
		var pnl_color := "green" if unrealized_pnl >= 0 else "red"
		_position_label.text = "持仓: %d股 @ $%.2f | 浮盈: [color=%s]$%.2f[/color]" % [quantity, avg_price, pnl_color, unrealized_pnl]

func set_current_symbol(symbol: StringName, max_qty: int = 10000) -> void:
	_current_symbol = symbol
	_current_max_qty = max_qty
	_qty_spinbox.max_value = max_qty

func _emit_order(side: int) -> void:
	var otype := GameEnums.OrderType.LIMIT if _limit_check.button_pressed else GameEnums.OrderType.MARKET
	var is_short := side == GameEnums.OrderSide.SHORT
	order_requested.emit(_current_symbol, side, otype, int(_qty_spinbox.value), _price_spinbox.value)
	order_requested_with_context.emit(_current_symbol, side, otype, int(_qty_spinbox.value), _price_spinbox.value, is_short)
