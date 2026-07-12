## 像素竖屏结算界面。
extends Control
class_name SettlementScreen

signal play_again_pressed()

var _result_panel: PanelContainer = null
var _result_label: Label = null
var _profit_label: Label = null
var _rank_label: Label = null
var _leaderboard_container: VBoxContainer = null

func _ready() -> void:
	var column := VBoxContainer.new(); column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 18; column.offset_top = 28; column.offset_right = -18; column.offset_bottom = -28
	column.add_theme_constant_override("separation", 12); add_child(column)
	var title := Label.new(); title.text = "══ 本局战报 ══"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24); title.add_theme_color_override("font_color", PixelTheme.ACCENT_GOLD); column.add_child(title)
	_result_panel = PanelContainer.new(); _result_panel.add_theme_stylebox_override("panel", PixelTheme.create_highlight_panel()); column.add_child(_result_panel)
	var result_box := VBoxContainer.new(); result_box.alignment = BoxContainer.ALIGNMENT_CENTER; _result_panel.add_child(result_box)
	_result_label = Label.new(); _result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _result_label.add_theme_font_size_override("font_size", 24); result_box.add_child(_result_label)
	_profit_label = Label.new(); _profit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _profit_label.add_theme_font_size_override("font_size", 30); result_box.add_child(_profit_label)
	_rank_label = Label.new(); _rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; result_box.add_child(_rank_label)
	var ranking_panel := PanelContainer.new(); ranking_panel.add_theme_stylebox_override("panel", PixelTheme.create_simple_panel()); ranking_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL; column.add_child(ranking_panel)
	var scroll := ScrollContainer.new(); ranking_panel.add_child(scroll); _leaderboard_container = VBoxContainer.new(); _leaderboard_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(_leaderboard_container)
	var button := Button.new(); button.text = "▸ 返回主菜单"; button.custom_minimum_size = Vector2(0, 48); button.pressed.connect(func(): play_again_pressed.emit()); column.add_child(button)

func show_result(data: Dictionary) -> void:
	var extracted: bool = data.get("extracted", false)
	_result_label.text = "撤 离 成 功" if extracted else "爆 仓 / 未 撤 离"
	_result_panel.add_theme_stylebox_override("panel", PixelTheme.create_highlight_panel() if extracted else PixelTheme.create_warning_panel())
	var profit: float = data.get("profit", 0.0)
	_profit_label.text = "%s$%d" % ["+" if profit >= 0 else "", int(profit)]
	_profit_label.add_theme_color_override("font_color", PixelTheme.COLOR_UP if profit >= 0 else PixelTheme.COLOR_DOWN)
	var rank_points: int = data.get("rank_points", 0); var rank_delta: int = data.get("rank_delta", 0)
	_rank_label.text = "段位积分 %d  (%s%d)" % [rank_points, "+" if rank_delta >= 0 else "", rank_delta]
	_populate_leaderboard(data.get("players", []))

func _populate_leaderboard(players: Array) -> void:
	for child in _leaderboard_container.get_children(): child.queue_free()
	var header := Label.new(); header.text = "排行榜"; header.add_theme_color_override("font_color", PixelTheme.ACCENT_GOLD); _leaderboard_container.add_child(header)
	var sorted_players := players.duplicate(); sorted_players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.get("total_assets", 0.0) > b.get("total_assets", 0.0))
	for i in range(sorted_players.size()):
		var player: Dictionary = sorted_players[i]; var row := Label.new()
		var status := "[OUT]" if player.get("extraction_result", 0) == GameEnums.ExtractionResult.SUCCESS else "[--]"
		row.text = "#%d %s %-10s $%.0f" % [i + 1, status, player.get("player_name", "Unknown"), player.get("total_assets", 0.0)]
		_leaderboard_container.add_child(row)
