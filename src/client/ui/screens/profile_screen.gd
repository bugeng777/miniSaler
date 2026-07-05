## 个人资料/保险柜查看界面
## 所有权: WS5 (客户端 UI 组)
extends Control
class_name ProfileScreen

var _stats_container: VBoxContainer = null
var _safebox_container: GridContainer = null


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var title := Label.new()
	title.text = "个人档案"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	add_child(title)
	title.position.y = 30

	_stats_container = VBoxContainer.new()
	_stats_container.position = Vector2(40, 80)
	add_child(_stats_container)

	var sb_title := Label.new()
	sb_title.text = "保险柜"
	sb_title.add_theme_font_size_override("font_size", 20)
	add_child(sb_title)
	sb_title.position = Vector2(40, 300)

	_safebox_container = GridContainer.new()
	_safebox_container.columns = 3
	_safebox_container.position = Vector2(40, 340)
	add_child(_safebox_container)


func load_profile(profile: PlayerTypes.PlayerProfile) -> void:
	for child in _stats_container.get_children():
		child.queue_free()
	_add_stat("总资金", "$%d" % int(profile.total_funds))
	_add_stat("总局数", str(profile.total_games))
	_add_stat("撤离次数", str(profile.total_extractions))
	_add_stat("胜率", "%.1f%%" % (profile.get_win_rate() * 100.0))
	_add_stat("累计利润", "$%d" % int(profile.total_profit))


func _add_stat(label_text: String, value_text: String) -> void:
	var hbox := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label_text + ": "
	hbox.add_child(lbl)
	var val := Label.new()
	val.text = value_text
	hbox.add_child(val)
	_stats_container.add_child(hbox)
