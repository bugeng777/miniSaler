## 390×844 像素准备界面。
extends Control
class_name LoadoutScreen

signal loadout_confirmed(extra_funds: float, skill_ids: Array[StringName])

var _fund_slider: HSlider = null
var _fund_label: Label = null
var _skill_container: VBoxContainer = null
var _selected_skills: Array[StringName] = []
var _confirm_btn: Button = null
var _countdown_label: Label = null
var _max_slots: int = Constants.INITIAL_SKILL_SLOTS

func _ready() -> void:
	var background := ColorRect.new(); background.color = PixelTheme.BG_DARKEST; background.set_anchors_preset(Control.PRESET_FULL_RECT); add_child(background)
	var column := VBoxContainer.new(); column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 18; column.offset_top = 22; column.offset_right = -18; column.offset_bottom = -28
	column.add_theme_constant_override("separation", 10); add_child(column)
	var header := HBoxContainer.new(); column.add_child(header)
	var title := Label.new(); title.text = "══ 入局准备 ══"; title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", 23); title.add_theme_color_override("font_color", PixelTheme.ACCENT_GOLD); header.add_child(title)
	_countdown_label = Label.new(); _countdown_label.text = "30"; _countdown_label.add_theme_color_override("font_color", PixelTheme.COLOR_DOWN); header.add_child(_countdown_label)

	var fund_panel := PanelContainer.new(); fund_panel.add_theme_stylebox_override("panel", PixelTheme.create_rpg_panel()); column.add_child(fund_panel)
	var fund_box := VBoxContainer.new(); fund_box.add_theme_constant_override("separation", 8); fund_panel.add_child(fund_box)
	var fund_title := Label.new(); fund_title.text = "资金配置"; fund_title.add_theme_color_override("font_color", PixelTheme.ACCENT_GOLD); fund_box.add_child(fund_title)
	_fund_label = Label.new(); _fund_label.text = "额外带入  $0"; _fund_label.add_theme_font_size_override("font_size", 18); fund_box.add_child(_fund_label)
	_fund_slider = HSlider.new(); _fund_slider.min_value = 0; _fund_slider.max_value = Constants.MAX_EXTRA_FUNDS; _fund_slider.step = 10_000; _fund_slider.custom_minimum_size = Vector2(0, 30); fund_box.add_child(_fund_slider)
	_fund_slider.value_changed.connect(func(value: float): _fund_label.text = "额外带入  $%d" % int(value))
	var risk := Label.new(); risk.text = "风险  □□□□□□□□□□"; risk.add_theme_color_override("font_color", PixelTheme.TEXT_SECONDARY); fund_box.add_child(risk)

	var skill_panel := PanelContainer.new(); skill_panel.add_theme_stylebox_override("panel", PixelTheme.create_simple_panel()); skill_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL; column.add_child(skill_panel)
	var skill_box := VBoxContainer.new(); skill_panel.add_child(skill_box)
	var skill_title := Label.new(); skill_title.text = "技能卡  [0/%d 槽位]" % _max_slots; skill_title.add_theme_color_override("font_color", PixelTheme.ACCENT_GOLD); skill_box.add_child(skill_title)
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; skill_box.add_child(scroll)
	_skill_container = VBoxContainer.new(); _skill_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _skill_container.add_theme_constant_override("separation", 5); scroll.add_child(_skill_container)

	_confirm_btn = Button.new(); _confirm_btn.text = "▸ 入局"; _confirm_btn.custom_minimum_size = Vector2(0, 52); _confirm_btn.pressed.connect(_on_confirm); column.add_child(_confirm_btn)

func set_countdown(seconds: float) -> void:
	_countdown_label.text = "%02d" % int(seconds)

func load_skills(available_skills: Array[Dictionary]) -> void:
	_selected_skills.clear()
	for child in _skill_container.get_children(): child.queue_free()
	for skill_data in available_skills:
		var button := Button.new(); var skill_id := StringName(skill_data.get("skill_id", ""))
		button.text = "%s  [OFF]\n%s" % [skill_data.get("display_name", ""), skill_data.get("description", "")]
		button.toggle_mode = true; button.custom_minimum_size = Vector2(0, 60)
		button.pressed.connect(func():
			if button.button_pressed:
				if _selected_skills.size() < _max_slots: _selected_skills.append(skill_id); button.text = button.text.replace("[OFF]", "[ON]")
				else: button.button_pressed = false
			else: _selected_skills.erase(skill_id); button.text = button.text.replace("[ON]", "[OFF]"))
		_skill_container.add_child(button)

func _on_confirm() -> void:
	loadout_confirmed.emit(_fund_slider.value, _selected_skills)
