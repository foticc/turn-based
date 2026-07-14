extends Node2D
## 可视化回合制战斗测试。

@onready var turn_manager: TurnManager = $TurnManager
@onready var player_team: Node2D = $BattleField/Players
@onready var enemy_team: Node2D = $BattleField/Enemies
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
	_append_log("[color=yellow]战斗开始！[/color]")
	turn_manager.start_battle(units)


func _on_phase_changed(phase: TurnManager.Phase) -> void:
	status_label.text = "阶段: %s" % TurnManager.Phase.keys()[phase]


func _on_round_started(round_number: int) -> void:
	status_label.text = "第 %d 回合" % round_number


func _on_turn_started(participant: TurnParticipant) -> void:
	status_label.text = "当前行动: %s" % participant.display_name
	for actor in _actors_by_unit.values():
		actor.set_turn_active(actor.battle_unit == participant)


func _on_action_requested(participant: TurnParticipant, _actions: Array) -> void:
	_command_menu.show_for(participant, turn_manager.participants)


func _on_command_action_chosen(action: TurnAction, target: TurnParticipant) -> void:
	turn_manager.submit_action(action, target)


func _on_no_targets() -> void:
	_append_log("[color=red]没有可用目标[/color]")


func _on_action_executing(action: TurnAction, actor: TurnParticipant, target: TurnParticipant) -> void:
	_last_target_id = target.id if target else ""
	var actor_node: BattleActor = _actors_by_unit.get(actor.id)
	if actor_node == null:
		return
	if action is SkillAction:
		actor_node.play_skill(action as SkillAction)
	elif action.id == "attack":
		actor_node.play_attack()


func _on_action_completed(action: TurnAction, _actor: TurnParticipant, result: Dictionary) -> void:
	for actor_node in _actors_by_unit.values():
		actor_node.sync_from_unit()

	var dealt_damage: bool = result.get("damage", 0) > 0
	var is_offensive := action.id == "attack" or action is SkillAction
	if not is_offensive or _last_target_id == "" or not dealt_damage:
		return

	var target_node: BattleActor = _actors_by_unit.get(_last_target_id)
	if target_node == null:
		return

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
