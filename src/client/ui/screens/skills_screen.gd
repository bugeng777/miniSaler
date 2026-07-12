extends Control
class_name SkillsScreen

signal back_requested()

var _list: VBoxContainer = null

func _ready() -> void:
	_build("技能库")

func _build(title_text: String) -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 18; box.offset_top = 24; box.offset_right = -18; box.offset_bottom = -24
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var title := Label.new(); title.text = title_text; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24); title.add_theme_color_override("font_color", PixelTheme.ACCENT_GOLD); box.add_child(title)
	var panel := PanelContainer.new(); panel.add_theme_stylebox_override("panel", PixelTheme.create_rpg_panel()); panel.size_flags_vertical = Control.SIZE_EXPAND_FILL; box.add_child(panel)
	var scroll := ScrollContainer.new(); panel.add_child(scroll); _list = VBoxContainer.new(); _list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(_list)
	var back := Button.new(); back.text = "◀ 返回"; back.pressed.connect(func(): back_requested.emit()); box.add_child(back)

func load_profile(profile: PlayerTypes.PlayerProfile) -> void:
	if not _list: return
	for child in _list.get_children(): child.queue_free()
	for raw in SkillTypes.ALL_SKILLS:
		var id := StringName(raw.get("skill_id", "")); var unlocked := profile.unlocked_skills.has(id)
		var row := Label.new(); row.text = ("[已解锁] " if unlocked else "[LOCKED] ") + raw.get("display_name", "") + "\n  " + raw.get("description", "")
		row.add_theme_color_override("font_color", PixelTheme.TEXT_PRIMARY if unlocked else PixelTheme.TEXT_DIM); _list.add_child(row)
