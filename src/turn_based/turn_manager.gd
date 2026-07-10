class_name TurnManager
extends Node
## 回合制战斗管理器，负责回合循环、行动调度与胜负判定。

enum Phase {
	IDLE,
	ROUND_START,
	TURN_START,
	WAITING_FOR_ACTION,
	EXECUTING_ACTION,
	TURN_END,
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


func start_battle(battle_participants: Array) -> void:
	if _battle_running:
		return

	participants.clear()
	for participant in battle_participants:
		participants.append(participant as TurnParticipant)
	current_round = 0
	current_participant = null
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
		return

	_waiting_for_action = false
	_execute_action(action, target)


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
		_build_turn_order()

		for participant in turn_order:
			if not _battle_running or _is_battle_over():
				break
			if not participant.can_act():
				continue

			current_participant = participant
			_set_phase(Phase.TURN_START)
			participant.on_turn_start()
			turn_started.emit(participant)
			_log("%s 的回合" % participant.display_name)

			var actions := participant.get_actions()
			if actions.is_empty():
				_end_current_turn()
				continue

			_set_phase(Phase.WAITING_FOR_ACTION)
			if participant.is_player_controlled():
				_waiting_for_action = true
				action_requested.emit(participant, actions)
				while _waiting_for_action and _battle_running:
					await get_tree().process_frame
			else:
				await get_tree().create_timer(0.6).timeout
				var choice := _choose_ai_action(participant, actions)
				_execute_action(choice.action, choice.target)

		_set_phase(Phase.ROUND_END)
		round_ended.emit(current_round)

	_finish_battle()


func _execute_action(action: TurnAction, target: TurnParticipant) -> void:
	if current_participant == null or action == null:
		return

	_set_phase(Phase.EXECUTING_ACTION)
	action_executing.emit(action, current_participant, target)
	var result := action.execute(current_participant, target)
	action_completed.emit(action, current_participant, result)

	if result.get("message", "") != "":
		_log(str(result.message))

	_end_current_turn()


func _end_current_turn() -> void:
	if current_participant == null:
		return

	_set_phase(Phase.TURN_END)
	current_participant.on_turn_end()
	turn_ended.emit(current_participant)
	current_participant = null


func _build_turn_order() -> void:
	var living := get_living_participants()
	living.sort_custom(func(a: TurnParticipant, b: TurnParticipant) -> bool:
		if a.speed != b.speed:
			return a.speed > b.speed
		return a.display_name < b.display_name
	)
	turn_order = living


func _choose_ai_action(actor: TurnParticipant, actions: Array) -> Dictionary:
	var attack_action: TurnAction = null
	var defend_action: TurnAction = null

	for action in actions:
		if action.id == "attack":
			attack_action = action
		elif action.id == "defend":
			defend_action = action

	if actor is BattleUnit:
		var unit := actor as BattleUnit
		if defend_action and unit.hp <= unit.max_hp * 0.3:
			return {"action": defend_action, "target": actor}

	if attack_action:
		var targets := actor.get_valid_targets(attack_action, participants)
		if not targets.is_empty():
			return {"action": attack_action, "target": targets.pick_random()}

	for action in actions:
		if action.target_type == TurnAction.TargetType.NONE:
			return {"action": action, "target": null}

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
