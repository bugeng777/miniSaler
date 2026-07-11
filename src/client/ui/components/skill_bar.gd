## 技能栏（主动技能按钮 + 被动技能状态指示）
## 所有权: WS5 (客户端 UI 组)
extends HBoxContainer
class_name SkillBar

signal skill_activate_requested(skill_id: StringName)

var _skill_buttons: Dictionary = {}     ## skill_id -> Button
var _skill_names: Dictionary = {}       ## skill_id -> String (原始显示名)
var _passive_indicators: Dictionary = {} ## skill_id -> ColorRect (被动状态指示条)


func add_skill(skill_id: StringName, display_name: String, is_active: bool) -> void:
	var container := VBoxContainer.new()
	container.custom_minimum_size = Vector2(80, 40)
	add_child(container)

	var btn := Button.new()
	btn.text = display_name
	btn.custom_minimum_size = Vector2(80, 30)
	btn.pressed.connect(func() -> void:
		if is_active:
			skill_activate_requested.emit(skill_id))
	container.add_child(btn)

	# 被动技能底部指示条
	var indicator := ColorRect.new()
	indicator.custom_minimum_size = Vector2(80, 4)
	if is_active:
		indicator.color = Color(0.0, 0.7, 0.5, 0.3)  # 主动技能: 暗绿
	else:
		indicator.color = Color(0.85, 0.75, 0.2, 0.8)  # 被动技能: 金色
		btn.tooltip_text = "被动技能 — 自动生效"
	container.add_child(indicator)

	_skill_buttons[skill_id] = btn
	_skill_names[skill_id] = display_name
	_passive_indicators[skill_id] = indicator


func update_cooldown(skill_id: StringName, remaining: float) -> void:
	if _skill_buttons.has(skill_id):
		var btn: Button = _skill_buttons[skill_id]
		if remaining > 0.0:
			btn.disabled = true
			btn.text = "%.0fs" % remaining
		else:
			btn.disabled = false
			btn.text = _skill_names.get(skill_id, "?")


## 更新被动技能激活状态（高亮指示条）
func set_passive_active(skill_id: StringName, is_active: bool) -> void:
	if _passive_indicators.has(skill_id):
		var indicator: ColorRect = _passive_indicators[skill_id]
		if is_active:
			indicator.color = Color(0.2, 0.9, 0.3, 1.0)  # 亮绿 = 激活中
		else:
			indicator.color = Color(0.85, 0.75, 0.2, 0.3)  # 暗金 = 未激活


## 显示技能效果持续时间（用于有持续时间的技能）
func show_effect_duration(skill_id: StringName, remaining: float) -> void:
	if _skill_buttons.has(skill_id):
		var btn: Button = _skill_buttons[skill_id]
		if remaining > 0.0:
			btn.text = "%s\n%.0fs" % [_skill_names.get(skill_id, "?"), remaining]
		else:
			btn.text = _skill_names.get(skill_id, "?")


func clear_skills() -> void:
	for btn in _skill_buttons.values():
		if is_instance_valid(btn) and is_instance_valid(btn.get_parent()):
			btn.get_parent().queue_free()
		elif is_instance_valid(btn):
			btn.queue_free()
	_skill_buttons.clear()
	_skill_names.clear()
	_passive_indicators.clear()
## 技能栏（主动技能按钮）
## 所有权: WS5 (客户端 UI 组)
extends HBoxContainer
class_name SkillBar

signal skill_activate_requested(skill_id: StringName)

var _skill_buttons: Dictionary = {}  ## skill_id -> Button


func add_skill(skill_id: StringName, display_name: String, is_active: bool) -> void:
	var btn := Button.new()
	btn.text = display_name
	btn.custom_minimum_size = Vector2(80, 30)
	if not is_active:
		btn.tooltip_text = "被动技能"
	btn.pressed.connect(func() -> void:
		if is_active:
			skill_activate_requested.emit(skill_id))
	_skill_buttons[skill_id] = btn
	add_child(btn)


func update_cooldown(skill_id: StringName, remaining: float) -> void:
	if _skill_buttons.has(skill_id):
		var btn: Button = _skill_buttons[skill_id]
		if remaining > 0.0:
			btn.disabled = true
			btn.text = "%.0fs" % remaining
		else:
			btn.disabled = false


func clear_skills() -> void:
	for btn in _skill_buttons.values():
		btn.queue_free()
	_skill_buttons.clear()
