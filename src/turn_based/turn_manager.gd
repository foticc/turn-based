class_name TurnManager
extends Node
## 回合制战斗：每回合先收集我方全部指令，再与敌方一齐按速度结算。

enum Phase {
	IDLE,
	ROUND_START,
	COMMAND, ## 收集我方指令
	WAITING_FOR_ACTION,
	RESOLVE, ## 按速度依次结算本回合行动
	EXECUTING_ACTION,
	ROUND_END,
	FINISHED,
}

signal phase_changed(new_phase: Phase)
signal round_started(round_number: int)
signal round_ended(round_number: int)
signal turn_started(participant: TurnParticipant)
signal turn_ended(participant: TurnParticipant)
signal action_requested(participant: TurnParticipant, actions: Array)
signal action_executing(action: TurnAction, actor: TurnParticipant, target: TurnParticipant)
signal action_completed(action: TurnAction, actor: TurnParticipant, result: Dictionary)
signal battle_finished(winning_team: int)
signal log_message(message: String)

var participants: Array[TurnParticipant] = []
var turn_order: Array[TurnParticipant] = []
var current_round: int = 0
var current_participant: TurnParticipant = null
var current_phase: Phase = Phase.IDLE

var _battle_running: bool = false
var _waiting_for_action: bool = false
## { "actor": TurnParticipant, "action": TurnAction, "target": TurnParticipant }
var _planned_actions: Array[Dictionary] = []


func start_battle(battle_participants: Array) -> void:
	if _battle_running:
		return

	participants.clear()
	for participant in battle_participants:
		participants.append(participant as TurnParticipant)
	current_round = 0
	current_participant = null
	_planned_actions.clear()
	_battle_running = true
	_set_phase(Phase.IDLE)
	_log("战斗开始！")
	_run_battle_loop()


func submit_action(action: TurnAction, target: TurnParticipant = null) -> void:
	if not _waiting_for_action or current_participant == null:
		return
	if action == null:
		return
	if not action.can_execute(current_participant, target):
		_log("无法执行该行动。")
		action_requested.emit(current_participant, _get_actions_for(current_participant))
		return

	_planned_actions.append({
		"actor": current_participant,
		"action": action,
		"target": target,
	})
	_log("%s 已选择【%s】" % [current_participant.display_name, action.display_name])
	_waiting_for_action = false


func get_living_participants() -> Array[TurnParticipant]:
	var living: Array[TurnParticipant] = []
	for p in participants:
		if p.is_alive:
			living.append(p)
	return living


func get_team_participants(team: int, living_only: bool = true) -> Array[TurnParticipant]:
	var result: Array[TurnParticipant] = []
	for p in participants:
		if p.team == team and (not living_only or p.is_alive):
			result.append(p)
	return result


func _run_battle_loop() -> void:
	while _battle_running and not _is_battle_over():
		current_round += 1
		_set_phase(Phase.ROUND_START)
		round_started.emit(current_round)
		_log("—— 第 %d 回合 ——" % current_round)
		_begin_round()

		_planned_actions.clear()
		_set_phase(Phase.COMMAND)

		# 1) 我方所有可行动单位依次选指令（先不结算）
		var player_units := _get_living_player_units()
		_sort_by_speed(player_units)
		for participant in player_units:
			if not _battle_running or _is_battle_over():
				break
			if not participant.can_act():
				continue

			current_participant = participant
			turn_started.emit(participant)
			_log("请为 %s 选择指令" % participant.display_name)

			var actions := _get_actions_for(participant)
			if actions.is_empty():
				turn_ended.emit(participant)
				current_participant = null
				continue

			_set_phase(Phase.WAITING_FOR_ACTION)
			_waiting_for_action = true
			action_requested.emit(participant, actions)
			while _waiting_for_action and _battle_running:
				await get_tree().process_frame

			turn_ended.emit(participant)
			current_participant = null

		if not _battle_running or _is_battle_over():
			break

		# 2) 敌方（及非玩家控制单位）决定行动
		for participant in get_living_participants():
			if participant.is_player_controlled() or not participant.can_act():
				continue
			var actions := _get_actions_for(participant)
			if actions.is_empty():
				continue
			var choice := _choose_ai_action(participant, actions)
			if choice.action == null:
				continue
			_planned_actions.append({
				"actor": participant,
				"action": choice.action,
				"target": choice.target,
			})

		# 3) 按速度统一结算
		_set_phase(Phase.RESOLVE)
		_log("—— 行动开始 ——")
		_sort_planned_by_speed()
		for plan in _planned_actions:
			if not _battle_running or _is_battle_over():
				break
			_resolve_planned(plan)
			if _battle_running and not _is_battle_over():
				await get_tree().create_timer(0.35).timeout

		_set_phase(Phase.ROUND_END)
		_end_round()
		round_ended.emit(current_round)

	_finish_battle()


func _begin_round() -> void:
	for p in participants:
		if p is BattleUnit:
			(p as BattleUnit).on_round_start()


