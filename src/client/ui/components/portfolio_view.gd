## 持仓展示
## 所有权: WS5 (客户端 UI 组)
extends VBoxContainer
class_name PortfolioView


func _ready() -> void:
	var title := Label.new()
	title.text = "持仓"
	title.add_theme_font_size_override("font_size", 16)
	add_child(title)


func update_positions(positions: Array) -> void:
	# 清除旧的持仓条目（保留标题）
	while get_child_count() > 1:
		get_child(1).queue_free()
	for pos in positions:
		var row := HBoxContainer.new()
		var sym_label := Label.new()
		sym_label.text = str(pos.get("symbol", ""))
		row.add_child(sym_label)
		var qty_label := Label.new()
		qty_label.text = "x%d" % pos.get("quantity", 0)
		row.add_child(qty_label)
		var pnl_label := Label.new()
		var pnl: float = pos.get("unrealized_pnl", 0.0)
		pnl_label.text = "$%.0f" % pnl
		pnl_label.add_theme_color_override("font_color",
			Color.GREEN if pnl >= 0 else Color.RED)
		row.add_child(pnl_label)
		add_child(row)
