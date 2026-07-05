## 结算界面
## 所有权: WS5 (客户端 UI 组)
extends Control
class_name SettlementScreen

signal play_again_pressed()

var _result_label: Label = null
var _profit_label: Label = null
var _rank_label: Label = null
var _leaderboard_container: VBoxContainer = null


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var title := Label.new()
	title.text = "本局结算"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	add_child(title)
	title.position.y = 40

	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.add_theme_font_size_override("font_size", 24)
	add_child(_result_label)
	_result_label.position = Vector2(200, 100)

	_profit_label = Label.new()
	_profit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_profit_label)
	_profit_label.position = Vector2(200, 150)

	_rank_label = Label.new()
	_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_rank_label)
	_rank_label.position = Vector2(200, 190)

	_leaderboard_container = VBoxContainer.new()
	_leaderboard_container.position = Vector2(100, 250)
	_leaderboard_container.custom_minimum_size = Vector2(500, 300)
	add_child(_leaderboard_container)

	var btn := Button.new()
	btn.text = "再来一局"
	btn.custom_minimum_size = Vector2(200, 50)
	btn.position = Vector2(260, 580)
	btn.pressed.connect(func() -> void: play_again_pressed.emit())
	add_child(btn)


func show_result(data: Dictionary) -> void:
	var extracted: bool = data.get("extracted", false)
	_result_label.text = "撤离成功!" if extracted else "爆仓/未撤离"
	var profit: float = data.get("profit", 0.0)
	_profit_label.text = "本局利润: $%d" % int(profit)
	_profit_label.add_theme_color_override("font_color",
		Color.GREEN if profit >= 0 else Color.RED)
	var rank_pts: int = data.get("rank_points", 0)
	var rank_d: int = data.get("rank_delta", 0)
	var sign_str := "+" if rank_d >= 0 else ""
	_rank_label.text = "段位积分: %d (%s%d)" % [rank_pts, sign_str, rank_d]
	# 排行榜
	_populate_leaderboard(data.get("players", []))


func _populate_leaderboard(players: Array) -> void:
	# 清除旧条目
	for child in _leaderboard_container.get_children():
		child.queue_free()
	# 标题
	var header := Label.new()
	header.text = "排行榜"
	header.add_theme_font_size_override("font_size", 18)
	_leaderboard_container.add_child(header)
	# 按总资产排序
	var sorted_players: Array = players.duplicate()
	sorted_players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("total_assets", 0.0) > b.get("total_assets", 0.0))
	for i in range(sorted_players.size()):
		var p: Dictionary = sorted_players[i]
		var row := Label.new()
		var name: String = p.get("player_name", "Unknown")
		var assets: float = p.get("total_assets", 0.0)
		var result: int = p.get("extraction_result", 0)
		var result_str := "✓" if result == GameEnums.ExtractionResult.SUCCESS else "✗"
		row.text = "#%d %s %s: $%.0f" % [i + 1, result_str, name, assets]
		_leaderboard_container.add_child(row)
