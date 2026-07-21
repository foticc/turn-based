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


func _actor_title() -> String:
	if _participant == null:
		return "选择指令"
	return "▶ %s 的指令" % _participant.display_name


func _add_actor_header(container: HBoxContainer) -> void:
	var label := Label.new()
	label.text = _actor_title()
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.45))
	label.add_theme_font_size_override("font_size", 18)
	container.add_child(label)


func _show_main_commands() -> void:
	_clear(_action_panel)
	_clear(_target_panel)
	_action_panel.visible = true
	_target_panel.visible = false

	_add_actor_header(_action_panel)

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
		_add_button(_action_panel, attack.get_button_text(), _request_action.bind(attack))

	if unit and unit.has_skills():
		_add_button(_action_panel, "技能", _request_skill_list)

	if defend:
		_add_button(_action_panel, defend.get_button_text(), _request_action.bind(defend))

	for action in others:
		_add_button(_action_panel, action.get_button_text(), _request_action.bind(action))


func _request_skill_list() -> void:
	# 必须在 pressed 回调结束后再清按钮，否则可能打断后续 UI 重建
	_show_skill_list.call_deferred()


func _request_action(action: TurnAction) -> void:
	_on_action_picked.call_deferred(action)


func _show_skill_list() -> void:
	_clear(_action_panel)
	_clear(_target_panel)
	_action_panel.visible = true
	_target_panel.visible = false

	_add_actor_header(_action_panel)

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
		btn.pressed.connect(_request_skill.bind(skill))
		_action_panel.add_child(btn)

	_add_button(_action_panel, "返回", _request_main_commands)


func _request_main_commands() -> void:
	_show_main_commands.call_deferred()


func _request_skill(skill: SkillAction) -> void:
	if not skill.is_ready(_participant):
		return
	_on_action_picked.call_deferred(skill)


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

	_add_actor_header(_target_panel)

	var multi := action is SkillAction and (action as SkillAction).max_targets > 1
	for target in targets:
		var label: String = str(target.display_name)
		if multi:
			label = "%s（主目标）" % str(target.display_name)
		_add_button(_target_panel, label, _request_target.bind(action, target))

	if action is SkillAction:
		_add_button(_target_panel, "返回", _request_skill_list)
	else:
		_add_button(_target_panel, "返回", _request_main_commands)


func _request_target(action: TurnAction, target: TurnParticipant) -> void:
	_confirm_target.call_deferred(action, target)


func _confirm_target(action: TurnAction, target: TurnParticipant) -> void:
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
	# 先移出再释放，避免同一帧内 HBox 里残留待删除子节点干扰布局
	while container.get_child_count() > 0:
		var child := container.get_child(0)
		container.remove_child(child)
		child.queue_free()
