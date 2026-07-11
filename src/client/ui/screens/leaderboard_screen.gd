## 排行榜屏幕（全局/赛季排行）
## 所有权: WS5 (客户端 UI 组)
## 支持按利润/胜率/段位切换排序维度
extends Control
class_name LeaderboardScreen

signal sort_changed(sort_key: StringName)

## 排序维度
enum SortKey { PROFIT, WIN_RATE, RANK_TIER, TOTAL_EXTRACTIONS }

var _current_sort: int = SortKey.PROFIT
var _table_container: VBoxContainer = null
var _sort_buttons: Dictionary = {}  ## SortKey -> Button
var _header_row: HBoxContainer = null
var _rows_container: VBoxContainer = null
var _title_label: Label = null


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 12)
	add_child(main_vbox)

	# 标题
	_title_label = Label.new()
	_title_label.text = "排行榜"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 28)
	main_vbox.add_child(_title_label)

	# 排序按钮行
	var sort_row := HBoxContainer.new()
	sort_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sort_row.add_theme_constant_override("separation", 8)
	main_vbox.add_child(sort_row)

	var sort_options: Array[Dictionary] = [
		{"key": SortKey.PROFIT, "label": "利润"},
		{"key": SortKey.WIN_RATE, "label": "胜率"},
		{"key": SortKey.RANK_TIER, "label": "段位"},
		{"key": SortKey.TOTAL_EXTRACTIONS, "label": "撤离次数"},
	]
	for opt in sort_options:
		var btn := Button.new()
		btn.text = opt["label"]
		btn.custom_minimum_size = Vector2(90, 35)
		var key: int = opt["key"]
		btn.pressed.connect(func() -> void: _on_sort_changed(key))
		sort_row.add_child(btn)
		_sort_buttons[key] = btn

	# 表头
	_header_row = HBoxContainer.new()
	_header_row.add_theme_constant_override("separation", 4)
	main_vbox.add_child(_header_row)
	for header_text in ["#", "玩家", "数值", "段位"]:
		var label := Label.new()
		label.text = header_text
		label.custom_minimum_size = Vector2(100, 30)
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_header_row.add_child(label)

	# 分割线
	var sep := HSeparator.new()
	main_vbox.add_child(sep)

	# 排行数据容器
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)
	_rows_container = VBoxContainer.new()
	_rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows_container)

	# 初始高亮
	_update_sort_highlight()


## 切换排序维度
func _on_sort_changed(key: int) -> void:
	_current_sort = key
	_update_sort_highlight()
	var key_name := _sort_key_to_name(key)
	sort_changed.emit(key_name)


## 更新排序按钮高亮
func _update_sort_highlight() -> void:
	for key in _sort_buttons:
		var btn: Button = _sort_buttons[key]
		if key == _current_sort:
			btn.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
		else:
			btn.remove_theme_color_override("font_color")


## 加载排行数据（由外部调用，传入排序后的玩家列表）
func load_leaderboard_data(players: Array[Dictionary]) -> void:
	# 清除旧行
	for child in _rows_container.get_children():
		child.queue_free()

	for i in range(players.size()):
		var p: Dictionary = players[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_rows_container.add_child(row)

		# 排名
		var rank_label := Label.new()
		rank_label.text = str(i + 1)
		rank_label.custom_minimum_size = Vector2(100, 25)
		if i < 3:
			rank_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		row.add_child(rank_label)

		# 玩家名
		var name_label := Label.new()
		name_label.text = p.get("player_name", "Unknown")
		name_label.custom_minimum_size = Vector2(100, 25)
		row.add_child(name_label)

		# 数值（根据排序维度显示不同字段）
		var value_label := Label.new()
		value_label.custom_minimum_size = Vector2(100, 25)
		match _current_sort:
			SortKey.PROFIT:
				value_label.text = "$%.0f" % p.get("total_profit", 0.0)
			SortKey.WIN_RATE:
				value_label.text = "%.1f%%" % (p.get("win_rate", 0.0) * 100.0)
			SortKey.RANK_TIER:
				value_label.text = _tier_name(p.get("rank_tier", 0))
			SortKey.TOTAL_EXTRACTIONS:
				value_label.text = str(p.get("total_extractions", 0))
		row.add_child(value_label)

		# 段位
		var tier_label := Label.new()
		tier_label.text = _tier_name(p.get("rank_tier", 0))
		tier_label.custom_minimum_size = Vector2(100, 25)
		row.add_child(tier_label)


## 段位名称映射
func _tier_name(tier: int) -> String:
	match tier:
		GameEnums.RankTier.BRONZE: return "青铜"
		GameEnums.RankTier.SILVER: return "白银"
		GameEnums.RankTier.GOLD: return "黄金"
		GameEnums.RankTier.PLATINUM: return "铂金"
		GameEnums.RankTier.DIAMOND: return "钻石"
		GameEnums.RankTier.LEGEND: return "传奇"
		_: return "未知"


## 排序键转名称
func _sort_key_to_name(key: int) -> StringName:
	match key:
		SortKey.PROFIT: return &"profit"
		SortKey.WIN_RATE: return &"win_rate"
		SortKey.RANK_TIER: return &"rank_tier"
		SortKey.TOTAL_EXTRACTIONS: return &"total_extractions"
		_: return &"profit"
