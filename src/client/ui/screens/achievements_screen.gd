extends Control
class_name AchievementsScreen

signal back_requested()
var _list: VBoxContainer = null

func _ready() -> void:
	var box := VBoxContainer.new(); box.set_anchors_preset(Control.PRESET_FULL_RECT); box.offset_left = 18; box.offset_top = 24; box.offset_right = -18; box.offset_bottom = -24; add_child(box)
	var title := Label.new(); title.text = "成就墙"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", 24); title.add_theme_color_override("font_color", PixelTheme.ACCENT_GOLD); box.add_child(title)
	var panel := PanelContainer.new(); panel.add_theme_stylebox_override("panel", PixelTheme.create_highlight_panel()); panel.size_flags_vertical = Control.SIZE_EXPAND_FILL; box.add_child(panel)
	var scroll := ScrollContainer.new(); panel.add_child(scroll); _list = VBoxContainer.new(); _list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(_list)
	var back := Button.new(); back.text = "◀ 返回"; back.pressed.connect(func(): back_requested.emit()); box.add_child(back)

func load_data(profile: PlayerTypes.PlayerProfile, definitions: Dictionary) -> void:
	if not _list: return
	for child in _list.get_children(): child.queue_free()
	for id in definitions:
		var definition = definitions[id]; var unlocked := profile.achievements.has(id)
		var row := HBoxContainer.new(); var icon := PixelIcon.new(); icon.icon_type = PixelIcon.Icon.TROPHY if unlocked else PixelIcon.Icon.LOCK; icon.pixel_size = 1; row.add_child(icon)
		var label := Label.new(); label.text = ("[DONE] " if unlocked else "[----] ") + definition.display_name + "\n" + definition.description; label.add_theme_color_override("font_color", PixelTheme.ACCENT_GOLD if unlocked else PixelTheme.TEXT_DIM); row.add_child(label); _list.add_child(row)
