class_name BattleCommandMenu
extends RefCounted
## 回合指令菜单：攻击 / 技能 / 防御；技能为二级列表。

signal action_chosen(action: TurnAction, target: TurnParticipant)
signal no_targets()

var _action_panel: HBoxContainer
var _target_panel: HBoxContainer
var _participant: TurnParticipant
var _participants: Array = []


func setup(action_panel: HBoxContainer, target_panel: HBoxContainer) -> void:
	_action_panel = action_panel
	_target_panel = target_panel


func show_for(participant: TurnParticipant, participants: Array) -> void:
	_participant = participant
	_participants = participants
	_show_main_commands()


func hide_all() -> void:
	_clear(_action_panel)
	_clear(_target_panel)
	if _action_panel:
		_action_panel.visible = false
	if _target_panel:
		_target_panel.visible = false


func _show_main_commands() -> void:
	_clear(_action_panel)
	_clear(_target_panel)
	_action_panel.visible = true
	_target_panel.visible = false

	var unit := _participant as BattleUnit
	var basics: Array[TurnAction] = []
	if unit:
		basics = unit.get_basic_actions()
	else:
		for action in _participant.get_actions():
			if not action is SkillAction:
				basics.append(action)

	var attack: TurnAction = null
	var defend: TurnAction = null
	var others: Array[TurnAction] = []
	for action in basics:
		if action.id == "attack":
			attack = action
		elif action.id == "defend":
			defend = action
		else:
			others.append(action)

	if attack:
		_add_button(_action_panel, attack.get_button_text(), _on_action_picked.bind(attack))

	if unit and unit.has_skills():
		_add_button(_action_panel, "技能", _show_skill_list)

	if defend:
		_add_button(_action_panel, defend.get_button_text(), _on_action_picked.bind(defend))

	for action in others:
		_add_button(_action_panel, action.get_button_text(), _on_action_picked.bind(action))


func _show_skill_list() -> void:
	_clear(_action_panel)
	_clear(_target_panel)
	_action_panel.visible = true
	_target_panel.visible = false

	var unit := _participant as BattleUnit
	if unit == null:
		_show_main_commands()
		return

	for skill in unit.get_skills():
		var btn := Button.new()
		btn.text = skill.get_button_text()
		btn.tooltip_text = skill.get_tooltip_text()
		var ready := skill.is_ready(_participant)
		# 不用 disabled，否则 tip 不显示；未就绪时点击无效
		btn.modulate = Color.WHITE if ready else Color(0.65, 0.65, 0.7)
		btn.pressed.connect(_on_skill_button_pressed.bind(skill, ready))
		_action_panel.add_child(btn)

	_add_button(_action_panel, "返回", _show_main_commands)


func _on_skill_button_pressed(skill: SkillAction, ready: bool) -> void:
	if not ready:
		return
	_on_action_picked(skill)


func _on_action_picked(action: TurnAction) -> void:
	_clear(_action_panel)
	_clear(_target_panel)

	if action.target_type == TurnAction.TargetType.NONE or action.target_type == TurnAction.TargetType.SELF:
		_action_panel.visible = false
		_target_panel.visible = false
		action_chosen.emit(action, _participant)
		return

	var targets := _participant.get_valid_targets(action, _participants)
	if targets.is_empty():
		no_targets.emit()
		_show_main_commands()
		return

	_action_panel.visible = false
	_target_panel.visible = true

	for target in targets:
		_add_button(_target_panel, target.display_name, _on_target_picked.bind(action, target))

	if action is SkillAction:
		_add_button(_target_panel, "返回", _show_skill_list)
	else:
		_add_button(_target_panel, "返回", _show_main_commands)


func _on_target_picked(action: TurnAction, target: TurnParticipant) -> void:
	hide_all()
	action_chosen.emit(action, target)


func _add_button(container: HBoxContainer, text: String, callable: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(callable)
	container.add_child(btn)


func _clear(container: HBoxContainer) -> void:
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()
