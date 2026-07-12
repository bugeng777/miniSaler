extends Control
class_name SettingsScreen

signal back_requested()

func _ready() -> void:
	var box := VBoxContainer.new(); box.set_anchors_preset(Control.PRESET_FULL_RECT); box.offset_left = 24; box.offset_top = 40; box.offset_right = -24; box.offset_bottom = -40; box.add_theme_constant_override("separation", 14); add_child(box)
	var title := Label.new(); title.text = "设置"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", 24); title.add_theme_color_override("font_color", PixelTheme.ACCENT_GOLD); box.add_child(title)
	var panel := PanelContainer.new(); panel.add_theme_stylebox_override("panel", PixelTheme.create_rpg_panel()); panel.size_flags_vertical = Control.SIZE_EXPAND_FILL; box.add_child(panel)
	var options := VBoxContainer.new(); options.add_theme_constant_override("separation", 14); panel.add_child(options)
	_add_slider(options, "主音量", 80); _add_slider(options, "音效", 90)
	var pixel_label := Label.new(); pixel_label.text = "画质: PIXEL PERFECT\n纹理过滤: NEAREST\n语言: 简体中文"; pixel_label.add_theme_color_override("font_color", PixelTheme.TEXT_SECONDARY); options.add_child(pixel_label)
	var back := Button.new(); back.text = "◀ 返回"; back.pressed.connect(func(): back_requested.emit()); box.add_child(back)

func _add_slider(parent: VBoxContainer, label_text: String, value: float) -> void:
	var label := Label.new(); label.text = label_text; parent.add_child(label)
	var slider := HSlider.new(); slider.min_value = 0; slider.max_value = 100; slider.step = 10; slider.value = value; parent.add_child(slider)
