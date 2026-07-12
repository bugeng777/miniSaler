## Pixel Street 主菜单。
extends Control
class_name MainMenuScreen


signal menu_item_selected(item: StringName)

var _funds_label: Label = null
var _start_button: Button = null
var _blink_timer: Timer = null
var _cursor_visible: bool = true


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = PixelTheme.BG_DARKEST
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	add_child(margin)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", PixelTheme.create_rpg_panel(PixelTheme.ACCENT_BLUE))
	margin.add_child(panel)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)

	var logo := Label.new()
	logo.text = "MINI\nWALL STREET"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_font_size_override("font_size", 28)
	logo.add_theme_color_override("font_color", PixelTheme.ACCENT_GOLD)
	content.add_child(logo)
	var subtitle := Label.new()
	subtitle.text = "- PIXEL MARKET RAID -"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", PixelTheme.TEXT_SECONDARY)
	content.add_child(subtitle)
	content.add_child(_build_skyline())

	var menu_panel := PanelContainer.new()
	menu_panel.add_theme_stylebox_override("panel", PixelTheme.create_simple_panel())
	menu_panel.custom_minimum_size = Vector2(280, 0)
	content.add_child(menu_panel)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 5)
	menu_panel.add_child(menu)
	_start_button = _add_menu_button(menu, "开始交易", &"start")
	_add_menu_button(menu, "保险柜", &"safe_box")
	_add_menu_button(menu, "技能库", &"skills")
	_add_menu_button(menu, "成就墙", &"achievements")
	_add_menu_button(menu, "个人主页", &"profile")
	_add_menu_button(menu, "设置", &"settings")

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 28)
	content.add_child(footer)
	var version := Label.new()
	version.text = "v0.1"
	version.add_theme_color_override("font_color", PixelTheme.TEXT_DIM)
	footer.add_child(version)
	_funds_label = Label.new()
	_funds_label.add_theme_color_override("font_color", PixelTheme.ACCENT_GOLD)
	footer.add_child(_funds_label)

	_blink_timer = Timer.new()
	_blink_timer.wait_time = 0.5
	_blink_timer.timeout.connect(_blink_cursor)
	add_child(_blink_timer)
	_blink_timer.start()


func set_total_funds(funds: float) -> void:
	if _funds_label:
		_funds_label.text = "$%s" % _format_money(funds)


func _add_menu_button(parent: VBoxContainer, label: String, item: StringName) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(250, 38)
	button.pressed.connect(func() -> void: menu_item_selected.emit(item))
	parent.add_child(button)
	return button


func _build_skyline() -> Control:
	var skyline := Control.new()
	skyline.custom_minimum_size = Vector2(280, 100)
	var buildings := [
		Rect2(8, 55, 34, 42), Rect2(48, 34, 28, 63), Rect2(82, 62, 42, 35),
		Rect2(130, 22, 36, 75), Rect2(172, 47, 30, 50), Rect2(208, 29, 58, 68),
	]
	for rect in buildings:
		var building := ColorRect.new()
		building.position = rect.position
		building.size = rect.size
		building.color = PixelTheme.TEXT_DIM
		skyline.add_child(building)
		for wy in range(int(rect.position.y + 8), int(rect.end.y - 5), 12):
			for wx in range(int(rect.position.x + 6), int(rect.end.x - 4), 10):
				var window := ColorRect.new()
				window.position = Vector2(wx, wy)
				window.size = Vector2(3, 5)
				window.color = PixelTheme.ACCENT_GOLD if (wx + wy) % 3 else PixelTheme.ACCENT_BLUE
				skyline.add_child(window)
	return skyline


func _blink_cursor() -> void:
	_cursor_visible = not _cursor_visible
	if _start_button:
		_start_button.text = ("▸ " if _cursor_visible else "  ") + "开始交易"


func _format_money(value: float) -> String:
	return "%.1fM" % (value / 1_000_000.0) if value >= 1_000_000.0 else "%.0fK" % (value / 1_000.0)
