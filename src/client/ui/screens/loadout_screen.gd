## 准备界面（配资金/选技能）
## 所有权: WS5 (客户端 UI 组)
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
	_build_ui()


func _build_ui() -> void:
	# 标题
	var title := Label.new()
	title.text = "准备阶段"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	add_child(title)

	# 资金配置
	var fund_panel := VBoxContainer.new()
	fund_panel.position = Vector2(40, 80)
	add_child(fund_panel)
	var fund_title := Label.new()
	fund_title.text = "带入额外资金"
	fund_panel.add_child(fund_title)
	_fund_slider = HSlider.new()
	_fund_slider.min_value = 0.0
	_fund_slider.max_value = Constants.MAX_EXTRA_FUNDS
	_fund_slider.step = 10_000.0
	_fund_slider.custom_minimum_size = Vector2(300, 30)
	fund_panel.add_child(_fund_slider)
	_fund_label = Label.new()
	_fund_label.text = "$0"
	fund_panel.add_child(_fund_label)
	_fund_slider.value_changed.connect(func(val: float) -> void:
		_fund_label.text = "$%d" % int(val)
	)

	# 技能选择
	var skill_panel := VBoxContainer.new()
	skill_panel.position = Vector2(40, 250)
	add_child(skill_panel)
	var skill_title := Label.new()
	skill_title.text = "选择技能 (槽位: %d)" % _max_slots
	skill_panel.add_child(skill_title)
	_skill_container = VBoxContainer.new()
	skill_panel.add_child(_skill_container)

	# 确认按钮
	_confirm_btn = Button.new()
	_confirm_btn.text = "入局"
	_confirm_btn.custom_minimum_size = Vector2(200, 50)
	_confirm_btn.position = Vector2(250, 600)
	_confirm_btn.pressed.connect(_on_confirm)
	add_child(_confirm_btn)

	# 倒计时
	_countdown_label = Label.new()
	_countdown_label.text = "30"
	_countdown_label.position = Vector2(600, 20)
	add_child(_countdown_label)


func set_countdown(seconds: float) -> void:
	_countdown_label.text = str(int(seconds))


func load_skills(available_skills: Array[Dictionary]) -> void:
	for child in _skill_container.get_children():
		child.queue_free()
	for skill_data in available_skills:
		var btn := Button.new()
		btn.text = "%s - %s" % [skill_data.get("display_name", ""), skill_data.get("description", "")]
		var sid := StringName(skill_data.get("skill_id", ""))
		btn.toggle_mode = true
		btn.pressed.connect(func() -> void:
			if btn.button_pressed:
				if _selected_skills.size() < _max_slots:
					_selected_skills.append(sid)
				else:
					btn.button_pressed = false
			else:
				_selected_skills.erase(sid)
		)
		_skill_container.add_child(btn)


func _on_confirm() -> void:
	loadout_confirmed.emit(_fund_slider.value, _selected_skills)
