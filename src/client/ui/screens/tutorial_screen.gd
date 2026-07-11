## 新手引导屏幕
## 所有权: WS5 (客户端 UI 组)
## 首次进入触发（total_games == 0），分步高亮引导，可跳过
extends Control
class_name TutorialScreen

signal tutorial_completed()
signal tutorial_skipped()

## 引导步骤定义
enum Step {
	SELECT_STOCK,    ## 选股
	BUY_STOCK,       ## 买入
	WATCH_NEWS,      ## 看新闻
	EXTRACT,         ## 撤离
	COMPLETE,        ## 完成
}

var _current_step: int = Step.SELECT_STOCK
var _overlay: ColorRect = null          ## 半透明遮罩
var _highlight_rect: ColorRect = null   ## 高亮框
var _text_label: Label = null           ## 步骤说明文字
var _next_btn: Button = null            ## 下一步按钮
var _skip_btn: Button = null            ## 跳过按钮
var _step_indicator: Label = null       ## 步骤指示器

## 每个步骤的引导文本
const STEP_TEXTS: Dictionary = {
	Step.SELECT_STOCK: "第一步：选择股票\n\n在左侧股票列表中，点击你想交易的股票。\n每只股票显示当前价格，选中后 K 线图会切换到该股票。",
	Step.BUY_STOCK: "第二步：买入股票\n\n在交易面板中输入数量，点击【买入】按钮。\n你可以使用快捷按钮快速选择数量，或设置限价单。",
	Step.WATCH_NEWS: "第三步：关注新闻\n\n底部新闻栏会实时推送市场消息。\n利好消息推动股价上涨，利空消息导致下跌。\n根据新闻判断买卖时机！",
	Step.EXTRACT: "第四步：撤离提现\n\n当撤离窗口开放时，点击【撤离】按钮。\n所有持仓会以当前市价平仓，利润永久入账。\n注意：窗口不是随时开放的，要抓住时机！",
}

const STEP_COUNT: int = 4


func _ready() -> void:
	_build_ui()
	_show_step(Step.SELECT_STOCK)


func _build_ui() -> void:
	# 半透明遮罩（覆盖全屏）
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	add_child(_overlay)

	# 高亮框（模拟目标区域高亮）
	_highlight_rect = ColorRect.new()
	_highlight_rect.color = Color(0.0, 0.7, 0.5, 0.15)
	_highlight_rect.custom_minimum_size = Vector2(200, 100)
	_highlight_rect.position = Vector2(100, 200)
	add_child(_highlight_rect)

	# 高亮框边框
	var border := ReferenceRect.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.border_color = Color(0.0, 0.9, 0.5)
	border.border_width = 2.0
	border.editor_only = false
	_highlight_rect.add_child(border)

	# 引导内容面板
	var content_panel := VBoxContainer.new()
	content_panel.position = Vector2(200, 400)
	content_panel.custom_minimum_size = Vector2(450, 250)
	add_child(content_panel)

	# 步骤指示器
	_step_indicator = Label.new()
	_step_indicator.add_theme_font_size_override("font_size", 14)
	_step_indicator.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	content_panel.add_child(_step_indicator)

	# 引导说明文字
	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(430, 120)
	_text_label.add_theme_font_size_override("font_size", 18)
	_text_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	content_panel.add_child(_text_label)

	# 按钮行
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	content_panel.add_child(btn_row)

	# 跳过按钮
	_skip_btn = Button.new()
	_skip_btn.text = "跳过引导"
	_skip_btn.custom_minimum_size = Vector2(100, 40)
	_skip_btn.pressed.connect(_on_skip)
	btn_row.add_child(_skip_btn)

	# 下一步按钮
	_next_btn = Button.new()
	_next_btn.text = "下一步"
	_next_btn.custom_minimum_size = Vector2(120, 40)
	_next_btn.pressed.connect(_on_next)
	btn_row.add_child(_next_btn)


## 显示指定步骤
func _show_step(step: int) -> void:
	_current_step = step
	if step >= Step.COMPLETE:
		_finish()
		return

	# 更新步骤指示器
	_step_indicator.text = "步骤 %d / %d" % [step + 1, STEP_COUNT]

	# 更新说明文字
	_text_label.text = STEP_TEXTS.get(step, "")

	# 移动高亮框到目标区域
	match step:
		Step.SELECT_STOCK:
			_highlight_rect.position = Vector2(10, 80)
			_highlight_rect.size = Vector2(160, 400)
		Step.BUY_STOCK:
			_highlight_rect.position = Vector2(180, 420)
			_highlight_rect.size = Vector2(400, 120)
		Step.WATCH_NEWS:
			_highlight_rect.position = Vector2(0, 560)
			_highlight_rect.size = Vector2(800, 40)
		Step.EXTRACT:
			_highlight_rect.position = Vector2(500, 480)
			_highlight_rect.size = Vector2(170, 80)

	# 最后一步显示"完成"
	if step == STEP_COUNT - 1:
		_next_btn.text = "完成"
	else:
		_next_btn.text = "下一步"


## 下一步
func _on_next() -> void:
	_show_step(_current_step + 1)


## 跳过
func _on_skip() -> void:
	tutorial_skipped.emit()
	_hide()


## 完成
func _finish() -> void:
	tutorial_completed.emit()
	_hide()


## 隐藏引导
func _hide() -> void:
	visible = false


## 重新显示（从设置中重新触发）
func restart() -> void:
	_show_step(Step.SELECT_STOCK)
	visible = true


## 判断是否应该显示新手引导
static func should_show(total_games: int) -> bool:
	return total_games == 0
