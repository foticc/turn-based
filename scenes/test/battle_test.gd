extends Node2D
## 5 玩家 vs 5 怪物 可视化回合制战斗测试。

@onready var turn_manager: TurnManager = $TurnManager
@onready var player_team: Node2D = $BattleField/Players
@onready var enemy_team: Node2D = $BattleField/Enemies
@onready var status_label: Label = $UI/MarginContainer/VBox/StatusLabel
@onready var action_panel: HBoxContainer = $UI/MarginContainer/VBox/ActionPanel
@onready var target_panel: HBoxContainer = $UI/MarginContainer/VBox/TargetPanel
@onready var log_label: RichTextLabel = $UI/MarginContainer/VBox/LogLabel
@onready var restart_button: Button = $UI/MarginContainer/VBox/RestartButton

var _actors_by_unit: Dictionary = {}
var _pending_action: TurnAction = null
var _last_target_id: String = ""


func _ready() -> void:
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
	_clear_ui()
	_actors_by_unit.clear()
	_last_target_id = ""

	var units: Array = []
	for actor in _get_all_actors():
		units.append(actor.create_battle_unit())
		_actors_by_unit[actor.battle_unit.id] = actor

	for actor in _actors_by_unit.values():
		actor.sync_from_unit()
		actor.set_turn_active(false)

	action_panel.visible = false
	target_panel.visible = false
	restart_button.disabled = true
	log_label.clear()
	_append_log("[color=yellow]5 vs 5 战斗开始！[/color]")
	turn_manager.start_battle(units)


func _on_phase_changed(phase: TurnManager.Phase) -> void:
	status_label.text = "阶段: %s" % TurnManager.Phase.keys()[phase]


func _on_round_started(round_number: int) -> void:
	status_label.text = "第 %d 回合" % round_number


func _on_turn_started(participant: TurnParticipant) -> void:
	status_label.text = "当前行动: %s" % participant.display_name
	for actor in _actors_by_unit.values():
		actor.set_turn_active(actor.battle_unit == participant)


func _on_action_requested(participant: TurnParticipant, actions: Array) -> void:
	_pending_action = null
	_clear_buttons(action_panel)
	_clear_buttons(target_panel)
	action_panel.visible = true
	target_panel.visible = false

	for action in actions:
		var btn := Button.new()
		btn.text = action.display_name
		btn.pressed.connect(_on_action_button_pressed.bind(action, participant))
		action_panel.add_child(btn)


func _on_action_button_pressed(action: TurnAction, participant: TurnParticipant) -> void:
	_pending_action = action
	_clear_buttons(action_panel)

	if action.target_type == TurnAction.TargetType.NONE or action.target_type == TurnAction.TargetType.SELF:
		action_panel.visible = false
		turn_manager.submit_action(action, participant)
		return

	var targets := participant.get_valid_targets(action, turn_manager.participants)
	if targets.is_empty():
		_append_log("[color=red]没有可用目标[/color]")
		action_panel.visible = true
		_on_action_requested(participant, participant.get_actions())
		return

	target_panel.visible = true
	for target in targets:
		var btn := Button.new()
		btn.text = target.display_name
		btn.pressed.connect(_on_target_button_pressed.bind(action, target))
		target_panel.add_child(btn)


func _on_target_button_pressed(action: TurnAction, target: TurnParticipant) -> void:
	action_panel.visible = false
	target_panel.visible = false
	_clear_buttons(target_panel)
	turn_manager.submit_action(action, target)


func _on_action_executing(action: TurnAction, actor: TurnParticipant, target: TurnParticipant) -> void:
	_last_target_id = target.id if target else ""
	var actor_node: BattleActor = _actors_by_unit.get(actor.id)
	if actor_node == null:
		return
	if action.id == "attack":
		actor_node.play_attack()


func _on_action_completed(action: TurnAction, _actor: TurnParticipant, result: Dictionary) -> void:
	for actor_node in _actors_by_unit.values():
		actor_node.sync_from_unit()

	if action.id != "attack" or _last_target_id == "":
		return

	var target_node: BattleActor = _actors_by_unit.get(_last_target_id)
	if target_node == null:
		return

	if result.get("defended", false):
		target_node.play_defend_on_hit()
	elif result.get("damage", 0) > 0:
		target_node.play_hurt()


func _on_battle_finished(_winning_team: int) -> void:
	action_panel.visible = false
	target_panel.visible = false
	restart_button.disabled = false
	for actor in _actors_by_unit.values():
		actor.set_turn_active(false)


func _clear_ui() -> void:
	_clear_buttons(action_panel)
	_clear_buttons(target_panel)
	_pending_action = null


func _clear_buttons(container: HBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()


func _append_log(message: String) -> void:
	log_label.append_text(message + "\n")
