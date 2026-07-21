extends Node2D
## 纯战斗测试：2 名玩家控制单位 vs 多名敌人（含多目标技能）。

@onready var turn_manager: TurnManager = $TurnManager
@onready var player_team: Node2D = $BattleField/Players
@onready var enemy_team: Node2D = $BattleField/Enemies
@onready var vfx_player: BattleVfxPlayer = $BattleField/VfxPlayer
@onready var status_label: Label = $UI/MarginContainer/VBox/StatusLabel
@onready var action_panel: HBoxContainer = $UI/MarginContainer/VBox/ActionPanel
@onready var target_panel: HBoxContainer = $UI/MarginContainer/VBox/TargetPanel
@onready var log_label: RichTextLabel = $UI/MarginContainer/VBox/LogLabel
@onready var restart_button: Button = $UI/MarginContainer/VBox/RestartButton

var _actors_by_unit: Dictionary = {}
var _last_target_id: String = ""
var _command_menu := BattleCommandMenu.new()


func _ready() -> void:
	_command_menu.setup(action_panel, target_panel)
	_command_menu.action_chosen.connect(_on_command_action_chosen)
	_command_menu.no_targets.connect(_on_no_targets)
	_connect_signals()
	restart_button.pressed.connect(_start_battle)
	_start_battle()


func _connect_signals() -> void:
	turn_manager.phase_changed.connect(_on_phase_changed)
	turn_manager.round_started.connect(_on_round_started)
	turn_manager.turn_started.connect(_on_turn_started)
	turn_manager.round_ended.connect(_on_round_ended)
	turn_manager.action_requested.connect(_on_action_requested)
	turn_manager.action_executing.connect(_on_action_executing)
	turn_manager.action_completed.connect(_on_action_completed)
	turn_manager.battle_finished.connect(_on_battle_finished)
	turn_manager.log_message.connect(_append_log)


func _get_all_actors() -> Array[BattleActor]:
	var actors: Array[BattleActor] = []
	for child in player_team.get_children():
		if child is BattleActor:
			actors.append(child)
	for child in enemy_team.get_children():
		if child is BattleActor:
			actors.append(child)
	return actors


func _start_battle() -> void:
	_command_menu.hide_all()
	_actors_by_unit.clear()
	_last_target_id = ""

	var units: Array = []
	for actor in _get_all_actors():
		units.append(actor.create_battle_unit())
		_actors_by_unit[actor.battle_unit.id] = actor

	for actor in _actors_by_unit.values():
		actor.sync_from_unit()
		actor.set_turn_active(false)

	restart_button.disabled = true
	log_label.clear()
	_append_log("[color=yellow]战斗开始！先为我方全员选择指令，再统一结算。[/color]")
	turn_manager.start_battle(units)


func _on_phase_changed(phase: TurnManager.Phase) -> void:
	status_label.text = "阶段: %s" % TurnManager.Phase.keys()[phase]


func _on_round_started(round_number: int) -> void:
	status_label.text = "第 %d 回合 · 选择指令" % round_number


func _on_turn_started(participant: TurnParticipant) -> void:
	if turn_manager.current_phase == TurnManager.Phase.RESOLVE \
			or turn_manager.current_phase == TurnManager.Phase.EXECUTING_ACTION:
		status_label.text = "行动中: %s" % participant.display_name
	else:
		status_label.text = "选择指令: %s" % participant.display_name
	for actor in _actors_by_unit.values():
		actor.set_turn_active(actor.battle_unit == participant)


func _on_action_requested(participant: TurnParticipant, _actions: Array) -> void:
	status_label.text = "选择指令: %s" % participant.display_name
	for actor in _actors_by_unit.values():
		actor.set_turn_active(actor.battle_unit == participant)
	_command_menu.show_for(participant, turn_manager.participants)


func _on_round_ended(_round_number: int) -> void:
	for actor_node in _actors_by_unit.values():
		actor_node.sync_from_unit()
		actor_node.set_turn_active(false)


func _on_command_action_chosen(action: TurnAction, target: TurnParticipant) -> void:
	turn_manager.submit_action(action, target)


func _on_no_targets() -> void:
	_append_log("[color=red]没有可用目标[/color]")


func _on_action_executing(action: TurnAction, actor: TurnParticipant, target: TurnParticipant) -> void:
	_last_target_id = target.id if target else ""
	var actor_node: BattleActor = _actors_by_unit.get(actor.id)
	var target_node: BattleActor = _actors_by_unit.get(target.id) if target else null
	if actor_node == null:
		return
	if action is SkillAction:
		var skill := action as SkillAction
		actor_node.play_skill(skill)
		if vfx_player:
			vfx_player.play_for_skill(skill, actor_node, _actor_nodes_for_skill(skill, target_node))
	elif action.id == "attack":
		actor_node.play_attack()


func _actor_nodes_for_skill(skill: SkillAction, fallback: BattleActor) -> Array:
	var nodes: Array = []
	for receiver in skill.get_resolved_targets():
		if receiver == null:
			continue
		var node: BattleActor = _actors_by_unit.get(receiver.id)
		if node:
			nodes.append(node)
	if nodes.is_empty() and fallback:
		nodes.append(fallback)
	return nodes


func _on_action_completed(action: TurnAction, _actor: TurnParticipant, result: Dictionary) -> void:
	for actor_node in _actors_by_unit.values():
		actor_node.sync_from_unit()

	var dealt_damage: bool = result.get("damage", 0) > 0
	var is_damage_skill := action is SkillAction and (
		(action as SkillAction).skill_kind == SkillDefinition.SkillKind.DAMAGE
	)
	var is_offensive := action.id == "attack" or is_damage_skill
	if not is_offensive or not dealt_damage:
		return

	var hit_ids: PackedStringArray = result.get("damaged_ids", PackedStringArray())
	if hit_ids.is_empty() and _last_target_id != "":
		hit_ids = PackedStringArray([_last_target_id])

	for target_id in hit_ids:
		var target_node: BattleActor = _actors_by_unit.get(target_id)
		if target_node == null:
			continue
		if result.get("defended", false):
			target_node.play_defend_on_hit()
		else:
			target_node.play_hurt()


func _on_battle_finished(_winning_team: int) -> void:
	_command_menu.hide_all()
	restart_button.disabled = false
	for actor in _actors_by_unit.values():
		actor.set_turn_active(false)


func _append_log(message: String) -> void:
	log_label.append_text(message + "\n")
