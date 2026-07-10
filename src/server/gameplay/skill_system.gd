## 技能系统
## 所有权: WS2 (游戏玩法组)
## 管理技能的加载、激活、冷却和效果计算
## 参考: PRD §四 技能系统
extends Node
class_name SkillSystem


## ─── 信号（接口 B：SkillSystem -> GameSession）────────────────────────────
signal skill_activated(player_id: int, skill_id: StringName, effect: Dictionary)
signal skill_cooldown_updated(player_id: int, skill_id: StringName, remaining: float)
## 被动技能效果变更信号（装备技能时触发，供 GameSession 转发给其他子系统）
## modifiers 字典 key = skill_id, value = base_value，语义如下：
##   news_reader    : float — 减少信息延迟秒数
##   sentiment_sense: float — 是否显示恐贪指数（1.0=显示，bool 语义）
##   short_expert   : float — 做空收益加成比例（如 0.2 = +20%）
##   safe_harbor    : float — 撤离窗口延长秒数
##   diversify      : float — 持仓 >3 时手续费减免比例（如 0.5 = 减半）
signal passive_effects_changed(player_id: int, modifiers: Dictionary)
## Phase 3 新增：技能效果应用信号（供 WS1/WS3/WS5 连接）
## effect 为 SkillTypes.SkillEffect 实例，含 effect_type/target/value/duration
signal skill_effect_applied(player_id: int, skill_id: StringName, effect: Dictionary)


## 技能定义缓存
var _skill_defs: Dictionary = {}  ## skill_id -> SkillTypes.SkillDef
## 技能效果契约缓存
var _skill_effects: Dictionary = {}  ## skill_id -> SkillTypes.SkillEffect
## 每个玩家的运行时技能状态
var _player_skills: Dictionary = {}  ## player_id -> Dictionary(skill_id -> SkillTypes.SkillRuntimeState)


func _ready() -> void:
	_load_skill_definitions()
	_load_skill_effects()


## 加载所有技能定义
func _load_skill_definitions() -> void:
	_skill_defs.clear()
	for raw in SkillTypes.ALL_SKILLS:
		var def := SkillTypes.SkillDef.from_dict(raw)
		_skill_defs[def.skill_id] = def


## 加载技能效果契约表（Phase 3）
func _load_skill_effects() -> void:
	_skill_effects.clear()
	for raw in SkillTypes.ALL_SKILL_EFFECTS:
		var eff := SkillTypes.SkillEffect.from_dict(raw)
		_skill_effects[eff.skill_id] = eff


## 为玩家装备技能（准备阶段调用）
func equip_skills(player_id: int, skill_ids: Array[StringName]) -> void:
	var runtime: Dictionary = {}
	for sid in skill_ids:
		if _skill_defs.has(sid):
			var state := SkillTypes.SkillRuntimeState.new()
			state.skill_id = sid
			runtime[sid] = state
	_player_skills[player_id] = runtime
	# 装备完成后立即广播被动效果，供 GameSession 转发给相关子系统
	var modifiers := get_passive_modifiers(player_id)
	passive_effects_changed.emit(player_id, modifiers)


## 每 tick 更新冷却（由 GameSession 调用）
func update_cooldowns(delta: float) -> void:
	for player_id in _player_skills:
		var skills: Dictionary = _player_skills[player_id]
		for skill_id in skills:
			var state: SkillTypes.SkillRuntimeState = skills[skill_id]
			if state.cooldown_remaining > 0.0:
				state.cooldown_remaining -= delta
				if state.cooldown_remaining <= 0.0:
					state.cooldown_remaining = 0.0
				skill_cooldown_updated.emit(player_id, skill_id, state.cooldown_remaining)
			if state.effect_remaining > 0.0:
				state.effect_remaining -= delta
				if state.effect_remaining <= 0.0:
					state.is_active = false
					state.effect_remaining = 0.0


## 激活主动技能
func activate_skill(player_id: int, skill_id: StringName) -> Dictionary:
	if not _player_skills.has(player_id):
		return {}
	var skills: Dictionary = _player_skills[player_id]
	if not skills.has(skill_id):
		return {}
	var state: SkillTypes.SkillRuntimeState = skills[skill_id]
	if not _skill_defs.has(skill_id):
		return {}
	var def: SkillTypes.SkillDef = _skill_defs[skill_id]
	# 检查是否为主动技能
	if def.trigger != GameEnums.SkillTrigger.ACTIVE:
		return {}
	# 检查冷却
	if state.cooldown_remaining > 0.0:
		return {}
	# 激活
	state.is_active = true
	state.cooldown_remaining = def.cooldown
	if def.duration > 0.0:
		state.effect_remaining = def.duration
	var effect := {"skill_id": skill_id, "value": def.base_value, "duration": def.duration}
	skill_activated.emit(player_id, skill_id, effect)
	# Phase 3: 同时广播 SkillEffect 契约数据
	if _skill_effects.has(skill_id):
		var skill_eff: SkillTypes.SkillEffect = _skill_effects[skill_id]
		skill_effect_applied.emit(player_id, skill_id, skill_eff.to_dict())
	return effect


## 检查被动技能效果（返回修改器字典）
func get_passive_modifiers(player_id: int) -> Dictionary:
	var modifiers: Dictionary = {}
	if not _player_skills.has(player_id):
		return modifiers
	var skills: Dictionary = _player_skills[player_id]
	for skill_id in skills:
		if not _skill_defs.has(skill_id):
			continue
		var def: SkillTypes.SkillDef = _skill_defs[skill_id]
		if def.trigger == GameEnums.SkillTrigger.PASSIVE:
			modifiers[skill_id] = def.base_value
	return modifiers


## 获取玩家技能状态列表（用于广播）
func get_player_skill_states(player_id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _player_skills.has(player_id):
		return result
	var skills: Dictionary = _player_skills[player_id]
	for skill_id in skills:
		var state: SkillTypes.SkillRuntimeState = skills[skill_id]
		result.append(state.to_dict())
	return result


## 获取技能定义
func get_skill_def(skill_id: StringName) -> SkillTypes.SkillDef:
	return _skill_defs.get(skill_id, null)


## 获取技能效果契约（Phase 3，供其他子系统查询）
func get_skill_effect(skill_id: StringName) -> SkillTypes.SkillEffect:
	return _skill_effects.get(skill_id, null)


## 获取所有技能效果契约表
func get_all_skill_effects() -> Dictionary:
	return _skill_effects


## 获取所有技能定义
func get_all_skill_defs() -> Dictionary:
	return _skill_defs


## 清理玩家技能
func clear_player(player_id: int) -> void:
	_player_skills.erase(player_id)
