## 时代选择屏幕
## 所有权: WS5 (客户端 UI 组)
extends Control
class_name EraSelectScreen

signal era_selected(era_id: StringName)
signal back_requested()

var _era_buttons: Dictionary = {}  ## era_id -> Button
var _era_container: VBoxContainer = null


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = PixelTheme.BG_DARKEST
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 18
	column.offset_top = 24
	column.offset_right = -18
	column.offset_bottom = -24
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	var title := Label.new()
	title.text = "◀ 选择时代"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", PixelTheme.ACCENT_GOLD)
	column.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_era_container = VBoxContainer.new()
	_era_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_era_container.add_theme_constant_override("separation", 8)
	scroll.add_child(_era_container)
	var back := Button.new()
	back.text = "◀ 返回主菜单"
	back.pressed.connect(func(): back_requested.emit())
	column.add_child(back)


## 加载时代数据（由 main.gd 调用）
func load_eras(eras: Array[EraData], unlocked_ids: Array[StringName]) -> void:
	# 清除旧按钮（重玩时）
	if _era_container:
		for child in _era_container.get_children():
			child.queue_free()
	_era_buttons.clear()
	# 创建新按钮
	for era in eras:
		var btn := Button.new()
		btn.text = "%s\n%d\n难度: %s" % [era.display_name, era.year, "★".repeat(era.difficulty)]
		btn.custom_minimum_size = Vector2(0, 92)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var is_unlocked := unlocked_ids.has(era.era_id)
		btn.disabled = not is_unlocked
		var eid := era.era_id
		btn.pressed.connect(func() -> void: era_selected.emit(eid))
		_era_buttons[era.era_id] = btn
		if is_unlocked:
			btn.add_theme_stylebox_override("normal", PixelTheme.create_simple_panel())
		else:
			btn.text = "[LOCKED]\n" + btn.text
			btn.add_theme_color_override("font_disabled_color", PixelTheme.TEXT_DIM)
		if _era_container:
			_era_container.add_child(btn)
