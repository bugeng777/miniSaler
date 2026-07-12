## 排行榜
## 所有权: WS5 (客户端 UI 组)
extends VBoxContainer
class_name LeaderboardView


func _ready() -> void:
	var title := Label.new()
	title.text = "排行榜"
	title.add_theme_font_size_override("font_size", 16)
	add_child(title)


func update_leaderboard(players: Array[Dictionary]) -> void:
	# 删除旧行（保留标题 child[0]）
	while get_child_count() > 1:
		var child := get_child(get_child_count() - 1)
		remove_child(child)
		child.queue_free()
	# 按总资产排序
	players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.get("total_assets", 0.0) > b.get("total_assets", 0.0))
	for i in range(players.size()):
		var p: Dictionary = players[i]
		var row := Label.new()
		row.text = "#%d %s: $%.0f" % [i + 1, p.get("player_name", ""), p.get("total_assets", 0.0)]
		add_child(row)
