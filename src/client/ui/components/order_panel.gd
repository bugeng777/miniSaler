## 买卖交易面板
## 所有权: WS5 (客户端 UI 组)
extends PanelContainer
class_name OrderPanel

signal order_requested(symbol: StringName, side: int, order_type: int, quantity: int, limit_price: float)

var _buy_btn: Button = null
var _sell_btn: Button = null
var _short_btn: Button = null
var _qty_spinbox: SpinBox = null
var _price_spinbox: SpinBox = null
var _limit_check: CheckBox = null


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	add_theme_stylebox_override("panel", PixelTheme.create_rpg_panel())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	var inputs := HBoxContainer.new()
	inputs.add_theme_constant_override("separation", 4)
	column.add_child(inputs)

	_qty_spinbox = SpinBox.new()
	_qty_spinbox.min_value = 1
	_qty_spinbox.max_value = 10000
	_qty_spinbox.value = 10
	_qty_spinbox.custom_minimum_size = Vector2(78, 32)
	_qty_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inputs.add_child(_qty_spinbox)

	_limit_check = CheckBox.new()
	_limit_check.text = "限价"
	inputs.add_child(_limit_check)

	_price_spinbox = SpinBox.new()
	_price_spinbox.min_value = 0.01
	_price_spinbox.max_value = 9999.0
	_price_spinbox.value = 100.0
	_price_spinbox.custom_minimum_size = Vector2(86, 32)
	_price_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inputs.add_child(_price_spinbox)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	column.add_child(actions)

	_buy_btn = Button.new()
	_buy_btn.text = "买入"
	_buy_btn.custom_minimum_size = Vector2(0, 40)
	_buy_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buy_btn.pressed.connect(func() -> void:
		_emit_order(GameEnums.OrderSide.BUY))
	actions.add_child(_buy_btn)

	_sell_btn = Button.new()
	_sell_btn.text = "卖出"
	_sell_btn.custom_minimum_size = Vector2(0, 40)
	_sell_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_btn.pressed.connect(func() -> void:
		_emit_order(GameEnums.OrderSide.SELL))
	actions.add_child(_sell_btn)

	_short_btn = Button.new()
	_short_btn.text = "做空"
	_short_btn.custom_minimum_size = Vector2(0, 40)
	_short_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_short_btn.pressed.connect(func() -> void:
		_emit_order(GameEnums.OrderSide.SHORT))
	actions.add_child(_short_btn)


func _emit_order(side: int) -> void:
	var otype := GameEnums.OrderType.LIMIT if _limit_check.button_pressed else GameEnums.OrderType.MARKET
	order_requested.emit(&"", side, otype, int(_qty_spinbox.value), _price_spinbox.value)
