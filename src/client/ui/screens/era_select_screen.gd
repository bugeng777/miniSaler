## 时代选择屏幕
## 所有权: WS5 (客户端 UI 组)
extends Control
class_name EraSelectScreen

signal era_selected(era_id: StringName)

var _era_buttons: Dictionary = {}  ## era_id -> Button


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var title := Label.new()
	title.text = "选择时代"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	add_child(title)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.position.y = 40

	var container := GridContainer.new()
	container.columns = 3
	container.position = Vector2(80, 120)
	container.size = Vector2(560, 400)
	add_child(container)


## 加载时代数据（由 main.gd 调用）
func load_eras(eras: Array[EraData], unlocked_ids: Array[StringName]) -> void:
	# 清除旧按钮（重玩时）
	var grid := get_child(1) as GridContainer
	if grid:
		for child in grid.get_children():
			child.queue_free()
	_era_buttons.clear()
	# 创建新按钮
	for era in eras:
		var btn := Button.new()
		btn.text = "%s\n%d\n难度: %s" % [era.display_name, era.year, "★".repeat(era.difficulty)]
		btn.custom_minimum_size = Vector2(170, 120)
		var is_unlocked := unlocked_ids.has(era.era_id)
		btn.disabled = not is_unlocked
		var eid := era.era_id
		btn.pressed.connect(func() -> void: era_selected.emit(eid))
		_era_buttons[era.era_id] = btn
		if grid:
			grid.add_child(btn)