func _end_round() -> void:
	for p in participants:
		if p is BattleUnit:
			(p as BattleUnit).on_round_end()


func _resolve_planned(plan: Dictionary) -> void:
	var actor: TurnParticipant = plan.get("actor")
	var action: TurnAction = plan.get("action")
	var target: TurnParticipant = plan.get("target")
	if actor == null or action == null or not actor.can_act():
		return

	if action.target_type == TurnAction.TargetType.SELF or action.target_type == TurnAction.TargetType.NONE:
		target = actor
	elif target == null or not target.is_alive:
		var alts: Array = actor.get_valid_targets(action, participants)
		if alts.is_empty():
			_log("%s 的【%s】取消（没有目标）" % [actor.display_name, action.display_name])
			return
		target = alts.pick_random()

	current_participant = actor
	turn_started.emit(actor)

	if action is SkillAction:
		var skill := action as SkillAction
		skill.clear_resolved_targets()
		skill.prepare_targets(actor, target, participants)

	if not action.can_execute(actor, target):
		_log("%s 无法执行【%s】" % [actor.display_name, action.display_name])
		if action is SkillAction:
			(action as SkillAction).clear_resolved_targets()
		turn_ended.emit(actor)
		current_participant = null
		return

	_set_phase(Phase.EXECUTING_ACTION)
	action_executing.emit(action, actor, target)
	var result := action.execute(actor, target)
	action_completed.emit(action, actor, result)

	if result.get("message", "") != "":
		_log(str(result.message))

	turn_ended.emit(actor)
	current_participant = null


func _get_living_player_units() -> Array[TurnParticipant]:
	var result: Array[TurnParticipant] = []
	for p in participants:
		if p.is_alive and p.is_player_controlled():
			result.append(p)
	return result


func _sort_by_speed(units: Array[TurnParticipant]) -> void:
	units.sort_custom(func(a: TurnParticipant, b: TurnParticipant) -> bool:
		return _effective_speed(a) > _effective_speed(b)
	)


func _sort_planned_by_speed() -> void:
	_planned_actions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _effective_speed(a.get("actor")) > _effective_speed(b.get("actor"))
	)
	turn_order.clear()
	for plan in _planned_actions:
		var actor: TurnParticipant = plan.get("actor")
		if actor:
			turn_order.append(actor)


func _effective_speed(participant: TurnParticipant) -> int:
	if participant == null:
		return 0
	if participant is BattleUnit:
		return (participant as BattleUnit).get_effective_speed()
	return participant.speed


func _get_actions_for(participant: TurnParticipant) -> Array:
	if participant is BattleUnit:
		if participant.is_player_controlled():
			return participant.get_actions()
		return (participant as BattleUnit).get_usable_actions()
	return participant.get_actions()


func _choose_ai_action(actor: TurnParticipant, actions: Array) -> Dictionary:
	var attack_action: TurnAction = null
	var defend_action: TurnAction = null
	var skill_actions: Array = []

	for action in actions:
		if action is SkillAction:
			skill_actions.append(action)
		elif action.id == "attack":
			attack_action = action
		elif action.id == "defend":
			defend_action = action

	if actor is BattleUnit:
		var unit := actor as BattleUnit
		if defend_action and unit.hp <= unit.max_hp * 0.3:
			return {"action": defend_action, "target": actor}

	if not skill_actions.is_empty() and randf() < 0.5:
		var skill: SkillAction = skill_actions.pick_random()
		if skill.is_ready(actor):
			var skill_targets := actor.get_valid_targets(skill, participants)
			if not skill_targets.is_empty():
				return {"action": skill, "target": skill_targets.pick_random()}

	if attack_action:
		var targets := actor.get_valid_targets(attack_action, participants)
		if not targets.is_empty():
			return {"action": attack_action, "target": targets.pick_random()}

	for action in actions:
		if action.target_type == TurnAction.TargetType.NONE or action.target_type == TurnAction.TargetType.SELF:
			return {"action": action, "target": actor}

	if actions.is_empty():
		return {"action": null, "target": null}
	return {"action": actions[0], "target": null}


func _is_battle_over() -> bool:
	var teams: Dictionary = {}
	for p in participants:
		if p.is_alive:
			teams[p.team] = true
	return teams.size() <= 1


func _finish_battle() -> void:
	_battle_running = false
	_waiting_for_action = false
	_planned_actions.clear()
	_set_phase(Phase.FINISHED)

	var winning_team := -1
	for p in participants:
		if p.is_alive:
			winning_team = p.team
			break

	var team_name := "玩家" if winning_team == 0 else "敌人"
	if winning_team == -1:
		_log("战斗结束：平局。")
	else:
		_log("战斗结束：%s 胜利！" % team_name)

	battle_finished.emit(winning_team)


func _set_phase(new_phase: Phase) -> void:
	current_phase = new_phase
	phase_changed.emit(new_phase)


func _log(message: String) -> void:
	log_message.emit(message)
