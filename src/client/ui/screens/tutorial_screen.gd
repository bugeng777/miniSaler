## 390×844 像素新手教程：卡片式步骤，不依赖桌面绝对坐标高亮框。
extends Control
class_name TutorialScreen

signal tutorial_completed()
signal tutorial_skipped()

enum Step { SELECT_STOCK, BUY_STOCK, WATCH_NEWS, EXTRACT, COMPLETE }

const STEP_COUNT := 4
const STEP_DATA: Dictionary = {
	Step.SELECT_STOCK: {"title": "第一步：选择股票", "body": "在股票横条中选择目标。\n每只股票显示实时报价，选择后 K 线会立即切换。", "art": "[MNTK] [BIOZ] [GOLX]\n   ▴ SELECT"},
	Step.BUY_STOCK: {"title": "第二步：提交订单", "body": "输入数量后选择买入、卖出或做空。\n市价单立即成交，限价单会进入订单簿等待。", "art": "QTY  010\n[ BUY ] [ SELL ]"},
	Step.WATCH_NEWS: {"title": "第三步：阅读新闻", "body": "底部新闻终端会逐字推送市场消息。\n结合 K 线与情绪指数判断风险，不要只追涨。", "art": "NEWS > RATE CUT..._\nFGI  ██████░░░░"},
	Step.EXTRACT: {"title": "第四步：抓住撤离窗口", "body": "窗口开放时立即决定是否落袋为安。\n成功撤离才能永久带走利润；错过窗口可能爆仓。", "art": "!! EXTRACTION OPEN !!\n[  EXIT MARKET  ]"},
}

var _current_step: int = Step.SELECT_STOCK
var _step_indicator: Label = null
var _title_label: Label = null
var _art_label: Label = null
var _text_label: Label = null
var _next_btn: Button = null

func _ready() -> void:
	_build_ui()
	_show_step(Step.SELECT_STOCK)

func _build_ui() -> void:
	var background := ColorRect.new(); background.color = PixelTheme.BG_DARKEST; background.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(background)
	var column := VBoxContainer.new(); column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 18; column.offset_top = 28; column.offset_right = -18; column.offset_bottom = -28
	column.add_theme_constant_override("separation", 12); add_child(column)
	var heading := Label.new(); heading.text = "══ 新手交易终端 ══"; heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 22); heading.add_theme_color_override("font_color", PixelTheme.ACCENT_GOLD); column.add_child(heading)
	_step_indicator = Label.new(); _step_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _step_indicator.add_theme_color_override("font_color", PixelTheme.TEXT_SECONDARY); column.add_child(_step_indicator)
	var card := PanelContainer.new(); card.add_theme_stylebox_override("panel", PixelTheme.create_rpg_panel()); card.size_flags_vertical = Control.SIZE_EXPAND_FILL; column.add_child(card)
	var card_content := VBoxContainer.new(); card_content.alignment = BoxContainer.ALIGNMENT_CENTER; card_content.add_theme_constant_override("separation", 20); card.add_child(card_content)
	_title_label = Label.new(); _title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _title_label.add_theme_font_size_override("font_size", 21); _title_label.add_theme_color_override("font_color", PixelTheme.ACCENT_GOLD); card_content.add_child(_title_label)
	var preview := PanelContainer.new(); preview.add_theme_stylebox_override("panel", PixelTheme.create_simple_panel()); preview.custom_minimum_size = Vector2(300, 190); card_content.add_child(preview)
	_art_label = Label.new(); _art_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _art_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; _art_label.add_theme_font_size_override("font_size", 18); _art_label.add_theme_color_override("font_color", PixelTheme.COLOR_UP); preview.add_child(_art_label)
	_text_label = Label.new(); _text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _text_label.custom_minimum_size = Vector2(300, 120); _text_label.add_theme_font_size_override("font_size", 16); card_content.add_child(_text_label)
	var buttons := HBoxContainer.new(); buttons.alignment = BoxContainer.ALIGNMENT_CENTER; buttons.add_theme_constant_override("separation", 10); column.add_child(buttons)
	var skip := Button.new(); skip.text = "跳过"; skip.custom_minimum_size = Vector2(110, 44); skip.pressed.connect(_on_skip); buttons.add_child(skip)
	_next_btn = Button.new(); _next_btn.text = "下一步 ▸"; _next_btn.custom_minimum_size = Vector2(160, 44); _next_btn.pressed.connect(_on_next); buttons.add_child(_next_btn)

func _show_step(step: int) -> void:
	_current_step = step
	if step >= Step.COMPLETE:
		_finish(); return
	var data: Dictionary = STEP_DATA.get(step, {})
	_step_indicator.text = "STEP %02d / %02d   %s" % [step + 1, STEP_COUNT, "■".repeat(step + 1) + "□".repeat(STEP_COUNT - step - 1)]
	_title_label.text = data.get("title", "")
	_art_label.text = data.get("art", "")
	_text_label.text = data.get("body", "")
	_next_btn.text = "完成 ▸" if step == STEP_COUNT - 1 else "下一步 ▸"

func _on_next() -> void: _show_step(_current_step + 1)
func _on_skip() -> void: tutorial_skipped.emit(); visible = false
func _finish() -> void: tutorial_completed.emit(); visible = false
func restart() -> void: visible = true; _show_step(Step.SELECT_STOCK)
static func should_show(total_games: int) -> bool: return total_games == 0
