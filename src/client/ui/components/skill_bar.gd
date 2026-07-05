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
